{-# LANGUAGE OverloadedStrings #-}

import qualified Eztv
import qualified Youtube
import System.Directory(getHomeDirectory)
import Control.Applicative((<$>))
import Control.Monad(join)
import Data.Maybe(fromMaybe)
import Control.Concurrent.Async(async, wait)
import Control.Concurrent.MVar(newEmptyMVar, MVar, putMVar, takeMVar)
import Control.Monad(forever)
import Control.Concurrent.Thread.Delay(delay)

import Web.Scotty
import Data.Monoid(mconcat)
import Control.Monad.IO.Class(liftIO)
import Control.Concurrent.MVar(swapMVar)
import Control.Concurrent.MVar(readMVar)
import Control.Concurrent.MVar(newMVar)
import Data.List(find)
import Control.Lens


data Crawlable = Channels [Youtube.Channel]
               | Series [Eztv.Serie]

                deriving (Show, Read)


loadConfigFile :: IO [(String, [String])]
loadConfigFile = do
    configFile <- join $ readFile <$> (++ "/.config/crawler.rc") <$> getHomeDirectory
    return $ read configFile


spawnFetcher :: IO (MVar [Crawlable])
spawnFetcher = do
        fetchRes <- newMVar []
        _ <- async $ fetcher fetchRes
        return fetchRes

        where
            getFromConfig key cfg = fromMaybe [] $ lookup key cfg
            fetcher queue = forever $ do
                    config <- loadConfigFile
                    let actions = [ Series   <$> Eztv.fetchSeries (getFromConfig "eztv" config)
                                  , Channels <$> Youtube.fetchChannels (getFromConfig "youtube" config)
                                  ] :: [IO Crawlable]

                    putStrLn "Start fetching !"
                    jobs <- sequence $ async <$> actions
                    res <- mapM wait jobs
                    putStrLn "Done fetching !"
                    _ <- swapMVar queue res
                    putStrLn "Going to sleep !"
                    delay (10^6 * 60 * 60 * 2)


runRestServer queue = scotty 8080 $ do
    get "/:word/:teo" $ do
        word <- param "word" :: ActionM String
        -- te <- param "teo"
        dest <- liftIO $ readMVar queue
        json $ show "" 
                -- case word of
                --         "serie" -> show $ case (fromMaybe (Series []) $ find (\a -> case a of
                --                                                                Series _ -> True
                --                                                                _ -> False) dest) of 
                --                             Series a -> a ^.. Eztv.serieName
                --                             _ -> []
                --         _ -> ""

main :: IO ()
main = do
    queue <- spawnFetcher
    runRestServer queue
    -- forever $ do
    --     dest <- takeMVar queue
    --     print dest

