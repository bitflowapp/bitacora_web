import path from "node:path";
import { fileURLToPath } from "node:url";

function parsePositiveInt(rawValue, fallbackValue) {
  const parsed = Number.parseInt(String(rawValue ?? "").trim(), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallbackValue;
}

const moduleDir = path.dirname(fileURLToPath(import.meta.url));
const repoPath = path.resolve(moduleDir, "..", "..");
const defaultCodexHome = path.join(repoPath, ".codex_home", ".codex_plus_jariel");

export function getBridgeConfig() {
  return Object.freeze({
    bridgeName: "wp-codex-bridge",
    repoPath,
    codexHome: (process.env.WP_CODEX_BRIDGE_CODEX_HOME || process.env.CODEX_HOME || defaultCodexHome).trim(),
    codexScriptPath: (process.env.WP_CODEX_BRIDGE_CODEX_SCRIPT || "").trim(),
    allowlist: ["+5492996209136", "+542996209136"],
    prefixes: ["codex:", "bitflow:", "repo:"],
    timeoutMs: parsePositiveInt(process.env.WP_CODEX_BRIDGE_TIMEOUT_MS, 120000),
    maxPromptChars: parsePositiveInt(process.env.WP_CODEX_BRIDGE_MAX_PROMPT_CHARS, 4000),
    maxResponseChars: parsePositiveInt(process.env.WP_CODEX_BRIDGE_MAX_RESPONSE_CHARS, 5500),
    outboundChunkChars: parsePositiveInt(process.env.WP_CODEX_BRIDGE_CHUNK_CHARS, 1700),
    dedupeTtlMs: parsePositiveInt(process.env.WP_CODEX_BRIDGE_DEDUPE_TTL_MS, 10 * 60 * 1000),
    logDir: path.join(repoPath, "logs", "wp_codex_bridge"),
    runDir: path.join(repoPath, "logs", "wp_codex_bridge", "runs"),
  });
}
