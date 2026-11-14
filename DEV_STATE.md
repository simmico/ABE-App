# DEV_STATE.md: Living Technical State & Multi-Chat Handoff

> **Purpose:** Every coding chat (`Chat 1` through `Chat 5`) and **Google Jules** reads this file first to see what has already been built and updates this file whenever a Roadmap Item is completed.

---

## 1. Current Overall Build Status
- **Active Stage:** Stage 1 (Foundation, Database & Discovery Feed)
- **Active Chat File:** `chats/CHAT_1_FOUNDATION.md`
- **Next Sub-Task to Execute:** `Sub-task 1.1` (Initialise Flutter multi-platform app & folder structure)
- **Completed Roadmap Items (Rio's Track):** None yet (`0 / 18` completed)

---

## 2. Installed Project Skills (`.agents/skills/`)
All agents working in this workspace have direct access to these installed local skills:
- **UI & Anti-AI Design:**
  - `.agents/skills/abe-anti-ai-design/SKILL.md` (ABE Dusty Rose & Cream Luxury Design System + UK English rules)
  - `.agents/skills/ui-ux-pro-max/SKILL.md` (Searchable UI/UX intelligence database)
  - `.agents/skills/design-system/SKILL.md`
  - `.agents/skills/ui-styling/SKILL.md`
  - `.agents/skills/brand/SKILL.md`
- **Security & Anti-Fraud:**
  - `.agents/skills/abe-security-auditor/SKILL.md` (Closed-Loop Wallet, Strict Venue-Only, 4-Digit PIN + Biometrics, Live Camera Lock)
  - Built-in `firestore-rules-author` subagent & `firebase-security-rules-auditor` skill
- **Multi-Chat & Google Jules Orchestration:**
  - `.agents/skills/abe-state-handoff/SKILL.md`
  - `.agents/skills/abe-jules-delegation/SKILL.md`

---

## 3. Repository & Directory Map
- `PROJECT_CONTEXT.md`: Master business model and product rules.
- `AGENTS.md`: Global rules for Antigravity and Google Jules.
- `ROADMAP_AQEELAH.md` & `ROADMAP_TECH.md`: 18-item roadmaps for Aqeelah and Rio.
- `AQEELAH_GROWTH_GUIDE.md`: Aqeelah's personal growth guide and outreach scripts.
- `founder-hub/`: Deployed interactive web hub (`index.html`, `concept.html`, `data/*.json`, `_worker.js`, `wrangler.jsonc`).
- `chats/`: Dedicated instruction & checkpoint files for each chat (`CHAT_0` to `CHAT_5`).
- `abe_app/` *(To be created in Chat 1, Sub-task 1.1)*: Flutter iOS, Android, and Web Admin application.

---

## 4. Completed Architecture & Database Log
*(Updated automatically by each chat as items are completed)*
- [x] **Founder Hub (`founder-hub/`)**: Built and configured for Cloudflare deployment.
- [ ] **Item 1:** Flutter & Backend Workspace Initialisation
- [ ] **Item 2:** Core Database Schemas & Security Rules
- [ ] **Item 3:** Auth Screens & Role Onboarding
- [ ] **Item 4:** Signature Visual Contract Card UI
- [ ] **Item 5:** Visual Contract Discovery Feed (CPT & JHB)
- [ ] **Item 6:** Booking Screen & Dynamic Modifier Calculator
- [ ] **Item 7:** Tech Portfolio Upload Flow
- [ ] **Item 8:** Stage 1 & 2 Prototype Review Refinements
- [ ] **Item 9:** Tech Availability Calendar & Slot Engine
- [ ] **Item 10:** Strict Venue-Only Booking Lock (Zero House Calls)
- [ ] **Item 11:** Grading & Tier Badge Engine
- [ ] **Item 12:** Biometric + 4-Digit Randomised PIN Start Lock
- [ ] **Item 13:** In-App Live Completion Camera Lock
- [ ] **Item 14:** Closed-Loop Wallet & 75/25 Cancellation Split
- [ ] **Item 15:** 3-Photo Dispute View & Empty Chair Salon Portal
- [ ] **Item 16:** South African Payment Gateways (Paystack/Peach + PayJustNow)
- [ ] **Item 17:** Full Security Audit & End-to-End QA
- [ ] **Item 18:** Production Deployment (CPT & JHB Launch)
