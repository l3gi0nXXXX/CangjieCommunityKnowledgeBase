package cangjie_humaneval_063

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
    plusExpectInt64(fibfib(20), 35890, "CJ-HUMANEVAL-063_plus_c000000")
    plusExpectInt64(fibfib(0), 0, "CJ-HUMANEVAL-063_plus_c000001")
    plusExpectInt64(fibfib(15), 1705, "CJ-HUMANEVAL-063_plus_c000002")
    plusExpectInt64(fibfib(23), 223317, "CJ-HUMANEVAL-063_plus_c000003")
    plusExpectInt64(fibfib(21), 66012, "CJ-HUMANEVAL-063_plus_c000004")
    plusExpectInt64(fibfib(25), 755476, "CJ-HUMANEVAL-063_plus_c000005")
    plusExpectInt64(fibfib(1), 0, "CJ-HUMANEVAL-063_plus_c000006")
    plusExpectInt64(fibfib(14), 927, "CJ-HUMANEVAL-063_plus_c000007")
    plusExpectInt64(fibfib(13), 504, "CJ-HUMANEVAL-063_plus_c000008")
    plusExpectInt64(fibfib(19), 19513, "CJ-HUMANEVAL-063_plus_c000009")
    plusExpectInt64(fibfib(57), 222332455004452, "CJ-HUMANEVAL-063_plus_c000010")
    plusExpectInt64(fibfib(22), 121415, "CJ-HUMANEVAL-063_plus_c000011")
    plusExpectInt64(fibfib(24), 410744, "CJ-HUMANEVAL-063_plus_c000012")
    plusExpectInt64(fibfib(56), 120879712950776, "CJ-HUMANEVAL-063_plus_c000013")
    plusExpectInt64(fibfib(18), 10609, "CJ-HUMANEVAL-063_plus_c000014")
    plusExpectInt64(fibfib(58), 408933139743937, "CJ-HUMANEVAL-063_plus_c000017")
    plusExpectInt64(fibfib(12), 274, "CJ-HUMANEVAL-063_plus_c000018")
    plusExpectInt64(fibfib(11), 149, "CJ-HUMANEVAL-063_plus_c000019")
    plusExpectInt64(fibfib(2), 1, "CJ-HUMANEVAL-063_plus_c000020")
    plusExpectInt64(fibfib(26), 1389537, "CJ-HUMANEVAL-063_plus_c000021")
    plusExpectInt64(fibfib(60), 1383410902447554, "CJ-HUMANEVAL-063_plus_c000022")
    plusExpectInt64(fibfib(4), 2, "CJ-HUMANEVAL-063_plus_c000023")
    plusExpectInt64(fibfib(59), 752145307699165, "CJ-HUMANEVAL-063_plus_c000024")
    plusExpectInt64(fibfib(16), 3136, "CJ-HUMANEVAL-063_plus_c000025")
    plusExpectInt64(fibfib(27), 2555757, "CJ-HUMANEVAL-063_plus_c000026")
    plusExpectInt64(fibfib(28), 4700770, "CJ-HUMANEVAL-063_plus_c000027")
    plusExpectInt64(fibfib(3), 1, "CJ-HUMANEVAL-063_plus_c000028")
    plusExpectInt64(fibfib(17), 5768, "CJ-HUMANEVAL-063_plus_c000029")
    plusExpectInt64(fibfib(61), 2544489349890656, "CJ-HUMANEVAL-063_plus_c000030")
    plusExpectInt64(fibfib(10), 81, "CJ-HUMANEVAL-063_plus_c000031")
    plusExpectInt64(fibfib(62), 4680045560037375, "CJ-HUMANEVAL-063_plus_c000032")
    plusExpectInt64(fibfib(29), 8646064, "CJ-HUMANEVAL-063_plus_c000033")
    plusExpectInt64(fibfib(30), 15902591, "CJ-HUMANEVAL-063_plus_c000034")
    plusExpectInt64(fibfib(31), 29249425, "CJ-HUMANEVAL-063_plus_c000035")
    plusExpectInt64(fibfib(32), 53798080, "CJ-HUMANEVAL-063_plus_c000036")
    plusExpectInt64(fibfib(48), 922906855808, "CJ-HUMANEVAL-063_plus_c000037")
    plusExpectInt64(fibfib(47), 501774317241, "CJ-HUMANEVAL-063_plus_c000038")
    plusExpectInt64(fibfib(46), 272809183135, "CJ-HUMANEVAL-063_plus_c000039")
    plusExpectInt64(fibfib(55), 65720971788709, "CJ-HUMANEVAL-063_plus_c000040")
    plusExpectInt64(fibfib(49), 1697490356184, "CJ-HUMANEVAL-063_plus_c000041")
    plusExpectInt64(fibfib(50), 3122171529233, "CJ-HUMANEVAL-063_plus_c000042")
    plusExpectInt64(fibfib(51), 5742568741225, "CJ-HUMANEVAL-063_plus_c000043")
    plusExpectInt64(fibfib(52), 10562230626642, "CJ-HUMANEVAL-063_plus_c000044")
    plusExpectInt64(fibfib(53), 19426970897100, "CJ-HUMANEVAL-063_plus_c000045")
    plusExpectInt64(fibfib(54), 35731770264967, "CJ-HUMANEVAL-063_plus_c000046")
    plusExpectInt64(fibfib(33), 98950096, "CJ-HUMANEVAL-063_plus_c000047")
    plusExpectInt64(fibfib(73), 3814116544533214284, "CJ-HUMANEVAL-063_plus_c000048")
    plusExpectInt64(fibfib(34), 181997601, "CJ-HUMANEVAL-063_plus_c000049")
    plusExpectInt64(fibfib(63), 8607945812375585, "CJ-HUMANEVAL-063_plus_c000050")
    plusExpectInt64(fibfib(45), 148323355432, "CJ-HUMANEVAL-063_plus_c000051")
    plusExpectInt64(fibfib(72), 2073693258389777176, "CJ-HUMANEVAL-063_plus_c000052")
    plusExpectInt64(fibfib(71), 1127444240280152749, "CJ-HUMANEVAL-063_plus_c000056")
    plusExpectInt64(fibfib(43), 43844049029, "CJ-HUMANEVAL-063_plus_c000057")
    plusExpectInt64(fibfib(9), 44, "CJ-HUMANEVAL-063_plus_c000058")
    plusExpectInt64(fibfib(35), 334745777, "CJ-HUMANEVAL-063_plus_c000059")
    plusExpectInt64(fibfib(44), 80641778674, "CJ-HUMANEVAL-063_plus_c000060")
    println("CJ-HUMANEVAL-063 Plus ok")
    return 0
}
