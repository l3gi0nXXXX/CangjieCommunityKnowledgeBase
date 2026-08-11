package cangjie_community_knowledge_base_test

import std.collection.ArrayList

public class CkbReproMainCliResult {
    public var handled: Bool
    public var exitCode: Int64
    public var output: String
    public init(handled: Bool, exitCode: Int64, output: String) {
        this.handled = handled
        this.exitCode = exitCode
        this.output = output
    }
}

public interface CkbReproMainCliAdapter {
    func runRelease(args: Array<String>): CkbReproMainCliResult
    func runP3(args: Array<String>): CkbReproMainCliResult
    func runP4(args: Array<String>): CkbReproMainCliResult
    func runPublicEvidence(args: Array<String>): CkbReproMainCliResult
    func runPreflight(args: Array<String>): CkbReproMainCliResult
    func runAuthorityBundle(args: Array<String>): CkbReproMainCliResult
    func runBundle(args: Array<String>): CkbReproMainCliResult
    func runPublishGate(args: Array<String>): CkbReproMainCliResult
    func runP8(args: Array<String>): CkbReproMainCliResult
    func runEnvironmentPlan(args: Array<String>): CkbReproMainCliResult
    func runAttestationAuthorityFreeze(args: Array<String>): CkbReproMainCliResult
    func runCompositionStage(args: Array<String>): CkbReproMainCliResult
    func runCompositionSeal(args: Array<String>): CkbReproMainCliResult
}

private class CkbReproProductionMainCliAdapter <: CkbReproMainCliAdapter {
    public init() {}
    public func runRelease(args: Array<String>): CkbReproMainCliResult {
        let execution = runCkbReleaseCli(args)
        CkbReproMainCliResult(true, execution.exitCode, execution.output)
    }
    public func runP3(args: Array<String>): CkbReproMainCliResult {
        runCkbP3ProductionMainCli(args)
    }
    public func runP4(args: Array<String>): CkbReproMainCliResult {
        runCkbP4ProductionMainCli(args)
    }
    public func runPublicEvidence(args: Array<String>): CkbReproMainCliResult {
        let options = parseCkbPublicEvidenceCliArgs(args)
        if (!options.valid) {
            let invalid = CkbPublicEvidenceRenderResult()
            invalid.diagnostic = options.diagnostic
            let output = if (options.json) {
                renderCkbPublicEvidenceCliJson(invalid)
            } else { renderCkbPublicEvidenceCliHuman(invalid) }
            return CkbReproMainCliResult(true, 2, output)
        }
        let result = runCkbPublicEvidenceCliAdapter(options)
        let output = if (options.json) {
            renderCkbPublicEvidenceCliJson(result)
        } else { renderCkbPublicEvidenceCliHuman(result) }
        CkbReproMainCliResult(true, if (result.ok) { 0 } else { 1 }, output)
    }
    public func runPreflight(args: Array<String>): CkbReproMainCliResult {
        let options = parseCkbReproPreflightCliArgs(args)
        if (!options.valid) {
            let invalid = CkbReproEnvironmentPreflightResult()
            invalid.diagnostic = options.diagnostic
            let output = if (options.json) {
                renderCkbReproPreflightCliJson(invalid,
                    CkbReproEnvironmentLock())
            } else {
                renderCkbReproPreflightCliHuman(invalid,
                    CkbReproEnvironmentLock())
            }
            return CkbReproMainCliResult(true, 2, output)
        }
        let loaded = loadCkbReproPreflightAuthority(
            options.environmentLockPath)
        if (!loaded[0].ok) {
            let blocked = CkbReproEnvironmentPreflightResult()
            blocked.diagnostic = loaded[0].diagnostic
            let output = if (options.json) {
                renderCkbReproPreflightCliJson(blocked, loaded[1])
            } else { renderCkbReproPreflightCliHuman(blocked, loaded[1]) }
            return CkbReproMainCliResult(true, 1, output)
        }
        if (let Some(authority) <- loaded[2]) {
            let result = runCkbReproPreflightCliAdapter(options, authority)
            let output = if (options.json) {
                renderCkbReproPreflightCliJson(result, loaded[1])
            } else { renderCkbReproPreflightCliHuman(result, loaded[1]) }
            return CkbReproMainCliResult(true, if (result.ok) { 0 } else { 1 },
                output)
        }
        let blocked = CkbReproEnvironmentPreflightResult()
        blocked.diagnostic = "environment_attestation_authority_unavailable"
        let output = if (options.json) {
            renderCkbReproPreflightCliJson(blocked, loaded[1])
        } else { renderCkbReproPreflightCliHuman(blocked, loaded[1]) }
        CkbReproMainCliResult(true, 1, output)
    }
    public func runAuthorityBundle(args: Array<String>): CkbReproMainCliResult {
        let execution = runCkbAuthorityBundleCli(args)
        CkbReproMainCliResult(true, execution.exitCode, execution.output)
    }
    public func runBundle(args: Array<String>): CkbReproMainCliResult {
        let options = parseCkbReproBundleCliArgs(args)
        if (!options.valid) {
            let invalid = CkbReproBundleResult()
            invalid.diagnostic = options.diagnostic
            let output = if (options.json) {
                renderCkbReproBundleCliJson(invalid)
            } else { renderCkbReproBundleCliHuman(invalid) }
            return CkbReproMainCliResult(true, 2, output)
        }
        let result = runCkbReproBundleCliAdapter(options)
        let output = if (options.json) {
            renderCkbReproBundleCliJson(result)
        } else { renderCkbReproBundleCliHuman(result) }
        CkbReproMainCliResult(true, if (result.ok) { 0 } else { 1 }, output)
    }
    public func runPublishGate(args: Array<String>): CkbReproMainCliResult {
        let options = parseCkbReproPublishGateCliArgs(args)
        if (!options.valid) {
            let invalid = CkbReproPublishGateResult()
            invalid.diagnostic = options.diagnostic
            let output = if (options.json) {
                renderCkbReproPublishGateCliJson(invalid)
            } else { renderCkbReproPublishGateCliHuman(invalid) }
            return CkbReproMainCliResult(true, 2, output)
        }
        let result = runCkbReproPublishGateCliAdapter(options)
        let output = if (options.json) {
            renderCkbReproPublishGateCliJson(result)
        } else { renderCkbReproPublishGateCliHuman(result) }
        CkbReproMainCliResult(true, if (result.publishable) { 0 } else { 1 },
            output)
    }
    public func runP8(args: Array<String>): CkbReproMainCliResult {
        runCkbP8ProductionMainCli(args)
    }
    public func runEnvironmentPlan(args: Array<String>): CkbReproMainCliResult {
        let execution = runCkbReproEnvironmentPlanCli(args)
        CkbReproMainCliResult(true, execution.exitCode, execution.output)
    }
    public func runAttestationAuthorityFreeze(args: Array<String>):
        CkbReproMainCliResult {
        let execution = runCkbReproAttestationAuthorityFreezeCli(args)
        CkbReproMainCliResult(true, execution.exitCode, execution.output)
    }
    public func runCompositionStage(args: Array<String>): CkbReproMainCliResult {
        let execution = runCkbReproCompositionStageCli(args)
        CkbReproMainCliResult(true, execution.exitCode, execution.output)
    }
    public func runCompositionSeal(args: Array<String>): CkbReproMainCliResult {
        let execution = runCkbReproCompositionSealCli(args)
        CkbReproMainCliResult(true, execution.exitCode, execution.output)
    }
}

public func executeCkbReproMainCli(command: String, args: Array<String>,
    adapter: CkbReproMainCliAdapter): CkbReproMainCliResult {
    if (command == "ckb-release-export" || command == "ckb-release-import" ||
        command == "ckb-logical-proof") {
        return adapter.runRelease(args)
    }
    if (command == "ckb-portable-vector-build" ||
        command == "ckb-qdrant-snapshot" ||
        command == "ckb-retrieval-parity") {
        return adapter.runP3(args)
    }
    if (command == "ckb-repro-build" || command == "ckb-repro-promote") {
        return adapter.runP4(args)
    }
    if (command == "ckb-public-evidence-export") {
        return adapter.runPublicEvidence(args)
    }
    if (command == "ckb-repro-preflight") {
        return adapter.runPreflight(args)
    }
    if (command == "ckb-authority-bundle") {
        return adapter.runAuthorityBundle(args)
    }
    if (command == "ckb-repro-bundle") {
        return adapter.runBundle(args)
    }
    if (command == "ckb-repro-publish-gate") {
        return adapter.runPublishGate(args)
    }
    if (command == "ckb-repro-verify") {
        return adapter.runP8(args)
    }
    if (command == "ckb-repro-environment-plan") {
        return adapter.runEnvironmentPlan(args)
    }
    if (command == "ckb-repro-attestation-authority-freeze") {
        return adapter.runAttestationAuthorityFreeze(args)
    }
    if (command == "ckb-repro-composition-seal") {
        return adapter.runCompositionSeal(args)
    }
    if (command == "ckb-repro-composition-stage") {
        return adapter.runCompositionStage(args)
    }
    CkbReproMainCliResult(false, 0, "")
}

public func runCkbReproMainCli(command: String,
    args: Array<String>): CkbReproMainCliResult {
    executeCkbReproMainCli(command, args, CkbReproProductionMainCliAdapter())
}

private func runCkbP3ProductionMainCli(args: Array<String>):
    CkbReproMainCliResult {
    runCkbReproP3ProductionComposition(args)
}

private func runCkbP4ProductionMainCli(args: Array<String>):
    CkbReproMainCliResult {
    runCkbReproP4ProductionComposition(args)
}

private func runCkbP8ProductionMainCli(args: Array<String>):
    CkbReproMainCliResult {
    runCkbReproP8ProductionComposition(args)
}
