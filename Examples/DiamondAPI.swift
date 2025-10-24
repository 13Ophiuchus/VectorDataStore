//
// DiamondAPI - Vapor Server (Linux)
// REST API for diamond registry with blockchain integration
//
// Deploy to: DigitalOcean, AWS, Heroku, or any Linux server
//

import Vapor
import VectorDataStore
import Web3
import Fluent
import FluentPostgresDriver

// MARK: - Diamond Model (Server) ----------------------------------------------

final class Diamond: Model, Content, @unchecked Sendable {
    static let schema = "diamonds"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "certificate_number")
    var certificateNumber: String
    
    @Field(key: "carat_weight")
    var caratWeight: Double
    
    @Field(key: "color")
    var color: String
    
    @Field(key: "clarity")
    var clarity: String
    
    @Field(key: "cut")
    var cut: String
    
    @Field(key: "shape")
    var shape: String
    
    @Field(key: "price")
    var price: Decimal
    
    @Field(key: "origin")
    var origin: String
    
    @Field(key: "certifying_lab")
    var certifyingLab: String
    
    @OptionalField(key: "blockchain_hash")
    var blockchainHash: String?
    
    @Field(key: "provenance_chain")
    var provenanceChainJSON: String // JSON string
    
    @Field(key: "ethically_sourced")
    var ethicallySourced: Bool
    
    @Field(key: "conflict_free")
    var conflictFree: Bool
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(
        id: UUID? = nil,
        certificateNumber: String,
        caratWeight: Double,
        color: String,
        clarity: String,
        cut: String,
        shape: String,
        price: Decimal,
        origin: String,
        certifyingLab: String,
        blockchainHash: String? = nil,
        provenanceChainJSON: String = "[]",
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
        self.blockchainHash = blockchainHash
        self.provenanceChainJSON = provenanceChainJSON
        self.ethicallySourced = ethicallySourced
        self.conflictFree = conflictFree
    }
}

// MARK: - Migration -----------------------------------------------------------

struct CreateDiamond: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("diamonds")
            .id()
            .field("certificate_number", .string, .required)
            .field("carat_weight", .double, .required)
            .field("color", .string, .required)
            .field("clarity", .string, .required)
            .field("cut", .string, .required)
            .field("shape", .string, .required)
            .field("price", .double, .required)
            .field("origin", .string, .required)
            .field("certifying_lab", .string, .required)
            .field("blockchain_hash", .string)
            .field("provenance_chain", .string, .required)
            .field("ethically_sourced", .bool, .required)
            .field("conflict_free", .bool, .required)
            .field("created_at", .datetime)
            .unique(on: "certificate_number")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("diamonds").delete()
    }
}

// MARK: - DTO Models ----------------------------------------------------------

struct DiamondCreateDTO: Content {
    let certificateNumber: String
    let caratWeight: Double
    let color: String
    let clarity: String
    let cut: String
    let shape: String
    let price: Decimal
    let origin: String
    let certifyingLab: String
    let provenanceChain: [ProvenanceEntryDTO]?
}

struct DiamondResponseDTO: Content {
    let id: UUID
    let certificateNumber: String
    let caratWeight: Double
    let color: String
    let clarity: String
    let cut: String
    let shape: String
    let price: Decimal
    let origin: String
    let certifyingLab: String
    let blockchainHash: String?
    let provenanceChain: [ProvenanceEntryDTO]
    let ethicallySourced: Bool
    let conflictFree: Bool
    let createdAt: Date?
    
    init(diamond: Diamond) throws {
        self.id = diamond.id!
        self.certificateNumber = diamond.certificateNumber
        self.caratWeight = diamond.caratWeight
        self.color = diamond.color
        self.clarity = diamond.clarity
        self.cut = diamond.cut
        self.shape = diamond.shape
        self.price = diamond.price
        self.origin = diamond.origin
        self.certifyingLab = diamond.certifyingLab
        self.blockchainHash = diamond.blockchainHash
        self.ethicallySourced = diamond.ethicallySourced
        self.conflictFree = diamond.conflictFree
        self.createdAt = diamond.createdAt
        
        let data = Data(diamond.provenanceChainJSON.utf8)
        self.provenanceChain = try JSONDecoder().decode([ProvenanceEntryDTO].self, from: data)
    }
}

struct ProvenanceEntryDTO: Content {
    let id: String
    let timestamp: Date
    let location: String
    let action: String
    let actor: String
    let blockchainTxHash: String?
}

struct SearchQueryDTO: Content {
    let query: String
    let topK: Int?
    let threshold: Float?
}

struct BlockchainVerificationDTO: Content {
    let verified: Bool
    let transactionHash: String?
    let message: String
}

// MARK: - Vector Store Service ------------------------------------------------

final class VectorStoreService: @unchecked Sendable {
    private let store: VectorDataStore<[Float], VectorDiamond>
    private let blockchain: BlockchainService
    
    init() async throws {
        // Configure Qdrant backend for production
        let qdrantURL = Environment.get("QDRANT_URL") ?? "http://localhost:6333"
        let apiKey = Environment.get("QDRANT_API_KEY")
        
        let backend = QdrantBackend<[Float]>(
            endpoint: URL(string: qdrantURL)!,
            apiKey: apiKey,
            collectionName: "diamonds",
            vectorDimensions: 1536
        )
        
        try await backend.createCollectionIfNeeded()
        
        // Configure OpenAI embedder
        let openaiKey = Environment.get("OPENAI_API_KEY")!
        let embedder = OpenAIEmbedder(apiKey: openaiKey, model: "text-embedding-3-small")
        
        // Create vector store
        let config = DataStoreConfiguration<[Float]>(
            storeName: "diamonds",
            schema: .init(vectorDimensions: 1536)
        )
        
        self.store = VectorDataStore(
            configuration: config,
            embedder: embedder,
            backend: backend
        )
        
        // Initialize blockchain service
        let infuraURL = Environment.get("INFURA_URL")!
        let privateKey = Environment.get("ETH_PRIVATE_KEY")!
        let contractAddress = Environment.get("CONTRACT_ADDRESS")!
        
        self.blockchain = try BlockchainService(
            infuraURL: infuraURL,
            privateKey: privateKey,
            contractAddress: contractAddress
        )
    }
    
    func indexDiamond(_ diamond: Diamond) async throws {
        let vectorDiamond = VectorDiamond(diamond: diamond)
        try await store.execute(DataStoreSaveChangesRequest([vectorDiamond]))
    }
    
    func searchDiamonds(query: String, topK: Int = 10, threshold: Float? = nil) async throws -> [Diamond] {
        let request = DataStoreFetchRequest<VectorDiamond>(
            queryText: query,
            topK: topK,
            threshold: threshold
        )
        
        let results = try await store.execute(request)
        return results.map { $0.toDiamond() }
    }
    
    func registerOnBlockchain(_ diamond: Diamond) async throws -> String {
        let provenanceHash = BlockchainService.calculateProvenanceHash(diamond)
        
        return try await blockchain.storeDiamondHash(
            diamondId: diamond.id!.uuidString,
            provenanceHash: provenanceHash,
            certificateNumber: diamond.certificateNumber
        )
    }
    
    func verifyBlockchain(_ diamond: Diamond) async throws -> Bool {
        guard let blockchainHash = diamond.blockchainHash else {
            return false
        }
        
        let expectedHash = BlockchainService.calculateProvenanceHash(diamond)
        return try await blockchain.verifyDiamondHash(
            diamondId: diamond.id!.uuidString,
            expectedHash: expectedHash
        )
    }
}

// MARK: - Vector Diamond Adapter ---------------------------------------------

struct VectorDiamond: VectorModel, Codable {
    let id: String
    let data: String
    
    var embeddingText: String { data }
    
    init?(metadata: [String: String]) {
        guard let id = metadata["id"],
              let data = metadata["data"] else {
            return nil
        }
        self.id = id
        self.data = data
    }
    
    init(diamond: Diamond) {
        self.id = diamond.id!.uuidString
        self.data = """
        \(diamond.caratWeight) carat \(diamond.color) color \(diamond.clarity) clarity \(diamond.cut) cut \(diamond.shape) shape diamond.
        Origin: \(diamond.origin). Certificate: \(diamond.certificateNumber) from \(diamond.certifyingLab).
        """
    }
    
    func toDiamond() -> Diamond {
        // In production, you'd query the database using the ID
        Diamond()
    }
}

// MARK: - Routes --------------------------------------------------------------

struct DiamondController: RouteCollection {
    let vectorStore: VectorStoreService
    
    func boot(routes: RoutesBuilder) throws {
        let diamonds = routes.grouped("api", "diamonds")
        
        diamonds.get(use: index)
        diamonds.post(use: create)
        diamonds.get(":diamondID", use: show)
        diamonds.put(":diamondID", use: update)
        diamonds.delete(":diamondID", use: delete)
        
        diamonds.post("search", use: search)
        diamonds.post(":diamondID", "register-blockchain", use: registerBlockchain)
        diamonds.post(":diamondID", "verify-blockchain", use: verifyBlockchain)
        diamonds.get(":diamondID", "similar", use: findSimilar)
    }
    
    // GET /api/diamonds
    func index(req: Request) async throws -> [DiamondResponseDTO] {
        let diamonds = try await Diamond.query(on: req.db).all()
        return try diamonds.map { try DiamondResponseDTO(diamond: $0) }
    }
    
    // POST /api/diamonds
    func create(req: Request) async throws -> DiamondResponseDTO {
        let dto = try req.content.decode(DiamondCreateDTO.self)
        
        let provenanceJSON = try JSONEncoder().encode(dto.provenanceChain ?? [])
        let provenanceString = String(data: provenanceJSON, encoding: .utf8)!
        
        let diamond = Diamond(
            certificateNumber: dto.certificateNumber,
            caratWeight: dto.caratWeight,
            color: dto.color,
            clarity: dto.clarity,
            cut: dto.cut,
            shape: dto.shape,
            price: dto.price,
            origin: dto.origin,
            certifyingLab: dto.certifyingLab,
            provenanceChainJSON: provenanceString
        )
        
        try await diamond.save(on: req.db)
        
        // Index in vector store
        try await vectorStore.indexDiamond(diamond)
        
        return try DiamondResponseDTO(diamond: diamond)
    }
    
    // GET /api/diamonds/:id
    func show(req: Request) async throws -> DiamondResponseDTO {
        guard let diamond = try await Diamond.find(req.parameters.get("diamondID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return try DiamondResponseDTO(diamond: diamond)
    }
    
    // PUT /api/diamonds/:id
    func update(req: Request) async throws -> DiamondResponseDTO {
        guard let diamond = try await Diamond.find(req.parameters.get("diamondID"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        let dto = try req.content.decode(DiamondCreateDTO.self)
        
        diamond.certificateNumber = dto.certificateNumber
        diamond.caratWeight = dto.caratWeight
        diamond.color = dto.color
        diamond.clarity = dto.clarity
        diamond.cut = dto.cut
        diamond.shape = dto.shape
        diamond.price = dto.price
        diamond.origin = dto.origin
        diamond.certifyingLab = dto.certifyingLab
        
        try await diamond.save(on: req.db)
        try await vectorStore.indexDiamond(diamond)
        
        return try DiamondResponseDTO(diamond: diamond)
    }
    
    // DELETE /api/diamonds/:id
    func delete(req: Request) async throws -> HTTPStatus {
        guard let diamond = try await Diamond.find(req.parameters.get("diamondID"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        try await diamond.delete(on: req.db)
        return .noContent
    }
    
    // POST /api/diamonds/search
    func search(req: Request) async throws -> [DiamondResponseDTO] {
        let query = try req.content.decode(SearchQueryDTO.self)
        
        let results = try await vectorStore.searchDiamonds(
            query: query.query,
            topK: query.topK ?? 10,
            threshold: query.threshold
        )
        
        return try results.map { try DiamondResponseDTO(diamond: $0) }
    }
    
    // POST /api/diamonds/:id/register-blockchain
    func registerBlockchain(req: Request) async throws -> DiamondResponseDTO {
        guard let diamond = try await Diamond.find(req.parameters.get("diamondID"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        let txHash = try await vectorStore.registerOnBlockchain(diamond)
        diamond.blockchainHash = txHash
        try await diamond.save(on: req.db)
        
        return try DiamondResponseDTO(diamond: diamond)
    }
    
    // POST /api/diamonds/:id/verify-blockchain
    func verifyBlockchain(req: Request) async throws -> BlockchainVerificationDTO {
        guard let diamond = try await Diamond.find(req.parameters.get("diamondID"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        guard let blockchainHash = diamond.blockchainHash else {
            return BlockchainVerificationDTO(
                verified: false,
                transactionHash: nil,
                message: "Diamond not registered on blockchain"
            )
        }
        
        let verified = try await vectorStore.verifyBlockchain(diamond)
        
        return BlockchainVerificationDTO(
            verified: verified,
            transactionHash: blockchainHash,
            message: verified ? "Provenance verified ✓" : "Verification failed"
        )
    }
    
    // GET /api/diamonds/:id/similar
    func findSimilar(req: Request) async throws -> [DiamondResponseDTO] {
        guard let diamond = try await Diamond.find(req.parameters.get("diamondID"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        let query = """
        \(diamond.caratWeight) carat \(diamond.color) \(diamond.clarity) \(diamond.cut) \(diamond.shape)
        """
        
        let results = try await vectorStore.searchDiamonds(
            query: query,
            topK: 6, // Include the diamond itself
            threshold: 0.85
        )
        
        // Filter out the diamond itself
        let similar = results.filter { $0.id != diamond.id }
        
        return try similar.map { try DiamondResponseDTO(diamond: $0) }
    }
}

// MARK: - App Configuration ---------------------------------------------------

public func configure(_ app: Application) async throws {
    // Database
    app.databases.use(
        .postgres(
            hostname: Environment.get("DB_HOST") ?? "localhost",
            username: Environment.get("DB_USER") ?? "vapor",
            password: Environment.get("DB_PASS") ?? "password",
            database: Environment.get("DB_NAME") ?? "diamonds"
        ),
        as: .psql
    )
    
    // Migrations
    app.migrations.add(CreateDiamond())
    try await app.autoMigrate()
    
    // CORS
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))
    
    // Initialize vector store
    let vectorStore = try await VectorStoreService()
    
    // Register routes
    try app.register(collection: DiamondController(vectorStore: vectorStore))
    
    // Health check
    app.get("health") { req in
        ["status": "healthy"]
    }
}

// MARK: - Main Entry Point ----------------------------------------------------

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        let app = Application(env)
        defer { app.shutdown() }
        
        try await configure(app)
        try await app.execute()
    }
}

// MARK: - Docker Compose Configuration ----------------------------------------

/*
# docker-compose.yml

version: '3.8'

services:
  api:
    build: .
    ports:
      - "8080:8080"
    environment:
      - DB_HOST=postgres
      - DB_USER=vapor
      - DB_PASS=password
      - DB_NAME=diamonds
      - QDRANT_URL=http://qdrant:6333
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - INFURA_URL=${INFURA_URL}
      - ETH_PRIVATE_KEY=${ETH_PRIVATE_KEY}
      - CONTRACT_ADDRESS=${CONTRACT_ADDRESS}
    depends_on:
      - postgres
      - qdrant
  
  postgres:
    image: postgres:15
    environment:
      - POSTGRES_USER=vapor
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=diamonds
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
  
  qdrant:
    image: qdrant/qdrant:latest
    ports:
      - "6333:6333"
      - "6334:6334"
    volumes:
      - qdrant_data:/qdrant/storage

volumes:
  postgres_data:
  qdrant_data:
*/
