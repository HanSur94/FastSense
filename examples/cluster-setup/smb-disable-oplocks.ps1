<#
.SYNOPSIS
    Disable SMB opportunistic locks (oplocks) on a Windows Server file share
    hosting a FastSense v4.0 cluster's EventStore directory.

.DESCRIPTION
    SMB oplocks cache file contents on the client and can yield torn reads
    of the SQLite EventStore during the oplock-break flush window. Per the
    SQLite team's deployment guidance, oplocks MUST be disabled on the
    directory hosting any SQLite database on an SMB share.

    This script disables SMB leases (the SMB3 successor of oplocks) on the
    SMB server. Run as Administrator on the file server.

    Why: SMB oplocks corrupt SQLite over network shares -- see
    https://www.sqlite.org/howtocorrupt.html section 3.4

.NOTES
    Required: Windows Server with the SmbShare module.
    Reversible: Set-SmbServerConfiguration -EnableLeasing $true -Force
#>

[CmdletBinding()]
param()

if (-NOT ([Security.Principal.WindowsPrincipal] `
          [Security.Principal.WindowsIdentity]::GetCurrent() `
        ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

Write-Host "Current SMB server configuration:"
Get-SmbServerConfiguration | Select-Object EnableLeasing, EnableOplocks

Write-Host ""
Write-Host "Disabling SMB leases (FastSense v4.0 requirement)..."
Set-SmbServerConfiguration -EnableLeasing $false -Confirm:$false

# Per-share oplock disable on the FastSense share
Set-SmbShare -Name "FastSenseShare" -CachingMode None -Confirm:$false

Write-Host ""
Write-Host "Verified SMB server configuration:"
Get-SmbServerConfiguration | Select-Object EnableLeasing, EnableOplocks

Write-Host ""
Write-Host "Done. Restart the SMB service or reboot the server for the change to take effect:"
Write-Host "    Restart-Service -Name LanmanServer -Force"
