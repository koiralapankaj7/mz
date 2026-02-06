// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

/// {@template mz_collection.aggregation_library}
/// Group-level aggregation support for computing summary values.
///
/// ## Why Aggregation?
///
/// Modern data applications often need to show summary statistics alongside
/// grouped data:
///
/// - **Dashboards** - Display KPIs like total revenue, average response time,
///   or count of active items per category
/// - **Reports** - Generate totals, subtotals, and statistical summaries for
///   hierarchical data structures
/// - **Data grids** - Show group headers with aggregate values (e.g., "Sales:
///   $15,000" or "Tasks: 42 items")
/// - **Analytics** - Compute running statistics, percentages, and comparisons
///   across data segments
///
/// Aggregation provides a unified API for defining, computing, and accessing
/// summary values without coupling to specific UI frameworks.
///
/// ## Key Features
///
/// ```text
/// ┌───────────────────────────┬──────────────────────────────────────┐
/// │          Feature          │            Description               │
/// ├───────────────────────────┼──────────────────────────────────────┤
/// │ Built-in aggregations     │ count, sum, average, min, max, etc.  │
/// │ Custom aggregations       │ Define any computation function      │
/// │ Type-safe results         │ AggregateResult with typed access    │
/// │ Null handling             │ Gracefully handles null/empty data   │
/// │ Pure Dart Listenable      │ No Flutter dependency required       │
/// │ Group support             │ Aggregate multiple groups at once    │
/// │ Initial values            │ Configurable defaults for empty sets │
/// └───────────────────────────┴──────────────────────────────────────┘
/// ```
///
/// ## Architecture
///
/// ```text
/// ┌─────────────────────────────────────────────────────────────────┐
/// │                    AggregationManager<T>                        │
/// │                                                                 │
/// │  ┌─────────────────────────────────────────────────────────┐   │
/// │  │              Aggregation Definitions                     │   │
/// │  │                                                         │   │
/// │  │  [0] Aggregation(id: 'total', sum: (t) => t.amount)    │   │
/// │  │  [1] Aggregation(id: 'count', count)                    │   │
/// │  │  [2] Aggregation(id: 'avg', average: (t) => t.score)   │   │
/// │  └─────────────────────────────────────────────────────────┘   │
/// │                              │                                  │
/// │                    aggregate(items)                             │
/// │                              │                                  │
/// │                              ▼                                  │
/// │  ┌─────────────────────────────────────────────────────────┐   │
/// │  │              AggregateResult                             │   │
/// │  │                                                         │   │
/// │  │  { 'total': 15000.0, 'count': 42, 'avg': 85.5 }        │   │
/// │  └─────────────────────────────────────────────────────────┘   │
/// └─────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Quick Start
///
/// {@tool snippet}
/// Define aggregations and compute summary values:
///
/// ```dart
/// // Define aggregations
/// final aggregations = AggregationManager<Task>(
///   aggregations: [
///     Aggregation.count(id: 'count', label: 'Tasks'),
///     Aggregation.sum(
///       id: 'hours',
///       label: 'Total Hours',
///       valueGetter: (task) => task.estimatedHours,
///     ),
///     Aggregation.average(
///       id: 'completion',
///       label: 'Avg Completion',
///       valueGetter: (task) => task.completionPercent,
///     ),
///   ],
/// );
///
/// // Compute aggregates for a group
/// final result = aggregations.aggregate(tasksInGroup);
/// print(result['count']); // 42
/// print(result['hours']); // 156.5
/// print(result['completion']); // 75.3
/// ```
/// {@end-tool}
///
/// {@tool snippet}
/// Use with GroupManager in a CollectionController:
///
/// ```dart
/// final controller = CollectionController<String, Task>(
///   store: store,
///   group: groupManager,
///   aggregations: aggregationManager,
/// );
///
/// // Access aggregates via SlotManager
/// final slot = slotManager.getSlot(0);
/// if (slot case GroupHeaderSlot(:final aggregates)) {
///   print('Total: ${aggregates?['total']}');
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [Aggregation] - Defines how to compute an aggregate value for a group.
/// * [AggregateResult] - Holds computed aggregate values for lookup.
/// * [AggregationManager] - Manages aggregation definitions and computation.
/// * [Listenable] - Pure Dart change notification mixin.
/// {@endtemplate}
library;

import 'package:meta/meta.dart';

import 'core.dart';

/// {@template mz_collection.aggregate_function}
/// A function that computes an aggregate value from a list of items.
///
/// Returns the aggregated result of type [R] from the input [items].
/// {@endtemplate}
typedef AggregateFunction<T, R> = R Function(List<T> items);

/// {@template mz_collection.value_getter}
/// A function that extracts a numeric value from an item.
///
/// Used by built-in aggregations like [Aggregation.sum] and
/// [Aggregation.average].
/// {@endtemplate}
typedef NumericValueGetter<T> = num? Function(T item);

/// {@template mz_collection.comparable_value_getter}
/// A function that extracts a comparable value from an item.
///
/// Used by [Aggregation.min] and [Aggregation.max].
/// {@endtemplate}
typedef ComparableValueGetter<T, V extends Comparable<V>> = V? Function(T item);

/// {@template mz_collection.aggregation}
/// Defines how to compute an aggregate value for a group of items.
///
/// An aggregation has:
/// - [id] - Unique identifier for lookup
/// - [label] - Display name for UI
/// - [aggregate] - Function that computes the value
///
/// ## Built-in Aggregations
///
/// ```text
/// ┌──────────────────┬────────────────────────────────────────────┐
/// │   Constructor    │              Description                   │
/// ├──────────────────┼────────────────────────────────────────────┤
/// │ Aggregation()    │ Custom aggregation function                │
/// │ .count()         │ Count of items                             │
/// │ .sum()           │ Sum of numeric values                      │
/// │ .average()       │ Average of numeric values                  │
/// │ .min()           │ Minimum value                              │
/// │ .max()           │ Maximum value                              │
/// │ .first()         │ First item's value                         │
/// │ .last()          │ Last item's value                          │
/// │ .distinct()      │ Count of distinct values                   │
/// └──────────────────┴────────────────────────────────────────────┘
/// ```
///
/// ## Custom Aggregation
///
/// ```dart
/// final customAgg = Aggregation<Task, String>(
///   id: 'status_summary',
///   label: 'Status',
///   aggregate: (items) {
///     final open = items.where((t) => t.status == 'open').length;
///     final closed = items.where((t) => t.status == 'closed').length;
///     return '$open open, $closed closed';
///   },
/// );
/// ```
/// {@endtemplate}
@immutable
class Aggregation<T, R> {
  /// Creates a custom aggregation.
  ///
  /// The [aggregate] function receives all items in a group and returns
  /// the computed value.
  const Aggregation({
    required this.id,
    required this.aggregate,
    this.label,
    this.initialValue,
  });

  /// Creates a count aggregation.
  ///
  /// Returns the number of items in the group.
  ///
  /// ```dart
  /// Aggregation.count<Task>(id: 'count', label: 'Tasks')
  /// ```
  static Aggregation<T, int> count<T>({
    required String id,
    String? label,
  }) {
    return Aggregation<T, int>(
      id: id,
      label: label,
      initialValue: 0,
      aggregate: (items) => items.length,
    );
  }

  /// Creates a sum aggregation.
  ///
  /// Sums the numeric values extracted by [valueGetter].
  /// Null values are treated as 0.
  ///
  /// ```dart
  /// Aggregation.sum<Task, double>(
  ///   id: 'total_hours',
  ///   label: 'Hours',
  ///   valueGetter: (task) => task.hours,
  /// )
  /// ```
  static Aggregation<T, double> sum<T>({
    required String id,
    required NumericValueGetter<T> valueGetter,
    String? label,
  }) {
    return Aggregation<T, double>(
      id: id,
      label: label,
      initialValue: 0,
      aggregate: (items) {
        var total = 0.0;
        for (final item in items) {
          total += valueGetter(item) ?? 0;
        }
        return total;
      },
    );
  }

  /// Creates an average aggregation.
  ///
  /// Computes the average of numeric values extracted by [valueGetter].
  /// Null values are excluded from the calculation.
  /// Returns null if no valid values exist.
  ///
  /// ```dart
  /// Aggregation.average<Task, double>(
  ///   id: 'avg_score',
  ///   label: 'Avg Score',
  ///   valueGetter: (task) => task.score,
  /// )
  /// ```
  static Aggregation<T, double?> average<T>({
    required String id,
    required NumericValueGetter<T> valueGetter,
    String? label,
  }) {
    return Aggregation<T, double?>(
      id: id,
      label: label,
      aggregate: (items) {
        if (items.isEmpty) return null;
        var sum = 0.0;
        var count = 0;
        for (final item in items) {
          final value = valueGetter(item);
          if (value != null) {
            sum += value;
            count++;
          }
        }
        return count > 0 ? sum / count : null;
      },
    );
  }

  /// Creates a minimum aggregation.
  ///
  /// Finds the minimum value extracted by [valueGetter].
  /// Null values are excluded.
  /// Returns null if no valid values exist.
  ///
  /// ```dart
  /// Aggregation.min<Task, DateTime>(
  ///   id: 'earliest',
  ///   label: 'Earliest',
  ///   valueGetter: (task) => task.createdAt,
  /// )
  /// ```
  static Aggregation<T, V?> min<T, V extends Comparable<V>>({
    required String id,
    required ComparableValueGetter<T, V> valueGetter,
    String? label,
  }) {
    return Aggregation<T, V?>(
      id: id,
      label: label,
      aggregate: (items) {
        V? minValue;
        for (final item in items) {
          final value = valueGetter(item);
          if (value != null) {
            if (minValue == null || value.compareTo(minValue) < 0) {
              minValue = value;
            }
          }
        }
        return minValue;
      },
    );
  }

  /// Creates a maximum aggregation.
  ///
  /// Finds the maximum value extracted by [valueGetter].
  /// Null values are excluded.
  /// Returns null if no valid values exist.
  ///
  /// ```dart
  /// Aggregation.max<Task, int>(
  ///   id: 'highest_priority',
  ///   label: 'Highest',
  ///   valueGetter: (task) => task.priority,
  /// )
  /// ```
  static Aggregation<T, V?> max<T, V extends Comparable<V>>({
    required String id,
    required ComparableValueGetter<T, V> valueGetter,
    String? label,
  }) {
    return Aggregation<T, V?>(
      id: id,
      label: label,
      aggregate: (items) {
        V? maxValue;
        for (final item in items) {
          final value = valueGetter(item);
          if (value != null) {
            if (maxValue == null || value.compareTo(maxValue) > 0) {
              maxValue = value;
            }
          }
        }
        return maxValue;
      },
    );
  }

  /// Creates a first-value aggregation.
  ///
  /// Returns the value from the first item in the group.
  /// Returns null if the group is empty.
  ///
  /// ```dart
  /// Aggregation.first<Task, String>(
  ///   id: 'first_status',
  ///   valueGetter: (task) => task.status,
  /// )
  /// ```
  static Aggregation<T, V?> first<T, V>({
    required String id,
    required V? Function(T item) valueGetter,
    String? label,
  }) {
    return Aggregation<T, V?>(
      id: id,
      label: label,
      aggregate: (items) => items.isEmpty ? null : valueGetter(items.first),
    );
  }

  /// Creates a last-value aggregation.
  ///
  /// Returns the value from the last item in the group.
  /// Returns null if the group is empty.
  ///
  /// ```dart
  /// Aggregation.last<Task, DateTime>(
  ///   id: 'last_updated',
  ///   valueGetter: (task) => task.updatedAt,
  /// )
  /// ```
  static Aggregation<T, V?> last<T, V>({
    required String id,
    required V? Function(T item) valueGetter,
    String? label,
  }) {
    return Aggregation<T, V?>(
      id: id,
      label: label,
      aggregate: (items) => items.isEmpty ? null : valueGetter(items.last),
    );
  }

  /// Creates a distinct count aggregation.
  ///
  /// Counts the number of distinct values extracted by [valueGetter].
  /// Null values are excluded.
  ///
  /// ```dart
  /// Aggregation.distinct<Task, String>(
  ///   id: 'unique_assignees',
  ///   label: 'Assignees',
  ///   valueGetter: (task) => task.assigneeId,
  /// )
  /// ```
  static Aggregation<T, int> distinct<T, V>({
    required String id,
    required V? Function(T item) valueGetter,
    String? label,
  }) {
    return Aggregation<T, int>(
      id: id,
      label: label,
      initialValue: 0,
      aggregate: (items) {
        final seen = <V>{};
        for (final item in items) {
          final value = valueGetter(item);
          if (value != null) {
            seen.add(value);
          }
        }
        return seen.length;
      },
    );
  }

  /// Creates a percentage aggregation.
  ///
  /// Computes the percentage of items matching the [predicate].
  ///
  /// ```dart
  /// Aggregation.percentage<Task>(
  ///   id: 'completion_rate',
  ///   label: 'Complete',
  ///   predicate: (task) => task.isComplete,
  /// )
  /// ```
  static Aggregation<T, double> percentage<T>({
    required String id,
    required bool Function(T item) predicate,
    String? label,
  }) {
    return Aggregation<T, double>(
      id: id,
      label: label,
      initialValue: 0,
      aggregate: (items) {
        if (items.isEmpty) return 0.0;
        final matching = items.where(predicate).length;
        return (matching / items.length) * 100;
      },
    );
  }

  /// Unique identifier for this aggregation.
  final String id;

  /// Optional display label for UI.
  final String? label;

  /// The function that computes the aggregate value.
  final AggregateFunction<T, R> aggregate;

  /// Initial value for empty groups.
  final R? initialValue;

  /// Computes the aggregate value for the given items.
  R compute(List<T> items) {
    if (items.isEmpty && initialValue != null) return initialValue!;
    return aggregate(items);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Aggregation<T, R> && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Aggregation(id: $id)';
}

/// {@template mz_collection.aggregate_result}
/// Holds computed aggregate values for a group.
///
/// Access values by aggregation id:
///
/// ```dart
/// final result = manager.aggregate(items);
/// print(result['count']); // 42
/// print(result['total']); // 1500.0
/// print(result.get<double>('average')); // 35.7 (typed access)
/// ```
/// {@endtemplate}
class AggregateResult {
  /// Creates an aggregate result from a map of values.
  const AggregateResult(this._values);

  /// Creates an empty aggregate result.
  const AggregateResult.empty() : _values = const {};

  final Map<String, dynamic> _values;

  /// Gets the value for an aggregation by [id].
  ///
  /// Returns null if the aggregation doesn't exist.
  dynamic operator [](String id) => _values[id];

  /// Gets a typed value for an aggregation.
  ///
  /// Returns null if the aggregation doesn't exist or has wrong type.
  ///
  /// ```dart
  /// final count = result.get<int>('count');
  /// final total = result.get<double>('total');
  /// ```
  V? get<V>(String id) {
    final value = _values[id];
    return value is V ? value : null;
  }

  /// Whether this result contains a value for [id].
  bool containsKey(String id) => _values.containsKey(id);

  /// All aggregation ids in this result.
  Iterable<String> get keys => _values.keys;

  /// All values in this result.
  Iterable<dynamic> get values => _values.values;

  /// All entries in this result.
  Iterable<MapEntry<String, dynamic>> get entries => _values.entries;

  /// Whether this result is empty.
  bool get isEmpty => _values.isEmpty;

  /// Whether this result is not empty.
  bool get isNotEmpty => _values.isNotEmpty;

  /// Number of aggregations in this result.
  int get length => _values.length;

  /// Converts to a regular map.
  Map<String, dynamic> toMap() => Map.unmodifiable(_values);

  @override
  String toString() => 'AggregateResult($_values)';
}

/// {@template mz_collection.aggregation_manager}
/// Manages aggregation definitions and computes group summaries.
///
/// ## Overview
///
/// An [AggregationManager] holds a collection of [Aggregation] definitions
/// and provides methods to compute aggregate values for groups of items.
///
/// ## Usage
///
/// ```dart
/// final manager = AggregationManager<Task>(
///   aggregations: [
///     Aggregation.count(id: 'count'),
///     Aggregation.sum(id: 'hours', valueGetter: (t) => t.hours),
///     Aggregation.average(id: 'score', valueGetter: (t) => t.score),
///   ],
/// );
///
/// // Compute for a single group
/// final result = manager.aggregate(taskList);
/// print('Count: ${result['count']}');
/// print('Total Hours: ${result['hours']}');
/// print('Avg Score: ${result['score']}');
///
/// // Compute for multiple groups
/// final results = manager.aggregateGroups({
///   'group1': tasks1,
///   'group2': tasks2,
/// });
/// ```
///
/// ## With Hierarchical Groups
///
/// The manager supports recursive aggregation for nested groups:
///
/// ```dart
/// // Aggregates bubble up from leaves to root
/// final hierarchicalResults = manager.aggregateHierarchy(rootNode);
/// ```
/// {@endtemplate}
class AggregationManager<T> with Listenable {
  /// Creates an aggregation manager.
  AggregationManager({
    Iterable<Aggregation<T, dynamic>>? aggregations,
  }) {
    if (aggregations != null) {
      for (final agg in aggregations) {
        _aggregations[agg.id] = agg;
      }
    }
  }

  final Map<String, Aggregation<T, dynamic>> _aggregations = {};

  /// All registered aggregations.
  Iterable<Aggregation<T, dynamic>> get aggregations => _aggregations.values;

  /// Number of registered aggregations.
  int get length => _aggregations.length;

  /// Whether any aggregations are registered.
  bool get isEmpty => _aggregations.isEmpty;

  /// Whether any aggregations are registered.
  bool get isNotEmpty => _aggregations.isNotEmpty;

  /// Gets an aggregation by [id].
  Aggregation<T, dynamic>? operator [](String id) => _aggregations[id];

  /// Gets a typed aggregation by [id].
  Aggregation<T, R>? getAggregation<R>(String id) {
    final agg = _aggregations[id];
    return agg is Aggregation<T, R> ? agg : null;
  }

  /// Adds an aggregation to the manager.
  void add(Aggregation<T, dynamic> aggregation) {
    _aggregations[aggregation.id] = aggregation;
    notifyChanged();
  }

  /// Adds multiple aggregations to the manager.
  void addAll(Iterable<Aggregation<T, dynamic>> aggregations) {
    for (final agg in aggregations) {
      _aggregations[agg.id] = agg;
    }
    notifyChanged();
  }

  /// Removes an aggregation by [id].
  Aggregation<T, dynamic>? remove(String id) {
    final removed = _aggregations.remove(id);
    if (removed != null) {
      notifyChanged();
    }
    return removed;
  }

  /// Removes all aggregations.
  void clear() {
    if (_aggregations.isNotEmpty) {
      _aggregations.clear();
      notifyChanged();
    }
  }

  /// Computes all aggregates for a list of items.
  ///
  /// Returns an [AggregateResult] containing values for all registered
  /// aggregations.
  ///
  /// ```dart
  /// final result = manager.aggregate(items);
  /// print(result['count']); // 42
  /// ```
  AggregateResult aggregate(List<T> items) {
    if (_aggregations.isEmpty) {
      return const AggregateResult.empty();
    }

    final values = <String, dynamic>{};
    for (final agg in _aggregations.values) {
      values[agg.id] = agg.compute(items);
    }
    return AggregateResult(values);
  }

  /// Computes aggregates for multiple named groups.
  ///
  /// Returns a map of group id to [AggregateResult].
  ///
  /// ```dart
  /// final results = manager.aggregateGroups({
  ///   'active': activeItems,
  ///   'completed': completedItems,
  /// });
  /// print(results['active']?['count']); // Active count
  /// ```
  Map<String, AggregateResult> aggregateGroups(Map<String, List<T>> groups) {
    final results = <String, AggregateResult>{};
    for (final entry in groups.entries) {
      results[entry.key] = aggregate(entry.value);
    }
    return results;
  }

  /// Computes a single aggregation for items.
  ///
  /// More efficient than [aggregate] when only one value is needed.
  ///
  /// ```dart
  /// final count = manager.computeOne('count', items);
  /// ```
  R? computeOne<R>(String id, List<T> items) {
    final agg = _aggregations[id];
    if (agg == null) return null;
    return agg.compute(items) as R?;
  }

  @override
  void dispose() {
    _aggregations.clear();
    super.dispose();
  }

  @override
  String toString() =>
      'AggregationManager(aggregations: ${_aggregations.length})';
}
