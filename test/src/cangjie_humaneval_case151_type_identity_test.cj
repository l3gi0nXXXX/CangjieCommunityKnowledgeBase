package cangjie_community_knowledge_base_test

import std.collection.*
import std.fs.{Directory, File, Path, exists, remove}
import std.unittest.*
import std.unittest.testmacro.*

private class H151Number {
    var kind: String = "none"
    var intValue: Int64 = 0
    var floatValue: Float64 = 0.0
    var boolValue: Bool = false
}

private func h151Int(value: Int64): H151Number {
    let result = H151Number()
    result.kind = "int"
    result.intValue = value
    result.floatValue = Float64(value)
    result
}

private func h151Float(value: Float64): H151Number {
    let result = H151Number()
    result.kind = "float"
    result.floatValue = value
    result
}

private func h151Bool(value: Bool): H151Number {
    let result = H151Number()
    result.kind = "bool"
    result.boolValue = value
    result
}

private func h151Values(values: Array<H151Number>): ArrayList<H151Number> {
    let result = ArrayList<H151Number>()
    for (value in values) { result.add(value) }
    result
}

private func h151OfficialSemantics(values: ArrayList<H151Number>): Int64 {
    var result: Int64 = 0
    for (value in values) {
        var projected: Int64 = 0
        if (value.kind == "int") {
            projected = value.intValue
        } else if (value.kind == "bool") {
            projected = if (value.boolValue) { 1 } else { 0 }
        } else {
            continue
        }
        if (projected > 0 && projected % 2 != 0) {
            result += projected * projected
        }
    }
    result
}

private func h151ReadUtf8(relativePath: String): String {
    let root = Path("cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-151")
    try {
        return String.fromUtf8(File.readFrom(root.join(relativePath)))
    } catch (_: Exception) {
        return ""
    }
}

@Test
public class CangjieHumanEvalCase151TypeIdentityTest {
    @TestCase
    public func h151Ut01TaggedIntegerFilterPreservesTypeIdentity(): Unit {
        @Expect(h151OfficialSemantics(h151Values([h151Int(3)])), 9)
        @Expect(h151OfficialSemantics(h151Values([h151Float(3.0)])), 0)
        @Expect(h151OfficialSemantics(h151Values([h151Bool(true)])), 1)
        @Expect(h151OfficialSemantics(h151Values([h151Bool(false)])), 0)
        @Expect(h151OfficialSemantics(h151Values([h151Int(4), h151Float(5.0)])), 0)
    }

    @TestCase
    public func h151Bnd01NegativeZeroLargeNaNAndInfinityAreHandled(): Unit {
        let zero: Float64 = 0.0
        @Expect(h151OfficialSemantics(h151Values([h151Int(-3), h151Int(0), h151Int(3037000499)])), 9223372030926249001)
        @Expect(h151OfficialSemantics(h151Values([h151Float(zero / zero), h151Float(1.0 / zero), h151Float(-1.0 / zero)])), 0)
    }

    @TestCase
    public func h151Pos01OfficialChecksRemainSatisfied(): Unit {
        @Expect(h151OfficialSemantics(h151Values([])), 0)
        @Expect(h151OfficialSemantics(h151Values([h151Int(5), h151Int(4)])), 25)
        @Expect(h151OfficialSemantics(h151Values([h151Float(0.1), h151Float(0.2), h151Float(0.3)])), 0)
        @Expect(h151OfficialSemantics(h151Values([h151Int(-10), h151Int(-20), h151Int(-30)])), 0)
        @Expect(h151OfficialSemantics(h151Values([h151Int(-1), h151Int(-2), h151Int(8)])), 0)
        @Expect(h151OfficialSemantics(h151Values([h151Float(0.2), h151Int(3), h151Int(5)])), 34)
    }

    @TestCase
    public func h151Neg01LegacyFloat64CollisionAndTagIgnoringAreRejected(): Unit {
        let legacyIntThree: Float64 = 3.0
        let legacyFloatThree: Float64 = 3.0
        @Expect(legacyIntThree == legacyFloatThree, true)
        @Expect(h151OfficialSemantics(h151Values([h151Int(3)])) != h151OfficialSemantics(h151Values([h151Float(3.0)])), true)
        let tests = h151ReadUtf8("tests/TestMain.cj")
        @Expect(tests.contains("evalInt(3)"), true)
        @Expect(tests.contains("evalFloat(3.0)"), true)
        @Expect(tests.contains("listOfFloat64("), false)
    }

    @TestCase
    public func h151Safe01UnicodeAndInvalidEncodingFailClosed(): Unit {
        let manifest = buildCangjieHumanEvalManifest("cangjie_eval/cases/Cangjie-HumanEval", "")
        @Expect(manifest.ok, true)
        manifest.rows[151].prompt = "中文类型身份🙂"
        @Expect(renderModelVisibleManifest(manifest).contains("中文类型身份🙂"), true)

        let root = "target/h151-invalid-utf8"
        if (exists(Path(root))) { remove(Path(root), recursive: true) }
        let caseRoot = Path(root).join("CJ-HUMANEVAL-151")
        Directory.create(caseRoot.join("starter/src"), recursive: true)
        Directory.create(caseRoot.join("tests"), recursive: true)
        File.writeTo(caseRoot.join("prompt.md"), [UInt8(255), UInt8(254)])
        File.writeTo(caseRoot.join("metadata.json"), "{malformed 中文🙂".toArray())
        File.writeTo(caseRoot.join("starter/src/solution.cj"), "package fixture\n".toArray())
        File.writeTo(caseRoot.join("tests/TestMain.cj"), "main() {}\n".toArray())
        let invalid = buildCangjieHumanEvalManifest(root, "")
        @Expect(invalid.ok, false)
        @Expect(invalid.diagnostics.size > 0, true)
    }

    @TestCase
    public func h151Manifest01FixtureAndCanonicalViewsUseTaggedValues(): Unit {
        let prompt = h151ReadUtf8("prompt.md")
        let starter = h151ReadUtf8("starter/src/solution.cj")
        let metadata = h151ReadUtf8("metadata.json")
        let translation = h151ReadUtf8("translation/line_translation.md")
        let canonical = String.fromUtf8(File.readFrom(Path("cangjie_eval/cangjie_humaneval_manifest.jsonl")))
        let readme = String.fromUtf8(File.readFrom(Path("cangjie_eval/cases/Cangjie-HumanEval/README.md")))
        let signature = "public func double_the_difference(lst: ArrayList<EvalValue>): Int64"
        @Expect(prompt.contains(signature), true)
        @Expect(starter.contains(signature), true)
        @Expect(metadata.contains(signature), true)
        @Expect(metadata.contains("Python int and float identities are preserved with EvalValue tags."), true)
        @Expect(metadata.contains("Python bool is an int subtype: evalBool(true) projects to integer 1 and contributes 1, while evalBool(false) projects to integer 0 and contributes 0."), true)
        @Expect(translation.contains("evalInt(3)"), true)
        @Expect(translation.contains("evalFloat(3.0)"), true)
        @Expect(translation.contains("evalBool(true)"), true)
        @Expect(translation.contains("evalBool(false)"), true)
        @Expect(canonical.contains("\"schemaVersion\":\"cangjie-humaneval-authority-v1\""), true)
        @Expect(canonical.contains("\"caseId\":\"CJ-HUMANEVAL-151\""), true)
        @Expect(canonical.contains("\"signature\":\"${signature}\""), true)
        @Expect(readme.contains("`CJ-HUMANEVAL-151` | `HumanEval/151` | `double_the_difference` | 11 | `${signature}`"), true)
    }
}
