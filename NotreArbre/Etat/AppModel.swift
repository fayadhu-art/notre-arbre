import SwiftUI
import ArbreCore

@MainActor
@Observable
final class AppModel {
    var famille = Famille()
    var enAttente: Set<Manque> = []
    var traites: Set<Manque> = []
    var onglet: Onglet = .accueil

    var entretienOuvert = false
    var entretienDepart: Manque?
    var erreur: String?

    let calendrier = Calendar.current
    private let stockage: Stockage

    enum Onglet { case accueil, arbre, famille }

    init() {
        let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        stockage = Stockage(dossier: dossier)
        if let s = try? stockage.charger() { charger(s) }
    }

    private func charger(_ s: Sauvegarde) {
        famille = s.famille
        enAttente = Set(s.enAttente)
        traites = Set(s.traites)
    }

    var sauvegarde: Sauvegarde {
        Sauvegarde(famille: famille, enAttente: Array(enAttente), traites: Array(traites))
    }

    func enregistrer() {
        do { try stockage.enregistrer(sauvegarde) } catch { erreur = "L'arbre n'a pas pu être enregistré." }
        let n = ajoutsAujourdhui.count
        Task { await Rappel.planifier(ajoutsAujourdhui: n) }
    }

    // MARK: Objectif

    var ajoutsAujourdhui: [Personne] { Objectif().ajoutsDuJour(famille, le: Date(), calendrier: calendrier) }
    var serie: Int { Objectif().serie(famille, jusquau: Date(), calendrier: calendrier) }
    var record: Int { Objectif().record(famille, calendrier: calendrier) }

    func ajouts(le jour: Date) -> Int { Objectif().ajoutsDuJour(famille, le: jour, calendrier: calendrier).count }

    // MARK: Questions

    var listeManques: [Manque] { manques(famille, enAttente: enAttente, traites: traites) }

    func reporter(_ m: Manque) { enAttente.insert(m); enregistrer() }

    func ouvrirEntretien(depart: Manque? = nil) {
        entretienDepart = depart
        entretienOuvert = true
    }

    // MARK: Modifications

    /// Applique une proposition validée. Renvoie vrai si l'objectif du jour vient d'être atteint.
    @discardableResult
    func appliquer(_ r: Resultat) -> Bool {
        let avant = ajoutsAujourdhui.count
        famille = r.famille
        if let t = r.traite { traites.insert(t) }
        for t in r.touchees { enAttente = enAttente.filter { $0.personne != t.id } }
        enregistrer()
        return avant < Objectif.cible && ajoutsAujourdhui.count >= Objectif.cible
    }

    func creerMoi(prenom: String, nom: String, sexe: Sexe) {
        let moi = Personne(prenom: prenom.majusculeInitiale, nom: nom, sexe: sexe, origine: .saisie)
        famille.ajouter(moi)
        famille.moiID = moi.id
        enregistrer()
    }

    func modifier(_ p: Personne) { famille.ajouter(p); enregistrer() }

    func supprimer(_ id: UUID) {
        guard id != famille.moiID else { return }
        famille.supprimer(id)
        enregistrer()
    }

    func restaurer(_ data: Data) {
        do {
            charger(try Stockage.importer(data))
            enregistrer()
        } catch {
            erreur = (error as? LocalizedError)?.errorDescription ?? "Ce fichier n'a pas pu être lu."
        }
    }

    func exporter() -> Data? { try? Stockage.exporter(sauvegarde) }

    // MARK: Textes

    func resume(_ id: UUID) -> String {
        guard let p = famille.personne(id) else { return "" }
        let lien = famille.lienAvecMoi(id)
        let date = p.naissance.precision == .inconnue ? "" : " · \(p.neAccorde) \(p.naissance.libelle)"
        return lien.majusculeInitiale + date
    }

    func suggestion(_ m: Manque) -> String {
        let nom = m.personne.flatMap { famille.personne($0)?.prenom } ?? ""
        let estMoi = m.personne == famille.moiID
        switch m.sujet {
        case .parents where estMoi: return "Commence par tes parents : je te guide, une question à la fois."
        case .parents, .grandsParents: return "On ne connaît pas encore les parents de \(nom). On commence par eux ?"
        case .freresSoeurs: return estMoi ? "Parle-moi de tes frères et sœurs." : "Qui sont les frères et sœurs de \(nom) ?"
        case .enfants: return estMoi ? "Ajoute tes enfants à l'arbre." : "Qui sont les enfants de \(nom) ?"
        case .dateNaissance: return estMoi ? "Il manque ton année de naissance." : "Il manque l'année de naissance de \(nom)."
        case .lieuNaissance: return estMoi ? "Il manque ton village de naissance." : "Il manque le village de naissance de \(nom)."
        }
    }
}
