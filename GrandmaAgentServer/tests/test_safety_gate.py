from pathlib import Path

from grandma_agent_server.models import WhitelistContact
from grandma_agent_server.safety import SafetyGate
from grandma_agent_server.whitelist import WhitelistStore


def make_whitelist(tmp_path: Path) -> WhitelistStore:
    store = WhitelistStore(tmp_path / "whitelist.json")
    store.add_contact(WhitelistContact(name="妈妈", aliases=["妈"]))
    return store


def test_accepts_whitelisted_wechat_voice_call(tmp_path: Path) -> None:
    decision = SafetyGate().evaluate(
        "accept_call",
        {"app_package": "com.tencent.mm", "contact_name": "妈妈", "call_type": "voice"},
        make_whitelist(tmp_path),
    )

    assert decision.allowed


def test_blocks_non_whitelisted_contact(tmp_path: Path) -> None:
    decision = SafetyGate().evaluate(
        "accept_call",
        {"app_package": "com.tencent.mm", "contact_name": "陌生人", "call_type": "voice"},
        make_whitelist(tmp_path),
    )

    assert not decision.allowed
    assert decision.reason == "contact_not_in_whitelist"


def test_blocks_non_wechat_package(tmp_path: Path) -> None:
    decision = SafetyGate().evaluate(
        "accept_call",
        {"app_package": "com.android.phone", "contact_name": "妈妈", "call_type": "voice"},
        make_whitelist(tmp_path),
    )

    assert not decision.allowed
    assert decision.reason == "unsupported_app_package"


def test_blocks_payment_action(tmp_path: Path) -> None:
    decision = SafetyGate().evaluate(
        "transfer",
        {"app_package": "com.tencent.mm", "contact_name": "妈妈", "amount": "100"},
        make_whitelist(tmp_path),
    )

    assert not decision.allowed
    assert decision.reason == "high_risk_action_blocked"


def test_blocks_high_risk_keyword(tmp_path: Path) -> None:
    decision = SafetyGate().evaluate(
        "accept_call",
        {"app_package": "com.tencent.mm", "contact_name": "妈妈", "call_type": "voice", "text": "微信支付"},
        make_whitelist(tmp_path),
    )

    assert not decision.allowed
    assert decision.reason.startswith("high_risk_keyword_blocked")
