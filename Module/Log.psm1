<#
.SYNOPSIS
    Writes messages to a centralized log file and console.
.DESCRIPTION
    A logging utility that other modules can call to append timestamped lines to a log file.
    The path to the log directory is read from the process-level environment variable $env:LogPath.
.PARAMETER Message
    The log message to write. Accepts pipeline input.
.PARAMETER Level
    The severity/importance of the log. Valid values: Info, Warning, Error, Debug, Trace. Default is Info.
.PARAMETER LogPath
    Optional directory path where the log file is saved. Defaults to $env:LogPath.
.PARAMETER WriteLogToFile
    Switch to force writing logs to a file.
.EXAMPLE
    Write-Log -Message "Starting scan..." -Level Info -WriteLogToFile
#>
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Trace')]
        [string]$Level = 'Info',

        [Parameter()]
        [string]$LogPath = $env:LogPath,

        [Parameter()]
        [switch]$WriteLogToFile
    )

    process {
        # Determine if we should write to file
        $shouldWrite = $WriteLogToFile.IsPresent
        if (-not $shouldWrite -and $null -ne $env:WriteLogToFile) {
            if ($env:WriteLogToFile -eq "true" -or $env:WriteLogToFile -eq "1") {
                $shouldWrite = $true
            }
        }

        # Format log line
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $paddedLevel = $Level.ToUpper().PadRight(7)
        $logLine = "$timestamp [$paddedLevel] $Message"

        if ($shouldWrite) {
            $fallbackUsed = $false
            if ([string]::IsNullOrWhiteSpace($LogPath)) {
                $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
                $LogPath = Join-Path $moduleRoot "Logs"
                $fallbackUsed = $true
            }

            try {
                # Ensure directory exists
                if (-not (Test-Path -Path $LogPath -ErrorAction Stop)) {
                    New-Item -ItemType Directory -Path $LogPath -Force -ErrorAction Stop | Out-Null
                }
                $logFile = Join-Path $LogPath "LazyWorker.log" -ErrorAction Stop
                $logLine | Out-File -FilePath $logFile -Append -Encoding utf8 -ErrorAction Stop
            }
            catch {
                if (-not $fallbackUsed) {
                    $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
                    $fallbackLogPath = Join-Path $moduleRoot "Logs"
                    try {
                        if (-not (Test-Path -Path $fallbackLogPath)) {
                            New-Item -ItemType Directory -Path $fallbackLogPath -Force | Out-Null
                        }
                        $logFile = Join-Path $fallbackLogPath "LazyWorker.log"
                        $logLine | Out-File -FilePath $logFile -Append -Encoding utf8
                    }
                    catch {
                        Write-Warning "Could not write to log file. Primary path ($LogPath) and fallback path ($fallbackLogPath) both failed. Details: $_"
                    }
                }
                else {
                    Write-Warning "Could not write to log file: $LogPath. Details: $_"
                }
            }
        }

        # Print to console (always runs) with color formatting
        # PS7+: ANSI escape codes | PS5.1: Write-Host -ForegroundColor
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $esc = [char]0x1b
            $colorReset     = "$esc[0m"
            $colorTimestamp = "$esc[90m"  # Dark Gray

            $colorLevel = switch ($Level) {
                'Error'   { "$esc[91m" }  # Bright Red
                'Warning' { "$esc[93m" }  # Bright Yellow
                'Debug'   { "$esc[90m" }  # Dark Gray
                'Trace'   { "$esc[36m" }  # Cyan
                'Info'    { "$esc[92m" }  # Bright Green
                default   { "$esc[37m" }  # White
            }
            $colorMessage = "$esc[37m"  # White

            $consoleLine = "${colorTimestamp}${timestamp}${colorReset} [${colorLevel}${paddedLevel}${colorReset}] ${colorMessage}${Message}${colorReset}"
            Write-Host $consoleLine
        }
        else {
            # PS5.1: dùng Write-Host -ForegroundColor vì không hỗ trợ ANSI
            $fgLevel = switch ($Level) {
                'Error'   { 'Red' }
                'Warning' { 'Yellow' }
                'Debug'   { 'DarkGray' }
                'Trace'   { 'Cyan' }
                'Info'    { 'Green' }
                default   { 'White' }
            }

            Write-Host $timestamp -ForegroundColor DarkGray -NoNewline
            Write-Host " [" -NoNewline
            Write-Host $paddedLevel -ForegroundColor $fgLevel -NoNewline
            Write-Host "] " -NoNewline
            Write-Host $Message -ForegroundColor White
        }
    }
}

Export-ModuleMember -Function 'Write-Log'
