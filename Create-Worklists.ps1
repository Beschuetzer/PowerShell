#Creates a list of instructions in order on how to fix each component in the Service Manual
function Initialize-Setup {
    $global:dict = [ordered]@{}
    $global:processed = @()
}
function Start-Task ($item) {
    Get-Details $item
    Get-Result $item
}
#region - Getting Component parts 
function Get-Components {
    $j = 1
    $null | Out-File $global:Component_file
    foreach ($line in Get-Content $Global:file_path) {
        # write "Original: $line"
        if ($line -match '[0-9]+\.[0-9]+\.[0-9]+') {
        # write "Line: $line"
            if ($line -match "^\s*[0-9]+\.[0-9]+\.[0-9]") {
                $number = $line.trim().split(' ')
                # Write-Host "Regular: $line"
            }
            elseif ($line -match '[0-9]+\.[0-9]+\.[0-9]+\s*') {
                $number_temp = $line.trim() -split '(?=[0-9]+\.[0-9]+\.[0-9]+\s*)', 2
                $number = $number_temp[1].trim() -split ' ', 2
                # Write-Host "Number: $($number[0])`nLine: $line`n`n"
                # Start-Sleep 2
            }
            #Splitting lines that start with numbers
            if ($line -match '^([0-9]+\.[0-9]+\.[0-9]+)' ) {
                # write "line: $line"
                $line2 = $line.trim() -split '(?=[0-9]+\.[0-9]+\.[0-9]+)', 2
                # Write-Host "Line: Before = $($line2[1])"
                $line3 = $line2.trim() -split ' ', 2
                $line4 = $line3[2].trim() -split '(?=\d)', 2
                $res = $($line4[0]).trim()
            }

            #Splitting the lines that have the numbers someone in the middle
            else {
                # write "line: $line"
                $line2 = $line.trim() -split '(?=[0-9]+\.[0-9]+\.[0-9]+)', 2
                # Write-Host "Line: Before = $($line2[1])"
                $line3 = $line2[1].trim() -split ' ', 2
                $line4 = $line3[1].trim() -split '(?=\d)', 2
                $res = $($line4[0]).trim()
            }
            $res = $res.replace( "(", "-")
            $res = $res.replace( ")", "-")
            $res = $res.replace( '"', "")
            # Write-Host "$($j): $res"

            #Getting the start and end of each item
            $start = Get-StartLocation $res $number[0].trim()
            $end = Get-EndLocation $start
            "$($number[0].trim()), $res, $start, $end" | Out-File -FilePath $global:Component_file -Append
            
            $Global:components += $res
            $j += 1
        }
    }
    # Write-Host "There are $($components.count) compontents to replace"
}
Function Get-StartLocation ($item, $number) {
    #gets the line in txt file that $item starts at
    $i = 1
    # Write-host "Matching $number $item with $line"
    foreach ($line in Get-Content $Global:file_path) {
        if ($line -match "[\(\)]") {
            $line = $line -replace '\(', '-'
            $line = $line -replace '\)', '-'
        }
        if ($line -match "$($number.trim())\s*$($item.trim())") {
            # Write-Host "$item starts at line: $i"
            # Write-host "Number: $($number) and Item: $item`n"
            return $i
        }
        $i += 1
    }
}
function Get-EndLocation ($start) {
    #finds the end location in txt file from start location
    $j = 1
    foreach ($line in Get-Content $Global:file_path) {
        if ($j -gt $start) {
            # Write-Host "Line: $line"
            if ($line -match "[0-9]+\.[0-9]+\.[0-9]+") {
                if ($null -ne $line) {
                    return $j - 1
                }
            }
        }
        $j += 1
    }
    return $j
}
Function Get-StartEndandNumber ($item) {
    foreach ($line in Get-Content $global:Component_file) {
        $l2 = $line.Split(',')[1]
        # write-host "L2: $l2 and Item: $item"
        if ($l2.toupper().trim() -eq $item.toupper().trim()) {
            $number = $line.Split(',')[0]
            $start = $line.Split(',')[2]
            $end = $line.Split(',')[3]
            # Start-Sleep 2
            return $start, $end, $number
        }
    }
}

Function Get-ToProcess {
    #Gets the items to recursively process
    $j = 1
    $previous_number = 0
    $to_process = @()
    $start, $end, $number = Get-StartEndandNumber $item
    foreach ($line in Get-Content $Global:file_path) {
        # Write-Host "J: $j, Start: $start and End: $end"
         #only processes lines relevant to each item based on their start and end line number
        if ($j -ge $start -and $j -le $end) {
            # Write-Host $line
            if ($line -match '[0-9]{1,2}\.\s+') {
            # if ($line.trim() -match '[0-9]+\. ' -and $line.trim() -notmatch '[0-9]+\.[0-9]+\.|[0-9]+\.[0-9]+\.[0-9]+') {
                # write-host $line
                # $match = $line -match '[0-9]{1,2}\.\s+'
                
                $current_number = $matches[$matches.length -1]
                # Write-Host "Line: $j - Max Number is $($max_number) and previous number: $previous_number`n"
                if ($current_number -le $previous_number) {
                    # Write-Host "Line: $j - Current Number is $($current_number) and previous number: $previous_number`n"
                    # Write-Host "breaking here"
                    break
                }
                else {
                    $previous_number = $current_number
                }
            }
            # Write-Host "`tLine $j - $line"  #here is shows every line being processed in the txt file

            if ($line -match "[0-9]+\. ") {
                $line2 = $line -split '(?=[0-9]+\. )'
                # Write-Host "`tLine $j - $line"  #here it only shows lines that start with a number
                    # Write-Host "`tLine2: $($line2[2])"
                foreach ($l in $line2) {
                    #gets the relevant lines
                    if ($l -match "[().]") {
                        $l2 = $l.replace(".", "").trim()
                        if ($l2 -match "`"" -or $l2 -match "[()]") {
                            $l2 = $l2.replace('"', "")
                            $l2 = $l2.replace('(', "-")
                            $l2 = $l2.replace(')', "-")
                            # Write-host "$l2 USED TO CONTAIN PARENTHESES"
                        }


                        #Gets rid of the numbers and spaces at the beginning of each instruction
                        $l2 = $l2 -replace '^\s*\d+\s*', ''
                        # Write-Host "l2 - $l2"
                        if ($l2 -match '\w+') {
                            # Write-Host "`t`tProcessing Sub Section - $l2"
                            #checking each line to see if it contains a keyword, which means it needs processing"
                            foreach ($c in $components) {
                                $c = $c -split (',')[0]
                                # Write-Host "`t`t`t`tChecking for $c"
                                #moves to next line if line is blank
                                if ($l2 -notmatch "$item\s*\[") {  #lines that contain [] don't need recursion
                                    if ($l2 -match "^\s*[0-9]{3,}") {
                                        # Write-Host "`t`t`t`t`tSkipping this line due to it being the title (3 or more numbers)"
                                        break
                                    }


                        #the match regex below needs work.  it matches partial matches.
                                    if ($l2 -match "^$c\s*\-|\s+$c\-") {
                                        # Write-Host "`t`t`t`t`tMatch Found: $c on line: $l2"
                                        $to_process += $c
                                        # Write-Host "`t`t`t`t`t`tTo Process: $to_process from $l2"
                                        # Start-Sleep 3                                        
                                        # break                           
                                    }
                                    elseif ($c -match $item) {
                                        # write-host "`t`tSkipping this line as it doesn't contain an enumerated step"
                                        continue
                                    }
                                }
                                else {
                                    # write-host "`t`t`t`t`tSkipping this line due to []"
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
        elseif ($j -gt $end) {
            break
        }
        $j += 1
    }
    return $to_process
}
function Get-Details  {
    #gets the instructions on what to do for each item
    param(
        [string]$item_main
    )
    $to_process = Get-ToProcess
    $global:order_local = "$($to_process -join ', ')"
    $global:dict["$item"] = $order_local 

    #recursion happens in this foreach loop
    foreach ($item in $to_process) {
        if ($global:processed -notcontains $item) {
            $global:processed += $item
            Get-Details $item
        }
        else {
            break
        }
    }
}

Function Get-Result ($item) {
    #outputting the results from get-details
    $ans = $item
    $n = 0
    $dict.Keys | ForEach-Object { 
        if ($n -lt $dict.Count ) {
            # Write-Host "key: $_ and value: $($dict.item($_))"
            if ($dict.item($_) -match '[a-zA-Z]') {
                $ans = $ans -replace "$_", "$($dict.Item($_)), $_" 
                # Write-Host "$_ contains word characters"
            }
        }
        # Write-Host "Ans: $Ans - N: $n and count: $($dict.Count)`n"
        $n += 1
    }
    $ans_final = @()
    $ans_split = $ans -split ','
    foreach ($a in $ans_split) {
        if ($a -notin $ans_final) {
            $ans_final += $a
        }
    }
    $ans = $ans_final -join ','
    $dict_out = $dict | Out-String
    $char = "-"
    $count = 189
    $sep = $char * $count
    $first = "SECTION FOR $item"
    $second = $dict_out
    $third = "$item ORDER - $ans"

    #outputs the header, dictionary, and result
    $line_full = "$first`n$second$third`n$sep"
    $line_full | Out-File -FilePath $output -Append | Out-Null

    #outputs only result
    # $line_basic = $third
    # $line_basic | Out-File -FilePath $output -Append | Out-Null
}
#this is what starts everything
Function Get-Worklist {
    Get-Components   
    foreach ($c in $global:components) {
    Initialize-Setup
    # if ($c -match "SCANNER UPPER COVER") {
        Start-Task $c
        # break
    # }
    }
}

function Create-TextFiles {
    $main_folder = "C:\Users\Adam\Desktop\Machines"
    $sub_folders = Get-ChildItem $main_folder -Directory
    foreach ($f in $sub_folders) {
        Write-Host ""$($f.fullname)\$f-Order.txt""
        $f_files = Get-ChildItem $f.fullname -File
        # New-Item -Path "$($f.fullname)\$f-Order.txt" -Force
        foreach ($ff in $f_files) {
            # Write-Host $ff.fullname
        }
    }
}

Function Start-Job {
    $global:folder_root = "C:\Users\Adam\Desktop\test"
    $sub_folder = Get-ChildItem $folder_root -Directory
    foreach ($f in $sub_folder) {
        #this is the location of the documentation folder
        #name of the file copied from the Service Manual
        $Global:file_name = "Replacement Parts.txt"
        #combination of the above two
        $global:file_path = join-path "$global:folder_root" $f.name "$Global:file_name"
        $Global:components = @()
        $global:Component_file = join-path "$global:folder_root" $f.Name "Components.txt"
        $global:output = join-path "$global:folder_root" $f.name "Order.txt"
        New-Item -ItemType File -Path "$global:output" -ErrorAction SilentlyContinue -Force | out-null 

        write-host "`nWorking on Order for $($f.name):"

        #relies on globals rather than passing variables
        Get-Worklist
        Write-Host "Output at: $output"
    }
}

Start-Job