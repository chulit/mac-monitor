import Darwin
import Foundation
import IOKit

/// Reads temperature sensors through the AppleSMC user client and shapes
/// them into the sampling seam's samples in degrees Celsius. Keys are
/// injected (model-specific, never assumed); each unreadable key reports
/// unavailable for its metric instead of failing the collection.
public struct TemperatureSensor: Sendable, Equatable {
  public let metric: String
  public let key: String

  public init(metric: String, key: String) {
    self.metric = metric
    self.key = key
  }
}

public final class TemperatureCollector {
  /// Verified on MacBook Air M2: Tp01 is CPU, Tp05 a second CPU-zone
  /// sensor of undocumented role, Ts0S storage. No GPU or per-cluster
  /// keys exist on this model.
  public static let appleSilicon = [
    TemperatureSensor(metric: "temperature", key: "Tp01"),
    TemperatureSensor(metric: "temperature.secondary", key: "Tp05"),
    TemperatureSensor(metric: "temperature.storage", key: "Ts0S"),
  ]

  private let sensors: [TemperatureSensor]
  private var connection: io_connect_t = 0

  public init(sensors: [TemperatureSensor] = TemperatureCollector.appleSilicon) {
    self.sensors = sensors
  }

  deinit {
    if connection != 0 {
      IOServiceClose(connection)
    }
  }

  public func collect(now: Date) -> [Sample] {
    sensors.map { sensor in
      guard let celsius = read(sensor.key) else {
        return Sample(timestamp: now, availability: .unavailable, metric: sensor.metric)
      }
      return Sample(timestamp: now, availability: .available, value: celsius, metric: sensor.metric)
    }
  }

  private func read(_ key: String) -> Double? {
    let code = keyCode(key)
    guard open(),
      let (dataSize, type) = keyInfo(code),
      dataSize > 0, dataSize <= 32,
      let bytes = readBytes(code, size: dataSize, type: type)
    else {
      return nil
    }
    switch type {
    case "flt ":
      return bytes.withUnsafeBytes { buffer in
        guard let base = buffer.baseAddress else {
          return nil
        }
        var value: Float = 0
        memcpy(&value, base, min(buffer.count, 4))
        return Double(value)
      }
    case "sp78":
      guard bytes.count >= 2 else {
        return nil
      }
      let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
      return Double(raw) / 256.0
    default:
      return nil
    }
  }

  @discardableResult
  private func open() -> Bool {
    if connection != 0 {
      return true
    }
    guard let matching = IOServiceMatching("AppleSMC") as CFDictionary? else {
      return false
    }
    let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
    guard service != 0 else {
      return false
    }
    defer { IOObjectRelease(service) }
    var connection: io_connect_t = 0
    guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else {
      return false
    }
    self.connection = connection
    return true
  }

  private func keyInfo(_ code: UInt32) -> (size: UInt32, type: String)? {
    var input = SMCParam()
    input.key = code
    input.data8 = 9
    guard let output = smcCall(&input), output.result == 0 else {
      return nil
    }
    return (output.keyInfo.dataSize, ostype(output.keyInfo.dataType))
  }

  private func readBytes(_ code: UInt32, size: UInt32, type: String) -> [UInt8]? {
    var input = SMCParam()
    input.key = code
    input.data8 = 5
    input.data32 = size
    input.keyInfo.dataSize = size
    input.keyInfo.dataType = keyCode(type)
    guard let output = smcCall(&input), output.result == 0 else {
      return nil
    }
    return withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(size))) }
  }

  private func smcCall(_ input: inout SMCParam) -> SMCParam? {
    var output = SMCParam()
    var outputSize = MemoryLayout<SMCParam>.size
    let status = withUnsafePointer(to: &input) { inPtr in
      withUnsafeMutablePointer(to: &output) { outPtr in
        IOConnectCallStructMethod(
          connection, 2,
          UnsafeRawPointer(inPtr), MemoryLayout<SMCParam>.size,
          UnsafeMutableRawPointer(outPtr), &outputSize
        )
      }
    }
    guard status == KERN_SUCCESS else {
      return nil
    }
    return output
  }

  private func keyCode(_ name: String) -> UInt32 {
    var result: UInt32 = 0
    for byte in name.utf8.prefix(4) {
      result = (result << 8) | UInt32(byte)
    }
    return result
  }

  private func ostype(_ code: UInt32) -> String {
    let b0 = CChar(bitPattern: UInt8(truncatingIfNeeded: code >> 24))
    let b1 = CChar(bitPattern: UInt8(truncatingIfNeeded: code >> 16))
    let b2 = CChar(bitPattern: UInt8(truncatingIfNeeded: code >> 8))
    let b3 = CChar(bitPattern: UInt8(truncatingIfNeeded: code))
    return [b0, b1, b2, b3, 0].withUnsafeBufferPointer { buffer in
      String(cString: buffer.baseAddress!)
    }
  }
}

private struct SMCVers {
  var major: CChar = 0
  var minor: CChar = 0
  var build: CChar = 0
  var reserved: CChar = 0
  var release: UInt16 = 0
}

private struct SMCPLimit {
  var version: UInt16 = 0
  var length: UInt16 = 0
  var cpu: UInt32 = 0
  var gpu: UInt32 = 0
  var mem: UInt32 = 0
}

private struct SMCKeyInfo {
  var dataSize: UInt32 = 0
  var dataType: UInt32 = 0
  var dataAttributes: UInt8 = 0
  var pad0: UInt8 = 0
  var pad1: UInt8 = 0
  var pad2: UInt8 = 0
}

private struct SMCParam {
  var key: UInt32 = 0
  var vers = SMCVers()
  var pLimit = SMCPLimit()
  var keyInfo = SMCKeyInfo()
  var result: UInt8 = 0
  var status: UInt8 = 0
  var data8: UInt8 = 0
  var data32: UInt32 = 0
  var bytes: (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
  ) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

  init() {
    assert(MemoryLayout<SMCParam>.size == 80, "SMC user-client structure must be 80 bytes")
  }
}
