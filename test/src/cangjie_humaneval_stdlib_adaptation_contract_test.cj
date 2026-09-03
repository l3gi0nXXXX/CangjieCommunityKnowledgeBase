package cangjie_community_knowledge_base_test

import std.collection.*
import std.crypto.digest.digest
import std.env.getVariable
import std.fs.{Directory, File, Path, exists}
import std.math.numeric.*
import std.process.launch
import std.unittest.*
import std.unittest.testmacro.*
import stdx.crypto.digest.MD5
import stdx.encoding.hex.toHexString

private let HSA_ROOT = Path("cangjie_eval/cases/Cangjie-HumanEval")

private func hsaRead(path: Path): String {
    try { String.fromUtf8(File.readFrom(path)) } catch (_: Exception) { "" }
}

private func hsaReset(root: Path): Unit {
    if (exists(root)) { _ = launch("/bin/rm", ["-rf", root.toString()]).wait() }
    Directory.create(root.join("src"), recursive: true)
}

private func hsaRunPublicBase(caseId: String, fixtureName: String, solution: String): (Int64, String) {
    let caseRoot = HSA_ROOT.join(caseId)
    let root = Path("target/${fixtureName}")
    hsaReset(root)
    File.writeTo(root.join("cjpm.toml"), File.readFrom(caseRoot.join("starter/cjpm.toml")))
    let manifestDiagnostic = ckbAbcdeInstallSuiteManifestDependencies(
        root.toString(), caseRoot.join("tests/cjpm.executable.toml").toString())
    if (manifestDiagnostic != "ok") { return (1, manifestDiagnostic) }
    File.writeTo(root.join("src/eval_support.cj"), File.readFrom(caseRoot.join("starter/src/eval_support.cj")))
    File.writeTo(root.join("src/solution.cj"), solution.toArray())
    File.writeTo(root.join("src/test_main.cj"), File.readFrom(caseRoot.join("tests/TestMain.cj")))
    let magicRoot = match (getVariable("MAGIC_PATH")) { case Some(value) => value; case None => "" }
    let inheritedDyld = match (getVariable("DYLD_LIBRARY_PATH")) { case Some(value) => value; case None => "" }
    let dyld = "/opt/homebrew/opt/openssl@3/lib:${magicRoot}/libs/cangjie-stdx-mac-aarch64-1.0.0.1/darwin_aarch64_llvm/dynamic/stdx:${inheritedDyld}"
    let command = "export DYLD_LIBRARY_PATH='${dyld}'; cd '${root.toString()}' && cjpm clean && cjpm build -i && cjpm run > run.log 2>&1"
    let exitCode = launch("/bin/zsh", ["-c", command]).wait()
    (exitCode, hsaRead(root.join("run.log")))
}

private func hsaFloorDiv(left: BigInt, right: BigInt): BigInt {
    var quotient = left / right
    let remainder = left % right
    if (remainder != BigInt(0) && ((left < BigInt(0)) != (right < BigInt(0)))) {
        quotient -= BigInt(1)
    }
    quotient
}

private let HSA160_SOLUTION = """
package cangjie_humaneval_160
import std.collection.*
import std.math.numeric.*
public func do_algebra(operatorValue: ArrayList<String>, operand: ArrayList<Int64>): Int64 {
    let values = ArrayList<BigInt>(); let operators = ArrayList<String>()
    for (value in operand) { values.add(BigInt(value)) }
    for (op in operatorValue) { operators.add(op) }
    var index = operators.size - 1
    while (index >= 0) {
        if (operators[index] == "**") {
            values[index] = hsa160Pow(values[index], values[index + 1])
            values.remove(at: index + 1); operators.remove(at: index)
        }
        index -= 1
    }
    index = 0
    while (index < operators.size) {
        if (operators[index] == "*") { values[index] *= values[index + 1] }
        else if (operators[index] == "//") { values[index] = hsa160FloorDiv(values[index], values[index + 1]) }
        else { index += 1; continue }
        values.remove(at: index + 1); operators.remove(at: index)
    }
    index = 0
    while (index < operators.size) {
        if (operators[index] == "+") { values[index] += values[index + 1] }
        else { values[index] -= values[index + 1] }
        values.remove(at: index + 1); operators.remove(at: index)
    }
    values[0].toInt64()
}
func hsa160FloorDiv(left: BigInt, right: BigInt): BigInt {
    var quotient = left / right; let remainder = left % right
    if (remainder != BigInt(0) && ((left < BigInt(0)) != (right < BigInt(0)))) { quotient -= BigInt(1) }
    quotient
}
func hsa160Pow(baseValue: BigInt, exponentValue: BigInt): BigInt {
    let zero = BigInt(0); let two = BigInt(2)
    if (exponentValue < zero) { throw Exception("negative exponent") }
    var base = baseValue; var exponent = exponentValue; var result = BigInt(1)
    while (exponent > zero) {
        if (exponent % two != zero) { result *= base }
        exponent /= two
        if (exponent > zero) { base *= base }
    }
    result
}
"""

private let HSA162_SOLUTION = """
package cangjie_humaneval_162
import std.crypto.digest.digest
import stdx.crypto.digest.MD5
import stdx.encoding.hex.toHexString
public func string_to_md5(text: String): Option<String> {
    if (text.isEmpty()) { return None<String> }
    Some<String>(toHexString(digest(MD5(), text.toArray())))
}
"""

@Test
public class CangjieHumanEvalStdlibAdaptationContractTest {
    // SA160-UT-01
    @TestCase
    public func sa160Ut01BigIntPublicOperatorsAndFinalNarrowing(): Unit {
        let value = (BigInt(7) + BigInt(5)) * BigInt(3) - BigInt(6)
        @Expect(value.toInt64(), 30)
        @Expect((BigInt(2) ** UInt64(10)).toInt64(), 1024)
    }

    // SA160-POS-01
    @TestCase
    public func sa160Pos01BigIntEvaluatorPassesPublicBase(): Unit {
        let result = hsaRunPublicBase("CJ-HUMANEVAL-160", "hsa-sa160-public-base", HSA160_SOLUTION)
        @Expect(result[0], 0)
        @Expect(result[1].contains("CJ-HUMANEVAL-160 ok"), true)
    }

    // SA160-NEG-01
    @TestCase
    public func sa160Neg01FloorCorrectionDiffersFromTruncation(): Unit {
        @Expect((BigInt(-7) / BigInt(2)).toInt64(), -3)
        @Expect(hsaFloorDiv(BigInt(-7), BigInt(2)).toInt64(), -4)
        @Expect(hsaFloorDiv(BigInt(7), BigInt(-2)).toInt64(), -4)
        @Expect(hsaFloorDiv(BigInt(-7), BigInt(-2)).toInt64(), 3)
    }

    // SA160-BND-01
    @TestCase
    public func sa160Bnd01WideIntermediateNarrowsOnlyAfterCancellation(): Unit {
        let wide = BigInt(3037000500) * BigInt(3037000500)
        @Expect((wide - BigInt.parse("9223372037000250000")).toInt64(), 0)
    }

    // SA162-UT-01 / SA162-BND-01
    @TestCase
    public func sa162UtBnd01OfficialDigestCompositionCoversUtf8AndBlockBoundary(): Unit {
        @Expect(toHexString(digest(MD5(), "Hello world".toArray())), "3e25960a79dbc69b674cd4ec67a72c62")
        @Expect(toHexString(digest(MD5(), "".toArray())), "d41d8cd98f00b204e9800998ecf8427e")
        @Expect(toHexString(digest(MD5(), "中文🙂".toArray())), "138a2c2516fcf4f9555f4bc54c3a0ae9")
        @Expect(toHexString(digest(MD5(), "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".toArray())), "c743a45e0d2e6a95cb859adae0248435")
    }

    // SA162-POS-01
    @TestCase
    public func sa162Pos01OfficialDigestImplementationPassesPublicBase(): Unit {
        let result = hsaRunPublicBase("CJ-HUMANEVAL-162", "hsa-sa162-public-base", HSA162_SOLUTION)
        @Expect(result[0], 0)
        @Expect(result[1].contains("CJ-HUMANEVAL-162 ok"), true)
    }

    // SA162-NEG-01
    @TestCase
    public func sa162Neg01MissingStdxDependencyFailsClosed(): Unit {
        let root = Path("target/hsa-sa162-no-stdx")
        hsaReset(root)
        File.writeTo(root.join("cjpm.toml"), """
[package]
  cjc-version = "1.0.0"
  name = "hsa_sa162_no_stdx"
  version = "0.1.0"
  output-type = "executable"
  src-dir = "src"
""".toArray())
        File.writeTo(root.join("src/main.cj"), """
package hsa_sa162_no_stdx
import stdx.crypto.digest.MD5
main() { let _ = MD5() }
""".toArray())
        let exitCode = launch("/bin/zsh", ["-lc", "cd '${root.toString()}' && cjpm clean && cjpm build -i > build.log 2>&1"]).wait()
        @Expect(exitCode != 0, true)
        @Expect(hsaRead(root.join("build.log")).contains("stdx.crypto.digest"), true)
    }

    // SA160-HIST-01 / SA162-HIST-01
    @TestCase
    public func sa160Sa162Hist01AuthorityAndStartersRemainAnswerFree(): Unit {
        let manifest = buildCangjieHumanEvalManifest(HSA_ROOT.toString(), "")
        @Expect(manifest.ok, true)
        @Expect(manifest.rows.size, 164)
        @Expect(manifest.rows[160].expectedKnowledgeTags.contains("BigInt"), true)
        @Expect(manifest.rows[162].expectedKnowledgeTags.contains("MD5"), true)
        @Expect(manifest.rows[162].expectedKnowledgeTags.contains("digest"), true)
        @Expect(manifest.rows[162].expectedKnowledgeTags.contains("toHexString"), true)
        let starter160 = hsaRead(HSA_ROOT.join("CJ-HUMANEVAL-160/starter/src/solution.cj"))
        let starter162 = hsaRead(HSA_ROOT.join("CJ-HUMANEVAL-162/starter/src/solution.cj"))
        @Expect(starter160.contains("return 0"), true)
        @Expect(starter160.contains("3037000500"), false)
        @Expect(starter162.contains("return None<String>"), true)
        @Expect(starter162.contains("3e25960a79dbc69b674cd4ec67a72c62"), false)
    }

    // Runner public-signature and exact-tag contract for SA-1/SA-2.
    @TestCase
    public func saRunnerPublicSignatureAndExactTags(): Unit {
        let context160 = ckbAbcdeBuildTaskContext(HSA_ROOT.join("CJ-HUMANEVAL-160").toString(), "CJ-HUMANEVAL-160")
        @Expect(context160.signature, "public func do_algebra(operatorValue: ArrayList<String>, operand: ArrayList<Int64>): Int64")
        @Expect(context160.expectedKnowledgeTags.contains("BigInt"), true)
        let context162 = ckbAbcdeBuildTaskContext(HSA_ROOT.join("CJ-HUMANEVAL-162").toString(), "CJ-HUMANEVAL-162")
        @Expect(context162.signature, "public func string_to_md5(text: String): Option<String>")
        @Expect(context162.expectedKnowledgeTags.contains("MD5"), true)
        @Expect(context162.expectedKnowledgeTags.contains("digest"), true)
        @Expect(context162.expectedKnowledgeTags.contains("toHexString"), true)
    }

    // Exact tags must become independent required retrieval lookups; generic numeric is insufficient.
    @TestCase
    public func saRetrievalPlansIndependentStdlibLookups(): Unit {
        let resolution = CangjieVersionResolution()
        resolution.ok = true; resolution.versionResolutionId = "stdlib-adaptation-test"
        let request = CangjieTaskKnowledgeRequest()
        request.taskText = "Use public standard-library equivalents."
        for (tag in ["BigInt", "MD5", "digest", "toHexString"]) { request.expectedKnowledgeTags.add(tag) }
        let plan = buildCangjieTaskQueryPlan(request, resolution)
        for (requiredTag in request.expectedKnowledgeTags) {
            var found = false
            for (item in plan) {
                if (item.queryKind == "required_knowledge_lookup" && item.requiredTag == requiredTag && item.query == requiredTag) {
                    found = true
                }
            }
            @Expect(found, true)
        }
        let generic = CangjieTaskKnowledgeRequest()
        generic.taskText = request.taskText; generic.expectedKnowledgeTags.add("numeric")
        let genericPlan = buildCangjieTaskQueryPlan(generic, resolution)
        for (item in genericPlan) { @Expect(item.requiredTag == "BigInt", false) }
    }

    // SA162-DEP-01: the same safe merge path applies to every suite manifest,
    // including a synthetic plus-named path, without inspecting verifier content.
    @TestCase
    public func sa162Dep01SuiteManifestDependencyPropagationFailsClosed(): Unit {
        let starter = hsaRead(HSA_ROOT.join("CJ-HUMANEVAL-162/starter/cjpm.toml"))
        let suite = """
[package]
  cjc-version = "1.0.0"
  name = "公开验证🙂"
  version = "0.1.0"
  output-type = "executable"
  src-dir = "src"
"""
        let merged = ckbAbcdeMergeSuiteManifestDependencies(starter.toArray(), suite.toArray())
        @Expect(merged.ok, true); @Expect(merged.diagnostic, "ok")
        @Expect(merged.manifest.contains("name = \"公开验证🙂\""), true)
        @Expect(merged.manifest.contains("[target.aarch64-apple-darwin.bin-dependencies]"), true)
        @Expect(merged.manifest.contains("\${MAGIC_PATH}/libs/"), true)

        let noDependency = ckbAbcdeMergeSuiteManifestDependencies("[package]\nname = \"history\"\n".toArray(), suite.toArray())
        @Expect(noDependency.ok, true); @Expect(noDependency.manifest.contains("bin-dependencies"), false)
        @Expect(ckbAbcdeMergeSuiteManifestDependencies([UInt8(255)], suite.toArray()).diagnostic, "starter_manifest_invalid_encoding")
        @Expect(ckbAbcdeMergeSuiteManifestDependencies(starter.toArray(), [UInt8(255)]).diagnostic, "suite_manifest_invalid_encoding")
        let duplicate = "[target.aarch64-apple-darwin.bin-dependencies]\npath-option = [\"\${MAGIC_PATH}/libs/a\"]\n[target.aarch64-apple-darwin.bin-dependencies]\npath-option = [\"\${MAGIC_PATH}/libs/b\"]\n"
        @Expect(ckbAbcdeMergeSuiteManifestDependencies(duplicate.toArray(), suite.toArray()).diagnostic, "starter_manifest_section_duplicate")
        let malicious = "[target.aarch64-apple-darwin.bin-dependencies]\npath-option = [\"/Users/private/stdx\"]\n"
        @Expect(ckbAbcdeMergeSuiteManifestDependencies(malicious.toArray(), suite.toArray()).diagnostic, "starter_manifest_dependency_path_forbidden")
        let conflict = suite + "\n[target.aarch64-apple-darwin.bin-dependencies]\npath-option = [\"\${MAGIC_PATH}/libs/conflict\"]\n"
        @Expect(ckbAbcdeMergeSuiteManifestDependencies(starter.toArray(), conflict.toArray()).diagnostic, "suite_manifest_dependency_conflict")

        let root = Path("target/hsa-suite-manifest-plus-propagation")
        hsaReset(root); File.writeTo(root.join("cjpm.toml"), starter.toArray())
        let syntheticPlus = root.join("plus-cjpm.executable.toml"); File.writeTo(syntheticPlus, suite.toArray())
        @Expect(ckbAbcdeInstallSuiteManifestDependencies(root.toString(), syntheticPlus.toString()), "ok")
        let installed = hsaRead(root.join("cjpm.toml"))
        @Expect(installed.contains("name = \"公开验证🙂\""), true)
        @Expect(installed.contains("[target.aarch64-apple-darwin.bin-dependencies]"), true)
    }

    // SA162-RUNNER-BND-01: external manifests are byte-bounded and only one
    // exact, safe path-option string may cross into an evaluator workspace.
    @TestCase
    public func sa162RunnerBnd01ManifestGrammarAndByteCapsFailClosed(): Unit {
        let suite = "[package]\nname = \"验证中文🙂\"\n"
        let header = "[target.aarch64-apple-darwin.bin-dependencies]\n"
        let good = "path-option = [\"\${MAGIC_PATH}/libs/stdx-safe/dynamic/stdx\"]\n"
        let extraKey = header + good + "other = \"forbidden\"\n"
        @Expect(ckbAbcdeMergeSuiteManifestDependencies(extraKey.toArray(), suite.toArray()).diagnostic,
            "starter_manifest_dependency_key_forbidden")
        let fakeKey = header + "path-option-extra = [\"\${MAGIC_PATH}/libs/stdx-safe\"]\n"
        @Expect(ckbAbcdeMergeSuiteManifestDependencies(fakeKey.toArray(), suite.toArray()).diagnostic,
            "starter_manifest_dependency_key_forbidden")
        let mixed = header + "path-option = [\"\${MAGIC_PATH}/libs/stdx-safe\", \"/tmp/evil\"]\n"
        @Expect(ckbAbcdeMergeSuiteManifestDependencies(mixed.toArray(), suite.toArray()).diagnostic,
            "starter_manifest_dependency_path_forbidden")
        let escaped = header + "path-option = [\"\${MAGIC_PATH}/libs/stdx\\evil\"]\n"
        @Expect(ckbAbcdeMergeSuiteManifestDependencies(escaped.toArray(), suite.toArray()).diagnostic,
            "starter_manifest_dependency_path_forbidden")
        let pathHeader = "[target.aarch64/evil.bin-dependencies]\n" + good
        @Expect(ckbAbcdeMergeSuiteManifestDependencies(pathHeader.toArray(), suite.toArray()).diagnostic,
            "starter_manifest_dependency_target_invalid")
        let emptyHeader = "[target..bin-dependencies]\n" + good
        @Expect(ckbAbcdeMergeSuiteManifestDependencies(emptyHeader.toArray(), suite.toArray()).diagnostic,
            "starter_manifest_dependency_target_invalid")
        let control = header + "path-option = [\"\${MAGIC_PATH}/libs/stdx\u{0001}evil\"]\n"
        @Expect(ckbAbcdeMergeSuiteManifestDependencies(control.toArray(), suite.toArray()).diagnostic,
            "suite_manifest_control_forbidden")
        let nul = header + "path-option = [\"\${MAGIC_PATH}/libs/stdx\u{0000}evil\"]\n"
        @Expect(ckbAbcdeMergeSuiteManifestDependencies(nul.toArray(), suite.toArray()).diagnostic,
            "suite_manifest_nul_forbidden")

        var oversizedStarter = header + good + "#中文🙂"
        while (oversizedStarter.toArray().size <= 65536) { oversizedStarter += "🙂" }
        @Expect(ckbAbcdeMergeSuiteManifestDependencies(oversizedStarter.toArray(), suite.toArray()).diagnostic,
            "starter_manifest_too_large")
        var oversizedSuite = suite + "#中文🙂"
        while (oversizedSuite.toArray().size <= 65536) { oversizedSuite += "🙂" }
        @Expect(ckbAbcdeMergeSuiteManifestDependencies((header + good).toArray(), oversizedSuite.toArray()).diagnostic,
            "suite_manifest_too_large")

        var exactStarter = header + good + "#中文🙂"
        while (exactStarter.toArray().size < 65536) { exactStarter += "x" }
        var exactSuite = suite + "#中文🙂"
        while (exactSuite.toArray().size < 65536) { exactSuite += "x" }
        @Expect(exactStarter.toArray().size, 65536)
        @Expect(exactSuite.toArray().size, 65536)
        @Expect(ckbAbcdeMergeSuiteManifestDependencies(exactStarter.toArray(), exactSuite.toArray()).diagnostic,
            "merged_manifest_too_large")
    }
}
