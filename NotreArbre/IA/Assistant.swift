import Foundation
import ArbreCore
#if canImport(FoundationModels)
import FoundationModels

@Generable
struct PersonneExtraite {
    @Guide(description: "Prénom de la personne, avec une majuscule. Chaîne vide si l'information concerne la personne concernée elle-même.")
    var prenom: String
    @Guide(description: "Nom de famille s'il est dit, sinon chaîne vide")
    var nom: String
    @Guide(description: "Lien avec la personne concernée", .anyOf(["lui-même", "père", "mère", "frère", "sœur", "fils", "fille", "époux", "épouse", "autre"]))
    var lien: String
    @Guide(description: "Sexe de la personne", .anyOf(["homme", "femme", "inconnu"]))
    var sexe: String
    @Guide(description: "Ce qui est dit de sa date ou année de naissance, mot pour mot (ex. « vers 1958 »), sinon chaîne vide")
    var dateTexte: String
    @Guide(description: "Village ou ville de naissance, sinon chaîne vide")
    var lieu: String
}

@Generable
struct Extraction {
    @Guide(description: "Chaque personne citée dans la réponse, ou l'information sur la personne concernée")
    var personnes: [PersonneExtraite]
    @Guide(description: "Vrai seulement si la réponse dit qu'il n'y a personne (pas de frère, aucun enfant)")
    var aucun: Bool
}
#endif

/// L'IA d'Apple, sur l'iPhone. Si elle n'est pas disponible, on lit la réponse simplement.
@MainActor
final class Assistant {
    var disponible: Bool {
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability { return true }
        #endif
        return false
    }

    private let consignes = """
    Tu aides un utilisateur à construire l'arbre généalogique de sa famille, en français.
    On te donne la personne concernée, la question posée et la réponse de l'utilisateur.
    Extrais chaque personne citée avec son lien avec la personne concernée.
    Si la réponse donne la date ou le lieu de naissance de la personne concernée elle-même, utilise le lien « lui-même » et un prénom vide.
    Quand l'utilisateur dit « je », « mon », « ma », « mes », il parle de lui : la personne concernée est alors l'utilisateur.
    Recopie les dates telles qu'elles sont dites. N'invente jamais un nom, une date ou un lieu.
    """

    func proposer(reponse: String, manque: Manque?, famille: Famille, origine: Origine = .entretien) async -> Resultat {
        var extraits: [Extrait] = []
        var aucun = false
        var compris = false
        #if canImport(FoundationModels)
        if disponible {
            do {
                let session = LanguageModelSession(instructions: consignes)
                let sujetID = manque?.personne ?? famille.moiID
                let sujet = sujetID.flatMap { famille.personne($0) }
                let estMoi = sujetID == famille.moiID
                let question = manque.map { texte($0, famille: famille) } ?? "Qui veux-tu ajouter à l'arbre ?"
                let presentation = estMoi ? "l'utilisateur lui-même (\(sujet?.prenom ?? ""))"
                    : "\(sujet?.prenom ?? "inconnu"), \(famille.lienAvecMoi(sujetID!)) de l'utilisateur"
                let source = origine == .document ? "Texte lu sur un document de famille" : "Réponse de l'utilisateur"
                let prompt = """
                Personne concernée : \(presentation).
                Question posée : « \(question) »
                \(source) : « \(reponse) »
                """
                let r = try await session.respond(to: prompt, generating: Extraction.self).content
                extraits = r.personnes.map {
                    Extrait(prenom: $0.prenom, nom: $0.nom, lien: $0.lien, sexe: $0.sexe, dateTexte: $0.dateTexte, lieu: $0.lieu)
                }
                aucun = r.aucun
                compris = true
            } catch {
                compris = false
            }
        }
        #endif
        if !compris {
            let s = extraitsSimples(reponse: reponse, manque: manque)
            extraits = s.extraits
            aucun = s.aucun
        }
        return construireProposition(extraits: extraits, aucun: aucun, manque: manque, famille: famille, origine: origine)
    }
}
