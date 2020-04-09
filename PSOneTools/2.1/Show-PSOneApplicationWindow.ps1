function Show-PSOneApplicationWindow
{
  <#
      .SYNOPSIS
      Brings main application window to the front (top most position on screen)

      .DESCRIPTION
      Uses a number of strategies to force an application window to the top.

      .EXAMPLE
      Show-PSOneApplicationWindow -Id $pid -Maximize 
      Brings current PowerShell window to the top and maximizes the window

      .EXAMPLE
      Get-Process -Name Notepad | Show-PSOneApplicationWindow -Maximize
      Brings notepad editor window to the top and maximizes it. 
      If there is no notepad application running, an exception is thrown.
      If there is more than one instance of notepad running, only the last instance is affected

      .LINK
      https://powershell.one/powershell-internals/extending-powershell/vbscript-and-csharp
  #>


  [CmdletBinding(DefaultParameterSetName='Id')]
  param
  (
    # Process Id of process. 
    # Process must have a main window and must not be hidden.
    [Parameter(Mandatory,ParameterSetName='Id',ValueFromPipeline,ValueFromPipelineByPropertyName,Position=0)]
    [int]
    $Id,
    
    # Process. Process must have a main window and must not be hidden.
    [Parameter(Mandatory,ParameterSetName='Process',ValueFromPipeline,Position=0)]
    [Diagnostics.Process]
    $Process,
    
    # maximizes the window after it has been brought to the top
    [switch]
    $Maximize
  )
  
  begin
  {
    # c# code to circumvent windows policies that may not allow bringing a window to the top
    # detailed discussion at https://powershell.one/powershell-internals/extending-powershell/vbscript-and-csharp
    $code = @'
using System;
using System.Runtime.InteropServices;

namespace API
{

    public class FocusWindow
    {
        [DllImport("User32.dll")]
        private static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool AttachThreadInput(IntPtr idAttach, IntPtr idAttachTo, bool fAttach);


        [DllImport("User32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("User32.dll")]
        private static extern IntPtr GetWindowThreadProcessId(IntPtr hwnd, IntPtr lpdwProcessId);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32")]
        private static extern int BringWindowToTop(IntPtr hWnd);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);

        private const uint SPI_GETFOREGROUNDLOCKTIMEOUT = 0x2000;
        private const uint SPI_SETFOREGROUNDLOCKTIMEOUT = 0x2001;
        private const int SPIF_SENDCHANGE = 0x2;

        private const int SW_HIDE = 0;
        private const int SW_SHOWNORMAL = 1;
        private const int SW_NORMAL = 1;
        private const int SW_SHOWMINIMIZED = 2;
        private const int SW_SHOWMAXIMIZED = 3;
        private const int SW_MAXIMIZE = 3;
        private const int SW_SHOWNOACTIVATE = 4;
        private const int SW_SHOW = 5;
        private const int SW_MINIMIZE = 6;
        private const int SW_SHOWMINNOACTIVE = 7;
        private const int SW_SHOWNA = 8;
        private const int SW_RESTORE = 9;
        private const int SW_SHOWDEFAULT = 10;
        private const int SW_MAX = 10;

        public static void Focus(IntPtr windowHandle, bool focus=false)
        {
            IntPtr blockingThread = GetWindowThreadProcessId(GetForegroundWindow(), IntPtr.Zero);
            IntPtr ownThread = GetWindowThreadProcessId(windowHandle, IntPtr.Zero);

            if (blockingThread == ownThread || blockingThread == IntPtr.Zero)
            {
                SetForegroundWindow(windowHandle);
                if (focus)
                { ShowWindow(windowHandle, SW_MAXIMIZE); }
            }
            else
            {
                if (AttachThreadInput(ownThread, blockingThread, true))
                {
                    BringWindowToTop(windowHandle);
                    SetForegroundWindow(windowHandle);
                    if (focus)
                    { ShowWindow(windowHandle, SW_MAXIMIZE); }
                    AttachThreadInput(ownThread, blockingThread, false);
                }
            }

            if (GetForegroundWindow() != windowHandle)
            {
                IntPtr Timeout = IntPtr.Zero;
                SystemParametersInfo(SPI_GETFOREGROUNDLOCKTIMEOUT, 0, Timeout, 0);
                SystemParametersInfo(SPI_SETFOREGROUNDLOCKTIMEOUT, 0, IntPtr.Zero, SPIF_SENDCHANGE);
                BringWindowToTop(windowHandle);
                SetForegroundWindow(windowHandle);
                if (focus)
                { ShowWindow(windowHandle, SW_MAXIMIZE); }
                SystemParametersInfo(SPI_SETFOREGROUNDLOCKTIMEOUT, 0, Timeout, SPIF_SENDCHANGE);
            }
        }
    }
}
'@

    # add type to powershell:
    Add-Type -TypeDefinition $code
  }
 
  # even though this function is pipeline-enabled, we do not use a process
  # block and instead use the end block because it won't make sense to 
  # process more than one input: only one application window can be focused.
  end
  {
    # if a process id was submitted, get the process:
    if ($PSCmdlet.ParameterSetName -eq 'Id')
    {
      try
      {
        $Process = Get-Process -Id $Id -ErrorAction Stop
      }
      catch
      {
        throw "Process ID $id not found."
      }
    }

    # get the main window handle:
    $handle = $process.MainWindowHandle

    # if there is no main window handle, emit an exception
    # background processes do not have a main window and obviously cannot be brought to the top
    # likewise, hidden and invisible windows have no window handle either
    if ($handle -eq [IntPtr]::Zero)
    {
      $message = 'Process {0} (PID={1}) has no main window.' -f $process.Name, $process.Id
      throw $message
    }

    # try and bring window handle to the top:
    [API.FocusWindow]::Focus($handle, $Maximize.IsPresent)
  }
}