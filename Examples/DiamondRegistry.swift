//
// DiamondRegistry - macOS App
// Desktop application for diamond registry management
//

import SwiftUI
import VectorDataStore
import SwiftData
import AppKit

@main
struct DiamondRegistryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandMenu("Diamond") {
                Button("Add Diamond...") {
                    NotificationCenter.default.post(name: .addDiamond, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
                
                Button("Search...") {
                    NotificationCenter.default.post(name: .searchDiamonds, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])
                
                Divider()
                
                Button("Import from CSV...") {
                    NotificationCenter.default.post(name: .importCSV, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                
                Button("Export Registry...") {
                    NotificationCenter.default.post(name: .exportRegistry, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var store = DiamondStore()
    @State private var selectedDiamond: Diamond?
    @State private var searchText = ""
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with diamond list
            DiamondSidebarView(
                diamonds: store.diamonds,
                selectedDiamond: $selectedDiamond,
                searchText: $searchText,
                store: store
            )
        } detail: {
            // Detail view
            if let diamond = selectedDiamond {
                DiamondDetailMacView(diamond: diamond, store: store)
            } else {
                Text("Select a diamond")
                    .font(.title)
                    .foregroundColor(.secondary)
            }
        }
        .task {
            await store.loadDiamonds()
        }
    }
}

struct DiamondSidebarView: View {
    let diamonds: [Diamond]
    @Binding var selectedDiamond: Diamond?
    @Binding var searchText: String
    @ObservedObject var store: DiamondStore
    
    var filteredDiamonds: [Diamond] {
        if searchText.isEmpty {
            return diamonds
        }
        return diamonds.filter {
            $0.certificateNumber.localizedCaseInsensitiveContains(searchText) ||
            $0.origin.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack {
            SearchField("Search diamonds", text: $searchText)
                .padding()
            
            List(filteredDiamonds, selection: $selectedDiamond) { diamond in
                DiamondRowMacView(diamond: diamond)
                    .tag(diamond)
            }
        }
        .navigationTitle("Diamond Registry")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    // Add diamond action
                } label: {
                    Label("Add", systemImage: "plus")
                }
                
                Button {
                    // Refresh action
                    Task {
                        await store.loadDiamonds()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}

struct DiamondRowMacView: View {
    let diamond: Diamond
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(diamond.caratWeight, specifier: "%.2f") ct")
                    .font(.headline)
                
                if diamond.blockchainHash != nil {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                }
            }
            
            Text("\(diamond.color) · \(diamond.clarity) · \(diamond.cut)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(diamond.certificateNumber)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct DiamondDetailMacView: View {
    let diamond: Diamond
    @ObservedObject var store: DiamondStore
    @State private var showingExport = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Diamond \(diamond.certificateNumber)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("$\(diamond.price as NSDecimalNumber)")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Export") {
                        showingExport = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                // Specifications Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    SpecCard(title: "Carat", value: "\(diamond.caratWeight, specifier: "%.2f")")
                    SpecCard(title: "Color", value: diamond.color)
                    SpecCard(title: "Clarity", value: diamond.clarity)
                    SpecCard(title: "Cut", value: diamond.cut)
                    SpecCard(title: "Shape", value: diamond.shape)
                    SpecCard(title: "Origin", value: diamond.origin)
                }
                
                Divider()
                
                // Blockchain Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Blockchain Verification")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let hash = diamond.blockchainHash {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transaction Hash:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(hash)
                                .font(.caption)
                                .monospaced()
                                .textSelection(.enabled)
                            
                            Button("Verify on Etherscan") {
                                if let url = URL(string: "https://etherscan.io/tx/\(hash)") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.link)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        Text("Not yet registered on blockchain")
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Provenance Chain
                ProvenanceTableView(chain: diamond.provenanceChain)
            }
            .padding()
        }
        .fileExporter(
            isPresented: $showingExport,
            document: DiamondDocument(diamond: diamond),
            contentType: .json,
            defaultFilename: "diamond-\(diamond.certificateNumber).json"
        ) { result in
            switch result {
            case .success(let url):
                print("Exported to \(url)")
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
    }
}

struct SpecCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ProvenanceTableView: View {
    let chain: [ProvenanceEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Provenance Chain")
                .font(.title2)
                .fontWeight(.bold)
            
            Table(chain) {
                TableColumn("Date") { entry in
                    Text(entry.timestamp, style: .date)
                }
                
                TableColumn("Action") { entry in
                    Text(entry.action)
                }
                
                TableColumn("Location") { entry in
                    Text(entry.location)
                }
                
                TableColumn("Actor") { entry in
                    Text(entry.actor)
                }
                
                TableColumn("Blockchain TX") { entry in
                    if let txHash = entry.blockchainTxHash {
                        Text(txHash.prefix(10) + "...")
                            .font(.caption)
                            .monospaced()
                    } else {
                        Text("—")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 300)
        }
    }
}

// MARK: - Document Type for Export

struct DiamondDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    let diamond: Diamond
    
    init(diamond: Diamond) {
        self.diamond = diamond
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let diamond = try? JSONDecoder().decode(Diamond.self, from: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.diamond = diamond
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(diamond)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let addDiamond = Notification.Name("addDiamond")
    static let searchDiamonds = Notification.Name("searchDiamonds")
    static let importCSV = Notification.Name("importCSV")
    static let exportRegistry = Notification.Name("exportRegistry")
}
