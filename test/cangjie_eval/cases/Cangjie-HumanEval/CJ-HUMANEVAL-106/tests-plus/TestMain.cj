package cangjie_humaneval_106

import std.collection.*
import std.math.*
func listOfInt64(values: Array<Int64>): ArrayList<Int64> { let out = ArrayList<Int64>(); for (v in values) { out.add(v) }; out }
func listOfFloat64(values: Array<Float64>): ArrayList<Float64> { let out = ArrayList<Float64>(); for (v in values) { out.add(v) }; out }
func listOfString(values: Array<String>): ArrayList<String> { let out = ArrayList<String>(); for (v in values) { out.add(v) }; out }
func listOfEvalValue(values: Array<EvalValue>): ArrayList<EvalValue> { let out = ArrayList<EvalValue>(); for (v in values) { out.add(v) }; out }
func listOfEvalEntry(values: Array<EvalEntry>): ArrayList<EvalEntry> { let out = ArrayList<EvalEntry>(); for (v in values) { out.add(v) }; out }
func listOfInt64List(values: Array<Array<Int64>>): ArrayList<ArrayList<Int64>> { let out = ArrayList<ArrayList<Int64>>(); for (row in values) { out.add(listOfInt64(row)) }; out }
func listOfInt64Pair(values: Array<(Int64, Int64)>): ArrayList<(Int64, Int64)> { let out = ArrayList<(Int64, Int64)>(); for (v in values) { out.add(v) }; out }
func mapOfStringInt64(values: Array<(String, Int64)>): HashMap<String, Int64> { let out = HashMap<String, Int64>(); for (v in values) { out[v[0]] = v[1] }; out }
func plusFail(label: String, detail: String): Unit { throw Exception("CangjieEval Plus failure: ${label}: ${detail}") }
func plusExpectInt64(actual: Int64, expected: Int64, label: String): Unit { if (actual != expected) { plusFail(label, "Int64 mismatch") } }
func plusExpectString(actual: String, expected: String, label: String): Unit { if (actual != expected) { plusFail(label, "String mismatch") } }
func plusExpectBool(actual: Bool, expected: Bool, label: String): Unit { if (actual != expected) { plusFail(label, "Bool mismatch") } }
func plusExpectFloat(actual: Float64, expected: Float64, atol: Float64, label: String): Unit { if (actual == expected) { return }; if (atol == 0.0) { plusFail(label, "Float64 exact mismatch"); return }; let difference = abs(actual - expected); let limit = atol + 0.0000001 * abs(expected); if (!(difference <= limit)) { plusFail(label, "Float64 allclose mismatch") } }
func plusExpectInt64List(actual: ArrayList<Int64>, expected: ArrayList<Int64>, label: String): Unit { if (actual.size != expected.size) { plusFail(label, "Int64 list size mismatch") }; for (j in 0..expected.size) { plusExpectInt64(actual[j], expected[j], "${label}[${j}]") } }
func plusExpectStringList(actual: ArrayList<String>, expected: ArrayList<String>, label: String): Unit { if (actual.size != expected.size) { plusFail(label, "String list size mismatch") }; for (j in 0..expected.size) { plusExpectString(actual[j], expected[j], "${label}[${j}]") } }
func plusExpectFloatList(actual: ArrayList<Float64>, expected: ArrayList<Float64>, atol: Float64, label: String): Unit { var exact = actual.size == expected.size; if (exact) { for (j in 0..expected.size) { if (actual[j] != expected[j]) { exact = false } } }; if (exact) { return }; if (atol == 0.0) { plusFail(label, "Float64 list exact mismatch"); return }; var count = actual.size; if (actual.size == expected.size) { count = actual.size } else if (actual.size == 1) { count = expected.size } else if (expected.size == 1) { count = actual.size } else { plusFail(label, "Float64 list broadcast mismatch"); return }; for (j in 0..count) { var a = 0.0; var e = 0.0; if (actual.size == 1) { a = actual[0] } else { a = actual[j] }; if (expected.size == 1) { e = expected[0] } else { e = expected[j] }; plusExpectFloat(a, e, atol, "${label}[${j}]") } }
func plusExpectInt64PairList(actual: ArrayList<(Int64, Int64)>, expected: ArrayList<(Int64, Int64)>, label: String): Unit { if (actual.size != expected.size) { plusFail(label, "pair list size mismatch") }; for (j in 0..expected.size) { plusExpectInt64(actual[j][0], expected[j][0], label); plusExpectInt64(actual[j][1], expected[j][1], label) } }
func plusExpectOptionInt64(actual: Option<Int64>, expected: Option<Int64>, label: String): Unit { match (expected) { case Some(e) => match (actual) { case Some(a) => plusExpectInt64(a, e, label); case None => plusFail(label, "expected Some") }; case None => match (actual) { case Some(_) => plusFail(label, "expected None"); case None => () } } }
func plusExpectOptionString(actual: Option<String>, expected: Option<String>, label: String): Unit { match (expected) { case Some(e) => match (actual) { case Some(a) => plusExpectString(a, e, label); case None => plusFail(label, "expected Some") }; case None => match (actual) { case Some(_) => plusFail(label, "expected None"); case None => () } } }
func plusExpectOptionInt64Tuple(actual: (Option<Int64>, Option<Int64>), expected: (Option<Int64>, Option<Int64>), label: String): Unit { plusExpectOptionInt64(actual[0], expected[0], label); plusExpectOptionInt64(actual[1], expected[1], label) }
func plusExpectStringBoolTuple(actual: (String, Bool), expected: (String, Bool), label: String): Unit { plusExpectString(actual[0], expected[0], label); plusExpectBool(actual[1], expected[1], label) }
func plusExpectInt64Tuple(actual: (Int64, Int64), expected: (Int64, Int64), label: String): Unit { plusExpectInt64(actual[0], expected[0], label); plusExpectInt64(actual[1], expected[1], label) }
func plusExpectFloatTuple(actual: (Float64, Float64), expected: (Float64, Float64), atol: Float64, label: String): Unit { plusExpectFloat(actual[0], expected[0], atol, label); plusExpectFloat(actual[1], expected[1], atol, label) }
func plusExpectStringInt64Map(actual: HashMap<String, Int64>, expected: HashMap<String, Int64>, label: String): Unit { if (actual.size != expected.size) { plusFail(label, "map size mismatch") }; for ((k, v) in expected) { if (!actual.contains(k)) { plusFail(label, "missing map key") }; plusExpectInt64(actual[k], v, label) } }
func plusExpectEvalValue(actual: EvalValue, expected: EvalValue, atol: Float64, label: String): Unit { if (actual.kind != expected.kind) { plusFail(label, "EvalValue kind mismatch") }; if (expected.kind == "int") { plusExpectInt64(actual.intValue, expected.intValue, label) } else if (expected.kind == "float") { plusExpectFloat(actual.floatValue, expected.floatValue, atol, label) } else if (expected.kind == "string") { plusExpectString(actual.stringValue, expected.stringValue, label) } else if (expected.kind == "bool") { plusExpectBool(actual.boolValue, expected.boolValue, label) } else if (!(expected.kind == "none" || expected.kind == "list" || expected.kind == "map")) { plusFail(label, "unsupported EvalValue kind") } }

main(): Int64 {
    plusExpectInt64List(f(0), listOfInt64([]), "CJ-HUMANEVAL-106_plus_c000000")
    plusExpectInt64List(f(2), listOfInt64([1, 2]), "CJ-HUMANEVAL-106_plus_c000001")
    plusExpectInt64List(f(4), listOfInt64([1, 2, 6, 24]), "CJ-HUMANEVAL-106_plus_c000002")
    plusExpectInt64List(f(6), listOfInt64([1, 2, 6, 24, 15, 720]), "CJ-HUMANEVAL-106_plus_c000003")
    plusExpectInt64List(f(8), listOfInt64([1, 2, 6, 24, 15, 720, 28, 40320]), "CJ-HUMANEVAL-106_plus_c000004")
    plusExpectInt64List(f(10), listOfInt64([1, 2, 6, 24, 15, 720, 28, 40320, 45, 3628800]), "CJ-HUMANEVAL-106_plus_c000005")
    plusExpectInt64List(f(15), listOfInt64([1, 2, 6, 24, 15, 720, 28, 40320, 45, 3628800, 66, 479001600, 91, 87178291200, 120]), "CJ-HUMANEVAL-106_plus_c000007")
    plusExpectInt64List(f(20), listOfInt64([1, 2, 6, 24, 15, 720, 28, 40320, 45, 3628800, 66, 479001600, 91, 87178291200, 120, 20922789888000, 153, 6402373705728000, 190, 2432902008176640000]), "CJ-HUMANEVAL-106_plus_c000008")
    plusExpectInt64List(f(12), listOfInt64([1, 2, 6, 24, 15, 720, 28, 40320, 45, 3628800, 66, 479001600]), "CJ-HUMANEVAL-106_plus_c000009")
    plusExpectInt64List(f(5), listOfInt64([1, 2, 6, 24, 15]), "CJ-HUMANEVAL-106_plus_c000010")
    plusExpectInt64List(f(7), listOfInt64([1, 2, 6, 24, 15, 720, 28]), "CJ-HUMANEVAL-106_plus_c000011")
    plusExpectInt64List(f(11), listOfInt64([1, 2, 6, 24, 15, 720, 28, 40320, 45, 3628800, 66]), "CJ-HUMANEVAL-106_plus_c000012")
    plusExpectInt64List(f(9), listOfInt64([1, 2, 6, 24, 15, 720, 28, 40320, 45]), "CJ-HUMANEVAL-106_plus_c000013")
    plusExpectInt64List(f(19), listOfInt64([1, 2, 6, 24, 15, 720, 28, 40320, 45, 3628800, 66, 479001600, 91, 87178291200, 120, 20922789888000, 153, 6402373705728000, 190]), "CJ-HUMANEVAL-106_plus_c000014")
    plusExpectInt64List(f(1), listOfInt64([1]), "CJ-HUMANEVAL-106_plus_c000016")
    plusExpectInt64List(f(13), listOfInt64([1, 2, 6, 24, 15, 720, 28, 40320, 45, 3628800, 66, 479001600, 91]), "CJ-HUMANEVAL-106_plus_c000020")
    plusExpectInt64List(f(3), listOfInt64([1, 2, 6]), "CJ-HUMANEVAL-106_plus_c000021")
    plusExpectInt64List(f(18), listOfInt64([1, 2, 6, 24, 15, 720, 28, 40320, 45, 3628800, 66, 479001600, 91, 87178291200, 120, 20922789888000, 153, 6402373705728000]), "CJ-HUMANEVAL-106_plus_c000022")
    plusExpectInt64List(f(21), listOfInt64([1, 2, 6, 24, 15, 720, 28, 40320, 45, 3628800, 66, 479001600, 91, 87178291200, 120, 20922789888000, 153, 6402373705728000, 190, 2432902008176640000, 231]), "CJ-HUMANEVAL-106_plus_c000023")
    plusExpectInt64List(f(16), listOfInt64([1, 2, 6, 24, 15, 720, 28, 40320, 45, 3628800, 66, 479001600, 91, 87178291200, 120, 20922789888000]), "CJ-HUMANEVAL-106_plus_c000028")
    plusExpectInt64List(f(17), listOfInt64([1, 2, 6, 24, 15, 720, 28, 40320, 45, 3628800, 66, 479001600, 91, 87178291200, 120, 20922789888000, 153]), "CJ-HUMANEVAL-106_plus_c000032")
    plusExpectInt64List(f(14), listOfInt64([1, 2, 6, 24, 15, 720, 28, 40320, 45, 3628800, 66, 479001600, 91, 87178291200]), "CJ-HUMANEVAL-106_plus_c000033")
    println("CJ-HUMANEVAL-106 Plus ok")
    return 0
}
