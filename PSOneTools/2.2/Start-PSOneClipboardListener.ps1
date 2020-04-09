function Start-PSOneClipboardListener
{
  <#
      .SYNOPSIS
      Monitors the clipboard, and when new valid PowerShell code is detected, opens the code in an editor

      .DESCRIPTION
      Uses a background thread to monitor the clipboard. If new valid PowerShell code is detected, an action is invoked. The action depends on the editor used, and opens the clipboard code in an editor window

      .EXAMPLE
      Start-PSOneClipboardListener
      Starts the background clipboard monitor

      .NOTES
      Anything that is copied to the clipboard can trigger the monitor, so make sure you turn off the monitor once you are done.

      .LINK
      https://powershell.one
  #>

  # a synchronized hashtable is a thread-safe way to share information
  # between the foreground thread and the background thread
  # the hashtable tells the background thread where to find the ISE object model, and the ISE window handle
  # the background thread uses this information to open a new editor pane in the ISE, then bring
  # the ISE to the foreground
  # The foreground thread can use the hashtable to stop the background thread by setting
  # Enabled to $false. The background thread monitors this information and stops when it
  # is set to $false:
  $hash = [hashtable]::Synchronized(@{
      ISE = $psIse
      WindowHandle = (Get-Process -Id $pid).MainWindowHandle
      Enabled = $true
      Status = ''
      Text = ''
      Error = ''
  })

  # this is the code executed by the background thread:
  $code = {
    # it receives the information from the foreground thread via a
    # thread-safe hashtable:
    param($hash)

    # it then accesses the ISE editor via the AutomationClient interface
    # this is a robust way to send the ISE window to the foreground later:
    Add-Type -AssemblyName UIAutomationClient 
    $element = [Windows.Automation.AutomationElement]::FromHandle($hash.WindowHandle)

    # the clipboard content is cleared to be able to pick up changes:
    Set-ClipBoard -Value ''
    $lastText = ''
    
    # this is the background monitoring loop
    do
    {
      try
      {
        # the current clipboard content is read and sent to Out-String to convert
        # multiline strings (string arrays) to a single string:
        $newText = Get-ClipBoard | Out-String
        
        # if the clipboard contains new text...
        if (($lastText -ne $newText) -and ([string]::IsNullOrEmpty($newText) -eq $false))
        {
          try
          {
            # ...text is placed into the hashtable for diagnostic purposes
            # (not really required for the functionality)
            $hash.Text = $newText

            # is it valid PowerShell code? Converting the clipboard
            # content to a scriptblock is a quick and easy way to tell:
            # if the clipboard does NOT contain valid PowerShell code,
            # then this will raise an exception:
            $null = [ScriptBlock]::Create($newText)
    
            # check to see whether the current clipboard code is already open
            # in one of the ISE panes:
            $found = $false
            foreach($file in $hash.ISE.CurrentPowerShellTab.Files)
            {
              if ($file.Editor.Text -eq $newText)
              {
                # was already open, so switch to that pane and DO NOT open
                # a new pane:
                $hash.ISE.CurrentPowerShellTab.Files.SelectedFile = $file
                $found = $true
                $hash.Status = 'Existing Document Selected'
                break
              }
            }
        
            # if the clipboard text was not yet open in ISE,
            # open a new pane:
            if ($found -eq $false)
            {
              $file = $hash.ISE.CurrentPowerShellTab.Files.Add()
              $file.Editor.Text = $newText
              $file.Editor.SetCaretPosition(1,1)
              $hash.Status = 'New Document Created'
            }

            # use the UIAutomationClient interface to focus the ISE
            # editor and bring its window to the front:
            $element.SetFocus()
          }
          catch
          {
            # the clipboard content was no valid PowerShell code:
            $hash.Status = "Syntax Error: $_"
          }
        }
      }
      catch
      {
        # something else failed. The error message is placed into the
        # hashtable so you can diagnose the problem from the foreground
        # thread:
        $hash.Error = $_.Exception.Message
      }
      
      # exit the monitoring loop if the foreground thread has set Enabled to $false:
      if ($hash.Enabled -eq $false) { break }
      
      # remember the last clipboard text, and sleep for a moment
      # until the loop runs again:
      $lastText = $newText
      Start-Sleep -Milliseconds 300
    } while ($hash.Enabled)
  }

  # monitoring the clipboard needs to run in its own background
  # thread so that ISE is not occupied by it and runs normally
  # By default, new threads are created in MTA mode. To access
  # the clipboard, STA mode is required, so we need to create
  # and prepare our own Runspace and cannot use the default
  # runspace:
  $Runspace = [runspacefactory]::CreateRunspace()
  $Runspace.ApartmentState = 'STA'
  [PowerShell]$powershell = [PowerShell]::Create()
  $powershell.Runspace = $Runspace
  $Runspace.Open()
  
  # add the code to the thread, and pass the hash as argument:
  $null = $powershell.AddScript($code).AddArgument($hash)
  
  # we are using a script-global variable $backgroundThread to store
  # all vital information about the background thread
  # that is necessary so that we can eventually stop the background
  # thread:
  try
  {
    $script:backgroundThread = [PSCustomObject]@{
      # keep a reference to the background thread:
      PowerShell = $powershell
      # also keep a reference to the handle returned when
      # we now launch the background thread asynchronously:
      Handle = $powershell.BeginInvoke()
      # also keep a reference to the hashtable that enables
      # us to later stop the background thread as well as 
      # read diagnostic information if something isn't working
      # right:
      Hash = $hash
    }
  }
  catch {}
  finally {
    # make sure we register the PowerShell engine event that fires when PowerShell exits,
    # and stop the background thread:
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Stop-ClipboardListener } -SupportEvent
  }
}

