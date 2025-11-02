import Cocoa
import QuartzCore

private struct ProcessSafetyBadgeStyle {
    let textHex: String
    let backgroundHex: String
    let backgroundAlphaOverride: CGFloat?
    let fallbackText: NSColor
    let fallbackBackground: NSColor

    var textColor: NSColor {
        NSColor.fromHex(textHex) ?? fallbackText
    }

    var backgroundColor: NSColor {
        NSColor.fromHex(backgroundHex, alpha: backgroundAlphaOverride) ?? fallbackBackground
    }
}

private enum ProcessSafetyBadgePalette {
    /// Update the hex values here to tweak the SAFE/UNSAFE/UNKNOWN badge colours.
    static let safe = ProcessSafetyBadgeStyle(
        textHex: "#066D16",
        backgroundHex: "#BFF2C7",
        backgroundAlphaOverride: 1,
        fallbackText: NSColor.systemGreen,
        fallbackBackground: NSColor.systemGreen.withAlphaComponent(0.25)
    )

    static let unsafe = ProcessSafetyBadgeStyle(
        textHex: "#C50A00",
        backgroundHex: "#F9D7D6",
        backgroundAlphaOverride: 0.25,
        fallbackText: NSColor.systemRed,
        fallbackBackground: NSColor.systemRed.withAlphaComponent(0.25)
    )

    static let unknown = ProcessSafetyBadgeStyle(
        textHex: "#363636",
        backgroundHex: "#D5D5D5",
        backgroundAlphaOverride: 1,
        fallbackText: NSColor.labelColor,
        fallbackBackground: NSColor.systemGray.withAlphaComponent(0.25)
    )
}

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
            return ProcessSafetyBadgePalette.safe.backgroundColor
        case .unsafe:
            return ProcessSafetyBadgePalette.unsafe.backgroundColor
        case .unknown:
            return ProcessSafetyBadgePalette.unknown.backgroundColor
        }
    }

    var textColor: NSColor {
        switch self {
        case .safe:
            return ProcessSafetyBadgePalette.safe.textColor
        case .unsafe:
            return ProcessSafetyBadgePalette.unsafe.textColor
        case .unknown:
            return ProcessSafetyBadgePalette.unknown.textColor
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

    private let volumeManager = VolumeManager()
    private let ruleStore: ProcessRuleStore
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
    private var saveSelectionToggle: NSButton!
    private var shouldSaveSelectedProcessesAsRules = false
    private var skipRuleAutomationOnce = false

    private var ejectButton: NSButton!
    private var endProcessesButton: NSButton!
    private var closeButton: NSButton!

    init(ruleStore: ProcessRuleStore = ProcessRuleStore()) {
        self.ruleStore = ruleStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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

    private func ensureViewLoadedIfNeeded() {
        if !isViewLoaded {
            _ = view
        }
    }

    private func populateVolumeIcons(for volumes: [Volume]) {
        let iconSize = NSSize(width: 24, height: 24)
        volumeIcons = [:]
        for volume in volumes {
            let baseIcon = NSWorkspace.shared.icon(forFile: volume.path)
            if let copied = baseIcon.copy() as? NSImage {
                copied.size = iconSize
                volumeIcons[volume] = copied
            } else {
                baseIcon.size = iconSize
                volumeIcons[volume] = baseIcon
            }
        }
    }

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
        emptyStateEmoji.font = NSFont.systemFont(ofSize: 30)
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
        processTableView.intercellSpacing = NSSize(width: 2, height: 0)
        processTableView.columnAutoresizingStyle = .sequentialColumnAutoresizingStyle

        let processCheckColumn = NSTableColumn(
            identifier: NSUserInterfaceItemIdentifier("ProcessCheckColumn"))
        processCheckColumn.width = 26
        processCheckColumn.minWidth = 24
        processCheckColumn.maxWidth = 32
        processCheckColumn.resizingMask = []
        let processHeaderCell = NSTableHeaderCell()
        processHeaderCell.title = ""
        processCheckColumn.headerCell = processHeaderCell
        processTableView.addTableColumn(processCheckColumn)

        let processVolumeColumn = NSTableColumn(
            identifier: NSUserInterfaceItemIdentifier("ProcessVolumeColumn"))
        processVolumeColumn.title = "Volume"
        processVolumeColumn.width = 140
        processVolumeColumn.minWidth = 120
        processVolumeColumn.resizingMask = [.autoresizingMask]
        processTableView.addTableColumn(processVolumeColumn)

        let processNameColumn = NSTableColumn(
            identifier: NSUserInterfaceItemIdentifier("ProcessNameColumn"))
        processNameColumn.title = "Process Name"
        processNameColumn.width = 210
        processNameColumn.minWidth = 180
        processNameColumn.resizingMask = [.autoresizingMask]
        processTableView.addTableColumn(processNameColumn)

        let processSafetyColumn = NSTableColumn(
            identifier: NSUserInterfaceItemIdentifier("ProcessSafetyColumn"))
        processSafetyColumn.title = ""
        processSafetyColumn.width = 64
        processSafetyColumn.minWidth = 60
        processSafetyColumn.maxWidth = 80
        processSafetyColumn.resizingMask = []
        processTableView.addTableColumn(processSafetyColumn)

        processScrollView.documentView = processTableView

        processSelectAllCheckbox = NSButton(
            checkboxWithTitle: "", target: self, action: #selector(processSelectAllClicked))
        processSelectAllCheckbox.allowsMixedState = true

        saveSelectionToggle = NSButton(
            title: "Always end these immediately",
            target: self,
            action: #selector(saveSelectionToggleChanged)
        )
        saveSelectionToggle.setButtonType(.switch)
        saveSelectionToggle.translatesAutoresizingMaskIntoConstraints = false
        saveSelectionToggle.isHidden = true
        saveSelectionToggle.isEnabled = false
        view.addSubview(saveSelectionToggle)

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

            saveSelectionToggle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            saveSelectionToggle.centerYAnchor.constraint(equalTo: endProcessesButton.centerYAnchor),
            saveSelectionToggle.trailingAnchor.constraint(
                lessThanOrEqualTo: endProcessesButton.leadingAnchor, constant: -12),

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
            let volumes = self.volumeManager.enumerateExternalVolumes()
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

        populateVolumeIcons(for: sortedVolumes)

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
        saveSelectionToggle.isHidden = true
        saveSelectionToggle.state = .off
        shouldSaveSelectedProcessesAsRules = false
        updateEjectButtonState()
        assignDefaultButton(ejectButton)
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
        saveSelectionToggle.isHidden = false
        updateSaveRuleToggleState()
        updateProcessSelectAllState()
        assignDefaultButton(endProcessesButton)
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
        saveSelectionToggle.isHidden = true

        emptyStateEmoji.isHidden = false
        emptyStateText.isHidden = false
        closeButton.isHidden = false
        assignDefaultButton(closeButton)
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
        saveSelectionToggle.isHidden = true
        closeButton.isHidden = true
        emptyStateEmoji.isHidden = true
        emptyStateText.isHidden = true
        assignDefaultButton(nil)
    }

    private func focusCloseButton() {
        guard let window = view.window else {
            DispatchQueue.main.async { [weak self] in
                self?.focusCloseButton()
            }
            return
        }

        window.makeFirstResponder(closeButton)
    }

    private func assignDefaultButton(_ button: NSButton?) {
        guard let window = view.window else {
            DispatchQueue.main.async { [weak self] in
                self?.assignDefaultButton(button)
            }
            return
        }

        if let button = button {
            window.defaultButtonCell = button.cell as? NSButtonCell
            window.makeFirstResponder(button)
        } else {
            window.defaultButtonCell = nil
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

    @objc private func saveSelectionToggleChanged(_ sender: NSButton) {
        guard !aggregatedProcesses.isEmpty else {
            sender.state = .off
            shouldSaveSelectedProcessesAsRules = false
            return
        }
        if selectedProcessIndexes.isEmpty {
            sender.state = .off
            shouldSaveSelectedProcessesAsRules = false
            return
        }
        shouldSaveSelectedProcessesAsRules = sender.state == .on
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

        let uniqueProcessesMap = selectedInfos.reduce(into: [Int: ProcessInfo]()) { partialResult, info in
            partialResult[info.process.pid] = info.process
        }
        let uniqueProcesses = Array(uniqueProcessesMap.values)

        if shouldSaveSelectedProcessesAsRules {
            ruleStore.addRules(for: uniqueProcesses)
            shouldSaveSelectedProcessesAsRules = false
            saveSelectionToggle.state = .off
            updateSaveRuleToggleState()
        }

        showProgressState(message: "Ending selected processes...")

        DispatchQueue.global(qos: .userInitiated).async {
            self.volumeManager.terminate(processes: uniqueProcesses)
            let volumesToCheck = Array(self.volumesPendingEjection)
            var updatedBlocking: [Volume: [ProcessInfo]] = [:]
            for volume in volumesToCheck {
                let processes = self.volumeManager.findProcessesUsingVolume(volume)
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
            updateSaveRuleToggleState()
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
        updateSaveRuleToggleState()
    }

    private func updateSaveRuleToggleState() {
        guard saveSelectionToggle != nil else { return }
        let hasSelection = !selectedProcessIndexes.isEmpty
        saveSelectionToggle.isEnabled = hasSelection
        if !hasSelection {
            saveSelectionToggle.state = .off
            shouldSaveSelectedProcessesAsRules = false
        }
    }

    private func updateEjectButtonState() {
        ejectButton.isEnabled = !selectedVolumes.isEmpty
    }

    private func attemptEject(volumes: [Volume]) {
        volumesPendingEjection = Set(volumes)
        showProgressState(message: "Ejecting selected drives...")

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.volumeManager.attemptEject(volumes: volumes)
            DispatchQueue.main.async {
                self.handleEjectResult(
                    successful: result.successful,
                    blocking: result.blocking,
                    failedWithoutProcesses: result.failedWithoutProcesses
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

        if skipRuleAutomationOnce {
            skipRuleAutomationOnce = false
            refreshProcessList(with: blocking)
            return
        }

        if applySavedRulesIfNeeded(on: blocking) {
            return
        }

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

    private func applySavedRulesIfNeeded(on blocking: [Volume: [ProcessInfo]]) -> Bool {
        var processesByPid: [Int: ProcessInfo] = [:]

        for (_, processes) in blocking {
            for process in processes {
                if ruleStore.containsRule(for: process.name) {
                    processesByPid[process.pid] = process
                }
            }
        }

        guard !processesByPid.isEmpty else {
            return false
        }

        let processesToTerminate = Array(processesByPid.values)
        showProgressState(message: "Ending saved processes...")

        DispatchQueue.global(qos: .userInitiated).async {
            self.volumeManager.terminate(processes: processesToTerminate)
            let volumesToCheck = Array(self.volumesPendingEjection)
            DispatchQueue.main.async {
                self.skipRuleAutomationOnce = true
                guard !volumesToCheck.isEmpty else {
                    self.showCompletionState(message: "All selected drives were ejected.")
                    return
                }
                self.attemptEject(volumes: volumesToCheck)
            }
        }

        return true
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

    func presentEjectionOutcome(for attemptedVolumes: [Volume], result: VolumeEjectResult) {
        ensureViewLoadedIfNeeded()
        let sortedVolumes = attemptedVolumes.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        allVolumes = sortedVolumes
        selectedVolumes = Set(sortedVolumes)
        populateVolumeIcons(for: sortedVolumes)
        volumeCheckboxes.removeAll()
        processCheckboxes.removeAll()
        aggregatedProcesses.removeAll()
        selectedProcessIndexes.removeAll()
        handleEjectResult(
            successful: result.successful,
            blocking: result.blocking,
            failedWithoutProcesses: result.failedWithoutProcesses
        )
    }

    func presentCompletion(message: String, emoji: String = "✅") {
        ensureViewLoadedIfNeeded()
        allVolumes.removeAll()
        selectedVolumes.removeAll()
        volumesPendingEjection.removeAll()
        aggregatedProcesses.removeAll()
        selectedProcessIndexes.removeAll()
        volumeIcons.removeAll()
        volumeCheckboxes.removeAll()
        processCheckboxes.removeAll()
        shouldSaveSelectedProcessesAsRules = false
        saveSelectionToggle.state = .off
        volumeTableView.reloadData()
        processTableView.reloadData()
        skipRuleAutomationOnce = false
        showCompletionState(message: message, emoji: emoji)
    }

    func restartScan() {
        ensureViewLoadedIfNeeded()
        allVolumes.removeAll()
        selectedVolumes.removeAll()
        volumesPendingEjection.removeAll()
        aggregatedProcesses.removeAll()
        selectedProcessIndexes.removeAll()
        volumeCheckboxes.removeAll()
        processCheckboxes.removeAll()
        shouldSaveSelectedProcessesAsRules = false
        saveSelectionToggle.state = .off
        volumeTableView.reloadData()
        processTableView.reloadData()
        skipRuleAutomationOnce = false
        showScanningState()
        scanForVolumes()
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
