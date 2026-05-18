"""Scoped just-in-time refresh policies for freshness-sensitive queries."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from .sources import SourceSync
from .storage import KnowledgeStorage


FRESHNESS_POLICIES = {"use_active", "ensure_recent", "ensure_ref", "force_candidate"}


@dataclass(frozen=True)
class RefreshResult:
    policy: str
    refreshed: int
    skippedReason: str | None


class JustInTimeRefresher:
    def __init__(
        self,
        storage: KnowledgeStorage,
        sync: SourceSync,
        cooldown: timedelta = timedelta(minutes=5),
        per_run_limit: int = 3,
        candidate_gate: bool = True,
    ):
        self.storage = storage
        self.sync = sync
        self.cooldown = cooldown
        self.per_run_limit = per_run_limit
        self.candidate_gate = candidate_gate

    def refresh(self, query: str, freshness_policy: str, now: datetime | None = None) -> RefreshResult:
        if freshness_policy not in FRESHNESS_POLICIES:
            raise ValueError(f"unknown freshnessPolicy: {freshness_policy}")
        if freshness_policy == "use_active":
            self._audit(query, freshness_policy, 0, "use-active")
            return RefreshResult(freshness_policy, 0, "use-active")
        if self.candidate_gate and freshness_policy == "force_candidate" and not self.storage.read_json("metadata", "candidate_version.json"):
            self._audit(query, freshness_policy, 0, "candidate-gate")
            return RefreshResult(freshness_policy, 0, "candidate-gate")

        now = now or datetime.now(timezone.utc)
        cooldown_key = f"{freshness_policy}:{query}"
        cooldowns = self.storage.read_json("cache", "refresh_cooldowns.json", {})
        last = cooldowns.get(cooldown_key)
        if last and now - datetime.fromisoformat(last) < self.cooldown:
            self._audit(query, freshness_policy, 0, "cooldown")
            return RefreshResult(freshness_policy, 0, "cooldown")

        records = self.sync.scoped_refresh(query, freshness_policy, limit=self.per_run_limit)
        cooldowns[cooldown_key] = now.isoformat()
        self.storage.write_json("cache", "refresh_cooldowns.json", cooldowns)
        self._audit(query, freshness_policy, len(records), None)
        return RefreshResult(freshness_policy, len(records), None)

    def _audit(self, query: str, policy: str, refreshed: int, skipped: str | None) -> None:
        audit = self.storage.read_json("metadata", "jit_refresh_audit.json", [])
        audit.append({"query": query, "freshnessPolicy": policy, "refreshed": refreshed, "skippedReason": skipped})
        self.storage.write_json("metadata", "jit_refresh_audit.json", audit)
