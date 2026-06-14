# Import dependency
Import-Module Posh-SSH -ErrorAction Stop

<#
.SYNOPSIS
    Sends a local file to a remote server using SCP over SSH.
.DESCRIPTION
    A utility function that wraps Posh-SSH's Set-SCPFile to transfer files securely.
    Supports both SSH private keys and password authentication.
.PARAMETER Path
    The local path to the file to be sent.
.PARAMETER DestinationPath
    The remote path where the file will be saved.
.PARAMETER ComputerName
    The hostname or IP address of the remote SSH server.
.PARAMETER UserName
    The username to log in to the remote SSH server.
.PARAMETER Key
    The password (plain-text string or SecureString) for SSH authentication.
.PARAMETER KeyPath
    The path to the SSH private key file.
.PARAMETER Port
    The port used by the remote SSH server (default is 22).
.PARAMETER WriteLogToFile
    If set, writes operations to the log file.
.EXAMPLE
    Send-FileViaSSH -Path "C:\temp\report.txt" -DestinationPath "/home/user/report.txt" -ComputerName "192.168.1.50" -UserName "admin" -Key "mypassword" -WriteLogToFile
#>
function Send-FileViaSSH {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [string]$Path,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$DestinationPath,

        [Parameter(Mandatory = $true)]
        [Alias('Host', 'IP')]
        [string]$ComputerName,

        [Parameter(Mandatory = $true)]
        [Alias('User')]
        [string]$UserName,

        [Parameter()]
        [Alias('Password', 'Pass')]
        $Key,

        [Parameter()]
        [string]$KeyPath,

        [Parameter()]
        [int]$Port = 22,

        [Parameter()]
        [switch]$WriteLogToFile
    )

    process {
        Write-Log -Message "Preparing to send file via SSH: $Path to $UserName@$($ComputerName):$DestinationPath" -Level Info -WriteLogToFile:$WriteLogToFile

        # Validate local path
        if (-not (Test-Path -Path $Path -PathType Leaf)) {
            $err = "Local file not found: $Path"
            Write-Log -Message $err -Level Error -WriteLogToFile:$WriteLogToFile
            Write-Error $err
            return
        }

        $resolvedPath = (Resolve-Path -Path $Path).Path

        # Prepare parameters for Set-SCPFile
        $scpParams = @{
            ComputerName = $ComputerName
            LocalFile    = $resolvedPath
            RemotePath   = $DestinationPath
            Port         = $Port
        }

        # Handle Password/Key authentication
        $secPassword = $null
        if ($null -ne $Key) {
            if ($Key -is [System.Security.SecureString]) {
                $secPassword = $Key
            } elseif ($Key -is [string]) {
                $secPassword = ConvertTo-SecureString $Key -AsPlainText -Force
            }
            $scpParams.Credential = New-Object System.Management.Automation.PSCredential($UserName, $secPassword)
        }

        # Handle KeyPath authentication
        if (-not [string]::IsNullOrWhiteSpace($KeyPath)) {
            if (-not (Test-Path -Path $KeyPath)) {
                $err = "SSH private key file not found: $KeyPath"
                Write-Log -Message $err -Level Error -WriteLogToFile:$WriteLogToFile
                Write-Error $err
                return
            }
            $scpParams.KeyPath = (Resolve-Path -Path $KeyPath).Path

            # Posh-SSH requires a credential even for key auth to carry the username
            if ($null -eq $scpParams.Credential) {
                $dummyPassword = ConvertTo-SecureString "dummy" -AsPlainText -Force
                $scpParams.Credential = New-Object System.Management.Automation.PSCredential($UserName, $dummyPassword)
            }
        }

        # If neither Key nor KeyPath is provided, we can still construct a credential and let Posh-SSH prompt
        if ($null -eq $scpParams.Credential -and [string]::IsNullOrWhiteSpace($scpParams.KeyPath)) {
            $dummyPassword = ConvertTo-SecureString "dummy" -AsPlainText -Force
            $scpParams.Credential = New-Object System.Management.Automation.PSCredential($UserName, $dummyPassword)
        }

        # Execution using ShouldProcess (WhatIf support)
        if ($PSCmdlet.ShouldProcess("File: $resolvedPath", "Send via SCP to $UserName@$($ComputerName):$DestinationPath on port $Port")) {
            Write-Log -Message "Executing Set-SCPFile to $UserName@$ComputerName..." -Level Info -WriteLogToFile:$WriteLogToFile
            try {
                Set-SCPFile @scpParams -ErrorAction Stop
                Write-Log -Message "SCP transfer completed successfully." -Level Info -WriteLogToFile:$WriteLogToFile
            }
            catch {
                $errMessage = "SCP transfer failed: $_"
                Write-Log -Message $errMessage -Level Error -WriteLogToFile:$WriteLogToFile
                Write-Error $errMessage
            }
        }
    }
}

Export-ModuleMember -Function 'Send-FileViaSSH'
