import test from 'node:test';
import assert from 'node:assert/strict';

import {
  computeHmacSignature,
  verifyPaystackSignature,
  verifyPeachSignature,
  verifyPayJustNowSignature,
} from '../src/webhooks/signatureVerifier.js';
import {
  InMemoryWebhookStore,
  PaymentWebhookProcessor,
} from '../src/webhooks/paymentWebhookProcessor.js';
import {
  AppointmentNotificationDispatcher,
  InMemoryNotificationTransport,
} from '../src/notifications/reminderDispatcher.js';
import {
  InMemoryOnboardingStore,
  PublicOnboardingHandlers,
} from '../src/publicApi/onboardingHandlers.js';
import { SlidingWindowRateLimiter, sanitiseText } from '../src/security/sanitiser.js';

const SECRETS = {
  paystack: 'whsec_test_paystack_za_secret_12345',
  peach_payments: 'whsec_test_peach_za_secret_67890',
  payjustnow: 'whsec_test_pjn_za_secret_abcde',
};

function seedBooking(overrides = {}) {
  return {
    id: 'bk_za_1001',
    clientId: 'client_zara',
    clientName: 'Zara Daniels',
    clientEmail: 'zara@abe.co.za',
    clientPhone: '+27821234567',
    techId: 'tech_nadia',
    techName: 'Nadia Jacobs',
    venueType: 'verified_studio',
    venueId: 'venue_cpt_seapoint_01',
    venueName: 'Atelier Rose Studio, Sea Point',
    venueAddress: '118 Regent Road, Sea Point, Cape Town',
    city: 'CPT',
    scheduledAtIso: '2026-12-01T10:00:00.000Z',
    expectedGatewayDueCents: 35000,
    status: 'pending_payment',
    ...overrides,
  };
}

test('Cryptographic webhook signature verification rejects tampered bodies and invalid secrets', () => {
  const rawBody = JSON.stringify({ event: 'charge.success', data: { amount: 35000 } });
  const psSig = computeHmacSignature('sha512', rawBody, SECRETS.paystack);
  assert.equal(verifyPaystackSignature(rawBody, psSig, SECRETS.paystack), true);
  assert.equal(verifyPaystackSignature(rawBody + ' ', psSig, SECRETS.paystack), false);
  assert.equal(verifyPaystackSignature(rawBody, 'deadbeef', SECRETS.paystack), false);

  const peachSig = computeHmacSignature('sha256', rawBody, SECRETS.peach_payments);
  assert.equal(verifyPeachSignature(rawBody, peachSig, SECRETS.peach_payments), true);
  assert.equal(verifyPeachSignature(rawBody, peachSig, 'wrong_secret'), false);

  const pjnSig = computeHmacSignature('sha256', rawBody, SECRETS.payjustnow);
  assert.equal(verifyPayJustNowSignature(rawBody, pjnSig, SECRETS.payjustnow), true);
});

test('PaymentWebhookProcessor confirms booking idempotently, generates client-only 4-digit PIN, and sends Push/WhatsApp/Email', async () => {
  const store = new InMemoryWebhookStore([seedBooking()]);
  const transport = new InMemoryNotificationTransport();
  const dispatcher = new AppointmentNotificationDispatcher({ transport });
  const processor = new PaymentWebhookProcessor({
    store,
    notificationDispatcher: dispatcher,
    secrets: SECRETS,
    pinGenerator: () => '4829',
  });

  const payload = {
    event: 'charge.success',
    data: {
      status: 'success',
      reference: 'ABE_PS_BKZA1001_IDEM1',
      amount: 35000,
      currency: 'ZAR',
      metadata: {
        bookingId: 'bk_za_1001',
        idempotencyKey: 'idem_za_1001',
      },
    },
  };
  const rawBody = JSON.stringify(payload);
  const sig = computeHmacSignature('sha512', rawBody, SECRETS.paystack);

  const first = await processor.processWebhook({
    provider: 'paystack',
    rawBody,
    signatureHeader: sig,
  });

  assert.equal(first.status, 'confirmed');
  assert.equal(first.idempotentReplay, false);
  assert.equal(first.pinGenerated, true);
  assert.equal(first.notificationsDispatched, 4);

  const updatedBooking = await store.getBooking('bk_za_1001');
  assert.equal(updatedBooking.status, 'confirmed');

  const pinDoc = store.bookingPins.get('bk_za_1001');
  assert.equal(pinDoc.pinCode, '4829');
  assert.equal(store.ledgerEntries.length, 1);

  const clientMsgs = transport.sentMessages.filter((m) => m.metadata.pinIncluded === true);
  const techMsgs = transport.sentMessages.filter((m) => m.recipientId === 'tech_nadia');
  assert.equal(clientMsgs.length, 3);
  assert.equal(techMsgs.length, 1);
  assert.equal(techMsgs[0].body.includes('4829'), false);
  assert.equal(transport.scheduledReminders.length, 2);

  // Duplicate webhook replay must NOT double-write ledger or regenerate PIN
  const replay = await processor.processWebhook({
    provider: 'paystack',
    rawBody,
    signatureHeader: sig,
  });
  assert.equal(replay.status, 'already_processed');
  assert.equal(replay.idempotentReplay, true);
  assert.equal(store.ledgerEntries.length, 1);
});

test('PaymentWebhookProcessor blocks 1-cent underpayment, path injection, house calls, and state rollback', async () => {
  const houseCallBooking = seedBooking({
    id: 'bk_house_call',
    venueType: 'house_call',
    venueAddress: 'Private residential home visit',
  });
  const totalPriceBooking = seedBooking({
    id: 'bk_total_zar',
    venueType: 'partner_salon',
    expectedGatewayDueCents: undefined,
    totalPriceZar: 450,
  });
  const completedBooking = seedBooking({
    id: 'bk_done_99',
    status: 'completed',
    expectedGatewayDueCents: 45000,
  });
  const store = new InMemoryWebhookStore([
    houseCallBooking,
    totalPriceBooking,
    completedBooking,
  ]);
  const processor = new PaymentWebhookProcessor({
    store,
    secrets: SECRETS,
    pinGenerator: () => '7391',
  });

  // 1-cent underpayment rejected when falling back to totalPriceZar * 100
  const underpayPayload = {
    event: 'ORDER_APPROVED',
    status: 'APPROVED',
    merchantReference: 'ABE_PJN_UNDER',
    bookingId: 'bk_total_zar',
    idempotencyKey: 'idem_under',
    amountCents: 1,
    currency: 'ZAR',
  };
  const underRaw = JSON.stringify(underpayPayload);
  await assert.rejects(
    () =>
      processor.processWebhook({
        provider: 'payjustnow',
        rawBody: underRaw,
        signatureHeader: computeHmacSignature('sha256', underRaw, SECRETS.payjustnow),
      }),
    /Amount mismatch/
  );

  // Firestore path injection in bookingId rejected
  const pathInjectPayload = {
    event: 'ORDER_APPROVED',
    status: 'APPROVED',
    merchantReference: 'ABE_PJN_PATH',
    bookingId: '../wallets/client_zara',
    idempotencyKey: 'idem_path',
    amountCents: 45000,
    currency: 'ZAR',
  };
  const pathRaw = JSON.stringify(pathInjectPayload);
  await assert.rejects(
    () =>
      processor.processWebhook({
        provider: 'payjustnow',
        rawBody: pathRaw,
        signatureHeader: computeHmacSignature('sha256', pathRaw, SECRETS.payjustnow),
      }),
    /Invalid bookingId/
  );

  // Completed booking cannot be rolled back to confirmed
  const rollbackPayload = {
    event: 'ORDER_APPROVED',
    status: 'APPROVED',
    merchantReference: 'ABE_PJN_DONE',
    bookingId: 'bk_done_99',
    idempotencyKey: 'idem_done_new',
    amountCents: 45000,
    currency: 'ZAR',
  };
  const rollbackRaw = JSON.stringify(rollbackPayload);
  const rollbackRes = await processor.processWebhook({
    provider: 'payjustnow',
    rawBody: rollbackRaw,
    signatureHeader: computeHmacSignature('sha256', rollbackRaw, SECRETS.payjustnow),
  });
  assert.equal(rollbackRes.status, 'already_processed');
  assert.equal((await store.getBooking('bk_done_99')).status, 'completed');

  // Valid partner_salon booking confirms cleanly
  const validPayload = {
    event: 'ORDER_APPROVED',
    status: 'APPROVED',
    merchantReference: 'ABE_PJN_VALID',
    bookingId: 'bk_total_zar',
    idempotencyKey: 'idem_valid_ps',
    amountCents: 45000,
    currency: 'ZAR',
  };
  const validRaw = JSON.stringify(validPayload);
  const validRes = await processor.processWebhook({
    provider: 'payjustnow',
    rawBody: validRaw,
    signatureHeader: computeHmacSignature('sha256', validRaw, SECRETS.payjustnow),
  });
  assert.equal(validRes.status, 'confirmed');
  assert.equal(store.bookingPins.get('bk_total_zar').pinCode, '7391');
});

test('PublicOnboardingHandlers sanitises nested XSS, enforces Strict Venue-Only, blocks prototype pollution, and rate-limits', async () => {
  assert.equal(sanitiseText('javajavascript:script:alert(1)'), 'alert(1)');

  const store = new InMemoryOnboardingStore();
  const rateLimiter = new SlidingWindowRateLimiter({ maxRequests: 2, windowMs: 60_000 });
  const handlers = new PublicOnboardingHandlers({ store, rateLimiter });

  const polluted = JSON.parse('{"fullName":"Test","__proto__":{"isAdmin":true}}');
  await assert.rejects(
    () => handlers.submitFoundingTechApplication({ payload: polluted, actorKey: '127.0.0.1' }),
    /forbidden key/
  );

  const techApp = await handlers.submitFoundingTechApplication({
    actorKey: '10.0.0.1',
    payload: {
      fullName: '<script>alert(1)</script>Kagiso M.',
      instagramHandle: '@kagisonails',
      email: 'kagiso@abe.co.za',
      phone: '0829991122',
      city: 'JHB',
      venueType: 'verified_studio',
      venueName: 'Rosebank Velvet Lounge',
      venueAddress: '19 Cradock Ave, Rosebank, Johannesburg',
      specialty: 'BIAB & Chrome',
      basePriceRangeZar: 'R400 - R650',
      popiaConsent: true,
    },
  });
  assert.equal(techApp.fullName, 'Kagiso M.');
  assert.equal(techApp.city, 'JHB');

  await assert.rejects(
    () =>
      handlers.submitFoundingTechApplication({
        actorKey: '10.0.0.2',
        payload: {
          fullName: 'Mobile Tech',
          instagramHandle: '@mobile',
          email: 'mob@abe.co.za',
          phone: '0821112222',
          city: 'CPT',
          venueType: 'house_call',
          venueName: 'Client home',
          venueAddress: 'House call to residential home',
          specialty: 'Gel',
          basePriceRangeZar: 'R350',
          popiaConsent: true,
        },
      }),
    /Strict Venue-Only Policy/
  );

  await handlers.submitFoundingTechApplication({
    actorKey: '10.0.0.1',
    payload: {
      fullName: 'Second Tech',
      instagramHandle: '@second',
      email: 'second@abe.co.za',
      phone: '0823334444',
      city: 'CPT',
      venueType: 'verified_studio',
      venueName: 'Sea Point Studio',
      venueAddress: '118 Regent Rd, Sea Point',
      specialty: 'French',
      basePriceRangeZar: 'R450',
      popiaConsent: true,
    },
  });

  await assert.rejects(
    () =>
      handlers.submitFoundingTechApplication({
        actorKey: '10.0.0.1',
        payload: {
          fullName: 'Third Tech',
          instagramHandle: '@third',
          email: 'third@abe.co.za',
          phone: '0825556666',
          city: 'CPT',
          venueType: 'verified_studio',
          venueName: 'Sea Point Studio',
          venueAddress: '118 Regent Rd, Sea Point',
          specialty: 'French',
          basePriceRangeZar: 'R450',
          popiaConsent: true,
        },
      }),
    /Too many submissions/
  );

  // Admin Quick Profile Seeder UAC enforcement + schema alignment
  await assert.rejects(
    () =>
      handlers.adminSeedFoundingProfile({
        actor: { uid: 'revoked_staff', isActive: false, permissions: ['techs.approve'] },
        payload: {},
      }),
    /Access revoked/
  );

  const seeded = await handlers.adminSeedFoundingProfile({
    actor: {
      uid: 'rio_admin',
      uacGroupId: 'super_admin',
      isActive: true,
      permissions: [],
    },
    payload: {
      techId: 'tech_nadia_cpt',
      techDisplayName: 'Nadia Jacobs',
      city: 'CPT',
      tierBadge: 'certified_pro',
      venueType: 'partner_salon_chair',
      venueId: 'venue_cpt_seapoint_01',
      venueName: 'Atelier Rose Studio, Sea Point',
      styleCategory: 'BIAB & Micro French',
      lookTitle: 'Sculpted Almond BIAB',
      basePriceZar: 450,
      baseDurationMinutes: 90,
      photoUrl: 'https://cdn.abe.co.za/cpt/nadia_biab.jpg',
    },
  });
  assert.equal(seeded.city, 'CPT');
  assert.equal(seeded.techTierBadge, 'certified_pro');
  assert.equal(seeded.venueType, 'partner_salon');
  assert.equal(store.staffAuditLogs.length, 1);
  assert.equal(store.staffAuditLogs[0].actorUacGroup, 'super_admin');
});
