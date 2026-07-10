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
                    if ($null -ne $property.Value -and ($property.Value -is [string] -or $property.Value -is [System.ValueType])) {
                        $name = $property.Name
                        $val = [string]$property.Value
                        
                        # Resolve path values ending in 'Path'
                        if ($name -like "*Path") {
                            # Normalize directory separators
                            if ($IsWindows) {
                                $val = $val -replace '/', '\'
                            } else {
                                $val = $val -replace '\\', '/'
                            }
                            # Check if the path is already rooted (absolute)
                            $isRooted = $val.StartsWith('/') -or $val.StartsWith('~') -or ($val -match '^[a-zA-Z]:')
                            if (-not $isRooted) {
                                $val = Join-Path $PSScriptRoot $val
                            }
                        }

                        [System.Environment]::SetEnvironmentVariable($name, $val, [System.EnvironmentVariableTarget]::Process)
                        Write-Host "    ✨ [ENV] $name = $val" -ForegroundColor DarkGreen
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


