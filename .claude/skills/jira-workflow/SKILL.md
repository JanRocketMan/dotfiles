---
name: jira-workflow
description: Jira conventions — acli jira tool, ticket creation, board defaults. Use when working with Jira tickets, sprints, or boards.
---

# Jira

To work with jira use `acli jira` tool. If its not installed or configured ask the user to do this.

## Assignee

- Do **not** use `@me` for assignee — it may resolve to the wrong account.
- Instead, retrieve the current user's email via `acli jira auth status` and use that email explicitly in all ticket creation and assignment commands.

## Defaults

- Always transition newly created tickets to **"To Do"** status after creation.

## Boards

Default to the **AI Lab | GTE** board unless the user explicitly mentions AM or Access Management.

- **AI Lab | GTE** (PAIR project, default): Use JQL `project = PAIR AND issuetype IN (Bug, Story, Task, Sub-task) AND component = "PAIR ML Nikita" ORDER BY created DESC`
- **Access Management (AM)**: For access-related tickets, search the AM board instead: `project = AM AND project = am AND filter != "Reject update 1 week" ORDER BY Rank DESC`
