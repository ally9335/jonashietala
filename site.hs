{-# LANGUAGE OverloadedStrings #-}
-- Workaround for new ghc features.
-- I'm not smart enough to figure out how to modify the code for this.
{-# LANGUAGE FlexibleContexts #-}

import Control.Applicative ((<$>))
import Data.Monoid (mappend, mconcat, (<>))
import Data.Char (toLower)
import Data.List (intercalate, isSuffixOf)
import Data.List.Utils (replace)
import Data.Ord (comparing)
import System.FilePath  (dropExtension, splitFileName, joinPath)

import Text.Blaze.Html (toHtml, toValue, (!))
import Text.Blaze.Html.Renderer.String (renderHtml)
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A
import Text.Regex (subRegex, mkRegex)

import Hakyll
import Text.Sass.Options

mail = "mail@jonashietala.se"
name = "Jonas Hietala"
siteRoot = "http://www.jonashietala.se"


myFeedConfiguration :: FeedConfiguration
myFeedConfiguration = FeedConfiguration
    { feedTitle       = name ++ ": All posts"
    , feedDescription = "Personal blog of " ++ name
    , feedAuthorName  = name
    , feedAuthorEmail = mail
    , feedRoot        = siteRoot
    }


config :: Configuration
config = defaultConfiguration
    { deployCommand = "./sync --site" }


-- Recommended posts on home page
recommended :: [Pattern]
recommended = [ "posts/2015-07-22-5_years_at_the_university.markdown"
              , "posts/2014-10-06-ida_summer_of_code_2014_summary.markdown"
              , "posts/2014-07-13-summer_job_at_configura.markdown"
              , "posts/2013-01-20-i_robot.markdown"
              , "posts/2010-06-01-game_design_analysis_world_of_goo.markdown"
              ]


main :: IO ()
main = hakyllWith config $ do
    match ("images/**" .||. "favicon.ico" .||. "fonts/**") $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*.scss" $ do
        compile getResourceBody

    -- Enable hot reload when changing an imported stylesheet
    scssDependencies <- makePatternDependency "css/*.scss"
    rulesExtraDependencies [scssDependencies] $ do
        create ["css/main.css"] $ do
            route   idRoute
            compile sassCompiler

    tags <- buildTags "posts/*.markdown" (fromCapture "tags/*")

    match "static/*.markdown" $ do
        route   staticRoute
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/static.html" defaultContext
            >>= loadAndApplyTemplate "templates/site.html" siteCtx
            >>= deIndexUrls

    match "static/*.html" $ do
        route   staticRoute
        compile copyFileCompiler

    match "posts/*.markdown" $ do
        route   postRoute
        compile $ pandocCompiler
            >>= applyFilter youtubeFilter
            >>= saveSnapshot "content"
            >>= return . fmap demoteHeaders
            >>= saveSnapshot "demoted_content"
            >>= loadAndApplyTemplate "templates/post.html" (postCtx tags)
            >>= saveSnapshot "post"
            >>= loadAndApplyTemplate "templates/site.html" (postCtx tags)
            >>= deIndexUrls

    match "drafts/*.markdown" $ do
        route   draftRoute
        compile $ pandocCompiler
            >>= applyFilter youtubeFilter
            >>= return . fmap demoteHeaders
            >>= loadAndApplyTemplate "templates/post.html" (draftCtx tags)
            >>= loadAndApplyTemplate "templates/site.html" (draftCtx tags)
            >>= deIndexUrls

    create ["blog/index.html"] $ do
        route idRoute
        compile $ do
            let ctx = constField "title" "My Weblog" <> siteCtx

            loadAllSnapshots "posts/*.markdown" "demoted_content"
                >>= recentFirst
                >>= loadAndApplyTemplateList "templates/post.html" (postCtx tags)
                >>= makeItem
                >>= loadAndApplyTemplate "templates/posts.html" ctx
                >>= loadAndApplyTemplate "templates/site.html" ctx
                >>= deIndexUrls

    create ["archive/index.html"] $ do
        let title = "The Archives"
        let pattern = "posts/*.markdown"

        route   idRoute
        compile $ archiveCompiler title tags pattern "templates/archive.html"

    create ["drafts/index.html"] $ do
        let title = "All drafts"
        let pattern = "drafts/*.markdown"

        route   idRoute
        compile $ draftArchiveCompiler title tags pattern "templates/drafts.html"

    tagsRules tags $ \tag pattern -> do
        let title = "Posts tagged: " ++ tag

        route   tagRoute
        compile $ archiveCompiler title tags pattern "templates/tags-archive.html"

    match "projects/*.markdown" $ do
        compile $ pandocCompiler
            >>= saveSnapshot "content"

    match "projects/games/*.markdown" $ do
        compile $ pandocCompiler
            >>= saveSnapshot "content"

    gamesDependencies <- makePatternDependency "projects/games/*.markdown"
    projectDependencies <- makePatternDependency "projects/*.markdown"
    rulesExtraDependencies [gamesDependencies, projectDependencies] $ do
        create ["projects/index.html"] $ do
            route   idRoute
            compile $ do
                games <- renderGamesList "projects/games/*.markdown"
                let ctx = constField "title" "Projects" <>
                          constField "games" games <>
                          --listField "games" (field "game" (return . itemBody)
                          siteCtx

                loadAllSnapshots "projects/*.markdown" "content"
                    -- Should be able to apply template in project?
                    >>= loadAndApplyTemplateList "templates/project.html" defaultContext
                    >>= makeItem
                    >>= loadAndApplyTemplate "templates/projects.html" ctx
                    >>= loadAndApplyTemplate "templates/site.html" ctx
                    >>= deIndexUrls

    -- Main page
    match "about.markdown" $ do
        route   $ customRoute (const "index.html")
        compile $ do
            list <- renderPostList tags "posts/*" $ fmap (take 5) . recentFirst
            recommended <- renderPostList tags (foldr1 (.||.) recommended) $ recentFirst
            let ctx = constField "posts" list <>
                      constField "recommended" recommended <>
                      --field "tags" (\_ -> renderTagList (sortTagsBy tagSort tags)) <>
                      field "tags" (\_ -> renderTagHtmlList (sortTagsBy tagSort tags)) <>
                      --field "tags" (\_ -> renderTagCloud 80 160 tags) <>
                      siteCtx

            pandocCompiler
                >>= loadAndApplyTemplate "templates/homepage.html" ctx
                >>= loadAndApplyTemplate "templates/site.html" (postCtx tags)
                >>= deIndexUrls

    match "templates/*" $ compile templateCompiler

    create ["feed.xml"] $ do
        route idRoute
        compile $ do
            let feedCtx = (postCtx tags) <> bodyField "description"
            posts <- fmap (take 30) . recentFirst =<<
                loadAllSnapshots "posts/*.markdown" "post"
            renderAtom myFeedConfiguration feedCtx posts


-- Sort tags after number of posts in tag
tagSort :: (String, [Identifier]) -> (String, [Identifier]) -> Ordering
tagSort a b = comparing (length . snd) b a


-- Find and replace bare youtube links separated by <p></p>.
youtubeFilter :: String -> String
youtubeFilter x = subRegex regex x result
  where
    regex = mkRegex "<p>https?://www\\.youtube\\.com/watch\\?v=([A-Za-z0-9_-]+)</p>"
    result = "<div class=\"video-wrapper\">\
                \<div class=\"video-container\">\
                  \<iframe src=\"//www.youtube.com/embed/\\1\" frameborder=\"0\" allowfullscreen/>\
                \</div>\
             \</div>";

applyFilter :: (Monad m, Functor f) => (String-> String) -> f String -> m (f String)
applyFilter transformator str = return $ (fmap $ transformator) str


archiveCompiler :: String -> Tags -> Pattern -> Identifier -> Compiler (Item String)
archiveCompiler title tags pattern tpl = do
    list <- renderPostList tags pattern recentFirst
    let ctx = mconcat
            [ constField "posts" list
            , constField "title" title
            , siteCtx
            ]

    makeItem ""
        >>= loadAndApplyTemplate tpl ctx
        >>= loadAndApplyTemplate "templates/site.html" ctx
        >>= deIndexUrls


draftArchiveCompiler :: String -> Tags -> Pattern -> Identifier -> Compiler (Item String)
draftArchiveCompiler title tags pattern tpl = do
    list <- renderDraftList tags pattern recentFirst
    let ctx = mconcat
            [ constField "posts" list
            , constField "title" title
            , siteCtx
            ]

    makeItem ""
        >>= loadAndApplyTemplate tpl ctx
        >>= loadAndApplyTemplate "templates/site.html" ctx
        >>= deIndexUrls


sassCompiler :: Compiler (Item String)
sassCompiler = loadBody "css/main.scss"
                >>= makeItem
                >>= withItemBody (unixFilter "sassc" args)
    where args = ["-s", "-I", "css/"]


siteCtx :: Context String
siteCtx = mconcat
    [ constField "mail" mail
    , constField "name" name
    , metaKeywordCtx
    , defaultContext
    , constField "gpg" "http://pgp.mit.edu/pks/lookup?op=get&search=0x48347567AD15CC54"
    ]

postCtx :: Tags -> Context String
postCtx tags = mconcat
    [ dateField "date" "%B %e, %Y"
    , dateField "ymd" "%F"
    , tagsField "tags" tags
    , siteCtx
    ]

draftCtx :: Tags -> Context String
draftCtx tags = mconcat
    [ constField "date" "January 1, 2000"
    , constField "ymd" "2000-01-01"
    , tagsField "tags" tags
    , siteCtx
    ]

gameCtx :: Context String
gameCtx = mconcat
    [ dateField "date" "%B %e, %Y"
    , dateField "ymd" "%F"
    , siteCtx
    ]

-- 'metaKeywords' from tags for insertion in header. Empty if no tags are found.
metaKeywordCtx :: Context String
metaKeywordCtx = field "metaKeywords" $ \item -> do
    tags <- getMetadataField (itemIdentifier item) "tags"
    return $ maybe "" showMetaTags tags
      where
        showMetaTags t = "<meta name=\"keywords\" content=\"" ++ t ++ "\">"


postList :: Pattern
         -> ([Item String]
         -> Compiler [Item String])
         -> Compiler [Item String]
postList pattern filter = filter =<< loadAll pattern


renderPostList :: Tags
               -> Pattern
               -> ([Item String]
               -> Compiler [Item String])
               -> Compiler String
renderPostList tags pattern filter = do
    posts <- postList pattern filter
    loadAndApplyTemplateList "templates/post-item.html" (postCtx tags) posts


renderDraftList :: Tags
               -> Pattern
               -> ([Item String]
               -> Compiler [Item String])
               -> Compiler String
renderDraftList tags pattern filter = do
    drafts <- loadAll pattern
    loadAndApplyTemplateList "templates/draft-item.html" (draftCtx tags) drafts


renderTagHtmlList :: Tags -> Compiler (String)
renderTagHtmlList = renderTags makeLink makeList
  where
    makeLink tag url count _ _ = renderHtml $ H.li $
        H.a ! A.href (toValue url) $ toHtml (tag ++ " (" ++ show count ++ ")")
    makeList tags = renderHtml $ H.ul $ H.preEscapedToHtml (intercalate "" tags)


--gamesList :: Compiler [Item String]
--gamesList = loadAll "templates/games/*.markdown"


renderGamesList :: Pattern -> Compiler String
renderGamesList pattern = do
    loadAllSnapshots "projects/games/*.markdown" "content"
        >>= recentFirst
        >>= loadAndApplyTemplateList "templates/game-item.html" gameCtx


postRoute :: Routes
postRoute = replacePosts `composeRoutes`
            dateRoute `composeRoutes`
            dropIndexRoute


staticRoute :: Routes
staticRoute = gsubRoute "static/" (const "") `composeRoutes`
              dropIndexRoute

draftRoute :: Routes
draftRoute = dropIndexRoute


tagRoute :: Routes
tagRoute = gsubRoute "tags/" (const "blog/tags/") `composeRoutes`
           dropIndexRoute


replacePosts :: Routes
replacePosts = gsubRoute "posts/" (const "blog/")


dateRoute :: Routes
dateRoute =
  gsubRoute "/[0-9]{4}-[0-9]{2}-[0-9]{2}-" (replace "-" "/")


-- Move to subdirectories to avoid extensions in links.
dropIndexRoute :: Routes
dropIndexRoute = customRoute $
     (++ "/index.html"). dropExtension . toFilePath


deIndexUrls :: Item String -> Compiler (Item String)
deIndexUrls item = return $ fmap (withUrls stripIndex) item


stripIndex :: String -> String
stripIndex url =
    if "index.html" `isSuffixOf` url && elem (head url) ['/', '.']
    then take (length url - 10) url
    else url


loadAndApplyTemplateList :: Identifier
                         -> Context a
                         -> [Item a]
                         -> Compiler String
loadAndApplyTemplateList i c is = do
    t <- loadBody i
    applyTemplateList t c is


-- Haxy way of joining snapshots of text.
joinBodies :: [Item String] -> Compiler String
joinBodies items =
    let tpl = readTemplate $ "$body$"
    in applyJoinTemplateList "" tpl defaultContext items

