#!/usr/bin/env bun
import { context7ConfigFile, errorMessage, requestJson, saveConfig, validateKeyFormat } from "./preflight";

function usage(): void {
  console.log("Usage: bun scripts/save-key.ts <c7-key>");
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

const apiKey = args[0];

if (!validateKeyFormat(apiKey)) {
  console.error("Invalid key format. Expected a value starting with ctx7sk-.");
  process.exit(1);
}

const url = new URL("https://context7.com/api/v2/libs/search");
url.searchParams.set("libraryName", "react");
url.searchParams.set("query", "hooks");

const { status, data } = await requestJson(url.toString(), apiKey);

if (status === 401) {
  console.error("Context7 rejected the key with 401 Unauthorized.");
  process.exit(1);
}

if (status !== 200) {
  const message = errorMessage(data);

  if (message) {
    console.error(`Context7 probe failed (${status}): ${message}`);
  } else {
    console.error(`Context7 probe failed with HTTP ${status}.`);
  }

  process.exit(1);
}

saveConfig(apiKey);
console.log(`Saved Context7 config to ${context7ConfigFile}`);
