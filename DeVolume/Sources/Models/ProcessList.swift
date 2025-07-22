import Foundation

class ProcessList {
    static func processesUsingVolume(atPath path: String) -> [ProcessInfo] {
        var processInfos: [ProcessInfo] = []
        let task = Process()
        let pipe = Pipe()
        
        // Use lsof to find processes using the given path
        // -F n: output fields for easier parsing, -w: suppress warnings
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-F", "pn", "+D", path]
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
        } catch {
            print("Failed to run lsof: \\(error)")
            return []
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }
        
        // lsof -F pn output: lines starting with 'p' (PID) and 'n' (process name)
        var currentPID: Int?
        var currentName: String?
        for line in output.split(separator: "\\n") {
            if line.hasPrefix("p") {
                if let pid = Int(line.dropFirst()) {
                    currentPID = pid
                }
            } else if line.hasPrefix("n") {
                currentName = String(line.dropFirst())
                if let name = currentName, let pid = currentPID {
                    processInfos.append(ProcessInfo(name: name, pid: pid))
                    currentName = nil
                    currentPID = nil
                }
            }
        }
        
        // Remove duplicates (sometimes lsof returns multiple lines for same process)
        let unique = Dictionary(grouping: processInfos, by: { $0.pid }).compactMap { $0.value.first }
        return unique
    }
}
