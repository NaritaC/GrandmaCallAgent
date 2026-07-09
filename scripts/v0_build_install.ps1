param(
    [string]$ProjectDir = "GrandmaBridge",
    [string]$PackageName = "com.grandmacallagent.bridge"
)

$ErrorActionPreference = "Stop"

function Require-Adb {
    $adb = Get-Command adb -ErrorAction SilentlyContinue
    if (-not $adb) {
        throw "adb not found. Install Android Studio Platform Tools and add adb to PATH."
    }
    return $adb.Source
}

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
$adb = Require-Adb
$gradleCommand = Resolve-GradleCommand $root.Path

Write-Host "adb: $adb"
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
adb install -r $apk
if ($LASTEXITCODE -ne 0) {
    throw "adb install failed with exit code $LASTEXITCODE."
}

Write-Host "Launching $PackageName..."
adb shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Host

Write-Host "Installed and launched. Enable Accessibility and Notification Listener permissions from the App before V0 tests."
