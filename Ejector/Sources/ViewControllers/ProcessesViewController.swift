import Cocoa

class ProcessesViewController: NSViewController {
    private var volume: Volume
    private var processes: [ProcessInfo] = []
    private var tableView: NSTableView!
    private var checkboxes: [NSButton] = []
    private var selectAllCheckbox: NSButton!
    
    init(volume: Volume) {
        self.volume = volume
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        setupUI()
        loadProcesses()
    }
    
    private func setupUI() {
        // Title label
        let titleLabel = NSTextField(labelWithString: "Processes using \(volume.name)")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Create scroll view and table view
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        view.addSubview(scrollView)
        
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        
        // Create select all checkbox in a header cell
        selectAllCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(selectAllClicked))
        selectAllCheckbox.state = .on  // Default to checked
        let headerCell = NSTableHeaderCell()
        headerCell.title = ""
        
        let checkColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CheckColumn"))
        checkColumn.headerCell = headerCell
        checkColumn.width = 30
        tableView.addTableColumn(checkColumn)
        
        // Add select all checkbox to the header view after the table is in the view hierarchy
        DispatchQueue.main.async {
            if let headerView = self.tableView.headerView {
                self.selectAllCheckbox.frame = NSRect(x: 7, y: 0, width: 16, height: headerView.frame.height)
                headerView.addSubview(self.selectAllCheckbox)
            }
        }
        
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NameColumn"))
        nameColumn.title = "Process Name"
        nameColumn.width = 200
        tableView.addTableColumn(nameColumn)
        
        let pidColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("PIDColumn"))
        pidColumn.title = "PID"
        pidColumn.width = 80
        tableView.addTableColumn(pidColumn)
        
        scrollView.documentView = tableView
        
        // Buttons
        let backButton = NSButton(title: "Back", target: self, action: #selector(backButtonClicked))
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.bezelStyle = .rounded
        view.addSubview(backButton)
        
        let endProcessesButton = NSButton(title: "End Processes", target: self, action: #selector(endProcessesButtonClicked))
        endProcessesButton.translatesAutoresizingMaskIntoConstraints = false
        endProcessesButton.bezelStyle = .rounded
        endProcessesButton.contentTintColor = NSColor.systemRed
        view.addSubview(endProcessesButton)
        
        // Set constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: backButton.topAnchor, constant: -20),
            
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            
            endProcessesButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            endProcessesButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func selectAllClicked() {
        let newState = selectAllCheckbox.state
        for checkbox in checkboxes {
            checkbox.state = newState
        }
    }
    
    private func loadProcesses() {
        processes = []
        checkboxes = []
        
        // Run lsof command to find processes using the volume
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
                
                // Skip the header line
                for i in 1..<lines.count {
                    let line = lines[i]
                    let components = line.components(separatedBy: " ").filter { !$0.isEmpty }
                    
                    if components.count >= 2 {
                        let processName = components[0]
                        if let pid = Int(components[1]) {
                            let process = ProcessInfo(name: processName, pid: pid)
                            if !processes.contains(where: { $0.pid == pid }) {
                                processes.append(process)
                            }
                        }
                    }
                }
            }
        } catch {
            print("Error running lsof: \(error)")
        }
        
        tableView.reloadData()
    }
    
    @objc private func backButtonClicked() {
        dismiss(self)
    }
    
    @objc private func endProcessesButtonClicked() {
        var selectedProcesses: [ProcessInfo] = []
        
        for (index, checkbox) in checkboxes.enumerated() {
            if checkbox.state == .on {
                selectedProcesses.append(processes[index])
            }
        }
        
        for process in selectedProcesses {
            let task = Process()
            task.launchPath = "/bin/kill"
            task.arguments = ["-9", String(process.pid)]
            
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                print("Error killing process \(process.pid): \(error)")
            }
        }
        
        loadProcesses()
    }
}

extension ProcessesViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return processes.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let columnIdentifier = tableColumn?.identifier else { return nil }
        let process = processes[row]
        
        switch columnIdentifier.rawValue {
        case "CheckColumn":
            let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
            checkbox.state = .on  // Default to checked
            if row >= checkboxes.count {
                checkboxes.append(checkbox)
            } else {
                checkboxes[row] = checkbox
            }
            return checkbox
            
        case "NameColumn":
            let cellIdentifier = NSUserInterfaceItemIdentifier("NameCell")
            var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
            
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
                    textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -4)
                ])
            }
            
            cellView?.textField?.stringValue = process.name
            return cellView
            
        case "PIDColumn":
            let cellIdentifier = NSUserInterfaceItemIdentifier("PIDCell")
            var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
            
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
                    textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -4)
                ])
            }
            
            cellView?.textField?.stringValue = String(process.pid)
            return cellView
            
        default:
            return nil
        }
    }
} 