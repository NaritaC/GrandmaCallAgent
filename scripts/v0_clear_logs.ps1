param(
    [string]$PackageName = "com.grandmacallagent.bridge",
    [string]$Serial = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $ScriptDir "v0_common.ps1")

$target = Resolve-V0AdbTarget -Serial $Serial
Write-Host "Clearing V0 local log from $PackageName..."
Invoke-V0Adb -Target $target -Arguments @(
    "shell",
    "run-as",
    $PackageName,
    "sh",
    "-c",
    "echo -n > files/v0_actions.log"
) | Out-Null
Write-Host "V0 local log cleared on $($target.Serial)."
