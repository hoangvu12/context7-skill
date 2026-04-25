#!/usr/bin/env bun
import { existsSync, mkdirSync, readFileSync, writeFileSync, chmodSync } from "node:fs";
import { dirname, join } from "node:path";

const home = process.env.HOME || process.env.USERPROFILE || "";

export const context7SkillDir = join(import.meta.dir, "..");
export const context7ConfigDir = join(home, ".config", "context7");
export const context7ConfigFile = join(context7ConfigDir, "config.json");
export const context7LegacyKeyFile = join(home, ".context7");

export function emitAuthRequired(): void {
  console.log("CONTEXT7_AUTH_REQUIRED");
  console.log("Get a free API key at https://context7.com/dashboard");
  console.log(`Then run: bun ${join(context7SkillDir, "scripts", "save-key.ts")} <your-key>`);
}

export function validateKeyFormat(apiKey = process.env.CONTEXT7_API_KEY || ""): boolean {
  return /^ctx7sk-[a-f0-9-]+$/.test(apiKey);
}

function stripWrappingQuotes(value: string): string {
  return value.replace(/^['\"]|['\"]$/g, "");
}

function loadDotenv(dotenvPath: string): void {
  if (!existsSync(dotenvPath)) {
    return;
  }

  for (const rawLine of readFileSync(dotenvPath, "utf8").split(/\r?\n/)) {
    const line = rawLine.replace(/^export\s+/, "").trim();

    if (!line || line.startsWith("#")) {
      continue;
    }

    const equalsIndex = line.indexOf("=");
    if (equalsIndex === -1) {
      continue;
    }

    const key = line.slice(0, equalsIndex).trim();
    const value = stripWrappingQuotes(line.slice(equalsIndex + 1).trim());

    if (key === "CONTEXT7_API_KEY" && !process.env.CONTEXT7_API_KEY) {
      process.env.CONTEXT7_API_KEY = value;
    }
  }
}

function loadJsonConfig(): void {
  if (!existsSync(context7ConfigFile) || process.env.CONTEXT7_API_KEY) {
    return;
  }

  try {
    const data = JSON.parse(readFileSync(context7ConfigFile, "utf8"));
    if (typeof data.api_key === "string") {
      process.env.CONTEXT7_API_KEY = data.api_key;
    }
  } catch {
    // Ignore malformed config and continue through the credential chain.
  }
}

function loadLegacyKey(): void {
  if (!existsSync(context7LegacyKeyFile) || process.env.CONTEXT7_API_KEY) {
    return;
  }

  process.env.CONTEXT7_API_KEY = readFileSync(context7LegacyKeyFile, "utf8").replace(/[\r\n]/g, "");
}

export function preflight(): boolean {
  if (validateKeyFormat()) {
    return true;
  }

  loadDotenv(join(process.cwd(), ".env"));
  if (validateKeyFormat()) {
    return true;
  }

  loadJsonConfig();
  if (validateKeyFormat()) {
    return true;
  }

  loadLegacyKey();
  if (validateKeyFormat()) {
    return true;
  }

  emitAuthRequired();
  return false;
}

export async function requestJson(url: string, apiKey: string): Promise<{ status: number; data: unknown }> {
  let response: Response;

  try {
    response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${apiKey}`,
      },
    });
  } catch {
    console.error("Context7 request failed due to a network error.");
    process.exit(1);
  }

  let data: unknown = {};
  try {
    data = await response.json();
  } catch {
    data = {};
  }

  return { status: response.status, data };
}

export function errorMessage(data: unknown): string {
  if (!data || typeof data !== "object") {
    return "";
  }

  const record = data as Record<string, unknown>;
  const error = record.error;

  if (error && typeof error === "object") {
    const message = (error as Record<string, unknown>).message;
    if (typeof message === "string") {
      return message;
    }
  }

  return typeof record.message === "string" ? record.message : "";
}

export function handleRequestFailure(status: number, data: unknown, retryKeyCommand = "bun scripts/save-key.ts <key>"): never {
  const message = errorMessage(data);

  if (status === 401) {
    console.error(`Context7 authentication failed. Re-save the key with ${retryKeyCommand}.`);
  } else if (status === 429) {
    console.error("Context7 rate limit reached. Retry with backoff.");
  } else if (message) {
    console.error(`Context7 request failed (${status}): ${message}`);
  } else {
    console.error(`Context7 request failed with HTTP ${status}.`);
  }

  process.exit(1);
}

export function saveConfig(apiKey: string): void {
  mkdirSync(dirname(context7ConfigFile), { recursive: true });
  writeFileSync(context7ConfigFile, `${JSON.stringify({ api_key: apiKey }, null, 2)}\n`, "utf8");

  try {
    chmodSync(context7ConfigFile, 0o600);
  } catch {
    // chmod is best-effort for Windows and restricted filesystems.
  }
}

if (import.meta.main && !preflight()) {
  process.exit(2);
}
