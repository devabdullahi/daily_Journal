# Living paintings: animating the scene

Agreed by Claude and Codex on 2026-10-28, after three rounds (Codex replied "AGREED"). This is a later feature: it comes after the iPhone engine optimization.

## Core idea

The engine paints once. The app brings chosen paintings to life cheaply at 60 fps. Re-running the paint physics per frame is far too slow, and AI video or image generation would break the no-image-generation rule and the oil-paint look.

## Who owns what

- **The shared Rust planner** emits an **animation manifest** next to each paint plan: which regions are eligible, their masks, effect parameters, sprite sets, counts, speeds and the seed. It's deterministic and versioned as its own artifact, linked to the `PaintPlan`, so animation fields can change without changing paint replay.
- **The app** owns the clock, accessibility behavior and rendering (one SwiftUI `Canvas` per painting, driven by one clock).
- **Eligibility, not default.** A painting animates only when the manifest marks a technique as eligible **and** its checks pass. Anything uncertain stays still.

## Techniques

### 1. Rain on a window (the first experiment)
- **Sprites from a fixed library.** Rain streaks, drops, snow and dust motes are painted by the engine **at build time**, in a few variants per motif and per pigment family, and shipped in the app. No engine pass per painting. Matching the scene means picking the nearest pre-painted pigment variant, never a recolor filter.
- **Clipped to the glass.** Clipped to the planner's glass mask, shrunk inward by a margin **measured from the visible painted frame in the render**, since paint can overrun the mask. The overlay never covers the frame.
- **Motion:** seeded speed (±20%), size, sideways drift and phase per drop; linear fall; opacity only at spawn and exit. Particle count is bounded in the manifest.

### 2. Fixed-window sky (the second experiment, gated)
- Content moves **inside** a fixed region whose boundary never moves. No cutouts, so nothing behind gets exposed.
- The sky is rendered once more by the engine as a wider strip: same plan chunks, **same coordinate system**, with **overscan larger than the maximum scroll**. It's generated off the critical path, after the daily painting is shown, or on the server.
- The app scrolls it a few pixels over 30–60 s inside an inset sky clip. A feathered horizon band is always taken from the final still, so the edge where foreground paint overlaps is never animated.
- Registration and every boundary are checked at real display size. If regions or margins can't be established reliably, that painting stays still.

### 3. Light (deferred, one test only)
One subtle lamp-light change (a glow breathing 2–3%) is tested against the still and the entry-fidelity checklist before any shader effect ships. Arbitrary distortion or shimmer shaders are deferred: they risk looking like a live filter and exposing mask edges.

## Rejected

- Cutting objects out of the final image and moving them: wet paint, overrun strokes and glazes make masks differ from the real pixels, which leaves seams, halos and exposed background.
- Moving painted objects or people. People stay still.
- Re-simulating paint physics per frame.
- AI video or image generation.

## Motion rules

From the motion skill and the Quiet-atelier design:
- One main motion plus at most 2–3 quiet loops; small amplitudes; calm easing; never teleport; loops close without a jump.
- The animation's first frame is **exactly** the still image.
- **Reduce Motion:** the still painting.
- Pause when off screen or in the background.
- Animation never adds an event the entry didn't describe (rain only if the scene has rain).
- Only the full-screen painting view animates. Gallery thumbnails, chapter and year paintings, and the widget stay still at launch.

## Checks per animated plan

- Static render matches the still.
- Reduce Motion shows the still.
- Mask-edge review at display size.
- Entry-fidelity checklist still passes.
- **Performance on the iPhone 17 Pro Max:** steady 60 fps, frame time, memory and battery measured, and no thermal rise over 5 minutes.

## Open decisions

- Free or Pro (not in the approved paywall split yet).
- Whether chapter and year paintings ever animate.
