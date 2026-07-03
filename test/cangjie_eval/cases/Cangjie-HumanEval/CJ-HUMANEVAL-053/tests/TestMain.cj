package cangjie_humaneval_053

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
    expectInt64(add(0, 1), 1, "CJ-HUMANEVAL-053_l9_c001")
    expectInt64(add(1, 0), 1, "CJ-HUMANEVAL-053_l10_c002")
    expectInt64(add(2, 3), 5, "CJ-HUMANEVAL-053_l11_c003")
    expectInt64(add(5, 7), 12, "CJ-HUMANEVAL-053_l12_c004")
    expectInt64(add(7, 5), 12, "CJ-HUMANEVAL-053_l13_c005")
    expectInt64(add(413, 628), 1041, "CJ-HUMANEVAL-053_l17_c006")
    expectInt64(add(915, 55), 970, "CJ-HUMANEVAL-053_l17_c007")
    expectInt64(add(470, 935), 1405, "CJ-HUMANEVAL-053_l17_c008")
    expectInt64(add(490, 409), 899, "CJ-HUMANEVAL-053_l17_c009")
    expectInt64(add(789, 131), 920, "CJ-HUMANEVAL-053_l17_c010")
    expectInt64(add(33, 408), 441, "CJ-HUMANEVAL-053_l17_c011")
    expectInt64(add(733, 644), 1377, "CJ-HUMANEVAL-053_l17_c012")
    expectInt64(add(78, 478), 556, "CJ-HUMANEVAL-053_l17_c013")
    expectInt64(add(667, 135), 802, "CJ-HUMANEVAL-053_l17_c014")
    expectInt64(add(465, 28), 493, "CJ-HUMANEVAL-053_l17_c015")
    expectInt64(add(418, 31), 449, "CJ-HUMANEVAL-053_l17_c016")
    expectInt64(add(29, 184), 213, "CJ-HUMANEVAL-053_l17_c017")
    expectInt64(add(872, 681), 1553, "CJ-HUMANEVAL-053_l17_c018")
    expectInt64(add(225, 529), 754, "CJ-HUMANEVAL-053_l17_c019")
    expectInt64(add(172, 137), 309, "CJ-HUMANEVAL-053_l17_c020")
    expectInt64(add(451, 958), 1409, "CJ-HUMANEVAL-053_l17_c021")
    expectInt64(add(111, 555), 666, "CJ-HUMANEVAL-053_l17_c022")
    expectInt64(add(190, 909), 1099, "CJ-HUMANEVAL-053_l17_c023")
    expectInt64(add(998, 364), 1362, "CJ-HUMANEVAL-053_l17_c024")
    expectInt64(add(315, 817), 1132, "CJ-HUMANEVAL-053_l17_c025")
    expectInt64(add(754, 563), 1317, "CJ-HUMANEVAL-053_l17_c026")
    expectInt64(add(853, 361), 1214, "CJ-HUMANEVAL-053_l17_c027")
    expectInt64(add(36, 577), 613, "CJ-HUMANEVAL-053_l17_c028")
    expectInt64(add(226, 441), 667, "CJ-HUMANEVAL-053_l17_c029")
    expectInt64(add(907, 300), 1207, "CJ-HUMANEVAL-053_l17_c030")
    expectInt64(add(646, 15), 661, "CJ-HUMANEVAL-053_l17_c031")
    expectInt64(add(480, 711), 1191, "CJ-HUMANEVAL-053_l17_c032")
    expectInt64(add(197, 831), 1028, "CJ-HUMANEVAL-053_l17_c033")
    expectInt64(add(101, 626), 727, "CJ-HUMANEVAL-053_l17_c034")
    expectInt64(add(64, 582), 646, "CJ-HUMANEVAL-053_l17_c035")
    expectInt64(add(965, 239), 1204, "CJ-HUMANEVAL-053_l17_c036")
    expectInt64(add(815, 947), 1762, "CJ-HUMANEVAL-053_l17_c037")
    expectInt64(add(475, 797), 1272, "CJ-HUMANEVAL-053_l17_c038")
    expectInt64(add(243, 431), 674, "CJ-HUMANEVAL-053_l17_c039")
    expectInt64(add(939, 107), 1046, "CJ-HUMANEVAL-053_l17_c040")
    expectInt64(add(203, 777), 980, "CJ-HUMANEVAL-053_l17_c041")
    expectInt64(add(796, 53), 849, "CJ-HUMANEVAL-053_l17_c042")
    expectInt64(add(102, 270), 372, "CJ-HUMANEVAL-053_l17_c043")
    expectInt64(add(861, 804), 1665, "CJ-HUMANEVAL-053_l17_c044")
    expectInt64(add(818, 372), 1190, "CJ-HUMANEVAL-053_l17_c045")
    expectInt64(add(77, 397), 474, "CJ-HUMANEVAL-053_l17_c046")
    expectInt64(add(153, 738), 891, "CJ-HUMANEVAL-053_l17_c047")
    expectInt64(add(755, 675), 1430, "CJ-HUMANEVAL-053_l17_c048")
    expectInt64(add(497, 21), 518, "CJ-HUMANEVAL-053_l17_c049")
    expectInt64(add(969, 108), 1077, "CJ-HUMANEVAL-053_l17_c050")
    expectInt64(add(799, 370), 1169, "CJ-HUMANEVAL-053_l17_c051")
    expectInt64(add(639, 597), 1236, "CJ-HUMANEVAL-053_l17_c052")
    expectInt64(add(916, 737), 1653, "CJ-HUMANEVAL-053_l17_c053")
    expectInt64(add(502, 319), 821, "CJ-HUMANEVAL-053_l17_c054")
    expectInt64(add(853, 681), 1534, "CJ-HUMANEVAL-053_l17_c055")
    expectInt64(add(257, 1000), 1257, "CJ-HUMANEVAL-053_l17_c056")
    expectInt64(add(233, 356), 589, "CJ-HUMANEVAL-053_l17_c057")
    expectInt64(add(543, 870), 1413, "CJ-HUMANEVAL-053_l17_c058")
    expectInt64(add(946, 210), 1156, "CJ-HUMANEVAL-053_l17_c059")
    expectInt64(add(303, 299), 602, "CJ-HUMANEVAL-053_l17_c060")
    expectInt64(add(863, 952), 1815, "CJ-HUMANEVAL-053_l17_c061")
    expectInt64(add(454, 310), 764, "CJ-HUMANEVAL-053_l17_c062")
    expectInt64(add(221, 946), 1167, "CJ-HUMANEVAL-053_l17_c063")
    expectInt64(add(906, 597), 1503, "CJ-HUMANEVAL-053_l17_c064")
    expectInt64(add(151, 555), 706, "CJ-HUMANEVAL-053_l17_c065")
    expectInt64(add(983, 459), 1442, "CJ-HUMANEVAL-053_l17_c066")
    expectInt64(add(181, 732), 913, "CJ-HUMANEVAL-053_l17_c067")
    expectInt64(add(717, 233), 950, "CJ-HUMANEVAL-053_l17_c068")
    expectInt64(add(456, 867), 1323, "CJ-HUMANEVAL-053_l17_c069")
    expectInt64(add(662, 471), 1133, "CJ-HUMANEVAL-053_l17_c070")
    expectInt64(add(525, 305), 830, "CJ-HUMANEVAL-053_l17_c071")
    expectInt64(add(939, 403), 1342, "CJ-HUMANEVAL-053_l17_c072")
    expectInt64(add(848, 433), 1281, "CJ-HUMANEVAL-053_l17_c073")
    expectInt64(add(890, 166), 1056, "CJ-HUMANEVAL-053_l17_c074")
    expectInt64(add(494, 431), 925, "CJ-HUMANEVAL-053_l17_c075")
    expectInt64(add(421, 576), 997, "CJ-HUMANEVAL-053_l17_c076")
    expectInt64(add(312, 844), 1156, "CJ-HUMANEVAL-053_l17_c077")
    expectInt64(add(154, 100), 254, "CJ-HUMANEVAL-053_l17_c078")
    expectInt64(add(480, 993), 1473, "CJ-HUMANEVAL-053_l17_c079")
    expectInt64(add(971, 202), 1173, "CJ-HUMANEVAL-053_l17_c080")
    expectInt64(add(349, 126), 475, "CJ-HUMANEVAL-053_l17_c081")
    expectInt64(add(505, 467), 972, "CJ-HUMANEVAL-053_l17_c082")
    expectInt64(add(416, 721), 1137, "CJ-HUMANEVAL-053_l17_c083")
    expectInt64(add(568, 849), 1417, "CJ-HUMANEVAL-053_l17_c084")
    expectInt64(add(320, 528), 848, "CJ-HUMANEVAL-053_l17_c085")
    expectInt64(add(249, 832), 1081, "CJ-HUMANEVAL-053_l17_c086")
    expectInt64(add(550, 707), 1257, "CJ-HUMANEVAL-053_l17_c087")
    expectInt64(add(695, 369), 1064, "CJ-HUMANEVAL-053_l17_c088")
    expectInt64(add(99, 69), 168, "CJ-HUMANEVAL-053_l17_c089")
    expectInt64(add(11, 674), 685, "CJ-HUMANEVAL-053_l17_c090")
    expectInt64(add(764, 798), 1562, "CJ-HUMANEVAL-053_l17_c091")
    expectInt64(add(519, 256), 775, "CJ-HUMANEVAL-053_l17_c092")
    expectInt64(add(535, 740), 1275, "CJ-HUMANEVAL-053_l17_c093")
    expectInt64(add(78, 943), 1021, "CJ-HUMANEVAL-053_l17_c094")
    expectInt64(add(850, 158), 1008, "CJ-HUMANEVAL-053_l17_c095")
    expectInt64(add(720, 194), 914, "CJ-HUMANEVAL-053_l17_c096")
    expectInt64(add(926, 895), 1821, "CJ-HUMANEVAL-053_l17_c097")
    expectInt64(add(592, 116), 708, "CJ-HUMANEVAL-053_l17_c098")
    expectInt64(add(523, 30), 553, "CJ-HUMANEVAL-053_l17_c099")
    expectInt64(add(635, 364), 999, "CJ-HUMANEVAL-053_l17_c100")
    expectInt64(add(55, 576), 631, "CJ-HUMANEVAL-053_l17_c101")
    expectInt64(add(828, 141), 969, "CJ-HUMANEVAL-053_l17_c102")
    expectInt64(add(612, 583), 1195, "CJ-HUMANEVAL-053_l17_c103")
    expectInt64(add(662, 251), 913, "CJ-HUMANEVAL-053_l17_c104")
    expectInt64(add(833, 726), 1559, "CJ-HUMANEVAL-053_l17_c105")
    println("CJ-HUMANEVAL-053 ok")
    return 0
}
