# uia-dump-windows.ps1 — list all top-level windows of the YuE2-Studio process
# (any class/name), plus child control summary for #32770 dialogs.
param([int]$AppPid = 0)
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$root = [System.Windows.Automation.AutomationElement]::RootElement
$wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
foreach ($w in $wins) {
  $proc = $w.Current.ProcessId
  $p = Get-Process -Id $proc -ErrorAction SilentlyContinue
  if ($AppPid -and $proc -ne $AppPid) { continue }
  if (-not $AppPid -and -not ($p -and $p.ProcessName -match 'YuE2|Studio')) { continue }
  $cls = $w.Current.ClassName
  $name = $w.Current.Name
  $type = $w.Current.ControlType.ProgrammaticName -replace 'ControlType.', ''
  $rect = $w.Current.BoundingRectangle
  Write-Output ("pid=$proc proc=$($p.ProcessName) type=$type class='$cls' name='$name' rect=$([int]$rect.X),$([int]$rect.Y),$([int]$rect.Width),$([int]$rect.Height) offscreen=$($w.Current.IsOffscreen)")
  if ($cls -eq '#32770') {
    $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
    function Dump($el, $depth) {
      if ($depth -gt 6) { return }
      $n = $el.Current.Name; $id = $el.Current.AutomationId; $t = $el.Current.ControlType.ProgrammaticName -replace 'ControlType.', ''
      Write-Output (("  " * $depth) + "$t id='$id' name='$n'")
      $child = $walker.GetFirstChildElement($el)
      while ($child) { Dump $child ($depth + 1); $child = $walker.GetNextSiblingElement($child) }
    }
    Dump $w 1
  }
}
