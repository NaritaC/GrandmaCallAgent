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
        "OutboundCancel"
    )]
    [string]$Scenario,
    [string]$PackageName = "com.grandmacallagent.bridge",
    [switch]$SkipClear,
    [switch]$SkipEvidence,
    [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

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
        $required = @("incoming_detected", "incoming_allowed", "accept_success")
        $steps = @(
            "Open GrandmaBridge and turn on '启用白名单来电自动接听'.",
            "Ask a whitelisted contact to place a WeChat voice call.",
            "Confirm the phone answers only on the WeChat incoming-call screen."
        )
    }
    "WhitelistVideo" {
        $required = @("incoming_detected", "incoming_allowed", "callType=video", "accept_success")
        $steps = @(
            "Open GrandmaBridge and turn on '启用白名单来电自动接听'.",
            "Ask a whitelisted contact to place a WeChat video call.",
            "Confirm the phone answers only on the WeChat incoming-call screen."
        )
    }
    "NonWhitelist" {
        $required = @("contact_not_in_local_whitelist")
        $forbidden = @("accept_success")
        $steps = @(
            "Open GrandmaBridge and turn on '启用白名单来电自动接听'.",
            "Ask a non-whitelisted contact to place a WeChat voice or video call.",
            "Confirm the phone does not auto-answer."
        )
    }
    "HighRiskPage" {
        $forbidden = @("accept_success", "outbound_click_final_call")
        $steps = @(
            "Open a WeChat payment, red packet, transfer, bank card, or delete-related test page.",
            "Do not perform any real payment, transfer, red packet, or delete action.",
            "Confirm GrandmaBridge does not click anything on that page."
        )
    }
    "NonCallAccept" {
        $forbidden = @("accept_success")
        $steps = @(
            "Open a WeChat page that contains an accept/agree button but is not a voice/video call.",
            "Use a test account or harmless page only; do not accept real friend, group, or payment-related requests.",
            "Confirm GrandmaBridge does not click the non-call accept button."
        )
    }
    "OutboundVoice" {
        $required = @("outbound_requested", "outbound_launch_wechat", "callType=voice", "outbound_click_final_call")
        $steps = @(
            "Open GrandmaBridge and enter a whitelisted WeChat display name in the outbound field.",
            "Tap '一键拨出微信语音'.",
            "Watch the screen. If it enters the wrong contact or page, tap '停止一键拨出' or disable Accessibility."
        )
    }
    "OutboundVideo" {
        $required = @("outbound_requested", "outbound_launch_wechat", "callType=video", "outbound_click_final_call")
        $steps = @(
            "Open GrandmaBridge and enter a whitelisted WeChat display name in the outbound field.",
            "Tap '一键拨出微信视频'.",
            "Watch the screen. If it enters the wrong contact or page, tap '停止一键拨出' or disable Accessibility."
        )
    }
    "OutboundCancel" {
        $required = @("outbound_cancel_requested", "outbound_cancelled")
        $steps = @(
            "Open GrandmaBridge and enter a whitelisted WeChat display name in the outbound field.",
            "Tap either outbound call button, then return to GrandmaBridge immediately.",
            "Tap '停止一键拨出'."
        )
    }
}

Write-Host "V0 scenario: $Scenario"
Write-Host "Package: $PackageName"
Write-Host "Safety: this script does not operate WeChat UI. It only clears logs, waits for your manual test, asserts logs, and optionally collects evidence."
Show-Steps -Steps $steps
Write-Host ""
Write-Host "Required log keywords: $($required -join ', ')"
Write-Host "Forbidden log keywords: $($forbidden -join ', ')"

if ($PlanOnly) {
    Write-Host "PlanOnly mode: no ADB command was run."
    return
}

if (-not $SkipClear) {
    & (Join-Path $ScriptDir "v0_clear_logs.ps1") -PackageName $PackageName
}

Read-Host "Press Enter after completing the manual steps above"

$assertFailed = $false
try {
    & (Join-Path $ScriptDir "v0_assert_log.ps1") -PackageName $PackageName -Required $required -Forbidden $forbidden
} catch {
    $assertFailed = $true
    Write-Host $_
}

if (-not $SkipEvidence) {
    & (Join-Path $ScriptDir "v0_collect_evidence.ps1") -PackageName $PackageName
}

if ($assertFailed) {
    throw "Scenario $Scenario failed. Review the local log and evidence bundle before continuing."
}

Write-Host "Scenario $Scenario passed."
