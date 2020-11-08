Connect-AzureAD
$currentPolicyDefinition = (Get-AzureADPolicy | ?{$_.Type -eq 'B2BManagementPolicy'} | select -First 1).Definition | ConvertFrom-Json
$domainList = $currentPolicyDefinition.B2BManagementPolicy.InvitationsAllowedAndBlockedDomainsPolicy
if ($domainList | gm -Name AllowedDomains) { $restrictionType = "Allow" }
if ($domainList | gm -Name BlockedDomains) { $restrictionType = "Block" }

if ($restrictionType -eq "Block" -and $domainList.BlockedDomains.Count -eq 0) {
    Write-Host "No Collaboration Restrictions Configured"
}

Write-Host "$restrictionType List Configured"

$guestUsers = Get-AzureADUser -Filter "Usertype eq 'Guest'" -All $true
$guestDomains = @()

$guestUsers | % { $guestDomains += $_.Mail.Split("@")[1] } 

$guestDomains = $guestDomains | Select -Unique
$unwantedDomains = New-Object PSObject
$rogueUsers = @()

if ($restrictionType -eq "Block") {
    
    $domainList.BlockedDomains | % {
        $rogueUsers += $guestUsers | select ObjectId,UserPrincipalName | ? UserPrincipalName -like "*$_*"
        $userCount = ($rogueUsers).Count
        $unwantedDomains | Add-Member -MemberType NoteProperty GuestDomain $_
        $unwantedDomains | Add-Member -MemberType NoteProperty UserCount $userCount
    }
}

if ($restrictionType -eq "Allow") {
    $guestDomains | % {
        if ($domainList.AllowedDomains -notcontains $_) {
            $rogueUsers += $guestUsers | select ObjectId,UserPrincipalName | ? UserPrincipalName -like "*$_*"
            $userCount = ($rogueUsers).Count
            $unwantedDomains | Add-Member -MemberType NoteProperty GuestDomain $_
            $unwantedDomains | Add-Member -MemberType NoteProperty UserCount $userCount
        }
    }
}