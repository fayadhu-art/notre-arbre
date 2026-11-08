# Notre arbre — document de conception

Date : 8 novembre 2026 · Auteur : Fayadhu AHAMADA, avec Claude

## 1. Intention

Construire l'arbre généalogique de la famille sans effort de saisie. L'utilisateur parle, l'IA pose les questions, crée les fiches et dessine l'arbre. Un objectif de 5 personnes par jour fait avancer l'arbre régulièrement. À la fin, l'arbre s'imprime en grand format pour le mur du salon.

Usage personnel, sur l'iPhone 17 Pro de l'utilisateur, installé avec Sideloadly.

## 2. Objectifs

- Entretien vocal en français : l'IA pose une question à la fois, comprend la réponse et crée ou complète les fiches.
- Dates incomplètes acceptées partout : date exacte, année seule, « vers », « avant », « après », inconnue.
- Arbre dessiné automatiquement, couleur par branche : corail côté père, violet côté mère, turquoise pour l'utilisateur.
- Objectif quotidien de 5 personnes, série de jours d'affilée, record, rappel si l'objectif n'est pas atteint.
- Export PDF vectoriel de l'arbre en grand format (A2, A1, A0) pour l'impression.
- Lecture d'un document photographié (livret de famille, acte) : l'IA propose les noms et les dates, l'utilisateur valide.
- Design de la maquette validée : effet verre d'iOS (Liquid Glass), couleurs turquoise, corail, violet.

## 3. Non-objectifs (version 1)

- Shimaoré : tout est en français.
- Serveur, compte, synchronisation en ligne.
- Publication sur l'App Store.
- iPad, Mac, Android.
- Import ou export GEDCOM (format des logiciels de généalogie).

## 4. Anti-objectifs (ce qui ferait échouer l'appli même si elle marche)

- Un formulaire à remplir à la place de la conversation.
- Une date obligatoire ou un format imposé qui bloque la saisie.
- Une fiche enregistrée sans que l'utilisateur ait vu et validé ce que l'IA a compris.
- La perte de l'arbre après une réinstallation de l'appli.
- Un PDF flou ou pixelisé à l'impression.
- Une appli qui ne ressemble pas à la maquette validée.

## 5. Contraintes

- Appareil : iPhone 17 Pro, iOS 26 ou plus récent (cible minimale iOS 26.0, requise par l'IA d'Apple et l'effet verre).
- IA : Apple Foundation Models, sur l'appareil, gratuite, sans internet. Apple Intelligence doit être activé sur l'iPhone.
- Voix : reconnaissance vocale d'Apple en français (fr-FR), sur l'appareil.
- Lecture de documents : Vision (reconnaissance de texte) en français.
- Compilation : GitHub Actions sur macOS, IPA non signée, même méthode que le dépôt MaMazda.
- Installation : Sideloadly avec le compte Apple Developer payant de l'utilisateur (appli valable un an avant réinstallation).
- Données : stockées uniquement sur l'iPhone.

## 6. Approches étudiées

| Approche | Avantages | Inconvénients |
|---|---|---|
| 1. Coque iOS + page web (méthode MaMazda) | Rapide, maquette reprise telle quelle | Effet verre imité en CSS, moins fluide, voix via un pont |
| 2. Appli native SwiftUI (retenue) | Vrai effet verre iOS, voix native fiable, PDF vectoriel net | Plus de code, design redessiné en Swift |
| 3. Appli web dans Safari | Aucune installation | Écartée : l'utilisateur veut une IPA et l'IA d'Apple n'est pas accessible depuis le web |

Choix de l'utilisateur : approche 2, pour le rendu iOS 27, l'IA d'Apple et l'impression grand format.

## 7. Ce qui est décidé

### 7.1 Écrans

Exigence de l'utilisateur : l'appli reprend fidèlement la maquette validée « Notre arbre — maquette » (https://claude.ai/artifact/X6xTxzeXvr2fNDwh5Wvdzp). Mêmes écrans, même disposition, mêmes textes, mêmes couleurs (turquoise #0F766E, corail #FF7A59, violet #7C3AED, fonds colorés flous), mêmes composants : cartes en verre, barre d'onglets flottante en pilule avec le bouton micro rond à droite, boutons ronds en verre. Le verre utilise l'effet natif d'iOS, ce qui donne un rendu au moins aussi beau que la maquette. Toute différence visible doit être justifiée par une contrainte technique et signalée à l'utilisateur.

Écrans :
1. Accueil : anneau de l'objectif (x/5), série de jours, bouton « Continuer l'entretien », chiffres (personnes, générations, questions en attente), suggestion de l'IA.
2. Entretien : bulles de conversation, carte « Fiche mise à jour » après chaque réponse, gros bouton micro, raccourcis « Je ne sais pas », « Demander à un proche », « Photo d'un document ».
3. Arbre : générations de haut en bas, zoom et déplacement au doigt, cercles en pointillés pour les personnes à trouver, légende des couleurs, bouton d'export PDF.
4. Fiche : identité, liens familiaux, liste « Ce qu'on ne sait pas encore », boutons « Compléter avec l'IA » et « Demander à un proche ».
5. Objectif atteint : affiché au 5e ajout de la journée, avec les personnes ajoutées.

### 7.2 Données

- Personne : prénom, nom, sexe, naissance (date floue), lieu de naissance, décès (date floue, facultatif), notes, origine de l'information (entretien, document, saisie), date d'ajout.
- Date floue : jour, mois et année facultatifs, plus une précision (exacte, année seule, vers, avant, après, inconnue). Affichage : « 12 mars 1985 », « 1958 », « vers 1958 », « avant 1950 », « date inconnue ».
- Liens : parent-enfant et couple. Frères, sœurs, oncles, cousins se déduisent de ces liens.
- Branche : calculée à partir de l'utilisateur (père et ses ascendants = côté père, mère et ses ascendants = côté mère).

### 7.3 Entretien avec l'IA

1. L'appli choisit la prochaine information manquante (ordre : parents, grands-parents, frères et sœurs, enfants, puis dates et lieux).
2. L'IA formule la question en français naturel.
3. L'utilisateur répond à la voix ou au clavier.
4. L'IA extrait de la réponse les personnes, liens, dates et lieux, sous forme structurée.
5. L'appli affiche ce qu'elle a compris dans une carte ; l'utilisateur valide ou corrige d'un appui.
6. Les fiches et l'arbre se mettent à jour, le compteur du jour aussi.

« Je ne sais pas » met la question en attente et passe à la suivante. Les questions en attente reviennent plus tard.

### 7.4 Objectif quotidien

- Compte : personnes créées dans la journée (une fiche complétée ne compte pas comme une nouvelle personne).
- Série : jours consécutifs avec 5 personnes ou plus. Record conservé.
- Rappel : notification locale le soir si l'objectif n'est pas atteint.

### 7.5 Impression

- Export PDF vectoriel de tout l'arbre, au format choisi (A2, A1, A0), orientation paysage.
- En-tête avec le titre de l'arbre, pied de page avec la date d'édition.
- Partage par la feuille de partage d'iOS (Fichiers, AirDrop, e-mail) pour l'envoyer à un imprimeur.

### 7.6 Sauvegarde

- Export de tout l'arbre dans un fichier de sauvegarde, et restauration depuis ce fichier, pour ne rien perdre en cas de réinstallation.

### 7.7 Compilation et installation

- Nouveau dépôt GitHub privé, workflow identique à MaMazda : compilation Release non signée sur macOS, IPA disponible dans les artefacts de l'exécution.
- L'utilisateur télécharge l'IPA et l'installe avec Sideloadly.

## 8. Laissé au développeur

- Organisation du code, stockage local (SwiftData recommandé), algorithme de placement de l'arbre.
- Formulation exacte des consignes données à l'IA d'Apple.
- Comportement si Apple Intelligence est désactivé : message clair et saisie au clavier avec extraction simple.
- Icône de l'appli dans l'esprit de la maquette.

## 9. Décisions de l'utilisateur (8 novembre 2026)

1. « Demander à un proche » : l'appli prépare les questions en message WhatsApp ; l'utilisateur saisit les réponses reçues.
2. Titre imprimé en haut de l'affiche : « Famille BAZAMA ».
3. Rappel : notification à 19 h si les 5 personnes du jour ne sont pas faites.
4. Sauvegarde : à chaque objectif atteint, l'appli propose d'enregistrer une copie de l'arbre (iCloud Drive ou Fichiers).
5. Dépôt GitHub privé `notre-arbre`, créé par l'utilisateur.
