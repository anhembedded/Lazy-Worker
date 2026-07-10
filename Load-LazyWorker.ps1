Write-Host @"
  _                     __        __         _             
 | |    __ _ _____   _  \ \      / /__  _ __| | _____ _ __ 
 | |   / _` |_  / | | |  \ \ /\ / / _ \| '__| |/ / _ \ '__|
 | |__| (_| |/ /| |_| |   \ V  V / (_) | |  |   <  __/ |   
 |_____\__,_/___|\__, |    \_/\_/ \___/|_|  |_|\_\___|_|   
                 |___/                                     
"@ -ForegroundColor Magenta

# 1. Load configuration from all JSON files in the Environment folder and set environment variables
$envFolder = Join-Path $PSScriptRoot "Environment"
if (Test-Path $envFolder) {
    $jsonFiles = Get-ChildItem -Path "$envFolder\*.json" -File
    Write-Host "🚀 Loading environment variables from $envFolder..." -ForegroundColor Cyan
    foreach ($file in $jsonFiles) {
        try {
            $config = Get-Content $file.FullName -Raw | ConvertFrom-Json
            if ($config) {
                Write-Host "  📄 File: $($file.Name)" -ForegroundColor Gray
                foreach ($property in $config.PSObject.Properties) {
                    $name = $property.Name
                    $rawVal = $property.Value
                    if ($null -ne $rawVal -and ($rawVal -is [string] -or $rawVal -is [System.ValueType])) {
                        # Use a string form for environment variables
                        $envVal = [string]$rawVal

                        # Resolve path values ending in 'Path'
                        if ($name -like "*Path" -and $envVal) {
                            # Normalize directory separators
                            if ($IsWindows) {
                                $envVal = $envVal -replace '/', '\\'
                            } else {
                                $envVal = $envVal -replace '\\', '/'
                            }
                            # Check if the path is already rooted (absolute)
                            $isRooted = $envVal.StartsWith('/') -or $envVal.StartsWith('~') -or ($envVal -match '^[a-zA-Z]:')
                            if (-not $isRooted) {
                                $envVal = Join-Path $PSScriptRoot $envVal
                            }
                        }

                        # Set process environment variable (string)
                        [System.Environment]::SetEnvironmentVariable($name, $envVal, [System.EnvironmentVariableTarget]::Process)

                        # Also create a PowerShell variable so users can access e.g. $MyName
                        # Preserve typed value when possible; for strings use the normalized envVal
                        if ($rawVal -isnot [string]) {
                            $psValue = $rawVal
                        } else {
                            $psValue = $envVal
                        }
                        Set-Variable -Name $name -Value $psValue -Scope Global -Force

                        Write-Host "    ✨ [ENV] $name = $envVal" -ForegroundColor DarkGreen
                    }
                }
            }
        }
        catch {
            Write-Warning "⚠️ Failed to load environment variables from $($file.Name). Details: $_"
        }
    }
}


# 2. Load the module
$manifestPath = Join-Path $PSScriptRoot "LazyWorker.psd1"
Write-Host "`n📦 Loading LazyWorker module from $manifestPath..." -ForegroundColor Cyan
try {
    Import-Module $manifestPath -Force -ErrorAction Stop
    Write-Host "✅ Module loaded successfully!" -ForegroundColor Green
    Write-Host "🛠️  Available Commands:" -ForegroundColor Cyan
    Get-Command -Module LazyWorker
}
catch {
    Write-Error "Failed to load LazyWorker module. Details: $_"
}


