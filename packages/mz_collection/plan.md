# MZ Collection - Architecture & Implementation Plan

## Overview

Extracting `collection_state` from `collection_view` package into a new standalone package `mz_collection`. The goal is to create a **blazingly fast**, **pure Dart**, **framework-agnostic** collection state management system.

## Design Philosophy

### Core Principles

1. **Zero Configuration Burden** - Managers should work out of the box with no required setup
2. **Call-Site Callbacks** - Tree/hierarchy knowledge passed at method level, not construction
3. **Injectable & Composable** - Managers can be created, cached, shared, and injected
4. **Pure Dart** - No Flutter dependency; uses custom `Listenable` mixin
5. **O(1) Operations** - Set/Map-based storage for fast lookups
6. **100% Test Coverage** - Every line tested; untestable code is code smell

### Key Insight: Callbacks at Call Site

Instead of configuring managers with tree structure at construction:

```dart
// ❌ Old approach - configuration burden on consumer
final selection = SelectionManager<String>(
  parentOf: (key) => parents[key],
  childrenOf: (key) => tree[key] ?? [],
);
```

We pass callbacks when needed:

```dart
// ✅ New approach - zero config, tree knowledge at call site
final selection = SelectionManager<String>();

// Controller (who knows the tree) provides callback when querying
final state = selection.stateOfTree(
  'folder1',
  total: 10,
  childrenOf: (key) => tree[key] ?? [],
);
```

**Benefits:**
- SelectionManager stays simple - just stores selections
- Tree knowledge stays with whoever owns the tree (e.g., CollectionController)
- Can inject SelectionManager without knowing tree structure
- Different callers can use different tree views

---

## Architecture

### Layered Design

```
┌─────────────────────────────────────────────────────────────────┐
│                    CollectionController                          │
│                   (Orchestrates everything)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │  Selection   │  │   Collapse   │  │   Reorder    │           │
│  │   Manager    │  │   Manager    │  │   Manager    │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │    Filter    │  │     Sort     │  │    Group     │           │
│  │   Manager    │  │   Manager    │  │   Manager    │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│                      Data Layer / Node                           │
│              (Tree structure, pagination, etc.)                  │
└─────────────────────────────────────────────────────────────────┘
```

### Manager Pattern

All managers follow consistent patterns:

1. **Pure Dart Listenable** - Custom mixin, no Flutter dependency
2. **Group-Based Storage** - `Map<K?, Set<K>>` for organizing by group
3. **Tristate Operations** - `yes`/`no`/`toggle` for state changes
4. **Call-Site Callbacks** - Tree traversal callbacks passed to methods

---

## Completed Work

### 1. FilterManager ✅

**File:** `lib/src/filter_manager.dart`

Multi-value filtering system with boolean composition.

**Features:**
- `Filter<T, V>` - Individual filter with multi-value support
- `FilterManager<T>` - Coordinates multiple filters
- `FilterExpression` - Boolean composition (AND/OR/NOT)
- `FilterMode` - any/all within single filter
- `CompositionMode` - and/or between filters
- Pure Dart `Listenable` mixin

**Test Coverage:** 100%

### 2. SortManager ✅

**File:** `lib/src/sort_manager.dart`

Multi-level sorting with configurable options.

**Features:**
- `SortOption<T, V>` - Individual sort criterion
- `SortManager<T>` - Manages multiple sort options
- `SortOrder` - ascending/descending
- Support for multi-level sorting
- Pure Dart `Listenable` (re-exported from filter_manager)

**Test Coverage:** 100%

### 3. GroupManager ✅

**File:** `lib/src/group_manager.dart`

Multi-level grouping with configurable options.

**Features:**
- `GroupOption<T, GroupBy>` - Individual grouping criterion
- `GroupManager<T>` - Manages multiple group options
- Type aliases: `GroupByString`, `GroupByInt`, etc.
- Key builders for custom group keys
- Pure Dart `Listenable`

**Test Coverage:** 100% (61 tests)

### 4. SelectionManager ✅

**File:** `lib/src/selection_manager.dart`

Selection state management with **flat storage** and **optional scopes**.

**Key Design: Flat Storage + Query-Time Grouping**

Traditional selection managers store selections by group key. This breaks when UI
grouping changes dynamically (e.g., user switches from grouping by "Status" to
"Priority"). Our manager uses **flat storage** as the source of truth:

- Selections persist across regrouping
- Consumer provides current group membership at query time
- Optional scopes for truly independent selection sets (tabs, sections)

**Features:**
- Flat storage: `Map<Object?, Set<K>>` (scope → selected keys)
- `select()` / `selectAll()` with `Tristate` (yes/no/toggle)
- `isSelected()` - check if key is selected
- Query-time grouping: `countIn(keys)`, `selectedIn(keys)`, `stateOf(keys)`
- Scope-wide queries: `allSelectedIn(scope:)`, `countAllIn(scope:)`
- `stateOf()` → `SelectionState` (none/partial/all)
- Tree operations with `keysIn` and `childrenOf` callbacks
- Pure Dart `Listenable`

**Test Coverage:** 100% (83 tests)

**API:**
```dart
// Zero config - just create it
final selection = SelectionManager<String>();

// Core operations
selection.select('key', state: Tristate.toggle);
selection.select('key', scope: 'tabA', state: Tristate.yes);
selection.selectAll(['a', 'b'], state: Tristate.yes);
selection.isSelected('key', scope: 'tabA');
selection.clear(scope: 'tabA');
selection.clearAll();

// Query-time grouping (consumer provides current group membership)
final activeItems = ['task1', 'task2', 'task3'];
selection.countIn(activeItems);     // How many of these are selected?
selection.selectedIn(activeItems);  // Which of these are selected?
selection.stateOf(activeItems);     // none/partial/all

// Selections persist across regrouping!
final highPriority = ['task1', 'task3'];  // Different grouping
selection.stateOf(highPriority);          // Still works!

// Scope-wide queries
selection.allSelectedIn(scope: 'tabA');
selection.countAllIn(scope: 'tabA');

// Tree operations - callbacks at CALL SITE
selection.countInTree(
  'folder',
  keysIn: (node) => filesInFolder[node] ?? [],
  childrenOf: (node) => subfolders[node] ?? [],
);
selection.stateOfTree(
  'folder',
  totalKeys: 50,
  keysIn: (node) => filesInFolder[node] ?? [],
  childrenOf: (node) => subfolders[node] ?? [],
);
```

### 5. Entities ✅

**File:** `lib/src/entities.dart`

Shared types and mixins.

**Contains:**
- `Tristate` enum (yes/no/toggle)
- `TriStateX` extension (resolve method)
- `Selectable` mixin
- `Visible` mixin
- `Collapsible` mixin
- `OrderPreserver` mixin
- `Indexable` mixin
- Type aliases: `ItemPredicate`, `ItemFilter`, `EqualityChecker`

---

### 5. CollapseManager ✅

**File:** `lib/src/collapse_manager.dart`

Manages collapsed/expanded state with flat storage and optional scopes.

**Features:**
- Flat storage: `Map<Object?, Set<K>>` (scope → collapsed keys)
- Default expanded (nodes NOT in set are expanded)
- `toggle()`, `collapse()` with Tristate operations
- `isCollapsed()`, `isExpanded()`
- Bulk operations: `collapseAll()`, `expandAll()`, `expandEverything()`
- Tree operations:
  - `collapseToLevel(root, level, childrenOf:)` - Expand to N levels
  - `expandToNode(target, parentOf:)` - Reveal deeply nested node
  - `collapseSiblings(key, siblingsOf:)` - Accordion behavior
- Pure Dart `Listenable`

**Test Coverage:** 100% (68 tests)

**API:**
```dart
final collapse = CollapseManager<String>();

// Core operations
collapse.toggle('folder1');
collapse.collapse('folder1', state: Tristate.yes);  // force collapse
collapse.collapse('folder1', state: Tristate.no);   // force expand
collapse.isCollapsed('folder1', scope: 'tree1');

// Bulk operations
collapse.collapseAll(['a', 'b', 'c'], state: Tristate.yes);
collapse.expandAll(scope: 'tree1');
collapse.expandEverything();

// Tree operations
collapse.collapseToLevel('root', level: 2, childrenOf: (k) => tree[k] ?? []);
collapse.expandToNode('deep/file.dart', parentOf: (k) => parentMap[k]);
collapse.collapseSiblings('section2', siblingsOf: (k) => siblings[k] ?? []);
```

### 6. ReorderManager ✅

**File:** `lib/src/reorder_manager.dart`

Manages item reordering with fractional indexing for O(1) insertions.

**Features:**
- Fractional indexing: O(1) insertions without shifting
- Sparse storage: Only stores items with custom positions
- `moveBetween(key, after:, before:)` - Move between anchors
- `moveToIndex(key, index)` - Move to specific position
- `setOrder()`, `clearOrder()`, `reset()`, `resetAll()`
- `applyOrder(keys)` - Get sorted list with custom order
- `comparator()` - Get comparator for external sorting
- Optional scopes for independent orderings
- Pure Dart `Listenable`

**Test Coverage:** 100% (56 tests)

**API:**
```dart
final reorder = ReorderManager<String>();
final items = ['a', 'b', 'c', 'd', 'e'];
double naturalOrderOf(String k) => items.indexOf(k).toDouble();

// Move 'd' between 'a' and 'b'
reorder.moveBetween(
  'd',
  after: 'a',
  before: 'b',
  orderOf: (k) => reorder.orderOf(k) ?? naturalOrderOf(k),
);

// Move to specific index
reorder.moveToIndex('e', 1, orderedKeys: items, orderOf: orderOf);

// Apply custom order
final sorted = reorder.applyOrder(items, naturalOrderOf: naturalOrderOf);

// Get comparator for external use
final comparator = reorder.comparator(naturalOrderOf: naturalOrderOf);
items.sort(comparator);

// Reset to original order
reorder.reset();
```

### 7. Node ✅

**File:** `lib/src/node.dart`

A lightweight, generic tree node for item storage with O(1) lookups.

**Key Design: Separation of Concerns**

The old Node was a "God class" (3700+ lines) that handled everything: items, selection,
collapse, visibility, ordering, filtering, etc. The new Node follows separation of concerns:

- **Node** handles tree structure, item storage, and collapse state
- **SelectionManager** handles selection state
- **ReorderManager** handles custom ordering
- **FilterManager** handles filtering
- **SortManager** handles sorting

**Features:**
- Generic items with no interface requirements: `Node<K, T>`
- Implements `Iterable<T>` for ergonomic iteration
- Dual storage: `List<T>` for ordering + `Map<K, T>` for O(1) lookups
- `keyOf` callback extracts unique key from items
- Optional `equalityChecker` for custom comparison
- Optional `extra` field for metadata
- Tree navigation: `parent`, `children`, `depth`, `root`, `parents`
- Tree search: `findNode()`, `findNodeByKey()`, `findNodeByItem()`
- Tree iteration: `descendants`, `flattenedItems`, `flattenedKeys`, `leaves`, `nodesAtDepth()`, `visibleDescendants`
- **Collapse state**: `isCollapsed`, `toggle()`, `collapse()`, `collapseToLevel()`, `expandToThis()`, `expandAll()`, `collapseAll()`
- Version tracking for concurrent modification detection
- Pure Dart `Listenable`

**Test Coverage:** 100% (104 tests)

**API:**
```dart
// Generic Node<K, T> - K is key type, T is item type
final node = Node<String, User>(
  id: 'users',
  keyOf: (user) => user.id,  // Extract key from item
);

// Add items
node.add(User(id: '1', name: 'Alice'));
node.addAll([user2, user3]);

// O(1) lookup by key
final alice = node['1'];

// Iterable<T> - use all Iterable methods
for (final user in node) { print(user.name); }
final admins = node.where((u) => u.isAdmin);
final names = node.map((u) => u.name);

// Tree structure
final child = Node<String, User>(id: 'vip', keyOf: (u) => u.id);
node.addChild(child);
print(child.depth);    // 1
print(child.parent);   // node
print(child.root);     // node

// Tree search
final found = node.findNode('vip');
final userNode = node.findNodeByKey('1');

// Tree iteration
for (final n in node.descendants) { }  // BFS order
for (final u in node.flattenedItems) { }  // All items in tree
for (final leaf in node.leaves) { }  // Leaf nodes only

// Collapse state (lives in Node, not separate manager)
node.toggle();                    // Toggle collapse
node.collapse(state: Tristate.yes);  // Force collapse
node.collapseToLevel(2);          // Expand first 2 levels
child.expandToThis();             // Reveal deeply nested node
for (final n in node.visibleDescendants) { }  // Skip collapsed
```

### 8. CollectionController ✅

**File:** `lib/src/collection_controller.dart`

A lean composition container that orchestrates Node + managers.

**Key Design: Composition Over Orchestration**

CollectionController is intentionally minimal. It holds references to components,
aggregates notifications, and provides convenience methods. It does NOT impose
UI structure - consumers wire things based on their specific needs.

**Features:**
- Holds Node + managers (SelectionManager, ReorderManager, optional Filter/Sort/Group)
- Accepts injected managers or creates defaults
- Aggregates notifications from all components
- Convenience methods bridging Node + Selection
- Disposes owned managers, leaves injected ones alone

**Test Coverage:** 100% (37 tests)

**API:**
```dart
// Create with defaults
final controller = CollectionController<String, Task>(
  node: Node<String, Task>(id: 'root', keyOf: (t) => t.id),
);

// Access components directly
controller.node.add(Task(id: '1', title: 'Buy milk'));
controller.selection.select('1');

// Convenience: Selection + Node
controller.selectAllInNode('folder1');              // Select all items in node
controller.selectionStateOfNode('folder1');         // none/partial/all
controller.selectedCountInNode('folder1');          // Count

// Convenience: Expand to item
controller.expandToItem('task-123');                // Reveal deeply nested item

// Convenience: Processing pipeline
for (final item in controller.processedItems()) {  // Filter + sort applied
  print(item);
}

// Listen to any change
controller.addListener(() => setState(() {}));

// Share managers across controllers
final sharedSelection = SelectionManager<String>();
final c1 = CollectionController(node: node1, selection: sharedSelection);
final c2 = CollectionController(node: node2, selection: sharedSelection);
```

---

## File Structure

```
lib/
├── src/
│   ├── entities.dart              ✅ Shared types and mixins
│   ├── filter_manager.dart        ✅ Filtering system
│   ├── sort_manager.dart          ✅ Sorting system
│   ├── group_manager.dart         ✅ Grouping system
│   ├── selection_manager.dart     ✅ Selection state (83 tests)
│   ├── collapse_manager.dart      ✅ Collapse/expand state (68 tests) [legacy, collapse now in Node]
│   ├── reorder_manager.dart       ✅ Reorder state (56 tests)
│   ├── node.dart                  ✅ Tree node + collapse (104 tests)
│   └── collection_controller.dart ✅ Orchestration (37 tests)
│
test/
├── src/
│   ├── filter_manager_test.dart         ✅
│   ├── sort_manager_test.dart           ✅
│   ├── group_manager_test.dart          ✅ (61 tests)
│   ├── selection_manager_test.dart      ✅ (83 tests)
│   ├── collapse_manager_test.dart       ✅ (68 tests) [legacy]
│   ├── reorder_manager_test.dart        ✅ (56 tests)
│   ├── node_test.dart                   ✅ (104 tests)
│   └── collection_controller_test.dart  ✅ (37 tests)
```

---

## Key Design Decisions

### 1. Single Type Parameter for Keys and Groups

Currently `SelectionManager<K>` uses K for both item keys and group keys.

**Trade-off:**
- Simpler API with one type parameter
- Items and groups must be same type
- Future: Could add `SelectionManager<K, G>` if needed

### 2. Tristate for All State Operations

Using `Tristate.yes`, `Tristate.no`, `Tristate.toggle` instead of separate methods.

**Benefits:**
- Consistent API across all managers
- Single method handles select/deselect/toggle
- Cleaner than `select()`, `deselect()`, `toggleSelect()`

### 3. Flat Storage with Query-Time Grouping

`Map<Object?, Set<K>>` where key is the scope (null = default scope).

**Why not group-based storage?**
Storing by group key breaks when UI grouping changes (user switches from
"Status" to "Priority" grouping). Selections tied to old group keys become stale.

**Benefits:**
- Selections persist across dynamic regrouping
- O(1) lookups within scope
- Consumer provides current group membership at query time
- Optional scopes for truly independent selection sets (tabs, sections)

### 4. SelectionState Enum

`none`, `partial`, `all` for checkbox tri-state UI.

**Use Cases:**
- Checkbox rendering (empty, dash, check)
- "Select All" toggle behavior
- Tree node indicators

---

## Testing Strategy

1. **100% Coverage Required** - Every line must be tested
2. **Manual Mocks/Fakes** - No external mocking packages
3. **Integration Tests** - Real-world scenario tests
4. **Edge Cases** - Empty states, boundaries, error conditions

---

## Next Steps

1. ~~Create SelectionManager~~ ✅
2. ~~Create CollapseManager~~ ✅ (later moved collapse into Node)
3. ~~Create ReorderManager~~ ✅
4. ~~Refactor Node~~ ✅
5. ~~Create CollectionController~~ ✅
6. Add barrel file exports
7. Create PaginationManager (for lazy loading support)
8. Integration testing with real-world scenarios

---

## Session Notes

### Session 1 (Completed)
- Discussed architecture and design philosophy
- Completed FilterManager, SortManager, GroupManager
- All with 100% test coverage

### Session 2
- Designed SelectionManager with callback-at-call-site pattern
- Initial implementation with group-based storage
- Fixed entities.dart (removed invalid imports)
- Created comprehensive tests
- Created this plan document

### Session 3
- **Major Refactoring**: Changed from group-based storage to flat storage
- User identified regrouping problem: "what if regrouping in listview change the items original places?"
- Redesigned SelectionManager with:
  - **Flat storage** - selections stored by key, not group
  - **Query-time grouping** - consumer provides `keys[]` at query time
  - **Optional scopes** - independent selection sets for tabs/sections
  - **Tree operations** with `keysIn` and `childrenOf` callbacks
- Updated all tests to match new API (83 tests, 100% pass)
- Code passes analyzer with zero warnings

### Session 4 (Current)
- Created **CollapseManager** with:
  - Flat storage with optional scopes (same pattern as SelectionManager)
  - Default expanded (nodes NOT in collapsed set are expanded)
  - Tree operations: `collapseToLevel()`, `expandToNode()`, `collapseSiblings()`
  - 68 tests, 100% pass
- Created **ReorderManager** with:
  - Fractional indexing for O(1) insertions
  - Sparse storage (only stores custom positions)
  - `moveBetween()`, `moveToIndex()`, `applyOrder()`, `comparator()`
  - 56 tests, 100% pass
- All managers now complete with consistent patterns

### Key Insight from Discussion
User's insight about dynamic regrouping led to a fundamental design change:

**Problem**: Storing selections by group key breaks when UI grouping changes.
When user switches from "Status" grouping to "Priority" grouping, selections
tied to old group keys become stale.

**Solution**: Flat storage with query-time grouping.
- Selections stored flat (by scope, not group)
- Consumer provides current group membership at query time: `stateOf(currentGroupKeys)`
- Same selections work regardless of how UI is grouped

### Performance Discussion
User asked about O(n) performance for query operations. Trade-off discussed:
- Current: O(n) queries, but simple and structure-agnostic
- Options: Consumer-side caching, stored aggregates, or hierarchical propagation
- Decision: Keep simple for now, add caching layer if profiling shows need

### Session 5
- **Complete Node Refactoring** - Rewrote from scratch
- Old Node was 3700+ lines "God class" doing everything
- New Node: ~500 lines, single responsibility (tree structure + item storage)
- Key design decisions:
  - **Generic items**: `Node<K, T>` - items don't need any interface
  - **Dual storage**: List for ordering + Map for O(1) key lookups
  - **Implements Iterable<T>**: Clean syntax, all Iterable methods free
  - **keyOf callback**: Extract unique key from items at runtime
  - **Version tracking**: `_version` counter for modification detection
  - **Pure Dart Listenable**: No Flutter dependency
- Comprehensive test coverage: 80 tests covering all functionality
- Edge cases tested: empty nodes, single items, deep nesting (10 levels), wide trees (100 children)

### Session 6
- **Moved collapse state into Node** (removed need for separate CollapseManager)
  - User insight: "If nodes are recreated because of regrouping, everything resets anyway"
  - Collapse is inherently structural - belongs in Node
  - Simpler mental model, less moving parts
  - Added: `isCollapsed`, `toggle()`, `collapse()`, `collapseToLevel()`, `expandToThis()`, `expandAll()`, `collapseAll()`, `visibleDescendants`
  - Node tests: 80 → 104 tests

- **Created CollectionController** - Lean composition container
  - Holds Node + managers
  - Aggregates notifications
  - Convenience methods bridging Node + Selection:
    - `selectAllInNode()`, `selectionStateOfNode()`, `selectedCountInNode()`
    - `expandToItem()` - reveal deeply nested items
    - `processedItems()` - apply filter + sort
  - Does NOT impose UI structure
  - 37 tests, 100% coverage

- **Key Design Decision**: Collapse in Node vs CollapseManager
  - Selection: Items have stable keys → flat storage works
  - Collapse: Nodes are structural → when nodes recreate, collapse state naturally resets
  - This is actually correct UX: new structure = fresh collapse state
