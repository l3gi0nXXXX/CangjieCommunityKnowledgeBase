package cangjie_community_knowledge_base

public class CkbMcpProtocolServer {
    private let delegate: CkbMcpStdioServer

    public init(service: CkbCommandLoopService, boundTaskContextBase64!: String = "", boundTaskContextHash!: String = "") {
        this.delegate = CkbMcpStdioServer(service, boundTaskContextBase64: boundTaskContextBase64, boundTaskContextHash: boundTaskContextHash)
    }

    public func handleMessage(message: String, protocolVersion: String, serverName: String): CkbMcpDispatchResult {
        this.delegate.handleMessage(message, protocolVersion, serverName)
    }

    public func handleRequest(message: String, protocolVersion: String, serverName: String): String {
        this.handleMessage(message, protocolVersion, serverName).payload
    }
}
