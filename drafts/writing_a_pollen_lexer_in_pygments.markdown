---
title: "Writing a Pollen lexer in Pygments"
tags: Pollen, Programming
---

After writing a few blog posts about Pollen I started getting annoyed that I didn't have syntax highlighting for the code snippets. So I did a bit of fooling around with Pygments, and it turns out writing a custom lexer isn't that unreasonable, so here's how I did it.

# Pollen markup

Pollen's rules are pretty simple as it's basically just some extra syntax for embedding Racket in a text file:

1. Code starts with `◊;`
2. You can insert variables with `◊|my-var|`
3. Run arbitrary Racket code with `◊( ... )`
4. There's an extra construction that transforms `◊fun[arg1 arg2]{some text}` to `◊(fun arg1 arg2 "some" text")`, which is useful when you want to send a bunch of text to a function. (I use it everywhere in my book.)

So basically I want to be able to highlight this type of code:

```{.pollen}
◊; A link can just be a standard reference
◊(define dune-audible "https://www.audible.com/pd/Dune-Audiobook/B002V1OF70")

I'm ◊strong{really} looking forward to the upcoming Dune movie!

◊div[#:class "extra-sand"]{
    I also recommend the Dune audiobook ◊link[#:ref dune-audible]{on Audible}.
}
```


