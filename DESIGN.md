---
name: Cyber-Metric
colors:
  surface: '#0d1515'
  surface-dim: '#0d1515'
  surface-bright: '#323b3b'
  surface-container-lowest: '#081010'
  surface-container-low: '#151d1d'
  surface-container: '#192121'
  surface-container-high: '#232b2c'
  surface-container-highest: '#2e3637'
  on-surface: '#dce4e4'
  on-surface-variant: '#b9caca'
  inverse-surface: '#dce4e4'
  inverse-on-surface: '#2a3232'
  outline: '#849495'
  outline-variant: '#3a494a'
  surface-tint: '#00dce5'
  primary: '#e9feff'
  on-primary: '#003739'
  primary-container: '#00f5ff'
  on-primary-container: '#006c71'
  inverse-primary: '#00696e'
  secondary: '#bcc7de'
  on-secondary: '#263143'
  secondary-container: '#3e495d'
  on-secondary-container: '#aeb9d0'
  tertiary: '#fdf9f9'
  on-tertiary: '#313030'
  tertiary-container: '#e0dddc'
  on-tertiary-container: '#626161'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#63f7ff'
  primary-fixed-dim: '#00dce5'
  on-primary-fixed: '#002021'
  on-primary-fixed-variant: '#004f53'
  secondary-fixed: '#d8e3fb'
  secondary-fixed-dim: '#bcc7de'
  on-secondary-fixed: '#111c2d'
  on-secondary-fixed-variant: '#3c475a'
  tertiary-fixed: '#e5e2e1'
  tertiary-fixed-dim: '#c9c6c5'
  on-tertiary-fixed: '#1c1b1b'
  on-tertiary-fixed-variant: '#474646'
  background: '#0d1515'
  on-background: '#dce4e4'
  surface-variant: '#2e3637'
  neon-cyan: '#00F5FF'
  deep-space: '#0D0D0D'
  slate-surface: '#1E293B'
  matrix-green: '#10B981'
  error-red: '#EF4444'
  muted-text: '#94A3B8'
typography:
  headline-lg:
    fontFamily: JetBrains Mono
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: JetBrains Mono
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: JetBrains Mono
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: JetBrains Mono
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: JetBrains Mono
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  code-block:
    fontFamily: JetBrains Mono
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 22px
  label-caps:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.1em
spacing:
  unit: 4px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 40px
  container-max-width: 1440px
---

## Brand & Style

The design system is a **Minimalist Futuristic** framework designed specifically for high-stakes technical environments. It targets backend engineers and modernization teams who value precision over decoration. 

The aesthetic is **"Cyberpunk-lite" Professional**: it borrows the high-contrast, data-heavy cues of science fiction interfaces but strips away the "grime" and clutter in favor of clinical precision. The personality is authoritative, sophisticated, and transformative—mirroring the product's ability to turn cryptic legacy code into clean, modern architectures. Visuals are defined by high-tech data visualization, sharp geometric shapes, and a dark-mode-first environment that reduces eye strain during deep work.

## Colors

The palette is rooted in a **Deep Space Black (#0D0D0D)** foundation to establish a boundless, high-contrast environment. **Neon Cyan (#00F5FF)** serves as the primary action color, utilized sparingly for focus states, primary buttons, and critical data points to simulate a "glowing" digital pulse.

**Slate Gray (#1E293B)** provides structural depth, used for container surfaces and card backgrounds to separate the UI from the void of the background. Status colors (Green and Red) are high-saturation but used only for semantic feedback (success/error), ensuring the "cybernetic" feel remains professional and functional.

## Typography

This design system uses **JetBrains Mono** (as the closest high-quality match to the 'Kode Mono' spirit) across all levels to maintain a strict "Code-as-UI" aesthetic. 

Headlines utilize tight letter spacing and heavy weights to feel like terminal headers. Labels are frequently set in all-caps with increased letter spacing to emulate hardware technical specs. Body text is optimized for readability within dense data tables and modernization reports. The monospaced nature of the entire system ensures that numerical data and SQL strings align perfectly, reinforcing the feeling of technical rigor.

## Layout & Spacing

The layout is governed by a **Strict 12-Column Fluid Grid** with generous margins to prevent the interface from feeling cramped. A 4px baseline grid ensures vertical rhythm across all components.

- **Desktop:** 12 columns, 24px gutters, 40px outer margins.
- **Tablet:** 8 columns, 16px gutters, 24px outer margins.
- **Mobile:** 4 columns, 12px gutters, 16px outer margins.

The spacing philosophy emphasizes "Functional Grouping." Use large gaps (32px+) between major modules (e.g., the SQL Input and the Python Output) to define the "Before & After" workflow. Inside components, use tight, precise padding (8px, 12px) to maintain a dense, tool-like feel.

## Elevation & Depth

Depth is achieved through **Tonal Layering and Subtle Glows** rather than traditional shadows. 

- **Level 0 (Background):** Deep Space Black (#0D0D0D).
- **Level 1 (Surfaces):** Slate Surface (#1E293B) with a 1px border of slightly lighter gray (#334155).
- **Active States:** Elements in focus or active status receive a "Cyber-Glow"—a 0px 0px 8px outer shadow using the Neon Cyan color at 30% opacity.
- **Overlays:** Modals use a backdrop blur (12px) to partially obscure the background, creating a "glass terminal" effect that keeps the user grounded in the data context.

## Shapes

The shape language is **Ultra-Sharp (0px radius)**. Every button, input field, and card container must have hard 90-degree angles. This choice reinforces the "precision tool" narrative and mimics the aesthetic of classic IDEs and command-line interfaces. 

Exceptions are made only for status indicators (like small "Check/X" circles), which should remain geometric and simple. Decorative elements, if used, should favor 45-degree angled corners (chamfers) to enhance the futuristic, high-tech vibe.

## Components

### Buttons
- **Primary:** Solid Neon Cyan background, Deep Space Black text, all-caps. No rounded corners. On hover: Add Cyan outer glow.
- **Ghost:** 1px Neon Cyan border, transparent background, Cyan text. 

### Input Fields (Code Editors)
- **Editor:** Deep Space background with a 1px Slate border. Active line highlighting in 10% Cyan.
- **Syntax Highlighting:** Use Neon Cyan for keywords, Matrix Green for strings, and Muted Slate for comments.

### Cards & Containers
- Containers must have a 1px border. For the "Modernization Report," use a header bar in Slate Gray to clearly separate metadata from the content body.

### Modernization Report Table
- Use thin Slate Gray hairlines between rows. 
- "Legacy" columns should have a subtle red-tinted background (5% opacity) and "Modern" columns a green-tinted background (5% opacity) to visually communicate the transformation.

### Status Chips
- Square-edged boxes with a 1px border and a small leading icon (Check/X). Use all-caps for the label.