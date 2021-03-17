 # $global:Path = read-host "Enter the path of the zipped FW files"
 $Global:rom_dir = "$path\Romdata"
 $Global:java_dir = "$path\sdk"
 $global:date = Get-Date -format "MM-dd-yy"
 $global:firmware_path = "C:\Users\Adam\Desktop\Firmware"
function Start-Task {
    #figure out why it deleted all zip files when renaming to the same name with a date already in name
    Set-PathtoFirmwareFiles
    $continue = "yes"
    #checking if path is a real path
    if (!(test-path $global:Path)) {
        Throw "$_ is not a valid path.  Try again"
    }

    #protection to prevent execution in root firmware path
    if ($global:Path -eq $global:firmware_path) {
        Throw "Cannot Execute in this directory"
    }

    #Checking if path has a subfolder named "romdata"
    $test = Get-ChildItem $rom_dir -File -ea SilentlyContinue -ErrorVariable err
    if ($err) {
        $continue = Read-Host "`nNo 'romdata' folder in $global:path`nAre you sure you want to continue (y/n)?"

        #Throwing error if no zip files in path
        $zip_files = Get-ChildItem $global:Path -Filter *.zip
        if (!($zip_files)) {
            Throw "'$global:Path' has NO zip files. Put the zip files in this path"
        }
    }

    #only continuing if the user wants to or there is a subfolder in path named 'romdata'
    if ($continue -match "^\s*yes\s*$|^\s*y\s*$") { 
       
        #close explorer window in order to avoid access issues
        $shell = New-Object -ComObject Shell.Application
        $window = $shell.Windows() | Where-Object { $_.LocationURL -like "$(([uri]"$global:path").AbsoluteUri)*" }
        ForEach ($w in $window) {
            #Write-Host "`nClosing $($w.locationurl))"
            $w.Quit() 
        }

        #Deleting any prevoius Readme_files folder
        if (Test-Path "$path\readme_files") {
            Remove-Item "$path\readme_files" -Recurse -Force -ea SilentlyContinue | Out-Null
        }

        #main body of script
        Start-FirmwareFileSetup $Path
        #Write-Host 1
        #Start-Sleep 2
        delete_old_firmware $Path
        #Write-Host 2
        #Start-Sleep 2
        Remove-Directories $rom_dir
        #Write-Host 3
        #Start-Sleep 2
        create_most_up_to_date_list $Path
        #Write-Host 4
        #Start-Sleep 2
        $new_path = Rename-path
        Copy-ToUSB $new_path
    }
    else {
        Write-host "Exiting Script"
    }
}

Function Get-LocalFirmwareFolder ($path) {
    $threshold = 2
    $paths = @()
    write-host "Finding zip files in $path"
    $zip_files = Get-ChildItem $path -Filter "*.zip"
    if ($zip_files.Length -gt $threshold) {
        write-host "Found more than $threshold zip files in $path"
        $res = $path
    }
    else {
        $dirs = Get-ChildItem $path -Recurse -Directory
        foreach ($d in $dirs) {
            $zip_files = Get-ChildItem $d.FullName -Filter "*.zip"
            if ($zip_files.Length -gt $threshold) {
                write-host "Found more than $threshold zip files in $($d.FullName)"
                $paths += $d.FullName
            }
        }
        if ($paths.Length -eq 1) {

        }
        elseif ($paths.Length -gt 1) {
            $n = 1
            Write-Host "The following folders have multiple zip files:"
            foreach ($p in $paths) {
                Write-Host "[$n] - $p"
            }
            Read-Host "  Which one is the correct path? "
        }
    }
    "returning $res"
    return $res
}
function Set-PathtoFirmwareFiles {
    $dirs = Get-ChildItem -literalpath $global:firmware_path -Directory
    $search = read-host "`nEnter the name of the machine for which you want to copy FW to USB"
    $res = @()
    # $index +=
    foreach ($d in $dirs) {
        if ($d.name -match $search) {
            # Write-Host "Match found: $($d.fullname)"
            $res += $d.FullName
            # $index += $n
        }
    }
    if ($res.Length -gt 1) {
        Write-Host "`nThere are multiple matches for '$search'.  Which one do you mean?"
        $n = 1

        foreach ($r in $res) {
            Write-host "[$n] - $r"
            $n += 1

        }
        Write-Host "`n"
        $ans = Read-Host "Type the number of the corresponding entry: "




    }
    elseif ($res.Length -eq 1) {
        Write-Host "Match Found: $($res[0])"
        $ans = Read-Host "Is this correct? (y/n)"
        while ($ans -notmatch "^[ynYN]$") {
            $ans = Read-Host "Invalid entry.  Either 'y' for yes or 'n' no: "
        }
        if ($ans -match 'y') {
            Write-Host "yes"
            Get-LocalFirmwareFolder $res[0]
        }
        elseif ($ans -match 'n') {
            Set-PathtoFirmwareFiles
        }
    }
}
Function Copy-ToUSB ($new_path) {
    $usb_drive = $null
    $drives = Get-PSDrive -PSProvider FileSystem
    foreach ($d in $drives) {
        #Write-Host $d.name
        $usb_drive = $d.name
    }
    #Write-Host "USB drive is $usb_drive"
    if ($usb_drive -notmatch "^\s*C\s*$") {
        Write-Host "USB drive is in"
        $src = "$($new_path)\romdata"
        $dest = "$($usb_drive):\romdata"
        if (Test-Path $dest) {
            Write-Host "Romdata present on USB.  Deleting '$($usb_drive):\romdata'"
            Remove-Item "$($usb_drive):\romdata" -Force -Recurse
        }
        else {
            Write-Host "Romdata absent on USB"
        }
        Write-Host "Copying '$src'`nto '$dest'"
        Copy-Item $src $dest -Recurse -Force -ErrorVariable err | Out-Null -ea Inquire
        if ($err) {
            Write-Host "Copying Unsuccessful"
        }
        else {
            Write-Host "Copying Successful"
        }
        $Shell = New-Object -ComObject Shell.Application
        Invoke-Item $src
        Invoke-Item $dest
        Start-Sleep 3
        Write-Host "Ejecting USB drive"
        $driveEject = New-Object -comObject Shell.Application
        $driveEject.Namespace(17).ParseName("$($usb_drive):").InvokeVerb("Eject")
    }
    else {
        Write-Host "USB drive is absent.  Manually transfer`n'$new_path\romdata'`nto root of an SD card"
        
    }
    
}
Function Rename-path {
    #Renaming file to include date
    $continue = $false
    $temp = $global:path -split "\\"
    $name = $($temp[$temp.count - 1])
    $suffix = ""
    #Write-Host "Name: $name and Continue: $continue"
    if ($name.trim() -eq "SD") {
       $name = $($temp[$temp.count - 2])
       $new_name = "$($temp[$temp.count - 2]) -- $date" 
       $continue = $true
       $suffix = $temp[$temp.count - 1]
    }
    elseif ($name.trim() -eq "NOP" -or $name.trim() -eq "SOP") {
       $name = $($temp[$temp.count - 3])
       $new_name = "$($temp[$temp.count - 3]) -- $date" 
       $continue = $true
       $suffix = "$($temp[$temp.count - 2])\$($temp[$temp.count - 1])" 

    }
    elseif ($temp[$temp.count - 2] -eq "Firmware") {
        $new_name =  "$name -- $date"
        $continue = $true
    }
    if ($continue -eq $true) {
        
        #logic to only have one date
        if ($new_name -match "(.*)\s+\-\-\s+[0-9]{2}\-[0-9]{2}\-[0-9]{2}(\s+\-\-\s+[0-9]{2}\-[0-9]{2}\-[0-9]{2})") {
            $new_name = "$($matches[1])$($matches[2])"
            
        }
        $new_path = "$global:firmware_path\$new_name"
        $old_path = "$global:firmware_path\$name"

        #only renaming if the new name is different
        if ($name -ne $new_name) {
            Write-Host "Changing $old_path`n$new_name"
            rename-Item $old_path $new_name
        }
    }

    #re-open explorer window
    $new_path = "$new_path\$suffix"
    #Invoke-Item $new_path
    #Write-Host "New_path: $new_path`nSUffix: $suffix"
    return $new_path
}
function Start-FirmwareFileSetup {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [validatescript({
            if (test-path $_) {
                return $true
            }
            else {
                Throw "$_ is not a valid path.  Try again"
            }
        })]
        [string]$Path
    )
    #Extracting Zip files
    $zip_files = Get-ChildItem -Path $Path -Recurse -Filter *.zip
    foreach ($f in $zip_files) {
        Expand-Archive -Path "$Path\$f" -DestinationPath "$Path" -Force -ErrorAction SilentlyContinue
    }
    #Moving .fwu files to rom_dir
    $fwu_files = Get-ChildItem $path -Recurse -Filter *.fwu
    New-Item -Path $rom_dir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    foreach ($f in $fwu_files) {
        move-Item $f.FullName $rom_dir -ea SilentlyContinue
    }
    #Start-Sleep 3
    $txt_files = Get-ChildItem $path -Recurse -Filter *.txt
    New-Item -Path $path -ItemType Directory -Name "Readme_Files" -ErrorAction SilentlyContinue | Out-Null

    #moving .txt to readme_files and incrementing same name files
    $i = 0
    foreach ($f in $txt_files) {
        # Write-Host $path\Readme_Files\$f
        if (!(test-path $path\Readme_Files\$f)) {
            move-Item $f.FullName $path\Readme_Files -ErrorAction SilentlyContinue
            # write-host 1
        }
        else {
            $f_new = $f -replace ".txt", ""
            $filename = "$f_new - $i.txt"
            move-Item $f.FullName $path\Readme_Files\$filename -ErrorAction SilentlyContinue
            # write-host 2  
            $i+=1
        }   
    }
    $dir = Get-ChildItem $path -Directory -Recurse | Where-Object -FilterScript {($_.GetFiles().Count -eq 0) -and $_.GetDirectories().Count -eq 0} | Select-Object -ExpandProperty FullName
    foreach ($d in $dir) {
        # Write-Host $d
        Remove-Item $d -ErrorAction SilentlyContinue -Force
    }
    
    #creating Java direcory
    New-Item $java_dir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    $exe_files = Get-ChildItem $path -Recurse -Filter *.exe
    foreach ($f in $exe_files) {
        # Write-Host $f.FullName
        Move-Item $f.FullName $java_dir -ErrorAction SilentlyContinue
    }
}
function create_most_up_to_date_list($path) {
    $out_file = "$path\All Versions as of $date.txt"
    $null | Out-File $out_file
    $info = [ordered]@{}
    $create_dates = [ordered]@{}
    $firmwares = [ordered]@{}
    Out-File -FilePath $out_file -InputObject "The most current versions as of $(Get-Date -format "MM/dd/yy") are:`n`n"
    $txt_files = Get-ChildItem $path -filter *.txt -File -Recurse
    foreach ($f in $txt_files) {
        $i = 1
        # Write-Host "File: $f"
        foreach ($l in Get-Content $f.FullName) {
            # Reading readmes for version, program_name, and create_date
            if ($l -match '\[Version\]') {
                $version = $l -replace '\[Version\]', ''
                # Write-Host "Version: $version"
            }
            if ($l -match '\[Program Name\]') {
                $program_name = $l -replace '\[Program Name\]', ''
                $program_name = "$program_name".trim()
                # Write-Host "Program: $program_name"
            }
            if ($l -match '\[Create Date\]') {
                $create_date = $l -replace '\[Create Date\]', ''
                $create_date = "$create_date".trim()
                # Write-Host "Program: $program_name"
            }
            if ($l -match '\[Firmware No.\]') {
                $firmware = $l -replace '\[Firmware No.\]', ''
                $firmware = "$firmware".trim()
                # Write-Host "Program: $program_name"
            }
            $i += 1
        }
        if ($null -ne $program_name -and $null -ne $version) {
            # Write-Host "Program Name: $program_name"
            # write-host "Create date: $create_date"
            # Write-Host "Version: $version and Info[program_name]: $($info[$program_name])"
            if ($null -ne $info[$program_name]) {
                # Write-Host "$program_name already has an entry"
                # Write-Host "comparing $create_date with $($create_dates[$program_name])"
                if ($create_date -gt $create_dates[$program_name]) {
                    # Write-Host "$create_date is Greater than $($create_dates[$program_name])"
                    $info.set_item($program_name, $version)
                    $create_dates.set_item($program_name, $create_date)
                    $firmwares.set_item($program_name, $firmware)
                }
            }   
            else {
                $info.set_item($program_name, $version)
                $create_dates.set_item($program_name, $create_date)
                $firmwares.set_item($program_name, $firmware)
            }     
        }   
    }
    $out = sortedKeys $info
    $part_1 = "Program Name"
    $part_2 = "(Version)"
    $part_3 = "File Name"
    $part_4 = "Date Created"
    $space_length = 45
    $space_less = 25
    # $1st_space = " " * ($space_length - $part_1.Length)
    $2nd_space = " " * ($space_length - $part_1.Length - $part_2.Length)
    $3rd_space = " " * ($space_length - $part_3.Length - $space_less)
    $title = "$part_1$part_2$2nd_space$part_3$3rd_space$part_4"
    Out-File -FilePath $out_file -InputObject $title -Append
    foreach ($program_name in $out) {
        # Write-Host "Create date for $program_name is $($create_dates[$program_name])"
        $ver = $info[$program_name].trim()
        $firm = $firmwares[$program_name].trim()
        $date = $create_dates[$program_name].trim()
        # $1st_space = " " * ($space_length - $program_name.Length)
        $2nd_space = " " * ($space_length - $ver.Length - $program_name.Length - 2)
        $3rd_space = " " * ($space_length - $firm.Length - $space_less)
        $output = "$program_name"+"($ver)" + $2nd_space + "$firm" + $3rd_space + "$date"
        Out-File -FilePath $out_file -InputObject $output -Append
    }
}
function sortedKeys([hashtable]$ht) {
    $out = @()
    foreach($k in $ht.keys) {
        $out += $k
    }
    [Array]::sort($out)
    return ,$out
}
function delete_old_firmware ($Path) {
    $to_delete = @()
    $names = (Get-ChildItem $rom_dir -File -ea Stop) 

    $k = 1
    # $j = 1
    $length = $names.Length
    foreach ($n in $names) {
        # Write-Host "k: $k and length: $($length)"
        $first = $n.Name
        $first = $first.split(".")[0]
        # Write-Host "First: $first"
        foreach($n2 in $names[$k..($length)]) {
            $second = $n2.Name
            $second = $second.split(".")[0]
            # Write-Host "Second: $second"

            #comparing pairs
            if ($k -ne $length ) {
                if ($first.length -eq $second.length) {
                    # write-host "`nComparing $first and $second"
                    # Write-Host "a: $a and b: $b"
                    
                    #only continues if the last character in both is a letter
                    $first_part_number = $first.substring(0, $first.length -1)
                    $second_part_number = $second.substring(0, $second.length -1)
                    $first_version = $first[$first.length -1]
                    $second_version = $second[$second.length -1]
                    # Write-Host "Part# 1: $first_part_number and Part# 2: $second_part_number"

                    #cont if last char in both is alpha
                    if ($first_version -match '[A-z]' -and $second_version -match '[A-z]') {
                        # write-host "Last char in $first is $first_version and Last char in $second is $second_version"

                        #cont if all but last char are the same
                        if ($first_part_number -eq $second_part_number) {
                            # write-host "$first_part_number and $second_part_number are the same"
                            # Write-Host "`nfirst: $first and second: $second`nfirst_ver: $first_version and second_ver: $second_version"

                            #delete the smaller version
                            if ($first_version -lt $second_version) {
                                # Write-Host "Deleting $($n.fullname)"
                                $to_delete += $n.fullname
                            }
                        }
                    }
                }
            }

        }
        $k += 1
    }

    foreach ($d in $to_delete) {
        Write-Host "Deleting $d"
        Remove-Item $d -Force -ErrorAction SilentlyContinue
    }
}
function Remove-Directories ($Path) {
    $dirs = Get-ChildItem $Path -Directory
    "`n"
    foreach ($d in $dirs) {
        write-host "Removing $($d.fullname)"
        Remove-Item $d.fullname -Force -Recurse
    }
    $dirs = Get-ChildItem $global:Path -Directory
    foreach ($d in $dirs) {
        if ($d.name -notmatch "Romdata|Readme_Files|SDK") {
           write-host "Removing $($d.fullname)"
           Remove-Item $d.fullname -Force -Recurse
        }
    }
    "`n"
}

# Start-Task
Set-PathtoFirmwareFiles