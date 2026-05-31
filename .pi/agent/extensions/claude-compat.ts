/**
 * Claude Code compatibility shims.
 *
 * 1. sandbox-context: ports the ~/.claude/hooks/sandbox-context.sh SessionStart
 *    hook. When NBOX=1 (running inside nanobox/bwrap sandbox), append the
 *    sandbox-constraint text to the system prompt so the model respects the
 *    read-only mounts, masked .env files, SSH-agent-only credentials, etc.
 *    Silent (no-op) when NBOX is unset, matching the original hook.
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SANDBOX_SCRIPT = join(homedir(), ".claude", "hooks", "sandbox-context.sh");

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
}
