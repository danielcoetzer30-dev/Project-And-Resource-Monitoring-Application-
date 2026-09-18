# Design system

How the app looks, and the rules for keeping it looking that way. Everything here
is already implemented in `lib/theme/` — this document explains it so nobody has
to reverse-engineer it from the code.

**The one rule that matters:** never hardcode a colour, font, size or spacing
value in a screen or widget. Use `Tokens.*` and `AppType.*`. If the value you
need doesn't exist there, add it there — then it exists everywhere.

---

## Direction

A dark instrument panel for a technical audience checking project health on the go.
Think fintech-ops rather than consumer app — calm and readable under a lot of live
data, with colour reserved almost entirely for meaning.

Three principles drive every decision below:

1. **Colour is meaning, not decoration.** The only saturated colours in the app are
   the four health states and one interactive blue. Nothing else is coloured.
2. **Status is never colour alone.** Every state renders as colour *and* icon *and*
   word. Colour-blind users, greyscale screens and glare all have to work.
3. **Numbers don't jitter.** Every numeric style uses tabular figures, so a
   live-updating metric holds its width as digits change.

---

## Colour

All colours live in `lib/theme/tokens.dart` as `Tokens.<name>`.

### Structure

| Token | Hex | Used for |
|---|---|---|
| `Tokens.shaft` | `#0D141B` | App background |
| `Tokens.seam` | `#151F29` | Panel and card surfaces |
| `Tokens.rule` | `#24313E` | Hairlines, dividers, gridlines, borders |
| `Tokens.chalk` | `#E6EDF3` | Primary text, large metrics |
| `Tokens.slate` | `#8697A8` | Labels, secondary text, axis text |

The base is blue-black rather than neutral grey. That's deliberate: it makes the
warm signal ramp below read as intentional rather than as tinting over grey.

Depth comes from stepping between `shaft` → `seam` and a one-pixel `rule` border.
**No drop shadows.** Shadows on a dark base turn to mud.

### Interactive

| Token | Hex | Used for |
|---|---|---|
| `Tokens.beacon` | `#4C9DD8` | Links, focus rings, selected tab, anything tappable |

Deliberately cool-blue and outside the warm health ramp, so "this is tappable"
can never be misread as "this is healthy". Use it for nothing else.

### Signal ramp — the four health states

| Token | Hex | State | Icon | Score |
|---|---|---|---|---|
| `Tokens.jade` | `#35A87C` | On track | `Icons.check_circle_outline` | ≥ 75 |
| `Tokens.brass` | `#D8A33A` | Watch | `Icons.trending_down` | 55–74 |
| `Tokens.ember` | `#E2703A` | At risk | `Icons.warning_amber_outlined` | 35–54 |
| `Tokens.flare` | `#E04B4B` | Critical | `Icons.error_outline` | < 35 |

The ramp runs cool → hot. It carries a temperature reading *and* a luminance
progression, which is why it survives red/green colour blindness far better than a
plain red/amber/green set.

**Don't reach for these tokens directly.** Go through `HealthState` in
`lib/models/health_state.dart`, which bundles colour, icon, label and severity
together — so you can't accidentally show a colour without its icon and word.
Render a state with the `StatusPill` widget, which does all three.

Score thresholds are a starting point. They'll move once interview data says
where the real boundaries sit; when they do, change them in `HealthState.fromScore`
and nowhere else.

### Tinted backgrounds

For a coloured background (a signal card, the load-shedding strip), use the state
colour at low alpha rather than a new token:

```dart
color: state.color.withValues(alpha: 0.12),          // fill
border: Border.all(color: state.color.withValues(alpha: 0.35)),
```

---

## Typography

Three typefaces, three jobs. All from Google Fonts via the `google_fonts` package.
Styles live in `lib/theme/typography.dart` as `AppType.<name>`.

| Face | Job | Why |
|---|---|---|
| **Archivo** | Structure — titles, headings, big numbers | Industrial grotesk, holds up compressed and heavy |
| **IBM Plex Sans** | Prose — body text, labels | Slight humanist warmth stops Archivo reading cold |
| **IBM Plex Mono** | Data — timestamps, deltas, IDs, anything that changes | Monospaced and tabular, so live values stay put |

**Inter is not used anywhere. Don't introduce it.**

### Type scale

| Style | Face | Size | Weight | Notes |
|---|---|---|---|---|
| `AppType.display` | Archivo | 26 | 700 | Screen titles. Tracking −0.6 |
| `AppType.heading` | Archivo | 17 | 600 | Section headings, project names |
| `AppType.metric` | Archivo | 34 | 700 | Health scores, big counts. Tabular. Tracking −1.2 |
| `AppType.metricSmall` | Archivo | 20 | 700 | Secondary numbers. Tabular |
| `AppType.body` | Plex Sans | 14 | 400 | Default text, `chalk` |
| `AppType.bodyMuted` | Plex Sans | 14 | 400 | Secondary text, `slate` |
| `AppType.bodyStrong` | Plex Sans | 14 | 500 | Emphasised body |
| `AppType.label` | Plex Sans | 11 | 600 | Uppercase panel headers, axis labels. Tracking +0.8, `slate` |
| `AppType.data` | Plex Mono | 12 | 500 | Timestamps, deltas, identifiers. Tabular, `slate` |
| `AppType.dataStrong` | Plex Mono | 12 | 500 | Same, in `chalk` |

Large display sizes use tight negative tracking; small labels use loose positive
tracking. Don't override tracking on a style — pick the style that already has it.

To recolour a style, use `copyWith`:

```dart
Text(score, style: AppType.metric.copyWith(color: state.color))
```

---

## Spacing and shape

| Token | Value |
|---|---|
| `Tokens.space1` | 4 |
| `Tokens.space2` | 8 |
| `Tokens.space3` | 12 |
| `Tokens.space4` | 16 |
| `Tokens.space5` | 24 |
| `Tokens.space6` | 32 |
| `Tokens.space7` | 48 |

Screen padding is `space4` on the sides. Gap between panels is `space3` or `space4`.
Inside a panel, `space4`.

| Token | Value | Used for |
|---|---|---|
| `Tokens.radiusSm` | 4 | Chips, pills, small controls |
| `Tokens.radiusMd` | 6 | Panels, cards, list rows |
| `Tokens.radiusLg` | 10 | Rarely — large containers |
| `Tokens.hairline` | 1 | Every border and divider |

Radii are small on purpose. This is an instrument panel, not a card grid — don't
round things off further.

---

## Components

Reuse these before writing new ones. They live in `lib/widgets/`.

### `Panel`
A `seam` surface with a `rule` border and `radiusMd`. Optional uppercase title in
`AppType.label`, with a hairline divider below it. This is the container for
almost everything.

### `StatusPill`
Renders a `HealthState` as colour + icon + label together — the only sanctioned
way to show a state. `compact: true` drops the word for dense rows where the label
is adjacent anyway.

### `HealthSeam`
The signature component. A segmented horizontal band, one segment per day or
sprint, coloured by the state it was in, with a white notch above any period where
a risk flag fired. Reads left→right as *trajectory*, not snapshot — the point is
seeing "drifting for nine days", not just "currently at risk".

- On list rows: `height: 22`, no axis
- On detail screens: `height: 40`, `showAxis: true` for dated labels at each end

It exposes the trend to screen readers as a sentence rather than a list of colours.

### Capacity bar (in `squads_screen.dart`, to be extracted)
100% sits at a fixed white marker roughly three-quarters along the bar, not at the
end — so over-allocation renders as visible overflow past the mark rather than as
a merely full bar.

---

## Platform conventions

Material 3 on Android (`NavigationBar`, `InkWell` ripples). Cupertino navigation
cues on iOS. One visual identity across both — same palette, type and iconography.
Don't build two differently-styled apps.

Keyboard focus is always visible (`beacon`). Reduced-motion preferences are
respected. These are part of the quality floor, not extras.

---

## Copy

Words are design material. Write from the user's side of the screen:

- **Name what people recognise**, not how the system is built. A person manages
  *notifications*, not *webhook config*.
- **Active voice; buttons say what happens.** "Save changes", not "Submit".
- **Errors say what went wrong and how to fix it.** No apologies, no vagueness.
- **An empty screen is an invitation to act**, not a blank.
- **Signals explain their reasoning.** An unexplained score is what makes
  monitoring feel like surveillance. Every `Signal` has a required `because` field
  for exactly this reason.

Vocabulary: it's a *signal*, not an *alert*. It's a *squad*, never a *person*.
The tool is diagnostic and supportive; the words should never sound punitive to the
team being measured.

---

## Things that would break the system

- Hardcoding a hex value or font in a widget
- Using a signal colour decoratively, or for anything that isn't a health state
- Showing a state as colour only, without `StatusPill`
- Adding a fifth brand/accent colour
- Introducing Inter, or any face not in the three above
- Drop shadows
- Larger border radii
- Per-person metrics anywhere in the UI (see the research proposal, Section D)
