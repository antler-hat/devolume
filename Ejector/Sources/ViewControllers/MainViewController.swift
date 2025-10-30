import Cocoa
import QuartzCore

struct VolumeProcessInfo {
    let volume: Volume
    let process: ProcessInfo
    let safety: ProcessSafety
    let descriptor: ProcessDescriptor?
}

private extension ProcessSafety {
    var displayText: String {
        switch self {
        case .safe:
            return "SAFE"
        case .unsafe:
            return "UNSAFE"
        case .unknown:
            return "UNKNOWN"
        }
    }

    var backgroundColor: NSColor {
        switch self {
        case .safe:
            return NSColor.systemGreen.withAlphaComponent(0.25)
        case .unsafe:
            return NSColor.systemRed.withAlphaComponent(0.25)
        case .unknown:
            return NSColor.systemGray.withAlphaComponent(0.25)
        }
    }

    var textColor: NSColor {
        switch self {
        case .safe:
            return NSColor.systemGreen
        case .unsafe:
            return NSColor.systemRed
        case .unknown:
            return NSColor.labelColor
        }
    }
}

class MainViewController: NSViewController {
    private enum ContentState {
        case scanning
        case noVolumes
        case volumeSelection
        case processResolution
        case completion
    }

    private var contentState: ContentState = .scanning

    private var allVolumes: [Volume] = []
    private var selectedVolumes: Set<Volume> = []
    private var volumesPendingEjection: Set<Volume> = []
    private var volumeIcons: [Volume: NSImage] = [:]

    private let minimumPreferredHeight: CGFloat = 300
    private let expandedPreferredHeight: CGFloat = 600
    private var aggregatedProcesses: [VolumeProcessInfo] = []
    private var selectedProcessIndexes: Set<Int> = []

    private var volumeCheckboxes: [Int: NSButton] = [:]
    private var processCheckboxes: [Int: NSButton] = [:]

    private var infoLabel: NSTextField!
    private var spinner: NSProgressIndicator!
    private var emptyStateEmoji: NSTextField!
    private var emptyStateText: NSTextField!

    private var volumeScrollView: NSScrollView!
    private var volumeTableView: NSTableView!
    private var volumeSelectAllCheckbox: NSButton!

    private var processScrollView: NSScrollView!
    private var processTableView: NSTableView!
    private var processSelectAllCheckbox: NSButton!

    private var ejectButton: NSButton!
    private var endProcessesButton: NSButton!
    private var closeButton: NSButton!

    private let processDescriptorList: [ProcessDescriptor] = [
        ProcessDescriptor(
            names: ["photos", "photos.app"],
            category: "Apple Photos app",
            safety: .safe,
            notes: "Ends photo library access. No data loss."
        ),
        ProcessDescriptor(
            names: ["photoanalysisd", "photoanal", "photoanalysis"],
            category: "Photos analysis daemon",
            safety: .safe,
            notes: "Handles face/object analysis. Non-destructive to stop."
        ),
        ProcessDescriptor(
            names: ["mediaanalysisd", "mediaanal"],
            category: "Media analysis daemon",
            safety: .safe,
            notes: "Indexes media metadata. Safe to stop; work will resume later."
        ),
        ProcessDescriptor(
            names: ["photolibr", "photolibraryd"],
            category: "Photo library service",
            safety: .safe,
            notes: "Manages local library sync. Safe to quit."
        ),
        ProcessDescriptor(
            names: ["cloudphotosd", "cloudphot"],
            category: "iCloud Photos sync",
            safety: .safe,
            notes: "Stops iCloud Photos syncing until it restarts."
        ),
        ProcessDescriptor(
            names: ["cleanmymac", "cleanmymacx", "cleanmymac x", "cleanmyma"],
            category: "CleanMyMac helper",
            safety: .safe,
            notes: "Cancels the current cleanup task without lasting effects."
        ),
        ProcessDescriptor(
            names: ["spotlight", "mds", "mds_stores", "mdworker", "mdworker_shared"],
            category: "Spotlight indexing",
            safety: .safe,
            notes: "Pauses indexing temporarily; macOS will restart it automatically."
        ),
        ProcessDescriptor(
            names: ["preview"],
            category: "Preview",
            safety: .safe,
            notes: "Closes open documents. No data loss beyond unsaved changes."
        ),
        ProcessDescriptor(
            names: ["quicklookuiservice", "quicklookui"],
            category: "Quick Look service",
            safety: .safe,
            notes: "Stops thumbnail generation. macOS will relaunch it if needed."
        ),
        ProcessDescriptor(
            names: ["dropbox"],
            category: "Cloud sync client",
            safety: .safe,
            notes: "Pauses Dropbox syncing until relaunched."
        ),
        ProcessDescriptor(
            names: ["googledrive", "google drive"],
            category: "Cloud sync client",
            safety: .safe,
            notes: "Pauses Google Drive syncing until relaunched."
        ),
        ProcessDescriptor(
            names: ["onedrive"],
            category: "Cloud sync client",
            safety: .safe,
            notes: "Pauses OneDrive syncing until relaunched."
        ),
        ProcessDescriptor(
            names: ["bird"],
            category: "iCloud Drive daemon",
            safety: .safe,
            notes: "Stops iCloud Drive syncing temporarily."
        ),
        ProcessDescriptor(
            names: ["soagent"],
            category: "CloudKit service",
            safety: .safe,
            notes: "Pauses CloudKit sync until the agent restarts."
        ),
        ProcessDescriptor(
            names: ["messages", "imagent"],
            category: "Messages",
            safety: .safe,
            notes: "Closes the Messages app or helper. Safe to reopen later."
        ),
        ProcessDescriptor(
            names: ["finder"],
            category: "Finder",
            safety: .unsafe,
            notes: "macOS restarts Finder automatically, but quitting may disrupt user workflow."
        ),
        ProcessDescriptor(
            names: ["backupd", "com.apple.timemachine"],
            category: "Time Machine backup",
            safety: .unsafe,
            notes: "Interrupts Time Machine backups; risk of incomplete backup."
        ),
        ProcessDescriptor(
            names: ["fsck"],
            category: "Filesystem check",
            safety: .unsafe,
            notes: "May interrupt disk repairs and risk corruption."
        ),
        ProcessDescriptor(
            names: ["diskutil"],
            category: "Disk utility task",
            safety: .unsafe,
            notes: "Stopping may leave disk operations incomplete."
        ),
        ProcessDescriptor(
            names: ["cp", "mv", "rsync"],
            category: "File transfer",
            safety: .unsafe,
            notes: "Stopping may interrupt file copy or sync operations."
        ),
        ProcessDescriptor(
            names: ["finalcutpro"],
            category: "Final Cut Pro",
            safety: .unsafe,
            notes: "Avoid quitting during editing or exports to prevent data loss."
        ),
        ProcessDescriptor(
            names: ["logicpro"],
            category: "Logic Pro",
            safety: .unsafe,
            notes: "Avoid quitting during editing or renders to prevent data loss."
        ),
        ProcessDescriptor(
            names: ["premiere", "adobepremierepro"],
            category: "Premiere Pro",
            safety: .unsafe,
            notes: "Avoid quitting during exports to prevent corruption."
        ),
        ProcessDescriptor(
            names: ["kernel_task"],
            category: "Core system process",
            safety: .unsafe,
            notes: "Critical system process. Never terminate."
        ),
        ProcessDescriptor(
            names: ["windowserver"],
            category: "macOS window manager",
            safety: .unsafe,
            notes: "Quitting will log you out immediately."
        )
    ]

    private lazy var processDescriptorLookup: [String: ProcessDescriptor] = {
        var lookup: [String: ProcessDescriptor] = [:]
        for descriptor in processDescriptorList {
            for name in descriptor.names {
                lookup[name.lowercased()] = descriptor
            }
        }
        return lookup
    }()

    override func loadView() {
        self.view = NSView()
        setupUI()
        showScanningState()
        scanForVolumes()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        positionHeaderCheckboxes()
    }

    private func setupUI() {
        infoLabel = NSTextField(labelWithString: "Scanning external volumes...")
        infoLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)

        emptyStateEmoji = NSTextField(labelWithString: "✅")
        emptyStateEmoji.font = NSFont.systemFont(ofSize: 60)
        emptyStateEmoji.alignment = .center
        emptyStateEmoji.translatesAutoresizingMaskIntoConstraints = false
        emptyStateEmoji.isHidden = true
        view.addSubview(emptyStateEmoji)

        emptyStateText = NSTextField(labelWithString: "")
        emptyStateText.font = NSFont.systemFont(ofSize: 18)
        emptyStateText.alignment = .center
        emptyStateText.translatesAutoresizingMaskIntoConstraints = false
        emptyStateText.isHidden = true
        view.addSubview(emptyStateText)

        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isDisplayedWhenStopped = false
        view.addSubview(spinner)

        volumeScrollView = NSScrollView()
        volumeScrollView.translatesAutoresizingMaskIntoConstraints = false
        volumeScrollView.hasVerticalScroller = true
        volumeScrollView.borderType = .bezelBorder
        volumeScrollView.isHidden = true
        view.addSubview(volumeScrollView)

        volumeTableView = NSTableView()
        volumeTableView.delegate = self
        volumeTableView.dataSource = self
        volumeTableView.usesAlternatingRowBackgroundColors = true

        let volumeCheckColumn = NSTableColumn(
            identifier: NSUserInterfaceItemIdentifier("VolumeCheckColumn"))
        volumeCheckColumn.width = 30
        let volumeHeaderCell = NSTableHeaderCell()
        volumeHeaderCell.title = ""
        volumeCheckColumn.headerCell = volumeHeaderCell
        volumeTableView.addTableColumn(volumeCheckColumn)

        let volumeNameColumn = NSTableColumn(
            identifier: NSUserInterfaceItemIdentifier("VolumeNameColumn"))
        volumeNameColumn.title = "Drive"
        volumeNameColumn.width = 450
        volumeTableView.addTableColumn(volumeNameColumn)

        volumeScrollView.documentView = volumeTableView

        volumeSelectAllCheckbox = NSButton(
            checkboxWithTitle: "", target: self, action: #selector(volumeSelectAllClicked))
        volumeSelectAllCheckbox.allowsMixedState = true

        processScrollView = NSScrollView()
        processScrollView.translatesAutoresizingMaskIntoConstraints = false
        processScrollView.hasVerticalScroller = true
        processScrollView.hasHorizontalScroller = false
        processScrollView.borderType = .bezelBorder
        processScrollView.isHidden = true
        view.addSubview(processScrollView)

        processTableView = NSTableView()
        processTableView.delegate = self
        processTableView.dataSource = self

        let processCheckColumn = NSTableColumn(
            identifier: NSUserInterfaceItemIdentifier("ProcessCheckColumn"))
        processCheckColumn.width = 30
        let processHeaderCell = NSTableHeaderCell()
        processHeaderCell.title = ""
        processCheckColumn.headerCell = processHeaderCell
        processTableView.addTableColumn(processCheckColumn)

        let processNameColumn = NSTableColumn(
            identifier: NSUserInterfaceItemIdentifier("ProcessNameColumn"))
        processNameColumn.title = "Process Name"
        processNameColumn.width = 220
        processTableView.addTableColumn(processNameColumn)

        let processSafetyColumn = NSTableColumn(
            identifier: NSUserInterfaceItemIdentifier("ProcessSafetyColumn"))
        processSafetyColumn.title = ""
        processSafetyColumn.width = 70
        processSafetyColumn.minWidth = 60
        processSafetyColumn.maxWidth = 90
        processTableView.addTableColumn(processSafetyColumn)

        processScrollView.documentView = processTableView

        processSelectAllCheckbox = NSButton(
            checkboxWithTitle: "", target: self, action: #selector(processSelectAllClicked))
        processSelectAllCheckbox.allowsMixedState = true

        ejectButton = NSButton(
            title: "Eject Drives", target: self, action: #selector(ejectButtonClicked))
        ejectButton.translatesAutoresizingMaskIntoConstraints = false
        ejectButton.bezelStyle = .rounded
        ejectButton.contentTintColor = NSColor.systemRed
        ejectButton.isHidden = true
        view.addSubview(ejectButton)

        endProcessesButton = NSButton(
            title: "End processes", target: self, action: #selector(endProcessesButtonClicked))
        endProcessesButton.translatesAutoresizingMaskIntoConstraints = false
        endProcessesButton.bezelStyle = .rounded
        endProcessesButton.contentTintColor = NSColor.systemRed
        endProcessesButton.isHidden = true
        view.addSubview(endProcessesButton)

        closeButton = NSButton(title: "Close", target: self, action: #selector(closeButtonClicked))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        closeButton.isHidden = true
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            volumeScrollView.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 20),
            volumeScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            volumeScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            volumeScrollView.bottomAnchor.constraint(equalTo: ejectButton.topAnchor, constant: -20),

            processScrollView.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 20),
            processScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            processScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            processScrollView.bottomAnchor.constraint(
                equalTo: endProcessesButton.topAnchor, constant: -20),

            ejectButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            ejectButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            endProcessesButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            endProcessesButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            closeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            emptyStateEmoji.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateEmoji.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),

            emptyStateText.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateText.topAnchor.constraint(equalTo: emptyStateEmoji.bottomAnchor, constant: 16),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func showScanningState() {
        contentState = .scanning
        infoLabel.stringValue = "Scanning external volumes..."
        infoLabel.isHidden = false
        spinner.isHidden = false
        spinner.startAnimation(nil)

        volumeScrollView.isHidden = true
        processScrollView.isHidden = true
        ejectButton.isHidden = true
        endProcessesButton.isHidden = true
        closeButton.isHidden = true
        emptyStateEmoji.isHidden = true
        emptyStateText.isHidden = true
    }

    private func scanForVolumes() {
        DispatchQueue.global(qos: .userInitiated).async {
            let volumes = self.enumerateExternalVolumes()
            DispatchQueue.main.async {
                self.handleVolumeScanResult(volumes)
            }
        }
    }

    private func handleVolumeScanResult(_ volumes: [Volume]) {
        spinner.stopAnimation(nil)
        spinner.isHidden = true

        let sortedVolumes = volumes.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        allVolumes = sortedVolumes

        let iconSize = NSSize(width: 24, height: 24)
        volumeIcons = [:]
        for volume in sortedVolumes {
            let baseIcon = NSWorkspace.shared.icon(forFile: volume.path)
            if let copied = baseIcon.copy() as? NSImage {
                copied.size = iconSize
                volumeIcons[volume] = copied
            } else {
                baseIcon.size = iconSize
                volumeIcons[volume] = baseIcon
            }
        }

        guard !sortedVolumes.isEmpty else {
            showNoVolumesState()
            return
        }

        selectedVolumes = Set(sortedVolumes)
        volumeCheckboxes.removeAll()
        volumeTableView.reloadData()

        updateVolumeSelectAllState()
        updateEjectButtonState()
        showVolumeSelectionState()
        adjustWindowSizeIfNeeded()
    }

    private func showNoVolumesState() {
        showCompletionState(message: "No external drives are mounted. Nothing to eject")
        contentState = .noVolumes
    }

    private func showVolumeSelectionState() {
        contentState = .volumeSelection
        infoLabel.stringValue = "Select the drives to eject:"

        spinner.stopAnimation(nil)
        spinner.isHidden = true
        emptyStateEmoji.isHidden = true
        emptyStateText.isHidden = true
        processScrollView.isHidden = true
        endProcessesButton.isHidden = true
        closeButton.isHidden = true

        volumeScrollView.isHidden = false
        ejectButton.isHidden = false
        updateEjectButtonState()
    }

    private func showProcessResolutionState() {
        contentState = .processResolution
        infoLabel.stringValue =
            "Processes are preventing ejection"

        spinner.stopAnimation(nil)
        spinner.isHidden = true
        volumeScrollView.isHidden = true
        ejectButton.isHidden = true
        emptyStateEmoji.isHidden = true
        emptyStateText.isHidden = true
        closeButton.isHidden = true

        processScrollView.isHidden = false
        endProcessesButton.isHidden = false
        updateProcessSelectAllState()
    }

    private func showCompletionState(message: String, emoji: String = "✅") {
        contentState = .completion
        emptyStateEmoji.stringValue = emoji
        emptyStateText.stringValue = message

        infoLabel.isHidden = true
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        volumeScrollView.isHidden = true
        processScrollView.isHidden = true
        ejectButton.isHidden = true
        endProcessesButton.isHidden = true

        emptyStateEmoji.isHidden = false
        emptyStateText.isHidden = false
        closeButton.isHidden = false
        focusCloseButton()
    }

    private func showProgressState(message: String) {
        infoLabel.stringValue = message
        infoLabel.isHidden = false
        spinner.isHidden = false
        spinner.startAnimation(nil)

        volumeScrollView.isHidden = true
        processScrollView.isHidden = true
        ejectButton.isHidden = true
        endProcessesButton.isHidden = true
        closeButton.isHidden = true
        emptyStateEmoji.isHidden = true
        emptyStateText.isHidden = true
    }

    private func focusCloseButton() {
        guard let window = view.window else {
            DispatchQueue.main.async { [weak self] in
                self?.focusCloseButton()
            }
            return
        }

        window.makeFirstResponder(closeButton)
        if let cell = closeButton.cell as? NSButtonCell {
            window.defaultButtonCell = cell
        }
    }

    private func positionHeaderCheckboxes() {
        if let headerView = volumeTableView.headerView {
            let height = headerView.frame.height
            let size: CGFloat = 18
            let y = (height - size) / 2.0
            volumeSelectAllCheckbox.frame = NSRect(x: 6, y: y, width: size, height: size)
            if volumeSelectAllCheckbox.superview !== headerView {
                headerView.addSubview(volumeSelectAllCheckbox)
            }
        }

        if let headerView = processTableView.headerView {
            let height = headerView.frame.height
            let size: CGFloat = 18
            let y = (height - size) / 2.0
            processSelectAllCheckbox.frame = NSRect(x: 6, y: y, width: size, height: size)
            if processSelectAllCheckbox.superview !== headerView {
                headerView.addSubview(processSelectAllCheckbox)
            }
        }
        processTableView.usesAlternatingRowBackgroundColors = true
    }

    @objc private func volumeSelectAllClicked() {
        var newState = volumeSelectAllCheckbox.state
        if newState == .mixed {
            newState = .on
            volumeSelectAllCheckbox.state = newState
        }
        if newState == .on {
            selectedVolumes = Set(allVolumes)
        } else {
            selectedVolumes.removeAll()
        }
        for checkbox in volumeCheckboxes.values {
            checkbox.state = newState
        }
        updateVolumeSelectAllState()
        updateEjectButtonState()
    }

    @objc private func processSelectAllClicked() {
        var newState = processSelectAllCheckbox.state
        if newState == .mixed {
            newState = .on
            processSelectAllCheckbox.state = newState
        }
        if newState == .on {
            selectedProcessIndexes = Set(0..<aggregatedProcesses.count)
        } else {
            selectedProcessIndexes.removeAll()
        }
        for checkbox in processCheckboxes.values {
            checkbox.state = newState
        }
        updateProcessSelectAllState()
    }

    @objc private func volumeCheckboxToggled(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < allVolumes.count else { return }
        let volume = allVolumes[row]
        if sender.state == .on {
            selectedVolumes.insert(volume)
        } else {
            selectedVolumes.remove(volume)
        }
        volumeCheckboxes[row] = sender
        updateVolumeSelectAllState()
        updateEjectButtonState()
    }

    @objc private func processCheckboxToggled(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < aggregatedProcesses.count else { return }
        if sender.state == .on {
            selectedProcessIndexes.insert(row)
        } else {
            selectedProcessIndexes.remove(row)
        }
        processCheckboxes[row] = sender
        updateProcessSelectAllState()
    }

    @objc private func ejectButtonClicked() {
        let volumesToEject = allVolumes.filter { selectedVolumes.contains($0) }
        guard !volumesToEject.isEmpty else { return }
        attemptEject(volumes: volumesToEject)
    }

    @objc private func endProcessesButtonClicked() {
        guard !selectedProcessIndexes.isEmpty else { return }
        let selectedInfos = selectedProcessIndexes
            .compactMap { index -> VolumeProcessInfo? in
                guard index >= 0 && index < aggregatedProcesses.count else { return nil }
                return aggregatedProcesses[index]
            }

        guard !selectedInfos.isEmpty else { return }

        let uniqueProcesses = selectedInfos.reduce(into: [Int: ProcessInfo]()) { partialResult, info in
            partialResult[info.process.pid] = info.process
        }.map { $0.value }

        showProgressState(message: "Ending selected processes...")

        DispatchQueue.global(qos: .userInitiated).async {
            self.terminate(processes: uniqueProcesses)
            let volumesToCheck = Array(self.volumesPendingEjection)
            var updatedBlocking: [Volume: [ProcessInfo]] = [:]
            for volume in volumesToCheck {
                let processes = self.findProcessesUsingVolume(volume)
                if !processes.isEmpty {
                    updatedBlocking[volume] = processes
                }
            }
            DispatchQueue.main.async {
                if updatedBlocking.isEmpty {
                    guard !volumesToCheck.isEmpty else {
                        self.showCompletionState(message: "All selected drives were ejected.")
                        return
                    }
                    self.attemptEject(volumes: volumesToCheck)
                } else {
                    self.refreshProcessList(with: updatedBlocking)
                }
            }
        }
    }

    private func updateVolumeSelectAllState() {
        guard !allVolumes.isEmpty else {
            volumeSelectAllCheckbox.state = .off
            volumeSelectAllCheckbox.isEnabled = false
            return
        }
        volumeSelectAllCheckbox.isEnabled = true

        if selectedVolumes.count == allVolumes.count {
            volumeSelectAllCheckbox.state = .on
        } else if selectedVolumes.isEmpty {
            volumeSelectAllCheckbox.state = .off
        } else {
            volumeSelectAllCheckbox.state = .mixed
        }
    }

    private func updateProcessSelectAllState() {
        let total = aggregatedProcesses.count
        guard total > 0 else {
            processSelectAllCheckbox.state = .off
            processSelectAllCheckbox.isEnabled = false
            return
        }
        processSelectAllCheckbox.isEnabled = true
        if selectedProcessIndexes.count == total {
            processSelectAllCheckbox.state = .on
        } else if selectedProcessIndexes.isEmpty {
            processSelectAllCheckbox.state = .off
        } else {
            processSelectAllCheckbox.state = .mixed
        }
    }

    private func updateEjectButtonState() {
        ejectButton.isEnabled = !selectedVolumes.isEmpty
    }

    private func attemptEject(volumes: [Volume]) {
        volumesPendingEjection = Set(volumes)
        showProgressState(message: "Ejecting selected drives...")

        DispatchQueue.global(qos: .userInitiated).async {
            var successful: [Volume] = []
            var blocking: [Volume: [ProcessInfo]] = [:]
            var failedWithoutProcesses: [Volume] = []

            for volume in volumes {
                let processes = self.findProcessesUsingVolume(volume)
                if !processes.isEmpty {
                    blocking[volume] = processes
                    continue
                }

                if self.ejectVolume(volume) {
                    successful.append(volume)
                } else {
                    failedWithoutProcesses.append(volume)
                }
            }

            DispatchQueue.main.async {
                self.handleEjectResult(
                    successful: successful,
                    blocking: blocking,
                    failedWithoutProcesses: failedWithoutProcesses
                )
            }
        }
    }

    private func handleEjectResult(
        successful: [Volume], blocking: [Volume: [ProcessInfo]], failedWithoutProcesses: [Volume]
    ) {
        let successfulSet = Set(successful)
        if !successfulSet.isEmpty {
            allVolumes.removeAll { successfulSet.contains($0) }
            selectedVolumes.subtract(successfulSet)
            for volume in successfulSet {
                volumeIcons.removeValue(forKey: volume)
            }
        }

        if blocking.isEmpty {
            volumesPendingEjection.removeAll()
            if failedWithoutProcesses.isEmpty {
                showCompletionState(message: "All selected drives were ejected.")
            } else {
                let names = failedWithoutProcesses.map { $0.name }.sorted()
                let joined = names.joined(separator: ", ")
                let message: String
                if names.count == 1 {
                    message =
                        "Unable to eject \(joined). Close any apps using it and try again."
                } else {
                    message =
                        "Unable to eject: \(joined). Close any apps using them and try again."
                }
                showCompletionState(message: message, emoji: "⚠️")
            }
            return
        }

        volumesPendingEjection = Set(blocking.keys)
        refreshProcessList(with: blocking)
    }

    private func refreshProcessList(with blocking: [Volume: [ProcessInfo]]) {
        aggregatedProcesses = aggregateProcesses(from: blocking)
        selectedProcessIndexes = Set(0..<aggregatedProcesses.count)

        processCheckboxes.removeAll()
        processTableView.reloadData()
        processSelectAllCheckbox.state = aggregatedProcesses.isEmpty ? .off : .on
        updateProcessSelectAllState()
        showProcessResolutionState()
        adjustWindowSizeIfNeeded()
    }

    private func aggregateProcesses(from map: [Volume: [ProcessInfo]]) -> [VolumeProcessInfo] {
        let sortedVolumes = map.keys.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        var aggregated: [VolumeProcessInfo] = []
        for volume in sortedVolumes {
            let processes = map[volume] ?? []
            let sortedProcesses = processes.sorted { lhs, rhs in
                let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if nameComparison == .orderedSame {
                    return lhs.pid < rhs.pid
                }
                return nameComparison == .orderedAscending
            }
            for process in sortedProcesses {
                let classification = classifyProcess(process)
                aggregated.append(
                    VolumeProcessInfo(
                        volume: volume,
                        process: process,
                        safety: classification.safety,
                        descriptor: classification.descriptor
                    )
                )
            }
        }
        return aggregated
    }

    private func classifyProcess(_ process: ProcessInfo) -> (safety: ProcessSafety, descriptor: ProcessDescriptor?) {
        let lowercased = process.name.lowercased()
        if let descriptor = processDescriptorLookup[lowercased] {
            return (descriptor.safety, descriptor)
        }

        // Handle truncated or suffixed process names by checking for prefix matches
        for descriptor in processDescriptorList {
            if descriptor.names.contains(where: { name in
                let lowerName = name.lowercased()
                return lowercased.hasPrefix(lowerName) || lowerName.hasPrefix(lowercased)
            }) {
                return (descriptor.safety, descriptor)
            }
        }

        return (.unknown, nil)
    }

    private func configureSafetyLabel(_ label: NSTextField, safety: ProcessSafety, descriptor: ProcessDescriptor? = nil) {
        label.stringValue = safety.displayText
        label.textColor = safety.textColor
        if label.layer == nil {
            label.wantsLayer = true
        }
        label.layer?.backgroundColor = safety.backgroundColor.cgColor
        label.layer?.cornerRadius = 4
        label.layer?.masksToBounds = true
        label.layer?.borderWidth = 0
        label.layer?.contentsGravity = .center
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        if let descriptor = descriptor {
            label.toolTip = "\(descriptor.category): \(descriptor.notes)"
        } else {
            label.toolTip = nil
        }
    }

    private func adjustWindowSizeIfNeeded() {
        guard let window = view.window else { return }

        let visibleRowCount: Int
        if contentState == .volumeSelection {
            visibleRowCount = allVolumes.count
        } else if contentState == .processResolution {
            visibleRowCount = aggregatedProcesses.count
        } else {
            visibleRowCount = 0
        }

        let targetHeight: CGFloat
        if visibleRowCount > 4 {
            targetHeight = expandedPreferredHeight
        } else {
            targetHeight = minimumPreferredHeight
        }

        let currentSize = window.contentView?.frame.size ?? window.frame.size
        if abs(currentSize.height - targetHeight) < 1 {
            return
        }

        var frame = window.frameRect(
            forContentRect: NSRect(
                origin: .zero,
                size: NSSize(width: currentSize.width, height: targetHeight)))
        frame.origin.x = window.frame.origin.x
        frame.origin.y = window.frame.maxY - frame.height

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(frame, display: true, animate: true)
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

    private func ejectVolume(_ volume: Volume) -> Bool {
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

    private func terminate(processes: [ProcessInfo]) {
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

    @objc private func closeButtonClicked() {
        view.window?.close()
    }
}

extension MainViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === volumeTableView {
            return allVolumes.count
        } else if tableView === processTableView {
            return aggregatedProcesses.count
        }
        return 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        guard let columnIdentifier = tableColumn?.identifier else { return nil }

        if tableView === volumeTableView {
            let volume = allVolumes[row]
            switch columnIdentifier.rawValue {
            case "VolumeCheckColumn":
                let identifier = NSUserInterfaceItemIdentifier("VolumeCheckCell")
                let checkbox: NSButton
                if let existing = tableView.makeView(withIdentifier: identifier, owner: self)
                    as? NSButton
                {
                    checkbox = existing
                } else {
                    checkbox = NSButton(
                        checkboxWithTitle: "", target: self, action: #selector(volumeCheckboxToggled))
                    checkbox.identifier = identifier
                }
                checkbox.target = self
                checkbox.action = #selector(volumeCheckboxToggled)
                checkbox.tag = row
                checkbox.state = selectedVolumes.contains(volume) ? .on : .off
                volumeCheckboxes[row] = checkbox
                return checkbox
            case "VolumeNameColumn":
                let identifier = NSUserInterfaceItemIdentifier("VolumeNameCell")
                var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
                if cell == nil {
                    cell = NSTableCellView()
                    cell?.identifier = identifier
                    let imageView = NSImageView()
                    imageView.translatesAutoresizingMaskIntoConstraints = false
                    imageView.imageScaling = .scaleProportionallyDown
                    cell?.addSubview(imageView)
                    cell?.imageView = imageView
                    let textField = NSTextField(labelWithString: "")
                    textField.translatesAutoresizingMaskIntoConstraints = false
                    cell?.addSubview(textField)
                    cell?.textField = textField
                    NSLayoutConstraint.activate([
                        imageView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                        imageView.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                        imageView.widthAnchor.constraint(equalToConstant: 24),
                        imageView.heightAnchor.constraint(equalToConstant: 24),
                        textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                        textField.trailingAnchor.constraint(
                            equalTo: cell!.trailingAnchor, constant: -4),
                        textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                    ])
                }
                if let icon = volumeIcons[volume] {
                    cell?.imageView?.image = icon
                } else {
                    let fallback = NSWorkspace.shared.icon(forFile: volume.path)
                    fallback.size = NSSize(width: 24, height: 24)
                    cell?.imageView?.image = fallback
                }
                cell?.textField?.stringValue = volume.name
                return cell
            default:
                return nil
            }
        } else if tableView === processTableView {
            let info = aggregatedProcesses[row]
            switch columnIdentifier.rawValue {
            case "ProcessCheckColumn":
                let identifier = NSUserInterfaceItemIdentifier("ProcessCheckCell")
                let checkbox: NSButton
                if let existing = tableView.makeView(withIdentifier: identifier, owner: self)
                    as? NSButton
                {
                    checkbox = existing
                } else {
                    checkbox = NSButton(
                        checkboxWithTitle: "", target: self, action: #selector(processCheckboxToggled))
                    checkbox.identifier = identifier
                }
                checkbox.target = self
                checkbox.action = #selector(processCheckboxToggled)
                checkbox.tag = row
                checkbox.state = selectedProcessIndexes.contains(row) ? .on : .off
                processCheckboxes[row] = checkbox
                return checkbox
            case "ProcessVolumeColumn":
                let identifier = NSUserInterfaceItemIdentifier("ProcessVolumeCell")
                var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
                if cell == nil {
                    cell = NSTableCellView()
                    cell?.identifier = identifier
                    let textField = NSTextField(labelWithString: "")
                    textField.translatesAutoresizingMaskIntoConstraints = false
                    cell?.addSubview(textField)
                    cell?.textField = textField
                    NSLayoutConstraint.activate([
                        textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                        textField.trailingAnchor.constraint(
                            equalTo: cell!.trailingAnchor, constant: -4),
                        textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                    ])
                }
                cell?.textField?.stringValue = info.volume.name
                return cell
            case "ProcessNameColumn":
                let identifier = NSUserInterfaceItemIdentifier("ProcessNameCell")
                var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
                if cell == nil {
                    cell = NSTableCellView()
                    cell?.identifier = identifier
                    let textField = NSTextField(labelWithString: "")
                    textField.translatesAutoresizingMaskIntoConstraints = false
                    cell?.addSubview(textField)
                    cell?.textField = textField
                    NSLayoutConstraint.activate([
                        textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                        textField.trailingAnchor.constraint(
                            equalTo: cell!.trailingAnchor, constant: -4),
                        textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                    ])
                }
                cell?.textField?.stringValue = info.process.name
                return cell
            case "ProcessPIDColumn":
                let identifier = NSUserInterfaceItemIdentifier("ProcessPIDCell")
                var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
                if cell == nil {
                    cell = NSTableCellView()
                    cell?.identifier = identifier
                    let textField = NSTextField(labelWithString: "")
                    textField.translatesAutoresizingMaskIntoConstraints = false
                    cell?.addSubview(textField)
                    cell?.textField = textField
                    NSLayoutConstraint.activate([
                        textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                        textField.trailingAnchor.constraint(
                            equalTo: cell!.trailingAnchor, constant: -4),
                        textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                    ])
                }
                cell?.textField?.stringValue = String(info.process.pid)
                return cell
            case "ProcessSafetyColumn":
                let identifier = NSUserInterfaceItemIdentifier("ProcessSafetyCell")
                var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
                if cell == nil {
                    cell = NSTableCellView()
                    cell?.identifier = identifier
                    let textField = NSTextField(labelWithString: "")
                    textField.translatesAutoresizingMaskIntoConstraints = false
                    textField.alignment = .center
                    textField.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
                    textField.lineBreakMode = .byClipping
                    textField.wantsLayer = true
                    textField.isBezeled = false
                    textField.drawsBackground = false
                    cell?.addSubview(textField)
                    cell?.textField = textField
                    NSLayoutConstraint.activate([
                        textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 8),
                        textField.trailingAnchor.constraint(lessThanOrEqualTo: cell!.trailingAnchor, constant: -8),
                        textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
                    ])
                }
                if let label = cell?.textField {
                    configureSafetyLabel(label, safety: info.safety, descriptor: info.descriptor)
                }
                return cell
            default:
                return nil
            }
        }

        return nil
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if tableView === volumeTableView {
            return 48
        } else if tableView === processTableView {
            return 32
        }
        return tableView.rowHeight
    }
}
