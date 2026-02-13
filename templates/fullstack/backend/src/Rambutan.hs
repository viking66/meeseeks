{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE OverloadedStrings #-}

module Rambutan (
    -- * API
    Api (..),
    runServer,

    -- * Types
    HelloResponse (..),

    -- * Pure functions (exported for testing)
    greeting,
) where

import Data.Aeson (ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)
import Network.Wai.Handler.Warp qualified as Warp
import Servant
import Servant.Server.Generic (AsServer)

data Api mode = Api
    { hello :: mode :- "api" :> "hello" :> Get '[JSON] HelloResponse
    , static :: mode :- Raw
    }
    deriving stock (Generic)

data HelloResponse = HelloResponse
    { message :: Text
    }
    deriving stock (Show, Eq, Generic)
    deriving anyclass (ToJSON)

greeting :: Text
greeting = "Hello from rambutan!"

server :: FilePath -> Api AsServer
server staticDir =
    Api
        { hello = helloHandler
        , static = serveDirectoryWebApp staticDir
        }

helloHandler :: Handler HelloResponse
helloHandler = pure HelloResponse{message = greeting}

runServer :: Int -> IO ()
runServer port = do
    putStrLn $ "Starting server on port " ++ show port
    Warp.run port $ serve (Proxy @(NamedRoutes Api)) (server "frontend/dist")
