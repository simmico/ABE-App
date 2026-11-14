---
name: abe-state-handoff
description: >-
  Enforces the crash-proof checkpoint and state-sync protocol across
  chats/CHAT_X_*.md, DEV_STATE.md, ROADMAP_TECH.md, and founder-hub/data/roadmap.json.
---

# ABE Multi-Chat Checkpoint & State Handoff Skill

Activate this skill during every coding chat to ensure that if a chat is closed or restarted at any moment, the next chat can resume without losing a single step, AND Rio's live Founder Hub website (`https://github.com/simmico/ABE`) updates automatically.

---

## 1. After Every Sub-Task (`[ ] X.Y` -> `[x] X.Y`)
Immediately after completing any sub-task inside your active `chats/CHAT_X_*.md` file, you **MUST** edit that `chats/CHAT_X_*.md` file to:
1. Change `- [ ] **Sub-task X.Y:**` to `- [x] **Sub-task X.Y:**`.
2. Update the `## Current Checkpoint` section at the top of `chats/CHAT_X_*.md` to point to the next incomplete sub-task.
3. Add the exact file paths you created or modified under `## Completed Files & Architecture Log` in `chats/CHAT_X_*.md`.

---

## 2. After Completing a Full Roadmap Item (`Item 1` to `Item 18`)
Whenever all sub-tasks for a full Roadmap Item (e.g., `Item 1`, `Item 2`, etc.) are finished, you **MUST** execute all 4 steps below:
1. **`DEV_STATE.md`**: Record the completed Item, any new database collections/models, and current architecture status.
2. **`ROADMAP_TECH.md`**: Tick the corresponding markdown checkbox (`[x]`).
3. **`founder-hub/data/roadmap.json` AND `founder-hub/js/sync.js`**:
   - In `founder-hub/data/roadmap.json`, find the matching `"id": "item_X"` object and set `"tech": { ..., "completed": true, "completedAt": "<ISO-date>" }`.
   - Run the sync script (or update `FALLBACK_ROADMAP` inside `founder-hub/js/sync.js`) so `founder-hub/js/sync.js` matches `founder-hub/data/roadmap.json`.
4. **Push Both Git Repositories:**
   - Commit and push `founder-hub` (`git -C founder-hub add -A && git -C founder-hub commit -m "Complete Item X for Rio" && git -C founder-hub push`) so Rio and Aqeelah's live Cloudflare website progress bar advances immediately!
   - Commit and push the root app repository (`git add -A && git commit -m "Complete Item X" && git push`).
