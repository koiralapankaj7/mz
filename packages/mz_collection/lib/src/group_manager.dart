// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

// GroupOption uses == and hashCode for identity by ID in collections.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

/// {@template mz_collection.group_manager_library}
/// A pure Dart grouping system for hierarchical data organization.
///
/// ## Why GroupManager?
///
/// Traditional grouping approaches fall short when applications need:
///
/// - **Nested grouping** - Group by category, then by status, then by date
///   (hierarchical levels)
/// - **Dynamic reordering** - Change grouping hierarchy at runtime by
///   adjusting order values
/// - **Independent reactivity** - Each group option notifies its own
///   listeners without coupling to a specific state management solution
/// - **Framework independence** - Grouping logic that works in Flutter, CLI
///   tools, servers, or any Dart environment
///
/// GroupManager combines what typically requires separate grouping,
/// hierarchy management, and state management packages into a unified
/// solution.
///
/// ## Key Features
///
/// ```text
/// ┌───────────────────────────┬──────────────────────────────────────┐
/// │          Feature          │            Description               │
/// ├───────────────────────────┼──────────────────────────────────────┤
/// │ Nested grouping levels    │ order property defines hierarchy     │
/// │ Dynamic hierarchy         │ Reorder levels at runtime            │
/// │ Pure Dart Listenable      │ No Flutter dependency required       │
/// │ Type-safe extractors      │ GroupIdentifier<T, GroupBy> per opt  │
/// │ Collapsible/selectable    │ Per-option collapse and select state │
/// │ Sort integration          │ Optional SortOption per group        │
/// └───────────────────────────┴──────────────────────────────────────┘
/// ```
///
/// ## System Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────────┐
/// │                       GroupManager<T>                             │
/// │                                                                   │
/// │  ┌─────────────────────────────────────────────────────────────┐  │
/// │  │                    Option Registry                          │  │
/// │  │           (ordered by GroupOption.order)                    │  │
/// │  │                                                             │  │
/// │  │  order: 0           order: 1           order: 2             │  │
/// │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │  │
/// │  │  │ GroupOption  │  │ GroupOption  │  │ GroupOption  │       │  │
/// │  │  │ id: category │→ │ id: status   │→ │ id: priority │       │  │
/// │  │  │ (Level 1)    │  │ (Level 2)    │  │ (Level 3)    │       │  │
/// │  │  └──────────────┘  └──────────────┘  └──────────────┘       │  │
/// │  └─────────────────────────────────────────────────────────────┘  │
/// │                                                                   │
/// │  Result: Category → Status → Priority → Items (leaves)           │
/// └───────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Hierarchical Grouping Concept
///
/// The `order` property defines **nesting depth**, not just priority:
///
/// ```text
///                    Root (order: -1)
///                         │
///         ┌───────────────┼───────────────┐
///         ▼               ▼               ▼
///     Category A      Category B      Category C    ← order: 0
///         │               │               │
///     ┌───┴───┐       ┌───┴───┐       ┌───┴───┐
///     ▼       ▼       ▼       ▼       ▼       ▼
///   Open   Closed   Open   Closed   Open   Closed   ← order: 1
///     │       │       │       │       │       │
///     ▼       ▼       ▼       ▼       ▼       ▼
///   Items   Items   Items   Items   Items   Items   ← leaf nodes
/// ```
///
/// Swapping orders redefines the hierarchy:
///
/// ```text
/// // Before: Group by Category (0) → Status (1)
/// categoryOption.order = 0;
/// statusOption.order = 1;
///
/// // After: Group by Status (0) → Category (1)
/// statusOption.order = 0;
/// categoryOption.order = 1;
/// ```
///
/// ## Quick Start
///
/// {@tool snippet}
/// Basic grouping setup:
///
/// ```dart
/// // Define how to extract group values from items
/// final categoryGroup = GroupOption<Ticket, String>(
///   id: 'category',
///   label: 'Category',
///   valueBuilder: (ticket) => ticket.category,
///   order: 0,  // Outermost grouping level
/// );
///
/// final statusGroup = GroupOption<Ticket, Status>(
///   id: 'status',
///   label: 'Status',
///   valueBuilder: (ticket) => ticket.status,
///   order: 1,  // Nested inside category
/// );
///
/// // Create manager with options
/// final groupManager = GroupManager<Ticket>(
///   options: [categoryGroup, statusGroup],
/// );
///
/// // Options are automatically sorted by order
/// for (final option in groupManager.options) {
///   print('${option.id}: order ${option.order}');
/// }
/// // Output: category: order 0, status: order 1
/// ```
/// {@end-tool}
///
/// {@tool snippet}
/// Dynamic hierarchy reordering:
///
/// ```dart
/// // Swap grouping levels
/// categoryGroup.order = 1;  // Now nested
/// statusGroup.order = 0;    // Now outermost
///
/// // GroupManager automatically re-sorts on order changes
/// // Listeners are notified of the change
/// ```
/// {@end-tool}
///
/// {@tool snippet}
/// Custom key generation:
///
/// ```dart
/// final dateGroup = GroupOption<Ticket, DateTime>(
///   id: 'date',
///   label: 'Date',
///   valueBuilder: (ticket) => ticket.createdAt,
///   // Custom key for grouping (e.g., by month)
///   keyBuilder: (date) =>
///       '${date.year}-${date.month.toString().padLeft(2, '0')}',
///   order: 0,
/// );
///
/// // Tickets created in January 2024 all get key '2024-01'
/// ```
/// {@end-tool}
///
/// ## Component Reference
///
/// The library provides these main components:
///
/// | Component | Purpose |
/// |-----------|---------|
/// | [GroupManager] | Registry and coordinator for [GroupOption]s |
/// | [GroupOption] | Defines a single grouping criterion |
/// | [GroupIdentifier] | Function type for value extraction |
/// | [Listenable] | Pure Dart change notification mixin |
///
/// ## Usage with Collections
///
/// GroupManager defines **how** items should be grouped, but the actual
/// tree structure creation is handled by collection implementations:
///
/// ```dart
/// // GroupManager defines the grouping rules
/// final manager = GroupManager<Item>(options: [...]);
///
/// // Collection uses manager to build tree structure
/// for (final item in items) {
///   final groupKey = manager.options.first.groupKeyFor(item);
///   // Use groupKey to place item in appropriate group
/// }
/// ```
///
/// See also:
///
/// * [GroupOption] - Individual grouping configuration.
/// * [GroupIdentifier] - Type alias for value extraction functions.
/// {@endtemplate}
library;

import 'package:meta/meta.dart';

import 'core.dart';
import 'sort_manager.dart' show SortOption;

/// {@template mz_collection.group_by_string}
/// A [GroupOption] that groups items by a [String] value.
///
/// Convenience type for the common case of grouping by string properties
/// like names, categories, or identifiers.
///
/// {@tool snippet}
/// ```dart
/// final categoryGroup = GroupByString<Ticket>(
///   id: 'category',
///   valueBuilder: (ticket) => ticket.category,
/// );
/// ```
/// {@end-tool}
/// {@endtemplate}
typedef GroupByString<T> = GroupOption<T, String>;

/// {@template mz_collection.group_by_int}
/// A [GroupOption] that groups items by an [int] value.
///
/// Used for grouping by numeric identifiers, counts, or priorities.
///
/// {@tool snippet}
/// ```dart
/// final priorityGroup = GroupByInt<Task>(
///   id: 'priority',
///   valueBuilder: (task) => task.priorityLevel,
/// );
/// ```
/// {@end-tool}
/// {@endtemplate}
typedef GroupByInt<T> = GroupOption<T, int>;

/// {@template mz_collection.group_by_double}
/// A [GroupOption] that groups items by a [double] value.
///
/// Used for grouping by floating-point values like prices or ratings.
///
/// {@tool snippet}
/// ```dart
/// final priceGroup = GroupByDouble<Product>(
///   id: 'price',
///   valueBuilder: (product) => product.price,
///   keyBuilder: (price) => '${(price / 100).floor() * 100}-${(price / 100).floor() * 100 + 99}',
/// );
/// ```
/// {@end-tool}
/// {@endtemplate}
typedef GroupByDouble<T> = GroupOption<T, double>;

/// {@template mz_collection.group_by_bool}
/// A [GroupOption] that groups items by a [bool] value.
///
/// Used for binary grouping like active/inactive or completed/pending.
///
/// {@tool snippet}
/// ```dart
/// final completedGroup = GroupByBool<Task>(
///   id: 'completed',
///   valueBuilder: (task) => task.isCompleted,
/// );
/// ```
/// {@end-tool}
/// {@endtemplate}
typedef GroupByBool<T> = GroupOption<T, bool>;

/// {@template mz_collection.group_by_date}
/// A [GroupOption] that groups items by a [DateTime] value.
///
/// Used for grouping by dates or timestamps. Typically combined with
/// a `keyBuilder` to group by day, week, month, etc.
///
/// {@tool snippet}
/// ```dart
/// final dateGroup = GroupByDate<Event>(
///   id: 'date',
///   valueBuilder: (event) => event.scheduledAt,
///   keyBuilder: (date) => '${date.year}-${date.month}',  // Group by month
/// );
/// ```
/// {@end-tool}
/// {@endtemplate}
typedef GroupByDate<T> = GroupOption<T, DateTime>;

/// {@template mz_collection.group_identifier}
/// Extracts a grouping value of type [GroupBy] from an item of type [T].
///
/// This function determines which group an item belongs to by extracting
/// the relevant value. Items with the same extracted value are grouped
/// together.
///
/// ## Example
///
/// ```dart
/// // Group tickets by their status
/// GroupIdentifier<Ticket, Status> byStatus = (ticket) => ticket.status;
///
/// // Group products by category name
/// GroupIdentifier<Product, String> byCategory = (p) => p.category.name;
/// ```
///
/// Returns `null` to indicate the item should remain at the parent level
/// (folder-like behavior where items can exist at any grouping level).
///
/// See also:
///
/// * [GroupOption.valueBuilder] - Uses this type for value extraction.
/// {@endtemplate}
typedef GroupIdentifier<T, GroupBy> = GroupBy? Function(T item);

/// {@template mz_collection.multi_group_identifier}
/// Extracts multiple grouping values of type [GroupBy] from an item of type
/// [T].
///
/// This function determines which groups an item belongs to by extracting
/// multiple values. The same item can appear in multiple groups when each
/// extracted value maps to a different group.
///
/// ## Example
///
/// ```dart
/// // Group emails by their labels (item appears in multiple groups)
/// MultiGroupIdentifier<Email, String> byLabels = (email) => email.labels;
///
/// // Group products by their tags
/// MultiGroupIdentifier<Product, String> byTags = (p) => p.tags;
/// ```
///
/// Returns `null` or an empty iterable to indicate the item should remain at
/// the parent level (folder-like behavior).
///
/// See also:
///
/// * [GroupOption.multi] - Constructor that uses this type for multi-value
///   grouping.
/// * [GroupIdentifier] - Single-value grouping alternative.
/// {@endtemplate}
typedef MultiGroupIdentifier<T, GroupBy> = Iterable<GroupBy>? Function(T item);

// ════════════════════════════════════════════════════════════════════════════
// GroupOption
// ════════════════════════════════════════════════════════════════════════════

/// {@template mz_collection.group_option}
/// Defines a single grouping criterion for organizing items hierarchically.
///
/// A [GroupOption] specifies:
/// - **What** to group by (`valueBuilder`)
/// - **How** to generate group keys (`keyBuilder`)
/// - **Where** in the hierarchy ([order])
/// - **Behavior** options (collapsible, selectable)
///
/// ## Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────┐
/// │                  GroupOption<Ticket, Status>                  │
/// │                                                               │
/// │  id: 'status'              label: 'Status'                    │
/// │  order: 1                  enabled: true                      │
/// │                                                               │
/// │  ┌─────────────────────────────────────────────────────────┐  │
/// │  │              valueBuilder: (ticket) => ...              │  │
/// │  │                                                         │  │
/// │  │  Ticket(status: open)     →  Status.open                │  │
/// │  │  Ticket(status: closed)   →  Status.closed              │  │
/// │  └─────────────────────────────────────────────────────────┘  │
/// │                            │                                  │
/// │                      groupKeyFor(ticket)                      │
/// │                            │                                  │
/// │                            ▼                                  │
/// │  ┌─────────────────────────────────────────────────────────┐  │
/// │  │              keyBuilder?.call(value)                    │  │
/// │  │                    or                                   │  │
/// │  │              value.toString()                           │  │
/// │  └─────────────────────────────────────────────────────────┘  │
/// │                            │                                  │
/// │                            ▼                                  │
/// │                     'Status.open'                             │
/// └───────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Order and Hierarchy
///
/// The [order] property defines nesting depth in the group hierarchy:
///
/// ```text
///   order: 0  →  Outermost grouping level (closest to root)
///   order: 1  →  Nested inside order 0
///   order: 2  →  Nested inside order 1
///   ...
/// ```
///
/// Changing [order] values redefines the entire hierarchy structure:
///
/// ```text
/// // Initial: Category → Status
/// categoryOption.order = 0;  // [Category]
/// statusOption.order = 1;    //    └─ [Status]
///                            //          └─ items
///
/// // After swap: Status → Category
/// statusOption.order = 0;    // [Status]
/// categoryOption.order = 1;  //    └─ [Category]
///                            //          └─ items
/// ```
///
/// ## Group Keys
///
/// The [groupKeyFor] method determines which group an item belongs to:
///
/// 1. Extract value using `valueBuilder`
/// 2. Convert to key using `keyBuilder` (or `toString()` if null)
/// 3. Return key (or null if item shouldn't be grouped at this level)
///
/// {@tool snippet}
/// Custom key generation for date grouping by month:
///
/// ```dart
/// final monthGroup = GroupOption<Event, DateTime>(
///   id: 'month',
///   valueBuilder: (event) => event.date,
///   keyBuilder: (date) {
///     final month = date.month.toString().padLeft(2, '0');
///     return '${date.year}-$month';
///   },
/// );
///
/// // Events from January 2024 get key '2024-01'
/// // Events from February 2024 get key '2024-02'
/// ```
/// {@end-tool}
///
/// ## Collapsible and Selectable Groups
///
/// Groups can be collapsed (hidden children) and selected:
///
/// ```dart
/// final option = GroupOption<Item, String>(
///   id: 'category',
///   valueBuilder: (item) => item.category,
///   collapsible: true,   // Groups can be collapsed
///   selectable: true,    // Groups can be selected
///   collapsed: false,    // Initial collapse state
///   selected: false,     // Initial selection state
/// );
/// ```
///
/// ## Sort Integration
///
/// Groups can have an associated [SortOption] for ordering within
/// the group:
///
/// ```dart
/// final sortByName = SortOption<Category, String>.value(
///   id: 'name',
///   sortBy: (cat) => cat.name,
/// );
///
/// final categoryGroup = GroupOption<Item, Category>(
///   id: 'category',
///   valueBuilder: (item) => item.category,
///   sortOption: sortByName,  // Sort groups alphabetically
/// );
/// ```
///
/// See also:
///
/// * [GroupManager] - Manages multiple [GroupOption]s.
/// * [GroupIdentifier] - Function type for value extraction.
/// * [SortOption] - Can be associated for group ordering.
/// {@endtemplate}
class GroupOption<T, GroupBy> with Listenable {
  /// Creates a grouping option for single-value grouping.
  ///
  /// Each item belongs to exactly one group at this level, determined by
  /// the [valueBuilder] function.
  ///
  /// The [id] must be unique within a [GroupManager].
  /// The [valueBuilder] extracts the grouping value from items.
  ///
  /// Optional parameters:
  /// - [label] - Human-readable name for UI display
  /// - [keyBuilder] - Custom key generation (defaults to `toString()`)
  /// - [order] - Hierarchy level (lower = outer, default 0)
  /// - [enabled] - Whether this grouping is active (default true)
  /// - [collapsible] - Whether groups can be collapsed (default true)
  /// - [selectable] - Whether groups can be selected (default true)
  /// - [collapsed] - Initial collapse state (default false)
  /// - [selected] - Initial selection state (default false)
  /// - [sortOption] - Optional sort for ordering groups
  /// - [extra] - Additional metadata for custom use
  ///
  /// For items that should appear in multiple groups, use [GroupOption.multi]
  /// instead.
  GroupOption({
    required this.id,
    required GroupIdentifier<T, GroupBy> valueBuilder,
    this.label = '',
    this.extra,
    this.selectable = true,
    this.collapsible = true,
    this.selected = false,
    this.collapsed = false,
    bool? enabled,
    int? order,
    String? Function(GroupBy value)? keyBuilder,
    SortOption<GroupBy, dynamic>? sortOption,
  })  : _valueBuilder = valueBuilder,
        _valuesBuilder = null,
        _sortOption = sortOption,
        _enabled = enabled ?? true,
        _order = order ?? 0,
        _keyBuilder = keyBuilder {
    sortOption?.addChangeListener(notifyChanged);
  }

  /// Creates a grouping option for multi-value grouping.
  ///
  /// Each item can belong to multiple groups at this level, determined by
  /// the [valuesBuilder] function which returns an iterable of group values.
  ///
  /// This is useful for scenarios like:
  /// - Email labels (an email can have multiple labels)
  /// - Product tags (a product can have multiple tags)
  /// - Category assignments (an item can be in multiple categories)
  ///
  /// The [id] must be unique within a [GroupManager].
  /// The [valuesBuilder] extracts multiple grouping values from items.
  ///
  /// Optional parameters are the same as the default constructor.
  ///
  /// Example:
  /// ```dart
  /// final tagsGroup = GroupOption<Product, String>.multi(
  ///   id: 'tags',
  ///   valuesBuilder: (product) => product.tags,
  ///   order: 0,
  /// );
  ///
  /// // A product with tags ['electronics', 'sale'] will appear
  /// // in both the 'electronics' group and the 'sale' group.
  /// ```
  GroupOption.multi({
    required this.id,
    required MultiGroupIdentifier<T, GroupBy> valuesBuilder,
    this.label = '',
    this.extra,
    this.selectable = true,
    this.collapsible = true,
    this.selected = false,
    this.collapsed = false,
    bool? enabled,
    int? order,
    String? Function(GroupBy value)? keyBuilder,
    SortOption<GroupBy, dynamic>? sortOption,
  })  : _valueBuilder = null,
        _valuesBuilder = valuesBuilder,
        _sortOption = sortOption,
        _enabled = enabled ?? true,
        _order = order ?? 0,
        _keyBuilder = keyBuilder {
    sortOption?.addChangeListener(notifyChanged);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Identity and Display
  // ──────────────────────────────────────────────────────────────────────────

  /// Unique identifier for this option within a [GroupManager].
  ///
  /// Used to look up, add, and remove options. Two options with the
  /// same [id] are considered equal regardless of other properties.
  final String id;

  /// Human-readable label for UI display.
  ///
  /// Defaults to empty string if not specified.
  final String label;

  /// Additional metadata for custom use.
  ///
  /// Can store any data needed by the application, such as icons,
  /// colors, or configuration objects.
  final dynamic extra;

  // ──────────────────────────────────────────────────────────────────────────
  // Grouping Configuration
  // ──────────────────────────────────────────────────────────────────────────

  /// The single-value builder (used when not multi-value).
  final GroupIdentifier<T, GroupBy>? _valueBuilder;

  /// The multi-value builder (used for multi-value grouping).
  final MultiGroupIdentifier<T, GroupBy>? _valuesBuilder;

  /// Extracts the grouping value from an item.
  ///
  /// This function determines which group an item belongs to.
  /// Items with the same extracted value are grouped together.
  ///
  /// Returns `null` to indicate the item should remain at the parent level
  /// instead of being grouped at this level. This enables folder-like behavior
  /// where items can exist at any level in the hierarchy.
  ///
  /// For multi-value grouping (created with [GroupOption.multi]), this returns
  /// the first value from `valuesBuilder`, or `null` if empty.
  ///
  /// Example:
  /// ```dart
  /// // Simple grouping - all items grouped by status
  /// valueBuilder: (ticket) => ticket.status,
  ///
  /// // Folder-like - only high priority items have assignee grouping
  /// valueBuilder: (task) => task.isHighPriority ? task.assignee : null,
  /// ```
  GroupIdentifier<T, GroupBy> get valueBuilder {
    if (_valueBuilder != null) return _valueBuilder;
    // For multi-value, return first value for backward compatibility
    return (item) {
      final values = _valuesBuilder?.call(item);
      if (values == null || values.isEmpty) return null;
      return values.first;
    };
  }

  /// Whether this option uses multi-value grouping.
  ///
  /// When `true`, items can appear in multiple groups at this level.
  /// Use [groupKeysFor] to get all group keys for an item.
  ///
  /// When `false`, items appear in at most one group at this level.
  /// Use [groupKeyFor] to get the single group key.
  bool get isMultiValue => _valuesBuilder != null;

  /// Optional custom key generator for group identification.
  ///
  /// If provided, converts the extracted [GroupBy] value into a string
  /// key used to identify groups. If null, `toString()` is used.
  ///
  /// Returning null from this function indicates the item should not
  /// be grouped at this level.
  final String? Function(GroupBy value)? _keyBuilder;

  /// Optional sort configuration for ordering groups.
  final SortOption<GroupBy, dynamic>? _sortOption;

  // ──────────────────────────────────────────────────────────────────────────
  // Behavior Flags
  // ──────────────────────────────────────────────────────────────────────────

  /// Whether groups at this level support selection.
  ///
  /// When true, groups can be selected/deselected. When false,
  /// selection operations on groups are no-ops.
  final bool selectable;

  /// Whether groups at this level can be collapsed.
  ///
  /// When true, groups can be collapsed to hide their children.
  /// When false, groups are always expanded.
  final bool collapsible;

  /// Initial selection state for new groups.
  ///
  /// Only applies when [selectable] is true.
  final bool selected;

  /// Initial collapse state for new groups.
  ///
  /// Only applies when [collapsible] is true.
  final bool collapsed;

  // ──────────────────────────────────────────────────────────────────────────
  // Mutable State
  // ──────────────────────────────────────────────────────────────────────────

  bool _enabled;
  int _order;

  // ──────────────────────────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────────────────────────

  /// The sort option for ordering groups at this level.
  ///
  /// Returns null if no sort is configured.
  SortOption<GroupBy, dynamic>? get sortOption => _sortOption;

  /// Generates the group key for an item (single-value grouping).
  ///
  /// Returns the string key that identifies which group the item
  /// belongs to at this level.
  ///
  /// Returns `null` if the item should remain at the parent level instead
  /// of being grouped. This enables folder-like behavior where items can
  /// exist at any level in the hierarchy, similar to files in folders.
  ///
  /// The key is generated by:
  /// 1. Extracting the value using `valueBuilder` (null = stay at parent)
  /// 2. Converting to string using `keyBuilder` or `toString()`
  ///
  /// For multi-value grouping, use [groupKeysFor] instead to get all keys.
  ///
  /// Example:
  /// ```dart
  /// final ticket = Ticket(status: Status.open);
  /// final key = statusOption.groupKeyFor(ticket);
  /// print(key); // 'Status.open' or custom key, null if no grouping
  /// ```
  String? groupKeyFor(T item) {
    final value = valueBuilder(item);
    // Null value indicates item stays at parent level (folder-like behavior)
    if (value == null) return null;
    if (_keyBuilder != null) return _keyBuilder(value);
    return value.toString();
  }

  /// Generates all group keys for an item (multi-value grouping).
  ///
  /// Returns a list of string keys identifying all groups the item
  /// belongs to at this level. An item can appear in multiple groups
  /// when using [GroupOption.multi].
  ///
  /// Returns an empty list if the item should remain at the parent level
  /// (folder-like behavior).
  ///
  /// For single-value grouping, this returns a single-element list
  /// containing the result of [groupKeyFor], or empty if null.
  ///
  /// Example:
  /// ```dart
  /// // Multi-value grouping by tags
  /// final product = Product(tags: ['electronics', 'sale']);
  /// final keys = tagsOption.groupKeysFor(product);
  /// print(keys); // ['electronics', 'sale']
  ///
  /// // Product appears in both 'electronics' and 'sale' groups
  /// ```
  List<String> groupKeysFor(T item) {
    if (_valuesBuilder != null) {
      // Multi-value grouping - build list directly (avoid lazy iterables)
      final values = _valuesBuilder(item);
      if (values == null) return const [];
      final result = <String>[];
      for (final value in values) {
        final key = _keyBuilder != null ? _keyBuilder(value) : value.toString();
        if (key != null) result.add(key);
      }
      return result;
    } else {
      // Single-value grouping - wrap in list
      final key = groupKeyFor(item);
      if (key == null) return const [];
      return [key];
    }
  }

  /// Whether this grouping option is active.
  ///
  /// When false, items bypass this grouping level.
  /// Changing this value notifies listeners.
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyChanged();
  }

  /// The hierarchy level for this grouping option.
  ///
  /// Lower values mean outer (closer to root) grouping levels.
  /// Higher values are nested deeper in the hierarchy.
  ///
  /// Changing order triggers a re-sort in [GroupManager] and
  /// rebuilds the group hierarchy.
  int get order => _order;
  set order(int value) {
    if (_order == value) return;
    _order = value;
    notifyChanged();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Equality - based on id for lookup in collections
  // ──────────────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroupOption<T, GroupBy> && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    final parts = <String>[
      if (id.isNotEmpty) 'id: $id',
      if (label.isNotEmpty) 'label: $label',
      'order: $_order',
      if (!_enabled) 'enabled: false',
      if (selectable) 'selectable',
      if (collapsible) 'collapsible',
      if (selected) 'selected',
      if (collapsed) 'collapsed',
      if (_sortOption != null) 'sortOption: $_sortOption',
    ];
    return 'GroupOption(${parts.join(', ')})';
  }

  @override
  void dispose() {
    _sortOption?.removeChangeListener(notifyChanged);
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// GroupManager
// ════════════════════════════════════════════════════════════════════════════

/// {@template mz_collection.group_manager}
/// Manages a collection of [GroupOption]s for hierarchical data organization.
///
/// [GroupManager] is the central coordinator for grouping configuration:
///
/// - **Registry**: Stores and manages [GroupOption] instances by ID
/// - **Ordering**: Maintains options sorted by [GroupOption.order]
/// - **Change notification**: Notifies listeners when options change
/// - **Lifecycle**: Properly disposes options and cleans up listeners
///
/// ## Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────────┐
/// │                       GroupManager<Ticket>                        │
/// │                                                                   │
/// │  ┌─────────────────────────────────────────────────────────────┐  │
/// │  │                    _options (Map by ID)                     │  │
/// │  │                                                             │  │
/// │  │  'category' → GroupOption(order: 0, ...)                    │  │
/// │  │  'status'   → GroupOption(order: 1, ...)                    │  │
/// │  │  'priority' → GroupOption(order: 2, ...)                    │  │
/// │  └─────────────────────────────────────────────────────────────┘  │
/// │                            │                                      │
/// │                     options getter                                │
/// │                            │                                      │
/// │                            ▼                                      │
/// │  ┌─────────────────────────────────────────────────────────────┐  │
/// │  │              Sorted by order, filtered by enabled           │  │
/// │  │                                                             │  │
/// │  │  [category(0), status(1), priority(2)]                      │  │
/// │  └─────────────────────────────────────────────────────────────┘  │
/// └───────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Lifecycle Management
///
/// ```text
/// ┌─────────────┐    ┌─────────────────┐    ┌─────────────┐
/// │    add()    │ →  │ addChangeLstnr  │ →  │ _sort()     │
/// │             │    │   to option     │    │ notify()    │
/// └─────────────┘    └─────────────────┘    └─────────────┘
///
/// ┌─────────────┐    ┌─────────────────┐    ┌─────────────┐
/// │  remove()   │ →  │ rmChangeLstnr   │ →  │ notify()    │
/// │             │    │  from option    │    │             │
/// └─────────────┘    └─────────────────┘    └─────────────┘
///
/// ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
/// │  dispose()  │ →  │ rmListener  │ →  │ clear all   │
/// │             │    │ from all    │    │ super       │
/// └─────────────┘    └─────────────┘    └─────────────┘
/// ```
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Creating and using a GroupManager:
///
/// ```dart
/// // Create options
/// final categoryOption = GroupOption<Ticket, String>(
///   id: 'category',
///   valueBuilder: (t) => t.category,
///   order: 0,
/// );
///
/// final statusOption = GroupOption<Ticket, Status>(
///   id: 'status',
///   valueBuilder: (t) => t.status,
///   order: 1,
/// );
///
/// // Create manager with initial options
/// final manager = GroupManager<Ticket>(
///   options: [statusOption, categoryOption],  // Order doesn't matter
/// );
///
/// // Options are sorted by order property
/// print(manager.options.map((o) => o.id));
/// // Output: (category, status)
/// ```
/// {@end-tool}
///
/// ## Dynamic Modification
///
/// {@tool snippet}
/// Adding and removing options:
///
/// ```dart
/// // Add new option
/// final priorityOption = GroupOption<Ticket, int>(
///   id: 'priority',
///   valueBuilder: (t) => t.priority,
///   order: 2,
/// );
/// manager.add(priorityOption);
///
/// // Remove option by ID
/// final removed = manager.remove('priority');
///
/// // Replace existing option
/// final updatedCategory = GroupOption<Ticket, String>(
///   id: 'category',
///   valueBuilder: (t) => t.category.toUpperCase(),
///   order: 0,
/// );
/// manager.add(updatedCategory, replace: true);
/// ```
/// {@end-tool}
///
/// ## Listening for Changes
///
/// {@tool snippet}
/// Reacting to grouping changes:
///
/// ```dart
/// manager.addChangeListener(() {
///   print('Grouping configuration changed');
///   // Rebuild UI or re-process data
/// });
///
/// // Changes that trigger notifications:
/// manager.add(newOption);           // New option added
/// manager.remove('oldOption');      // Option removed
/// existingOption.order = 5;         // Order changed
/// existingOption.enabled = false;   // Enabled state changed
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [GroupOption] - Individual grouping configuration.
/// * [Listenable] - Change notification mixin.
/// {@endtemplate}
class GroupManager<T> with Listenable {
  /// Creates a group manager with optional initial options.
  ///
  /// Options are automatically sorted by their [GroupOption.order]
  /// property.
  ///
  /// Example:
  /// ```dart
  /// final manager = GroupManager<Ticket>(
  ///   options: [categoryOption, statusOption, priorityOption],
  /// );
  /// ```
  GroupManager({Iterable<GroupOption<T, dynamic>>? options}) {
    if (options == null) return;
    options.toList()
      ..sort((a, b) => a.order.compareTo(b.order))
      ..forEach(add);
  }

  final _options = <String, GroupOption<T, dynamic>>{};

  /// Re-sorts options by order after an order change.
  void _sort() {
    final sorted = _options.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    _options
      ..clear()
      ..addEntries(sorted.map((o) => MapEntry(o.id, o)));
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────────────────────────

  /// Adds or replaces a grouping option.
  ///
  /// Returns `true` if the option was added (or replaced).
  /// Returns `false` if the option already exists and [replace] is false.
  ///
  /// When [replace] is true:
  /// - Removes the existing option with the same ID
  /// - Adds the new option
  /// - Re-sorts and notifies listeners
  ///
  /// When [replace] is false:
  /// - Only adds if no option with the same ID exists
  ///
  /// Example:
  /// ```dart
  /// manager.add(categoryOption);  // Returns true (added)
  /// manager.add(categoryOption);  // Returns false (exists)
  /// manager.add(newCategory, replace: true);  // Returns true (replaced)
  /// ```
  bool add(GroupOption<T, dynamic> option, {bool replace = false}) {
    if (replace) {
      _options.remove(option.id)?.removeChangeListener(_optionListener);
      _options[option.id] = option..addChangeListener(_optionListener);
      _sort();
      notifyChanged();
      return true;
    }

    // Use containsKey check instead of putIfAbsent to avoid closure allocation
    if (_options.containsKey(option.id)) return false;

    _options[option.id] = option..addChangeListener(_optionListener);
    _sort();
    notifyChanged();
    return true;
  }

  /// Removes a grouping option by ID.
  ///
  /// Returns the removed option, or null if not found.
  ///
  /// The removed option's listener is detached and listeners
  /// are notified of the change.
  ///
  /// Example:
  /// ```dart
  /// final removed = manager.remove('category');
  /// if (removed != null) {
  ///   print('Removed: ${removed.label}');
  /// }
  /// ```
  GroupOption<T, dynamic>? remove(String id) {
    final result = _options.remove(id);
    if (result != null) {
      result.removeChangeListener(_optionListener);
      notifyChanged();
    }
    return result;
  }

  /// Removes all grouping options in a single batch.
  ///
  /// This is more efficient than calling [remove] for each option
  /// as it only triggers a single notification.
  ///
  /// Example:
  /// ```dart
  /// manager.clear();  // Single rebuild instead of N rebuilds
  /// ```
  void clear() {
    if (_options.isEmpty) return;
    for (final option in _options.values) {
      option.removeChangeListener(_optionListener);
    }
    _options.clear();
    notifyChanged();
  }

  /// All registered options including disabled ones.
  ///
  /// Options are ordered by their [GroupOption.order] property.
  Iterable<GroupOption<T, dynamic>> get allOptions => _options.values;

  /// Only enabled options, ordered by [GroupOption.order].
  ///
  /// Use this for actual grouping operations as it filters out
  /// disabled options.
  Iterable<GroupOption<T, dynamic>> get options =>
      allOptions.where((e) => e.enabled);

  /// Returns the option with the given [id], or null if not found.
  ///
  /// Example:
  /// ```dart
  /// final categoryOption = manager.optionById('category');
  /// if (categoryOption != null) {
  ///   categoryOption.enabled = false;
  /// }
  /// ```
  GroupOption<T, dynamic>? optionById(String id) => _options[id];

  /// Whether any grouping options are currently enabled.
  ///
  /// Returns true if at least one option has [GroupOption.enabled] true.
  bool get hasActiveGroups => options.isNotEmpty;

  /// The number of registered options (including disabled).
  int get length => _options.length;

  /// Whether no options are registered.
  bool get isEmpty => _options.isEmpty;

  /// Whether at least one option is registered.
  bool get isNotEmpty => _options.isNotEmpty;

  /// Reorders multiple options in a single batch operation.
  ///
  /// This is more efficient than setting individual [GroupOption.order]
  /// values, as it only triggers a single rebuild instead of one per change.
  ///
  /// The [orders] map contains option IDs as keys and new order values.
  ///
  /// Example:
  /// ```dart
  /// // Swap category and status grouping levels
  /// manager.reorder({
  ///   'category': 1,  // Was 0, now nested
  ///   'status': 0,    // Was 1, now outermost
  /// });
  /// // Only ONE rebuild instead of two!
  /// ```
  void reorder(Map<String, int> orders) {
    if (orders.isEmpty) return;

    var changed = false;
    for (final entry in orders.entries) {
      final option = _options[entry.key];
      if (option != null && option._order != entry.value) {
        option._order = entry.value;
        changed = true;
      }
    }

    if (changed) {
      _sort();
      notifyChanged();
    }
  }

  /// Handles changes from individual options.
  void _optionListener() {
    _sort();
    notifyChanged();
  }

  @override
  void dispose() {
    for (final option in _options.values) {
      option.removeChangeListener(_optionListener);
    }
    _options.clear();
    super.dispose();
  }

  // ===========================================================================
  // State Serialization
  // ===========================================================================

  /// Captures the current group state for serialization.
  ///
  /// Returns a [GroupSnapshot] containing all enabled group options and their
  /// orders that can be serialized to JSON or a query string for persistence,
  /// deep linking, or sharing.
  ///
  /// {@tool snippet}
  /// Capturing and restoring group state:
  ///
  /// ```dart
  /// // Capture current state
  /// final snapshot = manager.captureState();
  ///
  /// // Serialize to JSON for storage
  /// final json = snapshot.toJson();
  /// localStorage.setItem('groups', jsonEncode(json));
  ///
  /// // Or convert to URL query string
  /// final url = '/items?${snapshot.toQueryString()}';
  ///
  /// // Later, restore the state
  /// final savedJson = jsonDecode(localStorage.getItem('groups'));
  /// final restored = GroupSnapshot.fromJson(savedJson);
  /// manager.restoreState(restored);
  /// ```
  /// {@end-tool}
  GroupSnapshot captureState() {
    final activeIds = <String>[];
    final orders = <String, int>{};

    for (final option in options) {
      activeIds.add(option.id);
      orders[option.id] = option.order;
    }

    return GroupSnapshot._(activeIds, orders);
  }

  /// Restores group state from a [GroupSnapshot].
  ///
  /// Only restores state for options that exist in this manager.
  /// Options not in the snapshot are disabled.
  /// Option IDs in the snapshot that don't exist in this manager are ignored.
  ///
  /// {@tool snippet}
  /// Restoring group state from a URL:
  ///
  /// ```dart
  /// // From URL query string
  /// final snapshot = GroupSnapshot.fromQueryString(
  ///   Uri.parse(url).query,
  /// );
  /// manager.restoreState(snapshot);
  ///
  /// // From stored JSON
  /// final snapshot = GroupSnapshot.fromJson(savedJson);
  /// manager.restoreState(snapshot);
  /// ```
  /// {@end-tool}
  void restoreState(GroupSnapshot snapshot) {
    // Disable all options first
    for (final option in _options.values) {
      option._enabled = false;
    }

    // Enable and set order for options in snapshot
    for (final id in snapshot._activeIds) {
      final option = _options[id];
      if (option != null) {
        option._enabled = true;
        final order = snapshot._orders[id];
        if (order != null) {
          option._order = order;
        }
      }
    }

    _sort();
    notifyChanged();
  }
}

// =============================================================================
// Group Snapshot (Serialization)
// =============================================================================

/// {@template mz_collection.group_snapshot}
/// A serializable snapshot of group state.
///
/// Use this to persist group configuration, create shareable URLs, or restore
/// grouping setups.
///
/// ## JSON Serialization
///
/// {@tool snippet}
/// Serialize group state to JSON:
///
/// ```dart
/// final snapshot = manager.captureState();
///
/// // To JSON
/// final json = snapshot.toJson();
/// // Result: {'activeIds': ['category', 'status'], 'orders': {'category': 0, 'status': 1}}
///
/// // From JSON
/// final restored = GroupSnapshot.fromJson(json);
/// ```
/// {@end-tool}
///
/// ## URL Query String
///
/// {@tool snippet}
/// Serialize group state to URL query string:
///
/// ```dart
/// final snapshot = manager.captureState();
///
/// // To query string
/// final query = snapshot.toQueryString();
/// // Result: 'group=category,status'
///
/// // Build URL
/// final url = '/items?$query';
///
/// // From query string
/// final restored = GroupSnapshot.fromQueryString(query);
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [GroupManager.captureState] - Creates a snapshot from current state.
/// * [GroupManager.restoreState] - Restores state from a snapshot.
/// {@endtemplate}
class GroupSnapshot {
  const GroupSnapshot._(this._activeIds, this._orders);

  /// Creates an empty group snapshot.
  const GroupSnapshot.empty()
      : _activeIds = const [],
        _orders = const {};

  /// Creates a group snapshot from active IDs and their orders.
  factory GroupSnapshot.fromData({
    required List<String> activeIds,
    Map<String, int>? orders,
  }) {
    return GroupSnapshot._(
      List.unmodifiable(activeIds),
      Map.unmodifiable(orders ?? {}),
    );
  }

  /// Creates a snapshot from a JSON map.
  factory GroupSnapshot.fromJson(Map<String, dynamic> json) {
    final activeIdsList = json['activeIds'] as List<dynamic>?;
    final ordersMap = json['orders'] as Map<String, dynamic>?;

    if (activeIdsList == null || activeIdsList.isEmpty) {
      return const GroupSnapshot.empty();
    }

    final activeIds = activeIdsList.whereType<String>().toList();
    final orders = <String, int>{};
    if (ordersMap != null) {
      for (final entry in ordersMap.entries) {
        if (entry.value is int) {
          orders[entry.key] = entry.value as int;
        }
      }
    }

    return GroupSnapshot._(
      List.unmodifiable(activeIds),
      Map.unmodifiable(orders),
    );
  }

  /// Creates a snapshot from a URL query string.
  ///
  /// Parses the `group` parameter with comma-separated IDs.
  /// Order values are assigned based on position (0, 1, 2, ...).
  factory GroupSnapshot.fromQueryString(String queryString) {
    if (queryString.isEmpty) return const GroupSnapshot.empty();

    final params = Uri.splitQueryString(queryString);
    final groupValue = params['group'];
    if (groupValue == null || groupValue.isEmpty) {
      return const GroupSnapshot.empty();
    }

    final activeIds = groupValue.split(',').map(Uri.decodeComponent).toList();
    final orders = <String, int>{};
    for (var i = 0; i < activeIds.length; i++) {
      orders[activeIds[i]] = i;
    }

    return GroupSnapshot._(
      List.unmodifiable(activeIds),
      Map.unmodifiable(orders),
    );
  }

  final List<String> _activeIds;
  final Map<String, int> _orders;

  /// Returns the list of active group IDs in order.
  List<String> get activeIds => _activeIds;

  /// Returns the order map for group options.
  Map<String, int> get orders => _orders;

  /// Whether this snapshot has any active groups.
  bool get isEmpty => _activeIds.isEmpty;

  /// Whether this snapshot has active groups.
  bool get isNotEmpty => _activeIds.isNotEmpty;

  /// The number of active groups in this snapshot.
  int get length => _activeIds.length;

  /// Converts this snapshot to a JSON-serializable map.
  ///
  /// The resulting map can be encoded with `jsonEncode` and stored or
  /// transmitted.
  Map<String, dynamic> toJson() {
    return {
      'activeIds': _activeIds,
      'orders': _orders,
    };
  }

  /// Converts this snapshot to a URL query string.
  ///
  /// Format: `group={id1},{id2},{id3}`
  ///
  /// The order of IDs reflects the grouping hierarchy.
  /// Note: Individual order values are not included in the query string
  /// as the order is implicit from the position in the list.
  String toQueryString() {
    if (_activeIds.isEmpty) return '';

    final encodedIds = _activeIds.map(Uri.encodeComponent).join(',');
    return 'group=$encodedIds';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GroupSnapshot) return false;
    if (_activeIds.length != other._activeIds.length) return false;
    for (var i = 0; i < _activeIds.length; i++) {
      if (_activeIds[i] != other._activeIds[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_activeIds);

  @override
  String toString() => 'GroupSnapshot($_activeIds)';
}

// =============================================================================
// Group Criteria (Serializable)
// =============================================================================

/// {@template mz_collection.group_criteria}
/// A serializable group criterion for page requests.
///
/// Represents a grouping field's ID without coupling to the
/// `GroupOption` class.
///
/// ## Query Parameter Format
///
/// {@tool snippet}
/// Converting to query parameters:
///
/// ```dart
/// final criteria = GroupCriteria(id: 'category');
/// final params = criteria.toQueryParams();
/// // Result: {'group': 'category'}
/// ```
/// {@end-tool}
/// {@endtemplate}
@immutable
class GroupCriteria {
  /// Creates a group criterion.
  const GroupCriteria({required this.id});

  /// Creates a criterion from a JSON map.
  factory GroupCriteria.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'id': final String id} => GroupCriteria(id: id),
      _ => throw FormatException('Invalid GroupCriteria JSON: $json'),
    };
  }

  /// Creates a group criterion from query parameters.
  static GroupCriteria? fromQueryParams(Map<String, String> params) {
    final groupParam = params['group'];
    if (groupParam == null || groupParam.isEmpty) return null;
    return GroupCriteria(id: groupParam);
  }

  /// The group field identifier.
  final String id;

  /// Converts this criterion to query parameters.
  ///
  /// Format: `group=id`
  Map<String, String> toQueryParams() => {'group': id};

  /// Converts this criterion to a JSON-compatible map.
  Map<String, dynamic> toJson() => {'id': id};

  @override
  String toString() => 'GroupCriteria($id)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GroupCriteria && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
