import Cocoa

struct VolumeProcessInfo {
    let volume: Volume
    let process: ProcessInfo
}

class MainViewController: NSViewController {
    private var allVolumes: [Volume] = []
    private var processesByVolume: [Volume: [ProcessInfo]] = [:]
    private var aggregatedProcesses: [VolumeProcessInfo] = []
    private var tableView: NSTableView!
    private var checkboxes: [NSButton] = []
    private var selectAllCheckbox: NSButton!
    private var infoLabel: NSTextField!
    // Empty state views
    private var emptyStateEmoji: NSTextField!
    private var emptyStateText: NSTextField!

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 500))
        setupUI()
        startVolumeScanAndEject()
    }

    private func setupUI() {
        // Info label
        infoLabel = NSTextField(labelWithString: "Scanning external volumes...")
        infoLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)

        // Empty state emoji
        emptyStateEmoji = NSTextField(labelWithString: "💽")
        emptyStateEmoji.font = NSFont.systemFont(ofSize: 80)
        emptyStateEmoji.alignment = .center
        emptyStateEmoji.isHidden = true
        emptyStateEmoji.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateEmoji)

        // Empty state text
        emptyStateText = NSTextField(labelWithString: "No external drives connected")
        emptyStateText.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        emptyStateText.alignment = .center
        emptyStateText.isHidden = true
        emptyStateText.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateText)

        // Table view (hidden until needed)
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        view.addSubview(scrollView)

        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self

        // Checkbox column
        selectAllCheckbox = NSButton(
            checkboxWithTitle: "", target: self, action: #selector(selectAllClicked))
        selectAllCheckbox.state = .on
        let checkColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CheckColumn"))
        checkColumn.headerCell = NSTableHeaderCell()
        checkColumn.headerCell.title = ""
        checkColumn.width = 30
        tableView.addTableColumn(checkColumn)

        // Volume column
        let volumeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("VolumeColumn"))
        volumeColumn.title = "Volume"
        volumeColumn.width = 180
        tableView.addTableColumn(volumeColumn)

        // Process name column
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NameColumn"))
        nameColumn.title = "Process Name"
        nameColumn.width = 200
        tableView.addTableColumn(nameColumn)

        // PID column
        let pidColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("PIDColumn"))
        pidColumn.title = "PID"
        pidColumn.width = 80
        tableView.addTableColumn(pidColumn)

        scrollView.documentView = tableView
        tableView.isHidden = true

        // End/Eject button
        let actionButton = NSButton(
            title: "End processes and eject", target: self, action: #selector(actionButtonClicked))
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.bezelStyle = .rounded
        actionButton.contentTintColor = NSColor.systemRed
        view.addSubview(actionButton)

        // Constraints
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -20),

            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            actionButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            // Empty state emoji centered
            emptyStateEmoji.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateEmoji.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            // Empty state text centered below emoji
            emptyStateText.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateText.topAnchor.constraint(equalTo: emptyStateEmoji.bottomAnchor, constant: 16)
        ])
    }

    private func startVolumeScanAndEject() {
        infoLabel.stringValue = "Scanning external volumes..."
        DispatchQueue.global(qos: .userInitiated).async {
            let volumes = self.enumerateExternalVolumes()
            print("DEBUG: Volumes detected: \(volumes.map { "\($0.name) (\($0.path))" })")
            var processesByVolume: [Volume: [ProcessInfo]] = [:]
            var volumesToEject: [Volume] = []

            for volume in volumes {
                let processes = self.findProcessesUsingVolume(volume)
                if processes.isEmpty {
                    volumesToEject.append(volume)
                } else {
                    processesByVolume[volume] = processes
                }
            }

            // Eject volumes with no processes
            for volume in volumesToEject {
                self.ejectVolume(volume)
            }

            // Aggregate processes for UI
            var aggregated: [VolumeProcessInfo] = []
            for (volume, processes) in processesByVolume {
                for process in processes {
                    aggregated.append(VolumeProcessInfo(volume: volume, process: process))
                }
            }

            DispatchQueue.main.async {
                self.allVolumes = volumes
                self.processesByVolume = processesByVolume
                self.aggregatedProcesses = aggregated

                print("DEBUG: aggregatedProcesses count: \(aggregated.count)")
                print("DEBUG: allVolumes count: \(volumes.count)")

                // Hide all UI by default
                self.infoLabel.isHidden = true
                self.tableView.isHidden = true
                if let actionButton = self.view.subviews.compactMap({ $0 as? NSButton }).last {
                    actionButton.isHidden = true
                }
                self.emptyStateEmoji.isHidden = true
                self.emptyStateText.isHidden = true

                if volumes.isEmpty {
                    // No external drives at all: show empty state
                    print("DEBUG: Showing empty state UI (no external drives detected)")
                    self.emptyStateEmoji.isHidden = false
                    self.emptyStateText.isHidden = false
                } else if aggregated.isEmpty {
                    // All external volumes ejected successfully
                    print("DEBUG: All external volumes ejected successfully UI")
                    self.infoLabel.stringValue = "All external volumes ejected successfully."
                    self.infoLabel.isHidden = false
                } else {
                    print("DEBUG: Showing table UI (processes preventing ejection)")
                    self.infoLabel.stringValue =
                        "Processes are preventing ejection. Select which to end:"
                    self.infoLabel.isHidden = false
                    self.tableView.isHidden = false
                    if let actionButton = self.view.subviews.compactMap({ $0 as? NSButton }).last {
                        actionButton.isHidden = false
                    }
                    self.tableView.reloadData()
                }
            }
        }
    }

    private func enumerateExternalVolumes() -> [Volume] {
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
        if let mountedVolumeURLs = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys), options: [.skipHiddenVolumes])
        {
            for url in mountedVolumeURLs {
                do {
                    let resourceValues = try url.resourceValues(forKeys: keys)
                    let isRemovable = resourceValues.volumeIsRemovable ?? false
                    let isEjectable = resourceValues.volumeIsEjectable ?? false
                    let isInternal = resourceValues.volumeIsInternal ?? true
                    let isRoot = resourceValues.volumeIsRootFileSystem ?? false
                    let volumeName = resourceValues.volumeLocalizedName ?? url.lastPathComponent

                    print("DEBUG: Checking volume: \(volumeName) (\(url.path)), removable: \(isRemovable), ejectable: \(isEjectable), internal: \(isInternal), root: \(isRoot)")

                    if isRoot || url.path == "/" {
                        continue
                    }
                    let systemPaths = [
                        "/System", "/private", "/home", "/net", "/Network", "/dev",
                        "/Volumes/Recovery",
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
        }
        print("DEBUG: enumerateExternalVolumes() returning \(result.count) volumes")
        return result
    }

    private func findProcessesUsingVolume(_ volume: Volume) -> [ProcessInfo] {
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
                for i in 1..<lines.count {
                    let line = lines[i]
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
            // Ignore errors
        }
        return result
    }

    private func ejectVolume(_ volume: Volume) {
        let task = Process()
        task.launchPath = "/usr/sbin/diskutil"
        task.arguments = ["eject", volume.path]
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            // Could log or show error
        }
    }

    @objc private func selectAllClicked() {
        let newState = selectAllCheckbox.state
        for checkbox in checkboxes {
            checkbox.state = newState
        }
        updateActionButtonTitle()
    }

    @objc private func updateActionButtonTitle() {
        let allChecked = checkboxes.allSatisfy { $0.state == .on }
        if let button = view.subviews.compactMap({ $0 as? NSButton }).last {
            button.title = allChecked ? "End processes and eject" : "End processes"
        }
    }

    @objc private func actionButtonClicked() {
        var selected: [VolumeProcessInfo] = []
        for (index, checkbox) in checkboxes.enumerated() {
            if checkbox.state == .on {
                selected.append(aggregatedProcesses[index])
            }
        }
        // End selected processes
        for info in selected {
            let task = Process()
            task.launchPath = "/bin/kill"
            task.arguments = ["-9", String(info.process.pid)]
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                // Could log or show error
            }
        }
        // If all are selected, eject all affected volumes
        if selected.count == aggregatedProcesses.count {
            let affectedVolumes = Set(selected.map { $0.volume })
            for volume in affectedVolumes {
                ejectVolume(volume)
            }
        }
        // Refresh
        startVolumeScanAndEject()
    }
}

extension MainViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return aggregatedProcesses.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        guard let columnIdentifier = tableColumn?.identifier else { return nil }
        let info = aggregatedProcesses[row]
        switch columnIdentifier.rawValue {
        case "CheckColumn":
            let checkbox = NSButton(
                checkboxWithTitle: "", target: self, action: #selector(updateActionButtonTitle))
            checkbox.state = .on
            if row >= checkboxes.count {
                checkboxes.append(checkbox)
            } else {
                checkboxes[row] = checkbox
            }
            return checkbox
        case "VolumeColumn":
            let cell = NSTextField(labelWithString: info.volume.name)
            cell.alignment = .left
            return cell
        case "NameColumn":
            let cell = NSTextField(labelWithString: info.process.name)
            cell.alignment = .left
            return cell
        case "PIDColumn":
            let cell = NSTextField(labelWithString: String(info.process.pid))
            cell.alignment = .left
            return cell
        default:
            return nil
        }
    }
}
