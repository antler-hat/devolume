import Cocoa

final class RulesViewController: NSViewController {
    private let ruleStore: ProcessRuleStore
    private var rules: [ProcessRule] = []

    private var tableView: NSTableView!
    private var removeButton: NSButton!
    private var emptyStateLabel: NSTextField!

    private var observer: NSObjectProtocol?

    init(ruleStore: ProcessRuleStore) {
        self.ruleStore = ruleStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func loadView() {
        view = NSView()
        setupUI()
        refreshRules()
        observer = NotificationCenter.default.addObserver(
            forName: ProcessRuleStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshRules()
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        tableView.deselectAll(nil)
        updateRemoveButtonState()
    }
}

extension RulesViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return rules.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < rules.count else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("RuleCell")
        let cell: NSTableCellView
        if let existing = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = existing
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        cell.textField?.stringValue = rules[row].displayName
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateRemoveButtonState()
    }
}

private extension RulesViewController {
    func setupUI() {
        view.translatesAutoresizingMaskIntoConstraints = false

        let titleField = NSTextField(labelWithString: "Saved process rules")
        titleField.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleField)

        let descriptionField = NSTextField(labelWithString: "These processes will end automatically when they block an ejection.")
        descriptionField.font = NSFont.systemFont(ofSize: 12)
        descriptionField.textColor = NSColor.secondaryLabelColor
        descriptionField.lineBreakMode = .byWordWrapping
        descriptionField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(descriptionField)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        view.addSubview(scrollView)

        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.allowsMultipleSelection = true
        tableView.usesAlternatingRowBackgroundColors = true

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("RuleNameColumn"))
        nameColumn.title = "Process"
        nameColumn.width = 260
        tableView.addTableColumn(nameColumn)

        scrollView.documentView = tableView

        removeButton = NSButton(
            title: "Remove Selected",
            target: self,
            action: #selector(removeSelectedRules)
        )
        removeButton.bezelStyle = .rounded
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.isEnabled = false
        view.addSubview(removeButton)

        emptyStateLabel = NSTextField(labelWithString: "No saved rules yet.")
        emptyStateLabel.font = NSFont.systemFont(ofSize: 13)
        emptyStateLabel.textColor = NSColor.secondaryLabelColor
        emptyStateLabel.alignment = .center
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.isHidden = true
        view.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            titleField.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            descriptionField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 4),
            descriptionField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            descriptionField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: descriptionField.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: removeButton.topAnchor, constant: -16),

            removeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            removeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            emptyStateLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
    }

    @objc func removeSelectedRules() {
        let selectedIndexes = tableView.selectedRowIndexes
        guard !selectedIndexes.isEmpty else { return }

        let identifiers = selectedIndexes.compactMap { index -> String? in
            guard index >= 0 && index < rules.count else { return nil }
            return rules[index].identifier
        }

        ruleStore.removeRules(withIdentifiers: identifiers)
        tableView.deselectAll(nil)
        updateRemoveButtonState()
    }

    func refreshRules() {
        rules = ruleStore.allRules()
        tableView.reloadData()
        emptyStateLabel.isHidden = !rules.isEmpty
        updateRemoveButtonState()
    }

    func updateRemoveButtonState() {
        let hasSelection = tableView.selectedRowIndexes.contains(where: { $0 >= 0 })
        removeButton.isEnabled = hasSelection
    }
}
