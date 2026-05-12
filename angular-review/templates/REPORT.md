# Review Angular — {{TARGET}}

**Verdict** : {{VERDICT}}  <!-- APPROVE | COMMENT | REQUEST_CHANGES -->

## Conformité projet (si R-PROJ actif)
- 🎯 R-PROJ BLOCKER : {{N_PROJ_BLOCKER}}
- 🎯 R-PROJ MAJOR   : {{N_PROJ_MAJOR}}
- 🎯 R-PROJ MINOR   : {{N_PROJ_MINOR}}

> Un seul R-PROJ BLOCKER suffit à classer le rendu en `REQUEST_CHANGES` (non-conformité au cahier des charges).

## Résumé global
- 🔴 BLOCKER : {{N_BLOCKER}}
- 🟠 MAJOR   : {{N_MAJOR}}
- 🟡 MINOR   : {{N_MINOR}}
- 🔵 INFO    : {{N_INFO}}

## Findings

### 🔴 BLOCKER
<!-- Pour chaque finding BLOCKER : -->
- **{{ruleId}}** — `{{file}}:{{line}}`
  > {{snippet}}
  {{message}} — {{suggestion}}
  Source : {{source}}

### 🟠 MAJOR
<!-- idem -->

### 🟡 MINOR
<!-- idem -->

### 🔵 INFO
<!-- idem -->

## Subagents lancés
- angular-security-reviewer — {{N}} findings
- angular-architecture-reviewer — {{N}} findings
- angular-performance-reviewer — {{N}} findings
- angular-a11y-error-reviewer — {{N}} findings
- project-compliance-reviewer — {{N}} findings *(si R-PROJ actif)*

## Validation empirique (Playwright MCP)
<!--
Si l'étape 6 a été exécutée, lister ici les vérifications faites et leur résultat.
Si non exécutée, écrire : « Non exécutée — <raison> ».

Format suggéré :
- ✅ Navigation vers http://localhost:4200 — OK
- ✅ Snapshot ARIA capturé — pas de violation a11y runtime
- ✅ Resize 1280→700 — layout conserve les contraintes attendues
- ❌ Attribut `id` manquant sur l'élément `.event` #3 — finding R-PROJ-001 promu BLOCKER

Suite Playwright versionnée (si présente) :
- ✅ tests/foo.spec.ts (5 tests, 5 passed)
- Rapport HTML : `npx playwright show-report` → http://localhost:9323
-->

## Cible
{{TARGET_DESCRIPTION}} — {{N_FILES}} fichier(s) modifié(s)

<!--
Règles de verdict :
- ≥ 1 BLOCKER R-PROJ          → REQUEST_CHANGES (non-conformité projet)
- ≥ 1 BLOCKER (tous prefixes) → REQUEST_CHANGES
- ≥ 3 MAJOR                   → REQUEST_CHANGES
- 0 finding & 0 INFO          → APPROVE
- sinon                       → COMMENT

Si une catégorie est vide, retirer la section correspondante (ne pas afficher "aucun").
-->
