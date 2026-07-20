param(
    [Parameter(Mandatory = $true)]
    [string]$ApkPath,

    [Parameter(Mandatory = $true)]
    [string]$Aapt2Path,

    [string]$ExpectedAccessibilityPackage = "com.tencent.mm"
)

$ErrorActionPreference = "Stop"

function Resolve-RequiredFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description was not found: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Invoke-Aapt2Dump {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = @(& $resolvedAapt2 @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "aapt2 $($Arguments -join ' ') failed with exit code $LASTEXITCODE. $($output -join ' ')"
    }
    return @($output | ForEach-Object { $_.ToString() })
}

$resolvedApk = Resolve-RequiredFile -Path $ApkPath -Description "APK"
$resolvedAapt2 = Resolve-RequiredFile -Path $Aapt2Path -Description "AAPT2"

$permissionDump = @(Invoke-Aapt2Dump -Arguments @("dump", "permissions", $resolvedApk))
$declaredPermissions = @($permissionDump | Where-Object {
    $_ -match '(?i)\buses-permission(?:-sdk-\d+)?:'
})
if ($declaredPermissions.Count -gt 0) {
    throw "V0-A APK declares forbidden uses-permission entries: $($declaredPermissions -join '; ')"
}

$accessibilityDump = @(Invoke-Aapt2Dump -Arguments @(
    "dump",
    "xmltree",
    $resolvedApk,
    "--file",
    "res/xml/accessibility_service_config.xml"
))
$packageLines = @($accessibilityDump | Where-Object { $_ -match '(?i)packageNames' })
if ($packageLines.Count -ne 1) {
    throw "Expected exactly one packageNames attribute in the packaged Accessibility config; found $($packageLines.Count)."
}
$escapedPackage = [regex]::Escape($ExpectedAccessibilityPackage)
if ($packageLines[0] -notmatch $escapedPackage) {
    throw "Packaged Accessibility scope does not contain the expected package $ExpectedAccessibilityPackage."
}

Write-Host "V0-A packaged APK safety verification passed."
Write-Host "- apk: $resolvedApk"
Write-Host "- uses-permission entries: 0"
Write-Host "- accessibility package: $ExpectedAccessibilityPackage"
