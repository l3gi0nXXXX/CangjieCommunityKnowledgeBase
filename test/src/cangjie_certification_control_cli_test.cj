package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.fs.{Directory, File, Path}
import std.time.*

@Test
public class CangjieCertificationControlCliTest {
    @TestCase
    public func preflightRejectsDatasetVersionThatDoesNotMatchAuthority(): Unit {
        let root = Path("../target/control-authority-dataset-${DateTime.now().toUnixTimeStamp().toMilliseconds()}")
        Directory.create(root, recursive: true)
        let authority = cangjieHumanEvalRenderAuthorityManifest(
            buildCangjieHumanEvalManifest("cangjie_eval/cases/Cangjie-HumanEval", ""))
        let authorityPath = root.join("authority.jsonl")
        let activeStartPath = root.join("active-start.json")
        let activeEndPath = root.join("active-end.json")
        let controlPath = root.join("control.json")
        File.writeTo(authorityPath, authority.toArray())
        File.writeTo(activeStartPath, "{\"activeKnowledgeVersion\":\"knowledge-v1\"}".toArray())
        File.writeTo(activeEndPath, "{\"activeKnowledgeVersion\":\"knowledge-v1\"}".toArray())
        let control = "{" +
            "\"runId\":\"run-中文🙂\"," +
            "\"outputRoot\":\"${root.join("output")}\"," +
            "\"workspaceRoot\":\"${root.join("workspace")}\"," +
            "\"runtimeHomeRoot\":\"${root.join("runtime-home")}\"," +
            "\"frozenVersion\":\"knowledge-v1\"," +
            "\"activeStatusStartPath\":\"${activeStartPath}\"," +
            "\"activeStatusEndPath\":\"${activeEndPath}\"," +
            "\"modelVersion\":\"GLM-5.2\"," +
            "\"claudeCodeVersion\":\"2.1.179\"," +
            "\"certificationTransport\":\"C-ckb-mcp-stdio\"," +
            "\"authorityManifestPath\":\"${authorityPath}\"," +
            "\"datasetVersion\":\"旧版本🙂\"}"
        File.writeTo(controlPath, control.toArray())
        @Expect(runCkbCertificationPreflightCli([
            "cangjie-certification-preflight", "--control-manifest", controlPath.toString()]), 1)
    }
}
