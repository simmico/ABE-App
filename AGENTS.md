# AGENTS.md: Global Rules for Antigravity & Google Jules

> **Mandatory Instructions for All AI Agents (Antigravity, Subagents, and Google Jules):**
> Read this file and `PROJECT_CONTEXT.md` before writing any code, creating any UI, or modifying any database schema.

---

## 1. Language, Copy, and Tone Rules (Strict)
1. **UK / South African English Only:** Every string, UI label, comment, commit message, and documentation file must use British/South African spelling (*colour, centre, organise, programme, practice/practise, licence, cancelled, tokenisation, randomised*).
2. **Zero Em-Dashes:** Never use the em-dash character in any UI copy, markdown file, or code comment.
3. **No Robotic AI Clichés:** Never use generic AI filler words (*delve, testament, tapestry, seamless, elevate, game-changer, leverage, foster, revolutionise*). Write crisp, direct, human copy suited to a modern South African beauty brand.
4. **Founder Names:** The two founders are **Aqeelah** (Brand, Quality, and Cape Town Operations) and **Rio** (Engineering, Architecture, and Johannesburg Operations).
5. **City Scope:** Launch cities are **Cape Town (CPT)** and **Johannesburg (JHB)**. Do not hard-code narrow suburb restrictions into the core data models.

---

## 2. Non-Negotiable Business & Security Invariants
Every feature, API endpoint, and database security rule must enforce these invariants:

1. **The Visual Contract:**
   - Every portfolio item uploaded by a nail technician has a **hard-coded base price (in ZAR / Rands)** and **base duration (in minutes)** for that exact look, plus optional toggle modifiers (*Soak-Off / Removal*, *Extra Length*, *Nail Repair*) that dynamically add price and minutes.
2. **Strict Venue-Only Policy (Zero House Calls):**
   - **No house calls or residential home visits are permitted anywhere in the codebase.**
   - Every booking record must reference either:
     - `verifiedStudioId`: A verified commercial salon/studio where the tech works, OR
     - `partnerSalonChairSlotId`: An "Empty Chair" partner salon slot reserved during off-peak hours.
   - Any booking payload missing a valid commercial venue reference must be rejected by backend validation and database rules.
3. **Appointment Start Lock (Biometric + Randomised 4-Digit Client PIN):**
   - Each confirmed booking generates a randomised 4-digit PIN visible only to the client.
   - A booking cannot transition to `in_progress` unless the tech passes biometric/selfie verification AND submits the matching 4-digit PIN.
4. **Appointment Completion Lock (Live In-App Camera Only):**
   - A booking cannot transition to `completed` (and funds cannot move to the tech's withdrawable/pending payout ledger) unless the tech captures a **live in-app camera photo** (`source: ImageSource.camera`, with gallery picker disabled) of the completed nails.
5. **Closed-Loop Wallet & Automated Cancellation Splits:**
   - **15% Platform Fee** on every completed booking.
   - **Customer Wallet is Closed-Loop:** Clients can spend wallet credits at checkout, but there must **never** be a client cash-withdrawal endpoint, and client SDKs must **never** have direct write access to `walletBalance`.
   - **Client Late Cancellation:** Automatically credits **75%** to the client's ABE Wallet and **25%** to the nail tech's earnings ledger.
   - **Tech Cancellation:** Automatically credits **100%** to the client's ABE Wallet plus generates a discount voucher for their next booking with any tech.

---

## 3. Anti-AI Design System ("Warm Luxury Beauty Studio")
Never generate default blue/purple Material templates or generic AI dashboards. Follow `.agents/skills/abe-anti-ai-design/SKILL.md`:
- **Colour Tokens:**
  - Alabaster Cream Background: `#FAF6F5`
  - Pure Surface Card: `#FFFFFF`
  - Soft Blush Highlight: `#F5E6E8`
  - Primary Dusty Rose: `#C87D87` (Hover/Active Deep Rose: `#A65E68`)
  - Warm Champagne / Rose Gold Accent: `#B89278`
  - Deep Espresso Charcoal Text: `#2B2123` (Muted Text: `#6E5A5D`)
  - Warm Border Hairline: `#EADCD9`
  - Sage Success: `#5E8C76`
- **Typography:**
  - Editorial Headings: *Cormorant Garamond* (semi-bold/bold, tight tracking)
  - Body, Prices, Badges & Controls: *Plus Jakarta Sans*
- **Component Feel:** Generous padding, `14px` to `22px` border radii, subtle warm borders (`1px solid #EADCD9`), soft espresso shadows (`rgba(43, 33, 35, 0.05)`), and high-contrast price/duration pills stamped cleanly onto nail photography.

---

## 4. Checkpoint & Multi-Chat Recovery Protocol
Each stage of development has its own dedicated instruction file in `chats/CHAT_X_*.md`.
- Whenever an agent completes a sub-task inside a `chats/CHAT_X_*.md` file, it **must immediately edit that `chats/CHAT_X_*.md` file** to:
  1. Tick the sub-task checkbox (`[x]`),
  2. Record the created/modified file paths under `## Completed Files & Architecture Log`, and
  3. Update `## Current Checkpoint` with the exact next sub-task to run.
- Whenever a full Roadmap Item (`Item 1` to `Item 18`) is completed, the agent must also update `ROADMAP_TECH.md` and `founder-hub/data/roadmap.json` (plus `founder-hub/js/sync.js`) so Rio and Aqeelah's live progress bar advances automatically.
