// Sample Swift: protocols, enums with associated values, generics, async/await.
import Foundation

let version = "1.4.2"
private let maxRetries = 3
private let slugPattern = #"[^a-z0-9]+"#

enum Role: String, CaseIterable, Codable {
    case admin, editor, viewer

    var label: String {
        switch self {
        case .admin: return "Full access"
        case .editor: return "Write access"
        case .viewer: return "Read access"
        }
    }

    var isPrivileged: Bool { self == .admin }
}

struct User: Codable, Identifiable, Hashable {
    let id: Int64
    var name: String
    var email: String?
    var roles: Set<Role> = []

    var slug: String {
        name.lowercased()
            .replacingOccurrences(of: slugPattern, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    func hasRole(_ wanted: Role...) -> Bool {
        wanted.contains { roles.contains($0) }
    }
}

enum RepositoryError: Error, LocalizedError {
    case notFound(id: Int64)
    case invalidName(String)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notFound(let id): return "user \(id) not found"
        case .invalidName(let name): return "invalid name: \(name.debugDescription)"
        case .underlying(let error): return error.localizedDescription
        }
    }
}

protocol Repository {
    associatedtype Item: Identifiable

    func save(_ item: Item) async throws -> Item
    func get(_ id: Item.ID) async throws -> Item
}

actor UserRepository: Repository {
    typealias Item = User

    private var items: [Int64: User] = [:]
    private let namespace: String

    init(namespace: String = "users") {
        self.namespace = namespace
    }

    var count: Int { items.count }

    func save(_ item: User) async throws -> User {
        guard !item.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw RepositoryError.invalidName(item.name)
        }

        for attempt in 1...maxRetries {
            do {
                items[item.id] = item
                return item
            } catch {
                print("attempt \(attempt)/\(maxRetries) failed: \(error)")
                try await Task.sleep(nanoseconds: UInt64(attempt) * 250_000_000)
            }
        }
        throw RepositoryError.underlying(RepositoryError.notFound(id: item.id))
    }

    func get(_ id: Int64) async throws -> User {
        guard let user = items[id] else { throw RepositoryError.notFound(id: id) }
        return user
    }
}

extension Sequence where Element == User {
    func summarize() -> String {
        let admins = filter { $0.hasRole(.admin) }.count
        return "\(admins)/\(underestimatedCount) admins (v\(version))"
    }
}

@main
struct App {
    static func main() async {
        let repo = UserRepository()
        let seed: [User] = [
            User(id: 1, name: "Ada Lovelace", email: "ada@example.com", roles: [.admin]),
            User(id: 2, name: "Grace Hopper", roles: [.editor, .viewer]),
        ]

        await withTaskGroup(of: Void.self) { group in
            for user in seed {
                group.addTask {
                    do {
                        let saved = try await repo.save(user)
                        print("saved \(saved.slug) — \(saved.roles.map(\.label).joined(separator: ", "))")
                    } catch let error as RepositoryError {
                        print("error: \(error.localizedDescription)")
                    } catch {
                        print("unexpected: \(error)")
                    }
                }
            }
        }

        let count = await repo.count
        print("""
        \(seed.summarize())
        stored: \(count)
        numbers: \(0b1010) \(0o17) \(0xFF) \(1_000_000) \(3.14e-2)
        """)
    }
}
