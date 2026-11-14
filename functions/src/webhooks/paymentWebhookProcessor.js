import crypto from 'node:crypto';
import {
  sanitiseFirestoreId,
  sanitiseSingleLine,
  stripPrototypeKeys,
  validateCommercialVenue,
  validateLaunchCity,
} from '../security/sanitiser.js';
import { verifyGatewayWebhookSignature } from './signatureVerifier.js';

/**
 * Idempotent South African payment webhook processor.
 *
 * Verifies cryptographic signatures, enforces positive ZAR amounts,
 * Strict Venue-Only checks, pending_payment -> confirmed state guards,
 * generates a CSPRNG 4-digit client-only PIN, appends an immutable
 * double-entry ledger record, and triggers notifications.
 */
export class PaymentWebhookProcessor {
  constructor({ store, notificationDispatcher, secrets, pinGenerator } = {}) {
    this.store = store || new InMemoryWebhookStore();
    this.notificationDispatcher = notificationDispatcher;
    this.secrets = secrets || {};
    this.pinGenerator = pinGenerator || (() => String(crypto.randomInt(1000, 10000)));
  }

  async processWebhook({ provider, rawBody, signatureHeader }) {
    const cleanProvider = sanitiseSingleLine(provider, 32).toLowerCase();
    const secret = this.secrets[cleanProvider];

    const signatureValid = verifyGatewayWebhookSignature({
      provider: cleanProvider,
      rawBody,
      signatureHeader,
      secret,
    });
    if (!signatureValid) {
      const error = new Error(`Invalid ${cleanProvider} webhook signature.`);
      error.statusCode = 401;
      throw error;
    }

    const rawText = Buffer.isBuffer(rawBody) ? rawBody.toString('utf8') : String(rawBody || '');
    const parsed = stripPrototypeKeys(JSON.parse(rawText));
    const normalised = normaliseGatewayPayload(cleanProvider, parsed);

    if (!normalised.isPaidEvent) {
      return {
        status: 'ignored_non_settlement_event',
        provider: cleanProvider,
        eventType: normalised.eventType,
      };
    }

    if (normalised.currency !== 'ZAR') {
      throw new Error(`Unsupported currency "${normalised.currency}". ABE settles strictly in ZAR.`);
    }

    if (!Number.isInteger(normalised.amountPaidCents) || normalised.amountPaidCents <= 0) {
      throw new Error('Settlement amountPaidCents must be a positive integer.');
    }

    const dedupeKey = sanitiseFirestoreId(
      `${cleanProvider}_${normalised.idempotencyKey}`,
      'dedupeKey'
    );
    const existingWebhook = await this.store.getProcessedWebhook(dedupeKey);
    if (existingWebhook) {
      return {
        status: 'already_processed',
        idempotentReplay: true,
        bookingId: existingWebhook.bookingId,
        reference: existingWebhook.reference,
      };
    }

    const booking = await this.store.getBooking(normalised.bookingId);
    if (!booking) {
      const error = new Error(`Booking ${normalised.bookingId} not found.`);
      error.statusCode = 404;
      throw error;
    }

    if (booking.status !== 'pending_payment') {
      return {
        status: 'already_processed',
        idempotentReplay: true,
        bookingId: booking.id,
        reference: booking.paymentReference || normalised.reference,
      };
    }

    // Strict Venue-Only Policy verification
    const venueCheck = validateCommercialVenue({
      venueType: booking.venueType,
      venueId: booking.venueId,
      venueAddress: booking.venueAddress || '',
    });
    validateLaunchCity(booking.city);

    if (typeof this.store.verifyCommercialVenueExists === 'function') {
      const venueVerified = await this.store.verifyCommercialVenueExists(venueCheck.venueId);
      if (!venueVerified) {
        throw new Error('Strict Venue-Only Policy: referenced commercial venue is not verified.');
      }
    }

    const expectedDueCents =
      typeof booking.expectedGatewayDueCents === 'number'
        ? Math.round(booking.expectedGatewayDueCents)
        : Math.round(Number(booking.totalPriceZar || 0) * 100);

    if (!Number.isFinite(expectedDueCents) || expectedDueCents <= 0) {
      throw new Error(`Booking ${booking.id} is missing a valid positive expected ZAR amount.`);
    }

    if (normalised.amountPaidCents !== expectedDueCents) {
      throw new Error(
        `Amount mismatch for booking ${booking.id}: expected ${expectedDueCents} cents, got ${normalised.amountPaidCents} cents.`
      );
    }

    const pinCode = this.pinGenerator();
    if (!/^\d{4}$/.test(pinCode)) {
      throw new Error('Generated booking PIN must be exactly 4 digits.');
    }

    const nowIso = new Date().toISOString();
    const commitOutcome = await this.store.commitConfirmedBooking({
      dedupeKey,
      bookingId: booking.id,
      clientId: booking.clientId,
      techId: booking.techId,
      provider: cleanProvider,
      reference: normalised.reference,
      amountPaidCents: normalised.amountPaidCents,
      pinCode,
      nowIso,
    });

    if (commitOutcome && commitOutcome.idempotentReplay) {
      return {
        status: 'already_processed',
        idempotentReplay: true,
        bookingId: booking.id,
        reference: normalised.reference,
      };
    }

    let notificationResult = null;
    if (this.notificationDispatcher) {
      notificationResult = await this.notificationDispatcher.sendBookingConfirmedNotifications({
        bookingId: booking.id,
        clientId: booking.clientId,
        clientName: booking.clientName,
        clientEmail: booking.clientEmail,
        clientPhone: booking.clientPhone,
        techId: booking.techId,
        techName: booking.techName,
        venueName: booking.venueName,
        venueAddress: booking.venueAddress,
        city: booking.city,
        scheduledAtIso: booking.scheduledAtIso,
        amountPaidZarCents: normalised.amountPaidCents,
        clientBookingPin: pinCode,
      });
    }

    return {
      status: 'confirmed',
      idempotentReplay: false,
      provider: cleanProvider,
      bookingId: booking.id,
      reference: normalised.reference,
      amountPaidCents: normalised.amountPaidCents,
      pinGenerated: true,
      notificationsDispatched: notificationResult ? notificationResult.dispatched.length : 0,
    };
  }
}

export function normaliseGatewayPayload(provider, body) {
  if (!body || typeof body !== 'object') {
    throw new Error('Malformed webhook JSON payload.');
  }

  if (provider === 'paystack') {
    const event = sanitiseSingleLine(String(body.event || ''), 64);
    const data = body.data || {};
    const meta = data.metadata || {};
    const isPaidEvent = event === 'charge.success' && data.status === 'success';
    if (!isPaidEvent) {
      return { eventType: event, isPaidEvent: false };
    }
    const reference = sanitiseFirestoreId(String(data.reference || ''), 'reference');
    const bookingId = sanitiseFirestoreId(String(meta.bookingId || ''), 'bookingId');
    const idempotencyKey = sanitiseFirestoreId(
      String(meta.idempotencyKey || reference),
      'idempotencyKey'
    );
    return {
      eventType: event,
      isPaidEvent: true,
      reference,
      bookingId,
      idempotencyKey,
      amountPaidCents: Math.round(Number(data.amount || 0)),
      currency: sanitiseSingleLine(String(data.currency || 'ZAR'), 8).toUpperCase(),
    };
  }

  if (provider === 'peach_payments') {
    const resultCode = String(body.result?.code || '');
    const isSuccess = /^000\.(000|100)\./.test(resultCode) || body.status === 'succeeded';
    const eventType = sanitiseSingleLine(String(body.type || 'payment'), 64);
    if (!isSuccess) {
      return { eventType, isPaidEvent: false };
    }
    const custom = body.customParameters || {};
    const reference = sanitiseFirestoreId(
      String(body.merchantTransactionId || body.id || ''),
      'reference'
    );
    const bookingId = sanitiseFirestoreId(String(custom.bookingId || ''), 'bookingId');
    const idempotencyKey = sanitiseFirestoreId(
      String(custom.idempotencyKey || reference),
      'idempotencyKey'
    );
    const amountCents = Math.round(Number(body.amount || 0) * 100);
    return {
      eventType,
      isPaidEvent: true,
      reference,
      bookingId,
      idempotencyKey,
      amountPaidCents: amountCents,
      currency: sanitiseSingleLine(String(body.currency || 'ZAR'), 8).toUpperCase(),
    };
  }

  if (provider === 'payjustnow') {
    const status = sanitiseSingleLine(String(body.status || ''), 40).toUpperCase();
    const isSuccess = status === 'APPROVED' || status === 'PAID' || status === 'SETTLED';
    const eventType = sanitiseSingleLine(String(body.event || status), 64);
    if (!isSuccess) {
      return { eventType, isPaidEvent: false };
    }
    const reference = sanitiseFirestoreId(
      String(body.merchantReference || body.orderToken || ''),
      'reference'
    );
    const bookingId = sanitiseFirestoreId(
      String(body.bookingId || body.metadata?.bookingId || ''),
      'bookingId'
    );
    const idempotencyKey = sanitiseFirestoreId(
      String(body.idempotencyKey || reference),
      'idempotencyKey'
    );
    return {
      eventType,
      isPaidEvent: true,
      reference,
      bookingId,
      idempotencyKey,
      amountPaidCents: Math.round(Number(body.amountCents || 0)),
      currency: sanitiseSingleLine(String(body.currency || 'ZAR'), 8).toUpperCase(),
    };
  }

  throw new Error(`Unsupported payment webhook provider: ${provider}`);
}

export class InMemoryWebhookStore {
  constructor(seedBookings = []) {
    this.bookings = new Map();
    this.bookingPins = new Map();
    this.processedWebhooks = new Map();
    this.ledgerEntries = [];
    for (const b of seedBookings) {
      this.bookings.set(b.id, { ...b });
    }
  }

  async getProcessedWebhook(dedupeKey) {
    return this.processedWebhooks.get(dedupeKey) || null;
  }

  async getBooking(bookingId) {
    return this.bookings.get(bookingId) || null;
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
    if (this.processedWebhooks.has(dedupeKey)) {
      return { idempotentReplay: true };
    }
    const existing = this.bookings.get(bookingId);
    if (!existing) {
      throw new Error(`Booking ${bookingId} missing during transaction commit.`);
    }
    if (existing.status !== 'pending_payment') {
      return { idempotentReplay: true };
    }

    this.bookings.set(bookingId, {
      ...existing,
      status: 'confirmed',
      paymentProvider: provider,
      paymentReference: reference,
      confirmedAtIso: nowIso,
    });

    this.bookingPins.set(bookingId, {
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

    this.ledgerEntries.push({
      id: `led_wh_${this.ledgerEntries.length + 1}`,
      idempotencyKey: dedupeKey,
      userId: clientId,
      entryType: 'booking_gross_payment',
      amountZarCents: amountPaidCents,
      direction: 'credit',
      description: `Upfront ${provider} ZAR payment confirmed (${reference})`,
      bookingId,
      createdAtIso: nowIso,
    });

    this.processedWebhooks.set(dedupeKey, {
      dedupeKey,
      bookingId,
      reference,
      provider,
      amountPaidCents,
      processedAtIso: nowIso,
    });
    return { idempotentReplay: false };
  }
}
