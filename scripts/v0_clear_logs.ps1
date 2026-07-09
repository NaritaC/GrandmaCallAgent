param(
    [string]$PackageName = "com.grandmacallagent.bridge"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    throw "adb not found. Install Android Studio Platform Tools and add adb to PATH."
}

Write-Host "Clearing V0 local log from $PackageName..."
& adb shell run-as $PackageName sh -c "echo -n > files/v0_actions.log"

if ($LASTEXITCODE -eq 0) {
    Write-Host "V0 local log cleared."
} else {
    Write-Host "Failed to clear logs. You can also clear logs from the GrandmaBridge app UI."
}
