# Reel Records — Design System

> Extracted from the Claude Design prototype. These are the exact tokens and patterns the prototype
> uses; treat them as the v1 spec. Values map cleanly to SwiftUI (Color assets, a Theme struct, view
> modifiers). Update here first if the design changes.

## Design intent

**Premium fishing journal × modern tracking app.** Dark, tactile, photo-forward, calm. A single vivid
green accent against near-black surfaces; confident display type; monospace for data/labels. No noise,
no gamification.

## 1. Color

All colors from the prototype's CSS custom properties. Names in `code` are the prototype's; use them
as asset names.

### Surfaces / background
| Token | Hex / value | Use |
|-------|-------------|-----|
| page | `#060706` | outermost app frame (near-black) |
| `--bg` | `#0A0C0B` | primary screen background |
| `--s1` | `#121512` | card / tile surface |
| `--s2` | `#181C18` | input / control surface |
| `--s3` | `#20251F` | raised surface |

### Borders
| Token | value | Use |
|-------|-------|-----|
| `--bd` | `rgba(255,255,255,.07)` | default hairline border |
| `--bd2` | `rgba(255,255,255,.13)` | stronger border / emphasis |

### Brand green (primary accent)
| Token | Hex / value | Use |
|-------|-------------|-----|
| `--grn` | `#37E27B` | primary actions, active states, accent |
| `--grn2` | `#5FF29B` | lighter green (icons, hover, highlights) |
| `--grnk` | `#04220F` | "ink" — text/icons **on** a green fill |
| `--grnt` | `rgba(55,226,123,.12)` | green tint fill (chips, icon chips, badges) |

### Text
| Token | Hex | Use |
|-------|-----|-----|
| `--tx` | `#F1F4F0` | primary text |
| `--tx2` | `#9AA39C` | secondary text |
| `--tx3` | `#5C645D` | tertiary / placeholder / muted labels |

### Semantic
| Token | value | Use |
|-------|-------|-----|
| danger | `#ff8a8a` | destructive text (e.g. Sign out) |
| link | `--grn` / hover `--grn2` | text links |

### Signature gradients
- **App backdrop:** `radial-gradient(120% 90% at 50% -10%, #161c18 0%, #0a0c0b 55%, #060706 100%)`
- **Green hero card:** `linear-gradient(150deg, #143324 0%, #0f1c15 58%, #0c130f 100%)` + green border
- **Warm welcome/photo wash:** `radial-gradient(130% 82% at 50% 4%, #4d3c22, #2a2418, #10120d)`
- **Photo bottom scrim:** `linear-gradient(180deg, transparent 42%, rgba(6,8,6,.86))`

## 2. Typography

Three families (loaded from Google Fonts in prototype; bundle equivalents in-app).

| Role | Family | Weights | Notes |
|------|--------|---------|-------|
| Display (`--dsp`) | **Archivo** | 500–900 | headings, stat numbers, buttons. Tight tracking `-.02em` on big titles |
| Body | **Manrope** | 400–800 | paragraphs, list text, inputs |
| Mono (`--mono`) | **JetBrains Mono** | 400–700 | labels, badges, stats, dates, metadata |

### Type scale (observed)
| Use | Size / weight / family |
|-----|------------------------|
| Hero title (welcome) | 52px / 900 / Archivo, line-height .92 |
| Big stat number | 58px / 900 / Archivo (dashboard), 24–32px elsewhere |
| Screen title (h1/h2) | 30px / 800 / Archivo |
| Section heading (h3) | 17–18px / 700 / Archivo |
| Card title | 22px / 800 / Archivo (detail), 14–15px / 700 in lists |
| Body | 14–16px / 400–600 / Manrope |
| Micro-label | 11px / 700 / uppercase, letter-spacing `.06em`, color `--tx3` |
| Mono badge / meta | 10–12px / 600 / JetBrains Mono, letter-spacing `.1–.16em` when uppercase |

## 3. Shape & elevation

- **Radii:** pills `999px`; buttons `15–17px`; cards/sheets `18–24px`; inputs `14–15px`; small icon
  tiles `10–14px`.
- **Icon chip:** ~34px square, radius ~10px, `--grnt` fill, `--grn2` icon.
- **Shadows:**
  - Green glow on primary CTA: `0 8–10px 26–34px rgba(55,226,123,.28–.42)`
  - Card/sheet lift: `0 6px 14–20px rgba(0,0,0,.4–.55)`
- **Blur:** `backdrop-filter: blur(8–20px)` on the tab bar, floating chips, and photo-overlay controls.

## 4. Iconography

- **FontAwesome 6.5.2** (solid + regular) in the prototype.
- Recurring: `fa-fish` (brand), `fa-location-dot` (spots), `fa-trophy` (biggest), `fa-star`,
  `fa-water`/`fa-droplet`, `fa-worm` (lure), `fa-ruler` (length), weather set
  (`fa-sun`, `fa-cloud`, `fa-cloud-sun`, `fa-cloud-rain`, `fa-smog`, `fa-moon`), tab bar
  (`fa-house`, `fa-book`, `fa-map`, `fa-user`, `fa-plus`).
- **iOS note (decided):** **SF Symbols** are the primary icon source (native, free, weight-matched);
  bundle a custom/FontAwesome glyph only for the few shapes SF Symbols lacks (e.g. a good lure/worm).
  See `decisions.md`.

## 5. Spacing & layout

- Screen horizontal padding: **20–26px**. Top padding **54–66px** (clears the status bar / notch).
- Card padding: **13–22px**. Inter-card gap: **10–16px**.
- Device frame target: **402 × 874** (from the prototype's iOS frame hint — iPhone-class portrait).
- Safe-area aware; content scrolls under a fixed blurred tab bar.

## 6. Components

| Component | Spec |
|-----------|------|
| **Primary button** | full-width, 56–58px, `--grn` fill, `--grnk` text, Archivo 800, green glow, `scale(.98)` on press |
| **Secondary button** | translucent `rgba(255,255,255,.06)`, 1px light border, blur, white text |
| **Text input** | 52–54px, `--s2` fill, `--bd` border, left-aligned icon, focus → border `--grn`; uppercase micro-label above |
| **Chip / filter pill** | pill radius; active = `--grn` fill + `--grnk` text; idle = `--s2` + `--tx2` + `--bd` border |
| **Stat tile** | `--s1` card, icon chip, big Archivo number, `--tx2` caption |
| **Catch card (list)** | photo w/ gradient scrim, weight/length mono badges top-left, species + spot + date over photo, lure/weather footer |
| **Catch card (carousel)** | 166px wide, photo + weight badge + species + spot |
| **Map pin** | teardrop (`border-radius:50% 50% 50% 4px; rotate(45deg)`), `fa-fish` centered; selected = larger + `--grn` fill + ripple |
| **Tab bar** | 5 slots, blurred `rgba(9,11,10,.92)`, top hairline; center **FAB** (58px, green, raised `-24px`, 4px `--bg` ring) for Add Catch; active tab = `--grn`, idle = `--tx3` |
| **Bottom sheet** | full-height overlay, `--bg`, header with close (✕) + title, scroll body, pinned footer action; `sheetUp` entrance |
| **Badge (mono)** | small, `--grnt`/dark fill, JetBrains Mono, for weight/length/counts |
| **Tackle card** | `--s1` card; photo thumb with a mono **type badge** (top-left) + **color swatch** dot (top-right); name and `size · brand` in mono. The mockup's green **catch-count** pill belongs to post-v1 F4 unless reprioritized. See `mockups/tacklebox.html` |
| **Color swatch** | small circle (grid card ~18px) / rounded square (form ~50px), 1px light border, filled with the lure color |
| **Lure picker** | selected item as a bordered card + a horizontal row of item pills; dashed **+ New lure** pill (`--grnt`); "Manage Tackle Box" row |

## 7. Motion

Keyframes from the prototype — keep durations/easing:
- `fadeUp` — content enters +14px, .4s ease (screen/tab content).
- `sheetUp` — overlay slides from 101% → 0, .36s `cubic-bezier(.2,.8,.2,1)` (Add / Detail sheets).
- `fadeIn` — .3s ease (screen swaps).
- `pulseRing` — expanding ring on the selected map pin, 1.7s ease-out infinite.
- Press feedback: `transform: scale(.94–.98)` on active.

## 8. SwiftUI translation notes

- Encode tokens once as a `Theme`/`Color` asset catalog + a `Font` extension (Archivo / Manrope /
  JetBrains Mono as bundled custom fonts). Don't scatter literal hex values in views.
- Prefer **SF Symbols**; bundle custom fonts + any needed FontAwesome glyphs.
- App is **dark-only** in v1 — no light theme (decided; see `decisions.md`).
- Build reusable views mirroring §6 (PrimaryButton, FieldInput, Chip, StatTile, CatchCard, BottomSheet)
  so screens stay declarative.
