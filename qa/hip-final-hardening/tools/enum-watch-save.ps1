# enum-watch-save.ps1 — start a background window enumerator for the app, fire
# a choose POST, print raw EnumWindows output DURING the hang and at the end,
# plus capture two full-desktop screenshots while the dialog should be up.
param(
  [string]$BodyPath = "C:\dev\yue2-hip-nightly\qa\gui-final-run\export\save-body.json",
  [string]$ShotDir = "C:\dev\yue2-hip-nightly\qa\gui-final-run\export"
)
Add-Type -TypeDefinition @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class WinEnum {
  public delegate bool EnumWindowsProc(IntPtr h, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lp);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  public static List<string> List(uint targetPid, bool visibleOnly) {
    var result = new List<string>();
    EnumWindows((h, lp) => {
      uint pid; GetWindowThreadProcessId(h, out pid);
      if (pid == targetPid && (!visibleOnly || IsWindowVisible(h))) {
        var t = new StringBuilder(256); GetWindowText(h, t, 256);
        var c = new StringBuilder(256); GetClassName(h, c, 256);
        result.Add(string.Format("hwnd={0} vis={1} class='{2}' title='{3}'", h, IsWindowVisible(h), c, t));
      }
      return true;
    }, IntPtr.Zero);
    return result;
  }
}
"@
Add-Type -AssemblyName System.Drawing
$app = Get-Process YuE2-Studio | Select-Object -First 1
Write-Output ("app pid: " + $app.Id)
Write-Output "--- windows BEFORE:"
[WinEnum]::List($app.Id, $false) | ForEach-Object { Write-Output $_ }

$proc = Start-Process curl.exe -ArgumentList @('-s','--max-time','80','-X','POST','http://127.0.0.1:8791/v1/files/save','-H','Content-Type: application/json','--data-binary',"@$BodyPath") -PassThru -WindowStyle Hidden -RedirectStandardOutput "$ShotDir\choose-resp.txt"

# observe during the hang
for ($i = 0; $i -lt 30 -and -not $proc.HasExited; $i++) {
  Start-Sleep -Milliseconds 1000
  if ($i -eq 3 -or $i -eq 10) {
    Write-Output ("--- windows DURING hang (t=" + $i + "s):")
    [WinEnum]::List($app.Id, $false) | ForEach-Object { Write-Output $_ }
    $bmp = New-Object System.Drawing.Bitmap([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width, [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen(0, 0, 0, 0, $bmp.Size)
    $bmp.Save("$ShotDir\screen-t$i.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Output ("screenshot saved: screen-t$i.png")
  }
}
$proc.WaitForExit()
Write-Output "--- curl exit:" $proc.ExitCode
Write-Output "--- response:"
Get-Content "$ShotDir\choose-resp.txt" -ErrorAction SilentlyContinue
Write-Output "--- windows AFTER:"
[WinEnum]::List($app.Id, $false) | ForEach-Object { Write-Output $_ }
