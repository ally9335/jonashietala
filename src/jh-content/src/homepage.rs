use std::collections::BTreeMap;
use std::fs;

use eyre::Result;
use serde::Serialize;
use tera::Context;

use crate::content::posts::{PostItem, PostRef};
use crate::markdown::markdown_to_html;
use crate::paths::AbsPath;
use crate::{item::RenderContext, item::TeraItem, site_url::SiteUrl};

use super::posts::PostRefContext;

#[derive(Debug)]
pub struct HomepageItem {
    pub about: String,
    pub url: SiteUrl,
    pub recent: Vec<PostRef>,
    pub recommended: Vec<PostRef>,
}

impl HomepageItem {
    pub fn new(dir: &AbsPath, posts: &BTreeMap<PostRef, PostItem>) -> Result<Self> {
        let about = fs::read_to_string(dir.join("about.markdown"))?;
        let url = SiteUrl::parse("/").expect("Should be able to create a url");

        let recent = posts.keys().take(5).map(Clone::clone).collect();
        let recommended = posts
            .iter()
            .filter(|(_, post)| post.recommended)
            .map(|(post_ref, _)| post_ref.clone())
            .collect();

        Ok(Self {
            url,
            about,
            recommended,
            recent,
        })
    }
}

impl TeraItem for HomepageItem {
    fn context(&self, ctx: &RenderContext) -> Context {
        Context::from_serialize(HomepageContext {
            title: "Home",
            about: markdown_to_html(&self.about),
            recommended: self
                .recommended
                .iter()
                .map(|x| PostRefContext::from_ref(x, ctx))
                .collect(),
            recent: self
                .recent
                .iter()
                .map(|x| PostRefContext::from_ref(x, ctx))
                .collect(),
        })
        .unwrap()
    }

    fn template(&self) -> &str {
        "homepage.html"
    }

    fn url(&self) -> &SiteUrl {
        &self.url
    }
}

#[derive(Debug, Clone, Serialize)]
struct HomepageContext<'a> {
    title: &'static str,
    about: String,
    recommended: Vec<PostRefContext<'a>>,
    recent: Vec<PostRefContext<'a>>,
}
