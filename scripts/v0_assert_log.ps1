param(
    [string]$PackageName = "com.grandmacallagent.bridge",
    [string[]]$Required = @(),
    [string[]]$Forbidden = @()
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    throw "adb not found. Install Android Studio Platform Tools and add adb to PATH."
}

$log = adb shell run-as $PackageName cat files/v0_actions.log
if ($LASTEXITCODE -ne 0) {
    throw "Failed to read V0 log. Install a debuggable build and open the app at least once."
}

$failed = $false

foreach ($pattern in $Required) {
    if ($log -match [regex]::Escape($pattern)) {
        Write-Host "PASS required: $pattern"
    } else {
        Write-Host "FAIL missing required: $pattern"
        $failed = $true
    }
}

foreach ($pattern in $Forbidden) {
    if ($log -match [regex]::Escape($pattern)) {
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
