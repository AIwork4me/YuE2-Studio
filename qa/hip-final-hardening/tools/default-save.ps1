# default-save.ps1 — click-Save-only dialog answerer (user-equivalent: accept
# the dialog's own default filename). Waits for the dialog to settle, then
# WM_COMMAND the Save button. Handles a replace-confirm with Yes if it appears.
param(
  [int]$TimeoutSec = 90,
  [int]$SettleMs = 3500,
  [string]$LogPath = "C:\dev\yue2-hip-nightly\qa\gui-final-run\export\default-save.log"
)
Add-Type -TypeDefinition @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class WL {
  public delegate bool EP(IntPtr h, IntPtr lp);
  public delegate bool EC(IntPtr h, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EC cb, IntPtr lp);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  public static List<IntPtr> Dialogs(uint pid) {
    var r = new List<IntPtr>();
    EnumWindows((h, lp) => { uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) { var c = new StringBuilder(256); GetClassName(h, c, 256);
        if (c.ToString() == "#32770") r.Add(h); }
      return true; }, IntPtr.Zero);
    return r;
  }
  public static bool HasEdit(IntPtr dlg) {
    bool has = false;
    EnumChildWindows(dlg, (h, lp) => { var c = new StringBuilder(64); GetClassName(h, c, 64);
      if (c.ToString() == "Edit" && GetDlgCtrlID(h) == 1001) { has = true; return false; } return true; }, IntPtr.Zero);
    return has;
  }
  public static IntPtr Btn(IntPtr dlg, int id) {
    IntPtr found = IntPtr.Zero;
    EnumChildWindows(dlg, (h, lp) => { var c = new StringBuilder(64); GetClassName(h, c, 64);
      if (c.ToString() == "Button" && GetDlgCtrlID(h) == id) { found = h; return false; } return true; }, IntPtr.Zero);
    return found;
  }
  public static void Command(IntPtr dlg, int id, IntPtr h) { PostMessage(dlg, 0x0111, (IntPtr)id, h); }
}
"@
function Log($m) { Add-Content -Path $LogPath -Value ("{0} {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $m) -Encoding UTF8 }
if (Test-Path $LogPath) { Remove-Item $LogPath -Force }
Log "start (default-name save)"
$app = Get-Process YuE2-Studio -ErrorAction Stop | Select-Object -First 1
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$done = 0
while ((Get-Date) -lt $deadline -and $done -lt 3) {
  $dialogs = [WL]::Dialogs($app.Id)
  if ($dialogs.Count -eq 0) { if ($done -gt 0) { break }; Start-Sleep -Milliseconds 250; continue }
  $hwnd = $dialogs[0]
  if ([WL]::HasEdit($hwnd)) {
    Start-Sleep -Milliseconds $SettleMs
    $save = [WL]::Btn($hwnd, 1)
    [WL]::Command($hwnd, 1, $save)
    Log ("save dialog hwnd=$hwnd -> WM_COMMAND save (btn=$save)")
    $done++
  } else {
    $yes = [WL]::Btn($hwnd, 6)
    if ($yes -eq [IntPtr]::Zero) { $yes = [WL]::Btn($hwnd, 1) }
    [WL]::Command($hwnd, 6, $yes)
    Log ("confirm hwnd=$hwnd -> YES")
    $done++
  }
  for ($i = 0; $i -lt 24; $i++) { Start-Sleep -Milliseconds 300; if ([WL]::Dialogs($app.Id).Count -eq 0) { break } }
  Log ("dialogs remaining: " + [WL]::Dialogs($app.Id).Count)
}
Log "RESULT: done=$done"
