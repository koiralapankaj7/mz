# mz_collection Architecture

## Overview

`mz_collection` is a pure Dart package for managing collections with filtering, sorting, grouping, pagination, and tree-based display. The controller owns data directly and coordinates all managers.

## Core Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CollectionController<K, T>                           │
│                         (Owns data, coordinates managers)                   │
│                                                                             │
│  Responsibilities:                                                          │
│  - Owns data directly (_items, _itemIndex)                                  │
│  - Coordinates all managers (filter, sort, group, selection, etc.)          │
│  - Builds Node<T> tree structure from items                                 │
│  - Applies local filter/sort based on TransformSource                       │
│  - Provides keyOf(T) → K for item identity                                  │
│  - Handles data loading lifecycle (load, loadMore, refresh)                 │
│  - CRUD operations (add, addAll, update, remove, clear)                     │
│                                                                             │
│  Key Properties:                                                            │
│  - items: Iterable<T>            (all items)                                │
│  - keyOf: T → K                  (identity function)                        │
│  - dataLoader: DataLoader<T>?    (optional, for external sources)           │
│  - filter: FilterManager<T>?     (optional)                                 │
│  - sort: SortManager<T>?         (optional)                                 │
│  - group: GroupManager<T>?       (optional)                                 │
│  - selection: SelectionManager<K>                                           │
│  - root: Node<T>                 (tree structure for display)               │
│                                                                             │
│  CRUD Methods:                                                              │
│  - add(T) → bool                 (add item, returns false if key exists)    │
│  - addAll(Iterable<T>)           (add multiple items)                       │
│  - update(K, (T) → T)            (update item by key)                       │
│  - remove(K) → bool              (remove item by key)                       │
│  - clear()                       (remove all items)                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                    (optional) dataLoader
                                     │
            ┌────────────────────────┼────────────────────────┐
            ▼                        ▼                        ▼
      REST API                 SQLite/Drift                GraphQL
```

## Data Flow

```
┌──────────────┐                    ┌──────────────────────────────────────┐
│   UI / App   │ ── CRUD ops ────►  │        CollectionController          │
│              │                    │     (owns data, builds tree)         │
└──────────────┘                    └──────────────────────────────────────┘
       ▲                                    │ (optional)
       │                                    │ dataLoader
       │ notifies                           ▼
       │                            ┌──────────────┐
       └─────────────────────────── │  API/DB/etc  │
                                    └──────────────┘

Tree Building Pipeline:

  1. Get items from controller
     controller.items → Iterable<T>

  2. Apply local filters (TransformSource.local or .combined)
     FilterManager.apply(items) → filtered items

  3. Build node structure
     - If GroupManager: create group nodes, sort groups, sort items within groups
     - If no grouping: create flat list of item nodes

  4. Apply local sorting (TransformSource.local or .combined)
     SortManager.apply(items) → sorted items

  5. Result: root Node<T> with children
       │
       ▼
┌──────────────┐
│   Node<T>    │  → Used by SlotManager for virtualized list display
└──────────────┘
```

## Type Parameters

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  K = Key type (e.g., String, int)                                           │
│      - Used by Controller to identify items                                 │
│      - Provided via keyOf: (T item) → K                                     │
│      - Used for selection, lookup by key, CRUD by key                       │
│                                                                             │
│  T = Item type (e.g., User, Task, Product)                                  │
│      - Stored in Controller, wrapped in Node<T> for display                 │
└─────────────────────────────────────────────────────────────────────────────┘

Example:
  CollectionController<String, Task>
  - K = String (task.id)
  - T = Task
  - keyOf = (task) => task.id
```

## Managers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              FilterManager<T>                               │
│                                                                             │
│  Contains: List<Filter<T, V>>                                               │
│  Each Filter has:                                                           │
│  - id: String                                                               │
│  - test: (T item, V value) → bool                                           │
│  - values: Set<V> (selected filter values)                                  │
│  - source: TransformSource (local/remote/combined)                          │
│                                                                             │
│  Key getters:                                                               │
│  - remoteFilters: filters with source = remote or combined                  │
│  - localFilters: filters with source = local or combined                    │
│  - criteria: FilterCriteria (serializable for PageRequest)                  │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              SortManager<T>                                 │
│                                                                             │
│  Contains: List<SortOption<T, V>>                                           │
│  Each SortOption has:                                                       │
│  - id: String                                                               │
│  - compare: (T a, T b) → int                                                │
│  - sortOrder: SortOrder (ascending/descending)                              │
│  - source: TransformSource (local/remote/combined)                          │
│                                                                             │
│  Key getters:                                                               │
│  - remoteSorts: sorts with source = remote or combined                      │
│  - localSorts: sorts with source = local or combined                        │
│  - criteria: SortCriteria (serializable for PageRequest)                    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              GroupManager<T>                                │
│                                                                             │
│  Contains: List<GroupOption<T, G>>                                          │
│  Each GroupOption has:                                                      │
│  - id: String                                                               │
│  - valueBuilder: (T item) → G? (extract group key)                          │
│  - keyBuilder: (G value) → String (group key for node)                      │
│  - labelBuilder: (G value) → String (display label)                         │
│  - sortOption: SortOption<G, V>? (for sorting groups)                       │
│  - enabled: bool                                                            │
│  - order: int (for multi-level grouping order)                              │
│                                                                             │
│  Supports:                                                                  │
│  - Single-value grouping: item belongs to one group                         │
│  - Multi-value grouping: item can appear in multiple groups                 │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                           SelectionManager<K>                               │
│                                                                             │
│  Manages selected item keys (not items themselves)                          │
│  - select(K key), deselect(K key), toggle(K key)                            │
│  - selectAll(Iterable<K>), deselectAll(), clear()                           │
│  - isSelected(K key) → bool                                                 │
│  - selectedKeys → Set<K>                                                    │
│  - selectionMode: single/multi/none                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

## TransformSource (Filter/Sort Processing)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            TransformSource                                  │
│                                                                             │
│  Determines WHERE filtering/sorting happens:                                │
│                                                                             │
│  ┌─────────────┬──────────────────┬──────────────────┬───────────────────┐  │
│  │   Source    │ Local Processing │ Remote (in req)  │ Use Case          │  │
│  ├─────────────┼──────────────────┼──────────────────┼───────────────────┤  │
│  │ local       │ ✓ Yes            │ ✗ No             │ Client-only       │  │
│  │ remote      │ ✗ No             │ ✓ Yes            │ Server-only       │  │
│  │ combined    │ ✓ Yes            │ ✓ Yes            │ Both              │  │
│  └─────────────┴──────────────────┴──────────────────┴───────────────────┘  │
│                                                                             │
│  Controller behavior:                                                       │
│  - On filter/sort change with remote source → triggers refetch              │
│  - Local filters/sorts always applied to items during tree build            │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Node Structure

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                               Node<T>                                       │
│                                                                             │
│  A node in the display tree. Can be:                                        │
│  - Root node (no item, contains all top-level children)                     │
│  - Group node (no item, represents a group header)                          │
│  - Item node (has item: T, represents actual data)                          │
│                                                                             │
│  Properties:                                                                │
│  - key: String (unique identifier)                                          │
│  - item: T? (null for root/group nodes)                                     │
│  - children: List<Node<T>>                                                  │
│  - parent: Node<T>?                                                         │
│  - depth: int                                                               │
│  - isExpanded: bool                                                         │
│  - isGroup: bool                                                            │
│  - groupValue: dynamic (for group nodes)                                    │
└─────────────────────────────────────────────────────────────────────────────┘

Example tree (grouped by category):

  root
  ├── group: "Work" (isGroup: true)
  │   ├── item: Task(id: "1", title: "Review PR")
  │   └── item: Task(id: "2", title: "Fix bug")
  └── group: "Personal" (isGroup: true)
      ├── item: Task(id: "3", title: "Buy groceries")
      └── item: Task(id: "4", title: "Call mom")
```

## DataLoader and PageRequest/PageResponse

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             DataLoader<T>                                   │
│                                                                             │
│  Function type for loading data from external sources:                      │
│  typedef DataLoader<T> = Future<PageResponse<T>> Function(PageRequest);    │
│                                                                             │
│  Used with controller's optional dataLoader parameter for:                  │
│  - REST APIs                                                                │
│  - GraphQL queries                                                          │
│  - Database queries                                                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                             PageRequest                                     │
│                                                                             │
│  Sent to DataLoader with full query context:                                │
│  - edge: PaginationEdge (leading/trailing)                                  │
│  - token: PageToken? (offset, cursor, or custom)                            │
│  - limit: int?                                                              │
│  - filter: FilterCriteria? (from FilterManager.remoteFilters)               │
│  - sort: SortCriteria? (from SortManager.remoteSorts)                       │
│  - group: GroupCriteria? (from GroupManager)                                │
│  - search: String?                                                          │
│                                                                             │
│  DataLoader implementations can use these to optimize queries               │
│  (e.g., SQL WHERE, ORDER BY, API query params)                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                            PageResponse<T>                                  │
│                                                                             │
│  Returned from DataLoader:                                                  │
│  - items: List<T> (fetched items)                                           │
│  - nextToken: PageToken? (for next page, null if exhausted)                 │
│  - hasMore: bool (convenience getter)                                       │
│  - childHints: Map<String, bool>? (for lazy loading tree nodes)             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Mixins (Controller Composition)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  CollectionController is composed of several mixins:                        │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ TreeBuildingMixin<K, T>                                             │    │
│  │ - Builds Node<T> tree from items                                    │    │
│  │ - Applies local filtering and sorting                               │    │
│  │ - Handles grouping logic                                            │    │
│  │ - Caches filtered items for performance                             │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ DataLoadingMixin<K, T>                                              │    │
│  │ - Manages load/loadMore/refresh lifecycle                           │    │
│  │ - Tracks pagination state per edge                                  │    │
│  │ - Debounces refetch requests                                        │    │
│  │ - Clears items on initial load                                      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ ChildLoadingMixin<K, T>                                             │    │
│  │ - Lazy loading of child nodes                                       │    │
│  │ - For hierarchical data (tree structures)                           │    │
│  │ - Uses dataLoader with notify: false to prevent premature rebuilds  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ StateSerializationMixin                                             │    │
│  │ - Snapshot/restore of controller state                              │    │
│  │ - For URL query params, deep linking, state persistence             │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

## SlotManager (Virtualized Display)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SlotManager<K, T>                                 │
│                                                                             │
│  Flattens Node<T> tree into slots for virtualized list display:             │
│                                                                             │
│  Node Tree:                    Slots (flattened):                           │
│                                                                             │
│    root                        [0] group: "Work"                            │
│    ├── group: "Work"           [1] item: Task(1)                            │
│    │   ├── Task(1)             [2] item: Task(2)                            │
│    │   └── Task(2)             [3] group: "Personal"                        │
│    └── group: "Personal"       [4] item: Task(3)                            │
│        ├── Task(3)             [5] item: Task(4)                            │
│        └── Task(4)                                                          │
│                                                                             │
│  Handles:                                                                   │
│  - Expand/collapse groups                                                   │
│  - Index calculations                                                       │
│  - Efficient updates on tree changes                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Typical Usage Flow

```dart
1. Create Managers (optional)
   final filter = FilterManager<Task>(filters: [...]);
   final sort = SortManager<Task>(options: [...]);
   final group = GroupManager<Task>(options: [...]);

2. Create Controller (owns data)
   final controller = CollectionController<String, Task>(
     keyOf: (task) => task.id,
     filter: filter,
     sort: sort,
     group: group,
     // Optional: dataLoader for external data sources
     dataLoader: (request) => api.fetchTasks(request),
   );

3. Add Data (or load from external source)
   // Direct CRUD
   controller.addAll(tasks);
   controller.add(newTask);
   controller.update('task-1', (t) => t.copyWith(done: true));
   controller.remove('task-1');

   // Or load from dataLoader
   await controller.load();

4. Access Tree for Display
   final root = controller.root;
   // or use SlotManager for virtualized list
   final slotManager = SlotManager(controller: controller);

5. Interact with Managers
   filter['status']!.add('completed');    // Filter changes → tree rebuilds
   sort.setCurrent(sort['date']);         // Sort changes → tree rebuilds
   controller.selection.select('task-1'); // Selection changes

6. Cleanup
   controller.dispose();
```

## Key Design Decisions

1. **Controller owns data** - CRUD operations go directly to controller, no separate Store
2. **DataLoader is optional** - For fetching from external sources (APIs, DBs)
3. **Key-based CRUD** - `remove(key)`, `update(key, fn)` instead of item-based
4. **Dual storage** - `_items: List<T>` preserves order, `_itemIndex: Map<K, T>` for O(1) lookup
5. **TransformSource on Filter/Sort** - Each filter/sort declares where it runs
6. **CRUD is sync, rebuilds are async** - Use `rebuildRootAsync()` for large datasets
7. **Node tree rebuilt on changes** - Cached filtered items optimize rebuild
8. **Managers are optional** - Controller works with just `keyOf`
