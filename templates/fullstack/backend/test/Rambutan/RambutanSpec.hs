module Rambutan.RambutanSpec (spec) where

import Data.Text qualified as T
import Test.Hspec
import Rambutan (HelloResponse (..), greeting)

spec :: Spec
spec = do
    describe "greeting" $ do
        it "is not empty" $ do
            greeting `shouldNotBe` T.empty

    describe "HelloResponse" $ do
        it "wraps greeting" $ do
            let resp = HelloResponse{message = greeting}
            resp.message `shouldBe` greeting
