import { accessSync, constants, readdirSync } from "node:fs";
import { join, delimiter } from "node:path";
import { homedir } from "node:os";

const CHROMIUM_NAMES = [
  "chromium",
  "chromium-browser",
];

function isExecutableFile(filePath) {
  try {
    accessSync(filePath, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function findExecutableOnPath(name, env = process.env) {
  if (!name) return null;

  if (name.includes("/")) {
    return isExecutableFile(name) ? name : null;
  }

  const pathEnv = env.PATH || "";
  const dirs = pathEnv.split(delimiter).filter(Boolean);

  for (const dir of dirs) {
    const candidate = join(dir, name);
    if (isExecutableFile(candidate)) return candidate;
  }

  return null;
}

function getPlaywrightChromium() {
  try {
    const baseDir = join(homedir(), ".cache", "ms-playwright");
    const entries = readdirSync(baseDir).filter(e => e.startsWith("chromium-")).sort().reverse();
    for (const entry of entries) {
      const bin = join(baseDir, entry, "chrome-linux", "chrome");
      if (isExecutableFile(bin)) return bin;
    }
  } catch {
    // playwright not installed or binary missing
  }
  return null;
}

/**
 * Resolve a Chromium binary for CDP automation.
 *
 * Checks system PATH first, then falls back to Playwright's bundled Chromium.
 */
export function resolveBrowserBin(preferredBin = null, env = process.env) {
  if (preferredBin) {
    const resolved = findExecutableOnPath(preferredBin, env);
    if (resolved) return resolved;
  }

  for (const name of CHROMIUM_NAMES) {
    const resolved = findExecutableOnPath(name, env);
    if (resolved) return resolved;
  }

  const pw = getPlaywrightChromium();
  if (pw) return pw;

  throw new Error(
    `No Chromium binary found. Tried: ${CHROMIUM_NAMES.join(", ")}, playwright bundled chromium`,
  );
}
