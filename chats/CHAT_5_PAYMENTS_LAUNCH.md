# CHAT 5: Stage 5 (SA Payment Gateways, Full Security Audit & Production Launch)

> **MANDATORY INSTRUCTIONS TO AGENT:**
> 1. You are **Chat 5 (Stage 5 Payments, Audit & Launch Builder)**. Read `AGENTS.md`, `PROJECT_CONTEXT.md`, and `DEV_STATE.md` immediately.
> 2. **Stay strictly within Stage 5 (Roadmap Items 16 to 18).**
> 3. **Crash-Proof Checkpoint Rule:** Immediately after completing EVERY sub-task below (`16.1`, `16.2`, etc.), you MUST edit this file (`chats/CHAT_5_PAYMENTS_LAUNCH.md`) to mark `[x]`, update `## Current Checkpoint`, and list all created/modified files under `## Completed Files & Architecture Log`.
> 4. **Founder Hub Sync Rule:** Whenever all sub-tasks for a full Roadmap Item (`Item 16`, `Item 17`, `Item 18`) are completed, follow `.agents/skills/abe-state-handoff/SKILL.md` to mark that item completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

---

## Current Checkpoint
- **Next Sub-Task to Execute:** `Sub-task 16.1` (Integrate South African payment gateway checkout & webhook handlers).
- **Last Completed Sub-Task:** Stage 4 (`CHAT_4_SECURITY_WALLET.md`).

---

## Mandatory Specialist Agents & Skills to Activate on Turn 1
1. **Security & Webhook Auditor:** Read `.agents/skills/abe-security-auditor/SKILL.md` and `firebase-security-rules-auditor`. Spawn `abe-security-agent` and `firestore-rules-author` to verify cryptographic webhook signature validation (preventing fake payment webhooks) and run a full red-team audit across all collections.
2. **UI & Accessibility Polish:** Spawn `abe-design-agent` and `flutter_a11y_agent` to do a final visual and accessibility pass across every screen.

---

## Granular Sub-Task Checkpoints (Stage 5: Items 16 to 18)

### Roadmap Item 16: South African Payment Gateways & Profile Seeding
- [ ] **Sub-task 16.1:** Build the Checkout & Payment Service (`lib/features/payment/`) integrating:
  - **Paystack / Peach Payments** (Card tokenisation + Instant EFT in ZAR),
  - **PayJustNow BNPL** (Buy-Now-Pay-Later checkout flow),
  - Automatic application of any available Client ABE Wallet balance before charging the remainder.
- [ ] **Sub-task 16.2:** Build the secure backend webhook handler verifying payment signatures before marking a booking `confirmed` and generating the client's 4-digit PIN.
- [ ] **Sub-task 16.3:** Build the Admin Bulk/Quick Profile Seeder tool so Aqeelah and Rio can rapidly load Founding Nail Tech portfolios for CPT and JHB, and mark **Item 16** completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

### Roadmap Item 17: Full Security Audit & End-to-End Bug Bash
- [ ] **Sub-task 17.1:** Run a full security audit using `firebase-security-rules-auditor` and `abe-security-auditor` across all database rules, wallet endpoints, PIN checks, and venue locks.
- [ ] **Sub-task 17.2:** Write end-to-end integration tests (`flutter-add-integration-test`) covering the complete booking lifecycle: Discovery -> Modifier Toggle -> Venue Check -> Upfront Payment -> 4-Digit PIN Start -> Live Camera Completion -> Tech Ledger Credit -> 75/25 Cancellation Split.
- [ ] **Sub-task 17.3:** Mark **Item 17** completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

### Roadmap Item 18: Production Deployment & CPT/JHB Soft Launch
- [ ] **Sub-task 18.1:** Configure production build flavors, app icons, splash screens, and release signing for iOS, Android, and the Web Admin Portal.
- [ ] **Sub-task 18.2:** Run final `dart analyze` and `flutter test` with zero warnings, and mark **Item 18** completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

---

## Completed Files & Architecture Log
*(Agent must append every created/modified file path here after each sub-task)*
- None yet.
