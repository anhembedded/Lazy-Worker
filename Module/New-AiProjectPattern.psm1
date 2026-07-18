function New-AiProjectPattern {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Path = ".",

        [Parameter()]
        [switch]$Force
    )

    process {
        Write-Log -Message "Initializing AI project directory structure at '$Path'..." -Level Info -WriteLogToFile

        # Resolve path to absolute path
        try {
            if ([System.IO.Path]::IsPathRooted($Path)) {
                $absolutePath = [System.IO.Path]::GetFullPath($Path)
            }
            else {
                $absolutePath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
            }
        }
        catch {
            Write-Log -Message "Failed to resolve path: $_" -Level Error -WriteLogToFile
            throw
        }

        # Define template source directory
        $templateSourceDir = Join-Path $PSScriptRoot "New-AiProjectPattern-Template\.ai"
        if (-not (Test-Path -Path $templateSourceDir)) {
            $errorMsg = "Template source directory not found at '$templateSourceDir'."
            Write-Log -Message $errorMsg -Level Error -WriteLogToFile
            throw $errorMsg
        }

        # Get all files recursively under templateSourceDir
        try {
            $templateFiles = Get-ChildItem -Path $templateSourceDir -Recurse -File -ErrorAction Stop
        }
        catch {
            Write-Log -Message "Failed to read template directory: $_" -Level Error -WriteLogToFile
            throw
        }

        # Copy files
        foreach ($file in $templateFiles) {
            # Compute relative path of the file from templateSourceDir
            $relativeSubPath = $file.FullName.Substring($templateSourceDir.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar)
            
            # Destination path under target directory .ai/
            $targetFilePath = Join-Path $absolutePath ".ai\$relativeSubPath"

            # Ensure parent directory exists
            $parentDir = Split-Path $targetFilePath -Parent
            if (-not (Test-Path -Path $parentDir)) {
                try {
                    New-Item -ItemType Directory -Path $parentDir -Force -ErrorAction Stop | Out-Null
                    Write-Log -Message "Created directory: '$parentDir'" -Level Info -WriteLogToFile
                }
                catch {
                    Write-Log -Message "Failed to create directory '$parentDir': $_" -Level Error -WriteLogToFile
                    throw
                }
            }

            # Copy file
            $fileExists = Test-Path -Path $targetFilePath
            if ($fileExists -and -not $Force) {
                Write-Log -Message "File already exists. Skipping: '$targetFilePath'" -Level Warning -WriteLogToFile
            }
            else {
                try {
                    Copy-Item -Path $file.FullName -Destination $targetFilePath -Force -ErrorAction Stop
                    $action = if ($fileExists) { "Overwrote" } else { "Created" }
                    Write-Log -Message "$action file: '$targetFilePath'" -Level Info -WriteLogToFile
                }
                catch {
                    Write-Log -Message "Failed to copy file from '$($file.FullName)' to '$targetFilePath': $_" -Level Error -WriteLogToFile
                    throw
                }
            }
        }

        Write-Log -Message "AI project directory structure initialized successfully at '$absolutePath'." -Level Info -WriteLogToFile
    }
}

Export-ModuleMember -Function 'New-AiProjectPattern'
