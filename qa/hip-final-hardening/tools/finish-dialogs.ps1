# finish-dialogs.ps1 — drain the app's dialog stack: confirm dialogs get Yes,
# save dialogs get the target path (UIA-on-HWND) + Save. Until none remain.
param(
  [string]$TargetPath = '',
  [int]$TimeoutSec = 60,
  [int]$SettleMs = 2500,
  [string]$LogPath = "C:\dev\yue2-hip-nightly\qa\gui-final-run\export\finish-dialogs.log"
)
Add-Type -TypeDefinition @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class WF {
  public delegate bool EP(IntPtr h, IntPtr lp);
  public delegate bool EC(IntPtr h, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EC cb, IntPtr lp);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  public static List<KeyValuePair<IntPtr, string>> Dialogs(uint pid) {
    var r = new List<KeyValuePair<IntPtr, string>>();
    EnumWindows((h, lp) => { uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) { var c = new StringBuilder(256); GetClassName(h, c, 256);
        if (c.ToString() == "#32770") { var t = new StringBuilder(256); GetWindowText(h, t, 256);
          r.Add(new KeyValuePair<IntPtr, string>(h, t.ToString())); } }
      return true; }, IntPtr.Zero);
    return r;
  }
  public static IntPtr ChildById(IntPtr dlg, string cls, int id) {
    IntPtr found = IntPtr.Zero;
    EnumChildWindows(dlg, (h, lp) => { var c = new StringBuilder(256); GetClassName(h, c, 256);
      if (c.ToString() == cls && GetDlgCtrlID(h) == id) { found = h; return false; } return true; }, IntPtr.Zero);
    return found;
  }
  public static void Command(IntPtr dlg, int ctrlId, IntPtr h) {
    PostMessage(dlg, 0x0111, (IntPtr)ctrlId, h);
  }
}
"@
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
function Log($m) { Add-Content -Path $LogPath -Value ("{0} {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $m) -Encoding UTF8 }
if (Test-Path $LogPath) { Remove-Item $LogPath -Force }
Log "start target='$TargetPath'"
$app = Get-Process YuE2-Studio -ErrorAction Stop | Select-Object -First 1
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
  $dialogs = [WF]::Dialogs($app.Id)
  if ($dialogs.Count -eq 0) { Log "no dialogs left"; break }
  $d = $dialogs[0]
  $hwnd = $d.Key; $title = $d.Value
  Log ("dialog hwnd=$hwnd title='$title'")
  if ($title -match '确认|Confirm') {
    $yes = [WF]::ChildById($hwnd, 'Button', 6)
    if ($yes -eq [IntPtr]::Zero) { $yes = [WF]::ChildById($hwnd, 'Button', 1) }
    [WF]::Command($hwnd, 6, $yes)
    Log "YES sent"
    Start-Sleep -Milliseconds 1500
    continue
  }
  $editH = [WF]::ChildById($hwnd, 'Edit', 1001)
  if ($editH -eq [IntPtr]::Zero) { Log "no edit; closing"; [WF]::Command($hwnd, 2, [WF]::ChildById($hwnd, 'Button', 2)); Start-Sleep -Milliseconds 800; continue }
  Start-Sleep -Milliseconds $SettleMs
  if ($TargetPath) {
    $edit = [System.Windows.Automation.AutomationElement]::FromHandle($editH)
    $vp = $edit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
    $vp.SetValue($TargetPath)
    Start-Sleep -Milliseconds 900
    $now = $vp.Current.ValueAsString()
    Log ("filename via UIA: '$now'")
  }
  $saveH = [WF]::ChildById($hwnd, 'Button', 1)
  $btn = [System.Windows.Automation.AutomationElement]::FromHandle($saveH)
  $btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
  Log "Save invoked (UIA on hwnd)"
  for ($i = 0; $i -lt 24; $i++) { Start-Sleep -Milliseconds 300; if ([WF]::Dialogs($app.Id).Count -eq 0) { break } }
  Log ("dialogs remaining: " + [WF]::Dialogs($app.Id).Count)
}
Log "RESULT: done"
