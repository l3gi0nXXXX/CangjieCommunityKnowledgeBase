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
    expectFloat64(find_zero(listOfInt64([-10, -2])), -5.000000000058208, "CJ-HUMANEVAL-032_l19_c001")
    expectFloat64(find_zero(listOfInt64([-3, -6, -7, 7])), 1.6679422343731858, "CJ-HUMANEVAL-032_l19_c002")
    expectFloat64(find_zero(listOfInt64([8, 3])), -2.666666666686069, "CJ-HUMANEVAL-032_l19_c003")
    expectFloat64(find_zero(listOfInt64([-10, -8])), -1.2500000000582077, "CJ-HUMANEVAL-032_l19_c004")
    expectFloat64(find_zero(listOfInt64([-3, 6, 9, -10])), -0.6685768984025344, "CJ-HUMANEVAL-032_l19_c005")
    expectFloat64(find_zero(listOfInt64([10, 7, 3, -3])), 2.4815587521297857, "CJ-HUMANEVAL-032_l19_c006")
    expectFloat64(find_zero(listOfInt64([8, -2, -10, -5, 3, 1, -2, -6])), 0.7057115506613627, "CJ-HUMANEVAL-032_l19_c007")
    expectFloat64(find_zero(listOfInt64([1, -7, -8, 2])), -0.8446386614232324, "CJ-HUMANEVAL-032_l19_c008")
    expectFloat64(find_zero(listOfInt64([1, 1])), -1.0, "CJ-HUMANEVAL-032_l19_c009")
    expectFloat64(find_zero(listOfInt64([-9, 4, 7, -7, 2, -8])), -0.8164280389901251, "CJ-HUMANEVAL-032_l19_c010")
    expectFloat64(find_zero(listOfInt64([10, 9, 1, 8, -4, -8])), -0.8227368473890238, "CJ-HUMANEVAL-032_l19_c011")
    expectFloat64(find_zero(listOfInt64([-3, -1])), -3.0000000000582077, "CJ-HUMANEVAL-032_l19_c012")
    expectFloat64(find_zero(listOfInt64([-3, -7])), -0.42857142857974395, "CJ-HUMANEVAL-032_l19_c013")
    expectFloat64(find_zero(listOfInt64([-2, 4, 10, 1, -5, 1, 1, -4])), -0.86899654957233, "CJ-HUMANEVAL-032_l19_c014")
    expectFloat64(find_zero(listOfInt64([10, -8, 9, 10, -5, 7])), -1.0731038876692764, "CJ-HUMANEVAL-032_l19_c015")
    expectFloat64(find_zero(listOfInt64([-5, 4, 2, -2])), -1.4836825707461685, "CJ-HUMANEVAL-032_l19_c016")
    expectFloat64(find_zero(listOfInt64([1, -9, -3, -9])), 0.10615823022089899, "CJ-HUMANEVAL-032_l19_c017")
    expectFloat64(find_zero(listOfInt64([2, -2, -8, -4, 8, 1])), 0.38501966872718185, "CJ-HUMANEVAL-032_l19_c018")
    expectFloat64(find_zero(listOfInt64([10, 5, 2, 10])), -0.8933422100380994, "CJ-HUMANEVAL-032_l19_c019")
    expectFloat64(find_zero(listOfInt64([-6, -2, -6, -3, 7, 7, -2, 8])), 0.9600705468910746, "CJ-HUMANEVAL-032_l19_c020")
    expectFloat64(find_zero(listOfInt64([8, 2, 1, -3, -6, 6, 5, -8])), 1.1312649988103658, "CJ-HUMANEVAL-032_l19_c021")
    expectFloat64(find_zero(listOfInt64([-7, -6])), -1.1666666666860692, "CJ-HUMANEVAL-032_l19_c022")
    expectFloat64(find_zero(listOfInt64([3, 9, -8, 2])), -0.2661688190419227, "CJ-HUMANEVAL-032_l19_c023")
    expectFloat64(find_zero(listOfInt64([9, 4, 6, -2, 7, -10, -7, 7])), -1.2858021691790782, "CJ-HUMANEVAL-032_l19_c024")
    expectFloat64(find_zero(listOfInt64([10, 1, -7, -1, 3, -5])), 1.0328693957999349, "CJ-HUMANEVAL-032_l19_c025")
    expectFloat64(find_zero(listOfInt64([-10, -2, 6, -5, 6, -7, 10, -1])), -0.7015198637964204, "CJ-HUMANEVAL-032_l19_c026")
    expectFloat64(find_zero(listOfInt64([-6, 1, -5, 7])), 1.1949840254965238, "CJ-HUMANEVAL-032_l19_c027")
    expectFloat64(find_zero(listOfInt64([9, 1])), -9.000000000058208, "CJ-HUMANEVAL-032_l19_c028")
    expectFloat64(find_zero(listOfInt64([-10, -7, 1, -1, -3, -9, -3, 8])), 1.5114667361485772, "CJ-HUMANEVAL-032_l19_c029")
    expectFloat64(find_zero(listOfInt64([-8, 5])), 1.599999999976717, "CJ-HUMANEVAL-032_l19_c030")
    expectFloat64(find_zero(listOfInt64([7, -6])), 1.1666666666278616, "CJ-HUMANEVAL-032_l19_c031")
    expectFloat64(find_zero(listOfInt64([5, 7, -5, -2])), -0.547214484482538, "CJ-HUMANEVAL-032_l19_c032")
    expectFloat64(find_zero(listOfInt64([-4, 7, -4, -1, 2, 10, 1, 4])), 0.6221468804869801, "CJ-HUMANEVAL-032_l19_c033")
    expectFloat64(find_zero(listOfInt64([-7, -3, -3, -8, 1, -10, 8, 7])), -0.7463565783691593, "CJ-HUMANEVAL-032_l19_c034")
    expectFloat64(find_zero(listOfInt64([8, -3, -10, -8])), 0.6355658151442185, "CJ-HUMANEVAL-032_l19_c035")
    expectFloat64(find_zero(listOfInt64([-3, -8])), -0.37500000005820766, "CJ-HUMANEVAL-032_l19_c036")
    expectFloat64(find_zero(listOfInt64([1, -8])), 0.12499999994179234, "CJ-HUMANEVAL-032_l19_c037")
    expectFloat64(find_zero(listOfInt64([-2, 5, -4, 7])), 0.4360383356688544, "CJ-HUMANEVAL-032_l19_c038")
    expectFloat64(find_zero(listOfInt64([8, 8, 5, -3])), 2.9021427524276078, "CJ-HUMANEVAL-032_l19_c039")
    expectFloat64(find_zero(listOfInt64([3, -4, -7, -7, 3, 1, 3, 3])), 0.39456867933040485, "CJ-HUMANEVAL-032_l19_c040")
    expectFloat64(find_zero(listOfInt64([-9, 10, 10, -7, -9, 2, 1, -7])), -1.0938426014618017, "CJ-HUMANEVAL-032_l19_c041")
    expectFloat64(find_zero(listOfInt64([-4, -4, 7, 4])), -2.0, "CJ-HUMANEVAL-032_l19_c042")
    expectFloat64(find_zero(listOfInt64([3, -5, -2, 4])), 0.6513878188561648, "CJ-HUMANEVAL-032_l19_c043")
    expectFloat64(find_zero(listOfInt64([-8, 4, 7, -7])), -0.9312933354522102, "CJ-HUMANEVAL-032_l19_c044")
    expectFloat64(find_zero(listOfInt64([10, 7])), -1.428571428579744, "CJ-HUMANEVAL-032_l19_c045")
    expectFloat64(find_zero(listOfInt64([-8, -3])), -2.666666666686069, "CJ-HUMANEVAL-032_l19_c046")
    expectFloat64(find_zero(listOfInt64([3, 5, 5, -4])), 2.0420076226000674, "CJ-HUMANEVAL-032_l19_c047")
    expectFloat64(find_zero(listOfInt64([-9, -5, 2, -10, 2, -2, 4, -1])), -0.6912827867781743, "CJ-HUMANEVAL-032_l19_c048")
    expectFloat64(find_zero(listOfInt64([7, 5, -6, -4, -1, -4, -9, 8])), -0.7303538502892479, "CJ-HUMANEVAL-032_l19_c049")
    expectFloat64(find_zero(listOfInt64([1, -9])), 0.11111111106583849, "CJ-HUMANEVAL-032_l19_c050")
    expectFloat64(find_zero(listOfInt64([8, 5])), -1.6000000000349246, "CJ-HUMANEVAL-032_l19_c051")
    expectFloat64(find_zero(listOfInt64([-9, 6, -8, -5])), -2.4085229280171916, "CJ-HUMANEVAL-032_l19_c052")
    expectFloat64(find_zero(listOfInt64([9, -8])), 1.1249999999417923, "CJ-HUMANEVAL-032_l19_c053")
    expectFloat64(find_zero(listOfInt64([2, -7, 8, -3])), 0.6666666666278616, "CJ-HUMANEVAL-032_l19_c054")
    expectFloat64(find_zero(listOfInt64([9, -8])), 1.1249999999417923, "CJ-HUMANEVAL-032_l19_c055")
    expectFloat64(find_zero(listOfInt64([8, 8, 6, 1, -2, -4, 1, -3])), 1.267006399051752, "CJ-HUMANEVAL-032_l19_c056")
    expectFloat64(find_zero(listOfInt64([2, -6, 10, -1, 4, 1])), -4.72142661397811, "CJ-HUMANEVAL-032_l19_c057")
    expectFloat64(find_zero(listOfInt64([-10, 4])), 2.4999999999417923, "CJ-HUMANEVAL-032_l19_c058")
    expectFloat64(find_zero(listOfInt64([-8, 7])), 1.142857142840512, "CJ-HUMANEVAL-032_l19_c059")
    expectFloat64(find_zero(listOfInt64([6, -2, -6, 1])), 0.9066398076247424, "CJ-HUMANEVAL-032_l19_c060")
    expectFloat64(find_zero(listOfInt64([-3, 1])), 2.9999999999417923, "CJ-HUMANEVAL-032_l19_c061")
    expectFloat64(find_zero(listOfInt64([-5, 4, 7, -1, 9, 10])), 0.5266727519920096, "CJ-HUMANEVAL-032_l19_c062")
    expectFloat64(find_zero(listOfInt64([7, -1])), 6.999999999941792, "CJ-HUMANEVAL-032_l19_c063")
    expectFloat64(find_zero(listOfInt64([-6, -2])), -3.0000000000582077, "CJ-HUMANEVAL-032_l19_c064")
    expectFloat64(find_zero(listOfInt64([-7, 7])), 0.9999999999417923, "CJ-HUMANEVAL-032_l19_c065")
    expectFloat64(find_zero(listOfInt64([-2, -1, 9, -4])), -0.3903882032027468, "CJ-HUMANEVAL-032_l19_c066")
    expectFloat64(find_zero(listOfInt64([-4, 10, -2, 6, 5, -2])), 0.38592179998522624, "CJ-HUMANEVAL-032_l19_c067")
    expectFloat64(find_zero(listOfInt64([-8, 10])), 0.7999999999883585, "CJ-HUMANEVAL-032_l19_c068")
    expectFloat64(find_zero(listOfInt64([-2, -9, -10, 1, -6, 10, -2, -5])), -1.9016489709028974, "CJ-HUMANEVAL-032_l19_c069")
    expectFloat64(find_zero(listOfInt64([7, 3, 7, -10, -7, -8, -6, 7])), 0.877888614195399, "CJ-HUMANEVAL-032_l19_c070")
    expectFloat64(find_zero(listOfInt64([1, 8])), -0.12500000005820766, "CJ-HUMANEVAL-032_l19_c071")
    expectFloat64(find_zero(listOfInt64([3, -6, -9, -1])), 0.3303229847806506, "CJ-HUMANEVAL-032_l19_c072")
    expectFloat64(find_zero(listOfInt64([-9, 1, -4, -3, -7, 1])), 7.4735223380848765, "CJ-HUMANEVAL-032_l19_c073")
    expectFloat64(find_zero(listOfInt64([9, -6, -3, -5, -5, 3, -10, -5])), 0.6800906549324282, "CJ-HUMANEVAL-032_l19_c074")
    expectFloat64(find_zero(listOfInt64([3, -3, -2, -5, -7, 2])), -1.0, "CJ-HUMANEVAL-032_l19_c075")
    expectFloat64(find_zero(listOfInt64([5, -3])), 1.6666666666278616, "CJ-HUMANEVAL-032_l19_c076")
    expectFloat64(find_zero(listOfInt64([4, 1, -1, -3])), 1.091414260212332, "CJ-HUMANEVAL-032_l19_c077")
    expectFloat64(find_zero(listOfInt64([-10, -4, 2, 1])), 2.1179422714048997, "CJ-HUMANEVAL-032_l19_c078")
    expectFloat64(find_zero(listOfInt64([-8, -2, 1, 10, 6, 2])), 0.8199922735802829, "CJ-HUMANEVAL-032_l19_c079")
    expectFloat64(find_zero(listOfInt64([-10, -7, -2, -5, 8, -2])), -0.7751165542285889, "CJ-HUMANEVAL-032_l19_c080")
    expectFloat64(find_zero(listOfInt64([-7, 9])), 0.7777777777519077, "CJ-HUMANEVAL-032_l19_c081")
    expectFloat64(find_zero(listOfInt64([1, 1, 3, 9, 6, -7, 2, 8])), -1.0796475561219268, "CJ-HUMANEVAL-032_l19_c082")
    expectFloat64(find_zero(listOfInt64([-2, -9, 3, -10])), -0.20000000001164153, "CJ-HUMANEVAL-032_l19_c083")
    expectFloat64(find_zero(listOfInt64([1, 3, -8, 1])), -0.2112208516919054, "CJ-HUMANEVAL-032_l19_c084")
    expectFloat64(find_zero(listOfInt64([-7, -1, 6, -1, 3, 1])), 0.9578598753432743, "CJ-HUMANEVAL-032_l19_c085")
    expectFloat64(find_zero(listOfInt64([-1, 7, -6, -4, 3, 2, -5, 9])), 0.17007400892907754, "CJ-HUMANEVAL-032_l19_c086")
    expectFloat64(find_zero(listOfInt64([2, 7, -10, -1, -1, -4])), 0.746446434292011, "CJ-HUMANEVAL-032_l19_c087")
    expectFloat64(find_zero(listOfInt64([8, 9, 10, 1, 4, 4, 4, -4])), 2.018535319773946, "CJ-HUMANEVAL-032_l19_c088")
    expectFloat64(find_zero(listOfInt64([-5, -8, -1, 6, 10, 9, 1, -8])), -0.7318775289459154, "CJ-HUMANEVAL-032_l19_c089")
    expectFloat64(find_zero(listOfInt64([-1, -3, -4, -6])), -0.42038060672348365, "CJ-HUMANEVAL-032_l19_c090")
    expectFloat64(find_zero(listOfInt64([-9, -3])), -3.0000000000582077, "CJ-HUMANEVAL-032_l19_c091")
    expectFloat64(find_zero(listOfInt64([9, -8, 4, 3, 10, 8, -4, 2])), -1.2079210819210857, "CJ-HUMANEVAL-032_l19_c092")
    expectFloat64(find_zero(listOfInt64([2, -3, -6, 10, -10, -7, 3, -3])), 0.4243725821143016, "CJ-HUMANEVAL-032_l19_c093")
    expectFloat64(find_zero(listOfInt64([6, 4, -9, 7])), -0.5456791458418593, "CJ-HUMANEVAL-032_l19_c094")
    expectFloat64(find_zero(listOfInt64([-7, 4, -6, 4])), 1.5720202162628993, "CJ-HUMANEVAL-032_l19_c095")
    expectFloat64(find_zero(listOfInt64([4, 9, 6, 3, 7, 4])), -1.4282608788926154, "CJ-HUMANEVAL-032_l19_c096")
    expectFloat64(find_zero(listOfInt64([5, 4, -2, -3])), 1.313795538211707, "CJ-HUMANEVAL-032_l19_c097")
    expectFloat64(find_zero(listOfInt64([6, 5, 10, -3, -2, 4])), -1.3557373622315936, "CJ-HUMANEVAL-032_l19_c098")
    expectFloat64(find_zero(listOfInt64([-1, -3])), -0.33333333337213844, "CJ-HUMANEVAL-032_l19_c099")
    expectFloat64(find_zero(listOfInt64([1, 1, 7, -8, -6, -6])), 0.696112065052148, "CJ-HUMANEVAL-032_l19_c100")
    println("CJ-HUMANEVAL-032 ok")
    return 0
}
