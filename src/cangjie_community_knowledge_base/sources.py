"""Source adapter contracts and fakeable bootstrap sync orchestration."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

from .models import RawRecord
from .storage import KnowledgeStorage


class SourceAdapter(Protocol):
    def fetch_full(self) -> list[RawRecord]:
        """Return a full source snapshot without performing hidden network work."""

    def refresh_scope(self, query: str, freshness_policy: str) -> list[RawRecord]:
        """Return scoped records for just-in-time refresh."""


@dataclass
class SyncResult:
    mode: str
    records: int
    ran_immediately: bool


class SourceSync:
    def __init__(self, storage: KnowledgeStorage, adapter: SourceAdapter):
        self.storage = storage
        self.adapter = adapter

    def bootstrap_full_sync(self) -> SyncResult:
        """Run a full sync immediately when no raw data exists."""

        if not self.storage.is_empty():
            count = len(self.storage.load_raw_records())
            return SyncResult(mode="skip-existing-data", records=count, ran_immediately=False)
        records = self.adapter.fetch_full()
        self.storage.replace_raw_records(records)
        self.storage.write_json("metadata", "last_sync.json", {"mode": "full", "records": len(records)})
        return SyncResult(mode="full", records=len(records), ran_immediately=True)

    def scoped_refresh(self, query: str, freshness_policy: str, limit: int | None = None) -> list[RawRecord]:
        records = self.adapter.refresh_scope(query, freshness_policy)
        if limit is not None:
            records = records[:limit]
        if records:
            current = {record.id: record for record in self.storage.load_raw_records()}
            current.update({record.id: record for record in records})
            self.storage.replace_raw_records(current.values())
        return records
