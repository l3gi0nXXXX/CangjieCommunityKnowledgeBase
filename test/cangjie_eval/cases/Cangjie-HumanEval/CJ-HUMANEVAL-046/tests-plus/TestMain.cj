package cangjie_humaneval_046

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
    plusExpectInt64(fib4(1), 0, "CJ-HUMANEVAL-046_plus_c000000")
    plusExpectInt64(fib4(2), 2, "CJ-HUMANEVAL-046_plus_c000001")
    plusExpectInt64(fib4(3), 0, "CJ-HUMANEVAL-046_plus_c000002")
    plusExpectInt64(fib4(4), 2, "CJ-HUMANEVAL-046_plus_c000003")
    plusExpectInt64(fib4(6), 8, "CJ-HUMANEVAL-046_plus_c000004")
    plusExpectInt64(fib4(7), 14, "CJ-HUMANEVAL-046_plus_c000005")
    plusExpectInt64(fib4(9), 54, "CJ-HUMANEVAL-046_plus_c000006")
    plusExpectInt64(fib4(11), 200, "CJ-HUMANEVAL-046_plus_c000007")
    plusExpectInt64(fib4(15), 2764, "CJ-HUMANEVAL-046_plus_c000008")
    plusExpectInt64(fib4(20), 73552, "CJ-HUMANEVAL-046_plus_c000009")
    plusExpectInt64(fib4(5), 4, "CJ-HUMANEVAL-046_plus_c000010")
    plusExpectInt64(fib4(19), 38158, "CJ-HUMANEVAL-046_plus_c000011")
    plusExpectInt64(fib4(21), 141776, "CJ-HUMANEVAL-046_plus_c000012")
    plusExpectInt64(fib4(16), 5328, "CJ-HUMANEVAL-046_plus_c000013")
    plusExpectInt64(fib4(17), 10270, "CJ-HUMANEVAL-046_plus_c000014")
    plusExpectInt64(fib4(14), 1434, "CJ-HUMANEVAL-046_plus_c000015")
    plusExpectInt64(fib4(18), 19796, "CJ-HUMANEVAL-046_plus_c000016")
    plusExpectInt64(fib4(22), 273282, "CJ-HUMANEVAL-046_plus_c000017")
    plusExpectInt64(fib4(10), 104, "CJ-HUMANEVAL-046_plus_c000018")
    plusExpectInt64(fib4(8), 28, "CJ-HUMANEVAL-046_plus_c000019")
    plusExpectInt64(fib4(0), 0, "CJ-HUMANEVAL-046_plus_c000020")
    plusExpectInt64(fib4(12), 386, "CJ-HUMANEVAL-046_plus_c000021")
    plusExpectInt64(fib4(13), 744, "CJ-HUMANEVAL-046_plus_c000022")
    plusExpectInt64(fib4(23), 526768, "CJ-HUMANEVAL-046_plus_c000023")
    plusExpectInt64(fib4(24), 1015378, "CJ-HUMANEVAL-046_plus_c000024")
    plusExpectInt64(fib4(41), 71083647136, "CJ-HUMANEVAL-046_plus_c000025")
    plusExpectInt64(fib4(25), 1957204, "CJ-HUMANEVAL-046_plus_c000026")
    plusExpectInt64(fib4(26), 3772632, "CJ-HUMANEVAL-046_plus_c000028")
    plusExpectInt64(fib4(27), 7271982, "CJ-HUMANEVAL-046_plus_c000029")
    plusExpectInt64(fib4(40), 36877489824, "CJ-HUMANEVAL-046_plus_c000033")
    plusExpectInt64(fib4(39), 19131675294, "CJ-HUMANEVAL-046_plus_c000037")
    plusExpectInt64(fib4(28), 14017196, "CJ-HUMANEVAL-046_plus_c000039")
    plusExpectInt64(fib4(29), 27019014, "CJ-HUMANEVAL-046_plus_c000040")
    plusExpectInt64(fib4(30), 52080824, "CJ-HUMANEVAL-046_plus_c000044")
    plusExpectInt64(fib4(31), 100389016, "CJ-HUMANEVAL-046_plus_c000047")
    plusExpectInt64(fib4(32), 193506050, "CJ-HUMANEVAL-046_plus_c000048")
    plusExpectInt64(fib4(33), 372994904, "CJ-HUMANEVAL-046_plus_c000049")
    plusExpectInt64(fib4(34), 718970794, "CJ-HUMANEVAL-046_plus_c000050")
    plusExpectInt64(fib4(42), 137018135298, "CJ-HUMANEVAL-046_plus_c000051")
    plusExpectInt64(fib4(43), 264110947552, "CJ-HUMANEVAL-046_plus_c000052")
    plusExpectInt64(fib4(38), 9925323044, "CJ-HUMANEVAL-046_plus_c000057")
    plusExpectInt64(fib4(37), 5149158974, "CJ-HUMANEVAL-046_plus_c000062")
    plusExpectInt64(fib4(44), 509090219810, "CJ-HUMANEVAL-046_plus_c000063")
    plusExpectInt64(fib4(35), 1385860764, "CJ-HUMANEVAL-046_plus_c000064")
    plusExpectInt64(fib4(45), 981302949796, "CJ-HUMANEVAL-046_plus_c000065")
    plusExpectInt64(fib4(36), 2671332512, "CJ-HUMANEVAL-046_plus_c000068")
    plusExpectInt64(fib4(50), 26112283777288, "CJ-HUMANEVAL-046_plus_c000074")
    plusExpectInt64(fib4(46), 1891522252456, "CJ-HUMANEVAL-046_plus_c000075")
    plusExpectInt64(fib4(49), 13546793363542, "CJ-HUMANEVAL-046_plus_c000076")
    plusExpectInt64(fib4(51), 50333045302120, "CJ-HUMANEVAL-046_plus_c000077")
    plusExpectInt64(fib4(47), 3646026369614, "CJ-HUMANEVAL-046_plus_c000078")
    plusExpectInt64(fib4(52), 97020064234626, "CJ-HUMANEVAL-046_plus_c000081")
    plusExpectInt64(fib4(48), 7027941791676, "CJ-HUMANEVAL-046_plus_c000082")
    plusExpectInt64(fib4(53), 187012186677576, "CJ-HUMANEVAL-046_plus_c000083")
    plusExpectInt64(fib4(54), 360477579991610, "CJ-HUMANEVAL-046_plus_c000086")
    plusExpectInt64(fib4(68), 3523669487722032972, "CJ-HUMANEVAL-046_plus_c000093")
    plusExpectInt64(fib4(67), 1828044717908083822, "CJ-HUMANEVAL-046_plus_c000094")
    plusExpectInt64(fib4(55), 694842876205932, "CJ-HUMANEVAL-046_plus_c000097")
    plusExpectInt64(fib4(61), 35639919326849136, "CJ-HUMANEVAL-046_plus_c000113")
    plusExpectInt64(fib4(62), 68698153303713410, "CJ-HUMANEVAL-046_plus_c000114")
    plusExpectInt64(fib4(63), 132419948094134672, "CJ-HUMANEVAL-046_plus_c000115")
    plusExpectInt64(fib4(64), 255247656741676658, "CJ-HUMANEVAL-046_plus_c000116")
    plusExpectInt64(fib4(66), 948371435605898616, "CJ-HUMANEVAL-046_plus_c000122")
    plusExpectInt64(fib4(65), 492005677466373876, "CJ-HUMANEVAL-046_plus_c000123")
    println("CJ-HUMANEVAL-046 Plus ok")
    return 0
}
