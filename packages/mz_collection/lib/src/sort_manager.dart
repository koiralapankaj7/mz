// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

// SortOption and SortValue use == and hashCode for identity in collections.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

/// {@template mz_collection.sort_manager_library}
/// A pure Dart sorting system with multi-level sorting and composition.
///
/// ## Why SortManager?
///
/// Traditional sorting approaches fall short when applications need:
///
/// - **Multi-level sorting** - Sort by name, then by date, then by id
///   (priority chain)
/// - **Dynamic sort direction** - Toggle between ascending, descending,
///   and no sorting with tri-state support
/// - **Sort composition** - Combine sorts using ThenBy chains
/// - **Framework independence** - Sort logic that works in Flutter, CLI
///   tools, servers, or any Dart environment
///
/// SortManager combines what typically requires separate sorting and
/// state management packages into a unified solution.
///
/// ## Key Features
///
/// ```text
/// ┌───────────────────────────┬──────────────────────────────────────┐
/// │          Feature          │            Description               │
/// ├───────────────────────────┼──────────────────────────────────────┤
/// │ Multi-level sorting       │ Priority chain of sort options       │
/// │ SortOrder (asc/desc/none) │ Tri-state direction control          │
/// │ Sort composition          │ SortThenBy for chained sorting       │
/// │ Pure Dart Listenable      │ No Flutter dependency required       │
/// │ Type-safe comparators     │ SortOption<T, SortBy> per sort       │
/// │ API sort strings          │ 'name:asc,date:desc' for backends    │
/// └───────────────────────────┴──────────────────────────────────────┘
/// ```
///
/// ## System Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────────┐
/// │                        SortManager<T>                             │
/// │                                                                   │
/// │  ┌─────────────────────────────────────────────────────────────┐  │
/// │  │                     Sort Registry                           │  │
/// │  │                                                             │  │
/// │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │  │
/// │  │  │ SortOption   │  │ SortOption   │  │ SortOption   │       │  │
/// │  │  │  id: name    │  │ id: date     │  │ id: priority │       │  │
/// │  │  └──────────────┘  └──────────────┘  └──────────────┘       │  │
/// │  └─────────────────────────────────────────────────────────────┘  │
/// │                                                                   │
/// │  ┌─────────────────────────────────────────────────────────────┐  │
/// │  │                   Active Sort Chain                         │  │
/// │  │                                                             │  │
/// │  │  [0] name:asc  →  [1] date:desc  →  [2] priority:asc        │  │
/// │  │  (primary)        (secondary)        (tertiary)             │  │
/// │  └─────────────────────────────────────────────────────────────┘  │
/// │                              │                                    │
/// │                              ▼                                    │
/// │                   ┌─────────────────────┐                         │
/// │                   │  compare(T a, T b)  │ ← Applies full chain    │
/// │                   │  sortString getter  │   in priority order     │
/// │                   └─────────────────────┘                         │
/// └───────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Sort Evaluation Flow
///
/// ```text
///                    Items to compare (a, b)
///                              │
///                              ▼
///           ┌──────────────────────────────────────────┐
///           │        SortManager.compare(a, b)         │
///           │                                          │
///           │  _activeSorts.isEmpty? ──yes──► return 0 │
///           │         │                                │
///           │        no                                │
///           │         ▼                                │
///           │  ┌───────────────────────────────┐       │
///           │  │   For each sort in chain:     │       │
///           │  │                               │       │
///           │  │   result = sort.compare(a, b) │       │
///           │  │   if (result != 0) return it  │       │
///           │  │   else continue to next       │       │
///           │  └───────────────────────────────┘       │
///           └──────────────────────────────────────────┘
///                              │
///                              ▼
///                        -1 / 0 / 1
/// ```
///
/// ## Quick Start
///
/// {@tool snippet}
/// Basic sorting with single option:
///
/// ```dart
/// // Define sort options
/// final nameSort = SortOption<User, String>(
///   id: 'name',
///   label: 'Name',
///   sortBy: (user) => user.name,
/// );
///
/// // Create manager with options
/// final sortManager = SortManager<User>(
///   options: [nameSort, dateSort, prioritySort],
/// );
///
/// // Set active sort
/// sortManager.setCurrent(nameSort);
///
/// // Sort a list
/// users.sort(sortManager.compare);
/// ```
/// {@end-tool}
///
/// {@tool snippet}
/// Multi-level sorting (sort by name, then by date):
///
/// ```dart
/// final sortManager = SortManager<User>(
///   options: [nameSort, dateSort, prioritySort],
/// );
///
/// // Set primary sort
/// sortManager.setCurrent(nameSort);
///
/// // Add secondary sort
/// sortManager.add(dateSort, order: SortOrder.descending);
///
/// // Sort string for API: 'name:asc,date:desc'
/// final apiParam = sortManager.sortString;
///
/// // Compare function applies full chain
/// users.sort(sortManager.compare);
/// ```
/// {@end-tool}
///
/// {@tool snippet}
/// Toggle sort direction:
///
/// ```dart
/// // Tri-state toggle: ascending → descending → none → ascending
/// sortManager.toggleOrder();
///
/// // Two-state toggle: ascending ↔ descending
/// sortManager.toggleOrder(triState: false);
///
/// // Set specific order
/// sortManager.setOrder(SortOrder.descending);
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [SortOption] - Individual sort option with type-safe value extraction.
/// * [SortOrder] - Ascending, descending, or none.
/// * [SortManager] - Coordinates multiple sorts with priority chain.
/// * [Listenable] - Pure Dart change notification mixin.
/// {@endtemplate}
library;

import 'package:meta/meta.dart';

import 'core.dart';

export 'core.dart' show Listenable, Listener, TransformSource;

/// {@template mz_collection.sort_identifier}
/// A function type that extracts a comparable value from an item.
///
/// The identifier receives the [item] being sorted and returns the value
/// to compare against other items.
///
/// {@tool snippet}
/// Common identifier patterns:
///
/// ```dart
/// // Direct property
/// SortIdentifier<User, String> nameSort = (user) => user.name;
///
/// // Nested property
/// SortIdentifier<Ticket, String?> assigneeSort =
///     (ticket) => ticket.assignee?.name;
///
/// // Computed value
/// SortIdentifier<Order, double> totalSort =
///     (order) => order.items.fold(0.0, (sum, i) => sum + i.price);
/// ```
/// {@end-tool}
/// {@endtemplate}
typedef SortIdentifier<T, SortBy> = SortBy Function(T item);

/// {@template mz_collection.comparables_getter}
/// A function type for retrieving a list of comparable values from an item.
///
/// Used by [ComparableSortOption] for multi-field sorting.
/// {@endtemplate}
typedef ComparablesGetter<T> = List<Comparable<Object>?> Function(T item);

/// {@template mz_collection.sort_comparator}
/// A function type that compares two items for sorting.
///
/// Returns a negative number if [a] should come before [b],
/// a positive number if [a] should come after [b],
/// or zero if they are equal.
/// {@endtemplate}
typedef SortComparator<T> = int Function(T a, T b);

/// {@template mz_collection.value_changed}
/// A function type for callbacks when a value changes.
/// {@endtemplate}
typedef ValueChanged<T> = void Function(T value);

/// {@template mz_collection.sort_order}
/// The direction in which items should be sorted.
///
/// ```text
/// ┌─────────────────────────────────────────────────────────────────┐
/// │                     SortOrder Values                            │
/// │                                                                 │
/// │  ascending   →  A to Z, 0 to 9, oldest to newest                │
/// │  descending  →  Z to A, 9 to 0, newest to oldest                │
/// │  none        →  No sorting applied (original order)             │
/// │                                                                 │
/// │  Tri-state toggle cycle:                                        │
/// │  ascending  ──►  descending  ──►  none  ──►  ascending          │
/// │                                                                 │
/// │  Two-state toggle cycle:                                        │
/// │  ascending  ◄──►  descending                                    │
/// └─────────────────────────────────────────────────────────────────┘
/// ```
/// {@endtemplate}
enum SortOrder {
  /// {@template mz_collection.sort_order_ascending}
  /// Ascending order (A to Z, 0 to 9, oldest to newest).
  /// {@endtemplate}
  ascending('asc'),

  /// {@template mz_collection.sort_order_descending}
  /// Descending order (Z to A, 9 to 0, newest to oldest).
  /// {@endtemplate}
  descending('desc'),

  /// {@template mz_collection.sort_order_none}
  /// No sorting applied, items maintain original order.
  /// {@endtemplate}
  none('');

  /// Creates a [SortOrder] with the given API [code].
  const SortOrder(this.code);

  /// The API code for this sort order ('asc', 'desc', or '').
  final String code;

  /// Whether this is ascending order.
  bool get isAscending => this == ascending;

  /// Whether this is descending order.
  bool get isDescending => this == descending;

  /// Whether sorting is disabled.
  bool get isNone => this == none;

  /// {@template mz_collection.sort_order_toggle}
  /// Returns the next sort order in the toggle cycle.
  ///
  /// If [triState] is true (default), cycles through all three states:
  /// ascending → descending → none → ascending
  ///
  /// If [triState] is false, toggles between ascending and descending only.
  /// {@endtemplate}
  SortOrder toggle({bool triState = true}) {
    if (!triState) {
      return this == ascending ? descending : ascending;
    }
    return switch (this) {
      ascending => descending,
      descending => none,
      none => ascending,
    };
  }
}

/// {@template mz_collection.sort_value}
/// A selectable sort value for [CustomSortOption].
///
/// Used when a sort option can sort by different fields that the user
/// can choose between at runtime.
///
/// {@tool snippet}
/// Creating sort values:
///
/// ```dart
/// final values = [
///   SortValue(id: 'created', label: 'Created', value: (t) => t.created),
///   SortValue(id: 'updated', label: 'Updated', value: (t) => t.updated),
/// ];
/// ```
/// {@end-tool}
/// {@endtemplate}
@immutable
class SortValue<T> {
  /// Creates a sort value.
  const SortValue({
    required this.id,
    required this.value,
    this.label,
  });

  /// Unique identifier for this sort value.
  final String id;

  /// Optional display label.
  final String? label;

  /// Function to extract the comparable value from an item.
  final Comparable<dynamic>? Function(T item) value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SortValue<T> && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SortValue(id: $id)';
}

/// {@template mz_collection.sort_option}
/// A sort option that defines how to extract and compare values.
///
/// A [SortOption] represents a single sorting criterion (like "name" or
/// "date") with a type-safe value extractor. Sort options can be mutable
/// (tracking their own sort order) or used with [SortManager] for
/// centralized state management.
///
/// ## Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────┐
/// │                   SortOption<User, String>                    │
/// │                                                               │
/// │  id: 'name'           label: 'Name'                           │
/// │  sortOrder: ascending (mutable)                               │
/// │                                                               │
/// │  sortBy: (user) => user.name                                  │
/// │                                                               │
/// │  ┌─────────────────────────────────────────────────────────┐  │
/// │  │             compare(a, b)                               │  │
/// │  │                                                         │  │
/// │  │  1. Extract: valueA = sortBy(a), valueB = sortBy(b)     │  │
/// │  │  2. Handle nulls: null < non-null                       │  │
/// │  │  3. Compare: valueA.compareTo(valueB)                   │  │
/// │  │  4. Apply order: negate if descending                   │  │
/// │  └─────────────────────────────────────────────────────────┘  │
/// └───────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Factory Constructors
///
/// ```text
/// ┌────────────────────┬────────────────────────────────────────────┐
/// │     Constructor    │              Use Case                      │
/// ├────────────────────┼────────────────────────────────────────────┤
/// │ SortOption()       │ Single value extraction (most common)      │
/// │ .withComparable()  │ Multi-field comparison (name, then date)   │
/// │ .withComparator()  │ Custom comparator function                 │
/// │ .custom()          │ Multiple sort values to choose from        │
/// └────────────────────┴────────────────────────────────────────────┘
/// ```
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Creating sort options:
///
/// ```dart
/// // Simple value extraction
/// final nameSort = SortOption<User, String>(
///   id: 'name',
///   label: 'Name',
///   sortIdentifier: (user) => user.name,
/// );
///
/// // Nullable values handled automatically
/// final assigneeSort = SortOption<Ticket, String?>(
///   id: 'assignee',
///   label: 'Assignee',
///   sortIdentifier: (ticket) => ticket.assignee?.name,
/// );
///
/// // Sort a list
/// users.sort(nameSort.compare);
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [SortManager] - Manages multiple sort options.
/// * [SortOrder] - Direction of sorting.
/// {@endtemplate}
abstract class SortOption<T, SortBy> with Listenable {
  /// Creates a sort option with a value extractor.
  ///
  /// The [id] is used for API sort strings and identifying the option.
  /// The [sortIdentifier] function extracts the comparable value from items.
  factory SortOption({
    required String id,
    required SortIdentifier<T, SortBy?> sortIdentifier,
    String? label,
    SortOrder? sortOrder,
    TransformSource source,
    bool enabled,
  }) = ValueSortOption<T, SortBy>;

  /// Creates a sort option using multiple comparable values.
  ///
  /// The [comparables] function returns a list of comparable values
  /// that are compared in order until a non-zero result is found.
  ///
  /// {@tool snippet}
  /// Multi-field sorting:
  ///
  /// ```dart
  /// final multiSort = SortOption<User, Never>.withComparable(
  ///   id: 'name_date',
  ///   label: 'Name, then Date',
  ///   comparables: (user) => [user.lastName, user.firstName, user.joinDate],
  /// );
  /// ```
  /// {@end-tool}
  factory SortOption.withComparable({
    required String id,
    required ComparablesGetter<T> comparables,
    String? label,
    SortOrder? sortOrder,
    TransformSource source,
    bool enabled,
  }) = ComparableSortOption<T>;

  /// Creates a sort option using a custom comparator.
  ///
  /// The [comparator] function directly compares two items.
  /// Optionally, a [secondaryComparator] can be provided for tie-breaking.
  ///
  /// {@tool snippet}
  /// Custom comparison logic:
  ///
  /// ```dart
  /// final customSort = SortOption<User, Never>.withComparator(
  ///   id: 'custom',
  ///   label: 'Custom Order',
  ///   comparator: (a, b) => a.priority.compareTo(b.priority),
  ///   secondaryComparator: (a, b) => a.name.compareTo(b.name),
  /// );
  /// ```
  /// {@end-tool}
  factory SortOption.withComparator({
    required String id,
    required SortComparator<T> comparator,
    String? label,
    SortOrder? sortOrder,
    TransformSource source,
    String secondaryId,
    SortOrder? secondarySortOrder,
    SortComparator<T>? secondaryComparator,
    bool enabled,
  }) = ComparatorSortOption<T>;

  /// Creates a sort option with multiple selectable sort values.
  ///
  /// Use this when the user can choose between different sort fields
  /// for the same option (e.g., a dropdown with "Sort by: Name / Date").
  ///
  /// {@tool snippet}
  /// Selectable sort values:
  ///
  /// ```dart
  /// final flexibleSort = SortOption<Ticket, Never>.custom(
  ///   id: 'flexible',
  ///   values: [
  ///     SortValue(id: 'created', label: 'Created', value: (t) => t.created),
  ///     SortValue(id: 'updated', label: 'Updated', value: (t) => t.updated),
  ///     SortValue(id: 'due', label: 'Due Date', value: (t) => t.dueDate),
  ///   ],
  /// );
  /// ```
  /// {@end-tool}
  factory SortOption.custom({
    required String id,
    required List<SortValue<T>> values,
    String? label,
    int initialIndex,
    SortOrder? sortOrder,
    TransformSource source,
    bool enabled,
  }) = CustomSortOption<T>;

  SortOption._({
    required this.id,
    this.label,
    this.enabled = true,
    this.source = TransformSource.local,
    SortOrder? sortOrder,
  }) : _sortOrder = sortOrder ?? SortOrder.ascending;

  /// {@template mz_collection.sort_option_none}
  /// A sentinel sort option representing no sorting.
  ///
  /// The [compare] method always returns 0 (equal).
  /// {@endtemplate}
  static final SortOption<Never, Never> none = _NoSort();

  /// Unique identifier for this sort option.
  ///
  /// Used in API sort strings and for option lookup.
  final String id;

  /// Optional display label for UI presentation.
  ///
  /// If null, the [id] can be used as a fallback.
  final String? label;

  /// Whether this sort option is enabled.
  final bool enabled;

  /// Determines where this sort's processing occurs.
  ///
  /// The controller uses this to decide whether to:
  /// - Apply the sort locally via [compare]
  /// - Send sort parameters to the remote data source
  /// - Do both
  ///
  /// See [TransformSource] for details on each mode.
  final TransformSource source;

  /// Whether this sort requires server processing.
  ///
  /// True for [TransformSource.remote] and [TransformSource.combined].
  bool get isRemote =>
      source == TransformSource.remote || source == TransformSource.combined;

  /// Whether this sort processes locally.
  ///
  /// True for [TransformSource.local] and [TransformSource.combined].
  bool get isLocal =>
      source == TransformSource.local || source == TransformSource.combined;

  SortOrder _sortOrder;

  /// The current sort order for this option.
  SortOrder get sortOrder => _sortOrder;
  set sortOrder(SortOrder value) {
    if (value == _sortOrder) return;
    _sortOrder = value;
    notifyChanged();
  }

  /// Whether the sorting is in ascending order.
  bool get ascending => _sortOrder.isAscending;

  /// Silently updates the sort order without notifying listeners.
  void silentUpdate(SortOrder? value) {
    if (value == null || value == _sortOrder) return;
    _sortOrder = value;
  }

  /// Toggles the sort order to the next state.
  ///
  /// See [SortOrder.toggle] for the toggle cycle.
  void toggle({bool triState = true}) {
    sortOrder = _sortOrder.toggle(triState: triState);
  }

  /// {@template mz_collection.sort_option_sort_string}
  /// Returns the sort string for API calls (e.g., 'name:asc').
  ///
  /// Returns empty string if sort order is [SortOrder.none] or id is empty.
  /// {@endtemplate}
  String get sortString {
    if (_sortOrder.isNone || id.trim().isEmpty) return '';
    return '$id:${_sortOrder.code}';
  }

  /// {@template mz_collection.sort_option_compare}
  /// Compares two items using this sort option.
  ///
  /// Returns:
  /// - Negative number if [a] should come before [b]
  /// - Positive number if [a] should come after [b]
  /// - Zero if [a] and [b] are equal
  ///
  /// If sort order is [SortOrder.none], always returns 0.
  /// {@endtemplate}
  int compare(T? a, T? b);

  /// Creates a copy of this option with optional overrides.
  SortOption<T, SortBy> copyWith({
    String? id,
    String? label,
    SortOrder? sortOrder,
    TransformSource? source,
    bool? enabled,
  });

  // Equality based on id and sort order for use in collections.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SortOption<T, SortBy> &&
          id == other.id &&
          _sortOrder == other._sortOrder;

  @override
  int get hashCode => Object.hash(id, _sortOrder);
}

/// {@template mz_collection.value_sort_option}
/// A sort option that extracts a single comparable value from each item.
///
/// This is the most common sort option type, using a [sortIdentifier]
/// function to extract the value to compare.
///
/// ## Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────┐
/// │                 ValueSortOption<User, String>                 │
/// │                                                               │
/// │  id: 'name'           sortOrder: ascending                    │
/// │                                                               │
/// │  sortIdentifier: (user) => user.name                          │
/// │                                                               │
/// │  ┌─────────────────────────────────────────────────────────┐  │
/// │  │             compare(a, b)                               │  │
/// │  │                                                         │  │
/// │  │  1. Extract: valueA = sortIdentifier(a)                 │  │
/// │  │  2. Extract: valueB = sortIdentifier(b)                 │  │
/// │  │  3. Compare: valueA.compareTo(valueB)                   │  │
/// │  │  4. Apply order: negate if descending                   │  │
/// │  └─────────────────────────────────────────────────────────┘  │
/// └───────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Creating a value-based sort:
///
/// ```dart
/// final nameSort = ValueSortOption<User, String>(
///   id: 'name',
///   sortIdentifier: (user) => user.name,
/// );
///
/// // Sort a list
/// users.sort(nameSort.compare);
///
/// // Toggle direction
/// nameSort.toggle();
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [SortOption] - Base class and factory constructors.
/// * [ComparableSortOption] - For multi-field sorting within one option.
/// {@endtemplate}
class ValueSortOption<T, SortBy> extends SortOption<T, SortBy> {
  /// Creates a value-based sort option.
  ValueSortOption({
    required super.id,
    required this.sortIdentifier,
    super.label,
    super.sortOrder,
    super.source,
    super.enabled,
  }) : super._();

  /// The function that extracts the sort value from an item.
  final SortIdentifier<T, SortBy?> sortIdentifier;

  @override
  @pragma('vm:prefer-inline')
  int compare(T? a, T? b) {
    if (_sortOrder.isNone) return 0;
    final valueA = a == null ? null : sortIdentifier(a);
    final valueB = b == null ? null : sortIdentifier(b);
    final result = _compareNullable(valueA, valueB);
    return ascending ? result : -result;
  }

  @override
  SortOption<T, SortBy> copyWith({
    String? id,
    String? label,
    SortOrder? sortOrder,
    TransformSource? source,
    bool? enabled,
    SortIdentifier<T, SortBy?>? sortIdentifier,
  }) {
    return ValueSortOption<T, SortBy>(
      id: id ?? this.id,
      label: label ?? this.label,
      sortOrder: sortOrder ?? this.sortOrder,
      source: source ?? this.source,
      enabled: enabled ?? this.enabled,
      sortIdentifier: sortIdentifier ?? this.sortIdentifier,
    );
  }

  @override
  String toString() => 'ValueSortOption(id: $id, sortOrder: $_sortOrder)';
}

/// {@template mz_collection.comparable_sort_option}
/// A sort option that compares multiple values in sequence.
///
/// The [comparables] function returns a list of comparable values that are
/// compared in order until a non-zero result is found. This enables
/// multi-field sorting within a single option (e.g., sort by last name,
/// then first name, then date).
///
/// ## Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────┐
/// │              ComparableSortOption<User>                       │
/// │                                                               │
/// │  id: 'full_name'      sortOrder: ascending                    │
/// │                                                               │
/// │  comparables: (user) => [user.lastName, user.firstName]       │
/// │                                                               │
/// │  ┌─────────────────────────────────────────────────────────┐  │
/// │  │             compare(a, b)                               │  │
/// │  │                                                         │  │
/// │  │  1. Extract: listA = comparables(a)                     │  │
/// │  │  2. Extract: listB = comparables(b)                     │  │
/// │  │  3. Compare each pair until result != 0                 │  │
/// │  │  4. Apply order: negate if descending                   │  │
/// │  └─────────────────────────────────────────────────────────┘  │
/// └───────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Creating a multi-field sort:
///
/// ```dart
/// final nameSort = ComparableSortOption<User>(
///   id: 'full_name',
///   comparables: (user) => [user.lastName, user.firstName, user.joinDate],
/// );
///
/// // Users sorted by lastName, then firstName, then joinDate
/// users.sort(nameSort.compare);
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [ValueSortOption] - For single-value sorting.
/// * [ComparatorSortOption] - For custom comparison logic.
/// {@endtemplate}
class ComparableSortOption<T> extends SortOption<T, Never> {
  /// Creates a comparable-based sort option.
  ComparableSortOption({
    required super.id,
    required this.comparables,
    super.label,
    super.sortOrder,
    super.source,
    super.enabled,
  }) : super._();

  /// The function that extracts multiple comparable values from an item.
  final ComparablesGetter<T> comparables;

  @override
  int compare(T? a, T? b) {
    if (_sortOrder.isNone) return 0;
    final listA = a == null ? <Comparable<Object>?>[] : comparables(a);
    final listB = b == null ? <Comparable<Object>?>[] : comparables(b);
    var result = 0;
    final length = listA.length < listB.length ? listA.length : listB.length;
    for (var i = 0; result == 0 && i < length; i++) {
      result = _compareNullable(listA[i], listB[i]);
    }
    return ascending ? result : -result;
  }

  @override
  SortOption<T, Never> copyWith({
    String? id,
    String? label,
    SortOrder? sortOrder,
    TransformSource? source,
    bool? enabled,
    ComparablesGetter<T>? comparables,
  }) {
    return ComparableSortOption<T>(
      id: id ?? this.id,
      label: label ?? this.label,
      sortOrder: sortOrder ?? this.sortOrder,
      source: source ?? this.source,
      enabled: enabled ?? this.enabled,
      comparables: comparables ?? this.comparables,
    );
  }

  @override
  String toString() => 'ComparableSortOption(id: $id, sortOrder: $_sortOrder)';
}

/// {@template mz_collection.comparator_sort_option}
/// A sort option that uses a custom comparator function.
///
/// Use this when you need full control over the comparison logic,
/// or when comparing values that aren't directly [Comparable].
/// Optionally supports a secondary comparator for tie-breaking.
///
/// ## Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────┐
/// │              ComparatorSortOption<Task>                       │
/// │                                                               │
/// │  id: 'priority'       sortOrder: descending                   │
/// │  secondaryId: 'name'  secondarySortOrder: ascending           │
/// │                                                               │
/// │  comparator: (a, b) => a.priority.compareTo(b.priority)       │
/// │  secondaryComparator: (a, b) => a.name.compareTo(b.name)      │
/// │                                                               │
/// │  ┌─────────────────────────────────────────────────────────┐  │
/// │  │             compare(a, b)                               │  │
/// │  │                                                         │  │
/// │  │  1. result = comparator(a, b)                           │  │
/// │  │  2. Apply primary order                                 │  │
/// │  │  3. If result == 0 && hasSecondary:                     │  │
/// │  │     result = secondaryComparator(a, b)                  │  │
/// │  │     Apply secondary order                               │  │
/// │  └─────────────────────────────────────────────────────────┘  │
/// └───────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Creating a custom comparator sort:
///
/// ```dart
/// final prioritySort = ComparatorSortOption<Task>(
///   id: 'priority',
///   comparator: (a, b) => a.priority.index.compareTo(b.priority.index),
///   secondaryId: 'name',
///   secondaryComparator: (a, b) => a.name.compareTo(b.name),
/// );
///
/// // Tasks sorted by priority, then by name for same priority
/// tasks.sort(prioritySort.compare);
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [ValueSortOption] - For simple value extraction.
/// * [ComparableSortOption] - For multi-field sorting with comparable values.
/// {@endtemplate}
class ComparatorSortOption<T> extends SortOption<T, Never> {
  /// Creates a comparator-based sort option.
  ComparatorSortOption({
    required super.id,
    required this.comparator,
    super.label,
    super.sortOrder,
    super.source,
    super.enabled,
    this.secondaryId = '',
    this.secondaryComparator,
    SortOrder? secondarySortOrder,
  })  : _secondarySortOrder = secondarySortOrder ?? SortOrder.ascending,
        super._();

  /// The primary comparator function.
  final SortComparator<T> comparator;

  /// The id for the secondary sort (used in sort string).
  final String secondaryId;

  /// Optional secondary comparator for tie-breaking.
  final SortComparator<T>? secondaryComparator;

  SortOrder _secondarySortOrder;

  /// The sort order for the secondary comparator.
  SortOrder get secondarySortOrder => _secondarySortOrder;
  set secondarySortOrder(SortOrder value) {
    if (value == _secondarySortOrder) return;
    _secondarySortOrder = value;
    notifyChanged();
  }

  /// Whether the secondary sort is ascending.
  bool get secondaryAscending => _secondarySortOrder.isAscending;

  /// Whether a secondary comparator is available.
  bool get hasSecondary => secondaryComparator != null;

  @override
  int compare(T? a, T? b) {
    if (_sortOrder.isNone || a == null || b == null) return 0;
    final result = ascending ? comparator(a, b) : comparator(b, a);
    if (result == 0 && hasSecondary) {
      return secondaryAscending
          ? secondaryComparator!(a, b)
          : secondaryComparator!(b, a);
    }
    return result;
  }

  @override
  String get sortString {
    final buffer = StringBuffer();
    if (!_sortOrder.isNone && id.trim().isNotEmpty) {
      buffer.write('$id:${_sortOrder.code}');
    }
    if (!_secondarySortOrder.isNone && secondaryId.trim().isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(',');
      buffer.write('$secondaryId:${_secondarySortOrder.code}');
    }
    return buffer.toString();
  }

  @override
  SortOption<T, Never> copyWith({
    String? id,
    String? label,
    SortOrder? sortOrder,
    TransformSource? source,
    bool? enabled,
    SortComparator<T>? comparator,
    String? secondaryId,
    SortOrder? secondarySortOrder,
    SortComparator<T>? secondaryComparator,
  }) {
    return ComparatorSortOption<T>(
      id: id ?? this.id,
      label: label ?? this.label,
      sortOrder: sortOrder ?? this.sortOrder,
      source: source ?? this.source,
      enabled: enabled ?? this.enabled,
      comparator: comparator ?? this.comparator,
      secondaryId: secondaryId ?? this.secondaryId,
      secondarySortOrder: secondarySortOrder ?? this.secondarySortOrder,
      secondaryComparator: secondaryComparator ?? this.secondaryComparator,
    );
  }

  @override
  String toString() => 'ComparatorSortOption(id: $id, sortOrder: $_sortOrder)';
}

/// {@template mz_collection.custom_sort_option}
/// A sort option with multiple selectable sort values.
///
/// Use this when the user can choose between different sort fields
/// at runtime (e.g., a dropdown with "Sort by: Name / Date / Priority").
///
/// ## Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────┐
/// │              CustomSortOption<Ticket>                         │
/// │                                                               │
/// │  id: 'flexible'       sortOrder: ascending                    │
/// │  currentIndex: 0                                              │
/// │                                                               │
/// │  values: [                                                    │
/// │    SortValue(id: 'created', value: (t) => t.createdAt),       │
/// │    SortValue(id: 'updated', value: (t) => t.updatedAt),       │
/// │    SortValue(id: 'due', value: (t) => t.dueDate),             │
/// │  ]                                                            │
/// │                                                               │
/// │  ┌─────────────────────────────────────────────────────────┐  │
/// │  │             compare(a, b)                               │  │
/// │  │                                                         │  │
/// │  │  1. Get current SortValue                               │  │
/// │  │  2. Extract: valueA = current.value(a)                  │  │
/// │  │  3. Extract: valueB = current.value(b)                  │  │
/// │  │  4. Compare and apply order                             │  │
/// │  └─────────────────────────────────────────────────────────┘  │
/// └───────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Creating a selectable sort:
///
/// ```dart
/// final dateSort = CustomSortOption<Ticket>(
///   id: 'date',
///   values: [
///     SortValue(id: 'created', label: 'Created', value: (t) => t.createdAt),
///     SortValue(id: 'updated', label: 'Updated', value: (t) => t.updatedAt),
///   ],
/// );
///
/// // Change which field to sort by
/// dateSort.current = dateSort.values[1]; // Sort by updated
///
/// // Or by index
/// dateSort.setCurrentIndex(0); // Sort by created
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [SortValue] - Represents a single selectable sort field.
/// * [ValueSortOption] - For fixed single-value sorting.
/// {@endtemplate}
class CustomSortOption<T> extends SortOption<T, Never> {
  /// Creates a custom sort option with selectable values.
  CustomSortOption({
    required super.id,
    required List<SortValue<T>> values,
    super.label,
    super.sortOrder,
    super.source,
    super.enabled,
    int initialIndex = 0,
  })  : _values = List.unmodifiable(values),
        _currentIndex =
            values.isEmpty ? -1 : initialIndex.clamp(0, values.length - 1),
        super._();

  final List<SortValue<T>> _values;
  int _currentIndex;

  /// The list of available sort values.
  List<SortValue<T>> get values => _values;

  /// The currently selected sort value, or null if no values.
  SortValue<T>? get current =>
      _currentIndex >= 0 && _currentIndex < _values.length
          ? _values[_currentIndex]
          : null;

  /// Sets the current sort value.
  set current(SortValue<T>? value) {
    if (value == null) return;
    final index = _values.indexOf(value);
    if (index >= 0 && index != _currentIndex) {
      _currentIndex = index;
      notifyChanged();
    }
  }

  /// Sets the current sort value by index.
  void setCurrentIndex(int index) {
    final clamped = index.clamp(0, _values.length - 1);
    if (clamped != _currentIndex) {
      _currentIndex = clamped;
      notifyChanged();
    }
  }

  @override
  String get sortString {
    if (_sortOrder.isNone || current == null) return '';
    return '${current!.id}:${_sortOrder.code}';
  }

  @override
  int compare(T? a, T? b) {
    if (_sortOrder.isNone || current == null) return 0;
    final valueA = a == null ? null : current!.value(a);
    final valueB = b == null ? null : current!.value(b);
    final result = _compareNullable(valueA, valueB);
    return ascending ? result : -result;
  }

  @override
  SortOption<T, Never> copyWith({
    String? id,
    String? label,
    SortOrder? sortOrder,
    TransformSource? source,
    bool? enabled,
    List<SortValue<T>>? values,
    int? initialIndex,
  }) {
    return CustomSortOption<T>(
      id: id ?? this.id,
      label: label ?? this.label,
      sortOrder: sortOrder ?? this.sortOrder,
      source: source ?? this.source,
      enabled: enabled ?? this.enabled,
      values: values ?? _values,
      initialIndex: initialIndex ?? _currentIndex,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomSortOption<T> &&
          id == other.id &&
          _sortOrder == other._sortOrder &&
          _currentIndex == other._currentIndex;

  @override
  int get hashCode => Object.hash(id, _sortOrder, _currentIndex);

  @override
  String toString() => 'CustomSortOption('
      'id: $id, sortOrder: $_sortOrder, current: ${current?.id})';
}

/// Sentinel sort option representing no sorting.
class _NoSort extends SortOption<Never, Never> {
  _NoSort() : super._(id: '', label: null, enabled: false);

  @override
  set sortOrder(SortOrder value) {}

  @override
  int compare(Never? a, Never? b) => 0;

  @override
  SortOption<Never, Never> copyWith({
    String? id,
    String? label,
    SortOrder? sortOrder,
    TransformSource? source,
    bool? enabled,
  }) =>
      _NoSort();

  @override
  String toString() => 'SortOption.none';
}

/// {@template mz_collection.sort_manager}
/// Manages multiple sort options with multi-level sorting support.
///
/// A [SortManager] holds a collection of sort options and maintains an
/// active sort chain for multi-level sorting. Users can set a primary sort,
/// add secondary/tertiary sorts, and toggle sort directions.
///
/// ## Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────────┐
/// │                       SortManager<User>                           │
/// │                                                                   │
/// │  triState: true        onSortChanged: callback                   │
/// │                                                                   │
/// │  ┌─────────────────────────────────────────────────────────────┐  │
/// │  │              _options: Map<String, SortOption>              │  │
/// │  │                                                             │  │
/// │  │  'name' ──► SortOption(id: name, sortBy: (u) => u.name)    │  │
/// │  │  'date' ──► SortOption(id: date, sortBy: (u) => u.date)    │  │
/// │  │  'age'  ──► SortOption(id: age,  sortBy: (u) => u.age)     │  │
/// │  └─────────────────────────────────────────────────────────────┘  │
/// │                                                                   │
/// │  ┌─────────────────────────────────────────────────────────────┐  │
/// │  │           _activeSorts: List<SortOption>                    │  │
/// │  │                                                             │  │
/// │  │  [0] SortOption(name, ascending)   ← primary               │  │
/// │  │  [1] SortOption(date, descending)  ← secondary             │  │
/// │  └─────────────────────────────────────────────────────────────┘  │
/// │                              │                                    │
/// │                    compare(a, b)                                  │
/// │                              │                                    │
/// │                              ▼                                    │
/// │              Applies sorts in priority order                      │
/// └───────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Sort Chain Lifecycle
///
/// ```text
///  add(opt, reset: true)      add(opt)              clearSorts()
///          │                      │                      │
///          ▼                      ▼                      ▼
///   ┌─────────────┐       ┌─────────────┐       ┌─────────────┐
///   │  Clear all  │       │  Append to  │       │  Clear all  │
///   │  Set as [0] │       │  chain      │       │  active     │
///   └──────┬──────┘       └──────┬──────┘       └──────┬──────┘
///          │                     │                     │
///          └─────────────────────┼─────────────────────┘
///                                ▼
///                        notifyChanged()
/// ```
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Creating and using a sort manager:
///
/// ```dart
/// // Create sort options
/// final nameSort = SortOption<User, String>(
///   id: 'name',
///   sortIdentifier: (u) => u.name,
/// );
/// final ageSort = SortOption<User, int>(
///   id: 'age',
///   sortIdentifier: (u) => u.age,
/// );
///
/// // Create manager and add sorts
/// final manager = SortManager<User>();
/// manager.add(nameSort);  // Primary sort
///
/// // Sort a list
/// users.sort(manager.compare);
///
/// // Get sort string for API
/// final param = manager.sortString; // 'name:asc'
/// ```
/// {@end-tool}
///
/// ## Multi-Level Sorting
///
/// {@tool snippet}
/// Sort by multiple fields:
///
/// ```dart
/// // Build a sort chain
/// manager.add(nameSort);                              // Primary
/// manager.add(dateSort, order: SortOrder.descending); // Secondary
/// manager.add(idSort);                                // Tertiary
///
/// // Sort string: 'name:asc,date:desc,id:asc'
/// print(manager.sortString);
///
/// // Reset and start new chain
/// manager.add(prioritySort, reset: true);  // Clears chain, sets as primary
///
/// // Users sorted by name, then by date within same name
/// users.sort(manager.compare);
/// ```
/// {@end-tool}
///
/// ## Listening to Changes
///
/// {@tool snippet}
/// React to sort changes:
///
/// ```dart
/// manager.addChangeListener(() {
///   setState(() {
///     _sortedItems = items.toList()..sort(manager.compare);
///   });
/// });
///
/// // Or use callback
/// final manager = SortManager<User>(
///   options: [...],
///   onSortChanged: (option) => print('Sort changed: ${option?.sortString}'),
/// );
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [SortOption] - Individual sort option definition.
/// * [SortOrder] - Ascending, descending, or none.
/// {@endtemplate}
class SortManager<T> with Listenable {
  /// {@template mz_collection.sort_manager_constructor}
  /// Creates a new sort manager.
  ///
  /// Initial [options] can be provided and will be registered immediately.
  ///
  /// If [currentOptionIndex] is provided and valid, sets that option as the
  /// initial primary sort.
  ///
  /// If [triState] is true (default), sort order toggles through all
  /// three states. If false, toggles only between ascending/descending.
  ///
  /// The [onSortChanged] callback is invoked when the active sort changes.
  /// {@endtemplate}
  SortManager({
    Iterable<SortOption<T, dynamic>>? options,
    int currentOptionIndex = 0,
    this.triState = true,
    this.onSortChanged,
  }) {
    if (options == null) return;
    for (final (index, option) in options.indexed) {
      _options[option.id] = option;
      if (index == currentOptionIndex) {
        setCurrent(option, silent: true);
      }
    }
  }

  /// Whether sort order toggles through all three states.
  ///
  /// If true: ascending → descending → none → ascending
  /// If false: ascending ↔ descending
  final bool triState;

  /// Optional callback invoked when the active sort changes.
  final ValueChanged<SortOption<T, dynamic>?>? onSortChanged;

  final Map<String, SortOption<T, dynamic>> _options = {};
  final List<SortOption<T, dynamic>> _activeSorts = [];
  final Map<String, Listener> _optionListeners = {};

  /// All registered options including those not in the active chain.
  ///
  /// Returns options in insertion order.
  Iterable<SortOption<T, dynamic>> get allOptions => _options.values;

  /// The number of registered options.
  int get length => _options.length;

  /// Returns the list of active sort options.
  ///
  /// The list is ordered by priority (index 0 is primary sort).
  List<SortOption<T, dynamic>> get activeSorts =>
      List.unmodifiable(_activeSorts);

  /// Returns active sorts that should be processed remotely.
  ///
  /// Includes sorts with [TransformSource.remote] or
  /// [TransformSource.combined]. Use this when building API requests.
  List<SortOption<T, dynamic>> get remoteSorts =>
      _activeSorts.where((s) => s.isRemote).toList();

  /// Returns active sorts that should be processed locally.
  ///
  /// Includes sorts with [TransformSource.local] or [TransformSource.combined].
  List<SortOption<T, dynamic>> get localSorts =>
      _activeSorts.where((s) => s.isLocal).toList();

  /// Returns the number of active sorts in the chain.
  int get activeSortCount => _activeSorts.length;

  /// Returns true if there are no active sorts.
  bool get isEmpty => _activeSorts.isEmpty;

  /// Returns true if there is at least one active sort.
  bool get isNotEmpty => _activeSorts.isNotEmpty;

  /// Returns the option with the given [id], or null if not found.
  SortOption<T, dynamic>? operator [](String id) => _options[id];

  /// Returns the option with the given [id], or null if not found.
  SortOption<T, dynamic>? getOptionById(String id) => _options[id];

  /// Returns the option with the given [id] cast to [SortOption<T, V>].
  SortOption<T, V>? getOption<V>(String id) =>
      _options[id] as SortOption<T, V>?;

  /// {@template mz_collection.sort_manager_current}
  /// Returns the primary (first) active sort option, or null.
  /// {@endtemplate}
  SortOption<T, dynamic>? get current =>
      _activeSorts.isNotEmpty ? _activeSorts[0] : _options.values.firstOrNull;

  /// Returns the current sort order, or [SortOrder.ascending] if no active
  /// sort.
  SortOrder get currentOrder => current?.sortOrder ?? SortOrder.ascending;

  void _onOptionChanged(SortOption<T, dynamic> option) {
    onSortChanged?.call(option);
    notifyChanged();
  }

  void _addOptionListener(SortOption<T, dynamic> option) {
    void listener() => _onOptionChanged(option);
    _optionListeners[option.id] = listener;
    option.addChangeListener(listener);
  }

  void _removeOptionListener(String id) {
    final listener = _optionListeners.remove(id);
    if (listener != null) {
      _options[id]?.removeChangeListener(listener);
    }
  }

  /// {@template mz_collection.sort_manager_add}
  /// Adds a sort option to the active chain.
  ///
  /// This is the primary method for building sort chains:
  ///
  /// ```dart
  /// manager.add(nameSort);                    // Primary sort
  /// manager.add(ageSort);                     // Secondary sort
  /// manager.add(dateSort, order: SortOrder.descending);  // Tertiary
  ///
  /// // Reset and start new chain
  /// manager.add(prioritySort, reset: true);   // Clears, sets as primary
  /// ```
  ///
  /// ## Parameters
  ///
  /// - [reset]: If true, clears the existing chain before adding.
  ///   When the same option is added with `reset: true` and no [order]
  ///   specified, toggles the sort order instead (like clicking a column
  ///   header repeatedly).
  ///
  /// - [order]: Sets the sort order for this option. If not specified,
  ///   uses the option's current sort order.
  ///
  /// - [triState]: Overrides the manager's [triState] for toggle behavior.
  ///   Only applies when toggling (same option with `reset: true`).
  ///
  /// - [silent]: If true, suppresses change notifications.
  ///
  /// ## Behavior
  ///
  /// - If option is already in chain: updates its sort order (if specified)
  /// - If option is not in chain: appends to the chain
  /// - Always registers the option for lookup via `operator[]`
  ///
  /// Returns `true` if the option was added or updated.
  /// {@endtemplate}
  bool add(
    SortOption<T, dynamic> option, {
    bool reset = false,
    SortOrder? order,
    bool? triState,
    bool silent = false,
  }) {
    if (reset) {
      // Toggle behavior: same option with reset and no explicit order
      if (_activeSorts.isNotEmpty &&
          _activeSorts[0].id == option.id &&
          order == null) {
        final activeOpt = _activeSorts[0];
        if (silent) {
          // Use silentUpdate to avoid triggering option's listeners
          final newOrder = activeOpt.sortOrder.toggle(
            triState: triState ?? this.triState,
          );
          activeOpt.silentUpdate(newOrder);
        } else {
          activeOpt.toggle(triState: triState ?? this.triState);
          _onOptionChanged(activeOpt);
        }
        return true;
      }
      // Clear existing chain
      _clearActive();
    }

    // Check if already in chain
    final existingIndex = _activeSorts.indexWhere((o) => o.id == option.id);
    if (existingIndex >= 0) {
      // Update order if specified
      if (order != null) {
        _activeSorts[existingIndex].sortOrder = order;
      }
      return true;
    }

    // Add to registry and chain
    _options.putIfAbsent(option.id, () => option);
    if (order != null) option.silentUpdate(order);
    _activeSorts.add(option);
    _addOptionListener(option);
    if (!silent) {
      onSortChanged?.call(option);
      notifyChanged();
    }
    return true;
  }

  /// Registers multiple [options] in this manager.
  void addAll(
    Iterable<SortOption<T, dynamic>?>? options, {
    bool silent = false,
  }) {
    if (options == null) return;
    for (final option in options.nonNulls) {
      if (option.id == current?.id) {
        option.silentUpdate(current?.sortOrder);
      }
      _options[option.id] = option;
    }
    if (!silent) notifyChanged();
  }

  /// {@template mz_collection.sort_manager_remove}
  /// Removes a sort option by ID.
  ///
  /// Returns the removed option, or null if not found.
  ///
  /// Also removes the option from active sorts if present.
  /// {@endtemplate}
  SortOption<T, dynamic>? remove(String id) {
    final option = _options.remove(id);
    if (option != null) {
      _removeFromActive(id);
      notifyChanged();
    }
    return option;
  }

  /// Removes all given [options] from the manager.
  void removeAll(
    Iterable<SortOption<T, dynamic>> options, {
    bool silent = false,
  }) {
    var removedSome = false;
    for (final option in options) {
      // Check if this is the current option BEFORE removing
      final wasCurrent = option.id == current?.id;
      final result = _options.remove(option.id);
      if (result != null) {
        _removeFromActive(option.id);
        if (wasCurrent) {
          onSortChanged?.call(null);
        }
        removedSome = true;
      }
    }
    if (removedSome && !silent) notifyChanged();
  }

  /// Removes all registered options in a single batch.
  ///
  /// This clears both the options registry and the active sort chain.
  /// More efficient than calling [remove] for each option as it only
  /// triggers a single notification.
  void clear() {
    if (_options.isEmpty) return;
    _clearActive();
    _options.clear();
    onSortChanged?.call(null);
    notifyChanged();
  }

  void _removeFromActive(String id) {
    final index = _activeSorts.indexWhere((o) => o.id == id);
    if (index >= 0) {
      _activeSorts.removeAt(index);
      _removeOptionListener(id);
    }
  }

  /// {@template mz_collection.sort_manager_set_current}
  /// Sets [option] as the primary sort, clearing any existing chain.
  ///
  /// This is a convenience method equivalent to `add(option, reset: true)`.
  ///
  /// If the same option is passed again, toggles its sort order instead.
  /// If [option] is null, this is a no-op.
  /// {@endtemplate}
  void setCurrent(
    SortOption<T, dynamic>? option, {
    bool silent = false,
    bool? triState,
  }) {
    if (option == null) return;
    add(option, reset: true, silent: silent, triState: triState);
  }

  /// {@template mz_collection.sort_manager_set_current_by_id}
  /// Sets the option with [id] as the primary sort.
  ///
  /// Does nothing if no option with that id exists.
  /// {@endtemplate}
  void setCurrentById(String id, {bool silent = false}) {
    final option = _options[id];
    if (option != null) setCurrent(option, silent: silent);
  }

  /// {@template mz_collection.sort_manager_remove_from_chain}
  /// Removes the sort with [id] from the active chain.
  /// {@endtemplate}
  void removeFromChain(String id) {
    final index = _activeSorts.indexWhere((o) => o.id == id);
    if (index >= 0) {
      _activeSorts.removeAt(index);
      _removeOptionListener(id);
      onSortChanged?.call(current);
      notifyChanged();
    }
  }

  void _clearActive() {
    for (final option in _activeSorts) {
      _removeOptionListener(option.id);
    }
    _activeSorts.clear();
  }

  /// {@template mz_collection.sort_manager_clear_sorts}
  /// Clears all active sorts.
  ///
  /// After clearing, [compare] returns 0 for all comparisons.
  /// {@endtemplate}
  void clearSorts() {
    if (_activeSorts.isEmpty) return;
    _clearActive();
    onSortChanged?.call(null);
    notifyChanged();
  }

  /// {@template mz_collection.sort_manager_set_sort_order}
  /// Sets the sort order for the primary sort.
  ///
  /// Does nothing if there's no active sort or order is unchanged.
  /// {@endtemplate}
  void setSortOrder(SortOrder order) {
    if (current == null || current!.sortOrder == order) return;
    current!.sortOrder = order;
  }

  /// {@template mz_collection.sort_manager_toggle_order}
  /// Toggles the sort order for the primary sort.
  ///
  /// Uses [triState] to determine the toggle cycle if provided;
  /// otherwise uses the manager's default [triState] setting.
  /// Does nothing if there's no active sort.
  /// {@endtemplate}
  void toggleOrder({bool? triState}) {
    current?.toggle(triState: triState ?? this.triState);
  }

  /// {@template mz_collection.sort_manager_compare}
  /// Compares two items using the active sort chain.
  ///
  /// Applies each sort in the chain in order until a non-zero
  /// result is found.
  ///
  /// Returns 0 if no active sorts or all sorts return 0.
  ///
  /// {@tool snippet}
  /// Sorting a list:
  ///
  /// ```dart
  /// users.sort(manager.compare);
  ///
  /// // Or use as comparator
  /// final sorted = users.toList()..sort(manager.compare);
  /// ```
  /// {@end-tool}
  /// {@endtemplate}
  int compare(T a, T b) {
    for (final option in _activeSorts) {
      final result = option.compare(a, b);
      if (result != 0) return result;
    }
    return 0;
  }

  /// {@template mz_collection.sort_manager_sort}
  /// Sorts [items] using the active sort chain and returns a new sorted list.
  ///
  /// This is the recommended way to sort a collection. The manager
  /// encapsulates all sorting logic including multi-level sorting and
  /// performance optimizations.
  ///
  /// Returns the original [items] unchanged if no sorts are active.
  ///
  /// Only sorts with [TransformSource.local] or [TransformSource.combined]
  /// are applied locally. Sorts with [TransformSource.remote] are skipped.
  ///
  /// For large lists (>1000 items), uses Schwartzian transform optimization
  /// to pre-extract sort keys, reducing redundant value extractions from
  /// O(n log n) to O(n).
  ///
  /// {@tool snippet}
  /// Sorting a collection:
  ///
  /// ```dart
  /// final manager = SortManager<User>(options: [...]);
  /// manager.setCurrent(manager['name']!);
  ///
  /// // Sort returns a new sorted list
  /// final sorted = manager.sort(users);
  ///
  /// // Chain with filtering
  /// final result = sortManager.sort(filterManager.filter(items).toList());
  /// ```
  /// {@end-tool}
  /// {@endtemplate}
  List<T> sort(List<T> items) {
    // Filter to only local sorts
    final localSorts = _activeSorts.where((s) => s.isLocal).toList();
    if (localSorts.isEmpty || items.length < 2) return items;

    // For small lists, use simple sort
    if (items.length < _schwartzianThreshold) {
      return items.toList()
        ..sort((a, b) => _compareWithSorts(a, b, localSorts));
    }

    // For large lists, use Schwartzian transform
    return _schwartzianSort(items, localSorts);
  }

  /// Threshold for using Schwartzian transform optimization.
  static const _schwartzianThreshold = 1000;

  /// Compares two items using a specific list of sort options.
  int _compareWithSorts(
    T a,
    T b,
    List<SortOption<T, dynamic>> sorts,
  ) {
    for (final option in sorts) {
      final result = option.compare(a, b);
      if (result != 0) return result;
    }
    return 0;
  }

  /// Sorts using Schwartzian transform for better performance on large lists.
  ///
  /// Pre-extracts ALL sort keys once (O(n * k)) instead of extracting during
  /// comparisons (O(n log n * k)), where k is the number of sort levels.
  /// This optimization is most impactful for multi-level sorting.
  List<T> _schwartzianSort(
    List<T> items,
    List<SortOption<T, dynamic>> localSorts,
  ) {
    // Extract ALL keys for ALL sort levels upfront - O(n * k)
    final decorated = <_DecoratedItem<T>>[];
    for (final item in items) {
      final keys = <dynamic>[];
      for (final sort in localSorts) {
        keys.add(_extractKey(item, sort));
      }
      decorated.add(_DecoratedItem(item, keys));
    }

    // Sort using pre-extracted keys - comparisons are now O(1) per level
    decorated.sort((a, b) {
      for (var i = 0; i < localSorts.length; i++) {
        final keyA = a.keys[i];
        final keyB = b.keys[i];

        // If key extraction returned null (e.g., ComparatorSortOption),
        // fall back to the option's compare method
        if (keyA == null && keyB == null) {
          final result = localSorts[i].compare(a.item, b.item);
          if (result != 0) return result;
          continue;
        }

        final keyResult = _compareKeys(keyA, keyB, localSorts[i].ascending);
        if (keyResult != 0) return keyResult;
      }
      return 0;
    });

    // Extract sorted items
    return decorated.map((d) => d.item).toList();
  }

  /// Extracts the sort key from an item for the given sort option.
  ///
  /// Returns `null` for [ComparatorSortOption] (uses custom comparator).
  Object? _extractKey(T item, SortOption<T, dynamic> option) {
    if (option is ValueSortOption<T, dynamic>) {
      return option.sortIdentifier(item);
    }
    if (option is CustomSortOption<T>) {
      return option.current?.value(item);
    }
    if (option is ComparableSortOption<T>) {
      // Return the list of comparables for multi-field options
      return option.comparables(item);
    }
    // For ComparatorSortOption, return null (uses custom comparator)
    return null;
  }

  /// Compares two pre-extracted keys.
  ///
  /// At least one of [a] or [b] is non-null (the both-null case is handled
  /// at the call site before invoking this method).
  int _compareKeys(Object? a, Object? b, bool ascending) {
    if (a == null) return ascending ? -1 : 1;
    if (b == null) return ascending ? 1 : -1;

    // Handle list keys (from ComparableSortOption)
    if (a is List && b is List) {
      final length = a.length < b.length ? a.length : b.length;
      for (var i = 0; i < length; i++) {
        final result = _compareSingleKey(a[i], b[i]);
        if (result != 0) return ascending ? result : -result;
      }
      return 0;
    }

    final result = _compareSingleKey(a, b);
    return ascending ? result : -result;
  }

  /// Compares two single key values.
  int _compareSingleKey(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;

    if (a is Comparable && b is Comparable) {
      if (a is String && b is String) {
        return a.toLowerCase().compareTo(b.toLowerCase());
      }
      return a.compareTo(b);
    }
    return a.toString().compareTo(b.toString());
  }

  /// {@template mz_collection.sort_manager_comparator}
  /// Returns a comparator function for use with sorting methods.
  ///
  /// Equivalent to using [compare] directly.
  /// {@endtemplate}
  int Function(T, T) get comparator => compare;

  /// {@template mz_collection.sort_manager_sort_string}
  /// Returns the sort string for API calls.
  ///
  /// Combines all active sorts in the format 'id:order,id:order'.
  ///
  /// {@tool snippet}
  /// Using sort string for API:
  ///
  /// ```dart
  /// final response = await api.fetchUsers(
  ///   sortBy: manager.sortString, // 'name:asc,date:desc'
  /// );
  /// ```
  /// {@end-tool}
  /// {@endtemplate}
  String get sortString {
    final parts = <String>[];
    for (final option in _activeSorts) {
      final str = option.sortString;
      if (str.isNotEmpty) parts.add(str);
    }
    return parts.join(',');
  }

  @override
  void dispose() {
    _clearActive();
    _options.clear();
    super.dispose();
  }

  @override
  String toString() => 'SortManager('
      'options: ${_options.length}, active: ${_activeSorts.length})';

  // ===========================================================================
  // State Serialization
  // ===========================================================================

  /// Captures the current sort state for serialization.
  ///
  /// Returns a [SortSnapshot] containing all active sort options that can be
  /// serialized to JSON or a query string for persistence, deep linking,
  /// or sharing.
  ///
  /// {@tool snippet}
  /// Capturing and restoring sort state:
  ///
  /// ```dart
  /// // Capture current state
  /// final snapshot = manager.captureState();
  ///
  /// // Serialize to JSON for storage
  /// final json = snapshot.toJson();
  /// localStorage.setItem('sort', jsonEncode(json));
  ///
  /// // Or convert to URL query string
  /// final url = '/items?${snapshot.toQueryString()}';
  ///
  /// // Later, restore the state
  /// final savedJson = jsonDecode(localStorage.getItem('sort'));
  /// final restored = SortSnapshot.fromJson(savedJson);
  /// manager.restoreState(restored);
  /// ```
  /// {@end-tool}
  SortSnapshot captureState() {
    final entries = <SortEntry>[];
    for (final option in _activeSorts) {
      if (option.sortOrder != SortOrder.none) {
        entries.add(SortEntry(id: option.id, order: option.sortOrder));
      }
    }
    return SortSnapshot._(entries);
  }

  /// Restores sort state from a [SortSnapshot].
  ///
  /// Only restores sorts for options that exist in this manager.
  /// Existing sorts are cleared before restoring.
  /// Sort IDs in the snapshot that don't exist in this manager are ignored.
  ///
  /// {@tool snippet}
  /// Restoring sort state from a URL:
  ///
  /// ```dart
  /// // From URL query string
  /// final snapshot = SortSnapshot.fromQueryString(
  ///   Uri.parse(url).query,
  /// );
  /// manager.restoreState(snapshot);
  ///
  /// // From stored JSON
  /// final snapshot = SortSnapshot.fromJson(savedJson);
  /// manager.restoreState(snapshot);
  /// ```
  /// {@end-tool}
  void restoreState(SortSnapshot snapshot) {
    _clearActive();

    for (final entry in snapshot._entries) {
      final option = _options[entry.id];
      if (option != null) {
        option.silentUpdate(entry.order);
        _activeSorts.add(option);
        _addOptionListener(option);
      }
    }

    notifyChanged();
  }
}

// ============================================================================
// Helper Classes
// ============================================================================

/// Helper class for Schwartzian transform - pairs an item with its
/// pre-extracted sort keys for all sort levels.
class _DecoratedItem<T> {
  const _DecoratedItem(this.item, this.keys);

  final T item;

  /// Pre-extracted keys for each sort level.
  final List<dynamic> keys;
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Compares two nullable comparable values.
///
/// Null values are considered less than non-null values.
@pragma('vm:prefer-inline')
int _compareNullable(dynamic a, dynamic b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  if (a is Comparable && b is Comparable) {
    // Case-insensitive string comparison
    if (a is String && b is String) {
      return a.toLowerCase().compareTo(b.toLowerCase());
    }
    return a.compareTo(b);
  }
  return a.toString().compareTo(b.toString());
}

// ============================================================================
// Type Aliases for Common Sort Types
// ============================================================================

/// {@template mz_collection.sort_by_string}
/// Type alias for sorting by String values.
///
/// {@tool snippet}
/// ```dart
/// final nameSort = SortByString<User>(
///   id: 'name',
///   sortIdentifier: (user) => user.name,
/// );
/// ```
/// {@end-tool}
/// {@endtemplate}
typedef SortByString<T> = SortOption<T, String>;

/// {@template mz_collection.sort_by_num}
/// Type alias for sorting by num values.
/// {@endtemplate}
typedef SortByNum<T> = SortOption<T, num>;

/// {@template mz_collection.sort_by_int}
/// Type alias for sorting by int values.
/// {@endtemplate}
typedef SortByInt<T> = SortOption<T, int>;

/// {@template mz_collection.sort_by_double}
/// Type alias for sorting by double values.
/// {@endtemplate}
typedef SortByDouble<T> = SortOption<T, double>;

/// {@template mz_collection.sort_by_date}
/// Type alias for sorting by DateTime values.
/// {@endtemplate}
typedef SortByDate<T> = SortOption<T, DateTime>;

// =============================================================================
// Sort Snapshot (Serialization)
// =============================================================================

/// {@template mz_collection.sort_entry}
/// A single sort entry representing an active sort option and its order.
///
/// Used by [SortSnapshot] to represent the sort state.
/// {@endtemplate}
@immutable
class SortEntry {
  /// Creates a sort entry.
  const SortEntry({required this.id, required this.order});

  /// Creates a sort entry from a JSON map.
  factory SortEntry.fromJson(Map<String, dynamic> json) {
    return SortEntry(
      id: json['id'] as String,
      order: _parseOrder(json['order'] as String?),
    );
  }

  /// The sort option ID.
  final String id;

  /// The sort order (ascending or descending).
  final SortOrder order;

  /// Converts this entry to a JSON map.
  Map<String, dynamic> toJson() => {'id': id, 'order': order.code};

  static SortOrder _parseOrder(String? code) {
    return switch (code) {
      'asc' => SortOrder.ascending,
      'desc' => SortOrder.descending,
      _ => SortOrder.ascending,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SortEntry && id == other.id && order == other.order;

  @override
  int get hashCode => Object.hash(id, order);

  @override
  String toString() => 'SortEntry($id:${order.code})';
}

/// {@template mz_collection.sort_snapshot}
/// A serializable snapshot of sort state.
///
/// Use this to persist sort state, create shareable URLs, or restore
/// sort configurations.
///
/// ## JSON Serialization
///
/// {@tool snippet}
/// Serialize sort state to JSON:
///
/// ```dart
/// final snapshot = manager.captureState();
///
/// // To JSON
/// final json = snapshot.toJson();
/// // Result: {'sorts': [{'id': 'name', 'order': 'asc'}, {'id': 'date', 'order': 'desc'}]}
///
/// // From JSON
/// final restored = SortSnapshot.fromJson(json);
/// ```
/// {@end-tool}
///
/// ## URL Query String
///
/// {@tool snippet}
/// Serialize sort state to URL query string:
///
/// ```dart
/// final snapshot = manager.captureState();
///
/// // To query string
/// final query = snapshot.toQueryString();
/// // Result: 'sort=name:asc,date:desc'
///
/// // Build URL
/// final url = '/items?$query';
///
/// // From query string
/// final restored = SortSnapshot.fromQueryString(query);
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [SortManager.captureState] - Creates a snapshot from current state.
/// * [SortManager.restoreState] - Restores state from a snapshot.
/// {@endtemplate}
@immutable
class SortSnapshot {
  const SortSnapshot._(this._entries);

  /// Creates an empty sort snapshot.
  const SortSnapshot.empty() : _entries = const [];

  /// Creates a sort snapshot from a list of sort entries.
  factory SortSnapshot.fromEntries(List<SortEntry> entries) {
    return SortSnapshot._(List.unmodifiable(entries));
  }

  /// Creates a snapshot from a JSON map.
  factory SortSnapshot.fromJson(Map<String, dynamic> json) {
    final sortsList = json['sorts'] as List<dynamic>?;
    if (sortsList == null || sortsList.isEmpty) {
      return const SortSnapshot.empty();
    }
    final entries = sortsList
        .whereType<Map<String, dynamic>>()
        .map(SortEntry.fromJson)
        .toList();
    return SortSnapshot._(List.unmodifiable(entries));
  }

  /// Creates a snapshot from a URL query string.
  ///
  /// Parses the `sort` parameter with format `id:order,id:order`.
  factory SortSnapshot.fromQueryString(String queryString) {
    if (queryString.isEmpty) return const SortSnapshot.empty();

    final params = Uri.splitQueryString(queryString);
    final sortValue = params['sort'];
    if (sortValue == null || sortValue.isEmpty) {
      return const SortSnapshot.empty();
    }

    final entries = <SortEntry>[];
    final pairs = sortValue.split(',');
    for (final pair in pairs) {
      final parts = pair.split(':');
      if (parts.isEmpty) continue;

      final id = Uri.decodeComponent(parts[0]);
      final orderCode = parts.length > 1 ? parts[1] : 'asc';
      final order = SortEntry._parseOrder(orderCode);
      entries.add(SortEntry(id: id, order: order));
    }

    return SortSnapshot._(List.unmodifiable(entries));
  }

  final List<SortEntry> _entries;

  /// Returns all sort entries in this snapshot.
  ///
  /// Entries are ordered by priority (first is primary sort).
  List<SortEntry> get entries => _entries;

  /// Whether this snapshot has any sorts.
  bool get isEmpty => _entries.isEmpty;

  /// Whether this snapshot has sorts.
  bool get isNotEmpty => _entries.isNotEmpty;

  /// The number of sorts in this snapshot.
  int get length => _entries.length;

  /// Converts this snapshot to a JSON-serializable map.
  ///
  /// The resulting map can be encoded with `jsonEncode` and stored or
  /// transmitted.
  Map<String, dynamic> toJson() {
    return {
      'sorts': _entries.map((e) => e.toJson()).toList(),
    };
  }

  /// Converts this snapshot to a URL query string.
  ///
  /// Format: `sort={id}:{order},{id}:{order}`
  ///
  /// Values are URL-encoded. Empty sorts are omitted.
  String toQueryString() {
    if (_entries.isEmpty) return '';

    final sortParts =
        _entries.map((e) => '${Uri.encodeComponent(e.id)}:${e.order.code}');
    return 'sort=${sortParts.join(',')}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SortSnapshot) return false;
    if (_entries.length != other._entries.length) return false;
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i] != other._entries[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_entries);

  @override
  String toString() => 'SortSnapshot($_entries)';
}

// =============================================================================
// Sort Criteria (Serializable)
// =============================================================================

/// {@template mz_collection.sort_criteria}
/// A serializable sort criterion for page requests.
///
/// Represents a sort field's ID and order without coupling to the
/// `SortOption` class.
///
/// ## Query Parameter Format
///
/// {@tool snippet}
/// Converting to query parameters:
///
/// ```dart
/// final criteria = SortCriteria(id: 'name', order: SortOrder.ascending);
/// final params = criteria.toQueryParams();
/// // Result: {'sort': 'name:asc'}
///
/// // Multiple sorts:
/// final params = SortCriteria.listToQueryParams([
///   SortCriteria(id: 'priority', order: SortOrder.descending),
///   SortCriteria(id: 'name', order: SortOrder.ascending),
/// ]);
/// // Result: {'sort': 'priority:desc,name:asc'}
/// ```
/// {@end-tool}
/// {@endtemplate}
@immutable
class SortCriteria {
  /// Creates a sort criterion.
  const SortCriteria({required this.id, required this.order});

  /// Creates an ascending sort criterion.
  const SortCriteria.ascending(this.id) : order = SortOrder.ascending;

  /// Creates a descending sort criterion.
  const SortCriteria.descending(this.id) : order = SortOrder.descending;

  /// Creates a criterion from a JSON map.
  factory SortCriteria.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'id': final String id, 'order': final String orderCode} => SortCriteria(
          id: id,
          order: SortOrder.values.firstWhere(
            (o) => o.code == orderCode,
            orElse: () => SortOrder.none,
          ),
        ),
      _ => throw FormatException('Invalid SortCriteria JSON: $json'),
    };
  }

  /// Creates a list of sort criteria from query parameters.
  ///
  /// Parses the `sort=field1:asc,field2:desc` format.
  static List<SortCriteria> fromQueryParams(Map<String, String> params) {
    if (params['sort'] case final String sort when sort.isNotEmpty) {
      return sort.split(',').map((part) {
        final order = SortOrder.values.firstWhere(
          (o) => o.code == part.split(':').elementAtOrNull(1),
          orElse: () => SortOrder.ascending,
        );
        return switch (part.trim().split(':')) {
          [final id] => SortCriteria(id: id, order: SortOrder.ascending),
          [final id, _] => SortCriteria(id: id, order: order),
          _ => throw FormatException('Invalid sort parameter: $part'),
        };
      }).toList();
    }
    return [];
  }

  /// Converts multiple criteria to query parameters.
  ///
  /// Format: `sort=field1:asc,field2:desc`
  static Map<String, String> listToQueryParams(List<SortCriteria> criteria) {
    final active = criteria.where((c) => c.isActive).toList();
    if (active.isEmpty) return {};
    return {'sort': active.map((c) => c.toQueryParam()).join(',')};
  }

  /// The sort field identifier.
  final String id;

  /// The sort order.
  final SortOrder order;

  /// Whether this is an active sort (not none).
  bool get isActive => order != SortOrder.none;

  /// Converts this criterion to query parameter format.
  ///
  /// Format: `id:asc` or `id:desc`
  String toQueryParam() => '$id:${order.code}';

  /// Converts this criterion to a JSON-compatible map.
  Map<String, dynamic> toJson() => {'id': id, 'order': order.code};

  @override
  String toString() => 'SortCriteria($id: ${order.code})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SortCriteria && id == other.id && order == other.order;

  @override
  int get hashCode => Object.hash(id, order);
}
