package cangjie_humaneval_055

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
    plusExpectInt64(fib(0), 0, "CJ-HUMANEVAL-055_plus_c000000")
    plusExpectInt64(fib(1), 1, "CJ-HUMANEVAL-055_plus_c000001")
    plusExpectInt64(fib(16), 987, "CJ-HUMANEVAL-055_plus_c000004")
    plusExpectInt64(fib(2), 1, "CJ-HUMANEVAL-055_plus_c000005")
    plusExpectInt64(fib(17), 1597, "CJ-HUMANEVAL-055_plus_c000006")
    plusExpectInt64(fib(15), 610, "CJ-HUMANEVAL-055_plus_c000007")
    plusExpectInt64(fib(14), 377, "CJ-HUMANEVAL-055_plus_c000008")
    plusExpectInt64(fib(63), 6557470319842, "CJ-HUMANEVAL-055_plus_c000009")
    plusExpectInt64(fib(64), 10610209857723, "CJ-HUMANEVAL-055_plus_c000010")
    plusExpectInt64(fib(13), 233, "CJ-HUMANEVAL-055_plus_c000011")
    plusExpectInt64(fib(3), 2, "CJ-HUMANEVAL-055_plus_c000012")
    plusExpectInt64(fib(71), 308061521170129, "CJ-HUMANEVAL-055_plus_c000013")
    plusExpectInt64(fib(72), 498454011879264, "CJ-HUMANEVAL-055_plus_c000014")
    plusExpectInt64(fib(70), 190392490709135, "CJ-HUMANEVAL-055_plus_c000015")
    plusExpectInt64(fib(35), 9227465, "CJ-HUMANEVAL-055_plus_c000016")
    plusExpectInt64(fib(62), 4052739537881, "CJ-HUMANEVAL-055_plus_c000017")
    plusExpectInt64(fib(69), 117669030460994, "CJ-HUMANEVAL-055_plus_c000018")
    plusExpectInt64(fib(12), 144, "CJ-HUMANEVAL-055_plus_c000019")
    plusExpectInt64(fib(36), 14930352, "CJ-HUMANEVAL-055_plus_c000020")
    plusExpectInt64(fib(34), 5702887, "CJ-HUMANEVAL-055_plus_c000021")
    plusExpectInt64(fib(61), 2504730781961, "CJ-HUMANEVAL-055_plus_c000022")
    plusExpectInt64(fib(67), 44945570212853, "CJ-HUMANEVAL-055_plus_c000023")
    plusExpectInt64(fib(4), 3, "CJ-HUMANEVAL-055_plus_c000024")
    plusExpectInt64(fib(5), 5, "CJ-HUMANEVAL-055_plus_c000025")
    plusExpectInt64(fib(11), 89, "CJ-HUMANEVAL-055_plus_c000026")
    plusExpectInt64(fib(66), 27777890035288, "CJ-HUMANEVAL-055_plus_c000027")
    plusExpectInt64(fib(10), 55, "CJ-HUMANEVAL-055_plus_c000028")
    plusExpectInt64(fib(65), 17167680177565, "CJ-HUMANEVAL-055_plus_c000029")
    plusExpectInt64(fib(74), 1304969544928657, "CJ-HUMANEVAL-055_plus_c000030")
    plusExpectInt64(fib(73), 806515533049393, "CJ-HUMANEVAL-055_plus_c000031")
    plusExpectInt64(fib(75), 2111485077978050, "CJ-HUMANEVAL-055_plus_c000032")
    plusExpectInt64(fib(44), 701408733, "CJ-HUMANEVAL-055_plus_c000033")
    plusExpectInt64(fib(28), 317811, "CJ-HUMANEVAL-055_plus_c000034")
    plusExpectInt64(fib(18), 2584, "CJ-HUMANEVAL-055_plus_c000035")
    plusExpectInt64(fib(6), 8, "CJ-HUMANEVAL-055_plus_c000036")
    plusExpectInt64(fib(45), 1134903170, "CJ-HUMANEVAL-055_plus_c000037")
    plusExpectInt64(fib(68), 72723460248141, "CJ-HUMANEVAL-055_plus_c000038")
    plusExpectInt64(fib(8), 21, "CJ-HUMANEVAL-055_plus_c000039")
    plusExpectInt64(fib(29), 514229, "CJ-HUMANEVAL-055_plus_c000040")
    plusExpectInt64(fib(7), 13, "CJ-HUMANEVAL-055_plus_c000041")
    plusExpectInt64(fib(27), 196418, "CJ-HUMANEVAL-055_plus_c000042")
    plusExpectInt64(fib(86), 420196140727489673, "CJ-HUMANEVAL-055_plus_c000043")
    plusExpectInt64(fib(60), 1548008755920, "CJ-HUMANEVAL-055_plus_c000044")
    println("CJ-HUMANEVAL-055 Plus ok")
    return 0
}
