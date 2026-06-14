<#
.SYNOPSIS
    Search-String searches files for occurrences of a given pattern.
.DESCRIPTION
    A utility function that finds lines matching a specified pattern in one or more files.
    Supports both file paths and directory paths, and optional recursive scanning.
.PARAMETER Path
    The path to the file or directory to search. Can be a pipeline input.
.PARAMETER Pattern
    The string or regular expression pattern to search for.
.PARAMETER Recursive
    Switch to search recursively if the path is a directory.
.EXAMPLE
    Search-String -Path . -Pattern "TODO" -Recursive
#>
function Search-String {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [string]$Path,

        [Parameter(Mandatory = $true, Position = 1)]
        [Alias('partern')]
        [string]$Pattern,

        [Parameter()]
        [Alias('recusive')]
        [switch]$Recursive
    )

    process {
        # Check if path exists
        if (-not (Test-Path -Path $Path)) {
            Write-Error "The path '$Path' does not exist."
            return
        }

        # Resolve path to absolute format
        $resolvedPath = Resolve-Path -Path $Path -ErrorAction Stop
        
        # If it's a directory, scan files. Otherwise, scan the file directly.
        if (Test-Path -Path $resolvedPath -PathType Container) {
            $gciParams = @{
                Path = $resolvedPath
                File = $true
            }
            if ($Recursive) {
                $gciParams.Recurse = $true
            }
            $files = Get-ChildItem @gciParams
        } else {
            $files = Get-Item -Path $resolvedPath
        }

        # Search within the resolved files
        foreach ($file in $files) {
            try {
                # Use Select-String to find matching lines and return MatchInfo objects directly
                Select-String -Path $file.FullName -Pattern $Pattern -ErrorAction SilentlyContinue
            }
            catch {
                Write-Warning "Could not search file: $($file.FullName). Details: $_"
            }
        }
    }
}


Export-ModuleMember -Function 'Search-String'