package cangjie_community_knowledge_base_test

import std.collection.*
import std.fs.{Directory, File, Path, exists, remove}
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbCertificationS4ContractTest {
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
        let assets = s4AssetsFromRun(options);
        @Expect(ckbAbcdeFreezeS4CaseAssets(groupRoot,assets,true),"ok")
        @Expect(ckbAbcdeFreezeS4CaseAssets(groupRoot,assets,false),"ok")
        let prompt = renderCkbS4CompletionPrompt(assets);
        File.writeTo(Path(groupRoot).join("prompt.final.md"), prompt.toArray());
        @Expect(prompt.contains("caseId"),false)
        @Expect(prompt.indexOf("## Student rules").getOrThrow()<prompt.indexOf("## Student skill").getOrThrow(),true)
        @Expect(prompt.indexOf("## Student skill").getOrThrow()<prompt.indexOf("## Frozen knowledge").getOrThrow(),true)
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
        File.writeTo(Path(groupRoot).join("student-rules.md"), "tampered".toArray());
        @Expect(ckbAbcdeFreezeS4CaseAssets(groupRoot,assets,false),"frozen_context_asset_hash_mismatch")
        @Expect(ckbS4FrozenContextEvidenceDiagnostic(assets,"{}"),"context_evidence_drift")
        let fake = S4FakeCertificationProvider();
        options.effectivePromptByteBudget = 1
        File.writeTo(Path(groupRoot).join("prompt.final.md"), renderCkbS4CompletionPrompt(assets).toArray());
        let blocked = ckbAbcdeRunClaudeCertification(options, CkbAbcdeGroups.D, groupRoot, "workspace", "runtime",
            "case", executor: fake);
        @Expect(blocked.exitCode,126)
        @Expect(fake.callCount,0)
        let manifest = String.fromUtf8(File.readFrom(Path(prepared[3])));
        @Expect(applyCkbAbcdeFrozenRunManifest(CkbAbcdeRunnerOptions(),manifest.replace(options.studentContextCompositeHash,s4Hash(r'e')).toArray()),"run_manifest_student_context_drift")
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
    let diagnostic = applyCkbAbcdeFrozenRunManifest(options, manifest.toArray());
    if (diagnostic != "ok") {
        return (diagnostic, options, "", manifestPath.toString())
    };
    let root = Path("../target/s4-real-${name}-${DateTime.now().toUnixTimeStamp().toMilliseconds()}");
    if (exists(root)) {
        remove(root, recursive: true)
    };
    Directory.create(root, recursive: true);
    let freeze = ckbAbcdeFreezeS4RunAssets(options, root.toString(), false);
    (freeze, options, root.toString(), manifestPath.toString())
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
