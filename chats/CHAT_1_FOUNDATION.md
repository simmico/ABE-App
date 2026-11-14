# CHAT 1: Stage 1 (Foundation, Database Schemas, Auth & Visual Contract Feed)

> **MANDATORY INSTRUCTIONS TO AGENT:**
> 1. You are **Chat 1 (Stage 1 Builder)**. Read `AGENTS.md`, `PROJECT_CONTEXT.md`, and `DEV_STATE.md` immediately.
> 2. **Stay strictly within Stage 1 (Roadmap Items 1 to 5).** Do not build Stage 2+ features.
> 3. **Crash-Proof Checkpoint Rule:** Immediately after completing EVERY sub-task below (`1.1`, `1.2`, etc.), you MUST edit this file (`chats/CHAT_1_FOUNDATION.md`) to mark `[x]`, update `## Current Checkpoint`, and list all created/modified files under `## Completed Files & Architecture Log`.
> 4. **Founder Hub Sync Rule:** Whenever all sub-tasks for a full Roadmap Item (`Item 1` through `Item 5`) are completed, follow `.agents/skills/abe-state-handoff/SKILL.md` to mark that item completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

---

## Current Checkpoint
- **Next Sub-Task to Execute:** `Sub-task 1.1` (Initialise Flutter project `abe_app/` and configure core theme using `abe-anti-ai-design`).
- **Last Completed Sub-Task:** None yet.

---

## Mandatory Specialist Agents & Skills to Activate on Turn 1
Before writing application code, read and activate:
1. **Design Intelligence:** Read `.agents/skills/abe-anti-ai-design/SKILL.md` and `.agents/skills/ui-ux-pro-max/SKILL.md`. Define a subagent named `abe-design-agent` (via `define_subagent`) whose system prompt enforces the Dusty Rose (`#C87D87`), Soft Blush (`#F5E6E8`), Warm Champagne (`#B89278`), Alabaster Cream (`#FAF6F5`), and Deep Espresso (`#2B2123`) palette, *Cormorant Garamond* + *Plus Jakarta Sans* typography, and UK English copy with zero em-dashes.
2. **Security & Rules Specialist:** Read `.agents/skills/abe-security-auditor/SKILL.md`. Whenever creating or modifying `firestore.rules` (in Item 2), you **MUST** delegate authoring to the `firestore-rules-author` subagent and audit with `firebase-security-rules-auditor`.
3. **Architecture & Static Analysis:** Use `flutter-apply-architecture-best-practices` and run `dart-run-static-analysis` after each item.

---

## Granular Sub-Task Checkpoints (Stage 1: Items 1 to 5)

### Roadmap Item 1: Architecture Setup & Role Routing
- [ ] **Sub-task 1.1:** Initialise the Flutter multi-platform project (`abe_app/` supporting iOS, Android, and Web) with layered clean architecture (`lib/core/`, `lib/features/`, `lib/shared/`).
- [ ] **Sub-task 1.2:** Build the official **ABE Warm Luxury Theme** (`lib/core/theme/abe_theme.dart`) using `.agents/skills/abe-anti-ai-design/SKILL.md` (Alabaster Cream `#FAF6F5`, Dusty Rose `#C87D87`, Champagne `#B89278`, Espresso `#2B2123`, *Cormorant Garamond* & *Plus Jakarta Sans*).
- [ ] **Sub-task 1.3:** Implement role definitions (`client`, `tech`, `salon_partner`, `admin`) and declarative route guards (`go_router` via `flutter-setup-declarative-routing`).
- [ ] **Sub-task 1.4:** Mark **Item 1** completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

### Roadmap Item 2: Core Database Schemas & Security Rules
- [ ] **Sub-task 2.1:** Create Dart domain models and JSON serialisation (`lib/features/*/domain/models/`) for:
  - `AbeUser` (id, name, role, city `CPT` or `JHB`, phone, rating),
  - `TechProfile` (userId, tierBadge: `rising` | `verified` | `certified_pro`, verifiedStudioId, bio),
  - `CommercialVenue` (id, name, city `CPT` | `JHB`, address, type: `verified_studio` | `partner_salon`, isVerified),
  - `VisualContractItem` (id, techId, photoUrl, title, basePriceZar, baseDurationMinutes, allowedModifiers).
- [ ] **Sub-task 2.2:** Delegate to the **`firestore-rules-author`** subagent (and audit with `abe-security-auditor`) to generate `firestore.rules` ensuring:
  - Public/authenticated read on verified `VisualContractItem` and `CommercialVenue` records,
  - Techs can only write to their own `VisualContractItem` records,
  - Only `admin` (Aqeelah/Rio) can promote `tierBadge` to `certified_pro` or set `CommercialVenue.isVerified = true`.
- [ ] **Sub-task 2.3:** Mark **Item 2** completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

### Roadmap Item 3: Auth Screens & Role Onboarding
- [ ] **Sub-task 3.1:** Build the Welcome, Sign In, and Registration screens (`lib/features/auth/presentation/`) reviewed by `abe-design-agent` (strictly UK English, zero em-dashes, luxury editorial feel).
- [ ] **Sub-task 3.2:** Build the Role & City Onboarding selector (choosing `Cape Town (CPT)` or `Johannesburg (JHB)` and role onboarding for Clients, Nail Techs, and Partner Salons).
- [ ] **Sub-task 3.3:** Mark **Item 3** completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

### Roadmap Item 4: Signature Visual Contract Card UI
- [ ] **Sub-task 4.1:** Build the reusable `VisualContractCard` widget (`lib/features/portfolio/presentation/widgets/visual_contract_card.dart`) showcasing:
  - Crisp `4:5` nail photography,
  - Top-left Merit Badge pill (*Rising Tech*, *Verified Tech*, or *Certified Pro ★* in Champagne/Rose Gold),
  - Bottom glass/cream bar with hard-coded **Base Price (`R450`)**, **Exact Duration (`90 mins`)**, and **Verified Salon Venue tag**.
- [ ] **Sub-task 4.2:** Write widget tests (`flutter-add-widget-test`) verifying price, duration, and badge rendering on `VisualContractCard`.
- [ ] **Sub-task 4.3:** Mark **Item 4** completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`.

### Roadmap Item 5: Visual Contract Discovery Feed (CPT & JHB)
- [ ] **Sub-task 5.1:** Build the `DiscoveryFeedScreen` (`lib/features/portfolio/presentation/screens/discovery_feed_screen.dart`) with instant filtering by City (`CPT` / `JHB`), Tier Badge, and Price Range, seeded with realistic CPT and JHB mock nail portfolios for immediate preview.
- [ ] **Sub-task 5.2:** Run `dart analyze` and `flutter test`, and audit accessibility with `flutter_a11y_agent`.
- [ ] **Sub-task 5.3:** Mark **Item 5** completed in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, and delegate the Stage 1 Background Subagent Offload Queue below via `invoke_subagent`.

---

## Completed Files & Architecture Log
*(Agent must append every created/modified file path here after each sub-task)*
- None yet.

---

## Background Subagent Offload Queue (Stage 1)
*(Executed automatically in the background via `invoke_subagent` inside Antigravity; replaces Google Jules)*
- **Background Task 1A:** Write comprehensive unit tests for `AbeUser`, `TechProfile`, `CommercialVenue`, and `VisualContractItem` JSON serialisation and price/duration edge cases.
- **Background Task 1B:** Build shimmer loading skeleton cards and empty-state illustrations for `DiscoveryFeedScreen` matching the Dusty Rose & Cream theme.
