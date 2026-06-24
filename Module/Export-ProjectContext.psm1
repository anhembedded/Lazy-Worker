<#
.SYNOPSIS
    Exports source files from a project directory into a single, AI/LLM-friendly
    context file with a directory tree and Markdown code blocks.
.DESCRIPTION
    Export-ProjectContext scans a project directory for files matching a glob
    pattern (default *.py), generates a text-based folder tree, then concatenates
    each file's content wrapped in Markdown headers and fenced code blocks.

    Heavy/non-code directories (__pycache__, .git, .venv, .idea, node_modules,
    .vs, bin, obj, dist, build, .tox, .mypy_cache, .pytest_cache, .eggs,
    __pypackages__) are automatically excluded. Binary files are detected and
    skipped.

    Consecutive empty lines (>2) are compressed to a single blank line to
    optimise tokens for AI context windows.
.PARAMETER Path
    The root directory of the project to scan.
.PARAMETER OutputPath
    The full path of the output text file to create.
.PARAMETER Pattern
    Glob pattern for file extensions to include. Default is "*.py".
.PARAMETER Recurse
    Process subdirectories recursively.
.PARAMETER PrintToTerminal
    Stream output to the host console as it is written.
.EXAMPLE
    Export-ProjectContext -Path "C:\Projects\MyApp" -OutputPath "C:\context.txt" -Recurse
.EXAMPLE
    Export-ProjectContext -Path ./src -OutputPath ./context.md -Pattern "*.ps1" -Recurse -PrintToTerminal
#>
function Export-ProjectContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter(Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$Pattern = '*.py',

        [Parameter()]
        [switch]$Recurse,

        [Parameter()]
        [switch]$PrintToTerminal
    )

    begin {
        # ── Directories to always exclude ────────────────────────────────
        $excludedDirs = @(
            '__pycache__', '.git', '.venv', 'venv', '.idea', 'node_modules',
            '.vs', 'bin', 'obj', 'dist', 'build', '.tox', '.mypy_cache',
            '.pytest_cache', '.eggs', '__pypackages__', '.next', '.nuxt',
            'coverage', '.terraform', '.serverless'
        )

        # ── Map common extensions → Markdown language identifiers ────────
        $langMap = @{
            '.py'    = 'python'
            '.ps1'   = 'powershell'
            '.psm1'  = 'powershell'
            '.psd1'  = 'powershell'
            '.js'    = 'javascript'
            '.ts'    = 'typescript'
            '.jsx'   = 'jsx'
            '.tsx'   = 'tsx'
            '.cs'    = 'csharp'
            '.java'  = 'java'
            '.go'    = 'go'
            '.rs'    = 'rust'
            '.rb'    = 'ruby'
            '.php'   = 'php'
            '.c'     = 'c'
            '.cpp'   = 'cpp'
            '.h'     = 'c'
            '.hpp'   = 'cpp'
            '.sh'    = 'bash'
            '.bash'  = 'bash'
            '.zsh'   = 'bash'
            '.yaml'  = 'yaml'
            '.yml'   = 'yaml'
            '.json'  = 'json'
            '.xml'   = 'xml'
            '.html'  = 'html'
            '.css'   = 'css'
            '.scss'  = 'scss'
            '.sql'   = 'sql'
            '.md'    = 'markdown'
            '.tf'    = 'hcl'
            '.toml'  = 'toml'
            '.ini'   = 'ini'
            '.cfg'   = 'ini'
            '.dockerfile' = 'dockerfile'
            '.r'     = 'r'
            '.lua'   = 'lua'
            '.kt'    = 'kotlin'
            '.swift' = 'swift'
            '.dart'  = 'dart'
        }

        # ── Helper: detect binary content ────────────────────────────────
        function Test-BinaryFile {
            param([string]$FilePath)
            try {
                $bytes = [System.IO.File]::ReadAllBytes($FilePath)
                # Empty files are not binary
                if ($bytes.Length -eq 0) { return $false }
                # Sample first 8KB for null bytes (classic binary indicator)
                $sampleSize = [Math]::Min($bytes.Length, 8192)
                for ($i = 0; $i -lt $sampleSize; $i++) {
                    if ($bytes[$i] -eq 0) { return $true }
                }
                return $false
            }
            catch {
                return $true  # If unreadable, treat as binary
            }
        }

        # ── Helper: compress consecutive empty lines ─────────────────────
        function Compress-EmptyLines {
            param([string]$Text)
            # Replace 3+ consecutive blank lines (allowing whitespace-only) with one blank line
            $compressedText = [regex]::Replace($Text, '(\r?\n\s*){3,}', [Environment]::NewLine + [Environment]::NewLine)
            return $compressedText
        }

        # ── Helper: build ASCII tree string ──────────────────────────────
        function Build-TreeString {
            param(
                [string]$RootPath,
                [System.IO.FileInfo[]]$Files
            )

            $rootName = Split-Path -Leaf $RootPath
            $treeLines = [System.Collections.Generic.List[string]]::new()
            $treeLines.Add($rootName)

            # Build a sorted set of relative directory+file paths
            $relativePaths = @()
            foreach ($file in $Files) {
                $relPath = $file.FullName.Substring($RootPath.Length).TrimStart([IO.Path]::DirectorySeparatorChar, '/', '\')
                $relativePaths += $relPath
            }
            $relativePaths = $relativePaths | Sort-Object

            # Group by parent directory for tree rendering
            $dirTree = [System.Collections.Specialized.OrderedDictionary]::new()
            foreach ($relPath in $relativePaths) {
                $parts = $relPath -split '[/\\]'
                $current = $dirTree
                for ($i = 0; $i -lt $parts.Count; $i++) {
                    $part = $parts[$i]
                    if ($i -eq ($parts.Count - 1)) {
                        # Leaf file
                        if (-not $current.Contains($part)) {
                            $current[$part] = $null
                        }
                    }
                    else {
                        # Directory node
                        if (-not $current.Contains($part)) {
                            $current[$part] = [System.Collections.Specialized.OrderedDictionary]::new()
                        }
                        $current = $current[$part]
                    }
                }
            }

            # Recursive renderer
            function Render-Tree {
                param(
                    [System.Collections.Specialized.OrderedDictionary]$Node,
                    [string]$Prefix
                )
                $keys = @($Node.Keys)
                for ($idx = 0; $idx -lt $keys.Count; $idx++) {
                    $key = $keys[$idx]
                    $isLast = ($idx -eq ($keys.Count - 1))
                    $connector = if ($isLast) { '└── ' } else { '├── ' }
                    $treeLines.Add("${Prefix}${connector}${key}")

                    if ($null -ne $Node[$key] -and $Node[$key] -is [System.Collections.Specialized.OrderedDictionary]) {
                        $extension = if ($isLast) { '    ' } else { '│   ' }
                        Render-Tree -Node $Node[$key] -Prefix "${Prefix}${extension}"
                    }
                }
            }

            Render-Tree -Node $dirTree -Prefix ''
            return ($treeLines -join [Environment]::NewLine)
        }
    }

    process {
        # ── Validate root path ───────────────────────────────────────────
        if (-not (Test-Path -Path $Path -PathType Container)) {
            $errMsg = "The path '$Path' does not exist or is not a directory."
            Write-Log -Message $errMsg -Level Error
            throw [System.IO.DirectoryNotFoundException]::new($errMsg)
        }

        $resolvedRoot = (Resolve-Path -Path $Path -ErrorAction Stop).Path

        # ── Validate output directory exists ─────────────────────────────
        $outputDir = Split-Path -Path $OutputPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path -Path $outputDir -PathType Container)) {
            try {
                New-Item -ItemType Directory -Path $outputDir -Force -ErrorAction Stop | Out-Null
                Write-Log -Message "Created output directory: $outputDir" -Level Info
            }
            catch {
                $errMsg = "Failed to create output directory '$outputDir': $_"
                Write-Log -Message $errMsg -Level Error
                throw
            }
        }

        # ── Collect files ────────────────────────────────────────────────
        Write-Log -Message "Scanning '$resolvedRoot' for '$Pattern' files (Recurse=$Recurse)..." -Level Info

        $gciParams = @{
            Path    = $resolvedRoot
            Filter  = $Pattern
            File    = $true
            ErrorAction = 'SilentlyContinue'
        }
        if ($Recurse) {
            $gciParams.Recurse = $true
        }

        $allFiles = @(Get-ChildItem @gciParams)

        # ── Filter out excluded directories ──────────────────────────────
        $filteredFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
        foreach ($file in $allFiles) {
            $skip = $false
            $pathParts = $file.FullName.Substring($resolvedRoot.Length) -split '[/\\]'
            foreach ($part in $pathParts) {
                if ($excludedDirs -contains $part) {
                    $skip = $true
                    break
                }
            }
            if (-not $skip) {
                $filteredFiles.Add($file)
            }
        }

        if ($filteredFiles.Count -eq 0) {
            Write-Log -Message "No files matched pattern '$Pattern' under '$resolvedRoot'." -Level Warning
            return
        }

        Write-Log -Message "Found $($filteredFiles.Count) file(s) after exclusions." -Level Info

        # ── Build output ─────────────────────────────────────────────────
        $sb = [System.Text.StringBuilder]::new(1MB)

        # METADATA: project tree
        [void]$sb.AppendLine('# PROJECT CONTEXT')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("**Root:** ``$resolvedRoot``")
        [void]$sb.AppendLine("**Pattern:** ``$Pattern``")
        [void]$sb.AppendLine("**Files:** $($filteredFiles.Count)")
        [void]$sb.AppendLine("**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('## Directory Tree')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('```')
        $treeString = Build-TreeString -RootPath $resolvedRoot -Files $filteredFiles
        [void]$sb.AppendLine($treeString)
        [void]$sb.AppendLine('```')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('---')
        [void]$sb.AppendLine()

        # ── Append each file ─────────────────────────────────────────────
        $processedCount = 0
        $skippedBinary  = 0

        foreach ($file in ($filteredFiles | Sort-Object FullName)) {
            $relativePath = $file.FullName.Substring($resolvedRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar, '/', '\')

            # Skip binary files
            if (Test-BinaryFile -FilePath $file.FullName) {
                Write-Log -Message "Skipped binary file: $relativePath" -Level Debug
                $skippedBinary++
                continue
            }

            # Determine language tag for fenced code block
            $ext = $file.Extension.ToLower()
            $lang = if ($langMap.ContainsKey($ext)) { $langMap[$ext] } else { '' }

            # Handle special filename-based detection (Dockerfile, Makefile, etc.)
            if ([string]::IsNullOrEmpty($lang)) {
                $baseName = $file.Name.ToLower()
                if ($baseName -eq 'dockerfile')  { $lang = 'dockerfile' }
                elseif ($baseName -eq 'makefile') { $lang = 'makefile' }
                elseif ($baseName -eq 'jenkinsfile') { $lang = 'groovy' }
            }

            try {
                $rawContent = [System.IO.File]::ReadAllText($file.FullName)
                $compressedContent = Compress-EmptyLines -Text $rawContent

                # Markdown header + fenced code block
                [void]$sb.AppendLine("# FILE: $relativePath")
                [void]$sb.AppendLine()
                [void]$sb.AppendLine("``````$lang")
                [void]$sb.Append($compressedContent)
                # Ensure content ends with newline before closing fence
                if (-not $compressedContent.EndsWith([Environment]::NewLine) -and -not $compressedContent.EndsWith("`n")) {
                    [void]$sb.AppendLine()
                }
                [void]$sb.AppendLine('``````')
                [void]$sb.AppendLine()

                $processedCount++

                if ($PrintToTerminal) {
                    Write-Host "  ✓ $relativePath" -ForegroundColor Green
                }
            }
            catch {
                Write-Log -Message "Failed to read '$relativePath': $_" -Level Warning
                if ($PrintToTerminal) {
                    Write-Host "  ✗ $relativePath (read error)" -ForegroundColor Red
                }
            }
        }

        # ── Write output file ────────────────────────────────────────────
        try {
            [System.IO.File]::WriteAllText($OutputPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
            Write-Log -Message "Context exported to '$OutputPath' ($processedCount files, $skippedBinary binary skipped)." -Level Info
        }
        catch {
            $errMsg = "Failed to write output file '$OutputPath': $_"
            Write-Log -Message $errMsg -Level Error
            throw
        }

        if ($PrintToTerminal) {
            Write-Host ''
            Write-Host "── Summary ──────────────────────────────────────" -ForegroundColor Cyan
            Write-Host "  Files processed : $processedCount" -ForegroundColor Gray
            Write-Host "  Binary skipped  : $skippedBinary" -ForegroundColor Gray
            Write-Host "  Output          : $OutputPath" -ForegroundColor Gray
            $fileSizeKB = [Math]::Round((Get-Item $OutputPath).Length / 1KB, 1)
            Write-Host "  Size            : ${fileSizeKB} KB" -ForegroundColor Gray
            Write-Host "─────────────────────────────────────────────────" -ForegroundColor Cyan
        }
    }
}

Export-ModuleMember -Function 'Export-ProjectContext'
