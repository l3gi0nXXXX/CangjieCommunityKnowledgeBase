package cangjie_humaneval_130

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

func plusExpectedTri(n: Int64): ArrayList<Float64> { let out = ArrayList<Float64>(); out.add(1.0); if (n == 0) { return out }; out.add(3.0); for (j in 2..=n) { if (j % 2 == 0) { out.add(1.0 + Float64(j) / 2.0) } else { out.add(out[out.size - 1] + out[out.size - 2] + 1.0 + Float64(j + 1) / 2.0) } }; out }
func plusExpectTri(actual: ArrayList<Float64>, n: Int64, atol: Float64, label: String): Unit { plusExpectFloatList(actual, plusExpectedTri(n), atol, label) }

main(): Int64 {
    plusExpectTri(tri(2), 2, 0.0, "CJ-HUMANEVAL-130_plus_c000000")
    plusExpectTri(tri(10), 10, 0.0, "CJ-HUMANEVAL-130_plus_c000001")
    plusExpectTri(tri(15), 15, 0.0, "CJ-HUMANEVAL-130_plus_c000002")
    plusExpectTri(tri(25), 25, 0.0, "CJ-HUMANEVAL-130_plus_c000003")
    plusExpectTri(tri(13), 13, 0.0, "CJ-HUMANEVAL-130_plus_c000004")
    plusExpectTri(tri(12), 12, 0.0, "CJ-HUMANEVAL-130_plus_c000005")
    plusExpectTri(tri(30), 30, 0.0, "CJ-HUMANEVAL-130_plus_c000006")
    plusExpectTri(tri(100), 100, 0.0, "CJ-HUMANEVAL-130_plus_c000007")
    plusExpectTri(tri(35), 35, 0.0, "CJ-HUMANEVAL-130_plus_c000008")
    plusExpectTri(tri(50), 50, 0.0, "CJ-HUMANEVAL-130_plus_c000009")
    plusExpectTri(tri(99), 99, 0.0, "CJ-HUMANEVAL-130_plus_c000010")
    plusExpectTri(tri(29), 29, 0.0, "CJ-HUMANEVAL-130_plus_c000011")
    plusExpectTri(tri(24), 24, 0.0, "CJ-HUMANEVAL-130_plus_c000012")
    plusExpectTri(tri(51), 51, 0.0, "CJ-HUMANEVAL-130_plus_c000013")
    plusExpectTri(tri(3), 3, 0.0, "CJ-HUMANEVAL-130_plus_c000014")
    plusExpectTri(tri(1), 1, 0.0, "CJ-HUMANEVAL-130_plus_c000015")
    plusExpectTri(tri(16), 16, 0.0, "CJ-HUMANEVAL-130_plus_c000016")
    plusExpectTri(tri(14), 14, 0.0, "CJ-HUMANEVAL-130_plus_c000017")
    plusExpectTri(tri(26), 26, 0.0, "CJ-HUMANEVAL-130_plus_c000018")
    plusExpectTri(tri(17), 17, 0.0, "CJ-HUMANEVAL-130_plus_c000019")
    plusExpectTri(tri(18), 18, 0.0, "CJ-HUMANEVAL-130_plus_c000020")
    plusExpectTri(tri(23), 23, 0.0, "CJ-HUMANEVAL-130_plus_c000021")
    plusExpectTri(tri(49), 49, 0.0, "CJ-HUMANEVAL-130_plus_c000022")
    plusExpectTri(tri(34), 34, 0.0, "CJ-HUMANEVAL-130_plus_c000023")
    plusExpectTri(tri(98), 98, 0.0, "CJ-HUMANEVAL-130_plus_c000024")
    plusExpectTri(tri(11), 11, 0.0, "CJ-HUMANEVAL-130_plus_c000025")
    plusExpectTri(tri(0), 0, 0.0, "CJ-HUMANEVAL-130_plus_c000026")
    plusExpectTri(tri(28), 28, 0.0, "CJ-HUMANEVAL-130_plus_c000027")
    plusExpectTri(tri(20), 20, 0.0, "CJ-HUMANEVAL-130_plus_c000028")
    plusExpectTri(tri(36), 36, 0.0, "CJ-HUMANEVAL-130_plus_c000029")
    plusExpectTri(tri(22), 22, 0.0, "CJ-HUMANEVAL-130_plus_c000030")
    plusExpectTri(tri(101), 101, 0.0, "CJ-HUMANEVAL-130_plus_c000031")
    plusExpectTri(tri(4), 4, 0.0, "CJ-HUMANEVAL-130_plus_c000032")
    plusExpectTri(tri(102), 102, 0.0, "CJ-HUMANEVAL-130_plus_c000033")
    plusExpectTri(tri(5), 5, 0.0, "CJ-HUMANEVAL-130_plus_c000034")
    plusExpectTri(tri(33), 33, 0.0, "CJ-HUMANEVAL-130_plus_c000035")
    plusExpectTri(tri(31), 31, 0.0, "CJ-HUMANEVAL-130_plus_c000036")
    plusExpectTri(tri(27), 27, 0.0, "CJ-HUMANEVAL-130_plus_c000037")
    plusExpectTri(tri(21), 21, 0.0, "CJ-HUMANEVAL-130_plus_c000038")
    plusExpectTri(tri(97), 97, 0.0, "CJ-HUMANEVAL-130_plus_c000039")
    plusExpectTri(tri(6), 6, 0.0, "CJ-HUMANEVAL-130_plus_c000040")
    plusExpectTri(tri(32), 32, 0.0, "CJ-HUMANEVAL-130_plus_c000041")
    plusExpectTri(tri(52), 52, 0.0, "CJ-HUMANEVAL-130_plus_c000042")
    plusExpectTri(tri(48), 48, 0.0, "CJ-HUMANEVAL-130_plus_c000043")
    plusExpectTri(tri(53), 53, 0.0, "CJ-HUMANEVAL-130_plus_c000044")
    plusExpectTri(tri(47), 47, 0.0, "CJ-HUMANEVAL-130_plus_c000045")
    plusExpectTri(tri(19), 19, 0.0, "CJ-HUMANEVAL-130_plus_c000046")
    plusExpectTri(tri(103), 103, 0.0, "CJ-HUMANEVAL-130_plus_c000047")
    plusExpectTri(tri(9), 9, 0.0, "CJ-HUMANEVAL-130_plus_c000048")
    plusExpectTri(tri(88), 88, 0.0, "CJ-HUMANEVAL-130_plus_c000049")
    plusExpectTri(tri(87), 87, 0.0, "CJ-HUMANEVAL-130_plus_c000050")
    plusExpectTri(tri(89), 89, 0.0, "CJ-HUMANEVAL-130_plus_c000051")
    plusExpectTri(tri(7), 7, 0.0, "CJ-HUMANEVAL-130_plus_c000052")
    plusExpectTri(tri(96), 96, 0.0, "CJ-HUMANEVAL-130_plus_c000053")
    plusExpectTri(tri(95), 95, 0.0, "CJ-HUMANEVAL-130_plus_c000054")
    plusExpectTri(tri(46), 46, 0.0, "CJ-HUMANEVAL-130_plus_c000055")
    plusExpectTri(tri(45), 45, 0.0, "CJ-HUMANEVAL-130_plus_c000056")
    plusExpectTri(tri(8), 8, 0.0, "CJ-HUMANEVAL-130_plus_c000057")
    plusExpectTri(tri(44), 44, 0.0, "CJ-HUMANEVAL-130_plus_c000058")
    plusExpectTri(tri(94), 94, 0.0, "CJ-HUMANEVAL-130_plus_c000059")
    plusExpectTri(tri(104), 104, 0.0, "CJ-HUMANEVAL-130_plus_c000060")
    plusExpectTri(tri(85), 85, 0.0, "CJ-HUMANEVAL-130_plus_c000061")
    plusExpectTri(tri(37), 37, 0.0, "CJ-HUMANEVAL-130_plus_c000062")
    plusExpectTri(tri(86), 86, 0.0, "CJ-HUMANEVAL-130_plus_c000063")
    plusExpectTri(tri(43), 43, 0.0, "CJ-HUMANEVAL-130_plus_c000064")
    plusExpectTri(tri(105), 105, 0.0, "CJ-HUMANEVAL-130_plus_c000065")
    plusExpectTri(tri(42), 42, 0.0, "CJ-HUMANEVAL-130_plus_c000066")
    plusExpectTri(tri(84), 84, 0.0, "CJ-HUMANEVAL-130_plus_c000067")
    plusExpectTri(tri(38), 38, 0.0, "CJ-HUMANEVAL-130_plus_c000068")
    plusExpectTri(tri(39), 39, 0.0, "CJ-HUMANEVAL-130_plus_c000069")
    plusExpectTri(tri(106), 106, 0.0, "CJ-HUMANEVAL-130_plus_c000070")
    plusExpectTri(tri(83), 83, 0.0, "CJ-HUMANEVAL-130_plus_c000071")
    plusExpectTri(tri(82), 82, 0.0, "CJ-HUMANEVAL-130_plus_c000072")
    plusExpectTri(tri(93), 93, 0.0, "CJ-HUMANEVAL-130_plus_c000073")
    plusExpectTri(tri(108), 108, 0.0, "CJ-HUMANEVAL-130_plus_c000074")
    plusExpectTri(tri(81), 81, 0.0, "CJ-HUMANEVAL-130_plus_c000075")
    plusExpectTri(tri(41), 41, 0.0, "CJ-HUMANEVAL-130_plus_c000076")
    plusExpectTri(tri(64), 64, 0.0, "CJ-HUMANEVAL-130_plus_c000077")
    plusExpectTri(tri(40), 40, 0.0, "CJ-HUMANEVAL-130_plus_c000078")
    plusExpectTri(tri(90), 90, 0.0, "CJ-HUMANEVAL-130_plus_c000079")
    plusExpectTri(tri(54), 54, 0.0, "CJ-HUMANEVAL-130_plus_c000080")
    plusExpectTri(tri(65), 65, 0.0, "CJ-HUMANEVAL-130_plus_c000081")
    plusExpectTri(tri(66), 66, 0.0, "CJ-HUMANEVAL-130_plus_c000082")
    plusExpectTri(tri(91), 91, 0.0, "CJ-HUMANEVAL-130_plus_c000083")
    plusExpectTri(tri(63), 63, 0.0, "CJ-HUMANEVAL-130_plus_c000084")
    plusExpectTri(tri(107), 107, 0.0, "CJ-HUMANEVAL-130_plus_c000085")
    plusExpectTri(tri(67), 67, 0.0, "CJ-HUMANEVAL-130_plus_c000086")
    plusExpectTri(tri(92), 92, 0.0, "CJ-HUMANEVAL-130_plus_c000087")
    plusExpectTri(tri(109), 109, 0.0, "CJ-HUMANEVAL-130_plus_c000088")
    plusExpectTri(tri(80), 80, 0.0, "CJ-HUMANEVAL-130_plus_c000089")
    plusExpectTri(tri(62), 62, 0.0, "CJ-HUMANEVAL-130_plus_c000090")
    plusExpectTri(tri(61), 61, 0.0, "CJ-HUMANEVAL-130_plus_c000091")
    plusExpectTri(tri(55), 55, 0.0, "CJ-HUMANEVAL-130_plus_c000092")
    plusExpectTri(tri(75), 75, 0.0, "CJ-HUMANEVAL-130_plus_c000093")
    plusExpectTri(tri(79), 79, 0.0, "CJ-HUMANEVAL-130_plus_c000094")
    plusExpectTri(tri(68), 68, 0.0, "CJ-HUMANEVAL-130_plus_c000095")
    plusExpectTri(tri(111), 111, 0.0, "CJ-HUMANEVAL-130_plus_c000096")
    plusExpectTri(tri(110), 110, 0.0, "CJ-HUMANEVAL-130_plus_c000097")
    plusExpectTri(tri(1000000), 1000000, 0.0, "CJ-HUMANEVAL-130_plus_c000098")
    plusExpectTri(tri(74), 74, 0.0, "CJ-HUMANEVAL-130_plus_c000099")
    plusExpectTri(tri(73), 73, 0.0, "CJ-HUMANEVAL-130_plus_c000100")
    plusExpectTri(tri(1000001), 1000001, 0.0, "CJ-HUMANEVAL-130_plus_c000101")
    plusExpectTri(tri(999999), 999999, 0.0, "CJ-HUMANEVAL-130_plus_c000102")
    plusExpectTri(tri(999997), 999997, 0.0, "CJ-HUMANEVAL-130_plus_c000103")
    plusExpectTri(tri(999998), 999998, 0.0, "CJ-HUMANEVAL-130_plus_c000104")
    plusExpectTri(tri(999996), 999996, 0.0, "CJ-HUMANEVAL-130_plus_c000105")
    plusExpectTri(tri(999995), 999995, 0.0, "CJ-HUMANEVAL-130_plus_c000106")
    plusExpectTri(tri(76), 76, 0.0, "CJ-HUMANEVAL-130_plus_c000107")
    plusExpectTri(tri(77), 77, 0.0, "CJ-HUMANEVAL-130_plus_c000108")
    plusExpectTri(tri(78), 78, 0.0, "CJ-HUMANEVAL-130_plus_c000109")
    plusExpectTri(tri(71), 71, 0.0, "CJ-HUMANEVAL-130_plus_c000110")
    plusExpectTri(tri(72), 72, 0.0, "CJ-HUMANEVAL-130_plus_c000111")
    plusExpectTri(tri(1000002), 1000002, 0.0, "CJ-HUMANEVAL-130_plus_c000112")
    plusExpectTri(tri(1000003), 1000003, 0.0, "CJ-HUMANEVAL-130_plus_c000113")
    plusExpectTri(tri(1000004), 1000004, 0.0, "CJ-HUMANEVAL-130_plus_c000114")
    println("CJ-HUMANEVAL-130 Plus ok")
    return 0
}
