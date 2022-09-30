use lazy_static::lazy_static;
use url::Url;

lazy_static! {
    pub static ref BASE_SITE_URL: Url = Url::parse("https://jonashietala.se").unwrap();
}
