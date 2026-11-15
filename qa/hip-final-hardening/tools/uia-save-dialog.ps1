# uia-save-dialog.ps1 — drive the native Save dialog of YuE2-Studio via UIA.
# Usage:
#   powershell -NoProfile -File uia-save-dialog.ps1 -TargetPath <file> -Action save|cancel -TimeoutSec 180 -LogPath <log>
# Finds a top-level dialog owned by the app process, dumps its control tree to
# the log (evidence), sets the filename, and clicks Save (IDOK) or Cancel.
param(
  [Parameter(Mandatory=$true)][string]$TargetPath,
  [Parameter(Mandatory=$true)][ValidateSet('save','cancel')][string]$Action,
  [int]$TimeoutSec = 180,
  [string]$LogPath = "C:\dev\yue2-hip-nightly\qa\gui-final-run\export\uia-dialog.log"
)
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
function Log($m) { $line = ("{0} {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $m); Add-Content -Path $LogPath -Value $line -Encoding UTF8 }
if (Test-Path $LogPath) { Remove-Item $LogPath -Force }
Log "UIA driver start action=$Action target=$TargetPath timeout=$TimeoutSec"

$root = [System.Windows.Automation.AutomationElement]::RootElement
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$dialog = $null
while ((Get-Date) -lt $deadline -and -not $dialog) {
  Start-Sleep -Milliseconds 400
  $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)
  $wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
  foreach ($w in $wins) {
    $cls = $w.Current.ClassName
    $name = $w.Current.Name
    $proc = $w.Current.ProcessId
    if ($cls -eq '#32770' -and $name -match 'Save|Save As|保存|另存') {
      $p = Get-Process -Id $proc -ErrorAction SilentlyContinue
      Log "dialog candidate: name='$name' class=$cls pid=$proc proc=$($p.ProcessName)"
      if ($p -and $p.ProcessName -match 'YuE2|Studio') { $dialog = $w; break }
    }
  }
}
if (-not $dialog) { Log "RESULT: no save dialog appeared within $TimeoutSec s"; exit 3 }
Log "DIALOG FOUND: '$($dialog.Current.Name)'"

# dump the control tree for evidence
$walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
function Dump($el, $depth) {
  if ($depth -gt 8) { return }
  $n = $el.Current.Name; $id = $el.Current.AutomationId; $t = $el.Current.ControlType.ProgrammaticName -replace 'ControlType.',''
  Log (("  " * $depth) + "$t id='$id' name='$n'")
  $child = $walker.GetFirstChildElement($el)
  while ($child) { Dump $child ($depth + 1); $child = $walker.GetNextSiblingElement($child) }
}
Dump $dialog 0

if ($Action -eq 'save') {
  # filename edit: try AutomationId 1001 first (common item dialog), else any Edit
  $edit = $null
  $try = $dialog.FindAll([System.Windows.Automation.TreeScope]::Descendants,
      (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, '1001')))
  if ($try.Count -gt 0) { $edit = $try[0] } else {
    $try = $dialog.FindAll([System.Windows.Automation.TreeScope]::Descendants,
      (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)))
    if ($try.Count -gt 0) { $edit = $try[0] }
  }
  if (-not $edit) { Log "RESULT: filename edit not found"; exit 4 }
  Log "filename edit found id='$($edit.Current.AutomationId)' name='$($edit.Current.Name)'"
  $vp = $edit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
  $vp.SetValue($TargetPath)
  Start-Sleep -Milliseconds 600
  $now = $vp.Current.ValueAsString()
  Log "filename now: '$now'"
  $btn = $dialog.FindFirst([System.Windows.Automation.TreeScope]::Descendants,
    (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, '1')))
  if (-not $btn) {
    $all = $dialog.FindAll([System.Windows.Automation.TreeScope]::Descendants,
      (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)))
    foreach ($b in $all) { if ($b.Current.Name -match '^Save|保存') { $btn = $b; break } }
  }
  if (-not $btn) { Log "RESULT: Save button not found"; exit 5 }
  Log "Save button: '$($btn.Current.Name)' id='$($btn.Current.AutomationId)'"
  $ip = $btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
  $ip.Invoke()
  Log "Save invoked"
} else {
  $btn = $dialog.FindFirst([System.Windows.Automation.TreeScope]::Descendants,
    (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, '2')))
  if (-not $btn) {
    $all = $dialog.FindAll([System.Windows.Automation.TreeScope]::Descendants,
      (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)))
    foreach ($b in $all) { if ($b.Current.Name -match 'Cancel|取消') { $btn = $b; break } }
  }
  if (-not $btn) { Log "RESULT: Cancel button not found"; exit 5 }
  Log "Cancel button: '$($btn.Current.Name)'"
  $btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
  Log "Cancel invoked"
}
# wait for the dialog to close (proof the click registered)
$gone = $false
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Milliseconds 250
  try { if ($dialog.Current.IsOffscreen -or -not $dialog.Current.Name) { $gone = $true; break } } catch { $gone = $true; break }
}
Log "dialog closed: $gone"
Log "RESULT: OK action=$Action"
exit 0
