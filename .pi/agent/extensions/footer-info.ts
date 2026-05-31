/**
 * Custom Footer Extension — compact footer with jj/git branch,
 * cost + context %, and compact model info.
 *
 * Format: ~/dotfiles on nvim-0.12          $0.835 for 110K on deepseek-v4-pro[1m] • high
 */

import { execSync } from "node:child_process";
import { relative, resolve, sep, isAbsolute } from "node:path";
import type { AssistantMessage, ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

// ── fixed-width formatters (keep footer pixels stable) ──────────────

/** Always 2 digits, capped at 99: 4 -> 04, 47 -> 47, 150 -> 99. */
function formatTps(tps: number): string {
	const clamped = Math.min(99, Math.max(0, Math.round(tps)));
	return `${clamped.toString().padStart(2, "0")}t/s`;
}

/** Dollars only, no cents: 2.011 -> $2, 0.835 -> $1. */
function formatCostDollars(cost: number): string {
	return `$${Math.round(cost)}`;
}

/** Always 3 digits + k, capped at 999k: 96000 -> 096k, 110000 -> 110k, 1500000 -> 999k. */
function formatContextK(tokens: number): string {
	const k = Math.min(999, Math.max(0, Math.round(tokens / 1000)));
	return `${k.toString().padStart(3, "0")}k`;
}

// ── helpers ─────────────────────────────────────────────────────────────

function formatCwd(cwd: string, home: string): string {
	const rcwd = resolve(cwd);
	const rhome = resolve(home);
	const rel = relative(rhome, rcwd);
	const inside =
		rel === "" ||
		(rel !== ".." && !rel.startsWith(`..${sep}`) && !isAbsolute(rel));
	return inside ? (rel === "" ? "~" : `~${sep}${rel}`) : cwd;
}

function getBranch(): string {
	// Try jj first (mirrors p10k prompt_my_vcs logic)
	try {
		const jjRoot = execSync("jj root 2>/dev/null", {
			shell: true,
			timeout: 2000,
			stdio: ["ignore", "pipe", "pipe"],
		})
			.toString()
			.trim();
		if (jjRoot && jjRoot !== process.env.HOME) {
			// Check bookmarks on current change
			let branch = execSync(
				"jj log -r @ --no-graph -T 'bookmarks.map(|b| b.name()).join(\", \")' 2>/dev/null",
				{ shell: true, timeout: 2000, stdio: ["ignore", "pipe", "pipe"] },
			)
				.toString()
				.trim();
			// No bookmark on @ — check parent
			if (!branch) {
				branch = execSync(
					"jj log -r @- --no-graph -T 'bookmarks.map(|b| b.name()).join(\", \")' 2>/dev/null",
					{ shell: true, timeout: 2000, stdio: ["ignore", "pipe", "pipe"] },
				)
					.toString()
					.trim();
			}
			if (branch) return `on ${branch}`;
			return ""; // jj repo but no bookmarks — don't fall back to git
		}
	} catch {
		// jj not available
	}

	// Fall back to git
	try {
		const gitRoot = execSync("git rev-parse --show-toplevel 2>/dev/null", {
			shell: true,
			timeout: 2000,
			stdio: ["ignore", "pipe", "pipe"],
		})
			.toString()
			.trim();
		if (!gitRoot || gitRoot === process.env.HOME) return "";
		const branch = execSync("git symbolic-ref --short HEAD 2>/dev/null", {
			shell: true,
			timeout: 2000,
			stdio: ["ignore", "pipe", "pipe"],
		})
			.toString()
			.trim();
		return branch ? `on ${branch}` : "";
	} catch {
		return "";
	}
}

// ── extension ───────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
	let modelId = "";
	let contextWindow = 0;
	let hasReasoning = true; // model supports deepseek thinking
	let thinkingLevel = "high"; // matches defaultThinkingLevel in settings

	// ── per-turn speed tracking ──────────────────────────────────────────
	// Captured from the assistant stream events. Each turn is a self-contained
	// HTTP stream: `start` → deltas → `done`. Tool execution happens *between*
	// turns (after `done`, before the next `start`), so it never enters the
	// denominator — throughput is pure generation speed.
	let turnStartTs: number | null = null;
	let lastTps: number | null = null; // tokens/sec from last clean turn
	let renderRequester: { requestRender: () => void } | null = null;

	// Track model changes
	pi.on("model_select", (_event) => {
		const m = _event.model as any;
		modelId = m.id || "";
		contextWindow = m.contextWindow || 0;
		hasReasoning = !!m.reasoning || !!m.compat?.thinkingFormat;
	});

	// Track thinking level changes
	pi.on("thinking_level_select", (_event) => {
		thinkingLevel = _event.level;
	});

	// Mark the start of an assistant turn. pi emits the stream's `start`
	// event as `message_start` (not `message_update`), so we capture it here.
	// `done`/`error` go straight to `message_end` — never via `message_update`.
	pi.on("message_start", (event) => {
		if (event.message.role !== "assistant") return;
		turnStartTs = Date.now();
	});

	// Finalize the turn: compute throughput, keep as "last" measurement
	pi.on("message_end", (event) => {
		if (event.message.role !== "assistant") return;
		const m = event.message as AssistantMessage;

		// Skip failed/aborted turns — keep the previous good measurement
		if (m.stopReason === "error" || m.stopReason === "aborted") {
			turnStartTs = null;
			return;
		}
		if (turnStartTs === null) return;

		const doneTs = Date.now();
		const durMs = doneTs - turnStartTs;
		const output = m.usage.output;

		// Throughput: output tokens / generation duration. Includes thinking +
		// tool-call argument tokens — all genuine streamed model output.
		// Require a minimum duration to skip the degenerate fallback path where
		// `message_start` fires late (empty stream, no partials) — otherwise we'd
		// divide by ~0 and show a wildly inflated t/s.
		if (output > 0 && durMs >= 50) {
			lastTps = output / (durMs / 1000);
		}

		turnStartTs = null;
		renderRequester?.requestRender();
	});

	pi.on("session_start", (_event, ctx) => {
		// Snapshot model info at session start (it may not be ready earlier)
		if (ctx.model) {
			const m = ctx.model as any;
			modelId = m.id || "";
			contextWindow = m.contextWindow || 0;
			hasReasoning = !!m.reasoning || !!m.compat?.thinkingFormat;
		}
		thinkingLevel = pi.getThinkingLevel();

		ctx.ui.setFooter((tui, theme, _footerData) => {
			renderRequester = tui;
			return {
				invalidate() {},
				render(width: number): string[] {
					// —— cumulative cost (cheap to compute) ——
					let totalCost = 0;
					for (const entry of ctx.sessionManager.getBranch()) {
						if (
							entry.type === "message" &&
							entry.message.role === "assistant"
						) {
							totalCost += (entry.message as AssistantMessage).usage.cost.total;
						}
					}

					// —— context usage ——
					const cu = ctx.getContextUsage();
					const cw = cu?.contextWindow ?? contextWindow;
					const tokens = cu?.tokens ?? null;
					const tokensStr = tokens !== null ? formatContextK(tokens) : "???k";

					// —— left side ——
					const home = process.env.HOME || "";
					const branch = getBranch();
					const left = branch
						? `${formatCwd(ctx.cwd, home)} ${branch}`
						: formatCwd(ctx.cwd, home);

					// —— right block: $cost for tokens on model[cw] • thinking ——
					const costStr = formatCostDollars(totalCost);
					const cwLabel =
						cw >= 1_000_000
							? `[${(cw / 1_000_000).toFixed(0)}m]`
							: cw >= 1_000
								? `[${Math.round(cw / 1_000)}k]`
								: `[${cw}]`;
					const tl = hasReasoning ? thinkingLevel : "off";
					const tpsStr = lastTps !== null ? formatTps(lastTps) : "--t/s";
					const right =
						`${costStr} for ${tokensStr} on ${modelId || "no-model"}${cwLabel} • ${tpsStr} • ${tl}`;

					// —— layout: left ... right ——
					const leftDim = theme.fg("dim", left);
					const rightDim = theme.fg("dim", right);

					const leftW = visibleWidth(leftDim);
					const rightW = visibleWidth(rightDim);

					if (leftW + rightW <= width) {
						const pad = " ".repeat(width - leftW - rightW);
						return [truncateToWidth(leftDim + pad + rightDim, width)];
					}

					// Right doesn't fit — drop it, show just left
					if (leftW <= width) {
						return [truncateToWidth(leftDim, width)];
					}

					// Left doesn't fit either — truncate it
					return [truncateToWidth(leftDim, width)];
				},
			};
		});
	});
}
