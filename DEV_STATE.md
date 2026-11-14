# DEV_STATE.md: Living Technical State & Multi-Chat Handoff

> **Purpose:** Every coding chat (`Chat 1` through `Chat 5`) and all Antigravity background subagents read this file first to see what has already been built and update this file whenever a Roadmap Item is completed.

---

## 1. Current Overall Build Status
- **Active Stage:** Stage 4 Completed (Ready for Stage 5: `chats/CHAT_5_PAYMENTS_LAUNCH.md`)
- **Active Chat File:** `chats/CHAT_4_SECURITY_WALLET.md` (All Stage 4 sub-tasks `12.1` to `15.4` completed)
- **Next Sub-Task to Execute:** `Sub-task 16.1` in `chats/CHAT_5_PAYMENTS_LAUNCH.md`
- **Completed Roadmap Items (Rio's Track):** `Item 1` through `Item 15` (`15 / 18` completed)

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
- [x] **Item 1:** Flutter & Backend Workspace Initialisation (`abe_app/`, `BrandConfig`, `AbeTheme`, `UacPermissionMatrix`, `FeatureFlagsService`)
- [x] **Item 2:** Core Database Schemas & Security Rules (`AbeUser`, `UacGroup`, `TechProfile`, `CommercialVenue`, `VisualContractItem`, `VoucherCode`, `StoreProduct`, `StoreOrder`, `DisputeTicket`, `StaffAuditLog`, `InputSanitiser`, `firestore.rules`)
- [x] **Item 3:** Auth Screens & Role Onboarding (`WelcomeAuthScreen`, `RoleCityOnboardingScreen` for `CPT` and `JHB`)
- [x] **Item 4:** Signature Visual Contract Card UI (`VisualContractCard` + widget tests)
- [x] **Item 5:** Visual Contract Discovery Feed (`DiscoveryFeedScreen` with `CPT`/`JHB`, Tier Badge, and Price Range filters + `DiscoveryFeedSkeletonCard`)
- [x] **Item 6:** Booking Screen & Dynamic Modifier Calculator (`BookingModifier`, `BookingPriceQuote`, `BookingCalculatorService`, `VisualContractDetailScreen`)
- [x] **Item 7:** Tech Portfolio Upload Flow (`TechPortfolioUploadScreen`, `VisualContractRepository`)
- [x] **Item 8:** Stage 1 & 2 Prototype Review Refinements (`AbeApp` unified prototype navigation, `abe-design-agent` & `flutter_a11y_agent` audit refinements)
- [x] **Item 9:** Tech Availability Calendar & Slot Engine (`SlotGeneratorService`, `TechCalendarSetupScreen`, `ClientSlotPickerSheet`)
- [x] **Item 10:** Strict Venue-Only Booking Lock (Zero House Calls) (`VenueSelectionService`, `BookingVenueSelection`, `VenueConfirmationCard`, hardened `firestore.rules`)
- [x] **Item 11:** Grading & Tier Badge Engine (`TierProgressionService`, `NailTechDashboardScreen`, `TechDashboardSnapshot`)
- [x] **Item 12:** Biometric + 4-Digit Randomised PIN Start Lock (`AppointmentStartLockService`, `TechStartAppointmentScreen`, `firestore.rules`)
- [x] **Item 13:** In-App Live Completion Camera Lock (`AppointmentCompletionLockService`, `OfflineEncryptedPhotoQueue`, `TechCompleteAppointmentScreen`)
- [x] **Item 14:** Closed-Loop Wallet & 75/25 Cancellation Split (`WalletAndLedgerService`, `CouponVoucherService`, `ClientWalletScreen`, `TechEarningsScreen`)
- [x] **Item 15:** 3-Photo Dispute View & Empty Chair Salon Portal (`MasterAdminCommandCentreScreen`, `DisputeSupportQueueScreen`, `StockUpStoreAndWarehouseScreen`, `SalonPartnerPortalScreen`)
- [ ] **Item 16:** South African Payment Gateways (Paystack/Peach + PayJustNow)
- [ ] **Item 17:** Full Security Audit & End-to-End QA
- [ ] **Item 18:** Production Deployment (CPT & JHB Launch)
