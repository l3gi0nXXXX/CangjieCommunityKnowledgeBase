package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.fs.{File, Path, exists}
import stdx.encoding.json.*

// File-only control plane for the P6 seal.  The manifest contains paths and
// public hashes only; credentials are neither accepted nor persisted.
public func runCkbCertificationPreflightCli(args: Array<String>): Int64 {
    let usage=ckbControlArgs(args,"cangjie-certification-preflight",["--control-manifest"])
    if(usage[0]!="ok"){println("usage error: ${usage[0]}");return 2}
    let path=usage[1];if(!exists(Path(path))){println("preflight blocked: control_manifest_missing");return 1}
    try {
        let root=JsonValue.fromStr(ckbControlRead(path)).asObject()
        let options=CkbCertificationPreflightOptions();let fp=CkbFrozenFingerprintInput()
        options.runId=ckbControlString(root,"runId");options.outputRoot=ckbControlString(root,"outputRoot");options.workspaceRoot=ckbControlString(root,"workspaceRoot");options.runtimeHomeRoot=ckbControlString(root,"runtimeHomeRoot")
        options.frozenVersion=ckbControlString(root,"frozenVersion");options.activeVersionAtStart=ckbControlActiveVersion(ckbControlRead(ckbControlString(root,"activeStatusStartPath")));options.activeVersionAtEnd=ckbControlActiveVersion(ckbControlRead(ckbControlString(root,"activeStatusEndPath")));options.modelVersion=ckbControlString(root,"modelVersion");options.claudeCodeVersion=ckbControlString(root,"claudeCodeVersion");options.certificationTransport=ckbControlString(root,"certificationTransport")
        let authority=ckbControlRead(ckbControlString(root,"authorityManifestPath"));let parsedAuthority=parseCangjieHumanEvalAuthorityManifest(authority);if(!parsedAuthority.ok||parsedAuthority.rows.size!=164){println("preflight blocked: authority_manifest_invalid");return 1};options.actualManifestHash=benchmarkGapSha256(authority);options.expectedManifestHash=ckbControlString(root,"authorityManifestHash")
        options.developmentClosureJson=ckbControlRead(ckbControlString(root,"developmentClosurePath"));options.knowledgeGateJson=ckbControlRead(ckbControlString(root,"knowledgeGatePath"));options.releaseGateJson=ckbControlRead(ckbControlString(root,"releaseGatePath"));options.filesystemProbeJson=ckbControlRead(ckbControlString(root,"filesystemProbePath"));options.providerIdentityJson=ckbControlRead(ckbControlString(root,"providerIdentityPath"));options.providerIdentityHash=benchmarkGapSha256(options.providerIdentityJson)
        options.parityRestPayload=ckbControlRead(ckbControlString(root,"parityRestPath"));options.parityStdioPayload=ckbControlRead(ckbControlString(root,"parityStdioPath"));options.parityHttpPayload=ckbControlRead(ckbControlString(root,"parityHttpPath"));options.parityEvidenceHash=benchmarkGapSha256(options.parityRestPayload)
        fp.knowledgeVersion=options.frozenVersion;fp.knowledgeContentHash=ckbControlString(root,"knowledgeContentHash");fp.datasetVersion=ckbControlString(root,"datasetVersion");fp.manifestHash=options.actualManifestHash;fp.modelVersion=options.modelVersion;fp.claudeCodeVersion=options.claudeCodeVersion;fp.promptHash=ckbControlString(root,"promptHash");fp.toolConfigHash=ckbControlString(root,"toolConfigHash");fp.providerIdentityHash=options.providerIdentityHash;fp.certificationTransport=options.certificationTransport;fp.runtimeConfigHash=ckbControlString(root,"runtimeConfigHash")
        let baselineRaw=ckbControlRead(ckbControlString(root,"baselineArmPath"));let treatmentRaw=ckbControlRead(ckbControlString(root,"treatmentArmPath"))
        for(raw in [options.developmentClosureJson,options.knowledgeGateJson,options.releaseGateJson,options.filesystemProbeJson,options.providerIdentityJson,options.parityRestPayload,options.parityStdioPayload,options.parityHttpPayload,baselineRaw,treatmentRaw]){if(ckbControlContainsSecret(raw)){println("preflight blocked: secret_artifact_forbidden");return 1}}
        let fingerprint=ckbFrozenFingerprint(fp);let baseline=ckbControlArm(baselineRaw);let treatment=ckbControlArm(treatmentRaw);options.experimentReport=runCkbContributionExperiment(baseline,treatment,frozenFingerprint:fingerprint)
        let report=runCertificationPreflight(options,fp);println(renderCertificationPreflightJson(report));return if(report.ok){0}else{1}
    } catch(_:Exception){println("preflight blocked: malformed_or_unreadable_artifact");1}
}

private func ckbControlArm(raw:String):CkbContributionArm{
    let o=JsonValue.fromStr(raw).asObject();if(ckbControlBool(o,"synthetic")){throw Exception("synthetic_arm_forbidden")};let a=CkbContributionArm();a.name=ckbControlString(o,"name");a.ckbEnabled=ckbControlBool(o,"ckbEnabled");a.workspaceId=ckbControlString(o,"workspaceId");a.sessionId=ckbControlString(o,"sessionId");a.runtimeHomeId=ckbControlString(o,"runtimeHomeId");a.datasetVersion=ckbControlString(o,"datasetVersion");a.manifestHash=ckbControlString(o,"manifestHash");a.modelVersion=ckbControlString(o,"modelVersion");a.claudeCodeVersion=ckbControlString(o,"claudeCodeVersion");a.promptHash=ckbControlString(o,"promptHash");a.toolConfigHash=ckbControlString(o,"toolConfigHash");a.temperature=ckbControlString(o,"temperature");a.toolBudget=ckbControlInt(o,"toolBudget");a.passed=ckbControlInt(o,"passed");a.total=ckbControlInt(o,"total");a.knowledgeHits=ckbControlInt(o,"knowledgeHits");a.failureClassificationHash=ckbControlString(o,"failureClassificationHash");a.resultArtifactJson=ckbControlString(o,"resultArtifactJson");a.resultArtifactHash=benchmarkGapSha256(a.resultArtifactJson);a.isolationSetJson=ckbControlString(o,"isolationSetJson");a.isolationSetHash=benchmarkGapSha256(a.isolationSetJson);a.frozenKnowledgeVersion=ckbControlString(o,"frozenKnowledgeVersion");a.frozenKnowledgeContentHash=ckbControlString(o,"frozenKnowledgeContentHash");a
}

private func ckbControlArgs(args:Array<String>,command:String,required:Array<String>):(String,String){let seen=HashSet<String>();var commandSeen=false;var value="";var i:Int64=0;while(i<args.size){let a=args[i];if(a==command&&!commandSeen){commandSeen=true;i+=1;continue};var known=false;for(k in required){if(a==k){known=true}};if(!known){return("unknown_argument:${a}","")};if(seen.contains(a)){return("duplicate_argument:${a}","")};if(i+1>=args.size||args[i+1].startsWith("--")){return("missing_argument_value:${a}","")};seen.add(a);value=args[i+1];i+=2};if(!commandSeen){return("command_required","")};for(k in required){if(!seen.contains(k)){return("required_argument_missing:${k}","")}};("ok",value)}
private func ckbControlRead(path:String):String{String.fromUtf8(File.readFrom(Path(path)))}
private func ckbControlString(o:JsonObject,k:String):String{o.get(k).getOrThrow().asString().getValue()}
private func ckbControlInt(o:JsonObject,k:String):Int64{o.get(k).getOrThrow().asInt().getValue()}
private func ckbControlBool(o:JsonObject,k:String):Bool{o.get(k).getOrThrow().asBool().getValue()}
public func ckbControlContainsSecret(raw:String):Bool{let v=raw.toAsciiLower();for(k in ["\"token\"","\"api_key\"","\"apikey\"","\"authorization\"","\"password\"","\"secret\"","bearer "]){if(v.contains(k)){return true}};false}
private func ckbControlActiveVersion(raw:String):String{try{return ckbControlString(JsonValue.fromStr(raw).asObject(),"activeKnowledgeVersion")}catch(_:Exception){};for(line in raw.split("\n")){if(line.startsWith("activeKnowledgeVersion=")){let parts=line.split("=");if(parts.size==2){return parts[1].trimAscii()}};if(line.startsWith("active=")){let parts=line.split("=");if(parts.size==2){return parts[1].trimAscii()}}};""}
