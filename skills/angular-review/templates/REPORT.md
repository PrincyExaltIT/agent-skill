# Review Angular — {{TARGET}}

**Verdict** : {{VERDICT}}  <!-- APPROVE | COMMENT | REQUEST_CHANGES -->

## Conformité projet ({{RULE_PREFIX}}) — *si reviewer actif*

> Affiche cette section uniquement si `references/PROJECT_COMPLIANCE_REVIEW.md` contient au moins une règle. `{{RULE_PREFIX}}` est lu dynamiquement depuis le frontmatter `rule_prefix` (défaut `R-PROJ`).

- 🎯 {{RULE_PREFIX}} BLOCKER : {{N_PROJ_BLOCKER}}
- 🎯 {{RULE_PREFIX}} MAJOR   : {{N_PROJ_MAJOR}}
- 🎯 {{RULE_PREFIX}} MINOR   : {{N_PROJ_MINOR}}

> Un seul BLOCKER sous `{{RULE_PREFIX}}` suffit à classer le rendu en `REQUEST_CHANGES` (non-conformité au cahier des charges).

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
  <!-- si evidence présent : -->
  Evidence ({{evidence.kind}}, confidence {{evidence.confidence}})

### 🟠 MAJOR
<!-- idem -->

### 🟡 MINOR
<!-- idem -->

### 🔵 INFO
<!-- idem -->

## Subagents lancés
- angular-security-reviewer — {{N_R_SEC}} findings
- angular-architecture-reviewer — {{N_R_ARCH}} findings
- angular-performance-reviewer — {{N_R_PERF}} findings
- angular-a11y-error-reviewer — {{N_R_A11Y_ERR}} findings
- project-compliance-reviewer — {{N_R_PROJ}} findings *(si actif, prefix `{{RULE_PREFIX}}`)*

## Validation empirique (Playwright MCP)
<!--
Si l'étape 6 a été exécutée, lister ici les vérifications faites et leur résultat.
Si non exécutée, écrire : « Non exécutée — <raison> ».

Format suggéré :
- ✅ Navigation vers http://localhost:4200 — OK
- ✅ Snapshot ARIA capturé — pas de violation a11y runtime
- ✅ Resize 1280→700 — layout conserve les contraintes attendues
- ❌ Contrainte projet violée à la mesure — finding {{RULE_PREFIX}}-NNN promu BLOCKER

Suite Playwright versionnée (si présente) :
- ✅ tests/foo.spec.ts (5 tests, 5 passed)
- Rapport HTML : `npx playwright show-report` → http://localhost:9323
-->

## Cible
{{TARGET_DESCRIPTION}} — {{N_FILES}} fichier(s) modifié(s)

<!--
Règles de verdict (générique — adaptables par variante de skill) :
- ≥ 1 BLOCKER {{RULE_PREFIX}}        → REQUEST_CHANGES (non-conformité projet)
- ≥ 1 BLOCKER (tous prefixes)        → REQUEST_CHANGES
- ≥ 3 MAJOR                          → REQUEST_CHANGES
- 0 finding & 0 INFO                 → APPROVE
- sinon                              → COMMENT

Si une catégorie est vide, retirer la section correspondante (ne pas afficher "aucun").
-->
