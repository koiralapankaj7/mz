// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

/// Pure Dart collection state management for lists, grids, tables, and trees.
///
/// This library provides a comprehensive set of tools for managing collection
/// state including:
///
/// - **CollectionController** - Central controller that owns data and
///   coordinates managers
/// - **Node** - Tree structure with items, children, and collapse state
/// - **FilterManager** - Filter definitions with search and fuzzy search
/// - **SortManager** - Multi-level sorting with custom comparators
/// - **GroupManager** - Dynamic grouping with multi-value support
/// - **SelectionManager** - Flat storage selection with scopes
/// - **PaginationState** - Multi-directional pagination
/// - **LinkManager** - DAG relationships between nodes
/// - **AggregationManager** - Group-level aggregations
/// - **SlotManager** - Virtualized rendering support
/// - **DataLoader** - Function type for external data sources
///
/// ## Quick Start
///
/// ```dart
/// import 'package:mz_collection/mz_collection.dart';
///
/// // Create a collection controller
/// final controller = CollectionController<Task>(
///   keyOf: (task) => task.id,
/// );
///
/// // Add items directly to controller
/// controller.addAll(tasks);
///
/// // Apply filters
/// controller.filter?.add(StatusFilter.active);
///
/// // Listen to changes
/// controller.addChangeListener(() {
///   print('Collection changed: ${controller.root.length} items');
/// });
/// ```
library;

export 'src/aggregation.dart';
export 'src/collection_controller.dart';
export 'src/core.dart';
export 'src/filter_manager.dart';
export 'src/fuzzy_search.dart';
export 'src/group_manager.dart';
export 'src/link_manager.dart';
export 'src/node.dart';
export 'src/pagination.dart';
export 'src/selection_manager.dart';
export 'src/slot_manager.dart';
export 'src/sort_manager.dart';
