package cangjie_humaneval_129

import std.collection.*
import std.math.*


func listOfInt64(values: Array<Int64>): ArrayList<Int64> { let out = ArrayList<Int64>(); for (v in values) { out.add(v) }; out }
func listOfFloat64(values: Array<Float64>): ArrayList<Float64> { let out = ArrayList<Float64>(); for (v in values) { out.add(v) }; out }
func listOfString(values: Array<String>): ArrayList<String> { let out = ArrayList<String>(); for (v in values) { out.add(v) }; out }
func listOfBool(values: Array<Bool>): ArrayList<Bool> { let out = ArrayList<Bool>(); for (v in values) { out.add(v) }; out }
func listOfEvalValue(values: Array<EvalValue>): ArrayList<EvalValue> { let out = ArrayList<EvalValue>(); for (v in values) { out.add(v) }; out }
func listOfEvalEntry(values: Array<EvalEntry>): ArrayList<EvalEntry> { let out = ArrayList<EvalEntry>(); for (v in values) { out.add(v) }; out }
func listOfInt64List(values: Array<Array<Int64>>): ArrayList<ArrayList<Int64>> { let out = ArrayList<ArrayList<Int64>>(); for (row in values) { out.add(listOfInt64(row)) }; out }
func listOfInt64Pair(values: Array<(Int64, Int64)>): ArrayList<(Int64, Int64)> { let out = ArrayList<(Int64, Int64)>(); for (v in values) { out.add(v) }; out }
func mapOfStringInt64(values: Array<(String, Int64)>): HashMap<String, Int64> { let out = HashMap<String, Int64>(); for (v in values) { out[v[0]] = v[1] }; out }
func mapOfStringString(values: Array<(String, String)>): HashMap<String, String> { let out = HashMap<String, String>(); for (v in values) { out[v[0]] = v[1] }; out }
func cjeFail(label: String, detail: String): Unit { throw Exception("CangjieEval failure: ${label}: ${detail}") }
func expectInt64(actual: Int64, expected: Int64, label: String): Unit { if (actual != expected) { cjeFail(label, "expected ${expected}, actual ${actual}") } }
func expectFloat64(actual: Float64, expected: Float64, label: String): Unit { if (abs(actual - expected) > 0.000001) { cjeFail(label, "expected ${expected}, actual ${actual}") } }
func expectString(actual: String, expected: String, label: String): Unit { if (actual != expected) { cjeFail(label, "expected ${expected}, actual ${actual}") } }
func expectBool(actual: Bool, expected: Bool, label: String): Unit { if (actual != expected) { cjeFail(label, "expected ${expected}, actual ${actual}") } }
func expectEvalValue(actual: EvalValue, expected: EvalValue, label: String): Unit { if (actual.kind != expected.kind) { cjeFail(label, "expected kind ${expected.kind}, actual kind ${actual.kind}") }; if (expected.kind == "int") { expectInt64(actual.intValue, expected.intValue, label) }; if (expected.kind == "float") { expectFloat64(actual.floatValue, expected.floatValue, label) }; if (expected.kind == "string") { expectString(actual.stringValue, expected.stringValue, label) }; if (expected.kind == "bool") { expectBool(actual.boolValue, expected.boolValue, label) } }
func expectInt64List(actual: ArrayList<Int64>, expected: ArrayList<Int64>, label: String): Unit { if (actual.size != expected.size) { cjeFail(label, "expected size ${expected.size}, actual size ${actual.size}") }; for (i in 0..expected.size) { expectInt64(actual[i], expected[i], "${label}[${i}]") } }
func expectFloat64List(actual: ArrayList<Float64>, expected: ArrayList<Float64>, label: String): Unit { if (actual.size != expected.size) { cjeFail(label, "expected size ${expected.size}, actual size ${actual.size}") }; for (i in 0..expected.size) { expectFloat64(actual[i], expected[i], "${label}[${i}]") } }
func expectStringList(actual: ArrayList<String>, expected: ArrayList<String>, label: String): Unit { if (actual.size != expected.size) { cjeFail(label, "expected size ${expected.size}, actual size ${actual.size}") }; for (i in 0..expected.size) { expectString(actual[i], expected[i], "${label}[${i}]") } }
func expectInt64PairList(actual: ArrayList<(Int64, Int64)>, expected: ArrayList<(Int64, Int64)>, label: String): Unit { if (actual.size != expected.size) { cjeFail(label, "expected size ${expected.size}, actual size ${actual.size}") }; for (i in 0..expected.size) { expectInt64(actual[i][0], expected[i][0], "${label}[${i}].0"); expectInt64(actual[i][1], expected[i][1], "${label}[${i}].1") } }
func expectOptionInt64(actual: Option<Int64>, expected: Option<Int64>, label: String): Unit { match (expected) { case Some(e) => match (actual) { case Some(a) => expectInt64(a, e, label); case None => cjeFail(label, "expected Some, actual None") }; case None => match (actual) { case Some(_) => cjeFail(label, "expected None, actual Some"); case None => () } } }
func expectOptionString(actual: Option<String>, expected: Option<String>, label: String): Unit { match (expected) { case Some(e) => match (actual) { case Some(a) => expectString(a, e, label); case None => cjeFail(label, "expected Some, actual None") }; case None => match (actual) { case Some(_) => cjeFail(label, "expected None, actual Some"); case None => () } } }
func expectOptionInt64Tuple(actual: (Option<Int64>, Option<Int64>), expected: (Option<Int64>, Option<Int64>), label: String): Unit { expectOptionInt64(actual[0], expected[0], "${label}.0"); expectOptionInt64(actual[1], expected[1], "${label}.1") }
func expectStringBoolTuple(actual: (String, Bool), expected: (String, Bool), label: String): Unit { expectString(actual[0], expected[0], "${label}.0"); expectBool(actual[1], expected[1], "${label}.1") }
func expectInt64Tuple(actual: (Int64, Int64), expected: (Int64, Int64), label: String): Unit { expectInt64(actual[0], expected[0], "${label}.0"); expectInt64(actual[1], expected[1], "${label}.1") }
func expectFloat64Tuple(actual: (Float64, Float64), expected: (Float64, Float64), label: String): Unit { expectFloat64(actual[0], expected[0], "${label}.0"); expectFloat64(actual[1], expected[1], "${label}.1") }
func expectStringInt64Map(actual: HashMap<String, Int64>, expected: HashMap<String, Int64>, label: String): Unit { if (actual.size != expected.size) { cjeFail(label, "expected map size ${expected.size}, actual size ${actual.size}") }; for ((k, v) in expected) { if (!actual.contains(k)) { cjeFail(label, "missing key ${k}") }; expectInt64(actual[k], v, "${label}.${k}") } }


main(): Int64 {
    expectInt64List(minPath(listOfInt64List([[1, 2, 3], [4, 5, 6], [7, 8, 9]]), 3), listOfInt64([1, 2, 1]), "CJ-HUMANEVAL-129_l5_c001")
    expectInt64List(minPath(listOfInt64List([[5, 9, 3], [4, 1, 6], [7, 8, 2]]), 1), listOfInt64([1]), "CJ-HUMANEVAL-129_l6_c002")
    expectInt64List(minPath(listOfInt64List([[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16]]), 4), listOfInt64([1, 2, 1, 2]), "CJ-HUMANEVAL-129_l7_c003")
    expectInt64List(minPath(listOfInt64List([[6, 4, 13, 10], [5, 7, 12, 1], [3, 16, 11, 15], [8, 14, 9, 2]]), 7), listOfInt64([1, 10, 1, 10, 1, 10, 1]), "CJ-HUMANEVAL-129_l8_c004")
    expectInt64List(minPath(listOfInt64List([[8, 14, 9, 2], [6, 4, 13, 15], [5, 7, 1, 12], [3, 10, 11, 16]]), 5), listOfInt64([1, 7, 1, 7, 1]), "CJ-HUMANEVAL-129_l9_c005")
    expectInt64List(minPath(listOfInt64List([[11, 8, 7, 2], [5, 16, 14, 4], [9, 3, 15, 6], [12, 13, 10, 1]]), 9), listOfInt64([1, 6, 1, 6, 1, 6, 1, 6, 1]), "CJ-HUMANEVAL-129_l10_c006")
    expectInt64List(minPath(listOfInt64List([[12, 13, 10, 1], [9, 3, 15, 6], [5, 16, 14, 4], [11, 8, 7, 2]]), 12), listOfInt64([1, 6, 1, 6, 1, 6, 1, 6, 1, 6, 1, 6]), "CJ-HUMANEVAL-129_l11_c007")
    expectInt64List(minPath(listOfInt64List([[2, 7, 4], [3, 1, 5], [6, 8, 9]]), 8), listOfInt64([1, 3, 1, 3, 1, 3, 1, 3]), "CJ-HUMANEVAL-129_l12_c008")
    expectInt64List(minPath(listOfInt64List([[6, 1, 5], [3, 8, 9], [2, 7, 4]]), 8), listOfInt64([1, 5, 1, 5, 1, 5, 1, 5]), "CJ-HUMANEVAL-129_l13_c009")
    expectInt64List(minPath(listOfInt64List([[1, 2], [3, 4]]), 10), listOfInt64([1, 2, 1, 2, 1, 2, 1, 2, 1, 2]), "CJ-HUMANEVAL-129_l16_c010")
    expectInt64List(minPath(listOfInt64List([[1, 3], [3, 2]]), 10), listOfInt64([1, 3, 1, 3, 1, 3, 1, 3, 1, 3]), "CJ-HUMANEVAL-129_l17_c011")
    println("CJ-HUMANEVAL-129 ok")
    return 0
}
