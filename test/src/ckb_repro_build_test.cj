package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbReproBuildTest {
    @TestCase
    public func p4Pos00TrackedSourceLockIsCanonicalAndComplete(): Unit {
        let bytes = File.readFrom(Path(
            "../reproducibility/manifests/source-lock.json"))
        let parsed = parseCkbReproSourceLock(bytes)
        @Expect(parsed[0].ok, true)
        @Expect(parsed[1].entries.size, 897)
        @Expect(renderCkbReproSourceLock(parsed[1]).toArray(), bytes)

        let schema = String.fromUtf8(File.readFrom(Path(
            "../reproducibility/source-lock.schema.json")))
        @Expect(schema.contains("\"assemblyPath\""), true)
        @Expect(schema.contains(
            "\"not\": {\"required\": [\"assemblyPath\"]}"), true)
    }

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
        let rendered = renderCkbReproSourceLock(first)
        let parsed = parseCkbReproSourceLock(rendered.toArray())
        @Expect(parsed[0].ok, true)
        @Expect(renderCkbReproSourceLock(parsed[1]), rendered)
        let aIndex = rendered.indexOf("\"sourceId\":\"a\"").getOrThrow()
        let bIndex = rendered.indexOf("\"sourceId\":\"b\"").getOrThrow()
        @Expect(aIndex < bIndex, true)
        @Expect(canonicalCkbReproSourceLockHash(first),
            canonicalCkbReproSourceLockHash(second))
        second.entries[0].license = "changed"
        @Expect(canonicalCkbReproSourceLockHash(first) ==
            canonicalCkbReproSourceLockHash(second), false)
        let mapped = p4ExternalLock("mapped")
        mapped.path = "docs/dev-guide/a.md"
        mapped.assemblyPath = "dev-guide/a.md"
        let mappedLock = CkbReproSourceLock(); mappedLock.entries.add(mapped)
        let mappedText = renderCkbReproSourceLock(mappedLock)
        @Expect(mappedText.contains(
            "\"assemblyPath\":\"dev-guide/a.md\""), true)
        let mappedParsed = parseCkbReproSourceLock(mappedText.toArray())
        @Expect(mappedParsed[0].ok, true)
        @Expect(buildCkbSourceMaterialsManifest(mappedParsed[1])
            .entries[0].relativePath, "dev-guide/a.md")
        let originalMappedHash = canonicalCkbReproSourceLockHash(mappedLock)
        mapped.assemblyPath = "dev-guide/b.md"
        @Expect(canonicalCkbReproSourceLockHash(mappedLock) ==
            originalMappedHash, false)
        let routed = p4ExternalLock("a")
        routed.assemblyRole = "community_docs"
        routed.outputKind = CangjieTypedRecordKinds.DOC_SECTION
        let routedLock = CkbReproSourceLock(); routedLock.entries.add(routed)
        let original = canonicalCkbReproSourceLockHash(routedLock)
        routed.outputKind = CangjieTypedRecordKinds.TOOL_MANUAL
        @Expect(canonicalCkbReproSourceLockHash(routedLock) == original, false)
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

        let unknownField =
            "{\"schemaVersion\":\"ckb-source-lock-v1\",\"sources\":[]," +
            "\"unexpected\":true}"
        @Expect(parseCkbReproSourceLock(unknownField.toArray())[0].diagnostic,
            "source_lock_field_contract_invalid")
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
        for (row in inventory) {
            @Expect(row.sourceLockEntryHash.startsWith("sha256:"), true)
        }
    }

    @TestCase
    public func p4Pos01MultipleRecordsBindOneSourceFile(): Unit {
        let lock = CkbReproSourceLock()
        lock.entries.add(p4ExternalLock("a"))
        let typed = ArrayList<CangjieTypedRecord>()
        for (name in ["first", "second"]) {
            let record = CangjieTypedRecord()
            record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
            record.sourceId = "record-${name}"
            record.sourceSet = CangjieSourceSets.DOCS
            record.path = "docs/a.md"
            record.title = name; record.content = "content-${name}"
            record.contentHash = cangjieTypedRecordContentHash(
                record.sourceId, record.content)
            typed.add(record)
        }
        let inventory = inventoryCkbCurrentKnowledgeSources(
            typed, ArrayList<RawRecord>(), lock)
        @Expect(inventory.size, 2)
        @Expect(inventory[0].sourceId, "a")
        @Expect(inventory[1].sourceId, "a")
        @Expect(inventory[0].identity == inventory[1].identity, false)
        @Expect(inventory[0].sourceLockEntryHash,
            canonicalCkbReproSourceLockEntryHash(lock.entries[0]))

        let semanticTool = CangjieTypedRecord()
        semanticTool.recordKind = CangjieTypedRecordKinds.TOOL_MANUAL
        semanticTool.sourceId = "semantic-tool"
        semanticTool.sourceSet = CangjieSourceSets.TOOLS
        semanticTool.path = "docs/a.md"
        semanticTool.title = "tool"; semanticTool.content = "content"
        semanticTool.contentHash = cangjieTypedRecordContentHash(
            semanticTool.sourceId, semanticTool.content)
        let semanticTyped = ArrayList<CangjieTypedRecord>()
        semanticTyped.add(semanticTool)
        let semanticRows = inventoryCkbCurrentKnowledgeSources(
            semanticTyped, ArrayList<RawRecord>(), lock)
        @Expect(semanticRows[0].sourceId, "a")

        let nestedLock = CkbReproSourceLock()
        let basename = p4ExternalLock("basename")
        basename.path = "README.md"
        let nested = p4ExternalLock("nested")
        nested.path = "third_party/README.md"
        nestedLock.entries.add(basename); nestedLock.entries.add(nested)
        let nestedRecord = CangjieTypedRecord()
        nestedRecord.recordKind = CangjieTypedRecordKinds.DOC_SECTION
        nestedRecord.sourceId = "nested-record"
        nestedRecord.sourceSet = CangjieSourceSets.DOCS
        nestedRecord.path = "third_party/README.md"
        nestedRecord.title = "nested"; nestedRecord.content = "content"
        nestedRecord.contentHash = cangjieTypedRecordContentHash(
            nestedRecord.sourceId, nestedRecord.content)
        let nestedTyped = ArrayList<CangjieTypedRecord>()
        nestedTyped.add(nestedRecord)
        let nestedRows = inventoryCkbCurrentKnowledgeSources(
            nestedTyped, ArrayList<RawRecord>(), nestedLock)
        @Expect(nestedRows[0].sourceId, "nested")

        let pathFixture = p4BuildFixture("public-identity")
        let portableRecord = CangjieTypedRecord()
        portableRecord.recordKind = CangjieTypedRecordKinds.DOC_SECTION
        portableRecord.sourceId = "portable-record"
        portableRecord.path = "docs/a.md"
        portableRecord.title = "absolute path semantics"
        portableRecord.content = "Use {{CKB_PATH:ABSOLUTE}}/example"
        portableRecord.contentHash = cangjieTypedRecordContentHash(
            portableRecord.sourceId, portableRecord.content)
        @Expect(ckbReproValidatedPublicTypedRecordIdentity(
            portableRecord, pathFixture.request.pathContext).ok, true)
        portableRecord.content = "Use {{CKB_PATH:UNKNOWN}}/example"
        portableRecord.contentHash = cangjieTypedRecordContentHash(
            portableRecord.sourceId, portableRecord.content)
        @Expect(ckbReproValidatedPublicTypedRecordIdentity(
            portableRecord, pathFixture.request.pathContext).diagnostic,
            "portable_placeholder_unresolved")
        p4RemoveBuildFixture(pathFixture)
        @Expect(validateCkbSourceCoverage(inventory,
            buildCkbKnowledgeSelectionManifest(inventory), 2).ready, true)

        let duplicate = p4ExternalLock("duplicate")
        duplicate.path = "docs/a.md"; lock.entries.add(duplicate)
        let ambiguous = inventoryCkbCurrentKnowledgeSources(
            typed, ArrayList<RawRecord>(), lock)
        @Expect(ambiguous[0].sourceId, "")
        @Expect(validateCkbSourceCoverage(ambiguous,
            buildCkbKnowledgeSelectionManifest(ambiguous), 2).ready, false)
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
        let canonicalProof = renderCkbReproBuildProof(result.proof)
        let parsedProof = parseCkbReproBuildProof(canonicalProof.toArray())
        @Expect(parsedProof[0].diagnostic, "ok")
        @Expect(parsedProof[0].ok, true)
        @Expect(parsedProof[1].preservationHash,
            result.proof.preservationHash)
        @Expect(parseCkbReproBuildProof([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbReproBuildProof(
            canonicalProof.replace("\"vectorCount\":0",
                "\"vectorCount\":1").toArray())[0].diagnostic,
            "build_proof_invalid")
        @Expect(backend.stages.toArray(),
            ["assemble", "validate_authority", "load_first_init", "validate_serving",
             "clean", "leakage", "materialize", "logical_scan"])
        @Expect(backend.selectedTypedCount > 0, true)
        @Expect(backend.portableRawCount, fixture.request.rawInput.size)
        let productionInput = CkbReproPipelineInput()
        productionInput.request = fixture.request
        productionInput.request.candidateVersion = "portable-production-candidate"
        productionInput.selectedTyped.add(fixture.request.typedInput[0])
        productionInput.portableTyped.add(fixture.request.typedInput[0])
        @Expect(CkbReproProductionBuildBackend().run(
            "assemble", productionInput).ok, true)
        productionInput.selectedTyped.add(fixture.request.typedInput[0])
        @Expect(CkbReproProductionBuildBackend().run(
            "assemble", productionInput).ok, false)
        p4RemoveBuildFixture(fixture)
    }

    @TestCase
    public func p4Reg02GenericRawAtomKeepsKnowledgeAtomKind(): Unit {
        let input = CkbReproPipelineInput()
        input.request.candidateVersion = "portable-production-candidate"
        let atom = RawRecord()
        atom.sourceId = "knowledge-atom-regression"
        atom.title = "Generic atom"
        atom.content = "Knowledge: String runes preserve Unicode boundaries\n" +
            "Example: text.toRuneArray()"
        atom.contentHash = cangjieTypedRecordContentHash(
            atom.sourceId, atom.content)
        atom.metadata.sourceId = atom.sourceId
        atom.metadata.sourceType = SourceTypes.DERIVED
        atom.metadata.sourceSet = CangjieSourceSets.KNOWLEDGE_ATOMS
        atom.metadata.path = "knowledge-atom/KC-02/regression.json"
        atom.metadata.trustLevel = TrustLevels.COMMUNITY
        atom.metadata.reviewState = ReviewStates.REVIEWED
        atom.metadata.license = "Apache-2.0"
        atom.metadata.repoVisibility = "public"
        atom.metadata.derivedFrom = ["generated-guidance:regression"]
        input.portableRaw.add(atom)

        @Expect(CkbReproProductionBuildBackend().run("clean", input).ok,
            true)
    }

    @TestCase
    public func p4Reg03ProductionProofIsPersistedForP3(): Unit {
        let fixture = p4BuildFixture("proof-output")
        let result = runCkbReproBuild(
            fixture.request, P4FakeBuildBackend())
        let output = Path(fixture.root).join("proof")
        Directory.create(output)

        @Expect(persistCkbReproBuildProof(
            output.toString(), result.proof), "ok")
        let parsed = parseCkbReproBuildProof(File.readFrom(
            output.join("repro-build-proof.json")))
        @Expect(parsed[0].ok, true)
        @Expect(parsed[1].preservationHash, result.proof.preservationHash)
        @Expect(persistCkbReproBuildProof(
            output.join("missing").toString(), result.proof),
            "p4_build_proof_write_failed")
        p4RemoveBuildFixture(fixture)
    }

    @TestCase
    public func p4Reg04ProductionCandidateBindsEvalSupportAuthority(): Unit {
        let fixture = p4BuildFixture("authority-binding")
        let input = CkbReproPipelineInput()
        input.request = fixture.request
        input.request.candidateVersion = "portable-authority-binding"
        input.request.evalSupportAuthority.authorityHash =
            "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        input.request.leakageAuthorityHash =
            "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        input.selectedTyped.add(fixture.request.typedInput[0])
        input.portableTyped.add(fixture.request.typedInput[0])
        let backend = CkbReproProductionBuildBackend()

        @Expect(backend.run("clean", input).ok, true)
        @Expect(backend.run("materialize", input).ok, true)
        let manifest = File.readFrom(Path(input.request.options.temporaryRoot)
            .join("candidate-artifacts/portable-authority-binding/" +
                "clean-candidate-manifest.json"))
        let text = String.fromUtf8(manifest)
        @Expect(text.contains(input.request.evalSupportAuthority.authorityHash),
            true)
        @Expect(text.contains(input.request.leakageAuthorityHash), false)
        p4RemoveBuildFixture(fixture)
    }

    @TestCase
    public func p4Reg05ProductionBackendReleasesTerminalBuildState(): Unit {
        let source = String.fromUtf8(File.readFrom(
            Path("../src/ckb_repro_build.cj")))
        @Expect(source.contains("private func releaseRetainedBuildState(): Unit"),
            true)
        @Expect(source.contains("if (!result.ok || stage == \"logical_scan\")"),
            true)
        @Expect(source.contains("private func assemble(input: " +
            "CkbReproPipelineInput): CkbReproBackendResult {\n" +
            "        this.releaseRetainedBuildState()"), true)
        @Expect(source.contains("visible.rawRecords.clear(); " +
            "visible.normalizedRecords.clear()"), true)
        @Expect(source.contains("this.kb = KnowledgeBase(FakeClock(0))"), true)
        @Expect(source.contains("this.candidate = " +
            "CkbCompleteCleanStudentCandidate()"), true)
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
        @Expect(first.proof.candidateVersion, fixture.request.candidateVersion)
        @Expect(first.proof.preservationHash,
            ckbReproBuildPreservationHash(first.proof))
        let original = first.proof.preservationHash
        first.proof.candidateVersion = "substituted-candidate"
        @Expect(ckbReproBuildPreservationHash(first.proof) == original, false)
        var controls = ""
        for (value in 0..32) { controls += Rune(UInt32(value)).toString() }
        first.proof.candidateVersion = controls
        let json = renderCkbReproBuildProof(first.proof)
        for (value in 0..32) {
            @Expect(json.contains(Rune(UInt32(value)).toString()), false)
        }
        p4RemoveBuildFixture(fixture)
    }

    @TestCase
    public func p4Pos03PromotionInterfaceFakePointerCommitsOnce(): Unit {
        let fixture = p4PromotionFixture("pos03")
        fixture.options.p8StrictPassed = 152
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

        let readBack = p4PromotionFixture("rollback-readback")
        let readBackBackend = P4FakePromotionBackend()
        readBackBackend.readBackOk = false
        @Expect(promoteCkbPortableCandidate(
            readBack.options, readBackBackend).diagnostic,
            "promotion_read_back_failed")
        @Expect(readBackBackend.currentVersion, "old")
        @Expect(readBackBackend.rollbackCalls, 1)
        p4RemovePromotionFixture(readBack)

        let cleanup = p4PromotionFixture("rollback-cleanup")
        let cleanupBackend = P4FakePromotionBackend()
        cleanupBackend.cleanupOldOk = false
        @Expect(promoteCkbPortableCandidate(
            cleanup.options, cleanupBackend).diagnostic,
            "promotion_cleanup_old_failed")
        @Expect(cleanupBackend.currentVersion, "old")
        @Expect(cleanupBackend.rollbackCalls, 1)
        p4RemovePromotionFixture(cleanup)
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
    fixture.request.candidateVersion = "portable-${id}"
    fixture.request.sourceLock.entries.add(p4GeneratedLock("generated"))
    fixture.request.inventory = p4Inventory()
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
    entry.assemblyRole = "community_docs"
    entry.outputKind = CangjieTypedRecordKinds.DOC_SECTION
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
    entry.outputPath = "generated/${id}.md"
    entry.license = "Apache-2.0"
    entry.assemblyRole = "generated_guidance"
    entry.outputKind = CangjieTypedRecordKinds.TOOL_MANUAL
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
    excluded.sourceLockEntryHash =
        "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
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
    selected.sourceLockEntryHash =
        "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
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
    public var rollbackCalls: Int64 = 0
    public var readBackOk: Bool = true
    public var cleanupOldOk: Bool = true
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
        stages.add("read_back"); readBackOk && currentVersion == options.candidateVersion
    }
    public func cleanupOld(): Bool { stages.add("cleanup_old"); cleanupOldOk }
    public func rollback(state: CkbPortablePromotionState): Bool {
        rollbackCalls += 1; currentVersion = state.activeVersion
        pointerHash = state.pointerHash; true
    }
    public func cleanupStaging(): Unit { cleanupStagingCalls += 1 }
}
