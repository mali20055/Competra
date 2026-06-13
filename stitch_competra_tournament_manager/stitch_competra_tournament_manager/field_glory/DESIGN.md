---
name: Field & Glory
colors:
  surface: '#05170d'
  surface-dim: '#05170d'
  surface-bright: '#2b3d31'
  surface-container-lowest: '#021108'
  surface-container-low: '#0d1f15'
  surface-container: '#112319'
  surface-container-high: '#1c2e23'
  surface-container-highest: '#27392d'
  on-surface: '#d2e8d7'
  on-surface-variant: '#bdcaba'
  inverse-surface: '#d2e8d7'
  inverse-on-surface: '#223429'
  outline: '#879485'
  outline-variant: '#3e4a3d'
  surface-tint: '#62df7d'
  primary: '#62df7d'
  on-primary: '#003914'
  primary-container: '#1ca64d'
  on-primary-container: '#003111'
  inverse-primary: '#006e2d'
  secondary: '#4de082'
  on-secondary: '#003919'
  secondary-container: '#00b55d'
  on-secondary-container: '#003e1c'
  tertiary: '#adceb8'
  on-tertiary: '#193626'
  tertiary-container: '#789883'
  on-tertiary-container: '#122f20'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#7ffc97'
  primary-fixed-dim: '#62df7d'
  on-primary-fixed: '#002109'
  on-primary-fixed-variant: '#005320'
  secondary-fixed: '#6dfe9c'
  secondary-fixed-dim: '#4de082'
  on-secondary-fixed: '#00210c'
  on-secondary-fixed-variant: '#005227'
  tertiary-fixed: '#c9ebd3'
  tertiary-fixed-dim: '#adceb8'
  on-tertiary-fixed: '#032112'
  on-tertiary-fixed-variant: '#2f4d3c'
  background: '#05170d'
  on-background: '#d2e8d7'
  surface-variant: '#27392d'
typography:
  display:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  stats-number:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 24px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  container-margin: 1rem
  gutter: 1rem
  stack-sm: 0.5rem
  stack-md: 1rem
  stack-lg: 1.5rem
---

## Brand & Style
The design system for COMPETRA is rooted in the high-stakes, premium atmosphere of professional football tournaments. It mimics the sleek, broadcast-quality aesthetics of modern sports media (like UEFA and EA FC) to instill a sense of prestige and athletic excellence. 

The visual style is **Corporate / Modern** with a **Tactile** edge, utilizing high-contrast greens and deep forest tones to simulate a night-match under stadium lights. The interface avoids unnecessary decorative flourishes, favoring high-performance layouts that prioritize real-time data, tournament brackets, and player statistics. The emotional response should be one of "Match Day Readiness"—energetic, focused, and professional.

## Colors
This design system utilizes a "Pitch-to-Podium" palette. The dark mode is the primary expression, capturing the intensity of stadium turf at night. 

- **Primary (Grass Green):** Used for main actions and brand signifiers.
- **Accent (Neon Green):** Reserved for highlights, active states, and "live" indicators to provide high-energy contrast.
- **Neutrals:** A desaturated green-grey scale is used for secondary text and borders to maintain the monochromatic "Deep Forest" theme without veering into neutral greys.
- **Semantic Colors:** Error and warning states use standard reds and ambers but are slightly desaturated to sit harmoniously against the dark green background.

## Typography
The typography relies exclusively on **Inter** to ensure maximum legibility across dense data tables and fast-moving tournament updates. 

- **Headlines:** Use Bold (700) weights with slightly tight letter-spacing to mimic sports broadcasting headlines.
- **Body:** Regular (400) weight is used for general information, ensuring the UI doesn't feel overly "heavy."
- **Labels & Stats:** SemiBold (600) is the workhorse for UI controls and metadata. For numerical data (scores, minutes, rankings), use "stats-number" with tabular lining to ensure columns of numbers align perfectly.
- **Uppercase:** Labels for "LIVE" status or "MATCH DAY" headers should use the `label-md` style with uppercase casing to differentiate them from interactive body text.

## Layout & Spacing
The design system employs a **Fluid Grid** model optimized for mobile-first tournament management. 

- **Grid:** A 4-column grid for mobile, scaling to 12-columns for tablet/desktop. 
- **Rhythm:** An 8px (2x unit) baseline grid governs vertical spacing. 
- **Safe Zones:** Use 16px (1rem) side margins for all primary content containers.
- **Density:** Tournament brackets and match lists should use "stack-sm" (8px) for tightly related items (e.g., Team A vs Team B) and "stack-md" (16px) for separating different matches.

## Elevation & Depth
In this design system, depth is communicated through **Tonal Layers** and **Subtle Contrast** rather than heavy drop shadows. 

- **Base Layer:** The Deep Forest Green (#0A1F14) acts as the stadium floor.
- **Surface Layer:** Cards and containers use a slightly lighter green (#0D2B1C). This "step up" in brightness indicates interactivity.
- **Ghost Borders:** For buttons or cards that require more definition, use a 1px solid stroke in `text-secondary` at 10% opacity.
- **Active States:** Instead of elevation, use the Neon Green (#4ADE80) accent as a bottom-border or left-accent "glow" to show which tournament or match is currently selected.

## Shapes
The shape language balances professional structure with organic curves reminiscent of a football pitch's markings. 

- **Cards & Modals:** Use `rounded-lg` (16px) to create a premium, modern feel.
- **Buttons & Inputs:** Use the base `rounded` (8px) to maintain a distinct "tappable" look that feels more precise than the larger containers.
- **Interactive Icons:** Small utility buttons (like "Close" or "Share") may use "Pill-shaped" (rounded-full) geometry to stand out against the rectangular grid.

## Components
- **Buttons:** Primary buttons use Grass Green with white text. Secondary buttons use a ghost style (border only). The "Live" button is a special case using Neon Green with a pulsating opacity animation.
- **Tournament Cards:** These should feature a 16px corner radius. Include a subtle, 10% opacity pitch-line pattern as a background texture to reinforce the football theme.
- **Chips:** Used for tournament status (e.g., "Open," "Ongoing," "Completed"). Chips are small (12px text), semi-bold, and use high-contrast backgrounds (Neon Green for "Live").
- **Match Lists:** Use a horizontal layout with team logos on either side of the score. The background for these rows should be the Surface color, separated by 1px dividers in the background color.
- **Input Fields:** Dark mode inputs use the Surface color for the fill with a 1px border. On focus, the border transitions to the Primary Grass Green.
- **Progress Bars:** Used for "Tournament Capacity" or "Game Time." These should be thin (4px) with a Neon Green fill and a dark, low-contrast track.