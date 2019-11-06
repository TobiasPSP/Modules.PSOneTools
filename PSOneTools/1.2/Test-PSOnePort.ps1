function Test-PSOnePort
{
  <#
      .SYNOPSIS
      Tests a network port on a remote computer

      .DESCRIPTION
      Tests whether a port on a remote computer is responding.

      .EXAMPLE
      Test-PSOnePort -ComputerName 127.0.0.1 -Port 4000 -Timeout 1000 
      Tests whether port 4000 on the local computer is responding, 
      and waits a maximum of 1000 milliseconds

      .EXAMPLE
      Test-PSOnePort -ComputerName 127.0.0.1 -Port 4000 -Timeout 1000 -Count 30 -Delay 2000
      Tests 30 times whether port 4000 on the local computer is responding, 
      and waits a maximum of 1000 milliseconds inbetween each test

      .EXAMPLE
      Test-PSOnePort -ComputerName 127.0.0.1 -Port 4000 -Timeout 1000 -Count 0 -Delay 2000 -ExitOnSuccess
      Continuously tests whether port 4000 on the local computer is responding, 
      waits a maximum of 1000 milliseconds inbetween each test, 
      and exits as soon as the port is responding

      .LINK
      https://powershell.one/tricks/network/porttest
  #>


  param
  (
    [Parameter(Mandatory)]
    [string]
    $ComputerName,
        
    # port number to test
    [Parameter(Mandatory)]
    [int]
    $Port,

    # timeout in milliseconds
    [int]
    $Timeout = 500,

    # number of tries. A value of 0 indicates countinuous testing
    [int]
    [ValidateRange(0,1000)]
    $Count = 1,
        
    # delay (in milliseconds) inbetween continuous tests
    $Delay = 2000,
        
    # when enabled, function returns as soon as port is available
    [Switch]
    $ExitOnSuccess
  )
  $ok = $false
  $c = 0
  $isOnline = $false
  $continuous = $Count -eq 0 -or $Count -gt 1
  try
  {
    do
    {
      $c++
      if ($c -gt $Count -and !$continuous) { 
        # count exceeded
        break
      }
      $start = Get-Date
            
      $tcpobject = [system.Net.Sockets.TcpClient]::new()
      $connect = $tcpobject.BeginConnect($computername,$port,$null,$null) 
      $wait = $connect.AsyncWaitHandle.WaitOne($timeout,$false) 
        
      if(!$wait) { 
        # no response from port
        $tcpobject.Close()
        $tcpobject.Dispose()
                
        Write-Verbose "Port $Port is not responding..."
        if ($continuous) { Write-Host '.' -NoNewline }
      } else { 
        try { 
          # port is reachable
          if ($continuous) { Write-Host '!' -NoNewline }
          [void]$tcpobject.EndConnect($connect)
          $tcpobject.Close()
          $tcpobject.Dispose()
                    
          $isOnline = $true
          if ($ExitOnSuccess)
          {
            $ok = $true
            $delay = 0
          }
        }
        catch { 
          # access to port restricted
          throw "You do not have permission to contact port $Port."
        } 
      } 
      $stop = Get-Date
      $timeUsed = ($stop - $start).TotalMilliseconds
      $currentDelay = $Delay - $timeUsed
      if ($currentDelay -gt 100)
      {
        Start-Sleep -Milliseconds $currentDelay
      }
    
    } until ($ok)
  }
  finally
  {
    # dispose objects to free memory
    if ($tcpobject)
    {
      $tcpobject.Close()
      $tcpobject.Dispose()
    }
  }
  if ($continuous) { Write-Host }
    
  return $isOnline
}