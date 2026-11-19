--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Hakyll
import           Data.List           (intersperse)
import           Data.Time           (defaultTimeLocale, formatTime, getCurrentTime)
import           System.Process      (readProcess)
import           Text.Pandoc.Options (HTMLMathMethod (MathML), WriterOptions (..))

--------------------------------------------------------------------------------
config :: Configuration
config = defaultConfiguration
    {
        destinationDirectory = "docs"
    }

mdCompiler :: Compiler (Item String)
mdCompiler = pandocCompilerWith defaultHakyllReaderOptions
  defaultHakyllWriterOptions 
  {
    writerHTMLMathMethod = MathML 
  }

readTimeField :: Context String
readTimeField = field "readtime" $ \item -> do
  body <- loadSnapshotBody (itemIdentifier item) "content"
  return (show (max 1 (length (words body) `div` 220)) ++ " min")

postCtx :: Tags -> Context String
postCtx tags =
     dateField "date" "%Y-%m-%d"
  <> tagsFieldWith getTags simpleRenderLink (mconcat . intersperse " ") "tags" tags
  <> defaultContext

main :: IO ()
main = do
    rev <- takeWhile (/= '\n') <$> readProcess "git" ["rev-parse", "--short", "HEAD"] ""
    now <- getCurrentTime
    let siteCtx = constField "rev" rev
                <> constField "built" (formatTime defaultTimeLocale "%Y-%m-%d" now)
                <> readTimeField
                <> defaultContext

    hakyllWith config $ do
        match "images/*" $ route idRoute >> compile copyFileCompiler
        match "files/*"  $ route idRoute >> compile copyFileCompiler
        match "fonts/*"  $ route idRoute >> compile copyFileCompiler
        match "css/*"    $ route idRoute >> compile compressCssCompiler
        match "templates/*" $ compile templateBodyCompiler

        tags <- buildTags "posts/*" (fromCapture "tags/*.html")

        match (fromList ["about.rst", "research.md"]) $ do
            route $ setExtension "html"
            compile $ mdCompiler
                >>= loadAndApplyTemplate "templates/default.html" siteCtx
                >>= relativizeUrls

        match "posts/*" $ do
            let ctx = postCtx tags <> siteCtx
            route $ setExtension "html"
            compile $ pandocCompiler
                >>= loadAndApplyTemplate "templates/post.html"    ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

        tagsRules tags $ \tag pat -> do
        let ctx = constField "title" tag
                <> listField "posts" (postCtx tags) (recentFirst =<< loadAll pat)
                <> siteCtx
        route idRoute
        compile $ makeItem ""
            >>= loadAndApplyTemplate "templates/archive.html" ctx
            >>= loadAndApplyTemplate "templates/default.html" ctx
            >>= relativizeUrls

        create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let ctx = listField "posts" (postCtx tags) (return posts)
                <> constField "title" "Writing"
                <> siteCtx
            makeItem ""
            >>= loadAndApplyTemplate "templates/archive.html" ctx
            >>= loadAndApplyTemplate "templates/default.html" ctx
            >>= relativizeUrls


        match "index.html" $ do
        route idRoute
        compile $ do
            posts <- fmap (take 5) . recentFirst =<< loadAll "posts/*"
            let ctx = listField "posts" (postCtx tags) (return posts) <> siteCtx
            getResourceBody
            >>= applyAsTemplate ctx
            >>= loadAndApplyTemplate "templates/default.html" ctx
            >>= relativizeUrls


--------------------------------------------------------------------------------


