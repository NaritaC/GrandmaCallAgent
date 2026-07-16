param(
    [string]$ProjectDir = "GrandmaBridge",
    [switch]$AssertReady
)

$ErrorActionPreference = "Stop"

function Find-CommandPath {
    param([string]$Name)
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    return $null
}

$failures = @()
$projectPath = $null

Write-Host "PowerShell: $($PSVersionTable.PSVersion)"

try {
    $projectPath = (Resolve-Path $ProjectDir).Path
    Write-Host "Project: $projectPath"
} catch {
    Write-Host "Project: missing ($ProjectDir)"
    $failures += "GrandmaBridge project directory was not found: $ProjectDir"
}

if ($projectPath) {
    $requiredFiles = @(
        "settings.gradle.kts",
        "build.gradle.kts",
        "app/build.gradle.kts",
        "app/src/main/AndroidManifest.xml"
    )

    foreach ($relativePath in $requiredFiles) {
        $path = Join-Path $projectPath $relativePath
        if (Test-Path $path) {
            Write-Host "Found: $relativePath"
        } else {
            Write-Host "Missing: $relativePath"
            $failures += "Missing Android project file: $relativePath"
        }
    }
}

$java = Find-CommandPath "java"
if ($java) {
    Write-Host "java: $java"
} else {
    Write-Host "java: missing"
    $failures += "java was not found on PATH."
}

$adb = Find-CommandPath "adb"
if ($adb) {
    Write-Host "adb: $adb"
} else {
    Write-Host "adb: missing"
    $failures += "adb was not found on PATH. Install Android Studio Platform Tools and add adb to PATH."
}

$gradleWrapper = if ($projectPath) { Join-Path $projectPath "gradlew.bat" } else { $null }
$hasWrapper = $gradleWrapper -and (Test-Path $gradleWrapper)
if ($hasWrapper) {
    Write-Host "gradle wrapper: $gradleWrapper"
} else {
    Write-Host "gradle wrapper: missing"
}

$gradle = Find-CommandPath "gradle"
if ($gradle) {
    Write-Host "gradle: $gradle"
} else {
    Write-Host "gradle: missing"
}

if (-not $hasWrapper -and -not $gradle) {
    $failures += "No Gradle wrapper or global gradle was found. Use Android Studio or add a Gradle wrapper/global Gradle."
}

if ($AssertReady) {
    if ($failures.Count -gt 0) {
        Write-Host ""
        Write-Host "V0 host preflight failed:"
        foreach ($failure in $failures) {
            Write-Host "- $failure"
        }
        throw "Host is not ready for CLI V0 build/install validation."
    }

    Write-Host ""
    Write-Host "V0 host preflight passed."
} elseif ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "Warnings:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
}
