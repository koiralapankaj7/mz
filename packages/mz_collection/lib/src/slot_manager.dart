// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

// GroupHeaderSlot uses getter/setter pairs intentionally for efficient
// in-place updates during collapse/expand operations.
// ignore_for_file: unnecessary_getters_setters

/// {@template mz_collection.slot_manager_library}
/// Slot-based virtualization support for efficient rendering of large
/// collections with grouping.
///
/// ## Overview
///
/// A **slot** is a position in the flattened view of a hierarchical collection.
/// Slots provide a unified addressing system that includes group headers,
/// items, and group footers, enabling efficient virtualized rendering.
///
/// ```text
/// Tree Structure:              Slots:
/// ├─ Group "A"                 0: GroupHeader "A"
/// │  ├─ Item 1                 1: Item 1
/// │  ├─ Item 2                 2: Item 2
/// │  └─ Item 3                 3: Item 3
/// ├─ Group "B"                 4: GroupHeader "B"
/// │  ├─ Item 4                 5: Item 4
/// │  └─ Item 5                 6: Item 5
/// └─ Group "C" (collapsed)     7: GroupHeader "C" (items hidden)
///    ├─ Item 6                 (skipped - collapsed)
///    └─ Item 7                 (skipped - collapsed)
/// ```
///
/// ## Key Features
///
/// - **O(1) slot count** - cached total
/// - **O(1) slot lookup** - flat array with direct index access
/// - **Collapse-aware** - automatically skips collapsed subtrees
/// - **Filter-aware** - only counts items that pass the filter
/// - **Pure Dart** - no Flutter dependency
///
/// ## Usage
///
/// {@tool snippet}
/// Using SlotManager with ListView.builder:
///
/// ```dart
/// final controller = CollectionController<Task>(...);
/// final slotManager = SlotManager<Task>(controller: controller);
///
/// // Get total visible slots
/// print(slotManager.totalSlots); // e.g., 150
///
/// // Get slot at index (for ListView.builder)
/// final slot = slotManager.getSlot(42);
/// switch (slot) {
///   case ItemSlot(:final item):
///     return ItemWidget(item);
///   case GroupHeaderSlot(:final node, :final depth):
///     return GroupHeader(node.id, depth: depth);
///   case null:
///     return SizedBox.shrink();
/// }
///
/// // Get range for visible viewport
/// final visibleSlots = slotManager.getSlotRange(start: 20, count: 15);
/// ```
/// {@end-tool}
/// {@endtemplate}
library;

import 'aggregation.dart';
import 'collection_controller.dart';
import 'group_manager.dart' show GroupOption;
import 'node.dart';

// =============================================================================
// Slot Types
// =============================================================================

/// {@template mz_collection.slot}
/// A position in the flattened virtualized view.
///
/// Slots provide a unified addressing system for items and group headers
/// in a hierarchical collection.
///
/// Use pattern matching to handle different slot types:
///
/// {@tool snippet}
/// Pattern matching on slot types:
///
/// ```dart
/// switch (slot) {
///   case ItemSlot(:final key, :final item):
///     // Render item
///   case GroupHeaderSlot(:final node, :final isCollapsed):
///     // Render group header with expand/collapse
/// }
/// ```
/// {@end-tool}
/// {@endtemplate}
sealed class Slot<T> {
  Slot({required this.index, required this.depth});

  /// The slot index in the flattened view.
  ///
  /// Mutable to allow efficient in-place updates when slots are
  /// inserted or removed without recreating all slot objects.
  int index;

  /// The nesting depth (0 = root level).
  final int depth;
}

/// {@template mz_collection.item_slot}
/// A slot containing an actual data item.
///
/// Provides access to the item and its key for rendering.
/// {@endtemplate}
final class ItemSlot<T> extends Slot<T> {
  /// Creates an item slot.
  ItemSlot({
    required super.index,
    required super.depth,
    required this.key,
    required this.item,
  });

  /// The unique key for this item.
  final String key;

  /// The actual data item.
  final T item;

  @override
  String toString() => 'ItemSlot($index, key: $key, depth: $depth)';
}

/// {@template mz_collection.group_header_slot}
/// A slot containing a group header.
///
/// Provides access to the group node for rendering headers with
/// expand/collapse functionality and optional aggregate values.
///
/// ## Tree vs Group Headers
///
/// Use [groupOptionId] to distinguish between tree nodes and synthetic groups:
/// - `null` - This is a **tree node** from the natural data hierarchy
/// - Non-null - This is a **group header** created by GroupManager
///
/// {@tool snippet}
/// Rendering different header styles:
///
/// ```dart
/// switch (slot) {
///   case GroupHeaderSlot(:final node, :final groupOptionId):
///     if (groupOptionId == null) {
///       // Tree node - e.g., folder in file browser
///       return TreeNodeHeader(node);
///     } else {
///       // Group header - e.g., "Status: Active"
///       return GroupHeader(node, groupBy: groupOptionId);
///     }
/// }
/// ```
/// {@end-tool}
///
/// ## With Aggregates
///
/// {@tool snippet}
/// Accessing aggregate values in group headers:
///
/// ```dart
/// switch (slot) {
///   case GroupHeaderSlot(:final label, :final aggregates):
///     final count = aggregates?['count'] ?? 0;
///     final total = aggregates?['total'] ?? 0.0;
///     return GroupHeader(label, count: count, total: total);
/// }
/// ```
/// {@end-tool}
/// {@endtemplate}
final class GroupHeaderSlot<T> extends Slot<T> {
  /// Creates a group header slot.
  GroupHeaderSlot({
    required super.index,
    required super.depth,
    required this.node,
    required bool isCollapsed,
    required int itemCount,
    required int totalCount,
    this.groupOptionId,
    AggregateResult? aggregates,
  })  : _isCollapsed = isCollapsed,
        _itemCount = itemCount,
        _totalCount = totalCount,
        _aggregates = aggregates;

  /// The node representing this group.
  final Node<T> node;

  /// The ID of the [GroupOption] that created this header, or `null` for
  /// tree nodes.
  ///
  /// Use this to distinguish between:
  /// - **Tree nodes** (`null`) - Natural hierarchy from the data structure
  /// - **Group headers** (non-null) - Synthetic grouping from GroupManager
  ///
  /// ```dart
  /// if (slot.groupOptionId == null) {
  ///   // Tree node - render as folder/parent item
  /// } else if (slot.groupOptionId == 'status') {
  ///   // Grouped by status - render as "Status: Active"
  /// }
  /// ```
  final String? groupOptionId;

  /// Whether this header is from a tree node (not a GroupManager group).
  ///
  /// Convenience getter for `groupOptionId == null`.
  bool get isTreeNode => groupOptionId == null;

  /// Whether this header is from a GroupManager group option.
  ///
  /// Convenience getter for `groupOptionId != null`.
  bool get isGroupHeader => groupOptionId != null;

  bool _isCollapsed;
  int _itemCount;
  int _totalCount;
  AggregateResult? _aggregates;

  /// Whether this group is currently collapsed.
  ///
  /// Mutable to allow efficient in-place updates during collapse/expand.
  // Getter/setter pair is intentional - enables mutable access to private field
  // for efficient slot updates during collapse/expand operations.
  bool get isCollapsed => _isCollapsed;
  set isCollapsed(bool value) => _isCollapsed = value;

  /// Number of direct items in this group (excluding nested groups).
  ///
  /// Mutable to allow efficient in-place updates when item counts change.
  int get itemCount => _itemCount;
  set itemCount(int value) => _itemCount = value;

  /// Total items including all nested groups.
  ///
  /// Mutable to allow efficient in-place updates when item counts change.
  int get totalCount => _totalCount;
  set totalCount(int value) => _totalCount = value;

  /// Computed aggregate values for this group.
  ///
  /// Contains values like sum, count, average for items in this group.
  /// Returns null if no aggregations are configured.
  ///
  /// {@tool snippet}
  /// Accessing aggregate values:
  ///
  /// ```dart
  /// final count = slot.aggregates?['count'];
  /// final total = slot.aggregates?.get<double>('total');
  /// ```
  /// {@end-tool}
  AggregateResult? get aggregates => _aggregates;
  set aggregates(AggregateResult? value) => _aggregates = value;

  /// The group's unique identifier (may be hierarchical like "Work/todo").
  ///
  /// Use this for collapse/expand operations.
  String get groupId => node.id;

  /// The group's display label (just the group value, e.g., "todo").
  ///
  /// For hierarchical IDs like "Work/todo", returns just "todo".
  /// Use this for UI display.
  String get label {
    final id = node.id;
    final lastSlash = id.lastIndexOf('/');
    return lastSlash == -1 ? id : id.substring(lastSlash + 1);
  }

  @override
  String toString() => 'GroupHeaderSlot($index, id: $groupId, depth: $depth, '
      'collapsed: $isCollapsed, items: $itemCount)';
}

// =============================================================================
// Group Info (for predicates)
// =============================================================================

/// Information about a group for use in collapse/expand predicates.
///
/// Used by [SlotManager.collapseWhere] and [SlotManager.expandWhere].
final class GroupInfo<T> {
  /// Creates group info (internal constructor).
  const GroupInfo({
    required this.node,
    required this.depth,
    required this.itemCount,
    required this.totalCount,
  });

  /// The group node.
  final Node<T> node;

  /// Nesting depth (0 = top level groups, 1 = nested, etc.).
  final int depth;

  /// Number of direct items in this group (excluding nested groups).
  final int itemCount;

  /// Total items including all nested groups.
  final int totalCount;

  /// The group's unique identifier.
  String get groupId => node.id;

  /// The group's display label (last segment of hierarchical ID).
  String get label {
    final id = node.id;
    final lastSlash = id.lastIndexOf('/');
    return lastSlash == -1 ? id : id.substring(lastSlash + 1);
  }

  /// Whether this group is currently collapsed.
  bool get isCollapsed => node.isCollapsed;
}

// =============================================================================
// SlotManager
// =============================================================================

/// {@template mz_collection.slot_manager}
/// Manages slot-based access to a hierarchical collection.
///
/// Provides **O(1) access** to slots in a flattened view of the collection
/// tree, supporting virtualized rendering of large datasets with instant
/// scrollbar dragging.
///
/// ## Features
///
/// - **O(1) lookup**: Flat array enables constant-time slot access
/// - **Collapse-aware**: Automatically skips collapsed subtrees
/// - **Filter-aware**: Only counts items passing the current filter
///
/// ## Memory Trade-off
///
/// The O(1) lookup uses a flat array with one entry per slot (~16-24 bytes
/// each). For 10,000 items, this is ~200KB - a reasonable trade-off for
/// instant scrolling performance.
///
/// ## Example
///
/// {@tool snippet}
/// Integrating SlotManager with ListView.builder:
///
/// ```dart
/// final slotManager = SlotManager<Task>(
///   controller: collectionController,
/// );
///
/// // Use with ListView.builder
/// ListView.builder(
///   itemCount: slotManager.totalSlots,
///   itemBuilder: (context, index) {
///     final slot = slotManager.getSlot(index);
///     return switch (slot) {
///       ItemSlot(:final item) => TaskTile(item),
///       GroupHeaderSlot(:final node) => GroupHeader(node),
///       null => const SizedBox.shrink(),
///     };
///   },
/// );
/// ```
/// {@end-tool}
/// {@endtemplate}
class SlotManager<T> with Listenable {
  /// Creates a slot manager for the given controller.
  ///
  /// The manager automatically rebuilds when the controller changes.
  ///
  /// Set [usePrebuiltSlots] to `false` to use on-demand slot creation
  /// (creates Slot objects on each getSlot() call). Default is `true`
  /// which pre-builds all Slot objects for zero-allocation access.
  ///
  /// Provide [aggregations] to compute aggregate values for group headers.
  SlotManager({
    required this.controller,
    this.aggregations,
    this.usePrebuiltSlots = true,
  }) {
    controller.addChangeListener(_onControllerChanged);
    aggregations?.addChangeListener(_onAggregationsChanged);
    _rebuild();
  }

  /// The collection controller providing the data.
  final CollectionController<T> controller;

  /// Optional aggregation manager for computing group summaries.
  ///
  /// When provided, group headers will include computed aggregate values
  /// (counts, sums, averages, etc.) accessible via
  /// [GroupHeaderSlot.aggregates].
  final AggregationManager<T>? aggregations;

  /// Whether to use pre-built Slot objects (true) or create on-demand (false).
  ///
  /// - `true` (default): Pre-builds Slot objects during rebuild for O(1)
  ///   access with zero allocations. Better scroll performance.
  /// - `false`: Stores lightweight references and creates Slot objects
  ///   on each getSlot() call. Lower memory, but allocates per access.
  final bool usePrebuiltSlots;

  // ---------------------------------------------------------------------------
  // Cached State
  // ---------------------------------------------------------------------------

  /// Cached node references for O(1) lookup by ID.
  final Map<String, Node<T>> _nodeCache = {};

  /// Flat array of pre-built Slot objects for O(1) lookup.
  /// Used when [usePrebuiltSlots] is true.
  final List<Slot<T>> _slots = [];

  /// Flat array of slot location references for on-demand slot creation.
  /// Used when [usePrebuiltSlots] is false.
  final List<_SlotLocation<T>> _slotLocations = [];

  /// Total visible slot count.
  int _totalSlots = 0;

  /// Unique item keys (computed lazily for multi-value grouping tracking).
  Set<String>? _uniqueKeys;

  /// Whether unique keys need to be recomputed.
  bool _uniqueKeysDirty = true;

  /// Cache version for invalidation tracking.
  int _version = 0;

  /// Whether filtering is needed (cached per rebuild).
  bool _hasActiveFilter = false;

  /// Whether this manager has been disposed.
  bool _isDisposed = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Total number of visible slots.
  ///
  /// This includes all visible items and group headers, excluding
  /// items within collapsed groups.
  int get totalSlots => _totalSlots;

  /// Cache version, incremented on each rebuild.
  ///
  /// Useful for detecting stale cached data in UI layer.
  int get version => _version;

  /// Whether the slot manager has any slots.
  bool get isEmpty => _totalSlots == 0;

  /// Whether the slot manager has slots.
  bool get isNotEmpty => _totalSlots > 0;

  /// Number of unique items across all groups.
  ///
  /// With multi-value grouping, the same item can appear in multiple groups.
  /// This property returns the count of distinct items (by key), while
  /// [totalSlots] includes headers plus all appearances of items.
  ///
  /// For single-value grouping, this equals the total item slots.
  ///
  /// This is computed lazily on first access after a rebuild.
  ///
  /// {@tool snippet}
  /// Counting unique items vs total slots:
  ///
  /// ```dart
  /// // Product with tags ['electronics', 'sale'] appears in 2 groups
  /// print(slotManager.totalSlots);      // 5 (2 headers + 3 items visible)
  /// print(slotManager.uniqueItemCount); // 2 (2 unique products)
  /// ```
  /// {@end-tool}
  int get uniqueItemCount {
    if (_uniqueKeysDirty) {
      _computeUniqueKeys();
    }
    return _uniqueKeys!.length;
  }

  /// Computes unique keys lazily (only when accessed).
  void _computeUniqueKeys() {
    _uniqueKeys = <String>{};
    if (usePrebuiltSlots) {
      for (final slot in _slots) {
        if (slot is ItemSlot<T>) {
          _uniqueKeys!.add(slot.key);
        }
      }
    } else {
      for (final loc in _slotLocations) {
        if (!loc.isHeader) {
          final item = loc.node.at(loc.itemIndex);
          _uniqueKeys!.add(loc.node.keyOf(item));
        }
      }
    }
    _uniqueKeysDirty = false;
  }

  /// Gets the slot at the given [index].
  ///
  /// Returns `null` if [index] is out of bounds.
  ///
  /// When [usePrebuiltSlots] is true, this is **O(1) with zero allocations**.
  /// When false, this creates a new Slot object on each call.
  ///
  /// {@tool snippet}
  /// Accessing a slot at a specific index:
  ///
  /// ```dart
  /// final slot = slotManager.getSlot(42);
  /// if (slot case ItemSlot(:final item)) {
  ///   print(item);
  /// }
  /// ```
  /// {@end-tool}
  Slot<T>? getSlot(int index) {
    if (usePrebuiltSlots) {
      if (index < 0 || index >= _slots.length) return null;
      return _slots[index];
    } else {
      if (index < 0 || index >= _slotLocations.length) return null;
      return _createSlotFromLocation(_slotLocations[index], index);
    }
  }

  /// Creates a Slot from a location reference (on-demand approach).
  Slot<T> _createSlotFromLocation(_SlotLocation<T> loc, int index) {
    if (loc.isHeader) {
      return GroupHeaderSlot<T>(
        index: index,
        depth: loc.depth,
        node: loc.node,
        isCollapsed: loc.node.isCollapsed,
        itemCount: loc.node.length,
        totalCount: loc.node.flattenedLength,
        groupOptionId: _extractGroupOptionId(loc.node),
        aggregates: _computeAggregates(loc.node),
      );
    } else {
      final item = loc.node.at(loc.itemIndex);
      return ItemSlot<T>(
        index: index,
        depth: loc.depth + 1,
        key: loc.node.keyOf(item),
        item: item,
      );
    }
  }

  /// Extracts the group option ID from a node, or null if it's a tree node.
  String? _extractGroupOptionId(Node<T> node) {
    final extra = node.extra;
    if (extra is GroupOption<T, dynamic>) {
      return extra.id;
    }
    return null;
  }

  /// Checks if slot at [index] is a group header.
  ///
  /// **O(1) with zero allocations**.
  bool isHeader(int index) {
    if (usePrebuiltSlots) {
      if (index < 0 || index >= _slots.length) return false;
      return _slots[index] is GroupHeaderSlot<T>;
    } else {
      if (index < 0 || index >= _slotLocations.length) return false;
      return _slotLocations[index].isHeader;
    }
  }

  /// Gets the item at slot [index], or null if it's a header or out of bounds.
  ///
  /// **O(1) with zero allocations**.
  T? getItem(int index) {
    if (usePrebuiltSlots) {
      if (index < 0 || index >= _slots.length) return null;
      final slot = _slots[index];
      if (slot is ItemSlot<T>) {
        return slot.item;
      }
      return null;
    } else {
      if (index < 0 || index >= _slotLocations.length) return null;
      final loc = _slotLocations[index];
      if (loc.isHeader) return null;
      return loc.node.at(loc.itemIndex);
    }
  }

  /// Gets a range of slots.
  ///
  /// Returns slots from [start] to [start] + [count] - 1.
  /// Useful for rendering a visible viewport.
  ///
  /// {@tool snippet}
  /// Getting slots for a visible viewport:
  ///
  /// ```dart
  /// final visible = slotManager.getSlotRange(
  ///   start: firstVisibleIndex,
  ///   count: visibleItemCount,
  /// );
  /// ```
  /// {@end-tool}
  List<Slot<T>> getSlotRange({required int start, required int count}) {
    final clampedStart = start.clamp(0, _totalSlots);
    final end = (start + count).clamp(0, _totalSlots);
    if (clampedStart >= end) return const [];

    // With prebuilt slots, return a sublist view (no new list allocation)
    if (usePrebuiltSlots) {
      return _slots.sublist(clampedStart, end);
    }

    // Without prebuilt slots, build on demand
    final result = List<Slot<T>>.generate(
      end - clampedStart,
      (i) => _createSlotFromLocation(
        _slotLocations[clampedStart + i],
        clampedStart + i,
      ),
    );
    return result;
  }

  /// Finds the slot index for an item with the given [key].
  ///
  /// Returns `-1` if the item is not found or is hidden (in collapsed group
  /// or filtered out).
  ///
  /// This operation is O(n) in the worst case.
  int indexOfKey(String key) {
    final item = controller[key];
    if (item == null) return -1;

    // Check if item passes filter
    if (!_passesFilter(item)) return -1;

    // Search for the item
    var index = 0;
    final found = _findKeyIndex(controller.root, key, 0, (i) => index = i);
    return found ? index : -1;
  }

  /// Finds the adjacent item to an item with the given [key].
  ///
  /// Returns the next visible item if available, otherwise the previous item.
  /// Returns `null` if no adjacent item exists (item is the only one visible).
  ///
  /// This is useful for master-detail views where deleting an item should
  /// auto-select the nearest neighbor.
  ///
  /// {@tool snippet}
  /// Auto-selecting adjacent item after deletion:
  ///
  /// ```dart
  /// void deleteItem(String key) {
  ///   final adjacent = slotManager.adjacentItem(key);
  ///   controller.remove(key);
  ///   if (adjacent != null) {
  ///     controller.selection.select(controller.keyOf(adjacent));
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  T? adjacentItem(String key) {
    final index = indexOfKey(key);
    if (index == -1) return null;

    // Try next item first
    final nextItem = nextItemAfter(index);
    if (nextItem != null) return nextItem;

    // Fall back to previous item
    return prevItemBefore(index);
  }

  /// Gets the next visible item after slot [index].
  ///
  /// Skips group headers. Returns `null` if no more items.
  T? nextItemAfter(int index) {
    for (var i = index + 1; i < _totalSlots; i++) {
      final item = getItem(i);
      if (item != null) return item;
    }
    return null;
  }

  /// Gets the previous visible item before slot [index].
  ///
  /// Skips group headers. Returns `null` if no more items.
  T? prevItemBefore(int index) {
    for (var i = index - 1; i >= 0; i--) {
      final item = getItem(i);
      if (item != null) return item;
    }
    return null;
  }

  /// Toggles the collapsed state of a group.
  ///
  /// When a group is collapsed, its children are hidden and don't
  /// occupy slots.
  ///
  /// Uses **incremental updates** for O(v) performance where v is the number
  /// of visible descendants, instead of O(n) full rebuild.
  void toggleCollapse(String groupId) {
    if (_isDisposed) return;
    final node = _nodeCache[groupId] ?? _findNode(controller.root, groupId);
    if (node == null) return;

    if (node.isCollapsed) {
      _expandNode(node, groupId);
    } else {
      _collapseNode(node, groupId);
    }
  }

  /// Collapses a group by ID.
  ///
  /// Uses **incremental updates** for O(v) performance.
  void collapse(String groupId) {
    if (_isDisposed) return;
    final node = _nodeCache[groupId] ?? _findNode(controller.root, groupId);
    if (node != null && !node.isCollapsed) {
      _collapseNode(node, groupId);
    }
  }

  /// Expands a group by ID.
  ///
  /// Uses **incremental updates** for O(v) performance.
  void expand(String groupId) {
    if (_isDisposed) return;
    final node = _nodeCache[groupId] ?? _findNode(controller.root, groupId);
    if (node != null && node.isCollapsed) {
      _expandNode(node, groupId);
    }
  }

  /// Incrementally collapses a node by removing its descendant slots.
  ///
  /// If the node's slot is not currently visible (e.g., parent is collapsed),
  /// only the node state is updated. The visual change will appear when the
  /// ancestor is expanded.
  void _collapseNode(Node<T> node, String groupId) {
    node.collapse(state: Tristate.yes, notify: false);

    final slotIndex = usePrebuiltSlots
        ? _findSlotIndex(groupId)
        : _findSlotIndexOnDemand(groupId);

    // If slot not visible (parent collapsed), just update state and notify.
    // The slot will be created with correct state when parent expands.
    if (slotIndex == -1) {
      _version++;
      notifyChanged();
      return;
    }

    if (usePrebuiltSlots) {
      _collapseSlotPrebuilt(slotIndex, node);
    } else {
      _collapseSlotOnDemand(slotIndex);
    }

    _uniqueKeysDirty = true;
    _version++;
    notifyChanged();
  }

  /// Collapses a slot in prebuilt mode by removing descendant slots.
  void _collapseSlotPrebuilt(int slotIndex, Node<T> node) {
    final headerSlot = _slots[slotIndex] as GroupHeaderSlot<T>;
    final depth = headerSlot.depth;

    // Count slots to remove (all descendants until we hit same/lower depth)
    var removeCount = 0;
    for (var i = slotIndex + 1; i < _slots.length; i++) {
      if (_slots[i].depth <= depth) break;
      removeCount++;
    }

    // Update header to collapsed state (in-place, no object recreation)
    headerSlot
      ..isCollapsed = true
      ..itemCount = node.length
      ..totalCount = node.flattenedLength;

    // Remove descendant slots
    if (removeCount > 0) {
      _slots.removeRange(slotIndex + 1, slotIndex + 1 + removeCount);
      _updateSlotIndices(slotIndex + 1);
    }

    _totalSlots = _slots.length;
  }

  /// Collapses a slot in on-demand mode by removing descendant locations.
  void _collapseSlotOnDemand(int slotIndex) {
    final loc = _slotLocations[slotIndex];
    final depth = loc.depth;

    var removeCount = 0;
    for (var i = slotIndex + 1; i < _slotLocations.length; i++) {
      final slotLoc = _slotLocations[i];
      final slotDepth = slotLoc.isHeader ? slotLoc.depth : slotLoc.depth + 1;
      if (slotDepth <= depth) break;
      removeCount++;
    }

    if (removeCount > 0) {
      _slotLocations.removeRange(slotIndex + 1, slotIndex + 1 + removeCount);
    }

    _totalSlots = _slotLocations.length;
  }

  /// Incrementally expands a node by inserting its descendant slots.
  ///
  /// If the node's slot is not currently visible (e.g., parent is collapsed),
  /// only the node state is updated. The visual change will appear when the
  /// ancestor is expanded.
  void _expandNode(Node<T> node, String groupId) {
    node.collapse(state: Tristate.no, notify: false);

    final slotIndex = usePrebuiltSlots
        ? _findSlotIndex(groupId)
        : _findSlotIndexOnDemand(groupId);

    // If slot not visible (parent collapsed), just update state and notify.
    // The slot will be created with correct state when parent expands.
    if (slotIndex == -1) {
      _version++;
      notifyChanged();
      return;
    }

    if (usePrebuiltSlots) {
      _expandSlotPrebuilt(slotIndex, node);
    } else {
      _expandSlotOnDemand(slotIndex, node);
    }

    _uniqueKeysDirty = true;
    _version++;
    notifyChanged();
  }

  /// Expands a slot in prebuilt mode by inserting descendant slots.
  void _expandSlotPrebuilt(int slotIndex, Node<T> node) {
    final headerSlot = _slots[slotIndex] as GroupHeaderSlot<T>;
    final depth = headerSlot.depth;

    // Update header to expanded state (in-place, no object recreation)
    headerSlot
      ..isCollapsed = false
      ..itemCount = node.length
      ..totalCount = node.flattenedLength;

    // Build slots for descendants
    final newSlots = <Slot<T>>[];
    var tempIndex = slotIndex + 1;
    _buildSlotsForExpand(node, depth + 1, newSlots, () => tempIndex++);

    // Insert new slots
    if (newSlots.isNotEmpty) {
      _slots.insertAll(slotIndex + 1, newSlots);
      _updateSlotIndices(slotIndex + 1);
    }

    _totalSlots = _slots.length;
  }

  /// Expands a slot in on-demand mode by inserting descendant locations.
  void _expandSlotOnDemand(int slotIndex, Node<T> node) {
    final loc = _slotLocations[slotIndex];
    final depth = loc.depth;

    // Build locations for descendants
    final newLocs = <_SlotLocation<T>>[];
    _buildLocationsForExpand(node, depth + 1, newLocs);

    if (newLocs.isNotEmpty) {
      _slotLocations.insertAll(slotIndex + 1, newLocs);
    }

    _totalSlots = _slotLocations.length;
  }

  /// Finds slot index by group ID in prebuilt slots.
  /// O(n) but cached nodes help.
  int _findSlotIndex(String groupId) {
    for (var i = 0; i < _slots.length; i++) {
      final slot = _slots[i];
      if (slot is GroupHeaderSlot<T> && slot.groupId == groupId) {
        return i;
      }
    }
    return -1;
  }

  /// Finds slot index by group ID in on-demand mode.
  int _findSlotIndexOnDemand(String groupId) {
    for (var i = 0; i < _slotLocations.length; i++) {
      final loc = _slotLocations[i];
      if (loc.isHeader && loc.node.id == groupId) {
        return i;
      }
    }
    return -1;
  }

  /// Updates indices for all slots starting from [startIndex].
  ///
  /// Updates indices in-place without recreating slot objects.
  void _updateSlotIndices(int startIndex) {
    for (var i = startIndex; i < _slots.length; i++) {
      _slots[i].index = i;
    }
  }

  /// Builds slots for an expanding node's descendants.
  void _buildSlotsForExpand(
    Node<T> node,
    int depth,
    List<Slot<T>> result,
    int Function() nextIndex,
  ) {
    // Add child groups first (folders before files)
    for (final child in node.children) {
      _nodeCache[child.id] = child;
      result.add(
        GroupHeaderSlot<T>(
          index: nextIndex(),
          depth: depth,
          node: child,
          isCollapsed: child.isCollapsed,
          itemCount: child.length,
          totalCount: child.flattenedLength,
          groupOptionId: _extractGroupOptionId(child),
          aggregates: _computeAggregates(child),
        ),
      );

      // Recurse if not collapsed
      if (!child.isCollapsed) {
        _buildSlotsForExpand(child, depth + 1, result, nextIndex);
      }
    }

    // Add items (files after folders)
    for (final item in node) {
      if (_passesFilter(item)) {
        result.add(
          ItemSlot<T>(
            index: nextIndex(),
            depth: depth,
            key: node.keyOf(item),
            item: item,
          ),
        );
      }
    }
  }

  /// Builds locations for an expanding node's descendants (on-demand mode).
  void _buildLocationsForExpand(
    Node<T> node,
    int depth,
    List<_SlotLocation<T>> result,
  ) {
    for (final child in node.children) {
      _nodeCache[child.id] = child;
      result.add(_SlotLocation<T>.header(child, depth));

      if (!child.isCollapsed) {
        _buildLocationsForExpand(child, depth + 1, result);
      }
    }

    var itemIndex = 0;
    for (final item in node) {
      if (_passesFilter(item)) {
        result.add(_SlotLocation<T>.item(node, itemIndex, depth));
      }
      itemIndex++;
    }
  }

  /// Collapses all groups to a given depth level.
  ///
  /// - Level 0: Only root expanded
  /// - Level 1: Root and first-level groups expanded
  void collapseToLevel(int level) {
    if (_isDisposed) return;
    controller.root.collapseToLevel(level);
    _rebuild();
    notifyChanged();
  }

  /// Expands all groups.
  void expandAll() {
    if (_isDisposed) return;
    controller.root.expandAll();
    _rebuild();
    notifyChanged();
  }

  /// Collapses all groups.
  void collapseAll() {
    if (_isDisposed) return;
    controller.root.collapseAll();
    _rebuild();
    notifyChanged();
  }

  /// Collapses groups matching the predicate.
  ///
  /// The predicate receives a [GroupInfo] containing:
  /// - [GroupInfo.node] - The group node
  /// - [GroupInfo.depth] - Nesting depth (0 = top level)
  /// - [GroupInfo.itemCount] - Direct items in this group
  /// - [GroupInfo.totalCount] - Total items including nested groups
  ///
  /// {@tool snippet}
  /// Collapse all groups at level 3+:
  ///
  /// ```dart
  /// slotManager.collapseWhere((info) => info.depth >= 3);
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// Collapse groups with less than 5 items:
  ///
  /// ```dart
  /// slotManager.collapseWhere((info) => info.itemCount < 5);
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// Collapse specific group IDs:
  ///
  /// ```dart
  /// slotManager.collapseWhere((info) => info.node.id.contains('archived'));
  /// ```
  /// {@end-tool}
  void collapseWhere(bool Function(GroupInfo<T> info) predicate) {
    if (_isDisposed) return;
    _applyCollapseWhere(controller.root, predicate, 0, collapse: true);
    _rebuild();
    notifyChanged();
  }

  /// Expands groups matching the predicate.
  ///
  /// See [collapseWhere] for predicate details.
  ///
  /// {@tool snippet}
  /// Expand only top-level groups:
  ///
  /// ```dart
  /// slotManager.expandWhere((info) => info.depth == 0);
  /// ```
  /// {@end-tool}
  void expandWhere(bool Function(GroupInfo<T> info) predicate) {
    if (_isDisposed) return;
    _applyCollapseWhere(controller.root, predicate, 0, collapse: false);
    _rebuild();
    notifyChanged();
  }

  void _applyCollapseWhere(
    Node<T> node,
    bool Function(GroupInfo<T> info) predicate,
    int depth, {
    required bool collapse,
  }) {
    for (final child in node.children) {
      final info = GroupInfo<T>(
        node: child,
        depth: depth,
        itemCount: child.length,
        totalCount: child.flattenedLength,
      );

      if (predicate(info)) {
        child.collapse(state: collapse ? Tristate.yes : Tristate.no);
      }

      // Recurse into children
      _applyCollapseWhere(child, predicate, depth + 1, collapse: collapse);
    }
  }

  /// Forces a rebuild of the slot cache.
  ///
  /// Normally rebuilds happen automatically when the controller changes.
  /// Use this if you need to force a rebuild after external changes.
  void rebuild() {
    if (_isDisposed) return;
    _rebuild();
    notifyChanged();
  }

  /// Releases resources.
  @override
  void dispose() {
    _isDisposed = true;
    controller.removeChangeListener(_onControllerChanged);
    aggregations?.removeChangeListener(_onAggregationsChanged);
    _nodeCache.clear();
    _slots.clear();
    _slotLocations.clear();
    _uniqueKeys?.clear();
    _uniqueKeys = null;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internal Implementation
  // ---------------------------------------------------------------------------

  void _onControllerChanged() {
    if (_isDisposed) return;
    _rebuild();
    notifyChanged();
  }

  void _onAggregationsChanged() {
    if (_isDisposed) return;
    _rebuild();
    notifyChanged();
  }

  void _rebuild() {
    _nodeCache.clear();
    _slots.clear();
    _slotLocations.clear();
    _uniqueKeysDirty = true; // Mark for lazy recomputation

    // Cache filter state to avoid repeated isEmpty checks
    final filter = controller.filter;
    _hasActiveFilter = filter != null && filter.isNotEmpty;

    if (usePrebuiltSlots) {
      _buildCache(controller.root, 0);
      _totalSlots = _slots.length;
    } else {
      _buildLocations(controller.root, 0);
      _totalSlots = _slotLocations.length;
    }
    _version++;
  }

  /// Builds both the group cache and flat slot array.
  void _buildCache(Node<T> node, int depth) {
    // Check if this is a group node (has a parent, so not root)
    final isGroupNode = node.hasParent;

    if (isGroupNode) {
      // Cache node for O(1) lookup
      _nodeCache[node.id] = node;

      // Add header slot with node's built-in counts and aggregates
      _slots.add(
        GroupHeaderSlot<T>(
          index: _slots.length,
          depth: depth,
          node: node,
          isCollapsed: node.isCollapsed,
          itemCount: node.length,
          totalCount: node.flattenedLength,
          groupOptionId: _extractGroupOptionId(node),
          aggregates: _computeAggregates(node),
        ),
      );

      // If collapsed, skip children
      if (node.isCollapsed) return;
    }

    // For group nodes, children are one level deeper
    // For root, children stay at current depth
    final childDepth = isGroupNode ? depth + 1 : depth;

    // Process child groups first (folders before files)
    for (final child in node.children) {
      _buildCache(child, childDepth);
    }

    // Then add direct items to flat array (files after folders)
    for (final item in node) {
      if (_passesFilter(item)) {
        _slots.add(
          ItemSlot<T>(
            index: _slots.length,
            depth: childDepth,
            key: node.keyOf(item),
            item: item,
          ),
        );
      }
    }
  }

  /// Builds flat location array for on-demand slot creation.
  void _buildLocations(Node<T> node, int depth) {
    final isGroupNode = node.hasParent;

    if (isGroupNode) {
      _nodeCache[node.id] = node;
      _slotLocations.add(_SlotLocation<T>.header(node, depth));

      if (node.isCollapsed) return;
    }

    final childDepth = isGroupNode ? depth + 1 : depth;

    for (final child in node.children) {
      _buildLocations(child, childDepth);
    }

    var itemIndex = 0;
    for (final item in node) {
      if (_passesFilter(item)) {
        _slotLocations.add(_SlotLocation<T>.item(node, itemIndex, childDepth));
      }
      itemIndex++;
    }
  }

  /// Finds the index of a key in the flattened view.
  bool _findKeyIndex(
    Node<T> node,
    String key,
    int depth,
    void Function(int) onFound,
  ) {
    final counter = _Counter();
    final foundIndex = _findKeyIndexImpl(node, key, depth, counter);
    if (foundIndex != null) {
      onFound(foundIndex);
      return true;
    }
    return false;
  }

  /// Returns the found index, or null if not found.
  int? _findKeyIndexImpl(
    Node<T> node,
    String key,
    int depth,
    _Counter counter,
  ) {
    final isGroupNode = node.hasParent;

    if (isGroupNode) {
      // Skip group header slot
      counter.value++;
    }

    if (node.isCollapsed && isGroupNode) {
      return null;
    }

    // Search children first (folders before files - matches _buildCache order)
    for (final child in node.children) {
      final found = _findKeyIndexImpl(child, key, depth + 1, counter);
      if (found != null) {
        return found;
      }
    }

    // Then search items
    for (final item in node) {
      if (_passesFilter(item)) {
        if (node.keyOf(item) == key) {
          return counter.value;
        }
        counter.value++;
      }
    }

    return null;
  }

  /// Finds a node by ID using recursive search.
  Node<T>? _findNode(Node<T> node, String id) {
    if (node.id == id) return node;
    for (final child in node.children) {
      final result = _findNode(child, id);
      if (result != null) return result;
    }
    return null;
  }

  /// Checks if an item passes the current filter.
  bool _passesFilter(T item) {
    if (!_hasActiveFilter) return true;
    return controller.filter!.apply(item);
  }

  /// Computes aggregates for a group node.
  ///
  /// Returns null if no aggregations are configured.
  AggregateResult? _computeAggregates(Node<T> node) {
    final agg = aggregations;
    if (agg == null || agg.isEmpty) return null;

    // Collect all items in this group (flattened)
    final items = node.flattenedItems.toList();
    return agg.aggregate(items);
  }
}

// =============================================================================
// Private Helper Classes
// =============================================================================

/// Lightweight reference to a slot's location for on-demand slot creation.
///
/// Used when [SlotManager.usePrebuiltSlots] is false.
class _SlotLocation<T> {
  /// Creates a reference to an item slot.
  _SlotLocation.item(this.node, this.itemIndex, this.depth);

  /// Creates a reference to a group header slot.
  _SlotLocation.header(this.node, this.depth) : itemIndex = -1;

  /// The node containing this slot.
  final Node<T> node;

  /// Index in node's item list, or -1 for group headers.
  final int itemIndex;

  /// Depth in the tree.
  final int depth;

  /// Whether this is a group header.
  @pragma('vm:prefer-inline')
  bool get isHeader => itemIndex == -1;
}

/// Mutable counter for tree traversal.
class _Counter {
  /// Current counter value.
  int value = 0;
}
