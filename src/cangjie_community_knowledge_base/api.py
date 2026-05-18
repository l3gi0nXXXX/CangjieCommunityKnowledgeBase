"""Public evidence-pack API surface for Metis and ACP consumers."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .config import SourceScope, default_source_scope
from .curation import CurationItem, OfflineCurationQueue
from .indexes import SearchHit, SearchIndex
from .normalizer import normalize_records
from .publisher import KnowledgePublisher
from .refresh import JustInTimeRefresher
from .scheduler import UpdateScheduler
from .sources import SourceAdapter, SourceSync
from .storage import KnowledgeStorage


class CangjieKnowledgeBase:
    """Small production-shaped facade around storage, sync, normalization, and search."""

    def __init__(self, root: str | Path, adapter: SourceAdapter | None = None, scope: SourceScope | None = None):
        self.storage = KnowledgeStorage(root)
        self.scope = scope or default_source_scope()
        self.adapter = adapter
        self.index = SearchIndex(self.storage)
        self.scheduler = UpdateScheduler(self.storage)
        self.publisher = KnowledgePublisher(self.storage, self.index)
        self.curation = OfflineCurationQueue(self.storage)
        self.sync = SourceSync(self.storage, adapter) if adapter is not None else None
        self.refresher = JustInTimeRefresher(self.storage, self.sync) if self.sync is not None else None
        self.storage.write_json("metadata", "source_scope.json", self._scope_dict())

    def bootstrap(self) -> dict[str, object]:
        if self.sync is None:
            raise ValueError("bootstrap requires a SourceAdapter")
        result = self.sync.bootstrap_full_sync()
        self.rebuild_indexes()
        return {"mode": result.mode, "records": result.records, "ranImmediately": result.ran_immediately}

    def rebuild_indexes(self) -> None:
        records = self.storage.load_raw_records()
        bundle = normalize_records(records)
        self.storage.replace_normalized(bundle.chunks)
        self.storage.write_json("normalized", "entities.json", [entity.to_dict() for entity in bundle.entities])
        self.storage.write_json("normalized", "comments.json", [comment.to_dict() for comment in bundle.comments])
        self.index.build(list(bundle.chunks), list(bundle.entities))

    def refresh(self, query: str, freshness_policy: str) -> dict[str, object]:
        if self.refresher is None:
            return {"policy": freshness_policy, "refreshed": 0, "skippedReason": "no-adapter"}
        result = self.refresher.refresh(query, freshness_policy)
        if result.refreshed:
            self.rebuild_indexes()
        return {"policy": result.policy, "refreshed": result.refreshed, "skippedReason": result.skippedReason}

    def enqueue_curation(self, item_id: str, reason: str, payload: dict[str, object]) -> None:
        self.curation.enqueue(CurationItem(item_id, reason, payload))

    def _scope_dict(self) -> dict[str, object]:
        return {
            "organizations": list(self.scope.organizations),
            "repoDiscovery": list(self.scope.repo_discovery),
            "websiteRoots": list(self.scope.website_roots),
            "documentationRoots": list(self.scope.documentation_roots),
            "standardLibraryRepositories": list(self.scope.standard_library_repositories),
            "includeIssueHistory": self.scope.include_issue_history,
            "includePullRequestHistory": self.scope.include_pull_request_history,
            "includeWebCandidates": self.scope.include_web_candidates,
            "webCandidateSeeds": list(self.scope.web_candidate_seeds),
        }


def cangjie_source_search(kb: CangjieKnowledgeBase, query: str, limit: int = 10) -> list[dict[str, Any]]:
    return _serialize_hits(kb.index.search(query, {"source", "repo", "issue", "pull_request"}, limit))


def cangjie_doc_search(kb: CangjieKnowledgeBase, query: str, limit: int = 10) -> list[dict[str, Any]]:
    return _serialize_hits(kb.index.search(query, {"doc", "documentation"}, limit))


def cangjie_website_search(kb: CangjieKnowledgeBase, query: str, limit: int = 10) -> list[dict[str, Any]]:
    return _serialize_hits(kb.index.search(query, {"website"}, limit))


def cangjie_web_candidate_search(kb: CangjieKnowledgeBase, query: str, limit: int = 10) -> list[dict[str, Any]]:
    return _serialize_hits(kb.index.search(query, {"web_candidate"}, limit))


def cangjie_hybrid_search(
    kb: CangjieKnowledgeBase,
    query: str,
    limit: int = 10,
    freshnessPolicy: str = "use_active",
) -> list[dict[str, Any]]:
    if freshnessPolicy != "use_active":
        kb.refresh(query, freshnessPolicy)
    return _serialize_hits(kb.index.search(query, None, limit))


def cangjie_evidence_pack(
    kb: CangjieKnowledgeBase,
    query: str,
    limit: int = 5,
    freshnessPolicy: str = "use_active",
) -> dict[str, Any]:
    hits = cangjie_hybrid_search(kb, query, limit=limit, freshnessPolicy=freshnessPolicy)
    return {
        "query": query,
        "freshnessPolicy": freshnessPolicy,
        "knowledgeVersion": kb.publisher.active_version(),
        "evidence": hits,
    }


def cangjie_knowledge_status(kb: CangjieKnowledgeBase) -> dict[str, Any]:
    records = kb.storage.load_raw_records()
    chunks = kb.storage.load_chunks()
    candidate = kb.storage.read_json("metadata", "candidate_version.json")
    return {
        "scope": kb.storage.read_json("metadata", "source_scope.json", {}),
        "storageLayout": ["data/raw", "data/normalized", "data/metadata", "data/indexes", "data/derived", "data/cache"],
        "rawRecords": len(records),
        "normalizedChunks": len(chunks),
        "activeKnowledgeVersion": kb.publisher.active_version(),
        "candidateKnowledgeVersion": None if not candidate else candidate["knowledgeVersion"],
        "scheduler": kb.scheduler.status(),
        "curationQueuePending": len(kb.curation.list_pending()),
        "finalGitCodeReplyGeneration": False,
    }


def _serialize_hits(hits: list[SearchHit]) -> list[dict[str, Any]]:
    return [
        {
            "id": hit.id,
            "title": hit.title,
            "snippet": hit.text[:240],
            "score": hit.score,
            "evidence": hit.evidence,
        }
        for hit in hits
    ]
