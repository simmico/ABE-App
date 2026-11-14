import crypto from 'node:crypto';
import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

import { AppointmentNotificationDispatcher } from './notifications/reminderDispatcher.js';
import { PaymentWebhookProcessor } from './webhooks/paymentWebhookProcessor.js';
import { PublicOnboardingHandlers } from './publicApi/onboardingHandlers.js';
import { sanitiseSingleLine, stripPrototypeKeys } from './security/sanitiser.js';

if (getApps().length === 0) {
  initializeApp();
}

const PAYSTACK_WEBHOOK_SECRET = defineSecret('PAYSTACK_WEBHOOK_SECRET');
const PEACH_WEBHOOK_SECRET = defineSecret('PEACH_WEBHOOK_SECRET');
const PAYJUSTNOW_WEBHOOK_SECRET = defineSecret('PAYJUSTNOW_WEBHOOK_SECRET');

const SECURITY_HEADERS = {
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Cache-Control': 'no-store',
};

function applySecurityHeaders(res) {
  for (const [k, v] of Object.entries(SECURITY_HEADERS)) {
    res.setHeader(k, v);
  }
}

class FirestoreRateLimiter {
  constructor(db, { maxRequests = 6, windowMs = 60_000 } = {}) {
    this.db = db;
    this.maxRequests = maxRequests;
    this.windowMs = windowMs;
  }

  async checkAndRecord(actorKey) {
    const hash = crypto.createHash('sha256').update(String(actorKey)).digest('hex').slice(0, 32);
    const ref = this.db.collection('rate_limits').doc(hash);
    const now = Date.now();
    const cutoff = now - this.windowMs;

    return this.db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const timestamps = snap.exists ? (snap.data().timestamps || []) : [];
      const recent = timestamps.filter((ts) => typeof ts === 'number' && ts > cutoff);
      if (recent.length >= this.maxRequests) {
        return { allowed: false, remaining: 0 };
      }
      recent.push(now);
      tx.set(ref, { timestamps: recent, updatedAtMs: now });
      return { allowed: true, remaining: this.maxRequests - recent.length };
    });
  }
}

class FirestoreWebhookStore {
  constructor(db) {
    this.db = db;
  }

  async getProcessedWebhook(dedupeKey) {
    const snap = await this.db.collection('processed_webhooks').doc(dedupeKey).get();
    return snap.exists ? snap.data() : null;
  }

  async getBooking(bookingId) {
    const snap = await this.db.collection('bookings').doc(bookingId).get();
    return snap.exists ? { id: snap.id, ...snap.data() } : null;
  }

  async verifyCommercialVenueExists(venueId) {
    const venueSnap = await this.db.collection('commercial_venues').doc(venueId).get();
    if (venueSnap.exists && venueSnap.data().isVerified === true) {
      return true;
    }
    const partnerSnap = await this.db.collection('salon_partners').doc(venueId).get();
    return partnerSnap.exists && partnerSnap.data().isVerified === true;
  }

  async commitConfirmedBooking({
    dedupeKey,
    bookingId,
    clientId,
    techId,
    provider,
    reference,
    amountPaidCents,
    pinCode,
    nowIso,
  }) {
    return this.db.runTransaction(async (tx) => {
      const dedupeRef = this.db.collection('processed_webhooks').doc(dedupeKey);
      const dedupeSnap = await tx.get(dedupeRef);
      if (dedupeSnap.exists) {
        return { idempotentReplay: true };
      }

      const bookingRef = this.db.collection('bookings').doc(bookingId);
      const bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) {
        throw new Error(`Booking ${bookingId} missing during transaction commit.`);
      }
      if (bookingSnap.data().status !== 'pending_payment') {
        return { idempotentReplay: true };
      }

      const pinRef = this.db.collection('booking_pins').doc(bookingId);
      const ledgerRef = this.db.collection('financial_ledger').doc(`led_${dedupeKey}`);

      tx.update(bookingRef, {
        status: 'confirmed',
        paymentProvider: provider,
        paymentReference: reference,
        confirmedAtIso: nowIso,
      });

      tx.set(pinRef, {
        bookingId,
        clientId,
        techId,
        pinCode,
        failedAttempts: 0,
        supportAlertTriggered: false,
        biometricVerified: false,
        pinVerified: false,
        createdAtIso: nowIso,
      });

      tx.set(ledgerRef, {
        id: ledgerRef.id,
        idempotencyKey: dedupeKey,
        userId: clientId,
        entryType: 'booking_gross_payment',
        amountZarCents: amountPaidCents,
        amountZar: amountPaidCents / 100,
        direction: 'credit',
        description: `Upfront ${provider} ZAR payment confirmed (${reference})`,
        bookingId,
        createdAtIso: nowIso,
      });

      tx.set(dedupeRef, {
        dedupeKey,
        bookingId,
        reference,
        provider,
        amountPaidCents,
        processedAtIso: nowIso,
      });
      return { idempotentReplay: false };
    });
  }
}

class FirestoreNotificationTransport {
  constructor(db) {
    this.db = db;
  }

  async sendImmediate(message) {
    const ref = this.db.collection('notification_outbox').doc();
    const record = { id: ref.id, ...message, sentAtIso: new Date().toISOString() };
    await ref.set(record);
    return record;
  }

  async scheduleReminder(reminder) {
    const ref = this.db.collection('scheduled_reminders').doc(reminder.id);
    await ref.set(reminder, { merge: true });
    return reminder;
  }
}

class FirestoreOnboardingStore {
  constructor(db) {
    this.db = db;
  }

  async verifyCommercialVenueExists(venueId) {
    const venueSnap = await this.db.collection('commercial_venues').doc(venueId).get();
    if (venueSnap.exists && venueSnap.data().isVerified === true) {
      return true;
    }
    const partnerSnap = await this.db.collection('salon_partners').doc(venueId).get();
    return partnerSnap.exists && partnerSnap.data().isVerified === true;
  }

  async saveTechApplication(record) {
    await this.db.collection('tech_onboarding_applications').doc(record.id).set(record);
  }

  async saveSalonApplication(record) {
    await this.db.collection('salon_partner_applications').doc(record.id).set(record);
  }

  async saveWaitlistEntry(record) {
    await this.db.collection('client_waitlist').doc(record.id).set(record);
  }

  async saveSeededProfile(profile, auditLog) {
    const batch = this.db.batch();
    batch.set(this.db.collection('visual_contract_items').doc(profile.id), profile);
    batch.set(this.db.collection('staff_audit_logs').doc(auditLog.id), auditLog);
    await batch.commit();
  }
}

function buildWebhookHandler(provider, secretParam, signatureHeaderName) {
  return onRequest(
    { region: 'africa-south1', secrets: [secretParam] },
    async (req, res) => {
      applySecurityHeaders(res);
      if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method Not Allowed' });
        return;
      }
      if (!Buffer.isBuffer(req.rawBody)) {
        res.status(400).json({ error: 'Missing raw webhook request buffer.' });
        return;
      }

      const db = getFirestore();
      const processor = new PaymentWebhookProcessor({
        store: new FirestoreWebhookStore(db),
        notificationDispatcher: new AppointmentNotificationDispatcher({
          transport: new FirestoreNotificationTransport(db),
        }),
        secrets: {
          [provider]: secretParam.value(),
        },
      });

      try {
        const result = await processor.processWebhook({
          provider,
          rawBody: req.rawBody,
          signatureHeader: req.get(signatureHeaderName),
        });
        res.status(200).json(result);
      } catch (err) {
        const code = err.statusCode || 400;
        if (code === 401) {
          res.status(401).json({ error: 'Unauthorized webhook signature.' });
          return;
        }
        if (code >= 500) {
          res.status(500).json({ error: 'Webhook processing failed.' });
          return;
        }
        res.status(code).json({ error: sanitiseSingleLine(err.message, 200) });
      }
    }
  );
}

export const paystackWebhook = buildWebhookHandler(
  'paystack',
  PAYSTACK_WEBHOOK_SECRET,
  'x-paystack-signature'
);

export const peachWebhook = buildWebhookHandler(
  'peach_payments',
  PEACH_WEBHOOK_SECRET,
  'x-peach-signature'
);

export const payJustNowWebhook = buildWebhookHandler(
  'payjustnow',
  PAYJUSTNOW_WEBHOOK_SECRET,
  'x-payjustnow-signature'
);

function buildPublicOnboardingEndpoint(handlerMethod, extraResponseFields = () => ({})) {
  return onRequest(
    { region: 'africa-south1', cors: ['https://abe.co.za', 'https://www.abe.co.za'] },
    async (req, res) => {
      applySecurityHeaders(res);
      if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method Not Allowed' });
        return;
      }

      const db = getFirestore();
      const handlers = new PublicOnboardingHandlers({
        store: new FirestoreOnboardingStore(db),
        rateLimiter: new FirestoreRateLimiter(db, { maxRequests: 6, windowMs: 60_000 }),
      });

      const forwardedFor = req.get('x-forwarded-for');
      const actorIp = forwardedFor ? forwardedFor.split(',')[0].trim() : req.ip || 'unknown';

      try {
        const cleanBody = stripPrototypeKeys(req.body);
        const record = await handlers[handlerMethod]({
          payload: cleanBody,
          actorKey: actorIp,
        });
        res.status(201).json({ ok: true, id: record.id, ...extraResponseFields(record) });
      } catch (err) {
        res.status(err.statusCode || 400).json({ error: sanitiseSingleLine(err.message, 200) });
      }
    }
  );
}

export const submitTechApplication = buildPublicOnboardingEndpoint('submitFoundingTechApplication');
export const submitSalonApplication = buildPublicOnboardingEndpoint('submitSalonEmptyChairApplication');
export const submitWaitlistClaim = buildPublicOnboardingEndpoint(
  'submitClientWaitlistClaim',
  (record) => ({ voucherCode: record.voucherCodeIssued })
);

export const adminSeedFoundingProfile = onCall(
  { region: 'africa-south1', enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    const db = getFirestore();
    const userSnap = await db.collection('users').doc(request.auth.uid).get();
    if (!userSnap.exists) {
      throw new HttpsError('permission-denied', 'User record missing.');
    }
    const userData = userSnap.data() || {};
    let groupPerms = [];
    if (typeof userData.uacGroupId === 'string' && userData.uacGroupId.trim().length > 0) {
      const groupSnap = await db.collection('uac_groups').doc(userData.uacGroupId).get();
      if (groupSnap.exists && groupSnap.data().isActive) {
        groupPerms = groupSnap.data().permissions || [];
      }
    }
    const effectivePerms = Array.from(new Set([...(userData.permissions || []), ...groupPerms]));

    const handlers = new PublicOnboardingHandlers({
      store: new FirestoreOnboardingStore(db),
    });
    try {
      const cleanPayload = stripPrototypeKeys(request.data);
      return await handlers.adminSeedFoundingProfile({
        actor: {
          uid: request.auth.uid,
          uacGroupId: userData.uacGroupId || '',
          isActive: Boolean(userData.isActive),
          permissions: effectivePerms,
        },
        payload: cleanPayload,
      });
    } catch (err) {
      throw new HttpsError(
        err.statusCode === 403 ? 'permission-denied' : 'invalid-argument',
        sanitiseSingleLine(err.message, 200)
      );
    }
  }
);
