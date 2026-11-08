import XCTest
@testable import ArbreCore

/// Petite famille de test : moi, père, mère, grand-mère paternelle.
private func familleTest() -> (Famille, moi: Personne, pere: Personne, mere: Personne, gm: Personne) {
    let moi = Personne(prenom: "Fayadhu", sexe: .homme)
    let pere = Personne(prenom: "Ahamada", sexe: .homme, naissance: DateFloue(annee: 1958, precision: .vers))
    let mere = Personne(prenom: "Zaharia", sexe: .femme)
    let gm = Personne(prenom: "Mariama", sexe: .femme)
    var f = Famille(moiID: moi.id)
    [moi, pere, mere, gm].forEach { f.ajouter($0) }
    f.lierParent(pere.id, enfant: moi.id)
    f.lierParent(mere.id, enfant: moi.id)
    f.lierCouple(pere.id, mere.id)
    f.lierParent(gm.id, enfant: pere.id)
    return (f, moi, pere, mere, gm)
}

final class DateFloueTests: XCTestCase {
    func testCoreLoads() { XCTAssertEqual(ArbreCore.version, "1.0") }

    func testLibelles() {
        XCTAssertEqual(DateFloue(jour: 12, mois: 3, annee: 1985, precision: .exacte).libelle, "12 mars 1985")
        XCTAssertEqual(DateFloue(annee: 1958, precision: .annee).libelle, "1958")
        XCTAssertEqual(DateFloue(annee: 1958, precision: .vers).libelle, "vers 1958")
        XCTAssertEqual(DateFloue(annee: 1950, precision: .avant).libelle, "avant 1950")
        XCTAssertEqual(DateFloue(annee: 1960, precision: .apres).libelle, "après 1960")
        XCTAssertEqual(DateFloue.inconnue.libelle, "date inconnue")
    }

    func testDepuisTexte() {
        XCTAssertEqual(DateFloue.depuis(texte: "En 1958, je crois"), DateFloue(annee: 1958, precision: .vers))
        XCTAssertEqual(DateFloue.depuis(texte: "1958"), DateFloue(annee: 1958, precision: .annee))
        XCTAssertEqual(DateFloue.depuis(texte: "le 12 mars 1985"), DateFloue(jour: 12, mois: 3, annee: 1985, precision: .exacte))
        XCTAssertEqual(DateFloue.depuis(texte: "avant 1950"), DateFloue(annee: 1950, precision: .avant))
        XCTAssertEqual(DateFloue.depuis(texte: "les années 50"), DateFloue(annee: 1955, precision: .vers))
        XCTAssertEqual(DateFloue.depuis(texte: "1958 ou 1959"), DateFloue(annee: 1958, precision: .vers))
        XCTAssertEqual(DateFloue.depuis(texte: "je sais pas"), .inconnue)
        XCTAssertEqual(DateFloue.depuis(texte: ""), .inconnue)
    }
}

final class FamilleTests: XCTestCase {
    func testBranches() {
        let (f, moi, pere, mere, gm) = familleTest()
        XCTAssertEqual(f.branche(de: moi.id), .moi)
        XCTAssertEqual(f.branche(de: pere.id), .pere)
        XCTAssertEqual(f.branche(de: gm.id), .pere)
        XCTAssertEqual(f.branche(de: mere.id), .mere)
    }

    func testUncleIsFatherSide() {
        var (f, _, _, _, gm) = familleTest()
        let oncle = Personne(prenom: "Abdou", sexe: .homme)
        f.ajouter(oncle)
        f.lierParent(gm.id, enfant: oncle.id)
        XCTAssertEqual(f.branche(de: oncle.id), .pere)
    }

    func testGenerations() {
        let (f, moi, pere, mere, gm) = familleTest()
        XCTAssertEqual(f.generation(de: moi.id), 0)
        XCTAssertEqual(f.generation(de: pere.id), -1)
        XCTAssertEqual(f.generation(de: mere.id), -1)
        XCTAssertEqual(f.generation(de: gm.id), -2)
        XCTAssertEqual(f.nombreGenerations, 3)
    }

    func testFreresEtSoeursShareAParent() {
        var (f, moi, pere, _, _) = familleTest()
        let soeur = Personne(prenom: "Anli", sexe: .femme)
        f.ajouter(soeur)
        f.lierParent(pere.id, enfant: soeur.id)
        XCTAssertEqual(f.freresEtSoeurs(de: moi.id).map(\.id), [soeur.id])
    }

    func testLierParentIsIdempotent() {
        var (f, moi, pere, _, _) = familleTest()
        f.lierParent(pere.id, enfant: moi.id)
        XCTAssertEqual(f.parents(de: moi.id).count, 2)
    }

    func testFindMatchingIgnoresCaseAndAccents() {
        var (f, _, _, mere, _) = familleTest()
        XCTAssertEqual(f.trouver(prenom: "zaharia")?.id, mere.id)
        let said = Personne(prenom: "Saïd")
        f.ajouter(said)
        XCTAssertEqual(f.trouver(prenom: "Said")?.id, said.id)
        XCTAssertNil(f.trouver(prenom: "Inconnu"))
    }

    func testParente() {
        var (f, moi, pere, mere, gm) = familleTest()
        XCTAssertEqual(f.parente(de: moi.id), "Moi")
        XCTAssertEqual(f.parente(de: pere.id), "Papa")
        XCTAssertEqual(f.parente(de: mere.id), "Maman")
        XCTAssertEqual(f.parente(de: gm.id), "Grand-mère paternelle")
        let oncle = Personne(prenom: "Abdou", sexe: .homme)
        f = ajouterProche(oncle, a: pere.id, lien: .fratrie, famille: f)
        XCTAssertEqual(f.parente(de: oncle.id), "Oncle")
        let cousine = Personne(prenom: "Anfiati", sexe: .femme)
        f = ajouterProche(cousine, a: oncle.id, lien: .enfant, famille: f)
        XCTAssertEqual(f.parente(de: cousine.id), "Cousine")
        let soeur = Personne(prenom: "Anli", sexe: .femme)
        f = ajouterProche(soeur, a: moi.id, lien: .fratrie, famille: f)
        let neveu = Personne(prenom: "Ali", sexe: .homme)
        f = ajouterProche(neveu, a: soeur.id, lien: .enfant, famille: f)
        XCTAssertEqual(f.parente(de: neveu.id), "Neveu")
    }

    func testSecondWifeHalfSisterAndStepMother() {
        var (f, moi, pere, _, _) = familleTest()
        let epouse2 = Personne(prenom: "Halima", sexe: .femme)
        f = ajouterProche(epouse2, a: pere.id, lien: .conjoint, famille: f)
        XCTAssertEqual(f.conjoints(de: pere.id).count, 2)
        XCTAssertEqual(f.parente(de: epouse2.id), "Belle-mère")
        let demi = Personne(prenom: "Faouzia", sexe: .femme)
        f = ajouterProche(demi, a: pere.id, lien: .enfant, famille: f, parentsChoisis: [epouse2.id])
        XCTAssertEqual(Set(f.parents(de: demi.id).map(\.id)), [pere.id, epouse2.id])
        XCTAssertEqual(f.parente(de: demi.id), "Demi-sœur")
        let demiFrere = Personne(prenom: "Said", sexe: .homme)
        f = ajouterProche(demiFrere, a: moi.id, lien: .fratrie, famille: f, parentsChoisis: [pere.id])
        XCTAssertEqual(f.parente(de: demiFrere.id), "Demi-frère")
    }
}

final class DispositionTests: XCTestCase {
    func testParentsAboveChild() {
        let (f, moi, pere, _, _) = familleTest()
        let r = disposer(f)
        let yMoi = r.noeuds.first { $0.id == moi.id }!.y
        let yPere = r.noeuds.first { $0.id == pere.id }!.y
        XCTAssertEqual(yMoi - yPere, 130, accuracy: 0.001)
    }

    func testMissingParentsGetPlaceholders() {
        let (f, _, _, mere, _) = familleTest()
        let r = disposer(f)
        let aTrouver = r.noeuds.filter { $0.pour == mere.id }
        XCTAssertEqual(aTrouver.count, 2)
        XCTAssertTrue(aTrouver.allSatisfy { $0.aCompleter && $0.libelle == "À trouver" && $0.id == nil })
    }

    func testNoOverlapInARow() {
        let (f, _, _, _, _) = familleTest()
        let r = disposer(f)
        for (_, ligne) in Dictionary(grouping: r.noeuds, by: { $0.y }) {
            let xs = ligne.map(\.x).sorted()
            for (a, b) in zip(xs, xs.dropFirst()) { XCTAssertGreaterThanOrEqual(b - a, 84) }
        }
    }

    func testCoupleWithMissingPersonDoesNotCrash() {
        var (f, moi, _, _, _) = familleTest()
        f.couples.append(Couple(a: moi.id, b: UUID()))
        XCTAssertFalse(disposer(f).noeuds.isEmpty)
    }

    func testThreeWivesAroundHusbandWithChildrenUnderEachMother() {
        let h = Personne(prenom: "Ahamada", sexe: .homme)
        var f = Famille(moiID: h.id)
        f.ajouter(h)
        var epouses: [Personne] = []
        var enfants: [Personne] = []
        for nom in ["Zaharia", "Halima", "Echati"] {
            let e = Personne(prenom: nom, sexe: .femme)
            f = ajouterProche(e, a: h.id, lien: .conjoint, famille: f)
            let enfant = Personne(prenom: "Enfant de \(nom)")
            f = ajouterProche(enfant, a: h.id, lien: .enfant, famille: f, parentsChoisis: [e.id])
            epouses.append(e); enfants.append(enfant)
        }
        let r = disposer(f)
        func x(_ p: Personne) -> Double { r.noeuds.first { $0.id == p.id }!.x }
        XCTAssertLessThan(x(epouses[0]), x(h))
        XCTAssertLessThan(x(h), x(epouses[1]))
        XCTAssertLessThan(x(epouses[1]), x(epouses[2]))
        XCTAssertLessThan(x(enfants[0]), x(enfants[1]))
        XCTAssertLessThan(x(enfants[1]), x(enfants[2]))
        for (_, ligne) in Dictionary(grouping: r.noeuds, by: { $0.y }) {
            let xs = ligne.map(\.x).sorted()
            for (a, b) in zip(xs, xs.dropFirst()) { XCTAssertGreaterThanOrEqual(b - a, 84) }
        }
    }

    func testCoupleIsAdjacent() {
        let (f, _, pere, mere, _) = familleTest()
        let r = disposer(f)
        let p = r.noeuds.first { $0.id == pere.id }!, m = r.noeuds.first { $0.id == mere.id }!
        XCTAssertEqual(p.y, m.y)
        XCTAssertLessThan(abs(p.x - m.x), 84 * 1.2)
        XCTAssertGreaterThan(p.x, m.x, "le père est à droite, la mère à gauche")
    }
}

final class ProchaineQuestionTests: XCTestCase {
    func testEmptyFamilyAsksMyParentsFirst() {
        let moi = Personne(prenom: "Fayadhu", sexe: .homme)
        var f = Famille(moiID: moi.id)
        f.ajouter(moi)
        let m = manques(f, enAttente: [])
        XCTAssertEqual(m.first, Manque(personne: moi.id, sujet: .parents))
        XCTAssertEqual(texte(m.first!, famille: f), "Comment s'appellent tes parents ?")
    }

    func testPostponedComesLastAndTreatedDisappears() {
        let (f, moi, _, _, _) = familleTest()
        let premier = manques(f, enAttente: []).first!
        let suite = manques(f, enAttente: [premier])
        XCTAssertEqual(suite.last, premier)
        let freres = Manque(personne: moi.id, sujet: .freresSoeurs)
        XCTAssertFalse(manques(f, enAttente: [], traites: [freres]).contains(freres))
    }

    func testMessageListsQuestionsInFrench() {
        let (f, _, _, _, gm) = familleTest()
        let liste = [Manque(personne: gm.id, sujet: .grandsParents), Manque(personne: gm.id, sujet: .lieuNaissance)]
        let msg = messageQuestions(pour: gm, manques: liste, famille: f)
        XCTAssertTrue(msg.hasPrefix("Bonjour ! Je construis l'arbre de la famille."))
        XCTAssertTrue(msg.contains("Qui sont les parents de Mariama ?"))
        XCTAssertTrue(msg.contains("Dans quel village est née Mariama ?"))
    }
}

final class ObjectifTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Indian/Mayotte")!
        return c
    }()

    func date(_ j: Int, _ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: j, hour: h, minute: m))!
    }

    func famille(ajouts: [Date]) -> Famille {
        let moi = Personne(prenom: "Moi", ajouteeLe: date(1, 8))
        var f = Famille(moiID: moi.id)
        f.ajouter(moi)
        for d in ajouts { f.ajouter(Personne(prenom: "P", ajouteeLe: d)) }
        return f
    }

    func testCountsByLocalDay() {
        let f = famille(ajouts: [date(8, 23, 59), date(9, 0, 1)])
        XCTAssertEqual(Objectif().ajoutsDuJour(f, le: date(8, 12), calendrier: cal).count, 1)
        XCTAssertEqual(Objectif().ajoutsDuJour(f, le: date(9, 12), calendrier: cal).count, 1)
    }

    func testSerieAndRecord() {
        let jours = [5, 6, 7].flatMap { j in (0..<5).map { date(j, 10, $0) } } + (0..<4).map { date(8, 10, $0) }
        let f = famille(ajouts: jours)
        let o = Objectif()
        XCTAssertEqual(o.serie(f, jusquau: date(8, 20), calendrier: cal), 3, "aujourd'hui pas fini ne casse pas la série")
        XCTAssertEqual(o.serie(f, jusquau: date(9, 20), calendrier: cal), 0, "un jour à 4 casse la série")
        XCTAssertEqual(o.record(f, calendrier: cal), 3)
    }
}

final class StockageTests: XCTestCase {
    func dossier() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func testRoundTrip() throws {
        let s = Stockage(dossier: dossier())
        XCTAssertEqual(try s.charger(), Sauvegarde())
        let (f, moi, _, _, _) = familleTest()
        let sv = Sauvegarde(famille: f, enAttente: [Manque(personne: moi.id, sujet: .enfants)])
        try s.enregistrer(sv)
        XCTAssertEqual(try s.charger().famille.personnes.count, 4)
        XCTAssertEqual(try s.charger().enAttente, sv.enAttente)
    }

    func testBadImports() throws {
        XCTAssertThrowsError(try Stockage.importer(Data("n'importe quoi".utf8))) {
            XCTAssertEqual($0 as? ErreurStockage, .fichierIllisible)
        }
        XCTAssertThrowsError(try Stockage.importer(Data(#"{"version":99}"#.utf8))) {
            XCTAssertEqual($0 as? ErreurStockage, .versionInconnue(99))
        }
        let s = Stockage(dossier: dossier())
        let (f, _, _, _, _) = familleTest()
        try s.enregistrer(Sauvegarde(famille: f))
        _ = try? Stockage.importer(Data("abîmé".utf8))
        XCTAssertEqual(try s.charger().famille, f, "un import raté ne touche pas l'arbre")
    }
}

final class PropositionTests: XCTestCase {
    func testParentsAnswerCreatesBothParentsAsCouple() {
        let moi = Personne(prenom: "Fayadhu", sexe: .homme)
        var f = Famille(moiID: moi.id)
        f.ajouter(moi)
        let m = Manque(personne: moi.id, sujet: .parents)
        let r = construireProposition(extraits: [
            Extrait(prenom: "Ahamada", lien: "père", dateTexte: "vers 1958"),
            Extrait(prenom: "Zaharia", lien: "mère")
        ], aucun: false, manque: m, famille: f)
        XCTAssertEqual(r.famille.parents(de: moi.id).count, 2)
        XCTAssertEqual(r.famille.pere(de: moi.id)?.naissance, DateFloue(annee: 1958, precision: .vers))
        XCTAssertEqual(r.famille.couples.count, 1)
        XCTAssertEqual(r.touchees.filter(\.nouvelle).count, 2)
        XCTAssertEqual(f.personnes.count, 1, "la famille d'origine n'est pas modifiée")
    }

    func testSameNameTwiceIsNotDuplicated() {
        let (f, moi, _, mere, _) = familleTest()
        let r = construireProposition(extraits: [Extrait(prenom: "zaharia", lien: "mère")], aucun: false,
                                      manque: Manque(personne: moi.id, sujet: .parents), famille: f)
        XCTAssertEqual(r.famille.personnes.count, f.personnes.count)
        XCTAssertEqual(r.touchees.first?.id, mere.id)
        XCTAssertEqual(r.touchees.first?.nouvelle, false)
    }

    func testSelfInfoUpdatesSubject() {
        let (f, _, _, _, gm) = familleTest()
        let r = construireProposition(extraits: [Extrait(lien: "lui-même", lieu: "bandraboua")], aucun: false,
                                      manque: Manque(personne: gm.id, sujet: .lieuNaissance), famille: f)
        XCTAssertEqual(r.famille.personne(gm.id)?.lieuNaissance, "Bandraboua")
    }

    func testNoSiblingsMarksQuestionTreated() {
        let (f, moi, _, _, _) = familleTest()
        let m = Manque(personne: moi.id, sujet: .freresSoeurs)
        let s = extraitsSimples(reponse: "Non, aucun", manque: m)
        let r = construireProposition(extraits: s.extraits, aucun: s.aucun, manque: m, famille: f)
        XCTAssertEqual(r.traite, m)
    }

    func testSimpleParsingOfParents() {
        let s = extraitsSimples(reponse: "Mon père s'appelle Ahamada et ma mère Zaharia", manque: Manque(personne: nil, sujet: .parents))
        XCTAssertEqual(s.extraits.map(\.prenom), ["Ahamada", "Zaharia"])
        XCTAssertEqual(s.extraits.map(\.lien), ["père", "mère"])
    }
}

final class AjoutTests: XCTestCase {
    func testAddMotherCouplesParents() {
        let moi = Personne(prenom: "Fayadhu", sexe: .homme)
        let pere = Personne(prenom: "Ahamada", sexe: .homme)
        var f = Famille(moiID: moi.id)
        f.ajouter(moi); f.ajouter(pere)
        f.lierParent(pere.id, enfant: moi.id)
        let mere = Personne(prenom: "Zaharia", sexe: .femme)
        let g = ajouterProche(mere, a: moi.id, lien: .mere, famille: f)
        XCTAssertEqual(g.mere(de: moi.id)?.id, mere.id)
        XCTAssertEqual(g.couples.count, 1)
    }

    func testSiblingSharesParentsAndChildGetsSpouse() {
        let (f, moi, pere, mere, _) = familleTest()
        let soeur = Personne(prenom: "Anli", sexe: .femme)
        let g = ajouterProche(soeur, a: moi.id, lien: .fratrie, famille: f)
        XCTAssertEqual(Set(g.parents(de: soeur.id).map(\.id)), [pere.id, mere.id])
        let epouse = Personne(prenom: "Nadia", sexe: .femme)
        let enfant = Personne(prenom: "Amina", sexe: .femme)
        let h = ajouterProche(enfant, a: moi.id, lien: .enfant, famille: ajouterProche(epouse, a: moi.id, lien: .conjoint, famille: g))
        XCTAssertEqual(Set(h.parents(de: enfant.id).map(\.id)), [moi.id, epouse.id])
    }

    func testHomonymIsKeptAsNewPerson() {
        let (f, moi, _, _, _) = familleTest()
        let autre = Personne(prenom: "Ahamada", sexe: .homme)
        let g = ajouterProche(autre, a: moi.id, lien: .fratrie, famille: f)
        XCTAssertEqual(g.personnes.count, f.personnes.count + 1)
    }
}

final class AffichageTests: XCTestCase {
    func testBirthDateIsNeverAsked() {
        let (f, _, _, _, _) = familleTest()
        XCTAssertFalse(manques(f, enAttente: []).contains { $0.sujet == .dateNaissance || $0.sujet == .lieuNaissance },
                       "ni la date ni le village de naissance ne sont demandés")
    }

    func testInitialsUseFirstAndLastName() {
        XCTAssertEqual(Personne(prenom: "Fayadhu", nom: "Ahamada").initiales, "FA")
        XCTAssertEqual(Personne(prenom: "Mariama").initiales, "MA")
    }
}

final class TraitsTests: XCTestCase {
    func testLineFromSingleParentStartsBelowHisName() {
        let (f0, moi, _, _, _) = familleTest()
        let enfant = Personne(prenom: "Insya", nom: "Ahamada", sexe: .femme)
        let f = ajouterProche(enfant, a: moi.id, lien: .enfant, famille: f0)
        let r = disposer(f, largeurNoeud: 104, ecartGeneration: 150)
        let m = r.noeuds.first { $0.id == moi.id }!
        let descendants = r.traits.filter { $0.de.0 == m.x && $0.a.1 > $0.de.1 && $0.de.1 >= m.y && $0.de.1 < m.y + 150 }
        XCTAssertFalse(descendants.isEmpty)
        XCTAssertTrue(descendants.allSatisfy { $0.de.1 >= m.y + 85 }, "aucun trait ne traverse le prénom et le nom")
    }
}

final class AllianceTests: XCTestCase {
    func testDifferentLastNameMeansHalfSibling() {
        var (f, moi, _, _, _) = familleTest()
        f.personnes[f.personnes.firstIndex { $0.id == moi.id }!].nom = "Ahamada"
        let fayna = Personne(prenom: "Fayna", nom: "Palmeya", sexe: .femme)
        f = ajouterProche(fayna, a: moi.id, lien: .fratrie, famille: f)
        XCTAssertEqual(f.parente(de: fayna.id), "Demi-sœur")
        let ben = Personne(prenom: "Ben Anli", nom: "AHAMADA", sexe: .homme)
        f = ajouterProche(ben, a: moi.id, lien: .fratrie, famille: f)
        XCTAssertEqual(f.parente(de: ben.id), "Frère")
    }

    func testMarriedInPeopleAreNotFamily() {
        var (f, moi, pere, _, gm) = familleTest()
        let oncle = Personne(prenom: "Abdou", sexe: .homme)
        f = ajouterProche(oncle, a: pere.id, lien: .fratrie, famille: f)
        let tante = Personne(prenom: "Mouna", sexe: .femme)
        f = ajouterProche(tante, a: oncle.id, lien: .conjoint, famille: f)
        XCTAssertEqual(f.parente(de: tante.id), "Tante par alliance")
        XCTAssertFalse(f.estDeLaFamille(tante.id))
        let epouse = Personne(prenom: "Nadia", sexe: .femme)
        f = ajouterProche(epouse, a: moi.id, lien: .conjoint, famille: f)
        XCTAssertFalse(f.estDeLaFamille(epouse.id))
        XCTAssertTrue(f.estDeLaFamille(oncle.id))
        XCTAssertTrue(f.estDeLaFamille(gm.id))
    }
}

final class EnfantsCommunsTests: XCTestCase {
    func testSecondWifeTakesHerChildrenFromFirstWife() {
        var (f, _, pere, mere, _) = familleTest()
        let fayna = Personne(prenom: "Fayna", sexe: .femme)
        f = ajouterProche(fayna, a: pere.id, lien: .enfant, famille: f)
        XCTAssertEqual(Set(f.parents(de: fayna.id).map(\.id)), [pere.id, mere.id], "lié d'office à la seule épouse")
        let halima = Personne(prenom: "Halima", sexe: .femme)
        f = ajouterProche(halima, a: pere.id, lien: .conjoint, famille: f)
        f = definirEnfantsCommuns(pere.id, avec: halima.id, enfants: [fayna.id], famille: f)
        XCTAssertEqual(Set(f.parents(de: fayna.id).map(\.id)), [pere.id, halima.id])
        f = definirEnfantsCommuns(pere.id, avec: halima.id, enfants: [], famille: f)
        XCTAssertEqual(f.parents(de: fayna.id).map(\.id), [pere.id])
    }
}

/// Vérifie qu'aucun trait ne passe dans la zone du prénom, du nom et de la parenté d'une personne.
private func traitsTraversantUnNom(_ r: (noeuds: [Noeud], traits: [Trait], taille: (Double, Double)), demiLargeur: Double = 52) -> [String] {
    var fautes: [String] = []
    for t in r.traits {
        let (x1, y1) = t.de, (x2, y2) = t.a
        for n in r.noeuds {
            let gauche = n.x - demiLargeur, droite = n.x + demiLargeur, haut = n.y + 30, bas = n.y + 84
            let horizontal = abs(y1 - y2) < 0.01
            let coupe = horizontal
                ? (y1 > haut && y1 < bas && max(x1, x2) > gauche && min(x1, x2) < droite)
                : (x1 > gauche && x1 < droite && max(y1, y2) > haut && min(y1, y2) < bas)
            if coupe { fautes.append(n.libelle) }
        }
    }
    return fautes
}

final class TraitsNomsTests: XCTestCase {
    func testWomanWithThreeHusbandsNoLineThroughNames() {
        var (f, moi, pere, mere, _) = familleTest()
        for (nom, enfant) in [("Antoissi", "Chamouine"), ("Mohamadi", "Fayna")] {
            let mari = Personne(prenom: nom, sexe: .homme)
            f = ajouterProche(mari, a: mere.id, lien: .conjoint, famille: f)
            f = ajouterProche(Personne(prenom: enfant, sexe: .femme), a: mere.id, lien: .enfant, famille: f, parentsChoisis: [mari.id])
        }
        f = ajouterProche(Personne(prenom: "Ben", sexe: .homme), a: moi.id, lien: .fratrie, famille: f, parentsChoisis: [pere.id, mere.id])
        f = ajouterProche(Personne(prenom: "Azzam", sexe: .homme), a: moi.id, lien: .enfant, famille: f)
        let r = disposer(f, largeurNoeud: 104, ecartGeneration: 150)
        XCTAssertEqual(traitsTraversantUnNom(r), [])
    }

    func testThreeWivesNoLineThroughNames() {
        let h = Personne(prenom: "Ahamada", sexe: .homme)
        var f = Famille(moiID: h.id)
        f.ajouter(h)
        for nom in ["Zaharia", "Halima", "Echati"] {
            let e = Personne(prenom: nom, sexe: .femme)
            f = ajouterProche(e, a: h.id, lien: .conjoint, famille: f)
            for i in 1...2 { f = ajouterProche(Personne(prenom: "\(nom) \(i)"), a: h.id, lien: .enfant, famille: f, parentsChoisis: [e.id]) }
        }
        let r = disposer(f, largeurNoeud: 104, ecartGeneration: 150)
        XCTAssertEqual(traitsTraversantUnNom(r), [])
    }
}

final class FratriesGroupeesTests: XCTestCase {
    func testChildrenOfSameCoupleStayTogetherWhateverTheOrderOfEntry() {
        var (f, moi, _, mere, _) = familleTest()
        let antoissi = Personne(prenom: "Antoissi", sexe: .homme)
        let mohamadi = Personne(prenom: "Mohamadi", sexe: .homme)
        f = ajouterProche(antoissi, a: mere.id, lien: .conjoint, famille: f)
        f = ajouterProche(mohamadi, a: mere.id, lien: .conjoint, famille: f)
        let fayna = Personne(prenom: "Fayna", sexe: .femme)
        let chamouine = Personne(prenom: "Chamouine", sexe: .homme)
        let fainouni = Personne(prenom: "Fainouni", sexe: .homme)
        f = ajouterProche(fayna, a: mere.id, lien: .enfant, famille: f, parentsChoisis: [mohamadi.id])
        f = ajouterProche(chamouine, a: mere.id, lien: .enfant, famille: f, parentsChoisis: [antoissi.id])
        f = ajouterProche(fainouni, a: mere.id, lien: .enfant, famille: f, parentsChoisis: [mohamadi.id])
        let r = disposer(f, largeurNoeud: 104, ecartGeneration: 150)
        let ligne = r.noeuds.filter { $0.y == r.noeuds.first { $0.id == moi.id }!.y }.sorted { $0.x < $1.x }.compactMap(\.id)
        let i = ligne.firstIndex(of: fayna.id)!, j = ligne.firstIndex(of: fainouni.id)!
        XCTAssertEqual(abs(i - j), 1, "Fayna et Fainouni, enfants du même couple, sont côte à côte")
        XCTAssertEqual(traitsTraversantUnNom(r), [])
    }
}

/// Deux traits qui se croisent vraiment (pas un simple raccord en T ou en coin).
private func croisements(_ traits: [Trait]) -> Int {
    let e = 0.01
    let h = traits.filter { abs($0.de.1 - $0.a.1) < e && abs($0.de.0 - $0.a.0) > e }
    let v = traits.filter { abs($0.de.0 - $0.a.0) < e && abs($0.de.1 - $0.a.1) > e }
    var n = 0
    for a in h {
        let x1 = min(a.de.0, a.a.0), x2 = max(a.de.0, a.a.0), y = a.de.1
        for b in v {
            let y1 = min(b.de.1, b.a.1), y2 = max(b.de.1, b.a.1), x = b.de.0
            if x > x1 + e && x < x2 - e && y > y1 + e && y < y2 - e { n += 1 }
        }
    }
    return n
}

final class CroisementsTests: XCTestCase {
    /// L'arbre de la capture : mère avec trois maris, enfants de chaque couple, moi marié avec enfants.
    func testRealFamilyHasNoCrossingLines() {
        var (f, moi, pere, mere, _) = familleTest()
        let fatuma = Personne(prenom: "Fatuma", nom: "Issoufi", sexe: .femme)
        f = ajouterProche(fatuma, a: moi.id, lien: .conjoint, famille: f)
        for n in ["Nassem", "Azzam", "Annaelle"] { f = ajouterProche(Personne(prenom: n, nom: "Ahamada"), a: moi.id, lien: .enfant, famille: f) }
        f = ajouterProche(Personne(prenom: "Ben Anli", nom: "Ahamada", sexe: .homme), a: moi.id, lien: .fratrie, famille: f, parentsChoisis: [pere.id, mere.id])
        let antoissi = Personne(prenom: "Antoissi", sexe: .homme), mohamadi = Personne(prenom: "Mohamadi", nom: "Palmeya", sexe: .homme)
        f = ajouterProche(antoissi, a: mere.id, lien: .conjoint, famille: f)
        f = ajouterProche(mohamadi, a: mere.id, lien: .conjoint, famille: f)
        f = ajouterProche(Personne(prenom: "Fayna", nom: "Palmeya"), a: mere.id, lien: .enfant, famille: f, parentsChoisis: [mohamadi.id])
        f = ajouterProche(Personne(prenom: "Chamouine", nom: "Antoissi"), a: mere.id, lien: .enfant, famille: f, parentsChoisis: [antoissi.id])
        f = ajouterProche(Personne(prenom: "Fainouni", nom: "Palmeya"), a: mere.id, lien: .enfant, famille: f, parentsChoisis: [mohamadi.id])
        let tante = Personne(prenom: "Mouhaza", nom: "Matoir", sexe: .femme)
        f = ajouterProche(tante, a: mere.id, lien: .fratrie, famille: f)
        let r = disposer(f, largeurNoeud: 104, ecartGeneration: 150)
        XCTAssertEqual(croisements(r.traits), 0, "aucun trait ne doit en croiser un autre")
        XCTAssertEqual(traitsTraversantUnNom(r), [])
    }

    func testThreeWivesHasNoCrossingLines() {
        let h = Personne(prenom: "Ahamada", sexe: .homme)
        var f = Famille(moiID: h.id)
        f.ajouter(h)
        for nom in ["Zaharia", "Halima", "Echati"] {
            let e = Personne(prenom: nom, sexe: .femme)
            f = ajouterProche(e, a: h.id, lien: .conjoint, famille: f)
            for i in 1...3 { f = ajouterProche(Personne(prenom: "\(nom) \(i)"), a: h.id, lien: .enfant, famille: f, parentsChoisis: [e.id]) }
        }
        let r = disposer(f, largeurNoeud: 104, ecartGeneration: 150)
        XCTAssertEqual(croisements(r.traits), 0)
        XCTAssertEqual(traitsTraversantUnNom(r), [])
    }
}

final class CouleursTests: XCTestCase {
    func testEachCoupleHasItsOwnColor() {
        var (f, _, pere, mere, _) = familleTest()
        let halima = Personne(prenom: "Halima", sexe: .femme)
        f = ajouterProche(halima, a: pere.id, lien: .conjoint, famille: f)
        let demi = Personne(prenom: "Faouzia", sexe: .femme)
        f = ajouterProche(demi, a: pere.id, lien: .enfant, famille: f, parentsChoisis: [halima.id])
        let r = disposer(f, largeurNoeud: 104, ecartGeneration: 150)
        let p = r.noeuds.first { $0.id == pere.id }!, m = r.noeuds.first { $0.id == mere.id }!, d = r.noeuds.first { $0.id == demi.id }!
        let coupleAvecMere = r.traits.first { $0.de.1 == p.y && $0.a.1 == p.y && Set([$0.de.0, $0.a.0]) == Set([p.x, m.x]) }!.groupe
        let versDemi = r.traits.first { $0.de.0 == d.x && $0.a.1 == d.y }!.groupe
        XCTAssertNotEqual(coupleAvecMere, versDemi, "les deux couples du père ont des couleurs différentes")
        XCTAssertGreaterThanOrEqual(Set(r.traits.map(\.groupe)).count, 3)
    }
}

final class CouleurCoupleTests: XCTestCase {
    func testChildrenLinkedToOneSpouseShareTheCoupleColor() {
        var (f, moi, _, _, _) = familleTest()
        let insya = Personne(prenom: "Insya", nom: "Ahamada", sexe: .femme)
        f = ajouterProche(insya, a: moi.id, lien: .enfant, famille: f)          // ajoutée avant l'épouse : un seul parent
        let fatuma = Personne(prenom: "Fatuma", nom: "Issoufi", sexe: .femme)
        f = ajouterProche(fatuma, a: moi.id, lien: .conjoint, famille: f)
        let r = disposer(f, largeurNoeud: 104, ecartGeneration: 150)
        let m = r.noeuds.first { $0.id == moi.id }!, e = r.noeuds.first { $0.id == fatuma.id }!, i = r.noeuds.first { $0.id == insya.id }!
        let couple = r.traits.first { $0.de.1 == m.y && $0.a.1 == m.y && Set([$0.de.0, $0.a.0]) == Set([m.x, e.x]) }!.groupe
        let versInsya = r.traits.first { $0.de.0 == i.x && $0.a.1 == i.y }!.groupe
        XCTAssertEqual(couple, versInsya, "le trait du couple et ceux de ses enfants ont la même couleur")
    }
}

final class CotesTests: XCTestCase {
    func testFatherSideIsOnTheRightMotherSideOnTheLeft() {
        var (f, moi, pere, mere, gm) = familleTest()
        let gmMat = Personne(prenom: "Mariama", sexe: .femme)
        f = ajouterProche(gmMat, a: mere.id, lien: .mere, famille: f)
        let r = disposer(f, largeurNoeud: 104, ecartGeneration: 150)
        func x(_ p: Personne) -> Double { r.noeuds.first { $0.id == p.id }!.x }
        XCTAssertGreaterThan(x(pere), x(mere))
        XCTAssertGreaterThan(x(gm), x(gmMat), "la grand-mère paternelle est à droite de la grand-mère maternelle")
        _ = moi
    }
}

final class CotePaternelTests: XCTestCase {
    func testPaternalUncleWithoutChildrenStaysOnTheRightNextToFather() {
        var (f, moi, pere, mere, gm) = familleTest()
        let gp = Personne(prenom: "Anli", sexe: .homme)
        f = ajouterProche(gp, a: pere.id, lien: .pere, famille: f)
        let gpMat = Personne(prenom: "Matoir", sexe: .homme), gmMat = Personne(prenom: "Fatima", sexe: .femme)
        f = ajouterProche(gpMat, a: mere.id, lien: .pere, famille: f)
        f = ajouterProche(gmMat, a: mere.id, lien: .mere, famille: f)
        for n in ["Mouhaza", "Hamidati", "Bahassani", "Kahissi"] {
            f = ajouterProche(Personne(prenom: n, sexe: .femme), a: mere.id, lien: .fratrie, famille: f)
        }
        let idrissa = Personne(prenom: "Idrissa", sexe: .homme)
        f = ajouterProche(idrissa, a: pere.id, lien: .fratrie, famille: f)
        for (mari, enfant) in [("Antoissi", "Chamouine"), ("Mohamadi", "Fayna")] {
            let m = Personne(prenom: mari, sexe: .homme)
            f = ajouterProche(m, a: mere.id, lien: .conjoint, famille: f)
            f = ajouterProche(Personne(prenom: enfant), a: mere.id, lien: .enfant, famille: f, parentsChoisis: [m.id])
        }
        let r = disposer(f, largeurNoeud: 104, ecartGeneration: 150)
        func x(_ p: Personne) -> Double { r.noeuds.first { $0.id == p.id }!.x }
        XCTAssertGreaterThan(x(pere), x(mere), "Papa à droite de Maman, même avec ses autres maris")
        XCTAssertGreaterThan(x(idrissa), x(pere), "l'oncle paternel est du côté droit")
        XCTAssertGreaterThan(x(gm), x(gmMat), "grands-parents paternels à droite des maternels")
        XCTAssertGreaterThan(x(gp), x(gpMat))
        XCTAssertEqual(croisements(r.traits), 0)
        XCTAssertEqual(traitsTraversantUnNom(r), [])
        _ = moi
    }
}

final class FamilleVisibleTests: XCTestCase {
    func testChildrenOfOneSpouseHangFromTheCoupleLine() {
        var (f, moi, _, _, _) = familleTest()
        let insya = Personne(prenom: "Insya", nom: "Ahamada", sexe: .femme)
        f = ajouterProche(insya, a: moi.id, lien: .enfant, famille: f)
        let fatuma = Personne(prenom: "Fatuma", nom: "Issoufi", sexe: .femme)
        f = ajouterProche(fatuma, a: moi.id, lien: .conjoint, famille: f)
        let r = disposer(f, largeurNoeud: 104, ecartGeneration: 150)
        let m = r.noeuds.first { $0.id == moi.id }!, e = r.noeuds.first { $0.id == fatuma.id }!
        let milieu = (m.x + e.x) / 2
        XCTAssertTrue(r.traits.contains { abs($0.de.0 - milieu) < 0.01 && abs($0.de.1 - m.y) < 0.01 && $0.a.1 > m.y },
                      "le trait vers les enfants part du milieu du trait du couple")
        XCTAssertEqual(croisements(r.traits), 0)
        XCTAssertEqual(traitsTraversantUnNom(r), [])
    }
}

final class LectureNomsTests: XCTestCase {
    func testReadsNamesFromAWhatsAppScreenshotText() {
        let texte = """
        Issa Attoumani
        21:45
        Voici mes enfants
        1. Halimati ATTOUMANI
        2. Boina Issa ATTOUMANI
        - Kamal
        • Mouhamadi Issa ATTOUMANI
        Merci
        """
        let noms = nomsDepuisTexte(texte, nomParDefaut: "ATTOUMANI")
        XCTAssertEqual(noms.dropFirst().map(\.prenom), ["Halimati", "Boina Issa", "Kamal", "Mouhamadi Issa"])
        XCTAssertEqual(noms.dropFirst().map(\.nom), ["ATTOUMANI", "ATTOUMANI", "ATTOUMANI", "ATTOUMANI"])
        XCTAssertEqual(noms.first, NomLu(prenom: "Issa", nom: "Attoumani"))
    }
}

final class AffiliationsTests: XCTestCase {
    func testDirectLinksOfAPersonAndTheirLines() {
        let (f, moi, pere, mere, gm) = familleTest()
        XCTAssertEqual(f.lienDirect(de: gm.id, avec: pere.id), "Sa mère")
        XCTAssertEqual(f.lienDirect(de: mere.id, avec: pere.id), "Son épouse")
        XCTAssertEqual(f.lienDirect(de: moi.id, avec: pere.id), "Son fils")
        XCTAssertNil(f.lienDirect(de: gm.id, avec: moi.id))
        let r = disposer(f)
        XCTAssertTrue(r.traits.contains { $0.personnes.contains(pere.id) && $0.personnes.contains(moi.id) })
        XCTAssertTrue(r.traits.contains { Set($0.personnes) == [pere.id, mere.id] })
    }
}

final class SousFamilleTests: XCTestCase {
    func testCousinTreeShowsOnlyHisOwnLine() {
        var (f, moi, pere, mere, gm) = familleTest()
        let oncle = Personne(prenom: "Abdou", sexe: .homme)
        f = ajouterProche(oncle, a: pere.id, lien: .fratrie, famille: f)
        let tante = Personne(prenom: "Mouna", sexe: .femme)
        f = ajouterProche(tante, a: oncle.id, lien: .conjoint, famille: f)
        let cousin = Personne(prenom: "Ali", sexe: .homme)
        f = ajouterProche(cousin, a: oncle.id, lien: .enfant, famille: f)
        let s = f.sousFamille(autour: cousin.id)
        let ids = Set(s.personnes.map(\.id))
        XCTAssertTrue(ids.isSuperset(of: [cousin.id, oncle.id, tante.id, gm.id]))
        XCTAssertFalse(ids.contains(moi.id), "le cousin ne voit pas ma branche")
        XCTAssertFalse(ids.contains(mere.id))
        XCTAssertEqual(s.parente(de: oncle.id), "Papa")
        XCTAssertEqual(s.parente(de: tante.id), "Maman")
        XCTAssertEqual(s.parente(de: gm.id), "Grand-mère paternelle")
    }
}
