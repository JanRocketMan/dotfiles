---
name: pdb-copilot
description: Co-debug a Python process through the PDB tool exposed by `tau --debug`. Use when the user asks to inspect, navigate, or control a shared PDB session.
---

# PDB copilot

Use the `pdb` tool to share control of the stock PDB session in the other tmux pane

## Safety rules

- Confirm the debugger state with `status` before the first command
- Read the relevant source before you move execution or add a breakpoint
- Send one PDB command per tool call
- Prefer `tbreak` over `break` when the stop is needed only once
- Do not use `jump`, assignment, function calls with side effects, or state mutation unless the user requests it
- Do not use `continue`, `next`, `step`, `return`, or `until` until you can explain the expected next stop
- Do not quit, exit, restart, or enter a nested debugger or interactive shell
- Use `interrupt` only when the program is running and the user wants it paused
- Treat expressions evaluated by `p` and `pp` as code execution inside the debuggee sandbox
- Leave the debugger paused when the task is complete
- Tell the user which pane and source location you reached, what you learned, and that control is returned

## Typical workflow

1. Call `status` and identify the current file, line, and stack frame
2. Read the source around the current location and the requested destination
3. Use `where`, `up`, `down`, `list`, `longlist`, `p`, or `pp` to inspect state
4. Set a temporary breakpoint with `tbreak path/to/file.py:LINE` when the destination is known
5. Use `continue` with a timeout that fits the expected work
6. If the timeout expires, use `status` instead of sending another command
7. Inspect the destination and stop issuing commands
8. Return control explicitly

For conditional navigation, prefer a conditional temporary breakpoint:

```text
tbreak path/to/file.py:123, condition
```

Use PDB's exact syntax from the running Python version. If syntax is uncertain, use `help COMMAND` in PDB before changing execution
