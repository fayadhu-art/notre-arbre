# Notre arbre — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Native SwiftUI iOS app that builds the family tree from a French voice interview driven by Apple's on-device AI, tracks a 5-people-per-day goal, and exports the tree as a large-format PDF poster; shipped as an unsigned IPA built on GitHub Actions.

**Architecture:** All pure logic (fuzzy dates, family graph, branches, generations, layout, next question, daily goal, JSON store) lives in a local Swift package `ArbreCore`, tested with `swift test` on the macOS runner. The app target `NotreArbre` holds SwiftUI screens and the Apple framework adapters (Speech, FoundationModels, Vision, UserNotifications, PDF). The Xcode project is generated in CI by XcodeGen from `project.yml`, so no hand-written `.pbxproj`.

**Tech Stack:** Swift 6, SwiftUI (iOS 26 Liquid Glass: `glassEffect`, `.buttonStyle(.glass)`), FoundationModels, Speech (`SFSpeechRecognizer`, locale `fr-FR`, on-device), Vision (`VNRecognizeTextRequest`, `fr-FR`), UserNotifications, XcodeGen, GitHub Actions `macos-26`.

**Spec:** `docs/superpowers/specs/2026-11-08-notre-arbre-design.md`

## Global Constraints

- iOS deployment target `26.0`; iPhone only; bundle id `com.fayadhu.notrearbre`; display name `Notre arbre`.
- All UI text in French. No network calls anywhere.
- Visual reference: the validated mockup https://claude.ai/artifact/X6xTxzeXvr2fNDwh5Wvdzp — same screens, layout, copy, colors. Colors: turquoise `#0F766E`, corail `#FF7A59` (text on light: `#C2410C`), violet `#7C3AED` (text: `#6D28D9`), background `#EEF1F4` with blurred blobs `#1FB5A3`, `#FF7A59`, `#8B6CF6`, `#FFC857`. Text `#1D1D1F`, secondary `#48484A`. Font: system (SF Pro) in place of Inter.
- Branch colors: father side corail, mother side violet, the user turquoise.
- Daily goal = 5 new people. Reminder at 19:00 local if goal not reached.
- Poster title: `Famille BAZAMA`. Formats A2 (420×594 mm), A1 (594×841 mm), A0 (841×1189 mm), landscape.
- No record is saved without the user validating the AI's proposal.
- Unsigned IPA artifact named `NotreArbre-ipa`, same build method as the MaMazda repo.

## Review Focus

1. A spoken answer naming a person already in the tree ("ma mère Zaharia" twice) — expect a match on the existing record, not a duplicate. Test in Task 3 (`testFindMatchingIgnoresCaseAndAccents`).
2. Fuzzy date phrases outside the happy path ("vers les années 50", "je sais pas", "1958 ou 1959") — expect a best-effort `DateFloue` or `.inconnue`, never a crash or a blocked save. Test in Task 2.
3. Day boundary and timezone for the goal (person added at 23:59 vs 00:01, Indian/Mayotte) — expect counts per local calendar day. Test in Task 5.
4. Apple Intelligence off or model not ready — expect the interview to fall back to typed entry with a clear French message, not a dead screen. Covered in Task 8 (manual check listed).
5. Restore from a backup file written by an older build or a corrupt file — expect a French error and the current tree untouched. Test in Task 6.

---

### Task 1: Repository, project generation and CI that ships an IPA

**Files:**
- Create: `project.yml`, `.github/workflows/ipa.yml`, `.gitignore`
- Create: `NotreArbre/NotreArbreApp.swift`, `NotreArbre/Info.plist` keys via `project.yml`, `NotreArbre/Assets.xcassets/` (AppIcon placeholder, AccentColor `#0F766E`)
- Create: `ArbreCore/Package.swift`, `ArbreCore/Sources/ArbreCore/ArbreCore.swift`, `ArbreCore/Tests/ArbreCoreTests/SmokeTests.swift`

**Interfaces:**
- Produces: module `ArbreCore` importable from the app; workflow jobs `test` (runs `swift test` in `ArbreCore/`) and `build` (needs `test`, uploads `NotreArbre.ipa` as artifact `NotreArbre-ipa`).

- [ ] **Step 1:** `project.yml`: app target `NotreArbre`, platform iOS, deploymentTarget `26.0`, local package `ArbreCore`, `TARGETED_DEVICE_FAMILY: 1`, Info.plist keys `NSMicrophoneUsageDescription` = "Le micro sert à répondre aux questions de l'entretien.", `NSSpeechRecognitionUsageDescription` = "La reconnaissance vocale transforme tes réponses en texte, sur ton iPhone.", `NSCameraUsageDescription` = "L'appareil photo sert à lire un livret de famille ou un acte.", `NSPhotoLibraryUsageDescription` = "Pour choisir la photo d'un document.", `UISupportsDocumentBrowser` not needed.
- [ ] **Step 2:** Workflow on `push` and `workflow_dispatch`, `runs-on: macos-26`. Job `test`: `cd ArbreCore && swift test`. Job `build`: `brew install xcodegen`, `xcodegen generate`, pick newest Xcode as in MaMazda, `xcodebuild -project NotreArbre.xcodeproj -scheme NotreArbre -configuration Release -sdk iphoneos CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -derivedDataPath build build`, copy `NotreArbre.app` into `Payload/`, zip to `NotreArbre.ipa`, upload.
- [ ] **Step 3:** Smoke test `testCoreLoads` asserting `ArbreCore.version == "1.0"`; app shows a placeholder `Text("Notre arbre")`.
- [ ] **Step 4:** Push; Expected: both jobs green, artifact `NotreArbre-ipa` present (`gh run list`, `gh run view --log-failed` on failure).
- [ ] **Step 5:** Commit `chore: projet XcodeGen, ArbreCore et CI IPA`.

### Task 2: Fuzzy dates

**Files:** Create `ArbreCore/Sources/ArbreCore/DateFloue.swift`; Test `ArbreCore/Tests/ArbreCoreTests/DateFloueTests.swift`

**Interfaces:**
- Produces: `struct DateFloue: Codable, Hashable { var jour: Int?; var mois: Int?; var annee: Int?; var precision: Precision }`, `enum Precision: String, Codable { case exacte, annee, vers, avant, apres, inconnue }`, `static let inconnue: DateFloue`, `var libelle: String`, `static func depuis(texte: String) -> DateFloue`, `var anneeEstimee: Int?`.

- [ ] **Step 1: Failing tests** — `libelle`: `(12,3,1985,.exacte)` → "12 mars 1985"; `(nil,nil,1958,.annee)` → "1958"; `.vers 1958` → "vers 1958"; `.avant 1950` → "avant 1950"; `.apres 1960` → "après 1960"; `.inconnue` → "date inconnue". `depuis`: "En 1958, je crois" → `.vers 1958` ("je crois", "environ", "vers", "à peu près" ⇒ `.vers`); "1958" → `.annee 1958`; "le 12 mars 1985" → exacte; "avant 1950" → `.avant`; "les années 50" → `.vers 1955`; "1958 ou 1959" → `.vers 1958`; "je sais pas" → `.inconnue`; "" → `.inconnue`.
- [ ] **Step 2:** Run `swift test --filter DateFloueTests`; Expected FAIL.
- [ ] **Step 3:** Implement with regex on lowercased, accent-folded text; French month names table.
- [ ] **Step 4:** Expected PASS.
- [ ] **Step 5:** Commit `feat: dates floues`.

### Task 3: Family graph, branches, generations

**Files:** Create `ArbreCore/Sources/ArbreCore/Personne.swift`, `ArbreCore/Sources/ArbreCore/Famille.swift`; Test `FamilleTests.swift`

**Interfaces:**
- Consumes: `DateFloue`.
- Produces: `struct Personne: Codable, Identifiable, Hashable { var id: UUID; var prenom: String; var nom: String; var sexe: Sexe; var naissance: DateFloue; var lieuNaissance: String?; var deces: DateFloue?; var notes: String; var origine: Origine; var ajouteeLe: Date }`, `enum Sexe: String, Codable { case homme, femme, inconnu }`, `enum Origine: String, Codable { case entretien, document, saisie }`. `struct Famille: Codable { var personnes: [Personne]; var liensParent: [LienParent]; var couples: [Couple]; var moiID: UUID? }` with `LienParent { parent: UUID; enfant: UUID }`, `Couple { a: UUID; b: UUID }`. Methods: `parents(de:) -> [Personne]`, `enfants(de:) -> [Personne]`, `freresEtSoeurs(de:) -> [Personne]`, `mutating ajouter(_:) `, `mutating lierParent(_ parent: UUID, enfant: UUID)` (idempotent), `mutating lierCouple(_:_:)`, `branche(de id: UUID) -> Branche` with `enum Branche { case moi, pere, mere, autre }`, `generation(de id: UUID) -> Int` (moi = 0, parents = -1, children = +1), `trouver(prenom: String, nom: String?) -> Personne?` (case- and accent-insensitive).

- [ ] **Step 1: Failing tests** — `testBranches` (moi→père→grand-mère paternelle all `.pere`, mère side `.mere`, moi `.moi`); `testGenerations`; `testFreresEtSoeursShareAParent`; `testLierParentIsIdempotent`; `testFindMatchingIgnoresCaseAndAccents` ("zaharia" finds "Zaharia", "Saïd" finds "Said").
- [ ] **Step 2:** Run; Expected FAIL. **Step 3:** Implement (branch: walk up from moi; father = parent with `sexe == .homme`, or first parent if unknown). **Step 4:** PASS. **Step 5:** Commit `feat: modèle de famille`.

### Task 4: Tree layout

**Files:** Create `ArbreCore/Sources/ArbreCore/Disposition.swift`; Test `DispositionTests.swift`

**Interfaces:**
- Produces: `struct Noeud { let id: UUID?; let x: Double; let y: Double; let aCompleter: Bool; let libelle: String }` (`id == nil` for a "à trouver" placeholder), `struct Trait { let de: (Double, Double); let a: (Double, Double); let pointille: Bool }`, `func disposer(_ famille: Famille, largeurNoeud: Double = 84, ecartGeneration: Double = 130) -> (noeuds: [Noeud], traits: [Trait], taille: (Double, Double))`.

- [ ] **Step 1: Failing tests** — `testParentsAboveChild` (parent y < child y by `ecartGeneration`); `testMissingParentsGetPlaceholders` (person with 0 known parents in generation ≤ -1 yields 2 placeholders labelled "À trouver"); `testNoOverlapInARow` (x gap ≥ `largeurNoeud`); `testCoupleIsAdjacent`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement per-generation rows; place each couple side by side, centre children under the couple, then shift rows to remove overlaps. **Step 4:** PASS. **Step 5:** Commit `feat: disposition de l'arbre`.

### Task 5: Next question and daily goal

**Files:** Create `ArbreCore/Sources/ArbreCore/ProchaineQuestion.swift`, `ArbreCore/Sources/ArbreCore/Objectif.swift`; Tests `ProchaineQuestionTests.swift`, `ObjectifTests.swift`

**Interfaces:**
- Produces: `struct Manque: Codable, Hashable { let personne: UUID?; let sujet: Sujet }`, `enum Sujet: String, Codable { case parents, grandsParents, freresSoeurs, enfants, dateNaissance, lieuNaissance }`, `func manques(_ f: Famille, enAttente: Set<Manque>) -> [Manque]` (order: parents, grandsParents, freresSoeurs, enfants, dateNaissance, lieuNaissance; postponed items last), `struct Objectif { static let cible = 5; func ajoutsDuJour(_ f: Famille, le: Date, calendrier: Calendar) -> [Personne]; func serie(_ f: Famille, jusquau: Date, calendrier: Calendar) -> Int; func record(_ f: Famille, calendrier: Calendar) -> Int }`.

- [ ] **Step 1: Failing tests** — empty family → first `Manque` is `.parents` of moi; postponed item comes last; `ajoutsDuJour` counts by local calendar day with `TimeZone(identifier: "Indian/Mayotte")` (23:59 and 00:01 fall on different days); `serie` = 3 for three consecutive days at ≥5, breaks on a day at 4; today below 5 does not break a series ending yesterday.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** PASS. **Step 5:** Commit `feat: prochaine question et objectif`.

### Task 6: JSON store and backup

**Files:** Create `ArbreCore/Sources/ArbreCore/Stockage.swift`; Test `StockageTests.swift`

**Interfaces:**
- Produces: `struct Sauvegarde: Codable { let version: Int; let famille: Famille; let enAttente: [Manque] }` (`version = 1`), `final class Stockage { init(dossier: URL); func charger() throws -> Sauvegarde; func enregistrer(_: Sauvegarde) throws; static func exporter(_: Sauvegarde) throws -> Data; static func importer(_: Data) throws -> Sauvegarde }`, `enum ErreurStockage: Error { case fichierIllisible, versionInconnue(Int) }` with French `localizedDescription`.

- [ ] **Step 1: Failing tests** — round trip; `charger()` on missing file returns empty family; `importer` of garbage throws `.fichierIllisible`; `version: 99` throws `.versionInconnue(99)`; a failed import leaves the file on disk unchanged.
- [ ] **Step 2:** FAIL. **Step 3:** Implement (atomic write `famille.json`, ISO8601 dates). JSON chosen over SwiftData: one file is also the backup format. **Step 4:** PASS. **Step 5:** Commit `feat: stockage et sauvegarde`.

### Task 7: Design system and Accueil screen

**Files:** Create `NotreArbre/Design/Theme.swift`, `NotreArbre/Design/FondColore.swift`, `NotreArbre/Design/BarreOnglets.swift`, `NotreArbre/Ecrans/AccueilView.swift`, `NotreArbre/Etat/AppModel.swift`

**Interfaces:**
- Consumes: `Stockage`, `Famille`, `Objectif`, `manques`.
- Produces: `Color.turquoise/.corail/.violet/.corailTexte/.violetTexte`, `FondColore` (the four blurred blobs), `extension View { func carteVerre(rayon: CGFloat = 28) -> some View }` (`glassEffect(.regular, in: .rect(cornerRadius: rayon))`), `@Observable final class AppModel { var famille: Famille; var enAttente: Set<Manque>; func enregistrer(); var ajoutsAujourdhui: Int; var serie: Int; var record: Int }`, root `TabView`-free navigation: `enum Onglet { case accueil, arbre, famille }` + floating pill bar with round mic button opening the interview.

- [ ] **Step 1:** Build the Accueil screen to match mockup screen 1 (ring x/5 turquoise, "Encore N personnes", streak row with corail flame and week dots, "Continuer l'entretien" tinted glass button, three stat cards 47/4/9 colored turquoise/violet/corail with live values, "L'IA te propose" card with violet icon showing the first `Manque` in French).
- [ ] **Step 2:** First launch with no `moiID`: one sheet asking "Comment t'appelles-tu ?" that creates moi (only typed form in the app).
- [ ] **Step 3:** CI green; install IPA; compare with mockup screen 1 side by side. Expected: same layout and colors.
- [ ] **Step 4:** Commit `feat: design et accueil`.

### Task 8: Interview (voice + on-device AI)

**Files:** Create `NotreArbre/IA/Dictee.swift`, `NotreArbre/IA/Assistant.swift`, `NotreArbre/Ecrans/EntretienView.swift`, `NotreArbre/Ecrans/CarteProposition.swift`

**Interfaces:**
- Consumes: `AppModel`, `manques`, `DateFloue.depuis`, `Famille.trouver`.
- Produces: `@Observable final class Dictee { var texte: String; var enCours: Bool; func demarrer() async throws; func arreter() }` (`SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))`, `requiresOnDeviceRecognition = true`); `@Generable struct Extraction { var personnes: [PersonneExtraite]; var liens: [LienExtrait] }`, `@Generable struct PersonneExtraite { var prenom: String; var nom: String?; var sexe: String?; var dateTexte: String?; var lieu: String? }`, `@Generable struct LienExtrait { var parent: String; var enfant: String; var type: String }`; `final class Assistant { var disponible: Bool; func question(pour: Manque, famille: Famille) async -> String; func extraire(reponse: String, contexte: Manque, famille: Famille) async throws -> Extraction }` using `LanguageModelSession` with French instructions; `struct Proposition { var nouvelles: [Personne]; var misesAJour: [Personne]; var liens: [LienParent] }` built from `Extraction` by matching names with `trouver`.

- [ ] **Step 1:** Screen matches mockup screen 2: bubbles (assistant glass, user tinted), "Fiche mise à jour" card, chips "Je ne sais pas" (adds `Manque` to `enAttente`), "Demander à un proche" (Task 11), "Photo d'un document" (Task 10), mic button 84 pt tinted glass, keyboard button, tree button, header pill "x/5 aujourd'hui".
- [ ] **Step 2:** Flow: question → dictation → `extraire` → `CarteProposition` with Valider / Corriger → on Valider apply to `famille`, save, next question. On 5th new person today, present `ObjectifAtteintView`.
- [ ] **Step 3:** If `SystemLanguageModel.default.availability != .available`: banner "L'IA d'Apple n'est pas disponible. Active Apple Intelligence dans Réglages, ou écris ta réponse." and fall back to `DateFloue.depuis` + a simple first-name parse for typed answers.
- [ ] **Step 4:** Manual check on iPhone: say "Mon père s'appelle Ahamada, il est né vers 1958" → proposal shows Ahamada, father, "vers 1958"; say "ma mère Zaharia" twice → no duplicate; Apple Intelligence off → banner and typed entry work.
- [ ] **Step 5:** Commit `feat: entretien vocal avec l'IA`.

### Task 9: Tree and person screens

**Files:** Create `NotreArbre/Ecrans/ArbreView.swift`, `NotreArbre/Ecrans/FicheView.swift`, `NotreArbre/Ecrans/FamilleListeView.swift`

**Interfaces:**
- Consumes: `disposer`, `Famille.branche`, `manques`.
- Produces: `struct ArbreDessin: View { let famille: Famille; let pourImpression: Bool }` (reused by Task 12).

- [ ] **Step 1:** Arbre matches mockup screen 3: title, "N personnes · N générations", legend chips (« vers 1958 », à compléter, côté père / côté mère), nodes colored by branch, dashed placeholders opening the interview on that `Manque`, pinch-zoom and pan, share button (Task 12).
- [ ] **Step 2:** Fiche matches mockup screen 4: avatar in branch color, "Née vers 1935 · ta grand-mère paternelle" (relationship label computed from graph), Liens list, "Ce qu'on ne sait pas encore" from `manques` for this person, "Compléter avec l'IA", "Demander à un proche", Modifier (edit name, date text, place).
- [ ] **Step 3:** Famille tab: alphabetical list of people opening Fiche.
- [ ] **Step 4:** Manual check against mockup screens 3 and 4. **Step 5:** Commit `feat: arbre et fiches`.

### Task 10: Goal reached, reminder, backup prompt, document reading

**Files:** Create `NotreArbre/Ecrans/ObjectifAtteintView.swift`, `NotreArbre/Services/Rappel.swift`, `NotreArbre/Services/LectureDocument.swift`

**Interfaces:**
- Produces: `enum Rappel { static func planifier(ajoutsAujourdhui: Int) async }` (one `UNCalendarNotificationTrigger` at 19:00 today if < 5, removed when reached; body "Il te reste N personnes pour ton objectif du jour."), `enum LectureDocument { static func texte(de image: UIImage) async throws -> String }` (Vision, `recognitionLanguages = ["fr-FR"]`, `.accurate`).

- [ ] **Step 1:** ObjectifAtteintView matches mockup screen 5 (check ring, "Objectif atteint", "5 personnes ajoutées aujourd'hui.", streak/record line, today's list with branch avatars, "Terminer pour aujourd'hui", "Continuer quand même"), then offers "Enregistrer une copie de l'arbre" via `fileExporter` with `Stockage.exporter`, file name `notre-arbre-AAAA-MM-JJ.json`.
- [ ] **Step 2:** Réglages sheet (from the avatar button): "Restaurer une copie" via `fileImporter` + `Stockage.importer`, French error alert on failure.
- [ ] **Step 3:** "Photo d'un document": camera or photo picker → `LectureDocument.texte` → `Assistant.extraire` → same `CarteProposition` with `origine = .document`.
- [ ] **Step 4:** Manual check: reach 5 → screen + export; notification fires at 19:00 when below 5; photo of a printed text yields names. **Step 5:** Commit `feat: objectif atteint, rappel, sauvegarde, lecture de documents`.

### Task 11: Ask a relative on WhatsApp

**Files:** Create `NotreArbre/Services/DemandeProche.swift`

**Interfaces:**
- Produces: `func messageQuestions(pour personne: Personne?, manques: [Manque], famille: Famille) -> String` (in `ArbreCore`, tested), opened with `URL(string: "whatsapp://send?text=…")`, falling back to `ShareLink` if WhatsApp is not installed.

- [ ] **Step 1: Failing test** `testMessageListsQuestionsInFrench` — for Mariama with parents and village missing, message starts "Bonjour ! Je construis l'arbre de la famille." and contains "Qui sont les parents de Mariama ?" and "Dans quel village est née Mariama ?".
- [ ] **Step 2:** FAIL. **Step 3:** Implement and wire both buttons. **Step 4:** PASS. **Step 5:** Commit `feat: demander à un proche`.

### Task 12: Poster PDF export

**Files:** Create `NotreArbre/Services/Affiche.swift`

**Interfaces:**
- Consumes: `ArbreDessin(famille:pourImpression: true)`.
- Produces: `enum FormatAffiche: CaseIterable { case a2, a1, a0 }` with mm sizes from Global Constraints, `func pdfAffiche(famille: Famille, format: FormatAffiche) -> URL` using `ImageRenderer` → `render { size, contexte in }` into a `CGContext` PDF page (vector), title "Famille BAZAMA" at top, footer "Édité le 8 novembre 2026" style date, white background, no blobs, tree scaled to fit with margins of 20 mm.

- [ ] **Step 1:** Share button in ArbreView → format picker A2/A1/A0 → `ShareLink` of the PDF (`famille-bazama-a1.pdf`).
- [ ] **Step 2:** Manual check: open PDF in Files, zoom to 800 %: text and lines stay sharp. **Step 3:** Commit `feat: affiche PDF grand format`.

### Task 13: Final check

- [ ] **Step 1:** Run full CI; Expected all tests pass, artifact present.
- [ ] **Step 2:** Install with Sideloadly; walk the five mockup screens side by side and list any visible difference to the user.
- [ ] **Step 3:** Commit any fixes; push.
