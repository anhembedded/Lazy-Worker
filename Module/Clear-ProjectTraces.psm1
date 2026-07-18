function Clear-ProjectTraces {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Path = ".",

        [Parameter()]
        [string[]]$CustomPatterns = @(),

        [Parameter()]
        [switch]$Force
    )

    process {
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

        if (-not (Test-Path -Path $absolutePath)) {
            $errorMsg = "Path does not exist: '$absolutePath'"
            Write-Log -Message $errorMsg -Level Error -WriteLogToFile
            throw $errorMsg
        }

        Write-Log -Message "Scanning for project traces under '$absolutePath'..." -Level Info -WriteLogToFile

        # Predefined patterns of directories/files to clear
        $defaultPatterns = @(
            "bin",
            "obj",
            "node_modules",
            "__pycache__",
            ".vs",
            "dist",
            "build",
            ".pytest_cache",
            ".venv",
            "venv",
            "out",
            "target",
            ".gradle",
            ".idea"
        )

        $allPatterns = $defaultPatterns + $CustomPatterns
        $clearedCount = 0

        # Efficient recursive scanner that skips traversing inside directories marked for deletion
        function Get-ItemsToDelete {
            param(
                [string]$currentPath,
                [string[]]$patterns
            )

            $results = @()
            $children = Get-ChildItem -Path $currentPath -Force -ErrorAction SilentlyContinue
            foreach ($child in $children) {
                if ($patterns -contains $child.Name) {
                    $results += $child
                }
                elseif ($child.PSIsContainer) {
                    $results += Get-ItemsToDelete -currentPath $child.FullName -patterns $patterns
                }
            }
            return $results
        }

        $itemsToDelete = Get-ItemsToDelete -currentPath $absolutePath -patterns $allPatterns

        # Perform deletion
        foreach ($item in $itemsToDelete) {
            # Skip if already deleted (e.g. nested matched folder under another matched folder)
            if (-not (Test-Path -Path $item.FullName)) {
                continue
            }

            $itemType = if ($item.PSIsContainer) { "Directory" } else { "File" }

            if ($PSCmdlet.ShouldProcess($item.FullName, "Delete $itemType")) {
                try {
                    if ($item.PSIsContainer) {
                        Remove-Item -Path $item.FullName -Recurse -Force:$Force -ErrorAction Stop
                    }
                    else {
                        Remove-Item -Path $item.FullName -Force:$Force -ErrorAction Stop
                    }
                    Write-Log -Message "Deleted ${itemType}: '$($item.FullName)'" -Level Info -WriteLogToFile
                    $clearedCount++
                }
                catch {
                    Write-Log -Message "Failed to delete $($item.FullName): $_" -Level Warning -WriteLogToFile
                }
            }
        }

        Write-Log -Message "Cleanup complete. Cleared $clearedCount items under '$absolutePath'." -Level Info -WriteLogToFile
    }
}

Export-ModuleMember -Function 'Clear-ProjectTraces'
