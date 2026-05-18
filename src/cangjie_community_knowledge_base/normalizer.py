"""Normalize raw records into chunks, entities, and comments."""

from __future__ import annotations

import re
from dataclasses import dataclass

from .models import KnowledgeMetadata, NormalizedChunk, NormalizedComment, NormalizedEntity, RawRecord, utc_now_iso


SYMBOL_RE = re.compile(r"\b(?:func|class|interface|struct|enum)\s+([A-Za-z_][A-Za-z0-9_]*)|\b([A-Z][A-Za-z0-9_]{2,})\b")


@dataclass(frozen=True)
class NormalizedBundle:
    chunks: tuple[NormalizedChunk, ...]
    entities: tuple[NormalizedEntity, ...]
    comments: tuple[NormalizedComment, ...]


def normalize_records(records: list[RawRecord], chunk_size: int = 800) -> NormalizedBundle:
    chunks: list[NormalizedChunk] = []
    entities: list[NormalizedEntity] = []
    comments: list[NormalizedComment] = []
    indexed_at = utc_now_iso()

    for record in records:
        indexed_metadata = KnowledgeMetadata.from_dict({**record.metadata.to_dict(), "indexedAt": indexed_at})
        text = f"{record.title}\n{record.content}".strip()
        parts = _chunk_text(text, chunk_size)
        for index, part in enumerate(parts):
            chunks.append(
                NormalizedChunk(
                    id=f"{record.id}:chunk:{index}",
                    recordId=record.id,
                    text=part,
                    metadata=indexed_metadata,
                )
            )
        for index, name in enumerate(_extract_entities(text)):
            entities.append(
                NormalizedEntity(
                    id=f"{record.id}:entity:{index}",
                    recordId=record.id,
                    name=name,
                    kind="symbol",
                    metadata=indexed_metadata,
                )
            )
        for index, comment in enumerate(record.comments):
            comments.append(
                NormalizedComment(
                    id=f"{record.id}:comment:{index}",
                    recordId=record.id,
                    text=comment,
                    metadata=indexed_metadata,
                )
            )

    return NormalizedBundle(tuple(chunks), tuple(entities), tuple(comments))


def _chunk_text(text: str, chunk_size: int) -> list[str]:
    if len(text) <= chunk_size:
        return [text]
    chunks: list[str] = []
    cursor = 0
    while cursor < len(text):
        chunks.append(text[cursor : cursor + chunk_size].strip())
        cursor += chunk_size
    return [chunk for chunk in chunks if chunk]


def _extract_entities(text: str) -> list[str]:
    names: list[str] = []
    seen: set[str] = set()
    for match in SYMBOL_RE.finditer(text):
        name = match.group(1) or match.group(2)
        if name and name not in seen:
            seen.add(name)
            names.append(name)
    return names
