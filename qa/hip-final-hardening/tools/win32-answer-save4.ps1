# win32-answer-save4.ps1 — deterministic native Save-dialog driver:
#   filename = child Edit ctrl-id 1001 (parent ComboBox) -> SetWindowText
#   save     = child Button ctrl-id 1 -> WM_COMMAND(BN_CLICKED) to the dialog
#   cancel   = child Button ctrl-id 2 (or WM_CLOSE)
# Answers every stacked dialog until none remain.
param(
  [Parameter(Mandatory=$true)][ValidateSet('save','cancel')][string]$Action,
  [string]$TargetPath = '',
  [int]$TimeoutSec = 120,
  [int]$MaxDialogs = 4,
  [string]$LogPath = "C:\dev\yue2-hip-nightly\qa\gui-final-run\export\win32-answer4.log"
)
Add-Type -TypeDefinition @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class WD {
  public delegate bool EP(IntPtr h, IntPtr lp);
  public delegate bool EC(IntPtr h, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EC cb, IntPtr lp);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowText(IntPtr h, string s);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern IntPtr PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
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
  public static IntPtr ChildById(IntPtr dlg, string cls, int id) {
    IntPtr found = IntPtr.Zero;
    EnumChildWindows(dlg, (h, lp) => {
      var c = new StringBuilder(256); GetClassName(h, c, 256);
      if (c.ToString() == cls && GetDlgCtrlID(h) == id) { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }
  public static void Click(IntPtr dlg, IntPtr btn) {
    PostMessage(dlg, 0x0111, (IntPtr)((1 & 0xffff) | (0 << 16)), btn); // WM_COMMAND, BN_CLICKED, ctrl 1
  }
  public static void Close(IntPtr h) { SendMessage(h, 0x0010, IntPtr.Zero, IntPtr.Zero); }
}
"@
function Log($m) { Add-Content -Path $LogPath -Value ("{0} {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $m) -Encoding UTF8 }
if (Test-Path $LogPath) { Remove-Item $LogPath -Force }
Log "start action=$Action target='$TargetPath'"
$app = Get-Process YuE2-Studio -ErrorAction Stop | Select-Object -First 1
Log ("app pid " + $app.Id)
$answered = 0
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline -and $answered -lt $MaxDialogs) {
  $dialogs = [WD]::Dialogs($app.Id)
  if ($dialogs.Count -eq 0) { Start-Sleep -Milliseconds 250; continue }
  $hwnd = $dialogs[0]
  Log ("DIALOG #" + ($answered + 1) + " hwnd=" + $hwnd)
  if ($Action -eq 'cancel') {
    [WD]::Close($hwnd)
    Log "WM_CLOSE (cancel)"
    $answered++
    Start-Sleep -Milliseconds 700
    continue
  }
  # the common dialog's DirectUI state binds to the edit only after it settles;
  # writing earlier is silently discarded (observed at 13:42/13:44: save used pure defaults)
  Start-Sleep -Milliseconds 3000
  $edit = [WD]::ChildById($hwnd, 'Edit', 1001)
  if ($edit -eq [IntPtr]::Zero) { Log "RESULT: filename edit (id 1001) not found"; exit 4 }
  $before = New-Object System.Text.StringBuilder 512
  [WD]::GetWindowText($edit, $before, 512) | Out-Null
  Log ("edit hwnd=" + $edit + " before='" + $before + "'")
  [WD]::SetWindowText($edit, $TargetPath) | Out-Null
  Start-Sleep -Milliseconds 600
  $after = New-Object System.Text.StringBuilder 512
  [WD]::GetWindowText($edit, $after, 512) | Out-Null
  Log ("edit after='" + $after + "'")
  $save = [WD]::ChildById($hwnd, 'Button', 1)
  if ($save -eq [IntPtr]::Zero) { Log "RESULT: save button (id 1) not found"; exit 5 }
  Log ("save button hwnd=" + $save)
  [WD]::Click($hwnd, $save)
  Log "WM_COMMAND save sent"
  $answered++
  for ($i = 0; $i -lt 26; $i++) {
    Start-Sleep -Milliseconds 300
    if ([WD]::Dialogs($app.Id).Count -eq 0) { break }
  }
  Log ("dialogs remaining: " + [WD]::Dialogs($app.Id).Count)
}
Log ("RESULT: OK answered=$answered")
exit 0
