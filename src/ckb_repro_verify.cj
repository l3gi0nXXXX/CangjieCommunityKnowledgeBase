package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.sort.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

foreign {
    func open(path: CString, flags: Int32): Int32
    func read(fd: Int32, buffer: CPointer<UInt8>, size: UIntNative): IntNative
    func fstat(fd: Int32, stat: CPointer<UInt8>): Int32
    func fcntl(fd: Int32, command: Int32, ...): Int32
    func unlinkat(directoryFd: Int32, path: CString, flags: Int32): Int32
    func renameatx_np(fromFd: Int32, from: CString, toFd: Int32,
        to: CString, flags: UInt32): Int32
    func close(fd: Int32): Int32
    func __error(): CPointer<Int32>
}

public class CkbReproOwnedTempDescriptor {
    private var grandparentFd: Int32 = -1
    private var parentFd: Int32 = -1
    private var payloadFd: Int32 = -1
    private var grandparentIdentity: String = ""
    private var parentIdentity: String = ""
    private var payloadIdentity: String = ""
    private var grandparentPath: String = ""
    private var parentName: String = ""
    private var tempName: String = ""
    private var targetName: String = ""
    private var published: Bool = false
    private var createdByThisInvocation: Bool = false
    public var ok: Bool = false
    public var diagnostic: String = "composition_temporary_open_failed"
    public var nativeErrno: Int32 = 0
    public init() {}

    public func acquire(parent: String, tempName: String,
        targetName: String,
        forceInitialIdentityFailure!: Bool = false): Unit {
        if (tempName == "" || tempName.contains("/") || targetName == "" ||
            targetName.contains("/")) { return }
        let parentPath = Path(parent)
        this.grandparentPath = parentPath.parent.toString()
        this.parentName = parentPath.fileName
        this.tempName = tempName; this.targetName = targetName
        if (this.parentName == "" || this.parentName == "." ||
            this.parentName == "..") { return }
        this.grandparentFd = p8OpenBundleDirectory(this.grandparentPath)
        if (this.grandparentFd < 0) { return }
        this.grandparentIdentity =
            p8StableDescriptorIdentity(this.grandparentFd)
        let pname = unsafe { LibC.mallocCString(this.parentName) }
        this.parentFd = unsafe {
            openat(this.grandparentFd, pname, 0x100104, 0)
        }
        unsafe { LibC.free(pname) }
        if (this.parentFd < 0 || p8DescriptorKind(this.parentFd) != "directory") {
            this.diagnostic = "composition_parent_open_failed"
            this.close(); return
        }
        this.parentIdentity = p8StableDescriptorIdentity(this.parentFd)
        if (this.grandparentIdentity == "" || this.parentIdentity == "" ||
            !this.publicParentStillBound()) {
            this.diagnostic = "composition_parent_binding_invalid"
            this.close(); return
        }
        let tname = unsafe { LibC.mallocCString(this.tempName) }
        this.payloadFd = unsafe { openat(this.parentFd, tname, 0xb02, 0x180) }
        this.nativeErrno = if (this.payloadFd < 0) {
            unsafe { __error().read() }
        } else { Int32(0) }
        unsafe { LibC.free(tname) }
        if (this.payloadFd < 0) {
            this.diagnostic = if (this.nativeErrno == 17) {
                "composition_temporary_exists"
            } else { "composition_temporary_open_failed" }
            this.close(); return
        }
        this.createdByThisInvocation = true
        this.payloadIdentity = if (forceInitialIdentityFailure) { "" }
            else { p8StableDescriptorIdentity(this.payloadFd) }
        if (this.payloadIdentity == "") {
            // Keep the atomically-created fd open. A retry may establish the
            // inode identity needed for safe name cleanup, but this acquire
            // still fails so an unavailable first identity is never hidden.
            let retryIdentity = p8StableDescriptorIdentity(this.payloadFd)
            if (retryIdentity != "" &&
                p8DescriptorRegularSingleLink(this.payloadFd)) {
                this.payloadIdentity = retryIdentity
            }
            this.diagnostic = "composition_temporary_identity_initial_failed"
            this.cleanup(); return
        }
        if (!p8DescriptorRegularSingleLink(this.payloadFd)) {
            this.diagnostic = "composition_temporary_not_exclusive"
            this.cleanup(); return
        }
        if (unsafe { fchmod(this.payloadFd, 0x180) } != 0) {
            this.diagnostic = "composition_temporary_mode_failed"
            this.cleanup(); return
        }
        this.ok = true; this.diagnostic = "ok"
    }

    public func createPayload(bytes: Array<UInt8>): Bool {
        if (!this.ok || this.payloadFd < 0 ||
            !this.tempNameStillOwnedAndExclusive()) {
            this.diagnostic = "composition_temporary_name_replaced"
            return false
        }
        var offset: Int64 = 0
        while (offset < bytes.size) {
            let count = unsafe {
                let raw = acquireArrayRawData(bytes)
                let written = write(this.payloadFd,
                    raw.pointer + offset, UIntNative(bytes.size - offset))
                releaseArrayRawData(raw)
                Int64(written)
            }
            if (count <= 0) { return false }
            offset += count
        }
        if (unsafe { fsync(this.payloadFd) } != 0 ||
            unsafe { lseek(this.payloadFd, 0, 0) } != 0) { return false }
        let readback = ArrayList<UInt8>()
        while (true) {
            let buffer = Array<UInt8>(8192, repeat: UInt8(0))
            let count = unsafe {
                let raw = acquireArrayRawData(buffer)
                let value = read(this.payloadFd, raw.pointer,
                    UIntNative(buffer.size))
                releaseArrayRawData(raw)
                Int64(value)
            }
            if (count < 0 || count > buffer.size) { return false }
            if (count == 0) { break }
            readback.add(all: if (count == buffer.size) { buffer }
                else { buffer[0..count].clone() })
        }
        let exact = readback.toArray() == bytes &&
            this.tempNameStillOwnedAndExclusive()
        if (!exact) { this.diagnostic = "composition_readback_failed" }
        exact
    }

    public func publish(): Bool {
        if (!this.ok || this.payloadFd < 0 ||
            !this.publicParentStillBound() ||
            !this.tempNameStillOwnedAndExclusive() ||
            p8StableDescriptorIdentity(this.parentFd) != this.parentIdentity ||
            p8StableDescriptorIdentity(this.payloadFd) != this.payloadIdentity) {
            this.diagnostic = "composition_commit_precheck_failed"
            return false
        }
        let source = unsafe { LibC.mallocCString(this.tempName) }
        let target = unsafe { LibC.mallocCString(this.targetName) }
        let renameResult = unsafe { renameatx_np(this.parentFd, source,
            this.parentFd, target, UInt32(4)) }
        let renameErrno = if (renameResult != 0) {
            unsafe { __error().read() }
        } else { Int32(0) }
        let renamed = renameResult == 0
        unsafe { LibC.free(source); LibC.free(target) }
        if (renamed) {
            this.published = true
            _ = unsafe { close(this.payloadFd) }; this.payloadFd = -1
            this.diagnostic = "ok"
        } else if (renameErrno == 17) {
            this.diagnostic = "composition_commit_failed"
        } else {
            this.diagnostic = "composition_commit_rename_failed"
        }
        renamed
    }

    public func syncAndValidate(forceFailure!: Bool = false): Bool {
        if (!this.published) {
            this.diagnostic = "composition_parent_fsync_precondition_failed"
            return false
        }
        if (!this.publicParentStillBound()) {
            this.diagnostic = "composition_parent_binding_changed_after_publish"
            return false
        }
        this.syncParentAndValidate(forceFailure: forceFailure)
    }

    public func syncParentAndValidate(forceFailure!: Bool = false): Bool {
        if (!this.ok || this.parentFd < 0 || !this.publicParentStillBound()) {
            this.diagnostic = "composition_parent_binding_invalid"
            return false
        }
        if (forceFailure) {
            this.nativeErrno = 5
            this.diagnostic = "composition_parent_fsync_failed"
            return false
        }
        let synced = unsafe { fsync(this.parentFd) }
        this.nativeErrno = if (synced != 0) {
            unsafe { __error().read() }
        } else { Int32(0) }
        if (synced != 0) {
            this.diagnostic = "composition_parent_fsync_failed"
            return false
        }
        if (!this.publicParentStillBound()) {
            this.diagnostic = if (this.published) {
                "composition_parent_binding_changed_after_publish"
            } else { "composition_parent_binding_invalid" }
            return false
        }
        this.diagnostic = "ok"; true
    }

    public func readPublicTarget(maxBytes: Int64): (Bool, Array<UInt8>) {
        if (maxBytes < 1 || !this.publicParentStillBound()) {
            return (false, Array<UInt8>())
        }
        let publicParent = this.openPublicParent()
        if (publicParent < 0) { return (false, Array<UInt8>()) }
        try {
            let name = unsafe { LibC.mallocCString(this.targetName) }
            let fd = unsafe { openat(publicParent, name, 0x104, 0) }
            unsafe { LibC.free(name) }
            if (fd < 0 || p8DescriptorKind(fd) != "regular") {
                if (fd >= 0) { _ = unsafe { close(fd) } }
                return (false, Array<UInt8>())
            }
            try {
                let initial = p8StableDescriptorIdentity(fd)
                let bytes = ArrayList<UInt8>()
                while (true) {
                    let buffer = Array<UInt8>(8192, repeat: UInt8(0))
                    let count = unsafe {
                        let raw = acquireArrayRawData(buffer)
                        let value = read(fd, raw.pointer, UIntNative(buffer.size))
                        releaseArrayRawData(raw)
                        Int64(value)
                    }
                    if (count < 0 || bytes.size > maxBytes - count) {
                        return (false, Array<UInt8>())
                    }
                    if (count == 0) { break }
                    bytes.add(all: if (count == buffer.size) { buffer }
                        else { buffer[0..count].clone() })
                }
                if (bytes.size < 1 || initial == "" ||
                    p8StableDescriptorIdentity(fd) != initial) {
                    return (false, Array<UInt8>())
                }
                (true, bytes.toArray())
            } finally { _ = unsafe { close(fd) } }
        } finally { _ = unsafe { close(publicParent) } }
    }

    public func cleanup(): Bool {
        var removed = true
        if (!this.published && this.createdByThisInvocation &&
            this.parentFd >= 0 && this.payloadFd >= 0) {
            if (this.payloadIdentity == "") {
                this.payloadIdentity =
                    p8StableDescriptorIdentity(this.payloadFd)
            }
            let nameStillOwned = this.tempNameStillOwnedForCleanup()
            if (nameStillOwned) {
                let payload = unsafe { LibC.mallocCString(this.tempName) }
                removed = unsafe { unlinkat(this.parentFd, payload, 0) } == 0
                unsafe { LibC.free(payload) }
            } else {
                removed = false
            }
        }
        this.close(); removed
    }

    public func close(): Unit {
        if (this.payloadFd >= 0) { _ = unsafe { close(this.payloadFd) } }
        if (this.parentFd >= 0) { _ = unsafe { close(this.parentFd) } }
        if (this.grandparentFd >= 0) {
            _ = unsafe { close(this.grandparentFd) }
        }
        this.payloadFd = -1; this.parentFd = -1; this.grandparentFd = -1
    }

    private func openPublicParent(): Int32 {
        if (this.grandparentFd < 0 || this.grandparentPath == "" ||
            this.parentName == "" ||
            p8StableDescriptorIdentity(this.grandparentFd) !=
                this.grandparentIdentity) { return -1 }
        let publicGrandparent = p8OpenBundleDirectory(this.grandparentPath)
        if (publicGrandparent < 0 ||
            p8StableDescriptorIdentity(publicGrandparent) !=
                this.grandparentIdentity) {
            if (publicGrandparent >= 0) {
                _ = unsafe { close(publicGrandparent) }
            }
            return -1
        }
        let name = unsafe { LibC.mallocCString(this.parentName) }
        let observedFd = unsafe {
            openat(publicGrandparent, name, 0x100104, 0)
        }
        unsafe { LibC.free(name) }
        _ = unsafe { close(publicGrandparent) }
        if (observedFd < 0 || p8DescriptorKind(observedFd) != "directory" ||
            p8StableDescriptorIdentity(observedFd) != this.parentIdentity) {
            if (observedFd >= 0) { _ = unsafe { close(observedFd) } }
            return -1
        }
        observedFd
    }

    private func publicParentStillBound(): Bool {
        let observedFd = this.openPublicParent()
        if (observedFd < 0) { return false }
        let matched = p8DescriptorKind(observedFd) == "directory" &&
            p8StableDescriptorIdentity(observedFd) == this.parentIdentity
        _ = unsafe { close(observedFd) }
        matched
    }

    private func tempNameStillOwnedAndExclusive(): Bool {
        this.tempNameStillOwned(true)
    }

    private func tempNameStillOwnedForCleanup(): Bool {
        this.tempNameStillOwned(false)
    }

    private func tempNameStillOwned(requireSingleLink: Bool): Bool {
        if (this.parentFd < 0 || this.payloadFd < 0 ||
            this.payloadIdentity == "" ||
            p8StableDescriptorIdentity(this.payloadFd) !=
                this.payloadIdentity ||
            p8DescriptorKind(this.payloadFd) != "regular") { return false }
        if (requireSingleLink &&
            !p8DescriptorRegularSingleLink(this.payloadFd)) { return false }
        let name = unsafe { LibC.mallocCString(this.tempName) }
        let observedFd = unsafe { openat(this.parentFd, name, 0x104, 0) }
        unsafe { LibC.free(name) }
        if (observedFd < 0) { return false }
        let observed = p8StableDescriptorIdentity(observedFd)
        let regular = p8DescriptorKind(observedFd) == "regular"
        let exclusive = !requireSingleLink ||
            p8DescriptorRegularSingleLink(observedFd)
        _ = unsafe { close(observedFd) }
        observed == this.payloadIdentity && regular && exclusive
    }
}

public class CkbReproVerifyOptions {
    public var mode: String = ""
    public var workRoot: String = ""
    public var runtimeRoot: String = ""
    public var qdrantRoot: String = ""
    public var sourceRoot: String = ""
    public var candidateRoot: String = ""
    public var repositoryRoot: String = ""
    public var p0ManifestPath: String = ""
    public var p1ScoreContractPath: String = ""
    public var p2LogicalSnapshotPath: String = ""
    public var p3QdrantSnapshotPath: String = ""
    public var p4BuildProofPath: String = ""
    public var p6EnvironmentLockPath: String = ""
    public var p8ReferencePath: String = ""
    public var runCandidateCommit: String = ""
    public var releaseCommit: String = ""
    // There is intentionally no CLI option for a tag in either pre-tag mode.
    public var tag: String = ""
    public init() {}
}

public class CkbReproVerifyOptionsResult {
    public var ok: Bool = false
    public var diagnostic: String = "verify_options_not_parsed"
    public var options: CkbReproVerifyOptions = CkbReproVerifyOptions()
    public init() {}
}

public interface CkbReproReleaseVerifyEnvironmentProbe {
    func pathExists(path: String): Bool
    func pathIsEmptyDirectory(path: String): Bool
    func candidateEntryCount(path: String): Int64
    func inspectInput(path: String): CkbReproVerifyInputEvidence
    func canonicalReleaseRepository(): String
    func staleProcessCount(): Int64
    func privatePathDependencyCount(): Int64
}

public interface CkbReproVerifyEnvironmentProbe <:
    CkbReproReleaseVerifyEnvironmentProbe {
    func providerFingerprint(): String
    func modelIdentity(): String
}

public class CkbFilesystemReproVerifyEnvironmentProbe <:
    CkbReproVerifyEnvironmentProbe {
    private let candidateStore: FileKnowledgeStore
    private let pathContext: CkbPortablePathContext
    private let releaseRepository: String
    private let providerHash: String
    private let model: String
    private let staleCounter: () -> Int64

    public init(candidateStore: FileKnowledgeStore,
        pathContext: CkbPortablePathContext, releaseRepository: String,
        providerHash: String, model: String,
        staleCounter: () -> Int64) {
        this.candidateStore = candidateStore; this.pathContext = pathContext
        this.releaseRepository = releaseRepository
        this.providerHash = providerHash; this.model = model
        this.staleCounter = staleCounter
    }
    public func pathExists(path: String): Bool { exists(Path(path)) }
    public func pathIsEmptyDirectory(path: String): Bool {
        try { Directory.readFrom(Path(path)).size == 0 }
        catch (_: Exception) { false }
    }
    public func candidateEntryCount(path: String): Int64 {
        try { Directory.readFrom(Path(path)).size }
        catch (_: Exception) { -1 }
    }
    public func inspectInput(path: String): CkbReproVerifyInputEvidence {
        p8InspectProductionInput(path)
    }
    public func canonicalReleaseRepository(): String {
        this.releaseRepository
    }
    public func providerFingerprint(): String { this.providerHash }
    public func modelIdentity(): String { this.model }
    public func staleProcessCount(): Int64 { this.staleCounter() }
    public func privatePathDependencyCount(): Int64 {
        let snapshot = this.candidateStore.loadActiveSnapshot()
        if (!snapshot.valid) { return 1 }
        let input = CkbStudentVisiblePathInput()
        for (record in snapshot.rawRecords) { input.rawRecords.add(record) }
        for (record in snapshot.normalizedRecords) {
            input.normalizedRecords.add(record)
        }
        for (record in snapshot.activeIndex) { input.activeRecords.add(record) }
        for (record in snapshot.vectorRecords) { input.vectorRecords.add(record) }
        let report = scanCkbStudentVisiblePaths(input, this.pathContext)
        if (!report.ready) { return report.findings.size + 1 }
        report.machinePathCount + report.unmappedCount
    }
}

public class CkbReleaseFilesystemReproVerifyEnvironmentProbe <:
    CkbReproReleaseVerifyEnvironmentProbe {
    private let candidateRoot: String
    private let releaseRepository: String
    private let staleCounter: () -> Int64
    public init(candidateRoot: String, releaseRepository: String,
        staleCounter: () -> Int64) {
        this.candidateRoot = candidateRoot
        this.releaseRepository = releaseRepository
        this.staleCounter = staleCounter
    }
    public func pathExists(path: String): Bool { exists(Path(path)) }
    public func pathIsEmptyDirectory(path: String): Bool {
        try { Directory.readFrom(Path(path)).size == 0 }
        catch (_: Exception) { false }
    }
    public func candidateEntryCount(path: String): Int64 {
        try { Directory.readFrom(Path(path)).size }
        catch (_: Exception) { -1 }
    }
    public func inspectInput(path: String): CkbReproVerifyInputEvidence {
        p8InspectProductionInput(path)
    }
    public func canonicalReleaseRepository(): String {
        this.releaseRepository
    }
    public func staleProcessCount(): Int64 { this.staleCounter() }
    public func privatePathDependencyCount(): Int64 {
        if (this.candidateRoot == "") { return 1 }
        let read = p8ReadPortablePathReport(this.candidateRoot)
        if (read[0] != "ok") { return 1 }
        try {
            let text = String.fromUtf8(read[1])
            let object = JsonValue.fromStr(text).asObject()
            if (object.size() != 5 ||
                !object.get("ready").getOrThrow().asBool().getValue() ||
                object.get("scannedFieldCount").getOrThrow().asInt()
                    .getValue() < 0 ||
                object.get("machinePathCount").getOrThrow().asInt()
                    .getValue() != 0 ||
                object.get("unmappedCount").getOrThrow().asInt()
                    .getValue() != 0 ||
                object.get("findings").getOrThrow().asArray()
                    .getItems().size != 0) { return 1 }
            0
        } catch (_: Exception) { 1 }
    }
}

private func p8ReadPortablePathReport(root: String):
    (String, Array<UInt8>) {
    let reader = CkbReproFilesystemBundleReadBackend()
    if (!reader.rootExists(root)) { return ("bundle_root_invalid", []) }
    var expected: ?CkbReproBundleReadEntry = None
    for (entry in reader.list(root)) {
        if (entry.relativePath == "portable-path-report.json") {
            if (expected.isSome()) { return ("report_duplicate", []) }
            expected = Some(entry)
        }
    }
    let entry = match (expected) {
        case Some(value) => value
        case None => return ("report_missing", [])
    }
    if (entry.kind != "regular" || !entry.withinRoot || entry.size < 1 ||
        entry.size > 64 * 1024) { return ("report_invalid", []) }
    var handle: ?CkbReproBundleReadHandle = None
    try {
        let opened = reader.open(root, entry); handle = Some(opened)
        if (!opened.noFollow()) { return ("report_invalid", []) }
        let bytes = ArrayList<UInt8>(); let buffer = Array<UInt8>(4096, repeat: 0)
        while (true) {
            let count = opened.read(buffer)
            if (count < 0) { return ("report_read_failed", []) }
            if (count == 0) { break }
            if (bytes.size + count > 64 * 1024) {
                return ("report_too_large", [])
            }
            for (i in 0..count) { bytes.add(buffer[i]) }
        }
        let observed = opened.observedEntry()
        if (observed.identity != entry.identity || observed.size != entry.size ||
            observed.kind != "regular" || !observed.withinRoot) {
            return ("report_identity_drift", [])
        }
        ("ok", bytes.toArray())
    } catch (_: Exception) { ("report_read_failed", []) }
    finally {
        if (let Some(opened) <- handle) { try { opened.close() } catch (_: Exception) {} }
    }
}

private func p8InspectProductionInput(
    pathText: String): CkbReproVerifyInputEvidence {
    let out = CkbReproVerifyInputEvidence()
    let path = Path(pathText)
    if (!path.isAbsolute() || !exists(path)) { return out }
    let canonical = try { canonicalize(path).toString() }
        catch (_: Exception) { return out }
    if (canonical != pathText) { return out }
    var fd: Int32 = -1
    try {
        fd = p8OpenBundlePath(pathText)
        if (fd < 0) { return out }
        let before = Array<UInt8>(144, repeat: UInt8(0))
        let beforeOk = unsafe {
            let pointer = acquireArrayRawData(before)
            let status = fstat(fd, pointer.pointer)
            releaseArrayRawData(pointer); status == 0
        }
        if (!beforeOk ||
            (p8LittleEndian(before, 4, 2) & UInt64(0xf000)) !=
                UInt64(0x8000) ||
            p8LittleEndian(before, 6, 2) != UInt64(1)) { return out }
        let digest = SHA256(); var size: Int64 = 0
        let buffer = Array<UInt8>(65536, repeat: UInt8(0))
        while (true) {
            let count = unsafe {
                let pointer = acquireArrayRawData(buffer)
                let value = read(fd, pointer.pointer, UIntNative(buffer.size))
                releaseArrayRawData(pointer); Int64(value)
            }
            if (count < 0 || count > buffer.size) { return out }
            if (count == 0) { break }
            size += count
            digest.write(if (count == buffer.size) { buffer }
                else { buffer[0..count].clone() })
        }
        let after = Array<UInt8>(144, repeat: UInt8(0))
        let afterOk = unsafe {
            let pointer = acquireArrayRawData(after)
            let status = fstat(fd, pointer.pointer)
            releaseArrayRawData(pointer); status == 0
        }
        let beforeIdentity = p8StatIdentity(before)
        let afterIdentity = p8StatIdentity(after)
        if (!afterOk || beforeIdentity == "" ||
            beforeIdentity != afterIdentity ||
            size != Int64(p8LittleEndian(before, 96, 8))) { return out }
        out.ok = true; out.regular = true; out.noFollow = true
        out.stable = true; out.size = size; out.identity = beforeIdentity
        out.sha256 = p8DigestHash(digest); out
    } finally { if (fd >= 0) { _ = unsafe { close(fd) } } }
}

private func p8StatIdentity(stat: Array<UInt8>): String {
    if (stat.size < 104) { return "" }
    "dev=${p8LittleEndian(stat, 0, 4)};" +
        "ino=${p8LittleEndian(stat, 8, 8)};" +
        "size=${p8LittleEndian(stat, 96, 8)};" +
        "mtime=${p8LittleEndian(stat, 48, 8)}:" +
        "${p8LittleEndian(stat, 56, 8)};" +
        "ctime=${p8LittleEndian(stat, 64, 8)}:" +
        "${p8LittleEndian(stat, 72, 8)}"
}

private func p8DigestHash(digest: SHA256): String {
    let digits = "0123456789abcdef".toRuneArray()
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(digits[Int64(byte / UInt8(16))])
        out.append(digits[Int64(byte % UInt8(16))])
    }
    "sha256:${out.toString()}"
}

public class CkbReproVerifyInputEvidence {
    public var ok: Bool = false
    public var regular: Bool = false
    public var noFollow: Bool = false
    public var stable: Bool = false
    public var size: Int64 = -1
    public var sha256: String = ""
    public var identity: String = ""
    public init() {}
}

public class CkbReproVerifyEnvironmentResult {
    public var ok: Bool = false
    public var startAllowed: Bool = false
    public var diagnostic: String = "verify_environment_not_checked"
    public var heap: CkbServiceHeapPreflightResult =
        CkbServiceHeapPreflightResult()
    public var optionsFingerprint: String = ""
    public var inputEvidenceHash: String = ""
    public var localToctouToken: String = ""
    public var canonicalReleaseRepository: String = ""
    public var providerFingerprint: String = ""
    public var modelIdentity: String = ""
    public let inputRoles = ArrayList<String>()
    public let inputHashes = ArrayList<String>()
    public let inputSizes = ArrayList<Int64>()
    public init() {}
}

public class CkbReproStageEvidence {
    public var ok: Bool = false
    public var diagnostic: String = "stage_not_run"
    public var knowledgeVersion: String = ""
    public var logicalManifestHash: String = ""
    public var vectorProofHash: String = ""
    public var sourceLockHash: String = ""
    public var pathProofHash: String = ""
    public var rawRecords: Int64 = 0
    public var normalizedRecords: Int64 = 0
    public var activeRecords: Int64 = 0
    public var vectorPoints: Int64 = 0
    public var vectorDimension: Int64 = 0
    public var leakageFindings: Int64 = 0
    public var pathFindings: Int64 = 0
    public var retrievalDiff: Int64 = 0
    public var mcpParityDiff: Int64 = 0
    public init() {}
}

public class CkbReproExpectedIdentity {
    public var knowledgeVersion: String = ""
    public var logicalManifestHash: String = ""
    public var vectorProofHash: String = ""
    public var sourceLockHash: String = ""
    public var pathProofHash: String = ""
    public var rawRecords: Int64 = 7818
    public var normalizedRecords: Int64 = 7978
    public var activeRecords: Int64 = 7978
    public var vectorPoints: Int64 = 7978
    public var vectorDimension: Int64 = 1024
    public init() {}
}

public interface CkbReproRunCertificationExecutor {
    func restore(options: CkbReproVerifyOptions): CkbReproStageEvidence
    func rebuild(options: CkbReproVerifyOptions): CkbReproStageEvidence
    func runReference(options: CkbReproVerifyOptions):
        CkbReproReferenceRunEvidence
    func cleanup(options: CkbReproVerifyOptions): Bool { true }
}

// P8-B deliberately has no provider or Runner method.
public interface CkbReproReleaseVerificationExecutor {
    func restore(options: CkbReproVerifyOptions): CkbReproStageEvidence
    func rebuild(options: CkbReproVerifyOptions): CkbReproStageEvidence
    func verifyPublicEvidence(options: CkbReproVerifyOptions):
        CkbReproContractResult
    func verifyDocumentation(options: CkbReproVerifyOptions):
        CkbReproContractResult
    func cleanup(options: CkbReproVerifyOptions): Bool { true }
}

public interface CkbReproRestoreStageOperation {
    func execute(options: CkbReproVerifyOptions): CkbReproStageEvidence
}

public interface CkbReproRebuildStageOperation {
    func execute(options: CkbReproVerifyOptions): CkbReproStageEvidence
}

public interface CkbReproReferenceRunOperation {
    func execute(options: CkbReproVerifyOptions): CkbReproReferenceRunEvidence
}

public interface CkbReproPublicEvidenceOperation {
    func execute(options: CkbReproVerifyOptions): CkbReproContractResult
}

public interface CkbReproDocumentationOperation {
    func execute(options: CkbReproVerifyOptions): CkbReproContractResult
}

public class CkbInProcessReproRunnerInvoker <: CkbReproRunnerInvoker {
    public init() {}
    public func generate(args: Array<String>, runRoot: String):
        (Int64, String) {
        runCangjieEvalAbcdeFromP8(args, runRoot, "")
    }
    public func evaluate(args: Array<String>, runRoot: String,
        expectedGenerationSeal: String): Int64 {
        runCangjieEvalAbcdeFromP8(
            args, runRoot, expectedGenerationSeal)[0]
    }
}

public interface CkbP8ReferenceRunInspector {
    func inspect(runRoot: String, authorityManifestText: String,
        reference: CkbReproReferenceManifest): CkbReproReferenceRunEvidence
}

public class CkbP8ProductionReferenceRunInspector <:
    CkbP8ReferenceRunInspector {
    public init() {}
    public func inspect(runRoot: String, authorityManifestText: String,
        reference: CkbReproReferenceManifest): CkbReproReferenceRunEvidence {
        let out = CkbReproReferenceRunEvidence()
        let gate = ckbStrictCertificationGateFromRunRoot(
            runRoot, authorityManifestText)
        let thresholdOnly = !gate.ok && gate.diagnostics.size == 1 &&
            gate.diagnostics[0] == "strict_pass_at_1_requirements_not_met"
        let results = p8InspectProductionInput(
            Path(runRoot).join("results.jsonl").toString())
        if ((!gate.ok && !thresholdOnly) || gate.total != 164 || !results.ok) {
            out.diagnostic = "reference_run_evidence_invalid"; return out
        }
        let projected = projectCkbPublicEvidenceFromRunFiles(
            runRoot, reference, bindReferenceOutcome: false)
        if (!projected.ok || projected.score.total != gate.total ||
            projected.score.unitFirstSamplePassed != gate.unitPass ||
            projected.score.strictPassed != gate.unitPassAt1 ||
            projected.score.transportUnresolved != gate.unresolvedTransport) {
            out.diagnostic = "reference_run_projection_invalid"; return out
        }
        out.totalCases = projected.score.total
        out.rawPassed = projected.score.unitFirstSamplePassed
        out.strictPassed = projected.score.strictPassed
        out.protocolInvalid = projected.score.protocolInvalid
        out.transportUnresolved = projected.score.transportUnresolved
        out.businessFailed = projected.score.businessFailed
        out.resultsHash = results.sha256; out.ok = true
        out.diagnostic = if (projected.score.strictPassed >= 151) {
            "ok"
        } else { "score_mismatch_hold" }
        out
    }
}

public class CkbP8ProductionReferenceRunOperation <:
    CkbReproReferenceRunOperation {
    private let reference: CkbReproReferenceManifest
    private let lock: CkbReproEnvironmentLock
    private let inputs: CkbReproRunnerInputs
    private let preflight: CkbReproEnvironmentPreflightResult
    private let runner: CkbReproRunnerInvoker
    private let authorityManifestText: String
    private let inspector: CkbP8ReferenceRunInspector
    public init(reference: CkbReproReferenceManifest,
        lock: CkbReproEnvironmentLock, inputs: CkbReproRunnerInputs,
        preflight: CkbReproEnvironmentPreflightResult,
        runner: CkbReproRunnerInvoker, authorityManifestText: String,
        inspector!: CkbP8ReferenceRunInspector =
            CkbP8ProductionReferenceRunInspector()) {
        this.reference = reference; this.lock = lock; this.inputs = inputs
        this.preflight = preflight; this.runner = runner
        this.authorityManifestText = authorityManifestText
        this.inspector = inspector
    }
    public func execute(options: CkbReproVerifyOptions):
        CkbReproReferenceRunEvidence {
        let out = CkbReproReferenceRunEvidence()
        if (options.mode != "run-certify" ||
            this.authorityManifestText == "") {
            out.diagnostic = "reference_run_inputs_invalid"; return out
        }
        let exitCode = runCkbReproCertifiedStudent(this.reference, this.lock,
            this.inputs, this.preflight, this.runner)
        if (exitCode != 0) {
            out.diagnostic = "reference_runner_failed"; return out
        }
        let runRoot = Path(this.inputs.runsRoot).join(
            this.inputs.runId).toString()
        this.inspector.inspect(
            runRoot, this.authorityManifestText, this.reference)
    }
}

public class CkbP8ProductionRestoreInputs {
    public var archiveBackend: ?CkbReleaseArchiveBackend = None
    public var pathPolicy: CkbReleasePathPolicy = CkbReleasePathPolicy()
    public var targetCollection: String = ""
    public var qdrantManifest: CkbQdrantSnapshotManifest =
        CkbQdrantSnapshotManifest()
    public var qdrantControl: ?CkbQdrantSnapshotExecutor = None
    public var qdrantFile: ?CkbQdrantSnapshotFileExecutor = None
    public var pathContext: CkbPortablePathContext = CkbPortablePathContext()
    public var parityManifest: CkbRetrievalParityManifest =
        CkbRetrievalParityManifest()
    public var parityBackend: ?CkbRetrievalParityBackend = None
    public var sourceLockHash: String = ""
    public var pathProofHash: String = ""
    public init() {}
}

public class CkbP8ProductionRestoreOperation <:
    CkbReproRestoreStageOperation {
    private let inputs: CkbP8ProductionRestoreInputs
    private let beforeRuntimeCleanup: () -> Bool
    public init(inputs: CkbP8ProductionRestoreInputs,
        beforeRuntimeCleanup!: () -> Bool = { => true }) {
        this.inputs = inputs
        this.beforeRuntimeCleanup = beforeRuntimeCleanup
    }
    public func execute(options: CkbReproVerifyOptions): CkbReproStageEvidence {
        if (exists(Path(options.runtimeRoot))) {
            return p8StageFailure("restore_runtime_root_exists")
        }
        let result = try { this.executeCore(options) }
            catch (_: Exception) { p8StageFailure("restore_operation_failed") }
        if (exists(Path(options.runtimeRoot))) {
            if (!this.beforeRuntimeCleanup()) {
                return p8StageFailure("restore_runtime_cleanup_precondition_failed")
            }
            if (!p8RemoveRuntimeRoot(options.runtimeRoot)) {
                return p8StageFailure("restore_runtime_cleanup_failed")
            }
        }
        result
    }
    private func executeCore(options: CkbReproVerifyOptions): CkbReproStageEvidence {
        let out = CkbReproStageEvidence()
        let archive = match (this.inputs.archiveBackend) {
            case Some(value) => value
            case None => out.diagnostic = "restore_archive_backend_required"; return out
        }
        let control = match (this.inputs.qdrantControl) {
            case Some(value) => value
            case None => out.diagnostic = "restore_qdrant_backend_required"; return out
        }
        let file = match (this.inputs.qdrantFile) {
            case Some(value) => value
            case None => out.diagnostic = "restore_qdrant_file_backend_required"; return out
        }
        let parityBackend = match (this.inputs.parityBackend) {
            case Some(value) => value
            case None => out.diagnostic = "restore_parity_backend_required"; return out
        }
        let inspected = inspectCkbReleaseArchive(
            archive, options.p2LogicalSnapshotPath)
        if (!inspected.ok) { out.diagnostic = inspected.diagnostic; return out }
        let logical = importCkbLogicalSnapshot(options.p2LogicalSnapshotPath,
            options.runtimeRoot, archive, pathPolicy: this.inputs.pathPolicy)
        if (!logical.ok) { out.diagnostic = logical.diagnostic; return out }
        if (logical.manifestHash != inspected.manifest.manifestHash) {
            out.diagnostic = "logical_snapshot_archive_manifest_mismatch"; return out
        }
        let restored = restoreCkbQdrantSnapshotFromFile(
            this.inputs.targetCollection, options.p3QdrantSnapshotPath,
            this.inputs.qdrantManifest, control, file)
        if (!restored.ok) {
            if (restored.targetAbsentConfirmed && restored.uploadAttempted) {
                return p8CreatedQdrantFailure(out, restored.diagnostic,
                    control, this.inputs.targetCollection)
            }
            out.diagnostic = restored.diagnostic; return out
        }
        let statusRequest = CkbQdrantSnapshotRequest()
        statusRequest.method = "GET"
        statusRequest.path = "/collections/${this.inputs.targetCollection}"
        let response = control.execute(statusRequest)
        if (response.statusCode < 200 || response.statusCode >= 300) {
            return p8CreatedQdrantFailure(out,
                "qdrant_snapshot_status_read_failed", control,
                this.inputs.targetCollection)
        }
        let status = parseCkbQdrantRestoredStatus(response.bodyBytes,
            this.inputs.targetCollection,
            this.inputs.qdrantManifest.payloadCanonicalHash)
        if (!status[0].ok) { return p8CreatedQdrantFailure(out,
            status[0].diagnostic, control, this.inputs.targetCollection) }
        let provider = CkbP3FilesystemVerificationInputProvider(
            options.runtimeRoot, this.inputs.pathContext)
        if (!provider.ready(this.inputs.qdrantManifest.collection)) {
            return p8CreatedQdrantFailure(out,
                "logical_snapshot_restore_readback_mismatch", control,
                this.inputs.targetCollection)
        }
        let verified = verifyRestoredCkbQdrantSnapshot(
            status[1], this.inputs.qdrantManifest, inspected.manifest,
            provider.visibleInput(this.inputs.qdrantManifest.collection),
            provider.pathContext(this.inputs.qdrantManifest.collection))
        if (!verified.ok) { return p8CreatedQdrantFailure(out,
            verified.diagnostic, control, this.inputs.targetCollection) }
        if (this.inputs.parityManifest.knowledgeVersion != logical.activeVersion ||
            this.inputs.parityManifest.logicalManifestHash != logical.manifestHash) {
            return p8CreatedQdrantFailure(out,
                "retrieval_parity_identity_mismatch", control,
                this.inputs.targetCollection)
        }
        let parity = verifyCkbRetrievalParityManifest(
            this.inputs.parityManifest, parityBackend)
        if (!parity.ok) { return p8CreatedQdrantFailure(out,
            parity.diagnostic, control, this.inputs.targetCollection) }
        out.knowledgeVersion = logical.activeVersion
        out.logicalManifestHash = logical.manifestHash
        out.vectorProofHash = this.inputs.qdrantManifest.vectorProofHash
        out.sourceLockHash = this.inputs.sourceLockHash
        out.pathProofHash = this.inputs.pathProofHash
        out.rawRecords = logical.rawCount
        out.normalizedRecords = logical.normalizedCount
        out.activeRecords = logical.indexCount
        out.vectorPoints = this.inputs.qdrantManifest.points
        out.vectorDimension = this.inputs.qdrantManifest.dimension
        let cleanup = CkbQdrantSnapshotRequest(); cleanup.method = "DELETE"
        cleanup.path = "/collections/${this.inputs.targetCollection}"
        let cleanupResponse = control.execute(cleanup)
        if (cleanupResponse.statusCode != 200 && cleanupResponse.statusCode != 202 &&
            cleanupResponse.statusCode != 404) {
            out.diagnostic = "restore_qdrant_cleanup_failed"; return out
        }
        out.ok = true; out.diagnostic = "ok"; out
    }
}

private func p8RemoveRuntimeRoot(root: String): Bool {
    var attempts: Int64 = 0
    while (exists(Path(root)) && attempts < 3) {
        try { remove(Path(root), recursive: true) }
        catch (_: Exception) {}
        attempts += 1
    }
    !exists(Path(root))
}

public class CkbP8ProductionRebuildInputs {
    public var publicBuildInputRoot: String = ""
    public var buildManifest: CkbReproBuildInputManifest =
        CkbReproBuildInputManifest()
    public var authority: CkbReproPrivateBuildAuthority =
        CkbReproPrivateBuildAuthority()
    public var reader: ?CkbReproBundleReadBackend = None
    public var materialBackend: ?CkbReproMaterializingSourceBackend = None
    public var materializer: ?CkbReproOwnedSourceMaterializer = None
    public var assembler: ?CkbReproActualSourceAssembler = None
    public var pipeline: ?CkbReproBuildBackend = None
    public var archiveBackend: ?CkbReleaseArchiveBackend = None
    public var qdrantManifest: CkbQdrantSnapshotManifest =
        CkbQdrantSnapshotManifest()
    public var targetCollection: String = ""
    public var qdrantControl: ?CkbQdrantSnapshotExecutor = None
    public var qdrantFile: ?CkbQdrantSnapshotFileExecutor = None
    public var parityManifest: CkbRetrievalParityManifest =
        CkbRetrievalParityManifest()
    public var parityBackend: ?CkbRetrievalParityBackend = None
    public var pathProofHash: String = ""
    public init() {}
}

public class CkbP8ProductionRebuildOperation <:
    CkbReproRebuildStageOperation {
    private let inputs: CkbP8ProductionRebuildInputs
    public init(inputs: CkbP8ProductionRebuildInputs) { this.inputs = inputs }
    public func execute(options: CkbReproVerifyOptions): CkbReproStageEvidence {
        let outputRoot = this.inputs.authority.outputRoot
        let temporaryRoot = this.inputs.authority.temporaryRoot
        if (exists(Path(outputRoot)) || exists(Path(temporaryRoot))) {
            return p8StageFailure("production_rebuild_root_exists")
        }
        let result = try { this.executeCore(options) }
            catch (_: Exception) { p8StageFailure("rebuild_operation_failed") }
        if (!result.ok) {
            for (root in [outputRoot, temporaryRoot]) {
                if (exists(Path(root))) {
                    try { remove(Path(root), recursive: true) }
                    catch (_: Exception) {
                        return p8StageFailure("production_rebuild_cleanup_failed")
                    }
                }
            }
        }
        result
    }
    private func executeCore(options: CkbReproVerifyOptions): CkbReproStageEvidence {
        let out = CkbReproStageEvidence()
        if (this.inputs.publicBuildInputRoot == "" ||
            !Path(this.inputs.publicBuildInputRoot).isAbsolute() ||
            this.inputs.publicBuildInputRoot == options.candidateRoot ||
            this.inputs.authority.outputRoot != options.runtimeRoot ||
            this.inputs.authority.temporaryRoot !=
                Path(options.workRoot).join("rebuild-temporary").toString() ||
            this.inputs.authority.outputRoot == this.inputs.authority.temporaryRoot) {
            out.diagnostic = "production_rebuild_root_mismatch"; return out
        }
        let reader = match (this.inputs.reader) {
            case Some(value) => value
            case None => out.diagnostic = "rebuild_reader_required"; return out
        }
        let materialBackend = match (this.inputs.materialBackend) {
            case Some(value) => value
            case None => out.diagnostic = "rebuild_material_backend_required"; return out
        }
        let materializer = match (this.inputs.materializer) {
            case Some(value) => value
            case None => out.diagnostic = "rebuild_materializer_required"; return out
        }
        let assembler = match (this.inputs.assembler) {
            case Some(value) => value
            case None => out.diagnostic = "rebuild_assembler_required"; return out
        }
        let pipeline = match (this.inputs.pipeline) {
            case Some(value) => value
            case None => out.diagnostic = "rebuild_pipeline_required"; return out
        }
        let archive = match (this.inputs.archiveBackend) {
            case Some(value) => value
            case None => out.diagnostic = "rebuild_archive_backend_required"; return out
        }
        let control = match (this.inputs.qdrantControl) {
            case Some(value) => value
            case None => out.diagnostic = "rebuild_qdrant_backend_required"; return out
        }
        let file = match (this.inputs.qdrantFile) {
            case Some(value) => value
            case None => out.diagnostic = "rebuild_qdrant_file_backend_required"; return out
        }
        let parityBackend = match (this.inputs.parityBackend) {
            case Some(value) => value
            case None => out.diagnostic = "rebuild_parity_backend_required"; return out
        }
        let inspected = inspectCkbReleaseArchive(
            archive, options.p2LogicalSnapshotPath)
        if (!inspected.ok) { out.diagnostic = inspected.diagnostic; return out }
        let built = runCkbReproProductionBuild(this.inputs.publicBuildInputRoot,
            this.inputs.buildManifest, this.inputs.authority, reader,
            materialBackend, materializer, assembler, pipeline)
        if (!built.ready || !built.proof.logicalReady ||
            built.proof.evalSupportPersisted != 0 || built.proof.vectorCount != 0 ||
            built.proof.vectorState != "DEGRADED") {
            out.diagnostic = if (built.diagnostic == "") {
                "production_rebuild_invalid"
            } else { built.diagnostic }
            return out
        }
        let store = FileKnowledgeStore(this.inputs.authority.outputRoot)
        let snapshot = store.loadActiveSnapshot()
        let metadata = store.loadMetadataStatus()
        if (!snapshot.valid || !metadata.valid ||
            snapshot.activeVersion != inspected.manifest.portableKnowledgeVersion ||
            snapshot.rawRecords.size != inspected.manifest.rawCount ||
            snapshot.normalizedRecords.size != inspected.manifest.normalizedCount ||
            ckbCertifiedNormalizedRecordsChecksum(snapshot.normalizedRecords) !=
                inspected.manifest.normalizedChecksum ||
            snapshot.activeIndex.size != inspected.manifest.indexCount ||
            snapshot.vectorRecords.size != 0 ||
            metadata.vectorState != EmbeddingProviderState.DEGRADED ||
            metadata.vectorIndexCount != 0) {
            out.diagnostic = "production_rebuild_readback_mismatch"; return out
        }
        let restored = restoreCkbQdrantSnapshotFromFile(
            this.inputs.targetCollection, options.p3QdrantSnapshotPath,
            this.inputs.qdrantManifest, control, file)
        if (!restored.ok) {
            if (restored.targetAbsentConfirmed && restored.uploadAttempted) {
                return p8CreatedQdrantFailure(out, restored.diagnostic,
                    control, this.inputs.targetCollection)
            }
            out.diagnostic = restored.diagnostic; return out
        }
        let request = CkbQdrantSnapshotRequest(); request.method = "GET"
        request.path = "/collections/${this.inputs.targetCollection}"
        let response = control.execute(request)
        if (response.statusCode < 200 || response.statusCode >= 300) {
            return p8CreatedQdrantFailure(out,
                "qdrant_snapshot_status_read_failed", control,
                this.inputs.targetCollection)
        }
        let status = parseCkbQdrantRestoredStatus(response.bodyBytes,
            this.inputs.targetCollection,
            this.inputs.qdrantManifest.payloadCanonicalHash)
        if (!status[0].ok) { return p8CreatedQdrantFailure(out,
            status[0].diagnostic, control, this.inputs.targetCollection) }
        let provider = CkbP3FilesystemVerificationInputProvider(
            this.inputs.authority.outputRoot, this.inputs.authority.pathContext)
        if (!provider.logicalReady()) {
            return p8CreatedQdrantFailure(out,
                "production_rebuild_readback_mismatch", control,
                this.inputs.targetCollection)
        }
        let verified = verifyRestoredCkbQdrantSnapshot(status[1],
            this.inputs.qdrantManifest, inspected.manifest,
            provider.visibleRuntimeInput(),
            provider.pathContext(this.inputs.qdrantManifest.collection))
        if (!verified.ok) { return p8CreatedQdrantFailure(out,
            verified.diagnostic, control, this.inputs.targetCollection) }
        if (this.inputs.parityManifest.knowledgeVersion != snapshot.activeVersion ||
            this.inputs.parityManifest.logicalManifestHash !=
                inspected.manifest.manifestHash) {
            return p8CreatedQdrantFailure(out,
                "retrieval_parity_identity_mismatch", control,
                this.inputs.targetCollection)
        }
        let parity = verifyCkbRetrievalParityManifest(
            this.inputs.parityManifest, parityBackend)
        if (!parity.ok) { return p8CreatedQdrantFailure(out,
            parity.diagnostic, control, this.inputs.targetCollection) }
        out.knowledgeVersion = snapshot.activeVersion
        out.logicalManifestHash = inspected.manifest.manifestHash
        out.vectorProofHash = this.inputs.qdrantManifest.vectorProofHash
        out.sourceLockHash = built.proof.sourceLockHash
        out.pathProofHash = this.inputs.pathProofHash
        out.rawRecords = snapshot.rawRecords.size
        out.normalizedRecords = snapshot.normalizedRecords.size
        out.activeRecords = snapshot.activeIndex.size
        out.vectorPoints = this.inputs.qdrantManifest.points
        out.vectorDimension = this.inputs.qdrantManifest.dimension
        out.ok = true; out.diagnostic = "ok"; out
    }
}

private func p8CreatedQdrantFailure(out: CkbReproStageEvidence,
    diagnostic: String, control: CkbQdrantSnapshotExecutor,
    collection: String): CkbReproStageEvidence {
    let request = CkbQdrantSnapshotRequest(); request.method = "DELETE"
    request.path = "/collections/${collection}"
    let response = control.execute(request)
    if (response.statusCode != 200 && response.statusCode != 202 &&
        response.statusCode != 404) {
        out.diagnostic = "qdrant_created_collection_cleanup_failed"
    } else { out.diagnostic = diagnostic }
    out
}

public class CkbProductionRestoreStageOperation <:
    CkbReproRestoreStageOperation {
    private let action: (CkbReproVerifyOptions) -> CkbReproStageEvidence
    public init(action: (CkbReproVerifyOptions) -> CkbReproStageEvidence) {
        this.action = action
    }
    public func execute(options: CkbReproVerifyOptions): CkbReproStageEvidence {
        this.action(options)
    }
}

public class CkbProductionRebuildStageOperation <:
    CkbReproRebuildStageOperation {
    private let action: (CkbReproVerifyOptions) -> CkbReproStageEvidence
    public init(action: (CkbReproVerifyOptions) -> CkbReproStageEvidence) {
        this.action = action
    }
    public func execute(options: CkbReproVerifyOptions): CkbReproStageEvidence {
        this.action(options)
    }
}

public class CkbProductionReferenceRunOperation <:
    CkbReproReferenceRunOperation {
    private let action: (CkbReproVerifyOptions) -> CkbReproReferenceRunEvidence
    public init(action: (CkbReproVerifyOptions) -> CkbReproReferenceRunEvidence) {
        this.action = action
    }
    public func execute(options: CkbReproVerifyOptions):
        CkbReproReferenceRunEvidence { this.action(options) }
}

public class CkbProductionPublicEvidenceOperation <:
    CkbReproPublicEvidenceOperation {
    private let action: (CkbReproVerifyOptions) -> CkbReproContractResult
    public init(action: (CkbReproVerifyOptions) -> CkbReproContractResult) {
        this.action = action
    }
    public func execute(options: CkbReproVerifyOptions):
        CkbReproContractResult { this.action(options) }
}

public class CkbProductionDocumentationOperation <:
    CkbReproDocumentationOperation {
    private let action: (CkbReproVerifyOptions) -> CkbReproContractResult
    public init(action: (CkbReproVerifyOptions) -> CkbReproContractResult) {
        this.action = action
    }
    public func execute(options: CkbReproVerifyOptions):
        CkbReproContractResult { this.action(options) }
}

public class CkbP8ProductionPublicEvidenceOperation <:
    CkbReproPublicEvidenceOperation {
    public init() {}
    public func execute(options: CkbReproVerifyOptions): CkbReproContractResult {
        let reader = CkbP8ManifestAuthorizedReader()
        if (!reader.start(options.candidateRoot).ok) {
            return p8Failure("public_evidence_binding_missing")
        }
        let standalone = reader.read("p5_public_evidence",
            "public-evidence-export.json", 64 * 1024)
        let archive = reader.read("p5_public_evidence",
            "ckb-public-reference-evidence.tar.zst", 64 * 1024 * 1024)
        let referenceBytes = reader.read("p8_reference",
            "reproducibility/manifests/reference-run.json", 1024 * 1024)
        if (!standalone[0].ok || !archive[0].ok || !referenceBytes[0].ok ||
            !reader.finish().ok ||
            !scanCkbPublicEvidenceLeakage(standalone[1]).ok ||
            !scanCkbPublicEvidenceLeakage(referenceBytes[1]).ok) {
            return p8Failure("public_evidence_binding_missing")
        }
        let publicManifest = parseCkbPublicEvidenceExportManifest(standalone[1])
        let reference = parseCkbReproReferenceManifest(referenceBytes[1])
        let referenceValidation = validateCkbReproReferenceManifest(reference[1])
        if (!publicManifest[0].ok ||
            !validateCkbPublicEvidenceExportManifest(publicManifest[1]).ok ||
            !reference[0].ok || !referenceValidation.ok ||
            publicManifest[1].referenceManifestHash !=
                referenceValidation.manifestHash ||
            publicManifest[1].privateResultsHash != reference[1].resultsHash ||
            publicManifest[1].runId != reference[1].runId ||
            publicManifest[1].knowledgeVersion != reference[1].knowledgeVersion ||
            publicManifest[1].providerFingerprint !=
                reference[1].providerFingerprint ||
            publicManifest[1].modelFingerprint != reference[1].modelFingerprint ||
            publicManifest[1].vectorProofHash != reference[1].vectorProofHash ||
            publicManifest[1].certifiedRunInputHash !=
                reference[1].certifiedRunInputHash ||
            reference[1].baselineKind != "portable_release" ||
            reference[1].evidenceStatus != "complete" ||
            reference[1].totalCases != 164 || reference[1].strictPassed < 151) {
            return p8Failure("public_evidence_binding_invalid")
        }
        try { p8VerifyAuthorizedPublicArchive(archive[1], options,
            publicManifest[1], reference[1]) }
        catch (_: Exception) { p8Failure("public_evidence_temp_cleanup_failed") }
    }
}

private func p8VerifyAuthorizedPublicArchive(bytes: Array<UInt8>,
    options: CkbReproVerifyOptions, publicManifest: CkbPublicEvidenceExportManifest,
    reference: CkbReproReferenceManifest): CkbReproContractResult {
    var workOwned = false
    let archivePath = Path(options.workRoot).join(
        "p8-public-evidence-readonly.archive")
    try {
        if (!exists(Path(options.workRoot))) {
            Directory.create(Path(options.workRoot), recursive: false)
            workOwned = true
        }
        if (exists(archivePath)) { return p8Failure("public_evidence_temp_exists") }
        File.writeTo(archivePath, bytes)
        let backend = CkbPortableReleaseArchiveBackend()
        let listed = backend.enumerate(archivePath.toString())
        if (!listed.ok || listed.entries.size != 3) {
            return p8Failure("public_evidence_archive_invalid")
        }
        let required = HashSet<String>()
        for (path in ["public-evidence.jsonl", "score.json", "manifest.json"]) {
            required.add(path)
        }
        for (entry in listed.entries) {
            if (entry.kind != CkbReleaseArchiveEntryKinds.REGULAR ||
                !required.contains(entry.path)) {
                return p8Failure("public_evidence_archive_invalid")
            }
            required.remove(entry.path)
        }
        if (required.size != 0) {
            return p8Failure("public_evidence_archive_invalid")
        }
        let evidence = backend.readRegular(archivePath.toString(),
            "public-evidence.jsonl")
        let scoreBytes = backend.readRegular(archivePath.toString(), "score.json")
        let manifestBytes = backend.readRegular(archivePath.toString(), "manifest.json")
        if (!evidence.ok || !scoreBytes.ok || !manifestBytes.ok ||
            evidence.bytes.size > 64 * 1024 * 1024 ||
            scoreBytes.bytes.size > 64 * 1024 ||
            manifestBytes.bytes.size > 64 * 1024 ||
            !scanCkbPublicEvidenceLeakage(evidence.bytes).ok ||
            !scanCkbPublicEvidenceLeakage(scoreBytes.bytes).ok ||
            !scanCkbPublicEvidenceLeakage(manifestBytes.bytes).ok) {
            return p8Failure("public_evidence_archive_invalid")
        }
        let evidenceText = try { String.fromUtf8(evidence.bytes) }
            catch (_: Exception) { return p8Failure("invalid_response_encoding") }
        let scoreText = try { String.fromUtf8(scoreBytes.bytes) }
            catch (_: Exception) { return p8Failure("invalid_response_encoding") }
        let archivedManifest = parseCkbPublicEvidenceExportManifest(
            manifestBytes.bytes)
        let score = parseCkbStrictScoreEvidenceJsonl(evidence.bytes)
        let runManifestHash = try {
            JsonValue.fromStr(evidenceText.split("\n")[0]).asObject()
                .get("runManifestHash").getOrThrow().asString().getValue()
        } catch (_: Exception) { "" }
        if (!archivedManifest[0].ok ||
            renderCkbPublicEvidenceExportManifest(archivedManifest[1]) !=
                renderCkbPublicEvidenceExportManifest(publicManifest) ||
            !score.valid || score.total != 164 || score.strictPassed < 151 ||
            runManifestHash == "" ||
            runManifestHash != publicManifest.runManifestHash ||
            scoreText.trimAscii() != renderCkbHumanEvalStrictScoreJson(score) ||
            benchmarkGapSha256(evidenceText) != publicManifest.publicEvidenceHash ||
            score.strictPassed != reference.strictPassed ||
            score.unitFirstSamplePassed != reference.rawPassed ||
            score.businessFailed != reference.businessFailed ||
            score.protocolInvalid != reference.protocolInvalid) {
            return p8Failure("public_evidence_archive_binding_invalid")
        }
        p8Success()
    } catch (_: Exception) { p8Failure("public_evidence_archive_failed") }
    finally {
        if (exists(archivePath)) {
            try { remove(archivePath) }
            catch (_: Exception) { throw Exception("public_evidence_temp_cleanup_failed") }
        }
        if (workOwned && exists(Path(options.workRoot))) {
            try { remove(Path(options.workRoot), recursive: true) }
            catch (_: Exception) { throw Exception("public_evidence_temp_cleanup_failed") }
        }
    }
}

public class CkbP8FilesystemDocumentationReader <:
    CkbReproDocumentationReader {
    private let authorized = CkbP8ManifestAuthorizedReader()
    public init() {}
    public func list(root: String): ArrayList<CkbReproDocumentationEntry> {
        let out = ArrayList<CkbReproDocumentationEntry>()
        if (!this.authorized.start(root).ok) { return out }
        let required = HashSet<String>()
        for (path in requiredCkbReproDocumentationFiles()) { required.add(path) }
        let seen = HashSet<String>(); var invalid = false
        for (asset in this.authorized.manifest().assets) {
            if (asset.role != "p7_documentation") { continue }
            if (!required.contains(asset.relativePath)) {
                if (asset.relativePath != "docs/service-http-operations.md") {
                    invalid = true
                }
                continue
            }
            if (seen.contains(asset.relativePath) ||
                asset.logicalAsset != asset.relativePath ||
                asset.partIndex != 0 || asset.partCount != 1 ||
                asset.size != asset.logicalSize || asset.sha256 != asset.logicalSha256) {
                invalid = true; continue
            }
            seen.add(asset.relativePath)
            let item = CkbReproDocumentationEntry()
            item.relativePath = asset.relativePath
            item.kind = CKB_REPRO_DOCUMENTATION_ENTRY_REGULAR
            out.add(item)
        }
        if (invalid || seen.size != required.size) { out.clear() }
        out
    }
    public func read(root: String, relativePath: String): CkbReproDocumentationRead {
        let out = CkbReproDocumentationRead()
        let read = this.authorized.read("p7_documentation", relativePath,
            4 * 1024 * 1024)
        out.found = read[0].ok; if (out.found) { out.bytes = read[1] }; out
    }
    public func finish(): CkbReproContractResult { this.authorized.finish() }
}

public class CkbP8ProductionDocumentationOperation <:
    CkbReproDocumentationOperation {
    private let registeredCommands: Array<String>
    public init(registeredCommands: Array<String>) {
        this.registeredCommands = registeredCommands
    }
    public func execute(options: CkbReproVerifyOptions): CkbReproContractResult {
        let reader = CkbP8FilesystemDocumentationReader()
        let evidence = validateCkbReproDocumentation(
            reader, options.candidateRoot,
            CKB_REPRO_DOCUMENTATION_MODE_RELEASE, this.registeredCommands)
        if (!evidence.ok) { return p8Failure(evidence.diagnostic) }
        reader.finish()
    }
}

public class CkbP8ManifestAuthorizedReader {
    private let backend = CkbReproFilesystemBundleReadBackend()
    private var root: String = ""
    private var loaded: CkbReproBundleLoadResult = CkbReproBundleLoadResult()
    public init() {}
    public func start(root: String): CkbReproContractResult {
        if (this.root != "") { return p8Failure("candidate_reader_reused") }
        let loaded = validateCkbReproBundleManifest(root, this.backend)
        if (!loaded.contract.ok) { return loaded.contract }
        this.root = root; this.loaded = loaded; p8Success()
    }
    public func manifest(): CkbReproBundleManifest { this.loaded.manifest }
    public func read(role: String, relativePath: String, maxBytes: Int64):
        (CkbReproContractResult, Array<UInt8>) {
    if (this.root == "" || !validateCkbReproBundleRelativePath(relativePath).ok ||
        maxBytes < 1 || maxBytes > 64 * 1024 * 1024) {
        return (p8Failure("candidate_file_invalid"), Array<UInt8>())
    }
    var asset = CkbReproBundleAsset(); var assetCount: Int64 = 0
    for (value in this.loaded.manifest.assets) {
        if (value.relativePath == relativePath && value.role == role &&
            value.logicalAsset == relativePath && value.partIndex == 0 &&
            value.partCount == 1 && value.size == value.logicalSize &&
            value.sha256 == value.logicalSha256) {
            asset = value; assetCount += 1
        }
    }
    var found = CkbReproBundleReadEntry(); var count: Int64 = 0
    for (entry in this.backend.list(this.root)) {
        if (entry.relativePath == relativePath) { found = entry; count += 1 }
    }
    if (assetCount != 1 || count != 1 || found.kind != "regular" ||
        found.size != asset.size || found.size > maxBytes) {
        return (p8Failure("candidate_file_invalid"), Array<UInt8>())
    }
    let bytes = ArrayList<UInt8>(); let handle = this.backend.open(this.root, found)
    try {
        while (true) {
            let buffer = Array<UInt8>(65536, repeat: UInt8(0))
            let size = handle.read(buffer)
            if (size < 0 || size > buffer.size || bytes.size + size > maxBytes) {
                return (p8Failure("candidate_file_read_failed"), Array<UInt8>())
            }
            if (size == 0) { break }
            bytes.add(all: if (size == buffer.size) { buffer }
                else { buffer[0..size].clone() })
        }
        let observed = handle.observedEntry()
        if (!handle.noFollow() || observed.relativePath != found.relativePath ||
            observed.kind != found.kind || observed.identity != found.identity ||
            observed.size != found.size || !observed.withinRoot) {
            return (p8Failure("candidate_file_changed"), Array<UInt8>())
        }
    } finally { handle.close() }
    let value = bytes.toArray()
    if (ckbReproBundleHash(value) != asset.sha256) {
        return (p8Failure("candidate_file_hash_mismatch"), Array<UInt8>())
    }
    (p8Success(), value)
    }
    public func finish(): CkbReproContractResult {
        if (this.root == "") { return p8Failure("candidate_reader_not_started") }
        let after = validateCkbReproBundleManifest(this.root, this.backend)
        if (!after.contract.ok || after.rootIdentity != this.loaded.rootIdentity ||
            after.manifest.inputSetHash != this.loaded.manifest.inputSetHash ||
            after.proofSetHash != this.loaded.proofSetHash) {
            return p8Failure("candidate_bundle_changed")
        }
        p8Success()
    }
}

public class CkbProductionRunCertificationExecutor <:
    CkbReproRunCertificationExecutor {
    private let restoreOperation: CkbReproRestoreStageOperation
    private let rebuildOperation: CkbReproRebuildStageOperation
    private let referenceOperation: CkbReproReferenceRunOperation
    private let cleanupAction: (CkbReproVerifyOptions) -> Bool
    public init(restoreOperation: CkbReproRestoreStageOperation,
        rebuildOperation: CkbReproRebuildStageOperation,
        referenceOperation: CkbReproReferenceRunOperation,
        cleanupAction!: (CkbReproVerifyOptions) -> Bool = { _: CkbReproVerifyOptions => true }) {
        this.restoreOperation = restoreOperation
        this.rebuildOperation = rebuildOperation
        this.referenceOperation = referenceOperation
        this.cleanupAction = cleanupAction
    }
    public func restore(options: CkbReproVerifyOptions): CkbReproStageEvidence {
        this.restoreOperation.execute(options)
    }
    public func rebuild(options: CkbReproVerifyOptions): CkbReproStageEvidence {
        this.rebuildOperation.execute(options)
    }
    public func runReference(options: CkbReproVerifyOptions):
        CkbReproReferenceRunEvidence {
        this.referenceOperation.execute(options)
    }
    public func cleanup(options: CkbReproVerifyOptions): Bool {
        this.cleanupAction(options)
    }
}

// This type deliberately cannot hold a reference runner or model provider.
public class CkbProductionReleaseVerificationExecutor <:
    CkbReproReleaseVerificationExecutor {
    private let restoreOperation: CkbReproRestoreStageOperation
    private let rebuildOperation: CkbReproRebuildStageOperation
    private let publicEvidenceOperation: CkbReproPublicEvidenceOperation
    private let documentationOperation: CkbReproDocumentationOperation
    private let cleanupAction: (CkbReproVerifyOptions) -> Bool
    public init(restoreOperation: CkbReproRestoreStageOperation,
        rebuildOperation: CkbReproRebuildStageOperation,
        publicEvidenceOperation: CkbReproPublicEvidenceOperation,
        documentationOperation: CkbReproDocumentationOperation,
        cleanupAction!: (CkbReproVerifyOptions) -> Bool = { _: CkbReproVerifyOptions => true }) {
        this.restoreOperation = restoreOperation
        this.rebuildOperation = rebuildOperation
        this.publicEvidenceOperation = publicEvidenceOperation
        this.documentationOperation = documentationOperation
        this.cleanupAction = cleanupAction
    }
    public func restore(options: CkbReproVerifyOptions): CkbReproStageEvidence {
        this.restoreOperation.execute(options)
    }
    public func rebuild(options: CkbReproVerifyOptions): CkbReproStageEvidence {
        this.rebuildOperation.execute(options)
    }
    public func verifyPublicEvidence(options: CkbReproVerifyOptions):
        CkbReproContractResult {
        this.publicEvidenceOperation.execute(options)
    }
    public func verifyDocumentation(options: CkbReproVerifyOptions):
        CkbReproContractResult {
        this.documentationOperation.execute(options)
    }
    public func cleanup(options: CkbReproVerifyOptions): Bool {
        this.cleanupAction(options)
    }
}

public func newCkbInjectedRunCertificationExecutorForTest(
    restore: CkbReproRestoreStageOperation,
    rebuild: CkbReproRebuildStageOperation,
    reference: CkbReproReferenceRunOperation):
    CkbReproRunCertificationExecutor {
    CkbProductionRunCertificationExecutor(restore, rebuild, reference)
}

public func newCkbP8AInjectedExecutorForTest(
    restore: CkbReproRestoreStageOperation,
    rebuild: CkbReproRebuildStageOperation,
    reference: CkbReproReferenceManifest,
    lock: CkbReproEnvironmentLock, inputs: CkbReproRunnerInputs,
    preflight: CkbReproEnvironmentPreflightResult,
    runner: CkbReproRunnerInvoker, authorityManifestText: String):
    CkbReproRunCertificationExecutor {
    CkbProductionRunCertificationExecutor(restore, rebuild,
        CkbP8ProductionReferenceRunOperation(reference, lock, inputs,
            preflight, runner, authorityManifestText))
}

public func newCkbP8AProductionExecutor(
    restore: CkbP8ProductionRestoreInputs,
    rebuild: CkbP8ProductionRebuildInputs,
    reference: CkbReproReferenceManifest,
    lock: CkbReproEnvironmentLock, inputs: CkbReproRunnerInputs,
    preflight: CkbReproEnvironmentPreflightResult,
    runner: CkbReproRunnerInvoker, authorityManifestText: String,
    lifecycle!: ?CkbP8OwnedLocalLifecycle = None):
    CkbReproRunCertificationExecutor {
    let restoreOperation: CkbReproRestoreStageOperation = match (lifecycle) {
        case Some(value) => CkbP8OwnedQdrantRestoreOperation(restore, value)
        case None => CkbP8ProductionRestoreOperation(restore)
    }
    let rebuildOperation: CkbReproRebuildStageOperation = match (lifecycle) {
        case Some(value) => CkbP8OwnedParityRebuildOperation(rebuild, value)
        case None => CkbP8ProductionRebuildOperation(rebuild)
    }
    CkbProductionRunCertificationExecutor(
        restoreOperation,
        rebuildOperation,
        CkbP8ProductionReferenceRunOperation(reference, lock, inputs,
            preflight, runner, authorityManifestText),
        cleanupAction: { options: CkbReproVerifyOptions =>
            p8CleanupP8OwnedState(options, rebuild, lifecycle) })
}

// P8-B has no Runner or model/provider parameter by construction.
public func newCkbP8BProductionExecutor(
    restore: CkbP8ProductionRestoreInputs,
    rebuild: CkbP8ProductionRebuildInputs,
    registeredCommands: Array<String>,
    lifecycle!: ?CkbP8OwnedLocalLifecycle = None):
    CkbReproReleaseVerificationExecutor {
    let restoreOperation: CkbReproRestoreStageOperation = match (lifecycle) {
        case Some(value) => CkbP8OwnedQdrantRestoreOperation(restore, value)
        case None => CkbP8ProductionRestoreOperation(restore)
    }
    let rebuildOperation: CkbReproRebuildStageOperation = match (lifecycle) {
        case Some(value) => CkbP8OwnedParityRebuildOperation(rebuild, value)
        case None => CkbP8ProductionRebuildOperation(rebuild)
    }
    CkbProductionReleaseVerificationExecutor(
        restoreOperation,
        rebuildOperation,
        CkbP8ProductionPublicEvidenceOperation(),
        CkbP8ProductionDocumentationOperation(registeredCommands),
        cleanupAction: { options: CkbReproVerifyOptions =>
            p8CleanupP8OwnedState(options, rebuild, lifecycle) })
}

private class CkbP8OwnedQdrantRestoreOperation <:
    CkbReproRestoreStageOperation {
    private let delegate: CkbP8ProductionRestoreOperation
    private let lifecycle: CkbP8OwnedLocalLifecycle
    public init(inputs: CkbP8ProductionRestoreInputs,
        lifecycle: CkbP8OwnedLocalLifecycle) {
        this.delegate = CkbP8ProductionRestoreOperation(inputs,
            beforeRuntimeCleanup: { => lifecycle.stopParityService() })
        this.lifecycle = lifecycle
    }
    public func execute(options: CkbReproVerifyOptions): CkbReproStageEvidence {
        let started = this.lifecycle.startQdrant(options)
        if (!started.ok) { return p8StageFailure(started.diagnostic) }
        let result = this.delegate.execute(options)
        if (!this.lifecycle.stopParityService()) {
            return p8StageFailure("p8_parity_service_stop_failed")
        }
        result
    }
}

private class CkbP8OwnedParityRebuildOperation <:
    CkbReproRebuildStageOperation {
    private let delegate: CkbP8ProductionRebuildOperation
    private let lifecycle: CkbP8OwnedLocalLifecycle
    public init(inputs: CkbP8ProductionRebuildInputs,
        lifecycle: CkbP8OwnedLocalLifecycle) {
        this.delegate = CkbP8ProductionRebuildOperation(inputs)
        this.lifecycle = lifecycle
    }
    public func execute(options: CkbReproVerifyOptions): CkbReproStageEvidence {
        let result = this.delegate.execute(options)
        if (!this.lifecycle.stopParityService()) {
            return p8StageFailure("p8_parity_service_stop_failed")
        }
        result
    }
}

private func p8CleanupP8OwnedState(options: CkbReproVerifyOptions,
    rebuild: CkbP8ProductionRebuildInputs,
    lifecycle: ?CkbP8OwnedLocalLifecycle): Bool {
    let rebuildCleaned = p8CleanupRebuildOwned(options, rebuild)
    let lifecycleCleaned = match (lifecycle) {
        case Some(value) => try { value.cleanup(options) }
            catch (_: Exception) { false }
        case None => true
    }
    rebuildCleaned && lifecycleCleaned
}

private func p8CleanupRebuildOwned(options: CkbReproVerifyOptions,
    inputs: CkbP8ProductionRebuildInputs): Bool {
    var ok = true
    for (root in [inputs.authority.outputRoot, inputs.authority.temporaryRoot,
        options.sourceRoot]) {
        if (root != "" && exists(Path(root))) {
            try { remove(Path(root), recursive: true) }
            catch (_: Exception) { ok = false }
        }
    }
    match (inputs.qdrantControl) {
        case Some(control) =>
            let request = CkbQdrantSnapshotRequest(); request.method = "DELETE"
            request.path = "/collections/${inputs.targetCollection}"
            let response = control.execute(request)
            if (response.statusCode != 200 && response.statusCode != 202 &&
                response.statusCode != 404) { ok = false }
        case None => ok = false
    }
    ok
}

// P8-B has no reference-run parameter by construction.
public func newCkbInjectedReleaseVerificationExecutorForTest(
    restore: CkbReproRestoreStageOperation,
    rebuild: CkbReproRebuildStageOperation,
    publicEvidence: CkbReproPublicEvidenceOperation,
    documentation: CkbReproDocumentationOperation):
    CkbReproReleaseVerificationExecutor {
    CkbProductionReleaseVerificationExecutor(
        restore, rebuild, publicEvidence, documentation)
}

public class CkbReproCertifiedRunHashInputs {
    public var logicalProofHash: String = ""
    public var vectorProofHash: String = ""
    public var datasetHash: String = ""
    public var authorityHash: String = ""
    public var environmentHash: String = ""
    public var experimentHash: String = ""
    public var inputEvidenceHash: String = ""
    public var repositoryRoot: String = ""
    public var runCriticalManifest: CkbRunCriticalFilesManifest =
        CkbRunCriticalFilesManifest()
    public init() {}
}

public class CkbReproReferenceRunEvidence {
    public var ok: Bool = false
    public var diagnostic: String = "reference_run_not_run"
    public var totalCases: Int64 = 0
    public var rawPassed: Int64 = 0
    public var strictPassed: Int64 = 0
    public var businessFailed: Int64 = 0
    public var protocolInvalid: Int64 = 0
    public var transportUnresolved: Int64 = 0
    public var resultsHash: String = ""
    public init() {}
}

public class CkbReproTargetScore {
    public var runValid: Bool = false
    public var targetScoreMatched: Bool = false
    public var status: String = "invalid_run"
    public init() {}
}

public class CkbReproRunCertificationResult {
    public var ok: Bool = false
    public var diagnostic: String = "run_certification_not_run"
    public var restored: CkbReproStageEvidence = CkbReproStageEvidence()
    public var rebuilt: CkbReproStageEvidence = CkbReproStageEvidence()
    public var run: CkbReproReferenceRunEvidence =
        CkbReproReferenceRunEvidence()
    public var target: CkbReproTargetScore = CkbReproTargetScore()
    public var certifiedRunInputHash: String = ""
    public var runCriticalTreeHash: String = ""
    public var runnerCalls: Int64 = 0
    public var downstreamCalls: Int64 = 0
    public var referenceManifest: CkbReproReferenceManifest =
        CkbReproReferenceManifest()
    public var referenceValidation: CkbReproContractResult =
        CkbReproContractResult()
    public init() {}
}

public class CkbReproReleaseVerificationResult {
    public var schemaVersion: String = "ckb-repro-verification-report-v1"
    public var ok: Bool = false
    public var diagnostic: String = "release_verification_not_run"
    public var verifiedReleaseInputSetHash: String = ""
    public var bundleProofSetHash: String = ""
    public var restored: CkbReproStageEvidence = CkbReproStageEvidence()
    public var rebuilt: CkbReproStageEvidence = CkbReproStageEvidence()
    public var publicEvidence: CkbReproContractResult =
        CkbReproContractResult()
    public var documentation: CkbReproContractResult =
        CkbReproContractResult()
    public var runnerCalls: Int64 = 0
    public var releaseCommit: String = ""
    public var certifiedRunInputHash: String = ""
    public var runCriticalTreeHash: String = ""
    public var referenceManifestHash: String = ""
    public var authorityHash: String = ""
    public init() {}
}

public class CkbReproVerifiedReleaseAuthority {
    public var ok: Bool = false
    public var diagnostic: String = "release_authority_not_verified"
    public var authorityHash: String = ""
    public var verifiedInputSetHash: String = ""
    public var proofSetHash: String = ""
    public var referenceManifestHash: String = ""
    public var releaseCommitHash: String = ""
    public var rolesComplete: Bool = false
    public var derivedAssetCount: Int64 = -1
    public init() {}
}

public interface CkbReproReleaseAssetAuthority {
    func validate(loaded: CkbReproBundleLoadResult,
        reference: CkbReproReferenceManifest, releaseCommit: String,
        preflight: CkbReproVerifyEnvironmentResult):
        CkbReproVerifiedReleaseAuthority
}

public class CkbReproReleaseAuthorityEvidence {
    public var role: String = ""
    public var logicalAsset: String = ""
    public var size: Int64 = 0
    public var sha256: String = ""
    public init() {}
}

public class CkbReproReleaseAuthorityContract {
    public let expected = ArrayList<CkbReproReleaseAuthorityEvidence>()
    public var authorityDeliveryMode: String = ""
    public var layoutHash: String = ""
    public init() {}
}

public func buildCkbReproReleaseAuthorityContract(
    inputs: ArrayList<CkbReproReleaseAuthorityEvidence>,
    authorityDeliveryMode: String):
    (CkbReproContractResult, CkbReproReleaseAuthorityContract) {
    let contract = CkbReproReleaseAuthorityContract()
    contract.authorityDeliveryMode = authorityDeliveryMode
    for (source in inputs) {
        let evidence = CkbReproReleaseAuthorityEvidence()
        evidence.role = source.role
        evidence.logicalAsset = source.logicalAsset
        evidence.size = source.size
        evidence.sha256 = source.sha256
        contract.expected.add(evidence)
    }
    contract.layoutHash = p8AuthorityLayoutHash(contract)
    let validation = p8ValidateAuthorityLayout(contract)
    (validation, contract)
}

public class CkbReproCanonicalReleaseAssetAuthority <:
    CkbReproReleaseAssetAuthority {
    private let contract: CkbReproReleaseAuthorityContract
    public init(contract: CkbReproReleaseAuthorityContract) {
        this.contract = contract
    }
    public func validate(loaded: CkbReproBundleLoadResult,
        reference: CkbReproReferenceManifest, releaseCommit: String,
        preflight: CkbReproVerifyEnvironmentResult):
        CkbReproVerifiedReleaseAuthority {
        p8ValidateReleaseAuthority(this.contract, loaded, reference,
            releaseCommit, preflight)
    }
}

public interface CkbReproNativeReadOperation {
    func read(fd: Int32, buffer: Array<UInt8>): Int64
    func errorNumber(): Int32
}

public func ckbReproReadRetryingInterrupt(fd: Int32,
    buffer: Array<UInt8>, operation: CkbReproNativeReadOperation): Int64 {
    while (true) {
        let count = operation.read(fd, buffer)
        if (count >= 0 || operation.errorNumber() != 4) { return count }
    }
    -1
}

private class P8NativeReadOperation <: CkbReproNativeReadOperation {
    public init() {}
    public func read(fd: Int32, buffer: Array<UInt8>): Int64 {
        unsafe {
            let pointer = acquireArrayRawData(buffer)
            let count = read(fd, pointer.pointer, UIntNative(buffer.size))
            releaseArrayRawData(pointer)
            Int64(count)
        }
    }
    public func errorNumber(): Int32 {
        unsafe { __error().read() }
    }
}

public class CkbReproFilesystemBundleReadBackend <:
    CkbReproBundleReadBackend {
    public init() {}
    public func rootExists(root: String): Bool {
        try { canonicalize(Path(root)).toString() == root }
        catch (_: Exception) { false }
    }
    public func rootIdentity(root: String): String {
        if (!this.rootExists(root)) { return "" }
        let fd = p8OpenBundlePath(root)
        if (fd < 0) { return "" }
        let entry = p8DescriptorEntry(fd, root, "")
        _ = unsafe { close(fd) }
        if (entry.kind == "directory") { entry.identity } else { "" }
    }
    public func list(root: String): ArrayList<CkbReproBundleReadEntry> {
        let out = ArrayList<CkbReproBundleReadEntry>()
        if (!this.rootExists(root)) { return out }
        p8ListBundleDirectory(root, Path(root), "", out)
        out
    }
    public func open(root: String, expected: CkbReproBundleReadEntry):
        CkbReproBundleReadHandle {
        if (!this.rootExists(root) ||
            !validateCkbReproBundleRelativePath(expected.relativePath).ok) {
            throw Exception("bundle path invalid")
        }
        P8FilesystemBundleReadHandle(root, expected.relativePath)
    }
}

public func ckbReproReadSingleFileNoFollow(path: String, maxBytes: Int64):
    (Bool, Array<UInt8>) {
    if (path == "" || maxBytes < 1) { return (false, Array<UInt8>()) }
    let input = Path(path); let name = input.fileName
    if (name == "" || name == "." || name == "..") {
        return (false, Array<UInt8>())
    }
    let root = try { canonicalize(input.parent).toString() }
        catch (_: Exception) { return (false, Array<UInt8>()) }
    if (Path(root).join(name).toString() != path) {
        return (false, Array<UInt8>())
    }
    let fd = p8OpenBundlePath(path)
    if (fd < 0) { return (false, Array<UInt8>()) }
    try {
        let expected = p8DescriptorEntry(fd, root, name)
        if (expected.kind != "regular" || !expected.withinRoot ||
            expected.identity == "" || expected.size < 1 ||
            expected.size > maxBytes) { return (false, Array<UInt8>()) }
        let bytes = ArrayList<UInt8>()
        let operation = P8NativeReadOperation()
        let buffer = Array<UInt8>(8192, repeat: UInt8(0))
        while (true) {
            let count = ckbReproReadRetryingInterrupt(fd, buffer, operation)
            if (count < 0) { return (false, Array<UInt8>()) }
            if (count == 0) { break }
            if (bytes.size > maxBytes - count ||
                bytes.size > expected.size - count) {
                return (false, Array<UInt8>())
            }
            bytes.add(all: if (count == buffer.size) { buffer }
                else { buffer[0..count].clone() })
        }
        let observed = p8DescriptorEntry(fd, root, name)
        if (bytes.size != expected.size ||
            !p8SingleFileEntryEqual(expected, observed)) {
            return (false, Array<UInt8>())
        }
        (true, bytes.toArray())
    } finally { _ = unsafe { close(fd) } }
}

private func p8SingleFileEntryEqual(left: CkbReproBundleReadEntry,
    right: CkbReproBundleReadEntry): Bool {
    left.relativePath == right.relativePath && left.kind == right.kind &&
        left.canonicalPath == right.canonicalPath &&
        left.withinRoot == right.withinRoot &&
        left.identity == right.identity && left.size == right.size
}

public func ckbReproDirectoryOwnershipIdentity(path: String): String {
    let canonical = try { canonicalize(Path(path)).toString() }
        catch (_: Exception) { return "" }
    if (canonical != path) { return "" }
    let fd = p8OpenBundlePath(path)
    if (fd < 0) { return "" }
    try {
        let entry = p8DescriptorEntry(fd, path, "")
        if (entry.kind != "directory" || entry.identity == "") { return "" }
        entry.identity.split(";size=")[0]
    } finally { _ = unsafe { close(fd) } }
}

public func ckbReproCleanupOwnedDirectory(path: String,
    expectedIdentity: String, fileNames: Array<String>,
    beforeFinalDirectoryUnlink!: () -> Unit = { => }): Bool {
    if (expectedIdentity == "") { return false }
    if (!exists(Path(path))) { return true }
    let input = Path(path); let name = input.fileName
    if (name == "" || name == "." || name == "..") { return false }
    let parent = try { canonicalize(input.parent).toString() }
        catch (_: Exception) { return false }
    if (Path(parent).join(name).toString() != path) { return false }
    let parentFd = p8OpenBundlePath(parent)
    if (parentFd < 0) { return false }
    try {
        let cname = unsafe { LibC.mallocCString(name) }
        let childFd = unsafe { openat(parentFd, cname, 0x104, 0) }
        unsafe { LibC.free(cname) }
        if (childFd < 0) { return false }
        try {
            let entry = p8DescriptorEntry(childFd, path, "")
            if (entry.kind != "directory" ||
                entry.identity.split(";size=")[0] != expectedIdentity) {
                return false
            }
            for (fileName in fileNames) {
                if (fileName == "" || fileName == "." || fileName == ".." ||
                    fileName.contains("/")) { return false }
                let childName = unsafe { LibC.mallocCString(fileName) }
                _ = unsafe { unlinkat(childFd, childName, 0) }
                unsafe { LibC.free(childName) }
            }
            let observed = p8DescriptorEntry(childFd, path, "")
            if (observed.kind != "directory" ||
                observed.identity.split(";size=")[0] != expectedIdentity) {
                return false
            }
        } finally { _ = unsafe { close(childFd) } }
        try { beforeFinalDirectoryUnlink() }
        catch (_: Exception) { return false }
        let finalName = unsafe { LibC.mallocCString(name) }
        let finalFd = unsafe { openat(parentFd, finalName, 0x104, 0) }
        if (finalFd < 0) {
            unsafe { LibC.free(finalName) }; return false
        }
        let finalEntry = try { p8DescriptorEntry(finalFd, path, "") }
            finally { _ = unsafe { close(finalFd) } }
        if (finalEntry.kind != "directory" ||
            finalEntry.identity.split(";size=")[0] != expectedIdentity) {
            unsafe { LibC.free(finalName) }; return false
        }
        let removed = unsafe { unlinkat(parentFd, finalName, 0x80) } == 0
        unsafe { LibC.free(finalName) }
        removed && !exists(Path(path))
    } finally { _ = unsafe { close(parentFd) } }
}

private class P8FilesystemBundleReadHandle <:
    CkbReproBundleReadHandle {
    private let root: String
    private let relativePath: String
    private let fd: Int32
    private var closed: Bool = false
    public init(root: String, relativePath: String) {
        this.root = root
        this.relativePath = relativePath
        this.fd = p8OpenBundlePath("${root}/${relativePath}")
        if (this.fd < 0) { throw Exception("bundle open failed") }
        let initial = p8DescriptorEntry(this.fd, root, relativePath)
        if (initial.kind != "regular" || !initial.withinRoot) {
            _ = unsafe { close(this.fd) }
            this.closed = true
            throw Exception("bundle entry not regular")
        }
    }
    public func read(buffer: Array<UInt8>): Int64 {
        if (this.closed || buffer.size == 0) { return -1 }
        ckbReproReadRetryingInterrupt(this.fd, buffer,
            P8NativeReadOperation())
    }
    public func observedEntry(): CkbReproBundleReadEntry {
        if (this.closed) { return CkbReproBundleReadEntry() }
        p8DescriptorEntry(this.fd, this.root, this.relativePath)
    }
    public func noFollow(): Bool { !this.closed }
    public func close(): Unit {
        if (!this.closed) {
            this.closed = true
            if (unsafe { close(this.fd) } != 0) {
                throw Exception("bundle close failed")
            }
        }
    }
}

public func parseCkbReproVerifyOptions(args: Array<String>):
    CkbReproVerifyOptionsResult {
    let out = CkbReproVerifyOptionsResult()
    if (args.size == 0 || args.size % 2 != 0) {
        out.diagnostic = "verify_arguments_invalid"
        return out
    }
    let seen = HashSet<String>()
    var index: Int64 = 0
    while (index < args.size) {
        let key = args[index]
        let value = args[index + 1]
        if (seen.contains(key) || value == "") {
            out.diagnostic = "verify_argument_duplicate_or_empty"
            return out
        }
        seen.add(key)
        match (key) {
            case "--mode" => out.options.mode = value
            case "--work-root" => out.options.workRoot = value
            case "--runtime-root" => out.options.runtimeRoot = value
            case "--qdrant-root" => out.options.qdrantRoot = value
            case "--source-root" => out.options.sourceRoot = value
            case "--candidate-root" => out.options.candidateRoot = value
            case "--repository-root" => out.options.repositoryRoot = value
            case "--p0-manifest" => out.options.p0ManifestPath = value
            case "--p1-score-contract" =>
                out.options.p1ScoreContractPath = value
            case "--p2-logical-snapshot" =>
                out.options.p2LogicalSnapshotPath = value
            case "--p3-qdrant-snapshot" =>
                out.options.p3QdrantSnapshotPath = value
            case "--p4-build-proof" => out.options.p4BuildProofPath = value
            case "--p6-environment-lock" =>
                out.options.p6EnvironmentLockPath = value
            case "--p8-reference" => out.options.p8ReferencePath = value
            case "--run-candidate-commit" =>
                out.options.runCandidateCommit = value
            case "--release-commit" => out.options.releaseCommit = value
            case _ =>
                out.diagnostic = "verify_argument_unknown"
                return out
        }
        index += 2
    }
    let structural = p8ValidateOptions(out.options)
    out.ok = structural.ok
    out.diagnostic = structural.diagnostic
    out
}

public func validateCkbReproVerifyEnvironment(
    options: CkbReproVerifyOptions, heapRaw: String,
    probe: CkbReproVerifyEnvironmentProbe):
    CkbReproVerifyEnvironmentResult {
    try {
        p8ValidateEnvironmentUnchecked(options, heapRaw, probe, true,
            { => probe.providerFingerprint() },
            { => probe.modelIdentity() })
    } catch (_: Exception) {
        let out = CkbReproVerifyEnvironmentResult()
        out.diagnostic = "verify_environment_probe_failed"
        out
    }
}

public func validateCkbReproReleaseVerifyEnvironment(
    options: CkbReproVerifyOptions, heapRaw: String,
    probe: CkbReproReleaseVerifyEnvironmentProbe):
    CkbReproVerifyEnvironmentResult {
    try {
        p8ValidateEnvironmentUnchecked(options, heapRaw, probe, false,
            { => "" }, { => "" })
    } catch (_: Exception) {
        let out = CkbReproVerifyEnvironmentResult()
        out.diagnostic = "verify_environment_probe_failed"; out
    }
}

public func runCkbReproProductionCertification(args: Array<String>,
    heapRaw: String, expected: CkbReproExpectedIdentity,
    hashInputs: CkbReproCertifiedRunHashInputs,
    probe: CkbReproVerifyEnvironmentProbe,
    referenceTemplate: CkbReproReferenceManifest,
    executor: CkbReproRunCertificationExecutor):
    CkbReproRunCertificationResult {
    let parsed = parseCkbReproVerifyOptions(args)
    if (!parsed.ok || parsed.options.mode != "run-certify") {
        let out = CkbReproRunCertificationResult()
        out.diagnostic = if (!parsed.ok) { parsed.diagnostic }
            else { "verify_mode_mismatch" }
        return out
    }
    let preflight = validateCkbReproVerifyEnvironment(
        parsed.options, heapRaw, probe)
    if (!preflight.ok) {
        let out = CkbReproRunCertificationResult()
        out.diagnostic = preflight.diagnostic; return out
    }
    runCkbPortableReferenceHumanEval(parsed.options, expected, hashInputs,
        preflight, probe, referenceTemplate, executor)
}

public func runCkbReproProductionReleaseVerification(args: Array<String>,
    heapRaw: String, expected: CkbReproExpectedIdentity,
    reference: CkbReproReferenceManifest, expectedInputSetHash: String,
    expectedCertifiedRunInputHash: String,
    canonicalReleaseRepository: String,
    runCriticalManifest: CkbRunCriticalFilesManifest,
    authorityValidator: CkbReproReleaseAssetAuthority,
    probe: CkbReproReleaseVerifyEnvironmentProbe,
    backend: CkbReproBundleReadBackend,
    executor: CkbReproReleaseVerificationExecutor):
    CkbReproReleaseVerificationResult {
    let parsed = parseCkbReproVerifyOptions(args)
    if (!parsed.ok || parsed.options.mode != "release-verify") {
        let out = CkbReproReleaseVerificationResult()
        out.diagnostic = if (!parsed.ok) { parsed.diagnostic }
            else { "verify_mode_mismatch" }
        return out
    }
    let preflight = validateCkbReproReleaseVerifyEnvironment(
        parsed.options, heapRaw, probe)
    if (!preflight.ok) {
        let out = CkbReproReleaseVerificationResult()
        out.diagnostic = preflight.diagnostic; return out
    }
    verifyCkbUnsignedReleaseCandidate(parsed.options, expected, reference,
        expectedInputSetHash, expectedCertifiedRunInputHash,
        canonicalReleaseRepository, runCriticalManifest, authorityValidator,
        preflight, probe, backend, executor)
}

private func p8ValidateEnvironmentUnchecked(
    options: CkbReproVerifyOptions, heapRaw: String,
    probe: CkbReproReleaseVerifyEnvironmentProbe,
    onlineIdentityRequired: Bool,
    providerFingerprint: () -> String,
    modelIdentity: () -> String):
    CkbReproVerifyEnvironmentResult {
    let out = CkbReproVerifyEnvironmentResult()
    out.heap = ckbServiceHeapPreflight(heapRaw)
    let optionsValidation = p8ValidateOptions(options)
    if (!optionsValidation.ok) {
        out.diagnostic = optionsValidation.diagnostic
        return out
    }
    if (!out.heap.ok) {
        out.diagnostic = out.heap.errorCode
        return out
    }
    for (root in [options.workRoot, options.runtimeRoot,
        options.qdrantRoot, options.sourceRoot]) {
        if (probe.pathExists(root)) {
            out.diagnostic = if (probe.pathIsEmptyDirectory(root)) {
                "verify_root_must_not_exist"
            } else {
                "verify_root_contains_old_state"
            }
            return out
        }
    }
    if (!probe.pathExists(options.candidateRoot)) {
        out.diagnostic = "verify_candidate_missing"
        return out
    }
    if (probe.candidateEntryCount(options.candidateRoot) <= 0) {
        out.diagnostic = "verify_candidate_empty"
        return out
    }
    if (probe.staleProcessCount() != 0) {
        out.diagnostic = "verify_stale_process_detected"
        return out
    }
    if (probe.privatePathDependencyCount() != 0) {
        out.diagnostic = "verify_private_path_dependency"
        return out
    }
    let portableRows = ArrayList<String>()
    let localRows = ArrayList<String>()
    let paths = p8InputPaths(options)
    for (i in 0..paths.size) {
        let path = paths[i]
        let evidence = probe.inspectInput(path)
        if (!evidence.ok || !evidence.regular || !evidence.noFollow ||
            !evidence.stable || evidence.size < 0 ||
            !p8HashValid(evidence.sha256) || evidence.identity == "" ||
            p8HasControl(evidence.identity)) {
            out.diagnostic = "verify_input_evidence_invalid"
            return out
        }
        portableRows.add("${p8InputRole(options, i)}\t" +
            "${evidence.sha256}\t${evidence.size}")
        out.inputRoles.add(p8InputRole(options, i))
        out.inputHashes.add(evidence.sha256)
        out.inputSizes.add(evidence.size)
        localRows.add("${path}\t${evidence.identity}\t" +
            "${evidence.size}\t${evidence.sha256}")
    }
    out.optionsFingerprint = p8OptionsFingerprint(options)
    out.inputEvidenceHash = p8HashParts(
        "ckb-repro-portable-input-content-v1", portableRows.toArray())
    out.localToctouToken = p8HashParts(
        "ckb-repro-local-toctou-v1", localRows.toArray())
    out.canonicalReleaseRepository = probe.canonicalReleaseRepository()
    if (onlineIdentityRequired) {
        out.providerFingerprint = providerFingerprint()
        out.modelIdentity = modelIdentity()
    }
    if (out.canonicalReleaseRepository == "" ||
        (onlineIdentityRequired &&
        (!p8HashValid(out.providerFingerprint) || out.modelIdentity == ""))) {
        out.diagnostic = "verify_authority_identity_invalid"
        return out
    }
    out.ok = true
    out.startAllowed = true
    out.diagnostic = "ok"
    out
}

public func verifyRestoredCkbRelease(options: CkbReproVerifyOptions,
    expected: CkbReproExpectedIdentity,
    executor: CkbReproRunCertificationExecutor):
    CkbReproStageEvidence {
    try {
        p8ValidateStage(executor.restore(options), expected, false)
    } catch (_: Exception) {
        p8StageFailure("restore_executor_failed")
    }
}

public func verifyRebuiltCkbRelease(options: CkbReproVerifyOptions,
    expected: CkbReproExpectedIdentity,
    executor: CkbReproRunCertificationExecutor):
    CkbReproStageEvidence {
    try {
        p8ValidateStage(executor.rebuild(options), expected, true)
    } catch (_: Exception) {
        p8StageFailure("rebuild_executor_failed")
    }
}

public func computeCkbCertifiedRunInputHash(
    inputs: CkbReproCertifiedRunHashInputs): String {
    let critical = computeCkbRunCriticalTreeHash(
        inputs.runCriticalManifest, inputs.repositoryRoot)
    if (!p8HashValid(critical)) { return "" }
    for (hash in [inputs.logicalProofHash, inputs.vectorProofHash,
        inputs.datasetHash, inputs.authorityHash, inputs.environmentHash,
        inputs.experimentHash, inputs.inputEvidenceHash]) {
        if (!p8HashValid(hash)) { return "" }
    }
    let parts = [
        "logical=${inputs.logicalProofHash}",
        "vector=${inputs.vectorProofHash}",
        "dataset=${inputs.datasetHash}",
        "authority=${inputs.authorityHash}",
        "environment=${inputs.environmentHash}",
        "experiment=${inputs.experimentHash}",
        "inputEvidence=${inputs.inputEvidenceHash}",
        "runCritical=${critical}"
    ]
    p8HashParts("ckb-certified-run-input-v1", parts)
}

public func classifyCkbReferenceTargetScore(
    evidence: CkbReproReferenceRunEvidence): CkbReproTargetScore {
    let out = CkbReproTargetScore()
    if (!evidence.ok || evidence.totalCases != 164 ||
        evidence.strictPassed < 0 || evidence.strictPassed > 164 ||
        evidence.rawPassed < 0 || evidence.businessFailed < 0 ||
        evidence.protocolInvalid < 0 || evidence.transportUnresolved < 0 ||
        evidence.rawPassed < evidence.strictPassed ||
        evidence.rawPassed > 164 ||
        evidence.businessFailed + evidence.protocolInvalid + evidence.transportUnresolved !=
            164 - evidence.strictPassed ||
        !p8HashValid(evidence.resultsHash)) {
        return out
    }
    out.runValid = true
    out.targetScoreMatched = evidence.strictPassed >= 151
    out.status = if (out.targetScoreMatched) {
        "target_matched"
    } else {
        "score_mismatch_hold"
    }
    out
}

private func p8RunCkbPortableReferenceHumanEvalCore(
    options: CkbReproVerifyOptions, expected: CkbReproExpectedIdentity,
    hashInputs: CkbReproCertifiedRunHashInputs,
    preflight: CkbReproVerifyEnvironmentResult,
    probe: CkbReproVerifyEnvironmentProbe,
    referenceTemplate: CkbReproReferenceManifest,
    executor: CkbReproRunCertificationExecutor):
    CkbReproRunCertificationResult {
    let out = CkbReproRunCertificationResult()
    let start = p8ValidateExecutionStart(options, preflight, "run-certify")
    if (!start.ok) {
        out.diagnostic = start.diagnostic
        return out
    }
    if (hashInputs.repositoryRoot != options.repositoryRoot ||
        hashInputs.logicalProofHash != expected.logicalManifestHash ||
        hashInputs.vectorProofHash != expected.vectorProofHash ||
        hashInputs.inputEvidenceHash != preflight.inputEvidenceHash ||
        !p8ExpectedIdentityValid(expected)) {
        out.diagnostic = "certified_run_input_binding_mismatch"
        return out
    }
    if (referenceTemplate.providerFingerprint !=
        preflight.providerFingerprint ||
        referenceTemplate.model != preflight.modelIdentity ||
        referenceTemplate.knowledgeVersion != expected.knowledgeVersion ||
        referenceTemplate.vectorProofHash != expected.vectorProofHash) {
        out.diagnostic = "reference_template_identity_mismatch"
        return out
    }
    out.runCriticalTreeHash = computeCkbRunCriticalTreeHash(
        hashInputs.runCriticalManifest, hashInputs.repositoryRoot)
    out.certifiedRunInputHash =
        computeCkbCertifiedRunInputHash(hashInputs)
    if (!p8HashValid(out.certifiedRunInputHash)) {
        out.diagnostic = "certified_run_input_invalid"
        return out
    }
    out.restored = verifyRestoredCkbRelease(options, expected, executor)
    if (!out.restored.ok) {
        out.diagnostic = out.restored.diagnostic
        return out
    }
    out.rebuilt = verifyRebuiltCkbRelease(options, expected, executor)
    if (!out.rebuilt.ok) {
        out.diagnostic = out.rebuilt.diagnostic
        return out
    }
    let stable = p8RevalidateInputs(options, preflight, probe, true,
        { => probe.providerFingerprint() }, { => probe.modelIdentity() })
    if (!stable.ok) {
        out.diagnostic = stable.diagnostic
        return out
    }
    let criticalAfterPreflight = computeCkbRunCriticalTreeHash(
        hashInputs.runCriticalManifest, hashInputs.repositoryRoot)
    if (!p8HashValid(criticalAfterPreflight) ||
        criticalAfterPreflight != out.runCriticalTreeHash) {
        out.diagnostic = "run_critical_identity_drift"
        return out
    }
    out.runnerCalls = 1
    out.run = try { executor.runReference(options) }
        catch (_: Exception) {
            out.diagnostic = "reference_runner_failed"
            return out
        }
    out.target = classifyCkbReferenceTargetScore(out.run)
    if (!out.target.runValid) {
        out.diagnostic = "reference_run_invalid"
        return out
    }
    out.ok = out.target.targetScoreMatched
    out.diagnostic = out.target.status
    if (out.ok) {
        let written = writeCkbPortableReferenceManifest(
            referenceTemplate, out.run, options.runCandidateCommit,
            out.certifiedRunInputHash, out.runCriticalTreeHash)
        out.referenceValidation = written[0]
        out.referenceManifest = written[1]
        if (!out.referenceValidation.ok) {
            out.ok = false
            out.diagnostic = "portable_reference_write_invalid"
        }
    }
    out
}

public func runCkbPortableReferenceHumanEval(
    options: CkbReproVerifyOptions, expected: CkbReproExpectedIdentity,
    hashInputs: CkbReproCertifiedRunHashInputs,
    preflight: CkbReproVerifyEnvironmentResult,
    probe: CkbReproVerifyEnvironmentProbe,
    referenceTemplate: CkbReproReferenceManifest,
    executor: CkbReproRunCertificationExecutor):
    CkbReproRunCertificationResult {
    let out = try { p8RunCkbPortableReferenceHumanEvalCore(options, expected,
        hashInputs, preflight, probe, referenceTemplate, executor) }
        catch (_: Exception) {
            let failed = CkbReproRunCertificationResult()
            failed.diagnostic = "certification_unexpected_failure"; failed
        }
    let cleaned = try { executor.cleanup(options) }
        catch (_: Exception) { false }
    if (!cleaned) {
        out.ok = false; out.diagnostic += ";certification_cleanup_failed"
    }
    out
}

public func writeCkbPortableReferenceManifest(
    template: CkbReproReferenceManifest,
    run: CkbReproReferenceRunEvidence, runCandidateCommit: String,
    certifiedRunInputHash: String, runCriticalTreeHash: String):
    (CkbReproContractResult, CkbReproReferenceManifest) {
    let manifest = p8CopyReferenceManifest(template)
    manifest.baselineKind = "portable_release"
    manifest.evidenceStatus = "complete"
    manifest.runnerCommit = runCandidateCommit
    manifest.certifiedRunInputHash = certifiedRunInputHash
    manifest.runCriticalTreeHash = runCriticalTreeHash
    manifest.resultsHash = run.resultsHash
    manifest.totalCases = run.totalCases
    manifest.rawPassed = run.rawPassed
    manifest.strictPassed = run.strictPassed
    manifest.strictFailed = run.totalCases - run.strictPassed
    manifest.businessFailed = run.businessFailed
    manifest.protocolInvalid = run.protocolInvalid
    manifest.transportUnresolved = run.transportUnresolved
    manifest.missingEvidence.clear()
    let validation = validateCkbReproReferenceManifest(
        manifest, mode: "execution")
    (validation, manifest)
}

public func computeCkbVerifiedReleaseInputSetHash(
    bundle: CkbReproBundleManifest): String {
    computeCkbReproBundleInputSetHash(bundle.assets)
}

private func p8VerifyCkbUnsignedReleaseCandidateCore(
    options: CkbReproVerifyOptions, expected: CkbReproExpectedIdentity,
    reference: CkbReproReferenceManifest,
    expectedInputSetHash: String, expectedCertifiedRunInputHash: String,
    canonicalReleaseRepository: String,
    runCriticalManifest: CkbRunCriticalFilesManifest,
    authorityValidator: CkbReproReleaseAssetAuthority,
    preflight: CkbReproVerifyEnvironmentResult,
    probe: CkbReproReleaseVerifyEnvironmentProbe,
    backend: CkbReproBundleReadBackend,
    executor: CkbReproReleaseVerificationExecutor):
    CkbReproReleaseVerificationResult {
    let out = CkbReproReleaseVerificationResult()
    let start = p8ValidateExecutionStart(
        options, preflight, "release-verify")
    if (!start.ok) {
        out.diagnostic = start.diagnostic
        return out
    }
    if (!p8HashValid(expectedInputSetHash) ||
        !p8HashValid(expectedCertifiedRunInputHash)) {
        out.diagnostic = "release_expected_hash_invalid"
        return out
    }
    let referenceValidation = validateCkbReproReferenceManifest(
        reference, mode: "execution")
    if (!referenceValidation.ok || reference.baselineKind !=
        "portable_release" || reference.strictPassed < 151 ||
        reference.knowledgeVersion != expected.knowledgeVersion ||
        reference.vectorProofHash != expected.vectorProofHash ||
        !p8CommitValid(reference.runnerCommit) ||
        !p8HashValid(reference.certifiedRunInputHash) ||
        reference.certifiedRunInputHash != expectedCertifiedRunInputHash ||
        !p8HashValid(reference.runCriticalTreeHash)) {
        out.diagnostic = "portable_reference_invalid"
        return out
    }
    out.releaseCommit = options.releaseCommit
    out.certifiedRunInputHash = reference.certifiedRunInputHash
    out.runCriticalTreeHash = reference.runCriticalTreeHash
    out.referenceManifestHash = referenceValidation.manifestHash
    if (
        canonicalReleaseRepository !=
            preflight.canonicalReleaseRepository ||
        normalizeCkbReproRepositoryRemote(reference.observedRemote) !=
            canonicalReleaseRepository ||
        reference.releaseRepository != canonicalReleaseRepository) {
        out.diagnostic = "release_repository_mismatch"
        return out
    }
    let loaded = validateCkbReproBundleManifest(
        options.candidateRoot, backend)
    if (!loaded.contract.ok) {
        out.diagnostic = loaded.contract.diagnostic
        return out
    }
    out.verifiedReleaseInputSetHash =
        computeCkbVerifiedReleaseInputSetHash(loaded.manifest)
    out.bundleProofSetHash = loaded.proofSetHash
    if (out.verifiedReleaseInputSetHash != expectedInputSetHash) {
        out.diagnostic = "verified_release_input_changed"
        return out
    }
    let authority = try {
        authorityValidator.validate(
            loaded, reference, options.releaseCommit, preflight)
    } catch (_: Exception) {
        out.diagnostic = "release_asset_authority_failed"
        return out
    }
    if (!authority.ok || !p8HashValid(authority.authorityHash) ||
        !authority.rolesComplete || authority.derivedAssetCount != 0 ||
        authority.verifiedInputSetHash != expectedInputSetHash ||
        authority.proofSetHash != loaded.proofSetHash ||
        authority.referenceManifestHash != referenceValidation.manifestHash ||
        authority.releaseCommitHash !=
            ckbReproBundleHash(options.releaseCommit.toArray())) {
        out.diagnostic = "release_asset_authority_invalid"
        return out
    }
    out.authorityHash = authority.authorityHash
    let stable = p8RevalidateInputs(options, preflight, probe, false,
        { => "" }, { => "" })
    if (!stable.ok) {
        out.diagnostic = stable.diagnostic
        return out
    }
    let actualCritical = computeCkbRunCriticalTreeHash(
        runCriticalManifest, options.repositoryRoot)
    if (!p8HashValid(actualCritical) ||
        actualCritical != reference.runCriticalTreeHash) {
        out.diagnostic = "run_critical_changed_rerun_a"
        return out
    }
    let bundleStableBeforeRestore = p8RevalidateBundle(
        options.candidateRoot, expectedInputSetHash, loaded.proofSetHash,
        loaded.rootIdentity, backend)
    if (!bundleStableBeforeRestore.ok) {
        out.diagnostic = bundleStableBeforeRestore.diagnostic
        return out
    }
    out.restored = try {
        p8ValidateStage(executor.restore(options), expected, false)
    } catch (_: Exception) { p8StageFailure("restore_executor_failed") }
    if (!out.restored.ok) {
        out.diagnostic = out.restored.diagnostic
        return out
    }
    let bundleStableAfterRestore = p8RevalidateBundle(
        options.candidateRoot, expectedInputSetHash, loaded.proofSetHash,
        loaded.rootIdentity, backend)
    if (!bundleStableAfterRestore.ok) {
        out.diagnostic = bundleStableAfterRestore.diagnostic
        return out
    }
    out.rebuilt = try {
        p8ValidateStage(executor.rebuild(options), expected, true)
    } catch (_: Exception) { p8StageFailure("rebuild_executor_failed") }
    if (!out.rebuilt.ok) {
        out.diagnostic = out.rebuilt.diagnostic
        return out
    }
    let bundleStableAfterRebuild = p8RevalidateBundle(
        options.candidateRoot, expectedInputSetHash, loaded.proofSetHash,
        loaded.rootIdentity, backend)
    if (!bundleStableAfterRebuild.ok) {
        out.diagnostic = bundleStableAfterRebuild.diagnostic
        return out
    }
    out.publicEvidence = try { executor.verifyPublicEvidence(options) }
        catch (_: Exception) {
            p8Failure("public_evidence_executor_failed")
        }
    if (!out.publicEvidence.ok) {
        out.diagnostic = out.publicEvidence.diagnostic
        return out
    }
    let bundleStableAfterEvidence = p8RevalidateBundle(
        options.candidateRoot, expectedInputSetHash, loaded.proofSetHash,
        loaded.rootIdentity, backend)
    if (!bundleStableAfterEvidence.ok) {
        out.diagnostic = bundleStableAfterEvidence.diagnostic
        return out
    }
    out.documentation = try { executor.verifyDocumentation(options) }
        catch (_: Exception) {
            p8Failure("documentation_executor_failed")
        }
    if (!out.documentation.ok) {
        out.diagnostic = out.documentation.diagnostic
        return out
    }
    let bundleStableAfterDocs = p8RevalidateBundle(
        options.candidateRoot, expectedInputSetHash, loaded.proofSetHash,
        loaded.rootIdentity, backend)
    if (!bundleStableAfterDocs.ok) {
        out.diagnostic = bundleStableAfterDocs.diagnostic
        return out
    }
    out.ok = true
    out.diagnostic = "verified"
    out
}

public func verifyCkbUnsignedReleaseCandidate(
    options: CkbReproVerifyOptions, expected: CkbReproExpectedIdentity,
    reference: CkbReproReferenceManifest,
    expectedInputSetHash: String, expectedCertifiedRunInputHash: String,
    canonicalReleaseRepository: String,
    runCriticalManifest: CkbRunCriticalFilesManifest,
    authorityValidator: CkbReproReleaseAssetAuthority,
    preflight: CkbReproVerifyEnvironmentResult,
    probe: CkbReproReleaseVerifyEnvironmentProbe,
    backend: CkbReproBundleReadBackend,
    executor: CkbReproReleaseVerificationExecutor):
    CkbReproReleaseVerificationResult {
    let out = try { p8VerifyCkbUnsignedReleaseCandidateCore(options, expected,
        reference, expectedInputSetHash, expectedCertifiedRunInputHash,
        canonicalReleaseRepository, runCriticalManifest, authorityValidator,
        preflight, probe, backend, executor) } catch (_: Exception) {
            let failed = CkbReproReleaseVerificationResult()
            failed.diagnostic = "release_verification_unexpected_failure"; failed
        }
    let cleaned = try { executor.cleanup(options) }
        catch (_: Exception) { false }
    if (!cleaned) {
        out.ok = false
        out.diagnostic += ";release_verification_cleanup_failed"
    }
    out
}

public func renderCkbReproVerificationReport(
    result: CkbReproReleaseVerificationResult): String {
    "{\"schemaVersion\":\"ckb-repro-verification-report-v1\"," +
        "\"ok\":${result.ok}," +
        "\"diagnostic\":\"${p8Json(result.diagnostic)}\"," +
        "\"verifiedReleaseInputSetHash\":\"" +
        "${p8Json(result.verifiedReleaseInputSetHash)}\"," +
        "\"bundleProofSetHash\":\"${p8Json(result.bundleProofSetHash)}\"," +
        "\"releaseCommit\":\"${p8Json(result.releaseCommit)}\"," +
        "\"certifiedRunInputHash\":\"" +
        "${p8Json(result.certifiedRunInputHash)}\"," +
        "\"runCriticalTreeHash\":\"" +
        "${p8Json(result.runCriticalTreeHash)}\"," +
        "\"referenceManifestHash\":\"" +
        "${p8Json(result.referenceManifestHash)}\"," +
        "\"authorityHash\":\"${p8Json(result.authorityHash)}\"," +
        "\"restoreOk\":${result.restored.ok}," +
        "\"restoreDiagnostic\":\"" +
        "${p8Json(result.restored.diagnostic)}\"," +
        "\"rebuildOk\":${result.rebuilt.ok}," +
        "\"rebuildDiagnostic\":\"" +
        "${p8Json(result.rebuilt.diagnostic)}\"," +
        "\"publicEvidenceOk\":${result.publicEvidence.ok}," +
        "\"publicEvidenceDiagnostic\":\"" +
        "${p8Json(result.publicEvidence.diagnostic)}\"," +
        "\"documentationOk\":${result.documentation.ok}," +
        "\"documentationDiagnostic\":\"" +
        "${p8Json(result.documentation.diagnostic)}\"," +
        "\"runnerCalls\":${result.runnerCalls}}"
}

public func parseCkbReproVerificationReport(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbReproReleaseVerificationResult) {
    let out = CkbReproReleaseVerificationResult()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (p8Failure("invalid_response_encoding"), out)
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 19) {
            return (p8Failure("verification_report_invalid"), out)
        }
        out.schemaVersion = object.get("schemaVersion").getOrThrow()
            .asString().getValue()
        out.ok = object.get("ok").getOrThrow().asBool().getValue()
        out.diagnostic = object.get("diagnostic").getOrThrow()
            .asString().getValue()
        out.verifiedReleaseInputSetHash = object.get(
            "verifiedReleaseInputSetHash").getOrThrow().asString().getValue()
        out.bundleProofSetHash = object.get("bundleProofSetHash").getOrThrow()
            .asString().getValue()
        out.releaseCommit = object.get("releaseCommit").getOrThrow()
            .asString().getValue()
        out.certifiedRunInputHash = object.get("certifiedRunInputHash")
            .getOrThrow().asString().getValue()
        out.runCriticalTreeHash = object.get("runCriticalTreeHash")
            .getOrThrow().asString().getValue()
        out.referenceManifestHash = object.get("referenceManifestHash")
            .getOrThrow().asString().getValue()
        out.authorityHash = object.get("authorityHash").getOrThrow()
            .asString().getValue()
        out.restored.ok = object.get("restoreOk").getOrThrow()
            .asBool().getValue()
        out.restored.diagnostic = object.get("restoreDiagnostic").getOrThrow()
            .asString().getValue()
        out.rebuilt.ok = object.get("rebuildOk").getOrThrow()
            .asBool().getValue()
        out.rebuilt.diagnostic = object.get("rebuildDiagnostic").getOrThrow()
            .asString().getValue()
        out.publicEvidence.ok = object.get("publicEvidenceOk").getOrThrow()
            .asBool().getValue()
        out.publicEvidence.diagnostic = object.get("publicEvidenceDiagnostic")
            .getOrThrow().asString().getValue()
        out.documentation.ok = object.get("documentationOk").getOrThrow()
            .asBool().getValue()
        out.documentation.diagnostic = object.get("documentationDiagnostic")
            .getOrThrow().asString().getValue()
        out.runnerCalls = object.get("runnerCalls").getOrThrow()
            .asInt().getValue()
    } catch (_: Exception) {
        return (p8Failure("verification_report_invalid"),
            CkbReproReleaseVerificationResult())
    }
    (p8Success(), out)
}

public func validateCkbReproVerificationReport(
    report: CkbReproReleaseVerificationResult): CkbReproContractResult {
    if (report.schemaVersion != "ckb-repro-verification-report-v1" ||
        !report.ok || report.diagnostic != "verified" ||
        !report.restored.ok || report.restored.diagnostic != "ok" ||
        !report.rebuilt.ok || report.rebuilt.diagnostic != "ok" ||
        !report.publicEvidence.ok || report.publicEvidence.diagnostic != "ok" ||
        !report.documentation.ok || report.documentation.diagnostic != "ok" ||
        report.runnerCalls != 0 || !p8CommitValid(report.releaseCommit)) {
        return p8Failure("verification_report_invalid")
    }
    for (hash in [report.verifiedReleaseInputSetHash,
        report.bundleProofSetHash, report.certifiedRunInputHash,
        report.runCriticalTreeHash, report.referenceManifestHash,
        report.authorityHash]) {
        if (!p8HashValid(hash)) {
            return p8Failure("verification_report_invalid")
        }
    }
    p8Success()
}

private func p8ValidateOptions(options: CkbReproVerifyOptions):
    CkbReproContractResult {
    if (options.mode != "run-certify" &&
        options.mode != "release-verify") {
        return p8Failure("verify_mode_invalid")
    }
    let roots = [options.workRoot, options.runtimeRoot,
        options.qdrantRoot, options.sourceRoot, options.candidateRoot,
        options.repositoryRoot]
    for (root in roots) {
        if (!p8AbsoluteRoot(root)) {
            return p8Failure("verify_root_invalid")
        }
    }
    for (i in 0..roots.size) {
        for (j in i + 1..roots.size) {
            if (p8RootsOverlap(roots[i], roots[j])) {
                return p8Failure("verify_roots_overlap")
            }
        }
    }
    for (path in [options.p0ManifestPath, options.p1ScoreContractPath,
        options.p2LogicalSnapshotPath, options.p3QdrantSnapshotPath,
        options.p4BuildProofPath, options.p6EnvironmentLockPath]) {
        if (!p8AbsoluteFile(path)) {
            return p8Failure("verify_input_path_invalid")
        }
    }
    if (options.mode == "release-verify" &&
        !p8AbsoluteFile(options.p8ReferencePath)) {
        return p8Failure("verify_reference_path_invalid")
    }
    if (options.mode == "run-certify") {
        if (!p8CommitValid(options.runCandidateCommit) ||
            options.releaseCommit != "" || options.p8ReferencePath != "") {
            return p8Failure("run_candidate_commit_invalid")
        }
    } else if (!p8CommitValid(options.releaseCommit) ||
        options.runCandidateCommit != "") {
        return p8Failure("release_commit_invalid")
    }
    if (options.tag != "") { return p8Failure("verify_tag_forbidden") }
    p8Success()
}

private func p8InputPaths(options: CkbReproVerifyOptions): Array<String> {
    let paths = ArrayList<String>()
    for (path in [options.p0ManifestPath, options.p1ScoreContractPath,
        options.p2LogicalSnapshotPath, options.p3QdrantSnapshotPath,
        options.p4BuildProofPath, options.p6EnvironmentLockPath]) {
        paths.add(path)
    }
    if (options.mode == "release-verify") {
        paths.add(options.p8ReferencePath)
    }
    paths.toArray()
}

private func p8InputRole(options: CkbReproVerifyOptions, index: Int64):
    String {
    let roles = ["p0_manifest", "p1_score_contract",
        "p2_logical_snapshot", "p3_qdrant_snapshot", "p4_build_proof",
        "p6_environment_lock", "p8_reference"]
    if (index < 0 || index >= roles.size) { return "" }
    roles[index]
}

private func p8RevalidateInputs(options: CkbReproVerifyOptions,
    preflight: CkbReproVerifyEnvironmentResult,
    probe: CkbReproReleaseVerifyEnvironmentProbe,
    onlineIdentityRequired: Bool,
    providerFingerprint: () -> String,
    modelIdentity: () -> String): CkbReproContractResult {
    let portableRows = ArrayList<String>()
    let localRows = ArrayList<String>()
    try {
        let optionsValidation = p8ValidateOptions(options)
        if (!optionsValidation.ok ||
            p8OptionsFingerprint(options) != preflight.optionsFingerprint) {
            return p8Failure("verify_options_identity_drift")
        }
        if (probe.staleProcessCount() != 0) {
            return p8Failure("verify_stale_process_detected")
        }
        if (probe.privatePathDependencyCount() != 0) {
            return p8Failure("verify_private_path_dependency")
        }
        if (probe.canonicalReleaseRepository() !=
            preflight.canonicalReleaseRepository ||
            (onlineIdentityRequired &&
            (providerFingerprint() != preflight.providerFingerprint ||
            modelIdentity() != preflight.modelIdentity))) {
            return p8Failure("verify_authority_identity_drift")
        }
        let paths = p8InputPaths(options)
        for (i in 0..paths.size) {
            let evidence = probe.inspectInput(paths[i])
            if (!evidence.ok || !evidence.regular || !evidence.noFollow ||
                !evidence.stable || evidence.size < 0 ||
                !p8HashValid(evidence.sha256) ||
                evidence.identity == "") {
                return p8Failure("verify_input_evidence_invalid")
            }
            portableRows.add("${p8InputRole(options, i)}\t" +
                "${evidence.sha256}\t${evidence.size}")
            localRows.add("${paths[i]}\t${evidence.identity}\t" +
                "${evidence.size}\t${evidence.sha256}")
        }
    } catch (_: Exception) {
        return p8Failure("verify_environment_probe_failed")
    }
    if (p8HashParts("ckb-repro-portable-input-content-v1",
        portableRows.toArray()) != preflight.inputEvidenceHash ||
        p8HashParts("ckb-repro-local-toctou-v1",
        localRows.toArray()) != preflight.localToctouToken) {
        return p8Failure("verify_input_identity_drift")
    }
    p8Success()
}

private func p8RevalidateBundle(root: String, expectedInputSetHash: String,
    expectedProofSetHash: String, expectedRootIdentity: String,
    backend: CkbReproBundleReadBackend): CkbReproContractResult {
    let loaded = validateCkbReproBundleManifest(root, backend)
    if (!loaded.contract.ok || loaded.rootIdentity != expectedRootIdentity ||
        loaded.proofSetHash != expectedProofSetHash ||
        computeCkbVerifiedReleaseInputSetHash(loaded.manifest) !=
            expectedInputSetHash) {
        return p8Failure("bundle_revalidation_failed")
    }
    p8Success()
}

private func p8OptionsFingerprint(options: CkbReproVerifyOptions): String {
    p8HashParts("ckb-repro-verify-options-v1", [
        options.mode, options.workRoot, options.runtimeRoot,
        options.qdrantRoot, options.sourceRoot, options.candidateRoot,
        options.repositoryRoot, options.p0ManifestPath,
        options.p1ScoreContractPath, options.p2LogicalSnapshotPath,
        options.p3QdrantSnapshotPath, options.p4BuildProofPath,
        options.p6EnvironmentLockPath, options.p8ReferencePath,
        options.runCandidateCommit, options.releaseCommit
    ])
}

private func p8ValidateExecutionStart(options: CkbReproVerifyOptions,
    preflight: CkbReproVerifyEnvironmentResult,
    requiredMode: String): CkbReproContractResult {
    let optionsResult = p8ValidateOptions(options)
    if (!optionsResult.ok) { return optionsResult }
    if (options.mode != requiredMode) {
        return p8Failure("verify_state_mode_invalid")
    }
    if (!preflight.ok || !preflight.startAllowed ||
        preflight.optionsFingerprint != p8OptionsFingerprint(options) ||
        !p8HashValid(preflight.inputEvidenceHash)) {
        return p8Failure("verify_preflight_required")
    }
    p8Success()
}

private func p8StageFailure(diagnostic: String): CkbReproStageEvidence {
    let out = CkbReproStageEvidence()
    out.diagnostic = diagnostic
    out
}

private func p8ExpectedIdentityValid(
    expected: CkbReproExpectedIdentity): Bool {
    expected.knowledgeVersion != "" &&
        p8HashValid(expected.logicalManifestHash) &&
        p8HashValid(expected.vectorProofHash) &&
        p8HashValid(expected.sourceLockHash) &&
        p8HashValid(expected.pathProofHash) &&
        expected.rawRecords >= 0 && expected.normalizedRecords >= 0 &&
        expected.activeRecords >= 0 && expected.vectorPoints >= 0 &&
        expected.vectorDimension > 0
}

private func p8ValidateStage(stage: CkbReproStageEvidence,
    expected: CkbReproExpectedIdentity,
    requireSourceProof: Bool): CkbReproStageEvidence {
    if (!stage.ok) { return stage }
    if (stage.knowledgeVersion != expected.knowledgeVersion ||
        stage.logicalManifestHash != expected.logicalManifestHash ||
        stage.vectorProofHash != expected.vectorProofHash ||
        stage.rawRecords != expected.rawRecords ||
        stage.normalizedRecords != expected.normalizedRecords ||
        stage.activeRecords != expected.activeRecords ||
        stage.vectorPoints != expected.vectorPoints ||
        stage.vectorDimension != expected.vectorDimension) {
        stage.ok = false
        stage.diagnostic = "portable_identity_mismatch"
        return stage
    }
    if (stage.leakageFindings != 0 || stage.pathFindings != 0) {
        stage.ok = false
        stage.diagnostic = "portable_knowledge_findings"
        return stage
    }
    if (stage.retrievalDiff != 0 || stage.mcpParityDiff != 0) {
        stage.ok = false
        stage.diagnostic = "portable_retrieval_parity_mismatch"
        return stage
    }
    if (requireSourceProof &&
        (stage.sourceLockHash != expected.sourceLockHash ||
        stage.pathProofHash != expected.pathProofHash)) {
        stage.ok = false
        stage.diagnostic = "portable_rebuild_proof_mismatch"
        return stage
    }
    stage.diagnostic = "ok"
    stage
}

private func p8CopyReferenceManifest(source: CkbReproReferenceManifest):
    CkbReproReferenceManifest {
    let parsed = parseCkbReproReferenceManifest(
        renderCkbReproReferenceManifest(source).toArray())
    if (parsed[0].ok) { parsed[1] } else { CkbReproReferenceManifest() }
}

private func p8AuthorityFailure(diagnostic: String):
    CkbReproVerifiedReleaseAuthority {
    let out = CkbReproVerifiedReleaseAuthority()
    out.diagnostic = diagnostic
    out
}

private func p8OpenBundlePath(path: String): Int32 {
    let cpath = unsafe { LibC.mallocCString(path) }
    let fd = unsafe { open(cpath, 0x104) }
    unsafe { LibC.free(cpath) }
    fd
}

private func p8OpenBundleDirectory(path: String): Int32 {
    let cpath = unsafe { LibC.mallocCString(path) }
    let fd = unsafe { open(cpath, 0x100104) }
    unsafe { LibC.free(cpath) }
    fd
}

private func p8DescriptorKind(fd: Int32): String {
    let stat = Array<UInt8>(144, repeat: UInt8(0))
    let ok = unsafe {
        let raw = acquireArrayRawData(stat)
        let value = fstat(fd, raw.pointer) == 0
        releaseArrayRawData(raw)
        value
    }
    if (!ok) { return "" }
    let mode = p8LittleEndian(stat, 4, 2)
    if ((mode & UInt64(0xf000)) == UInt64(0x4000)) { "directory" }
    else if ((mode & UInt64(0xf000)) == UInt64(0x8000)) { "regular" }
    else { "special" }
}

private func p8DescriptorRegularSingleLink(fd: Int32): Bool {
    let stat = Array<UInt8>(144, repeat: UInt8(0))
    let ok = unsafe {
        let raw = acquireArrayRawData(stat)
        let value = fstat(fd, raw.pointer) == 0
        releaseArrayRawData(raw)
        value
    }
    if (!ok) { return false }
    let mode = p8LittleEndian(stat, 4, 2)
    let linkCount = p8LittleEndian(stat, 6, 2)
    (mode & UInt64(0xf000)) == UInt64(0x8000) &&
        linkCount == UInt64(1)
}

private func p8StableDescriptorIdentity(fd: Int32): String {
    let stat = Array<UInt8>(144, repeat: UInt8(0))
    let ok = unsafe {
        let raw = acquireArrayRawData(stat)
        let value = fstat(fd, raw.pointer) == 0
        releaseArrayRawData(raw)
        value
    }
    if (!ok || p8DescriptorKind(fd) == "special") { return "" }
    "dev=${p8LittleEndian(stat, 0, 4)};" +
        "ino=${p8LittleEndian(stat, 8, 8)}"
}

private func p8DescriptorEntry(fd: Int32, root: String,
    relativePath: String): CkbReproBundleReadEntry {
    let out = CkbReproBundleReadEntry()
    out.relativePath = relativePath
    let stat = Array<UInt8>(144, repeat: UInt8(0))
    let pathBytes = Array<UInt8>(1024, repeat: UInt8(0))
    var statOk = false
    var pathOk = false
    unsafe {
        let statPointer = acquireArrayRawData(stat)
        statOk = fstat(fd, statPointer.pointer) == 0
        releaseArrayRawData(statPointer)
        let pathPointer = acquireArrayRawData(pathBytes)
        pathOk = fcntl(fd, 50, pathPointer.pointer) == 0
        releaseArrayRawData(pathPointer)
    }
    if (!statOk || !pathOk) { return out }
    let mode = p8LittleEndian(stat, 4, 2)
    if ((mode & UInt64(0xf000)) == UInt64(0x8000)) {
        out.kind = "regular"
    } else if ((mode & UInt64(0xf000)) == UInt64(0x4000)) {
        out.kind = "directory"
    } else { out.kind = "special" }
    if (out.kind == "regular" && p8LittleEndian(stat, 6, 2) != UInt64(1)) {
        out.kind = "special"
    }
    let sizeBits = p8LittleEndian(stat, 96, 8)
    if ((sizeBits & (UInt64(1) << 63)) != 0) { return out }
    out.size = Int64(sizeBits)
    let chars = ArrayList<UInt8>()
    for (byte in pathBytes) {
        if (byte == UInt8(0)) { break }
        chars.add(byte)
    }
    out.canonicalPath = try { String.fromUtf8(chars.toArray()) }
        catch (_: Exception) { "" }
    out.withinRoot = out.canonicalPath == "${root}/${relativePath}"
    out.identity = "dev=${p8LittleEndian(stat, 0, 4)};" +
        "ino=${p8LittleEndian(stat, 8, 8)};size=${out.size};" +
        "mtime=${p8LittleEndian(stat, 48, 8)}:" +
        "${p8LittleEndian(stat, 56, 8)};" +
        "ctime=${p8LittleEndian(stat, 64, 8)}:" +
        "${p8LittleEndian(stat, 72, 8)}"
    out
}

private func p8LittleEndian(bytes: Array<UInt8>, offset: Int64,
    count: Int64): UInt64 {
    var value: UInt64 = 0
    for (i in 0..count) {
        value |= UInt64(bytes[offset + i]) << UInt64(i * 8)
    }
    value
}

private func p8ListBundleDirectory(root: String, directory: Path,
    prefix: String, out: ArrayList<CkbReproBundleReadEntry>): Unit {
    for (entry in Directory.readFrom(directory)) {
        let relative = if (prefix == "") { entry.name }
            else { "${prefix}/${entry.name}" }
        let path = validateCkbReproBundleRelativePath(relative)
        if (!path.ok) {
            let unsafeEntry = CkbReproBundleReadEntry()
            unsafeEntry.relativePath = relative
            unsafeEntry.kind = "special"
            out.add(unsafeEntry)
            continue
        }
        let fd = p8OpenBundlePath(entry.path.toString())
        if (fd < 0) {
            let unsafeEntry = CkbReproBundleReadEntry()
            unsafeEntry.relativePath = relative
            unsafeEntry.kind = "special"
            unsafeEntry.canonicalPath = "${root}/${relative}"
            out.add(unsafeEntry)
            continue
        }
        let observed = p8DescriptorEntry(fd, root, relative)
        _ = unsafe { close(fd) }
        out.add(observed)
        if (observed.kind == "directory" && observed.withinRoot) {
            p8ListBundleDirectory(root, entry.path, relative, out)
        }
    }
}

private func p8ValidateReleaseAuthority(
    contract: CkbReproReleaseAuthorityContract,
    loaded: CkbReproBundleLoadResult,
    reference: CkbReproReferenceManifest, releaseCommit: String,
    preflight: CkbReproVerifyEnvironmentResult):
    CkbReproVerifiedReleaseAuthority {
    let layout = p8ValidateAuthorityLayout(contract)
    if (!layout.ok) {
        return p8AuthorityFailure(layout.diagnostic)
    }
    if (!loaded.contract.ok || !p8HashValid(loaded.proofSetHash) ||
        !p8HashValid(loaded.manifest.inputSetHash)) {
        return p8AuthorityFailure("release_authority_bundle_invalid")
    }
    let mandatory = ["p0_manifest", "p1_score_contract",
        "p2_logical_snapshot", "p3_qdrant_snapshot", "p4_build_proof",
        "p5_public_evidence", "p6_environment_lock", "p7_documentation",
        "p8_reference", "source_lock", "authority_delivery",
        "portable_report", "license", "release_commit"]
    for (role in mandatory) {
        var count: Int64 = 0
        for (expected in contract.expected) {
            if (expected.role == role) { count += 1 }
        }
        let exactlyOne = role == "p8_reference" ||
            role == "release_commit"
        if (count == 0 || (exactlyOne && count != 1)) {
            return p8AuthorityFailure("release_authority_role_missing")
        }
    }
    let loadedGroups = HashSet<String>()
    for (asset in loaded.manifest.assets) {
        loadedGroups.add(asset.role + "\t" + asset.logicalAsset + "\t" +
            "${asset.logicalSize}\t${asset.logicalSha256}")
    }
    if (contract.expected.size != loadedGroups.size) {
        return p8AuthorityFailure("release_authority_contract_mismatch")
    }
    let contractKeys = HashSet<String>()
    for (expected in contract.expected) {
        let key = expected.role + "\t" + expected.logicalAsset
        if (contractKeys.contains(key) || expected.size < 0 ||
            !p8HashValid(expected.sha256)) {
            return p8AuthorityFailure("release_authority_contract_mismatch")
        }
        contractKeys.add(key)
        var matched = false
        for (asset in loaded.manifest.assets) {
            if (asset.role == expected.role &&
                asset.logicalAsset == expected.logicalAsset &&
                asset.logicalSize == expected.size &&
                asset.logicalSha256 == expected.sha256) { matched = true }
        }
        if (!matched) {
            return p8AuthorityFailure("release_authority_contract_mismatch")
        }
    }
    let requiredPreflight = HashSet<String>()
    for (role in ["p0_manifest", "p1_score_contract",
        "p2_logical_snapshot", "p3_qdrant_snapshot", "p4_build_proof",
        "p6_environment_lock", "p8_reference"]) {
        requiredPreflight.add(role)
    }
    let seenPreflight = HashSet<String>()
    for (i in 0..preflight.inputRoles.size) {
        if (i >= preflight.inputHashes.size || i >= preflight.inputSizes.size) {
            return p8AuthorityFailure("release_authority_preflight_mismatch")
        }
        if (!requiredPreflight.contains(preflight.inputRoles[i]) ||
            seenPreflight.contains(preflight.inputRoles[i])) {
            return p8AuthorityFailure("release_authority_preflight_mismatch")
        }
        seenPreflight.add(preflight.inputRoles[i])
        var matched = false
        for (expected in contract.expected) {
            if (p8AuthorityPreflightRole(expected.logicalAsset) ==
                    preflight.inputRoles[i] &&
                expected.sha256 == preflight.inputHashes[i] &&
                expected.size == preflight.inputSizes[i]) { matched = true }
        }
        if (!matched) {
            return p8AuthorityFailure("release_authority_preflight_mismatch")
        }
    }
    if (preflight.inputRoles.size != 7 ||
        preflight.inputHashes.size != 7 || preflight.inputSizes.size != 7 ||
        seenPreflight.size != requiredPreflight.size) {
        return p8AuthorityFailure("release_authority_preflight_mismatch")
    }
    let referenceValidation = validateCkbReproReferenceManifest(reference)
    if (!referenceValidation.ok) {
        return p8AuthorityFailure("release_authority_reference_mismatch")
    }
    var referenceMatched = false
    var commitMatched = false
    for (expected in contract.expected) {
        if (expected.role == "p8_reference" &&
            expected.sha256 == referenceValidation.manifestHash &&
            expected.size == referenceValidation.canonicalJson.toArray().size) {
            referenceMatched = true
        }
        if (expected.role == "release_commit" &&
            expected.sha256 == ckbReproBundleHash(releaseCommit.toArray()) &&
            expected.size == releaseCommit.toArray().size) {
            commitMatched = true
        }
    }
    if (!referenceMatched) {
        return p8AuthorityFailure("release_authority_reference_mismatch")
    }
    if (!p8CommitValid(releaseCommit) || !commitMatched) {
        return p8AuthorityFailure("release_authority_commit_mismatch")
    }
    let out = CkbReproVerifiedReleaseAuthority()
    out.ok = true
    out.diagnostic = "ok"
    out.verifiedInputSetHash = loaded.manifest.inputSetHash
    out.proofSetHash = loaded.proofSetHash
    out.referenceManifestHash = referenceValidation.manifestHash
    out.releaseCommitHash = ckbReproBundleHash(releaseCommit.toArray())
    out.authorityHash = computeCkbReproReleaseAuthorityHash(
        loaded, out.referenceManifestHash,
        referenceValidation.canonicalJson.toArray().size, releaseCommit)
    out.rolesComplete = true
    out.derivedAssetCount = 0
    out
}

public func computeCkbReproReleaseAuthorityHash(
    loaded: CkbReproBundleLoadResult, referenceManifestHash: String,
    referenceManifestSize: Int64, releaseCommit: String): String {
    if (!loaded.contract.ok || !p8HashValid(loaded.manifest.inputSetHash) ||
        !p8HashValid(loaded.proofSetHash) ||
        !p8HashValid(referenceManifestHash) || !p8CommitValid(releaseCommit)) {
        return ""
    }
    let inputs = ArrayList<CkbReproReleaseAuthorityEvidence>()
    let seen = HashSet<String>()
    var bundled = false; var publicRebuild = false
    for (asset in loaded.manifest.assets) {
        let key = asset.role + "\t" + asset.logicalAsset
        if (!seen.contains(key)) {
            seen.add(key)
            let evidence = CkbReproReleaseAuthorityEvidence()
            evidence.role = asset.role; evidence.logicalAsset = asset.logicalAsset
            evidence.size = asset.logicalSize; evidence.sha256 = asset.logicalSha256
            inputs.add(evidence)
        } else {
            var consistent = false
            for (evidence in inputs) {
                if (evidence.role == asset.role &&
                    evidence.logicalAsset == asset.logicalAsset &&
                    evidence.size == asset.logicalSize &&
                    evidence.sha256 == asset.logicalSha256) { consistent = true }
            }
            if (!consistent) { return "" }
        }
        if (asset.logicalAsset == "cangjie-humaneval-authority.tar.zst") {
            bundled = true
        }
        if (asset.logicalAsset == "authority-source-materials.json") {
            publicRebuild = true
        }
    }
    if (bundled == publicRebuild) { return "" }
    let built = buildCkbReproReleaseAuthorityContract(inputs,
        if (bundled) { "bundled" } else { "public_rebuild" })
    if (!built[0].ok) { return "" }
    var referenceMatched = false; var commitMatched = false
    for (evidence in built[1].expected) {
        if (evidence.role == "p8_reference" &&
            evidence.sha256 == referenceManifestHash &&
            evidence.size == referenceManifestSize) { referenceMatched = true }
        if (evidence.role == "release_commit" &&
            evidence.sha256 == ckbReproBundleHash(releaseCommit.toArray()) &&
            evidence.size == releaseCommit.toArray().size) { commitMatched = true }
    }
    if (!referenceMatched || !commitMatched) { return "" }
    let rows = ArrayList<String>()
    for (evidence in built[1].expected) {
        rows.add(evidence.role + "\t" + evidence.logicalAsset + "\t" +
            "${evidence.size}\t${evidence.sha256}")
    }
    let ordered = rows.toArray(); sort(ordered)
    p8HashParts("ckb-repro-release-authority-v1", [
        loaded.manifest.inputSetHash, loaded.proofSetHash,
        referenceManifestHash, ckbReproBundleHash(releaseCommit.toArray()),
        p8HashParts("ckb-repro-release-authority-contract-v1", ordered)])
}

private func p8AuthorityPreflightRole(logicalAsset: String): String {
    match (logicalAsset) {
        case "reproducibility/manifests/historical-reference-run.json" =>
            "p0_manifest"
        case "reproducibility/PUBLIC-EVIDENCE.schema.json" =>
            "p1_score_contract"
        case "ckb-logical-snapshot.tar.zst" => "p2_logical_snapshot"
        case "qdrant-collection.snapshot" => "p3_qdrant_snapshot"
        case "portable-logical-proof.json" => "p4_build_proof"
        case "reproducibility/manifests/environment-lock.json" =>
            "p6_environment_lock"
        case "reproducibility/manifests/reference-run.json" =>
            "p8_reference"
        case _ => ""
    }
}

public func ckbReproReleaseAuthorityRequiredLayout(mode: String):
    ArrayList<(String, String)> {
    let out = ArrayList<(String, String)>()
    for (row in [
        ("README.md", "p7_documentation"),
        ("docs/reproducibility/README.md", "p7_documentation"),
        ("docs/reproducibility/quick-start.md", "p7_documentation"),
        ("docs/reproducibility/restore-knowledge-base.md", "p7_documentation"),
        ("docs/reproducibility/rebuild-from-source.md", "p7_documentation"),
        ("docs/reproducibility/configure-claude-glm.md", "p7_documentation"),
        ("docs/reproducibility/freeze-humaneval-authority-delivery.md", "p7_documentation"),
        ("docs/reproducibility/run-humaneval-164.md", "p7_documentation"),
        ("docs/reproducibility/verify-strict-pass-at-1.md", "p7_documentation"),
        ("docs/reproducibility/result-interpretation.md", "p7_documentation"),
        ("docs/reproducibility/troubleshooting.md", "p7_documentation"),
        ("docs/reproducibility/release-maintainer-runbook.md", "p7_documentation"),
        ("docs/service-http-operations.md", "p7_documentation"),
        ("reproducibility/PUBLIC-EVIDENCE.schema.json", "p1_score_contract"),
        ("reproducibility/RELEASE-MANIFEST.schema.json", "p0_manifest"),
        ("reproducibility/authority-source-materials.schema.json", "authority_delivery"),
        ("reproducibility/source-lock.schema.json", "source_lock"),
        ("reproducibility/source-inventory.schema.json", "source_lock"),
        ("reproducibility/knowledge-selection.schema.json", "p0_manifest"),
        ("reproducibility/authority-delivery.schema.json", "authority_delivery"),
        ("reproducibility/environment-lock.schema.json", "p6_environment_lock"),
        ("reproducibility/historical-reference-evidence.schema.json", "p0_manifest"),
        ("reproducibility/reference-run.schema.json", "p0_manifest"),
        ("reproducibility/portable-path-policy.schema.json", "portable_report"),
        ("reproducibility/run-critical-files.schema.json", "p4_build_proof"),
        ("reproducibility/configs/provider.example.env", "p6_environment_lock"),
        ("reproducibility/configs/ckb.example.conf", "p6_environment_lock"),
        ("reproducibility/configs/claude-mcp.example.json", "p6_environment_lock"),
        ("reproducibility/configs/experiment-profile.json", "p1_score_contract"),
        ("reproducibility/manifests/source-lock.json", "source_lock"),
        ("reproducibility/manifests/source-inventory.jsonl", "source_lock"),
        ("reproducibility/manifests/portable-path-policy.json", "portable_report"),
        ("reproducibility/manifests/run-critical-files.json", "p4_build_proof"),
        ("reproducibility/manifests/knowledge-selection.jsonl", "p0_manifest"),
        ("reproducibility/manifests/environment-lock.json", "p6_environment_lock"),
        ("reproducibility/manifests/authority-delivery.json", "authority_delivery"),
        ("reproducibility/manifests/authority-source-materials.json", "authority_delivery"),
        ("reproducibility/manifests/historical-reference-evidence.json", "p0_manifest"),
        ("reproducibility/manifests/historical-reference-run.json", "p0_manifest"),
        ("reproducibility/manifests/reference-run.json", "p8_reference"),
        ("reproducibility/licenses/THIRD_PARTY_NOTICES.md", "license"),
        ("ckb-logical-snapshot.tar.zst", "p2_logical_snapshot"),
        ("qdrant-snapshot-manifest.json", "p3_qdrant_snapshot"),
        ("qdrant-collection.snapshot", "p3_qdrant_snapshot"),
        ("portable-logical-proof.json", "p4_build_proof"),
        ("promotion-candidate.json", "p4_build_proof"),
        ("portable-vector-proof.json", "p4_build_proof"),
        ("public-evidence-export.json", "p5_public_evidence"),
        ("source-materials-manifest.json", "source_lock"),
        ("ckb-public-reference-evidence.tar.zst", "p5_public_evidence"),
        ("leakage-report.json", "portable_report"),
        ("portable-path-report.json", "portable_report"),
        ("retrieval-parity.json", "portable_report"),
        ("release/release-commit.txt", "release_commit")]) { out.add(row) }
    if (mode == "bundled") {
        out.add(("cangjie-humaneval-authority.tar.zst",
            "authority_delivery"))
    } else if (mode == "public_rebuild") {
        out.add(("authority-source-materials.json", "authority_delivery"))
    }
    out
}

private func p8AuthorityLayoutHash(
    contract: CkbReproReleaseAuthorityContract): String {
    let rows = ArrayList<String>()
    for (evidence in contract.expected) {
        rows.add("${evidence.role}\t${evidence.logicalAsset}\t" +
            "${evidence.size}\t${evidence.sha256}")
    }
    let ordered = rows.toArray()
    sort(ordered)
    p8HashParts("ckb-repro-release-authority-layout-v1",
        [contract.authorityDeliveryMode,
        p8HashParts("ckb-repro-release-authority-layout-rows-v1", ordered)])
}

private func p8ValidateAuthorityLayout(
    contract: CkbReproReleaseAuthorityContract): CkbReproContractResult {
    if (contract.authorityDeliveryMode != "bundled" &&
        contract.authorityDeliveryMode != "public_rebuild") {
        return p8Failure("release_authority_delivery_mode_invalid")
    }
    if (contract.layoutHash == "" ||
        contract.layoutHash != p8AuthorityLayoutHash(contract)) {
        return p8Failure("release_authority_contract_mismatch")
    }
    let required = ckbReproReleaseAuthorityRequiredLayout(contract.authorityDeliveryMode)
    if (contract.expected.size != required.size) {
        return p8Failure("release_authority_layout_incomplete")
    }
    let seen = HashSet<String>()
    for (expected in contract.expected) {
        if (seen.contains(expected.logicalAsset)) {
            return p8Failure("release_authority_contract_mismatch")
        }
        seen.add(expected.logicalAsset)
        var matched = false
        for (row in required) {
            if (row[0] == expected.logicalAsset &&
                row[1] == expected.role) { matched = true }
        }
        if (!matched) { return p8Failure("release_authority_layout_invalid") }
    }
    p8Success()
}

private func p8HashParts(prefix: String, values: Array<String>): String {
    let builder = StringBuilder(prefix)
    for (value in values) {
        builder.append("${value.toArray().size}:${value}")
    }
    ckbReproBundleHash(builder.toString().toArray())
}

private func p8AbsoluteRoot(value: String): Bool {
    value.startsWith("/") && value != "/" && !value.endsWith("/") &&
        !value.contains("//") && !value.contains("/./") &&
        !value.contains("/../") && !value.endsWith("/.") &&
        !value.endsWith("/..") && !value.contains("\\") &&
        !value.contains("\n") && !value.contains("\r") &&
        !value.contains("\t") && !p8HasControl(value)
}

private func p8AbsoluteFile(value: String): Bool {
    p8AbsoluteRoot(value) && !value.endsWith("/")
}

private func p8RootsOverlap(left: String, right: String): Bool {
    left == right || left.startsWith(right + "/") ||
        right.startsWith(left + "/")
}

private func p8CommitValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 40) { return false }
    for (rune in runes) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
}

private func p8HashValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) {
        return false
    }
    for (i in 7..runes.size) {
        if (!((runes[i] >= r'0' && runes[i] <= r'9') ||
            (runes[i] >= r'a' && runes[i] <= r'f'))) { return false }
    }
    true
}

private func p8HasControl(value: String): Bool {
    for (rune in value.toRuneArray()) {
        if (rune < r' ' || rune == r'\u{7f}') { return true }
    }
    false
}

private func p8Success(): CkbReproContractResult {
    let out = CkbReproContractResult()
    out.ok = true
    out.diagnostic = "ok"
    out
}

private func p8Failure(diagnostic: String): CkbReproContractResult {
    let out = CkbReproContractResult()
    out.diagnostic = diagnostic
    out
}

private func p8Json(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"")
        .replace("\u{0000}", "\\u0000").replace("\u{0001}", "\\u0001")
        .replace("\u{0002}", "\\u0002").replace("\u{0003}", "\\u0003")
        .replace("\u{0004}", "\\u0004").replace("\u{0005}", "\\u0005")
        .replace("\u{0006}", "\\u0006").replace("\u{0007}", "\\u0007")
        .replace("\u{0008}", "\\b").replace("\t", "\\t")
        .replace("\n", "\\n").replace("\u{000b}", "\\u000b")
        .replace("\u{000c}", "\\f").replace("\r", "\\r")
        .replace("\u{000e}", "\\u000e").replace("\u{000f}", "\\u000f")
        .replace("\u{0010}", "\\u0010").replace("\u{0011}", "\\u0011")
        .replace("\u{0012}", "\\u0012").replace("\u{0013}", "\\u0013")
        .replace("\u{0014}", "\\u0014").replace("\u{0015}", "\\u0015")
        .replace("\u{0016}", "\\u0016").replace("\u{0017}", "\\u0017")
        .replace("\u{0018}", "\\u0018").replace("\u{0019}", "\\u0019")
        .replace("\u{001a}", "\\u001a").replace("\u{001b}", "\\u001b")
        .replace("\u{001c}", "\\u001c").replace("\u{001d}", "\\u001d")
        .replace("\u{001e}", "\\u001e").replace("\u{001f}", "\\u001f")
        .replace("\u{007f}", "\\u007f")
}
