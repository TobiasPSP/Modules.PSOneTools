function Get-PSOneDirectory
{
  <#
    .SYNOPSIS
    Lists the content of a folder and supports long path names (>256 characters)

    .DESCRIPTION
    Uses the Microsoft.Experimental.IO assembly to list folder contents without
    path name length limitations. You can use this function to search for and identify 
    files and folders that use long path names.

    .EXAMPLE
    Get-PSOneDirectory -Path C:\Windows -ErrorAction SilentlyContinue
    Dumps the entire content of the windows folder and reports all files
    and folders and their path length. Error messages due to folders
    where you have no access permissions are suppressed.

    .EXAMPLE
    Get-PSOneDirectory -Path C:\Windows -ErrorAction SilentlyContinue |
      Where-Object PathLength -gt 200
    Lists files and folders with a path length of greater than 200 characters. 
    Error messages due to folders where you have no access permissions are suppressed.

    .LINK
    https://powershell.one
    https://github.com/TobiasPSP/Modules.PSOneTools/blob/master/PSOneTools/1.5/Get-PSOneDirectory.ps1
    https://github.com/TobiasPSP/Modules.PSOneTools/blob/master/PSOneTools/1.5/Internal/Install-LongPathSupport.ps1
  #>


    [CmdletBinding()]
    param
    (
        # Folder path to enumerate
        [Parameter(Mandatory)]
        [string]
        $Path
    )

    # load DLL if not loaded yet
    # I am loading the DLL on demand because it is seldom used
    # and should only be loaded when someone wants to run
    # this function:
    & "$PSScriptRoot\Internal\Install-LongPathSupport"

    # emit the path and its length:
    [PSCustomObject]@{
        PathLength = $path.Length
        Type = 'Folder'
        Path = $Path
    }

    # try and enumerate subfolders:
    try
    {
        [Microsoft.Experimental.IO.LongPathDirectory]::EnumerateDirectories($Path) |
        ForEach-Object {
            # recursively enumerate child folders:
            Get-PSOneDirectory -path $_
        }
    }
    catch 
    {
        Write-Error "Unable to open folder '$Path': $_"
    }
    
    # try and enumerate files in folder
    try
    {
        # get all files from current folder:
        [Microsoft.Experimental.IO.LongPathDirectory]::EnumerateFiles($Path) |
        ForEach-Object {
            [PSCustomObject]@{
                PathLength = $_.Length
                Type = 'Folder'
                Path = $_
            }
        }
    }
    catch 
    {
        Write-Error "Unable to open folder '$Path': $_"
    }    
} 
