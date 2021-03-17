#why does "Pmem" get caught for some of the mid corrections but not others?

    $verb_list = (Get-Verb).verb | sort -Descending
    $cmdlet_list = (Get-command -CommandType Cmdlet, Function).name
    $split_items = @()
    $alias_mapping = @{}
    $script:verb_mapping = @{}
    $script:alias = $null

    $path = "$env:HOMEPATH\Desktop"
    $out_name = '\Aliases.ps1'
    $verb_mappings_file = '\Verb_mappings.txt'

    $path_full = $path + $out_name
    $verb_mappings = $path + $verb_mappings_file
    New-Item -Path $path_full -ItemType File -ErrorAction Continue
    rm $path_full
    echo $null > "$path\debug.txt"

    Function Get_noun_char {    
        #"Args[0] is equal to null: {0}" -f ($args[0] -eq $null) >> "$path\debug.txt" 
        if ($args[0] -eq $null) {
            "Going route 1 and arg[0] is: {0}" -f $args[0] >> "$path\debug.txt" 
            $start = 0
            $end = $noun.Length-1          
        }
        elseif ($args[0] -eq 0) {
            "Going route 2 and arg[0] is: {0}" -f $args[0] >> "$path\debug.txt"   
            $start = $args[1]+1
            $end = $noun.Length-1
        }    
        elseif ($args[1] -eq "2nd time") {
            "Going route 3 and arg[0] is: {0}" -f $args[0] >> "$path\debug.txt" 
            $start = $args[0]
            $end = $noun.Length-1
        }
        else {
            "Going route 4 and arg[0] is: {0}" -f $args[0] >> "$path\debug.txt"   
            $start = 0
            $end = $args[0]-1
        }
        foreach ($char in [char[]]$noun[$start..$end]) {             
            if ([char]::IsUpper($char) -or $char -match "[0123456789]") {
                #"Adding : {0} to {1}" -f $char, $alias
                $script:alias += $char                 
            }        
        } 
    }

    #creating a verbs.txt with all the verbs:
                                                                                                                <#
Remove-Item -Path 'C:\users\adam\desktop\Office and Text Files\PS_Alias_Project\Verbs.txt'
foreach ($item in $verb_list)
    {
    $count = (man $item-*).name | Measure-Object | select -ExpandProperty count
    #"$item has $count commands associated with it"
    foreach ($char in [char[]]$item[1..($item.Length-1)])
        {
        if ($char -notmatch "[aAeEiIoOuU]")
            {
            $first_consonant = $char
            break
            }
        }
    "{0}{1} {2} {3}" -f $item[0], $first_consonant, $item, $count >> 'C:\users\adam\desktop\Office and Text Files\PS_Alias_Project\Verbs.txt'
    $verb_prefix += @{$first_consonant = $item[0]}
    }


#import verb_mappings.txt


foreach($l in cat $verb_mappings) {
    $line = "$l".Split(" ")
    $alias_mapping += @{$line[1] = $line[0]}
}

#creating a hash table of all the verbs
foreach ($l in cat $verb_mappings) {
    $parts = $l.split(" ")
    #"{0} = {1}" -f $parts[1], $parts[0]
    $verb_mapping += @{$parts[1] = $parts[0]}
}
    #>

    #creating alias list:
    $result = $null
    $alias = $null
    $alias_hash = @{}
    $cmdlets = @()
    $i = 0
    $ends_with = $false
    $corrections_end = @{
                        "Alias"="al";"Clipboard"="cb";"Capability"="cbl";"Chassis"="ch";
                        "Client"="cln";"Culture"="clt";"Command"="cmd";"Computer"="cmp";
                        "Console"="cn";"Constraint"="cns";"Counter"="ctr";"Credential"="crd";
                        "Certificate"="crt";"Custom"="cst";"Clixml"="cxml";"Downgrading"="dg";
                        "Driver"="dr";"Disk"="dsk";"Dtc"="dtc";"Device"="dv";"Edition"="ed";
                        "Help"="hl";"History"="hst";"Info"="inf";"Instance"="ins";"Log"="lg";
                        "Module"="md";"Nat"="nat";"Package"="pck";"Pool"="pl";"Property"="pp";
                        "Printer"="pr";"Port"="prt";"Process"="ps";"Partition"="pt";"Portal"="ptl";
                        "Rdma"="rdma";"Rsc"="rsc";"Runspace"="rsp";"Rss"="rss";"Signature"="sg";
                        "Snippet"="sn";"Sriov"="sr";"Source"="src";"Server"="srv";"Session"="ss";
                        "Site"="st";"Service"="svc";"Tpm"="tpm";Trace="tr";"Transcript"="trn";
                        "Variable"="vb";"Verb"="vrb";
                        }    
    $corrections_mid = @{
                        "Address"="add";"Application"="app";"IPsec"="ips";

                        "Pcsv"="pcsv";"Pmem"="pm";
                        "Pnp"="pnp";"Partition"="pt";"Scheduled"="sch";"Sddl"="sddl";
                        "Security"="sec";"Smb"="smb";          
                        }
                                                                                    $verb_mapping = @{"Add"="A";"Approve"="Ap";"Assert"="As";"Block"="Bl";"Backup"="Bu";
                  "Confirm"="Cf";"Clear"="Clr";"Close"="Cls";"Connect"="Cn";
                  "Compare"="Cp";"Complete"="Cpl";"Compress"="Cpr";"Copy"="Cp";
                  "Checkpoint"="Ch";"Convert"="Cv";"ConvertFrom"="Cvf";"ConvertTo"="Cvt";
                  "Disable"="D";"Debug"="Db";"Disconnect"="Dc";"Dismount"="Dm";"Deny"="Dn";
                  "Enable"="E";"Edit"="Ed";"Eject"="E";"Enter"="En";"Expand"="Epd";
                  "Export"="Exp";"Exit"="Ex";"Find"="F";"Format"="Fr";"Get"="G";"Grant"="Gr";
                  "Group"="Grp";"Hide"="H";"Install"="I";"Import"="Imp";"Initialize"="Init";
                  "Invoke"="Iv";"Join"="Jn";"Lock"="Lc";"Limit"="Lm";"Mount"="M";"Merge"="Mr";
                  "Measure"="Ms";"Move"="Mv";"New"="N";"Out"="O";"Open"="Op";"Optimize"="Op";
                  "Ping"="Pn";"Pop"="Pp";"Protect"="Pr";"Push"="Ps";"Publish"="Pb";"Read"="R";
                  "Receive"="Rc";"Redo"="Rdo";"Register"="Rg";"Remove"="Rmv";"Rename"="Rn";
                  "Repair"="Rp";"Request"="Rq";"Reset"="Rs";"Resolve"="Rsl";"Resume"="Rs";
                  "Restart"="Rst";"Restore"="Rstr";"Resize"="Rs";"Revoke"="Rv";"Search"="Sr";
                  "Set"="S";"Show"="Sh";"Skip"="Sk";"Select"="Sl";"Submit"="Sb";"Send"="Sn";
                  "Split"="Sp";"Suspend"="Ss";"Start"="St";"Step"="St";"Stop"="Stp";
                  "Save"="Sv";"Switch"="Sw";"Sync"="Sy";"Test"="T";"Trace"="Tr";"Use"="U";
                  "Unblock"="Ub";"Undo"="Ud";"Uninstall"="Ui";"Unlock"="Ul";"Unprotect"="Up";
                  "Unpublish"="Up";"Update"="Ud";"Unregister"="Ur";"Where"="Wh";"Write"="W";
                  "Wait"="Wt";"Watch"="Wt";
                 }   

    #the bulk of the code:             
    foreach ($cmdlet in $cmdlet_list) {
        if ($cmdlet.Contains("-")) {  
            $verb, $noun = $cmdlet.split("-")

            #take the 1st letter of verbs not in the $verb_mapping hash 
                    if ($verb_mapping[$verb]) {
            $alias = $verb_mapping[$verb]
        }
                    Else {
            $alias = $verb[0]
        }        
       
            #check endings for pre-defined aliases:
                                                            foreach ($ending in $corrections_end.keys) {        
            if ("$noun".EndsWith($ending)) {
                #"{0} ends with {1}" -f $noun, $ending
                #$ends_with = $true 
                $ending_to_add = $ending               
                break
            }
            else {
                #"{0} doesn't end with {1}" -f $noun, $ending
                #$ends_with = $false     
                $ending_to_add = $null
            }
        }
       
            #check substrings for pre-defined aliases:
                                                                            foreach ($sstr in $corrections_mid.keys) {
            <#if (("$noun".contains("Pmem"))) {
                "{2} contains {1} is {0}" -f ("$noun".contains($sstr)), $sstr, $cmdlet
                if ($noun.EndsWith($sstr) -eq $false) {
                    "{2} ends with {1} is {0}" -f ($noun.EndsWith($sstr)), $sstr, $cmdlet
                }
            }#>
            if ("$noun".contains($sstr) -and ($noun.EndsWith($sstr) -eq $false)) {
               #"{0} contains {1}" -f $noun, $sstr       
                $mid_to_add = $sstr                      
                break
            }
            else {    
               # "{0} doesn't contain {1}" -f $noun, $sstr
                $mid_to_add = $null 
            }
        }
    
            #"{2} - Ending to add is {0} and Mid to add is {1}" -f $ending_to_add, $mid_to_add, $cmdlet >>"$path\debug.txt"

            #Case 1:there's an ending to change
                                                    if (($ending_to_add -ne $null) -and ($mid_to_add -eq $null)) {
            "Case 1 for {0}" -f $cmdlet >> "$path\debug.txt"
            if ($ending_to_add -eq $noun) {
                $alias += $corrections_end[$ending_to_add] 
            }
            else {                
                Get_noun_char            
                $alias = "$alias".Remove($alias.Length-1)           
                $alias += $corrections_end[$ending_to_add] 
            }             
        }

            #Case 2: there's a mid to change
            elseif (($ending_to_add -eq $null) -and ($mid_to_add -ne $null)) {
                for ($i=0;$i -lt ($noun.Length-$mid_to_add.Length); $i++)  {  
                    #"Range is {0} to {1} and substring is {2}" -f $i, ($mid_to_add.Length-1+$i), $noun.Substring($i,$mid_to_add.Length)
                    if ($noun.Substring($i,$mid_to_add.Length) -eq $mid_to_add) {
                        $index_start = $i
                        $index_end = ($i + $mid_to_add.length - 1)                    
                        break       
                    }
                }
                "Index start: {0} and Index End: {1} for {2} in {3}" -f $index_start, $index_end, $mid_to_add,$noun >> "$path\debug.txt"
                #"Alias for: {0}" -f $cmdlet
                #"Removing last char from {1} to get {0}" -f $alias.Remove($alias.Length-1), $alias        
                #"Adding {0} to {1}" -f $corrections_mid[$mid_to_add], $alias
             
                if ($noun.StartsWith($mid_to_add)) {
                    #"Case 2.1 for {0} and mid_to_add: {1}" -f $cmdlet, $mid_to_add >> "$path\debug.txt"
                    $alias += $corrections_mid[$mid_to_add] 
                    Get_noun_char $index_start $index_end
                }
                else {
                    #"Case 2.2 for {0} and mid_to_add: {1}" -f $cmdlet, $mid_to_add >> "$path\debug.txt"
                    #$alias += $noun[0]
                    Get_noun_char $index_start $index_end
                    $alias += $corrections_mid[$mid_to_add]    
                    get_noun_char ($index_end) "2nd time"
                }
             
                #"New Alias {0}" -f $alias
            }
            #Case 3: there's a mid and ending to change
            elseif (($ending_to_add -ne $null) -and ($mid_to_add -ne $null)) {
                #finding indexes of substring
                for ($i=0;$i -lt ($noun.Length-$mid_to_add.Length); $i++)  {  
                    #"Range is {0} to {1} and substring is {2}" -f $i, ($mid_to_add.Length-1+$i), $noun.Substring($i,$mid_to_add.Length)
                    if ($noun.Substring($i,$mid_to_add.Length) -eq $mid_to_add) {
                        $index_start = $i
                        $index_end = ($i + $mid_to_add.length - 1)                    
                        break       
                    }
                }
                #"Case 3 Index start: {0} and Index End: {1} for {2}" -f $index_start, $index_end, $noun >> "$path\debug.txt"
                if ($index_start -eq 0) {               
                    $alias += $corrections_mid[$mid_to_add] 
                    Get_noun_char $index_start $index_end
                    #$alias
                    $alias = $alias.Remove($alias.Length-1)
                    #$alias
                    $alias += $corrections_end[$ending_to_add]  
                    #$alias
                    #sts 2                    
                }           
            }
            #Case 4: there's nothing to change
            else {
                #"Case 4 for {0}" -f $cmdlet >> "$path\debug.txt"               
                Get_noun_char                 
            }   
            #only adds alias to result if it doesn't already exist:        
            $result += "Set-Alias {0} {1} -force -ErrorAction SilentlyContinue`n" -f "$alias".ToLower(), $cmdlet 
            #$result += "Set-Alias {0} {1} -force -ErrorAction SilentlyContinue`n" -f "$alias".ToLower(), $cmdlet >> "$path\debug.txt" 
            $alias_hash += @{$cmdlet="$alias".tolower()}
            $cmdlets += $cmdlet 
        }
        else {
            "skipping {0}" -f $cmdlet 
        }
    }
    $result | sort >> $path_full 

    #check for and print conflicts to a file:
    $aliases = @()
    foreach ($item in $alias_hash.Values) {
        $aliases += $item
    }
    $unique_alias = $aliases | select -Unique
    $diff = Compare-Object $unique_alias $aliases
    "Conflicts:`n{0}" -f (($diff.inputobject) | sort) #> "C:\Users\Adam\Desktop\Office and Text Files\PS_Alias_Project\Alias_Conflicts.txt"
