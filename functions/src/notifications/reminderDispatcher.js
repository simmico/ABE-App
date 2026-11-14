import { sanitiseSingleLine, sanitiseText } from '../security/sanitiser.js';

/**
 * Multi-channel appointment confirmation and reminder dispatcher
 * (Push / WhatsApp / Email) in UK/South African English with zero em-dashes.
 *
 * Security invariant: The 4-digit booking PIN is sent ONLY to the client's
 * notification channels and is NEVER included in any technician notification.
 */

export class AppointmentNotificationDispatcher {
  constructor({ transport } = {}) {
    this.transport = transport || new InMemoryNotificationTransport();
  }

  async sendBookingConfirmedNotifications({
    bookingId,
    clientId,
    clientName,
    clientEmail,
    clientPhone,
    techId,
    techName,
    venueName,
    venueAddress,
    city,
    scheduledAtIso,
    amountPaidZarCents,
    clientBookingPin,
  }) {
    const safeBookingId = sanitiseSingleLine(String(bookingId || ''), 128);
    const safeCity = sanitiseSingleLine(String(city || ''), 10);
    const safeScheduledAt = sanitiseSingleLine(String(scheduledAtIso || ''), 64);
    const safeClientName = sanitiseSingleLine(clientName || 'Client', 80);
    const safeTechName = sanitiseSingleLine(techName || 'your nail technician', 80);
    const safeVenueName = sanitiseSingleLine(venueName, 140);
    const safeAddress = sanitiseSingleLine(venueAddress, 240);
    const safeEmail = sanitiseSingleLine(String(clientEmail || clientId), 160);
    const safePhone = sanitiseSingleLine(String(clientPhone || clientId), 32);
    const safePin = sanitiseSingleLine(String(clientBookingPin || ''), 8);
    const amountZar = (Number(amountPaidZarCents || 0) / 100).toFixed(2);

    if (!/^\d{4}$/.test(safePin)) {
      throw new Error('A valid 4-digit client booking PIN is required for confirmation notifications.');
    }

    const clientReminderMessages = [
      {
        channel: 'push',
        recipientId: clientId,
        bookingId: safeBookingId,
        title: 'Booking Confirmed at ' + safeVenueName,
        body: sanitiseText(
          `Hi ${safeClientName}, your appointment with ${safeTechName} in ${safeCity} is confirmed ` +
            `(R${amountZar} paid). Your private 4-digit start PIN is ${safePin}.`,
          400
        ),
        metadata: {
          type: 'booking_confirmed',
          bookingId: safeBookingId,
          pinIncluded: true,
        },
      },
      {
        channel: 'whatsapp',
        recipientId: safePhone,
        bookingId: safeBookingId,
        templateName: 'abe_booking_confirmed_client_za',
        body: sanitiseText(
          `Aqeelah's Beauty Empire (ABE): Confirmed with ${safeTechName} at ${safeVenueName} ` +
            `(${safeAddress}) on ${safeScheduledAt}. Private start PIN: ${safePin}. ` +
            'Share this PIN only when you are seated at the venue.',
          500
        ),
        metadata: {
          type: 'booking_confirmed',
          bookingId: safeBookingId,
          pinIncluded: true,
        },
      },
      {
        channel: 'email',
        recipientId: safeEmail,
        bookingId: safeBookingId,
        subject: sanitiseSingleLine(
          `ABE Booking Confirmed (${safeCity}) - ${safeVenueName}`,
          180
        ),
        body:
          `Hi ${safeClientName},\n\n` +
          `Your Visual Contract booking (${safeBookingId}) with ${safeTechName} is confirmed.\n` +
          `Venue: ${safeVenueName}, ${safeAddress} (${safeCity})\n` +
          `When: ${safeScheduledAt}\n` +
          `Upfront Payment: R${amountZar}\n` +
          `Your Private 4-Digit Start PIN: ${safePin}\n\n` +
          'Important: Appointments take place strictly at verified commercial venues.',
        metadata: {
          type: 'booking_confirmed',
          bookingId: safeBookingId,
          pinIncluded: true,
        },
      },
    ];

    // Tech receives confirmation WITHOUT the 4-digit PIN.
    const techNotification = {
      channel: 'push',
      recipientId: techId,
      bookingId: safeBookingId,
      title: 'New Confirmed Booking (' + safeCity + ')',
      body: sanitiseText(
        `${safeClientName} booked with you at ${safeVenueName} for ${safeScheduledAt}. ` +
          'Verify your biometrics and request the client PIN upon arrival.',
        400
      ),
      metadata: {
        type: 'tech_booking_confirmed',
        bookingId: safeBookingId,
        pinIncluded: false,
      },
    };

    const scheduledReminders = this.buildPreAppointmentReminders({
      bookingId: safeBookingId,
      clientId,
      clientName: safeClientName,
      clientPhone: safePhone,
      techName: safeTechName,
      venueName: safeVenueName,
      venueAddress: safeAddress,
      scheduledAtIso: safeScheduledAt,
    });

    const dispatched = [];
    for (const msg of [...clientReminderMessages, techNotification]) {
      dispatched.push(await this.transport.sendImmediate(msg));
    }
    const queuedReminders = [];
    for (const reminder of scheduledReminders) {
      queuedReminders.push(await this.transport.scheduleReminder(reminder));
    }

    return { dispatched, queuedReminders };
  }

  buildPreAppointmentReminders({
    bookingId,
    clientId,
    clientName,
    clientPhone,
    techName,
    venueName,
    venueAddress,
    scheduledAtIso,
  }) {
    const startMs = Date.parse(scheduledAtIso);
    if (Number.isNaN(startMs)) {
      return [];
    }

    return [
      {
        id: `rem_24h_${bookingId}`,
        bookingId,
        clientId,
        channels: ['push', 'whatsapp'],
        recipientPhone: clientPhone || null,
        sendAtIso: new Date(startMs - 24 * 60 * 60 * 1000).toISOString(),
        message: sanitiseSingleLine(
          `Reminder for ${clientName}: Your ABE nail appointment with ${techName} is tomorrow at ` +
            `${venueName} (${venueAddress}). Check your app for your 4-digit start PIN.`,
          400
        ),
        status: 'scheduled',
      },
      {
        id: `rem_2h_${bookingId}`,
        bookingId,
        clientId,
        channels: ['push'],
        recipientPhone: clientPhone || null,
        sendAtIso: new Date(startMs - 2 * 60 * 60 * 1000).toISOString(),
        message: sanitiseSingleLine(
          `See you in 2 hours at ${venueName} (${venueAddress}). Have your 4-digit ABE start PIN ready.`,
          400
        ),
        status: 'scheduled',
      },
    ];
  }
}

export class InMemoryNotificationTransport {
  constructor() {
    this.sentMessages = [];
    this.scheduledReminders = [];
  }

  async sendImmediate(message) {
    const record = { ...message, sentAtIso: new Date().toISOString() };
    this.sentMessages.push(record);
    return record;
  }

  async scheduleReminder(reminder) {
    this.scheduledReminders.push(reminder);
    return reminder;
  }
}
