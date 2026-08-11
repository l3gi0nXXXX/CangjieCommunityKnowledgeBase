package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.io.InputStream
import std.process.{ProcessRedirect, launch}
import std.unittest.*
import std.unittest.testmacro.*

private let R6_ATTESTATION_FINGERPRINT =
    "0123456789ABCDEF0123456789ABCDEF01234567"

private class R6AttestationProbe <: CkbReproEnvironmentProbe {
    public var calls: Int64 = 0
    public func inspect(attested: CkbReproEnvironmentLock,
        attestedInputHash: String, evidenceRepositoryRoot: String):
        CkbReproEnvironmentProbeResult {
        this.calls += 1
        let out = CkbReproEnvironmentProbeResult()
        out.ok = true; out.diagnostic = "ok"
        out.observed = attested; out.attestedInputHash = attestedInputHash
        out.attestationEvidenceCommit = attested.runCandidateCommit
        out
    }
}

private class R6AttestationPlanAttachFailureHook <:
    CkbReproCompositionSealCommitHook {
    public func beforeCompositionCommit(): Unit {}
    public func afterTempAcquired(path: String, kind: String): Unit {}
    public func afterTargetPublished(path: String, kind: String): Unit {}
    public func forceParentFsyncFailure(kind: String): Bool { false }
    public func forceInitialTempIdentityFailure(kind: String): Bool {
        kind == "plan"
    }
    public func afterCompositionCommitted(compositionPath: String,
        expectedMode: String): Bool { false }
}

private func r6AttestationReadPipe(pipe: InputStream): String {
    let bytes = ArrayList<UInt8>()
    let buffer = Array<UInt8>(1024, repeat: UInt8(0))
    while (true) {
        let count = pipe.read(buffer)
        if (count <= 0) { break }
        for (index in 0..count) { bytes.add(buffer[index]) }
    }
    String.fromUtf8(bytes.toArray()).trimAscii()
}

private func r6AttestationSandbox(): String {
    let process = launch("mktemp", ["-d",
        "/tmp/ckb-r6-attestation-XXXXXX"],
        stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
    let output = spawn { => r6AttestationReadPipe(process.stdOutPipe) }
    let error = spawn { => r6AttestationReadPipe(process.stdErrPipe) }
    let code = process.wait(); let path = output.get(); _ = error.get()
    if (code != 0 || path == "") { throw Exception("mktemp failed") }
    canonicalize(Path(path)).toString()
}

private func r6AttestationPlanned(path: String): Unit {
    let source = canonicalize(Path(
        "../reproducibility/manifests/environment-lock.json"))
    let parsed = parseCkbReproEnvironmentLock(File.readFrom(source))
    if (!parsed[0].ok) { throw Exception("planned fixture invalid") }
    let plan = parsed[1]
    plan.identityStatus = "planned"
    plan.cangjieSdkVersion = "1.0.0"
    plan.cangjieSdkHash = benchmarkGapSha256("sdk")
    plan.opensslVersion = "OpenSSL 3"
    plan.qdrantImageDigest = benchmarkGapSha256("qdrant")
    plan.runCandidateCommit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    plan.claudeCodeVersion = "1.0.0"
    plan.archiveTool = "tar+zstd"
    plan.archiveToolVersion = "tar 1|zstd 1"
    plan.authorityDeliveryHash = benchmarkGapSha256("delivery")
    plan.compositionManifestHash = ""
    plan.attestationAuthorityHash = ""
    File.writeTo(Path(path), renderCkbReproEnvironmentLock(plan).toArray())
}

private func r6AttestationRuntime(): CkbRuntimeConfig {
    let value = CkbRuntimeConfig()
    value.networkEnabled = false
    value.embeddingProvider = "deterministic"
    value.embeddingModel = "嵌入🙂-v1"
    value.embeddingDimensions = 16
    value.embeddingEndpoint = ""
    value.embeddingBatchSize = 16
    value.embeddingMaxBatchBytes = 65536
    value.embeddingMaxTextBytes = 8192
    value.embeddingTotalTimeoutMillis = 0
    value.embeddingTimeoutMillis = 10000
    value.embeddingRetryCount = 2
    value.embeddingAllowPrivateEndpoint = false
    value.vectorBackend = "qdrant"
    value.vectorActiveCollection = "active"
    value.vectorCandidateCollection = "candidate"
    value.vectorEndpoint = "http://127.0.0.1:6333"
    value.vectorDimensions = 16
    value.vectorDistance = "Cosine"
    value.vectorTimeoutMillis = 10000
    value.vectorRetryCount = 2
    value.vectorAllowPrivateEndpoint = true
    value.timeoutMillis = 10000; value.retryCount = 2
    value.networkProxy = ""; value.networkEnvProxyEnabled = false
    value.networkNoProxy = ""; value.networkInsecureSkipTlsVerify = false
    value.networkCaFile = ""; value.networkAllowPrivateNetwork = true
    value.networkAllowedHosts = "127.0.0.1"
    value.serviceBind = "127.0.0.1"; value.servicePort = 18890
    value
}

private func r6AttestationPolicy(): CkbPortablePathPolicy {
    let policy = CkbPortablePathPolicy()
    policy.schemaVersion = "ckb-portable-path-policy-v1"
    policy.baselineState = "historicalPrePortableBaseline"
    policy.unmappedAction = "fail"
    policy.sourceRootRuleId =
        "source-lock-repository-commit-tree-relative-v1"
    for (value in ["/usr/bin/env", "/dev/null"]) {
        policy.allowlist.add(value)
    }
    for (value in ["PROJECT_ROOT", "SOURCE_ROOT", "USER_HOME", "SDK_ROOT",
        "INSTALL_ROOT", "BUILD_ROOT", "TMPDIR", "ABSOLUTE"]) {
        policy.placeholders.add("{{CKB_PATH:${value}}}")
    }
    for (value in ["sourceId", "sourceUrl", "repo", "path", "derivedFrom",
        "title", "content", "chunk", "citation"]) {
        policy.fieldCoverage.add(value)
    }
    for (pair in ["source_locator|source_lock_relative",
        "declared_project_root|placeholder", "user_home|placeholder",
        "sdk_install_build_tmp|explicit_root_placeholder",
        "runtime_state|exclude", "non_filesystem_slash_text|preserve",
        "absolute_path_semantics_example|semantic_placeholder",
        "unmapped|fail"]) {
        let parts = pair.split("|"); let row = CkbPortablePathCategory()
        row.id = parts[0]; row.action = parts[1]; policy.categories.add(row)
    }
    policy
}

private func r6AttestationPrepare(sandbox: String): (String, String, String) {
    let plan = Path(sandbox).join("planned.json").toString()
    r6AttestationPlanned(plan)
    let root = Path(sandbox).join("组合🙂").toString()
    let runtime = Path(sandbox).join("runtime.json").toString()
    let policy = Path(sandbox).join("policy.json").toString()
    let routes = Path(sandbox).join("routes.json").toString()
    File.writeTo(Path(runtime),
        renderCkbReproCliRuntimeConfig(r6AttestationRuntime()).toArray())
    File.writeTo(Path(policy),
        renderCkbPortablePathPolicy(r6AttestationPolicy()).toArray())
    let apiRoutes = ArrayList<String>(); apiRoutes.add("/v1/cangjie/task")
    File.writeTo(Path(routes), renderCkbReproApiRoutes(apiRoutes).toArray())
    let result = runCkbReproCompositionStageCli([
        "ckb-repro-composition-stage", "--prepare-only",
        "--root", root, "--mode", "p3-vector-build",
        "--environment-plan", plan,
        "--input", "runtime_config=${runtime}",
        "--input", "path_policy=${policy}",
        "--input", "local_root_map=${runtime}",
        "--input", "api_routes=${routes}",
        "--input", "path_context=${runtime}"])
    if (!result.ok) { throw Exception("prepare failed:${result.diagnostic}") }
    let manifest = Path(root).join(
        "reproducibility/manifests/runtime-composition.json").toString()
    if (!ckbReproReadSingleFileNoFollow(manifest, 64 * 1024)[0] ||
        exists(Path(root).join(
            "reproducibility/manifests/environment-lock.json"))) {
        throw Exception("prepare publication invalid")
    }
    (root, plan, manifest)
}

private func r6AttestationWriterArgs(plan: String, manifest: String,
    output: String): Array<String> {
    ["ckb-repro-attestation-authority-freeze",
        "--environment-lock", plan,
        "--composition-manifest", manifest,
        "--signing-fingerprint", R6_ATTESTATION_FINGERPRINT,
        "--output-root", output]
}

private func r6AttestationFinalizeArgs(root: String, plan: String,
    authority: String): Array<String> {
    let args = ArrayList<String>()
    args.add("ckb-repro-composition-seal")
    args.add("--root"); args.add(root)
    args.add("--mode"); args.add("p3-vector-build")
    args.add("--environment-plan"); args.add(plan)
    args.add("--attestation-authority"); args.add(authority)
    for (role in ckbReproCliCompositionRoles("p3-vector-build")) {
        args.add("--asset")
        args.add("${role}=${ckbReproCliCompositionRoleRelativePath(role)}")
    }
    args.toArray()
}

private func r6AttestationOwnedRemove(path: String,
    files: Array<String>): Unit {
    if (!exists(Path(path))) { return }
    let identity = ckbReproDirectoryOwnershipIdentity(path)
    if (identity == "" ||
        !ckbReproCleanupOwnedDirectory(path, identity, files)) {
        throw Exception("owned cleanup failed")
    }
}

private func r6AttestationCleanup(sandbox: String): Unit {
    let root = Path(sandbox).join("组合🙂")
    if (exists(root)) {
        r6AttestationOwnedRemove(root.join("assets").toString(),
            ["runtime_config.json", "path_policy.json", "api_routes.json"])
        r6AttestationOwnedRemove(root.join("private-authority").toString(),
            ["local-roots.json", "path-context.json"])
        r6AttestationOwnedRemove(root.join("public-build-inputs").toString(), [])
        r6AttestationOwnedRemove(root.join("reproducibility/manifests").toString(),
            ["runtime-composition.json", "environment-plan.json",
                "environment-attestation-authority.json", "environment-lock.json"])
        r6AttestationOwnedRemove(root.join("reproducibility").toString(), [])
        r6AttestationOwnedRemove(root.toString(), [])
    }
    r6AttestationOwnedRemove(Path(sandbox).join("authority").toString(),
        ["environment-plan.json", "environment-attestation-authority.json"])
    for (name in ["linked-parent"]) {
        let path = Path(sandbox).join(name)
        if (exists(path)) { remove(path, recursive: false) }
    }
    for (name in ["existing", "real-parent"]) {
        r6AttestationOwnedRemove(Path(sandbox).join(name).toString(), [])
    }
    r6AttestationOwnedRemove(sandbox,
        ["planned.json", "runtime.json", "policy.json", "routes.json",
            "malformed.json", "binary.json", "sentinel.txt"])
}

@Test
public class CkbReproAttestationAuthorityWriterTest {
    @TestCase
    public func r6AttestationE2ePrepareWriterFinalizeIsExact(): Unit {
        let sandbox = r6AttestationSandbox()
        try {
            let prepared = r6AttestationPrepare(sandbox)
            let output = Path(sandbox).join("authority").toString()
            let writer = runCkbReproAttestationAuthorityFreezeCli(
                r6AttestationWriterArgs(prepared[1], prepared[2], output))
            @Expect(writer.ok, true)
            @Expect(writer.providerCalls + writer.modelCalls + writer.runnerCalls,
                0)
            let plan = Path(output).join("environment-plan.json").toString()
            let authority = Path(output).join(
                "environment-attestation-authority.json").toString()
            let probe = R6AttestationProbe()
            let final = runCkbReproCompositionSealCliWithProbe(
                r6AttestationFinalizeArgs(prepared[0], plan, authority), probe)
            @Expect(final.ok, true)
            @Expect(probe.calls, 1)
            let manifestBytes = ckbReproReadSingleFileNoFollow(
                prepared[2], 64 * 1024)[1]
            let manifestHash = ckbReproBundleHash(manifestBytes)
            let frozenPath = Path(prepared[0]).join(
                "reproducibility/manifests/environment-lock.json").toString()
            let frozen = parseCkbReproEnvironmentLock(
                ckbReproReadSingleFileNoFollow(frozenPath, 128 * 1024)[1])
            @Expect(frozen[0].ok, true)
            @Expect(validateCkbReproEnvironmentLock(frozen[1],
                mode: "execution").ok, true)
            @Expect(frozen[1].identityStatus, "frozen")
            @Expect(frozen[1].compositionManifestHash, manifestHash)
            let authorityBytes = ckbReproReadSingleFileNoFollow(
                authority, 64 * 1024)[1]
            let verified = loadCkbReproVerifiedAttestationAuthority(
                authorityBytes, frozen[1].attestationAuthorityHash)
            @Expect(verified[0].ok, true)
            @Expect(verified[1].observedEnvironmentProjectionHash(),
                ckbReproObservedEnvironmentProjectionHash(frozen[1]))
        } finally { r6AttestationCleanup(sandbox) }
    }

    @TestCase
    public func r6AttestationNegTamperedCompositionAssetFailsClosed(): Unit {
        let sandbox = r6AttestationSandbox()
        try {
            let prepared = r6AttestationPrepare(sandbox)
            File.writeTo(Path(prepared[0]).join("assets/runtime_config.json"),
                "tampered🙂".toArray())
            let output = Path(sandbox).join("authority").toString()
            let result = runCkbReproAttestationAuthorityFreezeCli(
                r6AttestationWriterArgs(prepared[1], prepared[2], output))
            @Expect(result.diagnostic,
                "attestation_authority_composition_manifest_invalid")
            @Expect(exists(Path(output)), false)
        } finally { r6AttestationCleanup(sandbox) }
    }

    @TestCase
    public func r6AttestationNegMismatchedAuthorityIsNotAttached(): Unit {
        let sandbox = r6AttestationSandbox()
        try {
            let prepared = r6AttestationPrepare(sandbox)
            let output = Path(sandbox).join("authority").toString()
            @Expect(runCkbReproAttestationAuthorityFreezeCli(
                r6AttestationWriterArgs(prepared[1], prepared[2], output)).ok,
                true)
            let plan = Path(output).join("environment-plan.json").toString()
            let authority = Path(output).join(
                "environment-attestation-authority.json").toString()
            File.writeTo(Path(authority), "{}".toArray())
            let result = runCkbReproCompositionSealCliWithProbe(
                r6AttestationFinalizeArgs(prepared[0], plan, authority),
                R6AttestationProbe())
            @Expect(result.diagnostic, "composition_environment_attach_invalid")
            @Expect(exists(Path(prepared[0]).join(
                "reproducibility/manifests/environment-plan.json")), false)
            @Expect(exists(Path(prepared[0]).join(
                "reproducibility/manifests/environment-lock.json")), false)
        } finally { r6AttestationCleanup(sandbox) }
    }

    @TestCase
    public func r6AttestationRecPlanAttachFailureRetriesExactly(): Unit {
        let sandbox = r6AttestationSandbox()
        try {
            let prepared = r6AttestationPrepare(sandbox)
            let output = Path(sandbox).join("authority").toString()
            @Expect(runCkbReproAttestationAuthorityFreezeCli(
                r6AttestationWriterArgs(prepared[1], prepared[2], output)).ok,
                true)
            let plan = Path(output).join("environment-plan.json").toString()
            let authority = Path(output).join(
                "environment-attestation-authority.json").toString()
            let args = r6AttestationFinalizeArgs(prepared[0], plan, authority)
            let first = runCkbReproCompositionSealCliWithProbeAndHook(args,
                R6AttestationProbe(), R6AttestationPlanAttachFailureHook())
            @Expect(first.ok, false)
            let manifests = Path(prepared[0]).join("reproducibility/manifests")
            let attachedAuthority = manifests.join(
                "environment-attestation-authority.json")
            let attachedPlan = manifests.join("environment-plan.json")
            let environment = manifests.join("environment-lock.json")
            @Expect(ckbReproReadSingleFileNoFollow(
                attachedAuthority.toString(), 64 * 1024)[1],
                ckbReproReadSingleFileNoFollow(authority, 64 * 1024)[1])
            @Expect(exists(attachedPlan), false)
            @Expect(exists(environment), false)
            @Expect(loadCkbReproCliComposition(prepared[2],
                "p3-vector-build").ok, false)
            let retry = runCkbReproCompositionSealCliWithProbe(args,
                R6AttestationProbe())
            @Expect(retry.ok, true)
            @Expect(ckbReproReadSingleFileNoFollow(
                attachedAuthority.toString(), 64 * 1024)[1],
                ckbReproReadSingleFileNoFollow(authority, 64 * 1024)[1])
            @Expect(ckbReproReadSingleFileNoFollow(
                attachedPlan.toString(), 128 * 1024)[1],
                ckbReproReadSingleFileNoFollow(plan, 128 * 1024)[1])
            @Expect(validateCkbReproEnvironmentLock(
                parseCkbReproEnvironmentLock(
                    ckbReproReadSingleFileNoFollow(environment.toString(),
                        128 * 1024)[1])[1], mode: "execution").ok, true)
        } finally { r6AttestationCleanup(sandbox) }
    }

    @TestCase
    public func r6AttestationNegMalformedAndBinaryPlansFailClosed(): Unit {
        let sandbox = r6AttestationSandbox()
        try {
            let prepared = r6AttestationPrepare(sandbox)
            let malformed = Path(sandbox).join("malformed.json")
            let binary = Path(sandbox).join("binary.json")
            File.writeTo(malformed, "{\"identityStatus\":\"planned\"".toArray())
            File.writeTo(binary, [UInt8(0xff), UInt8(0xfe)])
            for (entry in [(malformed, "malformed"), (binary, "binary")]) {
                let output = Path(sandbox).join("authority").toString()
                let result = runCkbReproAttestationAuthorityFreezeCli(
                    r6AttestationWriterArgs(entry[0].toString(),
                        prepared[2], output))
                @Expect(result.diagnostic,
                    "attestation_authority_environment_plan_invalid")
                @Expect(exists(Path(output)), false)
            }
        } finally { r6AttestationCleanup(sandbox) }
    }

    @TestCase
    public func r6AttestationBndExistingSymlinkAndFingerprintFailBeforeWrite(): Unit {
        let sandbox = r6AttestationSandbox()
        try {
            let prepared = r6AttestationPrepare(sandbox)
            let existing = Path(sandbox).join("existing")
            let real = Path(sandbox).join("real-parent")
            let linked = Path(sandbox).join("linked-parent")
            Directory.create(existing); Directory.create(real)
            @Expect(parseCkbReproAttestationAuthorityFreezeOptions(
                r6AttestationWriterArgs(prepared[1], prepared[2],
                    existing.toString())).diagnostic,
                "attestation_authority_output_root_invalid")
            @Expect(launch("/bin/ln", ["-s", real.toString(),
                linked.toString()]).wait(), 0)
            @Expect(parseCkbReproAttestationAuthorityFreezeOptions(
                r6AttestationWriterArgs(prepared[1], prepared[2],
                    linked.join("output").toString())).diagnostic,
                "attestation_authority_output_root_invalid")
            let invalid = r6AttestationWriterArgs(prepared[1], prepared[2],
                Path(sandbox).join("authority").toString())
            invalid[6] = "0123456789abcdef0123456789abcdef01234567"
            @Expect(parseCkbReproAttestationAuthorityFreezeOptions(invalid)
                .diagnostic, "attestation_authority_fingerprint_invalid")
        } finally { r6AttestationCleanup(sandbox) }
    }

    @TestCase
    public func r6AttestationBndCleanupDoesNotFollowExternalSymlink(): Unit {
        let sandbox = r6AttestationSandbox()
        let outside = r6AttestationSandbox()
        try {
            let sentinel = Path(outside).join("sentinel.txt")
            File.writeTo(sentinel, "keep🙂".toArray())
            let linked = Path(sandbox).join("linked-parent")
            @Expect(launch("/bin/ln", ["-s", outside,
                linked.toString()]).wait(), 0)
            remove(linked, recursive: false)
            @Expect(String.fromUtf8(File.readFrom(sentinel)), "keep🙂")
        } finally {
            r6AttestationCleanup(sandbox)
            r6AttestationOwnedRemove(outside, ["sentinel.txt"])
        }
    }
}
