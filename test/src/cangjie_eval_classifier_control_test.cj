package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.env.getVariable
import std.fs.{Directory, File, Path, exists, remove}
import std.process.launch
import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieEvalClassifierControlTest {
    // P5-C-UT-01
    @TestCase
    public func p5IcUt01SealedIndependentEvidenceBindsSchemaModelAndProvenance(): Unit {
        let env=ckbP5ClassifierProcessEnvironment("/private/运行库🙂:/secret-value",true);@Expect(env.size,1);@Expect(env[0].name,"DYLD_LIBRARY_PATH");@Expect(env[0].value,"/private/运行库🙂:/secret-value")
        @Expect(ckbP5ClassifierDyldDiagnostic("",true),"classifier_dyld_library_path_missing");@Expect(ckbP5ClassifierDyldDiagnostic("",false),"ok");@Expect(ckbP5ClassifierProcessEnvironment("",false).size,0)
        let request=p5IcRequest("CJ-HUMANEVAL-016");let a=p5IcConfig("a","codex","GPT-5.6-Sol");let b=p5IcConfig("b","claude-code","GLM-5.2")
        let first=sealCkbP5ClassifierResponse(request,p5IcResponse("codex","GPT-5.6-Sol"),a,"/tmp/p5-a/workspace","/tmp/p5-a/home","session-a")
        let second=sealCkbP5ClassifierResponse(request,p5IcResponse("claude-code","GLM-5.2"),b,"/tmp/p5-b/workspace","/tmp/p5-b/home","session-b")
        @Expect(first.contains("\"schemaVersion\":\"ckb-p5-classifier-v1\""),true)
        @Expect(first.contains("\"observedModel\":\"GPT-5.6-Sol\""),true)
        @Expect(first.contains("\"provenanceHash\":\"sha256:"),true)
        @Expect(first.contains("positiveTestPassed"),false)
        @Expect(first.contains("negativeTestPassed"),false)
        @Expect(first.contains("boundaryTestPassed"),false)
        @Expect(ckbP5ClassifierArtifactIdentityValid(first),true)
        @Expect(ckbP5ClassifierArtifactIdentityValid(second),true)
        @Expect(first==second,false)
        @Expect(confirmKnowledgeGap(first,second).confirmed,true)
        let alternateResponse=p5IcResponse("claude-code","GLM-5.2").replace("GENERAL-STRING-API","GENERAL-STRING-API-ALTERNATE").replace("General reusable String API guidance 中文🙂","Equivalent reusable String guidance with different wording 中文🙂")
        let alternate=sealCkbP5ClassifierResponse(request,alternateResponse,b,"/tmp/p5-b-alt/workspace","/tmp/p5-b-alt/home","session-b-alt")
        @Expect(alternate.isEmpty(),false);@Expect(ckbP5ClassifierArtifactIdentityValid(alternate),true)
        @Expect(alternate.contains(ckbP5ClassifierArtifactConsensusHash(alternate)),true)
        @Expect(ckbP5ClassifierArtifactEvidenceHash(first)==ckbP5ClassifierArtifactEvidenceHash(alternate),false)
        @Expect(ckbP5ClassifierArtifactConsensusHash(first)==ckbP5ClassifierArtifactConsensusHash(alternate),false)
        @Expect(confirmKnowledgeGap(first,alternate).confirmed,true)
        let familyMismatch=sealCkbP5ClassifierResponse(request,alternateResponse.replace("standard_library","syntax"),b,"/tmp/p5-b-family/workspace","/tmp/p5-b-family/home","session-b-family")
        @Expect(confirmKnowledgeGap(first,familyMismatch).confirmed,true)
        let citationMismatch=sealCkbP5ClassifierResponse(request,alternateResponse.replace("https://docs.cangjie-lang.cn/docs/1.0.0/","https://docs.cangjie-lang.cn/docs/other/"),b,"/tmp/p5-b-citation/workspace","/tmp/p5-b-citation/home","session-b-citation")
        @Expect(confirmKnowledgeGap(first,citationMismatch).confirmed,true)
        let targetMismatch=sealCkbP5ClassifierResponse(request,alternateResponse.replace("\"targetVersion\":\"1.0.0\"","\"targetVersion\":\"1.0.1\""),b,"/tmp/p5-b-target/workspace","/tmp/p5-b-target/home","session-b-target")
        @Expect(confirmKnowledgeGap(first,targetMismatch).diagnostic,"classifier_semantic_disagreement")
        let sourceMismatchRequest=request.replace("sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        let sourceMismatch=sealCkbP5ClassifierResponse(sourceMismatchRequest,p5IcResponse("claude-code","GLM-5.2"),b,"/tmp/p5-b-source/workspace","/tmp/p5-b-source/home","session-b-source")
        @Expect(confirmKnowledgeGap(first,sourceMismatch).diagnostic,"classifier_semantic_disagreement")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,"{\"schemaVersion\":\"ckb-p5-classifier-response-v1\"}",a,"/tmp/p5-a/workspace","/tmp/p5-a/home","session-a")[1],"classifier_response_incomplete")
        let retrievalA=sealCkbP5ClassifierResponse(request,p5IcResponse("codex","GPT-5.6-Sol").replace("knowledge_gap","retrieval_failure"),a,"/tmp/p5-a2/workspace","/tmp/p5-a2/home","session-a2")
        let retrievalB=sealCkbP5ClassifierResponse(request,p5IcResponse("claude-code","GLM-5.2").replace("knowledge_gap","retrieval_failure"),b,"/tmp/p5-b2/workspace","/tmp/p5-b2/home","session-b2")
        let nonKnowledge=confirmIndependentClassifierPair(retrievalA,retrievalB)
        @Expect(nonKnowledge.confirmed,true);@Expect(nonKnowledge.category,"retrieval_failure");@Expect(routeNonKnowledgeFailure(nonKnowledge.category),"retrieval")
        @Expect(confirmKnowledgeGap(retrievalA,retrievalB).confirmed,false)
    }

    @TestCase
    public func p5IcBnd01UnicodeRestrictedRequestAndInvalidUtf8FailClosed(): Unit {
        let root=p5IcRoot("unicode");let caseRoot=p5IcSample(root,"CJ-HUMANEVAL-016","error: 编译错误🙂")
        let request=buildCkbP5ClassifierRequest(caseRoot,"CJ-HUMANEVAL-016","run-中文🙂")
        @Expect(request.contains("编译错误🙂"),true)
        @Expect(request.contains("studentSourceExcerpt"),true);@Expect(request.contains("学生源码🙂"),true);@Expect(request.contains("\"studentSourceHash\":\"sha256:"),true)
        @Expect(request.contains("canonical_solution"),false)
        @Expect(request.contains("teacher-solutions"),false)
        @Expect(request.contains("hidden_test"),false)
        File.writeTo(caseRoot.join("result-evidence.json"),[UInt8(0xff),UInt8(0xfe)])
        @Expect(buildCkbP5ClassifierRequest(caseRoot,"CJ-HUMANEVAL-016","run-中文🙂"),"missing_case_evidence")
        let unitRoot=p5IcRoot("unit-summary");let unitCase=p5IcSample(unitRoot,"CJ-HUMANEVAL-065","Exception: failure: expected 001, actual 484849 中文🙂\n at /private/user/path token=secret",failureType:"test_failure")
        let unitRequest=buildCkbP5ClassifierRequest(unitCase,"CJ-HUMANEVAL-065","run-中文🙂")
        @Expect(unitRequest.contains("expected 001, actual 484849 中文🙂"),true)
        @Expect(unitRequest.contains("/private/user/path"),false);@Expect(unitRequest.contains("token=secret"),false)
        let compilerRoot=p5IcRoot("compiler-summary");let longDetailBuilder=StringBuilder();for(_ in 0..300){longDetailBuilder.append("边界🙂")};let longDetail=longDetailBuilder.toString()
        let compilerLog="\u{001b}[31merror\u{001b}[0m: mismatched types\n  \u{001b}[36m==>\u{001b}[0m /Users/private/项目🙂/solution.cj:35:5:\n   | _____^ expected 'Float64', found 'Unit' 中文🙂 ${longDetail}\nAuthorization: secret\n/private/token=secret"
        let compilerCase=p5IcSample(compilerRoot,"CJ-HUMANEVAL-032",compilerLog)
        let compilerRequest=buildCkbP5ClassifierRequest(compilerCase,"CJ-HUMANEVAL-032","run-中文🙂")
        @Expect(compilerRequest.contains("location solution.cj:35:5:"),true)
        @Expect(compilerRequest.contains("expected 'Float64', found 'Unit' 中文🙂"),true)
        @Expect(compilerRequest.contains("/Users/private"),false);@Expect(compilerRequest.toAsciiLower().contains("authorization:"),false);@Expect(compilerRequest.contains("token=secret"),false)
        @Expect(compilerRequest.contains(longDetail),false)
        File.writeTo(compilerCase.join("test.log"),[UInt8(0xff),UInt8(0xfe)])
        let invalidLogRequest=buildCkbP5ClassifierRequest(compilerCase,"CJ-HUMANEVAL-032","run-中文🙂")
        @Expect(invalidLogRequest.startsWith("{"),true);@Expect(invalidLogRequest.contains("compilerTestSummary\":\"\""),true)
    }

    // P5-C-UT-02 / P5-C-BND-02 / P5-C-POS-02 / P5-C-NEG-02
    @TestCase
    public func p5IcSourceFactsRejectUnsupportedAbsImportPrerequisite(): Unit {
        let config=p5IcConfig("a","codex","GPT-5.6-Sol")
        let request=p5IcAbsRequest("CASE-GENERIC-UTF8-🙂","main(): Unit { let value: Float64 = -3.5; println(value.abs()) }",
            "error: undeclared identifier 'abs' 中文🙂")
        let globalAbs=p5IcResponse("codex","GPT-5.6-Sol").replace("General reusable String API guidance 中文🙂",
            "Float64 absolute value uses the global abs(value) function, not a receiver .abs() member.")
        let allowed=sealCkbP5ClassifierResponseWithDiagnostic(request,globalAbs,config,"/tmp/p5-fact-ok/workspace","/tmp/p5-fact-ok/home","session-fact-ok")
        @Expect(allowed[0].isEmpty(),false);@Expect(allowed[1],"ok")

        let unsupported=globalAbs.replace("Float64 absolute value uses the global abs(value) function, not a receiver .abs() member.",
            "Float64 requires import std.math.* before calling the global abs(value) function instead of .abs().")
        let rejected=sealCkbP5ClassifierResponseWithDiagnostic(request,unsupported,config,"/tmp/p5-fact-bad/workspace","/tmp/p5-fact-bad/home","session-fact-bad")
        @Expect(rejected[0],"");@Expect(rejected[1],"classifier_response_source_fact_unsupported")
        let unsupportedFromPackage=globalAbs.replace("Float64 absolute value uses the global abs(value) function, not a receiver .abs() member.",
            "The correct approach requires using a function from std.math, for example importing std.math.* before global abs(value).")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,unsupportedFromPackage,config,"/tmp/p5-fact-package/workspace","/tmp/p5-fact-package/home","session-fact-package")[1],"classifier_response_source_fact_unsupported")

        let evidencedRequest=p5IcAbsRequest("CASE-GENERIC-EVIDENCED","import std.math.*\nmain(): Unit { let value: Float64 = -3.5; println(value.abs()) }",
            "error: undeclared identifier 'abs' after import std.math.*")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(evidencedRequest,unsupported,config,"/tmp/p5-fact-evidenced/workspace","/tmp/p5-fact-evidenced/home","session-fact-evidenced")[1],"classifier_response_source_fact_unsupported")

        let explicitNoImport=globalAbs.replace("Float64 absolute value uses the global abs(value) function, not a receiver .abs() member.",
            "The global abs(value) function replaces receiver .abs(); std.math import is unnecessary and not required.")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,explicitNoImport,config,"/tmp/p5-fact-no-import/workspace","/tmp/p5-fact-no-import/home","session-fact-no-import")[1],"ok")

        let unrelated=p5IcAbsRequest("CASE-GENERIC-OTHER","main(): Unit { let value: Float64 = -3.5; println(value.abs()) }",
            "error: undeclared identifier 'otherApi'")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(unrelated,unsupported,config,"/tmp/p5-fact-other/workspace","/tmp/p5-fact-other/home","session-fact-other")[1],"ok")
        let nonKnowledge=unsupported.replace("\"category\":\"knowledge_gap\"","\"category\":\"compile_error\"")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,nonKnowledge,config,"/tmp/p5-fact-non/workspace","/tmp/p5-fact-non/home","session-fact-non")[1],"ok")
    }

    // CLASSIFIER-016-FACT-UT/BND/POS/NEG: request-aware String casing facts fail closed.
    @TestCase
    public func p5IcStringCasingSourceFactsMatchDocumentedReceiversAndImports(): Unit {
        let config=p5IcConfig("a","codex","GPT-5.6-Sol")
        let request=p5IcAbsRequest("CJ-HUMANEVAL-016",
            "public func solve(string: String): String { for (c in string.toLower()) { println(c) }; string }",
            "error: 'toLower' is not a member of struct 'String' 中文🙂")
        let base=p5IcResponse("codex","GPT-5.6-Sol")
        let ascii=base.replace("General reusable String API guidance 中文🙂",
            "String.toAsciiLower() returns an ASCII-only lowercase String; non-ASCII 中文🙂 is unchanged.")
        let runeAscii=base.replace("General reusable String API guidance 中文🙂",
            "Direct String iteration yields UInt8. Convert with string.runes(), then use the core Rune.toAsciiLowerCase() for ASCII-only casing.")
        let unicode=base.replace("General reusable String API guidance 中文🙂",
            "Unicode casing requires import std.unicode.* and conversion through runes(), then Rune.toLowerCase() returns a Rune.")
        let v3Importing=base.replace("General reusable String API guidance 中文🙂",
            "In Cangjie 1.0.0, direct String iteration yields UInt8 bytes. String.toAsciiLower() returns a String and performs ASCII-only casing. Rune.toAsciiLowerCase() returns a Rune and is also ASCII-only. Unicode casing requires importing std.unicode.*, after which Rune.toLowerCase() returns a Rune. String.toLower() is unavailable, and toLowerAscii is not a Cangjie API.")
        for((label,response) in [("string-ascii",ascii),("rune-ascii",runeAscii),("rune-unicode",unicode),("v3-importing",v3Importing)]){
            let result=sealCkbP5ClassifierResponseWithDiagnostic(request,response,config,"/tmp/p5-case-${label}/workspace","/tmp/p5-case-${label}/home","session-${label}")
            @Expect(result[0].isEmpty(),false);@Expect(result[1],"ok")
        }

        let oldV1=base.replace("General reusable String API guidance 中文🙂",
            "Iterate over the String's Runes, for (c in string) yielding Rune values, and convert each Rune using Rune.toLowerAscii().")
        let directRune=base.replace("General reusable String API guidance 中文🙂",
            "Direct String iteration yields Rune values; use each Rune for comparison.")
        let nonexistentString=base.replace("General reusable String API guidance 中文🙂",
            "String.toLower() is available and should be used for lowercase conversion.")
        let unicodeWithoutImport=base.replace("General reusable String API guidance 中文🙂",
            "For Unicode lowercase conversion call Rune.toLowerCase() on every Rune.")
        let wrongReceivers=base.replace("General reusable String API guidance 中文🙂",
            "Use String.toAsciiLowerCase() or Rune.toAsciiLower() for ASCII casing.")
        let importMention=base.replace("General reusable String API guidance 中文🙂",
            "Unicode casing mentions std.unicode.* and Rune.toLowerCase() returns a Rune; String.toLower() is unavailable.")
        let afterImport=base.replace("General reusable String API guidance 中文🙂",
            "After import std.unicode.*, Rune.toLowerCase() returns a Rune; String.toLower() is unavailable.")
        let falseNegativeApi=base.replace("General reusable String API guidance 中文🙂",
            "Unicode casing requires import std.unicode.* and Rune.toLowerCase() returns a Rune. toLowerAscii is not a Cangjie API, but use toLowerAscii for compatibility.")
        let commentDisguise=base.replace("General reusable String API guidance 中文🙂",
            "Unicode casing requires import std.unicode.*; // Rune.toLowerCase() returns a Rune. toLowerAscii is not a Cangjie API.")
        for((label,response) in [("old-v1",oldV1),("direct-rune",directRune),("string-tolower",nonexistentString),
            ("unicode-no-import",unicodeWithoutImport),("wrong-receivers",wrongReceivers),("import-mention",importMention),
            ("after-import",afterImport),("false-negative-api",falseNegativeApi),("comment-disguise",commentDisguise)]){
            let result=sealCkbP5ClassifierResponseWithDiagnostic(request,response,config,"/tmp/p5-case-bad-${label}/workspace","/tmp/p5-case-bad-${label}/home","session-bad-${label}")
            @Expect(result[0],"");@Expect(result[1],"classifier_response_source_fact_unsupported")
        }

        let unrelated=p5IcAbsRequest("CJ-HUMANEVAL-018",
            "public func solve(string: String): String { string }","error: unrelated member 中文🙂")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(unrelated,oldV1,config,"/tmp/p5-case-other/workspace","/tmp/p5-case-other/home","session-other")[1],"ok")
        let nonKnowledge=oldV1.replace("\"category\":\"knowledge_gap\"","\"category\":\"reasoning_failure\"")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,nonKnowledge,config,"/tmp/p5-case-non/workspace","/tmp/p5-case-non/home","session-non")[1],"ok")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,"{",config,"/tmp/p5-case-malformed/workspace","/tmp/p5-case-malformed/home","session-malformed")[1],"classifier_response_malformed")
        let leaking=ascii.replace("ASCII-only lowercase String","ASCII-only lowercase String token=secret /Users/private/秘密🙂")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,leaking,config,"/tmp/p5-case-leak/workspace","/tmp/p5-case-leak/home","session-leak")[1],"classifier_response_forbidden_content")
    }

    // CLASSIFIER-018-FACT-UT/BND/POS/NEG: plain keywords and raw identifiers have distinct legality.
    @TestCase
    public func p5IcReservedKeywordFactsRequireRawIdentifierBoundary(): Unit {
        let config=p5IcConfig("a","codex","GPT-5.6-Sol")
        let request=p5IcAbsRequest("CJ-HUMANEVAL-018",
            "public func solve(values: Array<Int64>): Int64 { var match = 0; match }",
            "error: expected identifier or pattern after 'var', found keyword 'match'\nhelp: escape the keyword `match` to use it as an identifier 中文🙂")
        let base=p5IcResponse("codex","GPT-5.6-Sol")
        let complete=base.replace("General reusable String API guidance 中文🙂",
            "Using the reserved keyword match directly as a plain variable identifier is invalid. The raw identifier `match` is legal in Cangjie; alternatively, rename it to a non-keyword identifier such as matchedCount 中文🙂.")
        let equivalent=base.replace("General reusable String API guidance 中文🙂",
            "An unescaped match cannot be used directly as an ordinary identifier because it is a keyword. The escaped identifier `match` is allowed, and renaming it to a different non-keyword variable is also valid.")
        for((label,response) in [("complete",complete),("equivalent",equivalent)]){
            let result=sealCkbP5ClassifierResponseWithDiagnostic(request,response,config,"/tmp/p5-keyword-${label}/workspace","/tmp/p5-keyword-${label}/home","session-keyword-${label}")
            @Expect(result[0].isEmpty(),false);@Expect(result[1],"ok")
        }

        let absolute=base.replace("General reusable String API guidance 中文🙂",
            "The reserved keyword match can never be used as an identifier under any circumstances; rename it to a non-keyword identifier.")
        let missingRaw=base.replace("General reusable String API guidance 中文🙂",
            "Using the reserved keyword match directly as a plain variable identifier is invalid; rename it to a non-keyword identifier.")
        let rawWithoutLegality=base.replace("General reusable String API guidance 中文🙂",
            "Using match directly as a plain identifier is invalid. Raw identifier syntax is `match`; rename to a non-keyword variable.")
        let missingPlainBoundary=base.replace("General reusable String API guidance 中文🙂",
            "The raw identifier `match` is legal, and renaming it to a non-keyword variable is valid.")
        let wordSalad=base.replace("General reusable String API guidance 中文🙂",
            "plain match keyword invalid raw identifier `match` legal rename non-keyword valid 中文🙂")
        let commentDisguise=base.replace("General reusable String API guidance 中文🙂",
            "Using the reserved keyword match directly as a plain variable identifier is invalid; rename it to a non-keyword identifier. // The raw identifier `match` is legal.")
        let contradictory=complete.replace("Using the reserved keyword match directly as a plain variable identifier is invalid.",
            "The reserved keyword match can never be used as an identifier under any circumstances.")
        for((label,response) in [("absolute",absolute),("missing-raw",missingRaw),("raw-no-legality",rawWithoutLegality),
            ("missing-plain",missingPlainBoundary),("word-salad",wordSalad),("comment-disguise",commentDisguise),("contradictory",contradictory)]){
            let result=sealCkbP5ClassifierResponseWithDiagnostic(request,response,config,"/tmp/p5-keyword-bad-${label}/workspace","/tmp/p5-keyword-bad-${label}/home","session-keyword-bad-${label}")
            @Expect(result[0],"");@Expect(result[1],"classifier_response_source_fact_unsupported")
        }

        let unrelated=p5IcAbsRequest("CJ-HUMANEVAL-018","public func solve(): Int64 { var found = 0; found }",
            "error: expected expression after '=' 中文🙂")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(unrelated,missingRaw,config,"/tmp/p5-keyword-other/workspace","/tmp/p5-keyword-other/home","session-keyword-other")[1],"ok")
        let nonKnowledge=missingRaw.replace("\"category\":\"knowledge_gap\"","\"category\":\"reasoning_failure\"")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,nonKnowledge,config,"/tmp/p5-keyword-non/workspace","/tmp/p5-keyword-non/home","session-keyword-non")[1],"ok")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,"{",config,"/tmp/p5-keyword-malformed/workspace","/tmp/p5-keyword-malformed/home","session-keyword-malformed")[1],"classifier_response_malformed")
        let leaking=complete.replace("non-keyword identifier","non-keyword identifier token=secret /Users/private/秘密🙂")
        @Expect(sealCkbP5ClassifierResponseWithDiagnostic(request,leaking,config,"/tmp/p5-keyword-leak/workspace","/tmp/p5-keyword-leak/home","session-keyword-leak")[1],"classifier_response_forbidden_content")
    }

    // P5-C-E2E-01
    @TestCase
    public func p5IcPos01TwoFakeProcessesProduceAnInjectableIndependentPair(): Unit {
        let root=p5IcRoot("positive");_=p5IcSample(root,"CJ-HUMANEVAL-016","error: String member missing 中文🙂")
        let fakeA=p5IcFake(root,"fake-a.sh","ok");let fakeB=p5IcFake(root,"fake-b.sh","ok")
        let output="${root}/classifier-output";let result=runCkbP5IndependentClassifiers(root,"run-中文🙂","C",output,p5IcExecutableConfig("a","codex","GPT-5.6-Sol",fakeA),p5IcExecutableConfig("b","claude-code","GLM-5.2",fakeB),10)
        @Expect(result.ok,true);@Expect(result.processed,1);@Expect(result.paired,1);@Expect(result.rejected,0)
        let diagnostic=String.fromUtf8(File.readFrom(Path(output).join("classifier-control-diagnostics.json")));@Expect(ckbP5ClassifierDiagnosticArtifactValid(diagnostic),true);@Expect(diagnostic.contains("\"ok\":true"),true);@Expect(diagnostic.contains("\"cases\":[]"),true);if(let Some(dyld)<-getVariable("DYLD_LIBRARY_PATH")){@Expect(diagnostic.contains(dyld),false)}
        let first=String.fromUtf8(File.readFrom(Path(output).join("pairs/a/CJ-HUMANEVAL-016.json")));let second=String.fromUtf8(File.readFrom(Path(output).join("pairs/b/CJ-HUMANEVAL-016.json")))
        @Expect(confirmKnowledgeGap(first,second).confirmed,true);@Expect(first==second,false)
    }

    @TestCase
    public func p5IcNeg01MalformedNonzeroTimeoutAndIdentityMismatchNeverProducePair(): Unit {
        for(mode in ["malformed","invalid_utf8","nonterminal","nonzero","identity"]){
            let root=p5IcRoot("negative-${mode}");_=p5IcSample(root,"CJ-HUMANEVAL-016","error: missing member")
            let output="${root}/classifier-output";let result=runCkbP5IndependentClassifiers(root,"run-中文🙂","C",output,p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcFake(root,"fake-a.sh",mode)),p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(root,"fake-b.sh","ok")),10)
            @Expect(result.ok,false);@Expect(result.paired,0);@Expect(result.rejected,1);@Expect(result.diagnostics.size,1);@Expect(result.diagnostics[0].contains(p5IcExpectedDiagnostic(mode)),true);@Expect(exists(Path(output).join("pairs/a/CJ-HUMANEVAL-016.json")),false)
            let diagnostic=String.fromUtf8(File.readFrom(Path(output).join("classifier-control-diagnostics.json")));@Expect(ckbP5ClassifierDiagnosticArtifactValid(diagnostic),true);@Expect(diagnostic.contains(p5IcExpectedDiagnostic(mode)),true);@Expect(diagnostic.contains("/tmp/"),false);@Expect(diagnostic.toAsciiLower().contains("token"),false);@Expect(exists(Path(output).join("runs/CJ-HUMANEVAL-016/a/stdout.tmp")),false);@Expect(exists(Path(output).join("runs/CJ-HUMANEVAL-016/a/stderr.tmp")),false);@Expect(exists(Path(output).join("runs/CJ-HUMANEVAL-016/a/workspace/response.json")),false)
        }
        let timeoutRoot=p5IcRoot("negative-timeout");_=p5IcSample(timeoutRoot,"CJ-HUMANEVAL-016","error: timeout")
        let timed=runCkbP5IndependentClassifiers(timeoutRoot,"run-中文🙂","C","${timeoutRoot}/classifier-output",p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcFake(timeoutRoot,"fake-a.sh","timeout")),p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(timeoutRoot,"fake-b.sh","ok")),1)
        @Expect(timed.ok,false);@Expect(timed.paired,0);@Expect(timed.rejected,1);let timedDiagnostic=String.fromUtf8(File.readFrom(Path(timeoutRoot).join("classifier-output/classifier-control-diagnostics.json")));@Expect(ckbP5ClassifierDiagnosticArtifactValid(timedDiagnostic),true);@Expect(timedDiagnostic.contains("classifier_process_timeout"),true)
    }

    // P5-C-UT-03/POS-03/NEG-03/BND-03: cross-process diagnostics are enum-only and fail closed.
    @TestCase
    public func p5IcSafeDiagnosticSidecarMapsExactEnumAndRejectsUnsafePayloads(): Unit {
        let root=p5IcRoot("safe-diagnostic");let path=Path(root).join("classifier-diagnostic.json")
        File.writeTo(path,"{\"schemaVersion\":\"cangjie-teacher-classifier-diagnostic-v1\",\"diagnostic\":\"classifier_response_source_fact_unsupported\"}\n".toArray())
        @Expect(ckbP5ReadClassifierFailureDiagnostic(path),"classifier_response_source_fact_unsupported")
        File.writeTo(path,"{\"schemaVersion\":\"wrong\",\"diagnostic\":\"classifier_timeout\"}".toArray())
        @Expect(ckbP5ReadClassifierFailureDiagnostic(path),"classifier_diagnostic_invalid")
        File.writeTo(path,"{\"schemaVersion\":\"cangjie-teacher-classifier-diagnostic-v1\",\"diagnostic\":\"unknown\"}".toArray())
        @Expect(ckbP5ReadClassifierFailureDiagnostic(path),"classifier_diagnostic_unknown")
        File.writeTo(path,"{\"schemaVersion\":\"cangjie-teacher-classifier-diagnostic-v1\",\"diagnostic\":\"classifier_timeout\",\"path\":\"/Users/private/秘密😀 token=secret\"}".toArray())
        @Expect(ckbP5ReadClassifierFailureDiagnostic(path),"classifier_diagnostic_invalid")
        File.writeTo(path,[UInt8(0xff),UInt8(0xfe)])
        @Expect(ckbP5ReadClassifierFailureDiagnostic(path),"classifier_diagnostic_invalid_encoding")
        File.writeTo(path,Array<UInt8>(513,repeat:UInt8(65)))
        @Expect(ckbP5ReadClassifierFailureDiagnostic(path),"classifier_diagnostic_too_large")
        remove(path)
        @Expect(ckbP5ReadClassifierFailureDiagnostic(path),"classifier_diagnostic_missing")

        let runRoot=p5IcRoot("safe-diagnostic-process");_=p5IcSample(runRoot,"CJ-HUMANEVAL-016","error: missing member")
        let output="${runRoot}/classifier-output";let result=runCkbP5IndependentClassifiers(runRoot,"run-中文🙂","C",output,
            p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcDiagnosticFake(runRoot,"fake-a.sh","classifier_response_source_fact_unsupported")),
            p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(runRoot,"fake-b.sh","ok")),10)
        @Expect(result.ok,false);@Expect(result.paired,0);@Expect(result.rejected,1)
        @Expect(result.diagnostics[0].contains("a=classifier_response_source_fact_unsupported"),true)
        @Expect(exists(Path(output).join("pairs/a/CJ-HUMANEVAL-016.json")),false)
        @Expect(exists(Path(output).join("runs/CJ-HUMANEVAL-016/a/workspace/classifier-diagnostic.json")),false)

        let staleRoot=p5IcRoot("safe-diagnostic-stale");_=p5IcSample(staleRoot,"CJ-HUMANEVAL-016","error: missing member")
        let staleOutput="${staleRoot}/classifier-output";let stale=runCkbP5IndependentClassifiers(staleRoot,"run-中文🙂","C",staleOutput,
            p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcStaleSuccessFake(staleRoot,"fake-a.sh")),
            p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(staleRoot,"fake-b.sh","ok")),10)
        @Expect(stale.ok,false);@Expect(stale.paired,0);@Expect(stale.rejected,1)
        @Expect(stale.diagnostics[0].contains("a=classifier_diagnostic_unexpected_on_success"),true)
        @Expect(exists(Path(staleOutput).join("runs/CJ-HUMANEVAL-016/a/workspace/classifier-diagnostic.json")),false)
    }

    @TestCase
    public func p5IcE2e01CliIsStrictAndFeedsExistingDevelopmentCloseRoots(): Unit {
        let root=p5IcRoot("e2e");_=p5IcSample(root,"CJ-HUMANEVAL-016","error: API missing")
        let output="${root}/classifier-output";let args=["cangjie-eval-classifier-run","--run-root",root,"--run-id","run-中文🙂","--transport","C","--output-root",output,"--classifier-a-executable",p5IcFake(root,"fake-a.sh","ok"),"--classifier-a-provider","codex","--classifier-a-model","GPT-5.6-Sol","--classifier-a-id","classifier-a","--classifier-b-executable",p5IcFake(root,"fake-b.sh","ok"),"--classifier-b-provider","claude-code","--classifier-b-model","GLM-5.2","--classifier-b-id","classifier-b","--timeout-seconds","10"]
        @Expect(runCangjieEvalClassifierControl(args),0)
        @Expect(exists(Path(output).join("pairs/a/CJ-HUMANEVAL-016.json")),true)
        let duplicate=ArrayList<String>();for(value in args){duplicate.add(value)};duplicate.add("--run-id");duplicate.add("duplicate")
        @Expect(runCangjieEvalClassifierControl(duplicate.toArray()),2)
        @Expect(runCangjieEvalClassifierControl(["cangjie-eval-classifier-run","--unknown","x"]),2)
        @Expect(runCangjieEvalClassifierControl(["cangjie-eval-classifier-run"]),2)
    }

    // NK-E2E-01
    @TestCase
    public func nkE2e01ControllerPersistsReasoningUnitRouteConsensusWithoutKnowledge(): Unit {
        let root=p5IcRoot("nk-route-e2e");_=p5IcSample(root,"CJ-HUMANEVAL-116","Exception: expected -4, actual -6 中文🙂",failureType:"test_failure")
        let output="${root}/classifier-output"
        let result=runCkbP5IndependentClassifiers(root,"run-中文🙂","C",output,p5IcExecutableConfig("a","codex","GPT-5.6-Sol",p5IcFake(root,"fake-a.sh","reasoning")),p5IcExecutableConfig("b","claude-code","GLM-5.2",p5IcFake(root,"fake-b.sh","unit")),10)
        @Expect(result.ok,true);@Expect(result.paired,1);@Expect(result.rejected,0)
        let first=String.fromUtf8(File.readFrom(Path(output).join("pairs/a/CJ-HUMANEVAL-116.json")));let second=String.fromUtf8(File.readFrom(Path(output).join("pairs/b/CJ-HUMANEVAL-116.json")))
        let confirmation=confirmIndependentClassifierPair(first,second)
        @Expect(confirmation.confirmed,true);@Expect(confirmation.diagnostic,"nonknowledge_route_consensus");@Expect(confirmation.route,"reasoning")
        @Expect(confirmKnowledgeGap(first,second).confirmed,false)
        let diagnostic=String.fromUtf8(File.readFrom(Path(output).join("classifier-control-diagnostics.json")))
        @Expect(ckbP5ClassifierDiagnosticArtifactValid(diagnostic),true);@Expect(diagnostic.contains("/tmp/"),false);@Expect(diagnostic.toAsciiLower().contains("token"),false)
    }
}

private func p5IcRoot(label:String):String{let root="/tmp/ckb-p5-ic-${label}-${DateTime.now().toUnixTimeStamp().toMilliseconds()}";if(exists(Path(root))){_=launch("/bin/rm",["-rf",root]).wait()};Directory.create(Path(root),recursive:true);root}
private func p5IcSample(root:String,caseId:String,log:String,failureType!:String="compile_error"):Path{
    let caseRoot=Path(root).join("cases").join(caseId).join(CkbAbcdeGroups.C);Directory.create(caseRoot,recursive:true)
    let sourceRoot=caseRoot.join("workspace/src");Directory.create(sourceRoot,recursive:true);File.writeTo(sourceRoot.join("solution.cj"),"package sample\n// 学生源码🙂\npublic func sample(s: String): Int64 { s.size }\n".toArray())
    let raw="{\"caseId\":\"${caseId}\",\"runId\":\"run-中文🙂\",\"datasetVersion\":\"dataset-v1\",\"attempt\":1,\"runMode\":\"development\",\"failureObservation\":\"missing reusable guidance 中文🙂\",\"suspectedKnowledgeGap\":true,\"failureType\":\"${failureType}\",\"unitPass\":false,\"resultEvidenceHash\":\"HASH\"}";let evidence=raw.replace("HASH",cangjieEvalTriageResultEvidenceHash(raw))
    let result="{\"caseId\":\"${caseId}\",\"runId\":\"run-中文🙂\",\"datasetVersion\":\"dataset-v1\",\"runMode\":\"development\",\"firstAttemptPass\":false,\"firstClaudeExitCode\":0,\"failureType\":\"${failureType}\",\"toolEvidenceHash\":\"sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"toolCoveragePass\":true,\"citationCount\":2}"
    File.writeTo(caseRoot.join("case-result.json"),result.toArray());File.writeTo(caseRoot.join("result-evidence.json"),evidence.toArray());File.writeTo(caseRoot.join("canonical-task-context.json"),"{\"taskText\":\"通用字符串 API 任务🙂\",\"signature\":\"public func sample(s: String): Int64\"}".toArray());File.writeTo(caseRoot.join("test.log"),log.toArray());caseRoot
}
private func p5IcRequest(caseId:String):String{let evidence="{\"caseId\":\"${caseId}\",\"runId\":\"run-001\",\"datasetVersion\":\"dataset-v1\",\"attempt\":1,\"runMode\":\"development\",\"failureObservation\":\"missing reusable guidance 中文🙂\",\"suspectedKnowledgeGap\":true,\"failureType\":\"compile_error\",\"unitPass\":false,\"resultEvidenceHash\":\"HASH\"}";let hash=cangjieEvalTriageResultEvidenceHash(evidence);"{\"schemaVersion\":\"ckb-p5-classifier-request-v1\",\"caseId\":\"${caseId}\",\"runId\":\"run-001\",\"datasetVersion\":\"dataset-v1\",\"attempt\":1,\"runMode\":\"development\",\"studentSourceExcerpt\":\"学生源码🙂\",\"studentSourceHash\":\"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"failureObservation\":\"missing reusable guidance 中文🙂\",\"resultEvidenceHash\":\"${hash}\"}"}
private func p5IcAbsRequest(caseId:String,source:String,compiler:String):String{
    p5IcRequest(caseId).replace("\"studentSourceExcerpt\":\"学生源码🙂\"","\"studentSourceExcerpt\":\"${source.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n")}\"").replace("\"resultEvidenceHash\":","\"compilerTestSummary\":\"${compiler.replace("\\","\\\\").replace("\"","\\\"")}\",\"resultEvidenceHash\":")
}
private func p5IcConfig(label:String,provider:String,model:String):CkbP5ClassifierConfig{p5IcExecutableConfig(label,provider,model,"/fake/${label}")}
private func p5IcExecutableConfig(label:String,provider:String,model:String,executable:String):CkbP5ClassifierConfig{let c=CkbP5ClassifierConfig();c.label=label;c.classifierId="classifier-${label}";c.provider=provider;c.model=model;c.executable=executable;c}
private func p5IcResponse(provider:String,model:String):String{"{\"schemaVersion\":\"ckb-p5-classifier-response-v1\",\"observedProvider\":\"${provider}\",\"observedModel\":\"${model}\",\"category\":\"knowledge_gap\",\"knowledgeFamily\":\"standard_library\",\"reusable\":true,\"sourceClass\":\"official\",\"citation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\",\"purificationPassed\":true,\"canonicalKnowledgeId\":\"GENERAL-STRING-API\",\"targetVersion\":\"1.0.0\",\"evidenceId\":\"official-string-api\",\"knowledgeText\":\"General reusable String API guidance 中文🙂\"}"}
private func p5IcExpectedDiagnostic(mode:String):String{if(mode=="malformed"){"classifier_response_malformed"}else if(mode=="invalid_utf8"){"classifier_response_invalid_encoding"}else if(mode=="nonterminal"){"classifier_response_incomplete"}else if(mode=="nonzero"){"classifier_diagnostic_missing"}else{"classifier_response_identity_mismatch"}}
private func p5IcDiagnosticFake(root:String,name:String,diagnostic:String):String{
    let path=Path(root).join(name);let body="#!/bin/zsh\nworkspace=''; while (( $# > 0 )); do case \"$1\" in --workspace) workspace=\"$2\"; shift 2;; *) shift 2;; esac; done\nprint -r -- '{\"schemaVersion\":\"cangjie-teacher-classifier-diagnostic-v1\",\"diagnostic\":\"${diagnostic}\"}' > \"$workspace/classifier-diagnostic.json\"\nexit 7\n"
    File.writeTo(path,body.toArray());_=launch("/bin/chmod",["700",path.toString()]).wait();path.toString()
}
private func p5IcStaleSuccessFake(root:String,name:String):String{
    let path=Path(root).join(name);let body="#!/bin/zsh\nworkspace=''; out=''; provider=''; model=''; while (( $# > 0 )); do case \"$1\" in --workspace) workspace=\"$2\"; shift 2;; --output) out=\"$2\"; shift 2;; --expected-provider) provider=\"$2\"; shift 2;; --expected-model) model=\"$2\"; shift 2;; *) shift 2;; esac; done\nprint -r -- '{\"schemaVersion\":\"cangjie-teacher-classifier-diagnostic-v1\",\"diagnostic\":\"classifier_timeout\"}' > \"$workspace/classifier-diagnostic.json\"\nprint -r -- \"{\\\"schemaVersion\\\":\\\"ckb-p5-classifier-response-v1\\\",\\\"observedProvider\\\":\\\"$provider\\\",\\\"observedModel\\\":\\\"$model\\\",\\\"category\\\":\\\"knowledge_gap\\\",\\\"knowledgeFamily\\\":\\\"standard_library\\\",\\\"reusable\\\":true,\\\"sourceClass\\\":\\\"official\\\",\\\"citation\\\":\\\"https://docs.cangjie-lang.cn/docs/1.0.0/\\\",\\\"purificationPassed\\\":true,\\\"canonicalKnowledgeId\\\":\\\"GENERAL-STRING-API\\\",\\\"targetVersion\\\":\\\"1.0.0\\\",\\\"evidenceId\\\":\\\"official-string-api\\\",\\\"knowledgeText\\\":\\\"General reusable String API guidance 中文🙂\\\"}\" > \"$out\"\n"
    File.writeTo(path,body.toArray());_=launch("/bin/chmod",["700",path.toString()]).wait();path.toString()
}
private func p5IcFake(root:String,name:String,mode:String):String{
    let path=Path(root).join(name);let body=if(mode=="timeout"){"#!/bin/zsh\nsleep 5\n"}else if(mode=="nonzero"){"#!/bin/zsh\nexit 7\n"}else{"#!/bin/zsh\nout=''; provider=''; model=''; while (( $# > 0 )); do case \"$1\" in --output) out=\"$2\"; shift 2;; --expected-provider) provider=\"$2\"; shift 2;; --expected-model) model=\"$2\"; shift 2;; *) shift 2;; esac; done\n"+if(mode=="malformed"){"print -r -- '{' > \"$out\"\n"}else if(mode=="invalid_utf8"){"printf '\\xff\\xfe' > \"$out\"\n"}else if(mode=="nonterminal"){"print -r -- '{\"schemaVersion\":\"ckb-p5-classifier-response-v1\"}' > \"$out\"\n"}else if(mode=="identity"){"print -r -- '{\"schemaVersion\":\"ckb-p5-classifier-response-v1\",\"observedProvider\":\"wrong\",\"observedModel\":\"wrong\",\"category\":\"knowledge_gap\"}' > \"$out\"\n"}else if(mode=="reasoning"||mode=="unit"){let category=if(mode=="reasoning"){"reasoning_failure"}else{"unit_failure"};"print -r -- \"{\\\"schemaVersion\\\":\\\"ckb-p5-classifier-response-v1\\\",\\\"observedProvider\\\":\\\"$provider\\\",\\\"observedModel\\\":\\\"$model\\\",\\\"category\\\":\\\"${category}\\\"}\" > \"$out\"\n"}else{"print -r -- \"{\\\"schemaVersion\\\":\\\"ckb-p5-classifier-response-v1\\\",\\\"observedProvider\\\":\\\"$provider\\\",\\\"observedModel\\\":\\\"$model\\\",\\\"category\\\":\\\"knowledge_gap\\\",\\\"knowledgeFamily\\\":\\\"standard_library\\\",\\\"reusable\\\":true,\\\"sourceClass\\\":\\\"official\\\",\\\"citation\\\":\\\"https://docs.cangjie-lang.cn/docs/1.0.0/\\\",\\\"purificationPassed\\\":true,\\\"canonicalKnowledgeId\\\":\\\"GENERAL-STRING-API\\\",\\\"targetVersion\\\":\\\"1.0.0\\\",\\\"evidenceId\\\":\\\"official-string-api\\\",\\\"knowledgeText\\\":\\\"General reusable String API guidance 中文🙂\\\"}\" > \"$out\"\n"}}
    File.writeTo(path,body.toArray());_=launch("/bin/chmod",["700",path.toString()]).wait();path.toString()
}
