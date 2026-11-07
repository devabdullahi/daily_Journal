# Engine plan: faster engine, better paintings (agreed by Claude and Codex, 2026-10-28)

The user asked to "replicate" the engine to be faster and paint better. After studying the source and profiling it, both Claude and Codex recommend **not** rewriting it. Fork and optimize it, and get better paintings from better plans.

## Evidence
- Profile of the slow sky pass (macOS `sample`, 10 s, M4): ~85% of samples were idle worker threads; the busy time was the per-bristle paint exchange (`bristle::exchange`, `Surf::add`, `Surf::take`) plus allocation churn from the per-pixel `Vec<Layer>` paint state. The whole run averaged ~1.35 of 10 cores (real 42.3 s, user 57.2 s).
- Rayon parallelism exists (pixel ops, and strokes whose tiles don't overlap in `sched.rs`), but broad overlapping strokes run serially.
- The quality problems in v1/v2 (mud, gaps, a reflection reading as grass) came from the plan, not the physics.

## Plan
0. **No rewrite.** Fork under MIT; keep LICENSE and THIRD_PARTY_NOTICES (spectral.js MIT port, CC BY 4.0 pigment data).
1. **Quality via the planner first:** a technique library for compositions (no complementaries mixed in one pass; soft-masked bands; fill on body passes; blend only for intended wet-on-wet; reflections as horizontal broken strokes + glaze; figures via gesture strokes). Judged by side-by-side human ratings on a fixed set of ~20 representative entries.
2. **Profile-led optimization of the fork:**
   - a. Lossless allocation fixes first (arena / reusable scratch storage). A capped layer stack with a merge rule only if its visual and replay drift is measured and accepted.
   - b. Exchange/add/take inner loops: data layout, hoisting constants, removing redundant powf/exp, checking auto-vectorization.
   - c. Experiment: more parallelism for overlapping strokes (e.g. disjoint bristles within a stroke step), only after mapping dependencies and showing a net gain.
   - d. Re-profile; optimize `fill_gaps` and the blend receptive map only if they show up.
   - **Gate:** 2× faster on the fixed v2 plan at 1024 px on the M4, within the repo's replay policy. Stretch goal: 3×.
3. **The live timelapse is the painting itself:** stream frames as the engine paints. Verify frame production and delivery latency end to end before claiming "frames within ~1 s". A preview tier (same engine, lower resolution) only if needed; never a second physics model.
4. **Then the iOS feasibility spike** on the optimized fork.

## Rejected for now
- **A new, lighter engine replicating the look:** high effort and risk; loses the technique library and fidelity, and needs new cross-device determinism.
- **A GPU (Metal/wgpu) port:** the mutable, layered paint state and deterministic replay make it high risk; revisit only if profiling after step 2 demands it.
