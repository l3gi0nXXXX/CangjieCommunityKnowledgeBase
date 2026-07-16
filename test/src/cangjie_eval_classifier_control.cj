public package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.convert.Parsable
import std.fs.{Directory, File, Path, exists, canonicalize}
import std.process.launch
import stdx.encoding.json.*

private let CKB_P5_CLASSIFIER_SCHEMA = "ckb-p5-classifier-v1"
private let CKB_P5_RESPONSE_SCHEMA = "ckb-p5-classifier-response-v1"
private let CKB_P5_REQUEST_SCHEMA = "ckb-p5-classifier-request-v1"

public class CkbP5ClassifierConfig {
    public var label: String = ""
    public var classifierId: String = ""
    public var provider: String = ""
    public var model: String = ""
    public var executable: String = ""
    public init() {}
}

public class CkbP5ClassifierRunResult {
    public var ok: Bool = false
    public var diagnostic: String = "not_started"
    public var processed: Int64 = 0
    public var paired: Int64 = 0
    public var rejected: Int64 = 0
    public init() {}
}

private class CkbP5ClassifierCliOptions {
    var runRoot: String = ""
    var runId: String = ""
    var transport: String = ""
    var outputRoot: String = ""
    var timeoutSeconds: Int64 = 300
    let first = CkbP5ClassifierConfig()
    let second = CkbP5ClassifierConfig()
    init() { first.label = "a"; second.label = "b" }
}

public func runCangjieEvalClassifierControl(args: Array<String>): Int64 {
    let parsed = ckbP5ParseClassifierCli(args)
    if (parsed[0] != "ok") { println("usage error: ${parsed[0]}"); return 2 }
    let options = ckbP5DecodeClassifierOptions(parsed[1])
    let result = runCkbP5IndependentClassifiers(options.runRoot, options.runId, options.transport,
        options.outputRoot, options.first, options.second, options.timeoutSeconds)
    if (!result.ok) {
        println("classifier control blocked diagnostic=${result.diagnostic} processed=${result.processed} rejected=${result.rejected}")
        return 1
    }
    println("classifier control complete processed=${result.processed} paired=${result.paired} rejected=${result.rejected}")
    0
}

// The opaque encoded value keeps the strict parser small without ever rendering
// executable arguments or environment values into diagnostics.
private func ckbP5ParseClassifierCli(args: Array<String>): (String, String) {
    let known = ["--run-root", "--run-id", "--transport", "--output-root", "--classifier-a-executable",
        "--classifier-a-provider", "--classifier-a-model", "--classifier-a-id", "--classifier-b-executable",
        "--classifier-b-provider", "--classifier-b-model", "--classifier-b-id", "--timeout-seconds"]
    let values = ArrayList<String>(); for (_ in known) { values.add("") }
    var i: Int64 = 0
    while (i < args.size) {
        if (args[i] == "cangjie-eval-classifier-run") { if (i != 0) { return ("command_must_be_first", "") }; i += 1; continue }
        var index: Int64 = -1; for (j in 0..known.size) { if (known[j] == args[i]) { index = j; break } }
        if (index < 0 || i + 1 >= args.size || args[i + 1].trimAscii() == "") { return ("unknown_or_missing_classifier_argument", "") }
        if (values[index] != "") { return ("duplicate_classifier_argument", "") }
        values[index] = args[i + 1].trimAscii(); i += 2
    }
    for (j in 0..12) { if (values[j] == "") { return ("classifier_arguments_incomplete", "") } }
    if (values[2] != "C" && values[2] != "D") { return ("classifier_transport_invalid", "") }
    let timeout = try { Int64.parse(values[12]) } catch (_: Exception) { return ("classifier_timeout_invalid", "") }
    if (timeout < 1 || timeout > 3600) { return ("classifier_timeout_invalid", "") }
    if (values[5] == values[10] || values[7] == values[11] || values[4] == values[9]) { return ("independent_classifier_configuration_required", "") }
    var encoded = ""; for (value in values) { encoded += ckbP5Part(value) }
    ("ok", encoded)
}

private func ckbP5DecodeClassifierOptions(encoded: String): CkbP5ClassifierCliOptions {
    let values = ckbP5DecodeParts(encoded); let o = CkbP5ClassifierCliOptions()
    o.runRoot=values[0];o.runId=values[1];o.transport=values[2];o.outputRoot=values[3]
    o.first.executable=values[4];o.first.provider=values[5];o.first.model=values[6];o.first.classifierId=values[7]
    o.second.executable=values[8];o.second.provider=values[9];o.second.model=values[10];o.second.classifierId=values[11]
    o.timeoutSeconds=Int64.parse(values[12]);o
}

private func ckbP5DecodeParts(encoded: String): ArrayList<String> {
    let out=ArrayList<String>();var index:Int64=0;let bytes=encoded.toArray()
    while(index<bytes.size){var colon=index;while(colon<bytes.size&&bytes[colon]!=UInt8(58)){colon+=1};let size=Int64.parse(String.fromUtf8(bytes[index..colon]));let start=colon+1;out.add(String.fromUtf8(bytes[start..start+size]));index=start+size};out
}

public func runCkbP5IndependentClassifiers(runRoot: String, runId: String, transport: String, outputRoot: String,
    first: CkbP5ClassifierConfig, second: CkbP5ClassifierConfig, timeoutSeconds: Int64): CkbP5ClassifierRunResult {
    let result = CkbP5ClassifierRunResult()
    if (!ckbP5SafeControlRoots(runRoot, outputRoot) || runId == "" || (transport != "C" && transport != "D") ||
        !ckbP5IndependentConfigs(first, second) || timeoutSeconds < 1 || timeoutSeconds > 3600) {
        result.diagnostic = "classifier_control_contract_invalid"; return result
    }
    let group = if (transport == "C") { CkbAbcdeGroups.C } else { CkbAbcdeGroups.D }
    if (!exists(Path(runRoot)) || exists(Path(outputRoot))) { result.diagnostic = "classifier_roots_invalid"; return result }
    try { Directory.create(Path(outputRoot), recursive: true) } catch (_: Exception) { result.diagnostic="classifier_output_create_failed";return result }
    for (index in 0..164) {
        let caseId=ckbP5CaseId(index);let caseRoot=Path(runRoot).join("cases").join(caseId).join(group)
        if (!exists(caseRoot.join("case-result.json")) && !exists(caseRoot.join("result-evidence.json"))) { continue }
        let caseResult=ckbP5ReadUtf8(caseRoot.join("case-result.json"))
        try { if (ckbP5Bool(JsonValue.fromStr(caseResult).asObject(),"firstAttemptPass")) { continue } } catch (_: Exception) { result.rejected+=1; continue }
        let request = buildCkbP5ClassifierRequest(caseRoot, caseId, runId)
        if (!request.startsWith("{")) { result.rejected+=1;continue }
        result.processed+=1
        let firstArtifact=ckbP5InvokeClassifier(outputRoot,caseId,request,first,timeoutSeconds)
        let secondArtifact=ckbP5InvokeClassifier(outputRoot,caseId,request,second,timeoutSeconds)
        if (firstArtifact==""||secondArtifact=="") { result.rejected+=1;continue }
        let confirmation=confirmIndependentClassifierPair(firstArtifact,secondArtifact)
        if(!confirmation.confirmed){result.rejected+=1;continue}
        let pairA=Path(outputRoot).join("pairs/a");let pairB=Path(outputRoot).join("pairs/b")
        try{if(!exists(pairA)){Directory.create(pairA,recursive:true)};if(!exists(pairB)){Directory.create(pairB,recursive:true)}}catch(_:Exception){result.diagnostic="classifier_pair_root_failed";return result}
        if(!ckbP5AtomicWrite(pairA.join("${caseId}.json"),firstArtifact+"\n")||!ckbP5AtomicWrite(pairB.join("${caseId}.json"),secondArtifact+"\n")){result.diagnostic="classifier_pair_write_failed";return result}
        result.paired+=1
    }
    result.ok=result.rejected==0;result.diagnostic=if(result.ok){"ok"}else{"classifier_cases_rejected"};result
}

public func buildCkbP5ClassifierRequest(caseRoot: Path, caseId: String, runId: String): String {
    let caseText=ckbP5ReadUtf8(caseRoot.join("case-result.json"));let evidenceText=ckbP5ReadUtf8(caseRoot.join("result-evidence.json"))
    if(caseText==""||evidenceText==""){return "missing_case_evidence"}
    try{
        let row=JsonValue.fromStr(caseText).asObject();let evidence=JsonValue.fromStr(evidenceText).asObject()
        let triage=triageEvalFailure(evidenceText)
        if(!triage.ok||ckbP5String(row,"caseId")!=caseId||ckbP5String(row,"runId")!=runId||ckbP5String(row,"runMode")!="development"||
            ckbP5String(evidence,"caseId")!=caseId||ckbP5String(evidence,"runId")!=runId||ckbP5Int(evidence,"attempt")!=1||
            ckbP5Bool(row,"firstAttemptPass")||ckbP5Int(row,"firstClaudeExitCode")!=0){return "first_complete_development_sample_required"}
        let contextText=ckbP5ReadUtf8(caseRoot.join("canonical-task-context.json"));if(contextText==""){return "task_context_missing"}
        let context=JsonValue.fromStr(contextText).asObject();let taskText=ckbP5String(context,"taskText");let signature=ckbP5String(context,"signature")
        if(taskText==""||signature==""||ckbP5Forbidden(taskText+"\n"+signature)){return "task_context_forbidden"}
        let failureType=ckbP5String(row,"failureType");let summary=ckbP5CompilerSummary(ckbP5ReadUtf8(caseRoot.join("test.log")),failureType)
        let request="{\"schemaVersion\":\"${CKB_P5_REQUEST_SCHEMA}\",\"caseId\":\"${ckbP5Escape(caseId)}\",\"runId\":\"${ckbP5Escape(runId)}\",\"datasetVersion\":\"${ckbP5Escape(ckbP5String(row,"datasetVersion"))}\",\"attempt\":1,\"runMode\":\"development\",\"taskText\":\"${ckbP5Escape(taskText)}\",\"signature\":\"${ckbP5Escape(signature)}\",\"failureObservation\":\"${ckbP5Escape(ckbP5String(evidence,"failureObservation"))}\",\"failureType\":\"${ckbP5Escape(failureType)}\",\"compilerTestSummary\":\"${ckbP5Escape(summary)}\",\"resultEvidenceHash\":\"${ckbP5Escape(ckbP5String(evidence,"resultEvidenceHash"))}\",\"retrievalDiagnostic\":\"${ckbP5Escape(ckbP5String(evidence,"retrievalDiagnostic"))}\",\"retrievalEvidenceHash\":\"${ckbP5Escape(ckbP5String(evidence,"retrievalEvidenceHash"))}\",\"toolEvidenceHash\":\"${ckbP5Escape(ckbP5String(row,"toolEvidenceHash"))}\",\"toolCoveragePass\":${ckbP5Bool(row,"toolCoveragePass")},\"citationCount\":${ckbP5Int(row,"citationCount")} }"
        if(ckbP5Forbidden(request)){"request_contains_forbidden_evidence"}else{request}
    }catch(_:Exception){"malformed_case_evidence"}
}

private func ckbP5InvokeClassifier(outputRoot:String,caseId:String,request:String,config:CkbP5ClassifierConfig,timeoutSeconds:Int64):String{
    let root=Path(outputRoot).join("runs").join(caseId).join(config.label);let workspace=root.join("workspace");let home=root.join("runtime-home")
    try{Directory.create(workspace,recursive:true);Directory.create(home,recursive:true)}catch(_:Exception){return ""}
    let requestPath=workspace.join("request.json");let responsePath=workspace.join("response.json");let stdoutPath=root.join("stdout.tmp");let stderrPath=root.join("stderr.tmp")
    if(!ckbP5AtomicWrite(requestPath,request+"\n")){return ""}
    let session="${caseId}-${config.label}-${benchmarkGapSha256(request+config.provider+config.model)}";let args=ArrayList<String>()
    for(value in ["--request",requestPath.toString(),"--output",responsePath.toString(),"--workspace",workspace.toString(),"--runtime-home",home.toString(),"--session-id",session,"--expected-provider",config.provider,"--expected-model",config.model]){args.add(value)}
    let marker=root.join("timeout.marker");let process=CkbTimedWorkerProcessLauncher(config.executable,args,workdir:workspace.toString(),cutoffAtMillis:ckbCoreNowMillis()+timeoutSeconds*1000,timeoutMarkerPath:marker.toString(),stdoutPath:stdoutPath.toString(),stderrPath:stderrPath.toString()).run()
    try{_=launch("/bin/rm",["-f",stdoutPath.toString(),stderrPath.toString()]).wait()}catch(_:Exception){}
    if(process.exitCode!=0||process.timedOut||!exists(responsePath)){return ""}
    let responseBytes=try{File.readFrom(responsePath)}catch(_:Exception){return ""};let response=try{String.fromUtf8(responseBytes)}catch(_:Exception){return ""}
    let artifact=sealCkbP5ClassifierResponse(request,response,config,workspace.toString(),home.toString(),session)
    try{_=launch("/bin/rm",["-f",responsePath.toString()]).wait()}catch(_:Exception){}
    if(artifact!=""){_=ckbP5AtomicWrite(root.join("classifier.json"),artifact+"\n")};artifact
}

public func sealCkbP5ClassifierResponse(requestText:String,responseText:String,config:CkbP5ClassifierConfig,workspace:String,runtimeHome:String,session:String):String{
    try{
        let request=JsonValue.fromStr(requestText).asObject();let response=JsonValue.fromStr(responseText).asObject()
        if(ckbP5String(request,"schemaVersion")!=CKB_P5_REQUEST_SCHEMA||ckbP5String(request,"caseId")==""||ckbP5String(request,"runId")==""||ckbP5String(request,"datasetVersion")==""||ckbP5Int(request,"attempt")!=1||ckbP5String(request,"runMode")!="development"||ckbP5String(response,"schemaVersion")!=CKB_P5_RESPONSE_SCHEMA||ckbP5String(response,"observedProvider")!=config.provider||ckbP5String(response,"observedModel")!=config.model||ckbP5Forbidden(responseText)){return ""}
        let category=ckbP5String(response,"category").toAsciiLower();if(!ckbP5ClassifierCategory(category)){return ""}
        let providerHash=benchmarkGapSha256(ckbP5Part(config.provider)+ckbP5Part(config.model)+ckbP5Part(ckbP5String(response,"observedProvider"))+ckbP5Part(ckbP5String(response,"observedModel")))
        let workspaceId=benchmarkGapSha256(try{canonicalize(Path(workspace)).toString()}catch(_:Exception){workspace});let runtimeHomeId=benchmarkGapSha256(try{canonicalize(Path(runtimeHome)).toString()}catch(_:Exception){runtimeHome});let sessionId=benchmarkGapSha256(session)
        let sourceId=benchmarkGapSha256(config.provider+"|"+config.model+"|"+config.executable+"|"+config.classifierId)
        let shared=ckbP5SharedClassifierFields(request,response,category);let consensusHash=ckbP5ClassifierConsensusHash(JsonValue.fromStr("{${shared}}").asObject())
        let provenanceHash=benchmarkGapSha256(ckbP5Part(benchmarkGapSha256(requestText))+ckbP5Part(providerHash)+ckbP5Part(workspaceId)+ckbP5Part(runtimeHomeId)+ckbP5Part(sessionId)+ckbP5Part(sourceId))
        let base="{\"schemaVersion\":\"${CKB_P5_CLASSIFIER_SCHEMA}\",\"classifierId\":\"${ckbP5Escape(config.classifierId)}\",\"sourceEvidenceId\":\"${sourceId}\",\"provider\":\"${ckbP5Escape(config.provider)}\",\"observedProvider\":\"${ckbP5Escape(ckbP5String(response,"observedProvider"))}\",\"expectedModel\":\"${ckbP5Escape(config.model)}\",\"observedModel\":\"${ckbP5Escape(ckbP5String(response,"observedModel"))}\",\"providerIdentityHash\":\"${providerHash}\",\"provenanceHash\":\"${provenanceHash}\",\"workspaceId\":\"${workspaceId}\",\"runtimeHomeId\":\"${runtimeHomeId}\",\"sessionId\":\"${sessionId}\",${shared},\"consensusHash\":\"${consensusHash}\",\"evidenceHash\":\"\"}"
        let hash=ckbP5ClassifierArtifactEvidenceHash(base);base.replace("\"evidenceHash\":\"\"","\"evidenceHash\":\"${hash}\"")
    }catch(_:Exception){""}
}

public func ckbP5ClassifierArtifactEvidenceHash(raw:String):String{try{ckbP5ClassifierArtifactHash(JsonValue.fromStr(raw).asObject())}catch(_:Exception){""}}
public func ckbP5ClassifierArtifactConsensusHash(raw:String):String{try{ckbP5ClassifierConsensusHash(JsonValue.fromStr(raw).asObject())}catch(_:Exception){""}}
public func ckbP5ClassifierArtifactIdentityValid(raw:String):Bool{try{let o=JsonValue.fromStr(raw).asObject();let provider=ckbP5String(o,"provider");let model=ckbP5String(o,"expectedModel");let expectedIdentity=benchmarkGapSha256(ckbP5Part(provider)+ckbP5Part(model)+ckbP5Part(provider)+ckbP5Part(model));ckbP5String(o,"schemaVersion")==CKB_P5_CLASSIFIER_SCHEMA&&ckbP5String(o,"classifierId")!=""&&ckbP5String(o,"sourceEvidenceId")!=""&&provider!=""&&ckbP5String(o,"observedProvider")==provider&&model!=""&&ckbP5String(o,"observedModel")==model&&ckbP5String(o,"providerIdentityHash")==expectedIdentity&&ckbP5Hash(ckbP5String(o,"provenanceHash"))&&ckbP5Hash(ckbP5String(o,"workspaceId"))&&ckbP5Hash(ckbP5String(o,"runtimeHomeId"))&&ckbP5Hash(ckbP5String(o,"sessionId"))&&ckbP5Hash(ckbP5String(o,"consensusHash"))&&ckbP5Hash(ckbP5String(o,"evidenceHash"))&&ckbP5String(o,"consensusHash")==ckbP5ClassifierConsensusHash(o)&&ckbP5String(o,"evidenceHash")==ckbP5ClassifierArtifactHash(o)}catch(_:Exception){false}}
private func ckbP5ClassifierConsensusHash(o:JsonObject):String{benchmarkGapSha256(ckbP5Part(ckbP5String(o,"category").toAsciiLower())+ckbP5Part(ckbP5String(o,"caseId"))+ckbP5Part(ckbP5String(o,"runId"))+ckbP5Part(ckbP5String(o,"datasetVersion"))+ckbP5Part("${ckbP5Int(o,"attempt")}")+ckbP5Part(ckbP5String(o,"runMode").toAsciiLower())+ckbP5Part(ckbP5String(o,"resultEvidenceHash").toAsciiLower())+ckbP5Part(ckbP5String(o,"failureObservation"))+ckbP5Part(ckbP5String(o,"knowledgeFamily").toAsciiLower())+ckbP5Part("${ckbP5Bool(o,"reusable")}")+ckbP5Part(ckbP5String(o,"sourceClass").toAsciiLower())+ckbP5Part(ckbP5String(o,"citation").toAsciiLower())+ckbP5Part("${ckbP5Bool(o,"purificationPassed")}")+ckbP5Part(ckbP5String(o,"canonicalKnowledgeId"))+ckbP5Part(ckbP5String(o,"targetVersion"))+ckbP5Part(ckbP5String(o,"evidenceId"))+ckbP5Part(ckbP5String(o,"knowledgeText"))+ckbP5Part(ckbP5String(o,"exampleText"))+ckbP5Part(ckbP5String(o,"testText"))+ckbP5Part(ckbP5String(o,"publishableMetadata")))}
private func ckbP5ClassifierArtifactHash(o:JsonObject):String{benchmarkGapSha256(ckbP5Part(ckbP5String(o,"schemaVersion"))+ckbP5Part(ckbP5String(o,"classifierId"))+ckbP5Part(ckbP5String(o,"sourceEvidenceId"))+ckbP5Part(ckbP5String(o,"provider"))+ckbP5Part(ckbP5String(o,"observedProvider"))+ckbP5Part(ckbP5String(o,"expectedModel"))+ckbP5Part(ckbP5String(o,"observedModel"))+ckbP5Part(ckbP5String(o,"providerIdentityHash"))+ckbP5Part(ckbP5String(o,"provenanceHash"))+ckbP5Part(ckbP5String(o,"workspaceId"))+ckbP5Part(ckbP5String(o,"runtimeHomeId"))+ckbP5Part(ckbP5String(o,"sessionId"))+ckbP5Part(ckbP5ClassifierConsensusHash(o))+ckbP5Part(ckbP5String(o,"consensusHash")))}
private func ckbP5Hash(v:String):Bool{let r=v.toRuneArray();if(r.size!=71||!v.startsWith("sha256:")){return false};for(i in 7..71){let c=r[i];if(!((c>=r'0'&&c<=r'9')||(c>=r'a'&&c<=r'f'))){return false}};true}

private func ckbP5SharedClassifierFields(request:JsonObject,response:JsonObject,category:String):String{
    let knowledge=category=="knowledge_gap"
    let family=if(knowledge){ckbP5String(response,"knowledgeFamily").toAsciiLower()}else{""}
    let source=if(knowledge){ckbP5String(response,"sourceClass").toAsciiLower()}else{""}
    "\"category\":\"${ckbP5Escape(category)}\",\"caseId\":\"${ckbP5Escape(ckbP5String(request,"caseId"))}\",\"runId\":\"${ckbP5Escape(ckbP5String(request,"runId"))}\",\"datasetVersion\":\"${ckbP5Escape(ckbP5String(request,"datasetVersion"))}\",\"attempt\":1,\"runMode\":\"development\",\"resultEvidenceHash\":\"${ckbP5Escape(ckbP5String(request,"resultEvidenceHash"))}\",\"failureObservation\":\"${ckbP5Escape(ckbP5String(request,"failureObservation"))}\",\"knowledgeFamily\":\"${ckbP5Escape(family)}\",\"reusable\":${knowledge&&ckbP5Bool(response,"reusable")},\"sourceClass\":\"${ckbP5Escape(source)}\",\"citation\":\"${if(knowledge){ckbP5Escape(ckbP5String(response,"citation"))}else{""}}\",\"purificationPassed\":${knowledge&&ckbP5Bool(response,"purificationPassed")},\"canonicalKnowledgeId\":\"${if(knowledge){ckbP5Escape(ckbP5String(response,"canonicalKnowledgeId"))}else{""}}\",\"targetVersion\":\"${if(knowledge){ckbP5Escape(ckbP5String(response,"targetVersion"))}else{""}}\",\"evidenceId\":\"${if(knowledge){ckbP5Escape(ckbP5String(response,"evidenceId"))}else{""}}\",\"knowledgeText\":\"${if(knowledge){ckbP5Escape(ckbP5String(response,"knowledgeText"))}else{""}}\",\"exampleText\":\"\",\"testText\":\"\",\"publishableMetadata\":\"classifier-stage-only\""
}

private func ckbP5CompilerSummary(text:String,failureType:String):String{
    if(failureType!="compile_error"){return if(failureType=="unit_failure"){"unit_test_failed_without_assertion_detail"}else{utf8SafePrefix(failureType,120)}}
    var out="";for(line in text.split("\n")){let clean=ckbP5StripAnsi(line);if(clean.toAsciiLower().contains("error")&&!clean.contains("/")){if(out!=""){out+=" | "};out+=utf8SafePrefix(clean,240);if(out.toRuneArray().size>=960){break}}};utf8SafePrefix(out,1024)
}
private func ckbP5StripAnsi(value:String):String{var out=value;for(code in ["\u{001b}[31m","\u{001b}[0m","\u{001b}[36m","\u{001b}[32m"]){out=out.replace(code,"")};out}
private func ckbP5Forbidden(value:String):Bool{let v=value.toAsciiLower();v.contains("teacher-solutions")||v.contains("canonical_solution")||v.contains("hidden_test")||v.contains("hidden-test")||v.contains("/reference/")||v.contains("authorization:")||v.contains("password")||v.contains("api_key")||v.contains("token=")}
private func ckbP5IndependentConfigs(a:CkbP5ClassifierConfig,b:CkbP5ClassifierConfig):Bool{a.classifierId!=""&&b.classifierId!=""&&a.classifierId!=b.classifierId&&a.provider=="codex"&&a.model=="GPT-5.6"&&b.provider=="claude-code"&&b.model=="GLM-5.2"&&a.executable.startsWith("/")&&b.executable.startsWith("/")&&a.executable!=b.executable}
private func ckbP5SafeControlRoots(runRoot:String,outputRoot:String):Bool{runRoot.startsWith("/")&&outputRoot.startsWith("/")&&runRoot!=outputRoot&&!outputRoot.startsWith(runRoot+"/cases/")&&!runRoot.contains("/ckb-data")&&!outputRoot.contains("/ckb-data")}
private func ckbP5ClassifierCategory(v:String):Bool{v=="knowledge_gap"||v=="retrieval_failure"||v=="reasoning_failure"||v=="compile_error"||v=="unit_failure"||v=="dataset_failure"||v=="runner_failure"||v=="environment_failure"||v=="tool_error"||v=="timeout"||v=="protocol_violation"}
private func ckbP5AtomicWrite(path:Path,text:String):Bool{try{if(!exists(path.parent)){Directory.create(path.parent,recursive:true)};let tmp=path.parent.join(".tmp-${benchmarkGapSha256(path.toString()+text).replace("sha256:","")}");File.writeTo(tmp,text.toArray());if(ckbP5ReadUtf8(tmp)!=text){_=launch("/bin/rm",["-f",tmp.toString()]).wait();return false};launch("/bin/mv",["-f",tmp.toString(),path.toString()]).wait()==0}catch(_:Exception){false}}
private func ckbP5ReadUtf8(path:Path):String{if(!exists(path)){return ""};try{String.fromUtf8(File.readFrom(path))}catch(_:Exception){""}}
private func ckbP5CaseId(i:Int64):String{if(i<10){"CJ-HUMANEVAL-00${i}"}else if(i<100){"CJ-HUMANEVAL-0${i}"}else{"CJ-HUMANEVAL-${i}"}}
private func ckbP5Part(value:String):String{"${value.toArray().size}:${value}"}
private func ckbP5String(o:JsonObject,k:String):String{match(o.get(k)){case Some(v)=>v.asString().getValue().trimAscii();case None=>""}}
private func ckbP5Bool(o:JsonObject,k:String):Bool{match(o.get(k)){case Some(v)=>v.asBool().getValue();case None=>false}}
private func ckbP5Int(o:JsonObject,k:String):Int64{match(o.get(k)){case Some(v)=>v.asInt().getValue();case None=>0}}
private func ckbP5Escape(v:String):String{v.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")}
