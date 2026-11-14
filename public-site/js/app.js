(function () {
  'use strict';

  const API_BASE = 'https://africa-south1-abe-prod.cloudfunctions.net';
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

  const SEED_SHOWCASE = [
    {
      id: 'vc_cpt_01',
      title: 'Sculpted Almond BIAB & Micro French',
      techName: 'Nadia Jacobs',
      tierLabel: 'Certified Pro ★',
      city: 'CPT',
      venueName: 'Atelier Rose Studio, Sea Point',
      priceZar: 450,
      durationMins: 90,
    },
    {
      id: 'vc_jhb_01',
      title: 'Champagne Glazed Gel-X Extensions',
      techName: 'Lerato Khumalo',
      tierLabel: 'Certified Pro ★',
      city: 'JHB',
      venueName: 'House of Alabaster, Rosebank',
      priceZar: 520,
      durationMins: 105,
    },
    {
      id: 'vc_cpt_02',
      title: 'Soft Blush Baby Boomer Gel Overlay',
      techName: 'Amina Abrahams',
      tierLabel: 'Verified Tech',
      city: 'CPT',
      venueName: 'Cavendish Lane Nail Bar, Claremont',
      priceZar: 390,
      durationMins: 75,
    },
    {
      id: 'vc_jhb_02',
      title: 'Espresso & Gold Foil Tortoiseshell Set',
      techName: 'Thando Mokoena',
      tierLabel: 'Verified Tech',
      city: 'JHB',
      venueName: 'Champagne Beauty Collective, Bryanston',
      priceZar: 480,
      durationMins: 95,
    },
  ];

  function sanitiseText(raw, maxLength) {
    if (typeof raw !== 'string') return '';
    let cleaned = raw;
    let prev;
    let passes = 0;
    do {
      prev = cleaned;
      cleaned = cleaned
        .replace(/<\s*script[^>]*>[\s\S]*?<\s*\/\s*script\s*>/gi, '')
        .replace(/<\s*style[^>]*>[\s\S]*?<\s*\/\s*style\s*>/gi, '')
        .replace(/\bon[a-z]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi, '')
        .replace(/<[^>]*>/g, '')
        .replace(/(javascript|vbscript|data)\s*:/gi, '')
        .replace(/\u2014/g, '-')
        .replace(/&lt;|&gt;/gi, '')
        .trim();
      passes++;
    } while (cleaned !== prev && passes < 5);

    if (cleaned.length > maxLength) {
      cleaned = cleaned.slice(0, maxLength).trim();
    }
    return cleaned;
  }

  function hasResidentialTerm(text) {
    const lower = sanitiseText(text, 240).toLowerCase();
    return RESIDENTIAL_TERMS.some((term) => lower.includes(term));
  }

  function createRateLimiter(maxSubmissions, windowMs) {
    const history = new Map();
    return function canSubmit(bucket) {
      const now = Date.now();
      const recent = (history.get(bucket) || []).filter((t) => now - t < windowMs);
      if (recent.length >= maxSubmissions) {
        return false;
      }
      recent.push(now);
      history.set(bucket, recent);
      return true;
    };
  }

  const canSubmitForm = createRateLimiter(3, 60000);

  function showStatus(elementId, message, isSuccess) {
    const el = document.getElementById(elementId);
    if (!el) return;
    el.textContent = sanitiseText(message, 280);
    el.className = 'status-banner ' + (isSuccess ? 'success' : 'error');
  }

  function renderShowcase(cityFilter) {
    const grid = document.getElementById('showcase-grid');
    if (!grid) return;

    while (grid.firstChild) {
      grid.removeChild(grid.firstChild);
    }

    const items = SEED_SHOWCASE.filter(
      (item) => cityFilter === 'ALL' || item.city === cityFilter
    );

    items.forEach((item) => {
      const card = document.createElement('article');
      card.className = 'contract-card';

      const media = document.createElement('div');
      media.className = 'contract-media';

      const badge = document.createElement('span');
      badge.className = 'tier-badge';
      badge.textContent = item.tierLabel;

      const stamp = document.createElement('div');
      stamp.className = 'price-duration-stamp';

      const price = document.createElement('span');
      price.className = 'price-stamp';
      price.textContent = 'R' + String(item.priceZar);

      const duration = document.createElement('span');
      duration.className = 'duration-stamp';
      duration.textContent = String(item.durationMins) + ' mins';

      stamp.appendChild(price);
      stamp.appendChild(duration);
      media.appendChild(badge);
      media.appendChild(stamp);

      const body = document.createElement('div');
      body.className = 'contract-body';

      const title = document.createElement('h3');
      title.className = 'contract-title';
      title.textContent = item.title;

      const meta = document.createElement('p');
      meta.className = 'contract-meta';
      meta.textContent = item.techName + ' • ' + item.city;

      const venue = document.createElement('span');
      venue.className = 'venue-tag';
      venue.textContent = 'Verified Venue: ' + item.venueName;

      body.appendChild(title);
      body.appendChild(meta);
      body.appendChild(venue);

      card.appendChild(media);
      card.appendChild(body);
      grid.appendChild(card);
    });
  }

  async function postJsonSafe(endpoint, payload) {
    if (window.location.protocol === 'file:') {
      return { ok: true, localPreview: true };
    }
    const response = await fetch(API_BASE + endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(data.error || 'Submission rejected by server.');
    }
    return data;
  }

  function initShowcaseFilters() {
    const buttons = document.querySelectorAll('[data-city-filter]');
    if (!buttons.length) return;
    renderShowcase('ALL');
    buttons.forEach((btn) => {
      btn.addEventListener('click', () => {
        buttons.forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');
        renderShowcase(btn.getAttribute('data-city-filter') || 'ALL');
      });
    });
  }

  function initTechForm() {
    const form = document.getElementById('tech-application-form');
    if (!form) return;
    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      if (!canSubmitForm('tech')) {
        showStatus('tech-form-status', 'Rate limit reached. Please wait a minute before submitting again.', false);
        return;
      }

      const data = new FormData(form);
      const payload = {
        fullName: sanitiseText(data.get('fullName'), 120),
        instagramHandle: sanitiseText(data.get('instagramHandle'), 80),
        email: sanitiseText(data.get('email'), 160),
        phone: sanitiseText(data.get('phone'), 32),
        city: sanitiseText(data.get('city'), 10),
        venueType: sanitiseText(data.get('venueType'), 64),
        venueName: sanitiseText(data.get('venueName'), 140),
        venueAddress: sanitiseText(data.get('venueAddress'), 240),
        specialty: sanitiseText(data.get('specialty'), 140),
        basePriceRangeZar: sanitiseText(data.get('basePriceRangeZar'), 40),
        popiaConsent: Boolean(data.get('popiaConsent')),
      };

      if (!payload.popiaConsent) {
        showStatus('tech-form-status', 'Please accept the POPIA privacy and commercial venue terms.', false);
        return;
      }
      if (hasResidentialTerm(payload.venueAddress) || hasResidentialTerm(payload.venueName)) {
        showStatus('tech-form-status', 'Strict Venue-Only Policy: residential house calls are not permitted.', false);
        return;
      }
      if (payload.fullName.length < 2 || !payload.email.includes('@')) {
        showStatus('tech-form-status', 'Please enter your full name and a valid email address.', false);
        return;
      }

      try {
        await postJsonSafe('/submitTechApplication', payload);
        form.reset();
        showStatus('tech-form-status', 'Application received for ' + payload.city + '. Aqeelah or Rio will review your commercial venue details shortly.', true);
      } catch (err) {
        showStatus('tech-form-status', err.message || 'Could not reach the server. Please check your connection and try again.', false);
      }
    });
  }

  function initSalonForm() {
    const form = document.getElementById('salon-application-form');
    if (!form) return;
    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      if (!canSubmitForm('salon')) {
        showStatus('salon-form-status', 'Rate limit reached. Please wait a minute before submitting again.', false);
        return;
      }

      const data = new FormData(form);
      const payload = {
        salonName: sanitiseText(data.get('salonName'), 140),
        ownerName: sanitiseText(data.get('ownerName'), 120),
        email: sanitiseText(data.get('email'), 160),
        phone: sanitiseText(data.get('phone'), 32),
        city: sanitiseText(data.get('city'), 10),
        suburb: sanitiseText(data.get('suburb'), 100),
        streetAddress: sanitiseText(data.get('streetAddress'), 240),
        availableChairs: Number(data.get('availableChairs') || 1),
        suggestedChairFeeZar: Number(data.get('suggestedChairFeeZar') || 0),
        quietDaysWindow: sanitiseText(data.get('quietDaysWindow'), 120),
        popiaConsent: Boolean(data.get('popiaConsent')),
      };

      if (!payload.popiaConsent) {
        showStatus('salon-form-status', 'Please accept the POPIA verification terms.', false);
        return;
      }
      if (hasResidentialTerm(payload.streetAddress)) {
        showStatus('salon-form-status', 'Only commercial salon premises can list Empty Chairs.', false);
        return;
      }

      try {
        await postJsonSafe('/submitSalonApplication', payload);
        form.reset();
        showStatus('salon-form-status', 'Empty Chair listing submitted for ' + payload.city + '. Our team will verify your salon stations.', true);
      } catch (err) {
        showStatus('salon-form-status', err.message || 'Could not reach the server. Please check your connection and try again.', false);
      }
    });
  }

  function initWaitlistForm() {
    const form = document.getElementById('waitlist-form');
    if (!form) return;
    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      if (!canSubmitForm('waitlist')) {
        showStatus('waitlist-form-status', 'Rate limit reached. Please wait a minute before trying again.', false);
        return;
      }

      const data = new FormData(form);
      const payload = {
        firstName: sanitiseText(data.get('firstName'), 80),
        city: sanitiseText(data.get('city'), 10),
        email: sanitiseText(data.get('email'), 160),
        preferredLook: sanitiseText(data.get('preferredLook'), 120),
        popiaConsent: Boolean(data.get('popiaConsent')),
      };

      if (!payload.popiaConsent || payload.firstName.length < 2 || !payload.email.includes('@')) {
        showStatus('waitlist-form-status', 'Please enter your name, valid email, and POPIA consent.', false);
        return;
      }

      try {
        await postJsonSafe('/submitWaitlistClaim', payload);
        form.reset();
        showStatus('waitlist-form-status', 'You are on the ' + payload.city + ' waitlist! Use voucher ABE_FOUNDING_50 at checkout.', true);
      } catch (err) {
        showStatus('waitlist-form-status', err.message || 'Could not reach the server. Please check your connection and try again.', false);
      }
    });
  }

  function initAdminSeederForm() {
    const form = document.getElementById('admin-seeder-form');
    if (!form) return;
    form.addEventListener('submit', (event) => {
      event.preventDefault();
      const data = new FormData(form);
      const techDisplayName = sanitiseText(data.get('techDisplayName'), 120);
      const city = sanitiseText(data.get('city'), 10);
      const tierBadge = sanitiseText(data.get('tierBadge'), 32);
      const venueType = sanitiseText(data.get('venueType'), 64);
      const venueId = sanitiseText(data.get('venueId'), 128);
      const venueName = sanitiseText(data.get('venueName'), 140);
      const lookTitle = sanitiseText(data.get('lookTitle'), 140);
      const basePriceZar = Number(data.get('basePriceZar'));
      const baseDurationMinutes = Number(data.get('baseDurationMinutes'));
      const photoUrl = sanitiseText(data.get('photoUrl'), 500);

      if (hasResidentialTerm(venueName) || hasResidentialTerm(venueId)) {
        showStatus('seeder-status', 'Strict Venue-Only Policy: residential venues cannot be seeded.', false);
        return;
      }
      if (!photoUrl.startsWith('https://')) {
        showStatus('seeder-status', 'Portfolio photoUrl must use HTTPS.', false);
        return;
      }
      if (basePriceZar < 150 || basePriceZar > 5000 || baseDurationMinutes < 30 || baseDurationMinutes > 300) {
        showStatus('seeder-status', 'Price must be R150 to R5000 and duration 30 to 300 minutes.', false);
        return;
      }

      showStatus(
        'seeder-status',
        'Validated & staged "' + lookTitle + '" for ' + techDisplayName + ' (' + city + ', R' + basePriceZar + ', ' + baseDurationMinutes + ' mins, ' + tierBadge + ', ' + venueType + '). Ready to call adminSeedFoundingProfile.',
        true
      );
    });
  }

  document.addEventListener('DOMContentLoaded', () => {
    initShowcaseFilters();
    initTechForm();
    initSalonForm();
    initWaitlistForm();
    initAdminSeederForm();
  });
})();
