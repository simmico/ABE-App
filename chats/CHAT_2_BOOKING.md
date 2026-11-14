# CHAT 2: Stage 2 (Booking Detail Screen, Dynamic Modifiers & Tech Portfolio Upload)

> **MANDATORY INSTRUCTIONS TO AGENT:**
> 1. You are **Chat 2 (Stage 2 Builder)**. Read `AGENTS.md`, `PROJECT_CONTEXT.md`, and `DEV_STATE.md` immediately.
> 2. **Stay strictly within Stage 2 (Roadmap Items 6 to 8).**
> 3. **Crash-Proof Checkpoint Rule:** Immediately after completing EVERY sub-task below (`6.1`, `6.2`, etc.), you MUST edit this file (`chats/CHAT_2_BOOKING.md`) to mark `[x]`, update `## Current Checkpoint`, and list all created/modified files under `## Completed Files & Architecture Log`.
> 4. **Founder Hub Sync Rule:** Whenever all sub-tasks for a full Roadmap Item (`Item 6`, `Item 7`, `Item 8`) are completed, follow `.agents/skills/abe-state-handoff/SKILL.md` to mark that item completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

---

## Current Checkpoint
- **Next Sub-Task to Execute:** `Sub-task 6.1` (Create `BookingModifier` model and dynamic price/duration calculator).
- **Last Completed Sub-Task:** Stage 1 (`CHAT_1_FOUNDATION.md`).

---

## Mandatory Specialist Agents & Skills to Activate on Turn 1
1. **Design Intelligence:** Read `.agents/skills/abe-anti-ai-design/SKILL.md` and `.agents/skills/ui-ux-pro-max/SKILL.md`. Spawn `abe-design-agent` to review the Booking Detail Screen and Tech Portfolio Upload UI so toggles, bottom sticky price bars, and photo upload cards feel like a high-end beauty studio app.
2. **Security Specialist:** Read `.agents/skills/abe-security-auditor/SKILL.md`. Ensure modifier calculations cannot produce negative prices or durations, and update `firestore.rules` via `firestore-rules-author` if new portfolio fields are added.

---

## Granular Sub-Task Checkpoints (Stage 2: Items 6 to 8)

### Roadmap Item 6: Booking Detail Screen & Dynamic Modifier Calculator
- [ ] **Sub-task 6.1:** Create the `BookingModifier` domain model and pure calculator service (`lib/features/booking/domain/`) supporting toggleable extras (*Soak-Off / Removal*, *Extra Length*, *Nail Repair per nail*) that dynamically add ZAR price and minutes to the base Visual Contract look.
- [ ] **Sub-task 6.2:** Build the `VisualContractDetailScreen` (`lib/features/booking/presentation/screens/visual_contract_detail_screen.dart`) with tactile modifier toggle rows and an animated bottom bar showing live **Total Price (`R...`)** and **Total Duration (`... mins`)**.
- [ ] **Sub-task 6.3:** Write unit and widget tests for the dynamic modifier calculator and mark **Item 6** completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

### Roadmap Item 7: Tech Portfolio Upload Flow
- [ ] **Sub-task 7.1:** Build the `TechPortfolioUploadScreen` (`lib/features/portfolio/presentation/screens/tech_portfolio_upload_screen.dart`) allowing nail techs to select a crisp photo of their work, enter the fixed base price and duration in minutes, and toggle which optional modifiers they offer for that set.
- [ ] **Sub-task 7.2:** Connect portfolio creation to the repository layer with input validation (minimum price, realistic duration bounds, verified commercial venue link).
- [ ] **Sub-task 7.3:** Mark **Item 7** completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

### Roadmap Item 8: Stage 1 & 2 Prototype Review & UI Polish
- [ ] **Sub-task 8.1:** Connect navigation from `DiscoveryFeedScreen` -> `VisualContractDetailScreen` -> `TechPortfolioUploadScreen` into a smooth clickable prototype for Rio and Aqeelah to test together.
- [ ] **Sub-task 8.2:** Run `dart analyze`, `flutter test`, and `flutter_a11y_agent` audit across all Stage 1 and Stage 2 screens.
- [ ] **Sub-task 8.3:** Mark **Item 8** completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

---

## Completed Files & Architecture Log
*(Agent must append every created/modified file path here after each sub-task)*
- None yet.

---

## Google Jules Offload Queue (Stage 2)
- **Jules Task 2A:** Add client-side image aspect-ratio cropping (`4:5`) and compression helper for `TechPortfolioUploadScreen`.
- **Jules Task 2B:** Write edge-case unit tests for multi-modifier combinations and currency formatting (`R1,250`).
