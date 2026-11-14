# CHAT 2: Stage 2 (Booking Detail Screen, Dynamic Modifiers & Tech Portfolio Upload)

> **MANDATORY INSTRUCTIONS TO AGENT:**
> 1. You are **Chat 2 (Stage 2 Builder)**. Read `AGENTS.md`, `PROJECT_CONTEXT.md`, and `DEV_STATE.md` immediately.
> 2. **Stay strictly within Stage 2 (Roadmap Items 6 to 8).**
> 3. **Crash-Proof Checkpoint Rule:** Immediately after completing EVERY sub-task below (`6.1`, `6.2`, etc.), you MUST edit this file (`chats/CHAT_2_BOOKING.md`) to mark `[x]`, update `## Current Checkpoint`, and list all created/modified files under `## Completed Files & Architecture Log`.
> 4. **Founder Hub Live JSON Update Rule:** Whenever all sub-tasks for a full Roadmap Item (`Item 6`, `Item 7`, `Item 8`) are completed, follow `.agents/skills/abe-state-handoff/SKILL.md` to set `"completed": true` for Rio (`tech`) in `founder-hub/data/roadmap.json` AND `founder-hub/js/sync.js`, and push `founder-hub` to GitHub!

---

## Current Checkpoint
- **Next Sub-Task to Execute:** `CHAT_3_CALENDAR_AND_VENUE.md` (Stage 2 complete; ready for Stage 3).
- **Last Completed Sub-Task:** `Sub-task 8.3` (Completed Stage 2 Items 6 to 8, audited with `abe-design-agent` and `flutter_a11y_agent`, synced Founder Hub, and delegated Background Tasks 2A & 2B).

---

## Mandatory Specialist Agents & Skills to Activate on Turn 1
1. **Design Intelligence:** Read `.agents/skills/abe-anti-ai-design/SKILL.md` and `.agents/skills/ui-ux-pro-max/SKILL.md`. Spawn `abe-design-agent` to review the Booking Detail Screen and Tech Portfolio Upload UI so toggles, bottom sticky price bars, and photo upload cards feel like a high-end beauty studio app.
2. **Security Specialist:** Read `.agents/skills/abe-security-auditor/SKILL.md`. Ensure modifier calculations and voucher previews cannot produce negative prices or durations, sanitise all text inputs against XSS, and update `firestore.rules` via `firestore-rules-author` if new portfolio fields are added.

---

## Granular Sub-Task Checkpoints (Stage 2: Items 6 to 8)

### Roadmap Item 6: Booking Detail Screen & Dynamic Modifier Calculator
- [x] **Sub-task 6.1:** Create the `BookingModifier` domain model and pure calculator service (`lib/features/booking/domain/`) supporting toggleable extras (*Soak-Off / Removal*, *Extra Length*, *Nail Repair per nail*) and promo/voucher code application that dynamically recalculate ZAR price and minutes.
- [x] **Sub-task 6.2:** Build the `VisualContractDetailScreen` (`lib/features/booking/presentation/screens/visual_contract_detail_screen.dart`) with tactile modifier toggle rows, promo code input field, and an animated bottom bar showing live **Total Price (`R...`)** and **Total Duration (`... mins`)**.
- [x] **Sub-task 6.3:** Write unit and widget tests for the dynamic modifier calculator, mark **Item 6 (`item_6`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, and push `founder-hub` to GitHub.

### Roadmap Item 7: Tech Portfolio Upload Flow
- [x] **Sub-task 7.1:** Build the `TechPortfolioUploadScreen` (`lib/features/portfolio/presentation/screens/tech_portfolio_upload_screen.dart`) allowing nail techs to select a crisp photo of their work, enter the fixed base price and duration in minutes, and toggle which optional modifiers they offer for that set.
- [x] **Sub-task 7.2:** Connect portfolio creation to the repository layer with input sanitisation and validation (minimum price, realistic duration bounds, verified commercial venue link).
- [x] **Sub-task 7.3:** Mark **Item 7 (`item_7`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, and push `founder-hub` to GitHub.

### Roadmap Item 8: Stage 1 & 2 Prototype Review & UI Polish
- [x] **Sub-task 8.1:** Connect navigation from `DiscoveryFeedScreen` -> `VisualContractDetailScreen` -> `TechPortfolioUploadScreen` into a smooth clickable prototype for Rio and Aqeelah to test together.
- [x] **Sub-task 8.2:** Run `dart analyze`, `flutter test`, and `flutter_a11y_agent` audit across all Stage 1 and Stage 2 screens.
- [x] **Sub-task 8.3:** Mark **Item 8 (`item_8`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, push `founder-hub` to GitHub, and delegate the Stage 2 Background Subagent Offload Queue below via `invoke_subagent`.

---

## Completed Files & Architecture Log
*(Agent must append every created/modified file path here after each sub-task)*
- `abe_app/lib/features/booking/domain/models/booking_modifier.dart` (Sub-task 6.1: `BookingModifierType`, `BookingModifier`, `BookingPriceQuote`, and `BookingModifierLineItem` domain models)
- `abe_app/lib/features/booking/domain/services/booking_calculator_service.dart` (Sub-task 6.1: Pure `BookingCalculatorService` for dynamic ZAR price, duration in minutes, and voucher discount calculation)
- `abe_app/lib/features/booking/presentation/screens/visual_contract_detail_screen.dart` (Sub-task 6.2: `VisualContractDetailScreen` with tactile modifier toggle rows, per-nail stepper, voucher validation, and animated sticky total bar)
- `abe_app/test/booking_calculator_and_detail_screen_test.dart` (Sub-task 6.3: Unit and widget test suite for `BookingModifier`, `BookingCalculatorService`, and `VisualContractDetailScreen`)
- `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, `founder-hub/js/sync.js` (Sub-task 6.3: Marked Item 6 completed for Rio)
- `abe_app/lib/features/portfolio/presentation/screens/tech_portfolio_upload_screen.dart` (Sub-task 7.1: `TechPortfolioUploadScreen` for 4:5 nail photo upload, fixed Rand price/duration, verified commercial venue link, and optional modifier toggles)
- `abe_app/lib/features/portfolio/data/repositories/visual_contract_repository.dart` (Sub-task 7.2: `VisualContractRepository` enforcing XSS sanitisation, R150-R5000 price bounds, 30-300 min duration bounds, and Strict Venue-Only Policy)
- `abe_app/test/tech_portfolio_upload_test.dart` (Sub-task 7.2: Unit and widget tests for `VisualContractRepository` and `TechPortfolioUploadScreen`)
- `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, `founder-hub/js/sync.js` (Sub-task 7.3: Marked Item 7 completed for Rio)
- `abe_app/lib/features/portfolio/presentation/screens/discovery_feed_screen.dart`, `abe_app/lib/main.dart`, `abe_app/test/widget_test.dart` (Sub-task 8.1: Connected Stage 1 & 2 prototype navigation across Discovery Feed, Booking Detail, and Tech Portfolio Upload)
- `abe_app/lib/features/booking/presentation/screens/visual_contract_detail_screen.dart`, `abe_app/lib/features/portfolio/presentation/screens/tech_portfolio_upload_screen.dart` (Sub-task 8.2: Audited with `abe-design-agent` and `flutter_a11y_agent`, applied 48x48dp touch targets and liveRegion accessibility refinements)
- `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, `founder-hub/js/sync.js` (Sub-task 8.3: Marked Item 8 completed for Rio and delegated Background Tasks 2A & 2B)
- `abe_app/lib/features/portfolio/domain/utils/portfolio_image_crop_helper.dart` (Background Task 2A: Deterministic 4:5 aspect-ratio cropping and compression metadata helper `PortfolioImageCropHelper` and `CroppedPortfolioImageSpec`)
- `abe_app/test/stage_2_offload_crop_and_calculator_edge_cases_test.dart` (Background Task 2B: Comprehensive edge-case unit tests for 4:5 image cropping, multi-modifier combinations, voucher discount bounds, XSS sanitisation, and ZAR currency formatting)

---

## Background Subagent Offload Queue (Stage 2)
*(Executed automatically in the background via `invoke_subagent` inside Antigravity)*
- **Background Task 2A:** Add client-side image aspect-ratio cropping (`4:5`) and compression helper for `TechPortfolioUploadScreen`.
- **Background Task 2B:** Write edge-case unit tests for multi-modifier combinations, voucher discount bounds, and currency formatting (`R1,250`).
