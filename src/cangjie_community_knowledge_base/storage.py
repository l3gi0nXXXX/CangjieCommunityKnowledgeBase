"""Small JSON/JSONL storage layer for offline tests and local crawls."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Iterable

from .models import NormalizedChunk, RawRecord


DATA_DIRECTORIES = ("raw", "normalized", "metadata", "indexes", "derived", "cache")


class KnowledgeStorage:
    def __init__(self, root: str | Path):
        self.root = Path(root)
        self.data_dir = self.root / "data"
        for name in DATA_DIRECTORIES:
            (self.data_dir / name).mkdir(parents=True, exist_ok=True)

    def path(self, area: str, filename: str) -> Path:
        if area not in DATA_DIRECTORIES:
            raise ValueError(f"unknown storage area: {area}")
        return self.data_dir / area / filename

    def is_empty(self) -> bool:
        raw_dir = self.data_dir / "raw"
        return not any(path.is_file() and path.stat().st_size > 0 for path in raw_dir.glob("*.jsonl"))

    def write_json(self, area: str, filename: str, data: Any) -> None:
        target = self.path(area, filename)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")

    def read_json(self, area: str, filename: str, default: Any = None) -> Any:
        target = self.path(area, filename)
        if not target.exists():
            return default
        return json.loads(target.read_text(encoding="utf-8"))

    def append_jsonl(self, area: str, filename: str, rows: Iterable[dict[str, Any]]) -> None:
        target = self.path(area, filename)
        with target.open("a", encoding="utf-8") as handle:
            for row in rows:
                handle.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")

    def read_jsonl(self, area: str, filename: str) -> list[dict[str, Any]]:
        target = self.path(area, filename)
        if not target.exists():
            return []
        return [json.loads(line) for line in target.read_text(encoding="utf-8").splitlines() if line.strip()]

    def replace_raw_records(self, records: Iterable[RawRecord], filename: str = "records.jsonl") -> None:
        target = self.path("raw", filename)
        rows = [record.to_dict() for record in records]
        target.write_text("", encoding="utf-8")
        self.append_jsonl("raw", filename, rows)

    def load_raw_records(self, filename: str = "records.jsonl") -> list[RawRecord]:
        return [RawRecord.from_dict(row) for row in self.read_jsonl("raw", filename)]

    def replace_normalized(self, chunks: Iterable[NormalizedChunk]) -> None:
        rows = [chunk.to_dict() for chunk in chunks]
        self.path("normalized", "chunks.jsonl").write_text("", encoding="utf-8")
        self.append_jsonl("normalized", "chunks.jsonl", rows)

    def load_chunks(self) -> list[NormalizedChunk]:
        return [NormalizedChunk.from_dict(row) for row in self.read_jsonl("normalized", "chunks.jsonl")]
