function Foreach-ObjectFast
{
  <#
      .SYNOPSIS
      Faster Foreach-Object

      .DESCRIPTION
      Foreach-ObjectFast can replace the built-in Foreach-Object and improves pipeline speed considerably.
      Foreach-ObjectFast supports only the most commonly used parameters -Begin, -Process, and -End, so you can replace
    
      1..100 | Foreach-Object { 'Server{0:d3}' -f $_ }
    
      with
    
      1..100 | Foreach-ObjectFast { 'Server{0:d3}' -f $_ }
    
      but you cannot currently replace instances of Foreach-Object that uses the less commonly used parameters, 
      like -RemainingScripts, -MemberNames, and -ArgumentList

      Foreach-ObjectFast has a performance benefit per iteration, so the more objects
      you send through the pipeline, the more significant performace benefits you will see.

      Foreach-ObjectFast is using a steppable pipeline internally which performs better.
      However because of this, the debugging experience will be different, and internal
      variables such as $MyInvocation may yield different results. For most every-day tasks,
      these changes are not important.

      A complete explanation of what Where-ObjectFast does can be found here:
      https://powershell.one/tricks/performance/pipeline

      .EXAMPLE
      $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

      $result = 1..1000000 | Foreach-ObjectFast -Process {
        "I am at $_"
      }

      $report = '{0} elements in {1:n2} seconds' 
      $report -f $result.Count, $stopwatch.Elapsed.TotalSeconds 
      
      Demos the speed improvements. Run this script to see how well it performs,
      then replace Foreach-ObjectFast with the default Foreach-Object, and check out
      the performace difference. $result is the same in both cases.

      .LINK
      https://powershell.one/tricks/performance/pipeline
  #>
  
  param
  (
    # executes for each pipeline element
    [ScriptBlock]
    $Process,
    
    # executes once before the pipeline is started.
    # can be used for initialization routines
    [ScriptBlock]
    $Begin,
    
    # executes once after all pipeline elements have been processed
    # can be used to do cleanup work
    [ScriptBlock]
    $End
  )
  
  begin
  {
    # construct a hard-coded anonymous simple function from
    # the submitted scriptblocks:
    $code = @"
& {
  begin
  {
    $Begin
  }
  process
  {
    $Process
  }
  end
  {
    $End
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