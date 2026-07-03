package cangjie_humaneval_141

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
    expectString(file_name_check("example.txt"), "Yes", "CJ-HUMANEVAL-141_l4_c001")
    expectString(file_name_check("1example.dll"), "No", "CJ-HUMANEVAL-141_l5_c002")
    expectString(file_name_check("s1sdf3.asd"), "No", "CJ-HUMANEVAL-141_l6_c003")
    expectString(file_name_check("K.dll"), "Yes", "CJ-HUMANEVAL-141_l7_c004")
    expectString(file_name_check("MY16FILE3.exe"), "Yes", "CJ-HUMANEVAL-141_l8_c005")
    expectString(file_name_check("His12FILE94.exe"), "No", "CJ-HUMANEVAL-141_l9_c006")
    expectString(file_name_check("_Y.txt"), "No", "CJ-HUMANEVAL-141_l10_c007")
    expectString(file_name_check("?aREYA.exe"), "No", "CJ-HUMANEVAL-141_l11_c008")
    expectString(file_name_check("/this_is_valid.dll"), "No", "CJ-HUMANEVAL-141_l12_c009")
    expectString(file_name_check("this_is_valid.wow"), "No", "CJ-HUMANEVAL-141_l13_c010")
    expectString(file_name_check("this_is_valid.txt"), "Yes", "CJ-HUMANEVAL-141_l14_c011")
    expectString(file_name_check("this_is_valid.txtexe"), "No", "CJ-HUMANEVAL-141_l15_c012")
    expectString(file_name_check("#this2_i4s_5valid.ten"), "No", "CJ-HUMANEVAL-141_l16_c013")
    expectString(file_name_check("@this1_is6_valid.exe"), "No", "CJ-HUMANEVAL-141_l17_c014")
    expectString(file_name_check("this_is_12valid.6exe4.txt"), "No", "CJ-HUMANEVAL-141_l18_c015")
    expectString(file_name_check("all.exe.txt"), "No", "CJ-HUMANEVAL-141_l19_c016")
    expectString(file_name_check("I563_No.exe"), "Yes", "CJ-HUMANEVAL-141_l20_c017")
    expectString(file_name_check("Is3youfault.txt"), "Yes", "CJ-HUMANEVAL-141_l21_c018")
    expectString(file_name_check("no_one#knows.dll"), "Yes", "CJ-HUMANEVAL-141_l22_c019")
    expectString(file_name_check("1I563_Yes3.exe"), "No", "CJ-HUMANEVAL-141_l23_c020")
    expectString(file_name_check("I563_Yes3.txtt"), "No", "CJ-HUMANEVAL-141_l24_c021")
    expectString(file_name_check("final..txt"), "No", "CJ-HUMANEVAL-141_l25_c022")
    expectString(file_name_check("final132"), "No", "CJ-HUMANEVAL-141_l26_c023")
    expectString(file_name_check("_f4indsartal132."), "No", "CJ-HUMANEVAL-141_l27_c024")
    expectString(file_name_check(".txt"), "No", "CJ-HUMANEVAL-141_l32_c025")
    expectString(file_name_check("s."), "No", "CJ-HUMANEVAL-141_l33_c026")
    println("CJ-HUMANEVAL-141 ok")
    return 0
}
