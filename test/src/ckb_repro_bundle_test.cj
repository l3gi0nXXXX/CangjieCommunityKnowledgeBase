package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashMap}
import std.unittest.*
import std.unittest.testmacro.*

private class P9FakeBundleBackend <: CkbReproBundleBackend {
    public let roots = HashMap<String, HashMap<String, Array<UInt8>>>()
    public var createCalls: Int64 = 0
    public var removeCalls: Int64 = 0
    public init() {}
    public func rootExists(root: String): Bool { this.roots.contains(root) }
    public func rootIsEmpty(root: String): Bool {
        if (!this.roots.contains(root)) { return false }
        this.roots[root].size == 0
    }
    public func createRoot(root: String): Bool {
        if (this.roots.contains(root)) { return false }
        this.roots[root] = HashMap<String, Array<UInt8>>()
        this.createCalls += 1
        true
    }
    public func read(root: String, relativePath: String): Array<UInt8> {
        if (!this.roots.contains(root) ||
            !this.roots[root].contains(relativePath)) { return Array<UInt8>() }
        this.roots[root][relativePath]
    }
    public func write(root: String, relativePath: String,
        bytes: Array<UInt8>): Bool {
        if (!this.roots.contains(root)) { return false }
        this.roots[root][relativePath] = bytes
        true
    }
    public func removeRoot(root: String): Bool {
        if (this.roots.contains(root)) { this.roots.remove(root) }
        this.removeCalls += 1
        true
    }
}

@Test
public class CkbReproBundleTest {
    @TestCase
    public func p9Ut01BundleAndGateContractComponent(): Unit {
        let first = p9Assets(false)
        let second = p9Assets(true)
        @Expect(computeCkbReproBundleInputSetHash(first),
            computeCkbReproBundleInputSetHash(second))
        let manifest = writeCkbReproReleaseManifest(first)
        let sums = writeCkbReproSha256Sums(first)
        @Expect(manifest.contains("RELEASE-MANIFEST.json"), false)
        @Expect(manifest.contains("SHA256SUMS"), false)
        @Expect(sums.contains("SHA256SUMS"), false)
        @Expect(sums.contains("SHA256SUMS.sig"), false)
    }

    @TestCase
    public func p9Bnd01BundleContractComponent(): Unit {
        for (path in ["", "/tmp/a", "../a", "a/../b", "a\\b",
            "a\nb", "private-runs/result.json"]) {
            @Expect(validateCkbReproBundleRelativePath(path).ok, false)
        }
        @Expect(validateCkbReproBundleRelativePath("资料/结果🙂.json").ok, true)
        @Expect(validateCkbReproBundleRelativePathBytes([0xff, 0xfe]).diagnostic,
            "invalid_response_encoding")
        @Expect(planCkbReproAssetParts("asset.bin", 0).size, 1)
        @Expect(planCkbReproAssetParts("asset.bin",
            2 * 1024 * 1024 * 1024 - 1).size, 1)
        @Expect(planCkbReproAssetParts("asset.bin",
            2 * 1024 * 1024 * 1024).size, 2)
        let tooMany = ArrayList<CkbReproBundleAsset>()
        for (i in 0..1001) { tooMany.add(p9Asset("assets/${i}.txt", "${i}")) }
        @Expect(validateCkbReproBundleAssets(tooMany).diagnostic,
            "bundle_asset_count_exceeded")
        let forbidden = p9BundleOptions("/tmp/ckb-p9/worktree/output")
        @Expect(assembleCkbUnsignedReleaseCandidate(forbidden, p9Assets(false),
            P9FakeBundleBackend()).diagnostic, "bundle_output_forbidden")
        let existingBackend = P9FakeBundleBackend()
        @Expect(existingBackend.createRoot("/tmp/ckb-p9/existing"), true)
        @Expect(assembleCkbUnsignedReleaseCandidate(
            p9BundleOptions("/tmp/ckb-p9/existing"), p9Assets(false),
            existingBackend).diagnostic, "bundle_output_exists")
    }

    @TestCase
    public func p9Neg01BundleAndGateContractComponent(): Unit {
        let duplicate = p9Assets(false)
        duplicate.add(p9Asset("assets/a.txt", "different"))
        @Expect(validateCkbReproBundleAssets(duplicate).diagnostic,
            "bundle_asset_duplicate")
        let self = p9Assets(false)
        self.add(p9Asset("RELEASE-MANIFEST.json", "self"))
        @Expect(validateCkbReproBundleAssets(self).diagnostic,
            "bundle_derived_asset_forbidden")
        let backend = P9FakeBundleBackend()
        let options = p9BundleOptions("/tmp/ckb-p9/unsigned")
        let tampered = p9Assets(false)
        tampered[0].sha256 = ckbReproBundleHash("tampered".toArray())
        let result = assembleCkbUnsignedReleaseCandidate(options, tampered,
            backend)
        @Expect(result.ok, false)
        @Expect(result.diagnostic, "bundle_asset_hash_mismatch")
        @Expect(backend.createCalls, 0)
        let finalizeResult = finalizeCkbReproReleaseBundle(
            p9BundleOptions("/tmp/ckb-p9/final"), p9Assets(false),
            ckbReproBundleHash("wrong-input-set".toArray()), backend)
        @Expect(finalizeResult.diagnostic, "bundle_verified_input_changed")
        @Expect(backend.rootExists("/tmp/ckb-p9/final"), false)
    }

    @TestCase
    public func p9Reg01BundleContractComponent(): Unit {
        let backend = P9FakeBundleBackend()
        let first = p9BundleOptions("/tmp/ckb-p9/unsigned-a")
        let second = p9BundleOptions("/tmp/ckb-p9/unsigned-b")
        let a = assembleCkbUnsignedReleaseCandidate(first, p9Assets(false),
            backend)
        let b = assembleCkbUnsignedReleaseCandidate(second, p9Assets(true),
            backend)
        @Expect(a.ok, true)
        @Expect(b.ok, true)
        @Expect(a.inputSetHash, b.inputSetHash)
        @Expect(a.treeHash, b.treeHash)
        @Expect(backend.read(first.outputRoot, "assets/a.txt"),
            "alpha".toArray())
        @Expect(backend.read(first.outputRoot, "assets/b.txt"),
            "仓颉🙂".toArray())
    }
}

private func p9Asset(path: String, value: String): CkbReproBundleAsset {
    let asset = CkbReproBundleAsset()
    asset.relativePath = path
    asset.bytes = value.toArray()
    asset.size = asset.bytes.size
    asset.sha256 = ckbReproBundleHash(asset.bytes)
    asset.inputKind = "verified_input"
    asset
}

private func p9Assets(reverse: Bool): ArrayList<CkbReproBundleAsset> {
    let out = ArrayList<CkbReproBundleAsset>()
    let a = p9Asset("assets/a.txt", "alpha")
    let b = p9Asset("assets/b.txt", "仓颉🙂")
    if (reverse) { out.add(b); out.add(a) } else { out.add(a); out.add(b) }
    out
}

private func p9BundleOptions(output: String): CkbReproBundleOptions {
    let options = CkbReproBundleOptions()
    options.outputRoot = output
    options.worktreeRoot = "/tmp/ckb-p9/worktree"
    options.productionRoot = "/tmp/ckb-p9/ckb-data"
    options.privateRunRoot = "/tmp/ckb-p9/private-runs"
    options.userConfigRoot = "/tmp/ckb-p9/config"
    options
}
