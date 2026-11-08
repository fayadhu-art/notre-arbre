import Foundation

public struct NomLu: Sendable, Equatable {
    public var prenom: String
    public var nom: String
    public init(prenom: String, nom: String) { self.prenom = prenom; self.nom = nom }
}

/// Transforme le texte lu sur une capture d'écran (un message WhatsApp, une liste) en prénoms et noms.
/// Une ligne = une personne. Les heures, numéros, puces et phrases trop longues sont ignorés.
/// Le nom de famille est le mot écrit en majuscules ; sinon le dernier mot s'il y en a plusieurs ; sinon `nomParDefaut`.
public func nomsDepuisTexte(_ texte: String, nomParDefaut: String) -> [NomLu] {
    var resultat: [NomLu] = []
    for brute in texte.components(separatedBy: .newlines) {
        var ligne = brute.trimmingCharacters(in: .whitespaces)
        // Puces et numéros en début de ligne : « 1. », « 2) », « - », « • ».
        if let r = ligne.range(of: #"^\s*(\d+\s*[\.\)\-:]|[-•*–])\s*"#, options: .regularExpression) { ligne.removeSubrange(r) }
        // Heures et dates (« 21:45 », « 08/11/2026 ») : ligne d'interface, on l'ignore.
        if ligne.range(of: #"\d{1,2}[:h]\d{2}|\d{1,2}/\d{1,2}"#, options: .regularExpression) != nil { continue }
        let mots = ligne.split(whereSeparator: { $0 == " " || $0 == "," })
            .map { $0.trimmingCharacters(in: CharacterSet.letters.union(CharacterSet(charactersIn: "-'")).inverted) }
            .filter { !$0.isEmpty }
        guard (1...5).contains(mots.count), mots.allSatisfy({ $0.first?.isLetter == true }) else { continue }
        let ignores: Set<String> = ["bonjour", "salut", "merci", "voici", "mes", "enfants", "les", "et", "aujourd'hui", "hier", "message", "vu"]
        if mots.count <= 2, mots.allSatisfy({ ignores.contains($0.lowercased()) }) { continue }
        if mots.contains(where: { ignores.contains($0.lowercased()) }) && mots.count > 2 { continue }
        let majuscules = mots.filter { $0.count > 1 && $0 == $0.uppercased() && $0 != $0.lowercased() }
        var prenom: [String], nom: String
        if let m = majuscules.last, majuscules.count < mots.count {
            nom = majuscules.joined(separator: " ")
            prenom = mots.filter { !majuscules.contains($0) }
            _ = m
        } else if mots.count >= 2 {
            nom = mots.last!
            prenom = Array(mots.dropLast())
        } else {
            nom = nomParDefaut
            prenom = mots
        }
        let p = prenom.joined(separator: " ")
        resultat.append(NomLu(prenom: p.prefix(1).uppercased() + p.dropFirst(), nom: nom))
    }
    return resultat
}
