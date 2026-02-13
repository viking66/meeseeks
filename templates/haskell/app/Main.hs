module Main (main) where

import Rambutan (greeting)

import Data.Text.IO qualified as T

main :: IO ()
main = T.putStrLn greeting
