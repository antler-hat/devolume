import Cocoa
import DiskArbitration

class VolumesViewController: NSViewController {
    private var volumesTableView: NSTableView!
    private var volumes: [Volume] = []

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        setupUI()
        loadVolumes()
    }

    private func setupUI() {
        // Title label
        let titleLabel = NSTextField(labelWithString: "Select an External Volume")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Create scroll view and table view
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        view.addSubview(scrollView)

        volumesTableView = NSTableView()
        volumesTableView.delegate = self
        volumesTableView.dataSource = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("VolumeColumn"))
        column.title = "External Volumes"
        column.width = 350
        volumesTableView.addTableColumn(column)

        scrollView.documentView = volumesTableView

        // Set constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
        ])
    }

    private func loadVolumes() {
        volumes = []

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

                    // Skip the root volume and system paths
                    if isRoot || url.path == "/" {
                        continue
                    }

                    // Skip system volumes and special paths
                    let systemPaths = [
                        "/System", "/private", "/home", "/net", "/Network", "/dev",
                        "/Volumes/Recovery",
                    ]
                    if systemPaths.contains(where: { url.path.hasPrefix($0) }) {
                        continue
                    }

                    // Only include external drives
                    if !isInternal || isRemovable || isEjectable {
                        // Check if the path starts with /Volumes/ to ensure it's a proper external drive
                        if url.path.hasPrefix("/Volumes/") {
                            let volume = Volume(name: volumeName, path: url.path)
                            volumes.append(volume)
                            print("Added volume: \(volumeName) at \(url.path)")  // Debug logging
                        }
                    }
                } catch {
                    print("Error reading volume properties for \(url.path): \(error)")
                }
            }
        }

        // Sort volumes by name
        volumes.sort { $0.name < $1.name }

        // Debug logging
        if volumes.isEmpty {
            print("No external volumes found")
        }

        volumesTableView.reloadData()
    }
}

extension VolumesViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return volumes.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let volume = volumes[row]

        let cellIdentifier = NSUserInterfaceItemIdentifier("VolumeCell")
        var cellView =
            tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView

        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = cellIdentifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView?.addSubview(textField)
            cellView?.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 4),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
                textField.trailingAnchor.constraint(
                    equalTo: cellView!.trailingAnchor, constant: -4),
            ])
        }

        cellView?.textField?.stringValue = volume.name

        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = volumesTableView.selectedRow
        if selectedRow >= 0 {
            let selectedVolume = volumes[selectedRow]
            let processesVC = ProcessesViewController(volume: selectedVolume)
            self.presentAsSheet(processesVC)
        }
    }
}
