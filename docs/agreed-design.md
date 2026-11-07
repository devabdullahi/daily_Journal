# Agreed design: Painted Journal

Agreed 2026-10-28 between Claude (Claude Code) and Codex after four rounds of debate (Codex replied "AGREED"). Supersedes the architecture in `../README.md` where they differ.

Product decisions by the user: daily → monthly chapter → year painting at the signup anniversary; the year painting must be recognizable; the daily painting appears instantly; no photos and no image-generation model; native iOS.

## Architecture (final)
1. iOS app (Swift/SwiftUI), local-first: entries saved locally first, always.
2. Reading (AI) is platform-specific, with three explicit user-visible modes: on-device (Foundation Models, when available and ready), opted-in cloud (Haiku; the user is told the text goes to Anthropic), and a private deterministic fallback. Output is one versioned `Reading` schema, treated as sensitive.
3. Planning and painting run in a shared Rust crate (`planner` beside the engine, behind a small UniFFI/C ABI), compiled for iOS and the Linux painter container. A plan parity test checks canonicalized plans across targets; engine determinism is tested separately.
4. Daily path: bounded request-response only. On devices/builds that passed the feasibility gate (#5) it's all local (read → plan → paint, live timelapse). Otherwise the cloud reads and plans with a hard timeout and the server paints, with honest progress.
5. A feasibility gate before committing to on-device painting: Swift↔Rust API spike plus measurements of render time, memory, thermals and battery on supported devices. Until it passes, server painting is the default path.
6. Backend: one TypeScript Worker as a modular monolith (auth, entries/sync, chapters, reveal, billing, shared). Thin: no art logic in TypeScript. D1 + R2. Table ownership is explicit; DB splitting waits until measured.
7. Chapter and year pipelines run as Cloudflare Workflows (gatherReadings → plan → paint → store → notify), with idempotency key (userId, artifactType, periodId, inputVersion), plus an outbox/reconciler so a committed period always gets a workflow. D1 painting status is authoritative. Queues are used only for fallback daily paint fan-out.
8. Chapters: stored anchor timestamp + timezone policy; a chapter for any period with ≥1 entry, labelled honestly; no chapter is fabricated for an empty period. Jobs don't depend on the app being open: the server works from synced Readings. Before chapter close the app shows pending-sync / missing-day status, with a grace window. Late-synced Readings revise a chapter (and the year plan) only if that artifact hasn't been delivered yet.
9. Year: closes chapter 12 on the anniversary, then paints. The reveal experience *begins* on the anniversary with a meaningful progress state. Recognizability comes from a small set of human-designed layouts with fixed big shapes and 12 explicit period slots. An empty period renders as an intentionally quiet slot, never a fabricated chapter. A constrained vision classifier (only if the user's processing choice covers it) is a quality signal with at most one retry; otherwise structural checks only.
10. Unreleased year art: server-side release authorization on every path (API, signed URLs, widget timelines, caches, logs, analytics). Tested at the API boundary.
11. Every painting stores engine version, plan version, Reading version, seed and status. Paintings are immutable once delivered; re-painting is an explicit user action creating a new version.
12. Entitlements: StoreKit 2 is the authority, validated server-side for protected server work. Superwall only for paywall experiments; RevenueCat only if Android ships.
13. Privacy: entry storage end-to-end encrypted where sync is enabled (scoped claims). Readings and derived chapter data are shared with the service and disclosed as such. No content in logs, analytics, crash reports or support tools. Retention + deletion + export defined. An honest device-loss/recovery story is shown before the user builds history.

## Feature implementation (final, short)
- Daily: as #4. Skippable timelapse from a versioned, size-capped stroke log with no text in it.
- Chapter: as #7–8. Appears when ready, with a "your month is ready" notification.
- Year: as #9–10.
- Widget: privacy-safe snapshot; lock-screen artwork/mood hidden by default (opt-in); never unreleased year data.
- Offline: write always works; painting waits for reading/planning availability with a clear state; drafts are never lost.
- Failure UX: failures never look like the user's fault, and never lose an entry.

## UX + monetization (final)
- No streak shame, no guilt notifications, no forced mood analysis. First painting in the first session, before any paywall.
- **Free:** unlimited entries, daily paintings, chapter paintings and the year painting at standard resolution, plus full export of entries and paintings. The whole story is free.
- **Pro (annual-first with a trial, monthly available, no weekly):** keepsake quality (high-resolution files, timelapse video export, the year reveal film, no watermark on shares), creative control (extra styles, re-paint, choosing the year layout), multi-device sync convenience. Lapsing never removes made paintings or export.
- **No physical products:** nothing is printed or shipped. Everything sold is digital.
- Paywall timing and price are experiments (after the first few daily uses vs. at the first chapter); trial and price terms always shown clearly. No ads.
- Launch quality gate: human ratings of real representative entries for recognizability, variety and emotional fit decide which compositions ship and what "instant" means.

## Code rules (final)
1. Product invariants are documented and tested at boundaries: entries are never lost; unreleased year art never leaks; no journal content in logs.
2. An ADR for every change to a boundary, schema or invariant.
3. One source of truth for cross-language schemas (Reading, PaintPlan, events), with code generated for Swift/TS/Rust; versioned; never hand-copied.
4. Golden-plan tests (canonicalized) and golden-image tests per engine version; visual changes are reviewed snapshot updates.
5. CI-enforced tooling: Swift (swift-format, SwiftLint, strict concurrency), TS (`strict`, no `any`, eslint, runtime validation of every request and queue/workflow payload), Rust (rustfmt, clippy -D warnings, no panicking unwrap on production/user paths; documented invariants allowed).
6. Swift: feature folders, small view models, declarative views; persistence/network/render/entitlements behind focused interfaces; explicit state enums; structured concurrency with cancellation; tested migrations.
7. TS: narrow module public APIs (index.ts only), one owner per table, authorization in services, idempotent handlers, outbox for DB+workflow consistency, versioned event schemas.
8. Rust wrapper: small stable UniFFI/C ABI; no Lua/MCP in the shipping app; pinned engine version recorded with outputs; bounded memory/canvas/strokes/time; explicit progress + cancellation; platform code only in the wrapper.
9. Simple types and explicit state transitions over clever abstractions; new dependencies need a stated reason.
10. Size guides (functions ~40 lines, files ~300) are review triggers, not bans.
11. Observability carries IDs, durations and statuses only.
12. Feature flags for new styles and paywall variants.

## Multiple entries per day (agreed in a follow-up debate, Codex replied "AGREED")
1. One painting per day. Chapters and the year are unchanged.
2. Day assignment: configurable cutoff (default 4am local), stored on the entry at creation; travel and timezone changes never move it.
3. Whole-day composition with ordered contribution slots: the first entry picks the composition; slot 1 is the main scene; later slots are reserved regions/motifs plus accent/glaze passes. When slots run out, entries only adjust accents within the budget. Slot designs are validated in the launch quality gate.
4. A per-day stroke/time budget, not an entry cap. Slot 1 gets the largest share, with decaying shares after it. Every entry informs the DayReading; the UI says the painting reflects the day as a whole.
5. Each entry has its own Reading, contribution plan, seed (entryId, version) and a slot fixed by creation order. Edits/deletes keep every other entry's plan and seed unchanged. A re-render is a new revision that may differ wherever strokes interact.
6. Every render shown is an immutable revision. The day points to its latest revision until close, then it's frozen. Intermediate revisions are deleted at close, and their plans remain for the timelapse.
7. Deleting an entry immediately and permanently deletes every revision containing it (storage, caches, signed URLs, timelapse). Only content-free provenance metadata is kept. Immutable = never silently changed, not never deleted on request.
8. DayReading (shared Rust crate, deterministic): motifs are kept per entry and combined with equal weight per entry (no length weighting); mood is an equal blend; chronological order is the tie-break; mixed reading modes are allowed; opting out of cloud reading never sends text.
9. Rendering: deterministic replay of the day's bounded plan from blank, benchmarked in the feasibility gate. Checkpoints only if they're engine-supported, versioned, deterministic and resumable.
10. Pending states: the entry is saved first; the previous revision is shown with a "painting will update" status; never shown as failed; never blocks writing. An entry that syncs after its day is delivered counts in the chapter.

## Paywall split (approved by the user, 2026-10-28)
| Feature | Free | Pro |
|---|---|---|
| Entries | Unlimited | Unlimited |
| Painted entries per day | 1 (extra entries saved and counted in the DayReading, no new strokes) | Unlimited, each adds to the day's painting |
| Paint palette | Starter set (~6 tubes) | Full pigment library |
| Painting styles | 2–3 compositions | All, plus seasonal |
| Timelapse | Watch in app | Video export, no watermark |
| Chapter paintings | Standard resolution | High resolution + chapter timelapse |
| Year painting | Revealed, standard resolution | High resolution, reveal film, choose the layout |
| Re-paint a day | No | Yes |
| Widgets | No | Yes |
| Mood insights | Last 7 days | Full history and trends |
| Cloud reading on older iPhones | Private fallback reader | Yes (Haiku) |
| Multi-device sync | No | Yes |
| Export of entries and paintings | Always | Always |

Never gated: the user's own data, made paintings, export, the existence of chapters and the year reveal.

## Visual design: "Quiet atelier" (agreed with Codex, 3 rounds, "AGREED")
Not oil-painting themed. A calm, native, editorial journal where the paintings are the only richly painted surfaces.
- Base color: the primed-canvas ground (warm off-white); dark mode = a deep charcoal "evening studio", designed separately.
- One restrained clay/ochre accent; the paintings supply the saturated color.
- Real paint only: every painterly accent is engine-rendered and pre-rendered as an asset (mood dabs, Pro pigment swatches, empty-state strokes). No stock brush textures.
- At most a subtle static grain on empty backgrounds; never behind text.
- Type: editor/reading in New York (system serif) by default with a switch to SF; controls/dates/labels in SF; serif titles for chapters/year; full Dynamic Type.
- Liquid Glass only for navigation and transient controls; content opaque. SF Symbols for actions.
- Motion: real brushwork is the main animation, always skippable and pausable; Reduce Motion respected. Sound off by default; one light haptic on save and on reveal-complete. One identity, no theme picker at launch.
- Framing grows with the story: day = unframed grid tile with an "Open"/"Final" status chip (the artwork never changes at close); chapter = thin frame; year = the one exhibition moment (full-bleed, then a gallery wall of 12 slots).
- Navigation: Liquid Glass tab bar with Today, Gallery, Insights; profile button on Today for settings/privacy/account; writing opens as a sheet.
- Onboarding: example painting, then writing; plain-language privacy; no paywall before the first painting.
- Year reveal: honest progress, reveal when ready, short transition set by prototyping, skippable, Reduce Motion = crossfade; the longer film is Pro replay/export.
- Insights is useful free (last 7 days of moods + the current period's colors); full history in Pro; never a mostly-locked screen.
- Paywall: artwork hero, visible benefits, clear price/trial terms.
- Never themed: body text styling beyond the serif choice, keyboard, settings, privacy, terms, standard nav.
- Test painting-forward vs writing-first App Store screenshots via Product Page Optimization.

## Drying and follow-ups (agreed with Codex, "AGREED")
The user's suggestion "dry 2 hours after an entry" was evaluated and rejected as a wall-clock rule, both as day's end and as a wet-blend window. Kept:
- Drying is a replay rule: each later contribution slot is painted as a session over dried paint (engine drying runs between slots in simulated time), so later entries read as crisp glazes/accents. Tied to slot order, never to elapsed time.
- "Continue this entry" edits that entry and updates its own contribution (new revision) without using a slot; free users can continue their one painted entry.
- The day closes only at its 4am cutoff; chips are "Open" / "Final".

## Travel and backdating (agreed with Codex, "AGREED")
- Each journal day has a pinned IANA timezone = the journal timezone in effect when the day began; empty days carry it forward; a detected device timezone change updates the journal timezone at the next day boundary. Store UTC timestamps + the IANA zone. Rejected: "the cutoff must pass in both zones".
- After a detected timezone change, the assigned date/timezone is confirmed once; then it's visible in entry details with a "change date" control.
- Backdating: any date in the current undelivered chapter period; creation time is kept separately; the user is told that a late entry for a day with a painting doesn't change that painting (it feeds the DayReading and chapter).
- Yesterday's empty day: until the next cutoff, a backdated entry may create that day's one painting (counts as the free painted entry; a final painting created late). Older empty days: included in the chapter, no daily painting.
- Chapter close happens no earlier than the later of the backdating deadline and the sync-grace deadline; late-sync handling for undelivered chapters is kept.
