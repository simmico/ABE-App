import crypto from 'node:crypto';
import {
  sanitiseSingleLine,
  sanitiseText,
  SlidingWindowRateLimiter,
  validateCommercialVenue,
  validateEmail,
  validateLaunchCity,
  validateSaPhone,
  validateStrictObject,
} from '../security/sanitiser.js';

const ALLOWED_TIERS = new Set(['rising', 'verified', 'certified_pro']);

/**
 * Backend handlers for the Public Marketing & Onboarding Website (`public-site/`)
 * and the Admin Quick Profile Seeder tool.
 */
export class PublicOnboardingHandlers {
  constructor({ store, rateLimiter } = {}) {
    this.store = store || new InMemoryOnboardingStore();
    this.rateLimiter =
      rateLimiter || new SlidingWindowRateLimiter({ maxRequests: 6, windowMs: 60_000 });
  }

  async _enforceRateLimit(actorIpOrKey) {
    const result = await this.rateLimiter.checkAndRecord(actorIpOrKey);
    if (!result.allowed) {
      const err = new Error('Too many submissions. Please wait a minute and try again.');
      err.statusCode = 429;
      throw err;
    }
  }

  async submitFoundingTechApplication({ payload, actorKey }) {
    await this._enforceRateLimit(`tech:${actorKey}`);
    const safe = validateStrictObject(payload, [
      'fullName',
      'instagramHandle',
      'email',
      'phone',
      'city',
      'venueType',
      'venueName',
      'venueAddress',
      'specialty',
      'basePriceRangeZar',
      'popiaConsent',
    ]);

    if (safe.popiaConsent !== true) {
      throw new Error('POPIA privacy consent is required before submitting.');
    }

    const fullName = sanitiseSingleLine(safe.fullName, 120);
    const instagramHandle = sanitiseSingleLine(safe.instagramHandle, 80);
    const email = validateEmail(safe.email);
    const phone = validateSaPhone(safe.phone);
    const city = validateLaunchCity(safe.city);
    const specialty = sanitiseText(safe.specialty, 140);
    const venueName = sanitiseSingleLine(safe.venueName, 140);
    const venueAddress = sanitiseText(safe.venueAddress, 240);

    if (fullName.length < 2 || instagramHandle.length < 2 || specialty.length < 2) {
      throw new Error('Please provide your full name, social handle, and nail specialty.');
    }

    const venueCheck = validateCommercialVenue({
      venueType: safe.venueType,
      venueId: venueName,
      venueAddress,
    });

    const record = {
      id: `tech_app_${crypto.randomUUID()}`,
      fullName,
      instagramHandle,
      email,
      phone,
      city,
      venueType: venueCheck.venueType,
      venueName,
      venueAddress,
      specialty,
      basePriceRangeZar: sanitiseSingleLine(String(safe.basePriceRangeZar || ''), 40),
      status: 'pending_aqeelah_review',
      createdAtIso: new Date().toISOString(),
    };
    await this.store.saveTechApplication(record);
    return record;
  }

  async submitSalonEmptyChairApplication({ payload, actorKey }) {
    await this._enforceRateLimit(`salon:${actorKey}`);
    const safe = validateStrictObject(payload, [
      'salonName',
      'ownerName',
      'email',
      'phone',
      'city',
      'suburb',
      'streetAddress',
      'availableChairs',
      'quietDaysWindow',
      'suggestedChairFeeZar',
      'popiaConsent',
    ]);

    if (safe.popiaConsent !== true) {
      throw new Error('POPIA privacy consent is required before submitting.');
    }

    const salonName = sanitiseSingleLine(safe.salonName, 140);
    const ownerName = sanitiseSingleLine(safe.ownerName, 120);
    const email = validateEmail(safe.email);
    const phone = validateSaPhone(safe.phone);
    const city = validateLaunchCity(safe.city);
    const suburb = sanitiseSingleLine(safe.suburb, 100);
    const streetAddress = sanitiseText(safe.streetAddress, 240);
    const quietDaysWindow = sanitiseSingleLine(safe.quietDaysWindow, 120);
    const availableChairs = Number(safe.availableChairs);
    const suggestedChairFeeZar = Number(safe.suggestedChairFeeZar);

    if (salonName.length < 2 || ownerName.length < 2 || suburb.length < 2) {
      throw new Error('Please provide the salon name, owner name, and suburb.');
    }

    validateCommercialVenue({
      venueType: 'partner_salon_chair',
      venueId: salonName,
      venueAddress: streetAddress,
    });

    if (
      !Number.isInteger(availableChairs) ||
      availableChairs < 1 ||
      availableChairs > 50 ||
      !Number.isFinite(suggestedChairFeeZar) ||
      suggestedChairFeeZar < 0
    ) {
      throw new Error('Available chairs must be 1 to 50 and chair fee cannot be negative.');
    }

    const record = {
      id: `salon_app_${crypto.randomUUID()}`,
      salonName,
      ownerName,
      email,
      phone,
      city,
      suburb,
      streetAddress,
      availableChairs,
      quietDaysWindow,
      suggestedChairFeeZar: Math.round(suggestedChairFeeZar),
      status: 'pending_verification',
      createdAtIso: new Date().toISOString(),
    };
    await this.store.saveSalonApplication(record);
    return record;
  }

  async submitClientWaitlistClaim({ payload, actorKey }) {
    await this._enforceRateLimit(`waitlist:${actorKey}`);
    const safe = validateStrictObject(payload, [
      'firstName',
      'email',
      'city',
      'preferredLook',
      'popiaConsent',
    ]);

    if (safe.popiaConsent !== true) {
      throw new Error('POPIA privacy consent is required to join the waitlist.');
    }

    const firstName = sanitiseSingleLine(safe.firstName, 80);
    const email = validateEmail(safe.email);
    const city = validateLaunchCity(safe.city);
    const preferredLook = sanitiseSingleLine(safe.preferredLook || 'BIAB & Micro French', 120);

    if (firstName.length < 2) {
      throw new Error('Please enter a valid first name.');
    }

    const record = {
      id: `waitlist_${crypto.randomUUID()}`,
      firstName,
      email,
      city,
      preferredLook,
      voucherCodeIssued: 'ABE_FOUNDING_50',
      createdAtIso: new Date().toISOString(),
    };
    await this.store.saveWaitlistEntry(record);
    return record;
  }

  async adminSeedFoundingProfile({ actor, payload }) {
    if (!actor || !actor.isActive) {
      const err = new Error('Access revoked: inactive or unauthenticated staff actor.');
      err.statusCode = 403;
      throw err;
    }
    const perms = new Set(actor.permissions || []);
    const isSuperAdmin = actor.uacGroupId === 'super_admin';
    if (!isSuperAdmin && !perms.has('techs.approve') && !perms.has('uac.manage_roles')) {
      const err = new Error('UAC Permission denied: techs.approve is required to seed profiles.');
      err.statusCode = 403;
      throw err;
    }

    const safe = validateStrictObject(payload, [
      'techId',
      'techDisplayName',
      'city',
      'tierBadge',
      'venueType',
      'venueId',
      'venueName',
      'styleCategory',
      'lookTitle',
      'basePriceZar',
      'baseDurationMinutes',
      'photoUrl',
    ]);

    const city = validateLaunchCity(safe.city);
    const venueCheck = validateCommercialVenue({
      venueType: safe.venueType,
      venueId: safe.venueId,
      venueAddress: safe.venueName,
    });
    const normalisedVenueType =
      venueCheck.venueType === 'partner_salon_chair'
        ? 'partner_salon'
        : venueCheck.venueType;

    if (typeof this.store.verifyCommercialVenueExists === 'function') {
      const venueVerified = await this.store.verifyCommercialVenueExists(venueCheck.venueId);
      if (!venueVerified) {
        throw new Error('Strict Venue-Only Policy: referenced commercial venue is not verified.');
      }
    }

    const basePriceZar = Number(safe.basePriceZar);
    const baseDurationMinutes = Number(safe.baseDurationMinutes);
    if (
      !Number.isFinite(basePriceZar) ||
      basePriceZar < 150 ||
      basePriceZar > 5000 ||
      !Number.isFinite(baseDurationMinutes) ||
      baseDurationMinutes < 30 ||
      baseDurationMinutes > 300
    ) {
      throw new Error('Price must be R150 to R5,000 and duration must be 30 to 300 minutes.');
    }

    const photoUrl = sanitiseSingleLine(safe.photoUrl, 500);
    if (!photoUrl.startsWith('https://')) {
      throw new Error('Portfolio photoUrl must use HTTPS.');
    }

    const tierBadge = sanitiseSingleLine(safe.tierBadge || 'rising', 32).toLowerCase();
    if (!ALLOWED_TIERS.has(tierBadge)) {
      throw new Error('Invalid tierBadge: must be rising, verified, or certified_pro.');
    }

    const nowIso = new Date().toISOString();
    const seededId = `vc_seed_${city.toLowerCase()}_${crypto.randomUUID().slice(0, 8)}`;
    const techId = sanitiseSingleLine(safe.techId || `tech_seed_${seededId}`, 128);
    const techDisplayName = sanitiseSingleLine(safe.techDisplayName, 120);
    const lookTitle = sanitiseSingleLine(safe.lookTitle, 140);
    if (techDisplayName.length < 2 || lookTitle.length < 4) {
      throw new Error('techDisplayName and lookTitle are required.');
    }

    const seeded = {
      id: seededId,
      techId,
      techDisplayName,
      techTierBadge: tierBadge,
      photoUrl,
      title: lookTitle,
      basePriceZar: Math.round(basePriceZar),
      baseDurationMinutes: Math.round(baseDurationMinutes),
      city,
      venueId: venueCheck.venueId,
      venueName: sanitiseSingleLine(safe.venueName, 140),
      venueType: normalisedVenueType,
      styleCategory: sanitiseSingleLine(safe.styleCategory || 'BIAB & Structured Gel', 80),
      allowedModifiers: [],
      seededBy: actor.uid,
      createdAtIso: nowIso,
    };

    await this.store.saveSeededProfile(seeded, {
      id: `audit_${crypto.randomUUID()}`,
      actorId: actor.uid,
      actorUacGroup: actor.uacGroupId || 'ops_admin',
      action: 'admin_seed_founding_profile',
      targetId: seeded.id,
      notes: `Seeded ${seeded.title} in ${seeded.city} at ${seeded.venueName}`,
      timestampIso: nowIso,
    });
    return seeded;
  }
}

export class InMemoryOnboardingStore {
  constructor() {
    this.techApplications = [];
    this.salonApplications = [];
    this.waitlist = [];
    this.seededProfiles = [];
    this.staffAuditLogs = [];
  }

  async saveTechApplication(record) {
    this.techApplications.push(record);
  }

  async saveSalonApplication(record) {
    this.salonApplications.push(record);
  }

  async saveWaitlistEntry(record) {
    this.waitlist.push(record);
  }

  async saveSeededProfile(profile, auditLog) {
    this.seededProfiles.push(profile);
    this.staffAuditLogs.push(auditLog);
  }
}
