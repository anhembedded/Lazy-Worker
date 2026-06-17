<#
.SYNOPSIS
    Gets a list of all installed font names on the system.
.DESCRIPTION
    Retrieves unique font names installed on the system. Supports Windows, Linux, and macOS.
.PARAMETER WriteLogToFile
    Switch to force writing logs to a file.
.EXAMPLE
    Get-AllFontName
#>
function Get-AllFontName {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$WriteLogToFile
    )

    process {
        Write-Log -Message "Starting Get-AllFontName..." -Level Info -WriteLogToFile:$WriteLogToFile

        $fontNames = [System.Collections.Generic.List[string]]::new()

        if ($IsWindows) {
            Write-Log -Message "Querying Windows registry for installed fonts..." -Level Debug -WriteLogToFile:$WriteLogToFile
            $regKeys = @(
                "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts",
                "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
            )
            foreach ($key in $regKeys) {
                if (Test-Path $key) {
                    $properties = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
                    if ($properties) {
                        $names = $properties.PSObject.Properties | Where-Object { 
                            $_.Name -notin @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider', 'RunspaceId') 
                        } | Select-Object -ExpandProperty Name
                        foreach ($name in $names) {
                            $cleanName = $name -replace '\s*\((TrueType|OpenType|PostScript|Type 1)\)\s*$', ''
                            [void]$fontNames.Add($cleanName)
                        }
                    }
                }
            }
        }
        elseif ($IsLinux) {
            if (Get-Command fc-list -ErrorAction SilentlyContinue) {
                Write-Log -Message "Using fc-list to retrieve installed fonts..." -Level Debug -WriteLogToFile:$WriteLogToFile
                $fcOutput = & fc-list : family
                foreach ($line in $fcOutput) {
                    if (-not [string]::IsNullOrWhiteSpace($line)) {
                        $parts = $line.Split(',')
                        foreach ($part in $parts) {
                            $trimmed = $part.Trim()
                            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                                [void]$fontNames.Add($trimmed)
                            }
                        }
                    }
                }
            }
            else {
                Write-Log -Message "fc-list not found. Scanning standard Linux font directories..." -Level Warning -WriteLogToFile:$WriteLogToFile
                $fontDirs = @(
                    "/usr/share/fonts",
                    "/usr/local/share/fonts",
                    "~/.local/share/fonts",
                    "~/.fonts"
                )
                foreach ($dir in $fontDirs) {
                    $resolvedDir = $dir
                    if ($dir -like "~*") {
                        $resolvedDir = $dir.Replace("~", $env:HOME)
                    }
                    if (Test-Path $resolvedDir) {
                        $files = Get-ChildItem -Path $resolvedDir -Recurse -Include *.ttf, *.otf, *.woff, *.woff2 -File -ErrorAction SilentlyContinue
                        foreach ($file in $files) {
                            [void]$fontNames.Add($file.BaseName)
                        }
                    }
                }
            }
        }
        elseif ($IsMacOS) {
            if (Get-Command fc-list -ErrorAction SilentlyContinue) {
                Write-Log -Message "Using fc-list to retrieve installed fonts on macOS..." -Level Debug -WriteLogToFile:$WriteLogToFile
                $fcOutput = & fc-list : family
                foreach ($line in $fcOutput) {
                    if (-not [string]::IsNullOrWhiteSpace($line)) {
                        $parts = $line.Split(',')
                        foreach ($part in $parts) {
                            $trimmed = $part.Trim()
                            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                                [void]$fontNames.Add($trimmed)
                            }
                        }
                    }
                }
            }
            else {
                Write-Log -Message "fc-list not found. Scanning standard macOS font directories..." -Level Warning -WriteLogToFile:$WriteLogToFile
                $fontDirs = @(
                    "/Library/Fonts",
                    "/System/Library/Fonts",
                    "~/Library/Fonts"
                )
                foreach ($dir in $fontDirs) {
                    $resolvedDir = $dir
                    if ($dir -like "~*") {
                        $resolvedDir = $dir.Replace("~", $env:HOME)
                    }
                    if (Test-Path $resolvedDir) {
                        $files = Get-ChildItem -Path $resolvedDir -Recurse -Include *.ttf, *.otf, *.woff, *.woff2 -File -ErrorAction SilentlyContinue
                        foreach ($file in $files) {
                            [void]$fontNames.Add($file.BaseName)
                        }
                    }
                }
            }
        }
        else {
            Write-Log -Message "Unsupported operating system for font listing." -Level Error -WriteLogToFile:$WriteLogToFile
        }

        $uniqueFonts = $fontNames | Sort-Object -Unique
        Write-Log -Message "Found $($uniqueFonts.Count) unique fonts installed." -Level Info -WriteLogToFile:$WriteLogToFile
        return $uniqueFonts
    }
}

Export-ModuleMember -Function 'Get-AllFontName'
