<#
.SYNOPSIS
    Retrieves history of Out-Of-Memory (OOM) killer events on Linux systems.
.DESCRIPTION
    Scans dmesg or system log files (/var/log/kern.log, /var/log/syslog) to search
    for Out-Of-Memory (OOM) killer occurrences, parsing them into structured objects.
    Designed to be fully compatible with the PowerShell pipeline for filtering and downstream commands.
.PARAMETER Source
    The log source to query. Options: Auto, dmesg, kern.log, syslog. Default is Auto (tries dmesg first, falls back to files).
.PARAMETER Limit
    Limits the number of returned events (newest first).
.PARAMETER ProcessName
    Pipes or specifies one or more process names to filter the history.
.PARAMETER ProcessId
    Pipes or specifies one or more process IDs (PIDs) to filter the history.
.PARAMETER Raw
    If specified, returns raw matching log lines instead of structured custom objects.
.PARAMETER WriteLogToFile
    Switch to force writing execution logs to a file.
.EXAMPLE
    Get-OomKillerHistory -Limit 5
.EXAMPLE
    Get-OomKillerHistory -ProcessName "antigravity-ide"
.EXAMPLE
    "chrome", "antigravity-ide" | Get-OomKillerHistory | Sort-Object TotalVMBytes -Descending
#>
function Get-OomKillerHistory {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter()]
        [ValidateSet('Auto', 'dmesg', 'kern.log', 'syslog')]
        [string]$Source = 'Auto',

        [Parameter()]
        [int]$Limit = 0,

        [Parameter(ParameterSetName = 'ByName', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$ProcessName,

        [Parameter(ParameterSetName = 'ById', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('PID')]
        [int[]]$ProcessId,

        [Parameter()]
        [switch]$Raw,

        [Parameter()]
        [switch]$WriteLogToFile
    )

    begin {
        if (-not $IsLinux) {
            Write-Error "Get-OomKillerHistory is only supported on Linux operating systems."
            return
        }

        # Helper to convert sizes with units (e.g. 405284kB) into numeric Bytes for pipeline sorting/filtering
        function ConvertTo-Bytes {
            param([string]$Value)
            if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
            
            $clean = $Value.Trim().TrimEnd(',')
            $foundMatches = [regex]::Match($clean, '^(\d+)(kb|mb|gb|tb|b)?$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($foundMatches.Success) {
                $num = [long]$foundMatches.Groups[1].Value
                $unit = $foundMatches.Groups[2].Value.ToUpper()
                switch ($unit) {
                    'KB' { return $num * 1KB }
                    'MB' { return $num * 1MB }
                    'GB' { return $num * 1GB }
                    'TB' { return $num * 1TB }
                    default { return $num }
                }
            }
            return $null
        }

        Write-Log -Message "Loading OOM killer history (Source: $Source)..." -Level Info -WriteLogToFile:$WriteLogToFile

        $lines = @()
        $sourceUsed = ""

        # Retrieve system boot time to resolve dmesg relative timestamps
        $bootTime = $null
        try {
            if (Test-Path /proc/uptime) {
                $uptimeSeconds = [double]((Get-Content /proc/uptime -Raw) -split '\s+')[0]
                $bootTime = (Get-Date).AddSeconds(-$uptimeSeconds)
            }
        }
        catch {
            Write-Log -Message "Failed to calculate system boot time. Uptime relative timestamps will display offset only. Error: $_" -Level Warning -WriteLogToFile:$WriteLogToFile
        }

        # Source resolution logic
        if ($Source -eq 'Auto' -or $Source -eq 'dmesg') {
            try {
                $dmesgOutput = & dmesg 2>$null
                if ($LASTEXITCODE -eq 0 -and $dmesgOutput) {
                    $lines = $dmesgOutput | Where-Object { $_ -match 'out of memory|killed process' }
                    $sourceUsed = "dmesg"
                }
            }
            catch {
                Write-Log -Message "dmesg command failed or is restricted: $_" -Level Debug -WriteLogToFile:$WriteLogToFile
            }
        }

        # Fallback to file logs if dmesg was not successful or not requested
        if ($lines.Count -eq 0 -and ($Source -eq 'Auto' -or $Source -eq 'kern.log' -or $Source -eq 'syslog')) {
            $logFilesToCheck = @()
            if ($Source -eq 'kern.log') { $logFilesToCheck += "/var/log/kern.log" }
            elseif ($Source -eq 'syslog') { $logFilesToCheck += "/var/log/syslog" }
            else {
                $logFilesToCheck += "/var/log/kern.log"
                $logFilesToCheck += "/var/log/syslog"
            }

            foreach ($logPath in $logFilesToCheck) {
                if (Test-Path $logPath) {
                    try {
                        $fileLines = Get-Content -Path $logPath -ErrorAction Stop
                        $lines = $fileLines | Where-Object { $_ -match 'out of memory|killed process' }
                        if ($lines.Count -gt 0) {
                            $sourceUsed = $logPath
                            break
                        }
                    }
                    catch {
                        Write-Log -Message "Failed to read log file '$logPath': $_" -Level Debug -WriteLogToFile:$WriteLogToFile
                    }
                }
            }
        }

        # Process and parse raw logs into memory cache for pipeline filtering
        $script:allEvents = @()
        if ($lines.Count -gt 0) {
            if ($Raw) {
                $script:allEvents = $lines
            }
            else {
                $dmesgPattern = '^\[\s*([\d.]+)\s*\]\s+(?:Out of memory:\s+)?Killed process\s+(\d+)\s+\(([^)]+)\)\s+total-vm:([^,\s]+),\s+anon-rss:([^,\s]+).*oom_score_adj:(\d+)'
                $syslogPattern = '^(\S+)\s+\S+\s+kernel:\s+(?:\[\s*[\d.]+\s*\]\s+)?(?:Out of memory:\s+)?Killed process\s+(\d+)\s+\(([^)]+)\)\s+total-vm:([^,\s]+),\s+anon-rss:([^,\s]+).*oom_score_adj:(\d+)'

                foreach ($line in $lines) {
                    [datetime]$parsedDate = [datetime]::MinValue
                    $parsedPid = $null
                    $parsedProcessName = $null
                    $totalVm = $null
                    $anonRss = $null
                    $oomScoreAdj = $null
                    $parsedSuccessfully = $false

                    # Pattern Match 1: Syslog / kern.log
                    $foundMatches = [regex]::Match($line, $syslogPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                    if ($foundMatches.Success) {
                        $rawDate = $foundMatches.Groups[1].Value
                        if ([DateTime]::TryParse($rawDate, [ref]$parsedDate)) {
                            # Parsed successfully
                        }
                        $parsedPid = [int]$foundMatches.Groups[2].Value
                        $parsedProcessName = $foundMatches.Groups[3].Value
                        $totalVm = $foundMatches.Groups[4].Value
                        $anonRss = $foundMatches.Groups[5].Value
                        $oomScoreAdj = [int]$foundMatches.Groups[6].Value
                        $parsedSuccessfully = $true
                    }
                    else {
                        # Pattern Match 2: dmesg (relative timestamp)
                        $foundMatches = [regex]::Match($line, $dmesgPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                        if ($foundMatches.Success) {
                            $uptimeOffset = [double]$foundMatches.Groups[1].Value
                            if ($null -ne $bootTime) {
                                $parsedDate = $bootTime.AddSeconds($uptimeOffset)
                            }
                            $parsedPid = [int]$foundMatches.Groups[2].Value
                            $parsedProcessName = $foundMatches.Groups[3].Value
                            $totalVm = $foundMatches.Groups[4].Value
                            $anonRss = $foundMatches.Groups[5].Value
                            $oomScoreAdj = [int]$foundMatches.Groups[6].Value
                            $parsedSuccessfully = $true
                        }
                    }

                    $displayDate = if ($parsedDate -eq [datetime]::MinValue) { $null } else { $parsedDate }

                    if ($parsedSuccessfully) {
                        $obj = [PSCustomObject]@{
                            Timestamp    = $displayDate
                            PID          = $parsedPid
                            ProcessName  = $parsedProcessName
                            TotalVM      = $totalVm
                            TotalVMBytes = (ConvertTo-Bytes $totalVm)
                            AnonRSS      = $anonRss
                            AnonRSSBytes = (ConvertTo-Bytes $anonRss)
                            OOMScoreAdj  = $oomScoreAdj
                            Source       = $sourceUsed
                            RawMessage   = $line.Trim()
                        }
                        $script:allEvents += $obj
                    }
                    else {
                        if ($line -match '^(\S+)\s+\S+\s+kernel:') {
                            $tempMatches = [regex]::Match($line, '^(\S+)')
                            if ($tempMatches.Success) {
                                [DateTime]::TryParse($tempMatches.Groups[1].Value, [ref]$parsedDate) | Out-Null
                            }
                        }
                        
                        $displayDate = if ($parsedDate -eq [datetime]::MinValue) { $null } else { $parsedDate }
                        $obj = [PSCustomObject]@{
                            Timestamp    = $displayDate
                            PID          = $null
                            ProcessName  = $null
                            TotalVM      = $null
                            TotalVMBytes = $null
                            AnonRSS      = $null
                            AnonRSSBytes = $null
                            OOMScoreAdj  = $null
                            Source       = $sourceUsed
                            RawMessage   = $line.Trim()
                        }
                        $script:allEvents += $obj
                    }
                }
            }
        }

        # Initialize list to collect matched events across pipeline iterations
        $script:accumulatedEvents = [System.Collections.Generic.List[System.Object]]::new()
    }

    process {
        if (-not $IsLinux) { return }

        $filtered = $script:allEvents
        $hasFilters = $false

        # Apply process name filter if specified (handles arrays)
        if ($null -ne $ProcessName -and $ProcessName.Count -gt 0) {
            if ($Raw) {
                # For raw strings, filter by simple match
                $filtered = $filtered | Where-Object {
                    $currLine = $_
                    $matchFound = $false
                    foreach ($name in $ProcessName) {
                        if ($currLine -like "*($name)*" -or $currLine -like "* $name *") {
                            $matchFound = $true
                            break
                        }
                    }
                    $matchFound
                }
            } else {
                $filtered = $filtered | Where-Object { $_.ProcessName -in $ProcessName }
            }
            $hasFilters = $true
        }

        # Apply PID filter if specified
        if ($null -ne $ProcessId -and $ProcessId.Count -gt 0) {
            if ($Raw) {
                $filtered = $filtered | Where-Object {
                    $currLine = $_
                    $matchFound = $false
                    foreach ($id in $ProcessId) {
                        if ($currLine -like "*process $id *") {
                            $matchFound = $true
                            break
                        }
                    }
                    $matchFound
                }
            } else {
                $filtered = $filtered | Where-Object { $_.PID -in $ProcessId }
            }
            $hasFilters = $true
        }

        # Add matching items to the final list, preventing duplicates
        if ($hasFilters) {
            foreach ($item in $filtered) {
                if (-not $script:accumulatedEvents.Contains($item)) {
                    $script:accumulatedEvents.Add($item)
                }
            }
        }
        else {
            # Standard run (no pipeline filters), accumulate everything
            foreach ($item in $script:allEvents) {
                $script:accumulatedEvents.Add($item)
            }
        }
    }

    end {
        if (-not $IsLinux) { return }

        $outputList = $script:accumulatedEvents

        # Apply Limit if specified
        if ($Limit -gt 0 -and $outputList.Count -gt $Limit) {
            $outputList = $outputList[-$Limit..-1]
        }

        # Output objects downstream sequentially to the pipeline
        foreach ($event in $outputList) {
            Write-Output $event
        }
    }
}

Export-ModuleMember -Function 'Get-OomKillerHistory'
