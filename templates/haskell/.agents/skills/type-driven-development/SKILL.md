---
name: type-driven-development
description: Design types before writing functions in Haskell or PureScript. Use when starting a new feature, modeling a domain, designing data structures, adding a new API endpoint, creating a new component, or when unsure how to structure code. Focuses on getting types right first — the functions follow naturally. Applies to both backend (Haskell) and frontend (PureScript) development.
---

# Type-Driven Development

## Core Principle

**Get the types right. The functions follow.**

In Haskell and PureScript, the quality of your software is largely determined by the quality of your types. Types are not annotations you add after writing code — they are the design tool you use *before* writing code.

**Types are the plan. The compiler is the assistant. Functions are the last step.**

## The Workflow

### 1. Model the Domain with Types

Before writing any function, ask: *What data does this feature work with?*

Define the types that represent your domain. Use sum types for variants, product types for combinations, newtypes for distinct concepts.

```haskell
-- Haskell: Story node domain
data Node = Node
    { nodeId :: NodeId
    , parentId :: Maybe NodeId
    , content :: Text
    , authorId :: UserId
    , score :: Int
    }

data PathNode = PathNode
    { nodeId :: Int64
    , content :: Text
    , totalScore :: Int
    }

data RootInfo = RootInfo
    { rootNodeId :: NodeId
    , storyTitle :: Text
    }
```

```purescript
-- PureScript: Frontend state
type PathNode = { nodeId :: Int, content :: String, totalScore :: Int }
type RootInfo = { rootNodeId :: Int, storyTitle :: String }

data StoryStatus
    = Loading
    | Failed String
    | Loaded { root :: RootInfo, path :: Array PathNode }
```

**At this stage, you're not writing logic.** You're deciding what the data looks like.

### 2. Write Function Signatures

With types defined, write the type signatures of the functions you need. Don't implement them yet.

```haskell
-- Haskell: What operations do we need?
computePath :: NodeId -> [Entity Node] -> [PathNode]

buildNodeDetail :: Entity Node -> Maybe Text -> [Entity Node] -> [Text] -> NodeDetail

validateContent :: Text -> Either Text Text

greeting :: Text
```

```purescript
-- PureScript: What does the component need?
formatScore :: Int -> String

buildNodeView :: PathNode -> NodeState -> HH.HTML w Action

selectBestChild :: Array ChildNode -> Maybe ChildNode
```

**Type signatures are design documents.** If the signature looks wrong — wrong inputs, wrong output, too many arguments, too few — the design is wrong. Fix it now, before writing any logic.

### 3. Verify the Skeleton Compiles

Stub implementations with `undefined` (Haskell) or `unsafeCrashWith` (PureScript) and compile.

```haskell
-- Haskell: stub with undefined
computePath :: NodeId -> [Entity Node] -> [PathNode]
computePath = undefined

buildNodeDetail :: Entity Node -> Maybe Text -> [Entity Node] -> [Text] -> NodeDetail
buildNodeDetail = undefined
```

```purescript
-- PureScript: stub with unsafeCrashWith
formatScore :: Int -> String
formatScore = unsafeCrashWith "TODO"

selectBestChild :: Array ChildNode -> Maybe ChildNode
selectBestChild = unsafeCrashWith "TODO"
```

```bash
just fix-build       # Haskell: does the type skeleton compile?
just build-frontend  # PureScript: does the type skeleton compile?
```

**If it doesn't compile, your types don't fit together.** Fix the types now — this is much cheaper than discovering a mismatch after you've written all the logic.

### 4. Use Typed Holes to Explore

When you're unsure what goes in a spot, use a typed hole (`_`) and let the compiler tell you.

```haskell
-- Haskell: "What type goes here?"
computePath nodeId nodes =
    let nodeMap = buildNodeMap nodes
        startNode = Map.lookup nodeId nodeMap
    in case startNode of
        Nothing -> []
        Just node -> _  -- GHC tells you: _ :: [PathNode]
                        -- and shows available bindings
```

The compiler responds with the expected type and all bindings in scope. The types fit together like a jigsaw — the hole tells you which piece is missing.

PureScript's compiler provides similar feedback for typed holes using `?holeName` syntax:

```purescript
selectBestChild children =
    let sorted = sortBy (comparing _.totalScore) children
    in ?result  -- Compiler tells you: ?result :: Maybe ChildNode
```

### 5. Implement

Now write the functions. With types already verified, implementation is often mechanical — you're just connecting the types.

## Type Design Checklist

Before moving to implementation, verify your types against these questions:

```
Can this type represent an invalid state?
  → Tighten it (sum type, newtype, smart constructor)

Are two fields the same primitive type but semantically different?
  → Newtype them (UserId vs NodeId, not both Int64)

Does a Maybe/Either represent a state that should be its own constructor?
  → Use a sum type instead

Is there a Boolean that really means "one of two kinds"?
  → Replace with a sum type

Does the type carry data that's only valid in certain states?
  → Split into separate constructors that carry only their relevant data

Can the type represent duplicates where uniqueness is required?
  → Use Set, NonEmpty, or a smart constructor

Is there a Text/String that has structure (email, URL, ID)?
  → Newtype with smart constructor
```

## Modeling State with Types

Use sum types to represent states explicitly. Each constructor carries only the data valid for that state.

<Bad>
```haskell
-- All fields always present, some meaningless in certain states
data Order = Order
    { status :: String        -- "pending", "paid", "shipped"
    , items :: [Item]
    , paymentId :: Maybe Text -- only valid when paid
    , trackingNo :: Maybe Text -- only valid when shipped
    }
```
</Bad>

<Good>
```haskell
-- Each state carries exactly its own data
data Order
    = Pending (NonEmpty Item)
    | Paid (NonEmpty Item) PaymentId
    | Shipped (NonEmpty Item) PaymentId TrackingNumber
```
</Good>

```purescript
-- PureScript: same pattern
data RemoteData a
    = NotAsked
    | Loading
    | Failure String
    | Success a
```

A `Pending` order can never have a tracking number. A `Shipped` order always has one. The compiler enforces this — no runtime checks needed.

## Types as API Contracts

When designing an API endpoint or component interface, start with the request and response types.

```haskell
-- Haskell: design the API types first
data NodeDetail = NodeDetail
    { nodeId :: Int64
    , content :: Text
    , totalScore :: Int
    , authorEmail :: Maybe Text
    , children :: [ChildNode]
    }

data ChildNode = ChildNode
    { childId :: Int64
    , content :: Text
    , totalScore :: Int
    , authorEmail :: Text
    }

-- Then the endpoint type follows naturally
type Api = "nodes" :> Capture "nodeId" NodeId :> "detail" :> Get '[JSON] NodeDetail
```

```purescript
-- PureScript: design component types first
type State =
    { status :: StoryStatus
    , expandedNodeId :: Maybe Int
    , nodeDetail :: RemoteData NodeDetail
    }

data Action
    = Initialize
    | ClickNode Int
    | CloseDetail
    | FollowBranch Int

-- Then the component follows naturally
component :: H.Component Query Input Output Aff
```

The types tell you what the code needs to do. The implementation connects the dots.

## Relationship to Other Skills

- **Parse, Don't Validate**: When your type design reveals a boundary between raw input and domain types, that boundary is a parser.
- **Total Depravity**: The type checklist above is Total Depravity applied — encode invariants in types, don't trust memory.
- **Three Layer Cake**: Types designed here live in Layer 3 (pure data) or Layer 2 (capability interfaces). Layer 1 just wires them together.
