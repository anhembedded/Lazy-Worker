# 1. Load configuration from all JSON files in the Environment folder and set environment variables
$envFolder = Join-Path $PSScriptRoot "Environment"
if (Test-Path $envFolder) {
    $jsonFiles = Get-ChildItem -Path "$envFolder\*.json" -File
    Write-Host "Loading environment variables from $envFolder..." -ForegroundColor Cyan
    foreach ($file in $jsonFiles) {
        try {
            $config = Get-Content $file.FullName -Raw | ConvertFrom-Json
            if ($config) {
                Write-Host "  File: $($file.Name)" -ForegroundColor Gray
                foreach ($property in $config.PSObject.Properties) {
                    if ($null -ne $property.Value -and ($property.Value -is [string] -or $property.Value -is [System.ValueType])) {
                        $name = $property.Name
                        $val = [string]$property.Value
                        [System.Environment]::SetEnvironmentVariable($name, $val, [System.EnvironmentVariableTarget]::Process)
                        Write-Host "    [ENV] $name = $val" -ForegroundColor DarkGreen
                    }
                }
            }
        }
        catch {
            Write-Warning "Failed to load environment variables from $($file.Name). Details: $_"
        }
    }
}


# 2. Load the module
$manifestPath = Join-Path $PSScriptRoot "LazyWorker.psd1"
Write-Host "Loading LazyWorker module from $manifestPath..." -ForegroundColor Cyan
Import-Module $manifestPath -Force
Write-Host "Module loaded successfully!" -ForegroundColor Green
Write-Host "Available Commands:" -ForegroundColor Cyan
Get-Command -Module LazyWorker
