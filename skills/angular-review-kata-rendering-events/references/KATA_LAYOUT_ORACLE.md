---
name: kata-layout-oracle
description: Oracle de mesure du rendu pour le kata « Rendering Events ». Source canonique des formules, tolérances et procédure DOM utilisées par Step 6 de l'orchestration.
domain: kata-compliance
applies_to:
  - "src/**/*.ts"
  - "src/**/*.html"
  - "src/**/*.css"
  - "src/**/*.scss"
sources:
  - README.md
---

# Kata Layout Oracle

Référentiel canonique des **formules de positionnement** et **procédures de mesure DOM** pour le kata « Rendering Events ». Ce fichier est lu par Step 6 de l'orchestration pour mesurer le rendu et émettre des findings avec `evidence.kind = "dom"`. Les règles `R-KATA-003` à `R-KATA-009` du `PROJECT_COMPLIANCE_REVIEW.md` cross-référencent ce document — **ne pas dupliquer les formules dans les règles**.

## §1. Système de coordonnées

- Le calendrier est rendu dans un conteneur unique couvrant **toute la viewport** (cf. R-KATA-008). Mesurer `containerHeight = container.getBoundingClientRect().height` et `containerWidth = container.getBoundingClientRect().width`.
- L'origine verticale (`top = 0`) correspond à **09:00**.
- La fin verticale (`top = containerHeight`) correspond à **21:00**.
- Toutes les coordonnées des évènements sont **relatives au conteneur**, pas à la viewport.

## §2. Plage horaire couverte

```
dayStartMinutes = 9 * 60   = 540
dayEndMinutes   = 21 * 60  = 1260
totalDayMinutes = 720         (12h)
```

Tout `startHour` ≠ 9 ou `endHour` ≠ 21 viole **R-KATA-003** (BLOCKER).

## §3. Formule de position verticale (`top`)

Pour un évènement commençant à `HH:MM` (heure locale du calendrier) :

```
eventStartMinutes = HH * 60 + MM
top_pct = (eventStartMinutes - dayStartMinutes) / totalDayMinutes * 100
top_px  = top_pct / 100 * containerHeight
```

Lié à **R-KATA-004** (BLOCKER). Patterns à flag : oubli de `MM`, formule en `HH * 60` sans soustraction de `dayStartMinutes`, position px hardcodée.

## §4. Formule de hauteur (`height`)

Pour un évènement de durée `duration` minutes :

```
height_pct = duration / totalDayMinutes * 100
height_px  = height_pct / 100 * containerHeight
```

Lié à **R-KATA-005** (BLOCKER). Exemple canonique du README : `duration = 60min` ⇒ `height_pct = 60/720 = 8.33%`. Sur un container de 1200px, cela donne 100px (cas explicite du README).

## §5. Règles de colonnes pour overlaps

Un **cluster** est l'ensemble des évènements liés par chevauchement transitif (A∩B et B∩C ⇒ A, B, C dans le même cluster, même si A ne chevauche pas C).

Pour chaque cluster :
1. Calculer `maxConcurrent` = nombre maximum d'évènements simultanés à n'importe quelle minute du cluster.
2. Assigner chaque évènement à une colonne `0 ≤ col < maxConcurrent` via un balayage chronologique (algorithme classique).
3. Appliquer :
   ```
   width_pct = 100 / maxConcurrent
   left_pct  = col * width_pct
   ```

Lié à **R-KATA-006** (BLOCKER) et **R-KATA-007** (MAJOR). Tous les évènements du cluster partagent la **même width** (R-KATA-006). La somme des widths à la tranche de pic égale `containerWidth` (R-KATA-007).

## §6. Comportement responsive

Lié à **R-KATA-009** (MAJOR). Deux familles d'implémentation acceptables :

- **% / unités viewport** : `top`, `height`, `width`, `left` exprimés en `%` ou `vh`/`vw`. Le navigateur recalcule nativement au resize — pas de listener nécessaire.
- **px + listener** : positions calculées en `px`, mais un `ResizeObserver` sur le conteneur ou un listener `window.resize` recalcule à chaque évènement. Vérifier que le listener déclenche bien un re-render Angular (signal change, `ChangeDetectorRef.detectChanges()`, ou recompute dans un `computed`).

Pattern à flag (BLOCKER de fait pour R-KATA-009) : positions calculées **une seule fois** au mount en `px`, sans recalcul au resize.

## §7. Tolérances de mesure

- **Comparaisons en `%`** : `±0.5%` (la formule donne des valeurs exactes ; cette marge absorbe les imprécisions de mesure).
- **Comparaisons en `px`** : `±2px` (subpixel rounding navigateur, anti-aliasing).
- **Différence de width entre évènements d'un même cluster** (R-KATA-006) : `±1px`. Au-delà, finding BLOCKER.

## §8. Sélecteurs de mesure (ordre de préférence)

R-KATA-001 garantit que chaque `div` d'évènement porte un attribut `id` strictement égal à `event.id`. Le sélecteur idéal est donc :

1. **Préféré** : `[id="<event.id>"]` (ex. `[id="42"]`). Confidence = `high`.
2. **Fallback 1** : `[data-event-id="<event.id>"]` si l'implémentation en ajoute. Confidence = `high`.
3. **Fallback 2** : `[data-testid="event-<id>"]` ou similaire. Confidence = `medium`.
4. **Heuristique de dernier recours** : énumérer les `.event`, `.calendar-event`, ou enfants directs du conteneur calendrier ; matcher par `textContent` qui contient l'id (R-KATA-002 le garantit). Confidence = `low`, documenter dans `evidence.measurement`.

Si **aucune** stratégie ne fonctionne (par exemple R-KATA-001 et R-KATA-002 sont tous deux violés), émettre un finding `R-RUNTIME-NNN` séparé pour « evidence collection impossible — kata id requirements violated, see R-KATA-001/002 ».

## §9. Procédure de mesure DOM (Playwright MCP)

À chaque mesure :

1. **Attendre la stabilité du layout** avant de mesurer :
   - `await page.waitForLoadState('networkidle')` après navigation.
   - Évaluer en page : `await Promise.all([new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))), document.fonts.ready])`.
2. **Mesurer relativement au conteneur**, pas à la viewport :
   ```js
   const container = document.querySelector('.calendar') || document.querySelector('[data-testid="calendar"]') || document.body.firstElementChild;
   const containerRect = container.getBoundingClientRect();
   const eventRect = document.querySelector(selector).getBoundingClientRect();
   const top_relative_px = eventRect.top - containerRect.top;
   const top_pct = top_relative_px / containerRect.height * 100;
   ```
3. **Ignorer pendant les animations** : si `getComputedStyle(el).transition !== 'none 0s ease 0s'` et `getComputedStyle(el).transitionDuration !== '0s'`, attendre `transitionend` ou un `setTimeout` cohérent avant de mesurer. Sinon, confidence = `medium` et le noter.
4. **Viewports à mesurer** :
   - Desktop : **1280×720** (par défaut Playwright).
   - Mobile (pour R-KATA-009) : **375×667** (iPhone SE). Re-mesurer après `page.setViewportSize({ width: 375, height: 667 })` + nouvelle stabilisation rAF×2.

## §10. Exemples expected/actual

### Exemple A — Évènement à 12:00, durée 60min, container 1200×900px

```
eventStartMinutes = 12*60 = 720
top_pct  = (720 - 540) / 720 * 100 = 25%
top_px   = 25% * 900 = 225px
height_pct = 60 / 720 * 100 = 8.33%
height_px  = 8.33% * 900 = 75px
```

Avec `containerHeight = 1200px` (cas canonique README) : `height_px = 8.33% * 1200 = 100px` ✅ (correspond exactement à l'exemple du README).

### Exemple B — Cluster de 3 évènements chevauchants, container width 1024px

```
maxConcurrent = 3
width_pct = 100 / 3 ≈ 33.33%
width_px  = 33.33% * 1024 ≈ 341.33px
left_pct  = col * 33.33%  (col ∈ {0, 1, 2})
```

Somme au pic : `3 * 341.33 ≈ 1024px = containerWidth` ✅.

### Exemple C — Finding négatif typique (R-KATA-004 BLOCKER, evidence.kind = "dom")

```json
{
  "ruleId": "R-KATA-004",
  "severity": "BLOCKER",
  "domain": "kata-compliance",
  "evidence": {
    "kind": "dom",
    "expected": "top = 25% of container height for event at 12:00 (oracle §3, §10 example A)",
    "actual": "top = 31.2%",
    "tolerance": "±0.5%",
    "selector": "[id='42']",
    "measurement": "getBoundingClientRect().top relative to .calendar container, viewport 1280×720, after rAF×2 + fonts.ready",
    "confidence": "high"
  }
}
```

## §11. Patterns adversariaux (test de l'algorithme de clustering)

L'input fourni par le kata (`src/assets/input.json`) peut être bénin et masquer un algorithme défaillant. R-KATA-006/007 exigent que **l'algorithme** soit robuste, pas seulement que le rendu sur l'input fourni soit visuellement correct. Tester mentalement (ou via tests unitaires) le clustering sur ces 3 patterns canoniques :

### Pattern 1 — Escalier (le piège classique du first-fit packing)

```
A: 17:00–19:00 (durée 120)
B: 17:00–18:00 (durée 60)
C: 18:30–19:30 (durée 60)
```

- **Concurrence simultanée** : à 17:00 → {A, B} (2) ; à 18:00 → {A} (1) ; à 18:30 → {A, C} (2) ; à 19:00 → {C} (1). **Peak = 2**.
- **Attendu** (R-KATA-007 lecture Outlook) : `totalColumns = 2`, `width = 50%` pour chaque event.
- **First-fit naïf échoue** : B prend col 0, A prend col 1 (B et A se chevauchent à 17:00). C ne peut pas prendre col 0 (B finit à 18:00, C démarre à 18:30 → OK col 0 est libre), mais A occupe col 1 jusqu'à 19:00. Donc C prend col 0. `totalColumns = 2` ✅ si l'algo recycle bien les colonnes.
- **Variante du piège** : B 17:00–18:00, A 17:00–19:00, C 18:00–19:30. Cette fois C démarre à 18:00 (= fin de B). Selon que l'algo utilise `>` strict ou `>=` pour réutiliser, C va en col 0 (peak=2) ou col 2 (peak=3 → bug). Lire l'algorithme et identifier l'opérateur de comparaison.

### Pattern 2 — Trois empilés au pic

```
A: 12:00–13:00
B: 12:00–13:00
C: 12:00–13:00
```

- **Peak = 3**, `totalColumns = 3`, `width = 33.33%`.
- Test trivial — si ça échoue, l'algorithme est complètement cassé.

### Pattern 3 — Long avec deux courts décalés

```
A: 12:00–15:00 (durée 180)
B: 12:00–13:00
C: 14:00–15:00
```

- **Concurrence** : 12:00 → {A,B}, 13:00 → {A}, 14:00 → {A,C}. **Peak = 2**.
- **Attendu** : B et C peuvent partager la col 0 (B finit à 13:00, C démarre à 14:00 — pas de chevauchement). `totalColumns = 2`, `width = 50%`.
- **Algo défaillant** : si l'algorithme crée une nouvelle colonne par évènement sans recyclage, `totalColumns = 3`.

### Procédure de validation R-KATA-006/007

Sans Playwright MCP : lire l'algorithme du candidat (ex. dans un service `CalendarLayoutService` ou directement dans un composant). Tracer mentalement le placement de chaque pattern. Si l'algorithme retourne `totalColumns > peak_simultaneous` sur l'un des 3 patterns → finding `R-KATA-007 MAJOR` avec `evidence.kind = "static"`, `expected = "totalColumns = <peak>"`, `actual = "<observed>"`, `confidence = "high"`.

Avec Playwright MCP : générer un `input.test.json` contenant le pattern, charger l'app avec cet input (override de la fixture), mesurer `Σ widths` au pic. Finding `evidence.kind = "dom"`.
