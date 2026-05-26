# Exemple — prompt envoyé au `kata-compliance-reviewer`

Exemple concret du prompt que l'orchestrator passe à `kata-compliance-reviewer` via l'outil sub-agent (Claude `Agent`, Copilot `runSubagent`, Codex `subagents`).

```
You are the kata-compliance-reviewer subagent for the « Rendering Events » kata audit.

Load your rules from: .claude/skills/angular-review-kata-rendering-events/references/PROJECT_COMPLIANCE_REVIEW.md
Load the measurement oracle from: .claude/skills/angular-review-kata-rendering-events/references/KATA_LAYOUT_ORACLE.md

Apply ONLY rules with prefix R-KATA. Severity levels: BLOCKER, MAJOR, MINOR, INFO.

## Files in scope
- src/app/calendar.component.html
- src/app/calendar.component.ts
- src/app/calendar.service.ts
- package.json

## Diff to review
```diff
diff --git a/src/app/calendar.component.html b/src/app/calendar.component.html
@@ -12,8 +12,8 @@
   @for (event of events(); track event.id) {
-    <div class="event" [id]="event.id" [style.top.%]="topPct(event)" [style.height.%]="heightPct(event)">
+    <div class="event" [attr.data-id]="event.id" [style.top.px]="event.start" [style.height.px]="event.duration">
       {{ event.id }}
     </div>
   }
```

## Output

Return a single JSON object — NO prose, NO markdown — valid against:
https://raw.githubusercontent.com/PrincyExaltIT/agent-skill/main/schema/subagent-output.schema.json

For every finding, include an `evidence` object:
- For findings discovered by reading the diff/source only: `evidence.kind = "static"` with `expected` / `actual` where applicable.
- For findings discovered by DOM measurement (Step 6 via Playwright MCP): `evidence.kind = "dom"` MUST include `expected`, `actual`, `tolerance`, `selector`, `measurement`, `confidence` — citing the relevant `KATA_LAYOUT_ORACLE.md` section.

{
  "$schema": "https://raw.githubusercontent.com/PrincyExaltIT/agent-skill/main/schema/subagent-output.schema.json",
  "agent": "kata-compliance-reviewer",
  "findings": [
    {
      "ruleId": "R-KATA-NNN",
      "severity": "BLOCKER|MAJOR|MINOR|INFO",
      "domain": "kata-compliance",
      "file": "path/to/file.html",
      "line": <number>,
      "snippet": "<line excerpt>",
      "message": "<violation observed>",
      "suggestion": "<fix>",
      "source": "README.md or references/KATA_LAYOUT_ORACLE.md",
      "evidence": {
        "kind": "static|dom",
        "expected": "<oracle-derived value>",
        "actual": "<observed value>",
        "tolerance": "<e.g. ±0.5% or ±2px>",
        "selector": "<CSS selector when kind=dom>",
        "measurement": "<measurement procedure when kind=dom>",
        "confidence": "high|medium|low"
      }
    }
  ]
}

If no findings: {"$schema": "...", "agent": "kata-compliance-reviewer", "findings": []}
```

Voir `examples/subagent-output.json` pour un exemple concret de sortie avec trois findings : un statique (R-KATA-001), un DOM mesuré (R-KATA-004), et un DOM-only (R-RUNTIME-001 sans contrepartie statique).
