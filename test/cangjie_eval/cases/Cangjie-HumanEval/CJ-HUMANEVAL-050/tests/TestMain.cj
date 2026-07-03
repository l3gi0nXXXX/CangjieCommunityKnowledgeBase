package cangjie_humaneval_050

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
    expectString(decode_shift("zferjuiaon"), "uazmepdvji", "CJ-HUMANEVAL-050_l15_c001")
    expectString(decode_shift("rpstbvkaavhqalr"), "mknowqfvvqclvgm", "CJ-HUMANEVAL-050_l15_c002")
    expectString(decode_shift("ctjjzgrqbsprbgjtsn"), "xoeeubmlwnkmwbeoni", "CJ-HUMANEVAL-050_l15_c003")
    expectString(decode_shift("fxjaucjmnh"), "asevpxehic", "CJ-HUMANEVAL-050_l15_c004")
    expectString(decode_shift("trhbkqguvhkpc"), "omcwflbpqcfkx", "CJ-HUMANEVAL-050_l15_c005")
    expectString(decode_shift("zzkogdbajvuwdjq"), "uufjbywveqpryel", "CJ-HUMANEVAL-050_l15_c006")
    expectString(decode_shift("miyycjcgwgrerzxgtvpo"), "hdttxexbrbmzmusboqkj", "CJ-HUMANEVAL-050_l15_c007")
    expectString(decode_shift("zljilebtyh"), "ugedgzwotc", "CJ-HUMANEVAL-050_l15_c008")
    expectString(decode_shift("kcgdrmkvvzu"), "fxbymhfqqup", "CJ-HUMANEVAL-050_l15_c009")
    expectString(decode_shift("cvzwjycystwfp"), "xquretxtnorak", "CJ-HUMANEVAL-050_l15_c010")
    expectString(decode_shift("stcbnexruwz"), "noxwizsmpru", "CJ-HUMANEVAL-050_l15_c011")
    expectString(decode_shift("gnaiepxoxatviyry"), "bivdzksjsvoqdtmt", "CJ-HUMANEVAL-050_l15_c012")
    expectString(decode_shift("wlgzqvnapreigqpfa"), "rgbulqivkmzdblkav", "CJ-HUMANEVAL-050_l15_c013")
    expectString(decode_shift("peuponwhqldxw"), "kzpkjirclgysr", "CJ-HUMANEVAL-050_l15_c014")
    expectString(decode_shift("hatibnliozdxvk"), "cvodwigdjuysqf", "CJ-HUMANEVAL-050_l15_c015")
    expectString(decode_shift("uzwrpneozbpaud"), "purmkizjuwkvpy", "CJ-HUMANEVAL-050_l15_c016")
    expectString(decode_shift("sumpurnnvgjkksvp"), "nphkpmiiqbeffnqk", "CJ-HUMANEVAL-050_l15_c017")
    expectString(decode_shift("qqvlidovzzpp"), "llqgdyjquukk", "CJ-HUMANEVAL-050_l15_c018")
    expectString(decode_shift("aqgrroonfynviz"), "vlbmmjjiatiqdu", "CJ-HUMANEVAL-050_l15_c019")
    expectString(decode_shift("cmckozftabxoceofons"), "xhxfjuaovwsjxzjajin", "CJ-HUMANEVAL-050_l15_c020")
    expectString(decode_shift("eahtjznlvrjrzjbbbs"), "zvcoeuigqmemuewwwn", "CJ-HUMANEVAL-050_l15_c021")
    expectString(decode_shift("kwbzmkxsrhjxqaohuiy"), "frwuhfsnmceslvjcpdt", "CJ-HUMANEVAL-050_l15_c022")
    expectString(decode_shift("rxrecoclppkdm"), "msmzxjxgkkfyh", "CJ-HUMANEVAL-050_l15_c023")
    expectString(decode_shift("hyxhdllednvmopl"), "ctscyggzyiqhjkg", "CJ-HUMANEVAL-050_l15_c024")
    expectString(decode_shift("dkorvilrsuwv"), "yfjmqdgmnprq", "CJ-HUMANEVAL-050_l15_c025")
    expectString(decode_shift("ljteoggboppjoxhm"), "geozjbbwjkkejsch", "CJ-HUMANEVAL-050_l15_c026")
    expectString(decode_shift("omvsyosamnqiqss"), "jhqntjnvhildlnn", "CJ-HUMANEVAL-050_l15_c027")
    expectString(decode_shift("ogplsqzccwmth"), "jbkgnluxxrhoc", "CJ-HUMANEVAL-050_l15_c028")
    expectString(decode_shift("yliqqaohtjtjaectuenw"), "tgdllvjcoeoevzxopzir", "CJ-HUMANEVAL-050_l15_c029")
    expectString(decode_shift("wqdnykrwqpfkvjdrjn"), "rlyitfmrlkafqeymei", "CJ-HUMANEVAL-050_l15_c030")
    expectString(decode_shift("sngneybupaaahavlus"), "nibiztwpkvvvcvqgpn", "CJ-HUMANEVAL-050_l15_c031")
    expectString(decode_shift("fdvlwalpuirlojlriumi"), "ayqgrvgkpdmgjegmdphd", "CJ-HUMANEVAL-050_l15_c032")
    expectString(decode_shift("nifmkensnpnjtna"), "idahfzinikieoiv", "CJ-HUMANEVAL-050_l15_c033")
    expectString(decode_shift("qqsueiuxxchnrua"), "llnpzdpssxcimpv", "CJ-HUMANEVAL-050_l15_c034")
    expectString(decode_shift("rqtwqqdxbawdwz"), "mlorllyswvryru", "CJ-HUMANEVAL-050_l15_c035")
    expectString(decode_shift("djueftidzxzbzzpelbr"), "yepzaodyusuwuukzgwm", "CJ-HUMANEVAL-050_l15_c036")
    expectString(decode_shift("ptdeoptepzpyvoahwzrj"), "koyzjkozkuktqjvcrume", "CJ-HUMANEVAL-050_l15_c037")
    expectString(decode_shift("juhhktvkjhrbexrpdpb"), "epccfoqfecmwzsmkykw", "CJ-HUMANEVAL-050_l15_c038")
    expectString(decode_shift("wndkyfthpnip"), "riyftaockidk", "CJ-HUMANEVAL-050_l15_c039")
    expectString(decode_shift("yjfsdfzdtlohuunqds"), "teanyauyogjcppilyn", "CJ-HUMANEVAL-050_l15_c040")
    expectString(decode_shift("xvpesrnuvb"), "sqkznmipqw", "CJ-HUMANEVAL-050_l15_c041")
    expectString(decode_shift("bweufglyylxgxwafcueq"), "wrzpabgttgsbsrvaxpzl", "CJ-HUMANEVAL-050_l15_c042")
    expectString(decode_shift("bblmhfgysvpkqnep"), "wwghcabtnqkflizk", "CJ-HUMANEVAL-050_l15_c043")
    expectString(decode_shift("yuxjrsieqmflgj"), "tpsemndzlhagbe", "CJ-HUMANEVAL-050_l15_c044")
    expectString(decode_shift("gekgosahqhmfxraxb"), "bzfbjnvclchasmvsw", "CJ-HUMANEVAL-050_l15_c045")
    expectString(decode_shift("hmkrgqlaionkorjkw"), "chfmblgvdjifjmefr", "CJ-HUMANEVAL-050_l15_c046")
    expectString(decode_shift("howhbspjquafzu"), "cjrcwnkelpvaup", "CJ-HUMANEVAL-050_l15_c047")
    expectString(decode_shift("yokgisifuvlclnvrig"), "tjfbdndapqgxgiqmdb", "CJ-HUMANEVAL-050_l15_c048")
    expectString(decode_shift("egfqdgqwondzhoj"), "zbalyblrjiyucje", "CJ-HUMANEVAL-050_l15_c049")
    expectString(decode_shift("uqlnsamclpgbgpvml"), "plginvhxgkbwbkqhg", "CJ-HUMANEVAL-050_l15_c050")
    expectString(decode_shift("yudrjdiprgns"), "tpymeydkmbin", "CJ-HUMANEVAL-050_l15_c051")
    expectString(decode_shift("yadzucjrinme"), "tvyupxemdihz", "CJ-HUMANEVAL-050_l15_c052")
    expectString(decode_shift("kfskdzkinyutmzbaufi"), "fanfyufditpohuwvpad", "CJ-HUMANEVAL-050_l15_c053")
    expectString(decode_shift("tskbqqbxhzzg"), "onfwllwscuub", "CJ-HUMANEVAL-050_l15_c054")
    expectString(decode_shift("azakfkvzugelbypmrhx"), "vuvfafqupbzgwtkhmcs", "CJ-HUMANEVAL-050_l15_c055")
    expectString(decode_shift("pmbilhgdzojhwyrfl"), "khwdgcbyujecrtmag", "CJ-HUMANEVAL-050_l15_c056")
    expectString(decode_shift("yuazsinwvgqsxseolq"), "tpvundirqblnsnzjgl", "CJ-HUMANEVAL-050_l15_c057")
    expectString(decode_shift("dyeinspvbiloiasozi"), "ytzdinkqwdgjdvnjud", "CJ-HUMANEVAL-050_l15_c058")
    expectString(decode_shift("jbvjrlafgfcplr"), "ewqemgvabaxkgm", "CJ-HUMANEVAL-050_l15_c059")
    expectString(decode_shift("jphuksmxjn"), "ekcpfnhsei", "CJ-HUMANEVAL-050_l15_c060")
    expectString(decode_shift("etovmuuuntjzzjdx"), "zojqhpppioeuueys", "CJ-HUMANEVAL-050_l15_c061")
    expectString(decode_shift("hqbmigqvywhpwziof"), "clwhdblqtrckrudja", "CJ-HUMANEVAL-050_l15_c062")
    expectString(decode_shift("gizfsjhhnybf"), "bduaneccitwa", "CJ-HUMANEVAL-050_l15_c063")
    expectString(decode_shift("jjpsqhtnmn"), "eeknlcoihi", "CJ-HUMANEVAL-050_l15_c064")
    expectString(decode_shift("livicbycerdgcl"), "gdqdxwtxzmybxg", "CJ-HUMANEVAL-050_l15_c065")
    expectString(decode_shift("hmxgvvxcqqfs"), "chsbqqsxllan", "CJ-HUMANEVAL-050_l15_c066")
    expectString(decode_shift("jstvfzeqatv"), "enoqauzlvoq", "CJ-HUMANEVAL-050_l15_c067")
    expectString(decode_shift("tzvbxdquiyfq"), "ouqwsylpdtal", "CJ-HUMANEVAL-050_l15_c068")
    expectString(decode_shift("rjflqiksmstefsh"), "meagldfnhnozanc", "CJ-HUMANEVAL-050_l15_c069")
    expectString(decode_shift("ecebycrmmewbq"), "zxzwtxmhhzrwl", "CJ-HUMANEVAL-050_l15_c070")
    expectString(decode_shift("ygfhkvlyoes"), "tbacfqgtjzn", "CJ-HUMANEVAL-050_l15_c071")
    expectString(decode_shift("cshidaxyqvhbz"), "xncdyvstlqcwu", "CJ-HUMANEVAL-050_l15_c072")
    expectString(decode_shift("uveufwerutdjnggg"), "pqzparzmpoyeibbb", "CJ-HUMANEVAL-050_l15_c073")
    expectString(decode_shift("pysgrhxfexcwfks"), "ktnbmcsazsxrafn", "CJ-HUMANEVAL-050_l15_c074")
    expectString(decode_shift("stffefjcglwggkebc"), "noaazaexbgrbbfzwx", "CJ-HUMANEVAL-050_l15_c075")
    expectString(decode_shift("vyzoxylmjttx"), "qtujstgheoos", "CJ-HUMANEVAL-050_l15_c076")
    expectString(decode_shift("hysihmfrfcji"), "ctndchamaxed", "CJ-HUMANEVAL-050_l15_c077")
    expectString(decode_shift("jnqntcaqeanmo"), "eilioxvlzvihj", "CJ-HUMANEVAL-050_l15_c078")
    expectString(decode_shift("ezmzjoetzgakpriqui"), "zuhuejzoubvfkmdlpd", "CJ-HUMANEVAL-050_l15_c079")
    expectString(decode_shift("bdbvoobtbapmf"), "wywqjjwowvkha", "CJ-HUMANEVAL-050_l15_c080")
    expectString(decode_shift("qvubyffexrmixtoo"), "lqpwtaazsmhdsojj", "CJ-HUMANEVAL-050_l15_c081")
    expectString(decode_shift("fakjtpanylxmprtnp"), "avfeokvitgshkmoik", "CJ-HUMANEVAL-050_l15_c082")
    expectString(decode_shift("koypucnxpcijrixardgf"), "fjtkpxiskxdemdsvmyba", "CJ-HUMANEVAL-050_l15_c083")
    expectString(decode_shift("xlpsviklvyyd"), "sgknqdfgqtty", "CJ-HUMANEVAL-050_l15_c084")
    expectString(decode_shift("sctywbinddzgdp"), "nxotrwdiyyubyk", "CJ-HUMANEVAL-050_l15_c085")
    expectString(decode_shift("srvjteeiiywd"), "nmqeozzddtry", "CJ-HUMANEVAL-050_l15_c086")
    expectString(decode_shift("ywimxwzjzh"), "trdhsrueuc", "CJ-HUMANEVAL-050_l15_c087")
    expectString(decode_shift("njlzakjgkas"), "ieguvfebfvn", "CJ-HUMANEVAL-050_l15_c088")
    expectString(decode_shift("rkfaiobwgw"), "mfavdjwrbr", "CJ-HUMANEVAL-050_l15_c089")
    expectString(decode_shift("jqqvhzlwbhsrliy"), "ellqcugrwcnmgdt", "CJ-HUMANEVAL-050_l15_c090")
    expectString(decode_shift("jhcjbephmtau"), "ecxewzkchovp", "CJ-HUMANEVAL-050_l15_c091")
    expectString(decode_shift("dxpvdtsuvarzu"), "yskqyonpqvmup", "CJ-HUMANEVAL-050_l15_c092")
    expectString(decode_shift("xcqceidglwfnwbk"), "sxlxzdybgrairwf", "CJ-HUMANEVAL-050_l15_c093")
    expectString(decode_shift("qzyyygbfwsdnhwmgeyw"), "lutttbwarnyicrhbztr", "CJ-HUMANEVAL-050_l15_c094")
    expectString(decode_shift("xjlcenorfxkfbqyngf"), "segxzijmasfawltiba", "CJ-HUMANEVAL-050_l15_c095")
    expectString(decode_shift("vmthionljngdlf"), "qhocdjigeibyga", "CJ-HUMANEVAL-050_l15_c096")
    expectString(decode_shift("affwbabfdhsowgoju"), "vaarwvwaycnjrbjep", "CJ-HUMANEVAL-050_l15_c097")
    expectString(decode_shift("dnzoqwwigttyzriact"), "yiujlrrdbootumdvxo", "CJ-HUMANEVAL-050_l15_c098")
    expectString(decode_shift("ncogmjbqjxcphbi"), "ixjbhewlesxkcwd", "CJ-HUMANEVAL-050_l15_c099")
    expectString(decode_shift("bjuqxnegramdbmpjk"), "weplsizbmvhywhkef", "CJ-HUMANEVAL-050_l15_c100")
    println("CJ-HUMANEVAL-050 ok")
    return 0
}
