# -*- coding: utf-8 -*-
# From https://github.com/blaenk/blaenk.github.io
from __future__ import print_function

import sys

from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import get_lexer_by_name
from pygments.util import ClassNotFound

from gdb import GDBLexer
from toml import TOMLLexer
from pollen import PollenLexer

html = HtmlFormatter(encoding='utf-8', nowrap=True)

while True:
    try:
        lang = sys.stdin.readline().rstrip("\n")
        amt = int(sys.stdin.readline().rstrip("\n"))
        code = sys.stdin.read(amt)

        with open('tmp', 'a') as myfile:
            myfile.write("LANG {}\n".format(lang))
            myfile.write("AMT {}\n".format(amt))
            myfile.write("CODE {}\n".format(code))

            rv = ""
            try:
                try:
                    if lang == "gdb":
                        lex = GDBLexer(encoding="utf-8")
                    elif lang == "toml":
                        lex = TOMLLexer(encoding="utf-8")
                    elif lang == "pollen":
                        lex = PollenLexer(encoding="utf-8")
                    else:
                        lex = get_lexer_by_name(lang, encoding="utf-8")
                except ClassNotFound as err:
                    myfile.write("Unknown language: {}".format(lang))
                    lex = get_lexer_by_name("text", encoding="utf-8")

                rv = highlight(code, lex, html)
            except ValueError as err:
                rv = "Pygments Error: {}".format(err)

            myfile.write("LEN {}\n".format(len(rv)))

            sys.stdout.write(str(len(rv)))
            sys.stdout.write("\n")
            sys.stdout.flush()

            if not hasattr(sys.stdout, 'buffer'):
                sys.stdout.write(rv)
                sys.stdout.flush()
            else:
                sys.stdout.buffer.write(rv)
                sys.stdout.buffer.flush()

            myfile.write("{}".format(rv))
    except Exception as err:
        with open('fail', 'a') as myfile:
            myfile.write("Uncaught error: {}".format(err))
        sys.exit()

