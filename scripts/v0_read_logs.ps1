param(
    [string]$PackageName = "com.grandmacallagent.bridge",
    [string]$Serial = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $ScriptDir "v0_common.ps1")

$target = Resolve-V0AdbTarget -Serial $Serial
Write-Host "Reading V0 local log from $PackageName on $($target.Serial)..."
Write-Host ""

Invoke-V0Adb -Target $target -Arguments @(
    "shell",
    "run-as",
    $PackageName,
    "cat",
    "files/v0_actions.log"
)
