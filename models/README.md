# Models

Open-weight GGUF files used by the `llm` plugin (`:help llm`). The weights
are not tracked; `registry.txt` records where each comes from so any clone
of this repository can fetch the same files with `:LlmDownload {name}`.

The entries that matter are Qwen2.5-Coder quantizations on Hugging Face: the
Q8_0 files are published by the llama.cpp maintainers under `ggml-org`, the
Q4_K_M ones by QuantFactory and bartowski. The coder models are trained for
fill-in-the-middle, which is what makes completion at the cursor work; they
cover most programming languages, LaTeX and Typst, and are serviceable for
English prose. Qwen3 and the Mistral models have no fill-in-the-middle and
are given only the text before the cursor. Licences differ by model; each
repository's page has its own.

Choose by memory: a model needs roughly its file size in VRAM plus about
1 GB for an 8k context, out of what the card has free. On a 6 GB laptop GPU
use the 3B model; on 12 GB or more use the 7B at Q4. `BENCHMARKS.md` has
the measurements behind that, and how to repeat them on another machine.
