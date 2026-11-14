# CHAT 3: Stage 3 (Tech Availability Calendar, Strict Venue-Only Lock, Tier Badges & Tech Dashboard)

> **MANDATORY INSTRUCTIONS TO AGENT:**
> 1. You are **Chat 3 (Stage 3 Builder)**. Read `AGENTS.md`, `PROJECT_CONTEXT.md`, and `DEV_STATE.md` immediately.
> 2. **Stay strictly within Stage 3 (Roadmap Items 9 to 11).**
> 3. **Crash-Proof Checkpoint Rule:** Immediately after completing EVERY sub-task below (`9.1`, `9.2`, etc.), you MUST edit this file (`chats/CHAT_3_CALENDAR_VENUE.md`) to mark `[x]`, update `## Current Checkpoint`, and list all created/modified files under `## Completed Files & Architecture Log`.
> 4. **Founder Hub Live JSON Update Rule:** Whenever all sub-tasks for a full Roadmap Item (`Item 9`, `Item 10`, `Item 11`) are completed, follow `.agents/skills/abe-state-handoff/SKILL.md` to set `"completed": true` for Rio (`tech`) in `founder-hub/data/roadmap.json` AND `founder-hub/js/sync.js`, and push `founder-hub` to GitHub!

---

## Current Checkpoint
- **Next Sub-Task to Execute:** `Sub-task 9.1` (Build Tech Availability Calendar & duration-aware slot generator).
- **Last Completed Sub-Task:** Stage 2 (`CHAT_2_BOOKING.md`).

---

## Mandatory Specialist Agents & Skills to Activate on Turn 1
1. **Security & Venue-Only Specialist:** Read `.agents/skills/abe-security-auditor/SKILL.md`. Spawn `abe-security-agent` and `firestore-rules-author` to guarantee that **no booking can ever be created without a verified commercial salon/studio or partner salon chair slot (strictly zero house calls)**.
2. **Design Intelligence:** Read `.agents/skills/abe-anti-ai-design/SKILL.md`. Spawn `abe-design-agent` to design the Calendar Slot Selector, Verified Venue Pill, Merit Tier Badges (*Rising Tech*, *Verified Tech*, *Certified Pro ★*), and the Nail Tech In-App Dashboard.

---

## Granular Sub-Task Checkpoints (Stage 3: Items 9 to 11)

### Roadmap Item 9: Tech Availability Calendar & Slot Engine
- [ ] **Sub-task 9.1:** Build the duration-aware `SlotGeneratorService` (`lib/features/calendar/domain/`) that calculates open appointment slots based on the tech's working hours, existing bookings, cleanup buffers, and the exact total minutes of the selected Visual Contract + modifiers.
- [ ] **Sub-task 9.2:** Build the `TechCalendarSetupScreen` (for nail techs to set weekly hours and block time) and the `ClientSlotPickerSheet` (for clients to select a date and time slot).
- [ ] **Sub-task 9.3:** Write unit tests for overlapping slot prevention, mark **Item 9 (`item_9`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, and push `founder-hub` to GitHub.

### Roadmap Item 10: Strict Venue-Only Booking Lock (Zero House Calls)
- [ ] **Sub-task 10.1:** Implement the `VenueSelectionService` and booking payload validator (`lib/features/booking/domain/`) requiring every booking to attach either:
  - `venueType: 'verified_studio'` (the tech's verified commercial salon chair), OR
  - `venueType: 'partner_salon_chair'` (an available off-peak chair slot at a verified Partner Salon in CPT or JHB).
- [ ] **Sub-task 10.2:** Delegate to `firestore-rules-author` and audit with `abe-security-auditor` so `firestore.rules` rejects any booking document lacking a verified commercial `venueId`.
- [ ] **Sub-task 10.3:** Build the Venue Confirmation card inside the booking checkout flow (clearly showing the commercial salon name, safety verification badge, and CPT/JHB area), mark **Item 10 (`item_10`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, and push `founder-hub` to GitHub.

### Roadmap Item 11: Grading, Tier Badges & Nail Tech In-App Dashboard
- [ ] **Sub-task 11.1:** Build the `TierProgressionService` (`lib/features/profile/domain/`) implementing:
  - `Rising Tech` (default upon identity & venue verification),
  - `Verified Tech` (unlocked automatically after completing $N$ bookings with $\ge 4.5$ average rating and 100% live completion photos),
  - `Certified Pro` (unlocked via Aqeelah's audition sign-off in the Admin Portal or sustained top-tier milestone).
- [ ] **Sub-task 11.2:** Build the **Nail Tech In-App Dashboard** (`lib/features/tech_dashboard/presentation/`) showing Today's Appointments, Chair Turnover stats, Tier Badge progress bar, Pending Payout Balance, and available Stock-Up Store credit allowance.
- [ ] **Sub-task 11.3:** Mark **Item 11 (`item_11`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, push `founder-hub` to GitHub, and delegate the Stage 3 Background Subagent Offload Queue below via `invoke_subagent`.

---

## Completed Files & Architecture Log
*(Agent must append every created/modified file path here after each sub-task)*
- None yet.

---

## Background Subagent Offload Queue (Stage 3)
*(Executed automatically in the background via `invoke_subagent` inside Antigravity)*
- **Background Task 3A:** Write unit tests for `SlotGeneratorService` testing 60-min, 90-min, and 135-min bookings across lunch breaks and existing appointments.
- **Background Task 3B:** Write security rule unit tests verifying that any booking payload without a valid commercial `venueId` is rejected.
