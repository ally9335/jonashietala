from pygments.lexer import RegexLexer, bygroups, using, include
from pygments.token import *
from pygments.lexers.lisp import RacketLexer
import re

class PollenLexer(RegexLexer):
    """
    Lexer for Pollen
    """

    name = 'Pollen'
    aliases = ['pollen']
    filenames = ['*.html.pm']

    flags = re.IGNORECASE | re.DOTALL | re.MULTILINE

    valid_symbol_chars = r'[\w!$%*+,<=>?/.\'@&#:-]'
    variable = r'[A-Z]%s*' % valid_symbol_chars

    tokens = {
        'root': [
            include('magic'),
            (r'.', Text)
        ],

        'magic': [
            (r'◊;.*?$', Comment, '#pop'),
            (r'◊', Name.Variable.Magic, 'post-magic'),
        ],

        'post-magic': [
            # |var|
            (r'(\|)(%s)(\|)' % variable,
                bygroups(Name.Variable.Magic, Name.Variable, Name.Variable.Magic),
                '#pop'),
            # (
            (r'(\()',
                Name.Variable.Magic, ('#pop', 'racket-parens')),
            # var
            (r'%s' % variable, Name.Variable, ('#pop', 'post-var')),
        ],

        'post-var': [
            (r'\[', Name.Variable.Magic, ('#pop', 'curly-start', 'racket-brackets')),
            include('curly-start'),
        ],

        'curly-start': [
            (r'\{', Name.Variable.Magic, ('#pop', 'curly-end'))
        ],

        'curly-end': [
            include('magic'),
            (r'\}', Name.Variable.Magic, '#pop'),
            (r'.', Text)
        ],

        'racket-parens': [
            (r'(.+)(\))',
                bygroups(using(RacketLexer, state='unquoted-datum'), Name.Variable.Magic),
                '#pop')
        ],

        'racket-brackets': [
            (r'(.+?)(\])',
                bygroups(using(RacketLexer, state='unquoted-datum'), Name.Variable.Magic),
                '#pop')
        ],
    }

