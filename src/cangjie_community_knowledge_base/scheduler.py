"""Update scheduler metadata, retry/backoff, and health status."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from .config import RETRY_DEFAULTS, SCHEDULE_DEFAULTS
from .models import utc_now_iso
from .storage import KnowledgeStorage


@dataclass(frozen=True)
class RetryState:
    attempts: int
    nextRetryAt: str | None
    status: str


class UpdateScheduler:
    def __init__(self, storage: KnowledgeStorage):
        self.storage = storage
        self.storage.write_json(
            "metadata",
            "schedule_defaults.json",
            {key: int(value.total_seconds()) for key, value in SCHEDULE_DEFAULTS.items()},
        )

    def defaults(self) -> dict[str, int]:
        return self.storage.read_json("metadata", "schedule_defaults.json", {})

    def record_success(self, job: str) -> None:
        state = self.storage.read_json("metadata", "job_state.json", {})
        state[job] = {"lastSuccessAt": utc_now_iso(), "attempts": 0, "status": "ok"}
        self.storage.write_json("metadata", "job_state.json", state)

    def record_failure(self, job: str, now: datetime | None = None) -> RetryState:
        now = now or datetime.now(timezone.utc)
        state = self.storage.read_json("metadata", "job_state.json", {})
        previous = state.get(job, {})
        attempts = int(previous.get("attempts", 0)) + 1
        backoff = RETRY_DEFAULTS["initial_backoff_seconds"] * (RETRY_DEFAULTS["backoff_multiplier"] ** (attempts - 1))
        next_retry = now + timedelta(seconds=backoff)
        status = "degraded" if attempts >= RETRY_DEFAULTS["max_attempts"] else "retrying"
        state[job] = {"attempts": attempts, "nextRetryAt": next_retry.isoformat(), "status": status}
        self.storage.write_json("metadata", "job_state.json", state)
        return RetryState(attempts=attempts, nextRetryAt=next_retry.isoformat(), status=status)

    def status(self, now: datetime | None = None) -> dict[str, object]:
        now = now or datetime.now(timezone.utc)
        state = self.storage.read_json("metadata", "job_state.json", {})
        overall = "ok"
        jobs = {}
        for job, info in state.items():
            status = info.get("status", "unknown")
            last_success = info.get("lastSuccessAt")
            if last_success:
                age = (now - datetime.fromisoformat(last_success)).total_seconds()
                if age >= RETRY_DEFAULTS["degraded_after_seconds"]:
                    status = "degraded"
                elif age >= RETRY_DEFAULTS["stale_after_seconds"]:
                    status = "stale"
            if status == "degraded":
                overall = "degraded"
            elif status == "stale" and overall == "ok":
                overall = "stale"
            jobs[job] = {**info, "status": status}
        return {"overall": overall, "jobs": jobs, "scheduleDefaults": self.defaults()}
