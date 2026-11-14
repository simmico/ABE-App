# CHAT 4: Stage 4 (Biometric + 4-Digit PIN Lock, Live Camera, Closed-Loop Wallet & Salons)

> **MANDATORY INSTRUCTIONS TO AGENT:**
> 1. You are **Chat 4 (Stage 4 Security & Financial Engine Builder)**. Read `AGENTS.md`, `PROJECT_CONTEXT.md`, and `DEV_STATE.md` immediately.
> 2. **Stay strictly within Stage 4 (Roadmap Items 12 to 15).**
> 3. **Crash-Proof Checkpoint Rule:** Immediately after completing EVERY sub-task below (`12.1`, `12.2`, etc.), you MUST edit this file (`chats/CHAT_4_SECURITY_WALLET.md`) to mark `[x]`, update `## Current Checkpoint`, and list all created/modified files under `## Completed Files & Architecture Log`.
> 4. **Founder Hub Sync Rule:** Whenever all sub-tasks for a full Roadmap Item (`Item 12` through `Item 15`) are completed, follow `.agents/skills/abe-state-handoff/SKILL.md` to mark that item completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

---

## Current Checkpoint
- **Next Sub-Task to Execute:** `Sub-task 12.1` (Build Biometric + Randomised 4-Digit Client PIN appointment start lock).
- **Last Completed Sub-Task:** Stage 3 (`CHAT_3_CALENDAR_VENUE.md`).

---

## Mandatory Specialist Agents & Skills to Activate on Turn 1
1. **Security & Financial Auditor:** Read `.agents/skills/abe-security-auditor/SKILL.md`. Spawn `abe-security-agent` and `firestore-rules-author` on every sub-task in this stage to verify:
   - The 4-digit PIN is readable only by the client who booked,
   - The completion photo can only come from `ImageSource.camera` (gallery blocked),
   - `walletBalance` and `ledger_entries` are server-write-only (clients can never withdraw cash).
2. **Design Intelligence:** Read `.agents/skills/abe-anti-ai-design/SKILL.md`. Spawn `abe-design-agent` to style the 4-Digit PIN keypad, Live Camera frame, Wallet screen, 3-Photo Dispute comparison view, and Partner Salon portal.

---

## Granular Sub-Task Checkpoints (Stage 4: Items 12 to 15)

### Roadmap Item 12: Biometric + 4-Digit Randomised PIN Start Lock
- [ ] **Sub-task 12.1:** Implement server-side generation of a unique, randomised 4-digit PIN per confirmed booking (stored in a client-only readable document so the tech cannot read it from the database).
- [ ] **Sub-task 12.2:** Build the `TechStartAppointmentScreen` requiring device Biometric authentication (`local_auth` / selfie verification) plus the 4-digit PIN keypad to transition the booking status to `in_progress`.
- [ ] **Sub-task 12.3:** Audit with `abe-security-agent` and mark **Item 12** completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

### Roadmap Item 13: In-App Live Completion Camera Lock
- [ ] **Sub-task 13.1:** Build the `TechCompleteAppointmentScreen` that forces live camera capture (`ImageSource.camera` only, zero gallery upload option) of the client's finished nails.
- [ ] **Sub-task 13.2:** Enforce in backend/rules that a booking cannot transition from `in_progress` to `completed` (and earnings cannot move to the tech's pending payout ledger) without a verified `completionPhotoUrl`.
- [ ] **Sub-task 13.3:** Mark **Item 13** completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

### Roadmap Item 14: Closed-Loop Customer Wallet & 75/25 Cancellation Split
- [ ] **Sub-task 14.1:** Build the double-entry `WalletAndLedgerService` (`lib/features/wallet/domain/`) implementing:
  - **15% Platform Fee** deduction on completed bookings (85% credited to Tech's pending payout ledger),
  - **Closed-Loop Client Wallet** (credits auto-applied at checkout, strictly no cash withdrawal route),
  - **Weekly/Bi-Weekly Tech Payouts** + **Instant Cash-Out** option with convenience fee deduction.
- [ ] **Sub-task 14.2:** Implement the **Automated Cancellation Split Engine**:
  - *Client Late Cancellation:* Automatically credits **75%** to the Client's ABE Wallet and **25%** to the Tech's earnings ledger.
  - *Tech Cancellation:* Automatically credits **100%** to the Client's ABE Wallet plus generates a next-booking discount voucher.
- [ ] **Sub-task 14.3:** Build the `ClientWalletScreen` and `TechEarningsScreen` UI, audit `firestore.rules` with `firestore-rules-author`, and mark **Item 14** completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

### Roadmap Item 15: 3-Photo Dispute View & Empty Chair Salon Portal
- [ ] **Sub-task 15.1:** Build the Web Admin **3-Photo Dispute Resolution Screen** (`lib/features/admin/presentation/screens/dispute_resolution_screen.dart`) showing side-by-side:
  1. The Booked **Visual Contract Portfolio Photo**,
  2. The Tech's **Live In-App Completion Photo**, and
  3. The Client's **Dispute Photo**,
  with 1-click buttons for Aqeelah/Rio to credit the client's wallet or release payout to the tech.
- [ ] **Sub-task 15.2:** Build the **Salon Partner "Empty Chair" Portal** (`lib/features/salon_partner/presentation/`) where independent salons in CPT and JHB list their spare nail stations and quiet mid-week hours (e.g., Tue to Thu 10:00 to 15:00) and set their chair fee.
- [ ] **Sub-task 15.3:** Mark **Item 15** completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

---

## Completed Files & Architecture Log
*(Agent must append every created/modified file path here after each sub-task)*
- None yet.

---

## Background Subagent Offload Queue (Stage 4)
*(Executed automatically in the background via `invoke_subagent` inside Antigravity; replaces Google Jules)*
- **Background Task 4A:** Write exhaustive unit tests for `WalletAndLedgerService` testing the 15% platform fee, 75%/25% client late-cancellation split, 100% + voucher tech cancellation recovery, and instant cash-out fee math.
- **Background Task 4B:** Build CSV export and filtering for the Admin Ledger & Dispute History table.
