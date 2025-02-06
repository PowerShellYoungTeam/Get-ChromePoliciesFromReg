function Get-ChromeUpdatePolicies {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$FQDNs
    )

    $chromeUpdateRegistryPath = "HKLM:\Software\Policies\Google\Update"

    foreach ($fqdn in $FQDNs) {
        try {
            $session = New-PSSession -ComputerName $fqdn -ErrorAction Stop
            Invoke-Command -Session $session -ScriptBlock {
                if (Test-Path -Path $using:chromeUpdateRegistryPath) {
                    Get-ItemProperty -Path $using:chromeUpdateRegistryPath
                }
                else {
                    Write-Output "No Chrome update policies found on $using:fqdn"
                }
            }
            Remove-PSSession -Session $session
        }
        catch {
            Write-Output "Failed to connect to $($fqdn): $($_.Exception.Message)"
        }
    }
}