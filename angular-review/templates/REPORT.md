# Review Angular — {{TARGET}}

**Verdict** : {{VERDICT}}  <!-- APPROVE | COMMENT | REQUEST_CHANGES -->

## Résumé
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

## Cible
{{TARGET_DESCRIPTION}} — {{N_FILES}} fichier(s) modifié(s)

<!--
Règles de verdict :
- ≥ 1 BLOCKER  → REQUEST_CHANGES
- ≥ 3 MAJOR    → REQUEST_CHANGES
- 0 finding & 0 INFO → APPROVE
- sinon → COMMENT

Si une catégorie est vide, retirer la section correspondante (ne pas afficher "aucun").
-->
