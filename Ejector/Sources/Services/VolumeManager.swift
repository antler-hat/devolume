import Foundation

struct VolumeEjectResult {
    let successful: [Volume]
    let blocking: [Volume: [ProcessInfo]]
    let failedWithoutProcesses: [Volume]

    var isSuccess: Bool {
        return blocking.isEmpty && failedWithoutProcesses.isEmpty
    }
}

final class VolumeManager {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func enumerateExternalVolumes() -> [Volume] {
        var result: [Volume] = []
        let keys: Set<URLResourceKey> = [
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeURLForRemountingKey,
            .volumeNameKey,
            .volumeLocalizedNameKey,
            .volumeIsInternalKey,
            .volumeIsRootFileSystemKey,
        ]

        guard
            let mountedVolumeURLs = fileManager.mountedVolumeURLs(
                includingResourceValuesForKeys: Array(keys), options: [.skipHiddenVolumes])
        else {
            return result
        }

        for url in mountedVolumeURLs {
            do {
                let resourceValues = try url.resourceValues(forKeys: keys)
                let isRemovable = resourceValues.volumeIsRemovable ?? false
                let isEjectable = resourceValues.volumeIsEjectable ?? false
                let isInternal = resourceValues.volumeIsInternal ?? true
                let isRoot = resourceValues.volumeIsRootFileSystem ?? false
                let volumeName = resourceValues.volumeLocalizedName ?? url.lastPathComponent

                if isRoot || url.path == "/" {
                    continue
                }

                let systemPaths = [
                    "/System", "/private", "/home", "/net", "/Network", "/dev", "/Volumes/Recovery",
                ]
                if systemPaths.contains(where: { url.path.hasPrefix($0) }) {
                    continue
                }

                if !isInternal || isRemovable || isEjectable {
                    if url.path.hasPrefix("/Volumes/") {
                        let volume = Volume(name: volumeName, path: url.path)
                        result.append(volume)
                    }
                }
            } catch {
                continue
            }
        }

        return result
    }

    func findProcessesUsingVolume(_ volume: Volume) -> [ProcessInfo] {
        var result: [ProcessInfo] = []
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = [volume.path]
        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                for index in 1..<lines.count {
                    let line = lines[index]
                    let components = line.components(separatedBy: " ").filter { !$0.isEmpty }
                    if components.count >= 2 {
                        let processName = components[0]
                        if let pid = Int(components[1]) {
                            let process = ProcessInfo(name: processName, pid: pid)
                            if !result.contains(where: { $0.pid == pid }) {
                                result.append(process)
                            }
                        }
                    }
                }
            }
        } catch {
            // Ignore errors from lsof failures
        }

        return result
    }

    func attemptEject(volumes: [Volume]) -> VolumeEjectResult {
        var successful: [Volume] = []
        var blocking: [Volume: [ProcessInfo]] = [:]
        var failedWithoutProcesses: [Volume] = []

        for volume in volumes {
            let processes = findProcessesUsingVolume(volume)
            if !processes.isEmpty {
                blocking[volume] = processes
                continue
            }

            if eject(volume) {
                successful.append(volume)
            } else {
                failedWithoutProcesses.append(volume)
            }
        }

        return VolumeEjectResult(
            successful: successful,
            blocking: blocking,
            failedWithoutProcesses: failedWithoutProcesses
        )
    }

    func eject(_ volume: Volume) -> Bool {
        let task = Process()
        task.launchPath = "/usr/sbin/diskutil"
        task.arguments = ["eject", volume.path]

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    func terminate(processes: [ProcessInfo]) {
        for process in processes {
            let task = Process()
            task.launchPath = "/bin/kill"
            task.arguments = ["-9", String(process.pid)]
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                continue
            }
        }
    }
}
