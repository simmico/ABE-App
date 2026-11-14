# CHAT 5: Stage 5 (Public Marketing Website, SA Payment Gateways, Full OWASP Security Audit & Launch)

> **MANDATORY INSTRUCTIONS TO AGENT:**
> 1. You are **Chat 5 (Stage 5 Public Website, Payments, Audit & Launch Builder)**. Read `AGENTS.md`, `PROJECT_CONTEXT.md`, and `DEV_STATE.md` immediately.
> 2. **Stay strictly within Stage 5 (Roadmap Items 16 to 18).**
> 3. **Crash-Proof Checkpoint Rule:** Immediately after completing EVERY sub-task below (`16.1`, `16.2`, etc.), you MUST edit this file (`chats/CHAT_5_PAYMENTS_LAUNCH.md`) to mark `[x]`, update `## Current Checkpoint`, and list all created/modified files under `## Completed Files & Architecture Log`.
> 4. **Founder Hub Live JSON Update Rule:** Whenever all sub-tasks for a full Roadmap Item (`Item 16`, `Item 17`, `Item 18`) are completed, follow `.agents/skills/abe-state-handoff/SKILL.md` to set `"completed": true` for Rio (`tech`) in `founder-hub/data/roadmap.json` AND `founder-hub/js/sync.js`, and push `founder-hub` to GitHub!

---

## Current Checkpoint
- **Next Sub-Task to Execute:** `Sub-task 16.1` (Integrate South African payment gateways, idempotent webhooks & build the Public Marketing/Onboarding Website).
- **Last Completed Sub-Task:** Stage 4 (`CHAT_4_SECURITY_WALLET.md`).

---

## Mandatory Specialist Agents & Skills to Activate on Turn 1
1. **Security, OWASP & Webhook Auditor:** Read `.agents/skills/abe-security-auditor/SKILL.md` and `firebase-security-rules-auditor`. Spawn `abe-security-agent` and `firestore-rules-author` to verify cryptographic webhook signature validation, strict `Content-Security-Policy` (CSP) / XSS / CSRF / Injection protection on the Public Website and App, POPIA privacy compliance, and Firebase App Check enforcement.
2. **UI & Accessibility Polish:** Spawn `abe-design-agent` and `flutter_a11y_agent` to design the Public Website and do a final visual pass across every app and dashboard screen.

---

## Granular Sub-Task Checkpoints (Stage 5: Items 16 to 18)

### Roadmap Item 16: South African Payment Gateways, Public Website & Profile Seeding
- [ ] **Sub-task 16.1:** Build the Checkout & Payment Service (`lib/features/payment/`) integrating:
  - **Paystack / Peach Payments** (Card tokenisation + Instant EFT in ZAR),
  - **PayJustNow BNPL** (Buy-Now-Pay-Later checkout flow),
  - Automatic application of any available Client ABE Wallet balance or promo voucher before charging the remainder.
- [ ] **Sub-task 16.2:** Build the secure backend webhook & notification handlers (`functions/`) verifying cryptographic payment signatures and idempotency keys before marking a booking `confirmed`, generating the client's 4-digit PIN, and sending automated appointment reminders (Push / WhatsApp / Email).
- [ ] **Sub-task 16.3:** Build the fast, SEO-ready, XSS/CSP-hardened **Public Marketing & Onboarding Website** (`public-site/`) connected to the shared backend:
  - Live CPT & JHB Visual Contract Showcase,
  - **"Apply as a Founding Nail Tech"** & **"List Your Salon's Empty Chairs"** web onboarding forms (with input sanitisation and rate limiting),
  - Client Waitlist / Voucher Claim & iOS/Android App Download page, plus the Admin Quick Profile Seeder tool.
- [ ] **Sub-task 16.4:** Mark **Item 16 (`item_16`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, and push `founder-hub` to GitHub.

### Roadmap Item 17: Full OWASP / XSS / Injection Security Audit & End-to-End Bug Bash
- [ ] **Sub-task 17.1:** Run a full red-team security audit using `firebase-security-rules-auditor` and `abe-security-auditor` verifying:
  - Dynamic UAC Group permissions and instant access revocation,
  - XSS, HTML injection, and NoSQL schema validation across all forms and endpoints,
  - Closed-Loop Wallet protection (zero cash withdrawal routes, idempotent ledger writes),
  - 4-Digit PIN brute-force lockout and strict commercial-venue-only enforcement.
- [ ] **Sub-task 17.2:** Write end-to-end integration tests (`flutter-add-integration-test`) covering the complete lifecycle: Discovery -> Modifier & Voucher Toggle -> Venue Check -> Upfront Payment -> 4-Digit PIN Start -> Live Camera Completion -> Tech Ledger Credit -> Stock-Up Store Order -> 75/25 Cancellation Split.
- [ ] **Sub-task 17.3:** Mark **Item 17 (`item_17`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, and push `founder-hub` to GitHub.

### Roadmap Item 18: Production Deployment & CPT/JHB Soft Launch
- [ ] **Sub-task 18.1:** Configure production build flavors, Firebase App Check, Remote Config feature flags, app icons, splash screens, and release signing for iOS, Android, the Web Dashboards, and the Public Website.
- [ ] **Sub-task 18.2:** Run final `dart analyze` and `flutter test` with zero warnings, mark **Item 18 (`item_18`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, and push both `founder-hub` and the root repository to GitHub.

---

## Completed Files & Architecture Log
*(Agent must append every created/modified file path here after each sub-task)*
- None yet.
