package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashMap, HashSet}
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
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

private class P9FakeBundleCliExecutor <: CkbReproBundleCliExecutor {
    public var outputExists: Bool = false
    public var parentExists: Bool = true
    public var unsignedExists: Bool = true
    public var reportExists: Bool = true
    public var fail: Bool = false
    public var unsignedCalls: Int64 = 0
    public var finalizeCalls: Int64 = 0
    public var cleanupCalls: Int64 = 0
    public init() {}
    public func exists(path: String): Bool {
        if (path.endsWith("/out")) { return this.outputExists }
        if (path.endsWith("/unsigned")) { return this.unsignedExists }
        if (path.endsWith("/p8-b.json")) { return this.reportExists }
        false
    }
    public func outputParentExists(path: String): Bool { this.parentExists }
    public func assembleUnsigned(options: CkbReproBundleCliOptions):
        CkbReproBundleResult {
        this.unsignedCalls += 1
        this.outputExists = true
        p9CliBundleResult(!this.fail)
    }
    public func finalizeBundle(options: CkbReproBundleCliOptions):
        CkbReproBundleResult {
        this.finalizeCalls += 1
        this.outputExists = true
        p9CliBundleResult(!this.fail)
    }
    public func cleanupOutput(path: String): Bool {
        this.cleanupCalls += 1
        this.outputExists = false
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
    public var noFollowFalsePath: String = ""
    public var secondManifestBytes: Array<UInt8> = Array<UInt8>()
    public var manifestReadCalls: Int64 = 0
    public var closeCalls: Int64 = 0
    public var negativeReadPath: String = ""
    public var oversizedReadPath: String = ""
    public var throwingClosePath: String = ""
    public var throwingCloseNumber: Int64 = -1
    public var maxBufferSize: Int64 = 0
    public let observedOverrides =
        HashMap<String, CkbReproBundleReadEntry>()
    public init() {}
    public func rootExists(root: String): Bool {
        this.rootExistsCalls += 1
        this.roots.contains(root)
    }
    public func rootIdentity(root: String): String {
        if (this.roots.contains(root)) { "fake-root:${root}" } else { "" }
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
    public func open(root: String, expected: CkbReproBundleReadEntry):
        CkbReproBundleReadHandle {
        this.readCalls += 1
        if (expected.relativePath == this.failReadPath) {
            throw Exception("fake read failure")
        }
        var bytes = Array<UInt8>()
        if (this.observedOverrides.contains(expected.relativePath)) {
            // The handle applies this observed identity after streaming.
        }
        if (expected.relativePath == "RELEASE-MANIFEST.json") {
            this.manifestReadCalls += 1
            if (this.manifestReadCalls > 1 &&
                this.secondManifestBytes.size > 0) {
                bytes = this.secondManifestBytes
            }
        }
        if (bytes.size == 0 && this.roots.contains(root) &&
            this.roots[root].contains(expected.relativePath)) {
            bytes = this.roots[root][expected.relativePath]
        }
        let observed = if (this.observedOverrides.contains(
            expected.relativePath)) {
            p9CopyReadEntry(this.observedOverrides[expected.relativePath])
        } else { p9CopyReadEntry(expected) }
        P9FakeBundleReadHandle(this, expected.relativePath, bytes, observed,
            expected.relativePath != this.noFollowFalsePath)
    }
}

private class P9FakeBundleReadHandle <: CkbReproBundleReadHandle {
    private let backend: P9FakeBundleReadBackend
    private let relativePath: String
    private let bytes: Array<UInt8>
    private let observed: CkbReproBundleReadEntry
    private let followsSafely: Bool
    private var offset: Int64 = 0
    public init(backend: P9FakeBundleReadBackend, relativePath: String,
        bytes: Array<UInt8>,
        observed: CkbReproBundleReadEntry, followsSafely: Bool) {
        this.backend = backend
        this.relativePath = relativePath
        this.bytes = bytes
        this.observed = observed
        this.followsSafely = followsSafely
    }
    public func read(buffer: Array<UInt8>): Int64 {
        if (this.relativePath == this.backend.negativeReadPath) { return -1 }
        if (this.relativePath == this.backend.oversizedReadPath) {
            return buffer.size + 1
        }
        if (buffer.size > this.backend.maxBufferSize) {
            this.backend.maxBufferSize = buffer.size
        }
        if (this.offset >= this.bytes.size) { return 0 }
        let remaining = this.bytes.size - this.offset
        let count = if (remaining < buffer.size) { remaining }
            else { buffer.size }
        for (i in 0..count) { buffer[i] = this.bytes[this.offset + i] }
        this.offset += count
        count
    }
    public func observedEntry(): CkbReproBundleReadEntry {
        p9CopyReadEntry(this.observed)
    }
    public func noFollow(): Bool { this.followsSafely }
    public func close(): Unit {
        this.backend.closeCalls += 1
        if (this.relativePath == this.backend.throwingClosePath ||
            this.backend.closeCalls == this.backend.throwingCloseNumber) {
            throw Exception("fake close failure")
        }
    }
}

private class P9SparseBundleReadBackend <: CkbReproBundleReadBackend {
    private let root: String
    private let manifestBytes: Array<UInt8>
    private let listing: ArrayList<CkbReproBundleReadEntry>
    public var generatedBytes: Int64 = 0
    public var maxBufferSize: Int64 = 0
    public init(root: String, manifestBytes: Array<UInt8>,
        assets: ArrayList<CkbReproBundleAsset>) {
        this.root = root; this.manifestBytes = manifestBytes
        this.listing = ArrayList<CkbReproBundleReadEntry>()
        this.listing.add(p9SparseEntry(root, "RELEASE-MANIFEST.json",
            manifestBytes.size))
        let directory = p9SparseEntry(root, "assets", 0)
        directory.kind = "directory"; this.listing.add(directory)
        for (asset in assets) {
            this.listing.add(p9SparseEntry(root, asset.relativePath, asset.size))
        }
    }
    public func rootExists(root: String): Bool { root == this.root }
    public func rootIdentity(root: String): String { "sparse-root-v1" }
    public func list(root: String): ArrayList<CkbReproBundleReadEntry> {
        this.listing
    }
    public func open(root: String, expected: CkbReproBundleReadEntry):
        CkbReproBundleReadHandle {
        P9SparseBundleReadHandle(this, expected,
            if (expected.relativePath == "RELEASE-MANIFEST.json") {
                this.manifestBytes
            } else { Array<UInt8>() })
    }
}

private class P9SparseBundleReadHandle <: CkbReproBundleReadHandle {
    private let backend: P9SparseBundleReadBackend
    private let entry: CkbReproBundleReadEntry
    private let concrete: Array<UInt8>
    private var offset: Int64 = 0
    public init(backend: P9SparseBundleReadBackend,
        entry: CkbReproBundleReadEntry, concrete: Array<UInt8>) {
        this.backend = backend; this.entry = p9CopyReadEntry(entry)
        this.concrete = concrete
    }
    public func read(buffer: Array<UInt8>): Int64 {
        if (buffer.size > this.backend.maxBufferSize) {
            this.backend.maxBufferSize = buffer.size
        }
        if (this.offset >= this.entry.size) { return 0 }
        let remaining = this.entry.size - this.offset
        let count = if (remaining < buffer.size) { remaining } else { buffer.size }
        if (this.concrete.size > 0) {
            for (i in 0..count) { buffer[i] = this.concrete[this.offset + i] }
        } else {
            for (i in 0..count) { buffer[i] = UInt8(0) }
            this.backend.generatedBytes += count
        }
        this.offset += count; count
    }
    public func observedEntry(): CkbReproBundleReadEntry {
        p9CopyReadEntry(this.entry)
    }
    public func noFollow(): Bool { true }
    public func close(): Unit {}
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
        @Expect(manifest.contains("\"role\":\"portable_report\""), true)
        @Expect(manifest.contains("\"partIndex\":0"), true)
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
        let missingRole = p9Asset("assets/missing-role.txt", "x")
        missingRole.role = ""
        @Expect(validateCkbReproBundleAssets(
            p9AssetList(missingRole)).diagnostic,
            "bundle_asset_role_invalid")
        let fakeRole = p9Asset("assets/fake-role.txt", "x")
        fakeRole.role = "humaneval_answer"
        @Expect(validateCkbReproBundleAssets(
            p9AssetList(fakeRole)).diagnostic,
            "bundle_asset_role_invalid")
        let derived = p9Asset("reports/verification.json", "x")
        derived.role = "p8_verification_report"
        @Expect(validateCkbReproBundleAssets(
            p9AssetList(derived)).diagnostic,
            "bundle_derived_asset_forbidden")
        let forgedAttestation = p9Asset("build-attestation.json", "x")
        forgedAttestation.role = "portable_report"
        @Expect(validateCkbReproBundleAssets(
            p9AssetList(forgedAttestation)).diagnostic,
            "bundle_derived_asset_forbidden")
        let forgedVerification = p9Asset(
            "reports/verification-report.json", "x")
        forgedVerification.role = "portable_report"
        @Expect(validateCkbReproBundleAssets(
            p9AssetList(forgedVerification)).diagnostic,
            "bundle_derived_asset_forbidden")
        let forgedLogical = p9Asset("assets/innocent.bin", "x")
        forgedLogical.logicalAsset = "build-attestation.json"
        @Expect(validateCkbReproBundleAssets(
            p9AssetList(forgedLogical)).diagnostic,
            "bundle_derived_asset_forbidden")
        let discontinuous = p9Asset("assets/data.part-0001", "x")
        discontinuous.logicalAsset = "assets/data"
        discontinuous.partIndex = 1
        discontinuous.partCount = 2
        discontinuous.logicalSize = 2
        discontinuous.logicalSha256 = ckbReproBundleHash("xy".toArray())
        @Expect(validateCkbReproBundleAssets(
            p9AssetList(discontinuous)).diagnostic,
            "bundle_asset_parts_incomplete")
        @Expect(planCkbReproAssetParts("asset.bin", 0).size, 1)
        @Expect(planCkbReproAssetParts("asset.bin",
            2 * 1024 * 1024 * 1024 - 1).size, 1)
        @Expect(planCkbReproAssetParts("asset.bin",
            2 * 1024 * 1024 * 1024).size, 2)
        let planned = planCkbReproAssetParts("asset.bin",
            2 * 1024 * 1024 * 1024)
        @Expect(planned[0].relativePath, "asset.bin.part-0001")
        @Expect(planned[1].relativePath, "asset.bin.part-0002")
        let wrongPartA = p9Asset("assets/data.part-0000", "x")
        let wrongPartB = p9Asset("assets/data.part-0002", "y")
        for (part in [wrongPartA, wrongPartB]) {
            part.logicalAsset = "assets/data"
            part.partCount = 2
            part.logicalSize = 2
            part.logicalSha256 = ckbReproBundleHash("xy".toArray())
        }
        wrongPartB.partIndex = 1
        let wrongParts = ArrayList<CkbReproBundleAsset>()
        wrongParts.add(wrongPartA)
        wrongParts.add(wrongPartB)
        @Expect(validateCkbReproBundleAssets(wrongParts).diagnostic,
            "bundle_asset_parts_incomplete")
        let tinyPartA = p9Asset("assets/tiny.part-0001", "x")
        let tinyPartB = p9Asset("assets/tiny.part-0002", "y")
        for (part in [tinyPartA, tinyPartB]) {
            part.logicalAsset = "assets/tiny"
            part.partCount = 2
            part.logicalSize = 2
            part.logicalSha256 = ckbReproBundleHash("xy".toArray())
        }
        tinyPartB.partIndex = 1
        let tinyParts = ArrayList<CkbReproBundleAsset>()
        tinyParts.add(tinyPartA)
        tinyParts.add(tinyPartB)
        @Expect(validateCkbReproBundleAssets(tinyParts).diagnostic,
            "bundle_asset_parts_incomplete")
        let twoGiBCanonical = p9TwoGiBMetadataAssets(false)
        @Expect(p9ParseAndValidate(p9ReadableBundle(
            "/tmp/ckb-p9/two-gib-canonical", twoGiBCanonical,
            false)).diagnostic, "bundle_asset_size_mismatch")
        let twoGiBWrongNonLast = p9TwoGiBMetadataAssets(true)
        @Expect(p9ParseAndValidate(p9ReadableBundle(
            "/tmp/ckb-p9/two-gib-wrong-nonlast", twoGiBWrongNonLast,
            false)).diagnostic, "bundle_asset_parts_incomplete")
        let maximum = ArrayList<CkbReproBundleAsset>()
        for (i in 0..995) {
            maximum.add(p9Asset("assets/${i}.txt", ""))
        }
        @Expect(validateCkbReproBundleAssets(maximum).ok, true)
        maximum.add(p9Asset("assets/995.txt", ""))
        @Expect(validateCkbReproBundleAssets(maximum).diagnostic,
            "bundle_asset_count_exceeded")
        let forbidden = p9BundleOptions("/tmp/ckb-p9/worktree/output")
        @Expect(assembleCkbUnsignedReleaseCandidate(forbidden, p9Assets(false),
            P9FakeBundleBackend()).diagnostic, "bundle_output_forbidden")
        let existingBackend = P9FakeBundleBackend()
        @Expect(existingBackend.createRoot("/tmp/ckb-p9/existing"), true)
        @Expect(assembleCkbUnsignedReleaseCandidate(
            p9BundleOptions("/tmp/ckb-p9/existing"), p9Assets(false),
            existingBackend).diagnostic, "bundle_output_exists")

        let context = p9CliContext()
        let fake = P9FakeBundleCliExecutor()
        let unsigned = parseCkbReproBundleCliArgs([
            "ckb-repro-bundle", "--mode", "unsigned", "--output",
            "/tmp/发布 资料/out"
        ])
        @Expect(unsigned.valid, true)
        @Expect(validateCkbReproBundleCliOptions(unsigned, context, fake).ok,
            true)
        let finalize = parseCkbReproBundleCliArgs([
            "ckb-repro-bundle", "--mode", "finalize", "--unsigned-root",
            "/tmp/已验证🙂/unsigned", "--verification-report",
            "/tmp/证据/p8-b.json", "--output", "/tmp/发布 资料/out"
        ])
        @Expect(finalize.valid, true)
        @Expect(validateCkbReproBundleCliOptions(finalize, context, fake).ok,
            true)
        for (output in ["relative/out", "/tmp/../escape/out",
            "/tmp/metis-worktree/out", "/tmp/ckb-data/out",
            "/tmp/p8-runs/out", "/tmp/settings/out"]) {
            let options = parseCkbReproBundleCliArgs([
                "ckb-repro-bundle", "--mode", "unsigned", "--output", output])
            @Expect(validateCkbReproBundleCliOptions(options, context, fake).ok,
                false)
        }
        let overlap = parseCkbReproBundleCliArgs([
            "ckb-repro-bundle", "--mode", "finalize", "--unsigned-root",
            "/tmp/发布 资料", "--verification-report", "/tmp/证据/p8-b.json",
            "--output", "/tmp/发布 资料/out"
        ])
        @Expect(validateCkbReproBundleCliOptions(overlap, context, fake).diagnostic,
            "bundle_unsigned_final_overlap")
        @Expect(parseCkbReproBundleCliArgs([
            "ckb-repro-bundle", "--mode", "unsigned", "--unsigned-root",
            "/tmp/已验证🙂/unsigned", "--output", "/tmp/发布 资料/out"
        ]).diagnostic, "bundle_unsigned_arguments_conflict")

        let temporary = Path("target/ckb-repro-cli-adapter")
        if (exists(temporary)) { remove(temporary, recursive: true) }
        Directory.create(temporary, recursive: true)
        let temporaryRoot = canonicalize(temporary).toString()
        let realOptions = parseCkbReproBundleCliArgs([
            "ckb-repro-bundle", "--mode", "unsigned", "--output",
            "${temporaryRoot}/out"
        ])
        let realContext = CkbReproBundleCliPathContext()
        realContext.worktreeRoot = "/tmp/protected-worktree"
        realContext.productionRoot = "/tmp/protected-production"
        realContext.privateRunRoot = "/tmp/protected-runs"
        realContext.userConfigRoot = "/tmp/protected-settings"
        let real = runCkbReproBundleCliAdapter(realOptions, realContext,
            p9Assets(false), "")
        @Expect(real.ok, true)
        @Expect(File.readFrom(Path(realOptions.outputRoot).join("assets/b.txt")),
            "仓颉🙂".toArray())
        remove(temporary, recursive: true)
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

        let fake = P9FakeBundleCliExecutor()
        fake.fail = true
        let cliOptions = parseCkbReproBundleCliArgs([
            "ckb-repro-bundle", "--mode", "finalize", "--unsigned-root",
            "/tmp/已验证🙂/unsigned", "--verification-report",
            "/tmp/证据/p8-b.json", "--output", "/tmp/发布 资料/out"
        ])
        let failed = executeCkbReproBundleCliAdapter(cliOptions, p9CliContext(), fake)
        @Expect(failed.ok, false)
        @Expect(fake.finalizeCalls, 1)
        @Expect(fake.cleanupCalls, 1)
        @Expect(fake.outputExists, false)
        @Expect(renderCkbReproBundleCliHuman(failed).contains("{\""), false)
        @Expect(renderCkbReproBundleCliJson(failed).startsWith("{"), true)
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
        let unpartitionedHuge = p9Asset("assets/huge.bin", "x")
        unpartitionedHuge.size = 2 * 1024 * 1024 * 1024
        unpartitionedHuge.logicalSize = unpartitionedHuge.size
        let huge = p9ReadableBundle("/tmp/ckb-p9/unpartitioned-huge",
            p9AssetList(unpartitionedHuge), false)
        @Expect(p9ParseAndValidate(huge).diagnostic,
            "bundle_asset_parts_incomplete")
        let twoGiB = p9ReadableBundle("/tmp/ckb-p9/two-gib-streaming",
            p9TwoGiBMetadataAssets(false), false)
        @Expect(p9Load(twoGiB).contract.ok, false)
        @Expect(twoGiB[0].maxBufferSize <= 65536, true)
        let sparseAssets = p9TwoGiBSparseAssets()
        let sparseManifest = writeCkbReproReleaseManifest(sparseAssets).toArray()
        let sparse = P9SparseBundleReadBackend(
            "/tmp/ckb-p9/two-gib-sparse", sparseManifest, sparseAssets)
        let sparseLoaded = validateCkbReproBundleManifest(
            "/tmp/ckb-p9/two-gib-sparse", sparse)
        @Expect(sparseLoaded.contract.ok, true)
        @Expect(sparse.maxBufferSize <= 65536, true)
        @Expect(sparse.generatedBytes, 4 * 1024 * 1024 * 1024)
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
        for (controlPath in ["assets/back\u{0008}space.txt",
            "assets/form\u{000c}feed.txt", "assets/unit\u{001f}sep.txt",
            "assets/delete\u{007f}.txt"]) {
            @Expect(validateCkbReproBundleRelativePath(
                controlPath).diagnostic, "bundle_path_invalid")
            let controlAssets = ArrayList<CkbReproBundleAsset>()
            controlAssets.add(p9Asset(controlPath, "x"))
            @Expect(parseCkbReproBundleManifest(
                writeCkbReproReleaseManifest(controlAssets).toArray())[
                    0].diagnostic, "bundle_path_invalid")
        }

        let escapedOrder = ArrayList<CkbReproBundleAsset>()
        escapedOrder.add(p9Asset("assets/\".txt", "quote"))
        escapedOrder.add(p9Asset("assets/#.txt", "hash"))
        let escapedManifest = writeCkbReproReleaseManifest(escapedOrder)
        let escapedParsed =
            parseCkbReproBundleManifest(escapedManifest.toArray())
        @Expect(escapedParsed[0].ok, true)
        @Expect(escapedParsed[1].assets[0].relativePath, "assets/#.txt")
        @Expect(escapedParsed[1].assets[1].relativePath, "assets/\".txt")
        @Expect(p9Load(p9ReadableBundle(
            "/tmp/ckb-p9/read-escaped-order",
            escapedOrder, false)).contract.ok, true)
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
        @Expect(seeded[0].closeCalls, 4)
        @Expect(seeded[0].maxBufferSize <= 65536, true)
        seeded[0].roots[seeded[1]]["assets/a.txt"] = "ALPHA".toArray()
        @Expect(loaded.assetProofs[0].sha256,
            loaded.manifest.assets[0].sha256)

        let largeBytes = Array<UInt8>(200000, repeat: UInt8(7))
        let large = p9ReadableBundle("/tmp/ckb-p9/read-streaming",
            p9AssetList(p9AssetBytes("assets/large.bin", largeBytes)), false)
        @Expect(p9Load(large).contract.ok, true)
        @Expect(large[0].maxBufferSize, 65536)
        @Expect(large[0].closeCalls, 3)

        let finalizeSeed = p9ReadableBundle(
            "/tmp/ckb-p9/finalize-loader", p9Assets(false), false)
        let firstLoad = p9Load(finalizeSeed)
        let report = CkbReproReleaseVerificationResult()
        report.ok = true
        report.diagnostic = "verified"
        report.verifiedReleaseInputSetHash = firstLoad.manifest.inputSetHash
        report.bundleProofSetHash = firstLoad.proofSetHash
        report.releaseCommit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        report.certifiedRunInputHash = ckbReproBundleHash("input".toArray())
        report.runCriticalTreeHash = ckbReproBundleHash("tree".toArray())
        report.referenceManifestHash = ckbReproBundleHash("reference".toArray())
        report.authorityHash = ckbReproBundleHash("authority".toArray())
        report.restored.ok = true; report.restored.diagnostic = "ok"
        report.rebuilt.ok = true; report.rebuilt.diagnostic = "ok"
        report.publicEvidence.ok = true; report.publicEvidence.diagnostic = "ok"
        report.documentation.ok = true; report.documentation.diagnostic = "ok"
        let loadedFinalize = loadCkbReproFinalizeInputs(finalizeSeed[1],
            renderCkbReproVerificationReport(report).toArray(), finalizeSeed[0])
        @Expect(loadedFinalize.ok, true)
        @Expect(loadedFinalize.manifest.inputSetHash,
            firstLoad.manifest.inputSetHash)
        @Expect(finalizeSeed[0].maxBufferSize <= 65536, true)
        let forged = renderCkbReproVerificationReport(report).replace(
            report.bundleProofSetHash, ckbReproBundleHash("forged".toArray()))
        @Expect(loadCkbReproFinalizeInputs(finalizeSeed[1], forged.toArray(),
            finalizeSeed[0]).diagnostic, "bundle_verification_report_mismatch")
    }

    @TestCase
    public func p9Pos01ProductionFinalizeOwnsAndEmitsCompleteArtifacts(): Unit {
        let collected = p9ProductionFinalizeFixture(suffix: "-collect")
        let collectOptions = parseCkbReproBundleCliArgs([
            "ckb-repro-bundle", "--mode", "unsigned", "--input-root",
            collected[0], "--output",
            Path(collected[3]).join("collected").toString()
        ])
        @Expect(collectOptions.valid, true)
        @Expect(runCkbReproBundleCliAdapter(
            collectOptions, p9CliContext()).ok, true)
        @Expect(File.readFrom(Path(collectOptions.outputRoot).join(
            "assets/a.txt")), "alpha".toArray())
        remove(Path(collected[3]), recursive: true)

        let fixture = p9ProductionFinalizeFixture()
        let options = parseCkbReproBundleCliArgs([
            "ckb-repro-bundle", "--mode", "finalize", "--unsigned-root",
            fixture[0], "--verification-report", fixture[1], "--output",
            fixture[2]
        ])
        let executor = CkbReproProductionBundleCliExecutor()
        let finalized = executor.finalizeBundle(options)
        @Expect(finalized.ok, true)
        @Expect(exists(Path(fixture[2]).join("RELEASE-MANIFEST.json")), true)
        @Expect(exists(Path(fixture[2]).join("verification-report.json")), true)
        @Expect(exists(Path(fixture[2]).join("build-attestation.json")), true)
        @Expect(exists(Path(fixture[2]).join("SHA256SUMS")), true)
        if (exists(Path(fixture[2]).join("build-attestation.json"))) {
            @Expect(validateCkbReproBuildAttestation(
                File.readFrom(Path(fixture[2]).join("build-attestation.json")),
                File.readFrom(Path(fixture[2]).join("verification-report.json")),
                File.readFrom(Path(fixture[2]).join("RELEASE-MANIFEST.json"))).ok,
                true)
        }
        let legacyBooleanAttestation =
            "{\"schemaVersion\":\"ckb-repro-build-attestation-v1\"," +
            "\"runCriticalTreeMatches\":true,\"strictPassed\":151," +
            "\"transportUnresolved\":0,\"leakageFindingCount\":0," +
            "\"fullTestsPassed\":true,\"licenseComplete\":true," +
            "\"externalProofsVerified\":true}"
        @Expect(validateCkbReproBuildAttestation(
            legacyBooleanAttestation.toArray(),
            File.readFrom(Path(fixture[1])),
            File.readFrom(Path(fixture[0]).join("RELEASE-MANIFEST.json"))).ok,
            false)
        if (exists(Path(fixture[2]).join("SHA256SUMS"))) {
            let sums = String.fromUtf8(File.readFrom(
                Path(fixture[2]).join("SHA256SUMS")))
            for (name in ["assets/a.txt", "assets/b.txt",
                "RELEASE-MANIFEST.json", "verification-report.json",
                "build-attestation.json"]) {
                @Expect(sums.contains("  ${name}\n"), true)
            }
            @Expect(sums.contains("  SHA256SUMS\n"), false)
        }

        let raced = p9ProductionFinalizeFixture(suffix: "-race")
        Directory.create(Path(raced[2]), recursive: false)
        File.writeTo(Path(raced[2]).join("external-sentinel"), "keep".toArray())
        let racedOptions = parseCkbReproBundleCliArgs([
            "ckb-repro-bundle", "--mode", "finalize", "--unsigned-root",
            raced[0], "--verification-report", raced[1], "--output", raced[2]
        ])
        let racedExecutor = CkbReproProductionBundleCliExecutor()
        @Expect(racedExecutor.finalizeBundle(racedOptions).ok, false)
        @Expect(racedExecutor.cleanupOutput(raced[2]), true)
        @Expect(exists(Path(raced[2]).join("external-sentinel")), true)
        remove(Path(fixture[3]), recursive: true)
        remove(Path(raced[3]), recursive: true)
    }

    @TestCase
    public func p9Neg01BundleReadContract(): Unit {
        let negativeRead = p9ReadableBundle(
            "/tmp/ckb-p9/read-negative-count", p9Assets(false), false)
        negativeRead[0].negativeReadPath = "assets/a.txt"
        @Expect(p9ParseAndValidate(negativeRead).diagnostic,
            "bundle_read_failed")
        @Expect(negativeRead[0].closeCalls > 0, true)

        let oversizedRead = p9ReadableBundle(
            "/tmp/ckb-p9/read-oversized-count", p9Assets(false), false)
        oversizedRead[0].oversizedReadPath = "assets/a.txt"
        @Expect(p9ParseAndValidate(oversizedRead).diagnostic,
            "bundle_read_failed")
        @Expect(oversizedRead[0].closeCalls > 0, true)

        let closeAfterIdentity = p9ReadableBundle(
            "/tmp/ckb-p9/close-after-identity", p9Assets(false), false)
        let changed = p9CopyReadEntry(
            closeAfterIdentity[0].listings[closeAfterIdentity[1]][1])
        changed.identity = "changed-before-close"
        closeAfterIdentity[0].observedOverrides["assets/a.txt"] = changed
        closeAfterIdentity[0].throwingClosePath = "assets/a.txt"
        @Expect(p9ParseAndValidate(closeAfterIdentity).diagnostic,
            "bundle_read_entry_changed")

        let closeAfterSuccess = p9ReadableBundle(
            "/tmp/ckb-p9/close-after-success", p9Assets(false), false)
        closeAfterSuccess[0].throwingClosePath =
            "RELEASE-MANIFEST.json"
        @Expect(p9ParseAndValidate(closeAfterSuccess).diagnostic,
            "bundle_read_close_failed")

        let assetCloseAfterSuccess = p9ReadableBundle(
            "/tmp/ckb-p9/asset-close-after-success",
            p9Assets(false), false)
        assetCloseAfterSuccess[0].throwingClosePath = "assets/a.txt"
        @Expect(p9ParseAndValidate(assetCloseAfterSuccess).diagnostic,
            "bundle_read_close_failed")

        let missingRoot = P9FakeBundleReadBackend()
        @Expect(validateCkbReproBundleManifest(
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
        changedManifest[0].secondManifestBytes =
            writeCkbReproReleaseManifest(p9Assets(false))
                .replace("schemaVersion", "schemaVersioN").toArray()
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
        @Expect(sameSizeTampered[0].closeCalls >= 2, true)

        let malformedAsset = writeCkbReproReleaseManifest(p9Assets(false))
            .replace("\"inputKind\":\"verified_input\"",
                "\"inputKind\":\"verified_input\",\"extra\":true")
        @Expect(parseCkbReproBundleManifest(
            malformedAsset.toArray())[0].diagnostic,
            "bundle_manifest_asset_contract_invalid")

        let oversizedManifest = p9ReadableBundle(
            "/tmp/ckb-p9/read-manifest-limit", p9Assets(false), false)
        oversizedManifest[0].listings[oversizedManifest[1]][0].size =
            16 * 1024 * 1024 + 1
        @Expect(p9ParseAndValidate(oversizedManifest).diagnostic,
            "bundle_manifest_size_exceeded")

        let nonCanonical = writeCkbReproReleaseManifest(p9Assets(false))
            .replace("},{", "}, {")
        @Expect(parseCkbReproBundleManifest(
            nonCanonical.toArray())[0].diagnostic,
            "bundle_manifest_non_canonical")

        let inputMismatch = p9ReadableBundle(
            "/tmp/ckb-p9/read-input-hash", p9Assets(false), false)
        p9ReplaceManifest(inputMismatch,
            writeCkbReproReleaseManifest(p9Assets(false)).replace(
                computeCkbReproBundleInputSetHash(p9Assets(false)),
                ckbReproBundleHash("different-input-set".toArray())))
        @Expect(p9ParseAndValidate(inputMismatch).diagnostic,
            "bundle_input_set_hash_mismatch")

        let selfAssets = ArrayList<CkbReproBundleAsset>()
        selfAssets.add(p9Asset("RELEASE-MANIFEST.json", "self"))
        let selfBundle = p9ReadableBundle(
            "/tmp/ckb-p9/read-self", ArrayList<CkbReproBundleAsset>(), false)
        p9ReplaceManifest(
            selfBundle, writeCkbReproReleaseManifest(selfAssets))
        @Expect(p9ParseAndValidate(selfBundle).diagnostic,
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

        let noFollow = p9ReadableBundle(
            "/tmp/ckb-p9/read-no-follow", p9Assets(false), false)
        noFollow[0].noFollowFalsePath = "assets/a.txt"
        @Expect(p9ParseAndValidate(noFollow).diagnostic,
            "bundle_read_no_follow_required")

        let swapSymlink = p9ReadableBundle(
            "/tmp/ckb-p9/read-swap-symlink", p9Assets(false), false)
        let symlinkObserved =
            p9CopyReadEntry(swapSymlink[0].listings[swapSymlink[1]][1])
        symlinkObserved.kind = "symlink"
        swapSymlink[0].observedOverrides["assets/a.txt"] = symlinkObserved
        @Expect(p9ParseAndValidate(swapSymlink).diagnostic,
            "bundle_read_observed_entry_unsafe")

        let swapOutside = p9ReadableBundle(
            "/tmp/ckb-p9/read-swap-outside", p9Assets(false), false)
        let outsideObserved =
            p9CopyReadEntry(swapOutside[0].listings[swapOutside[1]][1])
        outsideObserved.withinRoot = false
        outsideObserved.canonicalPath = "/tmp/outside/a.txt"
        swapOutside[0].observedOverrides["assets/a.txt"] = outsideObserved
        @Expect(p9ParseAndValidate(swapOutside).diagnostic,
            "bundle_read_observed_entry_unsafe")

        let swapIdentity = p9ReadableBundle(
            "/tmp/ckb-p9/read-swap-identity", p9Assets(false), false)
        let identityObserved =
            p9CopyReadEntry(swapIdentity[0].listings[swapIdentity[1]][1])
        identityObserved.identity = "swap-on-read"
        swapIdentity[0].observedOverrides["assets/a.txt"] = identityObserved
        @Expect(p9ParseAndValidate(swapIdentity).diagnostic,
            "bundle_read_entry_changed")

        let manifestSwap = p9ReadableBundle(
            "/tmp/ckb-p9/read-manifest-swap", p9Assets(false), false)
        let manifestObserved =
            p9CopyReadEntry(manifestSwap[0].listings[manifestSwap[1]][0])
        manifestObserved.identity = "manifest-swap-on-read"
        manifestSwap[0].observedOverrides[
            "RELEASE-MANIFEST.json"] = manifestObserved
        @Expect(p9ParseAndValidate(manifestSwap).diagnostic,
            "bundle_read_entry_changed")

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
    public func p9Neg02FilesystemBundleScansActualAssetContent(): Unit {
        var index: Int64 = 0
        for (attack in ["/Users/private/run", "/home/private/run",
            "/mnt/private/run", "/Volumes/private/run",
            "Authorization: Bearer secret", "token=secret",
            "api_key=secret"]) {
            @Expect(p9ValidateFilesystemBundleContent(
                attack.toArray(), "portable_report", index).diagnostic,
                "bundle_sensitive_content_detected")
            index += 1
        }
        @Expect(p9ValidateFilesystemBundleContent(
            [UInt8(0xff), UInt8(0xfe)], "portable_report", index).diagnostic,
            "bundle_text_encoding_invalid")
        index += 1
        let large = ("safe-仓颉🙂\n" * 100000) + "token=tail-secret"
        @Expect(p9ValidateFilesystemBundleContent(
            large.toArray(), "portable_report", index).diagnostic,
            "bundle_sensitive_content_detected")
        index += 1
        @Expect(p9ValidateFilesystemBundleContent(
            [UInt8(0xff), UInt8(0x00), UInt8(0xfe)],
            "p3_qdrant_snapshot", index).ok, true)
        index += 1
        for (attack in ["Authorization: Bearer secret",
            "/Users/private/run", "token=boundary-secret"]) {
            let binary = ArrayList<UInt8>()
            binary.add(UInt8(0xff))
            for (_ in 0..65532) { binary.add(UInt8(0x00)) }
            binary.add(all: attack.toArray())
            binary.add(UInt8(0xfe))
            @Expect(p9ValidateFilesystemBundleContent(binary.toArray(),
                "p3_qdrant_snapshot", index).diagnostic,
                "bundle_sensitive_content_detected")
            index += 1
        }
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

private func p9CliBundleResult(ok: Bool): CkbReproBundleResult {
    let result = CkbReproBundleResult()
    result.ok = ok
    result.diagnostic = if (ok) { "component_ready" } else {
        "bundle_verified_input_changed"
    }
    result.inputSetHash = if (ok) { ckbReproBundleHash("input".toArray()) } else { "" }
    result.treeHash = if (ok) { ckbReproBundleHash("tree".toArray()) } else { "" }
    result.assetCount = if (ok) { 2 } else { 0 }
    result
}

private func p9CliContext(): CkbReproBundleCliPathContext {
    let context = CkbReproBundleCliPathContext()
    context.worktreeRoot = "/tmp/metis-worktree"
    context.productionRoot = "/tmp/ckb-data"
    context.privateRunRoot = "/tmp/p8-runs"
    context.userConfigRoot = "/tmp/settings"
    context
}

private func p9Asset(path: String, value: String): CkbReproBundleAsset {
    p9AssetBytes(path, value.toArray())
}

private func p9AssetBytes(path: String,
    bytes: Array<UInt8>): CkbReproBundleAsset {
    let asset = CkbReproBundleAsset()
    asset.relativePath = path
    asset.bytes = bytes
    asset.size = asset.bytes.size
    asset.sha256 = ckbReproBundleHash(asset.bytes)
    asset.inputKind = "verified_input"
    asset.role = "portable_report"
    asset.logicalAsset = path
    asset.partIndex = 0
    asset.partCount = 1
    asset.logicalSize = asset.size
    asset.logicalSha256 = asset.sha256
    asset
}

private func p9Assets(reverse: Bool): ArrayList<CkbReproBundleAsset> {
    let out = ArrayList<CkbReproBundleAsset>()
    let a = p9Asset("assets/a.txt", "alpha")
    let b = p9Asset("assets/b.txt", "仓颉🙂")
    if (reverse) { out.add(b); out.add(a) } else { out.add(a); out.add(b) }
    out
}

private func p9AssetList(asset: CkbReproBundleAsset):
    ArrayList<CkbReproBundleAsset> {
    let out = ArrayList<CkbReproBundleAsset>()
    out.add(asset)
    out
}

private func p9TwoGiBMetadataAssets(wrongNonLast: Bool):
    ArrayList<CkbReproBundleAsset> {
    let out = ArrayList<CkbReproBundleAsset>()
    let count: Int64 = if (wrongNonLast) { 3 } else { 2 }
    for (index in 0..count) {
        let suffix = match (index) {
            case 0 => "0001"
            case 1 => "0002"
            case _ => "0003"
        }
        let part = p9Asset("assets/two-gib.bin.part-${suffix}", "x")
        part.logicalAsset = "assets/two-gib.bin"
        part.partIndex = index
        part.partCount = count
        part.logicalSize = 2 * 1024 * 1024 * 1024
        part.logicalSha256 = ckbReproBundleHash("logical".toArray())
        part.size = if (!wrongNonLast) {
            1024 * 1024 * 1024
        } else if (index == 0) {
            1024 * 1024 * 1024 - 1
        } else if (index == 1) {
            1024 * 1024 * 1024
        } else { 1 }
        out.add(part)
    }
    out
}

private func p9TwoGiBSparseAssets(): ArrayList<CkbReproBundleAsset> {
    let out = ArrayList<CkbReproBundleAsset>()
    for (index in 0..2) {
        let asset = CkbReproBundleAsset()
        asset.relativePath = "assets/two-gib.bin.part-000${index + 1}"
        asset.size = 1024 * 1024 * 1024
        asset.sha256 = "sha256:49bc20df15e412a64472421e13fe86ff1c5165e18b2afccf160d4dc19fe68a14"
        asset.inputKind = "verified_input"; asset.role = "portable_report"
        asset.logicalAsset = "assets/two-gib.bin"; asset.partIndex = index
        asset.partCount = 2; asset.logicalSize = 2 * 1024 * 1024 * 1024
        asset.logicalSha256 = "sha256:a7c744c13cc101ed66c29f672f92455547889cc586ce6d44fe76ae824958ea51"
        out.add(asset)
    }
    out
}

private func p9SparseEntry(root: String, path: String,
    size: Int64): CkbReproBundleReadEntry {
    let entry = CkbReproBundleReadEntry()
    entry.relativePath = path; entry.kind = "regular"
    entry.canonicalPath = "${root}/${path}"; entry.withinRoot = true
    entry.identity = "sparse:${path}:${size}"; entry.size = size
    entry
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

private func p9ProductionFinalizeFixture(suffix!: String = ""):
    (String, String, String, String) {
    let base = Path("target/ckb-repro-production-finalize${suffix}")
    if (exists(base)) { remove(base, recursive: true) }
    Directory.create(base.join("unsigned/assets"), recursive: true)
    let canonicalBase = canonicalize(base).toString()
    let unsigned = Path(canonicalBase).join("unsigned")
    let assets = p9Assets(false)
    for (asset in assets) {
        File.writeTo(unsigned.join(asset.relativePath), asset.bytes)
    }
    File.writeTo(unsigned.join("RELEASE-MANIFEST.json"),
        writeCkbReproReleaseManifest(assets).toArray())
    let loaded = validateCkbReproBundleManifest(unsigned.toString(),
        CkbReproFilesystemBundleReadBackend())
    let report = CkbReproReleaseVerificationResult()
    report.ok = true; report.diagnostic = "verified"
    report.verifiedReleaseInputSetHash = loaded.manifest.inputSetHash
    report.bundleProofSetHash = loaded.proofSetHash
    report.releaseCommit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    report.certifiedRunInputHash = ckbReproBundleHash("input".toArray())
    report.runCriticalTreeHash = ckbReproBundleHash("tree".toArray())
    report.referenceManifestHash = ckbReproBundleHash("reference".toArray())
    report.authorityHash = ckbReproBundleHash("authority".toArray())
    report.restored.ok = true; report.restored.diagnostic = "ok"
    report.rebuilt.ok = true; report.rebuilt.diagnostic = "ok"
    report.publicEvidence.ok = true; report.publicEvidence.diagnostic = "ok"
    report.documentation.ok = true; report.documentation.diagnostic = "ok"
    let reportPath = Path(canonicalBase).join("verification-input.json")
    File.writeTo(reportPath, renderCkbReproVerificationReport(report).toArray())
    (unsigned.toString(), reportPath.toString(),
        Path(canonicalBase).join("final").toString(), canonicalBase)
}

private func p9ValidateFilesystemBundleContent(bytes: Array<UInt8>,
    role: String, index: Int64): CkbReproContractResult {
    let root = Path("target/p9-content-scan-${index}")
    if (exists(root)) { remove(root, recursive: true) }
    Directory.create(root.join("assets"), recursive: true)
    let canonicalRoot = canonicalize(root).toString()
    let asset = p9AssetBytes("assets/content.bin", bytes)
    asset.role = role
    let assets = p9AssetList(asset)
    File.writeTo(Path(canonicalRoot).join(asset.relativePath), bytes)
    File.writeTo(Path(canonicalRoot).join("RELEASE-MANIFEST.json"),
        writeCkbReproReleaseManifest(assets).toArray())
    let result = validateCkbReproBundleManifest(canonicalRoot,
        CkbReproFilesystemBundleReadBackend()).contract
    remove(Path(canonicalRoot), recursive: true)
    result
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
    let directories = HashSet<String>()
    for (asset in assets) {
        let parts = asset.relativePath.split("/")
        let parent = StringBuilder()
        for (i in 0..parts.size - 1) {
            if (i > 0) { parent.append("/") }
            parent.append(parts[i])
            directories.add(parent.toString())
        }
    }
    for (directory in directories) {
        let entry = CkbReproBundleReadEntry()
        entry.relativePath = directory
        entry.kind = "directory"
        entry.canonicalPath = "${root}/${directory}"
        entry.withinRoot = true
        entry.identity = "fake-directory:${directory}"
        backend.listings[root].add(entry)
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
    validateCkbReproBundleManifest(seeded[1], seeded[0])
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

private func p9CopyReadEntry(
    entry: CkbReproBundleReadEntry): CkbReproBundleReadEntry {
    let copy = CkbReproBundleReadEntry()
    copy.relativePath = entry.relativePath
    copy.kind = entry.kind
    copy.canonicalPath = entry.canonicalPath
    copy.withinRoot = entry.withinRoot
    copy.identity = entry.identity
    copy.size = entry.size
    copy
}

private func p9ReplaceManifest(
    seeded: (P9FakeBundleReadBackend, String), manifest: String): Unit {
    let bytes = manifest.toArray()
    seeded[0].roots[seeded[1]]["RELEASE-MANIFEST.json"] = bytes
    seeded[0].listings[seeded[1]][0] =
        p9ReadEntry(seeded[1], "RELEASE-MANIFEST.json", bytes)
}

private func p9SetStableSecondListing(
    seeded: (P9FakeBundleReadBackend, String)): Unit {
    seeded[0].secondListings[seeded[1]] =
        ArrayList<CkbReproBundleReadEntry>()
    for (entry in seeded[0].listings[seeded[1]]) {
        seeded[0].secondListings[seeded[1]].add(
            p9CopyReadEntry(entry))
    }
}
