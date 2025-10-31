//
// DiamondApp - iOS Example
// Demonstrates VectorDataStore for blockchain diamond provenance
//
// Features:
// 1. Semantic diamond search
// 2. Provenance verification via vector similarity
// 3. On-device SwiftData backend
// 4. Blockchain integration (Ethereum via web3.swift)
// 5. Swift 6 concurrency
//

import SwiftUI
import VectorDataStore
import SwiftData
import Web3
import Web3ContractABI

// MARK: - Diamond Model --------------------------------------------------------

/// Diamond model with blockchain provenance
final class Diamond: PersistentModel, Identifiable, Codable {
    static var schemaVersion: Int { 1 }
    
    // Core Properties
    var id: String
    var certificateNumber: String
    var caratWeight: Double
    var color: String // D-Z scale
    var clarity: String // FL, IF, VVS1, VVS2, VS1, VS2, SI1, SI2, I1, I2, I3
    var cut: String // Excellent, Very Good, Good, Fair, Poor
    var shape: String // Round, Princess, Oval, Emerald, etc.
    
    // Blockchain Properties
    var blockchainHash: String?  // On-chain hash
    var provenanceChain: [ProvenanceEntry]
    var ethicallySourced: Bool
    var conflictFree: Bool
    
    // Metadata
    var price: Decimal
    var origin: String // Mine location
    var certifyingLab: String // GIA, AGS, etc.
    var createdAt: Date
    
    // Embedding text for vector search
    var embeddingText: String {
        """
        \(caratWeight) carat \(color) color \(clarity) clarity \(cut) cut \(shape) shape diamond.
        Origin: \(origin). Certificate: \(certificateNumber) from \(certifyingLab).
        \(ethicallySourced ? "Ethically sourced" : ""). \(conflictFree ? "Conflict free" : "").
        """
    }
    
    init(
        id: String = UUID().uuidString,
        certificateNumber: String,
        caratWeight: Double,
        color: String,
        clarity: String,
        cut: String,
        shape: String,
        price: Decimal,
        origin: String,
        certifyingLab: String,
        provenanceChain: [ProvenanceEntry] = [],
        ethicallySourced: Bool = true,
        conflictFree: Bool = true
    ) {
        self.id = id
        self.certificateNumber = certificateNumber
        self.caratWeight = caratWeight
        self.color = color
        self.clarity = clarity
        self.cut = cut
        self.shape = shape
        self.price = price
        self.origin = origin
        self.certifyingLab = certifyingLab
        self.provenanceChain = provenanceChain
        self.ethicallySourced = ethicallySourced
        self.conflictFree = conflictFree
        self.createdAt = Date()
    }
    
    required init?(metadata: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: metadata),
              let decoded = try? JSONDecoder().decode(Diamond.self, from: data) else {
            return nil
        }
        self = decoded
    }
    
    static func migrate(_ old: [String: Any], from version: Int) -> Diamond? {
        return nil // No migrations yet
    }
}

/// Provenance entry for supply chain tracking
struct ProvenanceEntry: Codable, Identifiable, Hashable {
    let id: String
    let timestamp: Date
    let location: String
    let action: String // "Mined", "Cut", "Polished", "Certified", "Transferred"
    let actor: String // Company or individual
    let blockchainTxHash: String? // Ethereum transaction hash
}

// MARK: - Blockchain Service ---------------------------------------------------

/// Ethereum blockchain integration for diamond provenance
actor BlockchainService {
    private let client: EthereumHttpClient
    private let account: EthereumAccount
    private let contractAddress: EthereumAddress
    
    enum BlockchainError: Error, LocalizedError {
        case contractError
        case transactionFailed
        case invalidHash
        case networkError
        
        var errorDescription: String? {
            switch self {
            case .contractError: return "Smart contract error"
            case .transactionFailed: return "Transaction failed"
            case .invalidHash: return "Invalid blockchain hash"
            case .networkError: return "Network connection error"
            }
        }
    }
    
    init(infuraURL: String, privateKey: String, contractAddress: String) throws {
        guard let clientURL = URL(string: infuraURL) else {
            throw BlockchainError.networkError
        }
        
        self.client = EthereumHttpClient(url: clientURL)
        self.account = try EthereumAccount(keyStorage: EthereumKeyLocalStorage())
        self.contractAddress = EthereumAddress(contractAddress)
    }
    
    /// Store diamond provenance hash on blockchain
    func storeDiamondHash(
        diamondId: String,
        provenanceHash: String,
        certificateNumber: String
    ) async throws -> String {
        
        // Smart contract function: storeDiamond(string id, bytes32 hash, string cert)
        struct StoreDiamondFunction: ABIFunction {
            static let name = "storeDiamond"
            let gasPrice: BigUInt? = nil
            let gasLimit: BigUInt? = BigUInt(200000)
            
            let diamondId: String
            let provenanceHash: Data
            let certificateNumber: String
            
            func encode(to encoder: ABIFunctionEncoder) throws {
                try encoder.encode(diamondId)
                try encoder.encode(provenanceHash)
                try encoder.encode(certificateNumber)
            }
        }
        
        let hashData = Data(hex: provenanceHash)
        let function = StoreDiamondFunction(
            diamondId: diamondId,
            provenanceHash: hashData,
            certificateNumber: certificateNumber
        )
        
        let transaction = try function.transaction(
            from: account.address,
            to: contractAddress
        )
        
        let txHash = try await client.eth_sendRawTransaction(transaction)
        return txHash.hex()
    }
    
    /// Verify diamond provenance hash on blockchain
    func verifyDiamondHash(diamondId: String, expectedHash: String) async throws -> Bool {
        
        // Smart contract function: getDiamondHash(string id) returns (bytes32)
        struct GetDiamondHashFunction: ABIFunction {
            static let name = "getDiamondHash"
            let gasPrice: BigUInt? = nil
            let gasLimit: BigUInt? = nil
            
            let diamondId: String
            
            func encode(to encoder: ABIFunctionEncoder) throws {
                try encoder.encode(diamondId)
            }
        }
        
        let function = GetDiamondHashFunction(diamondId: diamondId)
        let call = try function.call(to: contractAddress)
        
        let result = try await client.eth_call(call, block: .latest)
        let onChainHash = result.hex()
        
        return onChainHash == expectedHash
    }
    
    /// Calculate provenance hash for diamond
    static func calculateProvenanceHash(_ diamond: Diamond) -> String {
        let data = "\(diamond.certificateNumber)\(diamond.origin)\(diamond.provenanceChain.count)"
        return data.sha256()
    }
}

// MARK: - Diamond Store --------------------------------------------------------

/// Main diamond store with vector search and blockchain integration
@MainActor
class DiamondStore: ObservableObject {
    @Published var diamonds: [Diamond] = []
    @Published var searchResults: [Diamond] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let vectorStore: SwiftDataStyleStore<[Float], Diamond>
    private let blockchainService: BlockchainService
    
    init() throws {
        // Initialize SwiftData backend for local persistence
        let backend = try SwiftDataBackend<[Float]>.createDefault(storeName: "Diamonds")
        
        // Initialize OpenAI embedder
        let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        let embedder = OpenAIEmbedder(apiKey: apiKey, model: "text-embedding-3-small")
        
        // Create vector store configuration
        let config = DataStoreConfiguration<[Float]>(
            storeName: "diamonds",
            schema: .init(vectorDimensions: 1536)
        )
        
        // Initialize vector store
        self.vectorStore = SwiftDataStyleStore(
            configuration: config,
            embedder: embedder,
            backend: backend
        )
        
        // Initialize blockchain service
        let infuraURL = "https://mainnet.infura.io/v3/YOUR_PROJECT_ID"
        let privateKey = ProcessInfo.processInfo.environment["ETH_PRIVATE_KEY"] ?? ""
        let contractAddress = "0xYourContractAddress"
        
        self.blockchainService = try BlockchainService(
            infuraURL: infuraURL,
            privateKey: privateKey,
            contractAddress: contractAddress
        )
    }
    
    /// Add diamond with blockchain provenance
    func addDiamond(_ diamond: Diamond) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 1. Store in vector database
            try await vectorStore.transaction { tx in
                tx.insert(DefaultSnapshot(of: diamond))
            }
            
            // 2. Calculate provenance hash
            let provenanceHash = BlockchainService.calculateProvenanceHash(diamond)
            
            // 3. Store hash on blockchain
            let txHash = try await blockchainService.storeDiamondHash(
                diamondId: diamond.id,
                provenanceHash: provenanceHash,
                certificateNumber: diamond.certificateNumber
            )
            
            // 4. Update diamond with blockchain hash
            var updatedDiamond = diamond
            updatedDiamond.blockchainHash = txHash
            
            try await vectorStore.transaction { tx in
                tx.update(DefaultSnapshot(of: updatedDiamond))
            }
            
            await loadDiamonds()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Search diamonds by natural language query
    func searchDiamonds(query: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let request = DataStoreFetchRequest<Diamond>(
                semanticQuery: query,
                fetchLimit: 20,
                similarityThreshold: 0.7
            )
            
            let results = try await vectorStore.execute(request)
            searchResults = results.snapshots.map { $0.model }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Verify diamond provenance against blockchain
    func verifyProvenance(_ diamond: Diamond) async throws -> Bool {
        guard let blockchainHash = diamond.blockchainHash else {
            throw BlockchainService.BlockchainError.invalidHash
        }
        
        let expectedHash = BlockchainService.calculateProvenanceHash(diamond)
        return try await blockchainService.verifyDiamondHash(
            diamondId: diamond.id,
            expectedHash: expectedHash
        )
    }
    
    /// Find similar diamonds (for authentication)
    func findSimilar(to diamond: Diamond) async throws -> [Diamond] {
        let query = diamond.embeddingText
        
        let request = DataStoreFetchRequest<Diamond>(
            semanticQuery: query,
            fetchLimit: 5,
            similarityThreshold: 0.85 // High threshold for similarity
        )
        
        let results = try await vectorStore.execute(request)
        return results.snapshots
            .map { $0.model }
            .filter { $0.id != diamond.id } // Exclude the diamond itself
    }
    
    /// Load all diamonds
    func loadDiamonds() async {
        do {
            let request = DataStoreFetchRequest<Diamond>(fetchLimit: nil, semanticQuery: nil)
            let results = try await vectorStore.execute(request)
            diamonds = results.snapshots.map { $0.model }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - SwiftUI Views --------------------------------------------------------

struct DiamondListView: View {
    @StateObject private var store: DiamondStore
    @State private var searchQuery = ""
    @State private var showingAddDiamond = false
    
    init() {
        _store = StateObject(wrappedValue: try! DiamondStore())
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                SearchBar(text: $searchQuery, onSearch: {
                    Task {
                        try await store.searchDiamonds(query: searchQuery)
                    }
                })
                
                if store.isLoading {
                    ProgressView("Loading...")
                } else {
                    List(searchQuery.isEmpty ? store.diamonds : store.searchResults) { diamond in
                        NavigationLink(destination: DiamondDetailView(diamond: diamond, store: store)) {
                            DiamondRowView(diamond: diamond)
                        }
                    }
                }
            }
            .navigationTitle("Diamond Registry")
            .toolbar {
                Button {
                    showingAddDiamond = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddDiamond) {
                AddDiamondView(store: store)
            }
            .task {
                await store.loadDiamonds()
            }
        }
    }
}

struct DiamondRowView: View {
    let diamond: Diamond
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(diamond.caratWeight, specifier: "%.2f") ct \(diamond.shape)")
                    .font(.headline)
                
                HStack {
                    Text("\(diamond.color) · \(diamond.clarity) · \(diamond.cut)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if diamond.blockchainHash != nil {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Text("$\(diamond.price as NSDecimalNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            if diamond.ethicallySourced && diamond.conflictFree {
                VStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                    Text("Ethical")
                        .font(.caption2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct DiamondDetailView: View {
    let diamond: Diamond
    let store: DiamondStore
    
    @State private var isVerified: Bool?
    @State private var similarDiamonds: [Diamond] = []
    @State private var showingProvenance = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Diamond Image Placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 300)
                    .overlay(
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 100))
                            .foregroundColor(.blue.opacity(0.3))
                    )
                
                // Specifications
                VStack(alignment: .leading, spacing: 12) {
                    Text("Specifications")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    SpecRow(label: "Carat", value: "\(diamond.caratWeight, specifier: "%.2f")")
                    SpecRow(label: "Color", value: diamond.color)
                    SpecRow(label: "Clarity", value: diamond.clarity)
                    SpecRow(label: "Cut", value: diamond.cut)
                    SpecRow(label: "Shape", value: diamond.shape)
                    SpecRow(label: "Certificate", value: diamond.certificateNumber)
                    SpecRow(label: "Lab", value: diamond.certifyingLab)
                    SpecRow(label: "Origin", value: diamond.origin)
                }
                
                Divider()
                
                // Blockchain Verification
                VStack(alignment: .leading, spacing: 12) {
                    Text("Blockchain Verification")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let blockchainHash = diamond.blockchainHash {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .foregroundColor(.blue)
                            Text("Hash: \(blockchainHash.prefix(10))...")
                                .font(.caption)
                                .monospaced()
                        }
                        
                        Button("Verify Provenance") {
                            Task {
                                isVerified = try await store.verifyProvenance(diamond)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        if let verified = isVerified {
                            HStack {
                                Image(systemName: verified ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(verified ? .green : .red)
                                Text(verified ? "Verified ✓" : "Verification Failed")
                            }
                        }
                    } else {
                        Text("Not yet registered on blockchain")
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Similar Diamonds
                VStack(alignment: .leading, spacing: 12) {
                    Text("Similar Diamonds")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if similarDiamonds.isEmpty {
                        Button("Find Similar") {
                            Task {
                                similarDiamonds = try await store.findSimilar(to: diamond)
                            }
                        }
                    } else {
                        ForEach(similarDiamonds) { similar in
                            DiamondRowView(diamond: similar)
                        }
                    }
                }
                
                Divider()
                
                // Provenance Chain
                Button("View Provenance Chain") {
                    showingProvenance = true
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("Diamond Details")
        .sheet(isPresented: $showingProvenance) {
            ProvenanceChainView(chain: diamond.provenanceChain)
        }
    }
}

struct SpecRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct ProvenanceChainView: View {
    let chain: [ProvenanceEntry]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List(chain) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.action)
                        .font(.headline)
                    Text(entry.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(entry.actor)
                        .font(.caption)
                    Text(entry.timestamp, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let txHash = entry.blockchainTxHash {
                        Text("TX: \(txHash.prefix(10))...")
                            .font(.caption2)
                            .monospaced()
                    }
                }
            }
            .navigationTitle("Provenance Chain")
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}




// MARK: - Helper Extensions ----------------------------------------------------

extension String {
    func sha256() -> String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension Data {
    init(hex: String) {
        var hex = hex
        if hex.hasPrefix("0x") {
            hex = String(hex.dropFirst(2))
        }
        
        var data = Data()
        var index = hex.startIndex
        
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            if let byte = UInt8(hex[index..<nextIndex], radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }
        
        self = data
    }
}
