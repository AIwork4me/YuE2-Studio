# win32-answer-save3.ps1 — answer the app's native Save dialog like a user:
# foreground the dialog, Ctrl+A, type the full target path, ENTER. Handles
# stacked dialogs (the app fires the choose POST more than once per click).
# Cancel mode: WM_CLOSE (= Cancel semantics).
param(
  [Parameter(Mandatory=$true)][ValidateSet('save','cancel')][string]$Action,
  [string]$TargetPath = '',
  [int]$TimeoutSec = 120,
  [int]$MaxDialogs = 4,
  [string]$LogPath = "C:\dev\yue2-hip-nightly\qa\gui-final-run\export\win32-answer3.log"
)
Add-Type -TypeDefinition @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class WE7 {
  public delegate bool EP(IntPtr h, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr lp);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  public static List<IntPtr> Dialogs(uint pid) {
    var r = new List<IntPtr>();
    EnumWindows((h, lp) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) {
        var c = new StringBuilder(256); GetClassName(h, c, 256);
        if (c.ToString() == "#32770") r.Add(h);
      }
      return true;
    }, IntPtr.Zero);
    return r;
  }
  public static void Close(IntPtr h) { SendMessage(h, 0x0010, IntPtr.Zero, IntPtr.Zero); }
  public static bool Fore(IntPtr h) { return SetForegroundWindow(h); }
}
"@
function Log($m) { Add-Content -Path $LogPath -Value ("{0} {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $m) -Encoding UTF8 }
if (Test-Path $LogPath) { Remove-Item $LogPath -Force }
Log "start action=$Action target='$TargetPath'"

$wsh = New-Object -ComObject WScript.Shell
$app = Get-Process YuE2-Studio -ErrorAction Stop | Select-Object -First 1
Log ("app pid " + $app.Id)
$answered = 0
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline -and $answered -lt $MaxDialogs) {
  $dialogs = [WE7]::Dialogs($app.Id)
  if ($dialogs.Count -eq 0) { Start-Sleep -Milliseconds 250; continue }
  $hwnd = $dialogs[0]
  Log ("DIALOG #" + ($answered + 1) + " hwnd=" + $hwnd)
  if ($Action -eq 'cancel') {
    [WE7]::Close($hwnd)
    Log "WM_CLOSE (cancel)"
    $answered++
    Start-Sleep -Milliseconds 700
    continue
  }
  [WE7]::Fore($hwnd) | Out-Null
  Start-Sleep -Milliseconds 500
  $wsh.SendKeys('^a')
  Start-Sleep -Milliseconds 150
  $wsh.SendKeys($TargetPath)
  Start-Sleep -Milliseconds 500
  $wsh.SendKeys('{ENTER}')
  Log "typed path + ENTER"
  $answered++
  for ($i = 0; $i -lt 24; $i++) {
    Start-Sleep -Milliseconds 300
    if ([WE7]::Dialogs($app.Id).Count -eq 0) { break }
  }
  Log ("dialogs remaining: " + [WE7]::Dialogs($app.Id).Count)
}
Log ("RESULT: OK answered=$answered")
exit 0
