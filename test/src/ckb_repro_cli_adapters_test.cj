package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

private class P234ReleaseCliFake <: CkbReleaseCliAdapter {
    public var calls: Int64 = 0
    public var fail: Bool = false
    public func execute(options: CkbReleaseCliOptions): CkbReleaseCliOperationResult {
        this.calls += 1
        let out = CkbReleaseCliOperationResult()
        out.ok = !this.fail
        out.diagnostic = if (this.fail) { "invalid_response_encoding" } else { "ok" }
        out.summary = "版本=portable-仓颉🙂 图=ready"
        out
    }
}

private class P234P3CliFake <: CkbP3CliAdapter {
    public var calls: Int64 = 0
    public var fail: Bool = false
    public var cleaned: Bool = false
    public func execute(options: CkbP3CliOptions): CkbP3CliOperationResult {
        this.calls += 1
        let out = CkbP3CliOperationResult()
        out.ok = !this.fail
        out.diagnostic = if (this.fail) { "invalid_response_encoding" } else { "ok" }
        out.summary = "collection=仓颉🙂 points=7978 dimension=1024"
        if (this.fail) { this.cleaned = true }
        out
    }
}

private class P234P4CliFake <: CkbP4CliAdapter {
    public var calls: Int64 = 0
    public var fail: Bool = false
    public var cleaned: Bool = false
    public func execute(options: CkbP4CliOptions): CkbP4CliOperationResult {
        this.calls += 1
        let out = CkbP4CliOperationResult()
        out.ok = !this.fail
        out.diagnostic = if (this.fail) { "promotion_pointer_commit_failed" } else { "ok" }
        out.summary = "portable candidate 仓颉🙂 ready"
        if (this.fail) { this.cleaned = true }
        out
    }
}

@Test
public class CkbReproCliAdaptersTest {
    @TestCase
    public func p2Bnd01CliAdapterRejectsAmbiguousArgsAndKeepsUtf8(): Unit {
        let fake = P234ReleaseCliFake()
        @Expect(executeCkbReleaseCliAdapter([
            "ckb-release-export", "--store-root", "/tmp/仓颉🙂",
            "--logical-proof", "l", "--vector-proof", "v",
            "--output", "/tmp/out", "--output", "/tmp/again"
        ], fake).diagnostic, "duplicate_argument:--output")
        @Expect(executeCkbReleaseCliAdapter([
            "ckb-release-import", "--archive", "a", "--target-root"
        ], fake).diagnostic, "missing_argument_value:--target-root")
        @Expect(runCkbReleaseCli(["ckb-release-import"]).diagnostic,
            "required_argument_missing:--archive")
        @Expect(fake.calls, 0)
    }

    @TestCase
    public func p2Pos01CliAdapterRendersHumanUnlessJsonExplicit(): Unit {
        let fake = P234ReleaseCliFake()
        let args = ["ckb-release-import", "--archive", "/tmp/a",
            "--target-root", "/tmp/b"]
        let human = runCkbReleaseCli(args, fake)
        @Expect(human.ok, true)
        @Expect(human.output.contains("仓颉🙂"), true)
        @Expect(human.output.contains("\"ok\""), false)
        let json = executeCkbReleaseCliAdapter(
            ["ckb-release-import", "--archive", "/tmp/a",
             "--target-root", "/tmp/c", "--json"], fake)
        @Expect(json.output.contains("\"ok\":true"), true)
    }

    @TestCase
    public func p2Neg01CliAdapterPreservesFailureWithoutRawPayload(): Unit {
        let fake = P234ReleaseCliFake(); fake.fail = true
        let result = executeCkbReleaseCliAdapter([
            "ckb-release-import", "--archive", "/tmp/a",
            "--target-root", "/tmp/b"
        ], fake)
        @Expect(result.ok, false)
        @Expect(result.exitCode, 1)
        @Expect(result.output.contains("invalid_response_encoding"), true)
        @Expect(result.output.contains("\"result\""), false)
    }

    @TestCase
    public func p3Bnd01CliAdapterRejectsCrossModeAndMissingValues(): Unit {
        let fake = P234P3CliFake()
        @Expect(executeCkbP3CliAdapter([
            "ckb-qdrant-snapshot", "create", "--endpoint", "http://127.0.0.1:1",
            "--collection", "c", "--logical-manifest", "l", "--vector-proof", "v",
            "--output-root", "/tmp/o", "--snapshot", "wrong"
        ], fake).diagnostic, "argument_not_allowed:create:--snapshot")
        @Expect(executeCkbP3CliAdapter([
            "ckb-portable-vector-build", "--candidate-root", "c",
            "--environment-lock", "e", "--output-proof"
        ], fake).diagnostic, "missing_argument_value:--output-proof")
        @Expect(runCkbP3Cli(["ckb-qdrant-snapshot", "create"]).diagnostic,
            "required_argument_missing:--endpoint")
        @Expect(fake.calls, 0)
    }

    @TestCase
    public func p3Pos01CliAdapterRunsRestoreAndParityHumanOutput(): Unit {
        let fake = P234P3CliFake()
        let restore = runCkbP3Cli([
            "ckb-qdrant-snapshot", "restore", "--endpoint", "http://127.0.0.1:1",
            "--target-collection", "new", "--snapshot", "s", "--manifest", "m"
        ], fake)
        @Expect(restore.ok, true)
        @Expect(restore.output.contains("points=7978"), true)
        @Expect(restore.output.contains("\"ok\""), false)
        @Expect(executeCkbP3CliAdapter([
            "ckb-retrieval-parity", "--mode", "verify", "--manifest", "m",
            "--rest-endpoint", "http://127.0.0.1:1", "--mcp-stdio-command", "cmd",
            "--mcp-http-endpoint", "http://127.0.0.1:2"
        ], fake).ok, true)
    }

    @TestCase
    public func p3Pos02CliAdapterRunsPortableVectorBuild(): Unit {
        let fake = P234P3CliFake()
        let result = executeCkbP3CliAdapter([
            "ckb-portable-vector-build", "--candidate-root", "candidate",
            "--environment-lock", "environment.json", "--output-proof", "proof.json",
            "--json"
        ], fake)
        @Expect(result.ok, true)
        @Expect(result.output.contains("\"ok\":true"), true)
    }

    @TestCase
    public func p3Neg01CliAdapterContainsInvalidUtf8Failure(): Unit {
        let fake = P234P3CliFake(); fake.fail = true
        let result = executeCkbP3CliAdapter([
            "ckb-qdrant-snapshot", "verify", "--endpoint", "http://127.0.0.1:1",
            "--collection", "c", "--manifest", "m", "--logical-manifest", "l"
        ], fake)
        @Expect(result.diagnostic, "invalid_response_encoding")
        @Expect(result.output.contains("\"result\""), false)
    }

    @TestCase
    public func p3Neg02CliAdapterReportsCleanupOnBackendFailure(): Unit {
        let fake = P234P3CliFake(); fake.fail = true
        let result = executeCkbP3CliAdapter([
            "ckb-portable-vector-build", "--candidate-root", "candidate",
            "--environment-lock", "environment.json", "--output-proof", "proof.json"
        ], fake)
        @Expect(result.ok, false)
        @Expect(fake.cleaned, true)
    }

    @TestCase
    public func p4Bnd01CliAdapterRejectsUnknownDuplicateAndImplicitTargets(): Unit {
        let fake = P234P4CliFake()
        @Expect(executeCkbP4CliAdapter([
            "ckb-repro-build", "--output-root", "out", "--temporary-root", "tmp",
            "--unknown", "x"
        ], fake).diagnostic, "unknown_argument:--unknown")
        @Expect(executeCkbP4CliAdapter([
            "ckb-repro-promote", "--production-store", "p"
        ], fake).diagnostic, "required_argument_missing:--qdrant-endpoint")
        @Expect(runCkbP4Cli(["ckb-repro-build"]).diagnostic,
            "required_argument_missing:--output-root")
        @Expect(fake.calls, 0)
    }

    @TestCase
    public func p4Pos01CliAdapterRunsBuildWithExplicitRoots(): Unit {
        let fake = P234P4CliFake()
        let result = runCkbP4Cli([
            "ckb-repro-build", "--output-root", "/tmp/out 仓颉🙂",
            "--temporary-root", "/tmp/temp 仓颉🙂"
        ], fake)
        @Expect(result.ok, true)
        @Expect(result.output.contains("仓颉🙂"), true)
        @Expect(result.output.contains("\"ok\""), false)
    }

    @TestCase
    public func p4Pos03CliAdapterRequiresAndRunsApply(): Unit {
        let fake = P234P4CliFake()
        let result = executeCkbP4CliAdapter(p234PromotionArgs(true), fake)
        @Expect(result.ok, true)
        @Expect(fake.calls, 1)
    }

    @TestCase
    public func p4Neg03CliAdapterNeverExecutesWithoutApplyAndContainsFailure(): Unit {
        let fake = P234P4CliFake()
        @Expect(executeCkbP4CliAdapter(
            p234PromotionArgs(false), fake).diagnostic, "promotion_apply_required")
        @Expect(fake.calls, 0)
        fake.fail = true
        let failed = executeCkbP4CliAdapter(p234PromotionArgs(true), fake)
        @Expect(failed.ok, false)
        @Expect(fake.cleaned, true)
    }
}

private func p234PromotionArgs(apply: Bool): Array<String> {
    let values = ArrayList<String>()
    for (value in ["ckb-repro-promote", "--production-store", "/tmp/production",
        "--qdrant-endpoint", "http://127.0.0.1:6333",
        "--expected-active-version", "old", "--candidate-manifest", "candidate.json",
        "--p8-b-report", "p8-b.json"]) { values.add(value) }
    if (apply) { values.add("--apply") }
    values.toArray()
}
