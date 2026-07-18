Describe 'New-AiProjectPattern function' {
    BeforeAll {
        Import-Module -Force -Name "$PSScriptRoot/../LazyWorker.psd1" -ErrorAction Stop
    }

    It 'Is exported by the module' {
        $cmd = Get-Command -Name New-AiProjectPattern -ErrorAction SilentlyContinue
        $cmd | Should -Not -Be $null
        $cmd.CommandType | Should -Be 'Function'
    }

    Context 'Project directory structure initialization' {
        BeforeAll {
            $tempPath = Join-Path $PSScriptRoot "TempProjectPattern"
        }

        BeforeEach {
            if (Test-Path $tempPath) {
                Remove-Item -Path $tempPath -Recurse -Force | Out-Null
            }
            New-Item -ItemType Directory -Path $tempPath | Out-Null
        }

        AfterEach {
            if (Test-Path $tempPath) {
                Remove-Item -Path $tempPath -Recurse -Force | Out-Null
            }
        }

        It 'Creates all expected files and folders with default template contents' {
            New-AiProjectPattern -Path $tempPath

            # Check files
            $expectedFiles = @(
                ".ai/PLAYBOOK.md",
                ".ai/skills/implement-module.md",
                ".ai/skills/investigate-fix-bug.md",
                ".ai/skills/refactor.md",
                ".ai/skills/review-pr.md",
                ".ai/skills/optimize.md",
                ".ai/skills/write-doc.md",
                ".ai/skills/architecture.md",
                ".ai/rules/architecture.md",
                ".ai/rules/coding-style.md",
                ".ai/rules/testing.md",
                ".ai/rules/documentation.md",
                ".ai/rules/deployment.md",
                ".ai/prompts/feature.md",
                ".ai/prompts/bug.md",
                ".ai/prompts/review.md",
                ".ai/context/project.md",
                ".ai/context/architecture.md",
                ".ai/context/repository.md",
                ".ai/context/build.md",
                ".ai/context/testing.md",
                ".ai/context/documentation.md",
                ".ai/context/deployment.md",
                ".ai/context/dependencies.md",
                ".ai/context/runtime.md",
                ".ai/context/configuration.md",
                ".ai/context/api.md",
                ".ai/context/modules.md",
                ".ai/context/examples.md",
                ".ai/context/glossary.md",
                ".ai/context/troubleshooting.md"
            )

            foreach ($file in $expectedFiles) {
                $filePath = Join-Path $tempPath $file
                Test-Path -Path $filePath | Should -BeTrue
                $content = Get-Content -Path $filePath -Raw
                $content | Should -Not -BeNullOrEmpty
                # Basic check for Markdown heading
                $content | Should -Match '^#'
            }
        }

        It 'Does not overwrite existing files when -Force is omitted' {
            # 1. Initialize pattern first
            New-AiProjectPattern -Path $tempPath

            # 2. Modify one of the files
            $playbookFile = Join-Path $tempPath ".ai/PLAYBOOK.md"
            $customContent = "CUSTOM CONTENT THAT SHOULD NOT BE OVERWRITTEN"
            $customContent | Out-File -FilePath $playbookFile -Force -Encoding utf8

            # 3. Initialize again WITHOUT -Force
            New-AiProjectPattern -Path $tempPath

            # 4. Check if custom content is preserved
            $content = Get-Content -Path $playbookFile -Raw
            $content | Should -Match $customContent
        }

        It 'Overwrites existing files when -Force is specified' {
            # 1. Initialize pattern first
            New-AiProjectPattern -Path $tempPath

            # 2. Modify one of the files
            $playbookFile = Join-Path $tempPath ".ai/PLAYBOOK.md"
            $customContent = "CUSTOM CONTENT THAT SHOULD BE OVERWRITTEN"
            $customContent | Out-File -FilePath $playbookFile -Force -Encoding utf8

            # 3. Initialize again WITH -Force
            New-AiProjectPattern -Path $tempPath -Force

            # 4. Check if custom content was overwritten by default template
            $content = Get-Content -Path $playbookFile -Raw
            $content | Should -Not -Match $customContent
            $content | Should -Match '# AI Playbook'
        }
    }
}
