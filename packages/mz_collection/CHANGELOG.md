# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2025-01-31

### Added

- **CollectionController** - Central controller that owns data and coordinates managers
  - CRUD operations: `add`, `addAll`, `remove`, `update`, `clear`
  - Convenience methods: `upsert`, `upsertAll`, `removeAll`, `removeWhere`, `getAll`
  - Optional data loader for external sources with pagination
  - State serialization for deep linking and persistence

- **FilterManager** - Multi-filter support with expressions
  - Filter modes: any, all
  - Expressions: AND, OR, NOT composition
  - TransformSource: local, remote, combined processing
  - SearchFilter for text search
  - FuzzySearchFilter for Levenshtein-based fuzzy matching

- **SortManager** - Multi-level sorting
  - Sort options: value-based, comparable-based, custom comparator
  - Sort order: ascending, descending, none (tri-state)
  - Schwartzian transform optimization for large lists
  - Multi-key caching for efficient multi-level sorting

- **GroupManager** - Hierarchical grouping
  - Single and multi-value grouping
  - Nested groups with configurable depth
  - Group-level sorting
  - Integration with AggregationManager

- **SelectionManager** - Multi-scope selection
  - Scoped selection sets
  - Tri-state support (selected, not selected, toggle)
  - Batch operations

- **PaginationState** - Pagination tracking
  - Cursor and offset token types
  - Multi-edge support (leading/trailing)
  - Loading state tracking with retry support

- **AggregationManager** - Group-level computations
  - Built-in: count, sum, avg, min, max, first, last
  - Custom aggregation support
  - Integration with SlotManager for header display

- **LinkManager** - DAG relationship support
  - Bidirectional and directional links
  - Path finding
  - Reachability queries

- **Node** - Tree structure for display
  - Expand/collapse support
  - Hybrid recursion (iterative for deep trees)
  - Collapse state serialization
  - Item operations: `upsert`, `upsertAll`, `updateAll`
  - Child operations: `insertChildAt`, `reorderChild`, `swapChildren`
  - Navigation: `next(item)`, `prev(item)` for item traversal

- **SlotManager** - Virtualized list support
  - Efficient index calculations
  - Pre-built or on-demand slot creation
  - Group header and item slots
  - Navigation: `adjacentItem`, `nextItemAfter`, `prevItemBefore` for master-detail
  - `GroupHeaderSlot.groupOptionId` to distinguish tree nodes from synthetic groups
  - `isTreeNode` / `isGroupHeader` convenience getters

### Performance

- Multi-level sorting optimized with full Schwartzian transform
- Hybrid recursion prevents stack overflow on deep trees (10,000+ nodes)
- Filtered item caching minimizes redundant processing
