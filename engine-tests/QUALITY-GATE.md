# Quality gate for speed-ups (agreed by Claude and Codex, 2026-10-28)

How we make the engine faster on iPhone without a drop in quality. Every speed-up passes this gate before it's kept.

## 1. Classify every change
- **Exact:** must not change the picture (compiler settings, memory/allocation fixes, inner-loop rewrites). Passes only on replay checks: bit-for-bit equality on the same device type where the engine repo requires it, otherwise its documented drift policy. Compiler settings (LTO, target CPU, floating-point contraction) are checked too, never assumed safe.
- **Approximate:** may change the picture (fewer bristles, plan technique changes, smaller canvas). Passes only the human and meaning checks below.

## 2. Frozen reference set
About 20 representative journal entries → plans → reference renders on the current engine. Each records the plan, engine revision, build settings, device and size. Never regenerated silently.

## 3. Approximate changes must pass: fidelity to the entry
Quality means **does the painting translate this journal entry**, not aesthetic taste (the user's correction, 2026-10-28). There is no preference vote.

- **Ground truth = a fixed checklist per entry.** Each test entry (synthetic, written for testing, not user data) lists the elements its painting must convey: subject, setting, time of day and light, mood colors, key motifs (e.g. "orange evening sky", "wet street", "a walking figure"). Checklists are frozen before any candidate is evaluated. Candidates are scored against the checklist; losses relative to the reference render are flagged separately (the reference itself can be wrong).
- **Matching test (secondary):** a painting plus 4 entries (the true one + 3 fixed distractors, positions randomized), and the evaluator says which entry it depicts. Per-entry accuracy with uncertainty; the candidate must be non-inferior to the reference under a pre-set margin.
- **Who judges:** a vision model (Claude) as a frozen, blinded, repeatable screen: fixed model version, prompt, image size and protocol, with no knowledge of which image is the reference. **Humans adjudicate** every flagged element plus a pre-set random sample of unflagged ones, and checks are expanded wherever model and humans disagree.
- **Painterly character is secondary:** it must still read as oil paint. Diagnostics (CIEDE2000, SSIM, coverage, value histogram, texture/edge energy) are reviewed per entry and display size, along with the timelapse. Gaps or mud fail only where the checklist or plan requires clean coverage or separation, since exposed canvas can be intentional.

## 4. Performance measurement
≥5 runs per configuration, reporting median and spread; build settings, device, and thermal state at start and end recorded. First frame is measured end to end, until the UI actually shows it.

## 5. Order and attribution
Exact changes first (compiler → allocations → inner loops), measured on the Mac and the iPhone. Then approximate changes one at a time. Each step is measured against a preserved baseline and logged in a ledger (speed, memory, replay result, visual result). Stop when the target is met: **a good-looking daily tile in ≤ 5–7 s on iPhone, first frame ≤ 1 s.**
