from __future__ import annotations

import json
from typing import Any

from .models import SafetyDecision
from .whitelist import WhitelistStore


class SafetyGate:
    WECHAT_PACKAGE = "com.tencent.mm"
    ALLOWED_ACTION = "accept_call"
    ALLOWED_CALL_TYPES = {"voice", "video"}
    BLOCKED_ACTIONS = {
        "payment",
        "pay",
        "transfer",
        "red_packet",
        "delete_message",
        "clear_chat",
        "send_message",
        "add_friend",
        "modify_profile",
    }
    BLOCKED_KEYWORDS = {
        "支付",
        "付款",
        "转账",
        "收款",
        "红包",
        "银行卡",
        "验证码",
        "删除",
        "清空聊天记录",
        "撤回",
        "send message",
        "delete",
        "transfer",
        "payment",
    }

    def evaluate(
        self,
        action_type: str,
        payload: dict[str, Any],
        whitelist: WhitelistStore,
    ) -> SafetyDecision:
        normalized_action = (action_type or "").strip()
        if normalized_action in self.BLOCKED_ACTIONS:
            return self._deny(normalized_action, "high_risk_action_blocked", payload)

        serialized_payload = json.dumps(payload, ensure_ascii=False).casefold()
        for keyword in self.BLOCKED_KEYWORDS:
            if keyword.casefold() in serialized_payload:
                return self._deny(normalized_action, f"high_risk_keyword_blocked:{keyword}", payload)

        if normalized_action != self.ALLOWED_ACTION:
            return self._deny(normalized_action, "unsupported_action", payload)

        app_package = payload.get("app_package")
        if app_package != self.WECHAT_PACKAGE:
            return self._deny(normalized_action, "unsupported_app_package", payload)

        call_type = payload.get("call_type")
        if call_type not in self.ALLOWED_CALL_TYPES:
            return self._deny(normalized_action, "unsupported_call_type", payload)

        contact_name = payload.get("contact_name")
        if not whitelist.is_allowed(contact_name):
            return self._deny(normalized_action, "contact_not_in_whitelist", payload)

        return SafetyDecision(
            allowed=True,
            reason="allowed_wechat_whitelisted_call",
            action_type=normalized_action,
            payload=payload,
        )

    @staticmethod
    def _deny(action_type: str, reason: str, payload: dict[str, Any]) -> SafetyDecision:
        return SafetyDecision(
            allowed=False,
            reason=reason,
            action_type=action_type,
            payload=payload,
        )
