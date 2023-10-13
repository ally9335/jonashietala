---
title: "Converting my static site to epub"
tags: Cryptocurrency, Programming, Pollen, Racket, Why Cryptocurrencies?
---

# Creating an epub

I looked at [epub3 examples](https://github.com/IDPF/epub3-samples)

```bash
#!/bin/bash

cd _ebook/
zip -X0 why_cryptocurrencies.epub mimetype
zip -Xur9D why_cryptocurrencies.epub *
```


# Validating

The commonly recommended [idpf validator][idpf] is down. I instead used [epubcheck][] I found on github. Turns out I had a few errors:

[idpf]: http://validator.idpf.org/
[epubcheck]: https://github.com/w3c/epubcheck

```
$ java -jar epubcheck.jar ~/code/why_cryptocurrencies/_ebook/why_cryptocurrencies.epub
Check finished with errors
Messages: 2 fatals / 2183 errors / 2 warnings / 0 infos
```

And this was after I had made a bunch of corrections. Sigh.

Fixing them is annoying and time consuming, but it's not hard. Most of them were easily fixed by updating the templates and tag generation within Pollen.

0. Need to provide manifest and spine information in a `.opf` file.
0. Convert html to xhtml, with some stricter requirements such as `<aside>` aren't allowed inside `<li>`.

   Some the errors where dumb things I did with html generally, such as not escaping `?` in link fragments.

0. Must provide .png fallbacks for all images.


## Mass converting files:

```fish
for file in *.svg
    inkscape -w 1024 $file --export-filename (basename $file .svg)-fallback.png
end
```

Will from `energy-bars.svg` generate `energy-bars-fallback.png`.
