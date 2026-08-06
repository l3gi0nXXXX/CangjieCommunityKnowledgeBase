package cangjie_humaneval_100

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

func plusExpectedPile(n: Int64): ArrayList<Int64> { let out = ArrayList<Int64>(); for (j in 0..n) { out.add(n + 2 * j) }; out }
func plusExpectPile(actual: ArrayList<Int64>, n: Int64, label: String): Unit { plusExpectInt64List(actual, plusExpectedPile(n), label) }

main(): Int64 {
    plusExpectPile(make_a_pile(1), 1, "CJ-HUMANEVAL-100_plus_c000000")
    plusExpectPile(make_a_pile(2), 2, "CJ-HUMANEVAL-100_plus_c000001")
    plusExpectPile(make_a_pile(10), 10, "CJ-HUMANEVAL-100_plus_c000002")
    plusExpectPile(make_a_pile(15), 15, "CJ-HUMANEVAL-100_plus_c000003")
    plusExpectPile(make_a_pile(20), 20, "CJ-HUMANEVAL-100_plus_c000004")
    plusExpectPile(make_a_pile(100), 100, "CJ-HUMANEVAL-100_plus_c000005")
    plusExpectPile(make_a_pile(12), 12, "CJ-HUMANEVAL-100_plus_c000006")
    plusExpectPile(make_a_pile(25), 25, "CJ-HUMANEVAL-100_plus_c000007")
    plusExpectPile(make_a_pile(50), 50, "CJ-HUMANEVAL-100_plus_c000008")
    plusExpectPile(make_a_pile(14), 14, "CJ-HUMANEVAL-100_plus_c000009")
    plusExpectPile(make_a_pile(16), 16, "CJ-HUMANEVAL-100_plus_c000010")
    plusExpectPile(make_a_pile(9), 9, "CJ-HUMANEVAL-100_plus_c000011")
    plusExpectPile(make_a_pile(24), 24, "CJ-HUMANEVAL-100_plus_c000012")
    plusExpectPile(make_a_pile(99), 99, "CJ-HUMANEVAL-100_plus_c000013")
    plusExpectPile(make_a_pile(21), 21, "CJ-HUMANEVAL-100_plus_c000014")
    plusExpectPile(make_a_pile(51), 51, "CJ-HUMANEVAL-100_plus_c000015")
    plusExpectPile(make_a_pile(52), 52, "CJ-HUMANEVAL-100_plus_c000016")
    plusExpectPile(make_a_pile(22), 22, "CJ-HUMANEVAL-100_plus_c000017")
    plusExpectPile(make_a_pile(73), 73, "CJ-HUMANEVAL-100_plus_c000018")
    plusExpectPile(make_a_pile(17), 17, "CJ-HUMANEVAL-100_plus_c000019")
    plusExpectPile(make_a_pile(3), 3, "CJ-HUMANEVAL-100_plus_c000020")
    plusExpectPile(make_a_pile(101), 101, "CJ-HUMANEVAL-100_plus_c000021")
    plusExpectPile(make_a_pile(72), 72, "CJ-HUMANEVAL-100_plus_c000022")
    plusExpectPile(make_a_pile(98), 98, "CJ-HUMANEVAL-100_plus_c000023")
    plusExpectPile(make_a_pile(97), 97, "CJ-HUMANEVAL-100_plus_c000024")
    plusExpectPile(make_a_pile(53), 53, "CJ-HUMANEVAL-100_plus_c000025")
    plusExpectPile(make_a_pile(13), 13, "CJ-HUMANEVAL-100_plus_c000026")
    plusExpectPile(make_a_pile(4), 4, "CJ-HUMANEVAL-100_plus_c000027")
    plusExpectPile(make_a_pile(96), 96, "CJ-HUMANEVAL-100_plus_c000028")
    plusExpectPile(make_a_pile(92), 92, "CJ-HUMANEVAL-100_plus_c000029")
    plusExpectPile(make_a_pile(102), 102, "CJ-HUMANEVAL-100_plus_c000030")
    plusExpectPile(make_a_pile(23), 23, "CJ-HUMANEVAL-100_plus_c000031")
    plusExpectPile(make_a_pile(11), 11, "CJ-HUMANEVAL-100_plus_c000032")
    plusExpectPile(make_a_pile(93), 93, "CJ-HUMANEVAL-100_plus_c000033")
    plusExpectPile(make_a_pile(49), 49, "CJ-HUMANEVAL-100_plus_c000034")
    plusExpectPile(make_a_pile(78), 78, "CJ-HUMANEVAL-100_plus_c000035")
    plusExpectPile(make_a_pile(86), 86, "CJ-HUMANEVAL-100_plus_c000036")
    plusExpectPile(make_a_pile(71), 71, "CJ-HUMANEVAL-100_plus_c000037")
    plusExpectPile(make_a_pile(95), 95, "CJ-HUMANEVAL-100_plus_c000038")
    plusExpectPile(make_a_pile(94), 94, "CJ-HUMANEVAL-100_plus_c000039")
    plusExpectPile(make_a_pile(70), 70, "CJ-HUMANEVAL-100_plus_c000040")
    plusExpectPile(make_a_pile(77), 77, "CJ-HUMANEVAL-100_plus_c000041")
    plusExpectPile(make_a_pile(69), 69, "CJ-HUMANEVAL-100_plus_c000042")
    plusExpectPile(make_a_pile(79), 79, "CJ-HUMANEVAL-100_plus_c000043")
    plusExpectPile(make_a_pile(103), 103, "CJ-HUMANEVAL-100_plus_c000044")
    plusExpectPile(make_a_pile(68), 68, "CJ-HUMANEVAL-100_plus_c000045")
    plusExpectPile(make_a_pile(37), 37, "CJ-HUMANEVAL-100_plus_c000046")
    plusExpectPile(make_a_pile(18), 18, "CJ-HUMANEVAL-100_plus_c000047")
    plusExpectPile(make_a_pile(36), 36, "CJ-HUMANEVAL-100_plus_c000048")
    plusExpectPile(make_a_pile(67), 67, "CJ-HUMANEVAL-100_plus_c000049")
    plusExpectPile(make_a_pile(91), 91, "CJ-HUMANEVAL-100_plus_c000050")
    plusExpectPile(make_a_pile(35), 35, "CJ-HUMANEVAL-100_plus_c000051")
    plusExpectPile(make_a_pile(8), 8, "CJ-HUMANEVAL-100_plus_c000052")
    plusExpectPile(make_a_pile(90), 90, "CJ-HUMANEVAL-100_plus_c000053")
    plusExpectPile(make_a_pile(48), 48, "CJ-HUMANEVAL-100_plus_c000054")
    plusExpectPile(make_a_pile(54), 54, "CJ-HUMANEVAL-100_plus_c000055")
    plusExpectPile(make_a_pile(87), 87, "CJ-HUMANEVAL-100_plus_c000056")
    plusExpectPile(make_a_pile(19), 19, "CJ-HUMANEVAL-100_plus_c000057")
    plusExpectPile(make_a_pile(85), 85, "CJ-HUMANEVAL-100_plus_c000058")
    plusExpectPile(make_a_pile(84), 84, "CJ-HUMANEVAL-100_plus_c000059")
    plusExpectPile(make_a_pile(55), 55, "CJ-HUMANEVAL-100_plus_c000060")
    plusExpectPile(make_a_pile(7), 7, "CJ-HUMANEVAL-100_plus_c000061")
    plusExpectPile(make_a_pile(104), 104, "CJ-HUMANEVAL-100_plus_c000062")
    plusExpectPile(make_a_pile(5), 5, "CJ-HUMANEVAL-100_plus_c000063")
    plusExpectPile(make_a_pile(38), 38, "CJ-HUMANEVAL-100_plus_c000064")
    plusExpectPile(make_a_pile(74), 74, "CJ-HUMANEVAL-100_plus_c000065")
    plusExpectPile(make_a_pile(39), 39, "CJ-HUMANEVAL-100_plus_c000066")
    plusExpectPile(make_a_pile(83), 83, "CJ-HUMANEVAL-100_plus_c000067")
    plusExpectPile(make_a_pile(66), 66, "CJ-HUMANEVAL-100_plus_c000068")
    plusExpectPile(make_a_pile(80), 80, "CJ-HUMANEVAL-100_plus_c000069")
    plusExpectPile(make_a_pile(105), 105, "CJ-HUMANEVAL-100_plus_c000070")
    plusExpectPile(make_a_pile(47), 47, "CJ-HUMANEVAL-100_plus_c000071")
    plusExpectPile(make_a_pile(109), 109, "CJ-HUMANEVAL-100_plus_c000072")
    plusExpectPile(make_a_pile(65), 65, "CJ-HUMANEVAL-100_plus_c000073")
    plusExpectPile(make_a_pile(6), 6, "CJ-HUMANEVAL-100_plus_c000074")
    plusExpectPile(make_a_pile(42), 42, "CJ-HUMANEVAL-100_plus_c000075")
    plusExpectPile(make_a_pile(89), 89, "CJ-HUMANEVAL-100_plus_c000076")
    plusExpectPile(make_a_pile(46), 46, "CJ-HUMANEVAL-100_plus_c000077")
    plusExpectPile(make_a_pile(40), 40, "CJ-HUMANEVAL-100_plus_c000078")
    plusExpectPile(make_a_pile(88), 88, "CJ-HUMANEVAL-100_plus_c000079")
    plusExpectPile(make_a_pile(82), 82, "CJ-HUMANEVAL-100_plus_c000080")
    plusExpectPile(make_a_pile(108), 108, "CJ-HUMANEVAL-100_plus_c000081")
    plusExpectPile(make_a_pile(110), 110, "CJ-HUMANEVAL-100_plus_c000082")
    plusExpectPile(make_a_pile(64), 64, "CJ-HUMANEVAL-100_plus_c000083")
    plusExpectPile(make_a_pile(111), 111, "CJ-HUMANEVAL-100_plus_c000084")
    plusExpectPile(make_a_pile(26), 26, "CJ-HUMANEVAL-100_plus_c000085")
    plusExpectPile(make_a_pile(57), 57, "CJ-HUMANEVAL-100_plus_c000086")
    plusExpectPile(make_a_pile(58), 58, "CJ-HUMANEVAL-100_plus_c000087")
    plusExpectPile(make_a_pile(63), 63, "CJ-HUMANEVAL-100_plus_c000088")
    plusExpectPile(make_a_pile(59), 59, "CJ-HUMANEVAL-100_plus_c000089")
    plusExpectPile(make_a_pile(45), 45, "CJ-HUMANEVAL-100_plus_c000090")
    plusExpectPile(make_a_pile(106), 106, "CJ-HUMANEVAL-100_plus_c000091")
    plusExpectPile(make_a_pile(41), 41, "CJ-HUMANEVAL-100_plus_c000092")
    plusExpectPile(make_a_pile(81), 81, "CJ-HUMANEVAL-100_plus_c000093")
    plusExpectPile(make_a_pile(62), 62, "CJ-HUMANEVAL-100_plus_c000094")
    plusExpectPile(make_a_pile(107), 107, "CJ-HUMANEVAL-100_plus_c000095")
    plusExpectPile(make_a_pile(56), 56, "CJ-HUMANEVAL-100_plus_c000096")
    plusExpectPile(make_a_pile(43), 43, "CJ-HUMANEVAL-100_plus_c000097")
    plusExpectPile(make_a_pile(75), 75, "CJ-HUMANEVAL-100_plus_c000098")
    plusExpectPile(make_a_pile(30), 30, "CJ-HUMANEVAL-100_plus_c000099")
    plusExpectPile(make_a_pile(32), 32, "CJ-HUMANEVAL-100_plus_c000100")
    plusExpectPile(make_a_pile(33), 33, "CJ-HUMANEVAL-100_plus_c000101")
    plusExpectPile(make_a_pile(29), 29, "CJ-HUMANEVAL-100_plus_c000102")
    plusExpectPile(make_a_pile(34), 34, "CJ-HUMANEVAL-100_plus_c000103")
    plusExpectPile(make_a_pile(31), 31, "CJ-HUMANEVAL-100_plus_c000104")
    plusExpectPile(make_a_pile(76), 76, "CJ-HUMANEVAL-100_plus_c000105")
    plusExpectPile(make_a_pile(27), 27, "CJ-HUMANEVAL-100_plus_c000106")
    plusExpectPile(make_a_pile(28), 28, "CJ-HUMANEVAL-100_plus_c000107")
    plusExpectPile(make_a_pile(44), 44, "CJ-HUMANEVAL-100_plus_c000108")
    plusExpectPile(make_a_pile(1000000), 1000000, "CJ-HUMANEVAL-100_plus_c000109")
    plusExpectPile(make_a_pile(60), 60, "CJ-HUMANEVAL-100_plus_c000110")
    plusExpectPile(make_a_pile(61), 61, "CJ-HUMANEVAL-100_plus_c000111")
    println("CJ-HUMANEVAL-100 Plus ok")
    return 0
}
