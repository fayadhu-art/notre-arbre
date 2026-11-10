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
    /// Personnes reliées par ce trait (parents et enfants de la famille, ou les deux conjoints).
    public var personnes: [UUID] = []
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
    // Assez d'espace entre deux conjoints pour qu'un trait descende entre leurs noms sans les frôler.
    let espaceCouple = largeurNoeud + 24
    let espaceUnites = largeurNoeud + 36

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

    // Un couple : femme à gauche, homme à droite (le côté du père se retrouve à droite de l'arbre). Plusieurs épouses : 1re épouse, mari, 2e épouse, 3e épouse…
    func arranger(_ groupe: [String]) -> [String] {
        if groupe.count == 1 { return groupe }
        if groupe.count == 2 {
            let (a, b) = (groupe[0], groupe[1])
            return estHomme(a) && !estHomme(b) ? [b, a] : [a, b]
        }
        let nb = { (c: String) in conjointsDe[c]?.count ?? 0 }
        let centre = groupe.reduce(groupe[0]) { nb($1) > nb($0) ? $1 : $0 }
        var autres = groupe.filter { $0 != centre }
        // Le conjoint de la lignée directe (père ou mère de l'utilisateur, ancêtre) reste collé au centre,
        // du bon côté : la femme à gauche, l'homme à droite. Les autres conjoints vont de l'autre côté.
        if let i = autres.firstIndex(where: { c in elements[c]!.id.map { ligneDirecte.contains($0) } ?? false }) {
            autres.insert(autres.remove(at: i), at: 0)
        }
        let prioritaire = autres[0], reste = Array(autres.dropFirst())
        return estHomme(centre) ? [prioritaire, centre] + reste : reste.reversed() + [centre, prioritaire]
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
    func depart(_ parents0: [String]) -> (x: Double, sousLeNom: Bool)? {
        // Parent seul marié à une seule personne : on dessine la famille depuis le couple,
        // pour qu'on voie bien le père, la mère et les enfants ensemble.
        var parents = parents0
        if parents.count == 1, let conj = conjointsDe[parents[0]], conj.count == 1 { parents = [parents[0], conj[0]] }
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
    // Remontée : chaque couple au-dessus de ses enfants. Une personne sans enfant se cale sur ses frères et sœurs.
    func cibleParents(_ u: [String]) -> Double? {
        let enfants = u.flatMap { enfantsDe[$0] ?? [] }
        // Les ancêtres se placent au-dessus de leur enfant de la lignée directe (Papa, Maman…),
        // ce qui garde le côté père à droite et le côté mère à gauche jusqu'en haut de l'arbre.
        let directs = enfants.filter { c in elements[c]!.id.map { ligneDirecte.contains($0) } ?? false }
        if let m = moyenne(directs) { return m }
        if let m = moyenne(enfants) { return m }
        let freres = u.flatMap { c in (parentsDe[c] ?? []).flatMap { enfantsDe[$0] ?? [] } }.filter { !u.contains($0) }
        return moyenne(freres.flatMap { enfantsDe[$0] ?? [] })
    }
    for g in toutesGens.filter({ $0 < 0 }).reversed() {
        placer(unitesParGen[g]!, cible: cibleParents)
    }
    for g in toutesGens.filter({ $0 > 0 }) {
        placer(unitesParGen[g]!, cible: cibleEnfants)
    }
    // Descente : de haut en bas, chaque génération est replacée sous ses parents, pour que
    // les frères et sœurs restent groupés sous leur couple, côté père à droite, côté mère à gauche.
    for g in toutesGens.dropFirst() {
        placer(unitesParGen[g]!, cible: cibleEnfants)
    }

    // 4. Familles (un couple ou un parent seul, avec ses enfants) et pistes des traits.
    // Un parent seul marié une seule fois est regroupé avec son couple : une seule famille, un seul trait.
    func cleFamille(_ ps0: [String]) -> [String] {
        if ps0.count == 1, let conj = conjointsDe[ps0[0]], conj.count == 1 { return [ps0[0], conj[0]] }
        return ps0
    }
    var familles: [String: (parents: [String], enfants: [String])] = [:]
    var ordreFamilles: [String] = []
    for cle in ordre {
        guard let ps0 = parentsDe[cle] else { continue }
        let ps = cleFamille(ps0)
        let k = ps.sorted().joined(separator: "|")
        if familles[k] == nil { familles[k] = (ps, []); ordreFamilles.append(k) }
        familles[k]!.enfants.append(cle)
    }
    var groupes: [String: Int] = [:]
    func groupe(_ ps0: [String]) -> Int {
        let k = cleFamille(ps0).sorted().joined(separator: "|")
        if let g = groupes[k] { return g }
        groupes[k] = groupes.count
        return groupes[k]!
    }
    for k in ordreFamilles { _ = groupe(familles[k]!.parents) }

    let minX = x.values.min() ?? 0
    let marge = largeurNoeud / 2
    func px(_ c: String) -> Double { x[c]! - minX + marge }

    // Chaque famille : un trait qui descend du point de départ, une barre horizontale, puis un trait par enfant.
    // Dans une rangée, deux barres qui se chevauchent (ou se frôlent) ont chacune leur piste, espacées de 16 points.
    // L'ordre des pistes est choisi pour qu'aucun trait n'en croise un autre.
    struct Fam { let parents: [String]; let enfants: [String]; let x: Double; let sousLeNom: Bool
                 let gauche: Double; let droite: Double; let pointille: Bool; var niveau = 0 }
    let pasPiste = 16.0, margeBarre = 14.0
    var famsParGen: [Int: [Fam]] = [:]
    for k in ordreFamilles {
        let fam = familles[k]!
        guard let d = depart(fam.parents) else { continue }
        let dx = d.x - minX + marge
        let xs = fam.enfants.map(px)
        famsParGen[elements[fam.parents[0]]!.gen, default: []].append(
            Fam(parents: fam.parents, enfants: fam.enfants, x: dx, sousLeNom: d.sousLeNom,
                gauche: min(dx, xs.min()!), droite: max(dx, xs.max()!),
                pointille: fam.parents.contains { elements[$0]!.id == nil }))
    }
    var pistesParGen: [Int: Int] = [:]
    for (g, liste) in famsParGen {
        var fams = liste.sorted { ($0.x, $0.gauche) < ($1.x, $1.gauche) }
        let n = fams.count
        var dessous: [[Int]] = Array(repeating: [], count: n)   // dessous[i] = familles qui doivent passer sous i
        for a in 0..<n { for b in (a + 1)..<max(a + 1, n) {
            let A = fams[a], B = fams[b]
            guard A.droite + margeBarre > B.gauche else { continue }
            // Le départ de B tombe sur la barre de A : la barre de B passe au-dessus. Sinon l'inverse.
            if A.droite + margeBarre > B.x { dessous[b].append(a) } else { dessous[a].append(b) }
        } }
        var niveau = Array(repeating: 0, count: n)
        for _ in 0..<n {
            var change = false
            for i in 0..<n { for j in dessous[i] where niveau[j] < niveau[i] + 1 && niveau[i] + 1 < n {
                niveau[j] = niveau[i] + 1; change = true
            } }
            if !change { break }
        }
        for i in 0..<n { fams[i].niveau = niveau[i] }
        famsParGen[g] = fams
        pistesParGen[g] = (niveau.max() ?? 0) + 1
    }

    // Conjoints éloignés (personne mariée plusieurs fois) : un pont au-dessus des cercles.
    // Plusieurs ponts du même côté sont emboîtés : le plus long passe le plus haut.
    struct Pont { let centre: String; let autre: String }
    var adjacents: [(String, String)] = []
    var pontsParCote: [String: [Pont]] = [:]
    for a in ordre {
        for b in conjointsDe[a] ?? [] where rang[a]! < rang[b]! {
            if abs(x[a]! - x[b]!) <= espaceCouple + 0.5 { adjacents.append((a, b)); continue }
            let centre = nbConjoints(a) >= nbConjoints(b) ? a : b
            let autre = centre == a ? b : a
            pontsParCote[centre + (x[autre]! < x[centre]! ? "|g" : "|d"), default: []].append(Pont(centre: centre, autre: autre))
        }
    }
    var pontsParGen: [Int: Int] = [:]
    for (_, liste) in pontsParCote {
        let g = elements[liste[0].centre]!.gen
        pontsParGen[g] = max(pontsParGen[g] ?? 0, liste.count)
    }

    // 5. Hauteur de chaque rangée : l'écart grandit avec le nombre de pistes et de ponts, pour que rien ne se touche.
    let toutes = toutesGens
    let minGen = toutes.first ?? 0, maxGen = toutes.last ?? 0
    var yDe: [Int: Double] = [:]
    var yCourant = 26.0 + ((pontsParGen[minGen] ?? 0) > 0 ? 20 + 10 * Double(pontsParGen[minGen]!) : 0)
    for g in minGen...maxGen {
        yDe[g] = yCourant
        let pistes = Double(max(0, (pistesParGen[g] ?? 1) - 1))
        let ponts = Double(max(0, (pontsParGen[g + 1] ?? 0) - 1))
        yCourant += ecartGeneration + pistes * pasPiste + ponts * 10
    }
    func pos(_ c: String) -> (Double, Double) { (px(c), yDe[elements[c]!.gen]!) }
    let noeuds: [Noeud] = ordre.map { c in
        let e = elements[c]!
        let (qx, qy) = pos(c)
        return Noeud(cle: c, id: e.id, x: qx, y: qy, aCompleter: e.id == nil,
                     libelle: e.id.flatMap { f.personne($0)?.prenom } ?? "À trouver",
                     pour: e.pour, role: e.role)
    }

    // 6. Traits.
    var traits: [Trait] = []
    for (a, b) in adjacents {
        traits.append(Trait(de: pos(a), a: pos(b), pointille: elements[a]!.id == nil || elements[b]!.id == nil,
                            groupe: groupe([a, b]), personnes: [a, b].compactMap { elements[$0]!.id }))
    }
    for (cle, liste0) in pontsParCote {
        let sens: Double = cle.hasSuffix("|g") ? -1 : 1
        let liste = liste0.sorted { abs(x[$0.autre]! - x[$0.centre]!) > abs(x[$1.autre]! - x[$1.centre]!) }
        for (j, p) in liste.enumerated() {
            let c = pos(p.centre), o = pos(p.autre)
            let dx = min(12 + 9 * Double(j), 24)
            let haut = c.1 - 36 - 10 * Double(liste.count - 1 - j)
            let x1 = c.0 + sens * dx, x2 = o.0 - sens * 14
            let pointille = elements[p.centre]!.id == nil || elements[p.autre]!.id == nil
            let gr = groupe([p.centre, p.autre])
            let ids = [p.centre, p.autre].compactMap { elements[$0]!.id }
            traits.append(Trait(de: (x1, c.1 - (676 - dx * dx).squareRoot()), a: (x1, haut), pointille: pointille, groupe: gr, personnes: ids))
            traits.append(Trait(de: (x1, haut), a: (x2, haut), pointille: pointille, groupe: gr, personnes: ids))
            traits.append(Trait(de: (x2, haut), a: (x2, o.1 - 21.9), pointille: pointille, groupe: gr, personnes: ids))
        }
    }
    for (g, fams) in famsParGen {
        let py = yDe[g]!
        for fa in fams {
            let ids = (fa.parents + fa.enfants).compactMap { elements[$0]!.id }
            let gr = groupe(fa.parents)
            let midY = py + ecartGeneration * 0.62 + Double(fa.niveau) * pasPiste
            let debut = fa.sousLeNom ? py + ecartGeneration * 0.58 : py
            traits.append(Trait(de: (fa.x, debut), a: (fa.x, midY), pointille: fa.pointille, groupe: gr, personnes: ids))
            if fa.droite > fa.gauche { traits.append(Trait(de: (fa.gauche, midY), a: (fa.droite, midY), pointille: fa.pointille, groupe: gr, personnes: ids)) }
            for c in fa.enfants {
                let (cx, cy) = pos(c)
                traits.append(Trait(de: (cx, midY), a: (cx, cy), pointille: fa.pointille, groupe: gr, personnes: ids))
            }
        }
    }

    let maxX = noeuds.map(\.x).max() ?? 0
    let maxY = noeuds.map(\.y).max() ?? 0
    return (noeuds, traits, (maxX + marge, maxY + 92))
}
