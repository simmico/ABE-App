---
name: abe-security-auditor
description: >-
  Audits and enforces Aqeelah's Beauty Empire (ABE) security invariants:
  Dynamic UAC Groups & Permission Matrix, XSS/Injection/CSP hardening,
  Rate-Limiting & App Check, Closed-Loop Wallet protection, Strict Venue-Only bookings,
  4-Digit PIN + Biometric start lock, Live Camera completion lock, and Idempotent payments.
---

# ABE Security & Anti-Fraud Auditor Skill

Use this skill alongside `firestore-rules-author` and `firebase-security-rules-auditor` whenever creating or reviewing database schemas, backend functions, authentication, UAC permissions, web forms, booking flows, or wallet logic.

---

## Mandatory Security Audit Checklist (Red-Team Every Change)

### 1. Dynamic UAC Groups & Permission Matrix (`uac_groups` & `audit_logs`)
- **Granular Permission Checks:** Do not rely on a flat `"admin"` boolean. Enforce permission keys from the user's assigned UAC group (`super_admin`, `ops_admin`, `support_agent`, `supplier_partner`, `salon_partner`, `tech`, `client`), such as:
  - `disputes.view`, `disputes.resolve`, `wallet.credit_client`, `techs.approve`, `techs.award_pro`, `vouchers.manage`, `store.manage_inventory`, `store.fulfil_orders`, `uac.manage_roles`, `ledger.export`.
- **Instant Revocation:** When an admin revokes a user's UAC group or sets `isActive: false` in the Admin Dashboard, database rules and backend middleware must immediately block that user's token from reading or writing protected collections.
- **Immutable Staff Audit Log:** Every admin, support, or supplier action must write an immutable record to `staff_audit_logs` (`actorId`, `action`, `targetId`, `timestamp`).

### 2. Web, API & App Hardening (XSS, Injection, App Check & Rate Limiting)
- **XSS & HTML Sanitisation:** Strip/escape all HTML and script tags on every user-supplied string (bios, notes, dispute messages, salon descriptions, voucher codes). Configure strict `Content-Security-Policy` (CSP), `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, and `Referrer-Policy` headers on web endpoints.
- **NoSQL / Schema Injection Prevention:** Validate all payloads against strict schema types (rejecting unexpected keys, prototype pollution, or negative numeric values on prices, durations, modifier costs, or voucher discounts).
- **Brute-Force & Rate Limiting:**
  - **4-Digit PIN Lockout:** Maximum 5 failed PIN attempts on a booking locks PIN entry for 15 minutes and flags the booking for support review.
  - **Voucher Code Throttling:** Rate-limit voucher validation calls per user/IP to prevent promo-code enumeration.
  - **Firebase App Check:** Enforce App Check attestation across mobile and web clients.

### 3. Closed-Loop Wallet, Idempotency & Ledger Protection
- **No Client-Side Balance Writes:** Client SDKs (`client`, `tech`, `salon_partner`, `supplier_partner`) must have `allow write: if false;` on `wallets`, `financial_ledger`, and `payouts`.
- **Idempotency Keys:** Every payment webhook, wallet credit, cancellation split, and tech instant cash-out must require a unique `idempotencyKey` so duplicate network requests can never double-credit or double-payout.
- **No Customer Cash Withdrawal:** Verify there is no API route or function that allows a `client` role to withdraw wallet funds to a bank account.

### 4. Strict Venue-Only Enforcement (Zero House Calls)
- **Schema Validation:** Every booking document must contain `venueType` (`'verified_studio'` or `'partner_salon_chair'`) and a valid, verified commercial `venueId`. Reject any residential address.

### 5. Appointment Start & Completion Locks
- **PIN Secrecy:** The 4-digit booking PIN is readable **only** by the `client` who owns the booking, never readable by the `tech` via client-side queries.
- **Live Camera Only:** Completion photos must originate strictly from `ImageSource.camera` (gallery picker disabled) and be uploaded before a booking can transition to `completed`.
