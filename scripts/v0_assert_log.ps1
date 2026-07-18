param(
    [string]$PackageName = "com.grandmacallagent.bridge",
    [string]$Serial = "",
    [string[]]$Required = @(),
    [string[]]$Forbidden = @()
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $ScriptDir "v0_common.ps1")

$target = Resolve-V0AdbTarget -Serial $Serial
$log = Invoke-V0Adb -Target $target -Arguments @(
    "shell",
    "run-as",
    $PackageName,
    "cat",
    "files/v0_actions.log"
)
$logText = $log -join "`n"

$failed = $false

foreach ($pattern in $Required) {
    if ($logText -match [regex]::Escape($pattern)) {
        Write-Host "PASS required: $pattern"
    } else {
        Write-Host "FAIL missing required: $pattern"
        $failed = $true
    }
}

foreach ($pattern in $Forbidden) {
    if ($logText -match [regex]::Escape($pattern)) {
        Write-Host "FAIL forbidden present: $pattern"
        $failed = $true
    } else {
        Write-Host "PASS forbidden absent: $pattern"
    }
}

if ($Required.Count -eq 0 -and $Forbidden.Count -eq 0) {
    Write-Host "No assertions were provided. Use -Required and/or -Forbidden."
}

if ($failed) {
    throw "V0 log assertions failed."
}

Write-Host "V0 log assertions passed."
