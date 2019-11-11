function Where-ObjectFast
{
  <#
      .SYNOPSIS
      Faster Where-Object

      .DESCRIPTION
      Where-ObjectFast can replace the built-in Where-Object and improves pipeline speed considerably.
      Where-ObjectFast supports only the scriptblock version of Where-Object, so you can replace
    
      Get-Service | Where-Object { $_.Status -eq 'Running' }
    
      with
    
      Get-Service | Where-ObjectFast { $_.Status -eq 'Running' }
    
      but you cannot currently replace the short form of Where-Object:
    
      Get-Service | Where-Object Status -eq Running

      Where-ObjectFast has a performance benefit per iteration, so the more objects
      you send through the pipeline, the more significant performace benefits you will see.

      Where-ObjectFast is using a steppable pipeline internally which performs better.
      However because of this, the debugging experience will be different, and internal
      variables such as $MyInvocation may yield different results. For most every-day tasks,
      these changes are not important.

      A complete explanation of what Where-ObjectFast does can be found here:
      https://powershell.one/tricks/performance/pipeline

      .EXAMPLE
      $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

      $result = 1..1000000 | Where-ObjectFast -FilterScript {
      $_ % 5
      }

      $report = '{0} elements in {1:n2} seconds' 
      $report -f $result.Count, $stopwatch.Elapsed.TotalSeconds
  
      Demos the speed improvements. Run this script to see how well it performs,
      then replace Where-ObjectFast with the default Where-Object, and check out
      the performace difference. $result is the same in both cases.

      .LINK
      https://powershell.one/tricks/performance/pipeline
      https://github.com/TobiasPSP/Modules.PSOneTools/blob/master/PSOneTools/1.2/Where-ObjectFast.ps1
  #>


  param
  (
    # Filter scriptblock that is applied to each pipeline element.
    # When the filter scriptblock evaluates to $true, the element can pass,
    # else the element is filtered out.
    [ScriptBlock]
    $FilterScript
  )
  
  begin
  {
    # construct a hard-coded anonymous simple function:
    $code = @"
& {
  process { 
    if ($FilterScript) 
    { `$_ }
  }
}
"@
    # turn code into a scriptblock and invoke it
    # via a steppable pipeline so we can feed in data
    # as it comes in via the pipeline:
    $pip = [ScriptBlock]::Create($code).GetSteppablePipeline($myInvocation.CommandOrigin)
    $pip.Begin($true)
  }
  process 
  {
    # forward incoming pipeline data to the custom scriptblock:
    $pip.Process($_)
  }
  end
  {
    $pip.End()
  }
}