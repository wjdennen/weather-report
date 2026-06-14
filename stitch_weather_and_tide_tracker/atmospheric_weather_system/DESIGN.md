---
name: Atmospheric Weather System
colors:
  surface: '#0f1418'
  surface-dim: '#0f1418'
  surface-bright: '#343a3e'
  surface-container-lowest: '#0a0f12'
  surface-container-low: '#171c20'
  surface-container: '#1b2024'
  surface-container-high: '#252b2e'
  surface-container-highest: '#303539'
  on-surface: '#dee3e8'
  on-surface-variant: '#bdc8d1'
  inverse-surface: '#dee3e8'
  inverse-on-surface: '#2c3135'
  outline: '#87929a'
  outline-variant: '#3e484f'
  surface-tint: '#7bd0ff'
  primary: '#8ed5ff'
  on-primary: '#00354a'
  primary-container: '#38bdf8'
  on-primary-container: '#004965'
  inverse-primary: '#00668a'
  secondary: '#bec6e0'
  on-secondary: '#283044'
  secondary-container: '#3f465c'
  on-secondary-container: '#adb4ce'
  tertiary: '#ffc176'
  on-tertiary: '#472a00'
  tertiary-container: '#f1a02b'
  on-tertiary-container: '#613b00'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#c4e7ff'
  primary-fixed-dim: '#7bd0ff'
  on-primary-fixed: '#001e2c'
  on-primary-fixed-variant: '#004c69'
  secondary-fixed: '#dae2fd'
  secondary-fixed-dim: '#bec6e0'
  on-secondary-fixed: '#131b2e'
  on-secondary-fixed-variant: '#3f465c'
  tertiary-fixed: '#ffddb8'
  tertiary-fixed-dim: '#ffb960'
  on-tertiary-fixed: '#2a1700'
  on-tertiary-fixed-variant: '#653e00'
  background: '#0f1418'
  on-background: '#dee3e8'
  surface-variant: '#303539'
typography:
  display-temp:
    fontFamily: Inter
    fontSize: 96px
    fontWeight: '200'
    lineHeight: 100px
    letterSpacing: -0.04em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  display-temp-mobile:
    fontFamily: Inter
    fontSize: 72px
    fontWeight: '200'
    lineHeight: 80px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  container-padding: 1.5rem
  stack-gap: 1rem
  section-gap: 2rem
  grid-gutter: 1rem
  safe-area-top: env(safe-area-inset-top)
  glass-padding: 1.25rem
---

## Brand & Style
The brand personality is ethereal yet precise, aiming to make weather data feel immersive rather than purely clinical. The design system leverages **Glassmorphism** and **Atmospheric gradients** to create a sense of looking through a window into the current environment. 

The target audience consists of design-conscious users who value both aesthetic beauty and immediate data clarity. The emotional response should be one of calm and awareness. Surfaces are layered using translucent materials, allowing the "sky" (background gradients) to bleed through the interface, creating a cohesive relationship between the data and the environment it describes.

## Colors
The palette is dynamic and reactive. While the functional tokens are fixed, the background of the application shifts based on meteorological conditions:
- **Clear/Sunny:** Transitions from #38BDF8 to #7DD3FC.
- **Overcast/Rain:** Deep muted grays and slate blues (#475569 to #1E293B).
- **Night:** Deep indigo to rich navy (#1E1B4B to #0F172A).

The default state is set to **dark mode** foundations to ensure that vibrant weather icons and white typography pop against the atmospheric backgrounds. Glass surfaces use a semi-transparent white tint to maintain legibility without masking the background gradients.

## Typography
This design system utilizes **Inter** for its neutral, highly legible character, allowing the atmospheric visuals to remain the focus. 

The hierarchy is dominated by a `display-temp` style for the current temperature, using a light font weight to evoke a modern, airy feel. Headlines are bold and tight to anchor data sections. Small labels often use uppercase tracking to differentiate supplementary data (like humidity or UV index) from primary narrative text. All type should be rendered in white or very high-contrast light grays to ensure readability over blurred glass backgrounds.

## Layout & Spacing
The layout follows a **fluid vertical stack** optimized for mobile interaction. A generous margin of `1.5rem` is maintained on the left and right edges of the screen to prevent data from feeling cramped against the device bezel.

Components are grouped into "Glass Modules." Spacing within these modules (`glass-padding`) is consistent to maintain a rhythmic internal structure. Large vertical gaps are used between the primary "Hero" weather state and the detailed forecast cards to provide visual breathing room. Grid-heavy data, such as hourly forecasts, should use horizontal scrolling (overflow-x) to keep the primary vertical scroll clean.

## Elevation & Depth
Depth is not communicated through traditional drop shadows, but through **Backdrop Blurs** and **Tonal Layering**.

1.  **Level 0 (Background):** The full-screen animated or static color gradient.
2.  **Level 1 (Surface):** The primary glass containers. They feature a `20px` to `40px` backdrop blur and a thin `1px` semi-transparent border to define their edges against the background.
3.  **Level 2 (Popovers/Modals):** These use a higher opacity glass or a subtle inner glow to appear "closer" to the user.

Avoid solid fills. The goal is to maintain a sense of "lightness" throughout the entire UI.

## Shapes
The shape language is friendly and organic. Standard glass modules use `1rem` (rounded-lg) corner radii to soften the data-heavy nature of the app. Interactive elements like buttons or search bars may lean towards `rounded-xl` to distinguish them as touch targets.

## Components

### Glass Cards
The core container for all weather data. Must feature a `backdrop-filter: blur(20px)` and a background color of `rgba(255, 255, 255, 0.1)`. The border is a `1px` solid `rgba(255, 255, 255, 0.2)`.

### Weather Icons
Icons must be thin-line (0.5pt to 1pt stroke) and monochromatic white. They should avoid complex fills to maintain the minimalist aesthetic.

### Buttons & Inputs
Search bars and interactive chips should use a slightly darker glass tint (`rgba(0, 0, 0, 0.2)`) to indicate interactivity. Text within inputs should be white with a `70%` opacity placeholder.

### Hourly/Daily Lists
Forecast lists should remove dividers in favor of generous spacing. If dividers are necessary, use a `1px` line with `10%` white opacity.

### Data Chips
Small, pill-shaped indicators for "High/Low" or "Alerts." Alerts should use the **Warning** or **Error** colors with a low-opacity background fill to keep the text readable while highlighting the urgency.