# C# wrapper for Windows Credential Manager
if (-not ([System.Type]::GetType("CredentialManager"))) {
    $csharpSource = @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public class CredentialManager {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CREDENTIAL {
        public uint Flags;
        public uint Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public uint CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint Persist;
        public uint AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredWrite(ref CREDENTIAL userCredential, uint flags);

    [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredRead(string targetName, uint type, uint flags, out IntPtr credential);

    [DllImport("advapi32.dll", EntryPoint = "CredFree", SetLastError = true)]
    private static extern void CredFree(IntPtr buffer);

    [DllImport("advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredDelete(string targetName, uint type, uint flags);

    private const uint CRED_TYPE_GENERIC = 1;
    private const uint CRED_PERSIST_LOCAL_MACHINE = 2;

    public static bool SetSecret(string target, string username, string password) {
        if (string.IsNullOrEmpty(target)) return false;
        
        var cred = new CREDENTIAL();
        cred.Type = CRED_TYPE_GENERIC;
        cred.Persist = CRED_PERSIST_LOCAL_MACHINE;
        cred.TargetName = target;
        cred.UserName = username;

        byte[] blob = Encoding.Unicode.GetBytes(password ?? "");
        cred.CredentialBlobSize = (uint)blob.Length;
        cred.CredentialBlob = Marshal.AllocCoTaskMem(blob.Length);
        Marshal.Copy(blob, 0, cred.CredentialBlob, blob.Length);

        try {
            return CredWrite(ref cred, 0);
        }
        finally {
            Marshal.FreeCoTaskMem(cred.CredentialBlob);
        }
    }

    public static string[] GetSecret(string target) {
        if (string.IsNullOrEmpty(target)) return null;
        
        IntPtr credPtr = IntPtr.Zero;
        if (!CredRead(target, CRED_TYPE_GENERIC, 0, out credPtr)) {
            return null;
        }

        try {
            var cred = (CREDENTIAL)Marshal.PtrToStructure(credPtr, typeof(CREDENTIAL));
            byte[] blob = new byte[cred.CredentialBlobSize];
            Marshal.Copy(cred.CredentialBlob, blob, 0, blob.Length);
            string password = Encoding.Unicode.GetString(blob);
            
            return new string[] { cred.UserName, password };
        }
        finally {
            CredFree(credPtr);
        }
    }

    public static bool RemoveSecret(string target) {
        if (string.IsNullOrEmpty(target)) return false;
        return CredDelete(target, CRED_TYPE_GENERIC, 0);
    }
}
"@
    Add-Type -TypeDefinition $csharpSource -ErrorAction Stop
}

<#
.SYNOPSIS
    Saves a credential securely in Windows Credential Manager.
.PARAMETER Target
    The target name/key for the secret.
.PARAMETER UserName
    The username associated with the secret.
.PARAMETER Password
    The password or API key value to save.
#>
function Set-LazySecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Target,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$UserName,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]$Password
    )

    process {
        Write-Log -Message "Saving secret for target '$Target' (User: '$UserName') to Windows Credential Manager..." -Level Info -WriteLogToFile
        
        $success = [CredentialManager]::SetSecret($Target, $UserName, $Password)
        if ($success) {
            Write-Log -Message "Secret saved successfully for target '$Target'." -Level Info -WriteLogToFile
        }
        else {
            $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            $errorMsg = "Failed to save secret for target '$Target'. Win32 Error: $lastError"
            Write-Log -Message $errorMsg -Level Error -WriteLogToFile
            throw $errorMsg
        }
    }
}

<#
.SYNOPSIS
    Retrieves a stored credential from Windows Credential Manager.
.PARAMETER Target
    The target name/key of the secret to retrieve.
#>
function Get-LazySecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Target
    )

    process {
        Write-Log -Message "Retrieving secret for target '$Target' from Windows Credential Manager..." -Level Info -WriteLogToFile
        
        $result = [CredentialManager]::GetSecret($Target)
        if ($null -eq $result) {
            Write-Log -Message "No secret found for target '$Target'." -Level Warning -WriteLogToFile
            return $null
        }

        $username = $result[0]
        $password = $result[1]

        return [PSCustomObject]@{
            Target   = $Target
            UserName = $username
            Password = $password
        }
    }
}

<#
.SYNOPSIS
    Deletes a stored credential from Windows Credential Manager.
.PARAMETER Target
    The target name/key of the secret to remove.
#>
function Remove-LazySecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Target
    )

    process {
        Write-Log -Message "Removing secret for target '$Target' from Windows Credential Manager..." -Level Info -WriteLogToFile
        
        $success = [CredentialManager]::RemoveSecret($Target)
        if ($success) {
            Write-Log -Message "Secret for target '$Target' removed successfully." -Level Info -WriteLogToFile
        }
        else {
            Write-Log -Message "No secret found or failed to remove secret for target '$Target'." -Level Warning -WriteLogToFile
        }
    }
}

Export-ModuleMember -Function 'Set-LazySecret', 'Get-LazySecret', 'Remove-LazySecret'
