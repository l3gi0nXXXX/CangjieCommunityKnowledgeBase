package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.time.DateTime
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.*

@Test
public class CangjieEvalAbcdeRunnerCompletionTest {
    @TestCase
    public func targetedStudentParsesExplicitFailureSetWithoutChangingCertification():Unit{
        let targeted=parseCkbAbcdeRunnerOptions(["cangjie-eval-abcde","--targeted-student","--run-mode","development","--case-list","CJ-HUMANEVAL-077,116,145,162","--groups","D"])
        @Expect(targeted.targetedStudent,true);@Expect(targeted.caseSelectionValid,true)
        @Expect(targeted.selectedCaseIndexes.size,4);@Expect(targeted.selectedCaseIndexes[0],77)
        @Expect(targeted.selectedCaseIndexes[3],162);@Expect(targeted.caseStart,77);@Expect(targeted.caseEnd,162)
        @Expect(ckbAbcdeSelectedCase(targeted,77),true);@Expect(ckbAbcdeSelectedCase(targeted,78),false)
        @Expect(ckbAbcdeSelectedCase(targeted,116),true);@Expect(ckbAbcdeSelectedCase(targeted,161),false)
        let certification=parseCkbAbcdeRunnerOptions(["cangjie-eval-abcde","--run-mode","certification"])
        @Expect(certification.targetedStudent,false);@Expect(certification.caseStart,0);@Expect(certification.caseEnd,163)
    }

    @TestCase
    public func targetedStudentRequiresExplicitNonScoringSingleCompletionContract():Unit{
        let args=["cangjie-eval-abcde","--targeted-student","--run-mode","development","--case-id","CJ-HUMANEVAL-077","--groups","D","--generation-protocol","completion-only-v1","--samples-per-case","1","--generate-only","--transport-retries","0","--dataset-version","dataset-v1","--candidate-version","candidate-v1","--knowledge-version","knowledge-v1","--model-fingerprint","model-v1","--claude-bin","/usr/bin/true","--config","/usr/bin/true","--certification-run-manifest","/tmp/run-manifest.json","--provider-identity-artifact","/tmp/provider.json"]
        let valid=parseCkbAbcdeRunnerOptions(args);@Expect(ckbAbcdeDevelopmentOptionsDiagnostic(valid),"")
        valid.targetedStudent=false;@Expect(ckbAbcdeDevelopmentOptionsDiagnostic(valid),"targeted_student_opt_in_required")
        valid.targetedStudent=true;valid.generateOnly=false;valid.evaluateFrozen=true;valid.testSuites="base,plus";@Expect(ckbAbcdeDevelopmentOptionsDiagnostic(valid),"")
        @Expect(ckbAbcdeCompletionMode(valid),true)
        let context=CkbAbcdeTaskContext();ckbAbcdeBindTaskContextDatasetVersion(context,"dataset-v1")
        @Expect(context.datasetVersion,"dataset-v1")
        ckbAbcdeBindTaskContextDatasetVersion(context,"dataset-drift")
        @Expect(context.datasetVersion,"dataset-v1")
        valid.testSuites="base";@Expect(ckbAbcdeDevelopmentOptionsDiagnostic(valid),"targeted_student_requires_generate_or_evaluate")
        valid.testSuites="";valid.evaluateFrozen=false;valid.generateOnly=true
        valid.groups.clear();valid.groups.add(CkbAbcdeGroups.C);@Expect(ckbAbcdeDevelopmentOptionsDiagnostic(valid),"targeted_student_requires_group_d")
    }

    @TestCase
    public func targetedStudentRejectsMalformedDuplicateAndUtf8CaseSelection():Unit{
        for(value in ["CJ-HUMANEVAL-中文😀","077,077","164","77,,116"]){
            let options=parseCkbAbcdeRunnerOptions(["cangjie-eval-abcde","--targeted-student","--run-mode","development","--case-list",value,"--groups","D","--generation-protocol","completion-only-v1","--samples-per-case","1","--generate-only","--transport-retries","0","--dataset-version","dataset","--candidate-version","candidate","--knowledge-version","knowledge","--model-fingerprint","model","--claude-bin","/usr/bin/true","--certification-run-manifest","/tmp/manifest","--provider-identity-artifact","/tmp/provider"])
            @Expect(options.caseSelectionValid,false);@Expect(ckbAbcdeDevelopmentOptionsDiagnostic(options),"targeted_student_requires_case_selection")
        }
    }

    @TestCase
    public func targetedStudentIdentityDriftBlocksBeforeProviderExecutor():Unit{
        let options=CkbAbcdeRunnerOptions();options.generationProtocol="completion-only-v1";options.claudeBin="/usr/bin/true";options.providerRuntimeExecutablePath="/usr/bin/false"
        let executor=P3NeverCalledProvider();let result=ckbAbcdeRunClaudeCertification(options,CkbAbcdeGroups.D,"target/missing-targeted-group","target/missing-workspace","target/missing-home","target/missing-case",executor:executor)
        @Expect(result.exitCode,126);@Expect(result.stderr,"student_validation_identity_mismatch");@Expect(executor.calls,0)
    }

    // P3-UT-01
    @TestCase
    public func completionOptionsManifestAndSingleAnswerAreBound(): Unit {
        let options=parseCkbAbcdeRunnerOptions(["cangjie-eval-abcde","--generation-protocol","completion-only-v1","--samples-per-case","1","--generate-only"])
        @Expect(ckbAbcdeCompletionOptionsDiagnostic(options),"ok")
        let h="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        let legacyManifest="{\"generationProtocol\":\"completion-only-v1\",\"samplesPerCase\":1,\"datasetVersion\":\"dataset-v1\",\"knowledgeVersion\":\"knowledge-v1\",\"modelVersion\":\"GLM-5.2\",\"providerIdentityHash\":\"${h}\",\"skillBundleHash\":\"${h}\",\"samplingCapabilityHash\":\"${h}\",\"outputSchemaHash\":\"${h}\"}"
        @Expect(applyCkbAbcdeFrozenRunManifest(options,legacyManifest.toArray()),
            "run_manifest_malformed_json")
        let fixture = ckbPreflightStoreRouteFixture()
        @Expect(fixture.ready, true)
        if (!fixture.ready) { return }
        @Expect(runCkbCertificationPreflightCli(["cangjie-certification-preflight",
            "--control-manifest", fixture.controlPath],
            store: FileKnowledgeStore(fixture.frozenStorePath)), 0)
        let manifestPath = Path(fixture.outputRoot).join("run-manifest.json")
        options.certificationRunManifestPath = manifestPath.toString()
        let manifest = String.fromUtf8(File.readFrom(manifestPath))
        options.claudeBin=JsonValue.fromStr(manifest).asObject().get("providerRuntimeExecutablePath").getOrThrow().asString().getValue()
        @Expect(applyCkbAbcdeFrozenRunManifest(options,manifest.toArray()),"ok")
        let completion=ckbAbcdeExtractSingleCompletion(p3Terminal("package solution\npublic func answer(): Int64 { 42 } // 中文😀").toArray())
        @Expect(completion.ok,true);@Expect(completion.completionCount,1);@Expect(completion.toolCallCount,0)
        @Expect(completion.answerHash.startsWith("sha256:"),true)
    }

    @TestCase
    public func completionTranscriptNeedsNoToolResultAndContextHashesAreBound(): Unit {
        let terminal=p3Terminal("package solution\npublic func answer(): Int64 { 42 } // 中文😀")
        @Expect(ckbAbcdeCompletionViolation(terminal,"none"),"none")
        @Expect(ckbAbcdeCompletionViolation("{\"type\":\"tool_use\"}","none"),"completion_tool_use_forbidden")
        @Expect(ckbAbcdeCompletionViolation(terminal,"model_reference_exposure"),"model_reference_exposure")
        let task="task 中文😀";let pack="knowledge-pack";let skill="student-skill"
        let evidence=ckbAbcdeCompletionContextEvidence(task,pack,skill)
        @Expect(evidence.contains(benchmarkGapSha256(task)),true)
        @Expect(evidence.contains(benchmarkGapSha256(pack)),true)
        @Expect(evidence.contains(benchmarkGapSha256(skill)),true)
        @Expect(evidence!=ckbAbcdeCompletionContextEvidence(task,pack,skill+"-drift"),true)
    }

    @TestCase
    public func frozenEvaluationRebindsEveryExternalInputToSealedRun(): Unit {
        let options = CkbAbcdeRunnerOptions()
        options.runsRoot = "/sealed/runs"
        options.runId = "run-中文🙂"
        options.certificationPreflightPath = "/external/preflight.json"
        options.certificationRunManifestPath = "/external/run-manifest.json"
        options.providerIdentityArtifactPath = "/external/provider.json"
        options.frozenCandidateManifestPath = "/external/candidate.json"
        options.manifestPath = "/external/authority.jsonl"
        ckbAbcdeBindFrozenRunInputsForTest(options)
        let root = "/sealed/runs/run-中文🙂"
        @Expect(options.certificationPreflightPath,
            "${root}/preflight.json")
        @Expect(options.certificationRunManifestPath,
            "${root}/run-manifest.json")
        @Expect(options.providerIdentityArtifactPath,
            "${root}/provider-identity.json")
        @Expect(options.frozenCandidateManifestPath,
            "${root}/frozen-candidate-manifest.json")
        @Expect(options.manifestPath, "${root}/authority.jsonl")
    }

    @TestCase
    public func generationPhaseSealRejectsMutationAdditionAndSymlink(): Unit {
        let stamp = "${DateTime.now().toUnixTimeStamp().toMilliseconds()}"
        let root = Path("target/p4-generation-seal-${stamp}")
        Directory.create(root.join("cases/CJ-HUMANEVAL-000/D-ckb-mcp-http"),
            recursive: true)
        let artifact = root.join(
            "cases/CJ-HUMANEVAL-000/D-ckb-mcp-http/生成-🙂.json")
        File.writeTo(artifact, [UInt8(0xff), UInt8(0xfe), UInt8(0x00)])
        let canonicalRoot = canonicalize(root).toString()
        let seal = ckbAbcdeCreateGenerationSealForTest(canonicalRoot)
        @Expect(seal.startsWith("sha256:"), true)
        @Expect(ckbAbcdeVerifyGenerationSealForTest(canonicalRoot, seal), true)
        File.writeTo(artifact, "tampered 中文🙂".toArray())
        @Expect(ckbAbcdeVerifyGenerationSealForTest(canonicalRoot, seal), false)

        let addedRoot = Path("target/p4-generation-added-${stamp}")
        Directory.create(addedRoot, recursive: true)
        File.writeTo(addedRoot.join("one.json"), "{}".toArray())
        let canonicalAdded = canonicalize(addedRoot).toString()
        let addedSeal = ckbAbcdeCreateGenerationSealForTest(canonicalAdded)
        File.writeTo(addedRoot.join("two.json"), "{}".toArray())
        @Expect(ckbAbcdeVerifyGenerationSealForTest(
            canonicalAdded, addedSeal), false)

        let sealLinkRoot = Path("target/p4-generation-seal-link-${stamp}")
        Directory.create(sealLinkRoot, recursive: true)
        File.writeTo(sealLinkRoot.join("artifact.json"), "{}".toArray())
        let canonicalSealLink = canonicalize(sealLinkRoot).toString()
        let sealLinkHash = ckbAbcdeCreateGenerationSealForTest(
            canonicalSealLink)
        remove(sealLinkRoot.join("generation-phase-seal.json"))
        @Expect(launch("/bin/ln", ["-s", "artifact.json",
            sealLinkRoot.join("generation-phase-seal.json").toString()]).wait(), 0)
        @Expect(ckbAbcdeVerifyGenerationSealForTest(
            canonicalSealLink, sealLinkHash), false)

        let linkedRoot = Path("target/p4-generation-link-${stamp}")
        Directory.create(linkedRoot, recursive: true)
        File.writeTo(linkedRoot.join("real.json"), "{}".toArray())
        @Expect(launch("/bin/ln", ["-s", "real.json",
            linkedRoot.join("linked.json").toString()]).wait(), 0)
        @Expect(ckbAbcdeCreateGenerationSealForTest(
            canonicalize(linkedRoot).toString()), "")
        @Expect(runCangjieEvalAbcde(["cangjie-eval-abcde", "--run-mode",
            "certification"]), 1)
        @Expect(exists(root.join("generation-phase-seal.json")), true)
    }

    // P3-BND-01
    @TestCase
    public func completionBoundariesFailClosedWithoutTruncation(): Unit {
        @Expect(ckbAbcdeExtractSingleCompletion([UInt8(0xff),UInt8(0xfe)]).diagnostic,"invalid_response_encoding")
        @Expect(ckbAbcdeExtractSingleCompletion("{".toArray()).diagnostic,"malformed_json")
        @Expect(ckbAbcdeExtractSingleCompletion(p3TerminalFields("\"solution_cj\":\"ok\",\"extra\":1").toArray()).diagnostic,"completion_schema_invalid")
        @Expect(ckbAbcdeExtractSingleCompletion(p3Terminal("").toArray()).diagnostic,"completion_empty")
        let large=StringBuilder();for(_ in 0..262145){large.append("x")}
        let oversized=p3Terminal(large.toString()).toArray()
        @Expect(ckbAbcdeExtractSingleCompletion(oversized).diagnostic,"solution_too_large")
        let valid=StringBuilder();for(_ in 0..262144){valid.append("x")}
        @Expect(ckbAbcdeExtractSingleCompletion(p3Terminal(valid.toString()).toArray()).ok,true)
        let transcript=StringBuilder();for(_ in 0..4194305){transcript.append("x")}
        @Expect(ckbAbcdeExtractSingleCompletion(transcript.toString().toArray()).diagnostic,"transcript_too_large")
    }

    @TestCase
    public func completionEventArrayRequiresOneFinalTerminal(): Unit {
        let solution = "package solution\npublic func answer(): String { \"中文😀\" }"
        let terminal = p3Terminal(solution)
        let valid = "[{\"type\":\"system\"},{\"type\":\"assistant\"},${terminal}]"
        let completion = ckbAbcdeExtractSingleCompletion(valid.toArray())
        @Expect(completion.ok, true)
        @Expect(completion.solutionCj, solution)
        @Expect(ckbAbcdeExtractSingleCompletion("[${terminal},${terminal}]".toArray()).diagnostic,
            "malformed_json")
        @Expect(ckbAbcdeExtractSingleCompletion("[${terminal},{\"type\":\"system\"}]".toArray()).diagnostic,
            "malformed_json")
        @Expect(ckbAbcdeExtractSingleCompletion("[{\"type\":\"system\"}]".toArray()).diagnostic,
            "malformed_json")
        @Expect(ckbAbcdeExtractSingleCompletion("[1,${terminal}]".toArray()).diagnostic,
            "malformed_json")
    }

    @TestCase
    public func generationFailureWritesCanonicalImmutableTeacherCarrier(): Unit {
        let root=Path("target/p3-generation-failure-carrier-${DateTime.now().toUnixTimeStamp().toMilliseconds()}")
        Directory.create(root,recursive:true)
        File.writeTo(root.join("claude-transcript.jsonl"),Array<UInt8>())
        File.writeTo(root.join("claude-attempts.jsonl"),
            "{\"attempt\":1,\"exitCode\":124}\n".toArray())
        File.writeTo(root.join("claude.attempt-1.stderr.log"),
            "claude_timeout_after_600s\n".toArray())
        let options=CkbAbcdeRunnerOptions();options.runId="generation-failure-run"
        options.datasetVersion="cangjie-humaneval-164-v1"
        options.generationProtocol="completion-only-v1";options.generateOnly=true
        @Expect(persistCkbGenerationFailureEvidence(root.toString(),options,
            "CJ-HUMANEVAL-124","malformed_json"),"ok")
        let raw=File.readFrom(root.join("completion-failure.json"))
        let parsed=parseCkbCompletionFailure(raw)
        @Expect(parsed[1],"ok");@Expect(parsed[0].failureKind,"timeout")
        @Expect(parsed[0].baseStatus,"infra_error");@Expect(parsed[0].plusStatus,"infra_error")
        @Expect(parsed[0].assetLineage,"humaneval_164_derived")
        @Expect(parsed[0].failureObservation.contains("CJ-HUMANEVAL"),false)
        @Expect(parsed[0].failureObservation.contains("/Users/"),false)
        @Expect(persistCkbGenerationFailureEvidence(root.toString(),options,
            "CJ-HUMANEVAL-124","malformed_json"),"ok")
        File.writeTo(root.join("claude-transcript.jsonl"),"drift 中文🙂".toArray())
        @Expect(persistCkbGenerationFailureEvidence(root.toString(),options,
            "CJ-HUMANEVAL-124","malformed_json"),
            "failure_evidence_frozen")
        @Expect(persistCkbGenerationFailureEvidence(root.toString(),options,
            "CJ-HUMANEVAL-124",""),"generation_failure_evidence_invalid")

        let invalidRoot=Path("${root.toString()}-invalid");Directory.create(invalidRoot,recursive:true)
        File.writeTo(invalidRoot.join("claude-transcript.jsonl"),[UInt8(0xff),UInt8(0xfe)])
        @Expect(persistCkbGenerationFailureEvidence(invalidRoot.toString(),options,
            "CJ-HUMANEVAL-145","invalid_response_encoding"),"ok")
        let invalid=parseCkbCompletionFailure(File.readFrom(
            invalidRoot.join("completion-failure.json")))
        @Expect(invalid[1],"ok");@Expect(invalid[0].failureKind,"protocol_violation")

        let missingRoot=Path("${root.toString()}-missing");Directory.create(missingRoot,recursive:true)
        @Expect(persistCkbGenerationFailureEvidence(missingRoot.toString(),options,
            "CJ-HUMANEVAL-162","completion_read_failed"),"ok")
        let missing=parseCkbCompletionFailure(File.readFrom(
            missingRoot.join("completion-failure.json")))
        @Expect(missing[1],"ok");@Expect(missing[0].failureKind,"infra_error")
    }

    // P3-POS-01
    @TestCase
    public func validCompletionFreezesBeforeIndependentEvaluation(): Unit {
        let root="target/p3-completion-${DateTime.now().toUnixTimeStamp().toMilliseconds()}"
        let completion=ckbAbcdeExtractSingleCompletion(p3Terminal("package p3_completion_fixture\nmain() { println(\"ok 中文😀\") }").toArray())
        @Expect(ckbAbcdeFreezeCompletion(root,completion),"ok")
        @Expect(String.fromUtf8(File.readFrom(Path(root).join("solution.cj"))),completion.solutionCj)
        let compileRoot=Path("${root}-compile");Directory.create(compileRoot.join("src"),recursive:true)
        File.writeTo(compileRoot.join("src/main.cj"),completion.solutionCj.toArray())
        File.writeTo(compileRoot.join("cjpm.toml"),"[package]\ncjc-version = \"1.0.0\"\nname = \"p3_completion_fixture\"\nversion = \"0.1.0\"\noutput-type = \"executable\"\n".toArray())
        @Expect(launch("cjpm",["build"],workingDirectory:Some<Path>(compileRoot)).wait(),0)
        @Expect(ckbAbcdeFreezeCompletion(root,completion),"completion_already_frozen")
        let blockedParent=Path("${root}-blocked-parent");File.writeTo(blockedParent,"not-a-directory".toArray())
        let blockedRoot=blockedParent.join("child")
        @Expect(ckbAbcdeFreezeCompletion(blockedRoot.toString(),completion),"completion_freeze_failed")
        @Expect(exists(blockedRoot),false)
    }

    @TestCase
    public func realRunnerEvaluationInterfaceWritesIndependentBasePlusEvidence():Unit{
        let root=Path("target/p3-runner-evaluator-${DateTime.now().toUnixTimeStamp().toMilliseconds()}");let groupRoot=root.join("case");let workspace=groupRoot.join("workspace");Directory.create(workspace.join("src"),recursive:true);let solution="package solution\npublic func answer(): Int64 { 42 } // 中文😀\n";File.writeTo(workspace.join("src/solution.cj"),solution.toArray());let completion=ckbAbcdeExtractSingleCompletion(p3Terminal(solution).toArray());@Expect(ckbAbcdeFreezeCompletion(groupRoot.join("frozen-completion").toString(),completion),"ok");File.writeTo(groupRoot.join("generation-evidence.json"),"{\"answerHash\":\"${completion.answerHash}\",\"completionCount\":1,\"toolCallCount\":0,\"executionFeedbackCount\":0,\"interrupted\":false,\"generatedTokenCount\":1,\"checkpointRecovered\":false}".toArray());File.writeTo(groupRoot.join("answer-freeze.json"),"{\"answerHash\":\"${completion.answerHash}\",\"sequence\":2}".toArray())
        let verifier=P3FakeCompletionVerifier();let evaluated=ckbAbcdeEvaluateFrozenCompletion(groupRoot.toString(),root.join("case-source").toString(),workspace.toString(),completion.answerHash,"base,plus",executor:verifier)
        @Expect(evaluated.basePassed,true);@Expect(evaluated.plusPassed,true);@Expect(verifier.baseCalls,1);@Expect(verifier.plusCalls,1);@Expect(verifier.workspaces.size,2);@Expect(verifier.workspaces[0]!=verifier.workspaces[1],true);@Expect(String.fromUtf8(File.readFrom(workspace.join("src/solution.cj"))),solution)
        for(name in ["frozen-completion/solution.cj","generation-evidence.json","answer-freeze.json","base-test-result.json","plus-test-result.json"]){@Expect(exists(groupRoot.join(name)),true)}
        @Expect(String.fromUtf8(File.readFrom(groupRoot.join("base-test-result.json"))).contains("\"answerHash\":\"${completion.answerHash}\""),true);@Expect(String.fromUtf8(File.readFrom(groupRoot.join("plus-test-result.json"))).contains("\"answerHash\":\"${completion.answerHash}\""),true)
    }

    // P4-POS-01: exercise the production suite executor against the protected
    // Base and Plus assets without invoking a model or a certification run.
    @TestCase
    public func realCase000BaseAndPlusAssetsPassThroughProductionExecutor(): Unit {
        let root = Path("target/p4-real-plus-smoke-${DateTime.now().toUnixTimeStamp().toMilliseconds()}")
        let groupRoot = root.join("case")
        let workspace = groupRoot.join("workspace")
        let caseSrc = Path("cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-000")
        Directory.create(workspace, recursive: true)
        @Expect(launch("/bin/cp", ["-R", "${caseSrc.join("starter")}/.", workspace.toString()]).wait(), 0)
        let solution = "package cangjie_humaneval_000\n\n" +
            "import std.collection.*\n\n" +
            "public func has_close_elements(numbers: ArrayList<Float64>, threshold: Float64): Bool {\n" +
            "    for (i in 0..numbers.size) {\n" +
            "        for (j in (i + 1)..numbers.size) {\n" +
            "            let difference = numbers[i] - numbers[j]\n" +
            "            let distance = if (difference < 0.0) { -difference } else { difference }\n" +
            "            if (distance < threshold) { return true }\n" +
            "        }\n" +
            "    }\n" +
            "    return false\n" +
            "}\n"
        File.writeTo(workspace.join("src/solution.cj"), solution.toArray())
        let answerHash = benchmarkGapSha256(solution)
        let evaluated = ckbAbcdeEvaluateFrozenCompletion(groupRoot.toString(), caseSrc.toString(),
            workspace.toString(), answerHash, "base,plus")
        @Expect(evaluated.baseExecuted, true)
        @Expect(evaluated.plusExecuted, true)
        @Expect(evaluated.basePassed, true)
        @Expect(evaluated.plusPassed, true)
        @Expect(String.fromUtf8(File.readFrom(groupRoot.join("base-test-result.json"))).contains("\"passed\":true"), true)
        @Expect(String.fromUtf8(File.readFrom(groupRoot.join("plus-test-result.json"))).contains("\"passed\":true"), true)
    }

    // P3-NEG-01
    @TestCase
    public func toolFallbackAndMultipleTerminalFormsAreRejected(): Unit {
        for(raw in ["{\"type\":\"assistant\",\"tool_use\":\"Bash\"}",p3Terminal("x")+"\n"+p3Terminal("y")]){
            @Expect(ckbAbcdeExtractSingleCompletion(raw.toArray()).ok,false)
        }
        let command=ckbAbcdeCertificationClaudeCommand("case","home","profile","claude","GLM-5.2","transcript","stderr")
        let probe=ckbAbcdeRunCompletionCapabilityProbe(command,p3Terminal("public func answer(): Int64 { 42 }").toArray(),"provider_default_not_client_exposed")
        @Expect(probe.ok,true);@Expect(command.contains("--tools ''"),true);@Expect(command.contains("--max-turns 1"),true)
        @Expect(command.contains("--output-format json"),true);@Expect(command.contains("additionalProperties"),true)
        @Expect(command.contains("output-schema.json"),false)
        @Expect(command.contains("ANTHROPIC_AUTH_TOKEN=\"$GLM_API_KEY\""),true)
        @Expect(command.contains("ANTHROPIC_BASE_URL=\"$GLM_BASE_URL\""),true)
        @Expect(command.contains("ANTHROPIC_MODEL='GLM-5.2'"),true)
        @Expect(command.contains("secret-token"),false)
        @Expect(ckbAbcdeExtractSingleCompletion(p3Terminal("// bash SKILL.md mcp__ are harmless source text\nmain() {}").toArray()).ok,true)
        @Expect(ckbAbcdeExtractSingleCompletion(p3Terminal("// ```cangjie is documentation text\nmain() {}").toArray()).ok,true)
        @Expect(ckbAbcdeExtractSingleCompletion(p3Terminal("// JSON key name: \"solution_cj\"\nmain() {}").toArray()).ok,true)
        let assessed=ckbAbcdeAssessSample(p3Terminal("main() {}"),"GLM-5.2")
        @Expect(assessed.completeResult,true);@Expect(assessed.identityMatched,true);@Expect(assessed.toolEventCount,0)
        @Expect(command.toAsciiLower().contains("authorization"),false)
    }

    // R6-C1-NEG: identity/path drift is rejected before the provider executor.
    @TestCase
    public func studentValidationDriftMakesProviderCallCountZero(): Unit {
        let root=Path("../target/r6-provider-path-drift-${DateTime.now().toUnixTimeStamp().toMilliseconds()}");Directory.create(root,recursive:true);let runtimeA=root.join("runtime-a");let runtimeB=root.join("runtime-b");File.writeTo(runtimeA,"runtime-a".toArray());File.writeTo(runtimeB,"runtime-b".toArray())
        let options=CkbAbcdeRunnerOptions();options.runMode="certification";options.generationProtocol="completion-only-v1"
        options.claudeBin=canonicalize(runtimeA).toString();options.providerIdentityArtifactPath="/missing/provider.json";options.providerRuntimeExecutablePath=canonicalize(runtimeB).toString()
        options.completionControlPath="/missing/control.json";options.providerPromptCapabilityPath="/missing/capability.json"
        let executor=R6CountingProviderExecutor();let result=ckbAbcdeRunClaudeCertification(options,CkbAbcdeGroups.D,
            "/missing/group","/missing/workspace","/missing/home","/missing/case",executor:executor)
        @Expect(result.exitCode,126);@Expect(result.stderr,"student_validation_identity_mismatch");@Expect(executor.calls,0)
    }
}

private class P3NeverCalledProvider <: CkbAbcdeCertificationProviderExecutor {
    public var calls:Int64=0
    public override func execute(options:CkbAbcdeRunnerOptions,group:String,groupRoot:String,workspace:String,runtimeHome:String,caseSrc:String):CkbAbcdeCommandResult{calls+=1;CkbAbcdeCommandResult()}
}

private class R6CountingProviderExecutor <: CkbAbcdeCertificationProviderExecutor {
    public var calls:Int64=0
    public override func execute(options:CkbAbcdeRunnerOptions,group:String,groupRoot:String,workspace:String,
        runtimeHome:String,caseSrc:String):CkbAbcdeCommandResult{calls+=1;CkbAbcdeCommandResult()}
}

private class P3FakeCompletionVerifier <: CkbAbcdeCompletionSuiteExecutor {
    public var baseCalls:Int64=0
    public var plusCalls:Int64=0
    public var workspaces:ArrayList<String>=ArrayList<String>()
    public override func execute(suite:String,caseSrc:String,workspace:String):CkbAbcdeCommandResult{workspaces.add(workspace);if(suite=="base"){baseCalls+=1}else if(suite=="plus"){plusCalls+=1};let result=CkbAbcdeCommandResult();result.exitCode=0;result.stdout="PASS ${suite} 中文😀";result}
}

private func p3Terminal(solution:String):String{p3TerminalFields("\"solution_cj\":\"${ckbAbcdeJsonEscape(solution)}\"")}
private func p3TerminalFields(fields:String):String{"{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"modelUsage\":{\"GLM-5.2\":{}},\"structured_output\":{${fields}}}"}
