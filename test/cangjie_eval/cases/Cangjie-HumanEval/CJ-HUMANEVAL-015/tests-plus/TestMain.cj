package cangjie_humaneval_015

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

func plusExpectStringSequence(actual: String, n: Int64, label: String): Unit { let expected = StringBuilder(); for (j in 0..=n) { if (j > 0) { expected.append(" ") }; expected.append("${j}") }; plusExpectString(actual, expected.toString(), label) }

main(): Int64 {
    plusExpectStringSequence(string_sequence(1), 1, "CJ-HUMANEVAL-015_plus_c000000")
    plusExpectStringSequence(string_sequence(100), 100, "CJ-HUMANEVAL-015_plus_c000001")
    plusExpectStringSequence(string_sequence(500), 500, "CJ-HUMANEVAL-015_plus_c000002")
    plusExpectStringSequence(string_sequence(2), 2, "CJ-HUMANEVAL-015_plus_c000003")
    plusExpectStringSequence(string_sequence(99), 99, "CJ-HUMANEVAL-015_plus_c000004")
    plusExpectStringSequence(string_sequence(1000), 1000, "CJ-HUMANEVAL-015_plus_c000005")
    plusExpectStringSequence(string_sequence(10000), 10000, "CJ-HUMANEVAL-015_plus_c000006")
    plusExpectStringSequence(string_sequence(15), 15, "CJ-HUMANEVAL-015_plus_c000007")
    plusExpectStringSequence(string_sequence(20), 20, "CJ-HUMANEVAL-015_plus_c000008")
    plusExpectStringSequence(string_sequence(50000), 50000, "CJ-HUMANEVAL-015_plus_c000009")
    plusExpectStringSequence(string_sequence(49999), 49999, "CJ-HUMANEVAL-015_plus_c000010")
    plusExpectStringSequence(string_sequence(101), 101, "CJ-HUMANEVAL-015_plus_c000011")
    plusExpectStringSequence(string_sequence(50001), 50001, "CJ-HUMANEVAL-015_plus_c000012")
    plusExpectStringSequence(string_sequence(102), 102, "CJ-HUMANEVAL-015_plus_c000013")
    plusExpectStringSequence(string_sequence(49998), 49998, "CJ-HUMANEVAL-015_plus_c000014")
    plusExpectStringSequence(string_sequence(1001), 1001, "CJ-HUMANEVAL-015_plus_c000015")
    plusExpectStringSequence(string_sequence(18), 18, "CJ-HUMANEVAL-015_plus_c000016")
    plusExpectStringSequence(string_sequence(37), 37, "CJ-HUMANEVAL-015_plus_c000017")
    plusExpectStringSequence(string_sequence(36), 36, "CJ-HUMANEVAL-015_plus_c000018")
    plusExpectStringSequence(string_sequence(501), 501, "CJ-HUMANEVAL-015_plus_c000019")
    plusExpectStringSequence(string_sequence(84), 84, "CJ-HUMANEVAL-015_plus_c000020")
    plusExpectStringSequence(string_sequence(16), 16, "CJ-HUMANEVAL-015_plus_c000021")
    plusExpectStringSequence(string_sequence(10001), 10001, "CJ-HUMANEVAL-015_plus_c000022")
    plusExpectStringSequence(string_sequence(65), 65, "CJ-HUMANEVAL-015_plus_c000023")
    plusExpectStringSequence(string_sequence(19), 19, "CJ-HUMANEVAL-015_plus_c000024")
    plusExpectStringSequence(string_sequence(66), 66, "CJ-HUMANEVAL-015_plus_c000025")
    plusExpectStringSequence(string_sequence(499), 499, "CJ-HUMANEVAL-015_plus_c000026")
    plusExpectStringSequence(string_sequence(83), 83, "CJ-HUMANEVAL-015_plus_c000027")
    plusExpectStringSequence(string_sequence(21), 21, "CJ-HUMANEVAL-015_plus_c000028")
    plusExpectStringSequence(string_sequence(98), 98, "CJ-HUMANEVAL-015_plus_c000029")
    plusExpectStringSequence(string_sequence(97), 97, "CJ-HUMANEVAL-015_plus_c000030")
    plusExpectStringSequence(string_sequence(17), 17, "CJ-HUMANEVAL-015_plus_c000031")
    plusExpectStringSequence(string_sequence(82), 82, "CJ-HUMANEVAL-015_plus_c000032")
    plusExpectStringSequence(string_sequence(22), 22, "CJ-HUMANEVAL-015_plus_c000033")
    plusExpectStringSequence(string_sequence(999), 999, "CJ-HUMANEVAL-015_plus_c000034")
    plusExpectStringSequence(string_sequence(67), 67, "CJ-HUMANEVAL-015_plus_c000035")
    plusExpectStringSequence(string_sequence(998), 998, "CJ-HUMANEVAL-015_plus_c000036")
    plusExpectStringSequence(string_sequence(50002), 50002, "CJ-HUMANEVAL-015_plus_c000037")
    plusExpectStringSequence(string_sequence(9999), 9999, "CJ-HUMANEVAL-015_plus_c000038")
    plusExpectStringSequence(string_sequence(75), 75, "CJ-HUMANEVAL-015_plus_c000039")
    plusExpectStringSequence(string_sequence(38), 38, "CJ-HUMANEVAL-015_plus_c000040")
    plusExpectStringSequence(string_sequence(498), 498, "CJ-HUMANEVAL-015_plus_c000041")
    plusExpectStringSequence(string_sequence(502), 502, "CJ-HUMANEVAL-015_plus_c000042")
    plusExpectStringSequence(string_sequence(96), 96, "CJ-HUMANEVAL-015_plus_c000043")
    plusExpectStringSequence(string_sequence(23), 23, "CJ-HUMANEVAL-015_plus_c000044")
    plusExpectStringSequence(string_sequence(50003), 50003, "CJ-HUMANEVAL-015_plus_c000045")
    plusExpectStringSequence(string_sequence(9998), 9998, "CJ-HUMANEVAL-015_plus_c000046")
    plusExpectStringSequence(string_sequence(76), 76, "CJ-HUMANEVAL-015_plus_c000047")
    plusExpectStringSequence(string_sequence(14), 14, "CJ-HUMANEVAL-015_plus_c000048")
    plusExpectStringSequence(string_sequence(29), 29, "CJ-HUMANEVAL-015_plus_c000049")
    plusExpectStringSequence(string_sequence(49997), 49997, "CJ-HUMANEVAL-015_plus_c000050")
    plusExpectStringSequence(string_sequence(31), 31, "CJ-HUMANEVAL-015_plus_c000051")
    plusExpectStringSequence(string_sequence(85), 85, "CJ-HUMANEVAL-015_plus_c000052")
    plusExpectStringSequence(string_sequence(9997), 9997, "CJ-HUMANEVAL-015_plus_c000053")
    plusExpectStringSequence(string_sequence(77), 77, "CJ-HUMANEVAL-015_plus_c000054")
    plusExpectStringSequence(string_sequence(503), 503, "CJ-HUMANEVAL-015_plus_c000055")
    plusExpectStringSequence(string_sequence(103), 103, "CJ-HUMANEVAL-015_plus_c000056")
    plusExpectStringSequence(string_sequence(13), 13, "CJ-HUMANEVAL-015_plus_c000057")
    plusExpectStringSequence(string_sequence(30), 30, "CJ-HUMANEVAL-015_plus_c000058")
    plusExpectStringSequence(string_sequence(86), 86, "CJ-HUMANEVAL-015_plus_c000059")
    plusExpectStringSequence(string_sequence(997), 997, "CJ-HUMANEVAL-015_plus_c000060")
    plusExpectStringSequence(string_sequence(1002), 1002, "CJ-HUMANEVAL-015_plus_c000061")
    plusExpectStringSequence(string_sequence(35), 35, "CJ-HUMANEVAL-015_plus_c000062")
    plusExpectStringSequence(string_sequence(1003), 1003, "CJ-HUMANEVAL-015_plus_c000063")
    plusExpectStringSequence(string_sequence(63), 63, "CJ-HUMANEVAL-015_plus_c000064")
    plusExpectStringSequence(string_sequence(39), 39, "CJ-HUMANEVAL-015_plus_c000065")
    plusExpectStringSequence(string_sequence(12), 12, "CJ-HUMANEVAL-015_plus_c000066")
    plusExpectStringSequence(string_sequence(68), 68, "CJ-HUMANEVAL-015_plus_c000067")
    plusExpectStringSequence(string_sequence(24), 24, "CJ-HUMANEVAL-015_plus_c000068")
    plusExpectStringSequence(string_sequence(1004), 1004, "CJ-HUMANEVAL-015_plus_c000069")
    plusExpectStringSequence(string_sequence(3), 3, "CJ-HUMANEVAL-015_plus_c000070")
    plusExpectStringSequence(string_sequence(4), 4, "CJ-HUMANEVAL-015_plus_c000071")
    plusExpectStringSequence(string_sequence(95), 95, "CJ-HUMANEVAL-015_plus_c000072")
    plusExpectStringSequence(string_sequence(78), 78, "CJ-HUMANEVAL-015_plus_c000073")
    plusExpectStringSequence(string_sequence(5), 5, "CJ-HUMANEVAL-015_plus_c000074")
    plusExpectStringSequence(string_sequence(25), 25, "CJ-HUMANEVAL-015_plus_c000075")
    plusExpectStringSequence(string_sequence(28), 28, "CJ-HUMANEVAL-015_plus_c000076")
    plusExpectStringSequence(string_sequence(50004), 50004, "CJ-HUMANEVAL-015_plus_c000077")
    plusExpectStringSequence(string_sequence(104), 104, "CJ-HUMANEVAL-015_plus_c000078")
    plusExpectStringSequence(string_sequence(0), 0, "CJ-HUMANEVAL-015_plus_c000079")
    plusExpectStringSequence(string_sequence(40), 40, "CJ-HUMANEVAL-015_plus_c000080")
    plusExpectStringSequence(string_sequence(9996), 9996, "CJ-HUMANEVAL-015_plus_c000081")
    plusExpectStringSequence(string_sequence(64), 64, "CJ-HUMANEVAL-015_plus_c000082")
    plusExpectStringSequence(string_sequence(74), 74, "CJ-HUMANEVAL-015_plus_c000083")
    plusExpectStringSequence(string_sequence(10002), 10002, "CJ-HUMANEVAL-015_plus_c000084")
    plusExpectStringSequence(string_sequence(94), 94, "CJ-HUMANEVAL-015_plus_c000085")
    plusExpectStringSequence(string_sequence(41), 41, "CJ-HUMANEVAL-015_plus_c000086")
    plusExpectStringSequence(string_sequence(105), 105, "CJ-HUMANEVAL-015_plus_c000087")
    plusExpectStringSequence(string_sequence(32), 32, "CJ-HUMANEVAL-015_plus_c000088")
    plusExpectStringSequence(string_sequence(73), 73, "CJ-HUMANEVAL-015_plus_c000089")
    plusExpectStringSequence(string_sequence(81), 81, "CJ-HUMANEVAL-015_plus_c000090")
    plusExpectStringSequence(string_sequence(26), 26, "CJ-HUMANEVAL-015_plus_c000091")
    plusExpectStringSequence(string_sequence(72), 72, "CJ-HUMANEVAL-015_plus_c000092")
    plusExpectStringSequence(string_sequence(6), 6, "CJ-HUMANEVAL-015_plus_c000093")
    plusExpectStringSequence(string_sequence(996), 996, "CJ-HUMANEVAL-015_plus_c000094")
    plusExpectStringSequence(string_sequence(42), 42, "CJ-HUMANEVAL-015_plus_c000095")
    plusExpectStringSequence(string_sequence(93), 93, "CJ-HUMANEVAL-015_plus_c000096")
    plusExpectStringSequence(string_sequence(79), 79, "CJ-HUMANEVAL-015_plus_c000097")
    plusExpectStringSequence(string_sequence(1000000), 1000000, "CJ-HUMANEVAL-015_plus_c000098")
    plusExpectStringSequence(string_sequence(1000001), 1000001, "CJ-HUMANEVAL-015_plus_c000099")
    plusExpectStringSequence(string_sequence(1000002), 1000002, "CJ-HUMANEVAL-015_plus_c000100")
    plusExpectStringSequence(string_sequence(999999), 999999, "CJ-HUMANEVAL-015_plus_c000101")
    plusExpectStringSequence(string_sequence(1000003), 1000003, "CJ-HUMANEVAL-015_plus_c000102")
    plusExpectStringSequence(string_sequence(1000004), 1000004, "CJ-HUMANEVAL-015_plus_c000103")
    plusExpectStringSequence(string_sequence(34), 34, "CJ-HUMANEVAL-015_plus_c000104")
    plusExpectStringSequence(string_sequence(33), 33, "CJ-HUMANEVAL-015_plus_c000105")
    plusExpectStringSequence(string_sequence(27), 27, "CJ-HUMANEVAL-015_plus_c000106")
    plusExpectStringSequence(string_sequence(999998), 999998, "CJ-HUMANEVAL-015_plus_c000107")
    plusExpectStringSequence(string_sequence(1000005), 1000005, "CJ-HUMANEVAL-015_plus_c000108")
    plusExpectStringSequence(string_sequence(999997), 999997, "CJ-HUMANEVAL-015_plus_c000109")
    plusExpectStringSequence(string_sequence(87), 87, "CJ-HUMANEVAL-015_plus_c000110")
    plusExpectStringSequence(string_sequence(88), 88, "CJ-HUMANEVAL-015_plus_c000111")
    plusExpectStringSequence(string_sequence(89), 89, "CJ-HUMANEVAL-015_plus_c000112")
    plusExpectStringSequence(string_sequence(90), 90, "CJ-HUMANEVAL-015_plus_c000113")
    plusExpectStringSequence(string_sequence(1000006), 1000006, "CJ-HUMANEVAL-015_plus_c000114")
    plusExpectStringSequence(string_sequence(999996), 999996, "CJ-HUMANEVAL-015_plus_c000115")
    plusExpectStringSequence(string_sequence(999995), 999995, "CJ-HUMANEVAL-015_plus_c000116")
    plusExpectStringSequence(string_sequence(1000007), 1000007, "CJ-HUMANEVAL-015_plus_c000117")
    plusExpectStringSequence(string_sequence(7), 7, "CJ-HUMANEVAL-015_plus_c000118")
    plusExpectStringSequence(string_sequence(43), 43, "CJ-HUMANEVAL-015_plus_c000119")
    plusExpectStringSequence(string_sequence(44), 44, "CJ-HUMANEVAL-015_plus_c000120")
    plusExpectStringSequence(string_sequence(45), 45, "CJ-HUMANEVAL-015_plus_c000121")
    plusExpectStringSequence(string_sequence(999994), 999994, "CJ-HUMANEVAL-015_plus_c000122")
    plusExpectStringSequence(string_sequence(999993), 999993, "CJ-HUMANEVAL-015_plus_c000123")
    plusExpectStringSequence(string_sequence(1000008), 1000008, "CJ-HUMANEVAL-015_plus_c000124")
    plusExpectStringSequence(string_sequence(999992), 999992, "CJ-HUMANEVAL-015_plus_c000125")
    plusExpectStringSequence(string_sequence(62), 62, "CJ-HUMANEVAL-015_plus_c000126")
    plusExpectStringSequence(string_sequence(61), 61, "CJ-HUMANEVAL-015_plus_c000127")
    plusExpectStringSequence(string_sequence(60), 60, "CJ-HUMANEVAL-015_plus_c000128")
    plusExpectStringSequence(string_sequence(59), 59, "CJ-HUMANEVAL-015_plus_c000129")
    plusExpectStringSequence(string_sequence(1000010), 1000010, "CJ-HUMANEVAL-015_plus_c000130")
    plusExpectStringSequence(string_sequence(999991), 999991, "CJ-HUMANEVAL-015_plus_c000131")
    plusExpectStringSequence(string_sequence(1000009), 1000009, "CJ-HUMANEVAL-015_plus_c000132")
    plusExpectStringSequence(string_sequence(1000011), 1000011, "CJ-HUMANEVAL-015_plus_c000133")
    println("CJ-HUMANEVAL-015 Plus ok")
    return 0
}
