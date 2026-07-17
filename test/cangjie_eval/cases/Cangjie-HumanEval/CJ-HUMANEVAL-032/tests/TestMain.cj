package cangjie_humaneval_032

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
func polynomialValue(coefficients: ArrayList<Int64>, x: Float64): Float64 {
    var result: Float64 = 0.0
    var i = coefficients.size
    while (i > 0) {
        i -= 1
        result = result * x + Float64(coefficients[i])
    }
    return result
}
func expectPolynomialRoot(values: Array<Int64>, label: String): Unit {
    let original = listOfInt64(values)
    let candidateInput = listOfInt64(values)
    let actual = find_zero(candidateInput)
    let residual = abs(polynomialValue(original, actual))
    if (!(residual < 0.0001)) {
        cjeFail(label, "expected polynomial residual below 0.0001, actual ${residual}")
    }
}
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
    expectPolynomialRoot([-10, -2], "CJ-HUMANEVAL-032_l19_c001")
    expectPolynomialRoot([-3, -6, -7, 7], "CJ-HUMANEVAL-032_l19_c002")
    expectPolynomialRoot([8, 3], "CJ-HUMANEVAL-032_l19_c003")
    expectPolynomialRoot([-10, -8], "CJ-HUMANEVAL-032_l19_c004")
    expectPolynomialRoot([-3, 6, 9, -10], "CJ-HUMANEVAL-032_l19_c005")
    expectPolynomialRoot([10, 7, 3, -3], "CJ-HUMANEVAL-032_l19_c006")
    expectPolynomialRoot([8, -2, -10, -5, 3, 1, -2, -6], "CJ-HUMANEVAL-032_l19_c007")
    expectPolynomialRoot([1, -7, -8, 2], "CJ-HUMANEVAL-032_l19_c008")
    expectPolynomialRoot([1, 1], "CJ-HUMANEVAL-032_l19_c009")
    expectPolynomialRoot([-9, 4, 7, -7, 2, -8], "CJ-HUMANEVAL-032_l19_c010")
    expectPolynomialRoot([10, 9, 1, 8, -4, -8], "CJ-HUMANEVAL-032_l19_c011")
    expectPolynomialRoot([-3, -1], "CJ-HUMANEVAL-032_l19_c012")
    expectPolynomialRoot([-3, -7], "CJ-HUMANEVAL-032_l19_c013")
    expectPolynomialRoot([-2, 4, 10, 1, -5, 1, 1, -4], "CJ-HUMANEVAL-032_l19_c014")
    expectPolynomialRoot([10, -8, 9, 10, -5, 7], "CJ-HUMANEVAL-032_l19_c015")
    expectPolynomialRoot([-5, 4, 2, -2], "CJ-HUMANEVAL-032_l19_c016")
    expectPolynomialRoot([1, -9, -3, -9], "CJ-HUMANEVAL-032_l19_c017")
    expectPolynomialRoot([2, -2, -8, -4, 8, 1], "CJ-HUMANEVAL-032_l19_c018")
    expectPolynomialRoot([10, 5, 2, 10], "CJ-HUMANEVAL-032_l19_c019")
    expectPolynomialRoot([-6, -2, -6, -3, 7, 7, -2, 8], "CJ-HUMANEVAL-032_l19_c020")
    expectPolynomialRoot([8, 2, 1, -3, -6, 6, 5, -8], "CJ-HUMANEVAL-032_l19_c021")
    expectPolynomialRoot([-7, -6], "CJ-HUMANEVAL-032_l19_c022")
    expectPolynomialRoot([3, 9, -8, 2], "CJ-HUMANEVAL-032_l19_c023")
    expectPolynomialRoot([9, 4, 6, -2, 7, -10, -7, 7], "CJ-HUMANEVAL-032_l19_c024")
    expectPolynomialRoot([10, 1, -7, -1, 3, -5], "CJ-HUMANEVAL-032_l19_c025")
    expectPolynomialRoot([-10, -2, 6, -5, 6, -7, 10, -1], "CJ-HUMANEVAL-032_l19_c026")
    expectPolynomialRoot([-6, 1, -5, 7], "CJ-HUMANEVAL-032_l19_c027")
    expectPolynomialRoot([9, 1], "CJ-HUMANEVAL-032_l19_c028")
    expectPolynomialRoot([-10, -7, 1, -1, -3, -9, -3, 8], "CJ-HUMANEVAL-032_l19_c029")
    expectPolynomialRoot([-8, 5], "CJ-HUMANEVAL-032_l19_c030")
    expectPolynomialRoot([7, -6], "CJ-HUMANEVAL-032_l19_c031")
    expectPolynomialRoot([5, 7, -5, -2], "CJ-HUMANEVAL-032_l19_c032")
    expectPolynomialRoot([-4, 7, -4, -1, 2, 10, 1, 4], "CJ-HUMANEVAL-032_l19_c033")
    expectPolynomialRoot([-7, -3, -3, -8, 1, -10, 8, 7], "CJ-HUMANEVAL-032_l19_c034")
    expectPolynomialRoot([8, -3, -10, -8], "CJ-HUMANEVAL-032_l19_c035")
    expectPolynomialRoot([-3, -8], "CJ-HUMANEVAL-032_l19_c036")
    expectPolynomialRoot([1, -8], "CJ-HUMANEVAL-032_l19_c037")
    expectPolynomialRoot([-2, 5, -4, 7], "CJ-HUMANEVAL-032_l19_c038")
    expectPolynomialRoot([8, 8, 5, -3], "CJ-HUMANEVAL-032_l19_c039")
    expectPolynomialRoot([3, -4, -7, -7, 3, 1, 3, 3], "CJ-HUMANEVAL-032_l19_c040")
    expectPolynomialRoot([-9, 10, 10, -7, -9, 2, 1, -7], "CJ-HUMANEVAL-032_l19_c041")
    expectPolynomialRoot([-4, -4, 7, 4], "CJ-HUMANEVAL-032_l19_c042")
    expectPolynomialRoot([3, -5, -2, 4], "CJ-HUMANEVAL-032_l19_c043")
    expectPolynomialRoot([-8, 4, 7, -7], "CJ-HUMANEVAL-032_l19_c044")
    expectPolynomialRoot([10, 7], "CJ-HUMANEVAL-032_l19_c045")
    expectPolynomialRoot([-8, -3], "CJ-HUMANEVAL-032_l19_c046")
    expectPolynomialRoot([3, 5, 5, -4], "CJ-HUMANEVAL-032_l19_c047")
    expectPolynomialRoot([-9, -5, 2, -10, 2, -2, 4, -1], "CJ-HUMANEVAL-032_l19_c048")
    expectPolynomialRoot([7, 5, -6, -4, -1, -4, -9, 8], "CJ-HUMANEVAL-032_l19_c049")
    expectPolynomialRoot([1, -9], "CJ-HUMANEVAL-032_l19_c050")
    expectPolynomialRoot([8, 5], "CJ-HUMANEVAL-032_l19_c051")
    expectPolynomialRoot([-9, 6, -8, -5], "CJ-HUMANEVAL-032_l19_c052")
    expectPolynomialRoot([9, -8], "CJ-HUMANEVAL-032_l19_c053")
    expectPolynomialRoot([2, -7, 8, -3], "CJ-HUMANEVAL-032_l19_c054")
    expectPolynomialRoot([9, -8], "CJ-HUMANEVAL-032_l19_c055")
    expectPolynomialRoot([8, 8, 6, 1, -2, -4, 1, -3], "CJ-HUMANEVAL-032_l19_c056")
    expectPolynomialRoot([2, -6, 10, -1, 4, 1], "CJ-HUMANEVAL-032_l19_c057")
    expectPolynomialRoot([-10, 4], "CJ-HUMANEVAL-032_l19_c058")
    expectPolynomialRoot([-8, 7], "CJ-HUMANEVAL-032_l19_c059")
    expectPolynomialRoot([6, -2, -6, 1], "CJ-HUMANEVAL-032_l19_c060")
    expectPolynomialRoot([-3, 1], "CJ-HUMANEVAL-032_l19_c061")
    expectPolynomialRoot([-5, 4, 7, -1, 9, 10], "CJ-HUMANEVAL-032_l19_c062")
    expectPolynomialRoot([7, -1], "CJ-HUMANEVAL-032_l19_c063")
    expectPolynomialRoot([-6, -2], "CJ-HUMANEVAL-032_l19_c064")
    expectPolynomialRoot([-7, 7], "CJ-HUMANEVAL-032_l19_c065")
    expectPolynomialRoot([-2, -1, 9, -4], "CJ-HUMANEVAL-032_l19_c066")
    expectPolynomialRoot([-4, 10, -2, 6, 5, -2], "CJ-HUMANEVAL-032_l19_c067")
    expectPolynomialRoot([-8, 10], "CJ-HUMANEVAL-032_l19_c068")
    expectPolynomialRoot([-2, -9, -10, 1, -6, 10, -2, -5], "CJ-HUMANEVAL-032_l19_c069")
    expectPolynomialRoot([7, 3, 7, -10, -7, -8, -6, 7], "CJ-HUMANEVAL-032_l19_c070")
    expectPolynomialRoot([1, 8], "CJ-HUMANEVAL-032_l19_c071")
    expectPolynomialRoot([3, -6, -9, -1], "CJ-HUMANEVAL-032_l19_c072")
    expectPolynomialRoot([-9, 1, -4, -3, -7, 1], "CJ-HUMANEVAL-032_l19_c073")
    expectPolynomialRoot([9, -6, -3, -5, -5, 3, -10, -5], "CJ-HUMANEVAL-032_l19_c074")
    expectPolynomialRoot([3, -3, -2, -5, -7, 2], "CJ-HUMANEVAL-032_l19_c075")
    expectPolynomialRoot([5, -3], "CJ-HUMANEVAL-032_l19_c076")
    expectPolynomialRoot([4, 1, -1, -3], "CJ-HUMANEVAL-032_l19_c077")
    expectPolynomialRoot([-10, -4, 2, 1], "CJ-HUMANEVAL-032_l19_c078")
    expectPolynomialRoot([-8, -2, 1, 10, 6, 2], "CJ-HUMANEVAL-032_l19_c079")
    expectPolynomialRoot([-10, -7, -2, -5, 8, -2], "CJ-HUMANEVAL-032_l19_c080")
    expectPolynomialRoot([-7, 9], "CJ-HUMANEVAL-032_l19_c081")
    expectPolynomialRoot([1, 1, 3, 9, 6, -7, 2, 8], "CJ-HUMANEVAL-032_l19_c082")
    expectPolynomialRoot([-2, -9, 3, -10], "CJ-HUMANEVAL-032_l19_c083")
    expectPolynomialRoot([1, 3, -8, 1], "CJ-HUMANEVAL-032_l19_c084")
    expectPolynomialRoot([-7, -1, 6, -1, 3, 1], "CJ-HUMANEVAL-032_l19_c085")
    expectPolynomialRoot([-1, 7, -6, -4, 3, 2, -5, 9], "CJ-HUMANEVAL-032_l19_c086")
    expectPolynomialRoot([2, 7, -10, -1, -1, -4], "CJ-HUMANEVAL-032_l19_c087")
    expectPolynomialRoot([8, 9, 10, 1, 4, 4, 4, -4], "CJ-HUMANEVAL-032_l19_c088")
    expectPolynomialRoot([-5, -8, -1, 6, 10, 9, 1, -8], "CJ-HUMANEVAL-032_l19_c089")
    expectPolynomialRoot([-1, -3, -4, -6], "CJ-HUMANEVAL-032_l19_c090")
    expectPolynomialRoot([-9, -3], "CJ-HUMANEVAL-032_l19_c091")
    expectPolynomialRoot([9, -8, 4, 3, 10, 8, -4, 2], "CJ-HUMANEVAL-032_l19_c092")
    expectPolynomialRoot([2, -3, -6, 10, -10, -7, 3, -3], "CJ-HUMANEVAL-032_l19_c093")
    expectPolynomialRoot([6, 4, -9, 7], "CJ-HUMANEVAL-032_l19_c094")
    expectPolynomialRoot([-7, 4, -6, 4], "CJ-HUMANEVAL-032_l19_c095")
    expectPolynomialRoot([4, 9, 6, 3, 7, 4], "CJ-HUMANEVAL-032_l19_c096")
    expectPolynomialRoot([5, 4, -2, -3], "CJ-HUMANEVAL-032_l19_c097")
    expectPolynomialRoot([6, 5, 10, -3, -2, 4], "CJ-HUMANEVAL-032_l19_c098")
    expectPolynomialRoot([-1, -3], "CJ-HUMANEVAL-032_l19_c099")
    expectPolynomialRoot([1, 1, 7, -8, -6, -6], "CJ-HUMANEVAL-032_l19_c100")
    println("CJ-HUMANEVAL-032 ok")
    return 0
}
