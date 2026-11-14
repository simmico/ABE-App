# CHAT 5: Stage 5 (Public Marketing Website, SA Payment Gateways, Full OWASP Security Audit & Launch)

> **MANDATORY INSTRUCTIONS TO AGENT:**
> 1. You are **Chat 5 (Stage 5 Public Website, Payments, Audit & Launch Builder)**. Read `AGENTS.md`, `PROJECT_CONTEXT.md`, and `DEV_STATE.md` immediately.
> 2. **Stay strictly within Stage 5 (Roadmap Items 16 to 18).**
> 3. **Crash-Proof Checkpoint Rule:** Immediately after completing EVERY sub-task below (`16.1`, `16.2`, etc.), you MUST edit this file (`chats/CHAT_5_PAYMENTS_LAUNCH.md`) to mark `[x]`, update `## Current Checkpoint`, and list all created/modified files under `## Completed Files & Architecture Log`.
> 4. **Founder Hub Live JSON Update Rule:** Whenever all sub-tasks for a full Roadmap Item (`Item 16`, `Item 17`, `Item 18`) are completed, follow `.agents/skills/abe-state-handoff/SKILL.md` to set `"completed": true` for Rio (`tech`) in `founder-hub/data/roadmap.json` AND `founder-hub/js/sync.js`, and push `founder-hub` to GitHub!

---

## Current Checkpoint
- **Next Sub-Task to Execute:** None (Stage 5 and all `18 / 18` Engineering Roadmap items completed).
- **Last Completed Sub-Task:** `Sub-task 18.2` (Final `dart analyze` clean, `141/141` Flutter tests, `4/4` Cloud Functions tests, `2/2` Public Site tests passing; `Item 18` marked completed for Rio across `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, with both `founder-hub` and root repository pushed to GitHub).

---

## Mandatory Specialist Agents & Skills to Activate on Turn 1
1. **Security, OWASP & Webhook Auditor:** Read `.agents/skills/abe-security-auditor/SKILL.md` and `firebase-security-rules-auditor`. Spawn `abe-security-agent` and `firestore-rules-author` to verify cryptographic webhook signature validation, strict `Content-Security-Policy` (CSP) / XSS / CSRF / Injection protection on the Public Website and App, POPIA privacy compliance, and Firebase App Check enforcement.
2. **UI & Accessibility Polish:** Spawn `abe-design-agent` and `flutter_a11y_agent` to design the Public Website and do a final visual pass across every app and dashboard screen.

---

## Granular Sub-Task Checkpoints (Stage 5: Items 16 to 18)

### Roadmap Item 16: South African Payment Gateways, Public Website & Profile Seeding
- [x] **Sub-task 16.1:** Build the Checkout & Payment Service (`lib/features/payment/`) integrating:
  - **Paystack / Peach Payments** (Card tokenisation + Instant EFT in ZAR),
  - **PayJustNow BNPL** (Buy-Now-Pay-Later checkout flow),
  - Automatic application of any available Client ABE Wallet balance or promo voucher before charging the remainder.
- [x] **Sub-task 16.2:** Build the secure backend webhook & notification handlers (`functions/`) verifying cryptographic payment signatures and idempotency keys before marking a booking `confirmed`, generating the client's 4-digit PIN, and sending automated appointment reminders (Push / WhatsApp / Email).
- [x] **Sub-task 16.3:** Build the fast, SEO-ready, XSS/CSP-hardened **Public Marketing & Onboarding Website** (`public-site/`) connected to the shared backend:
  - Live CPT & JHB Visual Contract Showcase,
  - **"Apply as a Founding Nail Tech"** & **"List Your Salon's Empty Chairs"** web onboarding forms (with input sanitisation and rate limiting),
  - Client Waitlist / Voucher Claim & iOS/Android App Download page, plus the Admin Quick Profile Seeder tool.
- [x] **Sub-task 16.4:** Mark **Item 16 (`item_16`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, and push `founder-hub` to GitHub.

### Roadmap Item 17: Full OWASP / XSS / Injection Security Audit & End-to-End Bug Bash
- [x] **Sub-task 17.1:** Run a full red-team security audit using `firebase-security-rules-auditor` and `abe-security-auditor` verifying:
  - Dynamic UAC Group permissions and instant access revocation,
  - XSS, HTML injection, and NoSQL schema validation across all forms and endpoints,
  - Closed-Loop Wallet protection (zero cash withdrawal routes, idempotent ledger writes),
  - 4-Digit PIN brute-force lockout and strict commercial-venue-only enforcement.
- [x] **Sub-task 17.2:** Write end-to-end integration tests (`flutter-add-integration-test`) covering the complete lifecycle: Discovery -> Modifier & Voucher Toggle -> Venue Check -> Upfront Payment -> 4-Digit PIN Start -> Live Camera Completion -> Tech Ledger Credit -> Stock-Up Store Order -> 75/25 Cancellation Split.
- [x] **Sub-task 17.3:** Mark **Item 17 (`item_17`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, and push `founder-hub` to GitHub.

### Roadmap Item 18: Production Deployment & CPT/JHB Soft Launch
- [x] **Sub-task 18.1:** Configure production build flavors, Firebase App Check, Remote Config feature flags, app icons, splash screens, and release signing for iOS, Android, the Web Dashboards, and the Public Website.
- [x] **Sub-task 18.2:** Run final `dart analyze` and `flutter test` with zero warnings, mark **Item 18 (`item_18`)** completed for Rio (`tech.completed = true`) in `DEV_STATE.md`, `ROADMAP_TECH.md`, `founder-hub/data/roadmap.json`, and `founder-hub/js/sync.js`, and push both `founder-hub` and the root repository to GitHub.

---

## Completed Files & Architecture Log
*(Agent must append every created/modified file path here after each sub-task)*
- `abe_app/lib/features/payment/domain/models/payment_models.dart`
- `abe_app/lib/features/payment/domain/services/payment_gateway_adapter.dart`
- `abe_app/lib/features/payment/domain/services/checkout_payment_service.dart`
- `abe_app/lib/features/payment/presentation/screens/checkout_payment_screen.dart`
- `abe_app/test/payment_checkout_test.dart`
- `functions/package.json`
- `functions/src/index.js`
- `functions/src/security/sanitiser.js`
- `functions/src/webhooks/signatureVerifier.js`
- `functions/src/webhooks/paymentWebhookProcessor.js`
- `functions/src/notifications/reminderDispatcher.js`
- `functions/src/publicApi/onboardingHandlers.js`
- `functions/test/functions.test.js`
- `public-site/index.html`
- `public-site/admin-seeder.html`
- `public-site/css/styles.css`
- `public-site/js/app.js`
- `public-site/_headers`
- `public-site/robots.txt`
- `public-site/sitemap.xml`
- `public-site/test/public_site.test.mjs`
- `firestore.rules` (security-hardened Stage 5 parity)
- `abe_app/firestore.rules` (SHA-256 synced Stage 5 parity)
- `abe_app/lib/core/theme/abe_theme.dart`
- `abe_app/lib/features/venue/domain/models/commercial_venue.dart`
- `abe_app/lib/features/portfolio/presentation/widgets/visual_contract_card.dart`
- `abe_app/lib/features/portfolio/presentation/screens/discovery_feed_screen.dart`
- `abe_app/lib/features/booking/presentation/screens/visual_contract_detail_screen.dart`
- `abe_app/lib/features/booking/presentation/screens/tech_start_appointment_screen.dart`
- `abe_app/test/widget_test.dart`
- `abe_app/test/venue_selection_and_card_test.dart`
- `abe_app/test/stage_3_offload_venue_security_test.dart`
- `abe_app/lib/features/wallet/domain/services/coupon_voucher_service.dart`
- `abe_app/pubspec.yaml`
- `abe_app/test/end_to_end_lifecycle_test.dart`
- `abe_app/integration_test/abe_end_to_end_lifecycle_test.dart`
- `abe_app/lib/core/config/app_environment.dart`
- `abe_app/lib/core/config/app_check_and_remote_config_service.dart`
- `abe_app/.env.example`
- `firebase.json`
- `firestore.indexes.json`
- `storage.rules`
- `abe_app/android/key.properties.example`
- `abe_app/android/app/build.gradle.kts`
- `abe_app/android/app/src/main/AndroidManifest.xml`
- `abe_app/android/app/src/main/res/values/colors.xml`
- `abe_app/android/app/src/main/res/values/styles.xml`
- `abe_app/android/app/src/main/res/values-night/styles.xml`
- `abe_app/android/app/src/main/res/drawable/abe_brand_emblem.xml`
- `abe_app/android/app/src/main/res/drawable/launch_background.xml`
- `abe_app/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- `abe_app/ios/Runner/Info.plist`
- `abe_app/ios/Runner/Base.lproj/LaunchScreen.storyboard`
- `abe_app/ios/ExportOptions.plist`
- `abe_app/web/index.html`
- `abe_app/web/manifest.json`
- `public-site/wrangler.toml`
- `abe_app/test/production_release_config_test.dart`
