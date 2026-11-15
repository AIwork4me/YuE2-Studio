# make-readonly.ps1 — deny file-creation in the given directory for the current
# user, then self-test that creating a file there fails.
param([string]$Dir = "C:\dev\yue2-hip-nightly\qa\gui-final-run\export\readonly")
$user = "$env:USERDOMAIN\$env:USERNAME"
icacls $Dir /deny "${user}:(WD,AD)" | Out-Null
Write-Output ("deny applied to " + $user)
$test = Join-Path $Dir "probe-write-test.txt"
try {
  [System.IO.File]::WriteAllText($test, "x")
  Write-Output "WRITE STILL POSSIBLE - ACL FAILED"
  Remove-Item $test -ErrorAction SilentlyContinue
  exit 1
} catch {
  Write-Output ("write blocked OK: " + $_.Exception.Message.Split("`n")[0])
  exit 0
}
