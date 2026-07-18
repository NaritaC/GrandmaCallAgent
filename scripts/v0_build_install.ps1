param(
    [string]$ProjectDir = "GrandmaBridge",
    [string]$PackageName = "com.grandmacallagent.bridge",
    [string]$Serial = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $ScriptDir "v0_common.ps1")

function Resolve-GradleCommand {
    param([string]$RootDir)

    $wrapper = Join-Path $RootDir "gradlew.bat"
    if (Test-Path $wrapper) {
        return (Resolve-Path $wrapper).Path
    }

    $gradle = Get-Command gradle -ErrorAction SilentlyContinue
    if ($gradle) {
        return $gradle.Source
    }

    throw "No Gradle wrapper or global gradle found. Open GrandmaBridge in Android Studio and build once, or add a Gradle wrapper."
}

$root = Resolve-Path $ProjectDir
$target = Resolve-V0AdbTarget -Serial $Serial
$gradleCommand = Resolve-GradleCommand $root.Path

Write-Host "adb: $($target.AdbPath)"
Write-Host "selected device: $($target.Serial)"
Write-Host "gradle: $gradleCommand"
Write-Host "Building debug APK..."

Push-Location $root
try {
    & $gradleCommand ":app:assembleDebug"
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle build failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

$apk = Join-Path $root "app/build/outputs/apk/debug/app-debug.apk"
if (-not (Test-Path $apk)) {
    throw "Debug APK not found: $apk"
}

Write-Host "Installing APK: $apk"
Invoke-V0Adb -Target $target -Arguments @("install", "-r", $apk) | Out-Host

Write-Host "Launching $PackageName..."
Invoke-V0Adb -Target $target -Arguments @(
    "shell",
    "monkey",
    "-p",
    $PackageName,
    "-c",
    "android.intent.category.LAUNCHER",
    "1"
) | Out-Host

Write-Host "Installed and launched. Enable Accessibility and Notification Listener permissions from the App before V0 tests."
