package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.io.InputStream
import std.process.{ProcessRedirect, launch}
import std.unittest.*
import std.unittest.testmacro.*

private let R6_ENVIRONMENT_PLAN_COMMIT =
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

private class R6EnvironmentPlanProbe <: CkbReproEnvironmentProbe {
    public var calls: Int64 = 0
    public var diagnostic: String = "ok"
    public var commitDrift: Bool = false
    public var evidenceCommitDrift: Bool = false
    public var tamperUnobservable: Bool = false
    public var credentialValue: Bool = false
    public var explode: Bool = false
    public func inspect(attested: CkbReproEnvironmentLock,
        attestedInputHash: String, _: String): CkbReproEnvironmentProbeResult {
        this.calls += 1
        if (this.explode) { throw Exception("probe failure") }
        let out = CkbReproEnvironmentProbeResult()
        if (this.diagnostic != "ok") {
            out.diagnostic = this.diagnostic; return out
        }
        let parsed = parseCkbReproEnvironmentLock(
            renderCkbReproEnvironmentLock(attested).toArray())
        if (!parsed[0].ok) { return out }
        let observed = parsed[1]
        observed.cangjieSdkVersion = "1.0.0-仓颉🙂"
        observed.cangjieSdkHash = benchmarkGapSha256("sdk")
        observed.opensslVersion = "OpenSSL 3.6.0"
        observed.qdrantImageDigest = benchmarkGapSha256("qdrant")
        observed.claudeCodeVersion = "Claude Code 1.0.0"
        observed.archiveTool = "tar+zstd"
        observed.archiveToolVersion = "bsdtar 3|zstd 1"
        observed.authorityDeliveryHash = benchmarkGapSha256("delivery")
        if (this.tamperUnobservable) {
            observed.localDocsPolicy = "tampered-policy"
            observed.modelEffort = "tampered-effort"
        }
        if (this.credentialValue) {
            observed.glmCredentialEnv = "GLM_API_KEY=secret-value"
        }
        if (this.commitDrift) {
            observed.runCandidateCommit =
                "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        }
        out.ok = true; out.diagnostic = "ok"; out.observed = observed
        out.attestedInputHash = attestedInputHash
        out.attestationEvidenceCommit = if (this.evidenceCommitDrift) {
            "cccccccccccccccccccccccccccccccccccccccc"
        } else { observed.runCandidateCommit }
        out
    }
}

private func r6EnvironmentPlanReadPipe(pipe: InputStream): String {
    let bytes = ArrayList<UInt8>()
    let buffer = Array<UInt8>(1024, repeat: UInt8(0))
    while (true) {
        let count = pipe.read(buffer)
        if (count <= 0) { break }
        for (index in 0..count) { bytes.add(buffer[index]) }
    }
    String.fromUtf8(bytes.toArray()).trimAscii()
}

private func r6EnvironmentPlanSandbox(): String {
    let process = launch("mktemp", ["-d", "/tmp/ckb-r6-env-plan-XXXXXX"],
        stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
    let output = spawn { => r6EnvironmentPlanReadPipe(process.stdOutPipe) }
    let error = spawn { => r6EnvironmentPlanReadPipe(process.stdErrPipe) }
    let code = process.wait(); let path = output.get(); _ = error.get()
    if (code != 0 || path == "") { throw Exception("mktemp failed") }
    canonicalize(Path(path)).toString()
}

private func r6EnvironmentPlanTemplate(path: String): Unit {
    let source = canonicalize(Path(
        "../reproducibility/manifests/environment-lock.json"))
    let parsed = parseCkbReproEnvironmentLock(File.readFrom(source))
    if (!parsed[0].ok) { throw Exception("template invalid") }
    let plan = parsed[1]
    plan.identityStatus = "planned"
    plan.cangjieSdkVersion = ""; plan.cangjieSdkHash = ""
    plan.opensslVersion = ""; plan.qdrantImageDigest = ""
    plan.claudeCodeVersion = ""; plan.archiveToolVersion = ""
    plan.authorityDeliveryHash = ""; plan.compositionManifestHash = ""
    plan.attestationAuthorityHash = ""
    File.writeTo(Path(path), renderCkbReproEnvironmentLock(plan).toArray())
}

private func r6EnvironmentPlanPrepare(sandbox: String): (String, String) {
    let template = Path(sandbox).join("template-资料🙂.json").toString()
    r6EnvironmentPlanTemplate(template)
    let root = Path(sandbox).join("composition-资料🙂").toString()
    let runtime = Path(sandbox).join("runtime.json").toString()
    let policy = canonicalize(Path(
        "../public-build-inputs/portable-path-policy.json")).toString()
    let routes = canonicalize(Path(
        "../public-build-inputs/api-routes.json")).toString()
    File.writeTo(Path(runtime), File.readFrom(Path(
        canonicalize(Path("../assets/repro-runtime-config.json")).toString())))
    let staged = runCkbReproCompositionStageCli([
        "ckb-repro-composition-stage", "--prepare-only", "--root", root,
        "--mode", "p3-vector-build", "--environment-plan", template,
        "--input", "runtime_config=${runtime}",
        "--input", "path_policy=${policy}",
        "--input", "local_root_map=${runtime}",
        "--input", "api_routes=${routes}",
        "--input", "path_context=${runtime}"])
    if (!staged.ok) { throw Exception("composition prepare failed") }
    (template, Path(root).join(
        "reproducibility/manifests/runtime-composition.json").toString())
}

private func r6EnvironmentPlanArgs(template: String, composition: String,
    repository: String, output: String): Array<String> {
    ["ckb-repro-environment-plan", "--environment-template", template,
        "--composition-manifest", composition, "--run-candidate-commit",
        R6_ENVIRONMENT_PLAN_COMMIT, "--repository-root", repository,
        "--output", output]
}

private func r6EnvironmentPlanOwnedRemove(path: String,
    files: Array<String>): Unit {
    if (!exists(Path(path))) { return }
    let identity = ckbReproDirectoryOwnershipIdentity(path)
    if (identity == "" || !ckbReproCleanupOwnedDirectory(path, identity, files)) {
        throw Exception("owned cleanup failed")
    }
}

private func r6EnvironmentPlanCleanup(sandbox: String): Unit {
    let root = Path(sandbox).join("composition-资料🙂")
    if (exists(root)) {
        r6EnvironmentPlanOwnedRemove(root.join("assets").toString(),
            ["runtime_config.json", "path_policy.json", "api_routes.json"])
        r6EnvironmentPlanOwnedRemove(root.join("private-authority").toString(),
            ["local-roots.json", "path-context.json"])
        r6EnvironmentPlanOwnedRemove(root.join("public-build-inputs").toString(), [])
        r6EnvironmentPlanOwnedRemove(
            root.join("reproducibility/manifests").toString(),
            ["runtime-composition.json"])
        r6EnvironmentPlanOwnedRemove(root.join("reproducibility").toString(), [])
        r6EnvironmentPlanOwnedRemove(root.toString(), [])
    }
    r6EnvironmentPlanOwnedRemove(Path(sandbox).join("repository").toString(), [])
    r6EnvironmentPlanOwnedRemove(sandbox,
        ["template-资料🙂.json", "runtime.json", "environment-plan-资料🙂.json",
            "existing.json", "malformed.json", "binary.json",
            "composition-source.json", "composition-swap.json",
            "composition-replacement.json"])
}

@Test
public class CkbReproEnvironmentPlanWriterTest {
    @TestCase
    public func r6EnvironmentPlanPos01MeasuresAndPublishesCanonicalPlan(): Unit {
        let sandbox = r6EnvironmentPlanSandbox()
        let repository = Path(sandbox).join("repository")
        Directory.create(repository)
        let prepared = r6EnvironmentPlanPrepare(sandbox)
        let output = Path(sandbox).join("environment-plan-资料🙂.json")
        let probe = R6EnvironmentPlanProbe()
        try {
            let result = runCkbReproEnvironmentPlanCliWithProbe(
                r6EnvironmentPlanArgs(prepared[0], prepared[1],
                    canonicalize(repository).toString(), output.toString()), probe)
            @Expect(result.ok, true)
            @Expect(result.probeCalls, 1)
            @Expect(probe.calls, 1)
            @Expect(result.providerCalls, 0)
            @Expect(result.modelCalls, 0)
            @Expect(result.runnerCalls, 0)
            @Expect(result.output.contains("\"ok\""), false)
            let bytes = File.readFrom(output)
            let parsed = parseCkbReproEnvironmentLock(bytes)
            @Expect(parsed[0].ok, true)
            @Expect(validateCkbReproEnvironmentLock(parsed[1]).ok, true)
            @Expect(parsed[1].identityStatus, "planned")
            @Expect(parsed[1].runCandidateCommit, R6_ENVIRONMENT_PLAN_COMMIT)
            @Expect(parsed[1].cangjieSdkVersion, "1.0.0-仓颉🙂")
            @Expect(parsed[1].localDocsPolicy, "disabled")
            @Expect(parsed[1].modelEffort, "max")
            @Expect(parsed[1].compositionManifestHash, "")
            @Expect(parsed[1].attestationAuthorityHash, "")
            @Expect(renderCkbReproEnvironmentLock(parsed[1]).toArray(), bytes)
            @Expect(result.environmentPlanHash, ckbReproBundleHash(bytes))
        } finally { r6EnvironmentPlanCleanup(sandbox) }
    }

    @TestCase
    public func r6EnvironmentPlanNeg01ProbeFailureAndDriftPublishNothing(): Unit {
        for (kind in ["failure", "commit", "evidence", "exception",
            "credential"]) {
            let sandbox = r6EnvironmentPlanSandbox()
            let repository = Path(sandbox).join("repository")
            Directory.create(repository)
            let prepared = r6EnvironmentPlanPrepare(sandbox)
            let output = Path(sandbox).join("environment-plan-资料🙂.json")
            let probe = R6EnvironmentPlanProbe()
            probe.commitDrift = kind == "commit"
            probe.evidenceCommitDrift = kind == "evidence"
            probe.explode = kind == "exception"
            probe.credentialValue = kind == "credential"
            if (kind == "failure") {
                probe.diagnostic = "environment_probe_unavailable"
            }
            try {
                let result = runCkbReproEnvironmentPlanCliWithProbe(
                    r6EnvironmentPlanArgs(prepared[0], prepared[1],
                        canonicalize(repository).toString(), output.toString()),
                    probe)
                @Expect(result.ok, false)
                @Expect(result.probeCalls, 1)
                @Expect(probe.calls, 1)
                @Expect(exists(output), false)
                @Expect(result.output.contains("secret-value"), false)
            } finally { r6EnvironmentPlanCleanup(sandbox) }
        }
    }

    @TestCase
    public func r6EnvironmentPlanBnd01InvalidCommitPathsAndOutputNeverProbe(): Unit {
        let sandbox = r6EnvironmentPlanSandbox()
        let repository = Path(sandbox).join("repository")
        Directory.create(repository)
        let prepared = r6EnvironmentPlanPrepare(sandbox)
        let output = Path(sandbox).join("environment-plan-资料🙂.json")
        let base = r6EnvironmentPlanArgs(prepared[0], prepared[1],
            canonicalize(repository).toString(), output.toString())
        let probe = R6EnvironmentPlanProbe()
        try {
            let badCommit = base.clone(); badCommit[6] = "not-a-commit"
            @Expect(runCkbReproEnvironmentPlanCliWithProbe(
                badCommit, probe).diagnostic, "environment_plan_commit_invalid")
            let noncanonical = base.clone()
            noncanonical[10] = Path(sandbox).join(
                "repository/../environment-plan-资料🙂.json").toString()
            @Expect(runCkbReproEnvironmentPlanCliWithProbe(
                noncanonical, probe).diagnostic, "environment_plan_output_invalid")
            @Expect(probe.calls, 0)
            @Expect(exists(output), false)
        } finally { r6EnvironmentPlanCleanup(sandbox) }
    }

    @TestCase
    public func r6EnvironmentPlanBnd02ExactRetryAndConflictNeverOverwrite(): Unit {
        let sandbox = r6EnvironmentPlanSandbox()
        let repository = Path(sandbox).join("repository")
        Directory.create(repository)
        let prepared = r6EnvironmentPlanPrepare(sandbox)
        let output = Path(sandbox).join("environment-plan-资料🙂.json")
        let probe = R6EnvironmentPlanProbe()
        let args = r6EnvironmentPlanArgs(prepared[0], prepared[1],
            canonicalize(repository).toString(), output.toString())
        try {
            @Expect(runCkbReproEnvironmentPlanCliWithProbe(args, probe).ok, true)
            let exact = File.readFrom(output)
            @Expect(runCkbReproEnvironmentPlanCliWithProbe(args, probe).ok, true)
            @Expect(File.readFrom(output), exact)
            remove(output, recursive: false)
            File.writeTo(output, "preserve-mismatch".toArray())
            let conflict = runCkbReproEnvironmentPlanCliWithProbe(args, probe)
            @Expect(conflict.diagnostic, "environment_plan_output_conflict")
            @Expect(String.fromUtf8(File.readFrom(output)), "preserve-mismatch")
            @Expect(probe.calls, 3)
        } finally { r6EnvironmentPlanCleanup(sandbox) }
    }

    @TestCase
    public func r6EnvironmentPlanBnd03UnobservableTamperIsNotCopied(): Unit {
        let sandbox = r6EnvironmentPlanSandbox()
        let repository = Path(sandbox).join("repository")
        Directory.create(repository)
        let prepared = r6EnvironmentPlanPrepare(sandbox)
        let output = Path(sandbox).join("environment-plan-资料🙂.json")
        let probe = R6EnvironmentPlanProbe(); probe.tamperUnobservable = true
        try {
            let result = runCkbReproEnvironmentPlanCliWithProbe(
                r6EnvironmentPlanArgs(prepared[0], prepared[1],
                    canonicalize(repository).toString(), output.toString()), probe)
            @Expect(result.ok, true)
            let plan = parseCkbReproEnvironmentLock(File.readFrom(output))[1]
            @Expect(plan.localDocsPolicy, "disabled")
            @Expect(plan.modelEffort, "max")
            @Expect(renderCkbReproEnvironmentLock(plan).contains(
                "tampered-policy"), false)
        } finally { r6EnvironmentPlanCleanup(sandbox) }
    }

    @TestCase
    public func r6EnvironmentPlanBnd04SymlinkTemplateIsRejected(): Unit {
        let sandbox = r6EnvironmentPlanSandbox()
        let repository = Path(sandbox).join("repository")
        Directory.create(repository)
        let prepared = r6EnvironmentPlanPrepare(sandbox)
        let output = Path(sandbox).join("environment-plan-资料🙂.json")
        let link = Path(sandbox).join("template-link.json")
        let probe = R6EnvironmentPlanProbe()
        try {
            @Expect(launch("/bin/ln", ["-s", prepared[0], link.toString()])
                .wait(), 0)
            let result = runCkbReproEnvironmentPlanCliWithProbe(
                r6EnvironmentPlanArgs(link.toString(), prepared[1],
                    canonicalize(repository).toString(), output.toString()), probe)
            @Expect(result.diagnostic, "environment_plan_template_invalid")
            @Expect(probe.calls, 0)
            @Expect(exists(output), false)
        } finally {
            if (exists(link)) { remove(link, recursive: false) }
            r6EnvironmentPlanCleanup(sandbox)
        }
    }

    @TestCase
    public func r6EnvironmentPlanNeg02MalformedAndBinaryTemplateNeverProbe(): Unit {
        let sandbox = r6EnvironmentPlanSandbox()
        let repository = Path(sandbox).join("repository")
        Directory.create(repository)
        let prepared = r6EnvironmentPlanPrepare(sandbox)
        let output = Path(sandbox).join("environment-plan-资料🙂.json")
        let probe = R6EnvironmentPlanProbe()
        try {
            for (name in ["malformed.json", "binary.json"]) {
                let path = Path(sandbox).join(name)
                File.writeTo(path, if (name == "binary.json") {
                    [0xff, 0xfe]
                } else { "{bad".toArray() })
                let args = r6EnvironmentPlanArgs(path.toString(), prepared[1],
                    canonicalize(repository).toString(), output.toString())
                @Expect(runCkbReproEnvironmentPlanCliWithProbe(
                    args, probe).ok, false)
                @Expect(exists(output), false)
            }
            @Expect(probe.calls, 0)
        } finally { r6EnvironmentPlanCleanup(sandbox) }
    }

    @TestCase
    public func r6EnvironmentPlanBnd05ProbeRejectsRepositoryDriftAndCompositionLinksOrSwap(): Unit {
        @Expect(ckbReproResolveProbeRepositoryRoot(
            "/canonical/repository-a", false, "/canonical/repository-b"), "")
        @Expect(ckbReproResolveProbeRepositoryRoot(
            "/canonical/repository-a", false, "/canonical/repository-a"),
            "/canonical/repository-a")
        @Expect(ckbReproResolveProbeRepositoryRoot(
            "/canonical/repository-a", true, "/canonical/repository-b"),
            "/canonical/repository-a")

        let sandbox = r6EnvironmentPlanSandbox()
        let source = Path(sandbox).join("composition-source.json")
        let link = Path(sandbox).join("composition-link.json")
        let swap = Path(sandbox).join("composition-swap.json")
        let replacement = Path(sandbox).join("composition-replacement.json")
        let expected = "canonical-composition".toArray()
        try {
            File.writeTo(source, expected)
            let expectedHash = ckbReproBundleHash(expected)
            @Expect(ckbReproProbeCompositionAuthority(
                canonicalize(source).toString(), expectedHash), true)
            @Expect(launch("/bin/ln", ["-s", canonicalize(source).toString(),
                link.toString()]).wait(), 0)
            @Expect(ckbReproProbeCompositionAuthority(link.toString(),
                expectedHash), false)
            remove(link, recursive: false)

            File.writeTo(swap, expected)
            File.writeTo(replacement, "swapped-composition".toArray())
            @Expect(launch("/bin/mv", [replacement.toString(),
                swap.toString()]).wait(), 0)
            @Expect(ckbReproProbeCompositionAuthority(
                canonicalize(swap).toString(), expectedHash), false)
        } finally {
            if (exists(link)) { remove(link, recursive: false) }
            r6EnvironmentPlanCleanup(sandbox)
        }
    }
}
