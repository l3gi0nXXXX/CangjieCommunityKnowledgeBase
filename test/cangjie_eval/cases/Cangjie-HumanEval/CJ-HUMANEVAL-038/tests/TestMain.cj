package cangjie_humaneval_038

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
    expectString(decode_cyclic("ccuyujffvh"), "uccjyuvffh", "CJ-HUMANEVAL-038_l14_c001")
    expectString(decode_cyclic("tkrtxqgigqzzneowinzo"), "rtkqtxggizqzonenwizo", "CJ-HUMANEVAL-038_l14_c002")
    expectString(decode_cyclic("lsojridroive"), "olsijrodreiv", "CJ-HUMANEVAL-038_l14_c003")
    expectString(decode_cyclic("nicmodisoixwxejk"), "cnidmooiswixjxek", "CJ-HUMANEVAL-038_l14_c004")
    expectString(decode_cyclic("kudygkwsnfeyv"), "dkukygnwsyfev", "CJ-HUMANEVAL-038_l14_c005")
    expectString(decode_cyclic("jdtpzrkyxjthdyfwvcbb"), "tjdrpzxkyhjtfdycwvbb", "CJ-HUMANEVAL-038_l14_c006")
    expectString(decode_cyclic("pdnqiyfxcmgzyougljp"), "npdyqicfxzmguyojglp", "CJ-HUMANEVAL-038_l14_c007")
    expectString(decode_cyclic("qrzehtymczwgb"), "zqrtehcymgzwb", "CJ-HUMANEVAL-038_l14_c008")
    expectString(decode_cyclic("aqyqbzlraogq"), "yaqzqbalrqog", "CJ-HUMANEVAL-038_l14_c009")
    expectString(decode_cyclic("usmhpytikxhniyo"), "musyhpktinxhoiy", "CJ-HUMANEVAL-038_l14_c010")
    expectString(decode_cyclic("slgyjcajaigucbooyv"), "gslcyjaajuigocbvoy", "CJ-HUMANEVAL-038_l14_c011")
    expectString(decode_cyclic("iyvehcsknnzmbgirggu"), "viycehnskmnzibggrgu", "CJ-HUMANEVAL-038_l14_c012")
    expectString(decode_cyclic("ltjtjokxfh"), "jltotjfkxh", "CJ-HUMANEVAL-038_l14_c013")
    expectString(decode_cyclic("xovgjczmhhm"), "vxocgjhzmhm", "CJ-HUMANEVAL-038_l14_c014")
    expectString(decode_cyclic("agupnbahmzi"), "uagbpnmahzi", "CJ-HUMANEVAL-038_l14_c015")
    expectString(decode_cyclic("burixrgkdbx"), "rburixdgkbx", "CJ-HUMANEVAL-038_l14_c016")
    expectString(decode_cyclic("qfswvyquiloa"), "sqfywviqualo", "CJ-HUMANEVAL-038_l14_c017")
    expectString(decode_cyclic("ybgpnqewefeolqtd"), "gybqpneewofetlqd", "CJ-HUMANEVAL-038_l14_c018")
    expectString(decode_cyclic("uycpasinai"), "cuyspaaini", "CJ-HUMANEVAL-038_l14_c019")
    expectString(decode_cyclic("dmhxvgryfegh"), "hdmgxvfryheg", "CJ-HUMANEVAL-038_l14_c020")
    expectString(decode_cyclic("hkwiwpdocagvgnzitq"), "whkpiwcdovagzgnqit", "CJ-HUMANEVAL-038_l14_c021")
    expectString(decode_cyclic("hmgkgmwddtxfdmaqe"), "ghmmkgdwdftxadmqe", "CJ-HUMANEVAL-038_l14_c022")
    expectString(decode_cyclic("hrlnloweufwmrkrhsm"), "lhronluwemfwrrkmhs", "CJ-HUMANEVAL-038_l14_c023")
    expectString(decode_cyclic("pqfcuwvdnnxbl"), "fpqwcunvdbnxl", "CJ-HUMANEVAL-038_l14_c024")
    expectString(decode_cyclic("naywkumliosaqozqghqb"), "ynauwkimlaoszqohqgqb", "CJ-HUMANEVAL-038_l14_c025")
    expectString(decode_cyclic("nvuiuzdciewlrswti"), "unvziuidclewwrsti", "CJ-HUMANEVAL-038_l14_c026")
    expectString(decode_cyclic("cjhccknrzbzbo"), "hcjkccznrbbzo", "CJ-HUMANEVAL-038_l14_c027")
    expectString(decode_cyclic("awfvzhfpqiyxwxronjn"), "fawhvzqfpxiyrwxjonn", "CJ-HUMANEVAL-038_l14_c028")
    expectString(decode_cyclic("nditkyubdiulyd"), "indytkdubliuyd", "CJ-HUMANEVAL-038_l14_c029")
    expectString(decode_cyclic("gaelhezjvwm"), "egaelhvzjwm", "CJ-HUMANEVAL-038_l14_c030")
    expectString(decode_cyclic("hfanbanacj"), "ahfanbcnaj", "CJ-HUMANEVAL-038_l14_c031")
    expectString(decode_cyclic("ujpnkhqzppw"), "pujhnkpqzpw", "CJ-HUMANEVAL-038_l14_c032")
    expectString(decode_cyclic("sabyzpczwgcjhinry"), "bsapyzwczjgcnhiry", "CJ-HUMANEVAL-038_l14_c033")
    expectString(decode_cyclic("dkzlbwvmxv"), "zdkwlbxvmv", "CJ-HUMANEVAL-038_l14_c034")
    expectString(decode_cyclic("pbobsumfshbcqg"), "opbubssmfchbqg", "CJ-HUMANEVAL-038_l14_c035")
    expectString(decode_cyclic("rgvcuwsubfrufup"), "vrgwcubsuufrpfu", "CJ-HUMANEVAL-038_l14_c036")
    expectString(decode_cyclic("twkwbyoxlgdxvdvxipwl"), "ktwywbloxxgdvvdpxiwl", "CJ-HUMANEVAL-038_l14_c037")
    expectString(decode_cyclic("wivxntkljffwxbmwth"), "vwitxnjklwffmxbhwt", "CJ-HUMANEVAL-038_l14_c038")
    expectString(decode_cyclic("rixbzjcbrehrlcn"), "xrijbzrcbrehnlc", "CJ-HUMANEVAL-038_l14_c039")
    expectString(decode_cyclic("yshbqiloqfkgse"), "hysibqqlogfkse", "CJ-HUMANEVAL-038_l14_c040")
    expectString(decode_cyclic("ttsqmvfgddzx"), "sttvqmdfgxdz", "CJ-HUMANEVAL-038_l14_c041")
    expectString(decode_cyclic("luvrxvllmz"), "vluvrxmllz", "CJ-HUMANEVAL-038_l14_c042")
    expectString(decode_cyclic("yjkraiupdsqqqbkqf"), "kyjiradupqsqkqbqf", "CJ-HUMANEVAL-038_l14_c043")
    expectString(decode_cyclic("zokqanoltjcvcunhtzi"), "kzonqatolvjcncuzhti", "CJ-HUMANEVAL-038_l14_c044")
    expectString(decode_cyclic("lfyiffakofpbl"), "ylffifoakbfpl", "CJ-HUMANEVAL-038_l14_c045")
    expectString(decode_cyclic("cobfkmkvnovhpag"), "bcomfknkvhovgpa", "CJ-HUMANEVAL-038_l14_c046")
    expectString(decode_cyclic("vkwbojzsljkxxz"), "wvkjbolzsxjkxz", "CJ-HUMANEVAL-038_l14_c047")
    expectString(decode_cyclic("flwfdvbcwgorixjvic"), "wflvfdwbcrgojixcvi", "CJ-HUMANEVAL-038_l14_c048")
    expectString(decode_cyclic("gmtxnkhdhlctedzsm"), "tgmkxnhhdtlczedsm", "CJ-HUMANEVAL-038_l14_c049")
    expectString(decode_cyclic("hpetctzyijstf"), "ehpttcizytjsf", "CJ-HUMANEVAL-038_l14_c050")
    expectString(decode_cyclic("cypjzfkpzguv"), "pcyfjzzkpvgu", "CJ-HUMANEVAL-038_l14_c051")
    expectString(decode_cyclic("urbygpngvifqb"), "burpygvngqifb", "CJ-HUMANEVAL-038_l14_c052")
    expectString(decode_cyclic("hcdsyfazlgmkpdwvh"), "dhcfsylazkgmwpdvh", "CJ-HUMANEVAL-038_l14_c053")
    expectString(decode_cyclic("tgoeuuucfjadcnkvzaqs"), "otgueufucdjakcnavzqs", "CJ-HUMANEVAL-038_l14_c054")
    expectString(decode_cyclic("ontboiguoopcm"), "toniboogucopm", "CJ-HUMANEVAL-038_l14_c055")
    expectString(decode_cyclic("rtvvfvipzhcntxrygum"), "vrtvvfzipnhcrtxuygm", "CJ-HUMANEVAL-038_l14_c056")
    expectString(decode_cyclic("iowajmtexvw"), "wiomajxtevw", "CJ-HUMANEVAL-038_l14_c057")
    expectString(decode_cyclic("glfxvarpbvzqfgf"), "fglaxvbrpqvzffg", "CJ-HUMANEVAL-038_l14_c058")
    expectString(decode_cyclic("irikhaegcl"), "iirakhcegl", "CJ-HUMANEVAL-038_l14_c059")
    expectString(decode_cyclic("jrieqtzhmpyle"), "ijrteqmzhlpye", "CJ-HUMANEVAL-038_l14_c060")
    expectString(decode_cyclic("etroippliaoexqgso"), "retpoiipleaogxqso", "CJ-HUMANEVAL-038_l14_c061")
    expectString(decode_cyclic("dlivnwdnkowcusdhay"), "idlwvnkdncowdusyha", "CJ-HUMANEVAL-038_l14_c062")
    expectString(decode_cyclic("syqogzbqxwpwmvlqxfmv"), "qsyzogxbqwwplmvfqxmv", "CJ-HUMANEVAL-038_l14_c063")
    expectString(decode_cyclic("tfsmmswdwtalqozim"), "stfsmmwwdltazqoim", "CJ-HUMANEVAL-038_l14_c064")
    expectString(decode_cyclic("lndqcueircfmuxd"), "dlnuqcreimcfdux", "CJ-HUMANEVAL-038_l14_c065")
    expectString(decode_cyclic("wrxxahbwooiszkuam"), "xwrhxaobwsoiuzkam", "CJ-HUMANEVAL-038_l14_c066")
    expectString(decode_cyclic("gcsrsgdqkwkcq"), "sgcgrskdqcwkq", "CJ-HUMANEVAL-038_l14_c067")
    expectString(decode_cyclic("jqpevxmnttfxdrgr"), "pjqxevtmnxtfgdrr", "CJ-HUMANEVAL-038_l14_c068")
    expectString(decode_cyclic("sjhguxvzpirjtf"), "hsjxgupvzjirtf", "CJ-HUMANEVAL-038_l14_c069")
    expectString(decode_cyclic("lbrodnmfngwjo"), "rlbnodnmfjgwo", "CJ-HUMANEVAL-038_l14_c070")
    expectString(decode_cyclic("xydmemrpekwtupnyy"), "dxymmeerptkwnupyy", "CJ-HUMANEVAL-038_l14_c071")
    expectString(decode_cyclic("gwfqpedjmjfu"), "fgweqpmdjujf", "CJ-HUMANEVAL-038_l14_c072")
    expectString(decode_cyclic("skpbifvzwf"), "pskfbiwvzf", "CJ-HUMANEVAL-038_l14_c073")
    expectString(decode_cyclic("pipnmpfxdmth"), "ppipnmdfxhmt", "CJ-HUMANEVAL-038_l14_c074")
    expectString(decode_cyclic("zjbmxlmlys"), "bzjlmxymls", "CJ-HUMANEVAL-038_l14_c075")
    expectString(decode_cyclic("cbmhrqovedhozfpq"), "mcbqhreovodhpzfq", "CJ-HUMANEVAL-038_l14_c076")
    expectString(decode_cyclic("fhryilngnajqqw"), "rfhlyinngqajqw", "CJ-HUMANEVAL-038_l14_c077")
    expectString(decode_cyclic("pogydbjlockmqqjrkxm"), "gpobydojlmckjqqxrkm", "CJ-HUMANEVAL-038_l14_c078")
    expectString(decode_cyclic("nkfzxrbxbptaeupo"), "fnkrzxbbxaptpeuo", "CJ-HUMANEVAL-038_l14_c079")
    expectString(decode_cyclic("wjnjljbqonv"), "nwjjjlobqnv", "CJ-HUMANEVAL-038_l14_c080")
    expectString(decode_cyclic("gojxvlosgfb"), "jgolxvgosfb", "CJ-HUMANEVAL-038_l14_c081")
    expectString(decode_cyclic("acduiecwonyfazcrsvp"), "daceuiocwfnycazvrsp", "CJ-HUMANEVAL-038_l14_c082")
    expectString(decode_cyclic("dovtralzvodxymblknsa"), "vdoatrvlzxodbymnlksa", "CJ-HUMANEVAL-038_l14_c083")
    expectString(decode_cyclic("jmrssmjtljgdat"), "rjmmssljtdjgat", "CJ-HUMANEVAL-038_l14_c084")
    expectString(decode_cyclic("uznlctxzvjfudwvji"), "nuztlcvxzujfvdwji", "CJ-HUMANEVAL-038_l14_c085")
    expectString(decode_cyclic("swtsfgsogjadzutg"), "tswgsfgsodjatzug", "CJ-HUMANEVAL-038_l14_c086")
    expectString(decode_cyclic("qpsvmiwwaxpbnhw"), "sqpivmawwbxpwnh", "CJ-HUMANEVAL-038_l14_c087")
    expectString(decode_cyclic("ndtfhfyzjqaxkytck"), "tndffhjyzxqatkyck", "CJ-HUMANEVAL-038_l14_c088")
    expectString(decode_cyclic("zhxxwacepyh"), "xzhaxwpceyh", "CJ-HUMANEVAL-038_l14_c089")
    expectString(decode_cyclic("fcsehyafmnouohkeznki"), "sfcyehmafunokohnezki", "CJ-HUMANEVAL-038_l14_c090")
    expectString(decode_cyclic("cgobscaxvjtvqcvbfa"), "ocgcbsvaxvjtvqcabf", "CJ-HUMANEVAL-038_l14_c091")
    expectString(decode_cyclic("yvbdpugtwgmqylb"), "byvudpwgtqgmbyl", "CJ-HUMANEVAL-038_l14_c092")
    expectString(decode_cyclic("dkybhltulwimocxvpcyq"), "ydklbhltumwixoccvpyq", "CJ-HUMANEVAL-038_l14_c093")
    expectString(decode_cyclic("komgjzidbsuzxshtofh"), "mkozgjbidzsuhxsftoh", "CJ-HUMANEVAL-038_l14_c094")
    expectString(decode_cyclic("kfgzqqkuloc"), "gkfqzqlkuoc", "CJ-HUMANEVAL-038_l14_c095")
    expectString(decode_cyclic("tiehwjxtwqbyd"), "etijhwwxtyqbd", "CJ-HUMANEVAL-038_l14_c096")
    expectString(decode_cyclic("pssddyuufjyoeizp"), "spsyddfuuojyzeip", "CJ-HUMANEVAL-038_l14_c097")
    expectString(decode_cyclic("nalxlcmwnan"), "lnacxlnmwan", "CJ-HUMANEVAL-038_l14_c098")
    expectString(decode_cyclic("wqatjhgibs"), "awqhtjbgis", "CJ-HUMANEVAL-038_l14_c099")
    expectString(decode_cyclic("utyqyjgqqwd"), "yutjqyqgqwd", "CJ-HUMANEVAL-038_l14_c100")
    println("CJ-HUMANEVAL-038 ok")
    return 0
}
