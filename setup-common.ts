#!/usr/bin/env bun
/**
 * Workshop Setup — Common (tool verification)
 * Run AFTER the OS-specific setup script.
 * Usage: bun setup-common.ts [--json]
 */

import { $ } from "bun";

const JSON_OUTPUT = process.argv.includes("--json");

// Minimum required version per tool (semver-ish "major.minor" comparison).
// Leave a tool out of this map to skip the minimum-version check.
const MIN_VERSIONS: Record<string, string> = {
  bun: "1.1.0",
  uv: "0.4.0",
};

function parseVersion(raw: string): number[] {
  const match = raw.match(/(\d+)\.(\d+)(?:\.(\d+))?/);
  if (!match) return [];
  return [Number(match[1]), Number(match[2]), Number(match[3] ?? 0)];
}

function isVersionAtLeast(raw: string, min: string): boolean {
  const a = parseVersion(raw);
  const b = parseVersion(min);
  if (a.length === 0) return true; // couldn't parse — don't block on it
  for (let i = 0; i < 3; i++) {
    if ((a[i] ?? 0) > (b[i] ?? 0)) return true;
    if ((a[i] ?? 0) < (b[i] ?? 0)) return false;
  }
  return true;
}

// ── Colors ────────────────────────────────────────────────────────────────────
const G  = "\x1b[32m"; const Y = "\x1b[33m"; const R = "\x1b[31m";
const C  = "\x1b[36m"; const D = "\x1b[2m";  const B = "\x1b[1m"; const N = "\x1b[0m";

// ── Animation ─────────────────────────────────────────────────────────────────
const SPIN = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"];

function section(num: number, total: number, label: string) {
  const pct    = Math.round(num * 100 / total);
  const width  = 22;
  const filled = Math.round(width * pct / 100);
  const bar    = "█".repeat(filled) + "░".repeat(width - filled);
  process.stdout.write(`\n${B}${C}[${num}/${total}]${N} ${label.padEnd(32)} ${Y}[${bar}] ${String(pct).padStart(3)}%${N}\n`);
}

async function ver(cmd: string, vArgs = ["--version"]): Promise<string | null> {
  try {
    const r = await $`${cmd} ${vArgs}`.quiet();
    return r.stdout.toString().trim().split("\n")[0];
  } catch { return null; }
}

// ── Header ────────────────────────────────────────────────────────────────────
if (!JSON_OUTPUT) {
  console.clear();
  process.stdout.write(`${B}${C}`);
  console.log("  ╔══════════════════════════════════════════╗");
  console.log("  ║     Workshop Setup — Verification        ║");
  console.log("  ╚══════════════════════════════════════════╝");
  process.stdout.write(`${N}\n`);
}

const TOTAL = 1;
const errors: string[] = [];

// ── Verification ────────────────────────────────────────────────────────────
if (!JSON_OUTPUT) section(TOTAL, TOTAL, "Verification");

type Tool = { cmd: string; vArgs?: string[]; label: string; required: boolean };
const tools: Tool[] = [
  { cmd: "bun",    label: "bun",              required: true  },
  { cmd: "python3",label: "python3",          required: false },
  { cmd: "uv",     label: "uv",               required: true  },
  { cmd: "git",    label: "git",              required: true  },
  { cmd: "gh",     label: "gh (GitHub CLI)",   required: true  },
  { cmd: "claude", label: "claude",           required: true  },
  { cmd: "agy",    label: "agy (Antigravity)",required: true },
];

type Result = { tool: string; label: string; status: "ok" | "outdated" | "missing" | "optional"; version: string | null };
const results: Result[] = [];
const rows: [string, string, string][] = [];

for (const t of tools) {
  const v = await ver(t.cmd, t.vArgs);
  const min = MIN_VERSIONS[t.cmd];
  if (v && min && !isVersionAtLeast(v, min)) {
    rows.push([`${Y}⚠️ ${N}`, t.label, `${Y}${v} (minimum ${min} required)${N}`]);
    results.push({ tool: t.cmd, label: t.label, status: "outdated", version: v });
    if (t.required) errors.push(`${t.cmd} (outdated: ${v} < ${min})`);
  } else if (v) {
    rows.push([`${G}✅${N}`, t.label, v]);
    results.push({ tool: t.cmd, label: t.label, status: "ok", version: v });
  } else if (t.required) {
    rows.push([`${R}❌${N}`, t.label, "NOT FOUND"]);
    results.push({ tool: t.cmd, label: t.label, status: "missing", version: null });
    errors.push(t.cmd);
  } else {
    rows.push([`${Y}⚠️ ${N}`, t.label, `${D}not found (optional)${N}`]);
    results.push({ tool: t.cmd, label: t.label, status: "optional", version: null });
  }
}

// gh auth
try {
  await $`gh auth status`.quiet();
  rows.push([`${G}✅${N}`, "gh auth", "logged in"]);
  results.push({ tool: "gh-auth", label: "gh auth", status: "ok", version: null });
} catch {
  rows.push([`${Y}⚠️ ${N}`, "gh auth", `${Y}not logged in — run: gh auth login${N}`]);
  results.push({ tool: "gh-auth", label: "gh auth", status: "optional", version: null });
}

// claude auth
try {
  const r = await $`claude auth status`.quiet();
  const out = r.stdout.toString().trim();
  rows.push([`${G}✅${N}`, "claude auth", out.split("\n")[0] || "logged in"]);
  results.push({ tool: "claude-auth", label: "claude auth", status: "ok", version: null });
} catch {
  rows.push([`${Y}⚠️ ${N}`, "claude auth", `${Y}not logged in — run: claude login${N}`]);
  results.push({ tool: "claude-auth", label: "claude auth", status: "optional", version: null });
}

if (JSON_OUTPUT) {
  console.log(JSON.stringify({ ok: errors.length === 0, errors, results }, null, 2));
  process.exit(errors.length === 0 ? 0 : 1);
}

// Print table
const maxLen = Math.max(...rows.map(r => r[1].length));
const sep    = "─".repeat(maxLen + 34);
console.log(`\n ${sep}`);
for (const [icon, label, value] of rows)
  console.log(` ${icon}  ${label.padEnd(maxLen + 2)} ${value}`);
console.log(` ${sep}`);

// ── Summary ───────────────────────────────────────────────────────────────────
console.log("");
console.log(`${B}${C}  ══════════════════════════════════════════${N}`);
if (errors.length === 0) {
  console.log(`${G}  ✅  All checks passed — ready for the workshop!${N}`);
} else {
  console.log(`${R}  ❌  Issues: ${errors.join(", ")}${N}`);
  console.log(`${D}  Resolve the above and re-run this script.${N}`);
  process.exit(1);
}
console.log(`${B}${C}  ══════════════════════════════════════════${N}\n`);
