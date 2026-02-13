module Main where

import Prelude

import App.Capability.Api (mkApiCapability)
import App.Root as Root
import Effect (Effect)
import Halogen.Aff as HA
import Halogen.VDom.Driver (runUI)

main :: Effect Unit
main = HA.runHalogenAff do
  body <- HA.awaitBody
  let input = { api: mkApiCapability }
  runUI Root.component input body
