module App.Root where

import Prelude

import App.Capability.Api (ApiCapability)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect.Aff (Aff)
import Effect.Aff.Class (class MonadAff, liftAff)
import Halogen as H
import Halogen.HTML as HH

type Input = { api :: ApiCapability Aff }

type State =
  { api :: ApiCapability Aff
  , status :: Status
  }

data Status
  = Loading
  | Error String
  | Loaded String

data Action = Initialize

component :: forall query output m. MonadAff m => H.Component query Input output m
component =
  H.mkComponent
    { initialState
    , render
    , eval: H.mkEval $ H.defaultEval
        { handleAction = handleAction
        , initialize = Just Initialize
        }
    }

initialState :: Input -> State
initialState { api } = { api, status: Loading }

handleAction :: forall output m. MonadAff m => Action -> H.HalogenM State Action () output m Unit
handleAction Initialize = do
  { api } <- H.get
  result <- liftAff api.fetchHello
  case result of
    Left err -> H.modify_ _ { status = Error err }
    Right msg -> H.modify_ _ { status = Loaded msg }

render :: forall slots m. State -> H.ComponentHTML Action slots m
render { status } =
  HH.div_
    [ HH.h1_ [ HH.text "rambutan" ]
    , renderStatus status
    ]

renderStatus :: forall slots m. Status -> H.ComponentHTML Action slots m
renderStatus Loading =
  HH.p_ [ HH.text "Loading..." ]

renderStatus (Error msg) =
  HH.p_ [ HH.text $ "Error: " <> msg ]

renderStatus (Loaded msg) =
  HH.p_ [ HH.text msg ]
