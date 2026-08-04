package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists, rename, remove}
import std.sort.*
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CkbFrozenCandidateSealOptions {
    public var outputPath: String = ""
    public var expectedKnowledgeVersion: String = ""
    public var expectedCandidateChecksum: String = ""
    public var inputHash: String = ""
    public var configHash: String = ""
    public var modelHash: String = ""
    public var studentLeakageProofJson: String = ""
    public var studentLeakageArtifactJson: String = ""
    public var anonymousQueryArtifactJson: String = ""
    public var anonymousAtomQueryArtifactJson: String = ""
    public var restLeakageArtifactJson: String = ""
    public var mcpStdioLeakageArtifactJson: String = ""
    public var mcpHttpLeakageArtifactJson: String = ""
    public var authorityIsolationArtifactJson: String = ""
    public var atomTestArtifactJson: String = ""
    public init() {}
}

public class CkbFrozenCandidateSealReport {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var manifestJson: String = ""
    public var evidenceHash: String = ""
    public init() {}
}

public interface CkbFrozenCandidateFaultInjector { func checkpoint(): Unit }
public class NoopCkbFrozenCandidateFaultInjector <: CkbFrozenCandidateFaultInjector { public func checkpoint():Unit{} }

public func ckbBuildFrozenCandidateSeal(store: FileKnowledgeStore,
    options: CkbFrozenCandidateSealOptions,
    faultInjector!: CkbFrozenCandidateFaultInjector = NoopCkbFrozenCandidateFaultInjector()): CkbFrozenCandidateSealReport {
    let report = CkbFrozenCandidateSealReport()
    let pointer = store.loadActiveSnapshotPointer()
    if (!pointer.valid) { report.diagnostic = "active_snapshot_pointer_required"; return report }
    if (pointer.activeVersion != options.expectedKnowledgeVersion) {
        report.diagnostic = "frozen_knowledge_version_mismatch"; return report
    }
    for (hash in [options.expectedCandidateChecksum, options.inputHash, options.configHash,
        options.modelHash]) { if (!ckbFrozenCandidateHash(hash)) {
        report.diagnostic = "frozen_input_hash_required"; return report
    } }
    let snapshot = store.loadActiveSnapshot()
    if (!snapshot.valid) { report.diagnostic = "active_snapshot_invalid"; return report }
    let candidateChecksum = ckbCertifiedNormalizedRecordsChecksum(snapshot.normalizedRecords)
    if (candidateChecksum != options.expectedCandidateChecksum) {
        report.diagnostic = "frozen_candidate_checksum_mismatch"; return report
    }
    if (!options.studentLeakageProofJson.contains(
        "\"schemaVersion\":\"ckb-student-leakage-seal-v2\"")) {
        report.diagnostic = "student_leakage_proof_v2_required"; return report
    }
    let trustDiagnostic = ckbCandidateTrustSealDiagnostic(options.studentLeakageProofJson,
        snapshot.normalizedRecords, options.studentLeakageArtifactJson,
        options.anonymousQueryArtifactJson, options.authorityIsolationArtifactJson,
        options.atomTestArtifactJson, restText: options.restLeakageArtifactJson,
        mcpStdioText: options.mcpStdioLeakageArtifactJson,
        mcpHttpText: options.mcpHttpLeakageArtifactJson,
        anonymousQueryText: options.anonymousAtomQueryArtifactJson)
    if (trustDiagnostic != "ok") { report.diagnostic = "student_leakage_proof_mismatch"; return report }
    faultInjector.checkpoint()
    let verifiedPointer = store.loadActiveSnapshotPointer()
    if (ckbActiveSnapshotPointerIdentityHash(verifiedPointer) != ckbActiveSnapshotPointerIdentityHash(pointer)) {
        report.diagnostic = "frozen_active_pointer_drift"; return report
    }
    let txRoot = store.root.join("transactions").join(pointer.txId)
    if (!exists(txRoot) || !exists(txRoot.join("COMMIT"))) {
        report.diagnostic = "committed_transaction_required"; return report
    }
    let transactionHash = ckbFrozenCandidateDirectoryHash(txRoot)
    let pointerHash = ckbActiveSnapshotPointerIdentityHash(pointer)
    let body = "{\"schemaVersion\":\"ckb-frozen-candidate-v2\",\"knowledgeVersion\":\"${ckbFrozenCandidateEscape(pointer.activeVersion)}\",\"txIdHash\":\"${benchmarkGapSha256(pointer.txId)}\",\"activePointerHash\":\"${pointerHash}\",\"transactionHash\":\"${transactionHash}\",\"candidateChecksum\":\"${candidateChecksum}\",\"inputHash\":\"${options.inputHash}\",\"configHash\":\"${options.configHash}\",\"modelHash\":\"${options.modelHash}\",\"studentLeakageProofHash\":\"${benchmarkGapSha256(options.studentLeakageProofJson)}\",\"authorityIsolationArtifactHash\":\"${benchmarkGapSha256(options.authorityIsolationArtifactJson)}\",\"anonymousQueryArtifactHash\":\"${benchmarkGapSha256(options.anonymousQueryArtifactJson)}\",\"anonymousAtomQueryArtifactHash\":\"${benchmarkGapSha256(options.anonymousAtomQueryArtifactJson)}\",\"restLeakageArtifactHash\":\"${benchmarkGapSha256(options.restLeakageArtifactJson)}\",\"mcpStdioLeakageArtifactHash\":\"${benchmarkGapSha256(options.mcpStdioLeakageArtifactJson)}\",\"mcpHttpLeakageArtifactHash\":\"${benchmarkGapSha256(options.mcpHttpLeakageArtifactJson)}\",\"atomTestArtifactHash\":\"${benchmarkGapSha256(options.atomTestArtifactJson)}\""
    report.evidenceHash = benchmarkGapSha256(body + "}")
    report.manifestJson = body + ",\"evidenceHash\":\"${report.evidenceHash}\"}"
    report.ok = true; report.diagnostic = "ok"; report
}

public func ckbFrozenCandidateManifestIntegrityDiagnostic(manifestJson:String,
    expectedCandidateChecksum!:String="",expectedLeakageProofHash!:String="",
    expectedKnowledgeVersion!:String=""):String {
    try {
        let object=JsonValue.fromStr(manifestJson).asObject()
        let schema=ckbFrozenCandidateString(object,"schemaVersion")
        if(schema!="ckb-frozen-candidate-v1"&&schema!="ckb-frozen-candidate-v2"){return "frozen_candidate_manifest_invalid"}
        let body=ckbFrozenCandidateManifestBody(object)
        if(ckbFrozenCandidateString(object,"evidenceHash")!=benchmarkGapSha256(body+"}")){return "frozen_candidate_manifest_invalid"}
        if(schema=="ckb-frozen-candidate-v2"&&
            manifestJson!=body+",\"evidenceHash\":\"${benchmarkGapSha256(body+"}")}\"}"){
            return "frozen_candidate_manifest_invalid"
        }
        for(key in ["txIdHash","activePointerHash","transactionHash","candidateChecksum","inputHash","configHash","modelHash","studentLeakageProofHash","authorityIsolationArtifactHash","anonymousQueryArtifactHash","atomTestArtifactHash"]){if(!ckbFrozenCandidateHash(ckbFrozenCandidateString(object,key))){return "frozen_candidate_manifest_invalid"}}
        if(schema=="ckb-frozen-candidate-v2"){for(key in ["anonymousAtomQueryArtifactHash","restLeakageArtifactHash","mcpStdioLeakageArtifactHash","mcpHttpLeakageArtifactHash"]){if(!ckbFrozenCandidateHash(ckbFrozenCandidateString(object,key))){return "frozen_candidate_manifest_invalid"}}}
        if(expectedCandidateChecksum!=""&&ckbFrozenCandidateString(object,"candidateChecksum")!=expectedCandidateChecksum){return "frozen_candidate_checksum_mismatch"}
        if(expectedLeakageProofHash!=""&&ckbFrozenCandidateString(object,"studentLeakageProofHash")!=expectedLeakageProofHash){return "student_leakage_proof_mismatch"}
        if(expectedKnowledgeVersion!=""&&ckbFrozenCandidateString(object,"knowledgeVersion")!=expectedKnowledgeVersion){return "frozen_knowledge_version_mismatch"}
        "ok"
    }catch(_:Exception){"frozen_candidate_manifest_invalid"}
}

public func ckbFrozenCandidateManifestDiagnostic(store:FileKnowledgeStore,manifestJson:String):String{
    let integrity=ckbFrozenCandidateManifestIntegrityDiagnostic(manifestJson);if(integrity!="ok"){return integrity}
    try{let object=JsonValue.fromStr(manifestJson).asObject();let pointer=store.loadActiveSnapshotPointer();if(!pointer.valid){return "frozen_candidate_manifest_drift"};let txRoot=store.root.join("transactions").join(pointer.txId);if(ckbFrozenCandidateString(object,"knowledgeVersion")!=pointer.activeVersion||ckbFrozenCandidateString(object,"txIdHash")!=benchmarkGapSha256(pointer.txId)||ckbFrozenCandidateString(object,"activePointerHash")!=ckbActiveSnapshotPointerIdentityHash(pointer)||ckbFrozenCandidateString(object,"transactionHash")!=ckbFrozenCandidateDirectoryHash(txRoot)){return "frozen_candidate_manifest_drift"};let end=store.loadActiveSnapshotPointer();if(ckbActiveSnapshotPointerIdentityHash(end)!=ckbActiveSnapshotPointerIdentityHash(pointer)){return "frozen_candidate_manifest_drift"};"ok"}catch(_:Exception){"frozen_candidate_manifest_drift"}
}

private func ckbFrozenCandidateManifestBody(object:JsonObject):String {
    let schema=ckbFrozenCandidateString(object,"schemaVersion")
    let prefix="{\"schemaVersion\":\"${schema}\",\"knowledgeVersion\":\"${ckbFrozenCandidateEscape(ckbFrozenCandidateString(object, "knowledgeVersion"))}\",\"txIdHash\":\"${ckbFrozenCandidateString(object, "txIdHash")}\",\"activePointerHash\":\"${ckbFrozenCandidateString(object, "activePointerHash")}\",\"transactionHash\":\"${ckbFrozenCandidateString(object, "transactionHash")}\",\"candidateChecksum\":\"${ckbFrozenCandidateString(object, "candidateChecksum")}\",\"inputHash\":\"${ckbFrozenCandidateString(object, "inputHash")}\",\"configHash\":\"${ckbFrozenCandidateString(object, "configHash")}\",\"modelHash\":\"${ckbFrozenCandidateString(object, "modelHash")}\",\"studentLeakageProofHash\":\"${ckbFrozenCandidateString(object, "studentLeakageProofHash")}\",\"authorityIsolationArtifactHash\":\"${ckbFrozenCandidateString(object, "authorityIsolationArtifactHash")}\",\"anonymousQueryArtifactHash\":\"${ckbFrozenCandidateString(object, "anonymousQueryArtifactHash")}\""
    if(schema=="ckb-frozen-candidate-v1"){return prefix+",\"atomTestArtifactHash\":\"${ckbFrozenCandidateString(object,"atomTestArtifactHash")}\""}
    prefix+",\"anonymousAtomQueryArtifactHash\":\"${ckbFrozenCandidateString(object,"anonymousAtomQueryArtifactHash")}\",\"restLeakageArtifactHash\":\"${ckbFrozenCandidateString(object,"restLeakageArtifactHash")}\",\"mcpStdioLeakageArtifactHash\":\"${ckbFrozenCandidateString(object,"mcpStdioLeakageArtifactHash")}\",\"mcpHttpLeakageArtifactHash\":\"${ckbFrozenCandidateString(object,"mcpHttpLeakageArtifactHash")}\",\"atomTestArtifactHash\":\"${ckbFrozenCandidateString(object,"atomTestArtifactHash")}\""
}

public func runCkbFrozenCandidateSealCli(args: Array<String>, store: FileKnowledgeStore): Int64 {
    let parsed = ckbFrozenCandidateArgs(args)
    if (parsed[0] != "ok") { println("usage error: ${parsed[0]}"); return 2 }
    try {
        let control = JsonValue.fromStr(ckbFrozenCandidateRead(parsed[1])).asObject()
        let options = CkbFrozenCandidateSealOptions()
        options.outputPath = ckbFrozenCandidateString(control, "outputPath")
        options.expectedKnowledgeVersion = ckbFrozenCandidateString(control, "expectedKnowledgeVersion")
        options.expectedCandidateChecksum = ckbFrozenCandidateString(control, "expectedCandidateChecksum")
        options.inputHash = ckbFrozenCandidateString(control, "inputHash")
        options.configHash = ckbFrozenCandidateString(control, "configHash")
        options.modelHash = ckbFrozenCandidateString(control, "modelHash")
        options.studentLeakageProofJson = ckbFrozenCandidateRead(ckbFrozenCandidateString(control, "studentLeakageProofPath"))
        options.studentLeakageArtifactJson = ckbFrozenCandidateRead(ckbFrozenCandidateString(control, "studentLeakageArtifactPath"))
        options.anonymousQueryArtifactJson = ckbFrozenCandidateRead(ckbFrozenCandidateString(control, "anonymousQueryArtifactPath"))
        options.anonymousAtomQueryArtifactJson = ckbFrozenCandidateRead(ckbFrozenCandidateString(control, "anonymousAtomQueryArtifactPath"))
        options.restLeakageArtifactJson = ckbFrozenCandidateRead(ckbFrozenCandidateString(control, "restLeakageArtifactPath"))
        options.mcpStdioLeakageArtifactJson = ckbFrozenCandidateRead(ckbFrozenCandidateString(control, "mcpStdioLeakageArtifactPath"))
        options.mcpHttpLeakageArtifactJson = ckbFrozenCandidateRead(ckbFrozenCandidateString(control, "mcpHttpLeakageArtifactPath"))
        options.authorityIsolationArtifactJson = ckbFrozenCandidateRead(ckbFrozenCandidateString(control, "authorityIsolationArtifactPath"))
        options.atomTestArtifactJson = ckbFrozenCandidateRead(ckbFrozenCandidateString(control, "atomTestArtifactPath"))
        let report = ckbBuildFrozenCandidateSeal(store, options)
        if (!report.ok) { println("freeze blocked: ${report.diagnostic}"); return 1 }
        let tmp = "${options.outputPath}.tmp-${report.evidenceHash.replace("sha256:", "")}"
        try { File.writeTo(Path(tmp), report.manifestJson.toArray()); rename(tmp, to: options.outputPath, overwrite: true) }
        catch (e: Exception) { try { remove(tmp) } catch (_: Exception) {}; throw e }
        println(report.manifestJson); 0
    } catch (e: Exception) {
        let diagnostic = if (e.message == "invalid_response_encoding") { "invalid_response_encoding" }
            else if (e.message == "artifact_read_failed") { "artifact_read_failed" } else { "malformed_json" }
        println("freeze blocked: ${diagnostic}"); 1
    }
}

private func ckbFrozenCandidateArgs(args:Array<String>):(String,String){var command=false;var control="";var i:Int64=0;while(i<args.size){let value=args[i];if(value=="cangjie-frozen-candidate-seal"&&!command){command=true;i+=1;continue};if(value=="--store"){if(i+1>=args.size){return("missing_argument_value:--store","")};i+=2;continue};if(value!="--control-manifest"){return("unknown_argument:${value}","")};if(control!=""){return("duplicate_argument:--control-manifest","")};if(i+1>=args.size){return("missing_argument_value:--control-manifest","")};control=args[i+1];i+=2};if(!command){return("command_required","")};if(control==""){return("required_argument_missing:--control-manifest","")};("ok",control)}
private func ckbFrozenCandidateRead(path:String):String{let bytes=try{File.readFrom(Path(path))}catch(_:Exception){throw Exception("artifact_read_failed")};try{String.fromUtf8(bytes)}catch(_:Exception){throw Exception("invalid_response_encoding")}}
private func ckbFrozenCandidateString(object:JsonObject,key:String):String{object.get(key).getOrThrow().asString().getValue()}
private func ckbFrozenCandidateDirectoryHash(root:Path):String{let entries=ArrayList<String>();ckbFrozenCandidateCollect(root,"",entries);let ordered=entries.toArray();sort(ordered);let seed=StringBuilder();for(entry in ordered){seed.append("${entry.toArray().size}:${entry}")};benchmarkGapSha256(seed.toString())}
private func ckbFrozenCandidateCollect(root:Path,prefix:String,out:ArrayList<String>):Unit{for(entry in Directory.readFrom(root)){let relative=if(prefix==""){entry.name}else{"${prefix}/${entry.name}"};if(entry.isDirectory()){ckbFrozenCandidateCollect(entry.path,relative,out)}else if(entry.isRegular()){out.add("${relative}=${ckbFrozenCandidateBytesHash(File.readFrom(entry.path))}")}}}
private func ckbFrozenCandidateBytesHash(bytes:Array<UInt8>):String{let digest=SHA256();digest.write(bytes);let out=StringBuilder();for(byte in digest.finish()){out.append(ckbFrozenCandidateNibble(byte/UInt8(16)));out.append(ckbFrozenCandidateNibble(byte%UInt8(16)))};"sha256:${out.toString()}"}
private func ckbFrozenCandidateNibble(value:UInt8):String{if(value==UInt8(0)){return "0"};if(value==UInt8(1)){return "1"};if(value==UInt8(2)){return "2"};if(value==UInt8(3)){return "3"};if(value==UInt8(4)){return "4"};if(value==UInt8(5)){return "5"};if(value==UInt8(6)){return "6"};if(value==UInt8(7)){return "7"};if(value==UInt8(8)){return "8"};if(value==UInt8(9)){return "9"};if(value==UInt8(10)){return "a"};if(value==UInt8(11)){return "b"};if(value==UInt8(12)){return "c"};if(value==UInt8(13)){return "d"};if(value==UInt8(14)){return "e"};"f"}
private func ckbFrozenCandidateHash(value:String):Bool{if(!value.startsWith("sha256:")||value.toRuneArray().size!=71){return false};for(r in value.toRuneArray()[7..71]){if(!((r>=r'0'&&r<=r'9')||(r>=r'a'&&r<=r'f'))){return false}};true}
private func ckbFrozenCandidateEscape(value:String):String{value.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")}
