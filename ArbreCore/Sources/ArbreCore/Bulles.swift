import Foundation

/// Une « bulle » dessinée à la place des traits : soit un couple (capsule derrière les deux conjoints),
/// soit les enfants d'un couple (carte derrière la fratrie, avec « Enfants de … » en titre).
public struct Bulle: Sendable, Identifiable {
    public let id: String
    public let x1: Double
    public let x2: Double
    public let y1: Double
    public let y2: Double
    /// Numéro de famille : le couple et sa fratrie ont le même, donc la même couleur.
    public let groupe: Int
    public let titre: String?
    public let estCouple: Bool
}

public func bulles(_ f: Famille, largeurNoeud w: Double = 84, ecartGeneration: Double = 130) -> [Bulle] {
    let r = disposer(f, largeurNoeud: w, ecartGeneration: ecartGeneration)
    var pos: [UUID: (Double, Double)] = [:]
    for n in r.noeuds { if let id = n.id { pos[id] = (n.x, n.y) } }
    let espaceCouple = w + 6

    // Clé d'une famille : ses parents réels. Un parent seul marié une seule fois = son couple.
    func cle(_ parents: [UUID]) -> [UUID] {
        var ps = parents
        if ps.count == 1 {
            let c = f.conjoints(de: ps[0])
            if c.count == 1 { ps.append(c[0].id) }
        }
        return ps.sorted { $0.uuidString < $1.uuidString }
    }
    var familles: [[UUID]: [UUID]] = [:]
    for p in f.personnes where pos[p.id] != nil {
        let ps = f.parents(de: p.id).map(\.id)
        guard !ps.isEmpty else { continue }
        familles[cle(ps), default: []].append(p.id)
    }
    // Numéros de couleur : de haut en bas, de gauche à droite.
    let ordre = familles.sorted { a, b in
        let pa = a.value.compactMap { pos[$0] }.min { ($0.1, $0.0) < ($1.1, $1.0) } ?? (0, 0)
        let pb = b.value.compactMap { pos[$0] }.min { ($0.1, $0.0) < ($1.1, $1.0) } ?? (0, 0)
        return (pa.1, pa.0) < (pb.1, pb.0)
    }
    var groupes: [[UUID]: Int] = [:]
    for (k, _) in ordre { groupes[k] = groupes.count }

    var resultat: [Bulle] = []
    let tous = r.noeuds
    for (k, enfants) in ordre {
        let g = groupes[k]!
        let noms = k.compactMap { pid in f.personne(pid).map { (pos[pid]?.0 ?? 0, $0.prenom) } }.sorted { $0.0 < $1.0 }.map(\.1)
        let titre = noms.isEmpty ? nil : "Enfants de " + noms.joined(separator: " et ")
        // Les enfants sont groupés par rangée, en morceaux contigus (sans englober quelqu'un d'autre).
        let parRangee = Dictionary(grouping: enfants.compactMap { e in pos[e].map { (e, $0) } }, by: { $0.1.1 })
        var premier = true
        for (y, membres) in parRangee.sorted(by: { $0.key < $1.key }) {
            let ids = Set(membres.map(\.0))
            let rangee = tous.filter { $0.y == y }.sorted { $0.x < $1.x }
            var morceau: [Double] = []
            func fermer() {
                guard let a = morceau.first, let b = morceau.last else { return }
                resultat.append(Bulle(id: "f\(g)-\(resultat.count)", x1: a - w / 2 - 4, x2: b + w / 2 + 4,
                                      y1: y - 50, y2: y + 90, groupe: g, titre: premier ? titre : nil, estCouple: false))
                premier = false
                morceau = []
            }
            for n in rangee {
                if let id = n.id, ids.contains(id) { morceau.append(n.x) } else { fermer() }
            }
            fermer()
        }
    }
    // Couples côte à côte : une capsule de la couleur de leur famille.
    for c in f.couples {
        guard let a = pos[c.a], let b = pos[c.b], a.1 == b.1, abs(a.0 - b.0) <= espaceCouple + 0.5 else { continue }
        let k = cle([c.a, c.b])
        let g = groupes[k] ?? {
            let n = groupes.count
            groupes[k] = n
            return n
        }()
        resultat.append(Bulle(id: "c\(c.a)-\(c.b)", x1: min(a.0, b.0) - 32, x2: max(a.0, b.0) + 32,
                              y1: a.1 - 32, y2: a.1 + 32, groupe: g, titre: nil, estCouple: true))
    }
    return resultat
}
