import UIKit
import SwiftUI

public class ChainManagementViewController: UIViewController {
    private let chainConfigService: ChainConfigurationService
    private var chains: [ChainConfig] = []
    private var tableView: UITableView!
    
    public init(chainConfigService: ChainConfigurationService) {
        self.chainConfigService = chainConfigService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Manage Chains"
        setupTableView()
        loadChains()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addChainTapped))
    }
    
    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ChainCell")
        view.addSubview(tableView)
    }
    
    private func loadChains() {
        Task {
            chains = await chainConfigService.availableChains
            tableView.reloadData()
        }
    }
    
    @objc private func addChainTapped() {
        let predefinedChains = await chainConfigService.getPredefinedChains()
        let addChainView = AddChainView(predefinedChains: predefinedChains) { [weak self] newChain in
            Task {
                try? await self?.chainConfigService.addChain(newChain)
                self?.loadChains()
                self?.dismiss(animated: true)
            }
        }
        
        let hostingController = UIHostingController(rootView: addChainView)
        present(hostingController, animated: true)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension ChainManagementViewController: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chains.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChainCell", for: indexPath)
        let chain = chains[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = chain.name
        content.secondaryText = chain.type.rawValue.capitalized
        cell.contentConfiguration = content
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Handle editing a chain
    }
    
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let chain = chains[indexPath.row]
            Task {
                try? await chainConfigService.removeChain(with: chain.chainId)
                loadChains()
            }
        }
    }
}

// MARK: - SwiftUI AddChainView

struct AddChainView: View {
    let predefinedChains: [ChainConfig]
    let onAdd: (ChainConfig) -> Void
    
    @State private var selectedChainIndex = 0
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select a Predefined Chain")) {
                    Picker("Chain", selection: $selectedChainIndex) {
                        ForEach(0..<predefinedChains.count, id: \.self) { index in
                            Text(predefinedChains[index].name).tag(index)
                        }
                    }
                }
                
                Button("Add Chain") {
                    onAdd(predefinedChains[selectedChainIndex])
                }
            }
            .navigationTitle("Add New Chain")
        }
    }
}
