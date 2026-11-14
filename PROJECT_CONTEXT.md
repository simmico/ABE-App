# Aqeelah's Beauty Empire (ABE): Master Project Context

> **Purpose of this file:** This document is the single source of truth for the **Aqeelah's Beauty Empire (ABE)** project. Any new chat session or agent working in this workspace must read this file first to understand the business model, product rules, architecture decisions, and team roles.

---

## 0. Writing and Language Rules (Mandatory)
- **UK English Only:** All documentation, user interface copy, schedules, and messages must be written in British/South African English (e.g., *colour, centre, organise, programme, practice/practise, licence, cancelled*).
- **Natural Tone (No Em-Dashes or AI Clichés):** Never use em-dashes in any text, page titles, or code comments. Avoid robotic buzzwords or filler phrases (e.g., *delve, testament, tapestry, seamless, game-changer, elevate, leverage, foster*). Write in direct, natural, human prose.
- **Founder Names:** Always refer to the two founders by name: **Aqeelah** and **Rio**.

---

## 1. Core Concept and Value Proposition
- **The Problem:** South Africa's beauty industry suffers from a trust deficit (the "Inspo vs. Reality" gap) and slow 20-minute WhatsApp booking back-and-forths.
- **The Solution (The Visual Contract):** A visual-first booking marketplace starting with **Nails** for the MVP launch. A technician's portfolio acts as a **Digital Contract**: every portfolio photo has a fixed base price and duration for that exact look.
- **Modifiers and Add-ons:** The base photo price covers the exact look shown, with optional toggle modifiers configured by the tech (such as *Soak-off / Removal*, *Extra Length*, or *Nail Repair*) that automatically add to the total price and duration.
- **Strict Venue-Only Policy (No House Calls):** For client and technician safety, **no house calls or home visits are permitted**. Every appointment must take place at either:
  1. **A Verified Salon or Commercial Studio** (where the tech already works or rents a station), OR
  2. **An "Empty Chair" Partner Salon** (independent salons and nail bars that list their idle chairs during quiet hours in exchange for a chair fee or split per booking).

---

## 2. Target Markets and Team Roles
### Launch Hubs (Dual-City Launch)
1. **Cape Town (CPT):** Managed on the ground by **Aqeelah**.
2. **Johannesburg (JHB):** Managed on the ground by **Rio**.

### Team Split
- **Rio (JHB):**
  - Product architecture, mobile app development (iOS, Android, and Web Admin), wallet engineering, database security, and JHB salon/tech ground operations.
- **Aqeelah (CPT):**
  - Market research, independent nail tech recruitment, "Empty Chair" salon partnership pitches, "Certified Pro" skill auditions and grading, social media/influencer seeding, and customer dispute resolution.
  - *Workflow focus:* Unrushed, confidence-building progression (Current Focus items rather than rigid daily deadlines) with clear scripts, checklists, and step-by-step research guides to build independence, business ownership, and communication confidence.

---

## 3. Product Mechanics (Phase 1 MVP vs. Phase 2)

### Phase 1: Core Nail Marketplace MVP
1. **Visual Contract Feed and Booking:**
   - Browse verified nail looks by city (CPT / JHB), style, price, and availability.
   - Instant booking with upfront payment (Card, Instant EFT, or PayJustNow BNPL).
2. **The Grading and Verification System (Free-Market Pricing + Merit Badges):**
   - Techs set their own prices (regulated by market demand), paired with clear tier badges:
     - **Rising Tech:** Entry tier upon onboarding and venue verification.
     - **Verified Tech:** Unlocked after completing a set number of bookings with high ratings and consistent in-app completion photos.
     - **Certified Pro:** The highest standard. Earned either through sustained top-tier performance OR fast-tracked via a live physical or video skill assessment graded by Aqeelah.
3. **Anti-Fraud and Appointment Lifecycle ("Before/After Lock"):**
   - **Start of Appointment:** The tech must pass a **Biometric Check (FaceID/Selfie)** and enter the client's **randomised 4-digit booking PIN** (generated per booking) to start the job timer. *No PIN/Biometric = No Payout.*
   - **End of Appointment (Dispute Protection):** The tech must take an **in-app live camera photo** (gallery uploads are blocked) of the finished nails to close the job.
   - **Dispute Resolution:** If a client disputes the quality, admins compare three photos side-by-side: (1) The booked **Portfolio Photo**, (2) The Tech's live **Completion Photo**, and (3) The Client's **Complaint Photo**.
4. **Financial Engine and Closed-Loop Wallet ("The Float"):**
   - **Platform Fee:** 15% commission per booking.
   - **Payouts:** Weekly or bi-weekly automated payouts to techs, with an **Instant Cash-Out** option for a small fee.
   - **Closed-Loop Customer Wallet:** Customers cannot withdraw cash. Refunds are credited to their in-app wallet (cash refunds are a last resort).
   - **Cancellation Policy:**
     - *Tech Cancels:* The client receives 100% wallet credit plus a discount voucher towards their next booking with any tech (or re-routing to another available tech nearby).
     - *Client Late Cancellation:* 75% is refunded to the client's ABE Wallet, and 25% is paid to the tech to cover their lost chair time.

### Phase 2: Post-Traction Expansion (Deferred from MVP)
- **B2B "Stock-Up" Supply Store:** Techs buy nail supplies directly in the app using their "Pending Payouts" (zero upfront capital), delivered via local suppliers and Pargo.
- **The Monthly "Beauty Box":** Curated customer subscription boxes with influencer early-unboxings and "Golden Ticket" mystery extras.
- **Squad Parties and Bridal Packages:** Group bookings hosted at partner salons or venues.
- **Additional Beauty Categories:** Expanding from Nails into Wigs/Hair and Lashes/Brows.

---

## 4. Interactive Founder Hub (`founder-hub/`)
To make planning, learning, and execution effortless for both Aqeelah and Rio, the repository includes a dedicated web application inside `founder-hub/` that works both by double-clicking the HTML files locally (`file://`) and when hosted on **GitHub + Cloudflare Pages**:
- **Aesthetic & Palette:** Sophisticated Dusty Rose (`#C87D87`), Soft Blush (`#F5E6E8`), Warm Champagne (`#B89278`), Alabaster Cream (`#FAF6F5`), and Deep Espresso (`#2B2123`).
- **`founder-hub/index.html` (Aqeelah & Rio's Workspace):**
  - Switch between **Aqeelah's View** and **Rio's View**.
  - Displays **Current Focus**, **Recently Completed**, and an **Upcoming / Previous Items** slider, plus a **Full Checklist** view and tabs for **Aqeelah's Growth Map** and **Research & Copy-Paste Scripts**.
- **`founder-hub/concept.html` (Interactive Master Plan with Scroll-Driven SVG Animations):**
  - A visual walkthrough of the entire business from start to finish, featuring custom scroll-scrubbed SVG animations.
- **Data & Sync Architecture:**
  - Data lives in `founder-hub/data/roadmap.json`, `growth.json`, and `scripts.json` (with an automatic fallback in `js/sync.js` so it also works immediately when opened directly via `file://` without a web server).

---

## 5. Recommended Tech Stack (Core Mobile Platform)
- **Mobile App (Client and Tech Views):** **Flutter** (Single codebase compiling natively to iOS and Android, plus Web Admin Portal).
- **Backend and Database:** **Firebase** (Auth, Cloud Firestore, Cloud Functions, Cloud Storage for portfolio and completion photos) or **Supabase** (PostgreSQL, Auth, and Storage).
- **Payments (South Africa):** **Paystack** or **Peach Payments** (Card tokenisation, Instant EFT, split/payout APIs) + **PayJustNow** (BNPL integration).
