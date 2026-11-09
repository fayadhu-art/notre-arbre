import Foundation

/// Une ligne de l'arbre « en escalier » : chaque personne sur sa ligne, ses enfants en dessous, décalés.
public struct LigneEscalier: Sendable, Identifiable, Equatable {
    public enum Genre: Sendable, Equatable {
        /// Une personne, avec son conjoint s'il n'en a qu'un.
        case personne(UUID, conjoint: UUID?)
        /// Une union d'une personne mariée plusieurs fois (« ♥ Antoissi »), ses enfants en dessous.
        case union(UUID)
        /// Personne déjà affichée plus haut (par exemple Maman dans le côté de ses parents).
        case renvoi(UUID)
        /// Titre d'un côté de la famille.
        case titre(String)
    }
    public let id: Int
    public let genre: Genre
    /// Profondeur : 0 = racine, 1 = ses enfants, etc.
    public let profondeur: Int
    /// Dernier enfant de sa fratrie (« └─ ») ou non (« ├─ »).
    public let dernier: Bool
    /// Pour chaque colonne avant la sienne : le trait vertical continue-t-il ?
    public let guides: [Bool]
    /// Numéro de la famille dont la ligne est un enfant (couleur du trait).
    public let groupe: Int
}

public func escalier(_ f: Famille) -> [LigneEscalier] {
    var lignes: [LigneEscalier] = []
    var vus = Set<UUID>()
    var familles: [String: Int] = [:]
    func groupe(_ a: UUID, _ b: UUID?) -> Int {
        let k = [a.uuidString, b?.uuidString ?? ""].sorted().joined(separator: "|")
        if let g = familles[k] { return g }
        familles[k] = familles.count
        return familles[k]!
    }
    func ajouter(_ g: LigneEscalier.Genre, _ prof: Int, _ dernier: Bool, _ guides: [Bool], _ gr: Int) {
        lignes.append(LigneEscalier(id: lignes.count, genre: g, profondeur: prof, dernier: dernier, guides: guides, groupe: gr))
    }

    /// Affiche une liste d'enfants sous un parent (ou une union).
    func enfants(_ liste: [Personne], prof: Int, guides: [Bool], gr: Int) {
        for (i, e) in liste.enumerated() { bloc(e.id, prof: prof, dernier: i == liste.count - 1, guides: guides, gr: gr) }
    }

    func bloc(_ p: UUID, prof: Int, dernier: Bool, guides: [Bool], gr: Int) {
        guard !vus.contains(p) else { ajouter(.renvoi(p), prof, dernier, guides, gr); return }
        vus.insert(p)
        let conj = f.conjoints(de: p)
        let mesEnfants = f.enfants(de: p)
        let sousGuides = prof == 0 ? [] : guides + [!dernier]
        if conj.count <= 1 {
            let c = conj.first?.id
            if let c { vus.insert(c) }
            ajouter(.personne(p, conjoint: c), prof, dernier, guides, gr)
            enfants(mesEnfants, prof: prof + 1, guides: sousGuides, gr: groupe(p, c))
        } else {
            ajouter(.personne(p, conjoint: nil), prof, dernier, guides, gr)
            let sansAutreParent = mesEnfants.filter { e in !f.parents(de: e.id).contains { x in conj.contains { $0.id == x.id } } }
            let unions = conj
            for (i, c) in unions.enumerated() {
                vus.insert(c.id)
                let derniere = i == unions.count - 1 && sansAutreParent.isEmpty
                let g = groupe(p, c.id)
                ajouter(.union(c.id), prof + 1, derniere, sousGuides, g)
                let communs = mesEnfants.filter { e in f.parents(de: e.id).contains { $0.id == c.id } }
                enfants(communs, prof: prof + 2, guides: sousGuides + [!derniere], gr: g)
            }
            enfants(sansAutreParent, prof: prof + 1, guides: sousGuides, gr: groupe(p, nil))
        }
    }

    /// Ancêtre le plus haut en remontant par les pères (sinon le premier parent).
    func sommet(_ depart: UUID) -> UUID {
        var x = depart
        var deja = Set<UUID>()
        while deja.insert(x).inserted, let p = f.pere(de: x) ?? f.parents(de: x).first { x = p.id }
        return x
    }

    if let moi = f.moiID {
        if let pere = f.pere(de: moi) {
            ajouter(.titre("Côté père"), 0, true, [], -1)
            bloc(sommet(pere.id), prof: 0, dernier: true, guides: [], gr: -1)
        }
        if let mere = f.mere(de: moi), !vus.contains(sommet(mere.id)) || f.parents(de: mere.id).count > 0 {
            ajouter(.titre("Côté mère"), 0, true, [], -1)
            bloc(sommet(mere.id), prof: 0, dernier: true, guides: [], gr: -1)
        }
        if !vus.contains(moi) { bloc(moi, prof: 0, dernier: true, guides: [], gr: -1) }
    }
    // Branches qui ne sont pas encore affichées (parents d'une personne entrée par mariage, etc.).
    var titreAutres = false
    for p in f.personnes where !vus.contains(p.id) && f.parents(de: p.id).isEmpty {
        if !titreAutres { ajouter(.titre("Autres branches"), 0, true, [], -1); titreAutres = true }
        bloc(p.id, prof: 0, dernier: true, guides: [], gr: -1)
    }
    for p in f.personnes where !vus.contains(p.id) {
        if !titreAutres { ajouter(.titre("Autres branches"), 0, true, [], -1); titreAutres = true }
        bloc(p.id, prof: 0, dernier: true, guides: [], gr: -1)
    }
    return lignes
}
