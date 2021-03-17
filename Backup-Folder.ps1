Function Write-Log ([string]$logstring) {
    #Add-content $global:Logfile -value $logstring -ErrorAction SilentlyContinue
}
function Get-PathbyGUI ([string]$msg) {
    Add-Type -AssemblyName System.Windows.Forms
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = $msg
    if ($FolderBrowser.ShowDialog() -eq "ok") {
        $Path = $FolderBrowser.SelectedPath
    }
    else {
        break
    }
    return $Path
}
Function Get-Continue ($Path, $destination, $GUI) {
    #"Path: $path and Dest: $destination"
    if ($GUI -and (($Path -ne $false) -or ($destination -ne $false))) {
        $msg = "You must either specify a source and then a destination path, or use -GUI to get them graphically.`nTry again." 
        if ($global:LogFile) {
            Write-Log $msg
        }
        if ($global:Test) {$msg} else {Write-Error $msg}
        $checks =  0
    } 
    elseif (($Path -eq $false) -and ($destination -eq $false) -and $GUI)  {
        $checks =  2
    }    
    elseif (!(test-path $Path -EA SilentlyContinue)) {
        $msg = "You must specify a valid Source Path.`nTry again."
        if ($global:LogFile) {
            Write-Log $msg
        }
        if ($global:Test) {$msg} else {Write-Error $msg}

        $checks =  0
    }           
    elseif ($destination -notmatch '^[A-z]:\\' -or $destination[0] -notin (Get-PSDrive -PSProvider FileSystem).Name) {
        $msg = "You must specify a valid destination or the drive letter you specified is not valid.`nTry again."
        if ($global:LogFile) {
            Write-Log $msg
        }
        if ($global:Test) {
            "$msg"
        }
        else {
            Write-Error $msg
        }
        $checks =  0
    }
    elseif ($Delete -and $DeleteConfirm) {
        $msg = "-Delete and -DeleteConfirm are mutually exclusive.  Please choose only one.  -Delete removes files without asking first.  -DeleteConfirm asks before deleting the files."
        if ($global:LogFile) {
            Write-Log $msg
        }
        if ($global:Test) {$msg} else {Write-Error $msg}
        $checks = 0
    }
    if ($checks -eq 2) {
            $Path = Get-PathbyGUI -msg "Select the Source Folder"
            $destination = Get-PathbyGUI -msg "Select the Destination Folder"
    }
    Elseif ($checks -eq 0) {
        $msg = "Checks failed!`n-------------"
        if ($global:LogFile) {
            Write-Log $msg
        }
        if ($global:Test) {$msg} else {Write-Error $msg}
        break
    } 
}
Function Remove-Files ($files, $dest_files) {
    $i = 0
    [array]$to_delete_name, [array]$to_delete_length = @()
    #creates array of names in dest that don't match source
    foreach ($f in $global:comp_name) {
        if (($f.sideindicator -eq "=>") -and ($null -ne $f.name)) {
            $to_delete_name += $f.name
        }
    }
    #creates array of lengths in dest that don't match source
    foreach ($f in $global:comp_length) {
        if (($f.sideindicator -eq "=>") -and ($null -ne $f.length)) {
            $to_delete_length += $f.length
        }
    }
    # Write-Host $to_delete_name
    # Write-Host $to_delete_length
    # ("New Folder" -in $to_delete_name)
    # (3704254 -in $to_delete_length)
    #Gotta find files with this name and test each one for a correspondent in source"
    foreach ($f in $d_all) {
        if ($f.name -in $to_delete_name) {
            #"$($f.fullname) is in $to_delete_name"
            if ($f.length -in $to_delete_length) {
                #"$($f.fullname) is in $to_delete_length"
                $f_escaped = $f.fullname -replace "[\[]", "``["
                $f_escaped = $f_escaped -replace "[\]]", "``]"
                $p = $f_escaped -ireplace [regex]::Escape($destination),$path
                if (!(test-path $p)) {
                    $msg = "`tDeleting: $($f.fullname) as there is no correspondent in the source"
                    if ($Test) {$msg} else {Write-Host $msg}
                    
                    Remove-item $f_escaped
                }
            }
        }        
    }
    "waiting:"
    sts 100     
}

Function New-Directory ($folders, $Path) {
    if ($null -eq $folders) {
        $folders = get-item $path -ea SilentlyContinue
    }
    foreach ($f in $folders) {
        $new_dir = $f.fullname -ireplace [regex]::Escape($Path),$destination
        $msg = "`tCreating directory '{0}' because it is not in destination" -f ($new_dir)
        if(!(Test-Path ($new_dir))) {
            if ($global:LogFile -ne $false) {
                Write-Log $msg
            }
            if ($global:Test) {$msg} else {Write-Verbose $msg}
            New-Item -Path $new_dir -ItemType Directory | out-null
        }
    }
}
Function Reset-Variables {
    $global:files, $global:size, $global:folders, $global:total_size, $global:current_size, $global:dest_file_time, $global:dest_files, $global:total_time = $null 
    [array]$global:to_remove, [array]$global:to_copy, [array]$global:to_copy_to, [array]$global:to_move, [array]$global:to_move_to, [array]$global:size_copy, [array]$global:size_move, [array]$global:removed = @()   
}
# Function New-DepthDirectory ($paths, $Destination) {
#     $global:new_dest = @()
#     foreach ($f in $paths) {
#         $dest = $destination + '\' + $($f -ireplace ("^.*\\", ""))
#         $global:new_Dest += $destination + '\' + $($f -ireplace ("^.*\\", ""))
#         $msg = "`tCreating path '{0}'" -f $dest
#         if (!(Test-Path $dest)) {
#             if ($global:LogFile -ne $false) {
#                 Write-Log $msg
#             }
#             Write-Verbose $msg
#             New-Item -Path $dest -ItemType Directory -ea SilentlyContinue | out-null
#         }
#     }
# }
Function Get-DestFile ($file, $Path, $destination) {
    $Destination_full = $file.DirectoryName -ireplace [regex]::Escape($Path),$Destination
    $Destination_full += '\'
    $dest_file_path = ($Destination_full + $file.Name) 
    return $dest_file_path, $Destination_full
}
Function Remove-After ($Path, $destination, $item) {
    foreach ($i in $item) {                
        $new_dir = $($i.fullname) -ireplace [regex]::Escape($destination), $Path 
        if (!(Test-Path $new_dir)) {
            $global:to_remove += $i.fullname
            if (!$DeleteConfirm) {
                if ((get-item $i.fullname -ea SilentlyContinue).psiscontainer) {
                    $msg = "`tDeleting directory '{0}' because it is not in source" -f $i.fullname
                    if ($global:Test) {$msg} else {Write-Host $msg}
                    if ($global:LogFile -ne $false) {
                        Write-Log $msg
                    }
                }
                else {
                    $msg = "`tDeleting file '{0}' because a newer version was copied from the source to a different location" -f $($i.fullname)
                    if ($global:Test) {$msg} else {Write-Host $msg}
                    if ($global:LogFile -ne $false) {
                        Write-Log $msg
                    }                
                }
                Remove-Item $i.fullname -ea SilentlyContinue
            }
        }                
    }
}
Function Out-Start ($Path, $destination) {
    $time = get-date -Format G
    $global:header = "Backup-Folder $path $destination $global:Options run at $time`:"
    $global:line = "-" * $global:header.Length
    if($global:LogFile -ne $False) {
        if (($global:LogFile -notmatch '^[A-z]:\\') -or ($global:LogFile[0] -notin (Get-PSDrive -PSProvider FileSystem).Name)) {
            Write-Error "`tInvalid Log path"
        }
        Write-Log "`n$global:line`n$global:header"
    }
    $msg = "`n$global:line`n$global:header`n$global:line"
    if ($global:Test) {$msg} else {Write-Host $msg}
}
Function Out-Results {
    $global:end_time = Get-Date
    $global:total_time = ($global:end_time - $global:start_time).totalseconds
    $global:rate = "$($global:total_size / $global:total_time) MB/S"
    if ($null -ne $global:total_size) {
        $msg = "`t{0:f5} MB transfered in $global:total_time seconds. ($rate)`n$global:line" -f $global:total_size
        if ($global:Test) {$msg} else {Write-Host $msg}        
        if ($global:LogFile -ne $false) {
            Write-Log $msg
        }
    }
    else {
        $msg = "`tNo files transfered`n$global:line"
        if ($global:Test) {$msg} else {Write-Host $msg}
        if ($global:LogFile -ne $false) {
            Write-Log $msg
        }
    }
}
Function Out-Summary ($NoRecursion) {
    "Summary:"
    # $i = 0
    # foreach ($p in $global:to_copy) {
    #     "`tCopied {0:f2} MB: '{1}' to '{2}'" -f $global:size_copy[$i], $p,$global:to_copy_to[$i]
    #     $i++
    # }
    # $i = 0
    # foreach ($p in $global:to_move) {
    #     "`tMoved {0:f2} MB: '{1}' to '{2}'" -f $global:size_move[$i], $p,$global:to_move_to[$i]
    #     $i++
    # }
    # $i = 0
    # if ($Delete) {
    #     foreach ($p in $global:to_remove) {
    #         "`tDeleted: '$p'"
    #         $i++
    #     }
    # }
    # if ($DeleteConfirm) {
    #     foreach ($p in ($global:removed | Sort-Object | Get-Unique)) {
    #         "`tDeleted: '$p'"
    #     }
    # }
    Out-Comparison
}
Function Out-Comparison {
    $global:DF = get-childitem $destination -Recurse -File
    $global:DD = get-childitem $destination -Recurse -Directory
    $global:SF = get-childitem $path -Recurse -File
    $global:SD = get-childitem $path -Recurse -Directory
    $msg = "`tSource '$Path' File Count: $($SF.count) and Directory Count: $($SD.count)"
    if ($global:Test) {$msg} else {Write-Host $msg}
    $msg = "`tDestination '$Destination' File Count: $($df.count) and Directory Count: $($DD.count)"
    if ($global:Test) {$msg} else {Write-Host $msg}
    Out-Results
}
Function Confirm-Delete {
    if ($null -ne $global:to_remove) {
        "`n`tThe following files/directories will be deleted:`n"
        $global:to_remove = $global:to_remove | sort | Get-Unique
        $total_removed = $null
        foreach ($f in $global:to_remove) {
            $size = ($f.length / 1MB)
            "`t$f ($size MB)"
        }
        $msg = "`nAre you sure you want to delete these files?`nOptions are Y (Yes), N (No), or S (Select individual files to delete): "
        $ans = Read-Host $msg
        while (($ans -notmatch '[yY]') -xor ($ans -notmatch '[nN]') -xor ($ans -notmatch '[Ss]')) {
            $msg = "That is not a valid option.  Options are 'Y' for Yes, 'N' for No, or 'S' for Select individual files to delete: "
            $ans = Read-Host $msg
        }
        if ($ans -match '[yY]') {
            foreach ($f in $global:to_remove) {
                $size = ($f.length / 1MB)
                "`tDeleting '$f'"
                $global:removed += $f
                $global:total_removed += $size
                Remove-Item -path $f -ErrorAction SilentlyContinue -Force -Recurse 
            }   
            "`tDeleted $size MB"
        }
        elseif ($ans -match '[Nn]') {
            "`tContinuing without deleting any files."
        }
        elseif ($ans -match '[sS]') {
            foreach ($f in $global:to_remove) {
                $msg = "Would you like to delete '$f'?"
                $ans = Read-Host $msg
                while (($ans -notmatch '[yY]') -and ($ans -notmatch '[nN]')) {
                    $msg = "That is not a valid option!  Options are 'Y' for Yes, 'N' for No"
                    $ans = Read-Host $msg
                }
                if ($ans -match '[yY]') {
                    "`tDeleting '$f'"
                    $global:removed += $f
                    Remove-Item $f -ea silentlycontinue
                }
                else {
                    "`tKeeping '$f'"
                }
            }
        }
    }
}
# Function Get-Sources ($Path, $Depth) {
#     #RETURNS AN ARRAY OF STRING PATHS
#     If ($Depth -eq 0) {
#         $keep = Get-ChildItem $path -Depth $Depth -Directory
#     }
#     else {
#         $root = Get-ChildItem $Path -Directory -Depth ($Depth-1)
#         $sub = Get-ChildItem $Path -Directory -Depth $Depth
#         $keep = Compare-Object $sub $root -PassThru 
#     }
#     return $keep.fullname
# }
function Get-Verbose {
    [CmdletBinding()]
    param()
        if ([System.Management.Automation.ActionPreference]::SilentlyContinue -ne $VerbosePreference) {
            return $true
        }
        else {
            return $false
        }
}
Function Remove-ArchiveProperty ($file) {
    $attribute = [io.fileattributes]::Archive 
    foreach ($f in $file) {
        #Write-Host "File $($f.name) attributes: $($f.Attributes)"
        if ($f.Attributes -eq "Archive") {
            #Write-host "`tRemoving Archive Bit for $($F.FullName)"
            Set-ItemProperty "$f.FullName" -Name attributes -Value ((Get-ItemProperty "$f.FullName" -ea silentlycontinue).Attributes -bxor $attribute) -ea silentlycontinue
        }
    }
}
Function Get-CopybyArchiveStatus ($file, $dest_file_path, $Destination_full,  $NoArchiveReset) {
    if ($file.attributes -eq "Archive") {
        $msg = "`tCopying '{3}' ({2:f2} MB) from '{0}' to '{1}' because the archive bit is set." -f $File.fullname, $dest_file_path,$global:current_size, $file.name
        $global:total_size += $global:current_size  
        $global:size_copy += $current_size
        $global:to_copy += $file.fullname
        $global:to_copy_to += $dest_file_path
        if ($global:Test) {$msg} else {Write-Host $msg}        
        Copy-Item "$file.FullName" "$Destination_full" -ErrorAction Stop -Force   
        if (!$NoArchiveReset) {  
            Remove-ArchiveProperty ($file, (get-item $dest_file_path -ea SilentlyContinue))
        }
        else {
            Remove-ArchiveProperty (get-item $dest_file_path -ea SilentlyContinue)
        }
        if ($global:LogFile -ne $false) {
            Write-Log $msg
        }
    }  
}
Function Get-CopybyDateStatus ($file, $dest_file_path, $Destination_full, $NoArchiveReset) {
    #need to escape all characters in dest_file_path [] not getting properly handled
    if (Get-Item "$dest_file_path" -ErrorAction SilentlyContinue) {
        $dest_file_time = (Get-Item -Path "$dest_file_path" -ErrorAction SilentlyContinue).LastWriteTime
        if ($file.LastWriteTime -gt $dest_file_time) { 
            $msg = "`tCopying '{3}' ({2:f2} MB) from '{0}' to '{1}' because the source version is newer." -f $File.fullname, $dest_file_path,$global:current_size, $file.name
            $global:total_size += $global:current_size 
            $global:to_copy += $file.fullname
            $global:to_copy_to += $dest_file_path
            $global:size_copy += $current_size
            if ($global:Test) {$msg} else {Write-Host $msg}        
            Copy-Item "$file.FullName" "$Destination_full" -ErrorAction SilentlyContinue -Force            
            if (!$NoArchiveReset) {  
                Remove-ArchiveProperty ($file, (get-item $dest_file_path -ea SilentlyContinue))
            }
            else {
                Remove-ArchiveProperty (get-item $dest_file_path -ea SilentlyContinue)
            }
            if ($global:LogFile -ne $false) {
                Write-Log $msg
            }
        }
    }
    else { 
        $msg = "`tCopying '{3}' ({2:f2} MB) from '{0}' to '{1}' because it is not in the destination." -f $File.fullname, $dest_file_path,$global:current_size, $file.name
        if ($global:Test) {$msg} else {Write-Host $msg}        
        $global:to_copy += $file.fullname
        $global:to_copy_to += $dest_file_path
        $global:size_copy += $current_size
        Copy-Item "$($file.FullName)" "$Destination_full" -ErrorAction SilentlyContinue -Force
        $global:total_size += $global:current_size 
        if (!$NoArchiveReset) {  
            Remove-ArchiveProperty ($file, (get-item $dest_file_path -ea SilentlyContinue))
        }
        else {
            Remove-ArchiveProperty (get-item $dest_file_path -ea SilentlyContinue)
        }
        if ($global:LogFile -ne $false) {
            Write-Log $msg
        }
    }
}
Function Get-MoveStatus ($file, $item, $Destination_full, $dest_file_path, $KeepNewer, $moved) {
    If ($KeepNewer) {
        if (($file.LastWriteTime -le $item.LastWriteTime) -and !(get-item ($dest_file_path) -ErrorAction SilentlyContinue)) {   
            $msg = "`tMoving '$($file.name)' from '$($item.fullname)' to '$dest_file_path' because it is newer or the same age."   
            if ($global:Test) {$msg} else {Write-Host $msg}        
            $global:to_move += $item.fullname
            $global:to_move_to += $dest_file_path
            $global:size_move += $current_size
            Move-Item -Path $item.fullname -Destination $Destination_full
            if (!$NoArchiveReset) {  
                Remove-ArchiveProperty ($file, (get-item $dest_file_path -ea SilentlyContinue))
            }
            else {
                Remove-ArchiveProperty (get-item $dest_file_path -ea SilentlyContinue)
            }
            if ($global:LogFile -ne $false) {
                Write-Log $msg             
            } 
            $moved = $true
        }
    }
    Else {
        if (($file.LastWriteTime -eq $item.LastWriteTime) -and !(get-item ($dest_file_path) -ErrorAction SilentlyContinue)) { 
            $msg = "`tMoving '$($file.name)' from '$($item.fullname)' to '$dest_file_path' because it is the same age." 
            if ($global:Test) {$msg} else {Write-Host $msg}                    
            $global:to_move += $item.fullname
            $global:to_move_to += $dest_file_path
            $global:size_move += $current_size
            Move-Item -Path $item.fullname -Destination $Destination_full 
            if (!$NoArchiveReset) {  
                Remove-ArchiveProperty ($file, (get-item $dest_file_path -ea SilentlyContinue))
            }
            else {
                Remove-ArchiveProperty (get-item $dest_file_path -ea SilentlyContinue)
            }
            if ($global:LogFile -ne $false) {
                Write-Log $msg
            }    
            $moved = $true
        }
    } 
    return $moved
}
Function Get-Parameters ($Move, $Delete, $DeleteConfirm, $GUI, $KeepNewer, $Verify, $NoArchiveReset) {
    if ($Move) {
        $M = "-Move"
        $global:Options += $M
    }
    else {
        $M = $null
        
    }
    if ($Delete) {
        $D = "-Delete"
        $global:Options += $D
    }
    else {
        $D = $null
    }
    if ($DeleteConfirm) {
        $DC = "-DeleteConfirm"
        $global:Options += $DC
    }
    else {
        $DC = $null
    }
    if ($GUI) {
        $G = "-GUI"
        $global:Options += $G
    }
    else {
        $G = $null
    }
    if ($KeepNewer) {
        $K = "-KeepNewer"
        $global:Options += $K
    }
    else {
        $K = $null
    }
    if ($Verify) {
        $V = "-Verify"
        $global:Options += $V
    }
    else {
        $V = $null
    }
    if ($NoArchiveReset) {
        $NAR = "-NoArchiveReset"
    }
    else {
        $NAR = $null
    }
    if (Get-Verbose) {
        $VB = "-Verbose"
    }
    else {
        $VB = $null
    }
    if ("$M $D $DC $G $K $V $NAR $VB".Length -eq 7) {
        return $null
    }
    else {
        return "$M $D $DC $G $K $V $NAR $VB"
    }
}
function Get-HashComparison ([string]$f1, [string]$f2) {
    #Write-Verbose "Comparing hashes for: $f1 and $f2"
    if ((Get-FileHash $f1 -Algorithm SHA1 -ErrorAction SilentlyContinue).hash -eq (Get-FileHash $f2 -Algorithm SHA1 -ErrorAction SilentlyContinue).hash) {
        return $true
    }
    else {
        return $false
    }
}
function Get-Verification ($Path, $Destination) {
    Write-host "Verification:" 
    $p_all = Get-ChildItem $path -Recurse
    $d_all = Get-ChildItem $destination -Recurse
    $global:comp_name = Compare-Object $p_all $d_all -Property name
    $global:comp_length = Compare-Object $p_all $d_all -Property length
    #if the directories have the same file names and file lengths
    if (($comp_name.count -eq 0) -and ($comp_length.count -eq 0)) {
        Write-Host "`tGenerating Hashes... This may take a few minutes depending on the size of the directories..."
        $p_hash = (Get-DirHash $path).hash
        $d_hash = (Get-DirHash $destination).hash
        Write-Host "`tHash of '$path': $p_hash`n`tHash of '$destination': $d_hash"
        if ($p_hash -eq $d_hash) {
            $msg = "`tSuccess: '$path' is a perfect backup of '$destination'"
            if ($global:Test) {$msg} else {Write-Host $msg}        
        }
        else {
            $msg = "`tFailure: '$path' is NOT a perfect backup of '$destination'"
            if ($global:Test) {$msg} else {Write-Host $msg}        
        }
        Write-Host "$global:line`n"
    }
    else {
            $msg = "`tGetting Difference(s)... This may take a few minutes depending on the size of the directories..."
            if ($global:Test) {$msg} else {Write-Host $msg}        
            Get-Difference $p_all $d_all $path $destination
    }
}

Function Get-Difference ($p_all, $d_all, $path, $destination) {
    [array]$global:diff_length , [array]$global:diff, [array]$global:length_to_find,[array]$global:name_to_find = @()
    $files = Get-ChildItem $path -File -ea SilentlyContinue
    $dest_files = Get-ChildItem $destination -File -ea SilentlyContinue
    #Creating array of lengths from compare-object -propery length
    foreach ($c in $global:comp_length) {
        if ($c.sideindicator -eq "=>") {
            $global:length_to_find+= $c.length
        }
    }
    foreach ($c in $global:comp_name) {
        if ($c.sideindicator -eq "=>") {
        $global:name_to_find += $c.name
        }
    }
    Get-Diffs $files $dest_files              
    #checks recursions
    foreach ($d in $d_all) {
        if ($d.psiscontainer) {
            $p = $d.fullname -ireplace [regex]::Escape($destination), $path
            If (!(test-path $p)) {
                $global:diff += $d.fullname
            }
            else {
                $files = Get-ChildItem $p -File -ea SilentlyContinue
                $dest_files = Get-ChildItem $d.fullname -File -ea SilentlyContinue
                Get-Diffs $files $dest_files              
            }
        }   
    }
    foreach ($d in $diff) {
        $p = $d -ireplace [regex]::Escape($destination), $path
        "`tDifference: '$d' does not exist in source"
    }
    Get-Correction $diff $diff_length
}
Function Get-Diffs ($files, $dest_files) {
    #checks length of file to see if it is same length any in $to_add
    foreach ($f in $dest_files) {
        if (($f.length -iin $global:length_to_find)) {
            $p = $f.FullName -ireplace [regex]::Escape($destination), $path
            "current file: $($f.name) and all files: $($files.name) "
            sts 2
            if ($files.name -notcontains $f.name) {
                $global:diff += $f.fullname
                if ($global:Test) {"Adding $f"}
            }
            #checks that source path exists and that the hash of source and dest files are not the same.
            if ((Test-path $p) -and ((Get-filehash $f.FullName -Algorithm sha1).hash -ne (Get-FileHash $p -Algorithm sha1).hash)) {
                $msg = "`tDifference: file '$($f.fullname)' differs in content from '$p'"
                if ($global:Test) {$msg} else {Write-Host $msg}        
                $global:diff_length += $f
            }
            
        }
    }
}
Function Get-Correction ($diff, $diff_length) {
    #Getting input about correcting differences and executing choice
    if (($null -ne $diff_length) -or ($null -ne $diff)) {
        #getting the correct $msg
        Write-host $global:line
        $c = "User Input:"
        if (($null -ne $diff) -and ($null -ne $diff_length)) {
            $msg = "$c Correct differences by copying over the files from '$path' that differ and deleting files in '$destination' not in '$path'?"
        }
        elseif ($null -ne $diff_length) {
            $msg = "$c Correct differences by copying over the files from '$path' that differ?"
        }
        elseif ($null -ne $diff) {
            $msg = "$c Correct differences by deleting files in '$destination' that do not exist in '$path'?"
        }
        #Getting user input
        $ans = Read-Host $msg
        while ($ans -notmatch '[yYNn]') {
            Write-Host "$ans is not a valid response.  Please try again."
            $ans = Read-Host $msg
        }
        #Carrying out user choice
        if ($ans -match '[Yy]') {
            if (($null -ne $diff) -and ($null -ne $diff_length)) {
                foreach ($f in $diff_length) {
                    $p = $f.FullName -ireplace [regex]::Escape($destination), $path
                    $msg = "`tCopying over $f from '$p'"
                    Write-Host $msg
                    Copy-Item "$p" "$($f.fullname)" -ea SilentlyContinue -Force
                }
                foreach ($f in $diff) {
                    $msg = "`tDeleting $f"
                    Write-Host $msg 
                    Remove-Item $f -ea silentlycontinue | out-null
                }
            }
            elseif ($null -ne $diff_length) {
                foreach ($f in $diff_length) {
                    $p = $f.FullName -ireplace [regex]::Escape($destination), $path
                    $msg = "`tCopying over $f from '$p'"
                    Write-Host $msg
                    Copy-Item "$p" "$f.fullname" -ea SilentlyContinue -Force
                }
            }
            elseif ($null -ne $diff) {
                foreach ($f in $diff) {
                    $msg = "`tDeleting $f"
                    Write-Host $msg
                    Remove-Item "$f" -ea SilentlyContinue | out-null
                }
            }
            Write-Host $global:line
            Get-Verification $path $destination
        }
        elseif ($ans -match '[nN]') {
            $msg = "`tDifferences retained"
            Write-Host "$msg`n$global:line`n"
        }
    }
    else {
        "There is nothing to correct"
    }
}
Function Get-DirHash {
    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({
            if(Test-Path -Path $_ -ErrorAction SilentlyContinue)
            {
                return $true
            }
            else
            {
                throw "$($_) is not a valid path."
            }
        })]
        [string]$Path
    )
    $temp=[System.IO.Path]::GetTempFileName()
    Get-ChildItem -File -Recurse $Path | Get-FileHash -Algorithm SHA1 | Select-Object -ExpandProperty Hash | Out-File $temp -NoNewline
    $hash=Get-FileHash $temp -Algorithm SHA1
    Remove-Item "$temp" -ea silentlycontinue
    $hash.Path=$Path
    return $hash
}

function Invoke-BackupFolder {
    [CmdletBinding(SupportsShouldprocess=$true, Confirmimpact="Medium")]
    Param(
        #Source directory to copy.  Can accept multiple values from a pipeline.
        [parameter(mandatory=$false,position=0,Valuefrompipeline=$true, Valuefrompipelinebypropertyname=$true)][string]$Path=$false,
        #Destination directory to copy.  Can accept multiple values from a pipeline.
        [parameter(mandatory=$false,position=1,Valuefrompipeline=$true, Valuefrompipelinebypropertyname=$true)][string]$destination=$false,
        #Default Mode is by date (copies only newer files), but "Archive" copies files with archive bit set
        [parameter(mandatory=$false)][validateset("Archive","Date")]$Mode = "Date", 
        #Moves any files with the same name that don't already exist at the destination
        [switch]$Move = $false,
        #shows what differs if anything between source and destination
        [switch]$Verify = $false,
        #Deletes folders and files in the destitation that are not in the source (only compares files name)
        [switch]$Delete = $false,
        #Asks whether you want to delete files and directories before deleting them
        [switch]$DeleteConfirm = $false,
        #Uses the GUI to get Source and Destination Directories
        [switch]$GUI = $false,
        #Keeps newer files in the database that have been moved from one directory to another.  Default is to copy over file from source even if it is older
        [switch]$KeepNewer = $false,
        #This is not user setable.  Set automatically when Backup-Folder is run
        [switch]$NoArchiveReset = $false,
        #this is used by another function
        [switch]$NoRecursion = $false
    )
    Get-Continue $path $destination $GUI
    $global:start_time = get-date
    Reset-Variables
    if ($NoRecursion) {
        $files = Get-ChildItem -Path $Path -File
        $folders = Get-ChildItem -Path $Path -Attributes Directory
        $dest_files = Get-ChildItem -Path $destination -File 
    }
    else {
        $files = Get-ChildItem -Path $Path -Recurse -File
        $folders = Get-ChildItem -Path $Path -Recurse -Attributes Directory
        $dest_files = Get-ChildItem -Path $destination -Recurse -File 
    }
    New-Directory $folders $Path
    if ($Delete -or $DeleteConfirm) {
        Remove-Files $files $dest_files
        if ($Delete -and !$DeleteConfirm) {
            $dest_files = Get-ChildItem -Path $destination -Recurse -File 
        }
    }
    foreach ($file in $files) {
        $dest_file_path,$Destination_full = Get-DestFile $file $Path $destination
        $moved = $false
        $global:current_size = ($file.Length / 1MB)
        #Move is exponential (need to delete or rework)
        if ($Move) { 
            if ($dest_files.name -eq $file.Name) {
                #"On: $($file.name) and Dest_files name: $($dest_files.name)"
                foreach ($item in $dest_files) {
                    #"$($file.name) and $item"
                    #Write-Host "$($file.fullname) and $($item.fullname) are the same file: $(get-hashcomparison $($file.fullname) $($item.fullname))"
                    if ($item.name -eq $file.name) {                        
                        $moved = Get-MoveStatus $file $item $Destination_full $dest_file_path $KeepNewer $moved
                        continue
                    }
                }        
            }  
        }
        if ($moved -eq $true) {
            continue
        } 
        else {
            if ($Mode -eq "Archive") {
                If ($KeepNewer) {
                    $item = get-item $dest_file_path -ErrorAction SilentlyContinue
                    #Write-Host "$($file.fullname) is newer than or equal to $($item.fullname): $($file.LastWriteTime -ge $($item.LastWriteTime))"
                    if (($file.LastWriteTime -ge $item.LastWriteTime)) {
                        Get-CopybyArchiveStatus $file $dest_file_path $Destination_full $NoArchiveReset 
                    }
                }
                else {
                    Get-CopybyArchiveStatus $file $dest_file_path $Destination_full $NoArchiveReset
                }
            }
            else {
                Get-CopybyDateStatus $file $dest_file_path $Destination_full $NoArchiveReset
            }  
        }
    } 
    if ($Delete -or $DeleteConfirm) {
        $dir = Get-ChildItem $destination -Recurse
        Remove-After $Path $destination $dir 
    }   
    if ($DeleteConfirm) {
        Confirm-Delete
    }   
    Out-Summary $NoRecursion
    if (!$NoArchiveReset) {
        $file = Get-ChildItem $Path -File -Recurse -Attributes Archive
        Remove-ArchiveProperty $file
    }  
}
function Start-InvokeBackup {
    [CmdletBinding(SupportsShouldprocess=$true, Confirmimpact="Medium")]
    Param(
        #Source directory to copy.  Can accept multiple values from a pipeline.
        [parameter(mandatory=$false,position=0,Valuefrompipeline=$true, Valuefrompipelinebypropertyname=$true)][string]$Path=$false,
        #Destination directory to copy.  Can accept multiple values from a pipeline.
        [parameter(mandatory=$false,position=1,Valuefrompipeline=$true, Valuefrompipelinebypropertyname=$true)][string]$destination=$false,
        #Default Mode is by date (copies only newer files), but "Archive" copies files with archive bit set
        [parameter(mandatory=$false)][validateset("Archive","Date")]$Mode = "Date", 
        #used by this function only
        [switch]$Recur=$false,
        #Moves any files with the same name that don't already exist at the destination
        [switch]$Move = $false,
        #shows what differs if anything between source and destination
        [switch]$Verify = $false,
        #Deletes folders and files in the destitation that are not in the source (only compares files name)
        [switch]$Delete = $false,
        #Asks whether you want to delete files and directories before deleting them
        [switch]$DeleteConfirm = $false,
        #Uses the GUI to get Source and Destination Directories
        [switch]$GUI = $false,
        #Keeps newer files in the database that have been moved from one directory to another.  Default is to copy over file from source even if it is older
        [switch]$KeepNewer = $false,
        #This is not user setable.  Set automatically when Backup-Folder is run
        [switch]$NoArchiveReset = $false,
        #this is used by another function
        [switch]$NoRecursion = $false
    )
    if ($recur -eq $false) {
        #Copying over from scratch if destination folder doesn't exist
        if (!(test-path $destination)) {
            $msg =  "`tCopying '$path' to '$destination'"
            if ($Test) {$msg} else {Write-Host $msg}
            copy-item "$path" "$destination" -Recurse 
            Write-Host "`tCopy of '$path' to '$destination' complete`n$global:line"
            return
        }
        else {
            $p_dirs = (Get-ChildItem $path -Directory -Recurse).fullname
            #creating empty directories in destination
            foreach ($p in $p_dirs) {
                $d = $p -ireplace [regex]::Escape($path), $destination
                New-item "$d" -ItemType Directory -ea SilentlyContinue | Out-Null
            }
            #Running on root folder
            $cmd = "Invoke-BackupFolder '$path' '$destination' -Mode $Mode $global:parameters -NoRecursion"
            Invoke-Expression $cmd
        }      
    }
    # Write-Host "Only need to find these files"
    # $lengths = @()
    # foreach ($item in $global:comp_length) {
    #     if ($item.sideindicator -eq "=>") {
    #         $Lengths += $item
    #     }
    # }
    # write-host $lengths
    # foreach ($item in $global:comp_name) {
    #     # Write-host "Item: $item"
    #     if ($item.sideindicator -eq "=>") {
    #         Write-Host "$($global:comp_name[$i].name) $($global:comp_length[$i].length)"
    #     }
    #     $i++
    # }

    $p_all = (Get-ChildItem $path -Directory -Depth 0).fullname
    foreach ($p in $p_all) {
        $d = $p -ireplace [regex]::Escape($path), $destination
        $dest_files = Get-ChildItem $d -ea SilentlyContinue -recurse
        $files = Get-ChildItem $p -ea SilentlyContinue -Recurse
        $dest_files_size = ($dest_files | Measure-Object -Property length -Sum -ErrorAction SilentlyContinue).sum
        $files_size = ($files | Measure-Object -Property length -Sum -ErrorAction SilentlyContinue).sum
        #Write-host "Path: $p count: $($files.count) length: $($files_size) and dest $d count: $($dest_files.count) size: $($dest_files_size)"
        #Compares subfolder file counts and sizes
        if (($files.count -eq $dest_files.count) -and ($files_size -eq $dest_files_size)) {
            $comp_name2 = Compare-Object $files $dest_files -Property name -ea SilentlyContinue
            $comp_length2 = Compare-Object $files $dest_files -Property length -ea SilentlyContinue
            if (($comp_name2 -ne 0) -or ($comp_length2 -ne 0)) {
                #Comparing further based on file name and length of each file in subdir
                $p_sub = Get-childitem $p -Directory -Depth 0
                if ($null -ne $p_sub) {
                    $d_sub = $p_sub -ireplace [regex]::Escape($p), $d
                    Start-InvokeBackup "$p_sub" "$d_sub" -Recur
                }
                else {
                    $global:to_invoke_path += $p
                    $global:to_invoke_dest += $d
                }
            } 
            else {
                $msg = "'$p' and '$d' are the same.  This branch stops"
                if ($Test) {$msg} else {Write-Host $msg}
            }
        }
        else {
            #check dest path if file count and total size of source and dest differ
            if (!(test-path $d)) {
                $global:to_invoke_path_empty += $p
                $global:to_invoke_dest_empty += $d
            }
            else {
                $global:to_invoke_path += $p
                $global:to_invoke_dest += $d
                Start-InvokeBackup "$p" "$d" -Recur
            }
        }
    }
    if ($recur -eq $false) {
        $i =0
        #getting Folders that don't have the same set of files (based on names and sizes)
        Foreach ($p in $global:to_invoke_path) {
            $p_file = Get-ChildItem $p -File -ea SilentlyContinue
            $d = $p -ireplace [regex]::Escape($path), $destination
            $d_file = Get-ChildItem $d -File -ea SilentlyContinue
            if (($d_file.count -ne $p_file.count) -or ($d_file.length -ne $p_file.Length)) {
                $global:to_invoke_path_empty += $global:to_invoke_path[$i]
                $global:to_invoke_dest_empty += $global:to_invoke_dest[$i]
            }
            $i++
        }
        $i = 0
        #Calling Invoke-Backupfolder on folders with differences
        foreach ($p in $global:to_invoke_path_empty) {
            # Write-Host "invoke_path_empty: $global:to_invoke_path_empty and dest: $($global:to_invoke_dest_empty[$i])"
            $cmd = "Invoke-BackupFolder '$p' '$($global:to_invoke_dest_empty[$i])' -Mode $Mode $global:parameters -NoRecursion"
            Write-Host $cmd
            Invoke-Expression $cmd
            $i++
        }
    }   
}



 Set-Alias bf backup-Folder
 set-alias rf Reset-Folders
 Function Test {
     param(
         [switch]$Date=$false,
         [switch]$Archive=$false,
         [switch]$File=$false
     )
    if ($File) {
        rf
        bf -file "C:\users\Adam\test\new folder\new.txt"
        $ans = $true
        $files = Get-ChildItem "C:\Users\adam\test" -file -Recurse -Attributes Archive
        $files2 = $null
        foreach ($f in $files ) {
            if ($f.Attributes -eq "Archive") {
                $ans = $false
                $files2 += "'$($f.FullName)', "
            }
        }
        "All Dest Files are Normal: $ans, Except: $files2"
    }
    else {
        rf
        $path = "c:\users\adam\test"
        $destination = "d:\test"
        $log = "C:\log.txt"
        if ($Date) {
            Backup-Folder $Path $destination -Delete -KeepNewer -LogPath $log
            Write-Host "$global:line`nDebug:`n`tRan Date mode"
        }
        elseif ($Archive) {
            Backup-Folder $Path $destination -Delete -Mode Archive -KeepNewer -LogPath $log
            Write-Host "$global:line`nDebug:`n`tRan Archive mode"
        }
        $source = Get-ChildItem $Path -File -Recurse
        $dest = Get-ChildItem $destination -File -Recurse
        $i=0
        $files = $null
        $ans = $true
        foreach ($f in $source) {
            if ($f.Attributes -eq "Archive") {
                $ans = $false
                $files += "'$($f.FullName)', "
            }
            $i+=1
        }
        "`tAll Source Files are Normal: $ans, Except: $($files)"
        $i=0
        $files = $null
        $ans = $true
        foreach ($f in $dest) {
            if ($f.Attributes -eq "Archive") {
                $ans = $false
                $files += "'$($f.FullName)', "
            }
            $i+=1
        }
        "`tAll Dest Files are Normal: $ans, Except: $files"
    }
}
function Reset-Folders{
    #Copy-Item 'F:\Backup test' F:\Test -recurse -Force | Out-Null
    $destination = 'd:\test'
    $Path = 'C:\users\adam\test'
    remove-item "d:\*" -Recurse -ea SilentlyContinue | out-null
    Remove-Item -Path $destination -Recurse -Force -ea SilentlyContinue | out-null
    Remove-Item -Path $Path -Recurse -Force -ea SilentlyContinue | out-null
    New-Item "$Path" -ItemType Directory -Force -ea SilentlyContinue | out-null
    New-Item "$Path\1" -ItemType Directory -Force -ea SilentlyContinue | out-null
    New-Item "$Path\1\1.2" -ItemType Directory -Force -ea SilentlyContinue | out-null
    New-Item "$Path\2" -ItemType Directory -Force -ea SilentlyContinue | out-null
    New-Item "$Path\file.txt" -ItemType File -Value "file.txt" -Force -ea SilentlyContinue | out-null
    (get-item "$Path\file.txt").LastWriteTime = (get-date).AddDays(1)
    Copy-Item -Recurse $Path $destination -Force -ea SilentlyContinue | out-null
    Remove-item "$destination\file.txt" -ea SilentlyContinue | out-null
    New-item "$destination\file.txt" -Value "Different" -ea SilentlyContinue | out-null
    New-Item "$Path\2\file2.txt" -ItemType File -Value "file2.txt orig" -ea SilentlyContinue -Force | out-null
    New-Item "$destination\file2.txt" -ItemType File -Value "file2.txt" -Force -ea SilentlyContinue | out-null
    New-Item "$Path\not_move_newer.txt" -ItemType File -Value "not move newer.txt" -Force -ea SilentlyContinue | out-null
    New-Item "$Path\1\1.2\copy2.txt" -ItemType File -Value "copy2 newer.txt" -Force -ea SilentlyContinue | out-null
    New-Item "$Path\new folder\" -ItemType Directory -Force -ea SilentlyContinue | out-null
    New-Item "$Path\new folder\new.txt" -ItemType File -Value "`"$path`" `"$destination\date`" -delete`n`"$path\non-existant`" `"$destination\error_path`"`n`"$path`" `"$destination\archive-delete`" -delete -mode archive`n`"$path`" `"$destination\archive`" -mode archive`n`"$path`" `"$destination\move`" -move`n`"$path`" `"$destination\move-delete`" -move -delete`n`"$path`" `"$destination\error_option`" dfdfkdj`n`"c:\test`" `"$destination`"" -Force -ea SilentlyContinue | out-null
    New-Item "$destination\not_in_source\" -ItemType Directory -Force -ea SilentlyContinue | out-null
    New-Item "$destination\not_in_source\not_in_source.txt" -ItemType File -Value "not_in_source.txt" -Force -ea SilentlyContinue| out-null
    New-Item "$destination\1\1.2\not_move_newer.txt" -ItemType File -Value "move newer.txt"  -Force -ea SilentlyContinue | out-null
    New-Item "$destination\1\1.2\copy2.txt" -ItemType File -Value "copy 2.txt" -Force -ea SilentlyContinue | out-null
    (get-item "$destination\1\1.2\not_move_newer.txt").LastWriteTime = (get-date).AddDays(1)
    (get-item "$destination\1\1.2\copy2.txt").LastWriteTime = (get-date).AddDays(-1)
    (get-item "$destination\not_in_source\not_in_source.txt").LastWriteTime = (get-date).AddDays(1)
    new-item "$Path\move2.txt" -ItemType file -Value "Move2.txt" -Force -ea SilentlyContinue | out-null
    new-item "$Path\not_move.txt" -ItemType file -Value "Not_Move.txt" -Force -ea SilentlyContinue | out-null
    new-item "$destination\1\1.2\not_move.txt" -ItemType file -Value "Not_Move.txt" -Force -ea SilentlyContinue | out-null
    (get-item "$destination\1\1.2\not_move.txt").LastWriteTime = (get-date).AddDays(-1)
    new-item "$destination\1\move2.txt" -ItemType file -Value "Move2.txt" -Force -ea SilentlyContinue | out-null
    (get-item "$Path\move2.txt").LastWriteTime = (get-item "$destination\1\move2.txt").LastWriteTime
    (get-item "$Path\2\file2.txt").LastWriteTime = (get-date).AddDays(-1)
    new-item "$Path\archive-set.txt" -ItemType file -Value "Archive-Set orig" -ea SilentlyContinue | out-null
    new-item "$Path\archive-not-set.txt" -ItemType file -Value "Archive-Not-Set" -ea SilentlyContinue | out-null
    new-item "$destination\archive-set.txt" -ItemType file -Value "Archive-Set" -ea SilentlyContinue | out-null
    Set-ItemProperty "$Path\archive-not-set.txt" -Name attributes -Value "Normal" -ea SilentlyContinue
    Set-ItemProperty "$Path\archive-set.txt" -Name attributes -Value "Archive" -ea SilentlyContinue
    (get-item "$Path\archive-set.txt").LastWriteTime = (get-item "$destination\archive-set.txt").LastWriteTime
    $fileobj = New-Object System.IO.FileStream "$path\move_big.txt", create, readwrite
    $fileobj.SetLength(12.25MB)
    $fileobj.Close()
}

#depth 0 with -file not working right
#add more detailed stats on rate of transfer (get-date/time before and after copy-item to get difference)


Function Get-Comparison ($p, $d) {
    "Getting comps for $p and $d"
    $global:p_all, $global:d_all, $global:comp_name, $global:comp_length = $null
    $global:p_all = Get-ChildItem $p
    $global:d_all = Get-ChildItem $d
    if ($d_all -eq $null) {
        $d_all = $d
    }
    "P_all: $p_all and d_all: $d_all"
    $global:comp_name = Compare-Object $global:p_all $global:d_all -Property name
    $global:comp_length = Compare-Object $global:p_all $global:d_all -Property length
}
function Start-Job {
    #uses names of files to find uncopied and excess files
    param(
        [parameter(Mandatory=$true)][validateset("Copy", "Delete", "DeleteConfirm")]$Job = $null,
        [parameter(Mandatory=$true,Position=0)]$Path = $null,
        [parameter(Mandatory=$true,Position=1)]$Destination = $null
    )
    "Start-Job Path: $Path and $Destination"
    [array]$name_list, [array]$length_list = @()
    if ($Job -eq "Copy") {
        $arrow = "<="
        $source = $global:p_all
        $p1 = $path
        $p2 = $destination
    }
    elseif (($Job -ieq "Delete") -or ($Job -ieq "DeleteConfirm")) {
        $arrow = "=>"
        $source = $global:d_all
        $p1 = $destination
        $p2 = $path
    }
    foreach ($f in $global:comp_name) {
        if (($f.sideindicator -eq $arrow) -and ($null -ne $f.name)) {
            $name_list += $f.name
            # $f
        }
    }
    #creates array of lengths in dest that don't match source
    foreach ($f in $global:comp_length) {
        if (($f.sideindicator -eq $arrow) -and ($null -ne $f.length)) {
            $length_list += $f.length
        }
    }
    # Write-Host "`n$global:comp_name`n$name_list"
    foreach ($f in $source) {
        if ($f.name -in $name_list) {
            #"$($f.fullname) is in to_delete_name"
            # if ($f.length -in $length_list) {
            # "$($f.fullname) is in to_delete_length"
            $f_escaped = $f.fullname -replace "[\`[]", "``["
            $f_escaped = $f_escaped -replace "[\]]", "``]"
            $d = $f.fullname -ireplace [regex]::Escape($p1),$p2
            # "Testing path for $d"
            # if (!(test-path $d)) {
                # "$d doesn't exit"
                if ($job -eq "Copy") {
                    $msg = "`tCopied: '$($f_escaped)' to '$d'"
                    #Copy-item $f_escaped $d
                }
                elseif ($Job -eq "Delete") {
                    $msg = "`tDeleted: '$($f_escaped)' as there is no correspondent in the source"
                    #Remove-item $f_escaped -Recurse -Force
                }
                elseif ($Job -ieq "DeleteConfirm") {
                    $global:to_remove += $f_escaped
                }
                if ($Test) {$msg} else {Write-Host $msg}
            # }
            # }
        }        
    }
    if ($Job -ieq "DeleteConfirm") {
        Confirm-Delete
    }
}
<#
.Synopsis
   File Backup/Copying Tool with multiple options
.DESCRIPTION
   File copying tool with the ability to copy files based on archive attribute and/or date.  Can create exact mirrors of directories rather efficiently.  Option for batch directory copying
.EXAMPLE
PS>  Backup-Folder c:\users\adam\test d:\test

-----------------------------------------------------------------------
Backup-Folder c:\users\adam\test d:\test  run at 4/23/2019 12:49:49 PM:
-----------------------------------------------------------------------
Summary:
        Copied 0.00 MB: 'C:\users\adam\test\archive-not-set.txt' to 'd:\test\archive-not-set.txt'
        Copied 0.00 MB: 'C:\users\adam\test\move2.txt' to 'd:\test\move2.txt'
        Copied 12.25 MB: 'C:\users\adam\test\move_big.txt' to 'd:\test\move_big.txt'
        Copied 0.00 MB: 'C:\users\adam\test\not_move_newer.txt' to 'd:\test\not_move_newer.txt'
        Copied 0.00 MB: 'C:\users\adam\test\not_move.txt' to 'd:\test\not_move.txt'
        Copied 0.00 MB: 'C:\users\adam\test\1\1.2\copy2.txt' to 'd:\test\1\1.2\copy2.txt'
        Copied 0.00 MB: 'C:\users\adam\test\2\file2.txt' to 'd:\test\2\file2.txt'
        Copied 0.00 MB: 'C:\users\adam\test\new folder\new.txt' to 'd:\test\new folder\new.txt' 
        Source 'c:\users\adam\test' File Count: 10 and Directory Count: 4
        Destination 'd:\test' File Count: 15 and Directory Count: 5
        12.25041 MB transfered
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   System.String[ ]
        Does not allow for piping.  Use the -file parameter and put the individual arguments on separate lines.
.OUTPUTS
    No ouput
.NOTES
    Use this function if you want to ensure that the files in a directory get to the destination and retain the same directory structure without overriding files that have not changed but whose last writetime is newer.
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>
Function Backup-Folder { 
    [CmdletBinding(SupportsShouldprocess=$true, Confirmimpact="Medium")]
    Param(
        #Source directory to copy.  Can accept multiple values from a pipeline.
        [parameter(mandatory=$false,position=0)][string]$Path=$null,
        #Destination directory to copy.  Can accept multiple values from a pipeline.
        [parameter(mandatory=$false,position=1)][string]$destination=$null,
        #Default Mode is by date (copies only newer files), but "Archive" copies files with archive bit set
        [parameter(mandatory=$false)][validateset("Archive","Date")]$Mode = "Date",
        #enables logging of the actions
        [parameter(Mandatory=$false)][string]$LogPath=$false,
        #used to specify a file for multiple copy operations
        [parameter(Mandatory=$false)][string]$File="",
        #Moves any files with the same name that don't already exist at the destination
        [switch]$Move = $false,
        #shows what differs if anything between source and destination
        [switch]$Verify = $false,
        #Deletes folders and files in the destitation that are not in the source (only compares files name)
        [switch]$Delete = $false,
        #Asks whether you want to delete files and directories before deleting them
        [switch]$DeleteConfirm = $false,
        #Uses the GUI to get Source and Destination Directories
        [switch]$GUI = $false,
        #Keeps newer files in the database that have been moved from one directory to another.  Default is to copy over file from source even if it is older
        [switch]$KeepNewer = $false,
        #This is not user setable.  Set automatically when Backup-Folder is run
        [switch]$NoArchiveReset = $false,
        #Used for Pester testing
        [switch]$global:Test = $false
    ) 
    if ($PSCmdlet.ShouldProcess("'$Path' and destination '$destination' with '$($PSBoundParameters.keys)' set to: '$($PSBoundParameters.values)'")) {
        [array]$global:Options, [array]$global:paths, [array]$global:to_invoke_path,[array]$global:to_invoke_dest , [array]$global:to_invoke_path_empty, [array]$global:to_invoke_dest_empty, [array]$global:to_remove = @()
        $global:verbose = Get-Verbose
        $global:parameters = Get-Parameters $Move $Delete $DeleteConfirm $GUI $KeepNewer $Verify $NoArchiveReset
        #Creating Logfile if it doesn't exist
        If (!(get-item $global:LogFile -ErrorAction SilentlyContinue)) {
            new-item $global:LogFile -ItemType file -ErrorAction SilentlyContinue
        }
        $folders = Get-ChildItem -Path $Path -Recurse -Attributes Directory
        $global:Logfile = $LogPath
        "Path: $path dest: $destination"
        New-Directory $folders $path
        Get-Comparison $path $destination
        Copy-Item "$path\*" $destination 
        sts 10
        foreach ($p in $global:p_all) {
            if ($p.psiscontainer) {
                $d = $p.fullname -ireplace [regex]::Escape($path), $destination
                "$($p.fullname) is a dir and $d is dest"
                Get-Comparison "$($p.fullname)" "$d"
                Start-Job $p.fullname $d -job "Copy"
                if ($Delete) {
                    Start-Job $p.fullname $d  -job "Delete"
                }
                if ($DeleteConfirm) {
                    Start-Job $p.fullname $d -job "DeleteConfirm"
                }
            }
        }
        # "waiting..."
        # sts 1000
        # if (($comp_name.count -eq 0) -and ($comp_length.count -eq 0) -and !$Verify) {
        #     "`t'$path' and '$destination' are most likely perfect backups.  Run with -verify to be certain."
        # }
        # else {
        #     if (($File -ne "")) {
        #         if (!(test-path $File -ea SilentlyContinue)) {
        #             Write-Error "$($File) is not a valid path to a .txt file.  Please try again."
        #         }
        #         else {
        #             #ADD OPTION TO SPECIFY PARAMETERS IN CLI TO OVERWRITE ONES IN FILE?  AS OF NOW, SPECIFYING PARAMETERS IN THE CLI DOESN'T THROW AN EXCEPTION.\
        #             [array]$paths = @()
        #             foreach ($l in (Get-Content $file -ea SilentlyContinue)) {
        #                 [array]$params, [array]$global:Options = @()
        #                 [array]$global:to_invoke_path_empty,[array]$global:to_invoke_dest, [array]$global:to_invoke_path = @()
        #                 $params = "$l" -split '" ' 
        #                 #"Params[0]: $($params[0])"
        #                 # "Params[1]: $($params[1])"
        #                 # "Params[2]: $($params[2])"
        #                 if ($params[2] -eq $null) {
        #                     $params += " "
        #                 }
        #                 elseif ($params[2].TrimEnd(' ') -imatch '.*-verify.*') {
        #                     $Verify = $true
        #                 }
        #                 #"Params[2]: $($params[2])"
        #                 $new_path = $params[0].TrimStart(' ')
        #                 $new_path = $new_path.TrimStart('"')
        #                 $new_dest = $params[1].Trimstart('"')
        #                 $Paths += $new_path
        #                 #"Path: $new_path and Dest: $new_dest"
        #                 foreach ($p in $params[2..($params.Length-1)]) {
        #                     $global:Options += $p
        #                 }
        #                 $cmd = "Start-InvokeBackup $l -NoArchiveReset"
        #                 #Write-Host $cmd
        #                 Out-Start $new_path $new_dest
        #                 Invoke-Expression $cmd
        #                 #"Verify: $verify"
        #                 if ($Verify) {
        #                     Get-Verification $new_path $new_dest
        #                 }
        #             }
        #             $paths =  $paths | Sort-Object | Get-Unique
        #             #Write-Host "Here are paths to remove archive bits: $paths"
        #             foreach ($p in $paths) {
        #                 $file = Get-ChildItem "$p" -file -Recurse -Attributes Archive -ErrorAction SilentlyContinue
        #                 Remove-ArchiveProperty $file
        #             }
        #         }
        #     }
        #     else { 
        #         if ($GUI) {$Path, $destination = Get-Continue $Path $destination $GUI} else {Get-Continue $Path $destination $GUI}
        #         $cmd = "Start-InvokeBackup '$Path' '$destination' -Mode $Mode $global:parameters" 
        #         if ($global:LogFile) {
        #             Write-Log $msg
        #         }
        #         Write-Verbose $cmd
        #         Out-Start $Path $destination
        #         Invoke-Expression $cmd    
        #         if ($Verify) {
        #             Get-Verification $path $destination
        #         }
        #     }
        # }
    }
}