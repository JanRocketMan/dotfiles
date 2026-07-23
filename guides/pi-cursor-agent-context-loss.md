# `pi-cursor-agent` drops Pi context files

## Summary

`pi-cursor-agent` 0.4.4 does not recognize the context-file format emitted by
Pi 0.81.1. Global and project `AGENTS.md` or `CLAUDE.md` instructions can
therefore be removed from the system prompt before the request reaches the
Cursor Agent API.

This is not a failure in Pi's context discovery. Pi loads the files correctly.
The loss happens while `pi-cursor-agent` translates Pi's system prompt into
Cursor rules.

Upstream package:
https://github.com/sudosubin/pi-frontier/tree/main/pi-cursor-agent

## Environment

- Pi: 0.81.1
- Provider: `cursor-agent`
- Package: `npm:pi-cursor-agent`
- Latest package version inspected: 0.4.4
- Configuration includes Pi skills, so the system prompt contains an
  `<available_skills>` block.

Example configuration:

```json
{
  "defaultProvider": "cursor-agent",
  "packages": [
    "npm:pi-cursor-agent"
  ],
  "skills": [
    "~/.claude/skills"
  ]
}
```

## Expected behavior

Pi loads context files from locations including:

- `~/.pi/agent/AGENTS.md`
- parent directories of the working directory
- the working directory

The provider should send those instructions to Cursor, either as Cursor rules
or as part of the preserved system prompt.

## Actual behavior

Skills reach the model, but context-file instructions do not. In the observed
session:

- the available Pi skills were present;
- `~/.pi/agent/AGENTS.md` was absent;
- the repository's context-file instructions were absent unless the model
  found and read the file itself;
- the model consequently used bare Git despite a global instruction requiring
  colocated Jujutsu.

## Root cause

Pi 0.81.1 serializes context files using XML-like blocks:

```xml
<project_context>
<project_instructions path="/home/user/.pi/agent/AGENTS.md">
# Personal preferences

...
</project_instructions>
<project_instructions path="/work/repo/AGENTS.md">
# Project instructions

...
</project_instructions>
</project_context>
```

The current parser in
`src/bridge/pi-context/parser.ts` only recognizes an older Markdown format:

```ts
const CONTEXT_HEADING = "# Project Context";
```

Its `extractContextFiles()` implementation looks for that heading and splits
the following content on headings matching `## /...`. It does not recognize
`<project_context>` or `<project_instructions path="...">`.

The loss then occurs through this sequence:

1. `parsePiSystemPrompt()` calls `extractContextFiles()`.
2. The current Pi prompt has no `# Project Context` heading, so the result is
   an empty context-file array.
3. `extractSkills()` successfully recognizes `<available_skills>`.
4. Because at least one skill was extracted, `hasExtracted` becomes `true`.
5. `buildCleanedPrompt()` rebuilds the prompt from a small set of preserved
   patterns instead of returning the original prompt.
6. The unrecognized `<project_context>` block is omitted from that rebuilt
   prompt.
7. `buildCursorRules()` receives no context files, so it cannot create global
   Cursor rules for them.
8. Neither the cleaned system prompt nor the Cursor rules contain the
   `AGENTS.md` content.

Relevant call path:

```text
streamCursorAgent()
  -> preparePiContext(context.systemPrompt)
     -> parsePiSystemPrompt()
        -> extractContextFiles()
        -> extractSkills()
        -> buildCleanedPrompt()
     -> buildCursorRules()
  -> LocalResourceProvider({ cursorRules })
  -> buildRunRequest({ systemPromptOverride: cleanedPrompt })
```

The problem is especially easy to reproduce when skills are enabled. If
nothing is extracted, `buildCleanedPrompt()` falls back to the original system
prompt. Once skills are extracted, the parser treats the translation as
successful and drops any context syntax it did not understand.

## Minimal reproduction

Pass a current-format Pi system prompt containing both project instructions
and skills to `parsePiSystemPrompt()`:

```ts
const prompt = `
<project_context>
<project_instructions path="/home/user/.pi/agent/AGENTS.md">
Always use Jujutsu. Never run bare git commands.
</project_instructions>
</project_context>

<available_skills>
<skill>
<name>example</name>
<description>Example skill</description>
<location>/home/user/.pi/agent/skills/example/SKILL.md</location>
</skill>
</available_skills>

Current date: Thursday, July 23, 2026
Current working directory: /work/repo
`;

const parsed = parsePiSystemPrompt(prompt);
```

Observed result with the 0.4.4 parser:

```ts
parsed.contextFiles.length === 0;
parsed.skills.length === 1;
parsed.cleanedPrompt.includes("Always use Jujutsu") === false;
```

Expected result:

```ts
parsed.contextFiles.length === 1;
parsed.contextFiles[0].path === "/home/user/.pi/agent/AGENTS.md";
parsed.contextFiles[0].content.includes("Always use Jujutsu") === true;
```

## Suggested fix

Support both context formats:

1. Parse current `<project_context>` blocks and each nested
   `<project_instructions path="...">...</project_instructions>` entry.
2. Keep the existing Markdown parser for compatibility with older Pi
   versions.
3. Decode escaped entities in the `path` attribute.
4. Preserve instruction content exactly apart from line-ending normalization
   and surrounding delimiter whitespace.
5. Use a safe fallback when the prompt appears to contain project context but
   no entries can be parsed. Returning the original prompt is safer than
   silently deleting instructions.

The parser should avoid using successful skill extraction as proof that every
other Pi context section was parsed successfully. Context parsing and skill
parsing need independent success checks.

## Suggested tests

Add parser and integration coverage for:

- the current XML-like context format with one global `AGENTS.md`;
- multiple global and project context files;
- the older `# Project Context` format;
- a prompt containing both current context and `<available_skills>`;
- paths containing spaces and escaped XML characters;
- instruction bodies containing Markdown, code fences, and XML-like text;
- malformed or unknown project-context syntax, verifying that the original
  instructions are not discarded;
- no context files and no skills;
- skills without context files;
- context files without skills;
- `buildCursorRules()` receiving every parsed context file;
- the final request containing the instructions as rules or preserved system
  prompt content.

The key regression test should reproduce the conditional failure where skills
parse successfully while current-format project instructions do not.

## Workarounds

Until the adapter is fixed:

- use a direct Pi provider that receives Pi's system prompt without this
  translation layer;
- place critical instructions in a Pi skill, because the adapter currently
  recognizes and forwards skills;
- use a known-compatible Pi version whose context format matches the adapter;
- patch `pi-cursor-agent` locally to parse the current context format.

Disabling context files is not a workaround because it removes the desired
instructions at the source.
