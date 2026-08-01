package cangjie_community_knowledge_base_test

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
    func runPublishGate(args: Array<String>): CkbReproMainCliResult
}

private class CkbReproProductionMainCliAdapter <: CkbReproMainCliAdapter {
    public init() {}
    public func runRelease(args: Array<String>): CkbReproMainCliResult {
        let execution = runCkbReleaseCli(args)
        CkbReproMainCliResult(true, execution.exitCode, execution.output)
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
}

public func executeCkbReproMainCli(command: String, args: Array<String>,
    adapter: CkbReproMainCliAdapter): CkbReproMainCliResult {
    if (command == "ckb-release-export" || command == "ckb-release-import") {
        return adapter.runRelease(args)
    }
    if (command == "ckb-repro-publish-gate") {
        return adapter.runPublishGate(args)
    }
    CkbReproMainCliResult(false, 0, "")
}

public func runCkbReproMainCli(command: String,
    args: Array<String>): CkbReproMainCliResult {
    executeCkbReproMainCli(command, args, CkbReproProductionMainCliAdapter())
}
