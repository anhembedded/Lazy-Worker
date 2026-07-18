Describe 'Clear-ProjectTraces function' {
    BeforeAll {
        Import-Module -Force -Name "$PSScriptRoot/../LazyWorker.psd1" -ErrorAction Stop
    }

    It 'Is exported by the module' {
        $cmd = Get-Command -Name Clear-ProjectTraces -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
        $cmd.CommandType | Should -Be 'Function'
    }

    Context 'Cleaning project traces' {
        BeforeAll {
            $tempPath = Join-Path $PSScriptRoot "TempCleanupFolder"
        }

        BeforeEach {
            if (Test-Path $tempPath) {
                Remove-Item -Path $tempPath -Recurse -Force | Out-Null
            }
            New-Item -ItemType Directory -Path $tempPath | Out-Null
            
            # Create standard trace dirs and files
            $dirsToCreate = @("bin", "obj", "node_modules", "__pycache__", ".vs", "src")
            foreach ($dir in $dirsToCreate) {
                New-Item -ItemType Directory -Path (Join-Path $tempPath $dir) -Force | Out-Null
            }
            
            # Create some fake files inside
            "fake content" | Out-File -FilePath (Join-Path $tempPath "bin/app.dll") -Force
            "fake content" | Out-File -FilePath (Join-Path $tempPath "src/index.js") -Force
        }

        AfterEach {
            if (Test-Path $tempPath) {
                Remove-Item -Path $tempPath -Recurse -Force | Out-Null
            }
        }

        It 'Removes default build and cache directories but preserves source directories' {
            # Execute clear
            Clear-ProjectTraces -Path $tempPath -Force

            # Check trace dirs deleted
            Test-Path -Path (Join-Path $tempPath "bin") | Should -BeFalse
            Test-Path -Path (Join-Path $tempPath "obj") | Should -BeFalse
            Test-Path -Path (Join-Path $tempPath "node_modules") | Should -BeFalse
            Test-Path -Path (Join-Path $tempPath "__pycache__") | Should -BeFalse
            Test-Path -Path (Join-Path $tempPath ".vs") | Should -BeFalse

            # Check source dir is preserved
            Test-Path -Path (Join-Path $tempPath "src") | Should -BeTrue
            Test-Path -Path (Join-Path $tempPath "src/index.js") | Should -BeTrue
        }

        It 'Removes custom patterns when specified' {
            # Create a custom directory
            New-Item -ItemType Directory -Path (Join-Path $tempPath "customTempDir") -Force | Out-Null

            Clear-ProjectTraces -Path $tempPath -CustomPatterns @("customTempDir") -Force

            # Check custom temp dir deleted
            Test-Path -Path (Join-Path $tempPath "customTempDir") | Should -BeFalse
        }
    }
}
