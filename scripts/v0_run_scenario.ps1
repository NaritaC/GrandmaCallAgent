param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
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
    )]
    [string]$Scenario,
    [string]$PackageName = "com.grandmacallagent.bridge",
    [string]$Serial = "",
    [ValidateSet("Unlocked", "LockedScreenOn", "LockedScreenOff")]
    [string]$ScreenState = "Unlocked",
    [string]$SnapshotGatePath = "",
    [switch]$AcceptLiveCallAction,
    [switch]$AcceptExperimentalOutbound,
    [switch]$SkipClear,
    [switch]$SkipEvidence,
    [switch]$SkipPreflight,
    [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $ScriptDir "v0_common.ps1")

function Show-Steps {
    param([string[]]$Steps)
    Write-Host ""
    Write-Host "Manual steps:"
    $index = 1
    foreach ($step in $Steps) {
        Write-Host "$index. $step"
        $index += 1
    }
}

$required = @()
$forbidden = @()
$steps = @()
$requiresSnapshotGate = $false
$requiresLiveCallAcceptance = $false
$requiresExperimentalOutbound = $false

switch ($Scenario) {
    "AutoAnswerOff" {
        $required = @("auto_answer_disabled")
        $forbidden = @("accept_success")
        $steps = @(
            "Open GrandmaBridge and turn off '启用白名单来电自动接听'.",
            "Ask a whitelisted contact to place a WeChat voice or video call.",
            "Confirm the phone does not auto-answer."
        )
    }
    "WhitelistVoice" {
        $requiresSnapshotGate = $true
        $requiresLiveCallAcceptance = $true
        $required = @("incoming_detected", "incoming_allowed", "accept_success")
        $steps = @(
            "Open GrandmaBridge and turn on '启用白名单来电自动接听'.",
            "Ask a whitelisted contact to place a WeChat voice call.",
            "Confirm the phone answers only on the WeChat incoming-call screen."
        )
    }
    "WhitelistVideo" {
        $requiresSnapshotGate = $true
        $requiresLiveCallAcceptance = $true
        $required = @("incoming_detected", "incoming_allowed", "callType=video", "accept_success")
        $steps = @(
            "Open GrandmaBridge and turn on '启用白名单来电自动接听'.",
            "Ask a whitelisted contact to place a WeChat video call.",
            "Confirm the phone answers only on the WeChat incoming-call screen."
        )
    }
    "NonWhitelist" {
        $requiresSnapshotGate = $true
        $requiresLiveCallAcceptance = $true
        $required = @("contact_not_in_local_whitelist")
        $forbidden = @("accept_success")
        $steps = @(
            "Open GrandmaBridge and turn on '启用白名单来电自动接听'.",
            "Ask a non-whitelisted contact to place a WeChat voice or video call.",
            "Confirm the phone does not auto-answer."
        )
    }
    "HighRiskPage" {
        $requiresLiveCallAcceptance = $true
        $requiresExperimentalOutbound = $true
        $required = @("outbound_requested", "outbound_launch_wechat", "local_reject_high_risk_keyword")
        $forbidden = @(
            "accept_success",
            "outbound_click_search",
            "outbound_set_search_text",
            "outbound_click_contact",
            "outbound_click_final_call"
        )
        $steps = @(
            "In a harmless test chat, leave a visible message containing the text '转账'. Do not open WeChat Pay, a transfer form, a red packet, a bank card page, or a delete confirmation.",
            "Return to GrandmaBridge, temporarily enable the V0.5 outbound checkbox, enter a whitelisted test contact, and tap either outbound call button.",
            "Confirm automation stops before search, text entry, contact selection, or call actions. Disable Accessibility immediately if any click occurs."
        )
    }
    "NonCallAccept" {
        $requiresLiveCallAcceptance = $true
        $forbidden = @("accept_success")
        $steps = @(
            "Open a WeChat page that contains an accept/agree button but is not a voice/video call.",
            "Use a test account or harmless page only; do not accept real friend, group, or payment-related requests.",
            "Confirm GrandmaBridge does not click the non-call accept button."
        )
    }
    "OutboundVoice" {
        $requiresLiveCallAcceptance = $true
        $requiresExperimentalOutbound = $true
        $required = @("outbound_requested", "outbound_launch_wechat", "callType=voice", "outbound_click_final_call")
        $steps = @(
            "Before starting, leave WeChat on its main tab page; do not leave it on a chat, payment, transfer, red packet, or delete-related page.",
            "Open GrandmaBridge, temporarily enable the V0.5 outbound checkbox, and enter the exact whitelisted WeChat remark in the outbound field.",
            "Tap '一键拨出微信语音'.",
            "Watch the screen. If it enters the wrong contact or page, tap '停止一键拨出' or disable Accessibility."
        )
    }
    "OutboundVideo" {
        $requiresLiveCallAcceptance = $true
        $requiresExperimentalOutbound = $true
        $required = @("outbound_requested", "outbound_launch_wechat", "callType=video", "outbound_click_final_call")
        $steps = @(
            "Before starting, leave WeChat on its main tab page; do not leave it on a chat, payment, transfer, red packet, or delete-related page.",
            "Open GrandmaBridge, temporarily enable the V0.5 outbound checkbox, and enter the exact whitelisted WeChat remark in the outbound field.",
            "Tap '一键拨出微信视频'.",
            "Watch the screen. If it enters the wrong contact or page, tap '停止一键拨出' or disable Accessibility."
        )
    }
    "OutboundWrongPage" {
        $requiresLiveCallAcceptance = $true
        $requiresExperimentalOutbound = $true
        $required = @("outbound_requested", "outbound_launch_wechat", "wechat_home_not_confirmed")
        $forbidden = @("outbound_set_search_text", "outbound_click_contact", "outbound_click_final_call")
        $steps = @(
            "Leave WeChat on a harmless test chat page. Do not use a payment, transfer, red packet, or delete-related page.",
            "Return to GrandmaBridge, temporarily enable the V0.5 outbound checkbox, enter a whitelisted test contact, and tap either outbound call button.",
            "Confirm no text is entered and no contact or call action is clicked, then return to GrandmaBridge and tap '停止一键拨出'."
        )
    }
    "OutboundCancel" {
        $requiresLiveCallAcceptance = $true
        $requiresExperimentalOutbound = $true
        $required = @("outbound_cancel_requested", "outbound_cancelled")
        $steps = @(
            "Open GrandmaBridge, temporarily enable the V0.5 outbound checkbox, and enter the exact whitelisted WeChat remark in the outbound field.",
            "Tap either outbound call button, then return to GrandmaBridge immediately.",
            "Tap '停止一键拨出'."
        )
    }
}

$incomingScenarios = @("AutoAnswerOff", "WhitelistVoice", "WhitelistVideo", "NonWhitelist")
if ($Scenario -in $incomingScenarios) {
    $stateStep = switch ($ScreenState) {
        "Unlocked" { "Keep the phone unlocked with the display on before the test call starts." }
        "LockedScreenOn" { "Lock the phone and leave the lock screen visible before the test call starts." }
        "LockedScreenOff" { "Lock the phone and turn the display off before the test call starts." }
    }
    $steps = @($stateStep) + @($steps)
}

Write-Host "V0 scenario: $Scenario"
Write-Host "Package: $PackageName"
if ($Scenario -in $incomingScenarios) {
    Write-Host "Screen state: $ScreenState"
}
if (-not [string]::IsNullOrWhiteSpace($Serial)) {
    Write-Host "Device serial: $Serial"
}
Write-Host "Safety: this script does not operate WeChat UI. It only clears logs, waits for your manual test, asserts logs, and optionally collects evidence."
if ($requiresSnapshotGate) {
    Write-Host "Gate: a complete six-case read-only snapshot gate is required before this scenario."
}
if ($requiresExperimentalOutbound) {
    Write-Host "Scope: this is an experimental V0.5 outbound scenario, not part of the V0-A pass gate."
}
Show-Steps -Steps $steps
Write-Host ""
Write-Host "Required log keywords: $($required -join ', ')"
Write-Host "Forbidden log keywords: $($forbidden -join ', ')"

if ($PlanOnly) {
    Write-Host "PlanOnly mode: no ADB command was run."
    return
}

if ($requiresLiveCallAcceptance -and -not $AcceptLiveCallAction) {
    throw "This scenario can expose a real phone UI to automation. Re-run with -AcceptLiveCallAction only with test accounts, a backup caller, and direct supervision."
}
if ($requiresExperimentalOutbound -and -not $AcceptExperimentalOutbound) {
    throw "Outbound automation moved to V0.5. Re-run with -AcceptExperimentalOutbound only after V0-A incoming-call validation passes."
}
if ($requiresSnapshotGate) {
    if ([string]::IsNullOrWhiteSpace($SnapshotGatePath)) {
        throw "A complete snapshot gate is required. Pass -SnapshotGatePath <snapshot-gate.json>."
    }
    if (-not (Test-Path -LiteralPath $SnapshotGatePath -PathType Leaf)) {
        throw "Snapshot gate file was not found: $SnapshotGatePath"
    }
    try {
        $snapshotGate = Get-Content -Raw -LiteralPath $SnapshotGatePath | ConvertFrom-Json
    } catch {
        throw "Unable to parse snapshot gate file: $SnapshotGatePath. $($_.Exception.Message)"
    }
    $gateValidation = Get-V0SnapshotGateValidation -Gate $snapshotGate
    if (-not $gateValidation.pass) {
        throw "Snapshot gate failed validation: $($gateValidation.reasons -join ', '). Keep automation disabled."
    }
}

if (-not $SkipPreflight) {
    & (Join-Path $ScriptDir "v0_device_preflight.ps1") -PackageName $PackageName -Serial $Serial -AssertReady
}

if (-not $SkipClear) {
    & (Join-Path $ScriptDir "v0_clear_logs.ps1") -PackageName $PackageName -Serial $Serial
}

Read-Host "Press Enter after completing the manual steps above"

$assertFailed = $false
try {
    & (Join-Path $ScriptDir "v0_assert_log.ps1") -PackageName $PackageName -Serial $Serial -Required $required -Forbidden $forbidden
} catch {
    $assertFailed = $true
    Write-Host $_
}

if (-not $SkipEvidence) {
    & (Join-Path $ScriptDir "v0_collect_evidence.ps1") -PackageName $PackageName -Serial $Serial
}

if ($assertFailed) {
    throw "Scenario $Scenario failed. Review the local log and evidence bundle before continuing."
}

Write-Host "Scenario $Scenario passed."
