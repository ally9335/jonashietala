#![cfg(test)]

use crate::content::SeriesItem;
use crate::paths::AbsPath;
use crate::site::{Site, SiteOptions};
use crate::site_url::{HrefUrl, ImgUrl};
use camino::Utf8Path;
use camino::Utf8PathBuf;
use eyre::Result;
use hotwatch::Event;
use lazy_static::lazy_static;
use regex::Regex;
use std::fs;
use std::path::PathBuf;
use tempfile::TempDir;
use tera::Tera;
use thiserror::Error;

use crate::{content::PostItem, util::load_templates, util::ParsedFile, util::ParsedFiles};

pub struct TestSite {
    pub site: Site,
    pub output_dir: TempDir,
    pub input_dir: TempDir,
}

impl TestSite {
    pub fn change_file(&mut self, file: &str, from: &str, to: &str) -> Result<()> {
        let path = self.input_dir.path().join(file);
        let content = fs::read_to_string(&path)?.replace(from, to);
        fs::write(&path, content)?;
        self.site.file_changed(Event::Write(path))
    }

    pub fn find_post<'a>(&'a self, file: &str) -> Option<&'a PostItem> {
        self.site
            .content
            .posts
            .values()
            .find(|post| post.path.file_name() == Some(file))
    }

    pub fn find_series<'a>(&'a self, file: &str) -> Option<&'a SeriesItem> {
        self.site
            .content
            .series
            .values()
            .find(|series| series.path.file_name() == Some(file))
    }

    pub fn output_path(&self, file: &str) -> AbsPath {
        AbsPath::from_path_buf(self.output_dir.path().join(file))
    }

    pub fn output_content(&self, file: &str) -> Result<String> {
        let path = self.output_path(file);
        let content = fs::read_to_string(&path)?;
        Ok(content)
    }

    pub fn read_file_to_string(&self, file: &str) -> std::io::Result<String> {
        fs::read_to_string(self.output_path(file))
    }

    /// Persist the input and output dir, allowing us to inspect them
    /// after test has finished.
    #[allow(dead_code)]
    pub fn persist(self) -> (PathBuf, PathBuf) {
        let TestSite {
            output_dir,
            input_dir,
            ..
        } = self;
        (input_dir.into_path(), output_dir.into_path())
    }

    #[allow(dead_code)]
    pub fn skip_clean(self) {
        let (input_dir, output_dir) = self.persist();
        println!(
            "Skipping cleaning\n  input: {}\n  output: {}",
            input_dir.display(),
            output_dir.display()
        );
    }
}

pub struct TestSiteBuilder {
    pub include_drafts: bool,
}

impl TestSiteBuilder {
    pub fn build(self) -> Result<TestSite> {
        let (output_dir, output_path) = AbsPath::new_tempdir()?;
        let (input_dir, input_path) = AbsPath::new_tempdir()?;

        fs_extra::dir::copy(
            "test-site",
            &input_path,
            &fs_extra::dir::CopyOptions {
                content_only: true,
                ..Default::default()
            },
        )?;

        let site = Site::load_content(SiteOptions {
            output_dir: output_path,
            input_dir: input_path,
            clear_output_dir: false,
            include_drafts: self.include_drafts,
        })?;
        site.render_all()?;

        Ok(TestSite {
            site,
            output_dir,
            input_dir,
        })
    }
}

pub fn templates() -> &'static Tera {
    lazy_static! {
        static ref TEMPLATES: Tera = load_templates("templates/*.html").unwrap();
    }
    &TEMPLATES
}

#[derive(Error, Debug)]
pub enum GeneratedFileError<'a> {
    #[error("missing doctype")]
    MissingDocType,
    #[error("broken link `{0}`")]
    BrokenLink(&'a str),
    #[error("url not found `{0}`")]
    UrlNotFound(String),
    #[error("img not found `{0}`")]
    LocalImgNotFound(String),
    #[error("fragment not found `{0}`")]
    LocalFragmentNotFound(&'a str),
    #[error("fragment `{0}` not found in `{1}`")]
    OtherFragmentNotFound(String, Utf8PathBuf),
}

pub fn check_file<'a>(
    file: &'a ParsedFile,
    files: &'a ParsedFiles,
    output_dir: &Utf8Path,
) -> Vec<GeneratedFileError<'a>> {
    lazy_static! {
        static ref BROKEN_LINK: Regex = Regex::new(r"\[[^[\]]]+]\[[^[\]]]*]").unwrap();
    }
    let mut errors = Vec::new();
    if !file.content.starts_with("<!DOCTYPE html>") {
        errors.push(GeneratedFileError::MissingDocType);
    }

    // FIXME these gives false positives when they're inside a code block.
    // Maybe find start/end of all code blocks, and then only add them if they're outside?
    for bad_link in BROKEN_LINK.find_iter(&file.content) {
        errors.push(GeneratedFileError::BrokenLink(bad_link.as_str()));
    }

    let mut links: Vec<&HrefUrl> = file.links.iter().collect();
    links.sort();

    for link in links {
        match link {
            HrefUrl::Internal(ref internal) => {
                let output_file = internal.output_file(output_dir);

                let external_ref = match files.get(&output_file) {
                    Some(file) => file,
                    None => {
                        errors.push(GeneratedFileError::UrlNotFound(internal.href().to_string()));
                        continue;
                    }
                };

                if let Some(fragment) = internal.fragment() {
                    let fragment = format!("#{fragment}");
                    if !external_ref.fragments.contains(&fragment) {
                        errors.push(GeneratedFileError::OtherFragmentNotFound(
                            fragment,
                            external_ref.path.clone(),
                        ));
                    }
                }
            }
            HrefUrl::Fragment(ref fragment) => {
                if !file.fragments.contains(fragment) {
                    errors.push(GeneratedFileError::LocalFragmentNotFound(fragment));
                }
            }
            HrefUrl::External(_) => {}
        }
    }

    let mut imgs: Vec<&ImgUrl> = file.imgs.iter().collect();
    imgs.sort();

    for img in imgs {
        match img {
            ImgUrl::Internal(ref internal) => {
                let output_file = internal.output_file(output_dir);
                if !output_file.exists() {
                    errors.push(GeneratedFileError::LocalImgNotFound(
                        internal.href().to_string(),
                    ));
                }
            }
            ImgUrl::External(_) => {}
        }
    }

    errors
}
