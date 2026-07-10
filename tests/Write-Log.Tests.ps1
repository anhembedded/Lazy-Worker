# Requires Pester
Describe 'Write-Log function' {
    It 'Is exported by the module' {
        Import-Module -Force -Name "$PSScriptRoot/../LazyWorker.psd1" -ErrorAction Stop
        $cmd = Get-Command -Name Write-Log -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
        $cmd.CommandType | Should -Be 'Function'
    }

    It 'Writes formatted message to log file when -WriteLogToFile is used' {
        Import-Module -Force -Name "$PSScriptRoot/../LazyWorker.psd1" -ErrorAction Stop
        $moduleRoot = Split-Path -Path (Get-Module LazyWorker).Path -Parent
        $logFile = Join-Path $moduleRoot "Logs/LazyWorker.log"
        if (Test-Path $logFile) { Remove-Item $logFile -Force }

        # Call Write-Log to write to file
        & { Write-Log -Message 'Test message' -Level Info -WriteLogToFile }

        Test-Path $logFile | Should -BeTrue
        $content = Get-Content -Path $logFile -ErrorAction Stop | Out-String
        $content | Should -Match 'Test message'

        # cleanup
        if (Test-Path $logFile) { Remove-Item $logFile -Force }
    }

    It 'Falls back to Logs folder when LogPath is empty' {
        Import-Module -Force -Name "$PSScriptRoot/../LazyWorker.psd1" -ErrorAction Stop
        $tempFolder = Join-Path $PSScriptRoot 'tempLogs'
        if (Test-Path $tempFolder) { Remove-Item -Recurse -Force $tempFolder }
        & { Write-Log -Message 'fallback test' -Level Info -LogPath '' -WriteLogToFile }
        $moduleRoot = Split-Path -Path (Get-Module LazyWorker).Path -Parent
        $fallbackLog = Join-Path $moduleRoot "Logs/LazyWorker.log"
        Test-Path $fallbackLog | Should -BeTrue
        # cleanup
        if (Test-Path $fallbackLog) { Remove-Item $fallbackLog -Force }
    }
}
