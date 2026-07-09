from __future__ import annotations

import json
from pathlib import Path

from .models import WhitelistContact


class WhitelistStore:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)
        if not self.path.exists():
            self._write({"contacts": []})

    def list_contacts(self) -> list[WhitelistContact]:
        data = self._read()
        return [WhitelistContact.model_validate(item) for item in data.get("contacts", [])]

    def add_contact(self, contact: WhitelistContact) -> WhitelistContact:
        contacts = self.list_contacts()
        normalized_name = self._normalize(contact.name)
        kept = [item for item in contacts if self._normalize(item.name) != normalized_name]
        kept.append(contact)
        self._write({"contacts": [item.model_dump() for item in kept]})
        return contact

    def is_allowed(self, contact_name: str | None) -> bool:
        normalized = self._normalize(contact_name)
        if not normalized:
            return False
        for contact in self.list_contacts():
            names = [contact.name, *contact.aliases]
            if normalized in {self._normalize(name) for name in names}:
                return True
        return False

    def _read(self) -> dict:
        with self.path.open("r", encoding="utf-8") as file:
            return json.load(file)

    def _write(self, data: dict) -> None:
        with self.path.open("w", encoding="utf-8") as file:
            json.dump(data, file, ensure_ascii=False, indent=2)
            file.write("\n")

    @staticmethod
    def _normalize(value: str | None) -> str:
        return "".join((value or "").split()).casefold()
