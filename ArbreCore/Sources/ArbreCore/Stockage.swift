import Foundation

public struct Sauvegarde: Codable, Equatable, Sendable {
    public var version: Int
    public var famille: Famille
    public var enAttente: [Manque]
    public var traites: [Manque]

    public init(version: Int = 1, famille: Famille = Famille(), enAttente: [Manque] = [], traites: [Manque] = []) {
        self.version = version
        self.famille = famille
        self.enAttente = enAttente
        self.traites = traites
    }
}

public enum ErreurStockage: Error, LocalizedError, Equatable {
    case fichierIllisible
    case versionInconnue(Int)

    public var errorDescription: String? {
        switch self {
        case .fichierIllisible: "Ce fichier n'est pas une sauvegarde de Notre arbre, ou il est abîmé."
        case .versionInconnue(let v): "Cette sauvegarde vient d'une version plus récente de l'appli (version \(v))."
        }
    }
}

public final class Stockage {
    public let fichier: URL

    public init(dossier: URL) {
        fichier = dossier.appendingPathComponent("famille.json")
    }

    public func charger() throws -> Sauvegarde {
        guard FileManager.default.fileExists(atPath: fichier.path) else { return Sauvegarde() }
        return try Self.importer(Data(contentsOf: fichier))
    }

    public func enregistrer(_ s: Sauvegarde) throws {
        try Self.exporter(s).write(to: fichier, options: .atomic)
    }

    public static func exporter(_ s: Sauvegarde) throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(s)
    }

    private struct Entete: Decodable { let version: Int }

    public static func importer(_ data: Data) throws -> Sauvegarde {
        let d = JSONDecoder()
        guard let entete = try? d.decode(Entete.self, from: data) else { throw ErreurStockage.fichierIllisible }
        guard entete.version == 1 else { throw ErreurStockage.versionInconnue(entete.version) }
        guard let s = try? d.decode(Sauvegarde.self, from: data) else { throw ErreurStockage.fichierIllisible }
        return s
    }
}
