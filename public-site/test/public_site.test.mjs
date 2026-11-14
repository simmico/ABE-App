import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const publicDir = path.resolve(import.meta.dirname, '..');

function readPublicFile(relPath) {
  return fs.readFileSync(path.join(publicDir, relPath), 'utf8');
}

test('Public website enforces zero em-dashes, strict CSP without inline styles/unsafe sinks', () => {
  const files = ['index.html', 'admin-seeder.html', 'css/styles.css', 'js/app.js', '_headers'];
  for (const file of files) {
    const content = readPublicFile(file);
    assert.equal(
      content.includes('\u2014'),
      false,
      `Forbidden em-dash found in public-site/${file}`
    );
  }

  const headers = readPublicFile('_headers');
  assert.match(headers, /Content-Security-Policy:/);
  assert.match(headers, /object-src 'none'/);
  assert.match(headers, /frame-ancestors 'none'/);
  assert.match(headers, /X-Frame-Options: DENY/);
  assert.match(headers, /X-Content-Type-Options: nosniff/);
  assert.match(headers, /X-Robots-Tag: noindex, nofollow/);

  const indexHtml = readPublicFile('index.html');
  const seederHtml = readPublicFile('admin-seeder.html');
  assert.equal(/\bstyle\s*=/.test(indexHtml), false, 'Inline style attributes violate strict CSP in index.html');
  assert.equal(/\bstyle\s*=/.test(seederHtml), false, 'Inline style attributes violate strict CSP in admin-seeder.html');
  assert.equal(/admin-seeder\.html/.test(indexHtml), false, 'Public landing page must not link admin-seeder.html');

  const js = readPublicFile('js/app.js');
  assert.equal(/\binnerHTML\b/.test(js), false, 'innerHTML must not be used in public-site/js/app.js');
  assert.equal(/\beval\s*\(/.test(js), false, 'eval() must not be used in public-site/js/app.js');
  assert.equal(/offlineQueued/.test(js), false, 'Fake offlineQueued success fallback must not exist');
});

test('Public website includes CPT/JHB showcase, onboarding forms, waitlist, Admin Seeder, and SA merchant policies', () => {
  const indexHtml = readPublicFile('index.html');
  assert.match(indexHtml, /Cape Town \(CPT\)/);
  assert.match(indexHtml, /Johannesburg \(JHB\)/);
  assert.match(indexHtml, /Apply as a Founding Nail Tech/);
  assert.match(indexHtml, /List Your Salon's Empty Chairs/);
  assert.match(indexHtml, /ABE_FOUNDING_50/);
  assert.match(indexHtml, /75%/);
  assert.match(indexHtml, /POPIA/);
  assert.match(indexHtml, /support@abe\.co\.za/);

  const seederHtml = readPublicFile('admin-seeder.html');
  assert.match(seederHtml, /techs\.approve/);
  assert.match(seederHtml, /admin-seeder-form/);
});
