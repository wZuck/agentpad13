import Foundation
import IOKit.hid
import AgentPadCore

// All IOKit callbacks and request state live on the main run loop. Opening
// without seize permits Codex Desktop to keep using the same endpoint.
// Request state is confined to the main run loop; the unchecked conformance
// documents that contract for the delayed timeout closure.
final class HIDTransport: NSObject, @unchecked Sendable {
    struct Device: Identifiable {
        let id: Int
        let label: String
        let handle: IOHIDDevice
        let version: Int
    }
    private let manager: IOHIDManager
    private var device: IOHIDDevice?
    private let input = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    private var decoder = RPCDecoder()
    private var nextID: UInt16 = UInt16.random(in: 700...990)
    private var pending: (id: UInt16, completion: (Result<[String: Any], Error>) -> Void)?
    private var pendingGeneration: UInt64 = 0
    var onDisconnect: (() -> Void)?

    override init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        super.init()
        let match: [String: Any] = [
            kIOHIDVendorIDKey: 0x303A, kIOHIDProductIDKey: 0x8360,
            kIOHIDDeviceUsagePageKey: 0xFF00, kIOHIDDeviceUsageKey: 0x61
        ]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, removed in
            guard let context else { return }
            let transport = Unmanaged<HIDTransport>.fromOpaque(context).takeUnretainedValue()
            if let current = transport.device, CFEqual(current, removed) {
                transport.disconnect()
                transport.onDisconnect?()
            }
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    deinit {
        disconnect()
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, 0)
        input.deallocate()
    }

    func discover() throws -> [Device] {
        let result = IOHIDManagerOpen(manager, 0)
        guard result == kIOReturnSuccess else { throw failure("无法访问 HID", result) }
        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        return devices.map { handle in
            let location = (IOHIDDeviceGetProperty(handle, kIOHIDLocationIDKey as CFString) as? NSNumber)?.intValue ?? 0
            let serial = IOHIDDeviceGetProperty(handle, kIOHIDSerialNumberKey as CFString) as? String ?? ""
            let version = (IOHIDDeviceGetProperty(handle, kIOHIDVersionNumberKey as CFString) as? NSNumber)?.intValue ?? 0
            let renderedVersion = String(format: "v%04X", version)
            return Device(
                id: location,
                label: "OAI · \(renderedVersion) · USB \(String(location, radix: 16)) \(serial)",
                handle: handle,
                version: version
            )
        }.sorted { $0.id < $1.id }
    }

    func connect(_ target: Device) throws {
        disconnect()
        let result = IOHIDDeviceOpen(target.handle, 0)
        guard result == kIOReturnSuccess else { throw failure("无法打开设备", result) }
        device = target.handle
        IOHIDDeviceScheduleWithRunLoop(target.handle, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceRegisterInputReportCallback(target.handle, input, 64, { context, result, _, _, reportID, report, count in
            guard let context, result == kIOReturnSuccess, reportID == 6 else { return }
            let transport = Unmanaged<HIDTransport>.fromOpaque(context).takeUnretainedValue()
            var bytes = Array(UnsafeBufferPointer(start: report, count: count))
            // Some HID backends omit the report-ID byte in their callback.
            if bytes.count == 63 { bytes.insert(6, at: 0) }
            transport.receive(bytes)
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    func disconnect() {
        finish(.failure(PadError.disconnected))
        if let device {
            IOHIDDeviceRegisterInputReportCallback(device, input, 64, nil, nil)
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(device, 0)
        }
        device = nil
        decoder.reset()
    }

    func request(_ method: String, map: Keymap? = nil, led: LEDSettings? = nil) async throws -> [String: Any] {
        guard let device else { throw PadError.disconnected }
        guard pending == nil else { throw PadError.busy }
        nextID = nextID >= 998 ? 700 : nextID + 1
        let id = nextID
        let frames = try OAIWire.request(method: method, id: id, map: map, led: led)
        pendingGeneration &+= 1
        let generation = pendingGeneration
        return try await withCheckedThrowingContinuation { continuation in
            pending = (id, { continuation.resume(with: $0) })
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.requestTimedOut(generation: generation)
            }
            for frame in frames {
                let result = frame.withUnsafeBufferPointer {
                    IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 6, $0.baseAddress!, frame.count)
                }
                if result != kIOReturnSuccess {
                    finish(.failure(failure("HID 写入失败", result)))
                    break
                }
            }
        }
    }

    private func requestTimedOut(generation: UInt64) {
        guard generation == pendingGeneration, pending != nil else { return }
        decoder.reset()
        finish(.failure(PadError.timeout))
    }

    private func receive(_ bytes: [UInt8]) {
        do {
            for message in try decoder.receive(bytes) {
                guard let id = message["id"] as? NSNumber, id.intValue == Int(pending?.id ?? 0) else { continue }
                if let error = message["error"] {
                    finish(.failure(PadError.device("固件拒绝请求：\(error)")))
                } else if message["result"] != nil {
                    finish(.success(message))
                }
            }
        } catch {
            // Other processes may also receive reports; malformed or foreign
            // traffic must never be interpreted as a successful configuration.
            decoder.reset()
        }
    }

    private func finish(_ result: Result<[String: Any], Error>) {
        let completion = pending?.completion
        pending = nil
        completion?(result)
    }

    private func failure(_ label: String, _ code: IOReturn) -> Error {
        PadError.device("\(label)（\(String(format: "0x%08x", code))）。请检查 USB 连接及系统的输入监控权限。")
    }
}
