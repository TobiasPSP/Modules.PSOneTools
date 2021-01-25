function Find-PSOneDuplicateFileFast {
    <#
        .SYNOPSIS
            Identifies files with duplicate content and uses a partial hash for large files to speed calculation up

        .DESCRIPTION
            Returns a hashtable with the hashes that have at least two files (duplicates). Large files with partial hashes are suffixed with a "P".
            Large files with a partial hash can be falsely positive: they may in fact be different even though the partial hash is the same
            You either need to calculate the full hash for these files to be absolutely sure, or add -TestPartialHash.
            Calculating a full hash for large files may take a very long time though. So you may be better off using other
            strategies to identify duplicate file content, i.e. look at identical creation times, etc.

        .EXAMPLE
            $Path = [Environment]::GetFolderPath('MyDocuments')
            Find-PSOneDuplicateFileFast -Path $Path 
            Find duplicate files in the user documents folder

        .EXAMPLE
            Find-PSOneDuplicateFileFast -Path c:\windows -Filter *.log 
            Find log files in the C:\Windows folder with duplicate content

        .EXAMPLE
            Find-PSOneDuplicateFileFast -Filter *.jpg -MaxFileSize 2MB -AlgorithmName MD5 -TestPartialHash
            This command will search the current folder for JPG files and will hash the
            first 2MB using the MD5 algorithm. If there are duplicates of the partial hash
            values it will check the files using the full file size to ensure that the files
            are truly duplicates.

        .LINK
            https://powershell.one

        .NOTES
            Updated by Steven Judd on 2021/01/24:
                Added ValidateScript to Path parameter to ensure the value is a directory and set the path default to the current path
                Set the Filter parameter value for the enumeration of the files (it was set to always check all files)
                Added AlgorithmName parameter to allow the algorithm to be specified
                Added example to show the default path and how to use the MaxFileSize, AlgorithmName, and TestPartialHas parameters
                Set positional parameter values on Path and Filter
    #>

    param(
        # Enter the Path of the folder to recursively search for duplicate files.
        # The default value is the current folder.
        [String]
        [Parameter(Position = 0)]
        [ValidateScript( {
                if (Test-Path -Path $_ -PathType Container) {
                    return $true
                }
                else {
                    #Test-Path check failed
                    throw "Path `'$_`' is invalid. It must be a directory."
                }
            })]
        $Path = '.',
    
        # Enter a filter value to apply to the file search.
        # The default value is '*' (all Files) 
        [String]
        [Parameter(Position = 1)]
        $Filter = '*',
        
        # When there are multiple files with same partial hash they may still be different.
        # When setting this switch, full hashes are calculated for all partial hashes.
        # Caution: setting this switch parameter may take a very long time for large 
        # files and/or network paths.
        [switch]
        $TestPartialHash,
        
        # If the file size is larger than the MaxFileSize value the function will use a
        # partial hash using the specified amount of the beginning of the file.
        # The default value is 100KB.
        [int64]
        $MaxFileSize = 100KB,

        # Select the hash algorithm to use. The fastest algorithm is SHA1. MD5 is second best
        # in terms of speed. Slower algorithms provide more secure hashes with a lesser chance
        # of duplicates with different content.
        # The default value is SHA1.
        [Security.Cryptography.HashAlgorithmName]
        [ValidateSet("SHA1", "SHA256", "SHA384", "SHA512", "MD5")]
        $AlgorithmName = 'SHA1'
    )

    # get a hashtable of all files of size greater 0
    # grouped by their length
        
    # ENUMERATE ALL FILES RECURSIVELY
    # call scriptblocks directly and pipe them together
    # this is by far the fastest way and much faster than
    # using Foreach-Object:
    & { 
        try {
            # try and use the fast API way of enumerating files recursively
            # this FAILS whenever there is any "Access Denied" errors
            Write-Progress -Activity 'Acquiring Files' -Status 'Fast Method'
            [IO.DirectoryInfo]::new($Path).GetFiles($Filter, 'AllDirectories')
        }
        catch {
            # use PowerShell's own (slow) way of enumerating files if any error occurs:
            Write-Progress -Activity 'Acquiring Files' -Status 'Falling Back to Slow Method'
            Get-ChildItem -Path $Path -Filter $Filter -File -Recurse -ErrorAction Ignore
        }
    } | 
    # EXCLUDE EMPTY FILES:
    # use direct process blocks with IF (which is much faster than Where-Object):
    & {
        process {
            # if the file has content...
            if ($_.Length -gt 0) {
                # let it pass through:
                $_
            }
        }
    } | 
    # GROUP FILES BY LENGTH, AND RETURN ONLY FILES WHERE THERE IS AT LEAST ONE
    # OTHER FILE WITH SAME SIZE
    # use direct scriptblocks with own hashtable (which is much faster than Group-Object)
    & { 
        begin 
        # start with an empty hashtable
        { $hash = @{ } } 

        process { 
            # group files by their length
            # (use "length" as hashtable key)
            $file = $_
            $key = $file.Length.toString()
            
            # if we see this key for the first time, create a generic
            # list to hold group items, and store FileInfo objects in this list
            # (specialized generic lists are faster than ArrayList):
            if ($hash.ContainsKey($key) -eq $false) {
                $hash[$key] = [Collections.Generic.List[System.IO.FileInfo]]::new()
            }
            # add file to appropriate hashtable key:
            $hash[$key].Add($file)
        } #end process block
    
        end { 
            # return only the files from groups with at least two files
            # (if there is only one file with a given length, then it 
            # cannot have any duplicates for sure):
            foreach ($pile in $hash.Values) {
                # are there at least 2 files in this pile?
                if ($pile.Count -gt 1) {
                    # yes, add it to the candidates
                    $pile
                }
            } #end foreach ($pile in $hash.Values)
        } #end end block
    } | 
    # CALCULATE THE NUMBER OF FILES TO HASH
    # collect all files and hand over en-bloc
    & {
        end { , @($input) }
    } |
    # GROUP FILES BY HASH, AND RETURN ONLY HASHES THAT HAVE AT LEAST TWO FILES:
    # use a direct scriptblock call with a hashtable (much faster than Group-Object):
    & {
        begin {
            # start with an empty hashtable
            $hash = @{ }
            
            # since this is a length procedure, a progress bar is in order
            # keep a counter of processed files:
            $c = 0
        } #end begin block
            
        process {
            $totalNumber = $_.Count
            foreach ($file in $_) {
            
                # update progress bar
                $c++
            
                # update progress bar every 20 files:
                if ($c % 20 -eq 0 -or $file.Length -gt 100MB) {
                    $percentComplete = $c * 100 / $totalNumber
                    Write-Progress -Activity 'Hashing File Content' -Status $file.Name -PercentComplete $percentComplete
                }
                
                # determine the buffer size from the smaller of 100KB or $MaxFileSize
                $bufferSize = [Math]::Min(100KB, $MaxFileSize)
                # use the specified algorithm and return partial hashes for files larger than $MaxFileSize:
                $result = Get-PsOneFileHash -StartPosition 1KB -Length $MaxFileSize -BufferSize $bufferSize -AlgorithmName $AlgorithmName -Path $file.FullName
                
                # add a "P" to partial hashes:
                if ($result.IsPartialHash) {
                    $partialHash = 'P'
                }
                else {
                    $partialHash = ''
                }
                
                # use the file hash of this file PLUS file length as a key to the hashtable
                $key = '{0}:{1}{2}' -f $result.Hash, $file.Length, $partialHash
            
                # if we see this key the first time, add a generic list to this key:
                if ($hash.ContainsKey($key) -eq $false) {
                    $hash.Add($key, [Collections.Generic.List[System.IO.FileInfo]]::new())
                }
            
                # add the file to the approriate group:
                $hash[$key].Add($file)
            } #end foreach ($file in $_)
        } #end process block
            
        end {
            # do a detail check on partial hashes if $TestDuplicatePartialHashes
            if ($TestPartialHash) {
                # first, CLONE the list of hashtable keys
                # (we cannot remove hashtable keys while enumerating the live keys list):
                $keys = @($hash.Keys).Clone()
                $i = 0
                foreach ($key in $keys) {
                    $i++
                    $percentComplete = $i * 100 / $keys.Count
                    if ($hash[$key].Count -gt 1 -and $key.EndsWith('P')) {
                        foreach ($file in $hash[$key]) {
                            Write-Progress -Activity 'Hashing Full File Content' -Status $file.Name -PercentComplete $percentComplete
                            $result = Get-FileHash -Path $file.FullName -Algorithm $AlgorithmName
                            $newkey = '{0}:{1}' -f $result.Hash, $file.Length
                            if ($hash.ContainsKey($newkey) -eq $false) {
                                $hash.Add($newkey, [Collections.Generic.List[System.IO.FileInfo]]::new())
                            }
                            $hash[$newkey].Add($file)
                        } #end foreach ($file in $hash[$key])
                        #remove the partial key entry with more than one file from the $hash hashtable
                        $hash.Remove($key)
                    } #end if ($hash[$key].Count -gt 1 -and $key.EndsWith('P'))
                } #end foreach ($key in $keys)
            } #end if ($TestPartialHash)
            
            # enumerate all keys
            $keys = @($hash.Keys).Clone()
            
            foreach ($key in $keys) {
                # if key has only one file, remove it:
                if ($hash[$key].Count -eq 1) {
                    $hash.Remove($key)
                }
            } #end foreach ($key in $keys)
            
            # return the hashtable with only duplicate files left:
            $hash
        } #end end block
    } #end of last piped code block
} #end Find-PSOneDuplicateFileFast function