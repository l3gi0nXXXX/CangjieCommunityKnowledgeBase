package cangjie_community_knowledge_base

// This file is the release-verify production boundary. Keep it free of all
// online execution clients and construct only the concrete B executor.
class CkbReproP8BProductionAssembly {
    var expected: CkbReproExpectedIdentity = CkbReproExpectedIdentity()
    var reference: CkbReproReferenceManifest = CkbReproReferenceManifest()
    var expectedInputSetHash: String = ""
    var expectedCertifiedInputHash: String = ""
    var releaseRepository: String = ""
    var critical: CkbRunCriticalFilesManifest = CkbRunCriticalFilesManifest()
    var authority: CkbReproReleaseAuthorityContract =
        CkbReproReleaseAuthorityContract()
    var probe: ?CkbReleaseFilesystemReproVerifyEnvironmentProbe = None
    var backend: ?CkbReproFilesystemBundleReadBackend = None
    var restore: CkbP8ProductionRestoreInputs = CkbP8ProductionRestoreInputs()
    var rebuild: CkbP8ProductionRebuildInputs = CkbP8ProductionRebuildInputs()
    var registeredCommands: Array<String> = Array<String>()
    public init() {}
}

func executeCkbReproP8BProductionAssembly(args: Array<String>, heap: String,
    json: Bool, assembly: CkbReproP8BProductionAssembly):
    CkbReproMainCliResult {
    let probe = match (assembly.probe) {
        case Some(value) => value
        case None => return ckbP8BMainFailure(
            "release_verify_probe_required", json)
    }
    let backend = match (assembly.backend) {
        case Some(value) => value
        case None => return ckbP8BMainFailure(
            "release_verify_backend_required", json)
    }
    let executor = newCkbP8BProductionExecutor(assembly.restore,
        assembly.rebuild, assembly.registeredCommands)
    let result = runCkbReproProductionReleaseVerification(args, heap,
        assembly.expected, assembly.reference, assembly.expectedInputSetHash,
        assembly.expectedCertifiedInputHash, assembly.releaseRepository,
        assembly.critical,
        CkbReproCanonicalReleaseAssetAuthority(assembly.authority), probe,
        backend, executor)
    if (json) {
        return CkbReproMainCliResult(true, if (result.ok) { 0 } else { 1 },
            renderCkbReproVerificationReport(result))
    }
    let output = if (result.ok) {
        "CKB release verification completed. release inputs and public evidence are verified.\n"
    } else {
        "CKB release verification failed: ${p8BMainSafe(result.diagnostic)}\n"
    }
    CkbReproMainCliResult(true, if (result.ok) { 0 } else { 1 }, output)
}

private func ckbP8BMainFailure(code: String, json: Bool):
    CkbReproMainCliResult {
    let output = if (json) {
        "{\"ok\":false,\"diagnostic\":\"${p8BMainSafe(code)}\"}"
    } else { "CKB release verification failed: ${p8BMainSafe(code)}\n" }
    CkbReproMainCliResult(true, 2, output)
}

private func p8BMainSafe(value: String): String {
    let runes = redactSensitive(value).toRuneArray()
    let end = if (runes.size < 160) { runes.size } else { 160 }
    let out = StringBuilder()
    for (i in 0..end) { out.append(runes[i]) }
    out.toString().replace("\\", "\\\\").replace("\"", "\\\"")
        .replace("\n", "\\n").replace("\r", "\\r")
}
