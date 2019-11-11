

function Test-PSOneScript
{
  <#
      .SYNOPSIS
      Parses a PowerShell Script (*.ps1, *.psm1, *.psd1)

      .DESCRIPTION
      Invokes the simple PSParser and returns tokens and syntax errors

      .EXAMPLE
      Test-PSOneScript -Path c:\test.ps1
      Parses the content of c:\test.ps1 and returns tokens and syntax errors

      .EXAMPLE
      Get-ChildItem -Path $home -Recurse -Include *.ps1,*.psm1,*.psd1 -File |
         Test-PSOneScript |
         Out-GridView

      parses all PowerShell files found anywhere in your user profile

      .EXAMPLE
      Get-ChildItem -Path $home -Recurse -Include *.ps1,*.psm1,*.psd1 -File |
         Test-PSOneScript |
         Where-Object Errors

      parses all PowerShell files found anywhere in your user profile
      and returns only those files that contain syntax errors

      .LINK
      https://powershell.one/powershell-internals/parsing-and-tokenization/simple-tokenizer
      https://github.com/TobiasPSP/Modules.PSOneTools/blob/master/PSOneTools/1.4/Test-PSOneScript.ps1

  #>

  [CmdletBinding(DefaultParameterSetName='Path')]
  param
  (
    # Path to PowerShell script file
    # can be a string or any object that has a "Path" 
    # or "FullName" property:
    [String]
    [Parameter(Mandatory,ValueFromPipeline,ParameterSetName='Path')]
    [Alias('FullName')]
    $Path,

    # PowerShell Code as String
    # you can also submit a ScriptBlock which will automatically be converted
    # to a string. ScriptBlocks by default cannot contain syntax errors because
    # they are parsed already.
    [String]
    [Parameter(Mandatory,ValueFromPipeline,ParameterSetName='Code')]
    $Code
  )
  
  begin
  {
    $errors = $null
  }
  process
  {
    # create a variable to receive syntax errors:
    $errors = $null
    # tokenize PowerShell code:

    # if a path was submitted, read code from file,
    if ($PSCmdlet.ParameterSetName -eq 'Path')
    {
        $code = Get-Content -Path $Path -Raw -Encoding Default
        $name = Split-Path -Path $Path -Leaf
        $filepath = $Path
    }
    else
    {
        # else the code is already present in $Code
        $name = $Code
        $filepath = ''
    }

    # return the results as a custom object
    [PSCustomObject]@{
      Name = $name
      Path = $filepath
      Tokens = [Management.Automation.PSParser]::Tokenize($code, [ref]$errors)
      Errors = $errors | Select-Object -ExpandProperty Token -Property Message
    }  
  }
}