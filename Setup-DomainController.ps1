Function Setup-Partitions {
    $OS_part = get-partition -DiskNumber 0 | ? {$_.DriveLetter -ieq "C"}
    if ((Get-Partition -PartitionNumber $OS_part.PartitionNumber).size -ne 30GB) {
        Resize-Partition -DiskNumber 0 -PartitionNumber $OS_part.PartitionNumber -Size 30GB | Out-Null
    }

    $continue = $true
    foreach ($p in (Get-Partition).size) {
        if ($p -eq 10GB) {
            $continue = $false
            $to_add = $p
        }
    }
    if ($continue -eq $true) {
        New-Partition -DiskNumber 0 -UseMaximumSize -AssignDriveLetter -ErrorAction SilentlyContinue | Out-Null
    } 
    Get-Volume | ? {$_.OperationalStatus -ne "ok"} | Format-Volume -FileSystem NTFS | Out-Null
}
Function Setup-FileShare {
    $drive = Get-PSDrive -PSProvider filesystem | Select-Object -last 1 | % root
    $share_name = "FileServer"
    $path = "$drive\$share_name"
    new-item $path -ItemType Directory -ea SilentlyContinue | Out-Null
    New-SmbShare -path $path -Name "FileServer" -FullAccess "Administrators", "Domain Admins" -ReadAccess "Domain Users"
}

Function Setup-OrganizationalUnits {
    $path = ".\Desktop\OU_Structure.txt"
    [string]$DomainName = (Get-ADDomain).distinguishedname
    ForEach($l in (Get-Content $path)) {
        $OrgUnitPath = ""
        Write-host "`n$l"
        $OrgUnits = (Split-Path $l -Parent).Split('\')
        [array]::Reverse($OrgUnits)
        write-host "OrgUnits: $OrgUnits"
        foreach($o in $OrgUnits) {
            if ($o.Length -eq 0) {
                break                
            }
            $OrgUnitPath += $OrgUnitPath + "OU=" + $o + ","
        }
        
        $NewOrgUnitName = Split-Path $l -Leaf
        [array]$temp = $OrgUnitPath -split(',')
        
        if ($OrgUnits.Count -ge 2) {
            [string]$OrgUnitPath = $temp[1..($temp.Length-1)] -join(",")
            Write-Host "This one is in if clause"
        }
        
        $OrgUnitPath += $DomainName
        Write-Host "Path: $OrgUnitPath"
        Write-Host "Leaf: $NewOrgUnitName"
        #Write-Host "New OU Name: $New_path"
        New-ADOrganizationalUnit -name "$NewOrgUnitName" -path "$OrgUnitPath" -ProtectedFromAccidentalDeletion:$false -ErrorAction SilentlyContinue | Out-Null
    }
   

}
Function Setup-DomainController {
    param(
        # This is the path of the .txt file with the OU structure
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateScript({
            if (Test-Path -Path $_ -ErrorAction silentlycontinue)
            {
                return $true
            }
            else
            {
                throw "$($_) is not a valid path."
            }
        })]
        [string]$global:Path
    )
    #need to specifiy the location of the txt file with the OU structure
    #$global:path = "C:\Users\Adam\Desktop\OU_Structure.txt"
    #install features 
    install-windowsfeature -name AD-Domain-Services, DHCP, DNS, FS-Data-Deduplication, FS-Resource-Manager, Print-Services, Print-Server, WDS -ea stop

    #partition HDD
    Setup-Partitions 
    #create share and permissions
    Setup-FileShare
    #promote to DC and create domain

    #setup dhcp

    #create ou structure
    Setup-OrganizationalUnits

}
