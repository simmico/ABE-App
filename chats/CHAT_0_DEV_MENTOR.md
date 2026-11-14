# CHAT 0: Rio's Dev Mentor, Git, Skills & Google Jules Setup Chat

> **Instruction to Agent:** You are **Chat 0 (Rio's Dev Mentor & Workflow Architect)**.
> First, read `AGENTS.md`, `PROJECT_CONTEXT.md`, and `DEV_STATE.md`.
> Your role is NOT to build all the stages yourself, but to guide Rio through his development environment setup, Git branching workflow, specialist agent usage, and delegating background tasks to **Google Jules** (`jules.google.com`).

---

## Current Checkpoint
- **Active Step:** `Step 0.2` (Main App Git Repository & Branch Strategy: set up the Git structure with clean `main` and `dev` branches so Google Jules can open Pull Requests cleanly).
- **Last Completed Step:** `Step 0.1` (Verified and installed local Flutter `3.50.0`, Dart `3.14.0`, Git `2.56.0`, Node `v22.14.0`, and Firebase CLI `15.36.0`).

---

## Mandatory Skills to Load in This Chat
- `.agents/skills/abe-jules-delegation/SKILL.md`
- `.agents/skills/abe-anti-ai-design/SKILL.md`
- `.agents/skills/abe-security-auditor/SKILL.md`

---

## Checklist for Chat 0 (Update `[x]` As You Complete Each With Rio)
- [x] **Step 0.1: Verify Local Dev Toolchain**
  - Check whether `flutter`, `dart`, `git`, `node`, and `firebase` CLIs are installed and working on Rio's Windows machine.
  - Guide Rio through installing or configuring any missing tool cleanly.
- [ ] **Step 0.2: Main App Git Repository & Branch Strategy**
  - Help Rio set up the Git structure for the main app (separate from or alongside `founder-hub`) with a clean `main` branch and `dev` branch so **Google Jules** can open Pull Requests cleanly.
- [ ] **Step 0.3: Connecting Google Jules (`jules.google.com`)**
  - Walk Rio through connecting Google Jules to his GitHub repository, showing him how Jules automatically reads `AGENTS.md` and `DEV_STATE.md`, and generating his first test GitHub Issue using `.agents/skills/abe-jules-delegation/SKILL.md`.
- [ ] **Step 0.4: How to Use Specialist Agents in Chats 1 to 5**
  - Explain to Rio how each stage chat (`CHAT_1` to `CHAT_5`) automatically spawns:
    1. `abe-design-agent` (for luxury, non-AI UI),
    2. `abe-security-agent` / `firestore-rules-author` (for wallet, PIN, and venue-only security), and
    3. `abe-qa-tester` (for running widget and unit tests).

---

## Completed Files & Architecture Log
- `chats/CHAT_0_DEV_MENTOR.md`: Completed Step 0.1 toolchain installation (`Flutter 3.50.0`, `Dart 3.14.0`, `Firebase CLI 15.36.0`, `Git 2.56.0`, `Node v22.14.0`) and updated checkpoint to Step 0.2.
