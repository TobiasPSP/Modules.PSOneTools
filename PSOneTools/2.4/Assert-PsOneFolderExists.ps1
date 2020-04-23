function Assert-PsOneFolderExists
{
  <#
    .SYNOPSIS
    Makes sure the specified folder(s) exist

    .DESCRIPTION
    If a folder does not exist, it will be created.

    .EXAMPLE
    ($Path = 'C:\test') | Assert-PsOneFolderExists
    Makes sure the folder c:\test exists. If it is still missing, it will be created.

    .EXAMPLE
    'C:\test','c:\test2' | Assert-PsOneFolderExists
    Makes sure the folders. If a folder is still missing, it will be created.

    .EXAMPLE
    Assert-PsOneFolderExists -Path 'C:\test','c:\test2'
    Makes sure the folders. If a folder is still missing, it will be created.

    .LINK
    https://powershell.one
  #>


  param
  (
    [Parameter(Mandatory,HelpMessage='Path to folder that must exist',ValueFromPipeline)]
    [string[]]
    $Path
  )
  
  process
  {
    foreach($_ in $Path)
    {
      $exists = Test-Path -Path $_ -PathType Container
      if (!$exists) { 
        Write-Warning -Message "$_ did not exist. Folder created."
        $null = New-Item -Path $_ -ItemType Directory 
      }
    }
  }
}