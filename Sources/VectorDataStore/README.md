
# VectorDataStore

**A Swift 6 vector database library with SwiftData-style APIs for semantic search.**

[![CI Status](https://github.com/YourUsername/VectorDataStore/workflows/VectorDataStore%20CI%2FCD/badge.svg)](https://github.com/YourUsername/VectorDataStore/actions)
[![codecov](https://codecov.io/gh/YourUsername/VectorDataStore/branch/main/graph/badge.svg)](https://codecov.io/gh/YourUsername/VectorDataStore)
[![Swift Version](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platforms-iOS%2017+%20|%20macOS%2014+%20|%20watchOS%209+%20|%20tvOS%2015+-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

VectorDataStore is a modern, type-safe Swift library that brings semantic search capabilities to your iOS, macOS, watchOS, and tvOS applications. Built with Swift 6's strict concurrency model, it provides SwiftData-style APIs for working with vector embeddings and vector databases.

## Features

- âœ… **SwiftData-Style APIs** - Familiar transaction-based API for iOS developers
- âœ… **Swift 6 Concurrency** - Full actor isolation and `async/await` support
- âœ… **Multiple Backends** - MemoryBackend, QdrantBackend, and extensible protocol
- âœ… **Embedding Providers** - OpenAI, with support for custom providers
- âœ… **Type-Safe** - Leverage Swift's type system for compile-time safety
- âœ… **Migration Support** - Schema versioning and data migration
- âœ… **Comprehensive Testing** - 80%+ code coverage with unit and integration tests

## Requirements

- **iOS 17.0+** / **macOS 14.0+** / **watchOS 9.0+** / **tvOS 15.0+**
- **Xcode 16.0+**
- **Swift 6.2+**

## Installation

### Swift Package Manager

Add VectorDataStore to your project using Swift Package Manager:

**In Xcode:**
1. Go to **File > Add Package Dependencies...**
2. Enter the repository URL:
   ```
   https://github.com/YourUsername/VectorDataStore.git
   ```
3. Select the version you want to use

**In Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/YourUsername/VectorDataStore.git", from: "1.0.0")
]
```

Then add it to your target:
```swift
targets: [
    .target(
        name: "YourApp",
        dependencies: ["VectorDataStore"]
    )
]
```

## Quick Start

### 1. Define Your Model

```swift
import VectorDataStore

struct ResearchPaper: VectorModel, Codable, Equatable {
    let id: String
    let title: String
    let abstract: String
    
    var embeddingText: String {
        "\(title). \(abstract)"
    }
    
    init?(metadata: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: metadata),
              let decoded = try? JSONDecoder().decode(Self.self, from: data) else {
            return nil
        }
        self = decoded
    }
}
```

### 2. Setup Your Store

```swift
// Configure the store
let config = DataStoreConfiguration<[Float]>(
    storeName: "research",
    schema: .init(vectorDimensions: 1536),
    endpoint: URL(string: "http://localhost:6333"),
    apiKey: nil
)

// Setup embedding provider
let embedder = OpenAIEmbedder(apiKey: "your-openai-api-key")

// Choose your backend
let backend = QdrantBackend<[Float]>(
    endpoint: config.endpoint!,
    collectionName: config.storeName,
    vectorDimensions: config.schema.vectorDimensions
)

// Create collection if needed
try await backend.createCollectionIfNeeded()

// Initialize the store
let store = VectorDataStore(
    configuration: config,
    embedder: embedder,
    backend: backend
)
```

### 3. Insert and Search Documents

```swift
// Insert documents
let papers = [
    ResearchPaper(id: "1", title: "Attention Is All You Need", 
                 abstract: "We propose a new architecture..."),
    ResearchPaper(id: "2", title: "BERT", 
                 abstract: "Bidirectional transformers...")
]

try await store.execute(DataStoreSaveChangesRequest(papers))

// Semantic search
let results = try await store.execute(
    DataStoreFetchRequest(queryText: "transformer architecture", topK: 5)
)

for paper in results {
    print(paper.title)
}
```

### 4. Using SwiftData-Style Store

```swift
// For SwiftData-style transactions with PersistentModel
final class Note: PersistentModel, Codable {
    static var schemaVersion: Int { 1 }
    
    var id: String
    var title: String
    var content: String
    
    var embeddingText: String { "\(title). \(content)" }
    
    // ... init methods
}

let swiftDataStore = SwiftDataStyleStore<[Float], Note>(
    configuration: config,
    embedder: embedder,
    backend: backend
)

// Insert via transaction
try await swiftDataStore.transaction { tx in
    let note = Note(id: UUID().uuidString, title: "Swift 6", content: "Concurrency")
    tx.insert(DefaultSnapshot(of: note))
}

// Semantic fetch
let notes = try await swiftDataStore.execute(
    DataStoreFetchRequest(semanticQuery: "concurrency", fetchLimit: 5)
)
```

## Backends

### MemoryBackend (Development/Testing)

Perfect for development and testing:

```swift
let backend = MemoryBackend<[Float]>()
```

### QdrantBackend (Production)

For production use with Qdrant vector database:

```swift
// Local Qdrant instance
let backend = QdrantBackend<[Float]>(
    endpoint: URL(string: "http://localhost:6333")!,
    collectionName: "my_collection",
    vectorDimensions: 1536
)

// Qdrant Cloud
let backend = QdrantBackend<[Float]>(
    endpoint: URL(string: "https://xyz.cloud.qdrant.io:6333")!,
    apiKey: "your-qdrant-api-key",
    collectionName: "my_collection",
    vectorDimensions: 1536
)
```

### Custom Backend

Implement the `VectorDBBackend` protocol:

```swift
public final class MyCustomBackend<Vector: VectorProtocol>: VectorDBBackend {
    public func upsert(_ payloads: [VectorPayload<Vector>]) async throws {
        // Your implementation
    }
    
    public func search(vector: Vector, topK: Int, threshold: Float?) async throws -> [[String: String]] {
        // Your implementation
    }
}
```

## Embedding Providers

### OpenAI

```swift
let embedder = OpenAIEmbedder(
    apiKey: "your-api-key",
    model: "text-embedding-3-small" // or "text-embedding-3-large"
)
```

### Custom Embedder

Implement the `EmbeddingModel` protocol:

```swift
actor MyEmbedder: EmbeddingModel {
    typealias Vector = [Float]
    
    func embed(texts: [String]) async throws -> [[Float]] {
        // Your embedding logic
    }
}
```

## Testing

Run tests using Swift Package Manager:

```bash
# Run all tests
swift test --enable-swift-testing

# Run with code coverage
swift test --enable-code-coverage

# Generate coverage report
swift test --enable-code-coverage && \
xcrun llvm-cov report .build/debug/VectorDataStorePackageTests.xctest/Contents/MacOS/VectorDataStorePackageTests \
  -instr-profile .build/debug/codecov/default.profdata
```

### Test Coverage

The library maintains **80%+ code coverage** across:
- Unit tests for all protocols and implementations
- Integration tests for end-to-end workflows
- Concurrency safety tests
- Performance benchmarks

See the [Testing Guide](Documentation/Testing.md) for more details.

## Architecture

```
VectorDataStore/
â”œâ”€â”€ Core/
â”‚   â”œâ”€â”€ EmbeddingModel.swift      # Embedding provider protocol
â”‚   â”œâ”€â”€ VectorProtocol.swift      # Vector operations
â”‚   â””â”€â”€ VectorDataStore.swift     # Main store actor
â”œâ”€â”€ Persistence/
â”‚   â”œâ”€â”€ PersistentModel.swift     # SwiftData-style model
â”‚   â””â”€â”€ SwiftDataStyleStore.swift # Transaction-based store
â”œâ”€â”€ Backends/
â”‚   â”œâ”€â”€ VectorDBBackend.swift     # Backend protocol
â”‚   â”œâ”€â”€ MemoryBackend.swift       # In-memory backend
â”‚   â””â”€â”€ QdrantBackend.swift       # Qdrant integration
â””â”€â”€ Configuration/
    â””â”€â”€ DataStoreConfiguration.swift
```

## Documentation

- [API Documentation](https://yourname.github.io/VectorDataStore/documentation/vectordatastore/)
- [Migration Guide](Documentation/Migration.md)
- [Testing Guide](Documentation/Testing.md)
- [Backend Implementation Guide](Documentation/CustomBackends.md)

## Examples

See the [Examples](Examples/) directory for:
- Basic usage
- Custom embedders
- Custom backends
- Migration scenarios
- SwiftUI integration

## Performance

VectorDataStore is optimized for performance:

- **Memory Backend**: <1ms search for 1K documents
- **Qdrant Backend**: <50ms search for 100K documents (local)
- **Concurrent Operations**: Full actor isolation for thread safety
- **Batch Operations**: Efficient bulk insert/update

See [Performance Benchmarks](Documentation/Performance.md) for detailed metrics.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

```bash
# Clone the repository
git clone https://github.com/YourUsername/VectorDataStore.git
cd VectorDataStore

# Install dependencies
swift build

# Run tests
swift test --enable-swift-testing

# Run linter
swiftlint
```

## Roadmap

- [x] Core vector store functionality
- [x] SwiftData-style APIs
- [x] MemoryBackend
- [x] QdrantBackend
- [x] OpenAI embeddings
- [ ] Local embedding models (CoreML)
- [ ] Pinecone backend
- [ ] Weaviate backend
- [ ] Advanced filtering (metadata queries)
- [ ] Compression/quantization support

## License

VectorDataStore is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- Inspired by Apple's SwiftData framework
- Built with Swift 6's modern concurrency features
- Integrates with Qdrant vector database
- Uses OpenAI embeddings API

## Support

- **Documentation**: [https://yourname.github.io/VectorDataStore](https://yourname.github.io/VectorDataStore)
- **Issues**: [GitHub Issues](https://github.com/YourUsername/VectorDataStore/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YourUsername/VectorDataStore/discussions)

---

Made with â¤ï¸ by [Your Name](https://github.com/YourName)


let cfg   = DataStoreConfiguration<[Float]>(storeName: "notes", schema: .init(vectorDimensions: 768))
let embed = OpenAIEmbedder()                // your type conforming to EmbeddingModel
let back  = MemoryBackend<[Float]>()        // swap for Pinecone/Weaviate implementation

let store = SwiftDataStyleStore<[Float], ResearchNote>(
    configuration: cfg,
    embedder: embed,
    backend: back
)

// 1. Insert via editing transaction
try await store.transaction { tx in
    let note = ResearchNote(id: UUID().uuidString, title: "Swift 6", content: "Strict concurrency is great")
    tx.insert(DefaultSnapshot(of: note))
}

// 2. Semantic fetch
let result = try await store.execute(
    DataStoreFetchRequest(semanticQuery: "concurrency safety", fetchLimit: 5)
)
print(result.snapshots.map(\.model.title))   // → ["Swift 6"]
mkdir -p ~/.config/mcp/wrapper
cd ~/.config/mcp/wrapper
python3 -m venv .venv
source .venv/bin/activate
pip install jinja2 requests
