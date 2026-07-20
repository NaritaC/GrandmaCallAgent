$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $ScriptDir "v0_common.ps1")

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if ($Expected -ne $Actual) {
        throw "$Name failed. Expected '$Expected', got '$Actual'."
    }
    Write-Host "PASS: $Name"
}

function Assert-Throws {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$ExpectedMessage,
        [Parameter(Mandatory = $true)][string]$Name
    )

    try {
        & $Action | Out-Null
    } catch {
        if ($_.Exception.Message -notlike "*$ExpectedMessage*") {
            throw "$Name threw an unexpected error: $($_.Exception.Message)"
        }
        Write-Host "PASS: $Name"
        return
    }
    throw "$Name failed. Expected an exception containing '$ExpectedMessage'."
}

Write-Host "Parsing V0 PowerShell scripts..."
$scriptFiles = Get-ChildItem -LiteralPath $ScriptDir -Filter "v0*.ps1" -File
foreach ($file in $scriptFiles) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        $messages = ($parseErrors | ForEach-Object { $_.Message }) -join "; "
        throw "PowerShell parse failed for $($file.Name): $messages"
    }
}
Write-Host "PASS: parsed $($scriptFiles.Count) V0 PowerShell scripts"

$repoRoot = Split-Path -Parent $ScriptDir
$manifestPath = Join-Path $repoRoot "GrandmaBridge\app\src\main\AndroidManifest.xml"
$accessibilityConfigPath = Join-Path $repoRoot "GrandmaBridge\app\src\main\res\xml\accessibility_service_config.xml"
$manifest = Get-Content -Raw -LiteralPath $manifestPath
$accessibilityConfig = Get-Content -Raw -LiteralPath $accessibilityConfigPath
Assert-Equal -Expected $false -Actual ($manifest -match 'android\.permission\.INTERNET') `
    -Name "keep V0 APK offline"
Assert-Equal -Expected $true -Actual (
    $accessibilityConfig -match 'android:packageNames="com\.tencent\.mm"'
) -Name "scope V0 accessibility events to WeChat"

Assert-Equal -Expected 8 -Actual (
    ConvertFrom-V0JavaMajorVersion -VersionText 'java version "1.8.0_402"'
) -Name "parse legacy Java major version"
Assert-Equal -Expected 21 -Actual (
    ConvertFrom-V0JavaMajorVersion -VersionText 'java 21.0.8 2025-07-15 LTS'
) -Name "parse current Java major version"

$knownCandidate = (Resolve-Path -LiteralPath (Join-Path $ScriptDir "v0_common.ps1")).Path
Assert-Equal -Expected $knownCandidate -Actual (
    Resolve-V0AdbPath -AdditionalCandidates @($knownCandidate)
) -Name "resolve explicit ADB candidate path"
Assert-Throws -Action {
    Resolve-V0ApkPath -ApkPath $knownCandidate
} -ExpectedMessage "must be an .apk file" -Name "reject non-APK prebuilt package"

$singleDeviceLines = @(
    "List of devices attached",
    "phone-001`tdevice product:test model:Test transport_id:1"
)
$singleDevice = @(ConvertFrom-V0AdbDevices -Lines $singleDeviceLines)
Assert-Equal -Expected 1 -Actual $singleDevice.Count -Name "parse one ADB device"
Assert-Equal -Expected "phone-001" -Actual (Select-V0AdbSerial -Devices $singleDevice) -Name "select sole ready device"

$mixedDeviceLines = @(
    "List of devices attached",
    "phone-001`tdevice product:test model:Test transport_id:1",
    "phone-002`tunauthorized usb:1-1 transport_id:2"
)
$mixedDevices = @(ConvertFrom-V0AdbDevices -Lines $mixedDeviceLines)
Assert-Equal -Expected "phone-001" -Actual (Select-V0AdbSerial -Devices $mixedDevices) -Name "ignore unauthorized device when one ready device exists"
Assert-Throws -Action {
    Select-V0AdbSerial -Devices $mixedDevices -Serial "phone-002"
} -ExpectedMessage "not ready" -Name "reject explicitly selected unauthorized device"

$multipleReady = @(
    [pscustomobject]@{ Serial = "phone-001"; State = "device" },
    [pscustomobject]@{ Serial = "emulator-5554"; State = "device" }
)
Assert-Throws -Action {
    Select-V0AdbSerial -Devices $multipleReady
} -ExpectedMessage "Multiple authorized" -Name "require serial when multiple devices are ready"
Assert-Equal -Expected "emulator-5554" -Actual (
    Select-V0AdbSerial -Devices $multipleReady -Serial "emulator-5554"
) -Name "select requested ready device"
Assert-Throws -Action {
    Select-V0AdbSerial -Devices @()
} -ExpectedMessage "No authorized Android device" -Name "reject missing device"

[xml]$passingVoiceSnapshot = @'
<hierarchy rotation="0">
  <node class="android.widget.FrameLayout" package="com.tencent.mm" clickable="false" enabled="true">
    <node text="V0TEST01" class="android.widget.TextView" package="com.tencent.mm" clickable="false" enabled="true" />
    <node text="语音通话" class="android.widget.TextView" package="com.tencent.mm" clickable="false" enabled="true" />
    <node resource-id="com.tencent.mm:id/accept_call" class="android.widget.Button" package="com.tencent.mm" clickable="true" enabled="true">
      <node text="接听" class="android.widget.TextView" package="com.tencent.mm" clickable="false" enabled="true" />
    </node>
  </node>
</hierarchy>
'@
$passingAnalysis = Get-V0CallSnapshotAnalysis `
    -Document $passingVoiceSnapshot `
    -ExpectedContactRemark "V0TEST01" `
    -CallType Voice
Assert-Equal -Expected $true -Actual $passingAnalysis.pass -Name "accept compatible WeChat call snapshot"
Assert-Equal -Expected "com.tencent.mm:id/accept_call" -Actual (
    $passingAnalysis.accept_target_resource_id
) -Name "resolve clickable accept ancestor"

$wrongContactAnalysis = Get-V0CallSnapshotAnalysis `
    -Document $passingVoiceSnapshot `
    -ExpectedContactRemark "V0TEST02" `
    -CallType Voice
Assert-Equal -Expected $false -Actual $wrongContactAnalysis.pass -Name "reject snapshot with different contact"
Assert-Equal -Expected $true -Actual (
    "expected_contact_not_visible" -in $wrongContactAnalysis.reasons
) -Name "report missing expected contact"

$wrongCallTypeAnalysis = Get-V0CallSnapshotAnalysis `
    -Document $passingVoiceSnapshot `
    -ExpectedContactRemark "V0TEST01" `
    -CallType Video
Assert-Equal -Expected $false -Actual $wrongCallTypeAnalysis.pass -Name "reject snapshot with different call type"

[xml]$systemUiSnapshot = $passingVoiceSnapshot.OuterXml.Replace(
    'package="com.tencent.mm"',
    'package="com.android.systemui"'
)
$systemUiAnalysis = Get-V0CallSnapshotAnalysis `
    -Document $systemUiSnapshot `
    -ExpectedContactRemark "V0TEST01" `
    -CallType Voice
Assert-Equal -Expected $false -Actual $systemUiAnalysis.pass -Name "reject non-WeChat active root"

[xml]$highRiskSnapshot = $passingVoiceSnapshot.OuterXml.Replace(
    '</node></node></hierarchy>',
    '<node text="转账" class="android.widget.TextView" package="com.tencent.mm" clickable="false" enabled="true" /></node></node></hierarchy>'
)
$highRiskAnalysis = Get-V0CallSnapshotAnalysis `
    -Document $highRiskSnapshot `
    -ExpectedContactRemark "V0TEST01" `
    -CallType Voice
Assert-Equal -Expected $false -Actual $highRiskAnalysis.pass -Name "reject snapshot containing high-risk text"

$matrixAnalyses = @()
foreach ($screenState in @("Unlocked", "LockedScreenOn", "LockedScreenOff")) {
    foreach ($callType in @("Voice", "Video")) {
        $matrixAnalyses += [pscustomobject]@{
            pass = $true
            screen_state = $screenState
            call_type = $callType
            target = [pscustomobject]@{
                device_model = "HUAWEI Pura 70 Ultra"
                harmonyos_version = "4.2.0"
                wechat_version = "8.0.76"
                operator_confirmed = $true
            }
        }
    }
}
$completeGate = Get-V0SnapshotGateSummary -Analyses $matrixAnalyses
Assert-Equal -Expected $true -Actual $completeGate.complete -Name "accept complete six-case snapshot gate"
Assert-Equal -Expected 6 -Actual $completeGate.valid_count -Name "count complete snapshot matrix"

$incompleteGate = Get-V0SnapshotGateSummary -Analyses @($matrixAnalyses | Select-Object -First 5)
Assert-Equal -Expected $false -Actual $incompleteGate.complete -Name "reject incomplete snapshot gate"
Assert-Equal -Expected "LockedScreenOff/Video" -Actual $incompleteGate.missing[0] -Name "report missing snapshot case"

$unconfirmedAnalyses = @($matrixAnalyses | ForEach-Object {
    $copy = $_ | Select-Object *
    $copy.target = $_.target | Select-Object *
    $copy.target.operator_confirmed = $false
    $copy
})
$unconfirmedGate = Get-V0SnapshotGateSummary -Analyses $unconfirmedAnalyses
Assert-Equal -Expected $false -Actual $unconfirmedGate.complete -Name "reject unconfirmed target matrix"

$completeGate | Add-Member -NotePropertyName snapshots_reviewed -NotePropertyValue $true
$gateValidation = Get-V0SnapshotGateValidation -Gate $completeGate
Assert-Equal -Expected $true -Actual $gateValidation.pass -Name "validate complete gate structure"
$tamperedGate = $completeGate | Select-Object *
$tamperedGate.valid = @($completeGate.valid | Select-Object -First 5)
$tamperedValidation = Get-V0SnapshotGateValidation -Gate $tamperedGate
Assert-Equal -Expected $false -Actual $tamperedValidation.pass -Name "reject gate missing a required valid case"

& (Join-Path $ScriptDir "v0_capture_call_snapshot.ps1") `
    -ExpectedContactRemark "V0TEST01" `
    -CallType Voice `
    -ScreenState Unlocked `
    -PlanOnly *> $null
Write-Host "PASS: planned read-only call snapshot without ADB"

$scenarios = @(
    "AutoAnswerOff",
    "WhitelistVoice",
    "WhitelistVideo",
    "NonWhitelist",
    "HighRiskPage",
    "NonCallAccept",
    "OutboundVoice",
    "OutboundVideo",
    "OutboundWrongPage",
    "OutboundCancel"
)
foreach ($scenario in $scenarios) {
    & (Join-Path $ScriptDir "v0_run_scenario.ps1") -Scenario $scenario -PlanOnly *> $null
}
Write-Host "PASS: planned $($scenarios.Count) V0 validation scenarios without ADB"

Assert-Throws -Action {
    & (Join-Path $ScriptDir "v0_run_scenario.ps1") -Scenario WhitelistVoice *> $null
} -ExpectedMessage "Re-run with -AcceptLiveCallAction" -Name "require explicit live automation acceptance"
Assert-Throws -Action {
    & (Join-Path $ScriptDir "v0_run_scenario.ps1") `
        -Scenario OutboundVoice `
        -AcceptLiveCallAction *> $null
} -ExpectedMessage "Outbound automation moved to V0.5" -Name "keep outbound automation behind V0.5 switch"
Assert-Throws -Action {
    & (Join-Path $ScriptDir "v0_run_scenario.ps1") `
        -Scenario WhitelistVoice `
        -AcceptLiveCallAction *> $null
} -ExpectedMessage "complete snapshot gate is required" -Name "require snapshot gate before allowlisted auto-answer"

$recommendedV0AScenarios = @(
    "AutoAnswerOff",
    "NonCallAccept",
    "NonWhitelist",
    "WhitelistVoice",
    "WhitelistVideo",
    "WhitelistVoice",
    "WhitelistVideo",
    "WhitelistVoice",
    "WhitelistVideo"
)
$recommendedV05Scenarios = @(
    "OutboundWrongPage",
    "HighRiskPage",
    "OutboundCancel",
    "OutboundVoice",
    "OutboundVideo"
)
$phoneGuidePath = Join-Path (Split-Path -Parent $ScriptDir) "docs\V0_PHONE_VALIDATION.md"
$phoneGuide = Get-Content -Raw -LiteralPath $phoneGuidePath
$v0ABlock = [regex]::Match(
    $phoneGuide,
    '(?s)V0-A 实机场景的推荐顺序是：\s*```powershell\s*(.*?)```'
)
if (-not $v0ABlock.Success) {
    throw "Phone validation guide is missing the V0-A recommended scenario code block."
}
$documentedV0AScenarios = @(
    [regex]::Matches($v0ABlock.Groups[1].Value, '-Scenario\s+([A-Za-z]+)') |
        ForEach-Object { $_.Groups[1].Value }
)
Assert-Equal -Expected ($recommendedV0AScenarios -join ',') -Actual (
    $documentedV0AScenarios -join ','
) -Name "phone validation guide lists V0-A scenarios in safe order"

$v05Block = [regex]::Match(
    $phoneGuide,
    '(?s)V0\.5 场景的推荐顺序是：\s*```powershell\s*(.*?)```'
)
if (-not $v05Block.Success) {
    throw "Phone validation guide is missing the V0.5 recommended scenario code block."
}
$documentedV05Scenarios = @(
    [regex]::Matches($v05Block.Groups[1].Value, '-Scenario\s+([A-Za-z]+)') |
        ForEach-Object { $_.Groups[1].Value }
)
Assert-Equal -Expected ($recommendedV05Scenarios -join ',') -Actual (
    $documentedV05Scenarios -join ','
) -Name "phone validation guide keeps outbound scenarios in V0.5"

$v05ConfirmedLines = @($v05Block.Groups[1].Value -split "`r?`n" | Where-Object {
    $_ -match '-Scenario' -and
    $_ -match '-AcceptLiveCallAction' -and
    $_ -match '-AcceptExperimentalOutbound'
})
Assert-Equal -Expected $recommendedV05Scenarios.Count -Actual $v05ConfirmedLines.Count `
    -Name "phone guide requires both outbound safety switches"

$snapshotCommands = @([regex]::Matches(
    $phoneGuide,
    'v0_capture_call_snapshot\.ps1\s+@snapshot\s+-CallType\s+(Voice|Video)\s+-ScreenState\s+(Unlocked|LockedScreenOn|LockedScreenOff)'
))
Assert-Equal -Expected 6 -Actual $snapshotCommands.Count -Name "phone guide lists all six snapshot cases"
Assert-Equal -Expected $true -Actual ($phoneGuide -match '-ConfirmScreenshotsReviewed') `
    -Name "phone guide requires manual screenshot review"
Write-Host "V0 script self-test passed."
