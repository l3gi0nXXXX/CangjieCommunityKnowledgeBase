package cangjie_community_knowledge_base

public class CkbMcpProtocolServer {
    private let delegate: CkbMcpStdioServer

    public init(service: CkbCommandLoopService) {
        this.delegate = CkbMcpStdioServer(service)
    }

    public func handleMessage(message: String, protocolVersion: String, serverName: String): CkbMcpDispatchResult {
        this.delegate.handleMessage(message, protocolVersion, serverName)
    }

    public func handleRequest(message: String, protocolVersion: String, serverName: String): String {
        this.handleMessage(message, protocolVersion, serverName).payload
    }
}
