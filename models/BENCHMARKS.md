# Model measurements

Two runs, one per machine. The case sets were rebuilt for the second, so
percentages compare models *within* a run and not across the two.

## The AMD machine, 2026-09-06

Run 2026-09-06 on the AMD machine: Ryzen 9 9950X3D, 61 GB RAM, Radeon RX 9070
XT with 15.92 GB of VRAM, llama.cpp build 10819 (Vulkan), all layers on the
GPU, 8k context, flash attention on.

Two benchmarks were used. **Speed and accuracy** masked the tail of 99 real
lines drawn from this repo's `autoload/*.vim`, `plugin/comments.vim` and
`spell/geophysics/fetch-corpus.py`, sent the same prefix and suffix the plugin
sends, and scored the first line of the answer. **Usefulness** used 54
hand-written editing situations across geophysics prose, LaTeX, Typst,
vimscript, Python, C and Scheme, judged on whether the suggestion was
substantively right rather than character-identical.

### Speed and accuracy, 99 completions

| model | GB | exact % | first token % | load s | gen tok/s | request ms |
|---|---|---|---|---|---|---|
| qwen2.5-coder-3b (Q8_0) | 3.29 | 34.3 | 62.6 | 2.6 | 147.5 | 344 |
| qwen2.5-coder-7b-q4 | 4.68 | 42.4 | 69.7 | 3.6 | 116.3 | 478 |
| qwen2.5-coder-7b (Q8_0) | 8.10 | 42.4 | 70.7 | 4.1 | 74.8 | 562 |
| qwen2.5-coder-14b-q4 | 8.99 | 41.4 | 70.7 | 5.1 | 62.0 | 901 |

### Usefulness, 54 situations

The easy tier saturated, so it separates nothing. The hard tier needed a
constant, a formula or a multi-token body, and it does separate them.

| model | easy tier (34) | hard tier (20) | geophysics subset (8) |
|---|---|---|---|
| qwen2.5-coder-3b | 31 | 12 | 3 |
| qwen2.5-coder-7b-q4 | 31 | 12 | 2 |
| qwen2.5-coder-7b | 30 | 12 | 2 |
| qwen2.5-coder-14b-q4 | 31 | 16 | 7 |
| qwen3-4b (no FIM) | 25 | 12 | 4 |

### What the numbers mean

**Q8_0 is not worth its size.** On the 7B the two quantizations disagreed on 1
of 99 completions and 0 of 20 usefulness cases. Q4_K_M is 42% smaller and 55%
faster to generate. Nothing measured here justifies Q8_0.

**The 7B is a real step up from the 3B, the 14B is not.** 3B to 7B is
significant on exact match (p = 0.039, paired McNemar). 7B to 14B is not
detectable on code at all, and the 14B is 1.6x slower per request.

**The 14B earns its keep only on domain knowledge.** It got the free-air
gradient (0.3086 mGal/m) and the Nyquist frequency for a 4 ms sample interval
(125 Hz) where every smaller model failed, the latter by a factor of two. On
the geophysics subset it answered every case the 7B answered plus five more and
lost none, though with only 8 cases that is p = 0.062, so it is strong rather
than proven.

**The dedicated prose model lost.** Qwen3-4B scored 25/34 on the easy tier
against 30 to 31 for the coder models, and it has no fill-in-the-middle, so the
text after the cursor is wasted on it.

### Conclusion for the AMD machine

`qwen2.5-coder-7b-q4` for code, which is what that machine defaults to.
`qwen2.5-coder-14b-q4` when writing papers and the model needs to know
constants. Switch at runtime with `:LlmModel`; see `:help llm-models`.

One caveat worth remembering: the 14B build is an imatrix quantization and the
7B is a plain one, so the 7B-Q8 against 7B-Q4 comparison slightly overstates
what quantization costs. It does not affect the 14B against 7B result.

## The laptop, 2026-09-07

Run on the RTX 4050 Laptop GPU, llama.cpp build 7170 (Vulkan), all layers on
the GPU, 8k context, flash attention on -- the arguments `plugin/llm.vim`
itself passes. The original harness was not tracked, so the cases were rebuilt
to the same recipe: 99 masked line tails from `autoload/*.vim`,
`plugin/comments.vim` and `spell/geophysics/fetch-corpus.py`, with the prefix
and suffix `s:context()` builds, and 24 hand-written editing situations
weighted towards code. Every model was run in both of the plugin's real modes,
`<C-X><C-A>` (12 tokens, 8 lines of suffix) and `<C-X><C-B>` (64 tokens, 30).

Three things about this machine that the desktop did not have:

**The usable VRAM is 5155 MiB, not 6141.** llama.cpp reports what is actually
free after Windows and the desktop have taken theirs, and that is the number a
model has to fit inside. `qwen2.5-coder-7b-q4` needs 4920 MiB (4168 weights,
448 KV, 304 compute) and fits with 235 MiB to spare. The 7B at Q8_0 does not
load at all: `ErrorOutOfDeviceMemory`, and llama-server exits. The 14B at Q4,
at 8.99 GB, is not a candidate.

**Speed is set by power, not by heat.** Dynamic Boost runs the GPU at 40 W and
1500-1800 MHz under the AC power mode (Best performance) and clamps it to 20 W
and 500-900 MHz under the battery one (Best power efficiency). That is close to
a factor of two on every model, and it is larger than the difference between
any two models here. Sustained load sits at 74-78 C with 12 C of headroom and
no thermal throttling, so heat is not what limits this machine. Latency below
was measured round-robin -- every model reloaded in rotation over three rounds
-- because measuring one model after another lets a power change land entirely
on whichever ran last. An early pass done that way put the 3B at 21 tok/s; its
real figure on AC is 45.6.

**This build ignores `-np 1`.** Build 7170 announces `main: setting n_parallel
= 4 and kv_unified = true (add -kvu to disable this)` and overrides the flag
`s:server_cmd()` passes. The KV cache is unified, so it costs no memory, but
the single-slot setup the plugin asks for is not what it gets.

### Accuracy, 99 completions

Accuracy does not depend on the clock, so these hold in both power modes.

| model | GB | menu exact % | menu first token % | block exact % | block first token % |
|---|---|---|---|---|---|
| qwen2.5-coder-1.5b (Q8_0) | 1.65 | 25.3 | 58.6 | 22.2 | 57.6 |
| qwen2.5-coder-3b (Q8_0) | 3.29 | 26.3 | 65.7 | 30.3 | 63.6 |
| qwen2.5-coder-7b-q4 | 4.68 | 30.3 | 72.7 | 32.3 | 70.7 |
| qwen2.5-coder-7b (Q8_0) | 8.10 | — does not load — | | | |

### Latency, by power mode

Median wall time for one completion, measured round-robin.

| model | AC menu | AC block | AC tok/s | battery menu | battery block | battery tok/s | load AC |
|---|---|---|---|---|---|---|---|
| qwen2.5-coder-1.5b | 449 ms | 548 ms | 83.0 | 763 ms | 898 ms | 48.9 | 1.8 s |
| qwen2.5-coder-3b | 772 ms | 983 ms | 45.6 | 1515 ms | 1927 ms | 21.2 | 3.4 s |
| qwen2.5-coder-7b-q4 | 1419 ms | 1760 ms | 33.9 | 3156 ms | 3815 ms | 11.8 | 4.4 s |

### Usefulness, 24 situations

| model | easy tier (13) | hard tier (11) | geophysics subset (5) |
|---|---|---|---|
| qwen2.5-coder-1.5b | 10 | 4 | 1 |
| qwen2.5-coder-3b | 12 | 6 | 1 |
| qwen2.5-coder-7b-q4 | 11 | 7 | 1 |

The 7B was the only one to write `np.sqrt(np.mean(x**2))` for an RMS rather
than a standard deviation, and the only one to keep the `const` in a qsort
comparator. The 1.5B was the only one to leak a `<|cursor|>` sentinel into an
answer, and only once, in a file too short to be realistic -- never in the 99
repository cases.

None of them know any geophysics. All three got the Nyquist frequency right
and all three missed the free-air gradient, the Bouguer slab constant, the
SEG-Y binary header length and Poisson's ratio from Vp/Vs. On the desktop that
was the 14B's one clear win, and the 14B cannot run here, so on this machine
that capability is simply absent.

### What the numbers mean

**The 7B is not measurably better than the 3B here.** Paired McNemar over the
99 cases: 7B against 3B gives p = 0.167 and 0.388 in menu mode, 0.092 and 0.791
in block mode -- nothing significant on any of the four. Against the 1.5B the
same test is decisive (first token p = 0.001 menu, p = 0.004 block; block exact
p = 0.021). So the 1.5B really is the weakest, and the gap the desktop found
between 3B and 7B does not reproduce at this sample size.

**Power mode moves more than model choice does.** The 3B on AC (772 ms) is
faster than the 1.5B on battery (763 ms is a tie) and twice as fast as itself
on battery. Any conclusion about lag has to name the power mode.

### Conclusion for the laptop

`qwen2.5-coder-3b` on AC: it is within noise of the 7B on every accuracy
measure and answers in a little over half the time. `qwen2.5-coder-1.5b` on
battery, where it is the only model that answers a word completion inside a
second. `after/plugin/local.vim` sets both and picks between them by checking
the power state off a job at startup; `:LlmPower` re-checks after plugging in
or unplugging, and `:LlmModel` overrides either.

`qwen2.5-coder-7b-q4` is worth keeping for a session where the answer matters
more than the wait -- it had the best point estimate on all four accuracy
measures and the best hard tier -- but not as a default at 1.4 s a completion.
