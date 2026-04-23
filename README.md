# Context7 Skill

Portable Agent Skill for retrieving up-to-date library documentation via Context7 by Upstash.

## Install

Primary install path:

```bash
npx skills add <your-username>/context7-skill -g
```

Target a specific agent:

```bash
npx skills add <your-username>/context7-skill -g -a claude-code
```

Manual fallback:

```bash
git clone https://github.com/<your-username>/context7-skill
cp -r context7-skill/skills/context7-docs ~/.claude/skills/
```

## Prerequisites

- `bash`
- `curl`
- `python` (3.9+)
- A Context7 API key from `https://context7.com/dashboard` (free tier available)

## First Run

The skill checks for a key in this order:

1. `CONTEXT7_API_KEY` env var
2. `./.env` in the current working directory
3. `~/.config/context7/config.json`
4. `~/.context7` legacy file

If none is found, the scripts print a `CONTEXT7_AUTH_REQUIRED` marker. The agent will ask you for a key, run `scripts/save-key.sh <key>`, then retry.

Manual setup:

```bash
bash skills/context7-docs/scripts/save-key.sh <your-c7-key>
```

## Included Scripts

- `scripts/library.sh` — search for a library by name and get its Context7 ID
- `scripts/ask.sh` — query documentation for a specific library ID
- `scripts/save-key.sh` — validate and persist API key
- `scripts/preflight.sh` — shared auth and dependency checks

## Example

Find a library:

```bash
bash skills/context7-docs/scripts/library.sh "next.js"
```

Query docs:

```bash
bash skills/context7-docs/scripts/ask.sh "/vercel/next.js" "How do I create middleware?"
```
