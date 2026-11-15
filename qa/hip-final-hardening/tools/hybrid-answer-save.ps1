# hybrid-answer-save.ps1 — UIA-on-HWND dialog driver: find the dialog and its
# controls by raw Win32 (reliable), then act through UIA patterns on those
# exact HWNDs (routes through the dialog provider so DirectUI state updates).
param(
  [Parameter(Mandatory=$true)][ValidateSet('save','cancel')][string]$Action,
  [string]$TargetPath = '',
  [int]$TimeoutSec = 90,
  [int]$MaxDialogs = 3,
  [int]$SettleMs = 3000,
  [string]$LogPath = "C:\dev\yue2-hip-nightly\qa\gui-final-run\export\hybrid-answer.log"
)
Add-Type -TypeDefinition @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class WH {
  public delegate bool EP(IntPtr h, IntPtr lp);
  public delegate bool EC(IntPtr h, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EC cb, IntPtr lp);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  public static List<IntPtr> Dialogs(uint pid) {
    var r = new List<IntPtr>();
    EnumWindows((h, lp) => { uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) { var c = new StringBuilder(256); GetClassName(h, c, 256); if (c.ToString() == "#32770") r.Add(h); }
      return true; }, IntPtr.Zero);
    return r;
  }
  public static IntPtr ChildById(IntPtr dlg, string cls, int id) {
    IntPtr found = IntPtr.Zero;
    EnumChildWindows(dlg, (h, lp) => { var c = new StringBuilder(256); GetClassName(h, c, 256);
      if (c.ToString() == cls && GetDlgCtrlID(h) == id) { found = h; return false; }
      return true; }, IntPtr.Zero);
    return found;
  }
  public static void Close(IntPtr h) { SendMessage(h, 0x0010, IntPtr.Zero, IntPtr.Zero); }
}
"@
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
function Log($m) { Add-Content -Path $LogPath -Value ("{0} {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $m) -Encoding UTF8 }
if (Test-Path $LogPath) { Remove-Item $LogPath -Force }
Log "start action=$Action target='$TargetPath' settle=$SettleMs"
$app = Get-Process YuE2-Studio -ErrorAction Stop | Select-Object -First 1
$answered = 0
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline -and $answered -lt $MaxDialogs) {
  $dialogs = [WH]::Dialogs($app.Id)
  if ($dialogs.Count -eq 0) { Start-Sleep -Milliseconds 250; continue }
  $hwnd = $dialogs[0]
  $editH = [WH]::ChildById($hwnd, 'Edit', 1001)
  Log ("DIALOG #" + ($answered + 1) + " hwnd=" + $hwnd + " edit=" + $editH)
  if ($Action -eq 'cancel') {
    [WH]::Close($hwnd); Log "WM_CLOSE (cancel)"; $answered++; Start-Sleep -Milliseconds 700; continue
  }
  if ($editH -eq [IntPtr]::Zero) { Log "RESULT: no edit 1001 (confirm dialog?)"; exit 4 }
  Start-Sleep -Milliseconds $SettleMs
  $edit = [System.Windows.Automation.AutomationElement]::FromHandle($editH)
  $vp = $edit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
  $vp.SetValue($TargetPath)
  Start-Sleep -Milliseconds 900
  $now = $vp.Current.ValueAsString()
  Log ("filename via UIA: '$now'")
  if ($now -notmatch [regex]::Escape([System.IO.Path]::GetFileName($TargetPath))) { Log "RESULT: value did not stick"; exit 6 }
  $saveH = [WH]::ChildById($hwnd, 'Button', 1)
  if ($saveH -eq [IntPtr]::Zero) { Log "RESULT: no save button"; exit 5 }
  $btn = [System.Windows.Automation.AutomationElement]::FromHandle($saveH)
  $btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
  Log "UIA Save invoked on button hwnd $saveH"
  $answered++
  for ($i = 0; $i -lt 26; $i++) { Start-Sleep -Milliseconds 300; if ([WH]::Dialogs($app.Id).Count -eq 0) { break } }
  Log ("dialogs remaining: " + [WH]::Dialogs($app.Id).Count)
}
Log ("RESULT: OK answered=$answered")
exit 0
