function Get-FQDN {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Hostname,
        [Parameter(Mandatory = $true)]
        [string]$Domain
    )
    return "$Hostname.$Domain"
}

function Test-FQDNOnline {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FQDN
    )
    try {
        $ping = Test-Connection -ComputerName $FQDN -Count 1 -Quiet
        return $ping
    }
    catch {
        return $false
    }
}

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

function Get-ChromeUpdatePoliciesController {
    param (
        [Parameter(Mandatory = $true)]
        [string]$HostnameOrFilePath,
        [Parameter(Mandatory = $true)]
        [string]$Domain,
        [Parameter(Mandatory = $true)]
        [string]$OutputFolder
    )

    $hostnames = @()
    if (Test-Path -Path $HostnameOrFilePath) {
        $hostnames = Get-Content -Path $HostnameOrFilePath
    }
    else {
        $hostnames = @($HostnameOrFilePath)
    }

    $fqdnList = $hostnames | ForEach-Object { Get-FQDN -Hostname $_ -Domain $Domain }
    $results = @()

    $counter = 0
    $total = $fqdnList.Count

    foreach ($fqdn in $fqdnList) {
        $counter++
        Write-Progress -Activity "Processing FQDNs" -Status "$counter out of $total" -PercentComplete (($counter / $total) * 100)

        if (Test-FQDNOnline -FQDN $fqdn) {
            try {
                $policies = Get-ChromeUpdatePolicies -FQDNs @($fqdn)
                $policyProperties = @{
                    UpdateDefault                                = $null
                    Install_8A69D345_D564_463C_AFF1_A69D9E530F96 = $null
                    Update_8A69D345_D564_463C_AFF1_A69D9E530F96  = $null
                    InstallDefault                               = $null
                    AutoUpdateCheckPeriodMinutes                 = $null
                    Install_8237E44A_0054_442C_B6B6_EA0509993955 = $null
                    Update_8237E44A_0054_442C_B6B6_EA0509993955  = $null
                    DisableAutoUpdateChecksCheckboxValue         = $null
                }
                foreach ($property in $policies.PSObject.Properties) {
                    if ($property.Value -ne $null) {
                        $policyProperties[$property.Name] = $property.Value
                    }
                }
                $results += [PSCustomObject]@{
                    FQDN   = $fqdn
                    Status = "Online"
                } + $policyProperties
            }
            catch {
                $results += [PSCustomObject]@{
                    FQDN    = $fqdn
                    Status  = "Error"
                    Message = $_.Exception.Message
                }
            }
        }
        else {
            $results += [PSCustomObject]@{
                FQDN    = $fqdn
                Status  = "Offline"
                Message = "Host is offline"
            }
        }
    }

    $date = Get-Date -Format "yyyyMMdd"
    $outputFile = Join-Path -Path $OutputFolder -ChildPath "ChromeUpdatePolicies_$date.csv"
    $results | Export-Csv -Path $outputFile -NoTypeInformation
}