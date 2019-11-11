function Expand-PSOneToken
{
  <#
      .SYNOPSIS
      Expands all nested token from a token of type "StringExpandable"

      .DESCRIPTION
      Recursively emits all tokens embedded in a token of type "StringExpandable"
      The original token is also emitted.

      .EXAMPLE
      Get-PSOneToken -Code '"Hello $host"' -TokenKind StringExpandable | Expand-PSOneToken 
      Emits all tokens, including the embedded (nested) tokens
      .LINK
      https://powershell.one/powershell-internals/parsing-and-tokenization/advanced-tokenizer
      https://github.com/TobiasPSP/Modules.PSOneTools/blob/master/PSOneTools/1.4/Expand-PSOneToken.ps1
  #>

  # use the most specific parameter as default:
  [CmdletBinding(DefaultParameterSetName='ExpandableString')]
  param
  (
    # binds a token of type "StringExpandableToken"
    [Parameter(Mandatory,ParameterSetName='ExpandableString',
                Position=0,ValueFromPipeline)]
    [Management.Automation.Language.StringExpandableToken]
    $StringExpandable,

    # binds all tokens
    [Parameter(Mandatory,ParameterSetName='Token',
                Position=0,ValueFromPipeline)]
    [Management.Automation.Language.Token]
    $Token
  )

  process
  {
    switch($PSCmdlet.ParameterSetName)
    {
      # recursively expand token of type "StringExpandable"
      'ExpandableString'  { 
        $StringExpandable 
        $StringExpandable.NestedTokens | 
          Where-Object { $_ } | 
          Expand-PSOneToken
      }
      # return regular token as-is:
      'Token'             { $Token }
      # should never occur:
      default             { Write-Warning $_ }
    }
  }
}