import SwiftUI
import ArbreCore

@MainActor
@Observable
final class AppModel {
    var famille = Famille()
    var enAttente: Set<Manque> = []
    var traites: Set<Manque> = []
    var onglet: Onglet = .accueil

    /// Formulaire d'ajout ouvert (personne touchée + lien).
    var ajout: Ajout?
    /// Fiche à modifier (date ou village manquant).
    var edition: UUID?
    var objectifAtteint = false
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

    /// Ouvre le bon formulaire pour une information manquante.
    func completer(_ m: Manque) {
        guard let id = m.personne else { return }
        switch m.sujet {
        case .parents, .grandsParents:
            ajout = Ajout(pour: id, lien: famille.pere(de: id) == nil ? .pere : .mere)
        case .freresSoeurs:
            ajout = Ajout(pour: id, lien: famille.parents(de: id).isEmpty ? (famille.pere(de: id) == nil ? .pere : .mere) : .fratrie)
        case .enfants:
            ajout = Ajout(pour: id, lien: .enfant)
        case .dateNaissance, .lieuNaissance:
            edition = id
        }
    }

    /// Liens qu'on peut ajouter à une personne (père et mère seulement s'ils manquent, frère ou sœur si on connaît un parent).
    func liensPossibles(_ id: UUID) -> [LienAjout] {
        // Une personne entrée par mariage : on n'ajoute que ses enfants avec la famille, pas sa propre famille.
        guard famille.estDeLaFamille(id) else { return [.enfant] }
        var l: [LienAjout] = []
        if famille.parents(de: id).count < 2 {
            if famille.pere(de: id) == nil { l.append(.pere) }
            if famille.mere(de: id) == nil { l.append(.mere) }
        }
        if !famille.parents(de: id).isEmpty { l.append(.fratrie) }
        l += [.enfant, .conjoint]
        return l
    }

    /// Ajoute une personne saisie dans le formulaire. Ouvre l'écran « Objectif atteint » au 5e ajout du jour.
    func ajouter(_ p: Personne, a sujet: UUID, lien: LienAjout, parentsChoisis: [UUID]? = nil, enfantsCommuns: Set<UUID> = []) {
        let avant = ajoutsAujourdhui.count
        famille = ajouterProche(p, a: sujet, lien: lien, famille: famille, parentsChoisis: parentsChoisis)
        if lien == .conjoint, !enfantsCommuns.isEmpty {
            famille = definirEnfantsCommuns(sujet, avec: p.id, enfants: enfantsCommuns, famille: famille)
        }
        enregistrer()
        verifierObjectif(avant: avant)
    }

    /// Crée les nouveaux enfants d'un couple, reliés aux deux parents.
    func ajouterEnfants(_ lignes: [NouvelEnfant], de sujet: UUID, avec conjoint: UUID) {
        let valides = lignes.filter { !$0.prenom.trimmingCharacters(in: .whitespaces).isEmpty && !$0.nom.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !valides.isEmpty else { return }
        let avant = ajoutsAujourdhui.count
        for l in valides {
            let e = Personne(prenom: l.prenom.trimmingCharacters(in: .whitespaces).majusculeInitiale,
                             nom: l.nom.trimmingCharacters(in: .whitespaces), sexe: l.sexe, origine: .saisie)
            famille = ajouterProche(e, a: sujet, lien: .enfant, famille: famille, parentsChoisis: [conjoint])
        }
        enregistrer()
        verifierObjectif(avant: avant)
    }

    private func verifierObjectif(avant: Int) {
        if avant < Objectif.cible && ajoutsAujourdhui.count >= Objectif.cible {
            // Laisse le formulaire se fermer avant d'afficher l'écran de victoire.
            Task { try? await Task.sleep(for: .milliseconds(600)); objectifAtteint = true }
        }
    }

    // MARK: Modifications

    func creerMoi(prenom: String, nom: String, sexe: Sexe) {
        let moi = Personne(prenom: prenom.majusculeInitiale, nom: nom, sexe: sexe, origine: .saisie)
        famille.ajouter(moi)
        famille.moiID = moi.id
        enregistrer()
    }

    func modifier(_ p: Personne) { famille.ajouter(p); enregistrer() }

    func definirEnfants(de sujet: UUID, avec conjoint: UUID, _ enfants: Set<UUID>) {
        famille = definirEnfantsCommuns(sujet, avec: conjoint, enfants: enfants, famille: famille)
        enregistrer()
    }

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
        let lieu = (p.lieuNaissance ?? "").isEmpty ? "" : " · \(p.lieuNaissance!)"
        return famille.parente(de: id) + lieu
    }

    func suggestion(_ m: Manque) -> String {
        let nom = m.personne.flatMap { famille.personne($0)?.prenom } ?? ""
        let estMoi = m.personne == famille.moiID
        switch m.sujet {
        case .parents where estMoi: return "Commence par ajouter tes parents à l'arbre."
        case .parents, .grandsParents: return "On ne connaît pas encore les parents de \(nom). On commence par eux ?"
        case .freresSoeurs: return estMoi ? "Parle-moi de tes frères et sœurs." : "Qui sont les frères et sœurs de \(nom) ?"
        case .enfants: return estMoi ? "Ajoute tes enfants à l'arbre." : "Qui sont les enfants de \(nom) ?"
        case .dateNaissance: return estMoi ? "Il manque ton année de naissance." : "Il manque l'année de naissance de \(nom)."
        case .lieuNaissance: return estMoi ? "Il manque ton village de naissance." : "Il manque le village de naissance de \(nom)."
        }
    }
}

struct Ajout: Identifiable, Equatable {
    let pour: UUID
    let lien: LienAjout
    var id: String { "\(pour)-\(lien.rawValue)" }
}

extension LienAjout {
    /// Libellé du menu selon la personne : « Ajouter une deuxième épouse » pour un homme déjà marié…
    func action(pour p: Personne?, famille: Famille) -> String {
        guard self == .conjoint, let p else { return action }
        let n = famille.conjoints(de: p.id).count
        switch p.sexe {
        case .homme:
            return ["Ajouter son épouse", "Ajouter une deuxième épouse", "Ajouter une troisième épouse"][safe: n] ?? "Ajouter une autre épouse"
        case .femme:
            return n == 0 ? "Ajouter son mari" : "Ajouter un autre mari"
        case .inconnu:
            return action
        }
    }

    var action: String {
        switch self {
        case .pere: "Ajouter son père"
        case .mere: "Ajouter sa mère"
        case .fratrie: "Ajouter un frère ou une sœur"
        case .enfant: "Ajouter un enfant"
        case .conjoint: "Ajouter un conjoint"
        }
    }
    var icone: String {
        switch self {
        case .pere, .mere: "arrow.up.circle"
        case .fratrie: "arrow.left.and.right.circle"
        case .enfant: "arrow.down.circle"
        case .conjoint: "heart.circle"
        }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

/// Une ligne « nouvel enfant » saisie avec un couple.
struct NouvelEnfant: Identifiable, Equatable {
    let id = UUID()
    var prenom = ""
    var nom = ""
    var sexe: Sexe = .inconnu
}
