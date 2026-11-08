import Foundation

/// Une personne comprise dans une réponse, avec son lien avec la personne concernée par la question.
/// `lien` : « lui-même », « père », « mère », « frère », « sœur », « fils », « fille », « époux », « épouse » ou « autre ».
public struct Extrait: Sendable, Equatable {
    public var prenom: String
    public var nom: String
    public var lien: String
    public var sexe: String
    public var dateTexte: String
    public var lieu: String

    public init(prenom: String = "", nom: String = "", lien: String, sexe: String = "inconnu", dateTexte: String = "", lieu: String = "") {
        self.prenom = prenom
        self.nom = nom
        self.lien = lien
        self.sexe = sexe
        self.dateTexte = dateTexte
        self.lieu = lieu
    }
}

public struct Resultat: Sendable {
    /// La famille telle qu'elle sera si l'utilisateur valide.
    public var famille: Famille
    /// Personnes créées ou modifiées, dans l'ordre (id, nouvelle fiche ?).
    public var touchees: [(id: UUID, nouvelle: Bool)]
    /// Question réglée sans nouvelle personne (« pas de frère »).
    public var traite: Manque?
    public var estVide: Bool { touchees.isEmpty && traite == nil }
}

private func majuscule(_ s: String) -> String {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    return t.prefix(1).uppercased() + t.dropFirst()
}

/// Applique ce que l'IA a compris à une copie de la famille. Rien n'est enregistré ici.
public func construireProposition(extraits: [Extrait], aucun: Bool, manque: Manque?, famille: Famille,
                                  maintenant: Date = Date(), origine: Origine = .entretien) -> Resultat {
    var f = famille
    var touchees: [(id: UUID, nouvelle: Bool)] = []
    func toucher(_ id: UUID, _ nouvelle: Bool) {
        if let i = touchees.firstIndex(where: { $0.id == id }) {
            touchees[i].nouvelle = touchees[i].nouvelle || nouvelle
        } else {
            touchees.append((id, nouvelle))
        }
    }
    guard let sujet = manque?.personne ?? f.moiID else { return Resultat(famille: f, touchees: [], traite: nil) }

    func completer(_ p: inout Personne, _ e: Extrait) {
        if !e.dateTexte.isEmpty {
            let d = DateFloue.depuis(texte: e.dateTexte)
            if d.precision != .inconnue { p.naissance = d }
        }
        if !e.lieu.trimmingCharacters(in: .whitespaces).isEmpty { p.lieuNaissance = majuscule(e.lieu) }
    }

    for e in extraits {
        let lien = plier(e.lien).replacingOccurrences(of: "œ", with: "oe")
        let prenom = e.prenom.trimmingCharacters(in: .whitespacesAndNewlines)
        if lien == "lui-meme" || lien == "elle-meme" || (prenom.isEmpty && (!e.dateTexte.isEmpty || !e.lieu.isEmpty)) {
            guard var p = f.personne(sujet) else { continue }
            completer(&p, e)
            f.ajouter(p)
            toucher(sujet, false)
            continue
        }
        guard !prenom.isEmpty else { continue }
        var sexe = Sexe(rawValue: plier(e.sexe)) ?? .inconnu
        switch lien {
        case "pere", "fils", "frere", "epoux", "mari": sexe = .homme
        case "mere", "fille", "soeur", "epouse", "femme": sexe = .femme
        default: break
        }
        var p: Personne
        var nouvelle = false
        if let existante = f.trouver(prenom: prenom, nom: e.nom) {
            p = existante
        } else {
            p = Personne(prenom: majuscule(prenom), nom: e.nom.trimmingCharacters(in: .whitespaces),
                         sexe: sexe, origine: origine, ajouteeLe: maintenant)
            nouvelle = true
        }
        if p.sexe == .inconnu { p.sexe = sexe }
        completer(&p, e)
        f.ajouter(p)
        switch lien {
        case "pere", "mere", "parent":
            f.lierParent(p.id, enfant: sujet)
        case "fils", "fille", "enfant":
            f.lierParent(sujet, enfant: p.id)
            let conj = f.conjoints(de: sujet)
            if conj.count == 1 { f.lierParent(conj[0].id, enfant: p.id) }
        case "frere", "soeur", "fratrie":
            for parent in f.parents(de: sujet) { f.lierParent(parent.id, enfant: p.id) }
        case "epoux", "epouse", "mari", "femme", "conjoint":
            f.lierCouple(sujet, p.id)
        default:
            break
        }
        toucher(p.id, nouvelle)
    }
    let ps = f.parents(de: sujet)
    if ps.count == 2 { f.lierCouple(ps[0].id, ps[1].id) }

    var traite: Manque?
    if let manque, aucun, touchees.isEmpty, [.freresSoeurs, .enfants].contains(manque.sujet) { traite = manque }
    return Resultat(famille: f, touchees: touchees, traite: traite)
}

/// Lecture simple d'une réponse tapée, quand l'IA d'Apple n'est pas disponible.
public func extraitsSimples(reponse: String, manque: Manque?) -> (extraits: [Extrait], aucun: Bool) {
    let t = plier(reponse)
    let mots = Set(t.split { !$0.isLetter }.map(String.init))
    let aucun = !mots.isDisjoint(with: ["aucun", "aucune", "personne", "non"]) || t.contains("pas de")
    let sujet = manque?.sujet
    if sujet == .dateNaissance { return ([Extrait(lien: "lui-même", dateTexte: reponse)], false) }
    if sujet == .lieuNaissance {
        var lieu = reponse.trimmingCharacters(in: .whitespacesAndNewlines)
        for debut in ["il est né à ", "elle est née à ", "né à ", "née à ", "à ", "a "] where plier(lieu).hasPrefix(plier(debut)) {
            lieu = String(lieu.dropFirst(debut.count)); break
        }
        return ([Extrait(lien: "lui-même", lieu: lieu)], false)
    }
    let vides: Set<String> = ["mon", "ma", "mes", "son", "sa", "ses", "pere", "mere", "s'appelle", "s'appellent", "s'appelait",
                              "il", "elle", "c'est", "est", "sont", "papa", "maman", "frere", "soeur", "sœur", "freres", "soeurs",
                              "fils", "fille", "enfants", "j'ai", "un", "une", "deux", "trois", "qui", "se", "nomme", "appelle",
                              "et", "le", "la", "les", "de", "du", "ne", "en", "vers", "environ",
                              "non", "oui", "aucun", "aucune", "pas", "personne", "je", "n'ai"]
    let morceaux = reponse
        .replacingOccurrences(of: " et ", with: ",")
        .split(whereSeparator: { ",;.\n".contains($0) })
        .map { m in m.split(separator: " ").map(String.init).filter { !vides.contains(plier($0)) && $0.first?.isLetter == true } }
        .filter { !$0.isEmpty }
    var liste: [Extrait] = []
    for (i, mots) in morceaux.enumerated() {
        let prenom = mots[0], nom = mots.dropFirst().joined(separator: " ")
        switch sujet {
        case .parents?, .grandsParents?: liste.append(Extrait(prenom: prenom, nom: nom, lien: i == 0 ? "père" : "mère"))
        case .enfants?: liste.append(Extrait(prenom: prenom, nom: nom, lien: "enfant"))
        case .freresSoeurs?: liste.append(Extrait(prenom: prenom, nom: nom, lien: "fratrie"))
        default: liste.append(Extrait(prenom: prenom, nom: nom, lien: "autre"))
        }
    }
    let annee = DateFloue.depuis(texte: reponse)
    if liste.count == 1, annee.precision != .inconnue { liste[0].dateTexte = reponse }
    return (liste, aucun && liste.isEmpty)
}
