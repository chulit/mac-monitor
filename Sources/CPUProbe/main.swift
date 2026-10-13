import Darwin
import Foundation

func ticks() -> (user: UInt64, system: UInt64, nice: UInt64, idle: UInt64)? {
  var info = host_cpu_load_info_data_t()
  var count = mach_msg_type_number_t(
    MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
  )
  let host = mach_host_self()
  defer { mach_port_deallocate(mach_task_self_, host) }
  let result = withUnsafeMutablePointer(to: &info) {
    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
      host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
    }
  }
  guard result == KERN_SUCCESS else {
    return nil
  }
  return (
    UInt64(info.cpu_ticks.0), UInt64(info.cpu_ticks.1),
    UInt64(info.cpu_ticks.2), UInt64(info.cpu_ticks.3)
  )
}

guard let first = ticks() else {
  print("no ticks")
  exit(2)
}
Thread.sleep(forTimeInterval: 2.0)
guard let second = ticks() else {
  print("no ticks")
  exit(2)
}
let busy = (second.user &- first.user) + (second.system &- first.system) + (second.nice &- first.nice)
let idle = second.idle &- first.idle
print("user=\(second.user &- first.user) system=\(second.system &- first.system) idle=\(idle)")
print("fraction=\(Double(busy) / Double(busy + idle))")
