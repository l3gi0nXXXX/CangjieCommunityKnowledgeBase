package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, FileInfo, Path, canonicalize, exists, remove,
    rename}
import std.process.launch
import std.sync.Mutex
import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*

private class R6O1aSealProbe <: CkbReproEnvironmentProbe {
    public var calls: Int64 = 0
    public var evidenceRepositoryRoot: String = ""
    public func inspect(attested: CkbReproEnvironmentLock,
        attestedInputHash: String, evidenceRepositoryRoot: String):
        CkbReproEnvironmentProbeResult {
        this.calls += 1
        this.evidenceRepositoryRoot = evidenceRepositoryRoot
        let out = CkbReproEnvironmentProbeResult()
        out.ok = true; out.diagnostic = "ok"
        out.observed = attested
        out.attestedInputHash = attestedInputHash
        out.attestationEvidenceCommit = attested.runCandidateCommit
        out
    }
}

private class R6O1aFailingSealProbe <: CkbReproEnvironmentProbe {
    public func inspect(attested: CkbReproEnvironmentLock,
        attestedInputHash: String, evidenceRepositoryRoot: String):
        CkbReproEnvironmentProbeResult {
        let out = CkbReproEnvironmentProbeResult()
        out.diagnostic = "injected_probe_failure"
        out
    }
}

private class R6O1aSealCommitHook <: CkbReproCompositionSealCommitHook {
    public let crash: Bool
    public var loaderBlockedBeforePublication: Bool = false
    public init(crash: Bool) { this.crash = crash }
    public func beforeCompositionCommit(): Unit {}
    public func afterTempAcquired(path: String, kind: String): Unit {}
    public func afterTargetPublished(path: String, kind: String): Unit {}
    public func forceParentFsyncFailure(kind: String): Bool { false }
    public func forceInitialTempIdentityFailure(kind: String): Bool { false }
    public func afterCompositionCommitted(compositionPath: String,
        expectedMode: String): Bool {
        this.loaderBlockedBeforePublication =
            !loadCkbReproCliComposition(compositionPath, expectedMode).ok
        this.crash
    }
}

private class R6O1aTwoWriterBarrierHook <:
    CkbReproCompositionSealCommitHook {
    private let mutex = Mutex()
    private var arrivals: Int64 = 0
    public func afterTempAcquired(path: String, kind: String): Unit {}
    public func afterTargetPublished(path: String, kind: String): Unit {}
    public func forceParentFsyncFailure(kind: String): Bool { false }
    public func forceInitialTempIdentityFailure(kind: String): Bool { false }
    public func beforeCompositionCommit(): Unit {
        this.mutex.lock(); this.arrivals += 1; this.mutex.unlock()
        var released = false
        for (_ in 0..5000) {
            this.mutex.lock()
            released = this.arrivals >= 2
            this.mutex.unlock()
            if (released) { return }
            sleep(Duration.millisecond)
        }
        throw Exception("two_writer_barrier_timeout")
    }
    public func afterCompositionCommitted(compositionPath: String,
        expectedMode: String): Bool { false }
    public func count(): Int64 {
        this.mutex.lock(); let value = this.arrivals; this.mutex.unlock()
        value
    }
}

private class R6O1aAdoptionBarrierHook <:
    CkbReproCompositionSealCommitHook {
    private let mutex = Mutex()
    private var committed: Bool = false
    private var adopted: Bool = false
    public func beforeCompositionCommit(): Unit {}
    public func afterTempAcquired(path: String, kind: String): Unit {}
    public func afterTargetPublished(path: String, kind: String): Unit {}
    public func forceParentFsyncFailure(kind: String): Bool { false }
    public func forceInitialTempIdentityFailure(kind: String): Bool { false }
    public func afterCompositionCommitted(compositionPath: String,
        expectedMode: String): Bool {
        this.mutex.lock(); this.committed = true; this.mutex.unlock()
        for (_ in 0..5000) {
            this.mutex.lock(); let released = this.adopted
            this.mutex.unlock()
            if (released) { return false }
            sleep(Duration.millisecond)
        }
        throw Exception("adoption_barrier_timeout")
    }
    public func waitForComposition(): Bool {
        for (_ in 0..5000) {
            this.mutex.lock(); let ready = this.committed
            this.mutex.unlock()
            if (ready) { return true }
            sleep(Duration.millisecond)
        }
        false
    }
    public func releaseAfterAdoption(): Unit {
        this.mutex.lock(); this.adopted = true; this.mutex.unlock()
    }
}

private class R6O1aSwapTempHook <: CkbReproCompositionSealCommitHook {
    private let outside: String
    private let symlink: Bool
    public var replacedPath: String = ""
    public init(outside: String, symlink!: Bool = true) {
        this.outside = outside; this.symlink = symlink
    }
    public func beforeCompositionCommit(): Unit {}
    public func forceParentFsyncFailure(kind: String): Bool { false }
    public func forceInitialTempIdentityFailure(kind: String): Bool { false }
    public func afterTempAcquired(path: String, kind: String): Unit {
        if (kind != "manifest") { return }
        this.replacedPath = path
        remove(Path(path))
        if (this.symlink) {
            if (launch("/bin/ln", ["-s", this.outside, path]).wait() != 0) {
                throw Exception("temp_swap_failed")
            }
        } else {
            File.writeTo(Path(path), "replacement-must-survive".toArray())
        }
    }
    public func afterTargetPublished(path: String, kind: String): Unit {}
    public func afterCompositionCommitted(compositionPath: String,
        expectedMode: String): Bool { false }
}

private class R6O1aFsyncFailureHook <:
    CkbReproCompositionSealCommitHook {
    private let failedKind: String
    public init(failedKind: String) { this.failedKind = failedKind }
    public func beforeCompositionCommit(): Unit {}
    public func afterTempAcquired(path: String, kind: String): Unit {}
    public func afterTargetPublished(path: String, kind: String): Unit {}
    public func forceParentFsyncFailure(kind: String): Bool {
        kind == this.failedKind
    }
    public func forceInitialTempIdentityFailure(kind: String): Bool { false }
    public func afterCompositionCommitted(compositionPath: String,
        expectedMode: String): Bool { false }
}

private class R6O1aParentSwapHook <:
    CkbReproCompositionSealCommitHook {
    private let afterPublish: Bool
    private var swapped: Bool = false
    public init(afterPublish: Bool) { this.afterPublish = afterPublish }
    public func beforeCompositionCommit(): Unit {}
    public func forceParentFsyncFailure(kind: String): Bool { false }
    public func forceInitialTempIdentityFailure(kind: String): Bool { false }
    public func afterTempAcquired(path: String, kind: String): Unit {
        if (!this.afterPublish && kind == "manifest") { this.swap(path) }
    }
    public func afterTargetPublished(path: String, kind: String): Unit {
        if (this.afterPublish && kind == "manifest") { this.swap(path) }
    }
    public func afterCompositionCommitted(compositionPath: String,
        expectedMode: String): Bool { false }
    private func swap(path: String): Unit {
        if (this.swapped) { return }
        let parent = Path(path).parent
        let detached = parent.parent.join("manifests-detached")
        rename(parent.toString(), to: detached.toString(), overwrite: false)
        Directory.create(parent)
        this.swapped = true
    }
}

private class R6O1aGrandparentSwapHook <:
    CkbReproCompositionSealCommitHook {
    public func beforeCompositionCommit(): Unit {}
    public func forceParentFsyncFailure(kind: String): Bool { false }
    public func forceInitialTempIdentityFailure(kind: String): Bool { false }
    public func afterTempAcquired(path: String, kind: String): Unit {
        if (kind != "manifest") { return }
        let grandparent = Path(path).parent.parent
        let detached = grandparent.parent.join("reproducibility-detached")
        rename(grandparent.toString(), to: detached.toString(), overwrite: false)
        Directory.create(grandparent.join("manifests"), recursive: true)
    }
    public func afterTargetPublished(path: String, kind: String): Unit {}
    public func afterCompositionCommitted(compositionPath: String,
        expectedMode: String): Bool { false }
}

private class R6O1aHardlinkTempHook <:
    CkbReproCompositionSealCommitHook {
    public let outside: String
    public init(outside: String) { this.outside = outside }
    public func beforeCompositionCommit(): Unit {}
    public func forceParentFsyncFailure(kind: String): Bool { false }
    public func forceInitialTempIdentityFailure(kind: String): Bool { false }
    public func afterTempAcquired(path: String, kind: String): Unit {
        if (kind == "manifest" &&
            launch("/bin/ln", [path, this.outside]).wait() != 0) {
            throw Exception("temp_hardlink_failed")
        }
    }
    public func afterTargetPublished(path: String, kind: String): Unit {}
    public func afterCompositionCommitted(compositionPath: String,
        expectedMode: String): Bool { false }
}

private class R6O1aInitialIdentityFailureHook <:
    CkbReproCompositionSealCommitHook {
    public func beforeCompositionCommit(): Unit {}
    public func forceParentFsyncFailure(kind: String): Bool { false }
    public func forceInitialTempIdentityFailure(kind: String): Bool {
        kind == "manifest"
    }
    public func afterTempAcquired(path: String, kind: String): Unit {}
    public func afterTargetPublished(path: String, kind: String): Unit {}
    public func afterCompositionCommitted(compositionPath: String,
        expectedMode: String): Bool { false }
}

private func cliCompositionHash(value: String): String {
    ckbReproBundleHash(value.toArray())
}

private func cliCompositionReadUtf8(path: Path): String {
    let bytes = File.readFrom(path)
    try { String.fromUtf8(bytes) } catch (_: Exception) {
        throw Exception("fixture_invalid_response_encoding")
    }
}

private func cliCompositionRoles(mode: String): Array<String> {
    if (mode == "p3-vector-build") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context"]
    }
    if (mode == "p3-snapshot-create") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context"]
    }
    if (mode == "p3-snapshot-restore" || mode == "p3-snapshot-verify") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context", "qdrant_manifest"]
    }
    if (mode == "p3-parity") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context", "mcp_stdio_command"]
    }
    if (mode == "p3-parity-build") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context", "mcp_stdio_command",
            "logical_manifest"]
    }
    if (mode == "p4-build") {
        return ["public_build_input_manifest", "private_build_authority",
            "path_policy", "local_root_map", "api_routes", "path_context",
            "eval_support",
            "leakage_authority", "runtime_config"]
    }
    if (mode == "p4-promote") {
        return ["runtime_config", "path_policy", "local_root_map",
            "api_routes", "path_context"]
    }
    if (mode == "run-certify") {
        return ["logical_manifest", "qdrant_manifest", "parity_manifest",
            "build_proof",
            "path_policy", "local_root_map", "api_routes",
            "public_build_input_manifest", "private_build_authority",
            "path_context", "eval_support", "leakage_authority",
            "runtime_transport", "mcp_stdio_command", "runner_inputs",
            "runner_authority", "reference_template", "authority_manifest",
            "run_critical_manifest"]
    }
    ["logical_manifest", "qdrant_manifest", "parity_manifest",
        "build_proof",
        "path_policy", "local_root_map", "api_routes",
        "public_build_input_manifest", "private_build_authority",
        "path_context", "eval_support", "leakage_authority",
        "runtime_transport", "mcp_stdio_command", "reference_template",
        "run_critical_manifest", "release_inputs_manifest"]
}

private func cliCompositionPrivateAuthority(): String {
    "{\"schemaVersion\":\"ckb-repro-private-cli-authority-v1\"," +
        "\"localRootMap\":\"private-authority/local-roots.json\"," +
        "\"pathContext\":\"private-authority/path-context.json\"," +
        "\"evalSupport\":\"private-authority/eval-support.json\"," +
        "\"leakageAuthority\":\"private-authority/leakage.json\"}"
}

private func cliCompositionBuildManifest(): String {
    let manifest = CkbReproBuildInputManifest()
    manifest.schemaVersion = "ckb-repro-build-inputs-v1"
    manifest.candidateVersion = "候选🙂-v1"
    manifest.targetVersion = "public-v1"
    manifest.expectedRawCount = 7978
    for (role in ckbReproPublicBuildInputRoles()) {
        let asset = CkbReproBuildInputAsset()
        asset.role = role; asset.relativePath = "build-inputs/${role}.json"
        asset.size = 1; asset.sha256 = cliCompositionHash(role)
        manifest.assets.add(asset)
    }
    renderCkbReproBuildInputManifest(manifest)
}

private func cliCompositionPath(role: String): String {
    if (role == "public_build_input_manifest") {
        return "assets/public-build-input-manifest.json"
    }
    if (role == "private_build_authority") {
        return "private-authority/build-authority.json"
    }
    if (role == "runner_authority") {
        return "private-authority/runner-authority.json"
    }
    if (role == "local_root_map") {
        return "private-authority/local-roots.json"
    }
    if (role == "path_context") {
        return "private-authority/path-context.json"
    }
    if (role == "eval_support") {
        return "private-authority/eval-support.json"
    }
    if (role == "leakage_authority") {
        return "private-authority/leakage.json"
    }
    "assets/${role}.json"
}

private func cliCompositionContent(role: String): String {
    if (role == "private_build_authority") {
        return cliCompositionPrivateAuthority()
    }
    if (role == "runner_authority") {
        return "{\"schemaVersion\":\"ckb-repro-runner-authority-v1\"," +
            "\"credentialEnvironmentVariables\":[\"ANTHROPIC_AUTH_TOKEN\"]}"
    }
    if (role == "public_build_input_manifest") {
        return cliCompositionBuildManifest()
    }
    "资料🙂:${role}"
}

private func cliCompositionManifest(mode: String): CkbReproCliCompositionManifest {
    let manifest = CkbReproCliCompositionManifest()
    manifest.schemaVersion = "ckb-repro-cli-composition-v1"
    manifest.mode = mode
    for (role in cliCompositionRoles(mode)) {
        let content = cliCompositionContent(role)
        let asset = CkbReproCliCompositionAsset()
        asset.role = role; asset.relativePath = cliCompositionPath(role)
        asset.size = content.toArray().size
        asset.sha256 = cliCompositionHash(content)
        manifest.assets.add(asset)
    }
    manifest
}

private func cliCompositionRoot(mode: String,
    validAuthority!: Bool = true): String {
    let suffix = DateTime.now().toUnixTimeStamp().toString() +
        "-${mode.hashCode()}-${validAuthority.hashCode()}"
    let path = Path("/tmp/ckb-cli-composition-${suffix}")
    if (exists(path)) { remove(path, recursive: true) }
    Directory.create(path)
    let root = canonicalize(path).toString()
    let composition = cliCompositionManifest(mode)
    for (row in composition.assets) {
        cliCompositionWriteFile(root, row.relativePath,
            cliCompositionContent(row.role))
    }
    let compositionText = renderCkbReproCliCompositionManifest(composition)
    cliCompositionWriteFile(root,
        "reproducibility/manifests/runtime-composition.json", compositionText)
    let current = cliCompositionReadUtf8(Path(
        "../reproducibility/manifests/environment-lock.json"))
    let hash = if (validAuthority) { cliCompositionHash(compositionText) }
        else { cliCompositionHash("wrong") }
    cliCompositionWriteFile(root,
        "reproducibility/manifests/environment-lock.json",
        current.replace("\"compositionManifestHash\": \"\"",
            "\"compositionManifestHash\": \"${hash}\""))
    root
}

private func cliCompositionWriteFile(root: String, relativePath: String,
    content: String): Unit {
    let target = Path(root).join(relativePath)
    if (!exists(target.parent)) { Directory.create(target.parent, recursive: true) }
    File.writeTo(target, content.toArray())
}

private func r6O1aSealFixture(suffix: String): (String, Array<String>) {
    let stamp = DateTime.now().toUnixTimeStamp()
    let path = Path("/tmp/r6-o1a-composition-${suffix}-${stamp}")
    if (exists(path)) { remove(path, recursive: true) }
    Directory.create(path)
    let root = canonicalize(path).toString()
    let mode = "p3-vector-build"
    let expectedManifest = cliCompositionManifest(mode)
    for (asset in expectedManifest.assets) {
        cliCompositionWriteFile(root, asset.relativePath,
            cliCompositionContent(asset.role))
    }
    let manifestHash = cliCompositionHash(
        renderCkbReproCliCompositionManifest(expectedManifest))
    let planned = parseCkbReproEnvironmentLock(File.readFrom(Path(
        "../reproducibility/manifests/environment-lock.json")))[1]
    planned.identityStatus = "planned"
    planned.cangjieSdkVersion = "1.0.0"
    planned.cangjieSdkHash = cliCompositionHash("sdk")
    planned.opensslVersion = "OpenSSL 3"
    planned.qdrantImageDigest = cliCompositionHash("qdrant")
    planned.runCandidateCommit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    planned.claudeCodeVersion = "1.0.0"
    planned.archiveTool = "tar+zstd"
    planned.archiveToolVersion = "tar 1|zstd 1"
    planned.authorityDeliveryHash = cliCompositionHash("delivery")
    planned.compositionManifestHash = ""
    planned.attestationAuthorityHash = ""
    let expected = parseCkbReproEnvironmentLock(
        renderCkbReproEnvironmentLock(planned).toArray())[1]
    expected.identityStatus = "frozen"
    expected.compositionManifestHash = manifestHash
    let projection = ckbReproObservedEnvironmentProjectionHash(expected)
    let source = "release://ckb/environment-attestation-authority-v1"
    let authority =
        "{\"schemaVersion\":\"ckb-repro-environment-attestation-authority-v1\"," +
        "\"status\":\"frozen\",\"signingFingerprint\":" +
        "\"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\"," +
        "\"observedEnvironmentProjectionHash\":\"${projection}\"," +
        "\"authoritySource\":\"${source}\",\"authoritySourceHash\":" +
        "\"${cliCompositionHash(source)}\"}"
    planned.attestationAuthorityHash = cliCompositionHash(authority)
    cliCompositionWriteFile(root,
        "reproducibility/manifests/environment-plan.json",
        renderCkbReproEnvironmentLock(planned))
    cliCompositionWriteFile(root,
        "reproducibility/manifests/environment-attestation-authority.json",
        authority)
    let args = ArrayList<String>()
    args.add("ckb-repro-composition-seal")
    args.add("--root"); args.add(root)
    args.add("--mode"); args.add(mode)
    for (role in cliCompositionRoles(mode)) {
        args.add("--asset")
        args.add("${role}=${cliCompositionPath(role)}")
    }
    (root, args.toArray())
}

@Test
public class CkbReproCliCompositionTest {
    @TestCase
    public func r6O1aPos01SealWritesAtomicPairAndLoaderReadsBack(): Unit {
        let fixture = r6O1aSealFixture("positive")
        let probe = R6O1aSealProbe()
        try {
            let result = runCkbReproCompositionSealCliWithProbe(
                fixture[1], probe)
            @Expect(result.ok, true)
            @Expect(result.output.contains("\"ok\""), false)
            @Expect(probe.calls, 1)
            let compositionPath = Path(fixture[0]).join(
                "reproducibility/manifests/runtime-composition.json")
            let environmentPath = Path(fixture[0]).join(
                "reproducibility/manifests/environment-lock.json")
            @Expect(exists(compositionPath), true)
            @Expect(exists(environmentPath), true)
            let loaded = loadCkbReproCliComposition(
                compositionPath.toString(), "p3-vector-build")
            @Expect(loaded.ok, true)
            @Expect(loaded.manifest.assets.size, 5)
            @Expect(loaded.authorityEnvironmentLock.identityStatus, "frozen")
            @Expect(loaded.authorityEnvironmentLock.compositionManifestHash,
                cliCompositionHash(cliCompositionReadUtf8(compositionPath)))
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
        }
    }

    @TestCase
    public func r6O1aPos02SealUsesExplicitEvidenceRepositoryRoot(): Unit {
        let fixture = r6O1aSealFixture("explicit-evidence-root")
        let probe = R6O1aSealProbe()
        let evidenceRoot = canonicalize(Path(fixture[0]).parent).toString()
        try {
            let result = runCkbReproCompositionSealCliWithProbeAndEvidenceRoot(
                fixture[1], probe, evidenceRoot)
            @Expect(result.ok, true)
            @Expect(probe.calls, 1)
            @Expect(probe.evidenceRepositoryRoot, evidenceRoot)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
        }
    }

    @TestCase
    public func r6O1aBnd01SymlinkAndExistingTargetLeaveNoPartialPair(): Unit {
        let fixture = r6O1aSealFixture("boundary")
        try {
            let asset = Path(fixture[0]).join("assets/runtime_config.json")
            let outside = Path(fixture[0]).parent.join("outside-资料🙂.json")
            File.writeTo(outside, "outside".toArray())
            remove(asset)
            @Expect(launch("/bin/ln", ["-s", outside.toString(),
                asset.toString()]).wait(), 0)
            let blocked = runCkbReproCompositionSealCliWithProbe(
                fixture[1], R6O1aSealProbe())
            @Expect(blocked.ok, false)
            @Expect(exists(Path(fixture[0]).join(
                "reproducibility/manifests/runtime-composition.json")), false)
            @Expect(exists(Path(fixture[0]).join(
                "reproducibility/manifests/environment-lock.json")), false)
            remove(asset); File.writeTo(asset,
                cliCompositionContent("runtime_config").toArray())
            let existing = Path(fixture[0]).join(
                "reproducibility/manifests/runtime-composition.json")
            File.writeTo(existing, "sentinel".toArray())
            @Expect(runCkbReproCompositionSealCliWithProbe(
                fixture[1], R6O1aSealProbe()).diagnostic,
                "composition_recovery_bytes_mismatch")
            @Expect(cliCompositionReadUtf8(existing), "sentinel")
            @Expect(exists(Path(fixture[0]).join(
                "reproducibility/manifests/environment-lock.json")), false)
            remove(outside)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
        }
    }

    @TestCase
    public func r6O1aRec01CrashArtifactIsBlockedThenRecoveredExactly(): Unit {
        let fixture = r6O1aSealFixture("crash-recovery")
        let crash = R6O1aSealCommitHook(true)
        try {
            let first = runCkbReproCompositionSealCliWithProbeAndHook(
                fixture[1], R6O1aSealProbe(), crash)
            @Expect(first.diagnostic, "composition_simulated_crash")
            @Expect(crash.loaderBlockedBeforePublication, true)
            let compositionPath = Path(fixture[0]).join(
                "reproducibility/manifests/runtime-composition.json")
            let environmentPath = Path(fixture[0]).join(
                "reproducibility/manifests/environment-lock.json")
            @Expect(exists(compositionPath), true)
            @Expect(exists(environmentPath), false)
            @Expect(cliCompositionReadUtf8(compositionPath),
                renderCkbReproCliCompositionManifest(
                    cliCompositionManifest("p3-vector-build")))
            let recovered = runCkbReproCompositionSealCliWithProbe(
                fixture[1], R6O1aSealProbe())
            @Expect(recovered.diagnostic, "ok")
            @Expect(recovered.ok, true)
            @Expect(loadCkbReproCliComposition(compositionPath.toString(),
                "p3-vector-build").ok, true)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
        }
    }

    @TestCase
    public func r6O1aRec02OrdinaryFailureKeepsExactRecoverableAnchor(): Unit {
        let fixture = r6O1aSealFixture("ordinary-cleanup")
        try {
            let result = runCkbReproCompositionSealCliWithProbe(
                fixture[1], R6O1aFailingSealProbe())
            @Expect(result.diagnostic, "injected_probe_failure")
            let compositionPath = Path(fixture[0]).join(
                "reproducibility/manifests/runtime-composition.json")
            let environmentPath = Path(fixture[0]).join(
                "reproducibility/manifests/environment-lock.json")
            @Expect(exists(compositionPath), true)
            @Expect(exists(environmentPath), false)
            let secured = ckbReproReadSingleFileNoFollow(
                compositionPath.toString(), 64 * 1024)
            @Expect(FileInfo(compositionPath).isRegular(), true)
            @Expect(FileInfo(compositionPath).isDirectory(), false)
            @Expect(FileInfo(compositionPath).isSymbolicLink(), false)
            let expectedComposition = renderCkbReproCliCompositionManifest(
                cliCompositionManifest("p3-vector-build"))
            @Expect(secured[0], true)
            @Expect(cliCompositionHash(try { String.fromUtf8(secured[1]) }
                catch (_: Exception) { "invalid" }),
                cliCompositionHash(expectedComposition))
            @Expect(cliCompositionReadUtf8(compositionPath),
                expectedComposition)
            @Expect(loadCkbReproCliComposition(compositionPath.toString(),
                "p3-vector-build").ok, false)
            var tempCount: Int64 = 0
            for (entry in Directory.readFrom(compositionPath.parent)) {
                if (entry.name.contains(".tmp-manifest-")) { tempCount += 1 }
            }
            @Expect(tempCount, 0)
            let recovered = runCkbReproCompositionSealCliWithProbe(
                fixture[1], R6O1aSealProbe())
            @Expect(recovered.diagnostic, "ok")
            @Expect(recovered.ok, true)
            @Expect(loadCkbReproCliComposition(compositionPath.toString(),
                "p3-vector-build").ok, true)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
        }
    }

    @TestCase
    public func r6O1aCon03AdopterPublicationSurvivesOwnerProbeFailure(): Unit {
        let fixture = r6O1aSealFixture("adopter-publication")
        let hook = R6O1aAdoptionBarrierHook()
        try {
            let owner = spawn { =>
                runCkbReproCompositionSealCliWithProbeAndHook(
                    fixture[1], R6O1aFailingSealProbe(), hook)
            }
            @Expect(hook.waitForComposition(), true)
            let adopter = runCkbReproCompositionSealCliWithProbe(
                fixture[1], R6O1aSealProbe())
            hook.releaseAfterAdoption()
            let failedOwner = owner.get()
            @Expect(adopter.ok, true)
            @Expect(adopter.diagnostic, "ok")
            @Expect(failedOwner.diagnostic, "injected_probe_failure")
            let compositionPath = Path(fixture[0]).join(
                "reproducibility/manifests/runtime-composition.json")
            let environmentPath = Path(fixture[0]).join(
                "reproducibility/manifests/environment-lock.json")
            @Expect(exists(compositionPath), true)
            @Expect(exists(environmentPath), true)
            @Expect(loadCkbReproCliComposition(compositionPath.toString(),
                "p3-vector-build").ok, true)
        } finally {
            hook.releaseAfterAdoption()
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
        }
    }

    @TestCase
    public func r6O1aCon01LoaderCannotSeePartialPairBeforeEnvCommit(): Unit {
        let fixture = r6O1aSealFixture("visibility")
        let hook = R6O1aSealCommitHook(false)
        try {
            let result = runCkbReproCompositionSealCliWithProbeAndHook(
                fixture[1], R6O1aSealProbe(), hook)
            @Expect(result.ok, true)
            @Expect(hook.loaderBlockedBeforePublication, true)
            @Expect(loadCkbReproCliComposition(Path(fixture[0]).join(
                "reproducibility/manifests/runtime-composition.json")
                .toString(), "p3-vector-build").ok, true)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
        }
    }

    @TestCase
    public func r6O1aCon02TwoWritersOwnDistinctTempsAndOnePublishes(): Unit {
        let fixture = r6O1aSealFixture("two-writers")
        let hook = R6O1aTwoWriterBarrierHook()
        try {
            let first = spawn { =>
                runCkbReproCompositionSealCliWithProbeAndHook(
                    fixture[1], R6O1aSealProbe(), hook)
            }
            let second = spawn { =>
                runCkbReproCompositionSealCliWithProbeAndHook(
                    fixture[1], R6O1aSealProbe(), hook)
            }
            let a = first.get(); let b = second.get()
            @Expect(hook.count(), 2)
            @Expect((a.ok && !b.ok) || (!a.ok && b.ok), true)
            @Expect(if (a.ok) { b.diagnostic } else { a.diagnostic },
                "composition_commit_failed")
            @Expect(loadCkbReproCliComposition(Path(fixture[0]).join(
                "reproducibility/manifests/runtime-composition.json")
                .toString(), "p3-vector-build").ok, true)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
        }
    }

    @TestCase
    public func r6O1aNeg02TempSymlinkReplacementIsNotFollowedOrDeleted(): Unit {
        let fixture = r6O1aSealFixture("temp-symlink-replacement")
        let outside = Path(fixture[0]).parent.join(
            "ckb-composition-temp-outside")
        if (exists(outside)) { remove(outside, recursive: true) }
        Directory.create(outside)
        let marker = outside.join("marker")
        File.writeTo(marker, "must-survive".toArray())
        try {
            let result = runCkbReproCompositionSealCliWithProbeAndHook(
                fixture[1], R6O1aSealProbe(),
                R6O1aSwapTempHook(outside.toString()))
            @Expect(result.ok, false)
            @Expect(result.diagnostic, "composition_readback_failed")
            @Expect(cliCompositionReadUtf8(marker), "must-survive")
            @Expect(exists(Path(fixture[0]).join(
                "reproducibility/manifests/runtime-composition.json")), false)
            @Expect(exists(Path(fixture[0]).join(
                "reproducibility/manifests/environment-lock.json")), false)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
            if (exists(outside)) { remove(outside, recursive: true) }
        }
    }

    @TestCase
    public func r6O1aBnd02PreoccupiedTempNamesAreSkippedWithoutMutation(): Unit {
        let fixture = r6O1aSealFixture("preoccupied-temp")
        let manifest = cliCompositionManifest("p3-vector-build")
        let token = cliCompositionHash(
            renderCkbReproCliCompositionManifest(manifest))
            .replace("sha256:", "")
        let manifestRoot = Path(fixture[0]).join(
            "reproducibility/manifests")
        let first = manifestRoot.join(
            "runtime-composition.json.tmp-manifest-${token}-0")
        let second = manifestRoot.join(
            "runtime-composition.json.tmp-manifest-${token}-1")
        let outside = Path(fixture[0]).parent.join(
            "ckb-composition-preoccupied-outside")
        if (exists(outside)) { remove(outside, recursive: true) }
        Directory.create(outside)
        let sentinel = outside.join("sentinel")
        File.writeTo(sentinel, "outside-must-survive".toArray())
        try {
            @Expect(launch("/bin/ln", ["-s", outside.toString(),
                first.toString()]).wait(), 0)
            File.writeTo(second, "occupied-must-survive".toArray())
            let result = runCkbReproCompositionSealCliWithProbe(
                fixture[1], R6O1aSealProbe())
            @Expect(result.ok, true)
            @Expect(FileInfo(first).isSymbolicLink(), true)
            @Expect(cliCompositionReadUtf8(second), "occupied-must-survive")
            @Expect(cliCompositionReadUtf8(sentinel), "outside-must-survive")
            var retainedTemps: Int64 = 0
            for (entry in Directory.readFrom(manifestRoot)) {
                if (entry.name.contains(".tmp-manifest-")) {
                    retainedTemps += 1
                }
            }
            @Expect(retainedTemps, 2)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
            if (exists(outside)) { remove(outside, recursive: true) }
        }
    }

    @TestCase
    public func r6O1aNeg03TempRegularReplacementSurvivesCleanup(): Unit {
        let fixture = r6O1aSealFixture("temp-regular-replacement")
        let replacement = Path(fixture[0]).parent.join(
            "ckb-composition-temp-regular")
        if (exists(replacement)) { remove(replacement) }
        File.writeTo(replacement, "unused".toArray())
        let hook = R6O1aSwapTempHook(replacement.toString(), symlink: false)
        try {
            let result = runCkbReproCompositionSealCliWithProbeAndHook(
                fixture[1], R6O1aSealProbe(), hook)
            @Expect(result.ok, false)
            @Expect(result.diagnostic, "composition_readback_failed")
            @Expect(cliCompositionReadUtf8(Path(hook.replacedPath)),
                "replacement-must-survive")
            @Expect(exists(Path(fixture[0]).join(
                "reproducibility/manifests/runtime-composition.json")), false)
            @Expect(exists(Path(fixture[0]).join(
                "reproducibility/manifests/environment-lock.json")), false)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
            if (exists(replacement)) { remove(replacement) }
        }
    }

    @TestCase
    public func r6O1aNeg07HardlinkedTempFailsBeforePayloadWrite(): Unit {
        let fixture = r6O1aSealFixture("temp-hardlink")
        let outside = Path(fixture[0]).parent.join(
            "ckb-composition-temp-hardlink-outside")
        if (exists(outside)) { remove(outside) }
        try {
            let result = runCkbReproCompositionSealCliWithProbeAndHook(
                fixture[1], R6O1aSealProbe(),
                R6O1aHardlinkTempHook(outside.toString()))
            @Expect(result.ok, false)
            @Expect(result.diagnostic, "composition_readback_failed")
            @Expect(exists(outside), true)
            @Expect(File.readFrom(outside).size, 0)
            let manifestRoot = Path(fixture[0]).join(
                "reproducibility/manifests")
            var tempCount: Int64 = 0
            for (entry in Directory.readFrom(manifestRoot)) {
                if (entry.name.contains(".tmp-manifest-")) { tempCount += 1 }
            }
            @Expect(tempCount, 0)
            @Expect(exists(manifestRoot.join("runtime-composition.json")), false)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
            if (exists(outside)) { remove(outside) }
        }
    }

    @TestCase
    public func r6O1aNeg08InitialIdentityFailureRetriesForSafeCleanup(): Unit {
        let fixture = r6O1aSealFixture("identity-retry-cleanup")
        try {
            let result = runCkbReproCompositionSealCliWithProbeAndHook(
                fixture[1], R6O1aSealProbe(),
                R6O1aInitialIdentityFailureHook())
            @Expect(result.ok, false)
            @Expect(result.diagnostic,
                "composition_temporary_identity_initial_failed")
            let manifestRoot = Path(fixture[0]).join(
                "reproducibility/manifests")
            var tempCount: Int64 = 0
            for (entry in Directory.readFrom(manifestRoot)) {
                if (entry.name.contains(".tmp-manifest-")) { tempCount += 1 }
            }
            @Expect(tempCount, 0)
            @Expect(exists(manifestRoot.join("runtime-composition.json")), false)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
        }
    }

    @TestCase
    public func r6O1aNeg04PreRenameParentSwapFailsClosed(): Unit {
        let fixture = r6O1aSealFixture("pre-parent-swap")
        try {
            let result = runCkbReproCompositionSealCliWithProbeAndHook(
                fixture[1], R6O1aSealProbe(), R6O1aParentSwapHook(false))
            @Expect(result.ok, false)
            @Expect(result.diagnostic, "composition_commit_precheck_failed")
            @Expect(exists(Path(fixture[0]).join(
                "reproducibility/manifests/runtime-composition.json")), false)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
        }
    }

    @TestCase
    public func r6O1aNeg05PostRenameParentSwapNeverRollsBackAnchor(): Unit {
        let fixture = r6O1aSealFixture("post-parent-swap")
        try {
            let result = runCkbReproCompositionSealCliWithProbeAndHook(
                fixture[1], R6O1aSealProbe(), R6O1aParentSwapHook(true))
            @Expect(result.ok, false)
            @Expect(result.diagnostic,
                "composition_parent_binding_changed_after_publish")
            @Expect(exists(Path(fixture[0]).join(
                "reproducibility/manifests/runtime-composition.json")), false)
            @Expect(exists(Path(fixture[0]).join(
                "reproducibility/manifests-detached/runtime-composition.json")),
                true)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
        }
    }

    @TestCase
    public func r6O1aNeg06GrandparentPublicPathSwapFailsClosed(): Unit {
        let fixture = r6O1aSealFixture("grandparent-swap")
        try {
            let result = runCkbReproCompositionSealCliWithProbeAndHook(
                fixture[1], R6O1aSealProbe(), R6O1aGrandparentSwapHook())
            @Expect(result.ok, false)
            @Expect(result.diagnostic, "composition_commit_precheck_failed")
            @Expect(exists(Path(fixture[0]).join(
                "reproducibility/manifests/runtime-composition.json")), false)
            @Expect(exists(Path(fixture[0]).join(
                "reproducibility-detached/manifests/runtime-composition.json")),
                false)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
        }
    }

    @TestCase
    public func r6O1aRec03CompositionFsyncFailureRecoversExactly(): Unit {
        let fixture = r6O1aSealFixture("composition-fsync")
        try {
            let failed = runCkbReproCompositionSealCliWithProbeAndHook(
                fixture[1], R6O1aSealProbe(),
                R6O1aFsyncFailureHook("manifest"))
            @Expect(failed.diagnostic, "composition_parent_fsync_failed")
            let manifestRoot = Path(fixture[0]).join(
                "reproducibility/manifests")
            @Expect(exists(manifestRoot.join("runtime-composition.json")), true)
            @Expect(exists(manifestRoot.join("environment-lock.json")), false)
            @Expect(runCkbReproCompositionSealCliWithProbe(
                fixture[1], R6O1aSealProbe()).ok, true)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
        }
    }

    @TestCase
    public func r6O1aRec04EnvironmentFsyncFailureRecoversExactPair(): Unit {
        let fixture = r6O1aSealFixture("environment-fsync")
        try {
            let failed = runCkbReproCompositionSealCliWithProbeAndHook(
                fixture[1], R6O1aSealProbe(),
                R6O1aFsyncFailureHook("environment"))
            @Expect(failed.diagnostic, "composition_parent_fsync_failed")
            @Expect(runCkbReproCompositionSealCliWithProbe(
                fixture[1], R6O1aSealProbe()).ok, true)
            @Expect(loadCkbReproCliComposition(Path(fixture[0]).join(
                "reproducibility/manifests/runtime-composition.json")
                .toString(), "p3-vector-build").ok, true)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
        }
    }

    @TestCase
    public func r6O1aNeg01MissingRoleAndInvalidAuthorityPublishNoEnvironment(): Unit {
        let fixture = r6O1aSealFixture("negative")
        try {
            let missing = fixture[1][0..fixture[1].size - 2].clone()
            @Expect(parseCkbReproCompositionSealOptions(missing)
                .diagnostic, "composition_seal_options_invalid")
            let authorityPath = Path(fixture[0]).join(
                "reproducibility/manifests/environment-attestation-authority.json")
            File.writeTo(authorityPath, [0xff, 0xfe])
            @Expect(runCkbReproCompositionSealCliWithProbe(
                fixture[1], R6O1aSealProbe()).diagnostic,
                "invalid_response_encoding")
            let compositionPath = Path(fixture[0]).join(
                "reproducibility/manifests/runtime-composition.json")
            @Expect(exists(compositionPath), true)
            @Expect(exists(Path(fixture[0]).join(
                "reproducibility/manifests/environment-lock.json")), false)
            @Expect(loadCkbReproCliComposition(compositionPath.toString(),
                "p3-vector-build").ok, false)
        } finally {
            if (exists(Path(fixture[0]))) {
                remove(Path(fixture[0]), recursive: true)
            }
        }
    }

    @TestCase
    public func r6O1aUt01SealOptionsAreExplicitOrderedAndFailClosed(): Unit {
        let args = ArrayList<String>()
        args.add("ckb-repro-composition-seal")
        args.add("--root"); args.add("/tmp/组合🙂")
        args.add("--mode"); args.add("p3-vector-build")
        for (role in cliCompositionRoles("p3-vector-build")) {
            args.add("--asset")
            args.add("${role}=${cliCompositionPath(role)}")
        }
        let parsed = parseCkbReproCompositionSealOptions(args.toArray())
        @Expect(parsed.diagnostic, "ok")
        @Expect(parsed.assets.size, 5)
        @Expect(parsed.assets[0].role, "runtime_config")
        let duplicate = args.clone()
        duplicate.add("--asset")
        duplicate.add("runtime_config=assets/duplicate.json")
        @Expect(parseCkbReproCompositionSealOptions(duplicate.toArray())
            .diagnostic, "composition_seal_options_invalid")
        let traversal = args.clone()
        traversal[6] = "runtime_config=../outside.json"
        @Expect(parseCkbReproCompositionSealOptions(traversal.toArray())
            .diagnostic, "composition_asset_argument_invalid")
    }

    @TestCase
    public func parserAcceptsCanonicalUnicodeAndRejectsMalformedInputs(): Unit {
        for (mode in ["p3-vector-build", "p3-parity-build", "p4-build", "run-certify",
            "release-verify"]) {
            let manifest = cliCompositionManifest(mode)
            let parsed = parseCkbReproCliCompositionManifest(
                renderCkbReproCliCompositionManifest(manifest).toArray())
            @Expect(parsed[0].ok, true)
            @Expect(parsed[1].mode, mode)
        }
        @Expect(parseCkbReproCliCompositionManifest([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbReproCliCompositionManifest("{".toArray())[0].diagnostic,
            "malformed_json")
        let valid = renderCkbReproCliCompositionManifest(
            cliCompositionManifest("p3-vector-build"))
        @Expect(parseCkbReproCliCompositionManifest(
            valid.replace("\"assets\":", "\"unknown\":1,\"assets\":")
                .toArray())[0].diagnostic,
            "cli_composition_field_contract_invalid")
        let longText = StringBuilder()
        for (_ in 0..40000) { longText.append("中🙂") }
        @Expect(parseCkbReproCliCompositionManifest(longText.toString().toArray())[0]
            .diagnostic, "cli_composition_size_invalid")
    }

    @TestCase
    public func modeContractsRejectDuplicatesTraversalAndCrossModeAssets(): Unit {
        let duplicate = cliCompositionManifest("p3-vector-build")
        duplicate.assets[1].role = duplicate.assets[0].role
        @Expect(validateCkbReproCliCompositionManifest(duplicate).diagnostic,
            "cli_composition_asset_invalid")
        let traversal = cliCompositionManifest("p3-vector-build")
        traversal.assets[0].relativePath = "../config.json"
        @Expect(validateCkbReproCliCompositionManifest(traversal).ok, false)
        let b = cliCompositionManifest("release-verify")
        b.assets[0].role = "runner_inputs"
        @Expect(validateCkbReproCliCompositionManifest(b).diagnostic,
            "cli_composition_asset_invalid")
        let a = cliCompositionManifest("run-certify")
        a.assets.remove(at: a.assets.size - 1)
        @Expect(validateCkbReproCliCompositionManifest(a).diagnostic,
            "cli_composition_mode_contract_invalid")
        for (mode in ["run-certify", "release-verify"]) {
            let cyclic = cliCompositionManifest(mode)
            let lock = CkbReproCliCompositionAsset()
            lock.role = "environment_lock"
            lock.relativePath =
                "reproducibility/manifests/environment-lock.json"
            lock.size = 1; lock.sha256 = cliCompositionHash("lock")
            cyclic.assets.add(lock)
            @Expect(validateCkbReproCliCompositionManifest(cyclic).diagnostic,
                "cli_composition_mode_contract_invalid")
        }
        for (item in [("run-certify", "environment_preflight"),
            ("run-certify", "experiment_profile"),
            ("release-verify", "release_asset_authority")]) {
            let redundant = cliCompositionManifest(item[0])
            let asset = CkbReproCliCompositionAsset()
            asset.role = item[1]
            asset.relativePath = "assets/${item[1]}.json"
            asset.size = 1; asset.sha256 = cliCompositionHash(item[1])
            redundant.assets.add(asset)
            @Expect(validateCkbReproCliCompositionManifest(redundant)
                .diagnostic, "cli_composition_mode_contract_invalid")
        }
        let wrongBuildRoot = cliCompositionManifest("p4-build")
        for (asset in wrongBuildRoot.assets) {
            if (asset.role == "public_build_input_manifest") {
                asset.relativePath = "assets/other-build-input-manifest.json"
            }
        }
        @Expect(validateCkbReproCliCompositionManifest(wrongBuildRoot)
            .diagnostic, "cli_composition_asset_invalid")
    }

    @TestCase
    public func buildAndPrivateAuthorityParsersAreStrict(): Unit {
        let build = cliCompositionBuildManifest()
        @Expect(parseCkbReproBuildInputManifest(build.toArray())[0].ok, true)
        @Expect(parseCkbReproBuildInputManifest(
            build.replace("\"assets\":", "\"extra\":0,\"assets\":")
                .toArray())[0].ok, false)
        @Expect(parseCkbReproBuildInputManifest([0xff])[0].diagnostic,
            "invalid_response_encoding")
        let authority = cliCompositionPrivateAuthority()
        @Expect(parseCkbReproCliPrivateAuthority(
            authority.toArray(), "release-verify")[0].ok, true)
        @Expect(parseCkbReproCliPrivateAuthority(
            authority.replace("}",
                ",\"credentialEnvironmentVariables\":[\"TOKEN\"]}").toArray(),
            "release-verify")[0].diagnostic,
            "private_authority_field_contract_invalid")
        for (field in ["runner", "model", "provider"]) {
            @Expect(parseCkbReproCliPrivateAuthority(authority.replace("}",
                ",\"${field}\":\"forbidden\"}").toArray(),
                "release-verify")[0].diagnostic,
                "private_authority_field_contract_invalid")
        }
        @Expect(parseCkbReproCliPrivateAuthority(
            [0xff, 0xfe], "release-verify")[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbReproCliPrivateAuthority(
            "{".toArray(), "release-verify")[0].diagnostic,
            "malformed_json")
        let runner = "{\"schemaVersion\":\"ckb-repro-runner-authority-v1\"," +
            "\"credentialEnvironmentVariables\":[\"ANTHROPIC_AUTH_TOKEN\"]}"
        @Expect(parseCkbReproCliRunnerAuthority(
            runner.toArray(), "run-certify")[0].ok, true)
        @Expect(parseCkbReproCliRunnerAuthority(
            runner.replace("ANTHROPIC_AUTH_TOKEN", "TOKEN=secret").toArray(),
            "run-certify")[0].diagnostic,
            "credential_environment_variable_invalid")
        @Expect(parseCkbReproCliRunnerAuthority(
            runner.toArray(), "release-verify")[0].diagnostic,
            "runner_authority_mode_invalid")

        let root = cliCompositionRoot("p4-build")
        try {
            let changedAuthority = authority.replace(
                "private-authority/local-roots.json",
                "private-authority/other-roots.json")
            File.writeTo(Path(root).join(
                "private-authority/build-authority.json"),
                changedAuthority.toArray())
            let compositionPath = Path(root).join(
                "reproducibility/manifests/runtime-composition.json")
            let composition = cliCompositionReadUtf8(compositionPath)
                .replace(cliCompositionHash(authority),
                    cliCompositionHash(changedAuthority))
            File.writeTo(compositionPath, composition.toArray())
            let environmentPath = Path(root).join(
                "reproducibility/manifests/environment-lock.json")
            let environment = cliCompositionReadUtf8(environmentPath)
                .replace(cliCompositionHash(renderCkbReproCliCompositionManifest(
                    cliCompositionManifest("p4-build"))),
                    cliCompositionHash(composition))
            File.writeTo(environmentPath, environment.toArray())
            @Expect(loadCkbReproCliComposition(Path(root).join(
                "reproducibility/manifests/runtime-composition.json")
                .toString(), "p4-build").diagnostic,
                "private_authority_asset_mismatch")
        } finally { if (exists(Path(root))) { remove(Path(root), recursive: true) } }
    }

    @TestCase
    public func loaderReadsAuthorizedP3P4AndP8Modes(): Unit {
        for (mode in ["p3-vector-build", "p4-build", "run-certify",
            "release-verify"]) {
            let root = cliCompositionRoot(mode)
            try {
                let loaded = loadCkbReproCliComposition(Path(root).join(
                    "reproducibility/manifests/runtime-composition.json")
                    .toString(), mode)
                @Expect(loaded.ok, true)
                @Expect(loaded.assets.size, cliCompositionRoles(mode).size)
                var hasEnvironmentLockAsset = false
                for (asset in loaded.assets) {
                    if (asset.role == "environment_lock") {
                        hasEnvironmentLockAsset = true
                    }
                }
                @Expect(hasEnvironmentLockAsset, false)
                @Expect(loaded.authorityEnvironmentLock.compositionManifestHash,
                    cliCompositionHash(renderCkbReproCliCompositionManifest(
                        cliCompositionManifest(mode))))
                @Expect(loaded.authorityEnvironmentLockBytes,
                    File.readFrom(Path(root).join(
                        "reproducibility/manifests/environment-lock.json")))
                @Expect(loaded.runnerAuthority.credentialEnvironmentVariables.size,
                    if (mode == "run-certify") { 1 } else { 0 })
                for (asset in loaded.assets) {
                    @Expect(asset.privateAuthority,
                        asset.relativePath.startsWith("private-authority/"))
                }
            } finally { if (exists(Path(root))) { remove(Path(root), recursive: true) } }
        }
    }

    @TestCase
    public func loaderRequiresOuterAuthorityBeforeReadingDeclaredAssets(): Unit {
        @Expect(parseCkbReproCliCompositionAuthority([0xff])[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbReproCliCompositionAuthority("{".toArray())[0]
            .diagnostic, "cli_composition_authority_field_contract_invalid")
        let root = cliCompositionRoot("p3-vector-build",
            validAuthority: false)
        try {
            let loaded = loadCkbReproCliComposition(Path(root).join(
                "reproducibility/manifests/runtime-composition.json")
                .toString(), "p3-vector-build")
            @Expect(loaded.ok, false)
            @Expect(loaded.diagnostic, "cli_composition_authority_mismatch")
        } finally { if (exists(Path(root))) { remove(Path(root), recursive: true) } }
    }

    @TestCase
    public func loaderRejectsHashSymlinkAndToctouDrift(): Unit {
        let root = cliCompositionRoot("p3-vector-build")
        try {
            let path = Path(root).join("assets/runtime_config.json")
            File.writeTo(path, "changed".toArray())
            @Expect(loadCkbReproCliComposition(Path(root).join(
                "reproducibility/manifests/runtime-composition.json")
                .toString(), "p3-vector-build").ok, false)
        } finally { if (exists(Path(root))) { remove(Path(root), recursive: true) } }

        let symlinkRoot = cliCompositionRoot("p3-vector-build")
        try {
            let target = Path(symlinkRoot).join("assets/runtime_config.json")
            let outside = Path("/tmp/ckb-cli-composition-outside.txt")
            File.writeTo(outside, "outside".toArray())
            remove(target)
            @Expect(launch("/bin/ln", ["-s", outside.toString(),
                target.toString()]).wait(), 0)
            @Expect(loadCkbReproCliComposition(Path(symlinkRoot).join(
                "reproducibility/manifests/runtime-composition.json")
                .toString(), "p3-vector-build").ok, false)
            remove(outside)
        } finally {
            if (exists(Path(symlinkRoot))) { remove(Path(symlinkRoot), recursive: true) }
        }

        let source = cliCompositionReadUtf8(Path(
            "../src/ckb_repro_cli_composition.cj"))
        @Expect(source.contains("observed.identity != initial.identity"), true)
        @Expect(source.contains("authorityAfter[1] != authorityBytes[1]"), true)
        @Expect(source.contains("manifestAfter[1] != manifestBytes[1]"), true)
        @Expect(source.contains(
            "let publicEnvironment = environmentClaim.descriptor.readPublicTarget"),
            true)
        @Expect(source.contains(
            "let publicComposition = manifestClaim.descriptor.readPublicTarget"),
            true)
    }
}
