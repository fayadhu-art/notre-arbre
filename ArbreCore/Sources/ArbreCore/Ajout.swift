import Foundation

/// Lien de la personne ajoutée avec la personne touchée dans l'arbre.
public enum LienAjout: String, Sendable, CaseIterable {
    case pere, mere, fratrie, enfant, conjoint
}

/// Ajoute une personne saisie à la main et la relie à `sujet`. Renvoie la nouvelle famille.
public func ajouterProche(_ p: Personne, a sujet: UUID, lien: LienAjout, famille: Famille) -> Famille {
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
        if conj.count == 1 { f.lierParent(conj[0].id, enfant: p.id) }
    case .fratrie:
        for parent in f.parents(de: sujet) { f.lierParent(parent.id, enfant: p.id) }
    case .conjoint:
        f.lierCouple(sujet, p.id)
    }
    return f
}
