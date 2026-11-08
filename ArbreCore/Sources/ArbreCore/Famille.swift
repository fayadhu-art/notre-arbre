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

    /// Profondeur de chaque ancêtre (la personne elle-même = 0).
    func profondeurs(_ id: UUID) -> [UUID: Int] {
        var p: [UUID: Int] = [id: 0]
        var file = [id]
        while !file.isEmpty {
            let x = file.removeFirst()
            for parent in parents(de: x) where p[parent.id] == nil {
                p[parent.id] = p[x]! + 1
                file.append(parent.id)
            }
        }
        return p
    }

    /// Parenté de sang de `cible` vue depuis `depuis` : « Papa », « Oncle », « Demi-sœur »… ou nil.
    func parenteDeSang(depuis: UUID, cible: UUID) -> String? {
        guard let x = personne(cible) else { return nil }
        let fem = x.sexe == .femme
        func g(_ m: String, _ f: String) -> String { fem ? f : m }
        let a = profondeurs(depuis), b = profondeurs(cible)
        var meilleur: (Int, Int)?
        for (k, da) in a {
            if let db = b[k], meilleur == nil || da + db < meilleur!.0 + meilleur!.1 { meilleur = (da, db) }
        }
        guard let (u, d) = meilleur else { return nil }
        switch (u, d) {
        case (0, 0): return "Moi"
        case (0, 1): return g("Fils", "Fille")
        case (0, 2): return g("Petit-fils", "Petite-fille")
        case (0, _): return g("Arrière-petit-fils", "Arrière-petite-fille")
        case (1, 0): return g("Papa", "Maman")
        case (2, 0):
            let base = g("Grand-père", "Grand-mère")
            if let p = pere(de: depuis), parents(de: p.id).contains(where: { $0.id == cible }) { return base + g(" paternel", " paternelle") }
            if let m = mere(de: depuis), parents(de: m.id).contains(where: { $0.id == cible }) { return base + g(" maternel", " maternelle") }
            return base
        case (3, 0): return g("Arrière-grand-père", "Arrière-grand-mère")
        case (_, 0): return "Ancêtre"
        case (1, 1):
            return estDemi(depuis, cible) ? g("Demi-frère", "Demi-sœur") : g("Frère", "Sœur")
        case (2, 1): return g("Oncle", "Tante")
        case (3, 1): return g("Grand-oncle", "Grand-tante")
        case (1, 2): return g("Neveu", "Nièce")
        case (1, 3): return g("Petit-neveu", "Petite-nièce")
        case (2, 2): return g("Cousin", "Cousine")
        default: return g("Cousin éloigné", "Cousine éloignée")
        }
    }

    /// Demi-frère ou demi-sœur : un seul parent en commun, ou un nom de famille différent.
    public func estDemi(_ a: UUID, _ b: UUID) -> Bool {
        let pa = Set(parents(de: a).map(\.id)), pb = Set(parents(de: b).map(\.id))
        if pa.intersection(pb).count == 1 && (pa.count == 2 || pb.count == 2) { return true }
        guard let x = personne(a), let y = personne(b) else { return false }
        let na = plier(x.nom), nb = plier(y.nom)
        return !na.isEmpty && !nb.isEmpty && na != nb
    }

    /// Lien direct de `cible` avec `sujet` : « Son père », « Sa fille », « Son épouse », « Sa demi-sœur »… ou nil.
    public func lienDirect(de cible: UUID, avec sujet: UUID) -> String? {
        guard let x = personne(cible) else { return nil }
        let f = x.sexe == .femme
        if cible == sujet { return "Personne choisie" }
        if parents(de: sujet).contains(where: { $0.id == cible }) { return f ? "Sa mère" : "Son père" }
        if conjoints(de: sujet).contains(where: { $0.id == cible }) { return f ? "Son épouse" : "Son mari" }
        if enfants(de: sujet).contains(where: { $0.id == cible }) { return f ? "Sa fille" : "Son fils" }
        if freresEtSoeurs(de: sujet).contains(where: { $0.id == cible }) {
            let demi = estDemi(sujet, cible)
            return f ? (demi ? "Sa demi-sœur" : "Sa sœur") : (demi ? "Son demi-frère" : "Son frère")
        }
        return nil
    }

    /// Vrai pour les personnes de la famille par le sang (ancêtres, descendants, frères, oncles, cousins…).
    /// Faux pour celles entrées par mariage : on ne remonte pas leur propre famille.
    public func estDeLaFamille(_ id: UUID) -> Bool {
        guard let moiID else { return true }
        return parenteDeSang(depuis: moiID, cible: id) != nil
    }

    /// Parenté avec l'utilisateur, affichée sous le nom : « Papa », « Grand-mère paternelle », « Oncle », « Belle-mère »…
    public func parente(de id: UUID) -> String {
        guard let moiID, let x = personne(id) else { return "" }
        let fem = x.sexe == .femme
        func g(_ m: String, _ f: String) -> String { fem ? f : m }
        if let s = parenteDeSang(depuis: moiID, cible: id) { return s }
        if conjoints(de: moiID).contains(where: { $0.id == id }) { return g("Mari", "Épouse") }
        // Conjoint d'un parent de sang.
        for c in conjoints(de: id) {
            guard let l = parenteDeSang(depuis: moiID, cible: c.id) else { continue }
            switch l {
            case "Papa", "Maman": return g("Beau-père", "Belle-mère")
            case "Frère", "Sœur", "Demi-frère", "Demi-sœur": return g("Beau-frère", "Belle-sœur")
            case "Fils", "Fille": return g("Gendre", "Belle-fille")
            case "Oncle", "Tante": return g("Oncle par alliance", "Tante par alliance")
            case _ where l.hasPrefix("Grand-père") || l.hasPrefix("Grand-mère"): return g("Grand-père par alliance", "Grand-mère par alliance")
            default: return "Par alliance"
            }
        }
        // Famille de mon conjoint.
        for e in conjoints(de: moiID) {
            guard let l = parenteDeSang(depuis: e.id, cible: id) else { continue }
            switch l {
            case "Papa", "Maman": return g("Beau-père", "Belle-mère")
            case "Frère", "Sœur", "Demi-frère", "Demi-sœur": return g("Beau-frère", "Belle-sœur")
            default: return "Belle-famille"
            }
        }
        return "Famille"
    }

    /// L'arbre d'une seule personne : ses ancêtres, ses frères et sœurs, ses conjoints, ses descendants
    /// et leurs conjoints. Les parentés sont recalculées depuis elle (elle devient « Moi »).
    public func sousFamille(autour id: UUID) -> Famille {
        let desc = descendants(de: id)
        var ids: Set<UUID> = [id]
        ids.formUnion(ancetres(de: id))
        ids.formUnion(desc)
        ids.formUnion(freresEtSoeurs(de: id).map(\.id))
        for x in desc.union([id]) { ids.formUnion(conjoints(de: x).map(\.id)) }
        return Famille(personnes: personnes.filter { ids.contains($0.id) },
                       liensParent: liensParent.filter { ids.contains($0.parent) && ids.contains($0.enfant) },
                       couples: couples.filter { ids.contains($0.a) && ids.contains($0.b) },
                       moiID: id)
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

    public mutating func retirerParent(_ parent: UUID, enfant: UUID) {
        liensParent.removeAll { $0.parent == parent && $0.enfant == enfant }
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
