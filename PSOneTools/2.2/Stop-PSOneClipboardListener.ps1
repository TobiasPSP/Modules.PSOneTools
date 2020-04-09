
function Stop-PSOneClipboardListener
{
  <#
      .SYNOPSIS
      Stops the clipboard monitor and ends the background thread.

      .DESCRIPTION
      As long as the clipboard monitor is running in the background, any valid PowerShell code that is copied to the clipboard opens a new editor pane.
      So it is important to stop the clipboard monitor when it is not useful anymore. 
      Make sure you stop the clipboard monitor before you close the ISE. If the background thread continues to run, the ISE window may close but the ISE process may still run.

      .EXAMPLE
      Stop-PSOneClipboardListener
      Stops the clipboard monitor, and ends the background thread.
  #>

  # check to see if the script-global variable with the background
  # thread information still exists:
  $exists = Test-Path -Path 'variable:backgroundThread'
  # if it does not exist (anymore), either the clipboard monitor has not yet been started,
  # or was already stopped. In either case, there is nothing left to do, so return:
  if ($exists -eq $false) { return }
  
  # stop the background thread by setting Enabled to $false. The background
  # thread checks this value for each loop iteration:
  $infos = $script:backgroundThread
  $infos.Hash.Enabled = $false
  
  # it may take a couple hundred milliseconds for the background thread to
  # actually check the hashtable and end, so check the thread handle and wait
  # for the background thread to stop:
  $c = 0
  do
  {
    $c++
    
    # if the background thread does not stop as expected,
    # try and force it to stop by using Stop()
    # This should actually never be necessary.
    # Forcefully stopping a thread is generally not a good idea and
    # may cause all kinds of exceptions
    if ($c -gt 10)
    {
      try { $infos.PowerShell.Stop() } catch {}
      break
    }
    Start-Sleep -Milliseconds 300
  } until ($infos.Handle.IsCompleted)

  try 
  {
    # complete the async call with EndInvoke():
    $null = $infos.PowerShell.EndInvoke($infos.Handle)
    # close the internal runspace:
    $infos.PowerShell.Runspace.Close()
  } catch {}
  # free the background thread memory:
  $infos.PowerShell.Dispose()
  # remove the script-global variable:
  Remove-Variable -Name backgroundThread -Scope script
}
