package cangjie_community_knowledge_base

import std.sync.Mutex

public class CkbAdminOperationGate {
    private let lock: Mutex = Mutex()
    private var busy: Bool = false
    private var owner: String = ""

    public init() {}

    public func enter(operationId: String): Bool {
        synchronized(this.lock) {
            if (this.busy) {
                return false
            }
            this.busy = true
            this.owner = operationId
            true
        }
    }

    public func leave(operationId: String): Unit {
        synchronized(this.lock) {
            if (!this.busy) {
                return
            }
            if (this.owner == operationId || operationId == "") {
                this.busy = false
                this.owner = ""
            }
        }
    }

    public func currentOperation(): String {
        synchronized(this.lock) {
            this.owner
        }
    }
}
