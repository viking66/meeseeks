---
name: three-layer-cake
description: Architecture pattern for structuring Haskell and PureScript applications into three layers — orchestration, capabilities, and pure logic. Use when designing module structure, deciding where to put business logic, choosing how to handle effects, structuring components, or when effectful code is getting hard to test. Applies to both backend (Haskell) and frontend (PureScript/Halogen). Based on Matt Parsons' "Three Layer Haskell Cake."
---

# Three Layer Cake

## The Pattern

Separate code into three layers. Effects at the edges, pure logic in the center.

```
┌─────────────────────────────────────────┐
│  Layer 1: Orchestration                 │
│  Wire things together, run effects      │
│  (Hard to test — keep thin)             │
├─────────────────────────────────────────┤
│  Layer 2: Capabilities                  │
│  Abstract effect interfaces             │
│  (Testable via swapped implementations) │
├─────────────────────────────────────────┤
│  Layer 3: Pure Logic                    │
│  Business rules, data transformation    │
│  (Trivially testable — no effects)      │
└─────────────────────────────────────────┘
```

**Push as much code as possible into Layer 3.**

## Layer 3: Pure Logic (Write Most Code Here)

Pure functions that take data in and return data out. No effects, no `IO`, no `Effect`, no `Aff`.

```haskell
-- Haskell
computePath :: NodeId -> [Entity Node] -> [PathNode]
computePath targetId nodes = ...

validateContent :: Text -> Either Text Text
validateContent t
    | T.null (T.strip t) = Left "Content required"
    | otherwise = Right t

buildTree :: [Entity Node] -> Map NodeId [Entity Node]
buildTree = ...
```

```purescript
-- PureScript
formatScore :: Int -> String
formatScore n
    | n > 0     = "+" <> show n
    | otherwise = show n

buildNodeView :: PathNode -> NodeState -> HH.HTML w Action
buildNodeView node state = ...

selectBestChild :: Array ChildNode -> Maybe ChildNode
selectBestChild = maximumBy (comparing _.totalScore)
```

**Why this is the biggest layer:**
- Trivially testable — no setup, no teardown, deterministic
- Easy to understand — input determines output
- Easy to refactor — change freely, tests catch breaks
- Reusable — no dependency on specific effects

**What goes here:**
- Business rules and validation
- Data transformation and formatting
- Tree/graph algorithms
- View rendering logic (Halogen HTML builders)
- Anything that doesn't need the outside world

## Layer 2: Capabilities (Abstract Effect Interfaces)

Records or typeclasses that describe *what* effects you need, not *how* they're performed.

```haskell
-- Haskell: typeclass style
class Monad m => AcquireStory m where
    getActiveRoot :: m (Maybe RootInfo)
    getPath :: NodeId -> m [PathNode]

class Monad m => ModifyStory m where
    addNode :: NodeId -> Text -> m (Either Text NodeId)
```

```purescript
-- PureScript: capability record style (idiomatic for Halogen)
type ApiCapability m =
    { fetchActiveRoot :: m (Either String RootInfo)
    , fetchPath :: Int -> m (Either String (Array PathNode))
    , fetchNodeDetail :: Int -> m (Either String NodeDetail)
    }

-- Production: real API calls
mkApiCapability :: ApiCapability Aff
mkApiCapability =
    { fetchActiveRoot: fetchJson "/api/active-root"
    , fetchPath: \nodeId -> fetchJson ("/api/path/" <> show nodeId)
    , fetchNodeDetail: \nodeId -> fetchJson ("/api/nodes/" <> show nodeId <> "/detail")
    }

-- Test: pure doubles
mkTestCapability :: ApiCapability Aff
mkTestCapability =
    { fetchActiveRoot: pure (Right testRoot)
    , fetchPath: \_ -> pure (Right testPath)
    , fetchNodeDetail: \_ -> pure (Right testDetail)
    }
```

**Critical rule: Capture domain operations, not infrastructure.**

<Good>
```haskell
-- Domain-specific: describes what you need
class AcquireUser m where
    getUserBy :: UserQuery -> m [User]
    getUser :: UserId -> m (Maybe User)
```
</Good>

<Bad>
```haskell
-- Infrastructure: leaks implementation details
class MonadDatabase m where
    runQuery :: Query -> m [Row]

class MonadHTTP m where
    httpGet :: URL -> m Response
```
</Bad>

If you capture `MonadDatabase`, you can't swap from database to API without changing consumers. If you capture `AcquireUser`, the implementation can be a database, an API, or a test double — consumers don't care.

## Layer 1: Orchestration (Keep This Thin)

Wires capabilities to implementations and sequences effects. This is the "main" layer.

```haskell
-- Haskell: handler that orchestrates
getPathHandler :: Pool SqlBackend -> NodeId -> Handler [PathNode]
getPathHandler pool nodeId = do
    nodes <- liftIO $ runDb pool $ selectList [] []
    pure $ computePath nodeId nodes  -- calls into Layer 3
```

```purescript
-- PureScript: Halogen handleAction
handleAction :: Action -> H.HalogenM State Action () o Aff Unit
handleAction = case _ of
    Initialize -> do
        result <- H.liftAff $ caps.fetchActiveRoot
        case result of
            Left err -> H.modify_ _ { status = Failed err }
            Right root -> do
                pathResult <- H.liftAff $ caps.fetchPath root.rootNodeId
                case pathResult of
                    Left err -> H.modify_ _ { status = Failed err }
                    Right path -> H.modify_ _ { status = Loaded { root, path } }
```

**What goes here:**
- Servant handlers (Haskell)
- Halogen `handleAction` / `handleQuery` (PureScript)
- Database calls, HTTP requests, DOM effects
- Wiring capabilities to real implementations

**What does NOT go here:**
- Business logic (move to Layer 3)
- Deciding *which* data to fetch based on complex rules (Layer 3)
- Data transformation after fetching (Layer 3)

## The Test Payoff

| Layer | How to Test | Effort |
|-------|------------|--------|
| Layer 3 (Pure) | Direct assertions, `shouldBe`/`shouldEqual` | Trivial |
| Layer 2 (Capabilities) | Swap implementation with test doubles | Easy |
| Layer 1 (Orchestration) | Integration tests or don't test | Hard (keep thin) |

The more code in Layer 3, the easier your test suite. If testing is hard, you have too much logic in Layer 1.

## Decision Gate

```
Writing a new function:
  Does it need effects (IO, Effect, Aff, database, HTTP, DOM)?
    NO  → Layer 3 (pure function)
    YES → Can the effect be abstracted behind a capability?
      YES → Layer 2 (capability interface) + Layer 3 (pure logic)
      NO  → Layer 1 (orchestration, keep minimal)

Existing function is hard to test:
  Does it mix effects with logic?
    → Extract the logic into a pure function (Layer 3)
    → The effectful part becomes thin orchestration (Layer 1)

Adding a new external dependency (API, database, service):
  → Define a capability interface (Layer 2)
  → Implement it in orchestration (Layer 1)
  → Consume it via the interface, never directly
```

## Anti-Pattern: The Fat Handler

When orchestration contains business logic, testing requires the full effect stack.

<Bad>
```haskell
-- Everything in one handler — untestable without database
getPathHandler pool nodeId = do
    nodes <- runDb pool $ selectList [] []
    let nodeMap = Map.fromList [(entityKey e, entityVal e) | e <- nodes]
    let go nid = case Map.lookup nid nodeMap of
            Nothing -> []
            Just node -> node : go (selectBestChild nodeMap nid)
    pure $ map toPathNode (go nodeId)
```
</Bad>

<Good>
```haskell
-- Orchestration: thin, just wires IO to pure logic
getPathHandler pool nodeId = do
    nodes <- runDb pool $ selectList [] []
    pure $ computePath nodeId nodes  -- Layer 3

-- Pure logic: easy to test
computePath :: NodeId -> [Entity Node] -> [PathNode]
computePath nodeId nodes = ...
```
</Good>

The same applies in PureScript — extract logic from `handleAction` into pure functions.
