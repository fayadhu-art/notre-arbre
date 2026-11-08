import Foundation

public enum Sujet: String, Codable, Sendable {
    case parents, grandsParents, freresSoeurs, enfants, dateNaissance, lieuNaissance
}

/// Une information qui manque dans l'arbre. `personne` = la personne concernée
/// (pour `grandsParents` : le parent dont on cherche les parents).
public struct Manque: Codable, Hashable, Sendable {
    public let personne: UUID?
    public let sujet: Sujet
    public init(personne: UUID?, sujet: Sujet) { self.personne = personne; self.sujet = sujet }
}

/// Liste ordonnée de ce qui manque. Les questions mises en attente passent en dernier ;
/// celles déjà traitées (« aucun », « personne ») disparaissent.
public func manques(_ f: Famille, enAttente: Set<Manque>, traites: Set<Manque> = []) -> [Manque] {
    guard let moi = f.moiID else { return [] }
    var liste: [Manque] = []
    if f.parents(de: moi).count < 2 { liste.append(Manque(personne: moi, sujet: .parents)) }
    for p in f.parents(de: moi) where f.parents(de: p.id).count < 2 {
        liste.append(Manque(personne: p.id, sujet: .grandsParents))
    }
    if f.freresEtSoeurs(de: moi).isEmpty { liste.append(Manque(personne: moi, sujet: .freresSoeurs)) }
    if f.enfants(de: moi).isEmpty { liste.append(Manque(personne: moi, sujet: .enfants)) }
    for p in f.personnes where p.naissance.precision == .inconnue {
        liste.append(Manque(personne: p.id, sujet: .dateNaissance))
    }
    for p in f.personnes where (p.lieuNaissance ?? "").isEmpty {
        liste.append(Manque(personne: p.id, sujet: .lieuNaissance))
    }
    liste.removeAll { traites.contains($0) }
    return liste.filter { !enAttente.contains($0) } + liste.filter { enAttente.contains($0) }
}

/// La question en français. `tutoiement` : on parle à l'utilisateur (« tes parents ») ;
/// sinon on parle de lui à la troisième personne (message à un proche).
public func texte(_ m: Manque, famille f: Famille, tutoiement: Bool = true) -> String {
    let p = m.personne.flatMap { f.personne($0) }
    let estMoi = m.personne != nil && m.personne == f.moiID
    let nom = p?.prenom ?? "cette personne"
    switch m.sujet {
    case .parents:
        return estMoi && tutoiement ? "Comment s'appellent tes parents ?" : "Qui sont les parents de \(nom) ?"
    case .grandsParents:
        return "Qui sont les parents de \(nom) ?"
    case .freresSoeurs:
        return estMoi && tutoiement ? "As-tu des frères et sœurs ?" : "Qui sont les frères et sœurs de \(nom) ?"
    case .enfants:
        return estMoi && tutoiement ? "As-tu des enfants ?" : "Qui sont les enfants de \(nom) ?"
    case .dateNaissance:
        if estMoi && tutoiement { return "En quelle année es-tu né ?" }
        return "En quelle année est \(p?.neAccorde ?? "né(e)") \(nom) ?"
    case .lieuNaissance:
        if estMoi && tutoiement { return "Dans quel village es-tu né ?" }
        return "Dans quel village est \(p?.neAccorde ?? "né(e)") \(nom) ?"
    }
}

/// Message prêt à envoyer sur WhatsApp à un proche.
public func messageQuestions(pour personne: Personne?, manques liste: [Manque], famille: Famille) -> String {
    let choisies = personne.map { p in liste.filter { $0.personne == p.id } } ?? liste
    let questions = choisies.prefix(8).enumerated()
        .map { "\($0.offset + 1). \(texte($0.element, famille: famille, tutoiement: false))" }
        .joined(separator: "\n")
    return "Bonjour ! Je construis l'arbre de la famille. Peux-tu m'aider à répondre à ces questions ?\n\n\(questions)\n\nMême une année approximative m'aide. Merci !"
}
