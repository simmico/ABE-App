---
name: abe-jules-delegation
description: >-
  Formats and delegates self-contained background coding tasks (unit tests,
  UI polish, shimmer skeletons, and edge-case checks) to Antigravity background
  subagents (`invoke_subagent`) since Google Jules has wound down.
---

# ABE Background Subagent Delegation Skill (Replacing Google Jules)

> **Important Update:** Since Google Jules (`jules.google.com`) has wound down, all tasks listed under the **Background Subagent Offload Queue** in `chats/CHAT_1_*.md` through `chats/CHAT_5_*.md` must be executed directly inside Antigravity using native background subagents (`invoke_subagent` with `TypeName: "self"` or a defined `abe-qa-tester` subagent) rather than asking Rio to paste issues into an external site.

---

## How Background Subagents Work in Antigravity
1. Whenever a Stage Chat (`CHAT_1` to `CHAT_5`) reaches its **Background Subagent Offload Queue**, the main agent spawns a background subagent via `invoke_subagent` to complete those unit tests or UI polish tasks automatically.
2. Every subagent prompt must instruct the subagent to read `AGENTS.md`, `PROJECT_CONTEXT.md`, and `DEV_STATE.md` first.

---

## Template for Spawning a Background Subagent Task
When invoking `invoke_subagent` for an offload task, pass this structured prompt:

```markdown
### [Background Subagent Task] <Short Descriptive Title>
**Context Files to Read First:** `AGENTS.md`, `PROJECT_CONTEXT.md`, `DEV_STATE.md`
**Files to Create / Modify:**
- `<exact/path/to/file1.dart>`
- `<exact/path/to/test_file1.dart>`

**Requirements:**
1. <Specific requirement 1 following UK English, zero em-dashes, and ABE design/security rules>
2. <Specific requirement 2>

**Verification / Done Criteria:**
- Run `flutter analyze` and `flutter test <test_file_path>` with zero errors.
```
