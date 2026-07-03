package cangjie_humaneval_069

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
    expectInt64(search(listOfInt64([5, 5, 5, 5, 1])), 1, "CJ-HUMANEVAL-069_l4_c001")
    expectInt64(search(listOfInt64([4, 1, 4, 1, 4, 4])), 4, "CJ-HUMANEVAL-069_l5_c002")
    expectInt64(search(listOfInt64([3, 3])), -1, "CJ-HUMANEVAL-069_l6_c003")
    expectInt64(search(listOfInt64([8, 8, 8, 8, 8, 8, 8, 8])), 8, "CJ-HUMANEVAL-069_l7_c004")
    expectInt64(search(listOfInt64([2, 3, 3, 2, 2])), 2, "CJ-HUMANEVAL-069_l8_c005")
    expectInt64(search(listOfInt64([2, 7, 8, 8, 4, 8, 7, 3, 9, 6, 5, 10, 4, 3, 6, 7, 1, 7, 4, 10, 8, 1])), 1, "CJ-HUMANEVAL-069_l11_c006")
    expectInt64(search(listOfInt64([3, 2, 8, 2])), 2, "CJ-HUMANEVAL-069_l12_c007")
    expectInt64(search(listOfInt64([6, 7, 1, 8, 8, 10, 5, 8, 5, 3, 10])), 1, "CJ-HUMANEVAL-069_l13_c008")
    expectInt64(search(listOfInt64([8, 8, 3, 6, 5, 6, 4])), -1, "CJ-HUMANEVAL-069_l14_c009")
    expectInt64(search(listOfInt64([6, 9, 6, 7, 1, 4, 7, 1, 8, 8, 9, 8, 10, 10, 8, 4, 10, 4, 10, 1, 2, 9, 5, 7, 9])), 1, "CJ-HUMANEVAL-069_l15_c010")
    expectInt64(search(listOfInt64([1, 9, 10, 1, 3])), 1, "CJ-HUMANEVAL-069_l16_c011")
    expectInt64(search(listOfInt64([6, 9, 7, 5, 8, 7, 5, 3, 7, 5, 10, 10, 3, 6, 10, 2, 8, 6, 5, 4, 9, 5, 3, 10])), 5, "CJ-HUMANEVAL-069_l17_c012")
    expectInt64(search(listOfInt64([1])), 1, "CJ-HUMANEVAL-069_l18_c013")
    expectInt64(search(listOfInt64([8, 8, 10, 6, 4, 3, 5, 8, 2, 4, 2, 8, 4, 6, 10, 4, 2, 1, 10, 2, 1, 1, 5])), 4, "CJ-HUMANEVAL-069_l19_c014")
    expectInt64(search(listOfInt64([2, 10, 4, 8, 2, 10, 5, 1, 2, 9, 5, 5, 6, 3, 8, 6, 4, 10])), 2, "CJ-HUMANEVAL-069_l20_c015")
    expectInt64(search(listOfInt64([1, 6, 10, 1, 6, 9, 10, 8, 6, 8, 7, 3])), 1, "CJ-HUMANEVAL-069_l21_c016")
    expectInt64(search(listOfInt64([9, 2, 4, 1, 5, 1, 5, 2, 5, 7, 7, 7, 3, 10, 1, 5, 4, 2, 8, 4, 1, 9, 10, 7, 10, 2, 8, 10, 9, 4])), 4, "CJ-HUMANEVAL-069_l22_c017")
    expectInt64(search(listOfInt64([2, 6, 4, 2, 8, 7, 5, 6, 4, 10, 4, 6, 3, 7, 8, 8, 3, 1, 4, 2, 2, 10, 7])), 4, "CJ-HUMANEVAL-069_l23_c018")
    expectInt64(search(listOfInt64([9, 8, 6, 10, 2, 6, 10, 2, 7, 8, 10, 3, 8, 2, 6, 2, 3, 1])), 2, "CJ-HUMANEVAL-069_l24_c019")
    expectInt64(search(listOfInt64([5, 5, 3, 9, 5, 6, 3, 2, 8, 5, 6, 10, 10, 6, 8, 4, 10, 7, 7, 10, 8])), -1, "CJ-HUMANEVAL-069_l25_c020")
    expectInt64(search(listOfInt64([10])), -1, "CJ-HUMANEVAL-069_l26_c021")
    expectInt64(search(listOfInt64([9, 7, 7, 2, 4, 7, 2, 10, 9, 7, 5, 7, 2])), 2, "CJ-HUMANEVAL-069_l27_c022")
    expectInt64(search(listOfInt64([5, 4, 10, 2, 1, 1, 10, 3, 6, 1, 8])), 1, "CJ-HUMANEVAL-069_l28_c023")
    expectInt64(search(listOfInt64([7, 9, 9, 9, 3, 4, 1, 5, 9, 1, 2, 1, 1, 10, 7, 5, 6, 7, 6, 7, 7, 6])), 1, "CJ-HUMANEVAL-069_l29_c024")
    expectInt64(search(listOfInt64([3, 10, 10, 9, 2])), -1, "CJ-HUMANEVAL-069_l30_c025")
    println("CJ-HUMANEVAL-069 ok")
    return 0
}
