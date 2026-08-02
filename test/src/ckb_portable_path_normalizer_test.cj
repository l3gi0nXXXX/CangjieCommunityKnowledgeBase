package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbPortablePathNormalizerTest {
    @TestCase
    public func p4Ut02PolicyContextClassificationAndRealHmacAreDeterministic(): Unit {
        let fixture = p4ContextFixture("ut")
        @Expect(fixture.ok, true)
        @Expect(validateCkbPortablePathPolicyForBuild(fixture.context.policy).ok, true)
        @Expect(buildCkbPortablePathRules(fixture.context.policy).size, 8)

        let source = classifyCkbPathOccurrence(
            "${fixture.root}/src/main.cj", "content", "official-doc", fixture.context)
        @Expect(source.ok, true)
        @Expect(source.category, "declared_project_root")
        @Expect(source.value, "{{CKB_PATH:PROJECT_ROOT}}/src/main.cj")

        for (value in ["https://example.invalid/v1/search", "ckb-source://official/src/main.cj",
            "/v1/search", "/usr/bin/env", "module/path"]) {
            let preserved = classifyCkbPathOccurrence(
                value, "content", "official-doc", fixture.context)
            @Expect(preserved.ok, true)
            @Expect(preserved.value, value)
        }

        let provider = CkbHmacSha256PathIdProvider("key".toArray())
        @Expect(provider.recordId(
            "The quick brown fox jumps over the lazy dog"),
            "hsha256:f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8")
        p4RemoveFixture(fixture)
    }

    @TestCase
    public func p4Bnd02UnicodePlatformPathsAndInvalidUtf8FailSafely(): Unit {
        let fixture = p4ContextFixture("边界🙂")
        @Expect(fixture.ok, true)
        let unicode = normalizeCkbKnowledgeText(
            "读取 ${fixture.root}/资料/🙂.cj 完成", "content", "official-doc", fixture.context)
        @Expect(unicode.ok, true)
        @Expect(unicode.value.contains(
            "{{CKB_PATH:PROJECT_ROOT}}/资料/🙂.cj"), true)

        let windows = normalizeCkbKnowledgeText(
            "C:\\Users\\alice\\资料\\🙂.cj", "content", "official-doc", fixture.context)
        @Expect(windows.ok, true)
        @Expect(windows.value, "{{CKB_PATH:USER_HOME}}\\资料\\🙂.cj")
        let unc = normalizeCkbKnowledgeText(
            "\\\\host\\Users\\alice\\file.cj", "content", "official-doc", fixture.context)
        @Expect(unc.ok, true)
        @Expect(unc.value, "{{CKB_PATH:USER_HOME}}\\file.cj")
        let fileUrl = normalizeCkbKnowledgeText(
            "file:///Users/alice/input.txt", "content", "official-doc", fixture.context)
        @Expect(fileUrl.ok, true)
        @Expect(fileUrl.value, "file://{{CKB_PATH:USER_HOME}}/input.txt")
        let temporary = normalizeCkbKnowledgeText(
            "/tmp/build/output", "content", "official-doc", fixture.context)
        @Expect(temporary.ok, true)
        @Expect(temporary.value, "{{CKB_PATH:TMPDIR}}/build/output")

        @Expect(parseCkbPortableLocalRootMap([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
        p4RemoveFixture(fixture)
    }

    @TestCase
    public func p4Pos02ComponentTypedRawAndStudentVisibleLayersBecomePortableWithoutDeletion(): Unit {
        let fixture = p4ContextFixture("pos")
        @Expect(fixture.ok, true)
        let typed = CangjieTypedRecord()
        typed.recordKind = CangjieTypedRecordKinds.DOC_SECTION
        typed.sourceId = "official:${fixture.root}/docs/guide.md"
        typed.title = "Guide at ${fixture.root}/docs"
        typed.content = "open(${fixture.root}/样例/🙂.cj)"
        typed.citation = "${fixture.root}/docs/guide.md:10"
        typed.heading = "/"
        typed.sectionId = "section ${fixture.root}/docs"
        typed.command = "run ${fixture.root}/bin/tool"
        typed.path = "${fixture.root}/docs/guide.md"
        typed.sourceRef = "https://example.invalid/ref"
        typed.resolvedCommit = "0123456789012345678901234567890123456789"
        typed.contentHash = cangjieTypedRecordContentHash(typed.sourceId, typed.content)
        let oldHash = typed.contentHash
        let typedResult = normalizeCkbTypedRecordPortablePaths(typed, fixture.context)
        @Expect(typedResult.ok, true)
        @Expect(typedResult.record.path, "docs/guide.md")
        @Expect(typedResult.record.content.contains("{{CKB_PATH:PROJECT_ROOT}}"), true)
        @Expect(typedResult.record.heading.contains("{{CKB_PATH:ABSOLUTE}}"), true)
        @Expect(typedResult.record.sectionId.contains("{{CKB_PATH:PROJECT_ROOT}}"), true)
        @Expect(typedResult.record.command.contains("{{CKB_PATH:PROJECT_ROOT}}"), true)
        @Expect(typedResult.record.contentHash == oldHash, false)
        @Expect(typed.path, "${fixture.root}/docs/guide.md")

        let raw = RawRecord()
        raw.sourceId = "atom:${fixture.root}/atoms/a.json"
        raw.title = "Atom ${fixture.root}/atoms"
        raw.content = "cache /home/alice/.cache/ckb"
        raw.metadata.sourceId = raw.sourceId
        raw.metadata.sourceUrl = "${fixture.root}/atoms/a.json"
        raw.metadata.repo = "official/repository"
        raw.metadata.path = "${fixture.root}/atoms/a.json"
        raw.metadata.derivedFrom = ["${fixture.root}/docs/guide.md"]
        raw.contentHash = cangjieTypedRecordContentHash(raw.sourceId, raw.content)
        let preScan = scanCkbRawPathOccurrences(raw, fixture.context)
        @Expect(preScan.ready, false)
        @Expect(preScan.machinePathCount > 0, true)
        let rawResult = normalizeCkbRawRecordPortablePaths(raw, fixture.context)
        @Expect(rawResult.ok, true)
        @Expect(rawResult.record.metadata.path, "atoms/a.json")
        @Expect(rawResult.record.content.contains("{{CKB_PATH:USER_HOME}}"), true)
        @Expect(rawResult.record.metadata.derivedFrom[0].startsWith("ckb-source://"), true)

        let layers = CkbStudentVisiblePathInput()
        layers.rawRecords.add(rawResult.record)
        layers.normalizedRecords.add(cangjieTypedRecordToNormalized(
            typedResult.record, KnowledgeMetadata()))
        layers.activeRecords.add(cangjieTypedRecordToNormalized(
            typedResult.record, KnowledgeMetadata()))
        let graph = GraphBuildResult()
        let node = GraphNode()
        node.nodeId = "path:official:docs/guide.md"
        node.nodeType = GraphNodeTypes.PATH
        node.label = "docs/guide.md"
        node.sourceId = typedResult.record.sourceId
        graph.nodes.add(node)
        layers.graph = graph
        let scan = scanCkbStudentVisiblePaths(layers, fixture.context)
        @Expect(scan.ready, true)
        @Expect(scan.machinePathCount, 0)
        @Expect(scan.unmappedCount, 0)

        let proof = buildCkbPortableRecordPreservationProof(
            [typed], [typedResult.record], [raw], [rawResult.record], fixture.context)
        @Expect(proof.ready, true)
        @Expect(proof.typedInputCount, 1)
        @Expect(proof.typedOutputCount, 1)
        @Expect(proof.rawInputCount, 1)
        @Expect(proof.rawOutputCount, 1)
        @Expect(proof.typedPairCount, 1)
        @Expect(proof.rawPairCount, 1)
        p4RemoveFixture(fixture)
    }

    @TestCase
    public func p4Neg02ComponentOverlapWideAllowlistUnmappedAndReportsFailClosedWithoutLeaks(): Unit {
        let fixture = p4ContextFixture("neg")
        @Expect(fixture.ok, true)
        let overlappingJson = "{\"schemaVersion\":\"ckb-portable-local-root-map-v1\"," +
            "\"roots\":[{\"sourceId\":\"official\",\"kind\":\"PROJECT_ROOT\"," +
            "\"localRoot\":\"${fixture.root}\"},{\"sourceId\":\"official\"," +
            "\"kind\":\"SOURCE_ROOT\",\"localRoot\":\"${fixture.root}/docs\"}]}"
        Directory.create(Path(fixture.root).join("docs"), recursive: true)
        let overlap = parseCkbPortableLocalRootMap(overlappingJson.toArray())
        @Expect(overlap[0].ok, true)
        @Expect(validateCkbPortableLocalRootMap(
            overlap[1], ["official"]).diagnostic, "portable_local_roots_overlap")

        fixture.context.policy.allowlist.add("/tmp")
        @Expect(validateCkbPortablePathPolicyForBuild(
            fixture.context.policy).diagnostic, "path_policy_allowlist_invalid")
        fixture.context.policy.allowlist.remove(at: fixture.context.policy.allowlist.size - 1)

        let metadata = KnowledgeMetadata()
        metadata.sourceId = "unknown"
        metadata.path = "/unmapped/private/root/file.cj"
        @Expect(validateCkbPortableMetadata(
            metadata, fixture.context).diagnostic, "unmapped_absolute_path")

        let scan = CkbPortablePathScanReport()
        scan.ready = false
        scan.unmappedCount = 1
        let finding = CkbPortablePathFinding()
        finding.sourceId = "official"
        finding.field = "content"
        finding.ruleId = "unmapped"
        finding.category = "unmapped"
        finding.privateValue = "/private/user/secret.cj"
        scan.findings.add(finding)
        let provider = CkbHmacSha256PathIdProvider("private-test-key".toArray())
        let privateReport = buildCkbPortablePathPrivateReport(scan, provider)
        let publicReport = buildCkbPortablePathPublicReport(scan)
        @Expect(privateReport.contains("/private/user"), false)
        @Expect(publicReport.contains("/private/user"), false)
        @Expect(publicReport.contains("hsha256:"), false)

        let typed = p4TypedProofRecord(fixture.root, "a")
        let typedNormalized = normalizeCkbTypedRecordPortablePaths(typed, fixture.context)
        @Expect(typedNormalized.ok, true)
        typedNormalized.record.title = "replacement"
        let raw = p4RawProofRecord(fixture.root, "a")
        let rawNormalized = normalizeCkbRawRecordPortablePaths(raw, fixture.context)
        @Expect(rawNormalized.ok, true)
        let typedMismatch = buildCkbPortableRecordPreservationProof(
            [typed], [typedNormalized.record], [raw], [rawNormalized.record], fixture.context)
        @Expect(typedMismatch.ready, false)
        @Expect(typedMismatch.diagnostic, "typed_record_mapping_mismatch")

        let typedExpected = normalizeCkbTypedRecordPortablePaths(typed, fixture.context)
        rawNormalized.record.title = "replacement"
        let rawMismatch = buildCkbPortableRecordPreservationProof(
            [typed], [typedExpected.record], [raw], [rawNormalized.record], fixture.context)
        @Expect(rawMismatch.ready, false)
        @Expect(rawMismatch.diagnostic, "raw_record_mapping_mismatch")
        p4RemoveFixture(fixture)
    }

    @TestCase
    public func p4Reg02ComponentRepeatedNormalizationIsByteStableAndMirrorIsExact(): Unit {
        let fixture = p4ContextFixture("reg")
        @Expect(fixture.ok, true)
        let raw = RawRecord()
        raw.sourceId = "official:${fixture.root}/src/a.cj"
        raw.title = "A"
        raw.content = "${fixture.root}/src/a.cj /v1/search https://example.invalid/a"
        raw.metadata.sourceId = raw.sourceId
        raw.metadata.repo = "official/repository"
        raw.metadata.path = "${fixture.root}/src/a.cj"
        raw.contentHash = cangjieTypedRecordContentHash(raw.sourceId, raw.content)
        let first = normalizeCkbRawRecordPortablePaths(raw, fixture.context)
        let second = normalizeCkbRawRecordPortablePaths(raw, fixture.context)
        @Expect(first.ok, true)
        @Expect(second.ok, true)
        @Expect(canonicalCkbPortableRawRecord(first.record),
            canonicalCkbPortableRawRecord(second.record))
        @Expect(first.record.content.contains("/v1/search"), true)
        @Expect(first.record.content.contains("https://example.invalid/a"), true)

        let typedA = p4TypedProofRecord(fixture.root, "a")
        let typedB = p4TypedProofRecord(fixture.root, "b")
        let typedAOut = normalizeCkbTypedRecordPortablePaths(typedA, fixture.context)
        let typedBOut = normalizeCkbTypedRecordPortablePaths(typedB, fixture.context)
        let rawA = p4RawProofRecord(fixture.root, "a")
        let rawB = p4RawProofRecord(fixture.root, "b")
        let rawAOut = normalizeCkbRawRecordPortablePaths(rawA, fixture.context)
        let rawBOut = normalizeCkbRawRecordPortablePaths(rawB, fixture.context)
        @Expect(typedAOut.ok && typedBOut.ok && rawAOut.ok && rawBOut.ok, true)
        let reordered = buildCkbPortableRecordPreservationProof(
            [typedA, typedB, typedA],
            [typedBOut.record, typedAOut.record, typedAOut.record],
            [rawA, rawB, rawA],
            [rawBOut.record, rawAOut.record, rawAOut.record],
            fixture.context)
        @Expect(reordered.ready, true)
        @Expect(reordered.typedPairCount, 3)
        @Expect(reordered.rawPairCount, 3)
        @Expect(reordered.typedPairAggregateHash.startsWith("sha256:"), true)
        @Expect(reordered.rawPairAggregateHash.startsWith("sha256:"), true)

        let source = String.fromUtf8(
            File.readFrom(Path("../src/ckb_portable_path_normalizer.cj")))
        let mirror = String.fromUtf8(
            File.readFrom(Path("src/ckb_portable_path_normalizer.cj")))
        @Expect(mirror.replace("package cangjie_community_knowledge_base_test",
            "package cangjie_community_knowledge_base"), source)
        p4RemoveFixture(fixture)
    }
}

private class P4ContextFixture {
    public var ok: Bool = false
    public var root: String = ""
    public var context: CkbPortablePathContext = CkbPortablePathContext()
    public init() {}
}

private func p4ContextFixture(id: String): P4ContextFixture {
    let fixture = P4ContextFixture()
    let relativeRoot = Path("target/p4-path-${id}")
    if (exists(relativeRoot)) { remove(relativeRoot, recursive: true) }
    Directory.create(relativeRoot, recursive: true)
    fixture.root = canonicalize(relativeRoot).toString()
    let policy = parseCkbPortablePathPolicy(
        File.readFrom(Path("../reproducibility/manifests/portable-path-policy.json")))
    if (!policy[0].ok) { return fixture }
    let localJson = "{\"schemaVersion\":\"ckb-portable-local-root-map-v1\"," +
        "\"roots\":[{\"sourceId\":\"official\",\"kind\":\"PROJECT_ROOT\"," +
        "\"localRoot\":\"${fixture.root}\"}]}"
    let local = parseCkbPortableLocalRootMap(localJson.toArray())
    if (!local[0].ok || !validateCkbPortableLocalRootMap(local[1], ["official"]).ok) {
        return fixture
    }
    fixture.context.policy = policy[1]
    fixture.context.localRoots = local[1]
    fixture.context.apiRoutes.add("/v1/search")
    fixture.ok = validateCkbPortablePathContext(fixture.context).ok
    fixture
}

private func p4RemoveFixture(fixture: P4ContextFixture): Unit {
    if (fixture.root != "" && exists(Path(fixture.root))) {
        remove(Path(fixture.root), recursive: true)
    }
}

private func p4TypedProofRecord(root: String, id: String): CangjieTypedRecord {
    let record = CangjieTypedRecord()
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.sourceId = "official:${root}/docs/${id}.md"
    record.title = "Document ${id}"
    record.content = "read ${root}/src/${id}.cj"
    record.citation = "${root}/docs/${id}.md:1"
    record.path = "${root}/docs/${id}.md"
    record.sourceRef = "https://example.invalid/${id}"
    record.contentHash = cangjieTypedRecordContentHash(record.sourceId, record.content)
    record
}

private func p4RawProofRecord(root: String, id: String): RawRecord {
    let record = RawRecord()
    record.sourceId = "official:${root}/atoms/${id}.json"
    record.title = "Atom ${id}"
    record.content = "read ${root}/src/${id}.cj"
    record.metadata.sourceId = record.sourceId
    record.metadata.repo = "official/repository"
    record.metadata.path = "${root}/atoms/${id}.json"
    record.contentHash = cangjieTypedRecordContentHash(record.sourceId, record.content)
    record
}
