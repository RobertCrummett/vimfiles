# Models

Open-weight GGUF files used by the `llm` plugin (`:help llm`). The weights
are not tracked; `registry.txt` records where each comes from so any clone
of this repository can fetch the same files with `:LlmDownload {name}`.

All entries are Qwen2.5-Coder or Qwen3 quantizations published by the
llama.cpp maintainers under `ggml-org` on Hugging Face, Apache-2.0 licensed.
The coder models are trained for fill-in-the-middle, which is what makes
completion at the cursor work; they cover most programming languages, LaTeX
and Typst, and are serviceable for English prose.

Choose by memory: a model needs roughly its file size in VRAM plus about
1 GB for an 8k context. On a 6 GB laptop GPU use the 3B model; on 12 GB or
more use the 7B.
