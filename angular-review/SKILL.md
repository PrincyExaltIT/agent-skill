---
name: angular-review
description: Lance un review Angular multi-subagents (sécurité, architecture, performance, a11y/erreurs) sur la branche courante ou un diff spécifié. Utilise les guidelines officielles compilées depuis angular.dev. Invoquer avec /angular-review (optionnellement suivi d'une cible : "PR <num>", "<branch>", "staged", "<commit-range>").
---

# Skill — angular-review

Tu es l'**orchestrator** d'un review Angular multi-subagents. Ce skill est **READ-ONLY** : ne jamais modifier de code, commit, push.

## Structure du skill (ressources bundlées)

```
.claude/skills/angular-review/
├── SKILL.md                          ← ce fichier (entry point)
├── references/                       ← chargées par les subagents à la demande
│   ├── SECURITY_REVIEW.md            ← R-SEC (23 règles)
│   ├── ARCHITECTURE_CLEAN_CODE_REVIEW.md ← R-ARCH (26 règles)
│   ├── PERFORMANCE_REVIEW.md         ← R-PERF (33 règles)
│   └── A11Y_AND_ERROR_HANDLING_REVIEW.md ← R-A11Y + R-ERR (24 règles)
├── templates/
│   └── REPORT.md                     ← gabarit du rapport final
├── reports/                          ← rapports générés (review-<timestamp>.md), créé à la volée
└── examples/
    ├── subagent-prompt.md            ← exemple de prompt subagent
    └── subagent-output.json          ← exemple de sortie JSON
```

Chaque guideline dans `references/` a un frontmatter (`name`, `domain`, `rule_prefix`, `applies_to`, `severity_levels`, `sources`) que l'orchestrator lit pour matcher les fichiers modifiés.

## Étape 1 — Déterminer la cible du review

Selon l'argument passé au skill :

| Argument | Cible du diff |
|---|---|
| (vide) | `git diff main...HEAD` |
| `staged` | `git diff --cached` |
| `PR <num>` | `gh pr diff <num>` |
| `<branch>` | `git diff main...<branch>` |
| `<range>` (ex: `abc..def`) | `git diff <range>` |

Calculer aussi la liste des fichiers modifiés (`--name-only`), filtrer hors `node_modules/`, `dist/`, `*.lock`, fichiers binaires.

Si le diff est **vide** → afficher « Aucun changement à reviewer » et arrêter.

## Étape 2 — Sélectionner les subagents éligibles

Lire le frontmatter de chaque fichier dans `.claude/skills/angular-review/references/`. Activer le subagent **si au moins un fichier modifié matche un glob de `applies_to`**.

Subagents disponibles :

| Subagent | Reference file | Rule prefix |
|---|---|---|
| `angular-security-reviewer` | `references/SECURITY_REVIEW.md` | `R-SEC` |
| `angular-architecture-reviewer` | `references/ARCHITECTURE_CLEAN_CODE_REVIEW.md` | `R-ARCH` |
| `angular-performance-reviewer` | `references/PERFORMANCE_REVIEW.md` | `R-PERF` |
| `angular-a11y-error-reviewer` | `references/A11Y_AND_ERROR_HANDLING_REVIEW.md` | `R-A11Y`, `R-ERR` |

Logger : `Subagents activés : <liste> (skipped : <liste>)`.

## Étape 3 — Lancer les subagents EN PARALLÈLE

**Règle critique** : émettre **un seul message** contenant **N appels `Agent`** parallèles (un par subagent éligible). Pas d'appels séquentiels.

Pour chaque subagent éligible, utiliser `subagent_type: general-purpose` avec ce prompt :

```
You are the <SUBAGENT_NAME> subagent for an Angular code review.

Load your rules from: .claude/skills/angular-review/references/<REFERENCE_FILE>

Apply ONLY rules with prefix <RULE_PREFIX>. Severity levels: BLOCKER, MAJOR, MINOR, INFO.

## Files in scope
<liste des fichiers matchant applies_to>

## Diff to review
```diff
<unified diff, ≤ 50 KB ; sinon découper>
```

## Output
Return a single JSON object — NO prose, NO markdown:

{
  "agent": "<SUBAGENT_NAME>",
  "findings": [
    {
      "ruleId": "<PREFIX>-NNN",
      "severity": "BLOCKER|MAJOR|MINOR|INFO",
      "domain": "<domain>",
      "file": "path/to/file.ts",
      "line": <number>,
      "snippet": "<line excerpt>",
      "message": "<what's wrong>",
      "suggestion": "<how to fix>",
      "source": "<angular.dev URL>"
    }
  ]
}

If no findings: {"agent": "<SUBAGENT_NAME>", "findings": []}
```

Voir `examples/subagent-prompt.md` pour un exemple concret et `examples/subagent-output.json` pour la sortie attendue.

**Garde-fous** :
- Si le diff dépasse 50 KB pour un subagent → le découper en paquets de fichiers et lancer plusieurs invocations parallèles du même subagent dans le même message.
- Donner un `description` court et différent par appel d'`Agent` (requis par l'outil).

## Étape 4 — Agrégation

Une fois tous les subagents revenus :

1. **Parser** chaque réponse comme JSON. Si parse échoue → warning + ignorer ses findings.
2. **Fusionner** les `findings` en une seule liste.
3. **Dédupliquer** par `(file, line, ruleId)`.
4. **Trier** par sévérité décroissante (`BLOCKER > MAJOR > MINOR > INFO`) puis par `file`.
5. **Compter** par sévérité.
6. **Calculer le verdict** :
   - `≥ 1 BLOCKER` → `REQUEST_CHANGES`
   - `≥ 3 MAJOR` → `REQUEST_CHANGES`
   - `0 finding & 0 INFO` → `APPROVE`
   - sinon → `COMMENT`

## Étape 5 — Rapport final

Charger `templates/REPORT.md` et substituer les placeholders `{{...}}`. Si une catégorie de sévérité est vide, retirer la section correspondante.

**Toujours produire deux sorties** :

1. **Fichier markdown** — écrire le rapport dans `.claude/skills/angular-review/reports/review-<YYYYMMDD-HHmmss>.md` (timestamp local).
   - Créer le dossier `reports/` s'il n'existe pas (via `Bash` `mkdir -p` ou équivalent PowerShell).
   - Le timestamp évite l'écrasement entre runs successifs.
   - Le contenu écrit doit être **identique** à ce qui est affiché à l'utilisateur (template substitué).
   - Utiliser l'outil `Write` (autorisé ici car cible = artefact du skill, pas le code source).

2. **Affichage inline** — afficher le rapport markdown directement dans la réponse à l'utilisateur, et indiquer en première ligne le chemin du fichier écrit (ex. `📄 Rapport écrit : .claude/skills/angular-review/reports/review-20260505-143022.md`).

> Note : `reports/` doit être ajouté à `.gitignore` du projet si l'utilisateur ne souhaite pas versionner les rapports — ne pas le faire automatiquement.

## Garde-fous globaux

- **READ-ONLY sur le code** : aucun `Edit`/`Write` sur les sources de l'application. Aucun `git commit`/`git push`. Seule exception autorisée : écrire le rapport markdown sous `.claude/skills/angular-review/reports/`.
- **Pas de fix automatique** : juste lister les findings.
- **Pas de network** au-delà de `gh pr diff` si une PR est ciblée. Les guidelines sont déjà compilées localement.
- **Confidentialité** : ne pas envoyer le diff à un service externe.

## Astuces

- Si `git` indispo ou pas de remote `main` → demander la cible à l'utilisateur.
- Si aucun fichier `*.ts`/`*.html` modifié → tous skippés ; afficher un message clair.
- Pour reviewer un seul fichier : `staged`, ou `HEAD~1..HEAD`.
