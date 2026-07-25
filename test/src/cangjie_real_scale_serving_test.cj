package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.File
import std.process.*
import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*

private class RealScaleServingBuildObserver <: CangjieServingIndexBuildObserver {
    public var count: Int64 = 0
    public var lastRecordCount: Int64 = 0
    public init() {}
    public func onServingIndexBuild(recordCount: Int64): Unit {
        this.count += 1
        this.lastRecordCount = recordCount
    }
}

@Test
public class CangjieRealScaleServingTest {
    private func root(name: String): String {
        "target/${name}-${DateTime.now().toUnixTimeStamp().toMilliseconds()}"
    }

    private func activeStore(name: String): FileKnowledgeStore {
        let store = FileKnowledgeStore(this.root(name))
        @Expect(r7CleanKnowledgeBase().persistActiveSnapshot(store).ok, true)
        store
    }

    @TestCase
    public func studentProjectionIsSharedAcrossRestStdioAndHttpAndRebuiltOnceOnReload(): Unit {
        let store = this.activeStore("real-scale-serving-cache")
        let observer = RealScaleServingBuildObserver()
        let service = CkbCommandLoopService(CkbRuntimeConfig(), store,
            studentServingBuildObserver: observer)
        _ = service.start()
        let context = "{\"taskId\":\"缓存-中文🙂\",\"benchmark\":\"generic\",\"taskText\":\"Use ArrayList.add\",\"signature\":\"func sample(): Unit\",\"targetVersion\":\"1.0.0\",\"sourceSet\":\"all\",\"versionPolicy\":\"default\"}"
        let parity = ckbAbcdeProbeInProcessTransportParity(service, "缓存-中文🙂", context)

        @Expect(parity.ok, true)
        @Expect(observer.count, 1)
        _ = service.handleLine("restart")
        @Expect(observer.count, 2)
        @Expect(service.cangjieTaskKnowledgePack(ckbRealScaleTaskRequest()).knowledgeVersion,
            store.loadActiveSnapshotPointer().activeVersion)
        @Expect(observer.count, 2)
    }

    @TestCase
    public func studentProjectionVersionDriftAndPollutedRecordFailClosed(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(ckbRealScaleRecord("clean", "Reusable ArrayList.add knowledge", "knowledge-v1"))
        let polluted = ckbRealScaleRecord("CJ-HUMANEVAL-145", "hidden_test reference solution", "knowledge-v1")
        polluted.metadata.path = "teacher-solutions/CJ-HUMANEVAL-145.cj"
        records.add(polluted)
        let projection = buildCangjieStudentServingProjection(records, "knowledge-v1")

        @Expect(cangjieStudentServingProjectionDiagnostic(projection, "knowledge-v1"),
            "student_knowledge_leakage_blocked")
        @Expect(projection.valid, false)
        @Expect(projection.index.records.size, 1)
        @Expect(cangjieStudentServingProjectionDiagnostic(projection, "knowledge-v2"),
            "student_serving_projection_version_drift")

        let allPolluted = ArrayList<NormalizedRecord>()
        allPolluted.add(polluted)
        let rejected = buildCangjieStudentServingProjection(allPolluted, "knowledge-v1")
        @Expect(rejected.valid, false)
        @Expect(rejected.diagnostic, "student_knowledge_leakage_blocked")

        let kb = newOfflineKnowledgeBase()
        kb.stageCandidateRecords("knowledge-v1", records)
        @Expect(kb.promoteCandidateToActive("knowledge-v1"), true)
        let store = FileKnowledgeStore(this.root("mixed-polluted-runtime"))
        @Expect(kb.persistActiveSnapshot(store).ok, true)
        let before = ckbActiveSnapshotPointerIdentityHash(
            store.loadActiveSnapshotPointer())
        let request = CangjieTaskKnowledgeRequest()
        request.taskId = "mixed-projection"
        request.taskText = "ArrayList add"
        request.versionSelector.targetVersion = "1.0.0"
        let pack = CkbCommandLoopService(CkbRuntimeConfig(), store)
            .cangjieTaskKnowledgePack(request)
        @Expect(pack.diagnostics.contains("student_knowledge_leakage_blocked"), true)
        @Expect(ckbActiveSnapshotPointerIdentityHash(
            store.loadActiveSnapshotPointer()), before)
    }

    @TestCase
    public func emptyStudentProjectionPreservesEmptyDiagnostic(): Unit {
        let observer = RealScaleServingBuildObserver()
        let projection = KnowledgeBase(FakeClock(0)).prepareStudentServingProjection(
            buildObserver: observer)
        @Expect(projection.valid, false)
        @Expect(projection.diagnostic, "student_serving_projection_empty")
        @Expect(observer.count, 1)
    }

    @TestCase
    public func derivedServingDocumentRejectionFailsWholeRuntimeWithoutPointerMutation(): Unit {
        let record = ckbRealScaleRecord("derived-negative",
            "ArrayList generic documentation", "knowledge-v1")
        record.metadata.sourceSet = ""
        record.metadata.sourceType = SourceTypes.DERIVED
        @Expect(cangjieStudentRecordDiagnostic(record).ok, true)
        let records = ArrayList<NormalizedRecord>(); records.add(record)
        let projection = buildCangjieStudentServingProjection(records,
            "knowledge-v1")
        @Expect(projection.valid, false)
        @Expect(projection.diagnostic, "student_knowledge_leakage_blocked")
        @Expect(projection.index.records.size, 1)
        @Expect(ckbRealScaleHasDiagnostic(projection.index.diagnostics,
            "serving_projection_rejected:"), true)

        let kb = newOfflineKnowledgeBase()
        kb.stageCandidateRecords("knowledge-v1", records)
        @Expect(kb.promoteCandidateToActive("knowledge-v1"), true)
        let store = FileKnowledgeStore(this.root("derived-rejection-runtime"))
        @Expect(kb.persistActiveSnapshot(store).ok, true)
        let before = ckbActiveSnapshotPointerIdentityHash(
            store.loadActiveSnapshotPointer())
        let request = CangjieTaskKnowledgeRequest()
        request.taskId = "derived-rejection"
        request.taskText = "ArrayList"
        request.versionSelector.targetVersion = "1.0.0"
        let pack = CkbCommandLoopService(CkbRuntimeConfig(), store)
            .cangjieTaskKnowledgePack(request)
        @Expect(pack.diagnostics.contains("student_knowledge_leakage_blocked"), true)
        @Expect(ckbActiveSnapshotPointerIdentityHash(
            store.loadActiveSnapshotPointer()), before)
    }

    @TestCase
    public func realScaleProjectionBuilds7373StudentRecordsExactlyOnce(): Unit {
        let records = ArrayList<NormalizedRecord>()
        for (i in 0..7373) {
            records.add(ckbRealScaleRecord("scale-${i}", "Reusable collection rule ${i}", "knowledge-v1"))
        }
        let observer = RealScaleServingBuildObserver()
        let projection = buildCangjieStudentServingProjection(records, "knowledge-v1",
            buildObserver: observer)
        @Expect(projection.valid, true)
        @Expect(projection.records.size, 7373)
        @Expect(projection.index.records.size, 7373)
        @Expect(observer.count, 1)
        @Expect(observer.lastRecordCount, 7373)
    }

    @TestCase
    public func certificationIdentityIsPreparedOnceFromBoundServiceAndUsesPointerGuard(): Unit {
        let store = this.activeStore("real-scale-identity")
        let service = CkbCommandLoopService(CkbRuntimeConfig(), store)
        let before = store.activeSnapshotMaterializationCount()
        let identity = prepareCkbCertificationHttpIdentity(service, store)
        let afterPrepare = store.activeSnapshotMaterializationCount()

        @Expect(identity.valid, true)
        @Expect(afterPrepare, before)
        for (_ in 0..100) {
            let response = handlePreparedCkbCertificationHttpRequest(identity, store, "GET",
                "/v1/certification/identity", "", [], CkbHttpServiceConfig())
            @Expect(response.statusCode, 200)
        }
        @Expect(store.activeSnapshotMaterializationCount(), afterPrepare)

        let cloneRoot = this.root("real-scale-identity-clone")
        @Expect(launch("/bin/cp", ["-R", store.root.toString(), cloneRoot]).wait(), 0)
        let clone = FileKnowledgeStore(cloneRoot)
        @Expect(ckbActiveSnapshotPointerIdentityHash(clone.loadActiveSnapshotPointer()),
            identity.pointerIdentityHash)
        let cloneIdentity = prepareCkbCertificationHttpIdentity(service, clone)
        @Expect(cloneIdentity.diagnostic, "certification_identity_service_store_mismatch")
        @Expect(cloneIdentity.responseBody.contains(store.root.toString()), false)
        @Expect(cloneIdentity.responseBody.contains(clone.root.toString()), false)

        _ = service.handleLine("restart")
        let afterReload = prepareCkbCertificationHttpIdentity(service, store)
        @Expect(afterReload.valid, true)
        @Expect(afterReload.pointerIdentityHash, identity.pointerIdentityHash)

        let unrelated = CkbCommandLoopService(CkbRuntimeConfig(),
            FileKnowledgeStore(this.root("real-scale-identity-unrelated")))
        @Expect(prepareCkbCertificationHttpIdentity(unrelated, store).diagnostic,
            "certification_identity_service_store_mismatch")

        let pointerPath = store.root.join("metadata/active-snapshot.manifest")
        let original = store.readText("metadata/active-snapshot.manifest")
        store.writeLinesAtomically("metadata/active-snapshot.manifest",
            original.replace("active=", "active=漂移🙂"))
        let drift = handlePreparedCkbCertificationHttpRequest(identity, store, "GET",
            "/v1/certification/identity", "", [], CkbHttpServiceConfig())
        @Expect(drift.statusCode, 409)
        @Expect(drift.body.contains("certification_identity_drift"), true)
        @Expect(drift.body.contains(pointerPath.toString()), false)
        File.writeTo(pointerPath, [0xff, 0xfe])
        let malformed = handlePreparedCkbCertificationHttpRequest(identity, store, "GET",
            "/v1/certification/identity", "", [], CkbHttpServiceConfig())
        @Expect(malformed.statusCode, 409)
        @Expect(malformed.body.contains("certification_identity_drift"), true)
    }

    @TestCase
    public func readinessAndFrozenPointerGuardsAreBoundedAndFailClosed(): Unit {
        @Expect(ckbAbcdeCertificationReadinessDeadlineMillis() >= 60000, true)
        @Expect(ckbAbcdeDevelopmentToolProbeTimeoutSeconds(), 30)
        @Expect(ckbAbcdeCertificationProbeMaxTimeSeconds(0), 0)
        @Expect(ckbAbcdeCertificationProbeMaxTimeSeconds(999), 0)
        @Expect(ckbAbcdeCertificationProbeMaxTimeSeconds(1000), 1)
        @Expect(ckbAbcdeCertificationProbeMaxTimeSeconds(29999), 29)
        @Expect(ckbAbcdeCertificationProbeMaxTimeSeconds(30000), 30)
        @Expect(ckbAbcdeCertificationProbeMaxTimeSeconds(60000), 30)
        @Expect(ckbAbcdeCertificationIdentityResponseDiagnostic(
            "{\"ok\":true,\"data\":{\"activeVersion\":\"知识🙂\",\"pointerIdentityHash\":\"sha256:pointer\",\"candidateChecksum\":\"sha256:checksum\"}}",
            "知识🙂", "sha256:pointer", "sha256:checksum"), "ok")
        @Expect(ckbAbcdeCertificationIdentityResponseDiagnostic(
            "{\"ok\":true,\"data\":{\"activeVersion\":\"wrong\",\"pointerIdentityHash\":\"sha256:pointer\",\"candidateChecksum\":\"sha256:checksum\"}}",
            "知识🙂", "sha256:pointer", "sha256:checksum"), "certification_http_identity_mismatch")
        @Expect(ckbAbcdeCertificationIdentityResponseDiagnostic(
            "{\"ok\":false,\"data\":{\"activeVersion\":\"知识🙂\",\"pointerIdentityHash\":\"sha256:pointer\",\"candidateChecksum\":\"sha256:checksum\"}}",
            "知识🙂", "sha256:pointer", "sha256:checksum"), "certification_http_identity_mismatch")
        @Expect(ckbAbcdeCertificationIdentityResponseDiagnostic("{", "知识🙂",
            "sha256:pointer", "sha256:checksum"), "certification_http_identity_malformed")

        let store = this.activeStore("real-scale-pointer")
        let manifest = ckbBuildFrozenCandidateSeal(store, ckbRealScaleFrozenControl(store))
        @Expect(manifest.diagnostic, "ok")
        let materializations = store.activeSnapshotMaterializationCount()
        @Expect(ckbAbcdeFrozenPointerDiagnostic(store, manifest.manifestJson), "ok")
        @Expect(store.activeSnapshotMaterializationCount(), materializations)
        store.writeLinesAtomically("metadata/active-snapshot.manifest",
            store.readText("metadata/active-snapshot.manifest").replace("active=", "active=漂移🙂"))
        @Expect(ckbAbcdeFrozenPointerDiagnostic(store, manifest.manifestJson),
            "frozen_candidate_store_drift")
    }

    @TestCase
    public func taskKnowledgeJsonParsingHandlesEmojiMalformedWrongTypesAndDuplicateKeys(): Unit {
        let store = this.activeStore("real-scale-json")
        let service = CkbCommandLoopService(CkbRuntimeConfig(), store)
        let emoji = ckbApiHandle(service, "POST", "/v1/cangjie/task-knowledge-pack",
            "{\"taskId\":\"仓颉🙂\",\"taskText\":\"数组🙂\",\"signature\":\"func solve(): Unit\",\"imports\":[\"std.collection.*\",\"中文🙂\"]}", [])
        @Expect(emoji.contains("\"ok\":true"), true)
        @Expect(emoji.contains("\"taskId\":\"仓颉🙂\""), true)

        let malformed = ckbApiHandle(service, "POST", "/v1/cangjie/task-knowledge-pack",
            "{\"taskId\":\"仓颉🙂\"", [])
        @Expect(malformed.contains("\"ok\":false"), true)
        @Expect(malformed.contains("\"code\":\"ckb.bad_request\""), true)

        let wrongTypes = ckbApiHandle(service, "POST", "/v1/cangjie/task-knowledge-pack",
            "{\"taskId\":7,\"taskText\":false,\"signature\":[],\"imports\":\"not-an-array\"}", [])
        @Expect(wrongTypes.contains("\"ok\":false"), true)
        @Expect(wrongTypes.contains("\"code\":\"ckb.bad_request\""), true)

        let duplicate = ckbApiHandle(service, "POST", "/v1/cangjie/task-knowledge-pack",
            "{\"taskId\":\"first\",\"taskId\":\"second🙂\",\"taskText\":\"数组\",\"signature\":\"func solve(): Unit\"}", [])
        @Expect(duplicate.contains("\"ok\":true"), true)
        @Expect(duplicate.contains("\"taskId\":\"second🙂\""), true)
        @Expect(duplicate.contains("\"taskId\":\"first\""), false)
    }
}

private func ckbRealScaleTaskRequest(): CangjieTaskKnowledgeRequest {
    let request = CangjieTaskKnowledgeRequest()
    request.taskId = "缓存-中文🙂"
    request.benchmark = "generic"
    request.taskText = "Use ArrayList.add"
    request.signature = "func sample(): Unit"
    request.versionSelector.targetVersion = "1.0.0"
    request.versionSelector.sourceSet = CangjieSourceSets.ALL
    request
}

private func ckbRealScaleRecord(id: String, content: String, version: String): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = id
    record.recordKind = ""
    record.title = content
    record.chunk = content
    record.citation = "https://docs.cangjie-lang.cn/docs/1.0.0/"
    record.metadata.sourceId = id
    record.metadata.sourceType = SourceTypes.DOC
    record.metadata.sourceUrl = record.citation
    record.metadata.targetVersion = "1.0.0"
    record.metadata.sourceSet = CangjieSourceSets.DOCS
    record.metadata.knowledgeVersion = version
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}

private func ckbRealScaleHasDiagnostic(values: ArrayList<String>, prefix: String): Bool {
    for (value in values) {
        if (value.startsWith(prefix)) {
            return true
        }
    }
    false
}

private func ckbRealScaleFrozenControl(store: FileKnowledgeStore): CkbFrozenCandidateSealOptions {
    let snapshot = store.loadActiveSnapshot()
    let artifacts = ckbS2ReleaseV2ArtifactsForTest(snapshot.normalizedRecords)
    let seal = ckbRenderCandidateTrustSeal(snapshot.normalizedRecords,
        artifacts[0], artifacts[1], artifacts[2], artifacts[3],
        restText: artifacts[4], mcpStdioText: artifacts[5],
        mcpHttpText: artifacts[6], anonymousQueryText: artifacts[7])
    let control = CkbFrozenCandidateSealOptions()
    control.expectedKnowledgeVersion = snapshot.activeVersion
    control.expectedCandidateChecksum = ckbCertifiedNormalizedRecordsChecksum(snapshot.normalizedRecords)
    control.inputHash = benchmarkGapSha256("input")
    control.configHash = benchmarkGapSha256("config")
    control.modelHash = benchmarkGapSha256("model")
    control.studentLeakageProofJson = seal
    control.studentLeakageArtifactJson = artifacts[0]
    control.anonymousQueryArtifactJson = artifacts[1]
    control.authorityIsolationArtifactJson = artifacts[2]
    control.atomTestArtifactJson = artifacts[3]
    control.restLeakageArtifactJson = artifacts[4]
    control.mcpStdioLeakageArtifactJson = artifacts[5]
    control.mcpHttpLeakageArtifactJson = artifacts[6]
    control.anonymousAtomQueryArtifactJson = artifacts[7]
    control
}
