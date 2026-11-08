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
    /// Numéro de la famille (un couple ou un parent seul, avec ses enfants) : sert à choisir la couleur.
    public var groupe: Int = 0
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
    func nbConjoints(_ c: String) -> Int { conjointsDe[c]?.count ?? 0 }
    /// Point d'où descend le trait d'une famille : entre les parents s'ils sont côte à côte,
    /// sinon au-dessous du parent « extérieur » (conjoint éloigné) ou du parent seul.
    func depart(_ parents: [String]) -> (x: Double, sousLeNom: Bool)? {
        let xs = parents.compactMap { x[$0] }
        guard xs.count == parents.count, !xs.isEmpty else { return nil }
        if xs.count == 2 {
            if abs(xs[0] - xs[1]) <= espaceCouple + 0.5 { return ((xs[0] + xs[1]) / 2, false) }
            return (nbConjoints(parents[0]) <= nbConjoints(parents[1]) ? xs[0] : xs[1], true)
        }
        return (xs[0], true)
    }
    /// Cible d'une unité d'enfants : le point de départ du trait de leur famille.
    func cibleEnfants(_ u: [String]) -> Double? {
        let v = u.compactMap { c in parentsDe[c].flatMap { depart($0)?.x } }
        return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
    }

    let toutesGens = unitesParGen.keys.sorted()
    placer(unitesParGen[0] ?? [], cible: { _ in nil })
    for g in toutesGens.filter({ $0 < 0 }).reversed() {
        placer(unitesParGen[g]!, cible: { u in moyenne(u.flatMap { enfantsDe[$0] ?? [] }) })
    }
    for g in toutesGens.filter({ $0 > 0 }) {
        placer(unitesParGen[g]!, cible: cibleEnfants)
    }
    // Deuxième passage : la génération de l'utilisateur est replacée sous ses parents, pour que
    // les enfants d'un même couple restent groupés, puis les générations suivantes suivent.
    if toutesGens.contains(where: { $0 < 0 }) {
        placer(unitesParGen[0] ?? [], cible: cibleEnfants)
        for g in toutesGens.filter({ $0 > 0 }) {
            placer(unitesParGen[g]!, cible: cibleEnfants)
        }
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

    // 5. Traits : couples, puis familles (parents → enfants). Chaque famille a son numéro de couleur.
    var traits: [Trait] = []
    var groupes: [String: Int] = [:]
    func groupe(_ ps0: [String]) -> Int {
        // Parent seul marié à une seule personne : ses enfants prennent la couleur de son couple.
        var ps = ps0
        if ps.count == 1, let conj = conjointsDe[ps[0]], conj.count == 1 { ps = [ps[0], conj[0]] }
        let k = ps.sorted().joined(separator: "|")
        if let g = groupes[k] { return g }
        groupes[k] = groupes.count
        return groupes[k]!
    }
    for cle in ordre { if let ps = parentsDe[cle] { _ = groupe(ps) } }
    for a in ordre {
        for b in conjointsDe[a] ?? [] where rang[a]! < rang[b]! {
            let pa = pos(a), pb = pos(b)
            let pointille = elements[a]!.id == nil || elements[b]!.id == nil
            let gr = groupe([a, b])
            if abs(pa.0 - pb.0) <= espaceCouple + 0.5 {
                traits.append(Trait(de: pa, a: pb, pointille: pointille, groupe: gr))
            } else {
                // Conjoints éloignés : petit pont au-dessus des cercles, sans traverser la personne entre eux.
                let (g, d) = pa.0 < pb.0 ? (pa, pb) : (pb, pa)
                let haut = g.1 - 30, bord = g.1 - 20
                traits.append(Trait(de: (g.0 + 16, bord), a: (g.0 + 16, haut), pointille: pointille, groupe: gr))
                traits.append(Trait(de: (g.0 + 16, haut), a: (d.0 - 16, haut), pointille: pointille, groupe: gr))
                traits.append(Trait(de: (d.0 - 16, haut), a: (d.0 - 16, bord), pointille: pointille, groupe: gr))
            }
        }
    }
    var familles: [String: (parents: [String], enfants: [String])] = [:]
    for cle in ordre { if let ps = parentsDe[cle] {
        let k = ps.sorted().joined(separator: "|")
        familles[k, default: (ps, [])].enfants.append(cle)
    } }
    // Chaque famille : un trait qui descend du point de départ, une barre horizontale, puis un trait par enfant.
    // Les barres d'une même rangée sont mises à des hauteurs différentes, choisies pour qu'aucun trait ne se croise.
    struct Fam { let parents: [String]; let enfants: [String]; let x: Double; let y: Double; let sousLeNom: Bool
                 let gauche: Double; let droite: Double; let pointille: Bool }
    var parRangee: [Double: [Fam]] = [:]
    for (_, fam) in familles {
        guard let d = depart(fam.parents) else { continue }
        let py = pos(fam.parents[0]).1
        let dx = d.x - minX + marge
        let xs = fam.enfants.map { pos($0).0 }
        parRangee[py, default: []].append(Fam(parents: fam.parents, enfants: fam.enfants, x: dx, y: py, sousLeNom: d.sousLeNom,
                                               gauche: min(dx, xs.min()!), droite: max(dx, xs.max()!),
                                               pointille: fam.parents.contains { elements[$0]!.id == nil }))
    }
    for (py, liste) in parRangee {
        let fams = liste.sorted { ($0.x, $0.gauche) < ($1.x, $1.gauche) }
        // Contraintes « au-dessus » : si la barre de A passe sous le départ de B, B doit être plus haut que A, et inversement.
        let n = fams.count
        var auDessus: [[Int]] = Array(repeating: [], count: n)   // auDessus[i] = familles qui doivent être sous i
        for a in 0..<n { for b in (a + 1)..<max(a + 1, n) {
            let A = fams[a], B = fams[b]
            guard A.droite > B.gauche else { continue }
            if A.droite > B.x { auDessus[b].append(a) } else { auDessus[a].append(b) }
        } }
        var niveau = Array(repeating: 0, count: n)
        for _ in 0..<n {
            var change = false
            for i in 0..<n { for j in auDessus[i] where niveau[j] < niveau[i] + 1 && niveau[i] + 1 < n {
                niveau[j] = niveau[i] + 1; change = true
            } }
            if !change { break }
        }
        let nbNiveaux = (niveau.max() ?? 0) + 1
        let haut = py + ecartGeneration * 0.60, bas = py + ecartGeneration - 30
        let pas = nbNiveaux > 1 ? min(8, (bas - haut) / Double(nbNiveaux - 1)) : 0
        for (k, f) in fams.enumerated() {
            let midY = haut + Double(niveau[k]) * pas
            let debut = f.sousLeNom ? py + ecartGeneration * 0.58 : py
            traits.append(Trait(de: (f.x, debut), a: (f.x, midY), pointille: f.pointille, groupe: groupe(f.parents)))
            if f.droite > f.gauche { traits.append(Trait(de: (f.gauche, midY), a: (f.droite, midY), pointille: f.pointille, groupe: groupe(f.parents))) }
            for c in f.enfants {
                let (cx, cy) = pos(c)
                traits.append(Trait(de: (cx, midY), a: (cx, cy), pointille: f.pointille, groupe: groupe(f.parents)))
            }
        }
    }

    let maxX = noeuds.map(\.x).max() ?? 0
    let maxY = noeuds.map(\.y).max() ?? 0
    return (noeuds, traits, (maxX + marge, maxY + 70))
}
