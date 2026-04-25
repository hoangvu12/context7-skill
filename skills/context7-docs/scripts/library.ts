#!/usr/bin/env bun
import { handleRequestFailure, preflight, requestJson } from "./preflight";

type LibraryResult = {
  id?: string;
  libraryId?: string;
  title?: string;
  description?: string;
  versions?: string[];
};

function usage(): void {
  console.log('Usage: bun scripts/library.ts "<library-name>"');
}

const args = Bun.argv.slice(2);

if (args.includes("-h") || args.includes("--help")) {
  usage();
  process.exit(0);
}

if (args.length !== 1) {
  if (args.length > 1) {
    console.error(`Unexpected argument: ${args[1]}`);
  }
  usage();
  process.exit(1);
}

if (!preflight()) {
  process.exit(2);
}

const query = args[0];
const url = new URL("https://context7.com/api/v2/libs/search");
url.searchParams.set("libraryName", query);
url.searchParams.set("query", query);

const { status, data } = await requestJson(url.toString(), process.env.CONTEXT7_API_KEY || "");

if (status !== 200) {
  handleRequestFailure(status, data);
}

const results = Array.isArray((data as { results?: unknown }).results)
  ? ((data as { results: LibraryResult[] }).results)
  : [];

if (results.length === 0) {
  console.log("No libraries found.");
  process.exit(0);
}

console.log(`Found ${results.length} library(ies):`);
console.log();

for (const lib of results) {
  const libId = lib.id || lib.libraryId || "unknown";
  const name = lib.title || libId;

  console.log(`ID:   ${libId}`);
  console.log(`Name: ${name}`);

  if (Array.isArray(lib.versions) && lib.versions.length > 0) {
    console.log(`Versions: ${lib.versions.slice(0, 5).join(", ")}`);
  }

  if (lib.description) {
    console.log(`Desc: ${lib.description.slice(0, 200)}`);
  }

  console.log();
}
