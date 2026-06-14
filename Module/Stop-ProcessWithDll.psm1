<#
.SYNOPSIS
    Stops processes that have loaded a specific DLL.
.DESCRIPTION
    This cmdlet searches all running processes to find those that have loaded a DLL
    matching the specified name, and terminates them.
.PARAMETER DllName
    The name or partial name of the DLL to search for.
.PARAMETER Force
    If specified, forces the termination of matching processes without prompting.
.PARAMETER PassThru
    Returns objects representing the stopped processes.
.EXAMPLE
    Stop-ProcessWithDll -DllName "myhelper.dll" -Force
#>
function Stop-ProcessWithDll {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Dll')]
        [string]$DllName,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$PassThru
    )

    process {
        Write-Verbose "Scanning processes for DLL: $DllName"
        
        $targetProcesses = Get-Process | Where-Object {
            try {
                # Check modules loaded by the process
                $modules = $_.Modules
                $found = $false
                foreach ($mod in $modules) {
                    if ($mod.ModuleName -like "*$DllName*" -or $mod.FileName -like "*$DllName*") {
                        $found = $true
                        break
                    }
                }
                $found
            }
            catch {
                # Silently catch access denied/permission errors for system/restricted processes
                $false
            }
        }

        if (-not $targetProcesses) {
            Write-Verbose "No processes found loading DLL: $DllName"
            return
        }

        foreach ($proc in $targetProcesses) {
            if ($PSCmdlet.ShouldProcess("Process '$($proc.Name)' (PID: $($proc.Id))", "Terminate process holding DLL '$DllName'")) {
                try {
                    $stopParams = @{
                        Id = $proc.Id
                    }
                    if ($Force) {
                        $stopParams.Force = $true
                    }
                    if ($PassThru) {
                        $stopParams.PassThru = $true
                    }

                    Stop-Process @stopParams
                }
                catch {
                    Write-Error "Failed to stop process '$($proc.Name)' (PID: $($proc.Id)): $_"
                }
            }
        }
    }
}

Export-ModuleMember -Function 'Stop-ProcessWithDll'
