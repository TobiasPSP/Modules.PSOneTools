

function Get-PSOneToken
{
  <#
      .SYNOPSIS
      Parses a PowerShell Script (*.ps1, *.psm1, *.psd1) and returns the token

      .DESCRIPTION
      Invokes the advanced PowerShell Parser and returns tokens and syntax errors

      .EXAMPLE
      Get-PSOneToken -Path c:\test.ps1
      Parses the content of c:\test.ps1 and returns tokens and syntax errors

      .EXAMPLE
      Get-ChildItem -Path $home -Recurse -Include *.ps1,*.psm1,*.psd1 -File |
      Get-PSOneToken |
      Out-GridView

      parses all PowerShell files found anywhere in your user profile

      .EXAMPLE
      Get-ChildItem -Path $home -Recurse -Include *.ps1,*.psm1,*.psd1 -File |
      Get-PSOneToken |
      Where-Object Errors

      parses all PowerShell files found anywhere in your user profile
      and returns only those files that contain syntax errors

      .LINK
      https://powershell.one/powershell-internals/parsing-and-tokenization/advanced-tokenizer
      https://github.com/TobiasPSP/Modules.PSOneTools/blob/master/PSOneTools/1.4/Get-PSOneToken.ps1
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
    
    # PowerShell Code as ScriptBlock
    [ScriptBlock]
    [Parameter(Mandatory,ValueFromPipeline,ParameterSetName='ScriptBlock')]
    $ScriptBlock,
    
    
    # PowerShell Code as String
    [String]
    [Parameter(Mandatory, ValueFromPipeline,ParameterSetName='Code')]
    $Code,
    
    # the kind of token requested. If neither TokenKind nor TokenFlag is requested, 
    # a full tokenization occurs
    [System.Management.Automation.Language.TokenKind[]]
    $TokenKind = $null,

    # the kind of token requested. If neither TokenKind nor TokenFlag is requested, 
    # a full tokenization occurs
    [System.Management.Automation.Language.TokenFlags[]]
    $TokenFlag = $null,

    # include nested token that are contained inside 
    # ExpandableString tokens
    [Switch]
    $IncludeNestedToken

  )
  
  begin
  {
    # create variables to receive tokens and syntax errors:
    $errors = 
    $tokens = $null

    # return tokens only?
    # when the user submits either one of these parameters, the return value should
    # be tokens of these kinds:
    $returnTokens = ($PSBoundParameters.ContainsKey('TokenKind')) -or 
    ($PSBoundParameters.ContainsKey('TokenFlag'))
  }
  process
  {
    # if a scriptblock was submitted, convert it to string
    if ($PSCmdlet.ParameterSetName -eq 'ScriptBlock')
    {
      $Code = $ScriptBlock.ToString()
    }

    # if a path was submitted, read code from file,
    if ($PSCmdlet.ParameterSetName -eq 'Path')
    {
      $code = Get-Content -Path $Path -Raw -Encoding Default
      $name = Split-Path -Path $Path -Leaf
      $filepath = $Path

      # parse the file:
      $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path, 
        [ref] $tokens, 
      [ref]$errors)
    }
    else
    {
      # else the code is already present in $Code
      $name = $Code
      $filepath = ''

      # parse the string code:
      $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $Code, 
        [ref] $tokens, 
      [ref]$errors)
    }

    if ($IncludeNestedToken)
    {
      # "unwrap" nested token
      $tokens = $tokens | Expand-PSOneToken
    }

    if ($returnTokens)
    {
      # filter token and use fast scriptblock filtering instead of Where-Object:
      $tokens |
      & { process { if ($TokenKind -eq $null -or 
          $TokenKind -contains $_.Kind) 
          { $_ }
      }} |
      & { process {
          $token = $_
          if ($TokenFlag -eq $null) { $token }
          else {
            $TokenFlag | 
            Foreach-Object { 
              if ($token.TokenFlags.HasFlag($_)) 
            { $token } } | 
            Select-Object -First 1
          }
        }
      }
            
    }
    else
    {
      # return the results as a custom object
      [PSCustomObject]@{
        Name = $name
        Path = $filepath
        Tokens = $tokens
        # "move" nested "Extent" up one level 
        # so all important properties are shown immediately
        Errors = $errors | 
        Select-Object -Property Message, 
        IncompleteInput, 
        ErrorId -ExpandProperty Extent
        Ast = $ast
      }
    }  
  }
}