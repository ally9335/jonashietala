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
import Data.Maybe (fromMaybe)
import Control.Applicative (Alternative (..))

import Text.Blaze.Html (toHtml, toValue, (!))
import Text.Blaze.Html.Renderer.String (renderHtml)
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A

-- Unicode friendly regex
-- This is the only library I found which has subtitutions and unicode support
import qualified Text.Regex.PCRE.Light as RL
import qualified Text.Regex.PCRE.Heavy as RH

import Hakyll
import Text.Sass.Options
import Text.Pandoc

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

postsGlob = "posts/*.markdown"


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

    tags <- buildTags postsGlob (fromCapture "tags/*")

    match "static/*.markdown" $ do
        route   staticRoute
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/static.html" siteCtx
            >>= loadAndApplyTemplate "templates/site.html" siteCtx
            >>= deIndexUrls

    match "static/*.txt" $ do
        route   txtStaticRoute
        compile getResourceString

    match "static/*.html" $ do
        route   staticRoute
        compile copyFileCompiler

    match postsGlob $ do
        let ctx = (postCtx tags)

        route   postRoute
        compile $ do
            pandocCompilerWith feedReaderOptions feedWriterOptions
                >>= applyFilter youtubeFilter
                >>= return . fmap demoteHeaders
                >>= loadAndApplyTemplate "templates/post.html" ctx
                >>= saveSnapshot "feed"
            pandocCompiler
                >>= applyFilter youtubeFilter
                >>= return . fmap demoteHeaders
                >>= saveSnapshot "demoted_content"
                >>= loadAndApplyTemplate "templates/post.html" ctx
                >>= loadAndApplyTemplate "templates/site.html" ctx
                >>= deIndexUrls

    match "drafts/*.markdown" $ do
        let ctx = (draftCtx tags)

        route   draftRoute
        compile $ pandocCompiler
            >>= applyFilter youtubeFilter
            >>= return . fmap demoteHeaders
            >>= loadAndApplyTemplate "templates/post.html" ctx
            >>= loadAndApplyTemplate "templates/site.html" ctx
            >>= deIndexUrls

    create ["blog/index.html"] $ do
        route idRoute
        compile $ do
            let ctx = constField "title" "My Weblog" <> siteCtx

            loadAllSnapshots "posts/*.markdown" "demoted_content"
                >>= recentFirst
                >>= loadAndApplyTemplateList "templates/post.html" (postInListCtx tags)
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
        compile $ draftArchiveCompiler title tags pattern "templates/post-list.html"

    -- Pages for individual tags
    tagsRules tags $ \tag pattern -> do
        let title = "Posts tagged: " ++ tag

        route   tagRoute
        compile $ archiveCompiler title tags pattern "templates/post-list.html"

    -- All tags list
    create ["blog/tags/index.html"] $ do
        let ctx = tagsCtx (\_ -> renderTagHtmlList (sortTagsBy tagSort tags))

        route idRoute
        compile $ makeItem ""
            >>= loadAndApplyTemplate "templates/tags.html" ctx
            >>= loadAndApplyTemplate "templates/site.html" ctx
            >>= deIndexUrls

    -- Projects page
    match "projects/*.markdown" $ do
        compile $ pandocCompiler
            >>= saveSnapshot "content"

    match "projects/games/*.markdown" $ do
        compile $ pandocCompiler
            >>= saveSnapshot "content"

    gamesDependencies <- makePatternDependency "projects/games/*.markdown"
    projectDependencies <- makePatternDependency "projects/*.markdown"
    rulesExtraDependencies [gamesDependencies, projectDependencies] $ do
        match "projects.markdown" $ do
            route   $ customRoute (const "projects/index.html")
            compile $ do
                games <- renderGamesList "projects/games/*.markdown"
                projects <- renderProjects "projects/*.markdown"
                let ctx = projectsCtx projects games

                pandocCompiler
                    >>= loadAndApplyTemplate "templates/projects.html" ctx
                    >>= loadAndApplyTemplate "templates/site.html" ctx
                    >>= deIndexUrls

    -- Main page
    match "about.markdown" $ do
        route   $ customRoute (const "index.html")
        compile $ do
            posts <- renderPostList tags "posts/*" $ fmap (take 5) . recentFirst
            recommended <- renderPostList tags (foldr1 (.||.) recommended) $ recentFirst

            pandocCompiler
                >>= loadAndApplyTemplate "templates/homepage.html" (homepageCtx posts recommended)
                >>= loadAndApplyTemplate "templates/site.html" (postCtx tags)
                >>= deIndexUrls

    match "templates/*" $ compile templateCompiler

    create ["feed.xml"] $ do
        route idRoute
        compile $ do
            let feedCtx = (postCtx tags) <> bodyField "description"

            posts <- fmap (take 30) . recentFirst =<<
                loadAllSnapshots "posts/*.markdown" "feed"
            renderAtom myFeedConfiguration feedCtx posts


-- Sort tags after number of posts in tag
tagSort :: (String, [Identifier]) -> (String, [Identifier]) -> Ordering
tagSort a b = comparing (length . snd) b a

-- Find and replace bare youtube links separated by <p></p>.
youtubeFilter :: String -> String
youtubeFilter txt = RH.gsub rx replace txt
    where
      rx = RL.compile "<p>\\s*https?://www\\.youtube\\.com/watch\\?v=([A-Za-z0-9_-]+)\\s*</p>"
                      [RL.utf8]
      replace = \[g] -> "<div class=\"video-wrapper\">\
                 \<div class=\"video-container\">\
                   \<iframe src=\"//www.youtube.com/embed/" ++ g ++ "\" frameborder=\"0\" allowfullscreen/>\
                 \</div>\
              \</div>";

applyFilter :: (Monad m, Functor f) => (String-> String) -> f String -> m (f String)
applyFilter transformator str = return $ (fmap $ transformator) str


archiveCompiler :: String
                -> Tags
                -> Pattern
                -> Identifier
                -> Compiler (Item String)
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


draftArchiveCompiler :: String
                     -> Tags 
                     -> Pattern 
                     -> Identifier 
                     -> Compiler (Item String)
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
    where args = ["-s", "-I", "css/", "--style", "compressed"]


siteCtx :: Context String
siteCtx = mconcat
    [ defaultContext
    , constField "mail" mail
    , constField "name" name
    , metaKeywordCtx
    ]


postInListCtx :: Tags -> Context String
postInListCtx tags = mconcat
    [ siteCtx
    , dateField "date" "%B %e, %Y"
    , dateField "ymd" "%F"
    , tagsField "linked_tags" tags
    ]


postCtx :: Tags -> Context String
postCtx tags = mconcat
    [ postInListCtx tags
    , field "nextPostUrl" nextPostUrl
    , field "prevPostUrl" prevPostUrl
    , field "nextPostTitle" nextPostTitle
    , field "prevPostTitle" prevPostTitle
    ]


draftCtx :: Tags -> Context String
draftCtx tags = mconcat
    [ siteCtx
    , constField "date" "January 1, 2000"
    , constField "ymd" "2000-01-01"
    , tagsField "linked_tags" tags
    ]

gameCtx :: Context String
gameCtx = mconcat
    [ siteCtx
    , dateField "date" "%B %e, %Y"
    , dateField "ymd" "%F"
    ]

projectsCtx :: String -> String -> Context String
projectsCtx projects games = mconcat
    [ siteCtx
    , constField "projects" projects
    , constField "games" games
    ]

homepageCtx :: String -> String -> Context String
homepageCtx posts recommended = mconcat
    [ siteCtx
    , constField "posts" posts
    , constField "recommended" recommended
    ]

tagsCtx :: (Item String -> Compiler String) -> Context String
tagsCtx tags = mconcat
    [ siteCtx
    , field "tags" tags
    ]


-- 'metaKeywords' from tags for insertion in header. Empty if no tags are found.
metaKeywordCtx :: Context String
metaKeywordCtx = field "metaKeywords" $ \item -> do
    tags <- getMetadataField (itemIdentifier item) "tags"
    return $ maybe "" showMetaTags tags
      where
        showMetaTags t = "<meta name=\"keywords\" content=\"" ++ t ++ "\">"


-- previous-next links from:
-- http://magnus.therning.org/posts/2014-09-27-000-previous-next-links.html
-- It's slow but it works...
-- Don't know how to speed it up iether. We could try to cache idents but
-- we can't pass extra data through field in postCtx. Urgh.
withRelatedPost:: (MonadMetadata m, Alternative m) =>
    (Identifier -> [Identifier] -> Maybe t) -> (t -> m b) -> Pattern -> Item a -> m b
withRelatedPost r f pattern item = do
    idents <- getMatches pattern >>= sortRecentFirst
    let id = itemIdentifier item
        prevId = r id idents
    case prevId of
        Just i -> f i
        Nothing -> empty

withPreviousPost :: (MonadMetadata m, Alternative m) => (Identifier -> m b) -> Pattern -> Item a -> m b
withPreviousPost = withRelatedPost itemAfter
    where
        itemAfter x xs = lookup x $ zip xs (tail xs)

withNextPost :: (MonadMetadata m, Alternative m) => (Identifier -> m b) -> Pattern -> Item a -> m b
withNextPost = withRelatedPost itemBefore
    where
        itemBefore x xs = lookup x $ zip (tail xs) xs

prevPostUrl :: Item String -> Compiler String
prevPostUrl = withPreviousPost (fmap (maybe empty toUrl) . getRoute) postsGlob

prevPostTitle :: Item String -> Compiler String
prevPostTitle = withPreviousPost (\ i -> getMetadataField' i "title") postsGlob

nextPostUrl :: Item String -> Compiler String
nextPostUrl = withNextPost (fmap (maybe empty toUrl) . getRoute) postsGlob

nextPostTitle :: Item String -> Compiler String
nextPostTitle = withNextPost (flip getMetadataField' "title") postsGlob


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
     -- Not sure how to just send settings, this can be used in templates $if(...)$
    let ctx = (postInListCtx tags)
    posts <- postList pattern filter
    loadAndApplyTemplateList "templates/post-item.html" ctx posts


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


renderGamesList :: Pattern -> Compiler String
renderGamesList pattern = do
    loadAllSnapshots pattern "content"
        >>= recentFirst
        >>= loadAndApplyTemplateList "templates/game-item.html" gameCtx


renderProjects :: Pattern -> Compiler String
renderProjects pattern = do
    loadAllSnapshots pattern "content"
        >>= loadAndApplyTemplateList "templates/project.html" siteCtx


postRoute :: Routes
postRoute = replacePosts `composeRoutes`
            dateRoute `composeRoutes`
            dropIndexRoute


staticRoute :: Routes
staticRoute = gsubRoute "static/" (const "") `composeRoutes`
              dropIndexRoute

draftRoute :: Routes
draftRoute = dropIndexRoute


txtStaticRoute :: Routes
txtStaticRoute = gsubRoute "static/" (const "") `composeRoutes`
                 setExtension ".txt"


tagRoute :: Routes
tagRoute = (customRoute $ (map toLower) . (replace " " "_") . toFilePath) `composeRoutes`
           gsubRoute "tags/" (const "blog/tags/") `composeRoutes`
           dropIndexRoute


replacePosts :: Routes
replacePosts = gsubRoute "posts/" (const "blog/")


dateRoute :: Routes
dateRoute =
  gsubRoute "/[0-9]{4}-[0-9]{2}-[0-9]{2}-" (replace "-" "/")


-- Move to subdirectories to avoid extensions in links.
dropIndexRoute :: Routes
dropIndexRoute = customRoute $
     (++ "/index.html") . dropExtension . toFilePath


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


-- Turn off code parsing for feed
-- The only way I found how to turn off line links. It messes up feed readers badly.
feedReaderOptions :: ReaderOptions
feedReaderOptions = defaultHakyllReaderOptions
    { readerExtensions = disableExtension Ext_fenced_code_attributes pandocExtensions }

feedWriterOptions :: WriterOptions
feedWriterOptions = defaultHakyllWriterOptions
    { writerExtensions = disableExtension Ext_fenced_code_attributes pandocExtensions }
