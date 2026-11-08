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
        XCTAssertLessThan(p.x, m.x, "le père est à gauche")
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
        XCTAssertFalse(manques(f, enAttente: []).contains { $0.sujet == .dateNaissance })
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
