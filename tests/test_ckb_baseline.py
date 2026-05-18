import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from cangjie_community_knowledge_base import (  # noqa: E402
    CangjieKnowledgeBase,
    KnowledgeMetadata,
    RawRecord,
    cangjie_evidence_pack,
    cangjie_hybrid_search,
    cangjie_knowledge_status,
    cangjie_source_search,
    default_source_scope,
)


class FakeAdapter:
    def __init__(self):
        self.full_calls = 0
        self.refresh_calls = []

    def fetch_full(self):
        self.full_calls += 1
        return [
            make_record(
                "repo-1",
                "repo",
                "https://gitcode.com/cangjie/stdx/blob/main/net.cj",
                "cangjie/stdx",
                "func HttpClient proxy",
                "Cangjie stdx HttpClient supports CONNECT tunnel behavior.",
            ),
            make_record(
                "doc-1",
                "documentation",
                "https://cangjie-lang.cn/docs/stdx/net/http",
                None,
                "HTTP docs",
                "Cangjie documentation describes stdx HTTP client APIs.",
            ),
            make_record(
                "web-1",
                "web_candidate",
                "https://example.org/cangjie-community-note",
                None,
                "Community note",
                "Community web candidate discusses package examples.",
                review_state="candidate",
            ),
            make_record(
                "local-leak",
                "repo",
                "/Users/l3gi0n/private/raw.txt",
                "cangjie/cangjie",
                "Local source",
                "A local path source mentions SecretSymbol.",
                derived_from=("/Users/l3gi0n/private/parent.txt",),
            ),
        ]

    def refresh_scope(self, query, freshness_policy):
        self.refresh_calls.append((query, freshness_policy))
        return [
            make_record(
                "refresh-%s" % index,
                "issue",
                "https://gitcode.com/cangjie/cangjie/issues/%s" % index,
                "cangjie/cangjie",
                "Recent issue %s" % index,
                "Fresh result %s for %s via %s." % (index, query, freshness_policy),
            )
            for index in range(5)
        ]


def make_record(
    record_id,
    source_type,
    source_url,
    repo,
    title,
    content,
    review_state="approved",
    derived_from=(),
):
    metadata = KnowledgeMetadata(
        sourceType=source_type,
        sourceUrl=source_url,
        repo=repo,
        commit="abc123" if repo else None,
        docVersion="1.0.0" if source_type in {"documentation", "website"} else None,
        crawlAt="2026-05-16T00:00:00+00:00",
        indexedAt=None,
        knowledgeVersion="candidate-2026-05-16",
        trustLevel="high",
        reviewState=review_state,
        license="MulanPSL-2.0",
        derivedFrom=tuple(derived_from),
    )
    return RawRecord(record_id, title, content, metadata)


class CkbBaselineTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.adapter = FakeAdapter()
        self.kb = CangjieKnowledgeBase(self.tmp.name, adapter=self.adapter)

    def tearDown(self):
        self.tmp.cleanup()

    def test_scope_storage_bootstrap_and_status(self):
        scope = default_source_scope()
        self.assertEqual(scope.organizations, ("cangjie", "cangjie-sig", "cangjie-tpc"))
        self.assertIn("all-public-repos", scope.repo_discovery)
        self.assertIn("https://cangjie-lang.cn/", scope.website_roots)
        self.assertIn("https://cangjie-lang.cn/docs/", scope.documentation_roots)
        self.assertEqual(scope.standard_library_repositories, ("cangjie/std", "cangjie/stdx"))
        self.assertIn("https://gitcode.com/cangjie-sig", scope.web_candidate_seeds)

        result = self.kb.bootstrap()
        self.assertTrue(result["ranImmediately"])
        self.assertEqual(result["records"], 4)
        self.assertEqual(self.adapter.full_calls, 1)
        for area in ("raw", "normalized", "metadata", "indexes", "derived", "cache"):
            self.assertTrue((Path(self.tmp.name) / "data" / area).is_dir())

        status = cangjie_knowledge_status(self.kb)
        self.assertEqual(status["rawRecords"], 4)
        self.assertGreaterEqual(status["normalizedChunks"], 4)
        self.assertFalse(status["finalGitCodeReplyGeneration"])
        self.assertIn("data/indexes", status["storageLayout"])

    def test_scheduler_sla_retry_and_stale_status(self):
        defaults = self.kb.scheduler.defaults()
        self.assertEqual(defaults["website_docs_check"], int(timedelta(hours=6).total_seconds()))
        self.assertEqual(defaults["website_docs_full_sync"], int(timedelta(days=1).total_seconds()))
        self.assertEqual(defaults["repo_list"], int(timedelta(hours=6).total_seconds()))
        self.assertEqual(defaults["active_repo"], int(timedelta(minutes=30).total_seconds()))
        self.assertEqual(defaults["active_item"], int(timedelta(minutes=10).total_seconds()))
        self.assertEqual(defaults["weekly_full_rebuild"], int(timedelta(days=7).total_seconds()))

        now = datetime(2026, 5, 16, tzinfo=timezone.utc)
        self.assertEqual(self.kb.scheduler.record_failure("repo_list", now=now).status, "retrying")
        self.kb.scheduler.record_failure("repo_list", now=now)
        self.assertEqual(self.kb.scheduler.record_failure("repo_list", now=now).status, "degraded")

        self.kb.scheduler.record_success("website_docs_check")
        state = self.kb.storage.read_json("metadata", "job_state.json")
        state["website_docs_check"]["lastSuccessAt"] = (now - timedelta(days=3)).isoformat()
        self.kb.storage.write_json("metadata", "job_state.json", state)
        self.assertEqual(self.kb.scheduler.status(now=now)["jobs"]["website_docs_check"]["status"], "stale")

    def test_evidence_pack_no_reply_and_no_local_path_leakage(self):
        self.kb.bootstrap()
        self.assertTrue(cangjie_source_search(self.kb, "CONNECT tunnel"))
        pack = cangjie_evidence_pack(self.kb, "SecretSymbol", limit=1)
        self.assertNotIn("reply", pack)
        self.assertNotIn("answer", pack)
        evidence = pack["evidence"][0]["evidence"]
        self.assertIsNone(evidence["sourceUrl"])
        self.assertEqual(evidence["derivedFrom"], [])

    def test_scoped_refresh_policies_limit_gate_cooldown_and_publish(self):
        self.kb.bootstrap()
        self.assertEqual(cangjie_hybrid_search(self.kb, "Fresh result", freshnessPolicy="use_active"), [])
        self.assertEqual(self.adapter.refresh_calls, [])

        gated = self.kb.refresh("Fresh result", "force_candidate")
        self.assertEqual(gated["skippedReason"], "candidate-gate")

        refreshed = self.kb.refresh("Fresh result", "ensure_recent")
        self.assertEqual(refreshed["refreshed"], 3)
        self.assertEqual(len(self.adapter.refresh_calls), 1)
        self.assertEqual(len([record for record in self.kb.storage.load_raw_records() if record.id.startswith("refresh-")]), 3)

        cooldown = self.kb.refresh("Fresh result", "ensure_recent")
        self.assertEqual(cooldown["skippedReason"], "cooldown")

        self.kb.publisher.create_candidate("candidate-2")
        self.assertFalse(self.kb.publisher.publish_candidate(["missing-smoke-query"]).published)
        self.assertTrue(self.kb.publisher.publish_candidate(["CONNECT tunnel"]).published)
        self.assertEqual(self.kb.publisher.active_version(), "candidate-2")

        forced = self.kb.refresh("Fresh result", "force_candidate")
        self.assertEqual(forced["refreshed"], 3)
        audit = self.kb.storage.read_json("metadata", "jit_refresh_audit.json")
        self.assertGreaterEqual(len(audit), 4)


if __name__ == "__main__":
    unittest.main()
