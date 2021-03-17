$global:music_root = "F:\Music"
$global:playlist_root = "F:\Music\playlists"
Function Move-PlaylistFilestoNewDirectory {
    $error_log = "$global:playlist_root\errors.txt"
    $duplicate_log = "$global:music_root\playlists\duplicates.txt"
    $log = "$global:playlist_root\log.txt"
    $null | Out-File $log
    $null | Out-File $error_log
    $null | Out-File $duplicate_log
    write-host "`n"
    $playlists = Get-ChildItem $global:playlist_root -Filter "*.wpl"
    foreach ($p in $playlists) {
        $log_list = @()
        $path_list = @()
        $playlist_songs = @()
        $playlist_songs_without_extension = @()
        $n = 0
        # Write-Host "Name: $p"
        $p -match "(.*)\.wpl" | Out-Null
        $playlist_name = "$($matches[1]) Playlist"
        $Msg = "Playlist Name: $playlist_name"
        Write-Host $Msg
        $msg | Out-File $log -Append
        $new_playlist_root = "f:\playlist copy\$playlist_name"
       
    
        #creating a folder in music root based on playlist name
        if (!(Test-Path -literalpath $new_playlist_root)) {
            New-item -literalpath $new_playlist_root -ItemType Directory | Out-Null
        }
        foreach ($l in Get-Content $p.FullName -Encoding UTF8) {
            # Write-Host "Line $n $l"

            #replace &apos; with '
            if ($l -match '&apos;') {
                $l = $l -replace '&apos;', "'"
                # write-host $l
                # Start-Sleep 2
            }

            #replacing ampersand
            if ($l -match '&amp;') {
                $l = $l -replace '&amp;', "&"
                # write-host $l
                # Start-Sleep 2
            }
            
            #finds the lines that have music files
            if ($l -match "(.*)(`".*\.(mp3|wma|flac|m4a|wav)`")(.*)") {
                # Write-Host "Match is $($matches[2])"
                $temp = $matches[2]
                if ($temp -match "`"(.*\\)(.*)(\..*)`"") {
                    $song_name = "$($matches[2])$($matches[3])"
                    $song_name_without_extension = $matches[2]
                    # Write-Host "$song_name and $song_name_without_extension"
                    # Start-Sleep 10
                    if ($song_name_without_extension -in $playlist_songs_without_extension) {
                        $msg = "`tDuplicate: $song_name in playlist $p"
                        Write-Host $Msg
                        $msg | Out-File $duplicate_log -Append
                    }
                    else {
                        $n += 1
                        $playlist_songs += $song_name
                        $playlist_songs_without_extension += $song_name_without_extension
                    }
                    $dest_file = "$new_playlist_root\$song_name"
                    $source_file = "$music_root\$song_name"
                    # Write-Host "Dest_file is $dest_file"
                    # Start-Sleep 2
                    if (!(Test-Path -literalpath $dest_file)) {
                        $msg = "`t$n - Copying: $song_name to $new_playlist_root"
                        Write-Host $msg
                        $log_list += $msg
                        copy-Item -literalpath $source_file -Destination $new_playlist_root -Force -ErrorVariable err
                        if ($err) {
                            "$log_list += $n - Error: $msg"
                            $path_list += "$new_playlist_root\$song_name"
                        }
                        else {
                            $path_list += "$new_playlist_root\$song_name"
                        }
                    }
                    else {
                        $log_list += "`t$n - Skipping: $song_name.  It already exists in $new_playlist_root"
                        $path_list += "$new_playlist_root\$song_name"
                    }
                }
            }
        }
        Remove-ExcessFiles $playlist_songs $new_playlist_root
        $num_in_dir = (Get-ChildItem $new_playlist_root -File).Length
        if ($n -eq $num_in_dir ) {
            $Msg = "All files copied: $num_in_dir in directory and $n in playlist`n"
            $msg | Out-File "$global:playlist_root\log.txt" -Append
            Write-Host $msg
        }
        else {
            $Msg = "Playlist Name: $playlist_name"
            $msg | Out-File $log -Append | Out-Null
            foreach ($l in $log_list) {
                $l | Out-File $log -Append| Out-Null
            }
            $msg = "Number of entries in playlist is $n but $num_in_dir files in playlist directory`n"
            Write-Host $Msg
            $msg | Out-File "$log" -Append
        }
    }
}

Function Remove-ExcessFiles ([array]$playlist_songs, $new_playlist_root) {
    $deleting_lot = "$global:playlist_root\Deletions.txt"
    $null | Out-File $deleting_lot | Out-Null
    $files = Get-ChildItem $new_playlist_root -File
    foreach ($f in $files) {
        if ($f.name -in $playlist_songs) {
            $msg = "`tKeeping $($f.name)"
            # write-host $msg

        }
        else {
            $msg = "`tDeleting $($f.fullname)"
            write-host $msg 
            $msg | Out-File $deleting_lot -Append | Out-Null
            Remove-Item -LiteralPath $f.FullName 
        }
    }
}


Move-PlaylistFilestoNewDirectory

#region Obsolete code
function Rename-MusicFiles {
    #Replaces files with German characters with English characters and deletes Japanese characters
    $mp3 = Get-ChildItem $global:music_root -File -Filter '*.mp3'
    $k = 1
    $duplicate_log = "$global:music_root\playlists\duplicates.txt"
    $error_log = "$global:music_root\playlists\errors.txt"
    $null | Out-File $duplicate_log
    $null | Out-File $error_log
    foreach ($m in $mp3) {
        $rename = $false
        $temp = $m.name
        #japanese characters
        if ($m.name -match "[\u3000-\u303f\u3040-\u309f\u30a0-\u30ff\uff00-\uffef\u4e00-\u9faf]") {
            $temp = $m.name -replace '[\u3000-\u303f\u3040-\u309f\u30a0-\u30ff\uff00-\uffef\u4e00-\u9faf]', ''
            # Start-Sleep 3
            # Write-Host "$k - Renaming $temp cuz japanese"
            $rename = $true
        }
        #german umlaut A
        if ($m.name -match "[\u00E4\u00C4]") {
            $temp = $temp -replace '\u00E4', 'ae'
            $temp = $temp -replace '\u00C4', 'Ae'
            # Write-Host "$k - Renaming $temp cuz a"
            $rename = $true
        }

        #german umlaut o
        if ($m.name -match "[\u00F6\u00D6]") {
            $temp = $temp -replace '\u00F6', 'oe'
            $temp = $temp -replace '\u00D6', 'Oe'
            # Write-Host "$k - Renaming $temp cuz o"
            $rename = $true
        }
        #german umlaut u
        if ($m.name -match "[\u00FC\u00DC]") {
            $temp = $temp -replace '\u00FC', 'ue'
            $temp = $temp -replace '\u00DC', 'Ue'
            # Write-Host "$k - Renaming $temp cuz u"
            $rename = $true
        }
        #german ß
        if ($m.name -match "\u00DF") {
            $temp = $temp -replace '\u00DF', 'ss'
            # Write-Host "$k - Renaming $temp cuz ß"
            $rename = $true
        }
        if ($rename -eq $true) {
            if ($temp -match "'") {
                $temp = $temp -replace "'", ''
            }
            if ($temp -match ".*~.*") {
                $temp = $temp -replace "~", ''
            }
            if ($temp -match ".*\(\s*\).*") {
                $temp = $temp -replace "\(\s*\)", ''
            }
            
            if ($temp -match "\s{2,}") {
                $temp = $temp -replace "\s{2,}", ' '
                # Write-Host $temp
            }
            if ($temp -match "\s\.mp3") {
                $temp = $temp -replace "\s\.mp3", '.mp3'
                # Write-Host $temp
            }
            $temp = $temp.trim()
            # Start-Sleep .5
            # write-host $m
            Rename-Item -literalpath "$($m.fullname)" "$global:music_root\$temp" -ErrorVariable err -ErrorAction SilentlyContinue
            if ($err) {
                Write-Host "$k - Error renaming $m"
            }
            else {
                Write-Host "$k - Renaming $temp"
                "`"$($m.name)`" changed to `"$temp`"" | Out-File $change_log -Append
            }
            # Start-Sleep 10
            $k += 1
        }
        
    }
}


function Rename-PlaylistNames {
    $playlists = Get-ChildItem $global:playlist_root -Filter "*.wpl"
    Get-ArrayofSongNames
    foreach ($p in $playlists) {
        Write-Host "Playlist: $p"
        $n = 0
        foreach ($l in get-content $p.FullName -Encoding UTF8) {
            if ($l -match '&apos;') {
                $l = $l -replace '&apos;', "'"
                # write-host $l
                # Start-Sleep 2
            }

            #replacing ampersand
            if ($l -match '&amp;') {
                $l = $l -replace '&amp;', "&"
                # write-host $l
                # Start-Sleep 2
            }
            
            #finds the lines that have music files
            if ($l -match "(.*)(`".*\.(mp3|wma|flac|m4a|wav)`")(.*)") {
                $temp = $matches[2]
                if ($temp -match "`"(.*\\)(.*)`"") {
                    $song_name = $matches[2].Trim()
                    Write-Host "`t$song_name"
                    if ($song_name -match "[\u3000-\u303f\u3040-\u309f\u30a0-\u30ff\uff00-\uffef\u4e00-\u9faf\u00E4\u00C4\u00F6\u00D6\u00FC\u00DC\u00DF]") {
                        Start-Sleep 2
                        $n += 1
                        if ($song_name -in $old_names) {
                            Write-Host "Match for $song_name"
                        }
                    }
                }
            }
        }
        Write-Host "`tNum of songs: $n"
    }

}


function Get-ArrayofSongNames {
    $global:old_names = @()
    $global:new_names = @()
    foreach ($l2 in Get-Content "$global:playlist_root\changes2.txt") {
        $temp2 = $l2 -split ' changed to '
        $old = $temp2[0].trim()
        $new = $temp2[1].trim()
        # write-host "`t`t old: $old and new: $new"
        $old_names += $old
        $new_names += $new
    }
    # Write-Host "Old Names: $old_names"
    # Write-Host "New Names: $new_names"
}
# Rename-PlaylistNames
# Edit-Mp3Genre
# Rename-MusicFiles
#endregion obsolete code
