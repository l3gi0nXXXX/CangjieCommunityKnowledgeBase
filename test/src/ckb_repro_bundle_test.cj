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

private class P9FakeBundleReadBackend <: CkbReproBundleReadBackend {
    public let roots = HashMap<String, HashMap<String, Array<UInt8>>>()
    public let listings =
        HashMap<String, ArrayList<CkbReproBundleReadEntry>>()
    public let secondListings =
        HashMap<String, ArrayList<CkbReproBundleReadEntry>>()
    public var rootExistsCalls: Int64 = 0
    public var listCalls: Int64 = 0
    public var readCalls: Int64 = 0
    public var failList: Bool = false
    public var failReadPath: String = ""
    public var secondManifestBytes: Array<UInt8> = Array<UInt8>()
    public var manifestReadCalls: Int64 = 0
    public init() {}
    public func rootExists(root: String): Bool {
        this.rootExistsCalls += 1
        this.roots.contains(root)
    }
    public func list(root: String): ArrayList<CkbReproBundleReadEntry> {
        this.listCalls += 1
        if (this.failList) { throw Exception("fake list failure") }
        if (this.listCalls > 1 && this.secondListings.contains(root)) {
            return this.secondListings[root]
        }
        if (!this.listings.contains(root)) {
            return ArrayList<CkbReproBundleReadEntry>()
        }
        this.listings[root]
    }
    public func read(root: String, relativePath: String): Array<UInt8> {
        this.readCalls += 1
        if (relativePath == this.failReadPath) {
            throw Exception("fake read failure")
        }
        if (relativePath == "RELEASE-MANIFEST.json") {
            this.manifestReadCalls += 1
            if (this.manifestReadCalls > 1 &&
                this.secondManifestBytes.size > 0) {
                return this.secondManifestBytes
            }
        }
        if (!this.roots.contains(root) ||
            !this.roots[root].contains(relativePath)) {
            return Array<UInt8>()
        }
        this.roots[root][relativePath]
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

    @TestCase
    public func p9Ut01BundleReadContract(): Unit {
        let manifestText = writeCkbReproReleaseManifest(p9Assets(false))
        let parsed = parseCkbReproBundleManifest(manifestText.toArray())
        @Expect(parsed[0].ok, true)
        @Expect(parsed[1].schemaVersion,
            "ckb-repro-release-component-v1")
        @Expect(parsed[1].assets.size, 2)
        @Expect(parsed[1].assets[0].relativePath, "assets/a.txt")
        @Expect(parsed[1].assets[1].relativePath, "assets/b.txt")
        @Expect(renderCkbReproBundleManifest(parsed[1]), manifestText)
    }

    @TestCase
    public func p9Bnd01BundleReadContract(): Unit {
        let unicodeAssets = ArrayList<CkbReproBundleAsset>()
        unicodeAssets.add(p9Asset("资料/结果🙂.json", "仓颉🙂"))
        let seeded = p9ReadableBundle("/tmp/ckb-p9/read-unicode",
            unicodeAssets, false)
        @Expect(p9Load(seeded).contract.ok, true)

        let emptyAssets = ArrayList<CkbReproBundleAsset>()
        emptyAssets.add(p9Asset("assets/empty.txt", ""))
        let empty = p9ReadableBundle(
            "/tmp/ckb-p9/read-empty", emptyAssets, false)
        @Expect(p9ParseAndValidate(empty).ok, true)

        @Expect(parseCkbReproBundleManifest([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbReproBundleManifest("{broken".toArray())[0].diagnostic,
            "malformed_json")

        let reordered = writeCkbReproReleaseManifest(p9Assets(false))
            .replace("\"schemaVersion\":\"ckb-repro-release-component-v1\"," +
                "\"inputSetHash\":",
                "\"inputSetHash\":")
        @Expect(parseCkbReproBundleManifest(reordered.toArray())[0].diagnostic,
            "bundle_manifest_field_contract_invalid")

        let quoted = ArrayList<CkbReproBundleAsset>()
        quoted.add(p9Asset("资料/\"结果🙂.json", "仓颉🙂"))
        let quotedManifest = writeCkbReproReleaseManifest(quoted)
        let quotedParsed =
            parseCkbReproBundleManifest(quotedManifest.toArray())
        @Expect(quotedParsed[0].ok, true)
        @Expect(renderCkbReproBundleManifest(quotedParsed[1]),
            quotedManifest)
        @Expect(p9Load(p9ReadableBundle(
            "/tmp/ckb-p9/read-quote", quoted, false)).contract.ok, true)
        @Expect(validateCkbReproBundleRelativePath(
            "资料/\t结果.json").diagnostic, "bundle_path_invalid")
    }

    @TestCase
    public func p9Pos01AndP8Pos04BundleReadContract(): Unit {
        let seeded = p9ReadableBundle("/tmp/ckb-p9/read-positive",
            p9Assets(false), true)
        let loaded = p9Load(seeded)
        @Expect(loaded.contract.ok, true)
        @Expect(loaded.contract.canonicalJson,
            writeCkbReproReleaseManifest(p9Assets(false)))
        @Expect(loaded.manifest.assets.size, 2)
        @Expect(loaded.assetProofs.size, 2)
        @Expect(loaded.manifest.assets[0].bytes.size, 0)
        @Expect(loaded.assetProofs[0].sha256,
            loaded.manifest.assets[0].sha256)
        @Expect(loaded.proofSetHash.startsWith("sha256:"), true)
        @Expect(seeded[0].rootExistsCalls, 1)
        @Expect(seeded[0].listCalls, 2)
        @Expect(seeded[0].readCalls, 4)
        seeded[0].roots[seeded[1]]["assets/a.txt"] = "ALPHA".toArray()
        @Expect(loaded.assetProofs[0].sha256,
            loaded.manifest.assets[0].sha256)
    }

    @TestCase
    public func p9Neg01BundleReadContract(): Unit {
        let missingRoot = P9FakeBundleReadBackend()
        @Expect(loadAndValidateCkbReproBundle(
            "/tmp/ckb-p9/missing", missingRoot).contract.diagnostic,
            "bundle_root_missing")

        let extra = p9ReadableBundle("/tmp/ckb-p9/read-extra",
            p9Assets(false), false)
        p9ReadPut(extra[0], extra[1], "unexpected.txt", "extra".toArray())
        @Expect(p9ParseAndValidate(extra).diagnostic,
            "bundle_root_extra_asset")

        let missing = p9ReadableBundle("/tmp/ckb-p9/read-missing",
            p9Assets(false), false)
        missing[0].roots[missing[1]].remove("assets/a.txt")
        missing[0].listings[missing[1]] =
            ArrayList<CkbReproBundleReadEntry>()
        missing[0].listings[missing[1]].add(p9ReadEntry(
            missing[1], "RELEASE-MANIFEST.json",
            missing[0].roots[missing[1]]["RELEASE-MANIFEST.json"]))
        missing[0].listings[missing[1]].add(p9ReadEntry(
            missing[1], "assets/b.txt",
            missing[0].roots[missing[1]]["assets/b.txt"]))
        @Expect(p9ParseAndValidate(missing).diagnostic,
            "bundle_root_missing_asset")

        let duplicateListing = p9ReadableBundle(
            "/tmp/ckb-p9/read-duplicate", p9Assets(false), false)
        duplicateListing[0].listings[duplicateListing[1]].add(
            p9ReadEntry(duplicateListing[1], "assets/a.txt",
                "alpha".toArray()))
        @Expect(p9ParseAndValidate(duplicateListing).diagnostic,
            "bundle_root_asset_duplicate")

        let changedManifest = p9ReadableBundle(
            "/tmp/ckb-p9/read-manifest-change", p9Assets(false), false)
        changedManifest[0].secondManifestBytes = "{}".toArray()
        @Expect(p9ParseAndValidate(changedManifest).diagnostic,
            "bundle_manifest_bytes_changed")

        let tampered = p9ReadableBundle("/tmp/ckb-p9/read-tampered",
            p9Assets(false), false)
        tampered[0].roots[tampered[1]]["assets/a.txt"] =
            "tampered".toArray()
        @Expect(p9ParseAndValidate(tampered).diagnostic,
            "bundle_asset_size_mismatch")

        let sameSizeTampered = p9ReadableBundle(
            "/tmp/ckb-p9/read-hash", p9Assets(false), false)
        sameSizeTampered[0].roots[sameSizeTampered[1]]["assets/a.txt"] =
            "ALPHA".toArray()
        @Expect(p9ParseAndValidate(sameSizeTampered).diagnostic,
            "bundle_asset_hash_mismatch")

        let malformedAsset = writeCkbReproReleaseManifest(p9Assets(false))
            .replace("\"inputKind\":\"verified_input\"",
                "\"inputKind\":\"verified_input\",\"extra\":true")
        @Expect(parseCkbReproBundleManifest(
            malformedAsset.toArray())[0].diagnostic,
            "bundle_manifest_asset_contract_invalid")

        let nonCanonical = writeCkbReproReleaseManifest(p9Assets(false))
            .replace("},{", "}, {")
        @Expect(parseCkbReproBundleManifest(
            nonCanonical.toArray())[0].diagnostic,
            "bundle_manifest_non_canonical")

        let inputMismatch = p9ReadableBundle(
            "/tmp/ckb-p9/read-input-hash", p9Assets(false), false)
        let inputManifest = parseCkbReproBundleManifest(
            inputMismatch[0].read(inputMismatch[1],
                "RELEASE-MANIFEST.json"))[1]
        inputManifest.inputSetHash = ckbReproBundleHash(
            "different-input-set".toArray())
        @Expect(validateCkbReproBundleManifest(inputMismatch[1],
            inputManifest, inputMismatch[0]).diagnostic,
            "bundle_input_set_hash_mismatch")

        let selfManifest = CkbReproBundleManifest()
        selfManifest.schemaVersion = "ckb-repro-release-component-v1"
        selfManifest.assets.add(p9Asset("RELEASE-MANIFEST.json", "self"))
        selfManifest.inputSetHash =
            computeCkbReproBundleInputSetHash(selfManifest.assets)
        @Expect(validateCkbReproBundleManifest("/tmp/ckb-p9/read-self",
            selfManifest, P9FakeBundleReadBackend()).diagnostic,
            "bundle_derived_asset_forbidden")

        let backendFailure = p9ReadableBundle(
            "/tmp/ckb-p9/read-failure", p9Assets(false), false)
        backendFailure[0].failList = true
        @Expect(p9ParseAndValidate(backendFailure).diagnostic,
            "bundle_read_failed")

        let manifestReadFailure = p9ReadableBundle(
            "/tmp/ckb-p9/read-manifest-failure", p9Assets(false), false)
        manifestReadFailure[0].failReadPath = "RELEASE-MANIFEST.json"
        @Expect(p9ParseAndValidate(manifestReadFailure).diagnostic,
            "bundle_read_failed")

        let assetReadFailure = p9ReadableBundle(
            "/tmp/ckb-p9/read-asset-failure", p9Assets(false), false)
        assetReadFailure[0].failReadPath = "assets/a.txt"
        @Expect(p9ParseAndValidate(assetReadFailure).diagnostic,
            "bundle_read_failed")

        for (kind in ["symlink", "directory", "special"]) {
            let unsafeEntry = p9ReadableBundle(
                "/tmp/ckb-p9/read-${kind}", p9Assets(false), false)
            unsafeEntry[0].listings[unsafeEntry[1]][1].kind = kind
            @Expect(p9ParseAndValidate(unsafeEntry).diagnostic,
                "bundle_root_entry_type_invalid")
        }
        let outside = p9ReadableBundle(
            "/tmp/ckb-p9/read-outside", p9Assets(false), false)
        outside[0].listings[outside[1]][1].withinRoot = false
        outside[0].listings[outside[1]][1].canonicalPath =
            "/tmp/outside/a.txt"
        @Expect(p9ParseAndValidate(outside).diagnostic,
            "bundle_root_entry_outside")

        let extraAfterList = p9ReadableBundle(
            "/tmp/ckb-p9/read-drift-extra", p9Assets(false), false)
        p9SetStableSecondListing(extraAfterList)
        extraAfterList[0].secondListings[extraAfterList[1]].add(
            p9ReadEntry(extraAfterList[1], "extra.txt", "extra".toArray()))
        @Expect(p9ParseAndValidate(extraAfterList).diagnostic,
            "bundle_root_listing_changed")

        let identityDrift = p9ReadableBundle(
            "/tmp/ckb-p9/read-drift-identity", p9Assets(false), false)
        p9SetStableSecondListing(identityDrift)
        identityDrift[0].secondListings[identityDrift[1]][1].identity =
            "replaced-identity"
        @Expect(p9ParseAndValidate(identityDrift).diagnostic,
            "bundle_root_listing_changed")

        let sizeDrift = p9ReadableBundle(
            "/tmp/ckb-p9/read-drift-size", p9Assets(false), false)
        p9SetStableSecondListing(sizeDrift)
        sizeDrift[0].secondListings[sizeDrift[1]][1].size += 1
        @Expect(p9ParseAndValidate(sizeDrift).diagnostic,
            "bundle_root_listing_changed")
    }

    @TestCase
    public func p9Reg01BundleReadContract(): Unit {
        let forward = p9ReadableBundle("/tmp/ckb-p9/read-forward",
            p9Assets(false), false)
        let reverse = p9ReadableBundle("/tmp/ckb-p9/read-reverse",
            p9Assets(false), true)
        let forwardResult = p9Load(forward).contract
        let reverseResult = p9Load(reverse).contract
        @Expect(forwardResult.ok, true)
        @Expect(reverseResult.ok, true)
        @Expect(forwardResult.canonicalJson, reverseResult.canonicalJson)
        @Expect(forwardResult.manifestHash, reverseResult.manifestHash)
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

private func p9ReadableBundle(root: String,
    assets: ArrayList<CkbReproBundleAsset>, reverseListing: Bool):
    (P9FakeBundleReadBackend, String) {
    let backend = P9FakeBundleReadBackend()
    backend.roots[root] = HashMap<String, Array<UInt8>>()
    backend.listings[root] = ArrayList<CkbReproBundleReadEntry>()
    p9ReadPut(backend, root, "RELEASE-MANIFEST.json",
        writeCkbReproReleaseManifest(assets).toArray())
    if (reverseListing) {
        for (i in 0..assets.size) {
            let asset = assets[assets.size - i - 1]
            p9ReadPut(backend, root, asset.relativePath, asset.bytes)
        }
    } else {
        for (asset in assets) {
            p9ReadPut(backend, root, asset.relativePath, asset.bytes)
        }
    }
    (backend, root)
}

private func p9ReadPut(backend: P9FakeBundleReadBackend, root: String,
    relativePath: String, bytes: Array<UInt8>): Unit {
    backend.roots[root][relativePath] = bytes
    backend.listings[root].add(p9ReadEntry(root, relativePath, bytes))
}

private func p9ParseAndValidate(
    seeded: (P9FakeBundleReadBackend, String)): CkbReproContractResult {
    p9Load(seeded).contract
}

private func p9Load(seeded: (P9FakeBundleReadBackend, String)):
    CkbReproBundleLoadResult {
    loadAndValidateCkbReproBundle(seeded[1], seeded[0])
}

private func p9ReadEntry(root: String, relativePath: String,
    bytes: Array<UInt8>): CkbReproBundleReadEntry {
    let entry = CkbReproBundleReadEntry()
    entry.relativePath = relativePath
    entry.kind = "regular"
    entry.canonicalPath = "${root}/${relativePath}"
    entry.withinRoot = true
    entry.identity = "fake:${ckbReproBundleHash(bytes)}"
    entry.size = bytes.size
    entry
}

private func p9SetStableSecondListing(
    seeded: (P9FakeBundleReadBackend, String)): Unit {
    seeded[0].secondListings[seeded[1]] =
        ArrayList<CkbReproBundleReadEntry>()
    for (entry in seeded[0].listings[seeded[1]]) {
        let copy = CkbReproBundleReadEntry()
        copy.relativePath = entry.relativePath
        copy.kind = entry.kind
        copy.canonicalPath = entry.canonicalPath
        copy.withinRoot = entry.withinRoot
        copy.identity = entry.identity
        copy.size = entry.size
        seeded[0].secondListings[seeded[1]].add(copy)
    }
}
