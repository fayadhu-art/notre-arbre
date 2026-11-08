import Foundation

public enum ArbreCore {
    public static let version = "1.0"
}

public enum Precision: String, Codable, Sendable {
    case exacte, annee, vers, avant, apres, inconnue
}

/// Une date qui accepte ce qu'on sait : date complète, année seule, « vers », « avant », « après » ou rien.
public struct DateFloue: Codable, Hashable, Sendable {
    public var jour: Int?
    public var mois: Int?
    public var annee: Int?
    public var precision: Precision

    public init(jour: Int? = nil, mois: Int? = nil, annee: Int? = nil, precision: Precision) {
        self.jour = jour
        self.mois = mois
        self.annee = annee
        self.precision = precision
    }

    public static let inconnue = DateFloue(precision: .inconnue)

    static let moisNoms = ["janvier", "février", "mars", "avril", "mai", "juin",
                           "juillet", "août", "septembre", "octobre", "novembre", "décembre"]

    public var anneeEstimee: Int? { precision == .inconnue ? nil : annee }

    public var libelle: String {
        guard let a = annee, precision != .inconnue else { return "date inconnue" }
        switch precision {
        case .exacte:
            var s = ""
            if let m = mois, (1...12).contains(m) {
                if let j = jour { s = (j == 1 ? "1er" : "\(j)") + " " }
                s += Self.moisNoms[m - 1] + " "
            }
            return s + "\(a)"
        case .annee: return "\(a)"
        case .vers: return "vers \(a)"
        case .avant: return "avant \(a)"
        case .apres: return "après \(a)"
        case .inconnue: return "date inconnue"
        }
    }

    /// Comprend une réponse en français : « En 1958, je crois », « le 12 mars 1985 », « les années 50 »…
    public static func depuis(texte: String) -> DateFloue {
        let t = plier(texte)
        if let m = t.firstMatch(of: /annees\s+(\d{2})\b/), let d = Int(m.1) {
            return DateFloue(annee: 1900 + d + 5, precision: .vers)
        }
        let annees = t.matches(of: /\b(1[6-9]\d{2}|20\d{2})\b/).compactMap { Int($0.1) }
        guard let a = annees.first else { return .inconnue }
        if t.contains("avant") { return DateFloue(annee: a, precision: .avant) }
        if t.contains("apres") { return DateFloue(annee: a, precision: .apres) }
        let indices = ["vers", "environ", "je crois", "a peu pres", "peut-etre", "peut etre", "je pense", "je dirais", "ou "]
        let vague = annees.count > 1 || indices.contains { t.contains($0) }
        let moisPlies = moisNoms.map { plier($0) }
        if let m = t.firstMatch(of: /\b(\d{1,2})(?:er)?\s+([a-z]+)\s+(\d{4})\b/),
           let j = Int(m.1), (1...31).contains(j),
           let idx = moisPlies.firstIndex(of: String(m.2)),
           let an = Int(m.3) {
            return DateFloue(jour: j, mois: idx + 1, annee: an, precision: vague ? .vers : .exacte)
        }
        return DateFloue(annee: a, precision: vague ? .vers : .annee)
    }
}

/// Minuscules, sans accents, sans espaces autour.
func plier(_ s: String) -> String {
    s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
        .lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
