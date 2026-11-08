import Foundation

/// Lien de la personne ajoutée avec la personne touchée dans l'arbre.
public enum LienAjout: String, Sendable, CaseIterable {
    case pere, mere, fratrie, enfant, conjoint
}

/// Ajoute une personne saisie à la main et la relie à `sujet`. Renvoie la nouvelle famille.
/// `parentsChoisis` : pour un enfant, l'autre parent (vide = inconnu) ; pour un frère ou une sœur,
/// les parents en commun (un seul = demi-frère ou demi-sœur). `nil` = choix automatique.
public func ajouterProche(_ p: Personne, a sujet: UUID, lien: LienAjout, famille: Famille, parentsChoisis: [UUID]? = nil) -> Famille {
    var f = famille
    f.ajouter(p)
    switch lien {
    case .pere, .mere:
        f.lierParent(p.id, enfant: sujet)
        let ps = f.parents(de: sujet)
        if ps.count == 2 { f.lierCouple(ps[0].id, ps[1].id) }
    case .enfant:
        f.lierParent(sujet, enfant: p.id)
        let conj = f.conjoints(de: sujet)
        for autre in parentsChoisis ?? (conj.count == 1 ? [conj[0].id] : []) { f.lierParent(autre, enfant: p.id) }
    case .fratrie:
        for parent in parentsChoisis ?? f.parents(de: sujet).map(\.id) { f.lierParent(parent, enfant: p.id) }
    case .conjoint:
        f.lierCouple(sujet, p.id)
    }
    return f
}

/// Choisit, parmi les enfants de `sujet`, ceux qu'il a eus avec `conjoint`.
/// Un enfant coché est relié au conjoint (et détaché d'un autre parent éventuel) ; un enfant décoché est détaché du conjoint.
public func definirEnfantsCommuns(_ sujet: UUID, avec conjoint: UUID, enfants choisis: Set<UUID>, famille: Famille) -> Famille {
    var f = famille
    for e in f.enfants(de: sujet).map(\.id) {
        let autres = f.parents(de: e).map(\.id).filter { $0 != sujet }
        if choisis.contains(e) {
            for a in autres where a != conjoint { f.retirerParent(a, enfant: e) }
            f.lierParent(conjoint, enfant: e)
        } else if autres.contains(conjoint) {
            f.retirerParent(conjoint, enfant: e)
        }
    }
    return f
}
