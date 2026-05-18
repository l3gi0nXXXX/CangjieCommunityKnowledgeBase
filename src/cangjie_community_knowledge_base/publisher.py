"""Knowledge version publishing with candidate-to-active gating."""

from __future__ import annotations

from dataclasses import dataclass

from .indexes import SearchIndex
from .storage import KnowledgeStorage


@dataclass(frozen=True)
class PublishResult:
    candidate: str
    active: str | None
    published: bool
    smokeQueries: tuple[str, ...]


class KnowledgePublisher:
    def __init__(self, storage: KnowledgeStorage, index: SearchIndex):
        self.storage = storage
        self.index = index

    def create_candidate(self, version: str) -> None:
        self.storage.write_json("metadata", "candidate_version.json", {"knowledgeVersion": version})

    def publish_candidate(self, smoke_queries: list[str]) -> PublishResult:
        candidate = self.storage.read_json("metadata", "candidate_version.json")
        if not candidate:
            raise ValueError("no candidate knowledgeVersion")
        failed = [query for query in smoke_queries if not self.index.search(query, limit=1)]
        if failed:
            return PublishResult(candidate["knowledgeVersion"], self.active_version(), False, tuple(smoke_queries))
        self.storage.write_json("metadata", "active_version.json", candidate)
        return PublishResult(candidate["knowledgeVersion"], candidate["knowledgeVersion"], True, tuple(smoke_queries))

    def active_version(self) -> str | None:
        active = self.storage.read_json("metadata", "active_version.json")
        return None if not active else active["knowledgeVersion"]
