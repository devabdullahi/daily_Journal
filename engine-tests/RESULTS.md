# Engine test results (2026-10-28)

The first look at the [claude-paint](https://github.com/aliceisjustplaying/claude-paint) engine for daily paintings. The machine is an Apple M4 Mac (10 cores) running the release build, rendered with `easel run <file.lua> --out <png> --width <px>`.

Test entry: *"rough morning, missed the bus in the rain. lunch w/ sam fixed it tho. long walk home, sky was orange"*

## Renders

| File | Plan | Width | Time |
|---|---|---|---|
| `paintings/v1-512.png` | `scripts/v1_naive.lua`: one pass per area, blue and orange mixed in one pass | 512 px | 2.6 s |
| `paintings/v1-1024.png` | same | 1024 px | 7.1 s |
| `paintings/v2-512.png` | `scripts/v2_technique.lua`: gaps filled, sky in 3 separate bands, blender passes | 512 px | 13.6 s |
| `paintings/v2-1024.png` | same | 1024 px | 42.3 s |
| `paintings/v2-timelapse.gif` + `v2-timelapse-frames/` | v2, a frame every 20 s of simulated hand time | 512 px frames | (inside the 42 s run) |

## What we learned

1. **The engine works headlessly.** `easel run` replays a Lua plan into a PNG, and `--frames-every` gives timelapse frames for free. No AI agent or MCP is needed at render time.
2. **The plan matters more than the engine.** v1 (naive) shows bare canvas between strokes and muddy olive where the blue met the orange. That's physically correct pigment mixing, but a planning mistake. v2 fixes both with real painter technique. The planner's compositions must encode that technique.
3. **Speed depends on technique, not just size.** `fill=true` and `blend` passes cost the most: in v2, the sky took 26 s of the 42 s at 1024 px. On this Mac, a daily tile is about 3–14 s at 512 px depending on the plan.
4. **Still to measure:** iPhone (needs an iOS build of the engine), memory, heat and battery; plus chapter and year sizes on the server.
5. **Plan issues still visible in v2:** the street reflection reads as grass (the strokes are too vertical and too contrasting), and the figure is crude. These need better compositions, not engine changes.

## iPhone 17 Pro Max (iPhone18,2, 6 cores), first on-device run

The engine was built unmodified as an iOS static library, with a small C entry point added (`easel_run_c`) and called from a throwaway SwiftUI app (`ios-bench/`). Release build.

| Plan | Width | iPhone | M4 Mac | Peak memory | Thermal |
|---|---|---|---|---|---|
| v1 (simple) | 512 px | **2.9 s** | 2.6 s | 235 MB | nominal |
| v2 (technique) | 512 px | **14.0 s** | 13.6 s | 262 MB | nominal |
| v2 | 1024 px | did not finish (the debug connection dropped during the run; cause not yet known) | 42.3 s | — | — |

Takeaways: the iPhone matches the Mac per painting, because the engine mostly uses about one core on both. Memory at 512 px is fine. The daily tile is CPU-bound in the bristle exchange, so speeding up the engine (ENGINE-PLAN step 2) and cheaper plans (step 1) are what move this number. Paintings from the phone are in `paintings/iphone/`.
