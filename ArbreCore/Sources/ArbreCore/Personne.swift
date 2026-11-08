import Foundation

public enum Sexe: String, Codable, Sendable { case homme, femme, inconnu }
public enum Origine: String, Codable, Sendable { case entretien, document, saisie }

public struct Personne: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var prenom: String
    public var nom: String
    public var sexe: Sexe
    public var naissance: DateFloue
    public var lieuNaissance: String?
    public var deces: DateFloue?
    public var notes: String
    public var origine: Origine
    public var ajouteeLe: Date

    public init(id: UUID = UUID(), prenom: String, nom: String = "", sexe: Sexe = .inconnu,
                naissance: DateFloue = .inconnue, lieuNaissance: String? = nil, deces: DateFloue? = nil,
                notes: String = "", origine: Origine = .entretien, ajouteeLe: Date = Date()) {
        self.id = id
        self.prenom = prenom
        self.nom = nom
        self.sexe = sexe
        self.naissance = naissance
        self.lieuNaissance = lieuNaissance
        self.deces = deces
        self.notes = notes
        self.origine = origine
        self.ajouteeLe = ajouteeLe
    }

    public var nomComplet: String { nom.isEmpty ? prenom : "\(prenom) \(nom)" }

    public var initiales: String {
        let lettres = prenom.filter { $0.isLetter }
        return String(lettres.prefix(2)).uppercased()
    }

    /// « né », « née » ou « né(e) ».
    public var neAccorde: String {
        switch sexe {
        case .homme: "né"
        case .femme: "née"
        case .inconnu: "né(e)"
        }
    }
}
