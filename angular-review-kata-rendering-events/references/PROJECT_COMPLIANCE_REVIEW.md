---
name: kata-compliance-reviewer
description: Audit de conformité au cahier des charges du kata « Rendering Events » (positionnement temps→pixels, chevauchement, responsivité, contraintes RFC2119 de l'énoncé).
domain: kata-compliance
rule_prefix: R-KATA
applies_to:
  - "src/**/*.ts"
  - "src/**/*.html"
  - "src/**/*.css"
  - "src/**/*.scss"
  - "src/assets/input.json"
  - "src/styles.css"
  - "src/index.html"
  - "package.json"
severity_levels: [BLOCKER, MAJOR, MINOR, INFO]
output_format: json
parallel_safe: true
sources:
  - README.md
  - https://microformats.org/wiki/rfc-2119-fr
---

# Reviewer Guideline — Conformité au kata « Rendering Events »

## But

Référentiel **autoritatif** dérivé de `README.md` du kata. Le kata est noté sur sa fidélité à l'énoncé — un écart par rapport aux contraintes RFC2119 (`DOIT`, `NE DOIT PAS`, `DEVRAIT`, `PEUT`) est l'erreur la plus grave possible et bloque l'évaluation, même si le code est par ailleurs propre.

L'agent doit :
1. Lire l'énoncé canonique dans `README.md` à la racine du repo.
2. Confronter le diff aux 13 règles ci-dessous.
3. Émettre un finding **par règle violée**, en citant le passage exact du README qui établit la contrainte.

## Niveaux de sévérité

- 🔴 **BLOCKER** — viole un `DOIT` / `NE DOIT PAS` ; le kata n'est pas considéré comme rendu.
- 🟠 **MAJOR** — viole un `DEVRAIT` ou casse une garantie attendue par le pipeline de test (resize, responsive, formules approximatives).
- 🟡 **MINOR** — viole un `PEUT` / détail visuel (bordure 1px, couleur de fond).
- 🔵 **INFO** — suggestion d'amélioration ou écart de craftsmanship sans casser le sujet.

## Contexte canonique (extraits du README)

> Le haut de la page représente 09h00. Le bas de la page représente 21h00.
> Les événements devraient être représentés sous forme de `div` avec une couleur de fond et une bordure de 1px.
> L'id de l'évenement doit être présent dans le contenu de la `div`, ainsi que dans son attribut `id` afin d'être validé par notre pipeline de test.
> Votre implémentation devrait être responsive (c'est-à-dire répondre aux événements `resize` de la fenêtre).
> 1. Si A et B sont deux évenements en chevauchement, alors Largeur(A) = Largeur(B).
> 2. LargeurMax = largeur de la fenêtre
> 3. Si sur une plage horaire donnée, deux évenements A et B se chevauchent, alors Largeur(A) + Largeur(B) = LargeurMax

---

## Règles à vérifier

### R-KATA-001 — Attribut `id` sur la `div` d'évènement

- **Sévérité** : 🔴 BLOCKER
- **Référence RFC2119** : « L'id d'un évènement `DOIT` être présent dans […] son attribut `id` »
- **Quoi vérifier** : chaque `div` rendue pour un évènement porte un attribut HTML `id` strictement égal à `event.id` (binding Angular `[id]="..."` ou `id="{{ ... }}"`).
- **Pattern à flag** : template d'évènement sans binding `[id]` / `[attr.id]` / `id="..."` ; binding sur `data-id` à la place du vrai `id`.
- **Pattern accepté** : `<div [id]="event.id">...` ou `<div [attr.id]="event.id">...`.
- **Note** : si `event.id` est un nombre, le DOM rendra `id="1"` — valide HTML5 et trouvable via `document.getElementById('1')`.

### R-KATA-002 — `id` également dans le **contenu** de la `div`

- **Sévérité** : 🔴 BLOCKER
- **Référence RFC2119** : « L'id d'un évènement `DOIT` être présent dans le contenu de sa div »
- **Quoi vérifier** : le `textContent` de la `div` d'évènement contient la valeur `event.id`.
- **Pattern à flag** : template d'évènement sans `{{ event.id }}` ni équivalent dans le contenu textuel ; id rendu uniquement via une icône / un attribut.

### R-KATA-003 — Échelle verticale 09:00 → 21:00

- **Sévérité** : 🔴 BLOCKER
- **Référence README** : « Le haut de la page représente 09h00. Le bas de la page représente 21h00. »
- **Quoi vérifier** : `startHour = 9`, `endHour = 21`. Plage totale = **720 minutes** (12 h).
- **Pattern à flag** : `startHour` à `0`/`8`/`10` ; `endHour` à `24`/`20`/`22` ; toute plage qui ne donne pas 720 minutes.
- **Exemple ✅** : `hours = [9, 10, ..., 20]; endHour = 21;`

### R-KATA-004 — Formule de position `top`

- **Sévérité** : 🔴 BLOCKER
- **Référence README** : « la position relative des événements se calcule en fonction de la bordure supérieure de la fenêtre, l'heure et la durée des événements. »
- **Formule attendue (en %)** : `top% = ((HH - startHour) * 60 + MM) / totalMinutes * 100`
- **Formule attendue (en px)** : `top_px = ((HH - startHour) * 60 + MM) / totalMinutes * containerHeight`
- **Pattern à flag** :
  - Calcul oubliant les minutes (`MM`) ;
  - Calcul en `HH * 60` au lieu de `(HH - startHour) * 60` ;
  - Position absolue en px hardcodée non-responsive.

### R-KATA-005 — Formule de hauteur `height`

- **Sévérité** : 🔴 BLOCKER
- **Référence README** : « un événement […] durant 1h […] aura une hauteur de 100px. »
- **Formule attendue (en %)** : `height% = duration / totalMinutes * 100`
- **Formule attendue (en px)** : `height_px = duration / totalMinutes * containerHeight`
- **Pattern à flag** : hauteur en pixels fixe indépendante de `duration` ; `height: ${duration}px` qui ne respecte pas l'échelle du container.

### R-KATA-006 — Chevauchement : largeurs égales

- **Sévérité** : 🔴 BLOCKER
- **Référence README, contrainte 1** : « Si A et B sont deux évenements en chevauchement, alors Largeur(A) = Largeur(B). »
- **Quoi vérifier** : pour tout cluster d'évènements en chevauchement transitif, toutes les `div` du cluster partagent la **même largeur** rendue.
- **Pattern accepté** : algorithme qui calcule un `totalColumns` par cluster puis applique `width = 100 / totalColumns`.
- **Pattern à flag** : largeurs calculées par évènement sans regroupement ; empilement vertical (z-index) sans découpe horizontale.

### R-KATA-007 — Chevauchement : somme des largeurs au pic du cluster (lecture Outlook)

- **Sévérité** : 🟠 MAJOR
- **Référence README, contraintes 2 et 3** : « LargeurMax = largeur de la fenêtre » ; « Si sur une plage horaire donnée, deux évenements A et B se chevauchent, alors Largeur(A) + Largeur(B) = LargeurMax »
- **Lecture à appliquer (Outlook)** : pour chaque cluster d'évènements en chevauchement transitif, à la **tranche de pic** (minute où le max d'évènements du cluster sont simultanément actifs), la somme des largeurs rendues doit égaler la largeur du container.
- **Pourquoi cette interprétation** : la lecture stricte par tranche (« à chaque tranche, Σ = MaxWidth ») est **mathématiquement insatisfaisable** dès qu'un cluster contient ≥ 3 évènements de durées hétérogènes — une `<div>` unique par évènement ne peut pas avoir deux largeurs différentes au même instant. La capture du README (Microsoft Outlook) reflète cette lecture relâchée.
- **Pattern accepté** : pour un cluster de `N` colonnes au pic, `width = 100% / N` et `left = col / N * 100%`.
- **Pattern à flag** :
  - Largeur fixe en pixels qui ne s'adapte pas au cluster ;
  - Marges (`gap`) entre colonnes qui réduisent la somme au pic ;
  - Largeur ne dépendant pas de `max-concurrent` du cluster.

### R-KATA-008 — Conteneur plein écran

- **Sévérité** : 🔴 BLOCKER
- **Référence README** : « Votre code devrait afficher les événements sur une page Web dans un conteneur couvrant toute la fenêtre. »
- **Quoi vérifier** :
  - `html, body { height: 100%; margin: 0; }` (ou équivalent Tailwind `h-screen` / `h-full`).
  - Le composant racine prend `100vh` / `100%` de hauteur.
  - Aucune marge / padding parasite réduisant l'aire utile.
- **Pattern à flag** :
  - `body` sans `height: 100%` et calendrier en `height: auto` ;
  - Wrapper centré avec `max-width` qui n'occupe pas toute la largeur (sauf design explicite conforme à R-KATA-007).

### R-KATA-009 — Responsivité au `resize`

- **Sévérité** : 🟠 MAJOR
- **Référence README, RFC2119** : « L'affichage `DOIT` être responsive » ; « Votre implémentation devrait […] répondre aux événements `resize` de la fenêtre. »
- **Quoi vérifier** : à la redimension, top/height/width/left restent corrects sans recharger.
- **Patterns acceptés** :
  - Positionnement en `%` ou unités viewport (`vh`, `vw`) → recalcul natif par le navigateur.
  - `ResizeObserver` ou listener `window.resize` qui re-calcule les positions en `px`.
- **Pattern à flag** :
  - Positions calculées **une seule fois** en `px` au mount, sans listener ;
  - Hauteur du container fixée (ex. `height: 800px`) sans relation au viewport.

### R-KATA-010 — Pas de librairies non autorisées

- **Sévérité** : 🔴 BLOCKER
- **Référence README, RFC2119** : « Le projet `NE DOIT PAS` utiliser d'imports de librairies autres que librairies nécessaires au fonctionnement du framework utilisé […]. Aucune autre librairie qui ne soit pas purement utilitaire (ex: lodash) ou purement axée graphique / templating (ex: material UI). »
- **Quoi vérifier** : `package.json` (dependencies + devDependencies). Sont autorisés :
  - Framework Angular et écosystème (`@angular/*`, `rxjs`, `tslib`, `zone.js`).
  - Build & TypeScript (`typescript`, `@angular/build`, `@angular/cli`).
  - Tests (`vitest`, `jasmine`, `karma`, `@angular/...test`, `jsdom`, `playwright`, `@playwright/*`).
  - Lint/format (`eslint`, `prettier`, `angular-eslint`, `typescript-eslint`).
  - **Purement utilitaire** : `lodash`, `date-fns` (si justifié).
  - **Purement graphique / templating** : `tailwindcss`, `@tailwindcss/*`, `postcss`, `@angular/material`, `@angular/cdk`.
- **Pattern à flag** :
  - Toute lib de _layout_ de calendrier (`@fullcalendar/*`, `react-big-calendar`, `dhtmlx-scheduler`, `tui-calendar`) → **disqualifie le rendu du kata** ;
  - Lib qui calcule les chevauchements à la place du candidat ;
  - State manager lourd (`@ngrx/*`, `redux`) sans justification de l'énoncé.

### R-KATA-011 — Bordure 1px sur l'évènement

- **Sévérité** : 🟡 MINOR
- **Référence README** : « Les événements devraient être représentés sous forme de `div` avec […] une bordure de 1px. »
- **Quoi vérifier** : la `div` d'évènement a une bordure visible d'1px (classe Tailwind `border` = 1px par défaut, ou CSS explicite `border: 1px solid …`).
- **Pattern à flag** : pas de bordure ; bordure d'épaisseur différente sans justification.

### R-KATA-012 — Couleur de fond sur l'évènement

- **Sévérité** : 🟡 MINOR
- **Référence README** : « Les événements devraient être représentés sous forme de `div` avec une couleur de fond […]. »
- **Quoi vérifier** : la `div` d'évènement applique une `background-color`.
- **Pattern à flag** : aucun fond appliqué (la `div` est transparente).

### R-KATA-013 — JS / TS moderne, lisibilité

- **Sévérité** : 🔵 INFO
- **Référence README, RFC2119** : « Le projet `DEVRAIT` être implémenté en JS moderne ES6 » ; « Le projet `PEUT` être implémenté en Typescript » ; « Les informations `DEVRAIENT` être facilement lisibles et agréables à l'œil ».
- **Quoi vérifier** : usage cohérent de `const`/`let`, destructuring, arrow functions, signaux Angular (`signal`, `computed`, `input`), nouveau control flow (`@for`, `@if`), absence de `var`, absence d'`any` non justifié.
- **Pattern à flag** :
  - `var` ou IIFE ;
  - `function` traditionnelles dans des méthodes de composant ;
  - `any` non commenté en TypeScript ;
  - Mise en page illisible ou densité d'information trop forte sur la `div` d'évènement.

---

## Format de sortie (rappel)

Retourner un unique objet JSON, **sans markdown ni prose** :

```json
{
  "agent": "kata-compliance-reviewer",
  "findings": [
    {
      "ruleId": "R-KATA-NNN",
      "severity": "BLOCKER|MAJOR|MINOR|INFO",
      "domain": "kata-compliance",
      "file": "path/to/file.ts",
      "line": 42,
      "snippet": "<extrait>",
      "message": "<violation observée>",
      "suggestion": "<correction>",
      "source": "README.md L<line>"
    }
  ]
}
```

Si aucune violation : `{"agent": "kata-compliance-reviewer", "findings": []}`.
