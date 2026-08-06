package cangjie_humaneval_019

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
    plusExpectString(sort_numbers("four eight two"), "two four eight", "CJ-HUMANEVAL-019_plus_c000000")
    plusExpectString(sort_numbers("nine"), "nine", "CJ-HUMANEVAL-019_plus_c000001")
    plusExpectString(sort_numbers("one six two four nine"), "one two four six nine", "CJ-HUMANEVAL-019_plus_c000002")
    plusExpectString(sort_numbers("two seven eight zero five"), "zero two five seven eight", "CJ-HUMANEVAL-019_plus_c000003")
    plusExpectString(sort_numbers("nine zero"), "zero nine", "CJ-HUMANEVAL-019_plus_c000004")
    plusExpectString(sort_numbers("seven three one"), "one three seven", "CJ-HUMANEVAL-019_plus_c000005")
    plusExpectString(sort_numbers("two two three three four five six"), "two two three three four five six", "CJ-HUMANEVAL-019_plus_c000006")
    plusExpectString(sort_numbers("zero five four one seven eight two six"), "zero one two four five six seven eight", "CJ-HUMANEVAL-019_plus_c000007")
    plusExpectString(sort_numbers("nine eight seven six five four three two one zero"), "zero one two three four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000008")
    plusExpectString(sort_numbers("two zero nine four five six"), "zero two four five six nine", "CJ-HUMANEVAL-019_plus_c000009")
    plusExpectString(sort_numbers("nine eight seven six five four one zero"), "zero one four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000010")
    plusExpectString(sort_numbers("two zero nine"), "zero two nine", "CJ-HUMANEVAL-019_plus_c000011")
    plusExpectString(sort_numbers("four eight"), "four eight", "CJ-HUMANEVAL-019_plus_c000012")
    plusExpectString(sort_numbers(""), "", "CJ-HUMANEVAL-019_plus_c000013")
    plusExpectString(sort_numbers("zero five four one seven"), "zero one four five seven", "CJ-HUMANEVAL-019_plus_c000014")
    plusExpectString(sort_numbers("six"), "six", "CJ-HUMANEVAL-019_plus_c000015")
    plusExpectString(sort_numbers("two two four five six"), "two two four five six", "CJ-HUMANEVAL-019_plus_c000016")
    plusExpectString(sort_numbers("zero five four one"), "zero one four five", "CJ-HUMANEVAL-019_plus_c000017")
    plusExpectString(sort_numbers("zero five seven"), "zero five seven", "CJ-HUMANEVAL-019_plus_c000018")
    plusExpectString(sort_numbers("four two"), "two four", "CJ-HUMANEVAL-019_plus_c000019")
    plusExpectString(sort_numbers("four"), "four", "CJ-HUMANEVAL-019_plus_c000020")
    plusExpectString(sort_numbers("two six"), "two six", "CJ-HUMANEVAL-019_plus_c000021")
    plusExpectString(sort_numbers("two two five six"), "two two five six", "CJ-HUMANEVAL-019_plus_c000022")
    plusExpectString(sort_numbers("seven"), "seven", "CJ-HUMANEVAL-019_plus_c000023")
    plusExpectString(sort_numbers("zero five four zero five four one seven eight two six"), "zero zero one two four four five five six seven eight", "CJ-HUMANEVAL-019_plus_c000024")
    plusExpectString(sort_numbers("zero five one seven eight two six"), "zero one two five six seven eight", "CJ-HUMANEVAL-019_plus_c000025")
    plusExpectString(sort_numbers("four four eight two"), "two four four eight", "CJ-HUMANEVAL-019_plus_c000026")
    plusExpectString(sort_numbers("seven three"), "three seven", "CJ-HUMANEVAL-019_plus_c000027")
    plusExpectString(sort_numbers("nine eight seven five four three two one zero"), "zero one two three four five seven eight nine", "CJ-HUMANEVAL-019_plus_c000028")
    plusExpectString(sort_numbers("two four five six"), "two four five six", "CJ-HUMANEVAL-019_plus_c000029")
    plusExpectString(sort_numbers("zero four one"), "zero one four", "CJ-HUMANEVAL-019_plus_c000030")
    plusExpectString(sort_numbers("zero seven eight two six"), "zero two six seven eight", "CJ-HUMANEVAL-019_plus_c000031")
    plusExpectString(sort_numbers("zero five eight two six"), "zero two five six eight", "CJ-HUMANEVAL-019_plus_c000032")
    plusExpectString(sort_numbers("zero"), "zero", "CJ-HUMANEVAL-019_plus_c000033")
    plusExpectString(sort_numbers("three"), "three", "CJ-HUMANEVAL-019_plus_c000034")
    plusExpectString(sort_numbers("one six"), "one six", "CJ-HUMANEVAL-019_plus_c000035")
    plusExpectString(sort_numbers("nine six"), "six nine", "CJ-HUMANEVAL-019_plus_c000036")
    plusExpectString(sort_numbers("two seven eight five"), "two five seven eight", "CJ-HUMANEVAL-019_plus_c000037")
    plusExpectString(sort_numbers("two"), "two", "CJ-HUMANEVAL-019_plus_c000038")
    plusExpectString(sort_numbers("two three three four five six"), "two three three four five six", "CJ-HUMANEVAL-019_plus_c000039")
    plusExpectString(sort_numbers("zero five four seven"), "zero four five seven", "CJ-HUMANEVAL-019_plus_c000040")
    plusExpectString(sort_numbers("nine eight seven one zero"), "zero one seven eight nine", "CJ-HUMANEVAL-019_plus_c000041")
    plusExpectString(sort_numbers("four five six"), "four five six", "CJ-HUMANEVAL-019_plus_c000042")
    plusExpectString(sort_numbers("two nine"), "two nine", "CJ-HUMANEVAL-019_plus_c000043")
    plusExpectString(sort_numbers("two two three"), "two two three", "CJ-HUMANEVAL-019_plus_c000044")
    plusExpectString(sort_numbers("nine eight seven six five two one zero"), "zero one two five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000045")
    plusExpectString(sort_numbers("zero five six"), "zero five six", "CJ-HUMANEVAL-019_plus_c000046")
    plusExpectString(sort_numbers("zero five"), "zero five", "CJ-HUMANEVAL-019_plus_c000047")
    plusExpectString(sort_numbers("zero five two six"), "zero two five six", "CJ-HUMANEVAL-019_plus_c000048")
    plusExpectString(sort_numbers("zero five four zero four one seven eight two six"), "zero zero one two four four five six seven eight", "CJ-HUMANEVAL-019_plus_c000049")
    plusExpectString(sort_numbers("four eight two two three"), "two two three four eight", "CJ-HUMANEVAL-019_plus_c000050")
    plusExpectString(sort_numbers("five four one seven eight two six"), "one two four five six seven eight", "CJ-HUMANEVAL-019_plus_c000051")
    plusExpectString(sort_numbers("nine seven six five two one zero"), "zero one two five six seven nine", "CJ-HUMANEVAL-019_plus_c000052")
    plusExpectString(sort_numbers("nine eight seven six zero"), "zero six seven eight nine", "CJ-HUMANEVAL-019_plus_c000053")
    plusExpectString(sort_numbers("two nine seven six five two one zero"), "zero one two two five six seven nine", "CJ-HUMANEVAL-019_plus_c000054")
    plusExpectString(sort_numbers("two four six"), "two four six", "CJ-HUMANEVAL-019_plus_c000055")
    plusExpectString(sort_numbers("nine one zero"), "zero one nine", "CJ-HUMANEVAL-019_plus_c000056")
    plusExpectString(sort_numbers("four six"), "four six", "CJ-HUMANEVAL-019_plus_c000057")
    plusExpectString(sort_numbers("zero five four"), "zero four five", "CJ-HUMANEVAL-019_plus_c000058")
    plusExpectString(sort_numbers("zero two six"), "zero two six", "CJ-HUMANEVAL-019_plus_c000059")
    plusExpectString(sort_numbers("zero five one"), "zero one five", "CJ-HUMANEVAL-019_plus_c000060")
    plusExpectString(sort_numbers("nine six five two one zero"), "zero one two five six nine", "CJ-HUMANEVAL-019_plus_c000061")
    plusExpectString(sort_numbers("two nine eight seven six five four one zero"), "zero one two four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000062")
    plusExpectString(sort_numbers("zero four one seven"), "zero one four seven", "CJ-HUMANEVAL-019_plus_c000063")
    plusExpectString(sort_numbers("two zero nine four zero four one"), "zero zero one two four four nine", "CJ-HUMANEVAL-019_plus_c000064")
    plusExpectString(sort_numbers("one zero five six"), "zero one five six", "CJ-HUMANEVAL-019_plus_c000065")
    plusExpectString(sort_numbers("nine seven six five two zero"), "zero two five six seven nine", "CJ-HUMANEVAL-019_plus_c000066")
    plusExpectString(sort_numbers("two nine eight seven six five four one zero one zero"), "zero zero one one two four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000067")
    plusExpectString(sort_numbers("two nine seven six five two one zero five two six"), "zero one two two two five five six six seven nine", "CJ-HUMANEVAL-019_plus_c000068")
    plusExpectString(sort_numbers("one"), "one", "CJ-HUMANEVAL-019_plus_c000069")
    plusExpectString(sort_numbers("nine eight seven five four three two one"), "one two three four five seven eight nine", "CJ-HUMANEVAL-019_plus_c000070")
    plusExpectString(sort_numbers("two seven"), "two seven", "CJ-HUMANEVAL-019_plus_c000071")
    plusExpectString(sort_numbers("nine eight seven six"), "six seven eight nine", "CJ-HUMANEVAL-019_plus_c000072")
    plusExpectString(sort_numbers("zero five one seven six"), "zero one five six seven", "CJ-HUMANEVAL-019_plus_c000073")
    plusExpectString(sort_numbers("nine one zero five four one seven eight two six"), "zero one one two four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000074")
    plusExpectString(sort_numbers("zero two"), "zero two", "CJ-HUMANEVAL-019_plus_c000075")
    plusExpectString(sort_numbers("two four zero four one"), "zero one two four four", "CJ-HUMANEVAL-019_plus_c000076")
    plusExpectString(sort_numbers("zero five four zero five four one seven"), "zero zero one four four five five seven", "CJ-HUMANEVAL-019_plus_c000077")
    plusExpectString(sort_numbers("two two four five"), "two two four five", "CJ-HUMANEVAL-019_plus_c000078")
    plusExpectString(sort_numbers("zero one seven eight two six"), "zero one two six seven eight", "CJ-HUMANEVAL-019_plus_c000079")
    plusExpectString(sort_numbers("nine two six"), "two six nine", "CJ-HUMANEVAL-019_plus_c000080")
    plusExpectString(sort_numbers("nine one zero five four one six"), "zero one one four five six nine", "CJ-HUMANEVAL-019_plus_c000081")
    plusExpectString(sort_numbers("two two seven eight zero five four five six"), "zero two two four five five six seven eight", "CJ-HUMANEVAL-019_plus_c000082")
    plusExpectString(sort_numbers("two four zero four"), "zero two four four", "CJ-HUMANEVAL-019_plus_c000083")
    plusExpectString(sort_numbers("two zero six"), "zero two six", "CJ-HUMANEVAL-019_plus_c000084")
    plusExpectString(sort_numbers("two three"), "two three", "CJ-HUMANEVAL-019_plus_c000085")
    plusExpectString(sort_numbers("two nine seven six five two one zero four five six"), "zero one two two four five five six six seven nine", "CJ-HUMANEVAL-019_plus_c000086")
    plusExpectString(sort_numbers("nine six five two three three four five six one zero"), "zero one two three three four five five six six nine", "CJ-HUMANEVAL-019_plus_c000087")
    plusExpectString(sort_numbers("nine eight one zero"), "zero one eight nine", "CJ-HUMANEVAL-019_plus_c000088")
    plusExpectString(sort_numbers("two four"), "two four", "CJ-HUMANEVAL-019_plus_c000089")
    plusExpectString(sort_numbers("four two nine eight seven six five four one zero"), "zero one two four four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000090")
    plusExpectString(sort_numbers("two two"), "two two", "CJ-HUMANEVAL-019_plus_c000091")
    plusExpectString(sort_numbers("nine seven six five two one"), "one two five six seven nine", "CJ-HUMANEVAL-019_plus_c000092")
    plusExpectString(sort_numbers("one six two nine"), "one two six nine", "CJ-HUMANEVAL-019_plus_c000093")
    plusExpectString(sort_numbers("zero five four one seven eight six"), "zero one four five six seven eight", "CJ-HUMANEVAL-019_plus_c000094")
    plusExpectString(sort_numbers("nine seven four six"), "four six seven nine", "CJ-HUMANEVAL-019_plus_c000095")
    plusExpectString(sort_numbers("five six"), "five six", "CJ-HUMANEVAL-019_plus_c000096")
    plusExpectString(sort_numbers("two zero nine four one"), "zero one two four nine", "CJ-HUMANEVAL-019_plus_c000097")
    plusExpectString(sort_numbers("zero five four one eight two six"), "zero one two four five six eight", "CJ-HUMANEVAL-019_plus_c000098")
    plusExpectString(sort_numbers("nine one zero five four one"), "zero one one four five nine", "CJ-HUMANEVAL-019_plus_c000099")
    plusExpectString(sort_numbers("one two three four five six seven eight nine"), "one two three four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000100")
    plusExpectString(sort_numbers("nine eight seven six five four three two one"), "one two three four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000101")
    plusExpectString(sort_numbers("five seven eight six nine four zero two one three"), "zero one two three four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000102")
    plusExpectString(sort_numbers("four six nine eight seven one five zero two three"), "zero one two three four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000103")
    plusExpectString(sort_numbers("seven one zero five two four eight six nine three"), "zero one two three four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000104")
    plusExpectString(sort_numbers("zero one two three four five six seven eight nine"), "zero one two three four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000105")
    plusExpectString(sort_numbers("two four six eight zero one three five seven nine"), "zero one two three four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000106")
    plusExpectString(sort_numbers("nine seven five three one eight six four two zero"), "zero one two three four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000107")
    plusExpectString(sort_numbers("one zero three four two six five seven eight nine"), "zero one two three four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000108")
    plusExpectString(sort_numbers("seven five zero four nine eight two six one three"), "zero one two three four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000109")
    plusExpectString(sort_numbers("five"), "five", "CJ-HUMANEVAL-019_plus_c000110")
    plusExpectString(sort_numbers("eight"), "eight", "CJ-HUMANEVAL-019_plus_c000111")
    plusExpectString(sort_numbers("four six nine eight five zero two three"), "zero two three four five six eight nine", "CJ-HUMANEVAL-019_plus_c000112")
    plusExpectString(sort_numbers("one two three three"), "one two three three", "CJ-HUMANEVAL-019_plus_c000113")
    plusExpectString(sort_numbers("two nine eight seven six five four three two one seven nine"), "one two two three four five six seven seven eight nine nine", "CJ-HUMANEVAL-019_plus_c000114")
    plusExpectString(sort_numbers("zero one two five six seven eight nine"), "zero one two five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000115")
    plusExpectString(sort_numbers("five four six nine eight seven one five zero two three two one three"), "zero one one two two three three four five five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000116")
    plusExpectString(sort_numbers("nine eight seven six five four two one"), "one two four five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000117")
    plusExpectString(sort_numbers("one two one four"), "one one two four", "CJ-HUMANEVAL-019_plus_c000118")
    plusExpectString(sort_numbers("one one one one one"), "one one one one one", "CJ-HUMANEVAL-019_plus_c000119")
    plusExpectString(sort_numbers("one two"), "one two", "CJ-HUMANEVAL-019_plus_c000120")
    plusExpectString(sort_numbers("four four two six nine two zero"), "zero two two four four six nine", "CJ-HUMANEVAL-019_plus_c000121")
    plusExpectString(sort_numbers("nine eight seven six five two three two one"), "one two two three five six seven eight nine", "CJ-HUMANEVAL-019_plus_c000122")
    plusExpectString(sort_numbers("nine eight seven two one"), "one two seven eight nine", "CJ-HUMANEVAL-019_plus_c000123")
    plusExpectString(sort_numbers("one zero three nine"), "zero one three nine", "CJ-HUMANEVAL-019_plus_c000124")
    plusExpectString(sort_numbers("nine eight"), "eight nine", "CJ-HUMANEVAL-019_plus_c000125")
    plusExpectString(sort_numbers("seven one zero five three"), "zero one three five seven", "CJ-HUMANEVAL-019_plus_c000126")
    plusExpectString(sort_numbers("zero two three"), "zero two three", "CJ-HUMANEVAL-019_plus_c000127")
    println("CJ-HUMANEVAL-019 Plus ok")
    return 0
}
