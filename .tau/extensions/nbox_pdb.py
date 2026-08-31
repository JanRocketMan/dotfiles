"""Expose an explicitly enabled nanobox PDB bridge as a Tau tool."""

import asyncio
import json
import os
from collections.abc import Mapping
from pathlib import Path

from tau_agent.messages import TextContent
from tau_agent.tools import (
    AgentTool,
    AgentToolResult,
    ToolCancellationToken,
    ToolUpdateCallback,
)
from tau_agent.types import JSONValue
from tau_coding.extensions import ExtensionAPI

PROTOCOL_VERSION = 1
MAX_RESPONSE_BYTES = 128 * 1024
MAX_TIMEOUT_SECONDS = 300.0


def _render_call(arguments: Mapping[str, JSONValue]) -> str:
    action = arguments.get("action", "status")
    if action == "command":
        return f"▸ pdb · {arguments.get('command', '')}"
    return f"▸ pdb · {action}"


def _timeout(arguments: Mapping[str, JSONValue]) -> float:
    raw_timeout = arguments.get("timeout", 30.0)
    if isinstance(raw_timeout, bool) or not isinstance(raw_timeout, (int, float)):
        raise ValueError("timeout must be a number")
    timeout = float(raw_timeout)
    if timeout <= 0 or timeout > MAX_TIMEOUT_SECONDS:
        raise ValueError(f"timeout must be greater than 0 and at most {MAX_TIMEOUT_SECONDS:g}")
    return timeout


async def _request(
    socket_path: Path,
    payload: dict[str, JSONValue],
    timeout: float,
) -> dict[str, JSONValue]:
    try:
        reader, writer = await asyncio.wait_for(
            asyncio.open_unix_connection(str(socket_path), limit=MAX_RESPONSE_BYTES),
            timeout=5.0,
        )
    except (OSError, TimeoutError) as exc:
        raise RuntimeError(f"cannot connect to the nanobox PDB bridge: {exc}") from exc

    try:
        encoded = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        writer.write(encoded + b"\n")
        await writer.drain()
        raw_response = await asyncio.wait_for(reader.readline(), timeout=timeout + 5.0)
        if not raw_response.endswith(b"\n"):
            raise RuntimeError("nanobox PDB bridge closed without a complete response")
        if len(raw_response) > MAX_RESPONSE_BYTES:
            raise RuntimeError("nanobox PDB bridge response is too large")
    except (OSError, TimeoutError) as exc:
        raise RuntimeError(f"nanobox PDB bridge request failed: {exc}") from exc
    finally:
        writer.close()
        await writer.wait_closed()

    try:
        response = json.loads(raw_response)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"nanobox PDB bridge returned invalid JSON: {exc}") from exc
    if not isinstance(response, dict):
        raise RuntimeError("nanobox PDB bridge returned a non-object response")
    if response.get("ok") is not True:
        raise RuntimeError(str(response.get("error", "nanobox PDB bridge request failed")))
    return response


async def _run_pdb(
    tool_call_id: str,
    arguments: Mapping[str, JSONValue],
    signal: ToolCancellationToken | None = None,
    on_update: ToolUpdateCallback | None = None,
) -> AgentToolResult:
    del tool_call_id, on_update
    if signal is not None and signal.is_cancelled():
        raise RuntimeError("PDB request cancelled")

    socket_value = os.environ.get("NBOX_PDB_SOCKET")
    if not socket_value:
        raise RuntimeError("nanobox PDB bridge is not enabled")
    socket_path = Path(socket_value)
    if not socket_path.is_socket():
        raise RuntimeError("nanobox PDB bridge socket is unavailable")

    action = arguments.get("action")
    if action not in {"status", "command", "interrupt"}:
        raise ValueError("action must be status, command, or interrupt")
    timeout = _timeout(arguments)
    payload: dict[str, JSONValue] = {
        "version": PROTOCOL_VERSION,
        "action": action,
        "timeout": timeout,
    }
    if action == "command":
        command = arguments.get("command")
        if not isinstance(command, str) or not command.strip():
            raise ValueError("command is required when action is command")
        payload["command"] = command

    response = await _request(socket_path, payload, timeout)
    output = response.get("output")
    if not isinstance(output, str):
        output = "(no output)"
    if response.get("timed_out") is True:
        output += "\n\n[PDB is still running. Use status to observe it or interrupt to pause it.]"
    return AgentToolResult(content=[TextContent(text=output)], details=response)


def setup(tau: ExtensionAPI) -> None:
    """Register the tool only for an explicit nanobox debug run."""
    socket_value = os.environ.get("NBOX_PDB_SOCKET")
    if os.environ.get("NBOX") != "1" or not socket_value or not Path(socket_value).is_socket():
        return

    tau.register_tool(
        AgentTool(
            name="pdb",
            label="PDB",
            description=(
                "Operate the stock PDB session in the selected tmux pane. Commands are typed "
                "visibly into that pane. The debuggee is a dedicated nanobox pane for this same "
                "project. Use status while it runs and interrupt only when needed."
            ),
            parameters={
                "type": "object",
                "additionalProperties": False,
                "properties": {
                    "action": {
                        "type": "string",
                        "enum": ["status", "command", "interrupt"],
                        "description": "Bridge action to perform.",
                    },
                    "command": {
                        "type": "string",
                        "description": "One PDB command. Required only for the command action.",
                        "maxLength": 4096,
                    },
                    "timeout": {
                        "type": "number",
                        "exclusiveMinimum": 0,
                        "maximum": MAX_TIMEOUT_SECONDS,
                        "description": "Seconds to wait for the next PDB prompt. Default 30.",
                    },
                },
                "required": ["action"],
            },
            execute_fn=_run_pdb,
            prompt_snippet=(
                "Inspect and control the explicitly shared PDB session in another tmux pane."
            ),
            prompt_guidelines=(
                "Use pdb only when the user asks to inspect or move the shared debugging session.",
                "Inspect repository source before setting breakpoints or moving execution.",
                "Prefer temporary breakpoints and avoid changing program state unless requested.",
                "Never quit or restart the shared debugger.",
                "Leave PDB paused and clearly return control to the user when finished.",
            ),
            execution_mode="sequential",
            render_call=_render_call,
        )
    )
