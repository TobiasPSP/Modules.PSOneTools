function Find-PSOneDuplicateFileFast
{
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
      find log files in the Windows folder with duplicate content

      .LINK
      https://powershell.one
  #>


  param
  (
    # Path of folder to recursively search
    [String]
    [Parameter(Mandatory)]
    $Path,
  
    # Filter to apply. Default is '*' (all Files) 
    [String]
    $Filter = '*',
    
    # when there are multiple files with same partial hash
    # they may still be different. When setting this switch,
    # full hashes are calculated which may take a very long time
    # for large files and/or slow networks
    [switch]
    $TestPartialHash,
    
    # use partial hashes for files larger than this:
    [int64]
    $MaxFileSize = 100KB
  )

  # get a hashtable of all files of size greater 0
  # grouped by their length
  
  
  # ENUMERATE ALL FILES RECURSIVELY
  # call scriptblocks directly and pipe them together
  # this is by far the fastest way and much faster than
  # using Foreach-Object:
  & { 
    try
    {
      # try and use the fast API way of enumerating files recursively
      # this FAILS whenever there is any "Access Denied" errors
      Write-Progress -Activity 'Acquiring Files' -Status 'Fast Method'
      [IO.DirectoryInfo]::new($Path).GetFiles('*', 'AllDirectories')
    }
    catch
    {
      # use PowerShell's own (slow) way of enumerating files if any error occurs:
      Write-Progress -Activity 'Acquiring Files' -Status 'Falling Back to Slow Method'
      Get-ChildItem -Path $Path -File -Recurse -ErrorAction Ignore
    }
  } | 
  # EXCLUDE EMPTY FILES:
  # use direct process blocks with IF (which is much faster than Where-Object):
  & {
    process
    {
      # if the file has content...
      if ($_.Length -gt 0)
      {
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
    { $hash = @{} } 

    process 
    { 
      # group files by their length
      # (use "length" as hashtable key)
      $file = $_
      $key = $file.Length.toString()
      
      # if we see this key for the first time, create a generic
      # list to hold group items, and store FileInfo objects in this list
      # (specialized generic lists are faster than ArrayList):
      if ($hash.ContainsKey($key) -eq $false) 
      {
        $hash[$key] = [Collections.Generic.List[System.IO.FileInfo]]::new()
      }
      # add file to appropriate hashtable key:
      $hash[$key].Add($file)
    } 
  
    end 
    { 
      # return only the files from groups with at least two files
      # (if there is only one file with a given length, then it 
      # cannot have any duplicates for sure):
      foreach($pile in $hash.Values)
      {
        # are there at least 2 files in this pile?
        if ($pile.Count -gt 1)
        {
          # yes, add it to the candidates
          $pile
        }
      }
    } 
  } | 
  # CALCULATE THE NUMBER OF FILES TO HASH
  # collect all files and hand over en-bloc
  & {
    end { ,@($input) }
  } |
  # GROUP FILES BY HASH, AND RETURN ONLY HASHES THAT HAVE AT LEAST TWO FILES:
  # use a direct scriptblock call with a hashtable (much faster than Group-Object):
  & {
    begin 
    {
      # start with an empty hashtable
      $hash = @{}
      
      # since this is a length procedure, a progress bar is in order
      # keep a counter of processed files:
      $c = 0
    }
      
    process
    {
      $totalNumber = $_.Count
      foreach($file in $_)
      {
      
        # update progress bar
        $c++
      
        # update progress bar every 20 files:
        if ($c % 20 -eq 0 -or $file.Length -gt 100MB)
        {
          $percentComplete = $c * 100 / $totalNumber
          Write-Progress -Activity 'Hashing File Content' -Status $file.Name -PercentComplete $percentComplete
        }
      
        # use the file hash of this file PLUS file length as a key to the hashtable
        # use the fastest algorithm SHA1, and use partial hashes for files larger than 100KB:
        $bufferSize = [Math]::Min(100KB, $MaxFileSize)
        $result = Get-PsOneFileHash -StartPosition 1KB -Length $MaxFileSize -BufferSize $bufferSize -AlgorithmName SHA1 -Path $file.FullName
        
        # add a "P" to partial hashes:
        if ($result.IsPartialHash) {
          $partialHash = 'P'
        }
        else
        {
          $partialHash = ''
        }
        
        
        $key = '{0}:{1}{2}' -f $result.Hash, $file.Length, $partialHash
      
        # if we see this key the first time, add a generic list to this key:
        if ($hash.ContainsKey($key) -eq $false)
        {
          $hash.Add($key, [Collections.Generic.List[System.IO.FileInfo]]::new())
        }
      
        # add the file to the approriate group:
        $hash[$key].Add($file)
      }
    }
      
    end
    {
      # remove all hashtable keys with only one file in them
      
      
      
      # do a detail check on partial hashes
      if ($TestPartialHash)
      {
        # first, CLONE the list of hashtable keys
        # (we cannot remove hashtable keys while enumerating the live
        # keys list):
        $keys = @($hash.Keys).Clone()
        $i = 0
        Foreach($key in $keys)
        {
          $i++
          $percentComplete = $i * 100 / $keys.Count
          if ($hash[$key].Count -gt 1 -and $key.EndsWith('P'))
          {
            foreach($file in $hash[$key])
            {
              Write-Progress -Activity 'Hashing Full File Content' -Status $file.Name -PercentComplete $percentComplete
              $result = Get-FileHash -Path $file.FullName -Algorithm SHA1
              $newkey = '{0}:{1}' -f $result.Hash, $file.Length
              if ($hash.ContainsKey($newkey) -eq $false)
              {
                $hash.Add($newkey, [Collections.Generic.List[System.IO.FileInfo]]::new())
              }
              $hash[$newkey].Add($file)
            }
            $hash.Remove($key)
          }
        }
      }
      
      # enumerate all keys...
      $keys = @($hash.Keys).Clone()
      
      foreach($key in $keys)
      {
        # ...if key has only one file, remove it:
        if ($hash[$key].Count -eq 1)
        {
          $hash.Remove($key)
        }
      }
       
      
       
      # return the hashtable with only duplicate files left:
      $hash
    }
  }
}