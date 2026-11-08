import Foundation

/// Un cercle de l'arbre. `x`, `y` = centre du cercle. `id == nil` : personne « à trouver ».
public struct Noeud: Sendable {
    public let cle: String
    public let id: UUID?
    public let x: Double
    public let y: Double
    public let aCompleter: Bool
    public let libelle: String
    /// Pour une personne à trouver : l'enfant dont elle est le parent, et son rôle (père ou mère).
    public let pour: UUID?
    public let role: Sexe?
}

public struct Trait: Sendable {
    public let de: (Double, Double)
    public let a: (Double, Double)
    public let pointille: Bool
}

private struct Element {
    let cle: String
    let id: UUID?
    let gen: Int
    let pour: UUID?
    let role: Sexe?
}

public func disposer(_ f: Famille, largeurNoeud: Double = 84, ecartGeneration: Double = 130)
    -> (noeuds: [Noeud], traits: [Trait], taille: (Double, Double)) {
    let espaceCouple = largeurNoeud + 6
    let espaceUnites = largeurNoeud + 20

    // 1. Éléments : personnes et parents à trouver.
    var gens = f.generations()
    for p in f.personnes where gens[p.id] == nil { gens[p.id] = 0 }
    var elements: [String: Element] = [:]
    var ordre: [String] = []
    var parentsDe: [String: [String]] = [:]
    func ajouter(_ e: Element) { elements[e.cle] = e; ordre.append(e.cle) }
    for p in f.personnes { ajouter(Element(cle: p.id.uuidString, id: p.id, gen: gens[p.id]!, pour: nil, role: nil)) }

    let ligneDirecte: Set<UUID> = {
        guard let moi = f.moiID else { return [] }
        return f.ancetres(de: moi).union([moi])
    }()
    for p in f.personnes {
        let reels = f.parents(de: p.id)
        var cles = reels.map { $0.id.uuidString }
        let g = gens[p.id]!
        if ligneDirecte.contains(p.id), g >= -1, reels.count < 2 {
            var roles: [Sexe] = []
            if f.pere(de: p.id) == nil { roles.append(.homme) }
            if f.mere(de: p.id) == nil || reels.isEmpty { roles.append(.femme) }
            for (i, r) in roles.prefix(2 - reels.count).enumerated() {
                let e = Element(cle: "ph-\(p.id.uuidString)-\(i)", id: nil, gen: g - 1, pour: p.id, role: r)
                ajouter(e)
                cles.append(e.cle)
            }
        }
        if !cles.isEmpty { parentsDe[p.id.uuidString] = cles }
    }
    var enfantsDe: [String: [String]] = [:]
    for (enfant, ps) in parentsDe { for p in ps { enfantsDe[p, default: []].append(enfant) } }
    let rangInitial = Dictionary(uniqueKeysWithValues: ordre.enumerated().map { ($1, $0) })
    for k in enfantsDe.keys { enfantsDe[k]!.sort { rangInitial[$0]! < rangInitial[$1]! } }

    func estHomme(_ c: String) -> Bool {
        let e = elements[c]!
        if let r = e.role { return r == .homme }
        return f.personne(e.id!)?.sexe == .homme
    }

    // 2. Couples : conjoints déclarés et paires de parents d'un même enfant. Un homme peut avoir plusieurs épouses.
    var conjointsDe: [String: [String]] = [:]
    func lier(_ a: String, _ b: String) {
        guard a != b, let ea = elements[a], let eb = elements[b], ea.gen == eb.gen,
              !(conjointsDe[a]?.contains(b) ?? false) else { return }
        conjointsDe[a, default: []].append(b)
        conjointsDe[b, default: []].append(a)
    }
    for c in f.couples { lier(c.a.uuidString, c.b.uuidString) }
    for cle in ordre { if let ps = parentsDe[cle], ps.count == 2 { lier(ps[0], ps[1]) } }
    let rang = Dictionary(uniqueKeysWithValues: ordre.enumerated().map { ($1, $0) })

    // Un couple : homme à gauche. Plusieurs épouses : 1re épouse, mari, 2e épouse, 3e épouse…
    func arranger(_ groupe: [String]) -> [String] {
        if groupe.count == 1 { return groupe }
        if groupe.count == 2 {
            let (a, b) = (groupe[0], groupe[1])
            return estHomme(b) && !estHomme(a) ? [b, a] : [a, b]
        }
        let nb = { (c: String) in conjointsDe[c]?.count ?? 0 }
        let centre = groupe.reduce(groupe[0]) { nb($1) > nb($0) ? $1 : $0 }
        let autres = groupe.filter { $0 != centre }
        return [autres[0], centre] + autres.dropFirst()
    }

    // 3. Unités par génération : chaque groupe de conjoints forme une unité.
    var unitesParGen: [Int: [[String]]] = [:]
    var place = Set<String>()
    for cle in ordre where !place.contains(cle) {
        var groupe: [String] = []
        var pile = [cle]
        while let c = pile.popLast() {
            if place.insert(c).inserted { groupe.append(c); pile += conjointsDe[c] ?? [] }
        }
        groupe.sort { rang[$0]! < rang[$1]! }
        unitesParGen[elements[cle]!.gen, default: []].append(arranger(groupe))
    }

    var x: [String: Double] = [:]
    func placer(_ unites: [[String]], cible: ([String]) -> Double?) {
        let triees = unites.enumerated().sorted { a, b in
            let ca = cible(a.element), cb = cible(b.element)
            switch (ca, cb) {
            case let (.some(va), .some(vb)): return va == vb ? a.offset < b.offset : va < vb
            case (.some, .none): return true
            case (.none, .some): return false
            default: return a.offset < b.offset
            }
        }.map(\.element)
        var fin = -Double.infinity
        for u in triees {
            let largeur = Double(u.count - 1) * espaceCouple
            let voulu = cible(u).map { $0 - largeur / 2 }
            let mini = fin == -.infinity ? (voulu ?? 0) : fin + espaceUnites
            let debut = max(voulu ?? mini, mini)
            for (i, c) in u.enumerated() { x[c] = debut + Double(i) * espaceCouple }
            fin = debut + largeur
        }
    }
    func moyenne(_ cles: [String]) -> Double? {
        let v = cles.compactMap { x[$0] }
        return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
    }

    let toutesGens = unitesParGen.keys.sorted()
    placer(unitesParGen[0] ?? [], cible: { _ in nil })
    for g in toutesGens.filter({ $0 < 0 }).reversed() {
        placer(unitesParGen[g]!, cible: { u in moyenne(u.flatMap { enfantsDe[$0] ?? [] }) })
    }
    for g in toutesGens.filter({ $0 > 0 }) {
        placer(unitesParGen[g]!, cible: { u in moyenne(u.flatMap { parentsDe[$0] ?? [] }) })
    }

    // 4. Normalisation et nœuds.
    let minX = x.values.min() ?? 0
    let minGen = toutesGens.first ?? 0
    let marge = largeurNoeud / 2
    func pos(_ c: String) -> (Double, Double) {
        (x[c]! - minX + marge, Double(elements[c]!.gen - minGen) * ecartGeneration + 26)
    }
    let noeuds: [Noeud] = ordre.map { c in
        let e = elements[c]!
        let (px, py) = pos(c)
        return Noeud(cle: c, id: e.id, x: px, y: py, aCompleter: e.id == nil,
                     libelle: e.id.flatMap { f.personne($0)?.prenom } ?? "À trouver",
                     pour: e.pour, role: e.role)
    }

    // 5. Traits : couples, puis familles (parents → enfants).
    var traits: [Trait] = []
    for a in ordre {
        for b in conjointsDe[a] ?? [] where rang[a]! < rang[b]! {
            traits.append(Trait(de: pos(a), a: pos(b), pointille: elements[a]!.id == nil || elements[b]!.id == nil))
        }
    }
    var familles: [String: (parents: [String], enfants: [String])] = [:]
    for cle in ordre { if let ps = parentsDe[cle] {
        let k = ps.sorted().joined(separator: "|")
        familles[k, default: (ps, [])].enfants.append(cle)
    } }
    for (_, fam) in familles {
        let pp = fam.parents.map(pos)
        let mx = pp.map(\.0).reduce(0, +) / Double(pp.count)
        let py = pp[0].1
        let midY = py + ecartGeneration * 0.62
        let pointille = fam.parents.contains { elements[$0]!.id == nil }
        let xs = fam.enfants.map { pos($0).0 }
        traits.append(Trait(de: (mx, py), a: (mx, midY), pointille: pointille))
        let gauche = min(mx, xs.min()!), droite = max(mx, xs.max()!)
        if droite > gauche { traits.append(Trait(de: (gauche, midY), a: (droite, midY), pointille: pointille)) }
        for c in fam.enfants {
            let (cx, cy) = pos(c)
            traits.append(Trait(de: (cx, midY), a: (cx, cy), pointille: pointille))
        }
    }

    let maxX = noeuds.map(\.x).max() ?? 0
    let maxY = noeuds.map(\.y).max() ?? 0
    return (noeuds, traits, (maxX + marge, maxY + 70))
}
