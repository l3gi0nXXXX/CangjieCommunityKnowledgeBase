package cangjie_community_knowledge_base_test

import std.collection.*
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbCertificationS4ContractTest {
    @TestCase
    public func psUt01PublicTaskPrecedesFrozenGuidanceAndChecklistClosesPrompt(): Unit {
        let assets = s4PromptSalienceAssets("Implement the public function.")
        let prompt = renderCkbS4CompletionPrompt(assets)
        let publicTaskAt = prompt.indexOf("## Public task").getOrThrow()
        let rulesAt = prompt.indexOf("## Student rules").getOrThrow()
        let skillAt = prompt.indexOf("## Student skill").getOrThrow()
        let knowledgeAt = prompt.indexOf("## Frozen knowledge").getOrThrow()
        let checklistAt = prompt.indexOf("## Pre-submit checklist").getOrThrow()
        @Expect(publicTaskAt < rulesAt, true)
        @Expect(rulesAt < skillAt, true)
        @Expect(skillAt < knowledgeAt, true)
        @Expect(knowledgeAt < checklistAt, true)
        @Expect(prompt.contains("scan every declared identifier against Cangjie reserved keywords"), true)
        @Expect(prompt.contains("rename or consistently escape any conflict"), true)
        @Expect(prompt.contains("verify the receiver type, member name, parameter types, and return type"), true)
        @Expect(prompt.contains("do not invent convenience members"), true)
        @Expect(prompt.endsWith("Submit exactly one completion.\n"), true)
    }

    @TestCase
    public func psBnd01UnicodeEmojiAndLongAssetsRemainExact(): Unit {
        let task = StringBuilder()
        for (_ in 0..4096) {
            task.append("中文🙂")
        }
        let assets = s4PromptSalienceAssets(task.toString())
        assets.rules = "规则🙂\n" + assets.rules
        assets.skill = "技能中文🙂\n" + assets.skill
        let prompt = renderCkbS4CompletionPrompt(assets)
        @Expect(prompt.contains(assets.publicTask), true)
        @Expect(prompt.contains(assets.rules), true)
        @Expect(prompt.contains(assets.skill), true)
        @Expect(prompt.contains(assets.knowledge), true)
        @Expect(prompt.toArray().size > assets.publicTask.toArray().size, true)
    }

    @TestCase
    public func psPos01PromptRenderingDoesNotChangeFrozenAssetEvidence(): Unit {
        let assets = s4PromptSalienceAssets("Implement the public function.")
        let evidenceBefore = renderCkbS4ContextEvidenceV2(assets)
        let rulesHashBefore = benchmarkGapSha256(assets.rules)
        let skillHashBefore = benchmarkGapSha256(assets.skill)
        let prompt = renderCkbS4CompletionPrompt(assets)
        @Expect(prompt == "", false)
        @Expect(renderCkbS4ContextEvidenceV2(assets), evidenceBefore)
        @Expect(benchmarkGapSha256(assets.rules), rulesHashBefore)
        @Expect(benchmarkGapSha256(assets.skill), skillHashBefore)
        @Expect(ckbS4FrozenContextEvidenceDiagnostic(assets, evidenceBefore), "ok")
    }

    @TestCase
    public func psNeg01PrivateProtocolAndCaseMarkersRemainRejected(): Unit {
        let privateCase = s4PromptSalienceAssets("{\"caseId\":\"private\"}")
        @Expect(ckbS4FrozenAssetsDiagnostic(privateCase), "private_protocol_field_forbidden")
        @Expect(renderCkbS4CompletionPrompt(privateCase), "")
        let privateProtocol = s4PromptSalienceAssets("Implement the public function.")
        privateProtocol.protocol = "{\"generationProtocol\":\"private\"}"
        @Expect(ckbS4FrozenAssetsDiagnostic(privateProtocol), "private_protocol_field_forbidden")
        @Expect(renderCkbS4CompletionPrompt(privateProtocol), "")
    }

    @TestCase
    public func psHist01CompletionOnlyInvariantRemainsStrict(): Unit {
        @Expect(ckbS4GenerationProtocolDiagnostic("completion-only-v1", 1, 1, 0), "ok")
        @Expect(ckbS4GenerationProtocolDiagnostic("completion-only-v1", 2, 1, 0), "single_completion_required")
        @Expect(ckbS4GenerationProtocolDiagnostic("completion-only-v1", 1, 2, 0), "completion_knowledge_entry_count_invalid")
        @Expect(ckbS4GenerationProtocolDiagnostic("completion-only-v1", 1, 1, 1), "completion_tool_call_forbidden")
    }

    @TestCase
    public func s4UtControlV5PreflightAndProviderCapabilityBindings(): Unit {
        let fixture = ckbPreflightStoreRouteFixture();
        @Expect(fixture.ready,true)
        if (!fixture.ready) {
            return
        }
        let input = String.fromUtf8(File.readFrom(Path(fixture.inputPath)));
        let parsed = parseCkbCertificationControlManifest(input.toArray());
        @Expect(parsed.ok,true)
        let sealed = sealCkbCertificationControlManifest(parsed);
        @Expect(parseCkbCertificationControlManifest(sealed.toArray()).ok,true)
        @Expect(runCkbCertificationPreflightCli(["cangjie-certification-preflight","--control-manifest",fixture.controlPath],store:FileKnowledgeStore(fixture.frozenStorePath)),0)
        let manifest = String.fromUtf8(File.readFrom(Path(fixture.outputRoot).join("run-manifest.json")))
        @Expect(manifest.contains("\"studentContextCompositeHash\":"),true)
        @Expect(manifest.contains("\"combinationAuditHash\":"),true)
        @Expect(manifest.contains("\"providerPromptCapabilityHash\":"),true)
    }

    @TestCase
    public func s4BndUtf8ByteBudgetAndJsonSseTerminalBoundaries(): Unit {
        let requestHash = s4Hash(r'd');
        let pack = "中文🙂";
        let structured = "{\"knowledgeVersion\":\"v1\",\"knowledgePack\":\"${pack}\",\"requestHash\":\"${requestHash}\",\"contentHash\":\"${benchmarkGapSha256(pack)}\"}";
        let rpc = "{\"jsonrpc\":\"2.0\",\"id\":7,\"result\":{\"structuredContent\":${structured}}}"
        @Expect(parseCompletionMcpHttpBody(rpc.toArray(),"auto","7",requestHash,"v1").ok,true)
        @Expect(parseCompletionMcpHttpBody("data: ${rpc}\n\n".toArray(),"auto","7",requestHash,"v1").ok,true)
        let taskPack = s4TaskKnowledgeRpc(requestHash)
        let parsedTaskPack = parseCompletionMcpHttpBody(
            taskPack.toArray(), "auto", "7", requestHash, "v1")
        @Expect(parsedTaskPack.ok, true)
        let normalized = String.fromUtf8(parsedTaskPack.normalizedBytes)
        @Expect(normalized.contains("matchedEvidence"), true)
        @Expect(normalized.contains("中文🙂"), true)
        @Expect(normalized.contains("CJ-HUMANEVAL-000"), false)
        @Expect(parseCompletionMcpHttpBody(taskPack.replace(requestHash,
            s4Hash(r'e')).toArray(), "auto", "7", requestHash, "v1")
            .diagnostic, "structured_content_request_hash_mismatch")
        @Expect(parseCompletionMcpHttpBody([UInt8(0xff)],"auto","7",requestHash,"v1").diagnostic,"invalid_response_encoding")
        let capability = s4Capability("model-v1", 6);
        @Expect(parseCkbS4ProviderPromptCapability(capability.toArray(),"model-v1","中文").ok,true)
        @Expect(parseCkbS4ProviderPromptCapability(capability.toArray(),"model-v1","中文a").diagnostic,"provider_prompt_budget_exceeded")
    }

    @TestCase
    public func s4PosSixAssetsFreezeEvidenceAndPromptOrder(): Unit {
        let prepared = s4PreparedRun("pos");
        @Expect(prepared[0],"ok")
        if (prepared[0] != "ok") {
            return
        };
        let options = prepared[1];
        let groupRoot = prepared[2]
        let frozenSkillBytes = File.readFrom(
            Path(options.studentContextRoot).join("student-skills.json"))
        let frozenSkillBundle = parseStudentSkillBundle(frozenSkillBytes)
        @Expect(frozenSkillBundle.ok, true)
        let expectedSkillHash =
            readStudentContextBundleV2(options.studentContextRoot).skillsHash
        @Expect(frozenSkillBundle.canonicalHash, expectedSkillHash)
        @Expect(benchmarkGapSha256(String.fromUtf8(frozenSkillBytes)) ==
            frozenSkillBundle.canonicalHash, false)
        @Expect(ckbAbcdeSkillBundleDiagnostic(frozenSkillBytes,
            expectedSkillHash), "ok")
        @Expect(ckbAbcdeSkillBundleDiagnostic(frozenSkillBytes,
            benchmarkGapSha256(String.fromUtf8(frozenSkillBytes))),
            "skill_bundle_hash_mismatch")
        let assets = s4AssetsFromRun(options);
        @Expect(ckbAbcdeFreezeS4CaseAssets(groupRoot,assets,true),"ok")
        @Expect(ckbAbcdeFreezeS4CaseAssets(groupRoot,assets,false),"ok")
        File.writeTo(Path(groupRoot).join("completion-context-evidence.json"),
            (ckbAbcdeCompletionContextEvidence(assets) + "\n").toArray())
        let loaded = ckbAbcdeLoadFrozenS4CaseContext(groupRoot,
            assets.compositeHash, assets.combinationAuditHash)
        @Expect(loaded.ok,true)
        @Expect(loaded.diagnostic,"ok")
        @Expect(loaded.assets.knowledge,assets.knowledge)
        let prompt = renderCkbS4CompletionPrompt(assets);
        File.writeTo(Path(groupRoot).join("prompt.final.md"), prompt.toArray());
        @Expect(prompt.contains("caseId"),false)
        @Expect(prompt.indexOf("## Public task").getOrThrow()<prompt.indexOf("## Student rules").getOrThrow(),true)
        @Expect(prompt.indexOf("## Student rules").getOrThrow()<prompt.indexOf("## Student skill").getOrThrow(),true)
        @Expect(prompt.indexOf("## Student skill").getOrThrow()<prompt.indexOf("## Frozen knowledge").getOrThrow(),true)
        @Expect(prompt.indexOf("## Frozen knowledge").getOrThrow()<prompt.indexOf("## Pre-submit checklist").getOrThrow(),true)
        let fake = S4FakeCertificationProvider();
        let result = ckbAbcdeRunClaudeCertification(options, CkbAbcdeGroups.D, groupRoot, "workspace", "runtime", "case",
            executor: fake);
        @Expect(result.exitCode,0)
        @Expect(fake.callCount,1)
        let transcript = s4CompletionTranscript();
        let probe = ckbAbcdeRunCompletionCapabilityProbe(
            "claude --bare --tools '' --disable-slash-commands --setting-sources '' --strict-mcp-config --max-turns 1 --json-schema",
            transcript.toArray(), "provider_default_not_client_exposed");
        @Expect(probe.ok,true)
        @Expect(ckbS4GenerationProtocolDiagnostic("completion-only-v1",1,1,0),"ok")
    }

    @TestCase
    public func s4NegRpcIdErrorHashVersionEvidenceAndProtocolDriftFailClosed(): Unit {
        let prepared = s4PreparedRun("neg");
        @Expect(prepared[0],"ok")
        if (prepared[0] != "ok") {
            return
        };
        let options = prepared[1];
        let groupRoot = prepared[2];
        let assets = s4AssetsFromRun(options)
        @Expect(ckbAbcdeFreezeS4CaseAssets(groupRoot,assets,true),"ok")
        File.writeTo(Path(groupRoot).join("completion-context-evidence.json"),
            (ckbAbcdeCompletionContextEvidence(assets) + "\n").toArray())
        File.writeTo(Path(groupRoot).join("student-rules.md"), "tampered".toArray());
        @Expect(ckbAbcdeFreezeS4CaseAssets(groupRoot,assets,false),"frozen_context_asset_hash_mismatch")
        @Expect(ckbAbcdeLoadFrozenS4CaseContext(groupRoot,
            assets.compositeHash,assets.combinationAuditHash).diagnostic,
            "completion_context_binding_mismatch")
        File.writeTo(Path(groupRoot).join("student-rules.md"), [UInt8(0xff),UInt8(0xfe)])
        @Expect(ckbAbcdeLoadFrozenS4CaseContext(groupRoot,
            assets.compositeHash,assets.combinationAuditHash).diagnostic,
            "invalid_response_encoding")
        @Expect(ckbS4FrozenContextEvidenceDiagnostic(assets,"{}"),"context_evidence_drift")
        let fake = S4FakeCertificationProvider();
        options.effectivePromptByteBudget = 1
        File.writeTo(Path(groupRoot).join("prompt.final.md"), renderCkbS4CompletionPrompt(assets).toArray());
        let blocked = ckbAbcdeRunClaudeCertification(options, CkbAbcdeGroups.D, groupRoot, "workspace", "runtime",
            "case", executor: fake);
        @Expect(blocked.exitCode,126)
        @Expect(fake.callCount,0)
        let manifest = String.fromUtf8(File.readFrom(Path(prepared[3])));
        let driftOptions = CkbAbcdeRunnerOptions()
        driftOptions.runId = options.runId
        driftOptions.runsRoot = options.runsRoot
        driftOptions.expectedModelVersion = options.expectedModelVersion
        driftOptions.certificationRunManifestPath = prepared[3]
        driftOptions.claudeBin = options.claudeBin
        @Expect(applyCkbAbcdeFrozenRunManifest(driftOptions,
            manifest.replace(options.studentContextCompositeHash,s4Hash(r'e')).toArray()),
            "student_context_not_student_validated")
    }

    @TestCase
    public func s4FrozenRulesIdentityAndFiveFunctionContract(): Unit {
        let rows = ArrayList<CkbStrictScoreEvidenceRow>();
        let manifest = s4RulesManifest()
        for (i in 0..164) {
            let caseId = if (i < 10) {
                "CJ-HUMANEVAL-00${i}"
            } else if (i < 100) {
                "CJ-HUMANEVAL-0${i}"
            } else {
                "CJ-HUMANEVAL-${i}"
            };
            let certification = s4Certification(caseId);
            @Expect(ckbAbcdeBindCompletionCertificationV5(certification,manifest,"completion-only-v1"),"ok")
            sealCkbCertificationEvidence(certification);
            let parsed = parseCkbCertificationEvidence(renderCkbCertificationEvidenceJson(certification));
            @Expect(parsed.valid,true)
            rows.add(cangjieHumanEvalCompletionScoreRow(parsed))
        }
        let score = computeCkbHumanEvalStrictScore(rows);
        @Expect(score.diagnostic,"ok")
        @Expect(score.valid,true)
        @Expect(score.strictPassed,164)
        @Expect(rows[0].schemaVersion,"ckb-humaneval-public-evidence-v3")
        @Expect(ckbS4RulesIdentityDiagnostic(rows[0].rulesHash,rows[0].rulesTreeHash,rows[0].rulesCount),"ok")
    }
}

private func s4PromptSalienceAssets(publicTask: String): CkbS4FrozenContextAssets {
    let assets = CkbS4FrozenContextAssets()
    assets.protocol = "Use exactly one completion. Do not call tools."
    assets.rules = "Preserve the frozen rules exactly."
    assets.skill = "Preserve the frozen skill exactly."
    assets.knowledge = "Preserve the frozen knowledge exactly."
    assets.providerCapability = "Preserve the frozen provider capability exactly."
    assets.publicTask = publicTask
    assets.compositeHash = s4Hash(r'a')
    assets.combinationAuditHash = s4Hash(r'b')
    assets
}

private class S4FakeCertificationProvider <: CkbAbcdeCertificationProviderExecutor {
    public var callCount: Int64 = 0;
    public override func execute(options: CkbAbcdeRunnerOptions, group: String, groupRoot: String, workspace: String,
        runtimeHome: String, caseSrc: String): CkbAbcdeCommandResult {
        callCount += 1
        let out = CkbAbcdeCommandResult();
        out.exitCode = 0
        out
    }
}

private func s4PreparedRun(name: String): (String, CkbAbcdeRunnerOptions, String, String) {
    let fixture = ckbPreflightStoreRouteFixture();
    if (!fixture.ready) {
        return ("fixture_not_ready", CkbAbcdeRunnerOptions(), "", "")
    };
    if (runCkbCertificationPreflightCli(["cangjie-certification-preflight", "--control-manifest", fixture.controlPath],
        store: FileKnowledgeStore(fixture.frozenStorePath)) != 0) {
        return ("preflight_failed", CkbAbcdeRunnerOptions(), "", "")
    }
    let manifestPath = Path(fixture.outputRoot).join("run-manifest.json");
    let manifest = String.fromUtf8(File.readFrom(manifestPath));
    let options = CkbAbcdeRunnerOptions();
    options.runId = "store-route-run"
    options.runsRoot = Path(fixture.outputRoot).parent.toString()
    options.expectedModelVersion = "GLM-5.2"
    options.certificationRunManifestPath = manifestPath.toString()
    options.claudeBin = fixture.runtimePath
    let diagnostic = applyCkbAbcdeFrozenRunManifest(options, manifest.toArray());
    if (diagnostic != "ok") {
        return (diagnostic, options, "", manifestPath.toString())
    };
    let root = Path("../target/s4-real-${name}-${DateTime.now().toUnixTimeStamp().toMilliseconds()}");
    if (exists(root)) {
        remove(root, recursive: true)
    };
    Directory.create(root, recursive: true);
    let canonicalRoot = canonicalize(root).toString()
    let freeze = ckbAbcdeFreezeS4RunAssets(options, canonicalRoot, false);
    (freeze, options, canonicalRoot, manifestPath.toString())
}

private func s4AssetsFromRun(options: CkbAbcdeRunnerOptions): CkbS4FrozenContextAssets {
    let assets = CkbS4FrozenContextAssets();
    assets.protocol = "Use exactly one completion. Do not call tools.\n"
    assets.rules = String.fromUtf8(File.readFrom(Path(options.studentContextRoot).join("AGENTS.md")))
    assets.skill = String.fromUtf8(File.readFrom(Path(options.studentContextRoot).join("student-skills.prompt.md")))
    assets.knowledge = "{\"knowledgeVersion\":\"knowledge-v1\",\"knowledgePack\":\"中文🙂\"}"
    assets.providerCapability = String.fromUtf8(File.readFrom(Path(options.providerPromptCapabilityPath)))
    assets.publicTask = "Implement the public function."
    assets.compositeHash = options.studentContextCompositeHash
    assets.combinationAuditHash = options.combinationAuditHash
    assets
}

private func s4CapabilityEvidence(model: String, budget: Int64): String {
    "{\"schemaVersion\":\"ckb-provider-prompt-capability-v1\",\"modelVersion\":\"${model}\",\"maxContextTokens\":${budget + 1},\"reservedOutputTokens\":1,\"sourceEvidence\":\"fixture\",\"observedAtUtc\":\"2026-08-07T00:00:00Z\"}"
}

private func s4Capability(model: String, budget: Int64): String {
    let evidence = s4CapabilityEvidence(model, budget);
    evidence.replace("}", ",\"capabilityHash\":\"${benchmarkGapSha256(evidence)}\"}")
}

private func s4CompletionTranscript(): String {
    let solution = "package solution\n";
    "{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"modelUsage\":{\"GLM-5.2\":{}},\"structured_output\":{\"solution_cj\":\"${solution.replace("\n", "\\n")}\"}}"
}

private func s4TaskKnowledgeRpc(requestHash: String): String {
    let structured = "{\"resultType\":\"task_knowledge_pack\"," +
        "\"interfaceId\":\"KI-02\",\"contentFamily\":\"task_knowledge\"," +
        "\"updateMechanism\":\"first_init_or_routine_update\"," +
        "\"queryId\":\"query\",\"taskId\":\"CJ-HUMANEVAL-000\"," +
        "\"benchmark\":\"Cangjie-HumanEval\",\"knowledgeVersion\":\"v1\"," +
        "\"targetVersion\":\"1.0.0\",\"evidenceHash\":\"${s4Hash(r'a')}\"," +
        "\"degraded\":false,\"truncated\":false," +
        "\"versionResolution\":{},\"queryPlan\":[],\"requiredKnowledge\":[]," +
        "\"matchedEvidence\":[{\"knowledge\":\"中文🙂\"}]," +
        "\"examples\":[],\"negativeRules\":[]," +
        "\"citations\":[{\"citation\":\"official\"}]," +
        "\"coverage\":{\"coveragePass\":true},\"diagnostics\":[],\"notes\":[]," +
        "\"requestBinding\":{\"schemaVersion\":\"ckb-runner-bound-mcp-v1\"," +
        "\"bindingMode\":\"runner_immutable\",\"requestHash\":\"${requestHash}\"," +
        "\"effectiveRequestHash\":\"${requestHash}\"," +
        "\"modelArgumentsHash\":\"${s4Hash(r'b')}\"," +
        "\"taskId\":\"CJ-HUMANEVAL-000\"}}"
    "{\"jsonrpc\":\"2.0\",\"id\":7,\"result\":{\"content\":[]," +
        "\"structuredContent\":${structured},\"isError\":false}}"
}

private func s4RulesManifest(): String {
    "{\"runManifestHash\":\"${s4Hash(r'a')}\",\"samplingCapability\":\"provider_default_not_client_exposed\",\"skillBundleVersion\":\"s4\",\"skillBundleHash\":\"${s4Hash(r'b')}\",\"assetLineage\":\"independent\",\"rulesHash\":\"${s4Hash(r'c')}\",\"rulesTreeHash\":\"${s4Hash(r'd')}\",\"rulesCount\":1}"
}

private func s4Certification(caseId: String): CkbCertificationCaseEvidence {
    let row = CkbCertificationCaseEvidence();
    row.runId = "s4-run"
    row.caseId = caseId
    row.group = CkbAbcdeGroups.D
    row.datasetVersion = "dataset"
    row.knowledgeVersion = "knowledge"
    row.modelFingerprint = "model"
    row.expectedModelVersion = "GLM-5.2"
    row.observedModelVersion = "GLM-5.2"
    row.claudeCodeVersion = "claude"
    let h = s4Hash(r'f');
    row.providerIdentityHash = h
    row.preflightHash = h
    row.authorityCaseHash = h
    row.authorityTestsHash = h
    row.isolationEvidenceHash = h
    row.answerHash = h
    row.transcriptHash = h
    row.testHash = h
    row.configHash = h
    row.artifactHash = h
    row.attempt = 1
    row.sampleAttemptCount = 1
    row.lastAuditedTransportAttempt = 1
    row.selectedBusinessSample = 1
    row.transportAttemptCount = 1
    row.retryCount = 0
    row.unresolvedTransport = 0
    row.attemptLineageHash = h
    row.llmTurnCount = 1
    row.sandboxDeniedOutsideWorkspace = true
    row.verifierMountedAfterAnswerFreeze = true
    row.certificationPassAt1 = true
    row.completionCount = 1
    row.toolCallCount = 0
    row.executionFeedbackCount = 0
    row.answerFreezeSequence = 1
    row.firstExecutionSequence = 2
    row.baseAnswerHash = h
    row.plusAnswerHash = h
    row.basePassed = true
    row.plusPassed = true
    row
}

private func s4Hash(value: Rune): String {
    var out = "";
    for (_ in 0..64) {
        out += value.toString()
    };
    "sha256:${out}"
}
