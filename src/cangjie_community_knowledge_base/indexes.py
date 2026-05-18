"""Simple text, symbol, graph, and vector-placeholder indexes."""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from typing import Any

from .models import NormalizedChunk, NormalizedEntity
from .storage import KnowledgeStorage


TOKEN_RE = re.compile(r"[A-Za-z0-9_]+")


@dataclass(frozen=True)
class SearchHit:
    id: str
    title: str
    text: str
    score: float
    evidence: dict[str, Any]


class SearchIndex:
    def __init__(self, storage: KnowledgeStorage):
        self.storage = storage

    def build(self, chunks: list[NormalizedChunk], entities: list[NormalizedEntity]) -> None:
        docs = []
        symbols: dict[str, list[str]] = {}
        graph: dict[str, list[str]] = {}
        vectors: dict[str, str] = {}
        for chunk in chunks:
            tokens = _tokens(chunk.text)
            docs.append({"id": chunk.id, "recordId": chunk.recordId, "tokens": tokens, "text": chunk.text, "metadata": chunk.metadata.to_dict()})
            graph[chunk.id] = list(chunk.metadata.derivedFrom)
            vectors[chunk.id] = hashlib.sha256(" ".join(tokens).encode("utf-8")).hexdigest()
        for entity in entities:
            symbols.setdefault(entity.name.lower(), []).append(entity.recordId)

        self.storage.write_json("indexes", "text.json", {"documents": docs})
        self.storage.write_json("indexes", "symbols.json", symbols)
        self.storage.write_json("indexes", "graph.json", graph)
        self.storage.write_json("indexes", "vector_placeholder.json", vectors)

    def search(self, query: str, source_types: set[str] | None = None, limit: int = 10) -> list[SearchHit]:
        query_tokens = set(_tokens(query))
        documents = self.storage.read_json("indexes", "text.json", {"documents": []})["documents"]
        hits: list[SearchHit] = []
        for document in documents:
            metadata = document["metadata"]
            if source_types and metadata["sourceType"] not in source_types:
                continue
            score = len(query_tokens.intersection(document["tokens"]))
            if score <= 0 and query.lower() not in document["text"].lower():
                continue
            hits.append(
                SearchHit(
                    id=document["id"],
                    title=document["recordId"],
                    text=document["text"],
                    score=float(score or 0.5),
                    evidence=_public_evidence(metadata),
                )
            )
        hits.sort(key=lambda hit: (-hit.score, hit.id))
        return hits[:limit]

    def symbol_search(self, symbol: str) -> list[str]:
        symbols = self.storage.read_json("indexes", "symbols.json", {})
        return symbols.get(symbol.lower(), [])


def _tokens(text: str) -> list[str]:
    return [token.lower() for token in TOKEN_RE.findall(text)]


def _public_evidence(metadata: dict[str, Any]) -> dict[str, Any]:
    allowed = {
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
    return {key: _sanitize(metadata.get(key)) for key in allowed}


def _sanitize(value: Any) -> Any:
    if isinstance(value, str) and _looks_like_local_path(value):
        return None
    if isinstance(value, list):
        return [_sanitize(item) for item in value if not (isinstance(item, str) and _looks_like_local_path(item))]
    return value


def _looks_like_local_path(value: str) -> bool:
    return value.startswith("/") or value.startswith("file:") or "/Users/" in value or "\\Users\\" in value
