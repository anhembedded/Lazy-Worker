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
            # Fallback dynamic path if LogPath env is null or empty
            if ([string]::IsNullOrWhiteSpace($LogPath)) {
                # $PSScriptRoot inside Module/Log.psm1 is C:\...\Lazy-Worker\Module
                # Split-Path gets the parent C:\...\Lazy-Worker
                $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
                $LogPath = Join-Path $moduleRoot "Logs"
            }

            # Ensure directory exists
            if (-not (Test-Path -Path $LogPath)) {
                try {
                    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
                }
                catch {
                    Write-Warning "Could not create log directory: $LogPath. Details: $_"
                }
            }

            $logFile = Join-Path $LogPath "LazyWorker.log"
            # Write to log file
            try {
                $logLine | Out-File -FilePath $logFile -Append -Encoding utf8
            }
            catch {
                Write-Warning "Could not write to log file: $logFile. Details: $_"
            }
        }

        # Print to console (always runs)
        switch ($Level) {
            'Error'   { Write-Host $logLine -ForegroundColor Red }
            'Warning' { Write-Host $logLine -ForegroundColor Yellow }
            'Debug'   { Write-Host $logLine -ForegroundColor DarkGray }
            'Trace'   { Write-Host $logLine -ForegroundColor Cyan }
            default   { Write-Host $logLine -ForegroundColor Gray }
        }
    }
}

Export-ModuleMember -Function 'Write-Log'
