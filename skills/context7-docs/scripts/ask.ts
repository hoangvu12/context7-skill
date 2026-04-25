#!/usr/bin/env bun
import { handleRequestFailure, preflight, requestJson } from "./preflight";

type CodeExample = {
  language?: string;
  code?: string;
};

type CodeSnippet = {
  codeTitle?: string;
  codeDescription?: string;
  codeLanguage?: string;
  codeList?: CodeExample[];
};

type InfoSnippet = {
  breadcrumb?: string;
  content?: string;
};

function usage(): void {
  console.log('Usage: bun scripts/ask.ts "<library-id>" "<question>"');
  console.log('Example: bun scripts/ask.ts "/vercel/next.js" "How do middleware work?"');
}

const args = Bun.argv.slice(2);

if (args.includes("-h") || args.includes("--help")) {
  usage();
  process.exit(0);
}

if (args.length !== 2) {
  if (args.length > 2) {
    console.error(`Unexpected argument: ${args[2]}`);
  }
  usage();
  process.exit(1);
}

if (!preflight()) {
  process.exit(2);
}

const [libraryId, query] = args;
const url = new URL("https://context7.com/api/v2/context");
url.searchParams.set("libraryId", libraryId);
url.searchParams.set("query", query);
url.searchParams.set("type", "json");

const { status, data } = await requestJson(url.toString(), process.env.CONTEXT7_API_KEY || "");

if (status !== 200) {
  handleRequestFailure(status, data);
}

const payload = data as { codeSnippets?: CodeSnippet[]; infoSnippets?: InfoSnippet[] };
const codeSnippets = Array.isArray(payload.codeSnippets) ? payload.codeSnippets : [];
const infoSnippets = Array.isArray(payload.infoSnippets) ? payload.infoSnippets : [];

for (const snippet of codeSnippets) {
  if (snippet.codeTitle) {
    console.log(`## ${snippet.codeTitle}`);
  }

  if (snippet.codeDescription) {
    console.log(snippet.codeDescription);
  }

  const codeList = Array.isArray(snippet.codeList) ? snippet.codeList : [];
  for (const codeExample of codeList) {
    const language = codeExample.language || snippet.codeLanguage || "";

    if (codeExample.code) {
      console.log(```${language}`);
      console.log(codeExample.code);
      console.log("```");
    }
  }

  console.log();
}

for (const info of infoSnippets) {
  if (info.breadcrumb) {
    console.log(`## ${info.breadcrumb}`);
  }

  if (info.content) {
    console.log(info.content);
  }

  console.log();
}

if (codeSnippets.length === 0 && infoSnippets.length === 0) {
  console.log("No documentation content returned.");
  console.log();
  console.log("Raw response:");
  console.log(JSON.stringify(data, null, 2));
}
