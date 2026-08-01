import Darwin
import Foundation

/// Polls host-wide CPU and memory stats via Mach APIs (no `top` shell-out,
/// no third-party deps) so the collapsed notch pill can show a live,
/// glanceable strip like boring-notch's system widgets.
@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var cpuUsage: Double = 0      // 0...100
    @Published private(set) var memoryUsedFraction: Double = 0 // 0...1

    private var timer: Timer?
    private var previousCPUTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?

    func start(interval: TimeInterval = 2) {
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.sample() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        sampleCPU()
        sampleMemory()
    }

    private func sampleCPU() {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &cpuLoad) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        let user = cpuLoad.cpu_ticks.0
        let system = cpuLoad.cpu_ticks.1
        let idle = cpuLoad.cpu_ticks.2
        let nice = cpuLoad.cpu_ticks.3

        if let previous = previousCPUTicks {
            let userDelta = Double(user &- previous.user)
            let systemDelta = Double(system &- previous.system)
            let idleDelta = Double(idle &- previous.idle)
            let niceDelta = Double(nice &- previous.nice)
            let total = userDelta + systemDelta + idleDelta + niceDelta
            if total > 0 {
                cpuUsage = ((userDelta + systemDelta + niceDelta) / total) * 100
            }
        }
        previousCPUTicks = (user, system, idle, nice)
    }

    private func sampleMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed
        let total = ProcessInfo.processInfo.physicalMemory
        guard total > 0 else { return }
        memoryUsedFraction = Double(used) / Double(total)
    }
}
