---
trigger: always_on
---

# AI Rules - PowerShell Modules

## 1. Files & Naming
- Create new sub-modules under `Module/` with `.psm1` extension (e.g., `Module/Get-SampleInfo.psm1`).
- Use standard Verb-Noun naming convention (e.g., `Get-SampleInfo`).

## 2. No $matches Variable
- **DO NOT** use the reserved automatic variable `$matches`. Use `$foundMatches` or `$searchResults` instead.

## 3. Manifest Registration (`LazyWorker.psd1`)
- Add new sub-module path to `NestedModules` array (e.g., `'Module\Get-SampleInfo.psm1'`).
- Add function name to `FunctionsToExport` array (e.g., `'Get-SampleInfo'`).
- For aliases: Add to `AliasesToExport`, define via `New-Alias`, and export using `Export-ModuleMember -Alias 'Alias-Name'`.
- Sub-modules must call `Export-ModuleMember -Function 'Function-Name'` at the end.

## 4. Logging & Config
- Use the central logging utility: `Write-Log -Message <string> [-Level <Info|Warning|Error|Debug|Trace>] [-WriteLogToFile]`.
- Save configurations as flat JSON key-values under `Environment/`. `Load-LazyWorker.ps1` dynamically loads these as `$env:KeyName`.

## 5. LogPath Fallback
- Prioritize `$env:LogPath`. If null/empty/whitespace, fallback to root `Logs` folder: `Join-Path (Split-Path $PSScriptRoot -Parent) "Logs"`. Do not skip file logging when `$env:LogPath` is missing.

## 6. Dependencies
- Check external module dependencies lazily inside the function/cmdlet definition (not at the root/top of the sub-module script) to avoid blocking the parent module import process. Prompt to install if missing.
- Auto-install NuGet (if missing), trust `PSGallery`, and run: `Install-Module -Name <Name> -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop`.
- Throw a terminating error if the installation is skipped or fails.

## 7. Testing
- Create Pester tests under a top-level `tests/` directory. Use descriptive filenames matching the module or function, e.g., `tests/Write-Log.Tests.ps1`.
- Tests should verify module exports, function behavior, and important fallbacks (e.g., LogPath fallback).
- Prefer idempotent tests: create and clean up any temporary files or folders used during testing.
- CI pipelines should run `Invoke-Pester -Path tests -PassThru` and fail the build on test failures.

