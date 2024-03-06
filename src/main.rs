mod content;
mod feed;
mod gen;
mod item;
mod markup;
mod paths;
mod site;
mod site_url;
mod upload;
mod util;

#[cfg(test)]
mod tests;

use crate::site_url::{HrefUrl, ImgUrl};
use axum::{routing::get_service, Router};
use axum_server::Server;
use camino::Utf8PathBuf;
use clap::{Parser, Subcommand};
use colored::Colorize;
use eyre::Result;
use futures::future::join_all;
use hotwatch::Hotwatch;
use lazy_static::lazy_static;
use paths::AbsPath;
use reqwest::Client;
use s3::creds::Credentials;
use s3::Bucket;
use s3::Region;
use site::{Site, SiteOptions};
use std::{collections::HashSet, net::SocketAddr, thread, time::Duration};
use tower_http::{services::ServeDir, trace::TraceLayer};
use tracing::{error, info};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use upload::SyncOpts;
use url::Url;
use util::parse_html_files;

#[derive(Parser, Debug)]
#[clap(version)]
struct Cli {
    #[clap(subcommand)]
    command: Commands,
    /// Verbose output
    #[clap(short, long)]
    verbose: bool,
}

// FIXME edit/promote/demote should match against title or slug
// case insensitively.
#[derive(Subcommand, Debug)]
enum Commands {
    /// Start a preview server
    Watch,
    /// Generate the site
    Build,
    /// Create a new post and open it for edit
    Post {
        #[clap(required = true)]
        title: Vec<String>,
    },
    /// Create a new draft and open it for edit
    Draft {
        #[clap(required = true)]
        title: Vec<String>,
    },
    /// Promote a draft to a post
    Promote {
        #[clap(required = true)]
        pattern: Vec<String>,
    },
    /// Demote a post to a draft
    Demote {
        #[clap(required = true)]
        pattern: Vec<String>,
    },
    /// Sync all generated files found in `.output`
    Sync,
    /// Upload files from `files` which aren't handled by the site generator
    UploadFiles,
    /// Dump a syntax binary, used to speedup SyntaxSet initialization
    DumpSyntaxBinary,
    /// Dump the CSS of a theme
    DumpTheme { file: Utf8PathBuf },
    /// Check external links
    CheckExternalLinks,
}

lazy_static! {
    static ref CURRENT_DIR: AbsPath = AbsPath::current_dir().unwrap();
    static ref OUTPUT_DIR: AbsPath = CURRENT_DIR.join(".output");
    static ref FILE_DIR: AbsPath = CURRENT_DIR.join("files");
}

static SITE_BUCKET: &str = "www.jonashietala.se";
static FILE_BUCKET: &str = "jonashietala-files";
static REGION: Region = Region::EuWest1;

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    let log_level = if cli.verbose { "debug" } else { "info" };

    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::new(format!(
            "jonashietala_se={log_level},tower_http={log_level}"
        )))
        .with(tracing_subscriber::fmt::layer())
        .init();

    match &cli.command {
        Commands::Build => {
            build()?;
        }
        Commands::Watch => {
            watch().await?;
        }
        Commands::Post { title } => {
            gen::new_post(title.join(" "))?;
        }
        Commands::Draft { title } => {
            gen::new_draft(title.join(" "))?;
        }
        Commands::Promote { pattern } => {
            gen::promote(pattern.join(" "))?;
        }
        Commands::Demote { pattern } => {
            gen::demote(pattern.join(" "))?;
        }
        Commands::Sync => {
            // So we don't forget...
            build()?;

            upload::sync(SyncOpts {
                dir: &OUTPUT_DIR,
                bucket: site_bucket()?,
                delete: true,
                print_urls: false,
            })
            .await?;
        }
        Commands::UploadFiles => {
            upload::sync(SyncOpts {
                dir: &FILE_DIR,
                bucket: file_bucket()?,
                delete: false,
                print_urls: true,
            })
            .await?;
        }
        Commands::DumpSyntaxBinary => {
            markup::dump_syntax_binary()?;
        }
        Commands::DumpTheme { file } => {
            markup::dump_theme(file)?;
        }
        Commands::CheckExternalLinks => {
            check_external_links().await?;
        }
    }

    Ok(())
}

fn site_bucket() -> Result<Bucket> {
    let credentials = Credentials::default()?;
    let bucket = Bucket::new(SITE_BUCKET, REGION.clone(), credentials)?.with_path_style();
    Ok(bucket)
}

fn file_bucket() -> Result<Bucket> {
    let credentials = Credentials::default()?;
    let bucket = Bucket::new(FILE_BUCKET, REGION.clone(), credentials)?;
    Ok(bucket)
}

fn build() -> Result<()> {
    let site = Site::load_content(SiteOptions {
        output_dir: OUTPUT_DIR.clone(),
        input_dir: CURRENT_DIR.clone(),
        clear_output_dir: true,
        include_drafts: false,
        generate_feed: true,
    })?;

    site.render_all()?;

    Ok(())
}

async fn watch() -> Result<()> {
    let mut site = Site::load_content(SiteOptions {
        output_dir: OUTPUT_DIR.clone(),
        input_dir: CURRENT_DIR.clone(),
        clear_output_dir: true,
        include_drafts: true,
        generate_feed: false,
    })?;

    site.render_all()?;

    tokio::task::spawn_blocking(move || {
        let mut hotwatch = Hotwatch::new_with_custom_delay(Duration::from_millis(100))
            .expect("hotwatch failed to initialize!");

        hotwatch
            .watch(".", move |event| {
                if let Err(err) = site.file_changed(event) {
                    error!("{err}");
                }
            })
            .expect("failed to watch folder!");

        loop {
            thread::sleep(Duration::from_secs(1));
        }
    });

    let app = Router::new()
        .fallback(get_service(ServeDir::new(&*OUTPUT_DIR)))
        .layer(TraceLayer::new_for_http());

    let addr = SocketAddr::from(([127, 0, 0, 1], 8080));
    info!("serving site on {addr}");
    Server::bind(addr).serve(app.into_make_service()).await?;

    Ok(())
}

async fn check_external_links() -> Result<()> {
    build()?;
    let files = parse_html_files(&*OUTPUT_DIR)?;

    let mut links = HashSet::new();
    for file in files.values() {
        for link in file.links.iter() {
            if let HrefUrl::External(ref url) = link {
                if url.scheme() != "mailto" {
                    links.insert(url);
                }
            }
        }

        for link in file.imgs.iter() {
            if let ImgUrl::External(ref url) = link {
                links.insert(url);
            }
        }
    }

    let client = Client::new();
    let mut requests = Vec::new();
    for link in links {
        requests.push(check_external_link(&client, link));
    }

    join_all(requests).await;

    Ok(())
}

async fn check_external_link(client: &Client, url: &Url) {
    match client.get(url.as_str()).send().await {
        Ok(response) => {
            let status = response.status();
            if status.is_success() {
                // FIXME or only show errors? Lots of links here...
                print!("{}", status.as_str().green());
            } else {
                print!("{}", status.as_str().red());
            }
            println!(" {url}");
        }
        Err(err) => {
            println!("{} parsing {url}: {err}", "Error".red());
        }
    }
}
