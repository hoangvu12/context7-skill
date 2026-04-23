---
name: context7-docs
description: Retrieve up-to-date, version-specific library documentation and code examples using Context7 by Upstash. Use when the user asks about library APIs, framework configuration, coding patterns, setup instructions, or any question where current documentation would produce better code than training-data knowledge.
---

# Context7 Docs

## When to use

Use this skill when the user needs:
- Current API documentation for a specific library or framework
- Version-specific setup or configuration steps
- Code examples that match the latest release of a package
- Answers to "how do I..." questions about third-party libraries

Context7 provides real-time documentation so the agent does not rely on stale training data or hallucinated APIs.

## Prerequisites

- `bash`
- `curl`
- `python` (3.9+)
- A Context7 API key (free tier available at https://context7.com/dashboard)

## Authentication Flow

The scripts resolve credentials in this order:

1. `CONTEXT7_API_KEY` environment variable
2. `./.env` in the current working directory
3. `~/.config/context7/config.json`
4. `~/.context7` legacy plaintext file

If no key is found, the scripts print a `CONTEXT7_AUTH_REQUIRED` marker. The agent should ask the user for their key, run `bash scripts/save-key.sh <key>`, then retry the original command.

## Commands

### Find a library

```bash
bash scripts/library.sh "<library-name>"
```

Example:

```bash
bash scripts/library.sh "next.js"
```

Returns a list of matching libraries with their Context7 IDs (e.g. `/vercel/next.js`).

### Query documentation

```bash
bash scripts/ask.sh "<library-id>" "<question>"
```

Example:

```bash
bash scripts/ask.sh "/vercel/next.js" "How do I create a middleware that checks JWT cookies?"
```

## Output Rules

- Always include code examples from the documentation when relevant.
- Cite the source URLs when Context7 provides them.
- If multiple libraries match, ask the user which one they mean.
- If a library is not found, suggest checking the exact name or visiting https://context7.com.

## Rate Limits

- Free tier: generous daily limits (subject to change — see dashboard)
- Higher limits require an API key

## References

- `references/API.md` — endpoint and parameter reference
