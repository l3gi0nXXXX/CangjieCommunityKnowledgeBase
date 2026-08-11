package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.convert.Parsable
import std.env.{getCommand, getVariable, getStdOut}
import std.fs.{File, OpenMode, Path}
import std.io.*
import std.process.*

main(args: Array<String>): Int64 {
    let bootstrap = ckbMaybeRelaunchWithNativeTlsEnv(args)
    if (bootstrap[0]) {
        return bootstrap[1]
    }
    ckbCliMain(args)
}

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

public func ckbCliMain(args: Array<String>): Int64 {
    let cli = parseCli(args)
    if (cli.command == "cangjie-clean-candidate-build") {
        return runCkbCleanCandidateBuildCli(args)
    }
    if (cli.command == "cangjie-candidate-runtime-materialize") {
        return runCkbCandidateRuntimeMaterializeCli(args)
    }
    if (cli.command == "cangjie-benchmark-gap-staging-init") {
        return runCkbBenchmarkGapStagingInitCli(args)
    }
    if (cli.command == "cangjie-atom-selection-build") {
        return runCkbAtomSelectionCli(args)
    }
    if (cli.command == "cangjie-student-context-import") {
        return runStudentContextImportCli(args)
    }
    let repro = runCkbReproMainCli(cli.command, args)
    if (repro.handled) {
        print(repro.output)
        return repro.exitCode
    }
    let config = loadCkbRuntimeConfig(cli.configPath)
    let store = FileKnowledgeStore(cli.storePath)
    if (ckbCliCommandUsesCommandLoopService(cli.command)) {
        let heapPreflight = ckbServiceHeapPreflightFromEnv()
        if (!heapPreflight.ok) {
            print(renderCkbServiceHeapPreflightText(heapPreflight))
            return 2
        }
    }
    if (cli.command == "cangjie-candidate-precert-seal") {
        return runCkbCandidatePrecertCli(args, store)
    }
    if (cli.command == "repository-event-worker") {
        let dedupeKey = ckbCliOption(args, "--dedupe-key")
        let owner = ckbCliOption(args, "--owner")
        let revision = ckbCliOptionInt(args, "--revision", -1)
        let resultRelativePath = ckbCliOption(args, "--result-rel")
        let hardDeadlineAtMillis = ckbCliOptionInt(args, "--hard-deadline", 0)
        let softDeadlineAtMillis = ckbCliOptionInt(args, "--deadline", 0)
        let schedulerRunId = ckbCliOption(args, "--scheduler-run-id")
        if (dedupeKey == "" || owner == "" || revision < 0 ||
            resultRelativePath == "") {
            println("usage error: repository-event-worker requires --dedupe-key --owner --revision --result-rel")
            return 2
        }
        let kb = loadCliKnowledgeBase(cli.command, store, config)
        let runner: SourceFetchRunner = if (config.networkEnabled) {
            HttpSourceFetchRunner(config)
        } else { DisabledNetworkFetchRunner() }
        let outcome = ckbRunRepositoryEventWorkerChild(kb, store, runner, config,
            dedupeKey, owner, revision, hardDeadlineAtMillis: hardDeadlineAtMillis,
            softDeadlineAtMillis: softDeadlineAtMillis,
            resultRelativePath: resultRelativePath, schedulerRunId: schedulerRunId)
        return if (outcome.state == "committed") { 0 } else { 1 }
    }
    if (cli.command == "scheduler-task-worker") {
        let taskName = ckbCliOption(args, "--task")
        let resultRelativePath = ckbCliOption(args, "--result-rel")
        if (taskName == "" || resultRelativePath == "") {
            println("usage error: scheduler-task-worker requires --task and --result-rel")
            return 2
        }
        let schedulerRunId = ckbCliOption(args, "--scheduler-run-id")
        let bootstrapStartedAtMillis = ckbCoreNowMillis()
        let workerSoftDeadlineAtMillis = ckbCliOptionInt(args, "--deadline", 0)
        if (ckbSchedulerBootstrapDeadlineExceededAt(taskName, bootstrapStartedAtMillis, ckbCoreNowMillis(), workerSoftDeadlineAtMillis)) {
            _ = ckbWriteSchedulerTaskBootstrapDeadlineFailure(store, taskName, ckbCliOption(args, "--since"), workerSoftDeadlineAtMillis, resultRelativePath, schedulerRunId, bootstrapStartedAtMillis)
            return 1
        }
        try {
            let kb = loadCliKnowledgeBase(cli.command, store, config)
            let taskBodyStartedAtMillis = ckbCoreNowMillis()
            if (ckbSchedulerBootstrapDeadlineExceededAt(taskName, bootstrapStartedAtMillis, taskBodyStartedAtMillis, workerSoftDeadlineAtMillis)) {
                _ = ckbWriteSchedulerTaskBootstrapDeadlineFailure(store, taskName, ckbCliOption(args, "--since"), workerSoftDeadlineAtMillis, resultRelativePath, schedulerRunId, bootstrapStartedAtMillis)
                return 1
            }
            let task = ckbRunSchedulerTaskWorker(kb, config, store, taskName, ckbCliOption(args, "--since"), workerSoftDeadlineAtMillis, resultRelativePath, schedulerRunId: schedulerRunId, bootstrapStartedAtMillis: bootstrapStartedAtMillis, taskBodyStartedAtMillis: taskBodyStartedAtMillis)
            return if (task.ok) { 0 } else { 1 }
        } catch (e: Exception) {
            if (ckbSchedulerBootstrapDeadlineExceededAt(taskName, bootstrapStartedAtMillis, ckbCoreNowMillis(), workerSoftDeadlineAtMillis)) {
                _ = ckbWriteSchedulerTaskBootstrapDeadlineFailure(store, taskName, ckbCliOption(args, "--since"), workerSoftDeadlineAtMillis, resultRelativePath, schedulerRunId, bootstrapStartedAtMillis)
            } else {
                _ = ckbWriteSchedulerTaskBootstrapFailure(store, taskName, ckbCliOption(args, "--since"), workerSoftDeadlineAtMillis, resultRelativePath, schedulerRunId, bootstrapStartedAtMillis, e.message)
            }
            return 1
        }
    }
    if (cli.command == "vector-bootstrap") {
        let result = ckbVectorBootstrapWithStoreAndKnowledgeStore(config, store, vectorStoreFromRuntime(config))
        if (ckbCliWantsJson(args)) {
            println(renderCkbVectorBootstrapJson(result))
        } else {
            print(renderCkbVectorBootstrapText(result))
        }
        return if (result.ok) { 0 } else { 1 }
    }
    if (cli.command == "vector-clean-derived") {
        let result = ckbCleanDerivedVectorArtifacts(config, store, hasArg(args, "--force"))
        if (ckbCliWantsJson(args)) {
            println(renderCkbDerivedVectorCleanupJson(result))
        } else {
            print(renderCkbDerivedVectorCleanupText(result))
        }
        return if (result.ok) { 0 } else { 1 }
    }
    if (cli.command == "cangjie-certification-preflight") {
        return runCkbCertificationPreflightCli(args, store: store)
    }
    if (cli.command == "cangjie-certification-control-seal") {
        return runCkbCertificationControlSealCli(args, store: store)
    }
    if (cli.command == "cangjie-frozen-candidate-seal") {
        return runCkbFrozenCandidateSealCli(args, store)
    }
    if (cli.command == "certification-http") {
        return runCkbCertificationHttpService(config, store)
    }
    let kb = loadCliKnowledgeBase(cli.command, store, config)
    let input = cliInput(args)
    if (cli.command == "" || cli.command == "doctor") {
        print(renderDoctor(cangjie_knowledge_status(kb)))
        print(renderRuntimeDoctor(config))
        return 0
    }
    if (cli.command == "status") {
        print(renderDoctor(cangjie_knowledge_status(kb)))
        print(renderRuntimeDoctor(config))
        return 0
    }
    if (cli.command == "metrics") {
        print(renderMetrics(cangjie_knowledge_status(kb)))
        print(renderRuntimeDoctor(config))
        return 0
    }
    if (cli.command == "service" || cli.command == "start") {
        return runCkbServiceLoop(config, store, kb)
    }
    if (cli.command == "service-http" || cli.command == "http-service") {
        return runCkbHttpService(config, store,
            loadedKnowledgeBase: Some<KnowledgeBase>(kb))
    }
    if (cli.command == "mcp-stdio") {
        return runCkbMcpStdioLoop(config, store,
            ckbCliOption(args, "--bound-task-context-base64"),
            ckbCliOption(args, "--bound-task-context-sha256"), kb)
    }
    if (cli.command == "cangjie-initialize") {
        let options = parseCkbFirstInitOptions(args)
        options.storeRoot = cli.storePath
        if (!options.apply && !options.dryRun) {
            println("usage error: cangjie-initialize requires --dry-run or --apply")
            return 2
        }
        let result = runCkbFirstInitializationWithActiveGuard(options, store)
        print(renderCkbFirstInitResult(result))
        return if (result.ok) { 0 } else { 1 }
    }
    if (cli.command == "cangjie-landing-status") {
        let service = CkbCommandLoopService(config, store,
            loadedKnowledgeBase: Some<KnowledgeBase>(kb))
        service.start()
        let report = collectCkbLandingStatus(service)
        if (ckbCliWantsJson(args)) {
            println(renderCkbLandingStatusJson(report))
        } else {
            print(renderCkbLandingStatusMarkdown(report))
        }
        return 0
    }
    if (cli.command == "service-once") {
        let service = CkbCommandLoopService(config, store,
            sourceRunner: if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() },
            loadedKnowledgeBase: Some<KnowledgeBase>(kb))
        print(service.start())
        let response = service.handleLine(cliTail(input, "service-once", "health"))
        print(response.text)
        return if (response.text.startsWith("error")) { 2 } else { 0 }
    }
    if (cli.command == "stop") {
        println("service protocol=ckb-stdio-v1 action=stop usage=\"send stop to the running service stdin\"")
        return 0
    }
    if (cli.command == "restart") {
        let service = CkbCommandLoopService(config, store,
            sourceRunner: if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() },
            loadedKnowledgeBase: Some<KnowledgeBase>(kb))
        print(service.handleLine("restart").text)
        return 0
    }
    if (cli.command == "sync-once") {
        println(ckbSyncOnce(kb, SourceAdapter(), store))
        return 0
    }
    if (cli.command == "sync-live") {
        let options = LiveSyncOptions()
        options.dryRun = cli.dryRun
        options.apply = cli.apply
        let applyOptions = parseLiveApplyOptions(args)
        options.maxRepos = applyOptions.maxRepos
        options.maxFilesPerRepo = applyOptions.maxFilesPerRepo
        options.maxItems = applyOptions.maxItems
        options.since = applyOptions.since
        let runner: SourceFetchRunner = if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() }
        let text = ckbSyncLive(kb, config, options, runner: runner, store: store)
        print(text)
        return if (text.startsWith("usage error")) { 2 } else { 0 }
    }
    if (cli.command == "source_analysis" || cli.command == "source-analysis") {
        let runner: SourceFetchRunner = if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() }
        let request = sourceAnalysisRequestFromText(cliTail(input, cli.command, ""))
        print(renderSourceAnalysis(ckbSourceAnalysis(request, runner: runner)))
        return 0
    }
    if (cli.command == "native-http-smoke") {
        let url = cliTail(input, "native-http-smoke", "")
        if (url == "") {
            println("usage error: native-http-smoke requires an allowlist URL")
            return 2
        }
        print(ckbNativeHttpSmoke(url, config))
        return 0
    }
    if (cli.command == "cangjie-corpus-status") {
        let service = CkbCommandLoopService(config, store,
            loadedKnowledgeBase: Some<KnowledgeBase>(kb))
        print(service.handleLine("cangjie_corpus_status").text)
        return 0
    }
    if (cli.command == "cangjie-knowledge-pack") {
        let service = CkbCommandLoopService(config, store,
            loadedKnowledgeBase: Some<KnowledgeBase>(kb))
        let tail = cliTail(input, cli.command, "Cangjie language context")
        print(service.handleLine("cangjie_knowledge_pack ${tail}").text)
        return 0
    }
    if (cli.command == "cangjie-api-search") {
        let service = CkbCommandLoopService(config, store,
            loadedKnowledgeBase: Some<KnowledgeBase>(kb))
        let tail = cliTail(input, cli.command, "stdx JSON")
        print(service.handleLine("cangjie_api_search ${tail}").text)
        return 0
    }
    if (cli.command == "cangjie-syntax-query") {
        let service = CkbCommandLoopService(config, store,
            loadedKnowledgeBase: Some<KnowledgeBase>(kb))
        let tail = cliTail(input, cli.command, "function syntax")
        print(service.handleLine("cangjie_syntax_query ${tail}").text)
        return 0
    }
    if (cli.command == "cangjie-cookbook") {
        let service = CkbCommandLoopService(config, store,
            loadedKnowledgeBase: Some<KnowledgeBase>(kb))
        let tail = cliTail(input, cli.command, "Cangjie task")
        print(service.handleLine("cangjie_cookbook ${tail}").text)
        return 0
    }
    if (cli.command == "cangjie-diagnose") {
        let service = CkbCommandLoopService(config, store,
            loadedKnowledgeBase: Some<KnowledgeBase>(kb))
        let tail = cliTail(input, cli.command, "Cangjie compiler diagnostic")
        print(service.handleLine("cangjie_diagnose ${tail}").text)
        return 0
    }
    if (cli.command == "cangjie-llms") {
        let service = CkbCommandLoopService(config, store,
            loadedKnowledgeBase: Some<KnowledgeBase>(kb))
        let task = cliTail(input, cli.command, "Cangjie language quick context")
        print(renderCangjieLlmsTxt(service.statusSnapshot(), service.cangjieKnowledgePack(task, budget: 5)))
        return 0
    }
    if (cli.command == "cangjie-context-pack") {
        let service = CkbCommandLoopService(config, store,
            loadedKnowledgeBase: Some<KnowledgeBase>(kb))
        let task = cliTail(input, cli.command, "Cangjie task")
        print(renderCangjieContextPack(service.cangjieCookbook(task, budget: 5)))
        return 0
    }
    if (cli.command == "cangjie-eval-summary") {
        let manifestPath = cliTail(input, cli.command, "")
        if (manifestPath == "") {
            println("usage error: cangjie-eval-summary requires a manifest JSONL path")
            return 2
        }
        let result = renderCangjieEvalManifestFileSummary(manifestPath)
        print(result[0])
        return result[1]
    }
    if (cli.command == "cangjie-eval-abcde") {
        return runCangjieEvalAbcde(args)
    }
    if (cli.command == "cangjie-eval-development-close") {
        return runCangjieEvalDevelopmentClose(args)
    }
    if (cli.command == "cangjie-eval-case-close") {
        return runCangjieEvalSingleCaseClose(args)
    }
    if (cli.command == "cangjie-eval-classifier-run") {
        return runCangjieEvalClassifierControl(args)
    }
    if (cli.command == "cangjie-humaneval-manifest-build") {
        return runCangjieHumanEvalManifestBuild(args)
    }
    if (cli.command == "cangjie-humaneval-plus-authority-build") {
        return runCangjieHumanEvalPlusAuthorityBuild(args)
    }
    if (cli.command == "cangjie-eval-knowledge-audit") {
        return runCangjieEvalKnowledgeAudit(args)
    }
    if (cli.command == "cangjie-typed-ingest-smoke") {
        return runCangjieTypedIngestSmoke(args)
    }
    if (cli.command == "cangjie-serving-feed-smoke") {
        return runCangjieServingFeedSmoke(args)
    }
    if (cli.command == "cangjie-serving-query-smoke") {
        return runCangjieServingQuerySmoke(args)
    }
    if (cli.command == "cangjie-update-promotion-smoke") {
        return runCangjieUpdatePromotionSmoke(args)
    }
    if (cli.command == "cangjie-abcde-parity-smoke") {
        return runCangjieAbcdeParitySmoke(args)
    }
    if (cli.command == "cangjie-humaneval-pass1-gate") {
        return runCangjieHumanEvalPass1Gate(args)
    }
    if (cli.command == "cangjie-humaneval-pass1-gate-smoke") {
        return runCangjieHumanEvalPass1GateSmoke(args)
    }
    if (cli.command == "cangjie-certified-production-publish") {
        return runCkbCertifiedProductionPublishCli(args, kb, store, cli.storePath)
    }
    if (cli.command == "cangjie-knowledge-release-gate") {
        return runCangjieKnowledgeReleaseGate(args, config: config, store: store, sourceRunner: if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() })
    }
    if (cli.command == "ollama-embedding-benchmark") {
        let result = ckbRunOllamaEmbeddingBenchmark(kb, config, ckbCliSampleSize(args))
        if (ckbCliWantsJson(args)) {
            println(renderCkbOllamaEmbeddingBenchmarkJson(result))
        } else {
            print("ollama embedding benchmark ok=${result.ok} status=${result.status} sampleSize=${result.sampleSize} p50Bytes=${result.p50Bytes} p95Bytes=${result.p95Bytes} p99Bytes=${result.p99Bytes} maxBytes=${result.maxBytes} measuredLatencyMillis=${result.measuredLatencyMillis} recommendation maxBatchItems=${result.maxBatchItems} maxBatchBytes=${result.maxBatchBytes} maxTextBytes=${result.maxTextBytes} diagnostic=${result.diagnostic}\n")
        }
        return if (result.ok) { 0 } else { 1 }
    }
    if (cli.command == "vector-reconcile") {
        let result = ckbVectorReconcile(kb, store, config, hasArg(args, "--force"))
        if (ckbCliWantsJson(args)) {
            println(renderCkbVectorReconcileJson(result))
        } else {
            print(renderCkbVectorReconcileText(result))
        }
        return if (result.ok) { 0 } else { 1 }
    }
    if (cli.command == "routine-repair") {
        let result = ckbRoutineRepair(kb, store, config, cli.storePath, hasArg(args, "--force"))
        if (ckbCliWantsJson(args)) {
            println(renderCkbRoutineRepairJson(result))
        } else {
            print(renderCkbRoutineRepairText(result))
        }
        return if (result.ok) { 0 } else { 1 }
    }
    if (cli.command == "rebuild-index") {
        let result = ckbRebuildIndex(kb, store)
        println("rebuild ok=${result.ok} activeKnowledgeVersion=${result.activeVersion} candidateKnowledgeVersion=${result.candidateVersion} count=${result.count}")
        return 0
    }
    if (cli.command == "scheduler-run") {
        let schedulerKb = kb
        let recovery = ckbRecoverStaleSchedulerRunsWithVectorStore(store, vectorStoreFromRuntime(config))
        let lock = ckbAcquireSchedulerRunLock(store, "scheduler-cli-${ckbCoreNowMillis()}", ckbCoreNowMillis() + ckbCliSchedulerRunLockBudgetMillis(args), stableSummaryHash(getCommand()))
        if (!lock.ok) {
            let busy = SchedulerExecutorResult()
            busy.runId = lock.runId
            busy.startedAtMillis = ckbCoreNowMillis()
            busy.endedAtMillis = busy.startedAtMillis
            busy.failed = 1
            busy.details = "scheduler lock ok=false status=${lock.status} diagnostic=${lock.diagnostic}\n"
            busy.validationDiagnostics.add("scheduler_lock:${lock.diagnostic}")
            ckbCliPopulateSchedulerRunEvidence(busy, config, cli.storePath)
            if (ckbCliWantsJson(args)) {
                busy.jsonPrinted = true
                println(ckbCliSchedulerRunJson(busy))
            } else {
                print("scheduler ran=0 succeeded=0 failed=1 degraded=0 forced=false\n")
                print(busy.details)
            }
            return 1
        }
        ckbApplySchedulerProfileBudgets(schedulerKb.scheduler)
        let runner = ckbSchedulerTaskRunnerForRuntime(schedulerKb, config, store, cli.configPath, cli.storePath, if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() })
        let executor = SchedulerExecutor(schedulerKb.scheduler, runner, FileSchedulerProgressSink(store), 300000)
        let taskNames = ckbCliSchedulerTaskNames(args)
        let gateTaskNames = if (hasArg(args, "--force-all")) {
            ckbSchedulerAllowlistTaskNames()
        } else {
            taskNames
        }
        let gate = ckbSchedulerPreRunGate(config, store, vectorStoreFromRuntime(config), gateTaskNames)
        if (!gate.ok) {
            let blocked = ckbSchedulerPreRunGateFailureResult(gate, gateTaskNames, hasArg(args, "--force") || hasArg(args, "--force-all"))
            blocked.runId = lock.runId
            for (diagnostic in recovery.diagnostics) {
                blocked.validationDiagnostics.add("recovery:${diagnostic}")
                blocked.details += "recovery ${diagnostic}\n"
            }
            ckbCliPopulateSchedulerRunEvidence(blocked, config, cli.storePath)
            ckbCliFinalizeBlockedSchedulerRun(blocked, store, config, lock)
            if (ckbCliWantsJson(args)) {
                blocked.jsonPrinted = true
                println(ckbCliSchedulerRunJson(blocked))
            } else {
                print("scheduler ran=0 succeeded=0 failed=1 degraded=0 forced=${blocked.forced}\n")
                print(blocked.details)
            }
            return 1
        }
        let result = if (hasArg(args, "--force-all")) {
            executor.runTaskNames(ckbSchedulerAllowlistTaskNames(), force: true)
        } else if (taskNames.size > 0) {
            executor.runTaskNames(taskNames, force: hasArg(args, "--force"))
        } else {
            executor.runDue()
        }
        for (diagnostic in recovery.diagnostics) {
            result.validationDiagnostics.add("recovery:${diagnostic}")
            result.details += "recovery ${diagnostic}\n"
        }
        if (lock.diagnostic != "") {
            result.validationDiagnostics.add("scheduler_lock:${lock.diagnostic}")
            result.details += "scheduler_lock ${lock.diagnostic}\n"
        }
        ckbCliFinalizeSchedulerRun(result, schedulerKb, store, config, cli.storePath, lock)
        if (ckbCliWantsJson(args)) {
            result.jsonPrinted = true
            println(ckbCliSchedulerRunJson(result))
        } else {
            print("scheduler ran=${result.ran} succeeded=${result.succeeded} failed=${result.failed} degraded=${result.degraded} forced=${result.forced}\n")
            print(result.details)
        }
        return if (result.failed > 0 || result.degraded > 0 || !result.finalizationOk) { 1 } else { 0 }
    }
    if (cli.command == "backup") {
        let result = store.backupActiveSnapshot(cliTail(input, "backup", ""))
        print(renderBackupRestore(result))
        return if (result.ok) { 0 } else { 1 }
    }
    if (cli.command == "restore") {
        let result = store.restoreActiveSnapshotBackup(cliTail(input, "restore", ""))
        print(renderBackupRestore(result))
        return if (result.ok) { 0 } else { 1 }
    }
    if (cli.command == "schema") {
        println(CkbSchema.mcpTools())
        println(CkbSchema.httpLikeRoutes())
        return 0
    }
    if (cli.command == "query") {
        let query = cliTail(input, "query", "func syntax")
        print(renderQuery(cangjie_evidence_pack(kb, query, 5)))
        return 0
    }
    if (cli.command == "evidence") {
        let query = cliTail(input, "evidence", "HttpClient")
        print(renderQuery(cangjie_evidence_pack(kb, query, 3)))
        return 0
    }
    println("  cangjie-benchmark-gap-staging-init --config <path> --store <empty-path> [--json]")
    println("  cangjie-candidate-runtime-materialize --source-store <absolute-canonical-path> --output-store <absolute-canonical-new-path> --candidate-version <version>")
    println("  ckb-logical-proof | ckb-portable-vector-build | ckb-qdrant-snapshot create|restore|verify | ckb-retrieval-parity --mode build|verify")
    println("  ckb-repro-composition-stage --prepare-only --root <new-path> --mode <stage> --environment-plan <path> [stage-specific options] [--json]")
    println("  ckb-repro-environment-plan --environment-template <canonical-planned-path> --composition-manifest <canonical-existing-path> --run-candidate-commit <40-hex> --repository-root <canonical-path> --output <canonical-new-path> [--json]")
    println("  ckb-repro-attestation-authority-freeze --environment-lock <canonical-planned-path> --composition-manifest <canonical-existing-path> --signing-fingerprint <40-uppercase-hex> --output-root <canonical-new-path> [--json]")
    println("  ckb-repro-composition-seal --root <prepared-path> --mode <stage> --environment-plan <path> --attestation-authority <path> --asset <role=relative-path>... [--json]")
    println("  ckb-authority-bundle seal|verify | ckb-repro-build | ckb-repro-promote --apply | ckb-repro-verify --mode run-certify|release-verify --composition-manifest <path> [--json]")
    println("  cangjie-student-context-import --allowed-root <path> --base-context <path|none> --candidate-set <path> --approval <path> --frozen-knowledge-manifest <path> --knowledge-store <path> --output <path> --context-version <version> [--scaffold-import] [--json]")
    println("Usage: cangjie_community_knowledge_base [--config <path>] [--store <path>] doctor | status | metrics | service | service-http | http-service | mcp-stdio | cangjie-clean-candidate-build (--dry-run|--apply) --source-store <path> --staging-store <path> --authority-store <path> [--atoms-store <path>] --candidate-version <version> [--json] | cangjie-initialize (--dry-run|--apply) --docs-root <path> --std-root <path> --stdx-root <path> --eval-root <path> | cangjie-atom-selection-build --manifest <selection.jsonl> --teacher-export-root <path> --output <atoms.jsonl> --proof <proof.json> | cangjie-candidate-precert-seal --selected-atoms <normalized-candidate.jsonl> --output-root <dir> | cangjie-humaneval-manifest-build --dataset-root <path> --output <authority.jsonl> | cangjie-eval-classifier-run --run-root <path> --run-id <id> --transport C|D --output-root <path> --classifier-a-executable <path> --classifier-a-provider <id> --classifier-a-model <model> --classifier-a-id <id> --classifier-b-executable <path> --classifier-b-provider <id> --classifier-b-model <model> --classifier-b-id <id> --timeout-seconds <n> | cangjie-eval-development-close --run-root <path> --run-id <id> --transport C|D --classifier-a-root <path> --classifier-b-root <path> | cangjie-certification-preflight --control-manifest <path> | cangjie-frozen-candidate-seal --control-manifest <path> --store <path> | cangjie-certified-production-publish --control-manifest <path> --store <path> | cangjie-landing-status [--format json] | service-once <command> | start | stop | restart | sync-once | sync-live (--dry-run|--apply) | source_analysis repo=<owner/repo> ref=<ref> path=<path> | native-http-smoke <url> | cangjie-corpus-status | cangjie-knowledge-pack <task> | cangjie-api-search <query> | cangjie-syntax-query <query> | cangjie-cookbook <task> | cangjie-diagnose <compiler-output> | cangjie-llms [task] | cangjie-context-pack <task> | cangjie-eval-summary <manifest.jsonl> | cangjie-eval-abcde [--preflight-only] | cangjie-eval-knowledge-audit --run-root <path> | cangjie-humaneval-pass1-gate --run-root <path> | cangjie-knowledge-release-gate --run-root <path> --manifest <manifest.jsonl> | cangjie-typed-ingest-smoke --docs-root <path> --case-root <path> | cangjie-serving-feed-smoke | cangjie-serving-query-smoke | cangjie-update-promotion-smoke | cangjie-abcde-parity-smoke | cangjie-humaneval-pass1-gate-smoke | vector-bootstrap [--json] | vector-clean-derived [--force] [--json] | vector-reconcile [--force] [--json] | routine-repair --force [--json] | ollama-embedding-benchmark [--json] [--sample-size <n>] | scheduler-run [--force-all|--task <name> [--force]] [--json] | rebuild-index | backup <path> | restore <path> | query <text> | evidence <text> | schema")
    2
}

private func ckbCliWantsJson(args: Array<String>): Bool {
    var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == "--json") {
            return true
        }
        if (args[i] == "--format" && i + 1 < args.size && args[i + 1] == "json") {
            return true
        }
        i += 1
    }
    false
}

private func ckbMaybeRelaunchWithNativeTlsEnv(args: Array<String>): (Bool, Int64) {
    if (getVariable("CKB_NATIVE_TLS_BOOTSTRAPPED") == Some("1")) {
        return (false, 0)
    }
    let cli = parseCli(args)
    if (!ckbCommandNeedsNativeTlsBootstrap(cli.command)) {
        return (false, 0)
    }
    let command = getCommand()
    if (command.trimAscii() == "") {
        return (false, 0)
    }
    let config = loadCkbRuntimeConfig(cli.configPath)
    let script = ckbNativeTlsBootstrapScript(command, args,
        caFile: config.networkCaFile)
    try {
        let process = launch("/bin/zsh", ["-lc", script], stdIn: Inherit, stdOut: Inherit, stdErr: Inherit)
        return (true, process.wait())
    } catch (e: Exception) {
        println("native tls bootstrap failed: ${e.message}")
        return (true, 1)
    }
}

class CliOptions {
    var command: String = ""
    var configPath: String = ""
    var storePath: String = "target/ckb-data"
    var dryRun: Bool = false
    var apply: Bool = false

    init() {}
}

private func parseCli(args: Array<String>): CliOptions {
    let cli = CliOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--config" && i + 1 < args.size) {
            cli.configPath = args[i + 1]
            i += 2
            continue
        }
        if (arg == "--store" && i + 1 < args.size) {
            cli.storePath = args[i + 1]
            i += 2
            continue
        }
        if (arg == "--dry-run") {
            cli.dryRun = true
            i += 1
            continue
        }
        if (arg == "--apply") {
            cli.apply = true
            i += 1
            continue
        }
        if (!arg.startsWith("--") && cli.command == "") {
            cli.command = arg
        }
        i += 1
    }
    cli
}

private func cliInput(args: Array<String>): String {
    var input = ""
    var skipNext = false
    for (arg in args) {
        if (skipNext) {
            skipNext = false
            continue
        }
        if (arg == "--config" || arg == "--store") {
            skipNext = true
            continue
        }
        if (arg == "--dry-run" || arg == "--apply") {
            continue
        }
        if (input == "") {
            input = arg
        } else {
            input += " ${arg}"
        }
    }
    input.trimAscii()
}

private func loadCliKnowledgeBase(command: String, store: FileKnowledgeStore, config: CkbRuntimeConfig): KnowledgeBase {
    if (command == "schema" || command == "cangjie-eval-knowledge-audit") {
        return newOfflineKnowledgeBase()
    }
    newKnowledgeBaseFromStoreWithRuntime(store, config).kb
}

private func cliTail(input: String, command: String, fallback: String): String {
    if (input == command) {
        return fallback
    }
    let prefixSize = command.size + 1
    if (input.size <= prefixSize) {
        return fallback
    }
    input[prefixSize..input.size].trimAscii()
}

private func parseLiveApplyOptions(args: Array<String>): LiveApplyOptions {
    let options = LiveApplyOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "--apply") {
            options.apply = true
        } else if (arg == "--max-repos") {
            options.maxRepos = parseNextInt(args, i, -1)
            i += 1
        } else if (arg == "--max-files-per-repo") {
            options.maxFilesPerRepo = parseNextInt(args, i, -1)
            i += 1
        } else if (arg == "--max-items") {
            options.maxItems = parseNextInt(args, i, -1)
            i += 1
        } else if (arg == "--since") {
            if (i + 1 < args.size) {
                options.since = args[i + 1]
            }
            i += 1
        }
        i += 1
    }
    options
}

private func hasArg(args: Array<String>, name: String): Bool {
    for (arg in args) {
        if (arg == name) {
            return true
        }
    }
    false
}

private func ckbCliOption(args: Array<String>, name: String): String {
    var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == name && i + 1 < args.size) {
            return args[i + 1]
        }
        i += 1
    }
    ""
}

private func ckbCliOptionInt(args: Array<String>, name: String, fallback: Int64): Int64 {
    let value = ckbCliOption(args, name)
    if (value == "") {
        return fallback
    }
    try {
        Int64.parse(value)
    } catch (_: Exception) {
        fallback
    }
}

private func ckbCliSchedulerTaskNames(args: Array<String>): ArrayList<String> {
    let names = ArrayList<String>()
    var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == "--task" && i + 1 < args.size) {
            names.add(args[i + 1])
            i += 2
            continue
        }
        i += 1
    }
    names
}

private func ckbCliSchedulerRunJson(result: SchedulerExecutorResult): String {
    ckbSchedulerRunOutputJson(result)
}

private func ckbCliFinalizeBlockedSchedulerRun(result: SchedulerExecutorResult, store: FileKnowledgeStore, config: CkbRuntimeConfig, lock: CkbSchedulerRunLock): Unit {
    result.businessOk = false
    result.finalizationOk = true
    try {
        store.saveSchedulerLoopMetadata("failed", config.schedulerEnabled, config.schedulerLoopIntervalMillis, if (result.forced) { "cli_forced" } else { "cli_due" }, 0, 0, result.taskNames, "scheduler_pre_run_gate_failed")
        result.loopMetadataSaved = true
        result.loopMetadataStatus = "succeeded"
    } catch (e: Exception) {
        result.loopMetadataStatus = "failed"
        ckbCliMarkFinalizationFailure(result, "loop_metadata_save_failed", e)
    }
    try {
        ckbReleaseSchedulerRunLock(store, lock, result.runId, "failed")
        result.lockReleased = true
        result.lockReleaseStatus = "failed"
    } catch (e: Exception) {
        result.lockReleaseStatus = "failed"
        ckbCliMarkFinalizationFailure(result, "lock_release_failed", e)
    }
    result.jsonReadyAtMillis = ckbCoreNowMillis()
}

private func ckbCliFinalizeSchedulerRun(result: SchedulerExecutorResult, schedulerKb: KnowledgeBase, store: FileKnowledgeStore, config: CkbRuntimeConfig, storePath: String, lock: CkbSchedulerRunLock): Unit {
    result.businessOk = result.failed == 0 && result.degraded == 0
    try {
        ckbCliPopulateSchedulerRunEvidence(result, config, storePath)
    } catch (e: Exception) {
        ckbCliMarkFinalizationFailure(result, "evidence_populate_failed", e)
    }
    try {
        store.saveScheduler(schedulerKb.scheduler.entries)
        result.schedulerSaved = true
        result.schedulerSaveStatus = "succeeded"
    } catch (e: Exception) {
        result.schedulerSaveStatus = "failed"
        ckbCliMarkFinalizationFailure(result, "scheduler_save_failed", e)
    }
    try {
        store.saveSchedulerLoopMetadata(if (result.businessOk) { "running" } else { "failed" }, config.schedulerEnabled, config.schedulerLoopIntervalMillis, if (result.forced) { "cli_forced" } else { "cli_due" }, 0, result.ran, result.taskNames, if (result.businessOk) { "ok" } else { "scheduler_cli_run_degraded" })
        result.loopMetadataSaved = true
        result.loopMetadataStatus = "succeeded"
    } catch (e: Exception) {
        result.loopMetadataStatus = "failed"
        ckbCliMarkFinalizationFailure(result, "loop_metadata_save_failed", e)
    }
    try {
        ckbReleaseSchedulerRunLock(store, lock, result.runId, if (result.businessOk) { "succeeded" } else { "failed" })
        result.lockReleased = true
        result.lockReleaseStatus = if (result.businessOk) { "succeeded" } else { "failed" }
    } catch (e: Exception) {
        result.lockReleaseStatus = "failed"
        ckbCliMarkFinalizationFailure(result, "lock_release_failed", e)
    }
    result.jsonReadyAtMillis = ckbCoreNowMillis()
}

private func ckbCliMarkFinalizationFailure(result: SchedulerExecutorResult, step: String, e: Exception): Unit {
    result.finalizationOk = false
    let message = if (e.message.trimAscii() != "") { e.message } else { e.toString() }
    let diagnostic = "${step}:${utf8SafePrefix(redactSensitive(message.replace("\n", " ").replace("\r", " ").trimAscii()), 240)}"
    result.finalizationDiagnostics.add(diagnostic)
    result.details += "finalization ${diagnostic}\n"
}

private func ckbCliPopulateSchedulerRunEvidence(result: SchedulerExecutorResult, config: CkbRuntimeConfig, storePath: String): Unit {
    result.buildCommit = ckbCliBuildCommitEvidence()
    result.configHash = stableSummaryHash(config.redactedSummary())
    result.storeHash = stableSummaryHash(storePath)
}

private func ckbCliBuildCommitEvidence(): String {
    if (let Some(value) <- getVariable("CKB_BUILD_COMMIT")) {
        let trimmed = value.trimAscii()
        if (trimmed != "") {
            return trimmed
        }
    }
    "command:${stableSummaryHash(getCommand())}"
}

private func ckbCliSchedulerRunLockBudgetMillis(args: Array<String>): Int64 {
    if (hasArg(args, "--force-all")) {
        return 7200000
    }
    1800000
}

private func parseNextInt(args: Array<String>, index: Int64, fallback: Int64): Int64 {
    if (index + 1 >= args.size) {
        return fallback
    }
    try {
        Int64.parse(args[index + 1])
    } catch (_: Exception) {
        fallback
    }
}

private func ckbCliSampleSize(args: Array<String>): Int64 {
    var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == "--sample-size") {
            return parseNextInt(args, i, 64)
        }
        i += 1
    }
    64
}

private func renderCangjieEvalManifestFileSummary(path: String): (String, Int64) {
    try {
        let text = String.fromUtf8(File.readFrom(Path(path)))
        let summary = parseCangjieEvalManifest(text)
        return (renderCangjieEvalManifestSummary(summary), if (summary.invalidLines == 0) { 0 } else { 1 })
    } catch (e: Exception) {
        return ("CangjieEval v0 summary\nstatus=read_failed\ndiagnostic=${redactSensitive(e.message)}\n", 1)
    }
}

private func runCkbMcpStdioLoop(config: CkbRuntimeConfig, store: FileKnowledgeStore,
    boundTaskContextBase64: String, boundTaskContextHash: String,
    loadedKnowledgeBase: KnowledgeBase): Int64 {
    let service = CkbCommandLoopService(config, store,
        sourceRunner: if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() },
        loadedKnowledgeBase: Some<KnowledgeBase>(loadedKnowledgeBase))
    let server = CkbMcpStdioServer(service, boundTaskContextBase64: boundTaskContextBase64, boundTaskContextHash: boundTaskContextHash)
    let stdout = getStdOut()
    try (stdinFile = File("/dev/stdin", OpenMode.Read)) {
        let reader = StringReader(stdinFile)
        while (true) {
            let line = if (let Some(line) <- reader.readln()) {
                line
            } else {
                break
            }
            if (line.trimAscii() == "") {
                continue
            }
            let response = server.handleLine(line)
            if (response.shouldWrite) {
                stdout.writeln(response.payload)
                stdout.flush()
            }
        }
    } catch (_: Exception) {
        return 1
    }
    0
}

private func runCkbServiceLoop(config: CkbRuntimeConfig, store: FileKnowledgeStore,
    loadedKnowledgeBase: KnowledgeBase): Int64 {
    let runner: SourceFetchRunner = if (config.networkEnabled) { HttpSourceFetchRunner(config) } else { DisabledNetworkFetchRunner() }
    let service = CkbCommandLoopService(config, store, sourceRunner: runner,
        loadedKnowledgeBase: Some<KnowledgeBase>(loadedKnowledgeBase))
    print(service.start())
    try (stdinFile = File("/dev/stdin", OpenMode.Read)) {
        let reader = StringReader(stdinFile)
        while (true) {
            let line = if (let Some(line) <- reader.readln()) {
                line
            } else {
                break
            }
            let response = service.handleLine(line)
            print(response.text)
            if (response.shouldStop) {
                break
            }
        }
    } catch (_: Exception) {
        println("log level=error event=service_stdin_closed protocol=ckb-stdio-v1")
        return 1
    }
    0
}
