---
layout: post
title: ModernBERT
---

{{ page.title }}
================

<p class="meta">04 May, 2025</p>

<i>My notes on ModernBERT. [Source](https://huggingface.co/blog/modernbert)</i>

* Family of encoder only (input text, output vector) models, with 8192 sequence length.
* Comes in two sizes: 149M and 395M params.

**BERT**
* [Released](<https://en.wikipedia.org/wiki/BERT_(language_model)>) in 2018 by Google, 2nd most popular model on HuggingFace.
* Encoder only transformer architecture makes it ideal for real world problems like retrieval, classification and entity extraction. Using self supervised learning.
* Pareto improvement - improvement to a system when a change harms no one and benefits at least one person.
* Tokenizer is WordPiece, similar to byte pair encoding. Vocab size is 30k.

**DECODER ONLY MODELS**
* OpenAI's GPT, Llama, Claude etc are decoder only models. But are big, slow and expensive for many jobs.
* Popular buzz around GenAI has obscured role of encoder-only models.

**ENCODER ONLY MODELS**
* Given text, encoder only models returns a vector, aka embeddings. The vector is compressed representation of models's input.
* Decoder only models can do work of encoder only models, but are hamstrung by key constraint: they are not mathematically allowed to peek at later tokens, they can only look backwards. Unlike encoder models which can look forwards and backwards.

**MODERN BERT**
* Context length of 8192 tokens (16x larger than most existing encoders.)
* 2x faster than DeBERTa and uses 1/5 of memory.

**USAGE**

To use it as a sentence transformer, we need to use an [unofficial](https://huggingface.co/answerdotai/ModernBERT-base/discussions/9), fine tuned version.
```python
from sentence_transformers import SentenceTransformer

model = SentenceTransformer("joe32140/ModernBERT-base-msmarco")
sentences = [
    'what county is hayden in',
    "Hayden is a city in Kootenai County, Idaho, United States. Located in the northern portion of the state, just north of Coeur d'Alene, its population was 13,294 at the 2010 census.",
    "According to the United States Census Bureau, the city has a total area of 9.61 square miles (24.89 km2), of which 9.60 square miles (24.86 km2) is land and 0.01 square miles (0.03 km2) is water. It lies at the southwestern end of Hayden Lake, and the elevation of the city is 2,287 feet (697 m) above sea level. Hayden is located on U.S. Route 95 at the junction of Route 41. It is also four miles (6 km) north of Interstate 90 and Coeur d'Alene. The Coeur d'Alene airport is northwest of Hayden.",
]
embeddings = model.encode(sentences)
similarities = model.similarity(embeddings, embeddings)

[for idx_i, sentence in enumerate(sentences):
    print(sentence)
    for idx_j, sentence in enumerate(sentences):
        print(f" - {similarities[idx_i][idx_j]:.4f}: {sentence: <30} ")](<for idx_i, sentence in enumerate(sentences):
    print(sentence[:100])
    for idx_j, sentence in enumerate(sentences):
        print(f" - {similarities[idx_i][idx_j]:.4f}: {sentence[:100]}... ")>)
```

```markdown
what county is hayden in
    - 1.0000: what county is hayden in...
    - 0.7469: Hayden is a city in Kootenai County, Idaho, United States. Located in the northern portion of the st...
    - 0.6398: According to the United States Census Bureau, the city has a total area of 9.61 square miles (24.89 ... - -0.1262: organization name...

Hayden is a city in Kootenai County, Idaho, United States. Located in the northern portion of the st
    - 0.7469: what county is hayden in...
    - 1.0000: Hayden is a city in Kootenai County, Idaho, United States. Located in the northern portion of the st...
    - 0.6513: According to the United States Census Bureau, the city has a total area of 9.61 square miles (24.89 ... -
    - -0.0741: organization name...

According to the United States Census Bureau, the city has a total area of 9.61 square miles (24.89
    - 0.6398: what county is hayden in...
    - 0.6513: Hayden is a city in Kootenai County, Idaho, United States. Located in the northern portion of the st...
    - 1.0000: According to the United States Census Bureau, the city has a total area of 9.61 square miles (24.89 ... -
    - -0.0760: organization name...

organization name
    - -0.1262: what county is hayden in...
    - -0.0741: Hayden is a city in Kootenai County, Idaho, United States. Located in the northern portion of the st...
    - -0.0760: According to the United States Census Bureau, the city has a total area of 9.61 square miles (24.89 ...
    - 1.0000: organization name...
```

NOTE, if you run into `NameError: name 'init_empty_weights' is not defined` error, it's due to bug in [transformers](https://github.com/huggingface/transformers/pull/37337). You can solve it by doing `pip install accelerate` or most likely the fix will be merged and available by the time you read this.
