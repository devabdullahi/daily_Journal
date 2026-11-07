# Engine build optimization log

Started 2026-10-28. This file records every speed change made to our fork of the [claude-paint](https://github.com/aliceisjustplaying/claude-paint) engine, with its measured result and whether it changed the picture.

## Summary

No speed-up yet. Step 1 (whole-program compiler optimization) made no difference: the paintings were byte-identical and about 2–4% slower, so it was rejected. The engine's speed is limited by its own code (the per-bristle paint exchange and memory churn), not by compiler settings, so the next steps change that code.

## Goal and rules

The goal is a good-looking daily painting in 5–7 s on iPhone, with the first strokes on screen within 1 s, without losing quality. The rules come from the quality gate agreed with Codex (`engine-tests/QUALITY-GATE.md`).

- **Exact changes first.** Compiler settings, memory fixes and inner-loop rewrites must produce the same painting. "Same" uses the engine's own rule from `engine/notes/workflow.md`: every pixel's channels within **2 of 255** of the reference, same dimensions, checked by `engine/scripts/compare_images.py`. Compiler settings are checked too, never assumed safe.
- **Approximate changes later, one at a time.** Fewer bristles, cheaper plans or smaller canvases must keep the painting faithful to the journal entry (the per-entry checklist), judged by a blinded vision-model screen with human adjudication.
- **Measure honestly.** At least 5 runs per configuration, median and spread reported, one change per step against a preserved baseline.
- **Keep attribution.** The engine is MIT-licensed; the fork keeps `LICENSE` and `THIRD_PARTY_NOTICES.md`.

## Setup

All work happens in a fork of the engine, measured on an Apple M4 Mac (10 cores). iPhone measurements follow on the iPhone 17 Pro Max.

| Item | Where | Notes |
|---|---|---|
| Fork | `daily_Journal/engine` | Branch `perf`, on top of `ios-spike` (adds the iOS static library and its C entry point `easel_run_c`) |
| Build output | Internal disk (`CARGO_TARGET_DIR`) | Keeps compiles fast and avoids macOS `._` files on the exFAT drive, which break git |
| Benchmark script | `engine-tests/bench.sh` | Runs a plan N times, prints median, min, max and a hash of the output image; `OUT=<dir>` keeps the images |
| Test paintings | `engine-tests/scripts/bench_v3c.lua` (failed-exam room), `bench_v2.lua` (sunset street) | Both carry the engine 9 log header, so the current engine runs, not legacy mode |
| Exactness check | `engine/scripts/compare_images.py` | The engine's own 2/255 per-pixel rule |

## Baseline

On the current engine (engine 9), a 512 px daily painting takes about 27.5 s on the M4 Mac. That's twice the earlier legacy-mode numbers.

| Painting | Width | Runs | Median | Min | Max |
|---|---|---|---|---|---|
| v3c, failed-exam room | 512 px | 5 | 27.47 s | 27.33 s | 27.98 s |
| v2, sunset street | 512 px | 5 | 27.53 s | 27.49 s | 27.99 s |

**Why it differs from the earlier tests:** the first tests (2.6–14 s at 512 px) ran without the log header that names the engine version, so the engine fell back to legacy behavior with fewer physics features. Engine 9 simulates more (knife skim, carried palette paint, liquid film levels and more), and that costs time. All numbers from here on use engine 9.

## Step 1: compiler build profile

A new `phone` build profile in `engine/Cargo.toml`, used for the shipping app and the server painter. The engine's own `release` profile is left unchanged, so it stays the baseline.

```toml
[profile.phone]
inherits = "release"
incremental = false   # release had incremental on, which splits code into pieces the optimizer can't see across
codegen-units = 1     # compile the whole crate as one unit so functions can be inlined across modules
lto = "fat"           # link-time optimization across the engine, Lua and every dependency
```

Not changed: `panic` stays `unwind`, because the engine uses `catch_unwind` (9 places).

**Result: rejected.** It was no faster, in fact slightly slower, and the output was identical.

| Painting | Baseline median | `phone` profile median | Change | Pixels changed |
|---|---|---|---|---|
| v3c | 27.47 s | 28.22 s (min 28.08, max 28.29) | +2.7% slower | 0 of 262,144 (byte-identical) |
| v2 | 27.53 s | 28.70 s (min 28.47, max 29.01) | +4.2% slower | 0 of 262,144 (byte-identical) |

Why it likely didn't help: the time is spent in a few hot functions that the normal release build already optimizes within their own module, so cross-module inlining has little to add, and a different code layout can cost a little. The `phone` profile stays in `Cargo.toml` for later re-testing after the code changes, but it isn't used.

## Ledger

| # | Change | v3c median | v2 median | Speed-up | Pixels within 2/255? | Status |
|---|---|---|---|---|---|---|
| C0 | Baseline (engine `release` profile) | 27.47 s | 27.53 s | — | reference | — |
| C1 | `phone` profile: LTO fat, 1 codegen unit, no incremental | 28.22 s | 28.70 s | none (2.7–4.2% slower) | yes, byte-identical | rejected |

## How to reproduce

Run from `daily_Journal`, with `CARGO_TARGET_DIR` pointing at a folder on the internal disk.

```bash
# baseline build (the engine's release profile)
cargo build --release -p easel --manifest-path engine/Cargo.toml

# optimized build (the phone profile)
cargo build --profile phone -p easel --manifest-path engine/Cargo.toml

# time 5 runs of each test painting at 512 px, keeping the images
cd engine-tests/scripts
OUT=/tmp/renders/C0 ../bench.sh "$CARGO_TARGET_DIR/release/easel" C0 5 512 bench_v3c.lua bench_v2.lua
OUT=/tmp/renders/C1 ../bench.sh "$CARGO_TARGET_DIR/phone/easel"   C1 5 512 bench_v3c.lua bench_v2.lua

# exactness: every pixel within 2/255 of the baseline
python3 ../../engine/scripts/compare_images.py /tmp/renders/C0/bench_v3c.png /tmp/renders/C1/bench_v3c.png
```

## Next steps

All remaining exact steps target the bristle paint exchange. Profiling showed that's where nearly all painting time goes.

1. **Memory fixes:** reuse storage for each pixel's paint layers instead of allocating and freeing it on every bristle touch. Lossless by default; checked with the 2/255 rule.
2. **Inner loops:** tighten `bristle::exchange`, `Surf::add` and `Surf::take` (hoist per-stroke constants, remove repeated `powf`/`exp`, check auto-vectorization).
3. **Parallel strokes (experiment):** map which bristle updates are independent before trying it; keep only a measured net gain.
4. **iPhone measurement:** rebuild the iOS library with the winning settings and rerun the EngineBench app on the iPhone 17 Pro Max.
5. **Then the approximate levers,** one at a time under the quality gate: cheaper plans, fewer bristles, canvas size.
6. **Afterwards:** the queued feature, animating the painted scene.

## iPhone: reaching a consistent ~30 s (agreed with Codex, 2026-10-28)

**Problem:** on the iPhone 17 Pro Max, most steps run at Mac speed, but some run 5–20× slower (the cone: 76 s vs 3.6 s on the Mac; the clouds: 110 s), and one run was terminated by iOS after >15 minutes. On the Mac the same paintings take ~30 s, so ~30 s on the phone means removing the phone-specific slowdowns.

**Hypotheses (not yet confirmed):** rayon worker threads getting low QoS and running on the efficiency cores; thermal throttling across back-to-back runs; memory pressure or jetsam; an iOS-specific code or build difference.

**Plan:**
1. **Parity check:** identical plan, seed, engine-9 header, width, build mode and features on Mac and iPhone, compared chunk by chunk (including the v7 clouds chunk on the Mac).
2. **Instrumented baseline on the iPhone:** per-chunk wall and CPU time, per-thread CPU and QoS, thread count, blocked time, thermal state every second, memory footprint and pressure, and jetsam/crash reports after each run. An Instruments Time Profiler capture of the cone and clouds chunks on the device. A cold run plus a realistic sustained sequence, ≥5 repeats each, with spread reported.
3. **Inspect** iOS-specific build settings and conditional code, and the generated code for the hot bristle path on iOS vs macOS.
4. **Then one variable at a time:** rayon worker QoS; pool sizes {2, 3, 6}. A setting is kept only if repeated runs improve and the 2/255 replay rule holds.
5. If the remaining cost is serial (the bristle exchange), the agreed engine code optimizations continue.

**Acceptance:** median ≈ 30 s with < 10% spread on the fixed daily plan, under the repeated-run protocol, with the replay gate intact and no terminations.

## Target update (2026-11-01)

About 30 s per daily painting is the goal, on the phone as on the Mac: the user should watch the painting being built. The earlier 5–7 s goal is dropped, and with it the approximate levers (smaller canvas, fewer bristles) and a Metal rewrite. Server painting stays the default until a device passes the feasibility gate (`docs/agreed-design.md`).

## iPhone parity results (2026-11-01)

Same engine-9 plans, width 512, release build of this fork on both machines. The EngineBench app now links `$HOME/Library/Caches/dj-target/aarch64-apple-ios/release` (it had been linking a deleted copy of the engine from another session, and its bundled plans had no engine-9 header).

**The 5–20× outliers were app suspension, not the engine.** iOS suspends every thread of an app that leaves the screen. A run where the app was switched away stalled in its sixth chunk (the thread sampler, which does no painting, stopped too). With the app kept on screen, no chunk is more than 1.6× slower than on the Mac. The shipping app must keep painting off-screen (a background task) or pause and resume visibly.

| Plan | Mac M4, 3 runs | iPhone 17 Pro Max, 3 runs | Ratio |
|---|---|---|---|
| v7 park ice cream | 29.5–29.9 s | 41.1–43.9 s | 1.45× |
| v3c failed-exam room | 27.6–28.0 s | 41.4–43.3 s | 1.52× |

Every chunk is 1.35–1.57× slower; the slowest is the grass chunk (v7 chunk 6: 10.9 s Mac, 16–17.5 s iPhone). Thermal state stayed nominal. The iPhone output is byte-identical to the Mac's (0 of 262,144 pixels).

**The engine keeps about two cores busy.** Mac: 58 s CPU in 29 s. iPhone: 545 s CPU in 255 s over six paintings. Rayon's workers run at `QOS_CLASS_DEFAULT` (priority 31): Darwin threads don't inherit the app's user-initiated QoS.

**Worker count and QoS** (`EASEL_THREADS`, `EASEL_QOS`, read once by `easel_run_c`; unset = rayon defaults), v7 plan, 3 runs each, run in this order:

| Config | Threads | Worker QoS | Runs | Thermal |
|---|---|---|---|---|
| P0 | 6 | default | 41.1, 43.6, 43.9 s | nominal |
| Q6 | 6 | user-initiated | 38.7, 41.8, 43.4 s | nominal |
| Q2 | 2 | user-initiated | 51.9, 51.5, 51.7 s | nominal → fair |
| D2 | 2 | default | 52.0, 52.2, 53.3 s | fair |
| Q3 | 3 | user-initiated | 48.9, 48.3, 48.2 s | fair |

- Fewer threads are slower: the efficiency cores contribute, and two workers on the two performance cores lose ~20%. Keep all 6.
- User-initiated QoS helps a little on a cool phone (first run −2.4 s); the effect fades over back-to-back runs. Kept for the app, but not a fix.
- Times rise from run to run within a config even at nominal thermal state, and peak memory grows 343 → 411 MB over six paintings in one process. Both need a look (a leak would matter for jetsam).

**Profile on the iPhone** (Instruments Time Profiler, one v7 painting): 95% of engine time is inside `engine7::exchange::contact`, the bristle–canvas exchange. About 30% is memory work on the paint-layer stacks (malloc/free, memmove, dropping `Vec<Layer>`, cloning), with `Latent::blend_parts`, `from_layers` and `split_top` the heaviest functions. A count on one painting: ~290 million pixel paint operations, ~150 million of them on layered pixels (usually 2 layers), each latent holding 2–9 tube parts, about a billion heap allocations in all.

## Step M1: move the pixel's layers instead of copying them (kept)

`Surf::take_with_lat` and `Surf::lay_layers` split a pixel's layer stack and rebuild the pixel from the halves. They cloned the whole stack first (`Latent::split_top` → `layers()`), then threw the original away. Now the pixel's latent is moved out (`mem::take`) and split in place (`Latent::split_top_owned`, `into_layers`): same values, same arithmetic in the same order. `from_layers` also reserves room for the tube parts up front. Other callers keep the copying `split_top`.

| | v7 Mac (M4) | v7 iPhone 17 Pro Max | Pixels changed |
|---|---|---|---|
| Before (C0 / P0) | 29.5–29.9 s | 41.1, 43.6, 43.9 s | reference |
| M1 | 26.7–26.9 s (−9.5%) | 35.8, 38.9, 39.2 s (−11%) | 0 of 262,144, Mac and iPhone |

Paint crate tests (`cargo test -p paint --features replay-effects`): 162 passed, 1 failed, 8 ignored. The failure, `bristle::knife_skim::a_skimming_knife_keeps_its_light_on_wet_dark_paint` ("on wet 0.43678316, on dried 0.8425079"), fails the same way without M1: it predates this work.

**Tried and rejected: inline tube parts** (`SmallVec<[(usize, f32); 10]>` for `Latent::parts`). Exact, but the Mac run went from 29.5 s to 38.1 s: each latent grew from ~240 to ~384 bytes, and the engine copies latents constantly, so the larger copies cost more than the allocations saved.

## Step M2: faster tube-part merge (kept)

`Latent::blend_parts` was then the heaviest function (~21% of its own time on the Mac). Its `add_parts` searched the pixel's tube parts once per part of the paint mixed in. Now a bit per tube (indices below 64) says whether a search can match at all, and while the pixel names no tube twice, a match at the same position is the only one (blending a pile into itself). Repeated tubes, which a plan can name, and indices from 64 up fall back to the search. Same result for any input: the test `wet::latent_tests::add_parts_matches_a_search_per_part` checks it bit for bit against the old search on 20,000 random lists with repeats and large indices.

| | v7 Mac (M4) | v7 iPhone 17 Pro Max | Pixels changed |
|---|---|---|---|
| Before (C0 / P0) | 29.5–29.9 s | 41.1, 43.6, 43.9 s | reference |
| M1 | 26.7–26.9 s | 35.8, 38.9, 39.2 s | 0 |
| M2 | 25.1–25.7 s | **31.9, 34.5, 36.0 s** | 0, Mac and iPhone |

Back-to-back runs on the phone get ~4 s slower from the first to the third with the thermal state still nominal, as before; a day's first painting is the cold case.

**Conclusion:** the phone runs this engine ~1.45× slower than the M4 Mac, evenly, with no phone-specific fault left. Reaching ~30 s on the phone means making the engine itself ~1.4× faster (Mac ≈ 21 s), through the exact code changes: the paint-layer memory churn, the inner loops, and wider parallelism (only ~2 cores are busy, and the phone's four efficiency cores can absorb more).
