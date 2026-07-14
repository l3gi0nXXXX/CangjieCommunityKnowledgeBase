package cangjie_community_knowledge_base_test

import std.fs.{Directory, File, Path, exists}
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieHumanEvalManifestTest {
    let datasetRoot = "cangjie_eval/cases/Cangjie-HumanEval"

    // P1-UT-01: the same read-only dataset produces byte-identical authority
    // and checksums, and task context consumes its integrity binding.
    @TestCase
    public func p1Ut01BuildIsDeterministic(): Unit {
        let first = buildCangjieHumanEvalManifest(datasetRoot, "")
        let second = buildCangjieHumanEvalManifest(datasetRoot, "")
        @Expect(first.ok, true)
        @Expect(second.ok, true)
        @Expect(first.rows.size, 164)
        @Expect(first.datasetVersion, second.datasetVersion)
        @Expect(cangjieHumanEvalRenderAuthorityManifest(first), cangjieHumanEvalRenderAuthorityManifest(second))
        @Expect(first.rows[0].promptHash.startsWith("sha256:"), true)
        @Expect(first.rows[0].testsHash.startsWith("sha256:"), true)

        let context = ckbAbcdeBuildTaskContext("${datasetRoot}/CJ-HUMANEVAL-000", "CJ-HUMANEVAL-000", cangjieHumanEvalRenderAuthorityManifest(first))
        @Expect(context.datasetVersion, first.datasetVersion)
        @Expect(context.promptHash, first.rows[0].promptHash)
        @Expect(context.starterHash, first.rows[0].starterHash)
        @Expect(context.signature, first.rows[0].signature)
    }

    // P1-BND-01: both ends of the closed 000..163 identity range survive,
    // Unicode remains intact, and invalid UTF-8 is rejected as explicit state.
    @TestCase
    public func p1Bnd01IdentityUnicodeAndInvalidUtf8Boundaries(): Unit {
        let manifest = buildCangjieHumanEvalManifest(datasetRoot, "")
        @Expect(manifest.rows[0].caseId, "CJ-HUMANEVAL-000")
        @Expect(manifest.rows[163].caseId, "CJ-HUMANEVAL-163")
        manifest.rows[0].prompt = "中文知识边界🙂"
        let visible = renderModelVisibleManifest(manifest)
        @Expect(visible.contains("中文知识边界🙂"), true)

        let unicodeRoot = "target/P1-清单🙂"
        p1ManifestReset(unicodeRoot)
        p1ManifestWriteCase(unicodeRoot, "# 中文 \\\"题目\\\" \\\\ 🙂\n", "{\"targetVersion\":\"1.0.0\",\"signature\":\"public func 中文函数🙂(): Unit\"}")
        let unicodeManifest = buildCangjieHumanEvalManifest(unicodeRoot, "")
        @Expect(unicodeManifest.rows.size, 1)
        @Expect(unicodeManifest.rows[0].prompt, "# 中文 \\\"题目\\\" \\\\ 🙂\n")
        @Expect(unicodeManifest.rows[0].signature, "public func 中文函数🙂(): Unit")
        let reparsedUnicode = parseCangjieHumanEvalAuthorityManifest(cangjieHumanEvalRenderAuthorityManifest(unicodeManifest))
        @Expect(reparsedUnicode.rows[0].prompt, unicodeManifest.rows[0].prompt)
        @Expect(reparsedUnicode.rows[0].signature, unicodeManifest.rows[0].signature)

        let root = "target/p1-manifest-invalid-utf8"
        p1ManifestReset(root)
        p1ManifestWriteCase(root, "valid", "{\"targetVersion\":\"1.0.0\",\"signature\":\"public func f(): Unit\"}")
        let caseRoot = Path(root).join("CJ-HUMANEVAL-000")
        File.writeTo(caseRoot.join("prompt.md"), [UInt8(255), UInt8(254)])
        let invalid = buildCangjieHumanEvalManifest(root, "")
        @Expect(invalid.ok, false)
        @Expect(p1ManifestHasDiagnostic(invalid, "case_read_failed:CJ-HUMANEVAL-000"), true)

        let malformedRoot = "target/p1-manifest-malformed-json"
        p1ManifestReset(malformedRoot)
        p1ManifestWriteCase(malformedRoot, "# prompt\n", "{not-json 中文🙂")
        let malformed = buildCangjieHumanEvalManifest(malformedRoot, "")
        @Expect(malformed.ok, false)
        @Expect(p1ManifestHasDiagnostic(malformed, "manifest_signature_missing:CJ-HUMANEVAL-000"), true)
    }

    // P1-POS-01: scan the checked-in 164-case corpus without changing it and
    // prove the model/verifier projections enforce their separate visibility.
    @TestCase
    public func p1Pos01RealDatasetAndSeparatedViews(): Unit {
        let manifest = buildCangjieHumanEvalManifest(datasetRoot, "")
        let validation = validateCangjieHumanEvalManifest(manifest, datasetRoot)
        let model = renderModelVisibleManifest(manifest)
        let verifier = renderVerifierManifest(manifest)
        @Expect(validation.ok, true)
        @Expect(validation.rows.size, 164)
        @Expect(model.contains("\"caseId\":\"CJ-HUMANEVAL-000\""), true)
        @Expect(model.contains("testsPath"), false)
        @Expect(model.contains("testsHash"), false)
        @Expect(model.contains("translationPath"), false)
        @Expect(model.contains("reference"), false)
        @Expect(model.contains("TestMain.cj"), false)
        @Expect(verifier.contains("\"testsHash\":\"sha256:"), true)
        @Expect(verifier.contains("\"testsPath\":\"CJ-HUMANEVAL-000/tests\""), true)
        @Expect(verifier.contains("public func has_close_elements"), false)
    }

    // P1-NEG-01: missing, duplicate, tampered and forbidden-view evidence are
    // all rejected without touching user configuration or production ckb-data.
    @TestCase
    public func p1Neg01RejectsMissingDuplicateTamperAndExposure(): Unit {
        let missing = buildCangjieHumanEvalManifest(datasetRoot, "")
        missing.rows.remove(at: 163)
        let missingValidation = validateCangjieHumanEvalManifest(missing, "")
        @Expect(missingValidation.ok, false)
        @Expect(p1ManifestHasDiagnostic(missingValidation, "manifest_case_count"), true)

        let duplicate = buildCangjieHumanEvalManifest(datasetRoot, "")
        duplicate.rows[1].caseId = duplicate.rows[0].caseId
        let duplicateValidation = validateCangjieHumanEvalManifest(duplicate, "")
        @Expect(duplicateValidation.ok, false)
        @Expect(p1ManifestHasDiagnostic(duplicateValidation, "manifest_duplicate_case_id"), true)

        let tampered = buildCangjieHumanEvalManifest(datasetRoot, "")
        tampered.rows[0].promptHash = "sha256:tampered"
        tampered.rows[0].caseHash = "sha256:tampered"
        let tamperedValidation = validateCangjieHumanEvalManifest(tampered, datasetRoot)
        @Expect(tamperedValidation.ok, false)
        @Expect(p1ManifestHasDiagnostic(tamperedValidation, "manifest_case_hash_mismatch"), true)

        let gateOptions = CangjieHumanEvalPass1GateOptions()
        let authority = cangjieHumanEvalRenderAuthorityManifest(buildCangjieHumanEvalManifest(datasetRoot, ""))
        let fakeHashAuthority = authority.replace(buildCangjieHumanEvalManifest(datasetRoot, "").rows[0].promptHash, "sha256:fake")
        let fakeHashGate = cangjieHumanEvalPass1GateFromText("", fakeHashAuthority, gateOptions, "/tmp/p1-gate", "/tmp/p1-manifest")
        @Expect(p1ManifestGateHasDiagnostic(fakeHashGate, "authority_manifest_hash_invalid:CJ-HUMANEVAL-000"), true)

        let valid = buildCangjieHumanEvalManifest(datasetRoot, "")
        let validAuthority = cangjieHumanEvalRenderAuthorityManifest(valid)
        let recomputeMismatch = validAuthority.replace(valid.rows[0].promptHash, "sha256:0000000000000000000000000000000000000000000000000000000000000000")
        let recomputeGate = cangjieHumanEvalPass1GateFromText("", recomputeMismatch, gateOptions, "/tmp/p1-gate", "/tmp/p1-manifest")
        @Expect(p1ManifestGateHasDiagnostic(recomputeGate, "authority_manifest_case_hash_invalid:CJ-HUMANEVAL-000"), true)

        let versionMismatch = validAuthority.replace(valid.datasetVersion, "cangjie-humaneval-164-sha256:0000000000000000000000000000000000000000000000000000000000000000")
        let versionGate = cangjieHumanEvalPass1GateFromText("", versionMismatch, gateOptions, "/tmp/p1-gate", "/tmp/p1-manifest")
        @Expect(p1ManifestGateHasDiagnostic(versionGate, "authority_manifest_dataset_hash_mismatch"), true)

        let visible = renderModelVisibleManifest(tampered)
        @Expect(visible.contains("tests/"), false)
        @Expect(visible.contains("translation/"), false)
        @Expect(visible.contains("canonical"), false)
        @Expect(visible.contains("solution.cj"), false)
    }

    @TestCase
    public func p1CliAtomicallyBuildsAndFailsClosed(): Unit {
        let output = "target/p1-cli/authority-清单🙂.jsonl"
        p1ManifestReset("target/p1-cli")
        @Expect(runCangjieHumanEvalManifestBuild(["cangjie-humaneval-manifest-build", "--dataset-root", datasetRoot, "--output", output]), 0)
        @Expect(parseCangjieHumanEvalAuthorityManifest(String.fromUtf8(File.readFrom(Path(output)))).rows.size, 164)
        @Expect(runCangjieHumanEvalManifestBuild(["cangjie-humaneval-manifest-build", "--dataset-root", datasetRoot, "--output", output, "--unknown"]), 2)
        @Expect(runCangjieHumanEvalManifestBuild(["cangjie-humaneval-manifest-build", "--dataset-root"]), 2)
    }
}

private func p1ManifestHasDiagnostic(result: CangjieHumanEvalManifestResult, prefix: String): Bool {
    for (diagnostic in result.diagnostics) { if (diagnostic.startsWith(prefix)) { return true } }
    false
}

private func p1ManifestGateHasDiagnostic(result: CangjieHumanEvalPass1GateResult, prefix: String): Bool {
    for (diagnostic in result.diagnostics) { if (diagnostic.startsWith(prefix)) { return true } }
    false
}

private func p1ManifestWrite(path: Path, text: String): Unit {
    if (!exists(path.parent)) { Directory.create(path.parent, recursive: true) }
    File.writeTo(path, text.toArray())
}

private func p1ManifestWriteCase(root: String, prompt: String, metadata: String): Unit {
    let caseRoot = Path(root).join("CJ-HUMANEVAL-000")
    p1ManifestWrite(caseRoot.join("prompt.md"), prompt)
    p1ManifestWrite(caseRoot.join("metadata.json"), metadata)
    p1ManifestWrite(caseRoot.join("starter/src/solution.cj"), "package fixture\npublic func f(): Unit {}\n")
    p1ManifestWrite(caseRoot.join("tests/TestMain.cj"), "main() {}\n")
    p1ManifestWrite(caseRoot.join("translation/line_translation.md"), "translation\n")
}

private func p1ManifestReset(path: String): Unit {
    if (exists(Path(path))) { _ = launch("/bin/rm", ["-rf", path]).wait() }
    Directory.create(Path(path), recursive: true)
}
