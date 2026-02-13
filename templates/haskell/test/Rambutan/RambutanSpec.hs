{-# LANGUAGE OverloadedStrings #-}

module Rambutan.RambutanSpec (spec) where

import Rambutan (greeting)
import Test.Hspec

spec :: Spec
spec = do
    describe "greeting" $ do
        it "returns a greeting" $ do
            greeting `shouldBe` "Hello from rambutan!"
