module App.Capability.Api where

import Prelude

import Affjax.Web as AX
import Affjax.ResponseFormat as RF
import Data.Argonaut (class DecodeJson, decodeJson, printJsonDecodeError)
import Data.Either (Either(..))
import Effect.Aff (Aff)

type ApiCapability m =
  { fetchHello :: m (Either String String)
  }

mkApiCapability :: ApiCapability Aff
mkApiCapability =
  { fetchHello: fetchHello
  }

fetchHello :: Aff (Either String String)
fetchHello = do
  (result :: Either String HelloResponse) <- fetchJson "/api/hello"
  pure $ map _.message result

type HelloResponse = { message :: String }

fetchJson :: forall a. DecodeJson a => String -> Aff (Either String a)
fetchJson url = do
  result <- AX.get RF.json url
  pure $ case result of
    Left err -> Left $ AX.printError err
    Right response -> case decodeJson response.body of
      Left decodeErr -> Left $ printJsonDecodeError decodeErr
      Right value -> Right value
