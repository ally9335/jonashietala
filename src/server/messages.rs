use serde::{Deserialize, Serialize};

use crate::content::PostItem;
use crate::markup::markup_lookup::{Heading, LinkDef};

#[derive(Debug, Serialize)]
#[serde(tag = "type")]
pub enum WebEvent {
    RefreshAll,
    RefreshPage {
        path: String,
    },
    PositionPage {
        path: String,
        linenum: u32,
        linecount: u32,
    },
}

#[derive(Debug, Deserialize)]
#[serde(tag = "id")]
pub enum NeovimEvent {
    CursorMoved {
        linenum: u32,
        linecount: u32,
        column: u32,
        path: String,
    },
    ListTags {
        message_id: u64,
    },
    ListSeries {
        message_id: u64,
    },
    ListUrls {
        message_id: u64,
    },
    ListLinkDefs {
        message_id: u64,
        path: String,
    },
    ListHeadings {
        message_id: u64,
        path: String,
    },
    GotoDef {
        message_id: u64,
        linenum: usize,
        column: usize,
        path: String,
    },
}

#[derive(Debug, Serialize)]
pub struct TagInfo {
    pub id: String,
    pub name: String,
    pub url: String,
    pub posts: Vec<PostInfo>,
}

#[derive(Debug, Serialize)]
pub struct PostInfo {
    pub title: String,
    pub url: String,
    pub tags: Vec<String>,
    pub series: Option<String>,
}

impl From<&PostItem> for PostInfo {
    fn from(post: &PostItem) -> Self {
        PostInfo {
            title: post.title.to_string(),
            url: post.url.href().to_string(),
            tags: post.tags.iter().map(|tag| tag.name.to_string()).collect(),
            series: post.series.as_ref().map(|x| x.id.clone()),
        }
    }
}

#[derive(Debug, Serialize)]
pub struct SeriesInfo {
    pub id: String,
    pub title: String,
    pub url: String,
    pub posts: Vec<PostInfo>,
}

#[derive(Debug, Serialize)]
pub struct UrlInfo {
    pub title: String,
    pub url: String,
}

#[derive(Debug, Serialize)]
pub struct LinkDefInfo {
    pub label: String,
    pub url: String,
}

impl From<&LinkDef> for LinkDefInfo {
    fn from(def: &LinkDef) -> Self {
        LinkDefInfo {
            label: def.label.clone(),
            url: def.url.clone(),
        }
    }
}

#[derive(Debug, Serialize)]
pub struct HeadingInfo {
    pub id: String,
    pub content: String,
}

impl From<&Heading> for HeadingInfo {
    fn from(heading: &Heading) -> Self {
        HeadingInfo {
            id: heading.id.clone(),
            content: heading.content.clone(),
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(tag = "id")]
pub enum NeovimResponse {
    ListTags {
        message_id: u64,
        tags: Vec<TagInfo>,
    },
    ListSeries {
        message_id: u64,
        series: Vec<SeriesInfo>,
    },
    ListUrls {
        message_id: u64,
        urls: Vec<UrlInfo>,
    },
    ListLinkDefs {
        message_id: u64,
        defs: Vec<LinkDefInfo>,
    },
    ListHeadings {
        message_id: u64,
        headings: Vec<HeadingInfo>,
    },
    GotoDef {
        message_id: u64,
        linenum: Option<usize>,
        column: Option<usize>,
        path: Option<String>,
    },
}
