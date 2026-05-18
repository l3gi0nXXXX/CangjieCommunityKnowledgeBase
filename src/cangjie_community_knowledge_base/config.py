"""Source scope and scheduler defaults for the Cangjie knowledge base."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import timedelta


@dataclass(frozen=True)
class SourceScope:
    """Declarative crawl scope. Implementations plug adapters into this scope."""

    organizations: tuple[str, ...]
    repo_discovery: tuple[str, ...]
    website_roots: tuple[str, ...]
    documentation_roots: tuple[str, ...]
    standard_library_repositories: tuple[str, ...]
    include_issue_history: bool = True
    include_pull_request_history: bool = True
    include_web_candidates: bool = True
    web_candidate_seeds: tuple[str, ...] = field(default_factory=tuple)


def default_source_scope() -> SourceScope:
    """Return the baseline scope requested for the independent monitor bridge."""

    return SourceScope(
        organizations=("cangjie", "cangjie-sig", "cangjie-tpc"),
        repo_discovery=("all-public-repos",),
        website_roots=("https://cangjie-lang.cn/",),
        documentation_roots=("https://cangjie-lang.cn/docs/",),
        standard_library_repositories=("cangjie/std", "cangjie/stdx"),
        include_issue_history=True,
        include_pull_request_history=True,
        include_web_candidates=True,
        web_candidate_seeds=(
            "https://gitcode.com/cangjie",
            "https://gitcode.com/cangjie-tpc",
            "https://gitcode.com/cangjie-sig",
        ),
    )


SCHEDULE_DEFAULTS: dict[str, timedelta] = {
    "website_docs_check": timedelta(hours=6),
    "website_docs_full_sync": timedelta(days=1),
    "repo_list": timedelta(hours=6),
    "active_repo": timedelta(minutes=30),
    "inactive_repo": timedelta(hours=6),
    "active_item": timedelta(minutes=10),
    "recent_closed_item": timedelta(hours=6),
    "archived_item": timedelta(days=7),
    "web_candidate": timedelta(days=7),
    "web_candidate_recrawl": timedelta(days=30),
    "derived_queue": timedelta(minutes=30),
    "weekly_full_rebuild": timedelta(days=7),
}


RETRY_DEFAULTS = {
    "max_attempts": 3,
    "initial_backoff_seconds": 30,
    "backoff_multiplier": 2,
    "stale_after_seconds": int(timedelta(days=2).total_seconds()),
    "degraded_after_seconds": int(timedelta(days=7).total_seconds()),
}
