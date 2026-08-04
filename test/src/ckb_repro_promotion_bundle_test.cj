package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbReproPromotionBundleTest {
    @TestCase
    public func p4P9UtPromotionLayoutRequiresSameBundleRuntimeAssets(): Unit {
        let assets = p4PromotionRequiredAssets()
        @Expect(validateCkbReproPromotionBundleLayout(assets).ok, true)
        let additional = CkbReproBundleAsset()
        additional.relativePath = "ckb-public-reference-evidence.tar.zst"
        additional.bytes = "additional-evidence".toArray()
        additional.size = additional.bytes.size
        additional.sha256 = ckbReproBundleHash(additional.bytes)
        additional.inputKind = "verified_input"
        additional.role = "p5_public_evidence"
        additional.logicalAsset = additional.relativePath
        additional.partIndex = 0; additional.partCount = 1
        additional.logicalSize = additional.size
        additional.logicalSha256 = additional.sha256
        assets.add(additional)
        @Expect(validateCkbReproPromotionBundleLayout(assets).ok, true)

        let missing = p4PromotionRequiredAssets()
        missing.remove(at: missing.size - 1)
        @Expect(validateCkbReproPromotionBundleLayout(missing).diagnostic,
            "promotion_bundle_layout_invalid")

        let wrongRole = p4PromotionRequiredAssets()
        wrongRole[wrongRole.size - 1].role = "p4_build_proof"
        @Expect(validateCkbReproPromotionBundleLayout(wrongRole).diagnostic,
            "promotion_bundle_layout_invalid")
    }

    @TestCase
    public func p4P9PosPromotionCaptureStreamsLargeAssetsToOwnedRoot(): Unit {
        let parent = Path("target/p4-promotion-capture-仓颉🙂")
        if (exists(parent)) { remove(parent, recursive: true) }
        Directory.create(parent, recursive: true)
        let bundle = parent.join("bundle")
        let owned = parent.join("owned")
        Directory.create(bundle)
        try {
            let assets = p4PromotionRequiredAssets()
            for (asset in assets) {
                let target = bundle.join(asset.relativePath)
                if (!exists(target.parent)) {
                    Directory.create(target.parent, recursive: true)
                }
                File.writeTo(target, asset.bytes)
            }
            File.writeTo(bundle.join("RELEASE-MANIFEST.json"),
                writeCkbReproReleaseManifest(assets).toArray())
            let captured = captureCkbReproPromotionRuntimeAssets(
                canonicalize(bundle).toString(),
                canonicalize(parent).join("owned").toString(),
                CkbReproFilesystemBundleReadBackend())
            @Expect(captured.contract.diagnostic, "ok")
            @Expect(captured.contract.ok, true)
            @Expect(captured.control.bytes.size, 7)
            @Expect(exists(Path(captured.logicalSnapshotPath)), true)
            @Expect(exists(Path(captured.qdrantSnapshotPath)), true)
            @Expect(File.readFrom(Path(captured.logicalSnapshotPath)).size,
                p4PromotionLargeText().size)
            @Expect(File.readFrom(Path(captured.qdrantSnapshotPath)).size,
                p4PromotionLargeBinary().size)
            @Expect(cleanupCkbReproPromotionRuntimeAssets(captured), true)
            @Expect(exists(owned), false)
        } finally {
            if (exists(parent)) { remove(parent, recursive: true) }
        }
    }

    @TestCase
    public func p4P9NegPromotionCaptureRejectsInvalidUtf8Control(): Unit {
        let parent = Path("target/p4-promotion-invalid-encoding")
        if (exists(parent)) { remove(parent, recursive: true) }
        Directory.create(parent, recursive: true)
        let bundle = parent.join("bundle")
        let owned = canonicalize(parent).join("owned")
        Directory.create(bundle)
        try {
            let assets = p4PromotionRequiredAssets()
            for (asset in assets) {
                if (asset.relativePath == "qdrant-snapshot-manifest.json") {
                    asset.bytes = [0xff, 0xfe]
                    asset.size = asset.bytes.size
                    asset.sha256 = ckbReproBundleHash(asset.bytes)
                    asset.logicalSize = asset.size
                    asset.logicalSha256 = asset.sha256
                }
                let target = bundle.join(asset.relativePath)
                if (!exists(target.parent)) {
                    Directory.create(target.parent, recursive: true)
                }
                File.writeTo(target, asset.bytes)
            }
            File.writeTo(bundle.join("RELEASE-MANIFEST.json"),
                writeCkbReproReleaseManifest(assets).toArray())
            let captured = captureCkbReproPromotionRuntimeAssets(
                canonicalize(bundle).toString(), owned.toString(),
                CkbReproFilesystemBundleReadBackend())
            @Expect(captured.contract.ok, false)
            @Expect(captured.contract.diagnostic,
                "bundle_text_encoding_invalid")
            @Expect(exists(owned), false)
        } finally {
            if (exists(parent)) { remove(parent, recursive: true) }
        }
    }

    @TestCase
    public func p4P9UtRuntimeBindingsRejectCrossBundleSnapshot(): Unit {
        let hash = ckbReproBundleHash("binding".toArray())
        let options = CkbPortablePromotionOptions()
        options.candidateVersion = "portable-v1"
        let logical = CkbLogicalSnapshotManifest()
        logical.portableKnowledgeVersion = options.candidateVersion
        logical.manifestHash = hash
        logical.p3VectorProofHash = hash
        logical.vectorCollection = "ckb-portable-v1"
        logical.vectorCount = 151
        logical.vectorDimension = 1024
        let vector = CkbPortableVectorProof()
        vector.vectorProofHash = hash
        let snapshot = CkbQdrantSnapshotManifest()
        snapshot.snapshotSha256 = hash
        snapshot.logicalManifestHash = hash
        snapshot.vectorProofHash = hash
        snapshot.collection = logical.vectorCollection
        snapshot.points = logical.vectorCount
        snapshot.dimension = logical.vectorDimension
        @Expect(validateCkbPortablePromotionRuntimeBindings(options, snapshot,
            logical, vector, hash).ok, true)

        snapshot.snapshotSha256 = ckbReproBundleHash("other".toArray())
        @Expect(validateCkbPortablePromotionRuntimeBindings(options, snapshot,
            logical, vector, hash).diagnostic,
            "promotion_runtime_asset_binding_invalid")
    }
}

private func p4PromotionRequiredAssets(): ArrayList<CkbReproBundleAsset> {
    let out = ArrayList<CkbReproBundleAsset>()
    for (row in [
        ("promotion-candidate.json", "p4_build_proof", "candidate".toArray()),
        ("portable-logical-proof.json", "p4_build_proof", "logical".toArray()),
        ("portable-vector-proof.json", "p4_build_proof", "vector".toArray()),
        ("public-evidence-export.json", "p5_public_evidence", "evidence".toArray()),
        ("reproducibility/manifests/reference-run.json", "p8_reference",
            "reference".toArray()),
        ("release/release-commit.txt", "release_commit", "commit".toArray()),
        ("qdrant-snapshot-manifest.json", "p3_qdrant_snapshot",
            "manifest".toArray()),
        ("ckb-logical-snapshot.tar.zst", "p2_logical_snapshot",
            p4PromotionLargeText()),
        ("qdrant-collection.snapshot", "p3_qdrant_snapshot",
            p4PromotionLargeBinary())
    ]) {
        let asset = CkbReproBundleAsset()
        asset.relativePath = row[0]
        asset.bytes = row[2]
        asset.size = asset.bytes.size
        asset.sha256 = ckbReproBundleHash(asset.bytes)
        asset.inputKind = "verified_input"
        asset.role = row[1]
        asset.logicalAsset = row[0]
        asset.partIndex = 0
        asset.partCount = 1
        asset.logicalSize = asset.size
        asset.logicalSha256 = asset.sha256
        out.add(asset)
    }
    out
}

private func p4PromotionLargeText(): Array<UInt8> {
    let out = ArrayList<UInt8>()
    let chunk = "portable-logical-仓颉🙂\n".toArray()
    for (_ in 0..8192) { for (byte in chunk) { out.add(byte) } }
    out.toArray()
}

private func p4PromotionLargeBinary(): Array<UInt8> {
    let out = ArrayList<UInt8>()
    for (index in 0..262177) {
        out.add(if (index % 2 == 0) { UInt8(0xfe) } else { UInt8(0xff) })
    }
    out.toArray()
}
