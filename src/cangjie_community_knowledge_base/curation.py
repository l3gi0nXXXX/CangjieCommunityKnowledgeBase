"""ACP offline curation queue."""

from __future__ import annotations

from dataclasses import dataclass

from .models import utc_now_iso
from .storage import KnowledgeStorage


@dataclass(frozen=True)
class CurationItem:
    id: str
    reason: str
    payload: dict[str, object]


class OfflineCurationQueue:
    def __init__(self, storage: KnowledgeStorage):
        self.storage = storage

    def enqueue(self, item: CurationItem) -> None:
        queue = self.storage.read_json("derived", "acp_curation_queue.json", [])
        queue.append({"id": item.id, "reason": item.reason, "payload": item.payload, "queuedAt": utc_now_iso(), "status": "pending"})
        self.storage.write_json("derived", "acp_curation_queue.json", queue)

    def list_pending(self) -> list[dict[str, object]]:
        return [item for item in self.storage.read_json("derived", "acp_curation_queue.json", []) if item.get("status") == "pending"]
