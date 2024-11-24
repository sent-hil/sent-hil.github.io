---
layout: post
title: Installing LaTeX-OCR On Osx
---

# {{ page.title }}

<p class="meta">11 May, 2024</p>

[LaTeX-OCR](https://github.com/lukas-blecher/LaTeX-OCR) is a library for
converting images to LATEX code. I recently had to reinstall it and ran into
some issues. I'm documenting them here so it can help someone else.

1. Install conda `brew install miniconda`
2. Install conda to start with your shell `conda init`
3. Activate a new conda environment: `conda create -n latexocr python=3.11`. If
4. Install with right qt version `pip install qt=6.6.3 "pix2tex[gui]"`

Thanks to this [post](https://github.com/lukas-blecher/LaTeX-OCR/issues/390) for fixing issue with `numpy` installation.

I also added this fish helper function to start with a single
command: `latexocr`

```shell
function latexocr
    conda_init
    conda activate latexocr
    /opt/homebrew/Caskroom/miniconda/base/envs/latexocr/bin/latexocr
end

function conda_init
    if test -f /opt/homebrew/Caskroom/miniconda/base/bin/conda
        eval /opt/homebrew/Caskroom/miniconda/base/bin/conda "shell.fish" "hook" $argv | source
    else
        if test -f "/opt/homebrew/Caskroom/miniconda/base/etc/fish/conf.d/conda.fish"
            . "/opt/homebrew/Caskroom/miniconda/base/etc/fish/conf.d/conda.fish"
        else
            set -x PATH "/opt/homebrew/Caskroom/miniconda/base/bin" $PATH
        end
    end
end
```
