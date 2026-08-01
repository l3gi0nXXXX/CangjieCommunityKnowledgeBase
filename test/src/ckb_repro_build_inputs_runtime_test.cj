package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

private func p4RuntimeBuildInputAsset(role: String):
    CkbReproBuildInputAsset {
    let out = CkbReproBuildInputAsset()
    out.role = role
    out.relativePath = "inputs/${role}.json"
    out.size = 2
    out.sha256 = benchmarkGapSha256("{}")
    out
}

private func p4RuntimeBuildInputManifest(): CkbReproBuildInputManifest {
    let out = CkbReproBuildInputManifest()
    out.schemaVersion = "ckb-repro-build-inputs-v1"
    out.candidateVersion = "portable-v1"
    out.targetVersion = "1.0.0"
    out.expectedRawCount = 1
    for (role in ckbReproPublicBuildInputRoles()) {
        out.assets.add(p4RuntimeBuildInputAsset(role))
    }
    out
}

private class P4RuntimeMaterialBackend <: CkbReproSourceMaterialBackend {
    public var calls: Int64 = 0
    public func fetch(entry: CkbReproSourceMaterialEntry):
        CkbReproBackendResult {
        this.calls += 1; CkbReproBackendResult(true, entry.expectedHash)
    }
    public func generate(entry: CkbReproSourceMaterialEntry):
        CkbReproBackendResult {
        this.calls += 1; CkbReproBackendResult(true, entry.expectedHash)
    }
}

@Test
public class CkbReproBuildInputsRuntimeTest {
    @TestCase
    public func publicInventoryIdentityIsThirdPartyRecomputableSha256(): Unit {
        let typed = CangjieTypedRecord()
        typed.recordKind = CangjieTypedRecordKinds.DOC_SECTION
        typed.sourceId = "docs/a"; typed.content = "仓颉🙂"
        typed.contentHash = cangjieTypedRecordContentHash(
            typed.sourceId, typed.content)
        let expected = benchmarkGapSha256(
            "ckb-public-record-identity-v1|typed|" +
            canonicalCkbPortableTypedRecord(typed))
        @Expect(ckbReproPublicTypedRecordIdentity(typed), expected)
        let typedRows = ArrayList<CangjieTypedRecord>(); typedRows.add(typed)
        let inventory = inventoryCkbPublicKnowledgeSources(
            typedRows, ArrayList<RawRecord>())
        @Expect(inventory.size, 1)
        @Expect(inventory[0].identity, expected)
    }

    @TestCase
    public func publicManifestExcludesPrivateAndDerivedInputs(): Unit {
        let manifest = p4RuntimeBuildInputManifest()
        @Expect(validateCkbReproBuildInputManifest(manifest).ok, true)
        for (forbidden in ["local_root_map", "eval_support_authority",
            "leakage_authority", "typed_input", "raw_input"]) {
            let invalid = p4RuntimeBuildInputManifest()
            invalid.assets.add(p4RuntimeBuildInputAsset(forbidden))
            @Expect(validateCkbReproBuildInputManifest(invalid).diagnostic,
                "build_inputs_role_contract_invalid")
        }
    }

    @TestCase
    public func missingPrivateCapabilityFailsBeforeSourceMaterialCalls(): Unit {
        let backend = P4RuntimeMaterialBackend()
        let context = CkbReproPrivateBuildContext()
        let result = assembleCkbReproProductionBuildRequest(
            p4RuntimeBuildInputManifest(), CkbReproBuildInputPayloads(),
            context, backend, CkbFirstInitReproSourceAssembler(),
            CkbHmacSha256PathIdProvider("fixture-key".toArray()))
        @Expect(result.ok, false)
        @Expect(result.diagnostic, "build_private_capability_required")
        @Expect(backend.calls, 0)
    }
}
