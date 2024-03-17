use std::{collections::HashMap, fs};

use camino::Utf8PathBuf;
use eyre::Result;
use lazy_static::lazy_static;
use tree_sitter_highlight::{HighlightConfiguration, HighlightEvent, Highlighter};

pub struct TreesitterHighlighter<'a> {
    config: &'a HighlightConfiguration,
}

impl<'a> TreesitterHighlighter<'a> {
    pub fn find(lang_id: &str) -> Option<Self> {
        CONFIGS.get(lang_id).map(|config| Self { config })
    }

    pub fn highlight(&self, lang_id: &str, code: &str) -> Result<String> {
        let mut highlighter = Highlighter::new();

        let highlights = highlighter
            .highlight(self.config, code.as_bytes(), None, |x| CONFIGS.get(x))
            .unwrap();

        // This isn't very nice... How to generate strings dynamically from inside a Fn closure
        // that returns a byte slice?
        // Not very easily.
        // let mut renderer = HtmlRenderer::new();
        // renderer.render(highlights, code.as_bytes(), &|attr| {
        //     CLASSES[attr.0].as_bytes()
        // })?;
        // let res = renderer.lines().join("");
        // Ok(res)

        let mut res = String::new();

        for event in highlights {
            match event? {
                HighlightEvent::Source { start, end } => res.push_str(&code[start..end]),
                HighlightEvent::HighlightEnd => res.push_str("</span>"),
                HighlightEvent::HighlightStart(attr) => {
                    res.push_str(&format!(
                        r#"<span class="{} {}">"#,
                        HIGHLIGHT_NAMES[attr.0].replace(".", " "),
                        lang_id
                    ));
                }
            }
        }

        if !res.ends_with("\n") {
            res.push('\n');
        }

        Ok(res)
    }
}

// TODO more things...
static HIGHLIGHT_NAMES: &[&str] = &[
    "attribute",
    "boolean",
    "character",
    "comment",
    "comment.documentation",
    "constant",
    "constant.builtin",
    "define",
    "exception",
    "fold",
    "function",
    "function.builtin",
    "function.call",
    "function.macro",
    "indent.align",
    "indent.auto",
    "indent.begin",
    "indent.branch",
    "indent.dedent",
    "indent.end",
    "indent.ignore",
    "indent.zero",
    "injection.content",
    "injection.language",
    "keyword",
    "keyword.conditional",
    "keyword.conditional.ternary",
    "keyword.coroutine",
    "keyword.debug",
    "keyword.directive",
    "keyword.directive.define",
    "keyword.exception",
    "keyword.function",
    "keyword.import",
    "keyword.operator",
    "keyword.repeat",
    "keyword.return",
    "keyword.storage",
    "label",
    "local.definition",
    "local.definition.field",
    "local.definition.function",
    "local.definition.import",
    "local.definition.macro",
    "local.definition.method",
    "local.definition.namespace",
    "local.definition.parameter",
    "local.definition.type",
    "local.definition.var",
    "local.reference",
    "local.scope",
    "markup",
    "markup.caption",
    "markup.delete",
    "markup.fixme",
    "markup.footnote",
    "markup.footnote.definition",
    "markup.footnote.reference",
    "markup.heading.1",
    "markup.heading.2",
    "markup.heading.3",
    "markup.heading.4",
    "markup.heading.5",
    "markup.heading.6",
    "markup.highlighted",
    "markup.insert",
    "markup.italic",
    "markup.link.definition",
    "markup.link.label",
    "markup.link.reference",
    "markup.link.url",
    "markup.list",
    "markup.list.checked",
    "markup.list.unchecked",
    "markup.math",
    "markup.note",
    "markup.quote",
    "markup.raw",
    "markup.strong",
    "markup.subscript",
    "markup.superscript",
    "markup.symbol",
    "markup.todo",
    "module",
    "nospell",
    "number",
    "number.float",
    "operator",
    "property",
    "punctuation",
    "punctuation.bracket",
    "punctuation.delimiter",
    "punctuation.special",
    "spell",
    "string",
    "string.escape",
    "string.special",
    "tag",
    "tag.attribute",
    "tag.delimiter",
    "text.title",
    "type",
    "type.builtin",
    "type.definition",
    "type.qualifier",
    "variable",
    "variable.builtin",
    "variable.member",
    "variable.parameter",
];

lazy_static! {
    // static ref CLASSES: Vec<String> = HIGHLIGHT_NAMES
    //     .iter()
    //     .map(|name| format!(r#"class="{}""#, name.replace(".", " ")))
    //     .collect();
    static ref HOME: Utf8PathBuf = Utf8PathBuf::from_path_buf(dirs::home_dir().unwrap()).unwrap();
    static ref CONFIGS: HashMap<String, HighlightConfiguration> = init_configurations();
}

fn read_nvim_treesitter_file(lang: &str, file: &str) -> String {
    let path = HOME
        .join(".local/share/nvim/lazy/nvim-treesitter/queries/")
        .join(lang)
        .join(file);
    let content =
        fs::read_to_string(&path).expect(&format!("Failed to find nvim-treesitter file: {path}"));
    content
}

fn read_nvim_treesitter_highlights(lang: &str) -> String {
    read_nvim_treesitter_file(lang, "highlights.scm")
}

fn read_nvim_treesitter_injections(lang: &str) -> String {
    read_nvim_treesitter_file(lang, "injections.scm")
}

fn read_nvim_treesitter_locals(lang: &str) -> String {
    read_nvim_treesitter_file(lang, "locals.scm")
}

// struct Config {
//     lang: &'static str,
//     langauge: Language,
// }

fn init_configurations() -> HashMap<String, HighlightConfiguration> {
    [
        (
            "rust",
            HighlightConfiguration::new(
                tree_sitter_rust::language(),
                tree_sitter_rust::HIGHLIGHT_QUERY,
                tree_sitter_rust::INJECTIONS_QUERY,
                "",
            )
            .unwrap(),
        ),
        (
            "sdjot",
            HighlightConfiguration::new(
                tree_sitter_sdjot::language(),
                tree_sitter_sdjot::HIGHLIGHTS_QUERY,
                tree_sitter_sdjot::INJECTIONS_QUERY,
                "",
            )
            .unwrap(),
        ),
        // (
        //     "c",
        //     HighlightConfiguration::new(
        //         tree_sitter_c::language(),
        //         &dbg!(read_nvim_treesitter_highlights("c")),
        //         &read_nvim_treesitter_injections("c"),
        //         &read_nvim_treesitter_locals("c"),
        //     )
        //     .unwrap(),
        // ),
    ]
    .into_iter()
    .map(|(name, mut config)| {
        config.configure(&HIGHLIGHT_NAMES);
        (name.to_string(), config)
    })
    .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_treesitter_highlight() {
        let highlighter = TreesitterHighlighter::find("rust").unwrap();
        assert_eq!(
            highlighter.highlight("rust", "let x = 2;").unwrap(),
            "<span class=\"keyword rust\">let</span> x = <span class=\"constant rust\">2</span><span class=\"punctuation delimiter rust\">;</span>\n"
        );
        // assert!(false);

        //         assert_eq!(
        //             highlighter
        //                 .highlight(
        //                     "rust",
        //                     r##"
        // lazy_static! {
        //     static ref BLOCK: Regex = Regex::new(
        //         r#"
        //         ^
        //         $
        //         "#
        //     ).unwrap()
        // }
        // "##
        //                 )
        //                 .unwrap(),
        //             "x"
        //         );
    }
}
