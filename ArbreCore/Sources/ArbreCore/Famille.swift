import Foundation

public struct LienParent: Codable, Hashable, Sendable {
    public var parent: UUID
    public var enfant: UUID
    public init(parent: UUID, enfant: UUID) { self.parent = parent; self.enfant = enfant }
}

public struct Couple: Codable, Hashable, Sendable {
    public var a: UUID
    public var b: UUID
    public init(a: UUID, b: UUID) { self.a = a; self.b = b }
}

public enum Branche: Sendable { case moi, pere, mere, autre }

public struct Famille: Codable, Equatable, Sendable {
    public var personnes: [Personne]
    public var liensParent: [LienParent]
    public var couples: [Couple]
    public var moiID: UUID?

    public init(personnes: [Personne] = [], liensParent: [LienParent] = [], couples: [Couple] = [], moiID: UUID? = nil) {
        self.personnes = personnes
        self.liensParent = liensParent
        self.couples = couples
        self.moiID = moiID
    }

    // MARK: Lecture

    public func personne(_ id: UUID) -> Personne? { personnes.first { $0.id == id } }
    public var moi: Personne? { moiID.flatMap { personne($0) } }

    public func parents(de id: UUID) -> [Personne] {
        liensParent.filter { $0.enfant == id }.compactMap { personne($0.parent) }
    }

    public func enfants(de id: UUID) -> [Personne] {
        liensParent.filter { $0.parent == id }.compactMap { personne($0.enfant) }
    }

    public func conjoints(de id: UUID) -> [Personne] {
        couples.compactMap { c in
            c.a == id ? personne(c.b) : (c.b == id ? personne(c.a) : nil)
        }
    }

    public func freresEtSoeurs(de id: UUID) -> [Personne] {
        let mesParents = Set(parents(de: id).map(\.id))
        guard !mesParents.isEmpty else { return [] }
        return personnes.filter { p in
            p.id != id && !mesParents.isDisjoint(with: parents(de: p.id).map(\.id))
        }
    }

    public func pere(de id: UUID) -> Personne? {
        let ps = parents(de: id)
        return ps.first { $0.sexe == .homme } ?? ps.first { $0.sexe == .inconnu }
    }

    public func mere(de id: UUID) -> Personne? {
        let ps = parents(de: id)
        let p = pere(de: id)
        return ps.first { $0.sexe == .femme } ?? ps.first { $0.id != p?.id }
    }

    func ancetres(de id: UUID) -> Set<UUID> {
        var vus = Set<UUID>()
        var pile = parents(de: id).map(\.id)
        while let x = pile.popLast() {
            if vus.insert(x).inserted { pile += parents(de: x).map(\.id) }
        }
        return vus
    }

    func descendants(de id: UUID) -> Set<UUID> {
        var vus = Set<UUID>()
        var pile = enfants(de: id).map(\.id)
        while let x = pile.popLast() {
            if vus.insert(x).inserted { pile += enfants(de: x).map(\.id) }
        }
        return vus
    }

    /// Côté d'une racine (père ou mère) : elle, ses ancêtres et leurs descendants, sauf sa propre descendance.
    func cote(_ racine: UUID) -> Set<UUID> {
        let anc = ancetres(de: racine)
        var s = anc.union([racine])
        for a in anc { s.formUnion(descendants(de: a)) }
        s.subtract(descendants(de: racine))
        return s
    }

    public func branche(de id: UUID) -> Branche {
        guard let moiID else { return .autre }
        if id == moiID { return .moi }
        if let p = pere(de: moiID), cote(p.id).contains(id) { return .pere }
        if let m = mere(de: moiID), cote(m.id).contains(id) { return .mere }
        return .autre
    }

    /// Génération de chaque personne reliée à moi : moi = 0, parents = -1, enfants = +1.
    public func generations() -> [UUID: Int] {
        guard let moiID else { return [:] }
        var gen: [UUID: Int] = [moiID: 0]
        var file = [moiID]
        while !file.isEmpty {
            let x = file.removeFirst()
            let g = gen[x]!
            let voisins = parents(de: x).map { ($0.id, g - 1) }
                + enfants(de: x).map { ($0.id, g + 1) }
                + conjoints(de: x).map { ($0.id, g) }
            for (v, gv) in voisins where gen[v] == nil {
                gen[v] = gv
                file.append(v)
            }
        }
        return gen
    }

    public func generation(de id: UUID) -> Int { generations()[id] ?? 0 }

    public var nombreGenerations: Int {
        let g = generations().values
        guard let mn = g.min(), let mx = g.max() else { return personnes.isEmpty ? 0 : 1 }
        return mx - mn + 1
    }

    public func trouver(prenom: String, nom: String? = nil) -> Personne? {
        let p = plier(prenom)
        guard !p.isEmpty else { return nil }
        let n = nom.map(plier) ?? ""
        return personnes.first { x in
            plier(x.prenom) == p && (n.isEmpty || x.nom.isEmpty || plier(x.nom) == n)
        }
    }

    /// Lien avec l'utilisateur, en français : « ton père », « ta grand-mère paternelle »…
    public func lienAvecMoi(_ id: UUID) -> String {
        guard let moiID, let x = personne(id) else { return "" }
        let f = x.sexe == .femme
        if id == moiID { return "toi" }
        let mesParents = parents(de: moiID).map(\.id)
        if mesParents.contains(id) { return f ? "ta mère" : "ton père" }
        if conjoints(de: moiID).contains(where: { $0.id == id }) { return f ? "ton épouse" : "ton époux" }
        if enfants(de: moiID).contains(where: { $0.id == id }) { return f ? "ta fille" : "ton fils" }
        if freresEtSoeurs(de: moiID).contains(where: { $0.id == id }) { return f ? "ta sœur" : "ton frère" }
        if let p = pere(de: moiID), parents(de: p.id).contains(where: { $0.id == id }) {
            return f ? "ta grand-mère paternelle" : "ton grand-père paternel"
        }
        if let m = mere(de: moiID), parents(de: m.id).contains(where: { $0.id == id }) {
            return f ? "ta grand-mère maternelle" : "ton grand-père maternel"
        }
        if mesParents.contains(where: { p in freresEtSoeurs(de: p).contains { $0.id == id } }) {
            return f ? "ta tante" : "ton oncle"
        }
        if enfants(de: moiID).contains(where: { e in enfants(de: e.id).contains { $0.id == id } }) {
            return f ? "ta petite-fille" : "ton petit-fils"
        }
        return "de la famille"
    }

    // MARK: Écriture

    public mutating func ajouter(_ p: Personne) {
        if let i = personnes.firstIndex(where: { $0.id == p.id }) { personnes[i] = p } else { personnes.append(p) }
    }

    public mutating func lierParent(_ parent: UUID, enfant: UUID) {
        guard parent != enfant,
              !liensParent.contains(LienParent(parent: parent, enfant: enfant)),
              parents(de: enfant).count < 2 else { return }
        liensParent.append(LienParent(parent: parent, enfant: enfant))
    }

    public mutating func lierCouple(_ a: UUID, _ b: UUID) {
        guard a != b, !couples.contains(where: { ($0.a == a && $0.b == b) || ($0.a == b && $0.b == a) }) else { return }
        couples.append(Couple(a: a, b: b))
    }

    public mutating func supprimer(_ id: UUID) {
        personnes.removeAll { $0.id == id }
        liensParent.removeAll { $0.parent == id || $0.enfant == id }
        couples.removeAll { $0.a == id || $0.b == id }
    }
}
