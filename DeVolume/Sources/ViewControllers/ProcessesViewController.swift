import Cocoa

class ProcessesViewController: NSViewController {
    private var volume: Volume
    private var processes: [ProcessInfo] = []
    private var tableView: NSTableView!
    
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
        // Fetch processes using the volume path
        self.processes = ProcessList.processesUsingVolume(atPath: volume.path)
        self.tableView.reloadData()
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
        if #available(macOS 10.14, *) {
            endProcessesButton.contentTintColor = .systemRed
        }
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
    
    @objc private func backButtonClicked() {
        dismiss(nil)
    }
    
    @objc private func endProcessesButtonClicked() {
        // Placeholder for process termination
    }
}

extension ProcessesViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return processes.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let columnIdentifier = tableColumn?.identifier else { return nil }
        let process = processes[row]
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("Cell")
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
        
        switch columnIdentifier.rawValue {
        case "NameColumn":
            cellView?.textField?.stringValue = process.name
        case "PIDColumn":
            cellView?.textField?.stringValue = String(process.pid)
        default:
            break
        }
        
        return cellView
    }
}
