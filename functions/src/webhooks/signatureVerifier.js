import crypto from 'node:crypto';

/**
 * Timing-safe cryptographic webhook signature verification for South African
 * payment gateways:
 * - Paystack South Africa: `x-paystack-signature` (HMAC-SHA512 hex)
 * - Peach Payments: `x-peach-signature` (HMAC-SHA256 hex)
 * - PayJustNow BNPL: `x-payjustnow-signature` (HMAC-SHA256 hex)
 */

function timingSafeHexEquals(expectedHex, providedHex) {
  if (typeof providedHex !== 'string' || typeof expectedHex !== 'string') {
    return false;
  }
  const cleanProvided = providedHex.trim().toLowerCase().replace(/^sha256=|^sha512=/, '');
  const cleanExpected = expectedHex.trim().toLowerCase();

  if (
    cleanProvided.length === 0 ||
    cleanProvided.length !== cleanExpected.length ||
    !/^[0-9a-f]+$/.test(cleanProvided)
  ) {
    return false;
  }

  const expectedBuf = Buffer.from(cleanExpected, 'hex');
  const providedBuf = Buffer.from(cleanProvided, 'hex');
  if (expectedBuf.length !== providedBuf.length) {
    return false;
  }
  return crypto.timingSafeEqual(expectedBuf, providedBuf);
}

export function computeHmacSignature(algorithm, rawBody, secret) {
  if (!secret || typeof secret !== 'string') {
    throw new Error('Webhook signing secret is not configured.');
  }
  const bodyBuffer = Buffer.isBuffer(rawBody)
    ? rawBody
    : Buffer.from(typeof rawBody === 'string' ? rawBody : JSON.stringify(rawBody), 'utf8');
  return crypto.createHmac(algorithm, secret).update(bodyBuffer).digest('hex');
}

export function verifyPaystackSignature(rawBody, signatureHeader, secret) {
  if (!signatureHeader) return false;
  const expected = computeHmacSignature('sha512', rawBody, secret);
  return timingSafeHexEquals(expected, signatureHeader);
}

export function verifyPeachSignature(rawBody, signatureHeader, secret) {
  if (!signatureHeader) return false;
  const expected = computeHmacSignature('sha256', rawBody, secret);
  return timingSafeHexEquals(expected, signatureHeader);
}

export function verifyPayJustNowSignature(rawBody, signatureHeader, secret) {
  if (!signatureHeader) return false;
  const expected = computeHmacSignature('sha256', rawBody, secret);
  return timingSafeHexEquals(expected, signatureHeader);
}

export function verifyGatewayWebhookSignature({
  provider,
  rawBody,
  signatureHeader,
  secret,
}) {
  switch (provider) {
    case 'paystack':
      return verifyPaystackSignature(rawBody, signatureHeader, secret);
    case 'peach_payments':
      return verifyPeachSignature(rawBody, signatureHeader, secret);
    case 'payjustnow':
      return verifyPayJustNowSignature(rawBody, signatureHeader, secret);
    default:
      return false;
  }
}
