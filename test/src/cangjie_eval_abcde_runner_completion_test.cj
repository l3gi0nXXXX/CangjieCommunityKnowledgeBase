package cangjie_community_knowledge_base_test

import std.fs.{Directory, File, Path, exists}
import std.time.DateTime
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieEvalAbcdeRunnerCompletionTest {
    // P3-UT-01
    @TestCase
    public func completionOptionsManifestAndSingleAnswerAreBound(): Unit {
        let options=parseCkbAbcdeRunnerOptions(["cangjie-eval-abcde","--generation-protocol","completion-only-v1","--samples-per-case","1","--generate-only"])
        @Expect(ckbAbcdeCompletionOptionsDiagnostic(options),"ok")
        let h="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        let manifest="{\"generationProtocol\":\"completion-only-v1\",\"samplesPerCase\":1,\"datasetVersion\":\"dataset-v1\",\"knowledgeVersion\":\"knowledge-v1\",\"modelVersion\":\"GLM-5.2\",\"providerIdentityHash\":\"${h}\",\"skillBundleHash\":\"${h}\",\"samplingCapabilityHash\":\"${h}\",\"outputSchemaHash\":\"${h}\"}"
        @Expect(applyCkbAbcdeFrozenRunManifest(options,manifest.toArray()),"ok")
        let completion=ckbAbcdeExtractSingleCompletion(p3Terminal("package solution\npublic func answer(): Int64 { 42 } // 中文😀").toArray())
        @Expect(completion.ok,true);@Expect(completion.completionCount,1);@Expect(completion.toolCallCount,0)
        @Expect(completion.answerHash.startsWith("sha256:"),true)
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

    // P3-POS-01
    @TestCase
    public func validCompletionFreezesBeforeIndependentEvaluation(): Unit {
        let root="target/p3-completion-${DateTime.now().toUnixTimeStamp().toMilliseconds()}"
        let completion=ckbAbcdeExtractSingleCompletion(p3Terminal("main() { println(\"ok 中文😀\") }").toArray())
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

    // P3-NEG-01
    @TestCase
    public func toolFallbackAndMultipleTerminalFormsAreRejected(): Unit {
        for(raw in ["{\"type\":\"assistant\",\"tool_use\":\"Bash\"}","```cangjie\\nx\\n```", p3Terminal("x")+"\n"+p3Terminal("y")]){
            @Expect(ckbAbcdeExtractSingleCompletion(raw.toArray()).ok,false)
        }
        let command=ckbAbcdeCertificationClaudeCommand("case","home","profile","claude","GLM-5.2","transcript","stderr")
        let probe=ckbAbcdeRunCompletionCapabilityProbe(command,p3Terminal("public func answer(): Int64 { 42 }").toArray(),"provider_default_not_client_exposed")
        @Expect(probe.ok,true);@Expect(command.contains("--tools ''"),true);@Expect(command.contains("--max-turns 1"),true)
        @Expect(command.contains("--output-format json"),true);@Expect(command.contains("additionalProperties"),true)
        @Expect(command.contains("output-schema.json"),false)
        @Expect(ckbAbcdeExtractSingleCompletion(p3Terminal("// bash SKILL.md mcp__ are harmless source text\nmain() {}").toArray()).ok,true)
        let assessed=ckbAbcdeAssessSample(p3Terminal("main() {}"),"GLM-5.2")
        @Expect(assessed.completeResult,true);@Expect(assessed.identityMatched,true);@Expect(assessed.toolEventCount,0)
        @Expect(command.toAsciiLower().contains("authorization"),false)
    }
}

private func p3Terminal(solution:String):String{p3TerminalFields("\"solution_cj\":\"${ckbAbcdeJsonEscape(solution)}\"")}
private func p3TerminalFields(fields:String):String{"{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"modelUsage\":{\"GLM-5.2\":{}},\"structured_output\":{${fields}}}"}
