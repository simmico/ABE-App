---
name: abe-security-auditor
description: >-
  Audits and enforces Aqeelah's Beauty Empire (ABE) security invariants:
  Closed-Loop Wallet protection, Strict Venue-Only bookings (no house calls),
  4-Digit PIN + Biometric start lock, Live Camera completion lock, and 75/25 cancellation splits.
---

# ABE Security & Anti-Fraud Auditor Skill

Use this skill alongside `firestore-rules-author` and `firebase-security-rules-auditor` whenever creating or reviewing database schemas, backend functions, authentication, booking flows, or wallet logic.

---

## Mandatory Security Audit Checklist (Red-Team Every Change)

### 1. Closed-Loop Wallet & Ledger Protection
- **No Client-Side Balance Writes:** Client SDKs (`client`, `tech`, `salon_partner`) must have `allow write: if false;` on `wallets`, `ledger_entries`, and `payouts` collections. All balance mutations must execute inside trusted server-side Cloud Functions / backend transactions.
- **No Customer Cash Withdrawal:** Verify there is no API route or function that allows a `client` role to withdraw wallet funds to a bank account. Client refunds go strictly to `clientWalletBalance`.
- **Double-Entry Integrity:** Every booking payment, 15% platform fee deduction, and 75%/25% late-cancellation split must write an immutable audit log entry in `ledger_entries`.

### 2. Strict Venue-Only Enforcement (Zero House Calls)
- **Schema Validation:** Every booking document must contain `venueType` (`'verified_studio'` or `'partner_salon_chair'`) and a valid, verified `venueId`.
- **Reject Residential Addresses:** Any booking creation request without a verified commercial `venueId` (or attempting to pass a free-text customer home address) must be rejected at both the API layer and database security rule layer.

### 3. Appointment Start Lock (Biometric + Randomised 4-Digit PIN)
- **PIN Secrecy:** The 4-digit booking PIN must be stored in a restricted sub-document or field readable **only** by the `client` who owns the booking, never readable by the `tech` via client-side queries.
- **Server-Side Verification:** To transition a booking from `confirmed` to `in_progress`, the tech submits the 4-digit PIN and biometric confirmation token to a server-side function, which verifies the PIN match and records `startedAt`.

### 4. Appointment Completion Lock (Live Camera Only)
- **Gallery Upload Prevention:** In the Flutter app, the completion photo picker must hard-code `ImageSource.camera` with no gallery fallback.
- **Server Check:** A booking cannot transition from `in_progress` to `completed` unless `completionPhotoUrl` (uploaded during the active appointment window) is present.
