param(
    [string]$PackageName = "com.grandmacallagent.bridge"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    throw "adb not found. Install Android Studio Platform Tools and add adb to PATH."
}

Write-Host "Reading V0 local log from $PackageName..."
Write-Host ""

& adb shell run-as $PackageName cat files/v0_actions.log

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Failed to read logs. Check that:"
    Write-Host "- GrandmaBridge is installed as a debuggable build."
    Write-Host "- The app has been opened at least once."
    Write-Host "- The package name is $PackageName."
}
