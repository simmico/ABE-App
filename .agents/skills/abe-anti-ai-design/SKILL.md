---
name: abe-anti-ai-design
description: >-
  Enforces the Aqeelah's Beauty Empire (ABE) Warm Luxury Design System and
  anti-AI copywriting rules across Flutter (iOS/Android) and Web Admin screens.
  Activate whenever building or reviewing UI components, screens, themes, or user-facing text.
---

# ABE Anti-AI Design & Copywriting Skill

Use this skill alongside `ui-ux-pro-max`, `design-system`, and `ui-styling` whenever creating or modifying any UI screen, widget, or user-facing string in **Aqeelah's Beauty Empire (ABE)**.

---

## 1. What Is Strictly Forbidden ("Anti-AI Slop" Rules)
1. **No Default Material/AI Templates:** Never use default Flutter Material purple/blue palettes, generic floating action buttons, or unstyled `Card` widgets.
2. **No Em-Dashes:** Never output the `—` character anywhere in UI text, placeholders, error messages, or comments.
3. **UK / South African English Only:** Always use British/South African spelling (*colour, centre, organise, programme, cancelled, randomised, tokenisation, Rands / R*).
4. **No AI Buzzwords:** Never write phrases like *seamless experience, elevate your beauty, delve, testament, game-changer, empower*. Use warm, clear, natural human copy.

---

## 2. Official ABE Colour Palette ("Dusty Rose & Alabaster Studio")
Configure these exact tokens in your Flutter `ThemeData` / `ColorScheme` and Web CSS:
- `bgCream` (`#FAF6F5`): Primary app scaffold background (warm alabaster cream, never stark `#FFFFFF` or cold grey `#F5F5F5`).
- `surfaceCard` (`#FFFFFF`): Elevated cards and sheets.
- `blushSoft` (`#F5E6E8`): Highlight backgrounds, active selection pills, and soft badges.
- `rosePrimary` (`#C87D87`): Primary CTA buttons, active toggles, and progress fills.
- `roseDark` (`#A65E68`): Pressed states, high-contrast badge text, and links.
- `champagne` (`#B89278`): Secondary accents, Certified Pro seal borders, and Salon Partner tags.
- `espresso` (`#2B2123`): Primary typography and dark mode/contrast pills (never harsh `#000000`).
- `textMuted` (`#6E5A5D`): Subtitles, durations, and secondary metadata.
- `borderWarm` (`#EADCD9`): 1px card borders and dividers.
- `sageSuccess` (`#5E8C76`): Verified badges, PIN confirmation, and completed states.

---

## 3. Typography & Hierarchy
- **Headings (`Cormorant Garamond`):** Semi-bold (`w600`) or Bold (`w700`), tight letter-spacing (`-0.01em`), used for screen titles, salon names, and section headers.
- **Body, Prices & Controls (`Plus Jakarta Sans`):**
  - Prices (`R450`) and Durations (`90 mins`) must be bold (`w700`), high-contrast, and immediately scannable on every Visual Contract card.
  - Buttons and badges use `w600` or `w700` with pill-shaped radii (`999px`) or soft rounded corners (`14px` to `22px`).

---

## 4. Signature ABE UI Components
1. **The Visual Contract Card:**
   - Aspect ratio `4:5` or `3:4` crisp nail photography.
   - Top-left overlay pill: Tech Tier Badge (*Rising Tech*, *Verified Tech*, or *Certified Pro ★*).
   - Bottom glass/cream bar stamped directly onto the card: **Exact Base Price (`R450`)** + **Exact Duration (`90 mins`)** + **Verified Salon Area (`CPT` / `JHB`)**.
2. **Dynamic Modifier Switches:**
   - Tactile toggle rows (*Soak-Off / Removal (+R80 • +30 mins)*, *Extra Length (+R60 • +15 mins)*) that animate the bottom sticky total bar immediately when tapped.
