/**
 * Input sanitisation, prototype-pollution protection, Strict Venue-Only checks,
 * and sliding-window rate limiting for ABE backend Cloud Functions.
 *
 * Enforces UK/South African English rules and zero em-dashes.
 */

const FORBIDDEN_KEYS = new Set(['__proto__', 'constructor', 'prototype']);
const RESIDENTIAL_TERMS = [
  'house call',
  'house_call',
  'housecall',
  'home visit',
  'home_visit',
  'residential',
  'private home',
  'client address',
  'mobile tech',
];
const EMAIL_PATTERN = /^[^\s@<>]{1,64}@[^\s@<>]{1,128}\.[A-Za-z]{2,24}$/;
const SA_PHONE_PATTERN = /^(\+27|0)[1-9][0-9]{8}$/;
const FIRESTORE_ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

export function sanitiseText(rawInput, maxLength = 500) {
  if (typeof rawInput !== 'string') {
    return '';
  }
  let cleaned = rawInput;
  let previous;
  let passes = 0;
  do {
    previous = cleaned;
    cleaned = cleaned
      .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '')
      .replace(/<\s*script[^>]*>[\s\S]*?<\s*\/\s*script\s*>/gi, '')
      .replace(/<\s*style[^>]*>[\s\S]*?<\s*\/\s*style\s*>/gi, '')
      .replace(/\bon[a-z]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi, '')
      .replace(/<[^>]*>/g, '')
      .replace(/(javascript|vbscript|data)\s*:/gi, '')
      .replace(/\u2014/g, '-')
      .replace(/&lt;|&gt;/gi, '')
      .trim();
    passes++;
  } while (cleaned !== previous && passes < 5);

  if (cleaned.length > maxLength) {
    cleaned = cleaned.slice(0, maxLength).trim();
  }
  return cleaned;
}

export function sanitiseSingleLine(rawInput, maxLength = 200) {
  return sanitiseText(rawInput, maxLength).replace(/[\r\n]+/g, ' ').trim();
}

export function sanitiseFirestoreId(rawInput, fieldName = 'id') {
  const clean = sanitiseSingleLine(String(rawInput || ''), 128);
  if (!FIRESTORE_ID_PATTERN.test(clean)) {
    throw new Error(`Invalid ${fieldName}: must contain 1..128 safe identifier characters.`);
  }
  return clean;
}

export function stripPrototypeKeys(value, depth = 0) {
  if (depth > 8) {
    throw new Error('Payload nesting depth exceeded.');
  }
  if (Array.isArray(value)) {
    return value.map((item) => stripPrototypeKeys(item, depth + 1));
  }
  if (value && typeof value === 'object') {
    const out = Object.create(null);
    for (const key of Object.keys(value)) {
      if (FORBIDDEN_KEYS.has(key)) {
        throw new Error(`Security rejection: forbidden key "${key}" detected.`);
      }
      out[key] = stripPrototypeKeys(value[key], depth + 1);
    }
    return out;
  }
  return value;
}

export function validateStrictObject(payload, allowedKeys) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw new Error('Payload must be a plain JSON object.');
  }
  const allowed = new Set(allowedKeys);
  const safeObj = Object.create(null);
  for (const key of Object.keys(payload)) {
    if (FORBIDDEN_KEYS.has(key)) {
      throw new Error(`Security rejection: forbidden key "${key}" detected.`);
    }
    if (!allowed.has(key)) {
      throw new Error(`Schema validation failed: unexpected field "${key}".`);
    }
    safeObj[key] = payload[key];
  }
  return safeObj;
}

export function validateLaunchCity(rawCity) {
  const city = sanitiseSingleLine(rawCity, 10).toUpperCase();
  if (city !== 'CPT' && city !== 'JHB') {
    throw new Error('City must be CPT (Cape Town) or JHB (Johannesburg).');
  }
  return city;
}

export function validateEmail(rawEmail) {
  const email = sanitiseSingleLine(rawEmail, 160).toLowerCase();
  if (!EMAIL_PATTERN.test(email)) {
    throw new Error('Please provide a valid email address.');
  }
  return email;
}

export function validateSaPhone(rawPhone) {
  const compact = sanitiseSingleLine(rawPhone, 32).replace(/[\s()-]/g, '');
  if (!SA_PHONE_PATTERN.test(compact)) {
    throw new Error('Please provide a valid South African phone number.');
  }
  return compact;
}

export function validateCommercialVenue({ venueType, venueId, venueAddress = '' }) {
  const cleanType = sanitiseSingleLine(venueType, 64).toLowerCase();
  const cleanId = sanitiseSingleLine(venueId, 128);
  const cleanAddress = sanitiseText(venueAddress, 240).toLowerCase();

  if (
    cleanType !== 'verified_studio' &&
    cleanType !== 'partner_salon_chair' &&
    cleanType !== 'partner_salon'
  ) {
    throw new Error(
      'Strict Venue-Only Policy: venueType must be verified_studio, partner_salon, or partner_salon_chair.'
    );
  }
  if (!cleanId) {
    throw new Error('Strict Venue-Only Policy: a verified commercial venueId is required.');
  }
  for (const term of RESIDENTIAL_TERMS) {
    if (cleanAddress.includes(term) || cleanId.toLowerCase().includes(term)) {
      throw new Error(
        'Strict Venue-Only Policy: residential house calls are strictly prohibited.'
      );
    }
  }
  return { venueType: cleanType, venueId: cleanId };
}

export class SlidingWindowRateLimiter {
  constructor({ maxRequests = 8, windowMs = 60_000, nowFn = () => Date.now() } = {}) {
    this.maxRequests = maxRequests;
    this.windowMs = windowMs;
    this.nowFn = nowFn;
    this.buckets = new Map();
  }

  async checkAndRecord(actorKey) {
    const cleanActor = sanitiseSingleLine(String(actorKey || 'anonymous'), 128) || 'anonymous';
    const now = this.nowFn();
    const cutoff = now - this.windowMs;
    const recent = (this.buckets.get(cleanActor) || []).filter((ts) => ts > cutoff);
    if (recent.length >= this.maxRequests) {
      this.buckets.set(cleanActor, recent);
      return { allowed: false, remaining: 0 };
    }
    recent.push(now);
    this.buckets.set(cleanActor, recent);
    return { allowed: true, remaining: this.maxRequests - recent.length };
  }
}
