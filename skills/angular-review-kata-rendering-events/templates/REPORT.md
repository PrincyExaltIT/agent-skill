# Review Angular — Kata Rendering Events — {{TARGET}}

**Verdict** : {{VERDICT}}  <!-- APPROVE | COMMENT | REQUEST_CHANGES -->

## Conformité kata (R-KATA)
- 🎯 R-KATA BLOCKER : {{N_KATA_BLOCKER}}
- 🎯 R-KATA MAJOR   : {{N_KATA_MAJOR}}
- 🎯 R-KATA MINOR   : {{N_KATA_MINOR}}

> Un seul R-KATA BLOCKER suffit à classer le rendu en `REQUEST_CHANGES` (non-conformité au cahier des charges du kata).

## Empirical validation
**Status** : {{EMPIRICAL_STATUS}}  <!-- passed | failed | skipped -->

<!--
Bloc OBLIGATOIRE pour le kata. Trois statuts possibles :

- `passed`  — Step 6 a tourné, toutes les contraintes mesurables de KATA_LAYOUT_ORACLE.md sont satisfaites.
- `failed`  — Step 6 a tourné et a émis ≥ 1 finding avec evidence.kind = "dom".
- `skipped` — Step 6 n'a pas tourné (Playwright MCP indisponible, dev server en échec, etc.). Donner la raison.

Quand `skipped` ou `failed`, le verdict est PLAFONNÉ à `COMMENT` (cf. Step 4.6 de ORCHESTRATION.md).

Pour chaque finding mesuré, citer inline : expected / actual / tolerance / selector / confidence,
pour que le lecteur voie la preuve sans ouvrir le JSON.
-->

## Findings kata (R-KATA) — pilote le verdict

### 🔴 R-KATA BLOCKER ({{N_KATA_BLOCKER}})
<!-- Pour chaque finding R-KATA BLOCKER : -->
- **{{ruleId}}** — `{{file}}:{{line}}`
  > {{snippet}}
  {{message}} — {{suggestion}}
  Source : {{source}}
  Evidence ({{evidence.kind}}, confidence {{evidence.confidence}}) — expected: {{evidence.expected}} | actual: {{evidence.actual}} | tolerance: {{evidence.tolerance}} | selector: `{{evidence.selector}}`

### 🟠 R-KATA MAJOR ({{N_KATA_MAJOR}})

### 🟡 R-KATA MINOR ({{N_KATA_MINOR}})

### 🔵 R-KATA INFO ({{N_KATA_INFO}})

## Hygiène prod (informatif — n'affecte pas le verdict kata)

> Les findings ci-dessous viennent des reviewers `angular-security-reviewer`, `angular-architecture-reviewer`, `angular-performance-reviewer`, `angular-a11y-error-reviewer`. Ils utilisent BLOCKER/MAJOR au sens « qualité Angular en production », pas au sens « kata non rendu ». Le verdict du kata est piloté **uniquement** par les findings R-KATA ci-dessus.

### 🔴 Hygiène BLOCKER ({{N_HYGIENE_BLOCKER}})

### 🟠 Hygiène MAJOR ({{N_HYGIENE_MAJOR}})

### 🟡 Hygiène MINOR ({{N_HYGIENE_MINOR}})

### 🔵 Hygiène INFO ({{N_HYGIENE_INFO}})

## Résumé chiffré
- Total R-KATA : 🔴 {{N_KATA_BLOCKER}} | 🟠 {{N_KATA_MAJOR}} | 🟡 {{N_KATA_MINOR}} | 🔵 {{N_KATA_INFO}}
- Total Hygiène : 🔴 {{N_HYGIENE_BLOCKER}} | 🟠 {{N_HYGIENE_MAJOR}} | 🟡 {{N_HYGIENE_MINOR}} | 🔵 {{N_HYGIENE_INFO}}

## Subagents lancés
- angular-security-reviewer — {{N_R_SEC}} findings
- angular-architecture-reviewer — {{N_R_ARCH}} findings
- angular-performance-reviewer — {{N_R_PERF}} findings
- angular-a11y-error-reviewer — {{N_R_A11Y_ERR}} findings
- kata-compliance-reviewer — {{N_R_KATA}} findings (R-KATA prefix)
- dom-verifier (Step 6) — {{N_R_RUNTIME}} R-RUNTIME findings + {{N_R_KATA_DOM}} R-KATA DOM-measured findings

## Cible
{{TARGET_DESCRIPTION}} — {{N_FILES}} fichier(s) modifié(s)

<!--
Règles de verdict (kata variant) — seuls les findings R-KATA pilotent le verdict :
- ≥ 1 BLOCKER R-KATA                                                      → REQUEST_CHANGES (non-conformité kata)
- ≥ 3 MAJOR R-KATA                                                        → REQUEST_CHANGES (problèmes significatifs de fidélité)
- 0 R-KATA BLOCKER & < 3 R-KATA MAJOR, DOM validation passed              → APPROVE
- 0 R-KATA BLOCKER & < 3 R-KATA MAJOR, DOM validation skipped/failed      → COMMENT (aucun APPROVE sans preuve mesurée — cf. Step 6)
- 0 R-KATA BLOCKER & < 3 R-KATA MAJOR, DOM passed, hygiène BLOCKER/MAJOR  → COMMENT (kata accepté, mais qualité prod à améliorer)

Les findings hygiène (R-SEC/R-ARCH/R-PERF/R-A11Y/R-ERR) ne forcent JAMAIS REQUEST_CHANGES en variante kata.

Si une catégorie est vide, retirer la section correspondante (ne pas afficher "aucun").
-->
