function Setup-AFtest{
    Remove-Item -Path d:\test -Recurse -Force
    Remove-Item -Path c:\test -Recurse -Force
    New-Item d:\test -ItemType Directory
    New-Item d:\test\1 -ItemType Directory
    New-Item d:\test\1\1.2 -ItemType Directory
    New-Item d:\test\2 -ItemType Directory
    New-Item d:\test\file.txt -ItemType File -Value "File.txt"
    New-Item d:\test\1\file1.txt -ItemType File -Value "File1.txt"
    New-Item d:\test\delete-me.txt -ItemType File -Value "Should be deleted"
    New-Item d:\test\2\delete-me.txt -ItemType File -Value "Should be deleted"
    New-Item d:\test\2\file2.txt -ItemType File -Value "File2.txt"
    New-Item d:\test\1\1.2\file1.2.txt -ItemType File -Value "File.txt"
    New-Item c:\test -ItemType Directory
    New-Item c:\test\1 -ItemType Directory
    New-Item c:\test\1\1.2 -ItemType Directory
    New-Item c:\test\2 -ItemType Directory
    New-Item c:\test\file.txt -ItemType File -Value "File.txt"
    New-Item c:\test\2\file2.txt -ItemType File -Value "File2.txt"
    New-Item c:\test\1\1.2\file1.2.txt -ItemType File -Value "File.txt"
    Move-Item c:\test\1\1.2\file1.2.txt C:\test
    Move-Item c:\test\2\file2.txt c:\test\1\file2.txt
    Move-Item c:\test\file.txt C:\test\1\1.2
    New-Item c:\test\2\file2-new.txt -ItemType File -Value "New-File2.txt"
    New-Item "c:\test\new folder\" -ItemType Directory    
}


function Archive-Folder {
    [CmdletBinding(SupportsShouldprocess=$true, Confirmimpact="Medium")]
    Param(
        #Source directory to copy.  Can accept multiple values from a pipeline.
        [parameter(mandatory=$true,position=0,Valuefrompipeline=$true, Valuefrompipelinebypropertyname=$true)][string]$Path,
        #Destination directory to copy.  Can accept multiple values from a pipeline.
        [parameter(mandatory=$true,position=1,Valuefrompipeline=$true, Valuefrompipelinebypropertyname=$true)][string]$Destination,
        #Default Mode is by date (copies only newer files), but "Archive" copies files with archive bit set
        [parameter(mandatory=$false)][validateset("Archive","Date")]$Mode = "Date",  
        #Moves any files with the same name that don't already exist at the destination
        [switch]$Mirror,
        #Deletes files with names that are in the destination directory tree but not in the source directory tree (only compares file name)
        [switch]$DeleteFiles,
        #Deletes folders in the destitation that are not in the source
        [switch]$DeleteDirectories,
        #Deletes empty directories at the destination
        [switch]$DeleteEmptyDirectories,
        #Uses the GUI to get Source and Destination Directories
        [switch]$GUI = $false,
        #Keeps newer files in the database that have been moved from one directory to another.  Default is to copy over file from source even if it is older
        [switch]$KeepNewer = $false               
    )
    Begin {
        
        #GUI - get src and dest pathes by GUI if -GUI is specified   
        if ($GUI) {
            Add-Type -AssemblyName System.Windows.Forms
            $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
            $FolderBrowser.Description = "Select the Source Folder"
            if ($FolderBrowser.ShowDialog() -eq "ok") {
                $Path = $FolderBrowser.SelectedPath
            }
            else {
                break
            }
            $FolderBrowser.Description = "Select the Destination Folder"
            if ($FolderBrowser.ShowDialog() -eq "ok") {
                $Destination = $FolderBrowser.SelectedPath
            }
            else {
                break
            }                   
        }           
            
    }
    Process { 
       if ($PSCmdlet.ShouldProcess("Copying files in $Path to $Destination with '$($PSBoundParameters.keys)' set to: '$($PSBoundParameters.values)'")) {
        
        #region 1 - Error Handling and deleting files in destination not present in source
        $files, $size, $folders, $total_size, $current_size, $dest_file_time, $dest_files = $null
        $attribute = [io.fileattributes]::Archive  
        if (!(test-path $path)) {
            Write-Error "You must specify a valid Source Path"
            break
        }           
        if ($Destination -notmatch '^[A-z]:\\' -or $Destination[0] -notin (Get-PSDrive -PSProvider FileSystem).Name) {
            Write-Error "$Destination is not a valid path."
            break
        }

            
        #endregion
       
        #region 2 - Get files, folders, and drives
        $files, $size, $folders, $total_size, $current_size, $dest_file_time, $dest_files = $null
        if ($Mode -eq "date") {
            $files = Get-ChildItem -Path $Path -Recurse -File
        }
        elseif ($Mode -eq "archive") {
            $files = Get-ChildItem -Path $Path -Recurse -Attributes Archive
        }
        $folders = Get-ChildItem -Path $Path -Recurse -Attributes Directory
        $dest_files = Get-ChildItem -Path $Destination -Recurse -File
        #endregion

        #region 3 - creates directories in destination
        foreach ($sd in $folders) {     
            $new_dir = $sd.fullname -ireplace [regex]::Escape($Path),$Destination
            if(!(Test-Path ($new_dir))) {
                "Creating path '{0}'" -f ($new_dir)
                New-Item -Path ($new_dir) -ItemType Directory
            }
         }
        #endregion
        
        #region 4 - iterates through files and copies over ones based on $Mode value ("archive" or "date")
        foreach ($file in $files) {  
            if ($DeleteFiles) {
                $mirror = $true
                foreach ($item in $dest_files) {
                   if (($files.name -notcontains $item.name)) {
                        "Deleting `'{0}`'" -f $item.fullname  
                        Remove-Item -Path $item.fullname
                    }
                }
                $dest_files = Get-ChildItem -Path $Destination -Recurse -File
            }                
            $current_size = ((Get-Item $file.fullname).Length/1MB)               
            $Destination_full = $file.DirectoryName -ireplace [regex]::Escape($Path),$Destination
            $Destination_full += '\'
            $dest_file = ($Destination_full + $file.Name)                   
            if ($Mirror) { 
                if ($dest_files.name -eq $file.Name) {
                    foreach ($item in $dest_files) {
                        if ($item.name -eq $file.name) {
                            $dest_file_time = (Get-Item -Path $item.fullname).LastWriteTime
                            If ($KeepNewer) {
                                if (($file.LastWriteTime -le $dest_file_time) -and !(test-path ($dest_file) -ErrorAction SilentlyContinue)) { 
                                    "Moving '{0}' from '{1}' to '{2}'" -f $file.name, $item.fullname, $dest_file
                                    Move-Item -Path $item.fullname -Destination $Destination_full                   
                                    break
                                }
                            }
                            Else {
                                if (($file.LastWriteTime -ge $dest_file_time) -and !(test-path ($dest_file) -ErrorAction SilentlyContinue)) { 
                                    "Moving '{0}' from '{1}' to '{2}'" -f $file.name, $item.fullname, $dest_file
                                    Move-Item -Path $item.fullname -Destination $Destination_full                   
                                    break
                                }
                            }                                                                          
                        }
                    }        
                }         
            }
            
            #if the destination file exists compare the date modified with the source file           
            if (Get-Item -Path $dest_file -ErrorAction SilentlyContinue) {
                #"{0} already exists" -f $file.name
                $dest_file_time = (Get-Item -Path $dest_file).LastWriteTime
                if ($file.LastWriteTime -gt $dest_file_time) { 
                    $total_size += $current_size               
                    "Copying: '{0}'`({2:f} MBs`) to '{1}'" -f $file.FullName, $dest_file, $current_size
                    Copy-Item -Path $file.FullName -Destination $Destination_full -ErrorAction Stop -Force     
                }
            }
            else {              
                #"{0} doesn't exist yet" -f $file.name
                $total_size += $current_size 
                "Copying: '{0}'`({2:f} MBs`) to '{1}'" -f $file.FullName, $dest_file, $current_size
                Copy-Item -Path $file.FullName -Destination $Destination_full -ErrorAction SilentlyContinue -Force      
            }    

            #removes archive bit if using Archive Mode
            if ($Mode -eq "Archive") { 
                $total_size += $current_size       
                "Copying: '{0}'`({2:f} MBs`) to '{1}'" -f $file.FullName, $dest_file, $current_size
                Copy-Item -Path $file.FullName -Destination $Destination_full -ErrorAction Stop -Force -Container     
                Set-ItemProperty $file.FullName -Name attributes -Value ((Get-ItemProperty $file.FullName).Attributes -bxor $attribute)
            }         
        }        
        #endregion
            
        #region 5 - deleting directories and displaying total amount transferred        
        if ($DeleteEmptyDirectories) {
            $empty_dir = Get-ChildItem -path $Destination -r -Directory | Where-Object {$_.GetFiles().Count -eq 0} | slo -ExpandProperty fullname
            foreach ($d in $empty_dir) {
                "Deleting {0}" -f $d
            }
        }        
        if ($DeleteFiles) {
            $dir = Get-ChildItem $Destination -Recurse
            foreach ($d in $dir) {                
                $new_dir = $($d.fullname) -ireplace [regex]::Escape($Destination), $Path               
                if (!(Test-Path $new_dir)) {
                    "Deleting $($d.fullname)"
                    Remove-Item $($d.fullname)
                }                
            }
        }        
        if ($null -ne $total_size) {
            "{0:f} MBs transfered" -f $total_size
        }
        else {
            "No files transferred"
        }
        #endregion   
      }     
    }
}
Set-Alias af Archive-Folder
Setup-AFtest
af C:\test D:\test -DeleteFiles