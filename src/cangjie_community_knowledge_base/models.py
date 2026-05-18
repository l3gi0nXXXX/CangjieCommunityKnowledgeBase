"""Data models shared by storage, indexes, and public APIs."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def _required_metadata(data: dict[str, Any]) -> dict[str, Any]:
    required = {
        "sourceType",
        "sourceUrl",
        "repo",
        "commit",
        "docVersion",
        "crawlAt",
        "indexedAt",
        "knowledgeVersion",
        "trustLevel",
        "reviewState",
        "license",
        "derivedFrom",
    }
    missing = sorted(required - set(data))
    if missing:
        raise ValueError(f"missing metadata fields: {', '.join(missing)}")
    return data


@dataclass(frozen=True)
class KnowledgeMetadata:
    sourceType: str
    sourceUrl: str
    repo: str | None
    commit: str | None
    docVersion: str | None
    crawlAt: str
    indexedAt: str | None
    knowledgeVersion: str | None
    trustLevel: str
    reviewState: str
    license: str | None
    derivedFrom: tuple[str, ...] = field(default_factory=tuple)

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["derivedFrom"] = list(self.derivedFrom)
        return data

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "KnowledgeMetadata":
        checked = _required_metadata(dict(data))
        checked["derivedFrom"] = tuple(checked.get("derivedFrom") or ())
        return cls(**checked)


@dataclass(frozen=True)
class RawRecord:
    id: str
    title: str
    content: str
    metadata: KnowledgeMetadata
    comments: tuple[str, ...] = field(default_factory=tuple)

    @property
    def sourceType(self) -> str:
        return self.metadata.sourceType

    @property
    def sourceUrl(self) -> str:
        return self.metadata.sourceUrl

    @property
    def repo(self) -> str | None:
        return self.metadata.repo

    @property
    def commit(self) -> str | None:
        return self.metadata.commit

    @property
    def docVersion(self) -> str | None:
        return self.metadata.docVersion

    @property
    def crawlAt(self) -> str:
        return self.metadata.crawlAt

    @property
    def indexedAt(self) -> str | None:
        return self.metadata.indexedAt

    @property
    def knowledgeVersion(self) -> str | None:
        return self.metadata.knowledgeVersion

    @property
    def trustLevel(self) -> str:
        return self.metadata.trustLevel

    @property
    def reviewState(self) -> str:
        return self.metadata.reviewState

    @property
    def license(self) -> str | None:
        return self.metadata.license

    @property
    def derivedFrom(self) -> tuple[str, ...]:
        return self.metadata.derivedFrom

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "content": self.content,
            "comments": list(self.comments),
            "metadata": self.metadata.to_dict(),
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "RawRecord":
        return cls(
            id=data["id"],
            title=data.get("title", ""),
            content=data.get("content", ""),
            comments=tuple(data.get("comments") or ()),
            metadata=KnowledgeMetadata.from_dict(data["metadata"]),
        )


@dataclass(frozen=True)
class NormalizedChunk:
    id: str
    recordId: str
    text: str
    metadata: KnowledgeMetadata

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "recordId": self.recordId,
            "text": self.text,
            "metadata": self.metadata.to_dict(),
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "NormalizedChunk":
        return cls(
            id=data["id"],
            recordId=data["recordId"],
            text=data["text"],
            metadata=KnowledgeMetadata.from_dict(data["metadata"]),
        )


@dataclass(frozen=True)
class NormalizedEntity:
    id: str
    recordId: str
    name: str
    kind: str
    metadata: KnowledgeMetadata

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "recordId": self.recordId,
            "name": self.name,
            "kind": self.kind,
            "metadata": self.metadata.to_dict(),
        }


@dataclass(frozen=True)
class NormalizedComment:
    id: str
    recordId: str
    text: str
    metadata: KnowledgeMetadata

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "recordId": self.recordId,
            "text": self.text,
            "metadata": self.metadata.to_dict(),
        }
