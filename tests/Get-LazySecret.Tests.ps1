Describe 'LazySecret functions' {
    BeforeAll {
        Import-Module -Force -Name "$PSScriptRoot/../LazyWorker.psd1" -ErrorAction Stop
    }

    It 'Are exported by the module' {
        Get-Command -Name Set-LazySecret -ErrorAction SilentlyContinue | Should -Not -Be $null
        Get-Command -Name Get-LazySecret -ErrorAction SilentlyContinue | Should -Not -Be $null
        Get-Command -Name Remove-LazySecret -ErrorAction SilentlyContinue | Should -Not -Be $null
    }

    Context 'Secret Management Operations' {
        BeforeAll {
            $testTarget = "LazyWorkerTestSecret_123"
            $testUser = "testUser@lazyworker.com"
            $testPassword = "SuperSecretPassword123!"
        }

        AfterEach {
            Remove-LazySecret -Target $testTarget | Out-Null
        }

        It 'Saves, retrieves, and removes secrets successfully' {
            # 1. Save secret
            Set-LazySecret -Target $testTarget -UserName $testUser -Password $testPassword

            # 2. Retrieve secret and verify properties
            $secret = Get-LazySecret -Target $testTarget
            $secret | Should -Not -BeNullOrEmpty
            $secret.Target | Should -Be $testTarget
            $secret.UserName | Should -Be $testUser
            $secret.Password | Should -Be $testPassword

            # 3. Remove secret
            Remove-LazySecret -Target $testTarget

            # 4. Verify secret is gone
            $emptySecret = Get-LazySecret -Target $testTarget
            $emptySecret | Should -BeNull
        }
    }
}
