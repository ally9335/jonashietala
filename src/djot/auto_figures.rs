use itertools::{Itertools, MultiPeek};
use tracing::warn;

pub struct AutoFigures<'a, I: Iterator<Item = Event<'a>>> {
    parent: MultiPeek<I>,
}

impl<'a, I: Iterator<Item = Event<'a>>> AutoFigures<'a, I> {
    pub fn new(parent: I) -> Self {
        Self {
            parent: parent.multipeek(),
        }
    }
}

impl<'a, I: Iterator<Item = Event<'a>>> Iterator for AutoFigures<'a, I> {
    type Item = Event<'a>;

    fn next(&mut self) -> Option<Self::Item> {
        let start = match self.parent.next()? {
            start @ Event::Start(Tag::Paragraph) => start,
            other => return Some(other),
        };

        match self.parent.peek()? {
            Event::Start(Tag::Image(_, _, _)) => {}
            _ => return Some(start),
        };

        loop {
            if let Event::End(Tag::Image(_, _, _)) = self.parent.peek()? {
                break;
            }
        }

        let mut attrs = Attrs::new();

        // We should only transform if we end at a paragraph,
        // using multipeek next() will reset to after the paragraph start.
        match self.parent.peek()? {
            Event::End(Tag::Paragraph) => {}
            // Capture an optional { width=600px } tag
            Event::Text(ref text) => {
                if let Some(parsed_attrs) =
                    parse_attrs(text).expect("Should be able to parse attrs")
                {
                    attrs = parsed_attrs;
                    let next = self.parent.peek()?;
                    if *next != Event::End(Tag::Paragraph) {
                        warn!("Unknown event after attrs: {next:?}");
                        return Some(start);
                    }
                } else {
                    // println!("Unknown text: `{text}`");
                    return Some(start);
                }
            }
            _event => {
                // println!("Unknown event: {event:?}");
                return Some(start);
            }
        }

        // Now we can eat it all up.
        let (dest, title) =
            if let Event::Start(Tag::Image(_type, dest, title)) = self.parent.next()? {
                (dest.to_string(), title.to_string())
            } else {
                panic!("Should have next img tag");
            };
        // Caption comes before image tag end.
        let mut events = Vec::new();
        loop {
            match self.parent.next()? {
                Event::End(Tag::Image(_, _, _)) => break,
                event => events.push(event),
            }
        }
        // Eat until the ending paragraph
        loop {
            if let Event::End(Tag::Paragraph) = self.parent.next()? {
                break;
            }
        }

        let mut caption = String::new();
        push_html(&mut caption, events.iter().cloned());

        let mut res = String::new();
        Figure {
            imgs: vec![Img {
                src: dest,
                title: Some(title),
                width: attrs.key_value.get("width").map(String::to_string),
                height: attrs.key_value.get("height").map(String::to_string),
            }],
            caption: if caption.is_empty() {
                None
            } else {
                Some(caption)
            },
            class: None,
            link: false,
        }
        .push_html(&mut res);

        Some(Event::Html(res.into()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use eyre::Result;
    use jotdown::{html, Parser, Render};

    fn convert(s: &str) -> Result<String> {
        let parser = Parser::new(s);
        let transformed = parser;
        let transformed = AutoFigures::new(parser);
        let mut body = String::new();
        html::Renderer::default().push(transformed, &mut body)?;
        Ok(body)
    }

    #[test]
    fn test_auto_figures() -> Result<()> {
        let s = "![](/images/img.png)";
        assert_eq!(
            convert(s)?,
            r#"<figure>
<img src="/images/img.png" />
</figure>"#
        );

        Ok(())
    }

    //     #[test]
    //     fn test_auto_figures_title() {
    //         let s = "![My *title*](/images/img.png)";
    //         assert_eq!(
    //             convert(s),
    //             r#"<figure>
    // <img src="/images/img.png" />
    // <figcaption>My <em>title</em></figcaption>
    // </figure>"#
    //         );
    //     }
}
