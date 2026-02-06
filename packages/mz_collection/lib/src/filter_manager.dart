// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

/// {@template mz_collection.filter_manager_library}
/// A pure Dart filtering system with multi-value filters and boolean
/// composition.
///
/// ## Why FilterManager?
///
/// Traditional filtering approaches fall short when applications need:
///
/// - **Multi-value selection** - Users select multiple values per filter
///   (e.g., show tickets assigned to Alice OR Bob)
/// - **Dynamic composition** - Combine filters with AND/OR/NOT logic at
///   runtime without rebuilding filter structures
/// - **Independent reactivity** - Each filter notifies its own listeners
///   without coupling to a specific state management solution
/// - **Framework independence** - Filter logic that works in Flutter, CLI
///   tools, servers, or any Dart environment
///
/// FilterManager combines what typically requires separate filtering,
/// composition, and state management packages into a unified solution.
///
/// ## Key Features
///
/// ```text
/// ┌───────────────────────────┬──────────────────────────────────────┐
/// │          Feature          │            Description               │
/// ├───────────────────────────┼──────────────────────────────────────┤
/// │ Multi-value filters       │ Each filter holds Set<V> of values   │
/// │ FilterMode (any/all)      │ OR/AND logic within a single filter  │
/// │ CompositionMode (and/or)  │ OR/AND logic between filters         │
/// │ Expression composition    │ Complex (A & B) | ~C expressions     │
/// │ Pure Dart Listenable      │ No Flutter dependency required       │
/// │ Single/multi select       │ Radio button or checkbox behavior    │
/// │ Type-safe predicates      │ FilterPredicate<T, V> per filter     │
/// └───────────────────────────┴──────────────────────────────────────┘
/// ```
///
/// ## System Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────────┐
/// │                       FilterManager<T>                            │
/// │                                                                   │
/// │  ┌─────────────────────────────────────────────────────────────┐  │
/// │  │                     Filter Registry                         │  │
/// │  │                                                             │  │
/// │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │  │
/// │  │  │ Filter<T,V1> │  │ Filter<T,V2> │  │ Filter<T,V3> │       │  │
/// │  │  │  id: status  │  │ id: assignee │  │ id: priority │       │  │
/// │  │  │  values: {…} │  │  values: {…} │  │  values: {…} │       │  │
/// │  │  │  mode: any   │  │  mode: all   │  │  mode: any   │       │  │
/// │  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │  │
/// │  │         │                 │                 │               │  │
/// │  └─────────┼─────────────────┼─────────────────┼───────────────┘  │
/// │            │                 │                 │                  │
/// │            ▼                 ▼                 ▼                  │
/// │  ┌─────────────────────────────────────────────────────────────┐  │
/// │  │                   Composition Engine                        │  │
/// │  │                                                             │  │
/// │  │  Default: FilterAnd([status, assignee, priority])           │  │
/// │  │     -or-                                                    │  │
/// │  │  Custom:  (status & assignee) | ~priority                   │  │
/// │  │                                                             │  │
/// │  └─────────────────────────────────────────────────────────────┘  │
/// │                              │                                    │
/// │                              ▼                                    │
/// │                   ┌─────────────────────┐                         │
/// │                   │   apply(T item)     │ ← Single evaluation     │
/// │                   │   filter(items)     │   point for all items   │
/// │                   └─────────────────────┘                         │
/// └───────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Filter Evaluation Flow
///
/// ```text
///                         Item to evaluate
///                                │
///                                ▼
///             ┌──────────────────────────────────────────┐
///             │         Filter.apply(item)               │
///             │                                          │
///             │  values.isEmpty? ───yes───► return true. │
///             │         │                                │
///             │        no                                │
///             │         ▼                                │
///             │  ┌───────────────────────────────┐       │
///             │  │       FilterMode check        │       │
///             │  │                               │       │
///             │  │  any: values.any(test)        │       │
///             │  │  all: values.every(test)      │       │
///             │  └───────────────────────────────┘       │
///             └──────────────────────────────────────────┘
///                                │
///                                ▼
///                          true / false
/// ```
///
/// ## Expression Composition
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────────┐
/// │                   FilterExpression Hierarchy                      │
/// │                                                                   │
/// │                     FilterExpression<T>                           │
/// │                            │                                      │
/// │        ┌───────────────────┼───────────────────┐                  │
/// │        │                   │                   │                  │
/// │        ▼                   ▼                   ▼                  │
/// │  FilterRef<T,V>      FilterAnd<T>        FilterOr<T>              │
/// │  (wraps Filter)      (all must pass)     (any must pass)          │
/// │                            │                   │                  │
/// │                            └─────────┬─────────┘                  │
/// │                                      │                            │
/// │                                      ▼                            │
/// │                              FilterNot<T>                         │
/// │                            (inverts result)                       │
/// │                                                                   │
/// │  Operators:  a & b  →  FilterAnd([a, b])                          │
/// │              a | b  →  FilterOr([a, b])                           │
/// │              ~a     →  FilterNot(a)                               │
/// └───────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Quick Start
///
/// {@tool snippet}
/// Basic filtering with multiple values:
///
/// ```dart
/// // Define a filter for ticket status
/// final statusFilter = Filter<Ticket, Status>(
///   id: 'status',
///   label: 'Status',
///   test: (ticket, status) => ticket.status == status,
/// );
///
/// // Select multiple statuses (OR logic by default)
/// statusFilter.add(Status.open);
/// statusFilter.add(Status.inProgress);
///
/// // Filter tickets - passes if status is open OR inProgress
/// final filtered = tickets.where(statusFilter.apply).toList();
/// ```
/// {@end-tool}
///
/// {@tool snippet}
/// Managing multiple filters together:
///
/// ```dart
/// final manager = FilterManager<Ticket>(
///   filters: [statusFilter, assigneeFilter, priorityFilter],
///   defaultMode: CompositionMode.and, // All filters must pass
/// );
///
/// // Add filter values
/// manager['status']?.add(Status.open);
/// manager.getFilter<User>('assignee')?.add(currentUser);
///
/// // Apply all filters at once
/// final results = tickets.where(manager.apply).toList();
/// ```
/// {@end-tool}
///
/// {@tool snippet}
/// Complex filter expressions using the `.ref` extension:
///
/// ```dart
/// // Use .ref to convert filters to expressions
/// final expression = (statusFilter.ref & assigneeFilter.ref)
///     | priorityFilter.ref;
///
/// manager.setExpression(expression);
///
/// // Now apply uses the custom expression
/// final results = tickets.where(manager.apply).toList();
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [Filter] - Individual filter with multi-value support and change
///   notification.
/// * [FilterExpression] - Base class for composing complex filter logic.
/// * [FilterManager] - Coordinates multiple filters with unified evaluation.
/// * [Listenable] - Pure Dart change notification mixin.
/// {@endtemplate}
library;

import 'package:meta/meta.dart';

import 'core.dart';

export 'core.dart' show Listenable, Listener, TransformSource, ValueListener;

/// {@template mz_collection.filter_predicate}
/// A function type that tests if an item matches a filter value.
///
/// The predicate receives the [item] being tested and the filter [value]
/// to test against. Returns `true` if the item matches, `false` otherwise.
///
/// {@tool snippet}
/// Common predicate patterns:
///
/// ```dart
/// // Direct equality
/// FilterPredicate<Ticket, Status> statusTest =
///     (ticket, status) => ticket.status == status;
///
/// // Property comparison
/// FilterPredicate<Ticket, User> assigneeTest =
///     (ticket, user) => ticket.assignee?.id == user.id;
///
/// // Collection membership
/// FilterPredicate<Ticket, String> tagTest =
///     (ticket, tag) => ticket.tags.contains(tag);
///
/// // Range check
/// FilterPredicate<Product, PriceRange> priceTest =
///     (product, range) =>
///         product.price >= range.min && product.price <= range.max;
/// ```
/// {@end-tool}
/// {@endtemplate}
typedef FilterPredicate<T, V> = bool Function(T item, V value);

/// {@template mz_collection.filter_mode}
/// How multiple values within a single [Filter] are combined.
///
/// When a filter has multiple selected values (e.g., filtering by colors
/// `[red, blue]`), FilterMode determines the matching logic:
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────┐
/// │                   FilterMode Comparison                       │
/// │                                                               │
/// │  FilterMode.any (default)       FilterMode.all                │
/// │  ────────────────────────       ───────────────               │
/// │                                                               │
/// │  values: [red, blue]            values: [urgent, bug]         │
/// │                                                               │
/// │  Item passes if:                Item passes if:               │
/// │  color == red OR blue           tags.contains(urgent)         │
/// │                                 AND tags.contains(bug)        │
/// │                                                               │
/// │  Use for:                       Use for:                      │
/// │  • Single-value properties      • Multi-value properties      │
/// │  • "Show any of these"          • "Must have all of these"    │
/// │  • Status, assignee, type       • Tags, labels, categories    │
/// └───────────────────────────────────────────────────────────────┘
/// ```
/// {@endtemplate}
enum FilterMode {
  /// {@template mz_collection.filter_mode_any}
  /// Item passes if it matches ANY selected value (OR logic).
  ///
  /// This is the default mode. Use this when filtering by single-value
  /// properties where an item should appear if it matches at least one
  /// selected value.
  ///
  /// {@tool snippet}
  /// Filtering tickets by multiple statuses:
  ///
  /// ```dart
  /// final statusFilter = Filter<Ticket, Status>(
  ///   id: 'status',
  ///   test: (ticket, status) => ticket.status == status,
  ///   mode: FilterMode.any, // Default
  /// );
  ///
  /// statusFilter.add(Status.open);
  /// statusFilter.add(Status.inProgress);
  ///
  /// // Ticket passes if status is open OR inProgress
  /// final passes = statusFilter.apply(ticket);
  /// ```
  /// {@end-tool}
  /// {@endtemplate}
  any,

  /// {@template mz_collection.filter_mode_all}
  /// Item passes if it matches ALL selected values (AND logic).
  ///
  /// Use this when filtering by multi-value properties where an item
  /// must satisfy every selected filter value to pass.
  ///
  /// {@tool snippet}
  /// Filtering tickets by required tags:
  ///
  /// ```dart
  /// final tagFilter = Filter<Ticket, String>(
  ///   id: 'tags',
  ///   test: (ticket, tag) => ticket.tags.contains(tag),
  ///   mode: FilterMode.all,
  /// );
  ///
  /// tagFilter.add('urgent');
  /// tagFilter.add('bug');
  ///
  /// // Ticket passes only if it has BOTH urgent AND bug tags
  /// final passes = tagFilter.apply(ticket);
  /// ```
  /// {@end-tool}
  /// {@endtemplate}
  all,
}

/// {@template mz_collection.composition_mode}
/// How filters in a [FilterManager] are combined by default.
///
/// This determines the boolean logic between different filters when no
/// custom [FilterExpression] is set.
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────┐
/// │                 CompositionMode Comparison                    │
/// │                                                               │
/// │  CompositionMode.and (default)  CompositionMode.or            │
/// │  ────────────────────────────   ─────────────────             │
/// │                                                               │
/// │  Filters: [status, assignee]    Filters: [status, assignee]   │
/// │                                                               │
/// │  Item passes if:                Item passes if:               │
/// │  status.apply(item) == true     status.apply(item) == true    │
/// │  AND                            OR                            │
/// │  assignee.apply(item) == true   assignee.apply(item) == true  │
/// │                                                               │
/// │  Typical use:                   Typical use:                  │
/// │  • Narrow down results          • Expand search               │
/// │  • Intersection filtering       • Union filtering             │
/// │  • "Match all criteria"         • "Match any criterion"       │
/// └───────────────────────────────────────────────────────────────┘
/// ```
/// {@endtemplate}
enum CompositionMode {
  /// {@template mz_collection.composition_mode_and}
  /// All filters must pass (AND logic between filters).
  ///
  /// This is the default mode. An item passes the [FilterManager] only
  /// if it passes ALL active filters. Empty filters are skipped.
  /// {@endtemplate}
  and,

  /// {@template mz_collection.composition_mode_or}
  /// Any filter must pass (OR logic between filters).
  ///
  /// An item passes the [FilterManager] if it passes ANY active filter.
  /// Empty filters are skipped.
  /// {@endtemplate}
  or,
}

/// {@template mz_collection.filter}
/// A filter that tests items against multiple selectable values.
///
/// A [Filter] represents a single filtering criterion (like "assignee" or
/// "status") that can have multiple active values. Users can add or remove
/// values, and the filter determines how to combine them using [FilterMode].
///
/// ## Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────┐
/// │                     Filter<Ticket, User>                      │
/// │                                                               │
/// │  id: 'assignee'           label: 'Assignee'                   │
/// │  mode: FilterMode.any     singleSelect: false                 │
/// │                                                               │
/// │  ┌─────────────────────────────────────────────────────────┐  │
/// │  │             _values: Set<User>                          │  │
/// │  │                                                         │  │
/// │  │  [User(alice)]  [User(bob)]  [User(carol)]              │  │
/// │  └─────────────────────────────────────────────────────────┘  │
/// │                            │                                  │
/// │                      apply(ticket)                            │
/// │                            │                                  │
/// │                            ▼                                  │
/// │   mode == any ? values.any(test) : values.every(test)         │
/// │                            │                                  │
/// │                            ▼                                  │
/// │                      true / false                             │
/// └───────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Single vs Multi Select
///
/// ```text
/// ┌───────────────────────────────┬───────────────────────────────┐
/// │     singleSelect: false       │      singleSelect: true       │
/// │     (checkbox behavior)       │      (radio button behavior)  │
/// ├───────────────────────────────┼───────────────────────────────┤
/// │  filter.add(a)  → {a}         │  filter.add(a)  → {a}         │
/// │  filter.add(b)  → {a, b}      │  filter.add(b)  → {b}         │
/// │  filter.add(c)  → {a, b, c}   │  filter.add(c)  → {c}         │
/// └───────────────────────────────┴───────────────────────────────┘
/// ```
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Creating and using a status filter:
///
/// ```dart
/// final statusFilter = Filter<Ticket, Status>(
///   id: 'status',
///   label: 'Status',
///   test: (ticket, status) => ticket.status == status,
/// );
///
/// // Add values to filter by
/// statusFilter.add(Status.open);
/// statusFilter.add(Status.inProgress);
///
/// // Check if a ticket passes (matches Status.open OR Status.inProgress)
/// final passes = statusFilter.apply(ticket);
///
/// // Filter a list
/// final openOrInProgress = tickets.where(statusFilter.apply).toList();
/// ```
/// {@end-tool}
///
/// ## Listening to Changes
///
/// {@tool snippet}
/// React to filter value changes:
///
/// ```dart
/// final filter = Filter<Ticket, Status>(
///   id: 'status',
///   test: (ticket, status) => ticket.status == status,
///   onChanged: (f) => print('Filter changed: ${f.values}'),
/// );
///
/// // Also supports Listenable pattern
/// filter.addChangeListener(() {
///   print('Values: ${filter.values}');
///   refilterData();
/// });
///
/// filter.add(Status.open); // Both callbacks fire
/// ```
/// {@end-tool}
///
/// ## Toggle Behavior
///
/// {@tool snippet}
/// Toggle values for chip-based UIs:
///
/// ```dart
/// // In a filter chip onTap handler
/// void onChipTap(Status status) {
///   final isNowSelected = statusFilter.toggle(status);
///   // UI will update via listener
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [FilterMode] - Controls AND/OR logic within the filter.
/// * [FilterManager] - Coordinates multiple filters together.
/// * [FilterRef] - Wraps a Filter for use in expressions.
/// {@endtemplate}
@immutable
class Filter<T, V> with Listenable {
  /// {@template mz_collection.filter_constructor}
  /// Creates a new filter.
  ///
  /// The [id] is a unique identifier used to retrieve this filter from
  /// a [FilterManager].
  ///
  /// The [test] predicate determines if an item matches a value.
  ///
  /// The optional [label] provides a display name for UI presentation.
  ///
  /// The [mode] determines how multiple values are combined:
  /// - [FilterMode.any] (default): item passes if it matches ANY value
  /// - [FilterMode.all]: item passes if it matches ALL values
  ///
  /// If [singleSelect] is true, adding a new value clears existing values
  /// first, enforcing radio-button behavior.
  ///
  /// Initial [values] can be provided to pre-select values.
  ///
  /// The [onChanged] callback is invoked whenever values change.
  ///
  /// The [source] determines where filtering is processed:
  /// - [TransformSource.local] (default): filter locally via [apply]
  /// - [TransformSource.remote]: send to server, no local filtering
  /// - [TransformSource.combined]: both local and remote
  /// {@endtemplate}
  Filter({
    required this.id,
    required this.test,
    this.label,
    this.mode = FilterMode.any,
    this.singleSelect = false,
    this.source = TransformSource.local,
    Iterable<V>? values,
    this.onChanged,
  }) : _values = {...?values};

  /// Unique identifier for this filter.
  ///
  /// Used by [FilterManager] to store and retrieve filters.
  final String id;

  /// Optional display label for UI presentation.
  ///
  /// If null, the [id] can be used as a fallback display name.
  final String? label;

  /// The predicate function to test items against values.
  ///
  /// Called once per selected value when [apply] is invoked.
  final FilterPredicate<T, V> test;

  /// How to combine multiple selected values.
  ///
  /// See [FilterMode] for details on each mode.
  final FilterMode mode;

  /// Whether only one value can be selected at a time.
  ///
  /// When true, [add] clears existing values before adding the new one.
  final bool singleSelect;

  /// Determines where this filter's processing occurs.
  ///
  /// The controller uses this to decide whether to:
  /// - Apply the filter locally via [apply]
  /// - Send filter parameters to the remote data source
  /// - Do both
  ///
  /// See [TransformSource] for details on each mode.
  final TransformSource source;

  /// Whether this filter requires server processing.
  ///
  /// True for [TransformSource.remote] and [TransformSource.combined].
  bool get isRemote =>
      source == TransformSource.remote || source == TransformSource.combined;

  /// Whether this filter processes locally.
  ///
  /// True for [TransformSource.local] and [TransformSource.combined].
  bool get isLocal =>
      source == TransformSource.local || source == TransformSource.combined;

  /// Optional callback invoked when values change.
  ///
  /// Called with this filter as the argument after any modification.
  final ValueListener<Filter<T, V>>? onChanged;

  final Set<V> _values;

  /// Returns an unmodifiable view of the selected values.
  ///
  /// The returned set cannot be modified directly; use [add], [remove],
  /// [toggle], or [clear] to modify values.
  Set<V> get values => Set.unmodifiable(_values);

  /// Returns the number of selected values.
  int get count => _values.length;

  /// Returns true if no values are selected.
  ///
  /// An empty filter passes all items in [apply].
  bool get isEmpty => _values.isEmpty;

  /// Returns true if any values are selected.
  bool get isNotEmpty => _values.isNotEmpty;

  /// Returns true if [value] is currently selected.
  bool contains(V value) => _values.contains(value);

  /// {@template mz_collection.filter_apply}
  /// Returns true if [item] passes this filter.
  ///
  /// If [source] is [TransformSource.remote], always returns true
  /// (remote-only filters don't filter locally).
  ///
  /// If no values are selected, returns true (empty filter passes all).
  ///
  /// Otherwise, uses [mode] to combine the selected values:
  /// - [FilterMode.any]: passes if item matches ANY value (OR)
  /// - [FilterMode.all]: passes if item matches ALL values (AND)
  /// {@endtemplate}
  bool apply(T item) {
    // Remote-only filters don't filter locally
    if (source == TransformSource.remote) return true;
    if (_values.isEmpty) return true;
    return switch (mode) {
      FilterMode.any => _values.any((v) => test(item, v)),
      FilterMode.all => _values.every((v) => test(item, v)),
    };
  }

  /// {@template mz_collection.filter_add}
  /// Adds [value] to the selected values.
  ///
  /// If [singleSelect] is true, clears existing values first.
  ///
  /// Returns true if the value was added (was not already present).
  /// Returns false if the value was already selected (no change made).
  ///
  /// Notifies listeners only when the value set actually changes.
  /// {@endtemplate}
  bool add(V value) {
    if (singleSelect) _values.clear();
    if (_values.add(value)) {
      _notify();
      return true;
    }
    return false;
  }

  /// {@template mz_collection.filter_remove}
  /// Removes [value] from the selected values.
  ///
  /// Returns true if the value was removed (was present).
  /// Returns false if the value wasn't selected (no change made).
  ///
  /// Notifies listeners only when the value set actually changes.
  /// {@endtemplate}
  bool remove(V value) {
    if (_values.remove(value)) {
      _notify();
      return true;
    }
    return false;
  }

  /// {@template mz_collection.filter_toggle}
  /// Toggles [value] in the selected values.
  ///
  /// If present, removes it. If absent, adds it.
  ///
  /// Returns true if value is now selected, false if now unselected.
  ///
  /// Always notifies listeners since the state always changes.
  /// {@endtemplate}
  bool toggle(V value) {
    _values.contains(value) ? _values.remove(value) : _values.add(value);
    _notify();
    return _values.contains(value);
  }

  /// {@template mz_collection.filter_clear}
  /// Clears all selected values.
  ///
  /// After clearing, [apply] will return true for all items.
  ///
  /// Notifies listeners only if there were values to clear.
  /// {@endtemplate}
  void clear() {
    if (_values.isEmpty) return;
    _values.clear();
    _notify();
  }

  /// {@template mz_collection.filter_set_all}
  /// Replaces all selected values with [values].
  ///
  /// This is equivalent to calling [clear] followed by adding each value,
  /// but only notifies listeners once.
  ///
  /// If [singleSelect] is true, only the last value in [values] is kept.
  ///
  /// {@tool snippet}
  /// Bulk setting filter values:
  ///
  /// ```dart
  /// // Replace all selected statuses at once
  /// statusFilter.setAll([Status.open, Status.inProgress]);
  ///
  /// // Useful for restoring filter state
  /// final savedValues = [Status.open, Status.closed];
  /// statusFilter.setAll(savedValues);
  /// ```
  /// {@end-tool}
  /// {@endtemplate}
  void setAll(Iterable<V> values) {
    _values.clear();
    if (singleSelect) {
      final last = values.lastOrNull;
      if (last != null) _values.add(last);
    } else {
      _values.addAll(values);
    }
    _notify();
  }

  void _notify() {
    onChanged?.call(this);
    notifyChanged();
  }

  /// Creates a copy of this filter with optional overrides.
  ///
  /// The new filter has its own value set and listeners.
  Filter<T, V> copyWith({
    String? id,
    String? label,
    FilterPredicate<T, V>? test,
    FilterMode? mode,
    bool? singleSelect,
    TransformSource? source,
    Iterable<V>? values,
  }) {
    return Filter<T, V>(
      id: id ?? this.id,
      label: label ?? this.label,
      test: test ?? this.test,
      mode: mode ?? this.mode,
      singleSelect: singleSelect ?? this.singleSelect,
      source: source ?? this.source,
      values: values ?? _values,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Filter<T, V> && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Filter(id: $id, values: ${_values.length})';
}

/// {@template mz_collection.filter_expression}
/// Base class for filter expressions that enable complex composition.
///
/// Filter expressions allow you to combine filters with AND, OR, and NOT
/// operators to create complex filtering logic beyond the simple composition
/// modes of [FilterManager].
///
/// ## Expression Tree
///
/// ```text
///                    FilterExpression<T>
///                           │
///        ┌──────────────────┼──────────────────┐
///        │                  │                  │
///        ▼                  ▼                  ▼
///   FilterRef<T,V>    FilterAnd<T>       FilterOr<T>
///   wraps Filter      all must pass      any must pass
///        │                  │                  │
///        │                  └────────┬─────────┘
///        │                           │
///        │                           ▼
///        │                    FilterNot<T>
///        │                   inverts result
///        │
///        └──► Special: FilterAlways<T>, FilterNever<T>
/// ```
///
/// ## Operator Support
///
/// Expressions can be composed using Dart operators:
///
/// ```text
/// ┌────────────┬─────────────────────┬─────────────────────────┐
/// │  Operator  │      Result         │        Meaning          │
/// ├────────────┼─────────────────────┼─────────────────────────┤
/// │   a & b    │  FilterAnd([a, b])  │  Both must pass         │
/// │   a | b    │  FilterOr([a, b])   │  Either can pass        │
/// │    ~a      │  FilterNot(a)       │  Inverts the result     │
/// └────────────┴─────────────────────┴─────────────────────────┘
/// ```
///
/// ## Building Complex Expressions
///
/// {@tool snippet}
/// Compose filters with boolean logic using the `.ref` extension:
///
/// ```dart
/// // Simple AND
/// final expr1 = statusFilter.ref & assigneeFilter.ref;
///
/// // Simple OR
/// final expr2 = statusFilter.ref | priorityFilter.ref;
///
/// // NOT
/// final expr3 = ~priorityFilter.ref;
///
/// // Complex: (status AND assignee) OR (NOT priority)
/// final expr4 = (statusFilter.ref & assigneeFilter.ref) | ~priorityFilter.ref;
///
/// // Apply to FilterManager
/// manager.setExpression(expr4);
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [FilterRef] - Wraps a [Filter] for use in expressions.
/// * [FilterAnd] - All sub-expressions must pass.
/// * [FilterOr] - Any sub-expression must pass.
/// * [FilterNot] - Inverts the result of an expression.
/// {@endtemplate}
abstract class FilterExpression<T> {
  /// Creates a filter expression.
  const FilterExpression();

  /// Evaluates this expression against [item].
  ///
  /// Returns true if the item passes this expression, false otherwise.
  bool apply(T item);

  /// Creates an AND expression combining this with [other].
  ///
  /// The resulting expression passes only if both this AND [other] pass.
  FilterExpression<T> operator &(FilterExpression<T> other) =>
      FilterAnd<T>([this, other]);

  /// Creates an OR expression combining this with [other].
  ///
  /// The resulting expression passes if either this OR [other] passes.
  FilterExpression<T> operator |(FilterExpression<T> other) =>
      FilterOr<T>([this, other]);

  /// Creates a NOT expression inverting this expression.
  ///
  /// The resulting expression passes if this expression fails,
  /// and fails if this expression passes.
  // ignore: use_to_and_as_if_applicable
  FilterExpression<T> operator ~() => FilterNot<T>(this);
}

/// {@template mz_collection.filter_ref}
/// A filter expression that wraps a [Filter].
///
/// This allows filters to be used in complex expressions while maintaining
/// their individual state and listener notifications.
///
/// {@tool snippet}
/// Wrapping filters for expression composition:
///
/// ```dart
/// final statusFilter = Filter<Ticket, Status>(...);
/// final assigneeFilter = Filter<Ticket, User>(...);
///
/// // Wrap in FilterRef for expression composition
/// final status = FilterRef(statusFilter);
/// final assignee = FilterRef(assigneeFilter);
///
/// // Now use operators
/// final expression = status & assignee;
/// ```
/// {@end-tool}
///
/// **Tip:** Use the [FilterToExpression.ref] extension for a more concise
/// syntax: `statusFilter.ref & assigneeFilter.ref`.
/// {@endtemplate}
class FilterRef<T, V> extends FilterExpression<T> {
  /// Creates a reference to [filter].
  const FilterRef(this.filter);

  /// The filter being referenced.
  final Filter<T, V> filter;

  @override
  bool apply(T item) => filter.apply(item);

  @override
  String toString() => 'FilterRef(${filter.id})';
}

/// {@template mz_collection.filter_and}
/// A filter expression where ALL sub-expressions must pass.
///
/// Evaluates sub-expressions in order and short-circuits on the first
/// failure (returns false immediately without evaluating remaining
/// expressions).
///
/// {@tool snippet}
/// Creating AND expressions:
///
/// ```dart
/// // Using constructor
/// final expr = FilterAnd([
///   FilterRef(statusFilter),
///   FilterRef(assigneeFilter),
///   FilterRef(priorityFilter),
/// ]);
///
/// // Using operator (creates nested structure for multiple)
/// final expr2 = status & assignee & priority;
/// // Equivalent to: FilterAnd([FilterAnd([status, assignee]), priority])
/// ```
/// {@end-tool}
/// {@endtemplate}
class FilterAnd<T> extends FilterExpression<T> {
  /// Creates an AND expression from [expressions].
  ///
  /// All expressions in the list must pass for the AND to pass.
  const FilterAnd(this.expressions);

  /// The sub-expressions that must all pass.
  final List<FilterExpression<T>> expressions;

  @override
  bool apply(T item) => expressions.every((e) => e.apply(item));

  @override
  String toString() => 'FilterAnd(${expressions.length})';
}

/// {@template mz_collection.filter_or}
/// A filter expression where ANY sub-expression must pass.
///
/// Evaluates sub-expressions in order and short-circuits on the first
/// success (returns true immediately without evaluating remaining
/// expressions).
///
/// {@tool snippet}
/// Creating OR expressions:
///
/// ```dart
/// // Using constructor
/// final expr = FilterOr([
///   FilterRef(statusFilter),
///   FilterRef(priorityFilter),
/// ]);
///
/// // Using operator
/// final expr2 = status | priority;
/// ```
/// {@end-tool}
/// {@endtemplate}
class FilterOr<T> extends FilterExpression<T> {
  /// Creates an OR expression from [expressions].
  ///
  /// At least one expression must pass for the OR to pass.
  const FilterOr(this.expressions);

  /// The sub-expressions where at least one must pass.
  final List<FilterExpression<T>> expressions;

  @override
  bool apply(T item) => expressions.any((e) => e.apply(item));

  @override
  String toString() => 'FilterOr(${expressions.length})';
}

/// {@template mz_collection.filter_not}
/// A filter expression that inverts another expression.
///
/// Returns true when the wrapped expression returns false, and vice versa.
///
/// {@tool snippet}
/// Creating NOT expressions:
///
/// ```dart
/// // Using constructor
/// final notPriority = FilterNot(FilterRef(priorityFilter));
///
/// // Using operator
/// final notPriority2 = ~FilterRef(priorityFilter);
///
/// // Complex: items that pass status but NOT priority
/// final expr = status & ~priority;
/// ```
/// {@end-tool}
/// {@endtemplate}
class FilterNot<T> extends FilterExpression<T> {
  /// Creates a NOT expression for [expression].
  const FilterNot(this.expression);

  /// The expression to invert.
  final FilterExpression<T> expression;

  @override
  bool apply(T item) => !expression.apply(item);

  @override
  String toString() => 'FilterNot($expression)';
}

/// {@template mz_collection.filter_always}
/// A filter expression that always passes.
///
/// Useful as a default expression or identity element in filter chains.
///
/// This is what [FilterManager] uses internally when no filters are active.
/// {@endtemplate}
class FilterAlways<T> extends FilterExpression<T> {
  /// Creates an always-pass expression.
  const FilterAlways();

  @override
  bool apply(T item) => true;

  @override
  String toString() => 'FilterAlways';
}

/// {@template mz_collection.filter_never}
/// A filter expression that never passes.
///
/// Useful for testing or as an explicit "no results" filter.
/// {@endtemplate}
class FilterNever<T> extends FilterExpression<T> {
  /// Creates a never-pass expression.
  const FilterNever();

  @override
  bool apply(T item) => false;

  @override
  String toString() => 'FilterNever';
}

/// Extension to convert [Filter] to [FilterRef] for expression composition.
///
/// This extension provides a convenient way to create filter expressions
/// without manually wrapping filters in [FilterRef].
///
/// {@tool snippet}
/// Using the ref extension for composition:
///
/// ```dart
/// final statusFilter = Filter<Ticket, Status>(...);
/// final assigneeFilter = Filter<Ticket, User>(...);
/// final priorityFilter = Filter<Ticket, Priority>(...);
///
/// // Instead of verbose FilterRef wrapping:
/// final expr1 = FilterRef(statusFilter) & FilterRef(assigneeFilter);
///
/// // Use the concise .ref getter:
/// final expr2 = statusFilter.ref & assigneeFilter.ref;
///
/// // Complex expressions become readable:
/// final expr3 = (statusFilter.ref & assigneeFilter.ref) | ~priorityFilter.ref;
/// ```
/// {@end-tool}
extension FilterToExpression<T, V> on Filter<T, V> {
  /// Returns a [FilterRef] wrapping this filter for use in expressions.
  ///
  /// This enables using filter composition operators (`&`, `|`, `~`)
  /// directly from filter instances.
  FilterRef<T, V> get ref => FilterRef<T, V>(this);
}

// ============================================================================
// Search Filter
// ============================================================================

/// {@template mz_collection.values_retriever}
/// A function type that retrieves searchable string values from an item.
///
/// The retriever receives the [item] being searched and returns an iterable
/// of string values to search within.
///
/// {@tool snippet}
/// Common retriever patterns:
///
/// ```dart
/// // Single field
/// ValuesRetriever<User> nameRetriever = (user) => [user.name];
///
/// // Multiple fields
/// ValuesRetriever<User> multiRetriever = (user) => [
///   user.name,
///   user.email,
///   user.department,
/// ];
///
/// // Nested/computed values
/// ValuesRetriever<Ticket> ticketRetriever = (ticket) => [
///   ticket.title,
///   ticket.description,
///   ticket.assignee?.name,
///   ...ticket.tags,
/// ];
/// ```
/// {@end-tool}
/// {@endtemplate}
typedef ValuesRetriever<T> = Iterable<String?> Function(T item);

/// {@template mz_collection.search_filter}
/// A specialized filter for text-based searching.
///
/// Unlike regular filters that test against a set of discrete values,
/// a [SearchFilter] tests items against a text query using substring
/// matching across multiple searchable fields.
///
/// ## Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────┐
/// │                    SearchFilter<Ticket>                       │
/// │                                                               │
/// │  id: 'search'          query: 'bug fix'                       │
/// │  source: TransformSource.local                                │
/// │                                                               │
/// │  valuesRetriever: (ticket) => [                               │
/// │    ticket.title,                                              │
/// │    ticket.description,                                        │
/// │    ticket.assignee?.name,                                     │
/// │  ]                                                            │
/// │                                                               │
/// │  ┌─────────────────────────────────────────────────────────┐  │
/// │  │             apply(ticket)                               │  │
/// │  │                                                         │  │
/// │  │  1. Extract: values = valuesRetriever(ticket)           │  │
/// │  │  2. Match: values.any(v => v.contains(query))           │  │
/// │  │  3. Return: true if any value contains query            │  │
/// │  └─────────────────────────────────────────────────────────┘  │
/// └───────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Search Modes
///
/// ```text
/// ┌──────────────────────┬────────────────────────────────────────────┐
/// │        Mode          │              Behavior                      │
/// ├──────────────────────┼────────────────────────────────────────────┤
/// │ TransformSource.local  │ Filters locally using valuesRetriever      │
/// │ TransformSource.remote │ Query sent to server, no local filtering   │
/// │ TransformSource.combined│ Both local filtering and remote query     │
/// └──────────────────────┴────────────────────────────────────────────┘
/// ```
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Creating a search filter:
///
/// ```dart
/// final searchFilter = SearchFilter<Ticket>(
///   id: 'search',
///   valuesRetriever: (ticket) => [
///     ticket.title,
///     ticket.description,
///     ticket.assignee?.name,
///   ],
/// );
///
/// // Set search query
/// searchFilter.query = 'urgent bug';
///
/// // Filter items
/// final matches = tickets.where(searchFilter.apply).toList();
///
/// // Or add to FilterManager
/// final manager = FilterManager<Ticket>(
///   filters: [statusFilter, searchFilter],
/// );
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [Filter] - Base filter class for discrete value filtering.
/// * [FilterManager] - Coordinates multiple filters including search.
/// {@endtemplate}
class SearchFilter<T> extends Filter<T, String> {
  /// Creates a search filter.
  ///
  /// The [valuesRetriever] extracts searchable strings from each item.
  /// For [TransformSource.remote], valuesRetriever can be a no-op since
  /// filtering happens server-side.
  ///
  /// The [source] determines where filtering occurs:
  /// - [TransformSource.local]: Client-side filtering only
  /// - [TransformSource.remote]: Server-side filtering, no local apply
  /// - [TransformSource.combined]: Both client and server filtering
  SearchFilter({
    required ValuesRetriever<T> valuesRetriever,
    super.id = 'search',
    super.source = TransformSource.local,
    String? query,
    super.label,
    super.onChanged,
  }) : super(
          test: _createSearchTest(valuesRetriever),
          singleSelect: true,
        ) {
    if (query != null && query.isNotEmpty) {
      add(query);
    }
  }

  /// Creates a remote-only search filter.
  ///
  /// This filter always returns true for [apply] since filtering
  /// happens server-side. Use [query] to get the search string for API calls.
  factory SearchFilter.remote({
    String id = 'search',
    String? query,
    String? label,
    ValueListener<Filter<T, String>>? onChanged,
  }) {
    return SearchFilter<T>(
      id: id,
      valuesRetriever: noOpRetriever,
      source: TransformSource.remote,
      query: query,
      label: label,
      onChanged: onChanged,
    );
  }

  /// No-op values retriever for remote-only filters.
  @visibleForTesting
  static Iterable<String?> noOpRetriever(dynamic _) => const [];

  static FilterPredicate<T, String> _createSearchTest<T>(
    ValuesRetriever<T> valuesRetriever,
  ) {
    return (item, query) {
      if (query.isEmpty) return true;
      final queryLower = query.toLowerCase();
      final values = valuesRetriever(item).whereType<String>();
      return values.any((v) => v.toLowerCase().contains(queryLower));
    };
  }

  /// The current search query.
  ///
  /// Setting this replaces any existing query value.
  String get query => values.firstOrNull ?? '';
  set query(String value) {
    clear();
    if (value.isNotEmpty) add(value);
  }

  @override
  String toString() => 'SearchFilter(id: $id, query: $query, mode: $source)';
}

// ============================================================================
// Deprecated Types
// ============================================================================

/// {@macro mz_collection.transform_source}
///
/// **Deprecated:** Use [TransformSource] instead.
@Deprecated('Use TransformSource instead')
typedef SearchMode = TransformSource;

/// {@template mz_collection.filter_manager}
/// Manages multiple filters with composition support.
///
/// A [FilterManager] holds a collection of filters and determines how to
/// combine them when evaluating items. It supports both simple composition
/// (AND/OR all filters via [CompositionMode]) and complex custom expressions
/// (via [setExpression]).
///
/// ## Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────────┐
/// │                     FilterManager<Ticket>                         │
/// │                                                                   │
/// │  defaultMode: CompositionMode.and                                 │
/// │  _customExpression: null (uses defaultMode)                       │
/// │                                                                   │
/// │  ┌─────────────────────────────────────────────────────────────┐  │
/// │  │                _filters: Map<String, Filter>                │  │
/// │  │                                                             │  │
/// │  │  'status' ──► Filter<Ticket, Status>                        │  │
/// │  │                 └─► addChangeListener(_onFilterChanged)     │  │
/// │  │                                                             │  │
/// │  │  'assignee' ──► Filter<Ticket, User>                        │  │
/// │  │                  └─► addChangeListener(_onFilterChanged)    │  │
/// │  │                                                             │  │
/// │  │  'priority' ──► Filter<Ticket, Priority>                    │  │
/// │  │                  └─► addChangeListener(_onFilterChanged)    │  │
/// │  └─────────────────────────────────────────────────────────────┘  │
/// │                              │                                    │
/// │                     _onFilterChanged(filter)                      │
/// │                              │                                    │
/// │                              ▼                                    │
/// │                     notifyChanged()  ──► UI updates               │
/// └───────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Filter Lifecycle
///
/// ```text
///    add(filter)              filter.add(value)          remove(id)
///         │                         │                         │
///         ▼                         ▼                         ▼
///  ┌─────────────┐          ┌─────────────┐          ┌─────────────┐
///  │   Register  │          │   Filter    │          │  Unregister │
///  │   listener  │          │   notifies  │          │   listener  │
///  └──────┬──────┘          └──────┬──────┘          └──────┬──────┘
///         │                        │                        │
///         ▼                        ▼                        ▼
///  notifyChanged()        _onFilterChanged()        notifyChanged()
///         │                        │                        │
///         └────────────────────────┼────────────────────────┘
///                                  ▼
///                           UI rebuilds
/// ```
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Creating and using a filter manager:
///
/// ```dart
/// final manager = FilterManager<Ticket>(
///   filters: [
///     Filter(
///       id: 'status',
///       test: (t, s) => t.status == s,
///     ),
///     Filter(
///       id: 'assignee',
///       test: (t, u) => t.assignee?.id == u.id,
///     ),
///   ],
///   defaultMode: CompositionMode.and,
/// );
///
/// // Add values through the manager
/// manager['status']?.add(Status.open);
/// manager.getFilter<User>('assignee')?.add(currentUser);
///
/// // Filter a list
/// final filtered = tickets.where(manager.apply).toList();
/// ```
/// {@end-tool}
///
/// ## Custom Expressions
///
/// {@tool snippet}
/// Override the default composition with custom logic:
///
/// ```dart
/// // Default: status AND assignee AND priority (all must pass)
///
/// // Custom: (status AND assignee) OR priority using .ref extension
/// manager.setExpression(
///   (manager['status']!.ref & manager['assignee']!.ref)
///       | manager['priority']!.ref,
/// );
///
/// // Revert to default composition
/// manager.setExpression(null);
/// ```
/// {@end-tool}
///
/// ## Listening to Changes
///
/// {@tool snippet}
/// React to any filter change:
///
/// ```dart
/// // Via constructor callback
/// final manager = FilterManager<Ticket>(
///   filters: [...],
///   onChanged: (filter) {
///     print('Filter ${filter.id} changed');
///   },
/// );
///
/// // Via Listenable pattern
/// manager.addChangeListener(() {
///   setState(() {
///     _filteredItems = items.where(manager.apply).toList();
///   });
/// });
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [Filter] - Individual filter that can be added to the manager.
/// * [CompositionMode] - Default AND/OR logic between filters.
/// * [FilterExpression] - For custom composition logic.
/// * [setExpression] - Override default composition with custom logic.
/// {@endtemplate}
class FilterManager<T> with Listenable {
  /// {@template mz_collection.filter_manager_constructor}
  /// Creates a new filter manager.
  ///
  /// Initial [filters] can be provided and will be added immediately.
  ///
  /// The [defaultMode] determines how filters are combined when no custom
  /// expression is set:
  /// - [CompositionMode.and] (default): all filters must pass
  /// - [CompositionMode.or]: any filter must pass
  ///
  /// The [onChanged] callback is invoked when any managed filter changes.
  /// {@endtemplate}
  FilterManager({
    Iterable<Filter<T, dynamic>>? filters,
    this.defaultMode = CompositionMode.and,
    this.onChanged,
  }) {
    filters?.forEach(add);
  }

  /// Default composition mode when no custom expression is set.
  ///
  /// See [CompositionMode] for available modes.
  final CompositionMode defaultMode;

  /// Optional callback invoked when any filter changes.
  ///
  /// The changed filter is passed as the argument.
  final ValueListener<Filter<T, dynamic>>? onChanged;

  final Map<String, Filter<T, dynamic>> _filters = {};
  final Map<String, Listener> _filterListeners = {};

  FilterExpression<T>? _customExpression;

  /// Cached default expression for performance.
  ///
  /// Invalidated when filters are added, removed, or their values change.
  /// This avoids recomputing the expression on every [apply] call.
  FilterExpression<T>? _cachedDefaultExpression;

  /// Returns all filters managed by this manager.
  ///
  /// The returned iterable is a view of the internal collection and
  /// should not be modified.
  Iterable<Filter<T, dynamic>> get filters => _filters.values;

  /// Returns filters that should be processed remotely.
  ///
  /// Includes filters with [TransformSource.remote] or
  /// [TransformSource.combined]. Use this when building API requests.
  Iterable<Filter<T, dynamic>> get remoteFilters =>
      _filters.values.where((f) => f.isRemote);

  /// Returns filters that should be processed locally.
  ///
  /// Includes filters with [TransformSource.local] or
  /// [TransformSource.combined].
  Iterable<Filter<T, dynamic>> get localFilters =>
      _filters.values.where((f) => f.isLocal);

  /// Returns the number of filters in this manager.
  int get filterCount => _filters.length;

  /// Returns the total number of selected values across all filters.
  int get selectedCount => _filters.values.fold(0, (sum, f) => sum + f.count);

  /// Returns true if all filters are empty (no values selected).
  ///
  /// When empty, [apply] returns true for all items.
  bool get isEmpty => _filters.values.every((f) => f.isEmpty);

  /// Returns true if any filter has selected values.
  bool get isNotEmpty => _filters.values.any((f) => f.isNotEmpty);

  /// Returns the filter with the given [id], or null if not found.
  ///
  /// Use [getFilter] for type-safe access with a specific value type.
  Filter<T, dynamic>? operator [](String id) => _filters[id];

  /// Returns the filter with the given [id] cast to [Filter<T, V>].
  ///
  /// Returns null if not found.
  ///
  /// Throws [TypeError] if the filter exists but has a different value type.
  Filter<T, V>? getFilter<V>(String id) => _filters[id] as Filter<T, V>?;

  /// Returns true if a filter with the given [id] exists in this manager.
  bool contains(String id) => _filters.containsKey(id);

  void _onFilterChanged(Filter<T, dynamic> filter) {
    _cachedDefaultExpression = null; // Invalidate cache
    onChanged?.call(filter);
    notifyChanged();
  }

  /// {@template mz_collection.filter_manager_add}
  /// Adds [filter] to this manager.
  ///
  /// If a filter with the same id already exists, it is replaced and
  /// its listener is removed.
  ///
  /// The manager automatically listens to filter changes and notifies
  /// its own listeners when any filter changes.
  /// {@endtemplate}
  void add(Filter<T, dynamic> filter) {
    final oldListener = _filterListeners[filter.id];
    if (oldListener != null) {
      _filters[filter.id]?.removeChangeListener(oldListener);
    }
    _filters[filter.id] = filter;
    void listener() => _onFilterChanged(filter);
    _filterListeners[filter.id] = listener;
    filter.addChangeListener(listener);
    _cachedDefaultExpression = null; // Invalidate cache
    notifyChanged();
  }

  /// Adds multiple [filters] to this manager.
  ///
  /// Equivalent to calling [add] for each filter, but only notifies
  /// listeners once at the end.
  void addAll(Iterable<Filter<T, dynamic>> filters) {
    for (final filter in filters) {
      final oldListener = _filterListeners[filter.id];
      if (oldListener != null) {
        _filters[filter.id]?.removeChangeListener(oldListener);
      }
      _filters[filter.id] = filter;
      void listener() => _onFilterChanged(filter);
      _filterListeners[filter.id] = listener;
      filter.addChangeListener(listener);
    }
    _cachedDefaultExpression = null; // Invalidate cache
    notifyChanged();
  }

  /// {@template mz_collection.filter_manager_remove}
  /// Removes the filter with the given [id].
  ///
  /// Returns the removed filter, or null if no filter with that id exists.
  ///
  /// The filter's listener is removed before returning.
  /// {@endtemplate}
  Filter<T, dynamic>? remove(String id) {
    final filter = _filters.remove(id);
    final listener = _filterListeners.remove(id);
    if (filter != null && listener != null) {
      filter.removeChangeListener(listener);
      _cachedDefaultExpression = null; // Invalidate cache
      notifyChanged();
    }
    return filter;
  }

  /// {@template mz_collection.filter_manager_clear}
  /// Clears all selected values in all filters.
  ///
  /// The filters themselves remain in the manager; only their values
  /// are cleared.
  ///
  /// After clearing, [apply] returns true for all items.
  /// {@endtemplate}
  void clear() {
    for (final filter in _filters.values) {
      filter.clear();
    }
  }

  /// Removes all filters from this manager.
  ///
  /// Unlike [clear], this removes the filter instances themselves.
  /// Listeners are removed from all filters before removal.
  void clearAll() {
    for (final entry in _filters.entries) {
      final listener = _filterListeners[entry.key];
      if (listener != null) {
        entry.value.removeChangeListener(listener);
      }
    }
    _filters.clear();
    _filterListeners.clear();
    _cachedDefaultExpression = null; // Invalidate cache
    notifyChanged();
  }

  /// {@template mz_collection.filter_manager_set_expression}
  /// Sets a custom filter [expression] for complex logic.
  ///
  /// When set, this expression is used instead of [defaultMode] for
  /// combining filters.
  ///
  /// Pass null to revert to using [defaultMode].
  ///
  /// {@tool snippet}
  /// Example custom expressions using the `.ref` extension:
  ///
  /// ```dart
  /// // All filters must pass (same as CompositionMode.and)
  /// manager.setExpression(
  ///   statusFilter.ref & assigneeFilter.ref,
  /// );
  ///
  /// // Complex logic: (A AND B) OR NOT C
  /// manager.setExpression(
  ///   (filterA.ref & filterB.ref) | ~filterC.ref,
  /// );
  ///
  /// // Revert to default
  /// manager.setExpression(null);
  /// ```
  /// {@end-tool}
  /// {@endtemplate}
  void setExpression(FilterExpression<T>? expression) {
    _customExpression = expression;
    _cachedDefaultExpression = null; // Invalidate cache (relevant if reverting)
    notifyChanged();
  }

  FilterExpression<T> get _defaultExpression {
    // Single loop instead of where().map().toList() chain
    final activeFilters = <FilterRef<T, dynamic>>[];
    for (final f in _filters.values) {
      if (f.isNotEmpty) activeFilters.add(f.ref);
    }
    if (activeFilters.isEmpty) return FilterAlways<T>();
    if (activeFilters.length == 1) return activeFilters.first;
    return switch (defaultMode) {
      CompositionMode.and => FilterAnd<T>(activeFilters),
      CompositionMode.or => FilterOr<T>(activeFilters),
    };
  }

  /// {@template mz_collection.filter_manager_apply}
  /// Returns true if [item] passes all active filters.
  ///
  /// If a custom expression was set via [setExpression], uses that.
  /// Otherwise, combines active filters using [defaultMode].
  ///
  /// Empty filters (no selected values) are skipped in the default
  /// expression.
  /// {@endtemplate}
  bool apply(T item) {
    final expression =
        _customExpression ?? (_cachedDefaultExpression ??= _defaultExpression);
    return expression.apply(item);
  }

  /// {@template mz_collection.filter_manager_filter}
  /// Filters [items] and returns only those that pass all active filters.
  ///
  /// This is the recommended way to filter a collection. The manager
  /// encapsulates all filtering logic including custom expressions.
  ///
  /// Returns the original [items] unchanged if:
  /// - No filters are active (all empty)
  /// - All active filters are remote-only ([TransformSource.remote])
  ///
  /// {@tool snippet}
  /// Filtering a collection:
  ///
  /// ```dart
  /// final manager = FilterManager<Ticket>(filters: [...]);
  /// manager['status']?.add(Status.open);
  ///
  /// // Filter returns lazy Iterable
  /// final filtered = manager.filter(tickets);
  ///
  /// // Convert to list if needed
  /// final filteredList = manager.filter(tickets).toList();
  /// ```
  /// {@end-tool}
  /// {@endtemplate}
  Iterable<T> filter(Iterable<T> items) {
    if (isEmpty) return items;
    // Skip iteration if no active local filters
    final hasActiveLocalFilter =
        _filters.values.any((f) => f.isNotEmpty && f.isLocal);
    if (!hasActiveLocalFilter) return items;
    return items.where(apply);
  }

  @override
  void dispose() {
    for (final entry in _filters.entries) {
      final listener = _filterListeners[entry.key];
      if (listener != null) {
        entry.value.removeChangeListener(listener);
      }
      entry.value.dispose();
    }
    _filters.clear();
    _filterListeners.clear();
    _cachedDefaultExpression = null;
    super.dispose();
  }

  @override
  String toString() => 'FilterManager(filters: ${_filters.length}, '
      'selected: $selectedCount)';

  // ===========================================================================
  // State Serialization
  // ===========================================================================

  /// Captures the current filter state for serialization.
  ///
  /// Returns a [FilterSnapshot] containing all filter values that can be
  /// serialized to JSON or a query string for persistence, deep linking,
  /// or sharing.
  ///
  /// {@tool snippet}
  /// Capturing and restoring filter state:
  ///
  /// ```dart
  /// // Capture current state
  /// final snapshot = manager.captureState();
  ///
  /// // Serialize to JSON for storage
  /// final json = snapshot.toJson();
  /// localStorage.setItem('filters', jsonEncode(json));
  ///
  /// // Or convert to URL query string
  /// final url = '/items?${snapshot.toQueryString()}';
  ///
  /// // Later, restore the state
  /// final savedJson = jsonDecode(localStorage.getItem('filters'));
  /// final restored = FilterSnapshot.fromJson(savedJson);
  /// manager.restoreState(restored);
  /// ```
  /// {@end-tool}
  FilterSnapshot captureState() {
    final values = <String, List<dynamic>>{};
    for (final filter in _filters.values) {
      if (filter.isNotEmpty) {
        values[filter.id] = filter.values.toList();
      }
    }
    return FilterSnapshot._(values);
  }

  /// Restores filter state from a [FilterSnapshot].
  ///
  /// Only restores values for filters that exist in this manager.
  /// Filters not present in the snapshot are cleared.
  /// Filter IDs in the snapshot that don't exist in this manager are ignored.
  ///
  /// {@tool snippet}
  /// Restoring filter state from a URL:
  ///
  /// ```dart
  /// // From URL query string
  /// final snapshot = FilterSnapshot.fromQueryString(
  ///   Uri.parse(url).query,
  /// );
  /// manager.restoreState(snapshot);
  ///
  /// // From stored JSON
  /// final snapshot = FilterSnapshot.fromJson(savedJson);
  /// manager.restoreState(snapshot);
  /// ```
  /// {@end-tool}
  void restoreState(FilterSnapshot snapshot) {
    for (final filter in _filters.values) {
      final values = snapshot._values[filter.id];
      if (values != null && values.isNotEmpty) {
        // Convert to a List to avoid CastList issues with generic types
        filter.setAll(values.toList());
      } else {
        filter.clear();
      }
    }
  }
}

// =============================================================================
// Filter Snapshot (Serialization)
// =============================================================================

/// {@template mz_collection.filter_snapshot}
/// A serializable snapshot of filter state.
///
/// Use this to persist filter state, create shareable URLs, or restore
/// filter configurations.
///
/// ## JSON Serialization
///
/// {@tool snippet}
/// Serialize filter state to JSON:
///
/// ```dart
/// final snapshot = manager.captureState();
///
/// // To JSON
/// final json = snapshot.toJson();
/// // Result: {'status': ['active', 'pending'], 'priority': ['high']}
///
/// // From JSON
/// final restored = FilterSnapshot.fromJson(json);
/// ```
/// {@end-tool}
///
/// ## URL Query String
///
/// {@tool snippet}
/// Serialize filter state to URL query string:
///
/// ```dart
/// final snapshot = manager.captureState();
///
/// // To query string
/// final query = snapshot.toQueryString();
/// // Result: 'filter.status=active,pending&filter.priority=high'
///
/// // Build URL
/// final url = '/items?$query';
///
/// // From query string
/// final restored = FilterSnapshot.fromQueryString(query);
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [FilterManager.captureState] - Creates a snapshot from current state.
/// * [FilterManager.restoreState] - Restores state from a snapshot.
/// {@endtemplate}
@immutable
class FilterSnapshot {
  const FilterSnapshot._(this._values);

  /// Creates an empty filter snapshot.
  const FilterSnapshot.empty() : _values = const {};

  /// Creates a filter snapshot from a map of filter values.
  ///
  /// The map keys are filter IDs, and values are lists of selected values.
  factory FilterSnapshot.fromValues(Map<String, List<dynamic>> values) {
    return FilterSnapshot._(Map.unmodifiable(values));
  }

  /// Creates a snapshot from a JSON map.
  ///
  /// The map should have filter IDs as keys and lists of values as values.
  factory FilterSnapshot.fromJson(Map<String, dynamic> json) {
    final values = <String, List<dynamic>>{};
    for (final entry in json.entries) {
      if (entry.value is List) {
        values[entry.key] = (entry.value as List).cast<dynamic>();
      }
    }
    return FilterSnapshot._(Map.unmodifiable(values));
  }

  /// Creates a snapshot from a URL query string.
  ///
  /// Parses parameters with `filter.` prefix.
  /// Values are split by comma and URL-decoded.
  factory FilterSnapshot.fromQueryString(String queryString) {
    if (queryString.isEmpty) return const FilterSnapshot.empty();

    final values = <String, List<dynamic>>{};
    final params = Uri.splitQueryString(queryString);

    for (final entry in params.entries) {
      if (!entry.key.startsWith('filter.')) continue;

      final filterId = entry.key.substring(7); // Remove 'filter.' prefix
      if (filterId.isEmpty) continue;

      final valueStrings = entry.value.split(',');
      values[filterId] = valueStrings.map(_parseValue).toList();
    }

    return FilterSnapshot._(Map.unmodifiable(values));
  }

  final Map<String, List<dynamic>> _values;

  /// Returns the selected values for a filter by [id].
  ///
  /// Returns null if the filter has no selected values in this snapshot.
  List<dynamic>? operator [](String id) => _values[id];

  /// Returns all filter IDs that have values in this snapshot.
  Iterable<String> get filterIds => _values.keys;

  /// Whether this snapshot has any filter values.
  bool get isEmpty => _values.isEmpty;

  /// Whether this snapshot has filter values.
  bool get isNotEmpty => _values.isNotEmpty;

  /// Converts this snapshot to a JSON-serializable map.
  ///
  /// The resulting map can be encoded with `jsonEncode` and stored or
  /// transmitted.
  ///
  /// Note: Filter values must be JSON-serializable (strings, numbers,
  /// booleans, or objects with `toJson` methods).
  Map<String, dynamic> toJson() {
    return {
      for (final entry in _values.entries)
        entry.key: entry.value.map(_valueToJson).toList(),
    };
  }

  /// Converts this snapshot to a URL query string.
  ///
  /// Format: `filter.{id}={value1},{value2}&filter.{id2}={value}`
  ///
  /// Values are URL-encoded. Empty filters are omitted.
  String toQueryString() {
    if (_values.isEmpty) return '';

    final parts = <String>[];
    for (final entry in _values.entries) {
      if (entry.value.isEmpty) continue;
      final encodedValues = entry.value
          .map((v) => Uri.encodeComponent(_valueToString(v)))
          .join(',');
      parts.add('filter.${Uri.encodeComponent(entry.key)}=$encodedValues');
    }
    return parts.join('&');
  }

  /// Converts a value to its JSON representation.
  static dynamic _valueToJson(dynamic value) {
    if (value == null ||
        value is String ||
        value is num ||
        value is bool ||
        value is List ||
        value is Map) {
      return value;
    }
    // Try to call toJson if available.
    try {
      // Uses dynamic call because the value type is unknown at compile time
      // and may or may not have a toJson method.
      // ignore: avoid_dynamic_calls
      return value.toJson();
      // Catches NoSuchMethodError to fall back to toString() for types
      // without toJson().
      // ignore: avoid_catching_errors
    } on NoSuchMethodError {
      return value.toString();
    }
  }

  /// Converts a value to a string for URL encoding.
  static String _valueToString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    // Try to call toJson if available for complex objects.
    try {
      // Uses dynamic call because the value type is unknown at compile time
      // and may or may not have a toJson method.
      // ignore: avoid_dynamic_calls
      return value.toJson().toString();
      // Catches NoSuchMethodError to fall back to toString() for types
      // without toJson().
      // ignore: avoid_catching_errors
    } on NoSuchMethodError {
      return value.toString();
    }
  }

  /// Parses a string value from URL query string.
  ///
  /// Attempts to parse as int, double, or bool. Returns string if no match.
  static dynamic _parseValue(String value) {
    if (value.isEmpty) return value;

    // Try int
    final intValue = int.tryParse(value);
    if (intValue != null) return intValue;

    // Try double
    final doubleValue = double.tryParse(value);
    if (doubleValue != null) return doubleValue;

    // Try bool
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;

    // Return as string
    return value;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FilterSnapshot) return false;
    if (_values.length != other._values.length) return false;
    for (final key in _values.keys) {
      final thisValues = _values[key];
      final otherValues = other._values[key];
      if (thisValues == null || otherValues == null) return false;
      if (thisValues.length != otherValues.length) return false;
      for (var i = 0; i < thisValues.length; i++) {
        if (thisValues[i] != otherValues[i]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        _values.entries.map((e) => Object.hash(e.key, Object.hashAll(e.value))),
      );

  @override
  String toString() => 'FilterSnapshot($_values)';
}

// =============================================================================
// Filter Criteria (Serializable)
// =============================================================================

/// {@template mz_collection.filter_criteria}
/// A serializable filter criterion for page requests.
///
/// Represents a filter's ID and selected values without coupling to the
/// `Filter` class. This enables easy serialization to query parameters,
/// JSON, or any other format.
///
/// ## Query Parameter Format
///
/// {@tool snippet}
/// Converting to query parameters:
///
/// ```dart
/// final criteria =
///     FilterCriteria(id: 'status', values: {'active', 'pending'});
/// final params = criteria.toQueryParams();
/// // Result: {'filter[status]': 'active,pending'}
/// ```
/// {@end-tool}
/// {@endtemplate}
@immutable
class FilterCriteria {
  /// Creates a filter criterion.
  const FilterCriteria({required this.id, required this.values});

  /// Creates a filter criterion from a single value.
  factory FilterCriteria.single(String id, Object? value) =>
      FilterCriteria(id: id, values: {value});

  /// Creates a criterion from a JSON map.
  factory FilterCriteria.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'id': final String id, 'values': final List<dynamic> values} =>
        FilterCriteria(id: id, values: values.toSet()),
      _ => throw FormatException('Invalid FilterCriteria JSON: $json'),
    };
  }

  /// Creates a filter criterion from query parameters.
  ///
  /// Parses the `filter[id]` format used by [toQueryParams].
  static List<FilterCriteria> fromQueryParams(Map<String, String> params) {
    final criteria = <FilterCriteria>[];
    for (final entry in params.entries) {
      final match = RegExp(r'^filter\[(.+)\]$').firstMatch(entry.key);
      if (match != null) {
        final id = match.group(1)!;
        final values = entry.value.split(',').map((v) => v.trim()).toSet();
        criteria.add(FilterCriteria(id: id, values: values));
      }
    }
    return criteria;
  }

  /// The filter identifier.
  final String id;

  /// The selected values for this filter.
  final Set<Object?> values;

  /// Whether this criterion has any values.
  bool get isNotEmpty => values.isNotEmpty;

  /// Whether this criterion has no values.
  bool get isEmpty => values.isEmpty;

  /// Converts this criterion to query parameters.
  ///
  /// Format: `filter[id]=value1,value2,...`
  Map<String, String> toQueryParams() {
    if (values.isEmpty) return {};
    return {'filter[$id]': values.map((v) => v?.toString() ?? '').join(',')};
  }

  /// Converts this criterion to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'values': values.map((v) => v?.toString()).toList(),
      };

  @override
  String toString() => 'FilterCriteria($id: $values)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterCriteria &&
          id == other.id &&
          values.length == other.values.length &&
          values.containsAll(other.values);

  @override
  int get hashCode => Object.hash(id, Object.hashAll(values));
}
