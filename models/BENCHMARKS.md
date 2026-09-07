# Model measurements

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

## Speed and accuracy, 99 completions

| model | GB | exact % | first token % | load s | gen tok/s | request ms |
|---|---|---|---|---|---|---|
| qwen2.5-coder-3b (Q8_0) | 3.29 | 34.3 | 62.6 | 2.6 | 147.5 | 344 |
| qwen2.5-coder-7b-q4 | 4.68 | 42.4 | 69.7 | 3.6 | 116.3 | 478 |
| qwen2.5-coder-7b (Q8_0) | 8.10 | 42.4 | 70.7 | 4.1 | 74.8 | 562 |
| qwen2.5-coder-14b-q4 | 8.99 | 41.4 | 70.7 | 5.1 | 62.0 | 901 |

## Usefulness, 54 situations

The easy tier saturated, so it separates nothing. The hard tier needed a
constant, a formula or a multi-token body, and it does separate them.

| model | easy tier (34) | hard tier (20) | geophysics subset (8) |
|---|---|---|---|
| qwen2.5-coder-3b | 31 | 12 | 3 |
| qwen2.5-coder-7b-q4 | 31 | 12 | 2 |
| qwen2.5-coder-7b | 30 | 12 | 2 |
| qwen2.5-coder-14b-q4 | 31 | 16 | 7 |
| qwen3-4b (no FIM) | 25 | 12 | 4 |

## What the numbers mean

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

## Conclusion

`qwen2.5-coder-7b-q4` for code, which is what this machine defaults to.
`qwen2.5-coder-14b-q4` when writing papers and the model needs to know
constants. Switch at runtime with `:LlmModel`; see `:help llm-models`.

One caveat worth remembering: the 14B build is an imatrix quantization and the
7B is a plain one, so the 7B-Q8 against 7B-Q4 comparison slightly overstates
what quantization costs. It does not affect the 14B against 7B result.
