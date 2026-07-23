/**
 * Claude Code compatibility shims.
 *
 * 1. sandbox-context: ports the ~/.claude/hooks/sandbox-context.sh SessionStart
 *    hook. When NBOX=1 (running inside nanobox/bwrap sandbox), append the
 *    sandbox-constraint text to the system prompt so the model respects the
 *    read-only mounts, masked .env files, SSH-agent-only credentials, etc.
 *    Silent (no-op) when NBOX is unset, matching the original hook.
 *
 * 2. /context: displays Pi's current system prompt and loaded resources
 *    without leaving the TUI.
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";
import type { Component, TUI } from "@earendil-works/pi-tui";
import { matchesKey, wrapTextWithAnsi } from "@earendil-works/pi-tui";

const SANDBOX_SCRIPT = join(homedir(), ".claude", "hooks", "sandbox-context.sh");
const CONTEXT_VISIBLE_LINES = 24;

function serialize(value: unknown): string {
	const seen = new WeakSet<object>();

	return (
		JSON.stringify(
			value,
			(_key, item: unknown) => {
				if (typeof item === "bigint") return item.toString();
				if (typeof item !== "object" || item === null) return item;
				if (seen.has(item)) return "[Circular]";
				seen.add(item);
				return item;
			},
			2,
		) ?? "undefined"
	);
}

function section(title: string, content: string): string {
	return [`========== ${title} ==========`, content || "(empty)"].join("\n");
}

class ContextViewer implements Component {
	private offset = 0;
	private lines: string[] = [];

	constructor(
		private readonly tui: TUI,
		private readonly theme: Theme,
		private readonly report: string,
		private readonly close: () => void,
	) {}

	handleInput(data: string): void {
		if (
			matchesKey(data, "escape") ||
			matchesKey(data, "ctrl+c") ||
			data === "q"
		) {
			this.close();
			return;
		}

		const maxOffset = Math.max(
			0,
			this.lines.length - CONTEXT_VISIBLE_LINES,
		);
		if (matchesKey(data, "up")) this.offset--;
		if (matchesKey(data, "down")) this.offset++;
		if (matchesKey(data, "pageUp")) this.offset -= CONTEXT_VISIBLE_LINES;
		if (matchesKey(data, "pageDown")) this.offset += CONTEXT_VISIBLE_LINES;
		if (matchesKey(data, "home")) this.offset = 0;
		if (matchesKey(data, "end")) this.offset = maxOffset;

		this.offset = Math.max(0, Math.min(maxOffset, this.offset));
		this.tui.requestRender();
	}

	render(width: number): string[] {
		this.lines = this.getLines(width);
		const maxOffset = Math.max(
			0,
			this.lines.length - CONTEXT_VISIBLE_LINES,
		);
		this.offset = Math.min(this.offset, maxOffset);
		const visible = this.lines.slice(
			this.offset,
			this.offset + CONTEXT_VISIBLE_LINES,
		);

		return [
			this.theme.fg("accent", this.theme.bold("Pi context inspector")),
			...visible,
			this.theme.fg(
				"dim",
				`${this.offset + 1}-${Math.min(this.offset + CONTEXT_VISIBLE_LINES, this.lines.length)} of ${this.lines.length} | ↑↓/PgUp/PgDn scroll | Home/End | q/Esc close`,
			),
		];
	}

	invalidate(): void {}

	private getLines(width: number): string[] {
		const contentWidth = Math.max(20, width);
		return this.report.split("\n").flatMap((line) => {
			if (!line) return [""];
			return wrapTextWithAnsi(line, contentWidth);
		});
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("before_agent_start", async (event) => {
		if (process.env.NBOX !== "1") return;

		// Reuse the original script's output verbatim — single source of truth.
		let sandboxText: string;
		try {
			// Execute the original hook script and capture its stdout.
			const { execSync } = await import("node:child_process");
			sandboxText = execSync(`bash "${SANDBOX_SCRIPT}"`, {
				encoding: "utf-8",
				timeout: 2000,
				stdio: ["ignore", "pipe", "ignore"],
			});
		} catch {
			// Script missing or failed — fall back to no injection.
			return;
		}

		if (!sandboxText.trim()) return;

		return {
			systemPrompt: event.systemPrompt + "\n\n" + sandboxText.trim(),
		};
	});

	pi.registerCommand("context", {
		description: "Inspect Pi's current prompt and loaded resources",
		handler: async (_args, ctx) => {
			if (ctx.mode !== "tui") {
				ctx.ui.notify("/context requires interactive mode", "error");
				return;
			}

			const systemPrompt = ctx.getSystemPrompt();
			const options = ctx.getSystemPromptOptions();
			const displayOptions = {
				...options,
				contextFiles: options.contextFiles?.map((file) => file.path),
				skills: options.skills?.map((skill) => skill.description),
			};
			const report = [
				section("current Pi system prompt", systemPrompt),
				section(
					"system prompt inputs and loaded resources",
					serialize(displayOptions),
				),
			].join("\n\n");

			await ctx.ui.custom<void>((tui, theme, _keybindings, done) => {
				return new ContextViewer(tui, theme, report, () => done());
			});
		},
	});
}
