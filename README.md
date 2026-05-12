# agent-skill

Collection of [Claude Code](https://claude.com/claude-code) skills.

## Available skills

| Skill | Description |
|---|---|
| [`angular-review`](./angular-review) | Multi-subagent Angular code review (security, architecture, performance, a11y/errors) using guidelines compiled from angular.dev. Read-only — produces a markdown report, never modifies code. |

## Install a skill

Skills live in `.claude/skills/<skill-name>/` (project-local) or `~/.claude/skills/<skill-name>/` (user-global).

### Project-local install

From the root of your project:

```bash
mkdir -p .claude/skills
git clone https://github.com/PrincyExaltIT/agent-skill.git /tmp/agent-skill
cp -r /tmp/agent-skill/angular-review .claude/skills/
```

### User-global install (available in every project)

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/PrincyExaltIT/agent-skill.git /tmp/agent-skill
cp -r /tmp/agent-skill/angular-review ~/.claude/skills/
```

Then in Claude Code, invoke with `/angular-review` (optionally followed by a target: `PR <num>`, `<branch>`, `staged`, or a commit range).

## License

[MIT](./LICENSE)
