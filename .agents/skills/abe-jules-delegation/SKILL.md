---
name: abe-jules-delegation
description: >-
  Formats self-contained background coding tasks and GitHub Issue specs for
  Google Jules (jules.google.com) so routine tests, UI polish, and isolated features
  can be coded asynchronously on GitHub branches.
---

# ABE Google Jules Delegation Skill

Use this skill whenever preparing tasks for **Google Jules** or updating the `## Google Jules Offload Queue` inside any `chats/CHAT_X_*.md` file.

---

## How Google Jules Works With This Repo
1. Google Jules connects to the GitHub repository and automatically reads `AGENTS.md` and `PROJECT_CONTEXT.md` at the root.
2. Jules works best when given **self-contained, well-scoped tasks** with explicit file paths and acceptance criteria.

---

## Template for Writing a Google Jules Task / GitHub Issue
Whenever generating a task for Rio to assign to Google Jules, format it using this exact block so Rio can copy-paste it directly into a GitHub Issue or the Jules web UI (`jules.google.com`):

```markdown
### [Jules Task] <Short Descriptive Title>
**Target Branch:** `jules/<short-slug>`
**Context Files to Read First:** `AGENTS.md`, `PROJECT_CONTEXT.md`, `DEV_STATE.md`
**Files to Create / Modify:**
- `<exact/path/to/file1.dart>`
- `<exact/path/to/test_file1.dart>`

**Requirements:**
1. <Specific requirement 1 following UK English and ABE design/security rules>
2. <Specific requirement 2>

**Verification / Done Criteria:**
- Run `flutter analyze` and `flutter test <test_file_path>` with zero errors.
```
