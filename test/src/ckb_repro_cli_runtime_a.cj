package cangjie_community_knowledge_base_test

class CkbReproP8AProductionAssembly {
    var expected: CkbReproExpectedIdentity = CkbReproExpectedIdentity()
    var hashInputs: CkbReproCertifiedRunHashInputs =
        CkbReproCertifiedRunHashInputs()
    var probe: ?CkbFilesystemReproVerifyEnvironmentProbe = None
    var reference: CkbReproReferenceManifest = CkbReproReferenceManifest()
    var environment: CkbReproEnvironmentLock = CkbReproEnvironmentLock()
    var runnerInputs: CkbReproRunnerInputs = CkbReproRunnerInputs()
    var preflight: CkbReproEnvironmentPreflightResult =
        CkbReproEnvironmentPreflightResult()
    var authorityManifestText: String = ""
    var restore: CkbP8ProductionRestoreInputs = CkbP8ProductionRestoreInputs()
    var rebuild: CkbP8ProductionRebuildInputs = CkbP8ProductionRebuildInputs()
    public init() {}
}

func executeCkbReproP8AProductionAssembly(args: Array<String>, heap: String,
    json: Bool, assembly: CkbReproP8AProductionAssembly):
    CkbReproMainCliResult {
    let probe = match (assembly.probe) {
        case Some(value) => value
        case None => return ckbP8AMainFailure(
            "run_certify_probe_required", json)
    }
    let executor = newCkbP8AProductionExecutor(assembly.restore,
        assembly.rebuild, assembly.reference, assembly.environment,
        assembly.runnerInputs, assembly.preflight,
        CkbInProcessReproRunnerInvoker(), assembly.authorityManifestText)
    let result = runCkbReproProductionCertification(args, heap,
        assembly.expected, assembly.hashInputs, probe, assembly.reference,
        executor)
    if (json) {
        let output = "{\"ok\":${result.ok},\"diagnostic\":\"" +
            "${p8AMainSafe(result.diagnostic)}\",\"status\":\"" +
            "${p8AMainSafe(result.target.status)}\",\"strictPassed\":" +
            "${result.run.strictPassed},\"totalCases\":${result.run.totalCases}," +
            "\"transportUnresolved\":${result.run.transportUnresolved}}"
        return CkbReproMainCliResult(true, if (result.ok) { 0 } else { 1 },
            output)
    }
    let output = if (result.ok) {
        "CKB run certification completed. strict pass@1 ${result.run.strictPassed}/${result.run.totalCases}.\n"
    } else {
        "CKB run certification failed: ${p8AMainSafe(result.diagnostic)}\n"
    }
    CkbReproMainCliResult(true, if (result.ok) { 0 } else { 1 }, output)
}

private func ckbP8AMainFailure(code: String, json: Bool):
    CkbReproMainCliResult {
    let output = if (json) {
        "{\"ok\":false,\"diagnostic\":\"${p8AMainSafe(code)}\"}"
    } else { "CKB run certification failed: ${p8AMainSafe(code)}\n" }
    CkbReproMainCliResult(true, 2, output)
}

private func p8AMainSafe(value: String): String {
    let runes = redactSensitive(value).toRuneArray()
    let end = if (runes.size < 160) { runes.size } else { 160 }
    let out = StringBuilder()
    for (i in 0..end) { out.append(runes[i]) }
    out.toString().replace("\\", "\\\\").replace("\"", "\\\"")
        .replace("\n", "\\n").replace("\r", "\\r")
}
