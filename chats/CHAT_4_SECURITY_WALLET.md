# CHAT 4: Stage 4 (4-Digit PIN Lock, Live Camera, Idempotent Wallet, Dashboards & Stock-Up Store)

> **MANDATORY INSTRUCTIONS TO AGENT:**
> 1. You are **Chat 4 (Stage 4 Security, Financial Engine, Admin & Store Builder)**. Read `AGENTS.md`, `PROJECT_CONTEXT.md`, and `DEV_STATE.md` immediately.
> 2. **Stay strictly within Stage 4 (Roadmap Items 12 to 15).**
> 3. **Crash-Proof Checkpoint Rule:** Immediately after completing EVERY sub-task below (`12.1`, `12.2`, etc.), you MUST edit this file (`chats/CHAT_4_SECURITY_WALLET.md`) to mark `[x]`, update `## Current Checkpoint`, and list all created/modified files under `## Completed Files & Architecture Log`.
> 4. **Founder Hub Live JSON Update Rule:** Whenever all sub-tasks for a full Roadmap Item (`Item 12` through `Item 15`) are completed, follow `.agents/skills/abe-state-handoff/SKILL.md` to set `"completed": true` for Rio (`tech`) in `founder-hub/data/roadmap.json` AND `founder-hub/js/sync.js`, and push `founder-hub` to GitHub!

---

## Current Checkpoint
- **Next Sub-Task to Execute:** `Sub-task 12.1` (Build Biometric + Randomised 4-Digit Client PIN appointment start lock with brute-force rate limiting).
- **Last Completed Sub-Task:** Stage 3 (`CHAT_3_CALENDAR_VENUE.md`).

---

## Mandatory Specialist Agents & Skills to Activate on Turn 1
1. **Security & Financial Auditor:** Read `.agents/skills/abe-security-auditor/SKILL.md`. Spawn `abe-security-agent` and `firestore-rules-author` on every sub-task in this stage to verify:
   - The 4-digit PIN is readable only by the client who booked, and locks for 15 minutes after 5 failed attempts,
   - The completion photo can only come from `ImageSource.camera` (with offline timestamp caching for weak salon signal),
   - `walletBalance`, `financial_ledger`, and `payouts` are server-write-only with mandatory `idempotencyKey` enforcement,
   - Dynamic UAC Group permissions (`uac.manage_roles`, `disputes.resolve`, `vouchers.manage`, `store.manage_inventory`) are enforced across all dashboards.
2. **Design Intelligence:** Read `.agents/skills/abe-anti-ai-design/SKILL.md`. Spawn `abe-design-agent` to style the 4-Digit PIN keypad, Live Camera frame, Wallet screen, Master Admin Command Centre, UAC Manager, 3-Photo Dispute Support Queue, Salon Partner Dashboard, and Stock-Up Store + Warehouse Supplier Dashboard.

---

## Granular Sub-Task Checkpoints (Stage 4: Items 12 to 15)

### Roadmap Item 12: Biometric + 4-Digit Randomised PIN Start Lock (Rate-Limited)
- [ ] **Sub-task 12.1:** Implement server-side generation of a unique, randomised 4-digit PIN per confirmed booking (stored in a client-only readable document) with brute-force rate limiting (max 5 failed attempts locks PIN entry for 15 minutes and alerts Support/Admin).
- [ ] **Sub-task 12.2:** Build the `TechStartAppointmentScreen` requiring device Biometric authentication (`local_auth` / selfie verification) plus the 4-digit PIN keypad to transition the booking status to `in_progress`.
- [ ] **Sub-task 12.3:** Audit with `abe-security-agent`, mark **Item 12 (`item_12`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, and push `founder-hub` to GitHub.

### Roadmap Item 13: In-App Live Completion Camera Lock (With Offline Resilience)
- [ ] **Sub-task 13.1:** Build the `TechCompleteAppointmentScreen` that forces live camera capture (`ImageSource.camera` only, zero gallery upload option) of the client's finished nails, with local encrypted queue fallback if salon cell signal drops.
- [ ] **Sub-task 13.2:** Enforce in backend/rules that a booking cannot transition from `in_progress` to `completed` (and earnings cannot move to the tech's pending payout ledger) without a verified `completionPhotoUrl`.
- [ ] **Sub-task 13.3:** Mark **Item 13 (`item_13`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, and push `founder-hub` to GitHub.

### Roadmap Item 14: Idempotent Closed-Loop Wallet, 75/25 Split & Coupon/Voucher Engine
- [ ] **Sub-task 14.1:** Build the idempotent double-entry `WalletAndLedgerService` (`lib/features/wallet/domain/`) implementing:
  - **15% Platform Fee** deduction on completed bookings (85% credited to Tech's pending payout ledger),
  - **Closed-Loop Client Wallet** (credits auto-applied at checkout, strictly no cash withdrawal route),
  - **Weekly/Bi-Weekly Tech Payouts** + **Instant Cash-Out** option with convenience fee deduction and `idempotencyKey` protection,
  - **Pending Payout Store Allowance** calculation (`Available Store Credit = Unpaid Net Earnings - Open Store Orders`).
- [ ] **Sub-task 14.2:** Implement the **Automated Cancellation Split Engine** & **Coupon / Voucher Management Service**:
  - *Client Late Cancellation:* Automatically credits **75%** to the Client's ABE Wallet and **25%** to the Tech's earnings ledger.
  - *Tech Cancellation:* Automatically credits **100%** to the Client's ABE Wallet plus generates a single-use apology discount voucher.
  - *Admin Coupon & Voucher Engine:* Support promo codes (`R1_EVENT`, influencer codes, percentage or fixed ZAR discounts, expiry dates, max redemptions, per-user limits, and rate-limited validation).
- [ ] **Sub-task 14.3:** Build the `ClientWalletScreen` and `TechEarningsScreen` UI, audit `firestore.rules` with `firestore-rules-author`, mark **Item 14 (`item_14`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, and push `founder-hub` to GitHub.

### Roadmap Item 15: Master Admin Command Centre, Dynamic UAC Editor, 3-Photo Dispute Support Queue, Salon Portal & Stock-Up Store / Warehouse Dashboard
- [ ] **Sub-task 15.1:** Build **Rio & Aqeelah's Master Admin Command Centre** (`lib/features/admin/presentation/`):
  - **Data & Financial Telemetry Dashboard:** Total Float held, GMV, 15% Platform Revenue, CPT vs. JHB bookings, Chair Turnover Rate, and SARS/Accountant CSV Ledger export.
  - **Dynamic UAC & Access Groups Manager:** View who can access what across all UAC Groups (`Super Admin`, `Ops Admin`, `Dispute Support Staff`, `Warehouse Supplier`, `Salon Partner`, `Tech`, `Client`), create custom UAC groups, toggle granular permissions, invite staff, and 1-click revoke access with immutable `StaffAuditLog` tracking.
  - **Coupon & Voucher Manager UI:** Create, pause, and track promo/voucher codes.
- [ ] **Sub-task 15.2:** Build the **Built-In 3-Photo Dispute Support Queue** (accessible to `Dispute Support Staff` and Admins without needing Jira/Zendesk) showing side-by-side:
  1. Booked **Visual Contract Portfolio Photo**,
  2. Tech's **Live In-App Completion Photo**, and
  3. Client's **Dispute Photo**,
  with 1-click buttons to credit the client's wallet or release payout to the tech.
- [ ] **Sub-task 15.3:** Build the **Stock-Up Store (In-App Tech Storefront)** + **Warehouse Supplier Dashboard & Hybrid Inventory Adapter** (`lib/features/store/`):
  - Render store rows natively in the app so Nail Techs can order supplies using their **Pending Payout Balance**,
  - Build the **Warehouse Supplier Portal** (`supplier_partner` UAC group) + **Hybrid Inventory Sync Adapter** (supporting 1-click CSV/Excel upload, Admin manual edits, or external Warehouse REST API/Webhook sync) and Pargo 4-hour dispatch tracking,
  - Build the **Salon Partner "Empty Chair" Dashboard** (`lib/features/salon_partner/`).
- [ ] **Sub-task 15.4:** Mark **Item 15 (`item_15`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, push `founder-hub` to GitHub, and delegate the Stage 4 Background Subagent Offload Queue below via `invoke_subagent`.

---

## Completed Files & Architecture Log
*(Agent must append every created/modified file path here after each sub-task)*
- None yet.

---

## Background Subagent Offload Queue (Stage 4)
*(Executed automatically in the background via `invoke_subagent` inside Antigravity)*
- **Background Task 4A:** Write exhaustive unit tests for `WalletAndLedgerService` testing idempotency keys, the 15% platform fee, 75%/25% client late-cancellation split, 100% + voucher tech cancellation recovery, and Stock-Up Store credit deduction math.
- **Background Task 4B:** Write unit tests for Dynamic UAC permission revocation, 4-digit PIN brute-force lockout, and CSV inventory import parsing for the Warehouse Supplier dashboard.
