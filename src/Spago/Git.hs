module Spago.Git
  ( requireCleanWorkingTree
  , hasCleanWorkingTree
  , getAllTags
  , commitAndTag
  , isIgnored
  , unsafeIsIgnored
  ) where

import Spago.Prelude
import Spago.Env

import qualified Data.Text     as Text
import qualified Turtle


requireCleanWorkingTree :: HasLogFunc env => RIO env ()
requireCleanWorkingTree = do
  clean <- hasCleanWorkingTree
  unless clean $ do
    die [ "Your git working tree is dirty. Please commit or stash your changes first." ]


hasCleanWorkingTree :: HasLogFunc env => RIO env Bool
hasCleanWorkingTree = do
  (code, out, err) <- Turtle.procStrictWithErr "git" ["status", "--porcelain"] empty

  when (code /= ExitSuccess) $ do
    logDebug $ "git status stderr: " <> display err
    die [ "Unable to check git status. Perhaps git is not installed or this is not a git repository?" ]

  pure $ out == ""


getAllTags :: HasGit env => RIO env [Text]
getAllTags = do
  git <- view gitL
  fmap Text.lines $ Turtle.strict $ Turtle.inproc git ["tag", "--list"] empty


commitAndTag :: HasGit env => Text -> Text -> RIO env ()
commitAndTag tag message = do
  git <- view gitL
  Turtle.procs git ["commit", "--quiet", "--allow-empty", "--message=" <> message] empty
  Turtle.procs git ["tag", "--annotate", "--message=" <> message, tag] empty


-- | Check if the path is ignored by git
--
-- `git check-ignore` exits with 1 when path is not ignored, and 128 when
-- a fatal error occurs (i.e. when not in a git repository).
isIgnored :: HasGit env => Text -> RIO env Bool
isIgnored = unsafeIsIgnored


-- FIXME: Remove the unsafe variant
--
-- With the current constraint system, this was the easiest method
-- to make .gitignore checking configurable via a CLI flag.
unsafeIsIgnored :: MonadIO m => Text -> m Bool
unsafeIsIgnored path = do
  (exitCode, _, _) <- Turtle.procStrictWithErr "git" ["check-ignore", "--quiet", path] empty
  pure $ exitCode == ExitSuccess
