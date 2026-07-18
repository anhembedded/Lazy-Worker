Describe 'Export-ProjectContext - multiple paths' {
    It 'Exports context for multiple directories into a single file' {
        # Prepare two temp directories with small files
        $root = Join-Path $PSScriptRoot '..' | Resolve-Path | Select-Object -ExpandProperty Path
        $tmpA = Join-Path $root 'tests_tmp_a'
        $tmpB = Join-Path $root 'tests_tmp_b'
        if (Test-Path $tmpA) { Remove-Item -Recurse -Force $tmpA }
        if (Test-Path $tmpB) { Remove-Item -Recurse -Force $tmpB }
        New-Item -ItemType Directory -Path $tmpA -Force | Out-Null
        New-Item -ItemType Directory -Path $tmpB -Force | Out-Null
        Set-Content -Path (Join-Path $tmpA 'a.ps1') -Value "Write-Host 'A'" -Force
        Set-Content -Path (Join-Path $tmpB 'b.ps1') -Value "Write-Host 'B'" -Force

        $out = Join-Path $root 'tests_tmp_output.md'
        if (Test-Path $out) { Remove-Item $out -Force }

        Import-Module -Force -Name "$PSScriptRoot/../LazyWorker.psd1" -ErrorAction Stop
        Export-ProjectContext -Path $tmpA,$tmpB -OutputPath $out -Pattern '*.ps1' -Recurse

        Test-Path $out | Should -BeTrue
        $content = Get-Content -Path $out -Raw
        $content | Should -Match 'a.ps1'
        $content | Should -Match 'b.ps1'

        # cleanup
        if (Test-Path $tmpA) { Remove-Item -Recurse -Force $tmpA }
        if (Test-Path $tmpB) { Remove-Item -Recurse -Force $tmpB }
        if (Test-Path $out) { Remove-Item -Force $out }
    }

    It 'Handles special path values: ., .., and ~' {
        $root = Join-Path $PSScriptRoot '..' | Resolve-Path | Select-Object -ExpandProperty Path

        # Create test directories inside repo root
        $dirDot = Join-Path $root 'tests_dot'
        $dirDotDotParent = Join-Path $root 'tests_parent'
        if (Test-Path $dirDot) { Remove-Item -Recurse -Force $dirDot }
        if (Test-Path $dirDotDotParent) { Remove-Item -Recurse -Force $dirDotDotParent }
        New-Item -ItemType Directory -Path $dirDot -Force | Out-Null
        New-Item -ItemType Directory -Path $dirDotDotParent -Force | Out-Null

        # Place files
        Set-Content -Path (Join-Path $dirDot 'dot.ps1') -Value "Write-Host 'DOT'" -Force
        $child = Join-Path $dirDotDotParent 'child'
        New-Item -ItemType Directory -Path $child -Force | Out-Null
        Set-Content -Path (Join-Path $child 'dotdot.ps1') -Value "Write-Host 'DOTDOT'" -Force

        $out = Join-Path $root 'tests_tmp_output_special.md'
        if (Test-Path $out) { Remove-Item $out -Force }

        Import-Module -Force -Name "$PSScriptRoot/../LazyWorker.psd1" -ErrorAction Stop

        # 1) Use '.' for dirDot
        Push-Location $dirDot
        Export-ProjectContext -Path '.' -OutputPath $out -Pattern '*.ps1' -Recurse
        Pop-Location
        $content = Get-Content -Path $out -Raw
        $content | Should -Match 'dot.ps1'
        Remove-Item $out -Force

        # 2) Use '..' from child to reference parent
        Push-Location $child
        Export-ProjectContext -Path '..' -OutputPath $out -Pattern '*.ps1' -Recurse
        Pop-Location
        $content = Get-Content -Path $out -Raw
        $content | Should -Match 'dotdot.ps1'
        Remove-Item $out -Force

        # 3) Use ~ (home) — place a file in $HOME/tmp_home_test
        $homeTmp = Join-Path $HOME 'tmp_home_test'
        if (Test-Path $homeTmp) { Remove-Item -Recurse -Force $homeTmp }
        New-Item -ItemType Directory -Path $homeTmp -Force | Out-Null
        Set-Content -Path (Join-Path $homeTmp 'home.ps1') -Value "Write-Host 'HOME'" -Force

        Export-ProjectContext -Path '~\tmp_home_test' -OutputPath $out -Pattern '*.ps1' -Recurse
        $content = Get-Content -Path $out -Raw
        $content | Should -Match 'home.ps1'

        # cleanup
        if (Test-Path $dirDot) { Remove-Item -Recurse -Force $dirDot }
        if (Test-Path $dirDotDotParent) { Remove-Item -Recurse -Force $dirDotDotParent }
        if (Test-Path $homeTmp) { Remove-Item -Recurse -Force $homeTmp }
        if (Test-Path $out) { Remove-Item -Force $out }
    }

    It 'Only exports directory tree and metadata, skipping source code contents when -Tree is specified' {
        $root = Join-Path $PSScriptRoot '..' | Resolve-Path | Select-Object -ExpandProperty Path
        $tmp = Join-Path $root 'tests_tree_tmp'
        if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        Set-Content -Path (Join-Path $tmp 'test1.ps1') -Value "Write-Host 'Test 1 Content'" -Force
        Set-Content -Path (Join-Path $tmp 'test2.ps1') -Value "Write-Host 'Test 2 Content'" -Force

        $out = Join-Path $root 'tests_tmp_tree_output.md'
        if (Test-Path $out) { Remove-Item $out -Force }

        Import-Module -Force -Name "$PSScriptRoot/../LazyWorker.psd1" -ErrorAction Stop
        Export-ProjectContext -Path $tmp -OutputPath $out -Pattern '*.ps1' -Recurse -Tree

        Test-Path $out | Should -BeTrue
        $content = Get-Content -Path $out -Raw
        $content | Should -Match 'test1.ps1'
        $content | Should -Match 'test2.ps1'
        $content | Should -Not -Match 'Test 1 Content'
        $content | Should -Not -Match 'Test 2 Content'
        $content | Should -Not -Match 'FILE: test1.ps1'

        # cleanup
        if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
        if (Test-Path $out) { Remove-Item -Force $out }
    }

    It 'Handles OutputPath pointing to a directory (with trailing slash or existing folder)' {
        $root = Join-Path $PSScriptRoot '..' | Resolve-Path | Select-Object -ExpandProperty Path
        $tmp = Join-Path $root 'tests_dirpath_tmp'
        if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        Set-Content -Path (Join-Path $tmp 'test.ps1') -Value "Write-Host 'Hello'" -Force

        # Case 1: Trailing slash (directory does not exist yet)
        $outDir1 = Join-Path $root 'tests_out_dir1/'
        if (Test-Path $outDir1) { Remove-Item -Recurse -Force $outDir1 }
        
        Import-Module -Force -Name "$PSScriptRoot/../LazyWorker.psd1" -ErrorAction Stop
        Export-ProjectContext -Path $tmp -OutputPath $outDir1 -Pattern '*.ps1' -Recurse

        $expectedFile1 = Join-Path $outDir1 'context.md'
        Test-Path $expectedFile1 | Should -BeTrue
        (Get-Content -Path $expectedFile1 -Raw) | Should -Match 'test.ps1'

        # Case 2: Existing directory path without trailing slash
        $outDir2 = Join-Path $root 'tests_out_dir2'
        if (Test-Path $outDir2) { Remove-Item -Recurse -Force $outDir2 }
        New-Item -ItemType Directory -Path $outDir2 -Force | Out-Null

        Export-ProjectContext -Path $tmp -OutputPath $outDir2 -Pattern '*.ps1' -Recurse

        $expectedFile2 = Join-Path $outDir2 'context.md'
        Test-Path $expectedFile2 | Should -BeTrue
        (Get-Content -Path $expectedFile2 -Raw) | Should -Match 'test.ps1'

        # cleanup
        if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
        if (Test-Path $outDir1) { Remove-Item -Recurse -Force $outDir1 }
        if (Test-Path $outDir2) { Remove-Item -Recurse -Force $outDir2 }
    }
}
