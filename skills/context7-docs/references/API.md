# Context7 API Reference

## Base URL

`https://context7.com/api`

## Authentication

All endpoints require a Bearer token in the `Authorization` header:

```
Authorization: Bearer <CONTEXT7_API_KEY>
```

API keys start with `c7_` and can be generated at https://context7.com/dashboard.

## Endpoints

### GET /libraries

Search for libraries by name.

**Query Parameters:**
- `q` (required) — search query / library name
- `limit` (optional) — max results to return (default: 10)

**Example:**

```bash
curl -sS "https://context7.com/api/libraries?q=next.js&limit=5" \
  -H "Authorization: Bearer $CONTEXT7_API_KEY"
```

**Response:**

```json
[
  {
    "id": "/vercel/next.js",
    "name": "Next.js",
    "description": "The React Framework for the Web",
    "version": "15.1.0"
  }
]
```

### POST /docs

Retrieve documentation for a specific library.

**Request Body:**

```json
{
  "libraryId": "/vercel/next.js",
  "query": "How do I create middleware?"
}
```

**Example:**

```bash
curl -sS -X POST "https://context7.com/api/docs" \
  -H "Authorization: Bearer $CONTEXT7_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"libraryId":"/vercel/next.js","query":"How do I create middleware?"}'
```

**Response Shape:**

The API returns documentation content, which may include:
- `content` / `answer` — main textual answer
- `results` — array of relevant snippets
- `sources` / `citations` — source URLs

## Error Codes

| HTTP | Meaning |
|---|---|
| 401 | Invalid or missing API key |
| 429 | Rate limit exceeded |
| 500 | Internal server error |

## Rate Limits

- Free tier has generous daily limits.
- Higher limits and private repos require a paid API key.

## MCP Server

Context7 also provides an MCP server at `https://mcp.context7.com/mcp` for native agent integration.

## More Info

- Website: https://context7.com
- Docs: https://context7.com/docs
- Dashboard: https://context7.com/dashboard
