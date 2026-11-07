# Painted Journal (working name)

An iOS journal where every day becomes a small oil painting. Each month, that month's days become one larger **chapter painting**. On the user's one-year signup anniversary, the twelve chapters are woven into one big, recognizable **year painting**: the bigger picture they didn't know they were building.

```
Day    → small painting of that day's entry        (painted instantly)
Month  → chapter painting from that month's days   (12 period slots a year)
Year   → one painting woven from the 12 chapters   (reveal begins on the signup anniversary)
```

All paintings are made with the [claude-paint](https://github.com/aliceisjustplaying/claude-paint) oil-paint engine (Rust, MIT). No photos and no image-generation model are used: an AI reads the entry, a shared Rust planner plans, and the engine paints.

> **Source of truth:** [`docs/agreed-design.md`](docs/agreed-design.md), agreed by Claude and Codex on 2026-10-28 after four rounds of debate. This README explains the *why* behind it.

## How each level is made

| Level | Read by | Planned + painted by | Where |
|---|---|---|---|
| Day | On-device Apple Foundation Models; else opt-in Claude Haiku; else a private fallback | Shared Rust planner + engine | On the iPhone if it passed the feasibility gate, otherwise the server. Request-response with a hard timeout |
| Chapter | Synced `Reading`s for that period | Shared Rust planner + engine | Server, as a Cloudflare Workflow at each user's period close |
| Year | The 12 chapter readings | Shared Rust planner + engine, into a human-designed layout with 12 slots | Server, after chapter 12 closes on the anniversary |

**Why the year painting is always recognizable:** it is painted fresh into one of a few human-designed layouts with fixed big shapes (horizon, landmark silhouette, focal figure) and 12 explicit period slots. Recognizability comes from the layout, not from luck. A month with no entries is an intentionally quiet slot, never a fabricated chapter. An optional vision check (only if the user's processing choice covers it) is a quality signal with at most one retry, not the guarantee.

**Months are counted from the signup date**, with a stored anchor timestamp and timezone policy, so the 12 periods line up exactly with the anniversary.

### Multiple entries per day

A day always has **one painting**. The first entry picks the day's composition. Each later entry fills the next reserved slot (a sky band, a foreground object, a light source) or adds accents, within a daily stroke and time budget, so the painting settles instead of turning muddy. The day ends at a configurable cutoff (default 4am local). Every shown render is an immutable revision until the day closes. Deleting an entry permanently deletes every revision that contains it. Full rules: [`docs/agreed-design.md`](docs/agreed-design.md#multiple-entries-per-day-agreed-in-a-follow-up-debate-codex-replied-agreed).

## Architecture styles

| Level | Style |
|---|---|
| Overall system | Event-driven background work (Workflows); request-response for anything the user waits on |
| Deployment shape | Modular monolith (one Cloudflare Worker) + one separate Rust painter container |
| Inside the Worker | Layered: routes → services → data access. No art logic |
| Planning + painting | One shared Rust crate, compiled for iOS and the Linux painter |

### Event-driven, with durable Workflows (overall system)

| Trigger | Handled by | Result |
|---|---|---|
| Entry saved (request-response) | Phone, or Worker + cloud reading | Daily painting, painted at once |
| `PeriodClosed` (daily schedule, per user) | Chapter Workflow | gather Readings → plan → paint → store → notify |
| `AnniversaryReached` (daily schedule, per user) | Year Workflow | close chapter 12 → plan → paint → hold behind the reveal gate → notify |
| `FallbackPaintRequested` | Queue → painter | Daily painting for devices that haven't passed the gate |

#### Why event-driven for the system

Chapter and year paintings happen *after* the user does anything, on each user's own calendar. That work is slow, can fail, and must eventually succeed, so it runs as background jobs instead of direct calls.

1. **The user never waits on long work.** Chapters and years run in the background and announce themselves. The daily painting is the exception on purpose: it's request-response with a hard timeout, because the user is watching.

2. **Durable steps instead of hand-built chains.** Cloudflare Workflows persist each step's result and retry failures. A crashed painter or timed-out AI call resumes where it stopped, instead of us building our own job state machine.

3. **Nothing gets skipped.** Queues and Workflows deliver at least once, and starting a Workflow isn't atomic with writing to D1. A small outbox plus a reconciler guarantees every closed period gets its Workflow. Idempotency keys `(userId, artifactType, periodId, inputVersion)` mean a retry never paints twice.

4. **Load spreads itself.** Periods close and anniversaries arrive on each user's own dates, so the work is spread across the calendar instead of spiking on one day.

5. **New reactions without touching old code.** A weekly recap or a share prompt can react to "chapter painted" without changing the pipeline.

**The trap, and the rule against it:** event-driven systems get hard to follow when everything fires events. Our rules:
- **Only slow, retryable or fan-out work is asynchronous.** Anything the user waits on stays request-response.
- **Every trigger has exactly one owner**, listed in the table above.
- **D1's painting status is the source of truth** for what the user sees, not the queue or the Workflow.

**Alternatives considered:**

| Option | Why not |
|---|---|
| Daily planning through the queue (our first design) | Broke "instant": the phone couldn't start painting until a background job returned |
| Hand-rolled queue chains + outbox + state machine | Workflows give durable steps and retries for free; we keep only a small outbox/reconciler |
| Everything request-response | Chapter and year jobs would be fragile, with nothing to retry them |

### Modular monolith + painter (deployment shape)

All TypeScript ships as **one Cloudflare Worker**, split into modules with hard boundaries:

```
src/
  auth/      sign-in, accounts
  entries/   sync of entries (encrypted) and Readings
  chapters/  period boundaries, chapter Workflows
  reveal/    year Workflow, release authorization
  billing/   StoreKit 2 entitlement validation
  shared/    db, storage, queue, workflow helpers
```

The **Rust painter container** runs the shared planner + engine for chapters, years and daily fallbacks.

#### Why a modular monolith + painter

1. **A small team gets one of everything.** One codebase, one deploy, one set of logs.
2. **No network between modules.** `chapters/` calls `entries/` as a function, with no timeouts or version skew.
3. **One Worker covers every entry point.** `fetch` (API), `queue` and `scheduled` handlers live in the same script, and Workflows are bound to it.
4. **The Worker stays thin.** There's no art logic in TypeScript at all. That lives in the shared Rust crate, so the Worker is only sync, storage, scheduling, entitlements and the reveal gate.
5. **Splitting stays possible.** Modules talk through small interfaces and own their tables, so any one can be lifted out later.

**Why the painter is separate:** it's Rust, CPU-heavy, and scales on a different curve from the API.

**Security note:** the module boundary around `reveal/` is for maintainers. **The surprise is protected by the server:** release authorization is checked on every path (API, signed URLs, widget timelines, caches, logs, analytics) and tested at the API boundary.

**The trap, and the rule against it:** modules reaching into each other's tables "just this once". Our rules: public `index.ts` only, one owner per table, authorization in services.

**Alternatives considered:**

| Option | Why not |
|---|---|
| Plain monolith | No boundaries, so the code tangles as it grows |
| Microservices | Many deploys and network failures for a small team that gains nothing from it |

### Layered (inside the Worker)

```
Routes       HTTP handlers: /entries, /readings, /chapters, /reveal
   ↓
Services     sync entry, close period, authorize release, check entitlement
   ↓
Data access  D1 queries, R2 signed links, queue sends, workflow starts
```

#### Why layered for the Worker

1. **Same logic, several entry points.** HTTP, queue, scheduled and Workflow handlers all call the same services, so the rules live once.
2. **The database can change in one place.** If D1 is ever split (only when measured), only the data-access layer changes.
3. **Testable rules.** Services are tested with a fake database: "a period with one entry still gets a chapter", "the year painting is never returned before release", "a lapsed subscriber can't re-paint".
4. **Clear security checkpoints.** Routes check who is calling; services check what's allowed, including authorization; data access uses parameterized queries only.
5. **Simple and familiar**, with no special framework.

**The trap:** empty pass-through layers. **Rule:** a service exists only if it holds a real rule.

### Shared Rust planner (planning + painting)

```
reading (from any reader) ──▶ plan(reading, level, canvas, seed) ──▶ PaintPlan ──▶ paint(plan) ──▶ image + stroke log
```

One Rust crate beside the engine, behind a small UniFFI/C interface, compiled for iOS and for the Linux painter.

#### Why one planner in Rust

1. **No drift.** The phone and the server plan dailies (and the server plans chapters and years). Two implementations, one in Swift and one in TypeScript, would drift apart. One crate can't.
2. **Testable parity.** A parity test checks that the same `Reading`, seed and versions give identical *canonicalized plans* on both targets. Engine determinism is tested separately, since byte-identical images across CPU architectures are a weaker promise.
3. **Reading is separate from planning.** AI reading is platform-specific (Foundation Models, Haiku or the fallback), but all three produce one versioned `Reading` schema. Planning is deterministic code.
4. **Provenance.** Every painting stores its engine, plan and Reading versions, its seed and its status. Delivered paintings never change; re-painting makes a new version.

**Why we dropped the plug-in framework:** an earlier design made the planner a microkernel with a plug-in registry. We replaced it with a plain static list of a few strong compositions behind one `compose` signature. A framework is machinery before there's variety to manage, and a few well-tested compositions beat many weak ones. Which compositions ship is decided by the launch quality gate.

### Styles and designs considered and rejected

| Style or design | Why not |
|---|---|
| Space-based | Built for huge simultaneous contention. Our bottleneck is painter CPU, not shared data |
| Microservices | Too much operational cost for a small team |
| Strict layered (whole system) | Forcing image downloads and jobs through the API adds latency and cost |
| Planner as a TypeScript plug-in microkernel | It would need a second copy on the phone; framework before variety |
| Hidden picture planned at signup, with tiles nudged as a mosaic | ~365 tiles is only about a 19×19 grid, too fragile for recognizability; it makes daily paintings less honest; the secret can leak |
| Mosaic assembled from daily tiles at the end | Can't guarantee a recognizable picture |
| Image-generation model | A different look from the oil paintings, plus an extra vendor |
| Year painting pre-painted before the anniversary | The final chapter's entries don't exist yet |

## Privacy

- Three reading modes, chosen by the user: **on-device**, **opted-in cloud** (Haiku, with a plain notice that the text goes to Anthropic), and a **private fallback**.
- Entry storage is end-to-end encrypted where sync is on, and claims are scoped to exactly that. Readings and chapter data are shared with the service and disclosed as such.
- No journal content in logs, analytics, crash reports or support tools.
- Defined retention, deletion and export; an honest device-loss/recovery story shown before users build history.

## Platform

- **Client:** native iOS, Swift / SwiftUI, local-first; StoreKit 2; a WidgetKit widget (privacy-safe, hidden on the lock screen by default)
- **Backend:** Cloudflare Workers, Workflows, D1, R2, Queues (fallback paints only), Containers (painter)
- **AI reading:** Apple Foundation Models on device; Claude Haiku as the opt-in cloud reader
- **Painting:** the shared Rust planner + claude-paint engine. On device only after the feasibility gate passes

## Diagrams

- [`architecture.mmd`](architecture.mmd): system overview
- [`nightly-flow.mmd`](nightly-flow.mmd): daily, period-close and anniversary flows
- [`planner.mmd`](planner.mmd): the shared Rust planner

## Open questions

- Pricing numbers (Pro annual and monthly, trial length)
- Android: later or never
- Exact retention periods
- Engine speed: daily on iPhone (the feasibility gate), chapter and year sizes on the server
