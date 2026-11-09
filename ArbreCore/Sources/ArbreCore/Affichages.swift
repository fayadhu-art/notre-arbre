import Foundation

// MARK: Numérotation Sosa (pour la roue des ancêtres)

/// Numéros Sosa : 1 = moi, 2 = mon père, 3 = ma mère, 2n = père de n, 2n+1 = mère de n.
public func numerosSosa(_ f: Famille, generations: Int = 5) -> [Int: UUID] {
    guard let moi = f.moiID else { return [:] }
    var r: [Int: UUID] = [1: moi]
    var file = [1]
    while !file.isEmpty {
        let n = file.removeFirst()
        guard let id = r[n], n < (1 << (generations - 1)) else { continue }
        if let p = f.pere(de: id) { r[2 * n] = p.id; file.append(2 * n) }
        if let m = f.mere(de: id) { r[2 * n + 1] = m.id; file.append(2 * n + 1) }
    }
    return r
}

// MARK: Personnes rangées par génération

public struct Generation: Sendable, Identifiable {
    public let id: Int
    public let titre: String
    public let personnes: [Personne]
}

public func parGeneration(_ f: Famille) -> [Generation] {
    let gens = f.generations()
    var groupes: [Int: [Personne]] = [:]
    var autres: [Personne] = []
    for p in f.personnes {
        if let g = gens[p.id] { groupes[g, default: []].append(p) } else { autres.append(p) }
    }
    func titre(_ g: Int) -> String {
        switch g {
        case ..<(-3): return "Ancêtres"
        case -3: return "Arrière-grands-parents"
        case -2: return "Grands-parents et grands-oncles"
        case -1: return "Parents, oncles et tantes"
        case 0: return "Ma génération"
        case 1: return "Enfants, neveux et nièces"
        case 2: return "Petits-enfants"
        default: return "Arrière-petits-enfants"
        }
    }
    var r = groupes.keys.sorted().map { g in
        Generation(id: g, titre: titre(g), personnes: groupes[g]!.sorted { a, b in
            // Côté père d'abord, puis côté mère, puis les autres ; ensuite par prénom.
            let ordre: (Branche) -> Int = { $0 == .moi ? 0 : ($0 == .pere ? 1 : ($0 == .mere ? 2 : 3)) }
            let (oa, ob) = (ordre(f.branche(de: a.id)), ordre(f.branche(de: b.id)))
            return oa != ob ? oa < ob : a.prenom.localizedCompare(b.prenom) == .orderedAscending
        })
    }
    if !autres.isEmpty { r.append(Generation(id: 99, titre: "Autres", personnes: autres)) }
    return r
}

// MARK: Familles une par une (un couple ou un parent seul, avec ses enfants)

public struct FamilleCarte: Sendable, Identifiable {
    public var id: String { parents.map(\.uuidString).joined(separator: "|") }
    public let parents: [UUID]
    public let enfants: [UUID]
    public let generation: Int
}

public func famillesUneParUne(_ f: Famille) -> [FamilleCarte] {
    let gens = f.generations()
    var cartes: [String: (parents: [UUID], enfants: [UUID])] = [:]
    var ordre: [String] = []
    for p in f.personnes {
        var ps = f.parents(de: p.id).map(\.id)
        guard !ps.isEmpty else { continue }
        if ps.count == 1 {
            let c = f.conjoints(de: ps[0])
            if c.count == 1 { ps.append(c[0].id) }
        }
        ps.sort { (f.personne($0)?.sexe == .femme ? 0 : 1) < (f.personne($1)?.sexe == .femme ? 0 : 1) }
        let k = ps.map(\.uuidString).sorted().joined(separator: "|")
        if cartes[k] == nil { cartes[k] = (ps, []); ordre.append(k) }
        cartes[k]!.enfants.append(p.id)
    }
    // Couples sans enfant enregistré : une carte aussi.
    for c in f.couples {
        let k = [c.a.uuidString, c.b.uuidString].sorted().joined(separator: "|")
        if cartes[k] == nil {
            let ps = [c.a, c.b].sorted { (f.personne($0)?.sexe == .femme ? 0 : 1) < (f.personne($1)?.sexe == .femme ? 0 : 1) }
            cartes[k] = (ps, []); ordre.append(k)
        }
    }
    return ordre.map { k in
        let c = cartes[k]!
        return FamilleCarte(parents: c.parents, enfants: c.enfants, generation: c.parents.compactMap { gens[$0] }.min() ?? 0)
    }
    .enumerated().sorted { ($0.element.generation, $0.offset) < ($1.element.generation, $1.offset) }.map(\.element)
}
