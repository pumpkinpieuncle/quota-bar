import Foundation
import Network

/// Where the HUD server should listen and what it should require.
public struct HUDServerSettings: Sendable, Equatable {
    public var port: UInt16
    /// `false` binds loopback only, which is handy for trying the page on the
    /// Mac itself without exposing anything to the network.
    public var allowsLAN: Bool
    public var token: String

    public init(port: UInt16, allowsLAN: Bool, token: String) {
        self.port = port
        self.allowsLAN = allowsLAN
        self.token = token
    }
}

public enum HUDServerState: Sendable, Equatable {
    case stopped
    case starting
    case running(port: UInt16)
    case failed(String)
}

/// A dependency-free HTTP/1.1 server that serves the HUD page and its data.
///
/// It only ever answers `GET`, only ever reads a snapshot the app pushes into
/// it, and closes every connection after one response — enough for a phone
/// polling every few seconds or an ESP32 waking up once a minute.
public final class HUDServer: @unchecked Sendable {
    public typealias StateHandler = @Sendable (HUDServerState) -> Void

    private let queue = DispatchQueue(label: "local.quotabar.hud", qos: .utility)
    private let lock = NSLock()
    private var listener: NWListener?
    private var settings: HUDServerSettings?
    private var payload: HUDPayload
    private var stateHandler: StateHandler?

    public init(payload: HUDPayload) {
        self.payload = payload
    }

    public func onStateChange(_ handler: @escaping StateHandler) {
        lock.lock()
        stateHandler = handler
        lock.unlock()
    }

    public func update(payload newPayload: HUDPayload) {
        lock.lock()
        payload = newPayload
        lock.unlock()
    }

    public func start(settings newSettings: HUDServerSettings) {
        queue.async { [self] in
            if let current = currentSettings(), current == newSettings, listener != nil {
                return
            }
            stopListener()
            store(settings: newSettings)
            emit(.starting)

            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            if !newSettings.allowsLAN {
                parameters.requiredInterfaceType = .loopback
            }
            guard
                let port = NWEndpoint.Port(rawValue: newSettings.port),
                let listener = try? NWListener(using: parameters, on: port)
            else {
                emit(.failed("port \(newSettings.port) is unavailable"))
                return
            }

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    emit(.running(port: newSettings.port))
                case .failed(let error):
                    // Drop the dead listener so the next status push retries
                    // instead of leaving the HUD permanently switched off.
                    stopListener()
                    emit(.failed(error.localizedDescription))
                case .cancelled:
                    emit(.stopped)
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.start(queue: queue)
            self.listener = listener
        }
    }

    public func stop() {
        queue.async { [self] in
            stopListener()
            store(settings: nil)
            emit(.stopped)
        }
    }

    // MARK: - Connections

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 16 * 1_024
        ) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var accumulated = buffer
            if let data { accumulated.append(data) }

            if error != nil {
                connection.cancel()
                return
            }
            // Headers end at the first blank line; the HUD never reads a body.
            if let range = accumulated.range(of: Data("\r\n\r\n".utf8)) {
                let head = String(decoding: accumulated[..<range.lowerBound], as: UTF8.self)
                respond(to: head, on: connection)
                return
            }
            if isComplete || accumulated.count > 16 * 1_024 {
                connection.cancel()
                return
            }
            receive(on: connection, buffer: accumulated)
        }
    }

    private func respond(to head: String, on connection: NWConnection) {
        let lines = head.split(separator: "\r\n", omittingEmptySubsequences: false)
        let requestLine = lines.first.map(String.init) ?? ""
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            send(.badRequest, on: connection)
            return
        }
        let method = String(parts[0]).uppercased()
        let target = String(parts[1])
        guard method == "GET" || method == "HEAD" else {
            send(.notAllowed, on: connection)
            return
        }

        let headerToken = lines
            .first { $0.lowercased().hasPrefix("x-quota-token:") }
            .map { $0.dropFirst("x-quota-token:".count).trimmingCharacters(in: .whitespaces) }
        let (path, query) = Self.split(target: target)
        let expected = currentSettings()?.token ?? ""
        let provided = query["token"] ?? headerToken ?? ""
        let authorized = expected.isEmpty || provided == expected

        switch path {
        case "/", "/index.html":
            send(.html(HUDWebPage.html), on: connection)
        case "/healthz":
            send(.text("ok\n"), on: connection)
        case "/api/status", "/api/status.json":
            guard authorized else { return send(.unauthorized, on: connection) }
            send(.json(snapshot().jsonData(pretty: query["pretty"] != nil)), on: connection)
        case "/api/hud", "/api/hud.txt":
            guard authorized else { return send(.unauthorized, on: connection) }
            send(.text(snapshot().plainText()), on: connection)
        default:
            send(.notFound, on: connection)
        }
    }

    private enum Response {
        case html(String)
        case json(Data)
        case text(String)
        case notFound
        case unauthorized
        case badRequest
        case notAllowed

        var status: String {
            switch self {
            case .html, .json, .text: "200 OK"
            case .notFound: "404 Not Found"
            case .unauthorized: "401 Unauthorized"
            case .badRequest: "400 Bad Request"
            case .notAllowed: "405 Method Not Allowed"
            }
        }

        var contentType: String {
            switch self {
            case .html: "text/html; charset=utf-8"
            case .json: "application/json; charset=utf-8"
            default: "text/plain; charset=utf-8"
            }
        }

        var body: Data {
            switch self {
            case .html(let text): Data(text.utf8)
            case .json(let data): data
            case .text(let text): Data(text.utf8)
            case .notFound: Data("not found\n".utf8)
            case .unauthorized: Data("missing or wrong token\n".utf8)
            case .badRequest: Data("bad request\n".utf8)
            case .notAllowed: Data("only GET is supported\n".utf8)
            }
        }
    }

    private func send(_ response: Response, on connection: NWConnection) {
        let body = response.body
        let header = """
        HTTP/1.1 \(response.status)\r
        Content-Type: \(response.contentType)\r
        Content-Length: \(body.count)\r
        Cache-Control: no-store\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r

        """
        var data = Data(header.utf8)
        data.append(body)
        connection.send(
            content: data,
            completion: .contentProcessed { _ in connection.cancel() }
        )
    }

    // MARK: - Helpers

    private func snapshot() -> HUDPayload {
        lock.lock()
        defer { lock.unlock() }
        return payload
    }

    private func currentSettings() -> HUDServerSettings? {
        lock.lock()
        defer { lock.unlock() }
        return settings
    }

    private func store(settings newSettings: HUDServerSettings?) {
        lock.lock()
        settings = newSettings
        lock.unlock()
    }

    private func emit(_ state: HUDServerState) {
        lock.lock()
        let handler = stateHandler
        lock.unlock()
        handler?(state)
    }

    private func stopListener() {
        listener?.stateUpdateHandler = nil
        listener?.newConnectionHandler = nil
        listener?.cancel()
        listener = nil
    }

    static func split(target: String) -> (path: String, query: [String: String]) {
        guard let markerIndex = target.firstIndex(of: "?") else {
            return (target, [:])
        }
        let path = String(target[..<markerIndex])
        var query: [String: String] = [:]
        for pair in target[target.index(after: markerIndex)...].split(separator: "&") {
            let halves = pair.split(separator: "=", maxSplits: 1)
            guard let name = halves.first else { continue }
            let value = halves.count > 1 ? String(halves[1]) : ""
            query[String(name)] = value.removingPercentEncoding ?? value
        }
        return (path, query)
    }

    /// IPv4 addresses of the Mac's active interfaces, so the settings panel can
    /// show a URL that a phone on the same Wi-Fi can actually reach.
    public static func localAddresses() -> [String] {
        var addresses: [String] = []
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let pointer = cursor {
            let interface = pointer.pointee
            cursor = interface.ifa_next
            guard
                let addressPointer = interface.ifa_addr,
                addressPointer.pointee.sa_family == UInt8(AF_INET),
                interface.ifa_flags & UInt32(IFF_UP) != 0,
                interface.ifa_flags & UInt32(IFF_LOOPBACK) == 0
            else {
                continue
            }
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                addressPointer,
                socklen_t(addressPointer.pointee.sa_len),
                &buffer,
                socklen_t(buffer.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else { continue }
            let address = String(
                decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
                as: UTF8.self
            )
            if !address.isEmpty, !addresses.contains(address) {
                addresses.append(address)
            }
        }
        return addresses
    }
}
