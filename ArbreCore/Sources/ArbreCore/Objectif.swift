import Foundation

public struct Objectif: Sendable {
    public static let cible = 5
    public init() {}

    public func ajoutsDuJour(_ f: Famille, le jour: Date, calendrier: Calendar) -> [Personne] {
        f.personnes.filter { $0.id != f.moiID && calendrier.isDate($0.ajouteeLe, inSameDayAs: jour) }
    }

    private func joursReussis(_ f: Famille, calendrier: Calendar) -> Set<Date> {
        var compte: [Date: Int] = [:]
        for p in f.personnes where p.id != f.moiID {
            compte[calendrier.startOfDay(for: p.ajouteeLe), default: 0] += 1
        }
        return Set(compte.filter { $0.value >= Self.cible }.keys)
    }

    /// Jours d'affilée avec l'objectif atteint. Aujourd'hui pas encore fini ne casse pas la série.
    public func serie(_ f: Famille, jusquau jour: Date, calendrier: Calendar) -> Int {
        let ok = joursReussis(f, calendrier: calendrier)
        var d = calendrier.startOfDay(for: jour)
        if !ok.contains(d) { d = calendrier.date(byAdding: .day, value: -1, to: d)! }
        var n = 0
        while ok.contains(d) {
            n += 1
            d = calendrier.date(byAdding: .day, value: -1, to: d)!
        }
        return n
    }

    public func record(_ f: Famille, calendrier: Calendar) -> Int {
        let jours = joursReussis(f, calendrier: calendrier).sorted()
        var meilleur = 0, courant = 0
        var precedent: Date?
        for d in jours {
            if let p = precedent, calendrier.date(byAdding: .day, value: 1, to: p) == d { courant += 1 } else { courant = 1 }
            meilleur = max(meilleur, courant)
            precedent = d
        }
        return meilleur
    }
}
