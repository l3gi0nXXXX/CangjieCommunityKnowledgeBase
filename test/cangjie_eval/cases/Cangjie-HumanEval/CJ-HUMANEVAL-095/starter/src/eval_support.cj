package cangjie_humaneval_095

import std.collection.*

public class EvalValue {
    public var kind: String = "none"
    public var intValue: Int64 = 0
    public var floatValue: Float64 = 0.0
    public var stringValue: String = ""
    public var boolValue: Bool = false
}

public class EvalEntry {
    public var key: EvalValue = EvalValue()
    public var value: EvalValue = EvalValue()
}

public func evalNone(): EvalValue { let v = EvalValue(); v.kind = "none"; v }
public func evalInt(value: Int64): EvalValue { let v = EvalValue(); v.kind = "int"; v.intValue = value; v.floatValue = Float64(value); v }
public func evalFloat(value: Float64): EvalValue { let v = EvalValue(); v.kind = "float"; v.floatValue = value; v }
public func evalString(value: String): EvalValue { let v = EvalValue(); v.kind = "string"; v.stringValue = value; v }
public func evalBool(value: Bool): EvalValue { let v = EvalValue(); v.kind = "bool"; v.boolValue = value; v }
public func evalEmptyList(): EvalValue { let v = EvalValue(); v.kind = "list"; v }
public func evalEmptyMap(): EvalValue { let v = EvalValue(); v.kind = "map"; v }
public func evalEntry(key: EvalValue, value: EvalValue): EvalEntry { let e = EvalEntry(); e.key = key; e.value = value; e }
