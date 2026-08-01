package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbReproBuildTest {
    @TestCase
    public func p4Ut01ComponentCanonicalSourceLocksBindEveryField(): Unit {
        let a = p4ExternalLock("b")
        let b = p4ExternalLock("a")
        let first = CkbReproSourceLock()
        first.entries.add(a); first.entries.add(b)
        let second = CkbReproSourceLock()
        second.entries.add(p4ExternalLock("a"))
        second.entries.add(p4ExternalLock("b"))
        @Expect(validateCkbReproBuildLocks(first).ok, true)
        @Expect(canonicalCkbReproSourceLockHash(first),
            canonicalCkbReproSourceLockHash(second))
        second.entries[0].license = "changed"
        @Expect(canonicalCkbReproSourceLockHash(first) ==
            canonicalCkbReproSourceLockHash(second), false)
    }

    @TestCase
    public func p4Bnd01ComponentUtf8UrlsAndSourceKindsFailClosed(): Unit {
        @Expect(parseCkbReproSourceLock([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
        for (repository in ["git@github.com:a/b.git", "https://u:p@example.invalid/a",
            "http://example.invalid/a", "https://example.invalid/latest"]) {
            let lock = CkbReproSourceLock()
            let entry = p4ExternalLock("bad")
            entry.repository = repository
            lock.entries.add(entry)
            @Expect(validateCkbReproBuildLocks(lock).ok, false)
        }
        let mixed = CkbReproSourceLock()
        let generated = p4GeneratedLock("generated")
        generated.repository = "https://example.invalid/forbidden.git"
        mixed.entries.add(generated)
        @Expect(validateCkbReproBuildLocks(mixed).diagnostic,
            "generated_source_fields_mixed")
    }

    @TestCase
    public func p4Pos01ComponentFakeMaterialsAndCoverageCloseExactly(): Unit {
        let lock = CkbReproSourceLock()
        lock.entries.add(p4ExternalLock("external"))
        lock.entries.add(p4GeneratedLock("generated"))
        let backend = P4FakeMaterialBackend()
        let materials = buildCkbSourceMaterialsManifest(lock)
        @Expect(materials.ready, true)
        @Expect(fetchAndValidateCkbSourceMaterials(materials, backend).ok, true)
        @Expect(generateAndValidateCkbSourceMaterials(materials, backend).ok, true)
        @Expect(backend.credentialReads, 0)
        @Expect(backend.cacheHits, 0)
        @Expect(backend.latestFetches, 0)

        let inventory = p4Inventory()
        let selection = buildCkbKnowledgeSelectionManifest(inventory)
        let coverage = validateCkbSourceCoverage(inventory, selection, 1)
        @Expect(coverage.ready, true)
        @Expect(coverage.selectedCount + coverage.excludedCount,
            coverage.inventoryCount)
    }

    @TestCase
    public func p4Neg01ComponentDriftDuplicateAndBackendFailureStopWork(): Unit {
        let inventory = p4Inventory()
        inventory.add(inventory[0])
        let coverage = validateCkbSourceCoverage(
            inventory, buildCkbKnowledgeSelectionManifest(inventory), 2)
        @Expect(coverage.ready, false)
        @Expect(coverage.diagnostic, "source_inventory_duplicate")

        let lock = CkbReproSourceLock()
        lock.entries.add(p4ExternalLock("external"))
        let backend = P4FakeMaterialBackend()
        backend.fetchOk = false
        @Expect(fetchAndValidateCkbSourceMaterials(
            buildCkbSourceMaterialsManifest(lock), backend).ok, false)
        @Expect(backend.generateCalls, 0)
    }

    @TestCase
    public func p4Reg01ComponentFakeSourceProofIsByteStable(): Unit {
        let lock = CkbReproSourceLock()
        lock.entries.add(p4GeneratedLock("b"))
        lock.entries.add(p4ExternalLock("a"))
        @Expect(renderCkbSourceMaterialsManifest(
            buildCkbSourceMaterialsManifest(lock)),
            renderCkbSourceMaterialsManifest(buildCkbSourceMaterialsManifest(lock)))
    }

    @TestCase
    public func p4Pos02BuildComponentRunsClosedFakeStateMachine(): Unit {
        let fixture = p4BuildFixture("pos02")
        let backend = P4FakeBuildBackend()
        let result = runCkbReproBuild(fixture.request, backend)
        @Expect(result.ready, true)
        @Expect(result.proof.logicalReady, true)
        @Expect(result.proof.evalSupportPersisted, 0)
        @Expect(result.proof.vectorCount, 0)
        @Expect(result.proof.vectorState, "DEGRADED")
        @Expect(backend.stages.toArray(),
            ["assemble", "validate_authority", "load_first_init", "validate_serving",
             "clean", "leakage", "materialize", "logical_scan"])
        @Expect(backend.selectedTypedCount > 0, true)
        @Expect(backend.portableRawCount, fixture.request.rawInput.size)
        p4RemoveBuildFixture(fixture)
    }

    @TestCase
    public func p4Neg02BuildComponentEvalSelectionAndStageFailureShortCircuit(): Unit {
        let fixture = p4BuildFixture("neg02")
        let leaked = CkbReproKnowledgeSelectionRow()
        leaked.identity = "eval"
        leaked.recordKind = CangjieTypedRecordKinds.EVAL_SUPPORT
        leaked.decision = "selected"
        fixture.request.selection.add(leaked)
        let backend = P4FakeBuildBackend()
        let selectionFailure = runCkbReproBuild(fixture.request, backend)
        @Expect(selectionFailure.ready, false)
        @Expect(selectionFailure.diagnostic, "eval_support_selection_forbidden")
        @Expect(backend.stages.size, 0)

        fixture.request.selection.remove(at: fixture.request.selection.size - 1)
        backend.failStage = "clean"
        let stageFailure = runCkbReproBuild(fixture.request, backend)
        @Expect(stageFailure.ready, false)
        @Expect(stageFailure.diagnostic, "build_stage_failed:clean")
        @Expect(backend.stages.contains("materialize"), false)
        p4RemoveBuildFixture(fixture)
    }

    @TestCase
    public func p4Reg02BuildComponentRepeatedProofIsDeterministic(): Unit {
        let fixture = p4BuildFixture("reg02")
        let first = runCkbReproBuild(fixture.request, P4FakeBuildBackend())
        let second = runCkbReproBuild(fixture.request, P4FakeBuildBackend())
        @Expect(first.ready, true)
        @Expect(second.ready, true)
        @Expect(renderCkbReproBuildProof(first.proof),
            renderCkbReproBuildProof(second.proof))
        p4RemoveBuildFixture(fixture)
    }

    @TestCase
    public func p4Pos03PromotionInterfaceFakePointerCommitsOnce(): Unit {
        let fixture = p4PromotionFixture("pos03")
        let backend = P4FakePromotionBackend()
        let result = promoteCkbPortableCandidate(fixture.options, backend)
        @Expect(result.ready, true)
        @Expect(result.pointerCommitted, true)
        @Expect(backend.commitCalls, 1)
        @Expect(backend.stages.toArray(),
            ["restore_vector", "validate_vector", "commit_pointer", "read_back",
             "cleanup_old"])
        p4RemovePromotionFixture(fixture)
    }

    @TestCase
    public func p4Neg03PromotionInterfaceMissingProofAndCommitFailurePreservePointer(): Unit {
        let fixture = p4PromotionFixture("neg03")
        fixture.options.apply = false
        let backend = P4FakePromotionBackend()
        @Expect(promoteCkbPortableCandidate(fixture.options, backend).diagnostic,
            "promotion_apply_required")
        @Expect(backend.stages.size, 0)

        fixture.options.apply = true
        backend.commitOk = false
        let failed = promoteCkbPortableCandidate(fixture.options, backend)
        @Expect(failed.ready, false)
        @Expect(backend.currentVersion, fixture.options.expectedActiveVersion)
        @Expect(backend.cleanupStagingCalls, 1)
        p4RemovePromotionFixture(fixture)
    }
}

private class P4BuildFixture {
    public var root: String = ""
    public var request: CkbReproBuildRequest = CkbReproBuildRequest()
    public init() {}
}

private func p4BuildFixture(id: String): P4BuildFixture {
    let fixture = P4BuildFixture()
    let path = Path("target/p4-build-${id}")
    if (exists(path)) { remove(path, recursive: true) }
    Directory.create(path, recursive: true)
    fixture.root = canonicalize(path).toString()
    fixture.request.options.outputRoot = fixture.root + "/output"
    fixture.request.options.temporaryRoot = fixture.root + "/temporary"
    fixture.request.options.expectedRawCount = 1
    fixture.request.sourceLock.entries.add(p4GeneratedLock("generated"))
    fixture.request.inventory = p4InventoryOne()
    fixture.request.selection = buildCkbKnowledgeSelectionManifest(fixture.request.inventory)
    fixture.request.pathContext = p4BuildPathContext(fixture.root)
    fixture.request.typedInput.add(p4BuildTyped(fixture.root))
    fixture.request.rawInput.add(p4BuildRaw(fixture.root))
    fixture
}

private func p4RemoveBuildFixture(fixture: P4BuildFixture): Unit {
    if (fixture.root != "" && exists(Path(fixture.root))) {
        remove(Path(fixture.root), recursive: true)
    }
}

private func p4ExternalLock(id: String): CkbReproSourceLockEntry {
    let entry = CkbReproSourceLockEntry()
    entry.sourceId = id
    entry.sourceType = "external_git"
    entry.repository = "https://example.invalid/${id}.git"
    entry.commit = "0123456789012345678901234567890123456789"
    entry.tree = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    entry.path = "docs/${id}.md"
    entry.fileHash = "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    entry.license = "Apache-2.0"
    entry.authMode = "anonymous"
    entry
}

private func p4GeneratedLock(id: String): CkbReproSourceLockEntry {
    let entry = CkbReproSourceLockEntry()
    entry.sourceId = id
    entry.sourceType = "generated"
    entry.generatorId = "generator-${id}"
    entry.generatorVersion = "1"
    entry.generatorSourceHash =
        "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
    entry.inputHashes.add(
        "sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd")
    entry.outputHash =
        "sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
    entry.license = "Apache-2.0"
    entry
}

private func p4Inventory(): ArrayList<CkbReproKnowledgeInventoryRow> {
    let rows = p4InventoryOne()
    let excluded = CkbReproKnowledgeInventoryRow()
    excluded.identity = "portable-eval"
    excluded.sourceId = "generated"
    excluded.recordKind = CangjieTypedRecordKinds.EVAL_SUPPORT
    excluded.portableLocator = "ckb-source://generated/eval"
    excluded.sourceType = "generated"
    excluded.license = "Apache-2.0"
    rows.add(excluded)
    rows
}

private func p4InventoryOne(): ArrayList<CkbReproKnowledgeInventoryRow> {
    let rows = ArrayList<CkbReproKnowledgeInventoryRow>()
    let selected = CkbReproKnowledgeInventoryRow()
    selected.identity = "portable-doc"
    selected.sourceId = "generated"
    selected.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    selected.portableLocator = "ckb-source://generated/docs/a.md"
    selected.sourceType = "generated"
    selected.license = "Apache-2.0"
    rows.add(selected)
    rows
}

private func p4BuildTyped(root: String): CangjieTypedRecord {
    let record = CangjieTypedRecord()
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.sourceId = "generated:${root}/docs/a.md"
    record.title = "A"
    record.content = "read ${root}/src/a.cj"
    record.citation = "${root}/docs/a.md:1"
    record.path = "${root}/docs/a.md"
    record.contentHash = cangjieTypedRecordContentHash(record.sourceId, record.content)
    record
}

private func p4BuildRaw(root: String): RawRecord {
    let record = RawRecord()
    record.sourceId = "generated:${root}/atoms/a.json"
    record.title = "A"
    record.content = "read ${root}/src/a.cj"
    record.metadata.sourceId = record.sourceId
    record.metadata.repo = "generated/repository"
    record.metadata.path = "${root}/atoms/a.json"
    record.contentHash = cangjieTypedRecordContentHash(record.sourceId, record.content)
    record
}

private func p4BuildPathContext(root: String): CkbPortablePathContext {
    let context = CkbPortablePathContext()
    context.policy = parseCkbPortablePathPolicy(
        File.readFrom(Path("../reproducibility/manifests/portable-path-policy.json")))[1]
    let local = CkbPortableLocalRoot()
    local.sourceId = "generated"
    local.kind = "PROJECT_ROOT"
    local.localRoot = root
    context.localRoots.schemaVersion = "ckb-portable-local-root-map-v1"
    context.localRoots.roots.add(local)
    context.apiRoutes.add("/v1/search")
    context
}

private class P4FakeMaterialBackend <: CkbReproSourceMaterialBackend {
    public var fetchOk: Bool = true
    public var generateOk: Bool = true
    public var credentialReads: Int64 = 0
    public var cacheHits: Int64 = 0
    public var latestFetches: Int64 = 0
    public var fetchCalls: Int64 = 0
    public var generateCalls: Int64 = 0
    public func fetch(entry: CkbReproSourceMaterialEntry): CkbReproBackendResult {
        fetchCalls += 1
        CkbReproBackendResult(fetchOk,
            if (fetchOk) { entry.expectedHash } else { "" })
    }
    public func generate(entry: CkbReproSourceMaterialEntry): CkbReproBackendResult {
        generateCalls += 1
        CkbReproBackendResult(generateOk,
            if (generateOk) { entry.expectedHash } else { "" })
    }
}

private class P4FakeBuildBackend <: CkbReproBuildBackend {
    public var stages: ArrayList<String> = ArrayList<String>()
    public var failStage: String = ""
    public var selectedTypedCount: Int64 = 0
    public var portableRawCount: Int64 = 0
    public func run(stage: String,
        input: CkbReproPipelineInput): CkbReproBackendResult {
        stages.add(stage)
        selectedTypedCount = input.selectedTyped.size
        portableRawCount = input.portableRaw.size
        CkbReproBackendResult(stage != failStage, "")
    }
}

private class P4PromotionFixture {
    public var root: String = ""
    public var options: CkbPortablePromotionOptions = CkbPortablePromotionOptions()
    public init() {}
}

private func p4PromotionFixture(id: String): P4PromotionFixture {
    let fixture = P4PromotionFixture()
    let path = Path("target/p4-promotion-${id}")
    if (exists(path)) { remove(path, recursive: true) }
    Directory.create(path, recursive: true)
    fixture.root = canonicalize(path).toString()
    fixture.options.productionStore = fixture.root
    fixture.options.qdrantEndpoint = "http://127.0.0.1:6333"
    fixture.options.expectedActiveVersion = "old"
    fixture.options.expectedPointerHash =
        "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    fixture.options.candidateVersion = "portable"
    fixture.options.candidateManifestHash =
        "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    fixture.options.p2ProofHash =
        "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
    fixture.options.p3ProofHash =
        "sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
    fixture.options.p5ProofHash =
        "sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
    fixture.options.p8AProofHash =
        "sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    fixture.options.p8BProofHash =
        "sha256:1111111111111111111111111111111111111111111111111111111111111111"
    fixture.options.identity = "portable-identity"
    fixture.options.p8StrictPassed = 151
    fixture.options.apply = true
    fixture
}

private func p4RemovePromotionFixture(fixture: P4PromotionFixture): Unit {
    if (fixture.root != "" && exists(Path(fixture.root))) {
        remove(Path(fixture.root), recursive: true)
    }
}

private class P4FakePromotionBackend <: CkbPortablePromotionBackend {
    public var currentVersion: String = "old"
    public var pointerHash: String =
        "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    public var commitOk: Bool = true
    public var commitCalls: Int64 = 0
    public var cleanupStagingCalls: Int64 = 0
    public var stages: ArrayList<String> = ArrayList<String>()
    public func readCurrent(): CkbPortablePromotionState {
        CkbPortablePromotionState(currentVersion, pointerHash, "")
    }
    public func restoreVector(_options: CkbPortablePromotionOptions): Bool {
        stages.add("restore_vector"); true
    }
    public func validateVector(_options: CkbPortablePromotionOptions): Bool {
        stages.add("validate_vector"); true
    }
    public func commitPointer(options: CkbPortablePromotionOptions): Bool {
        stages.add("commit_pointer"); commitCalls += 1
        if (commitOk) { currentVersion = options.candidateVersion }
        commitOk
    }
    public func readBack(options: CkbPortablePromotionOptions): Bool {
        stages.add("read_back"); currentVersion == options.candidateVersion
    }
    public func cleanupOld(): Bool { stages.add("cleanup_old"); true }
    public func cleanupStaging(): Unit { cleanupStagingCalls += 1 }
}
