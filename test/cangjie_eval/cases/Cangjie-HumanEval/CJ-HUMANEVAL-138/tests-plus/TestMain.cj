package cangjie_humaneval_138

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
    plusExpectBool(is_equal_to_sum_even(20), true, "CJ-HUMANEVAL-138_plus_c000000")
    plusExpectBool(is_equal_to_sum_even(22), true, "CJ-HUMANEVAL-138_plus_c000001")
    plusExpectBool(is_equal_to_sum_even(24), true, "CJ-HUMANEVAL-138_plus_c000002")
    plusExpectBool(is_equal_to_sum_even(30), true, "CJ-HUMANEVAL-138_plus_c000003")
    plusExpectBool(is_equal_to_sum_even(36), true, "CJ-HUMANEVAL-138_plus_c000004")
    plusExpectBool(is_equal_to_sum_even(40), true, "CJ-HUMANEVAL-138_plus_c000005")
    plusExpectBool(is_equal_to_sum_even(42), true, "CJ-HUMANEVAL-138_plus_c000006")
    plusExpectBool(is_equal_to_sum_even(48), true, "CJ-HUMANEVAL-138_plus_c000007")
    plusExpectBool(is_equal_to_sum_even(50), true, "CJ-HUMANEVAL-138_plus_c000008")
    plusExpectBool(is_equal_to_sum_even(28), true, "CJ-HUMANEVAL-138_plus_c000009")
    plusExpectBool(is_equal_to_sum_even(41), false, "CJ-HUMANEVAL-138_plus_c000010")
    plusExpectBool(is_equal_to_sum_even(21), false, "CJ-HUMANEVAL-138_plus_c000011")
    plusExpectBool(is_equal_to_sum_even(39), false, "CJ-HUMANEVAL-138_plus_c000012")
    plusExpectBool(is_equal_to_sum_even(23), false, "CJ-HUMANEVAL-138_plus_c000013")
    plusExpectBool(is_equal_to_sum_even(25), false, "CJ-HUMANEVAL-138_plus_c000014")
    plusExpectBool(is_equal_to_sum_even(35), false, "CJ-HUMANEVAL-138_plus_c000015")
    plusExpectBool(is_equal_to_sum_even(19), false, "CJ-HUMANEVAL-138_plus_c000016")
    plusExpectBool(is_equal_to_sum_even(49), false, "CJ-HUMANEVAL-138_plus_c000017")
    plusExpectBool(is_equal_to_sum_even(51), false, "CJ-HUMANEVAL-138_plus_c000018")
    plusExpectBool(is_equal_to_sum_even(52), true, "CJ-HUMANEVAL-138_plus_c000019")
    plusExpectBool(is_equal_to_sum_even(47), false, "CJ-HUMANEVAL-138_plus_c000020")
    plusExpectBool(is_equal_to_sum_even(37), false, "CJ-HUMANEVAL-138_plus_c000021")
    plusExpectBool(is_equal_to_sum_even(34), true, "CJ-HUMANEVAL-138_plus_c000022")
    plusExpectBool(is_equal_to_sum_even(-79), false, "CJ-HUMANEVAL-138_plus_c000023")
    plusExpectBool(is_equal_to_sum_even(29), false, "CJ-HUMANEVAL-138_plus_c000024")
    plusExpectBool(is_equal_to_sum_even(53), false, "CJ-HUMANEVAL-138_plus_c000025")
    plusExpectBool(is_equal_to_sum_even(57), false, "CJ-HUMANEVAL-138_plus_c000026")
    plusExpectBool(is_equal_to_sum_even(56), true, "CJ-HUMANEVAL-138_plus_c000027")
    plusExpectBool(is_equal_to_sum_even(-2), false, "CJ-HUMANEVAL-138_plus_c000028")
    plusExpectBool(is_equal_to_sum_even(0), false, "CJ-HUMANEVAL-138_plus_c000029")
    plusExpectBool(is_equal_to_sum_even(2), false, "CJ-HUMANEVAL-138_plus_c000030")
    plusExpectBool(is_equal_to_sum_even(5), false, "CJ-HUMANEVAL-138_plus_c000031")
    plusExpectBool(is_equal_to_sum_even(9), false, "CJ-HUMANEVAL-138_plus_c000032")
    plusExpectBool(is_equal_to_sum_even(15), false, "CJ-HUMANEVAL-138_plus_c000033")
    plusExpectBool(is_equal_to_sum_even(27), false, "CJ-HUMANEVAL-138_plus_c000034")
    plusExpectBool(is_equal_to_sum_even(100), true, "CJ-HUMANEVAL-138_plus_c000035")
    plusExpectBool(is_equal_to_sum_even(105), false, "CJ-HUMANEVAL-138_plus_c000036")
    plusExpectBool(is_equal_to_sum_even(8), true, "CJ-HUMANEVAL-138_plus_c000037")
    plusExpectBool(is_equal_to_sum_even(-3), false, "CJ-HUMANEVAL-138_plus_c000038")
    plusExpectBool(is_equal_to_sum_even(76), true, "CJ-HUMANEVAL-138_plus_c000039")
    plusExpectBool(is_equal_to_sum_even(101), false, "CJ-HUMANEVAL-138_plus_c000040")
    plusExpectBool(is_equal_to_sum_even(98), true, "CJ-HUMANEVAL-138_plus_c000041")
    plusExpectBool(is_equal_to_sum_even(3), false, "CJ-HUMANEVAL-138_plus_c000042")
    plusExpectBool(is_equal_to_sum_even(97), false, "CJ-HUMANEVAL-138_plus_c000043")
    plusExpectBool(is_equal_to_sum_even(7), false, "CJ-HUMANEVAL-138_plus_c000044")
    plusExpectBool(is_equal_to_sum_even(1), false, "CJ-HUMANEVAL-138_plus_c000045")
    plusExpectBool(is_equal_to_sum_even(6), false, "CJ-HUMANEVAL-138_plus_c000046")
    plusExpectBool(is_equal_to_sum_even(99), false, "CJ-HUMANEVAL-138_plus_c000047")
    plusExpectBool(is_equal_to_sum_even(-50), false, "CJ-HUMANEVAL-138_plus_c000048")
    plusExpectBool(is_equal_to_sum_even(102), true, "CJ-HUMANEVAL-138_plus_c000049")
    plusExpectBool(is_equal_to_sum_even(-71), false, "CJ-HUMANEVAL-138_plus_c000050")
    plusExpectBool(is_equal_to_sum_even(-1), false, "CJ-HUMANEVAL-138_plus_c000051")
    plusExpectBool(is_equal_to_sum_even(-72), false, "CJ-HUMANEVAL-138_plus_c000052")
    plusExpectBool(is_equal_to_sum_even(-27), false, "CJ-HUMANEVAL-138_plus_c000053")
    plusExpectBool(is_equal_to_sum_even(104), true, "CJ-HUMANEVAL-138_plus_c000054")
    plusExpectBool(is_equal_to_sum_even(96), true, "CJ-HUMANEVAL-138_plus_c000055")
    plusExpectBool(is_equal_to_sum_even(10), true, "CJ-HUMANEVAL-138_plus_c000056")
    plusExpectBool(is_equal_to_sum_even(-26), false, "CJ-HUMANEVAL-138_plus_c000057")
    plusExpectBool(is_equal_to_sum_even(-39), false, "CJ-HUMANEVAL-138_plus_c000058")
    plusExpectBool(is_equal_to_sum_even(-55), false, "CJ-HUMANEVAL-138_plus_c000059")
    plusExpectBool(is_equal_to_sum_even(-29), false, "CJ-HUMANEVAL-138_plus_c000060")
    plusExpectBool(is_equal_to_sum_even(-66), false, "CJ-HUMANEVAL-138_plus_c000061")
    plusExpectBool(is_equal_to_sum_even(11), false, "CJ-HUMANEVAL-138_plus_c000062")
    plusExpectBool(is_equal_to_sum_even(14), true, "CJ-HUMANEVAL-138_plus_c000063")
    plusExpectBool(is_equal_to_sum_even(-42), false, "CJ-HUMANEVAL-138_plus_c000064")
    plusExpectBool(is_equal_to_sum_even(4), false, "CJ-HUMANEVAL-138_plus_c000065")
    plusExpectBool(is_equal_to_sum_even(77), false, "CJ-HUMANEVAL-138_plus_c000066")
    plusExpectBool(is_equal_to_sum_even(-38), false, "CJ-HUMANEVAL-138_plus_c000067")
    plusExpectBool(is_equal_to_sum_even(-30), false, "CJ-HUMANEVAL-138_plus_c000068")
    plusExpectBool(is_equal_to_sum_even(-25), false, "CJ-HUMANEVAL-138_plus_c000069")
    plusExpectBool(is_equal_to_sum_even(-34), false, "CJ-HUMANEVAL-138_plus_c000070")
    plusExpectBool(is_equal_to_sum_even(78), true, "CJ-HUMANEVAL-138_plus_c000071")
    plusExpectBool(is_equal_to_sum_even(103), false, "CJ-HUMANEVAL-138_plus_c000072")
    plusExpectBool(is_equal_to_sum_even(-65), false, "CJ-HUMANEVAL-138_plus_c000073")
    plusExpectBool(is_equal_to_sum_even(-49), false, "CJ-HUMANEVAL-138_plus_c000074")
    plusExpectBool(is_equal_to_sum_even(-18), false, "CJ-HUMANEVAL-138_plus_c000075")
    plusExpectBool(is_equal_to_sum_even(-7), false, "CJ-HUMANEVAL-138_plus_c000076")
    plusExpectBool(is_equal_to_sum_even(75), false, "CJ-HUMANEVAL-138_plus_c000077")
    plusExpectBool(is_equal_to_sum_even(-37), false, "CJ-HUMANEVAL-138_plus_c000078")
    plusExpectBool(is_equal_to_sum_even(-73), false, "CJ-HUMANEVAL-138_plus_c000079")
    plusExpectBool(is_equal_to_sum_even(-51), false, "CJ-HUMANEVAL-138_plus_c000080")
    plusExpectBool(is_equal_to_sum_even(106), true, "CJ-HUMANEVAL-138_plus_c000081")
    plusExpectBool(is_equal_to_sum_even(64), true, "CJ-HUMANEVAL-138_plus_c000082")
    plusExpectBool(is_equal_to_sum_even(-52), false, "CJ-HUMANEVAL-138_plus_c000083")
    plusExpectBool(is_equal_to_sum_even(-8), false, "CJ-HUMANEVAL-138_plus_c000084")
    plusExpectBool(is_equal_to_sum_even(-6), false, "CJ-HUMANEVAL-138_plus_c000085")
    plusExpectBool(is_equal_to_sum_even(-10), false, "CJ-HUMANEVAL-138_plus_c000086")
    plusExpectBool(is_equal_to_sum_even(16), true, "CJ-HUMANEVAL-138_plus_c000087")
    plusExpectBool(is_equal_to_sum_even(12), true, "CJ-HUMANEVAL-138_plus_c000088")
    plusExpectBool(is_equal_to_sum_even(107), false, "CJ-HUMANEVAL-138_plus_c000089")
    plusExpectBool(is_equal_to_sum_even(26), true, "CJ-HUMANEVAL-138_plus_c000090")
    plusExpectBool(is_equal_to_sum_even(18), true, "CJ-HUMANEVAL-138_plus_c000091")
    plusExpectBool(is_equal_to_sum_even(108), true, "CJ-HUMANEVAL-138_plus_c000092")
    plusExpectBool(is_equal_to_sum_even(109), false, "CJ-HUMANEVAL-138_plus_c000093")
    plusExpectBool(is_equal_to_sum_even(17), false, "CJ-HUMANEVAL-138_plus_c000094")
    plusExpectBool(is_equal_to_sum_even(110), true, "CJ-HUMANEVAL-138_plus_c000095")
    plusExpectBool(is_equal_to_sum_even(31), false, "CJ-HUMANEVAL-138_plus_c000096")
    plusExpectBool(is_equal_to_sum_even(-98), false, "CJ-HUMANEVAL-138_plus_c000097")
    plusExpectBool(is_equal_to_sum_even(-87), false, "CJ-HUMANEVAL-138_plus_c000098")
    plusExpectBool(is_equal_to_sum_even(-5), false, "CJ-HUMANEVAL-138_plus_c000099")
    plusExpectBool(is_equal_to_sum_even(-40), false, "CJ-HUMANEVAL-138_plus_c000100")
    plusExpectBool(is_equal_to_sum_even(-88), false, "CJ-HUMANEVAL-138_plus_c000101")
    plusExpectBool(is_equal_to_sum_even(-4), false, "CJ-HUMANEVAL-138_plus_c000102")
    plusExpectBool(is_equal_to_sum_even(55), false, "CJ-HUMANEVAL-138_plus_c000103")
    plusExpectBool(is_equal_to_sum_even(-86), false, "CJ-HUMANEVAL-138_plus_c000104")
    plusExpectBool(is_equal_to_sum_even(13), false, "CJ-HUMANEVAL-138_plus_c000105")
    plusExpectBool(is_equal_to_sum_even(32), true, "CJ-HUMANEVAL-138_plus_c000106")
    plusExpectBool(is_equal_to_sum_even(54), true, "CJ-HUMANEVAL-138_plus_c000107")
    plusExpectBool(is_equal_to_sum_even(-68), false, "CJ-HUMANEVAL-138_plus_c000108")
    plusExpectBool(is_equal_to_sum_even(-90), false, "CJ-HUMANEVAL-138_plus_c000109")
    plusExpectBool(is_equal_to_sum_even(-91), false, "CJ-HUMANEVAL-138_plus_c000110")
    plusExpectBool(is_equal_to_sum_even(-78), false, "CJ-HUMANEVAL-138_plus_c000111")
    plusExpectBool(is_equal_to_sum_even(-80), false, "CJ-HUMANEVAL-138_plus_c000112")
    println("CJ-HUMANEVAL-138 Plus ok")
    return 0
}
