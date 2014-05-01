{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE FlexibleContexts #-}

module Http where


import           Data.Maybe
import           Network.HTTP.Conduit
import           Network.HTTP.Types.Status

import           Control.Monad.IO.Class(MonadIO, liftIO)
import           Control.Monad.Trans.Maybe(MaybeT, runMaybeT)
import           Control.Monad.Trans.Control(MonadBaseControl)

import           Control.Applicative
import           Control.Monad

import qualified Data.ByteString.Lazy as BL


getPages :: (MonadBaseControl IO m, MonadIO m) => (BL.ByteString -> IO b) -> [String] -> m [Maybe b]
getPages func urls = withManager $ \m -> mapM (runWorker m) urls
    where
        runWorker m url = do pageBody <- runMaybeT $ worker m url
                             case func <$> pageBody of
                                  Just !z -> return <$> liftIO z
                                  Nothing -> return Nothing



worker :: MonadIO m => Manager -> String -> MaybeT m BL.ByteString
worker manager url = msum $ replicate 3 fetchPage
    where
        fetchPage = do
            let request = parseUrl url
            guard(isJust request)
            let request' = (fromJust request) { responseTimeout = Nothing -- Hang until the server reply
                                               ,checkStatus = \_ _ _ -> Nothing -- Do not throw exception on exception other than 2xx
                                              }

            response <- liftIO $ httpLbs request' manager
            -- _ <- liftIO . print $ responseStatus response
            guard(statusIsSuccessful $ responseStatus response)
            return $ responseBody response