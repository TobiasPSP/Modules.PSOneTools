function Get-PSOneClipboardListenerStatus
{
  <#
      .SYNOPSIS
      Gets information from the background thread that monitors the clipboard

      .DESCRIPTION
      Outputs the current content of the shared hashtable that always returns the current state of the clipboard monitor
      This information can be used for debugging and to better understand how the clipboard monitor works

      .EXAMPLE
      Get-ClipboardListenerStatus
      returns the current state of the clipboard monitor
  #>

  # take the script-global object and return the hashtable, and
  # select status, possible exception messages, and the last text
  # that was read from the clipboard:
  $script:backgroundThread.Hash |
    Select-Object -Property Status, Error, Text
}

