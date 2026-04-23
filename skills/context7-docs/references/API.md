# Context7 API Reference

## Base URL

`https://context7.com/api`

## Authentication

All API requests require authentication using an API key. Include your API key in the `Authorization` header:

```
Authorization: Bearer <CONTEXT7_API_KEY>
```

API keys start with `ctx7sk` and can be generated at https://context7.com/dashboard.

## Endpoints

### GET /v2/libs/search

Search for libraries by name with intelligent LLM-powered ranking.

**Query Parameters:**
- `libraryName` (required) — library name to search for (e.g., 'react', 'nextjs')
- `query` (required) — user's question or task for relevance ranking

**Example:**

```bash
curl -sS "https://context7.com/api/v2/libs/search?libraryName=react&query=hooks" \
  -H "Authorization: Bearer $CONTEXT7_API_KEY"
```

**Response:**

```json
{
  "results": [
    {
      "id": "/facebook/react",
      "title": "React",
      "description": "A JavaScript library for building user interfaces",
      "branch": "main",
      "lastUpdateDate": "2025-01-15T10:30:00.000Z",
      "state": "finalized",
      "totalTokens": 500000,
      "totalSnippets": 2500,
      "stars": 220000,
      "trustScore": 10,
      "benchmarkScore": 95.5,
      "versions": ["v18.2.0", "v17.0.2"]
    }
  ],
  "searchFilterApplied": false
}
```

### GET /v2/context

Retrieve intelligent, LLM-reranked documentation context for natural language queries.

**Query Parameters:**
- `libraryId` (required) — Context7-compatible library ID (e.g., `/vercel/next.js`)
- `query` (required) — user's question or task
- `type` (optional) — response format: `json` or `txt` (default: `txt`)

**Example:**

```bash
curl -sS "https://context7.com/api/v2/context?libraryId=%2Fvercel%2Fnext.js&query=How%20to%20use%20middleware&type=json" \
  -H "Authorization: Bearer $CONTEXT7_API_KEY"
```

**Response (JSON):**

```json
{
  "codeSnippets": [
    {
      "codeTitle": "Middleware Authentication Example",
      "codeDescription": "Shows how to implement authentication checks in Next.js middleware",
      "codeLanguage": "typescript",
      "codeTokens": 150,
      "codeId": "https://github.com/vercel/next.js/blob/canary/docs/middleware.mdx#_snippet_0",
      "pageTitle": "Middleware",
      "codeList": [
        {
          "language": "typescript",
          "code": "import { NextResponse } from 'next/server'\nimport type { NextRequest } from 'next/server'\n\nexport function middleware(request: NextRequest) {\n  const token = request.cookies.get('token')\n  if (!token) {\n    return NextResponse.redirect(new URL('/login', request.url))\n  }\n  return NextResponse.next()\n}"
        }
      ]
    }
  ],
  "infoSnippets": [
    {
      "pageId": "https://github.com/vercel/next.js/blob/canary/docs/middleware.mdx",
      "breadcrumb": "Routing > Middleware",
      "content": "Middleware allows you to run code before a request is completed...",
      "contentTokens": 200
    }
  ]
}
```

## Error Codes

| HTTP | Description | Action |
|---|---|---|
| 200 | Success | Process normally |
| 202 | Accepted - Library not finalized | Wait and retry |
| 301 | Moved - Library redirected | Use `redirectUrl` |
| 400 | Bad Request | Check parameters |
| 401 | Unauthorized | Check API key |
| 403 | Forbidden | Check permissions/plan |
| 404 | Not Found | Verify library ID |
| 409 | Conflict | Library already exists |
| 422 | Unprocessable | Library too large |
| 429 | Rate limit | Retry after `Retry-After` |
| 500 | Internal error | Retry with backoff |
| 503 | Service unavailable | Retry later |
| 504 | Gateway timeout | Retry later |

## Rate Limits

- Without API key: Low limits
- With API key: Higher limits based on plan
- View usage at https://context7.com/dashboard

## Versioning

Pin to specific versions using `/` or `@` syntax:

```bash
# Slash syntax
curl "https://context7.com/api/v2/context?libraryId=/vercel/next.js/v15.1.8&query=app%20router" \
  -H "Authorization: Bearer $CONTEXT7_API_KEY"

# At syntax
curl "https://context7.com/api/v2/context?libraryId=/vercel/next.js@v15.1.8&query=app%20router" \
  -H "Authorization: Bearer $CONTEXT7_API_KEY"
```

## More Info

- Website: https://context7.com
- Docs: https://context7.com/docs
- Dashboard: https://context7.com/dashboard
- API Guide: https://context7.com/docs/api-guide.md
