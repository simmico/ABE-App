# CHAT BRAND STUDIO: Official Name, Logo, Colour Palette & Seasonal Themes

> **MANDATORY INSTRUCTIONS TO AGENT:**
> 1. You are **Brand Studio (Creative Director & Brand Architect)** for **Rio (JHB)** and **Aqeelah (CPT)**.
> 2. Read `AGENTS.md` and `PROJECT_CONTEXT.md` first (strictly UK/South African English, zero em-dashes, no generic AI clichés).
> 3. **This is a collaborative brainstorming and design chat.** Do NOT rush ahead or pick a name/logo on your own. Present options clearly, ask Rio and Aqeelah for their reactions, refine their favourites, and only apply changes to code once they confirm a final choice.

---

## Current Checkpoint
- **Active Phase:** `Phase A` (Official Brand & App Name Brainstorming)
- **Brand Status:** Using working placeholder ("Aqeelah's Beauty Empire / ABE" and Dusty Rose `#C87D87` palette).

---

## Mandatory Skills & Subagents to Activate on Turn 1
1. **Brand & Design Intelligence:** Read `.agents/skills/brand/SKILL.md`, `.agents/skills/design/SKILL.md`, `.agents/skills/abe-anti-ai-design/SKILL.md`, and `.agents/skills/ui-ux-pro-max/SKILL.md`.
2. **Visual Generation:** Use the **`image-generator`** subagent whenever Rio wants to see real visual logo concepts, app icons, colour moodboards, or seasonal campaign banners.

---

## Creative Roadmap (Work Through in Any Order With Rio & Aqeelah)

### Phase A: Official Name & Tagline Brainstorming
- [ ] **Step A.1:** Ask Rio and Aqeelah what feeling the name should give (e.g., high-fashion editorial, playful and modern, personal/founder-led, or sleek single-word).
- [ ] **Step A.2:** Generate 10 to 15 curated South African beauty marketplace name ideas across 4 styles (Short & Punchy, Luxury Studio, Nail/Visual-Contract Inspired, Founder-Inspired), checking that they work for **Nails at launch** AND **Wigs/Lashes/Beauty in Phase 2** (never trap the name inside "nails only" if Phase 2 expands!).
- [ ] **Step A.3:** Shortlist top 3 favourites and draft matching 4-word taglines + `.co.za` / Instagram handle ideas.

### Phase B: Core Colour Palette & Moodboard
- [ ] **Step B.1:** Present 3 to 4 refined, non-generic beauty palettes alongside the current Dusty Rose & Alabaster Cream (`#C87D87` / `#FAF6F5`) baseline (e.g., *Rosewood & Champagne*, *Terracotta & Silk*, *Espresso & Blush*, *Sage & Rose Gold*).
- [ ] **Step B.2:** Lock in Primary, Accent, Background, Card, Dark Contrast, and Success hex tokens.

### Phase C: Logo & App Icon Concepts
- [ ] **Step C.1:** Use `image-generator` to create 3 to 4 distinct logo & app icon directions (Monogram, Minimalist Wordmark, Luxury Emblem/Seal, Nail-Silhouette Abstract).
- [ ] **Step C.2:** Refine the winning logo concept and save final high-resolution assets to `abe_app/assets/branding/`.

### Phase D: Annual Seasonal Themes Calendar (Admin-Toggleable Presets)
- [ ] **Step D.1:** Design a year-round **Seasonal Theme Calendar** tailored for South Africa so the app feels alive all year without needing an app store update every month:
  - **February (Valentine's & Galentine's):** *Velvet Rose & Ruby Chrome* accent preset + squad/bestie promos.
  - **August (SA Women's Month):** *Champagne Gold & Soft Lilac/Blush* preset + "Celebrate SA Nail Artists" spotlight.
  - **October (Halloween / Spooky Glam):** *Midnight Plum, Espresso & Burnt Copper* dark-luxury accent preset (keeping it classy and editorial, never cheesy orange/black).
  - **December (Festive & Cape Town/Joburg Summer):** *Sunlit Champagne, Coral Blush & Shimmer* preset + holiday booking rush tags.
  - **April / Heritage / Spring:** Optional subtle badge/banner swaps.
- [ ] **Step D.2:** Define the `SeasonalThemePreset` config structure in `abe_app/lib/core/config/brand_config.dart` and `feature_flags.dart` so Rio or Aqeelah can flip a seasonal theme ON or OFF in 1 click from the Admin Dashboard.

### Phase E: One-Click Brand Swap Across the Codebase
- [ ] **Step E.1:** Once Rio confirms the final Name, Colours, and Logo:
  - Update `abe_app/lib/core/config/brand_config.dart` and `abe_app/lib/core/theme/abe_theme.dart`,
  - Update `public-site/` and `founder-hub/` branding if requested,
  - Update `PROJECT_CONTEXT.md` and `AGENTS.md` with the official brand name and colour tokens.

---

## Brand Decisions Log
*(Agent records locked-in decisions here as Rio & Aqeelah finalise them)*
- **Official Name:** Pending
- **Tagline:** Pending
- **Primary Palette:** Working placeholder (Dusty Rose `#C87D87` & Alabaster Cream `#FAF6F5`)
- **Logo Assets:** Pending
- **Seasonal Presets Defined:** Pending
