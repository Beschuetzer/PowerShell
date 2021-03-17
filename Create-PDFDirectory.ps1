#PopulateLeftOff is the main function
#-Recurse gets all folders below $dir
#-Extract extracts any zip files in the dir/dirs
#-delete deletes any zip files in the dir/dirs but only after extracting (must be used in conjunction with -Extract)

function PopulateLeftOff {
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$dir,
        [switch]$Recurse,
        [switch]$Extract,
        [switch]$Delete
    )
    if ($Recurse){
        $dirs = Get-ChildItem $dir -Directory
        foreach ($d in $dirs){
            $dir_full = $d.FullName
            #Write-Host "dir_full: $dir_full`n`Delete: $delete"
            Start-Process($dir_full)
            if ($Extract){
                if ($delete){
                    Start-ZipExtractionandDeletion "$($dir_full)" -Delete
                }
                else {
                    Start-ZipExtractionandDeletion "$($dir_full)"
                }
            }            
        }
    }
    else{
        Start-Process($dir)
        if ($Extract){
            if ($delete){
                Start-ZipExtractionandDeletion "$($dir_full)" -Delete
            }
            else {
                Start-ZipExtractionandDeletion "$($dir_full)"
            }
        }   
    }

}

function Start-Process{
    param (
        [string]$dir
    )    
    $out_filesstr = "$dir\Left Off.txt"
    New-Item $out_filesstr -ErrorAction SilentlyContinue | Out-Null 
    $out_file = Get-Content $out_filesstr 
    #Write-Host "outfile: $(test-path $out_filesstr) and length $($out_file.Length)"
    if ((Test-Path $out_filesstr) -and ($out_file.Length -eq 0)) {            
        $stream = [System.IO.StreamWriter] $out_filesstr
        $files = Get-ChildItem $dir -Filter "*.pdf"
        $stream.WriteLine("Left off Location for the following:`n")
        foreach ($f in $files){
            #Write-Host "Adding: $($f.name) to $out_filesstr`n$($f.name -eq $null) "
            $stream.WriteLine("$($f.name) - ")
        }
        $stream.Close()
    }
}

function Start-ZipExtractionandDeletion {
    param 
    (
        [string]$Directory,
        [switch]$Delete
    )
    $zip_files = Get-ChildItem $directory -File -Filter "*.zip"
    #Write-Host "Zip files: $($zip_files)\nDirectory: $($directory)\nDelete: $delete"
    foreach ($z in $zip_files){
        #Write-Host "BaseName: $($z.BaseName)"
        $zip_filepath = $z.FullName
        $filename = $z.BaseName
        $dest = "$directory\$filename"
        if(!(test-path $dest)) {
            Expand-Archive -Path $zip_filepath -DestinationPath $dest -Force -ErrorAction SilentlyContinue
        }        
        if ($Delete){
            Start-Deletion($z.FullName)
        }
    }
    
}

function Start-Deletion {
    param 
    (
        [string]$zip_file
    )
    Write-Host "removing: $zip_file"
    Remove-Item $zip_file -Force -ErrorAction SilentlyContinue
}
