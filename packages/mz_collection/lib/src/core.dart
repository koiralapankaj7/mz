// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

/// {@template mz_collection.core_library}
/// Core infrastructure for change notification and transformation control.
///
/// ## Why Core?
///
/// Building reactive collections requires foundational primitives that:
///
/// - **Framework independence** - Work in Flutter, CLI tools, servers, or
///   any Dart environment without external dependencies
/// - **Flexible notification** - Allow classes to use both custom listeners
///   and Flutter's ChangeNotifier simultaneously
/// - **Transformation control** - Configure where filtering, sorting, and
///   searching operations execute (local, remote, or both)
/// - **Type-safe callbacks** - Provide clear function signatures for
///   listeners with and without value parameters
///
/// This library provides the building blocks that FilterManager, SortManager,
/// and other mz_collection modules depend on.
///
/// ## Key Features
///
/// ```text
/// +-------------------------+--------------------------------------------+
/// |        Feature          |              Description                   |
/// +-------------------------+--------------------------------------------+
/// | Listenable mixin        | Pure Dart change notification pattern      |
/// | Listener typedef        | Zero-argument callback for notifications   |
/// | ValueListener typedef   | Callback with typed value parameter        |
/// | TransformSource enum    | Local/remote/combined processing control   |
/// +-------------------------+--------------------------------------------+
/// ```
///
/// ## Notification Architecture
///
/// ```text
/// +-------------------------------------------------------------------+
/// |                        Listenable                                 |
/// |                                                                   |
/// |  +-------------------------------------------------------------+  |
/// |  |               _listeners: List<Listener>                    |  |
/// |  |                                                             |  |
/// |  |  [listener1]  [listener2]  [listener3]  ...                 |  |
/// |  +-------------------------------------------------------------+  |
/// |                            |                                      |
/// |                      notifyChanged()                              |
/// |                            |                                      |
/// |             +--------------+--------------+                       |
/// |             v              v              v                       |
/// |        listener1()    listener2()    listener3()                  |
/// +-------------------------------------------------------------------+
/// ```
///
/// ## Quick Start
///
/// {@tool snippet}
/// Using Listenable in a custom class:
///
/// ```dart
/// class Counter with Listenable {
///   int _count = 0;
///   int get count => _count;
///
///   void increment() {
///     _count++;
///     notifyChanged();
///   }
/// }
///
/// final counter = Counter();
/// counter.addChangeListener(() => print('Count: ${counter.count}'));
/// counter.increment(); // Prints: Count: 1
/// ```
/// {@end-tool}
///
/// {@tool snippet}
/// Configuring transformation source:
///
/// ```dart
/// // Local-only filter (client processes)
/// final statusFilter = Filter<Ticket, Status>(
///   id: 'status',
///   test: (t, s) => t.status == s,
///   source: TransformSource.local,
/// );
///
/// // Remote-only search (server handles)
/// final search = SearchFilter<Ticket>.remote(id: 'search');
///
/// // Combined (both client and server)
/// final dateFilter = Filter<Ticket, DateRange>(
///   id: 'date',
///   test: (t, r) => t.created.isInRange(r),
///   source: TransformSource.combined,
/// );
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [Listenable] - Pure Dart change notification mixin.
/// * [Listener] - Callback type for change notifications.
/// * [ValueListener] - Callback type with a value parameter.
/// * [TransformSource] - Enum for local/remote/combined processing.
/// {@endtemplate}
library;

import 'package:meta/meta.dart';

// ============================================================================
// Listener Types
// ============================================================================

/// {@template mz_collection.listener}
/// A function type for generic listeners without arguments.
///
/// Used by [Listenable] for simple change notifications.
/// {@endtemplate}
typedef Listener = void Function();

/// {@template mz_collection.value_listener}
/// A function type for listening to value changes.
///
/// Called with the changed [value] when a filter's state changes.
/// {@endtemplate}
typedef ValueListener<T> = void Function(T value);

// ============================================================================
// Listenable
// ============================================================================

/// {@template mz_collection.listenable}
/// A mixin that provides change notification capabilities without Flutter.
///
/// This is a pure Dart implementation that uses different method names
/// than Flutter's `ChangeNotifier`, allowing classes to extend both
/// if needed. Users can override [notifyChanged] to redirect notifications
/// to their preferred system (e.g., `ChangeNotifier.notifyListeners()`).
///
/// ## Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────┐
/// │                        Listenable                             │
/// │                                                               │
/// │  ┌─────────────────────────────────────────────────────────┐  │
/// │  │               _listeners: List<Listener>                │  │
/// │  │                                                         │  │
/// │  │  [listener1]  [listener2]  [listener3]  ...             │  │
/// │  └─────────────────────────────────────────────────────────┘  │
/// │                            │                                  │
/// │                      notifyChanged()                          │
/// │                            │                                  │
/// │             ┌──────────────┼──────────────┐                   │
/// │             ▼              ▼              ▼                   │
/// │        listener1()    listener2()    listener3()              │
/// └───────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Thread Safety
///
/// The [notifyChanged] method creates a copy of the listener list
/// before iterating, allowing listeners to safely add or remove
/// other listeners during notification.
///
/// {@tool snippet}
/// Using Listenable in a custom class:
///
/// ```dart
/// class Counter with Listenable {
///   int _count = 0;
///
///   int get count => _count;
///
///   void increment() {
///     _count++;
///     notifyChanged();
///   }
/// }
///
/// final counter = Counter();
/// counter.addChangeListener(() => print('Count: ${counter.count}'));
/// counter.increment(); // Prints: Count: 1
/// ```
/// {@end-tool}
///
/// {@tool snippet}
/// Extending with ChangeNotifier:
///
/// ```dart
/// class MyFilterManager<T> extends FilterManager<T> with ChangeNotifier {
///   @override
///   void notifyChanged() {
///     super.notifyChanged(); // Required for internal listeners
///     notifyListeners(); // Notify ChangeNotifier listeners
///   }
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * `Filter` - Uses Listenable to notify when values change.
/// * `FilterManager` - Uses Listenable to notify when any filter changes.
/// {@endtemplate}
mixin Listenable {
  final _listeners = <Listener>[];

  /// {@template mz_collection.listenable_add_change_listener}
  /// Registers a [listener] to be called when this object changes.
  ///
  /// The same listener can be added multiple times and will be called
  /// once for each registration.
  /// {@endtemplate}
  void addChangeListener(Listener listener) => _listeners.add(listener);

  /// {@template mz_collection.listenable_remove_change_listener}
  /// Removes a previously registered [listener].
  ///
  /// If the listener was added multiple times, only the first occurrence
  /// is removed. Returns silently if the listener was not registered.
  /// {@endtemplate}
  void removeChangeListener(Listener listener) => _listeners.remove(listener);

  /// {@template mz_collection.listenable_notify_changed}
  /// Notifies all registered listeners that this object has changed.
  ///
  /// For single listeners, calls directly without allocation. For multiple
  /// listeners, creates a snapshot to handle concurrent modification safely.
  ///
  /// Override this method to redirect notifications to another system
  /// (e.g., `ChangeNotifier.notifyListeners()`). Always call
  /// `super.notifyChanged()` to ensure internal listeners are notified.
  /// {@endtemplate}
  @protected
  @mustCallSuper
  void notifyChanged() {
    final count = _listeners.length;
    if (count == 0) return;
    if (count == 1) {
      // Single listener - call directly without copy
      _listeners[0]();
      return;
    }
    // Multiple listeners - snapshot to handle concurrent modification
    final snapshot = List<Listener>.of(_listeners);
    for (var i = 0; i < snapshot.length; i++) {
      snapshot[i]();
    }
  }

  /// {@template mz_collection.listenable_has_listeners}
  /// Whether this object has any registered listeners.
  ///
  /// Can be used to optimize by skipping expensive computations
  /// when no one is listening.
  /// {@endtemplate}
  bool get hasListeners => _listeners.isNotEmpty;

  /// {@template mz_collection.listenable_dispose}
  /// Disposes this object by clearing all listeners.
  ///
  /// After calling dispose, no further notifications will be sent.
  /// {@endtemplate}
  void dispose() => _listeners.clear();
}

// ============================================================================
// Transform Source
// ============================================================================

/// {@template mz_collection.transform_source}
/// Determines where a transformation (filter, sort, search) is processed.
///
/// This enables per-filter and per-sort configuration of local/remote behavior.
/// The controller uses this to determine whether to:
/// - Apply the transformation locally
/// - Send parameters to the remote data source
/// - Do both (combined mode)
///
/// ```text
/// ┌───────────────────────────┬────────────────────────────────────────────┐
/// │       Source              │              Behavior                      │
/// ├───────────────────────────┼────────────────────────────────────────────┤
/// │ TransformSource.local     │ Applied locally only via apply()/compare() │
/// │ TransformSource.remote    │ Sent to server only, no local processing   │
/// │ TransformSource.combined  │ Both local processing and server query     │
/// └───────────────────────────┴────────────────────────────────────────────┘
/// ```
///
/// {@tool snippet}
/// Example of per-filter configuration:
///
/// ```dart
/// // Status filter - static enum values, always local
/// final statusFilter = Filter<Ticket, Status>(
///   id: 'status',
///   test: (t, s) => t.status == s,
///   source: TransformSource.local,
/// );
///
/// // Full-text search - server handles better
/// final searchFilter = SearchFilter<Ticket>(
///   valuesRetriever: (t) => [t.title, t.description],
///   source: TransformSource.remote,
/// );
///
/// // Date range - filter locally AND send to server for pagination
/// final dateFilter = Filter<Ticket, DateRange>(
///   id: 'date',
///   test: (t, r) => t.created.isAfter(r.start) && t.created.isBefore(r.end),
///   source: TransformSource.combined,
/// );
/// ```
/// {@end-tool}
/// {@endtemplate}
enum TransformSource {
  /// {@template mz_collection.transform_source_local}
  /// Transformation is applied client-side only.
  ///
  /// The filter/sort's `apply()`/`compare()` method processes items locally.
  /// No parameters are sent to the remote data source.
  /// {@endtemplate}
  local,

  /// {@template mz_collection.transform_source_remote}
  /// Transformation is handled server-side only.
  ///
  /// The filter/sort's local methods pass all items through unchanged.
  /// Parameters are sent to the remote data source for processing.
  /// {@endtemplate}
  remote,

  /// {@template mz_collection.transform_source_combined}
  /// Transformation is applied both client-side and server-side.
  ///
  /// The filter/sort's local methods process items locally,
  /// AND parameters are sent to the remote data source.
  /// {@endtemplate}
  combined,
}

// ============================================================================
// Tristate
// ============================================================================

/// Represents a three-state value for boolean-like operations.
///
/// This enum is useful for scenarios where a simple boolean is not sufficient,
/// such as selection states, expandable/collapsible UI elements, or any
/// situation where a toggle operation is needed alongside definitive states.
///
/// {@tool snippet}
/// Usage examples:
///
/// ```dart
/// // For selection:
/// selection.select(key, state: Tristate.yes);    // Select
/// selection.select(key, state: Tristate.no);     // Deselect
/// selection.select(key, state: Tristate.toggle); // Toggle
///
/// // For collapse:
/// collapse.collapse(key, state: Tristate.yes);   // Collapse
/// collapse.collapse(key, state: Tristate.no);    // Expand
/// collapse.collapse(key, state: Tristate.toggle); // Toggle
/// ```
/// {@end-tool}
enum Tristate {
  /// Represents a true, selected, or collapsed state.
  yes,

  /// Represents a false, unselected, or expanded state.
  no,

  /// Represents a toggle operation - inverts the current state.
  toggle,
}

/// Extension to provide resolve functionality for [Tristate].
extension TriStateX on Tristate {
  /// Resolves the [Tristate] to a boolean value.
  ///
  /// [value] is the current boolean state, used for toggle operations.
  ///
  /// Returns:
  /// - `true` for [Tristate.yes]
  /// - `false` for [Tristate.no]
  /// - The opposite of [value] for [Tristate.toggle]
  ///
  /// {@tool snippet}
  /// Usage:
  ///
  /// ```dart
  /// bool currentState = true;
  /// bool newState = Tristate.toggle.resolve(currentState); // Returns false
  /// ```
  /// {@end-tool}
  // ignore: avoid_positional_boolean_parameters
  bool resolve(bool? value) => switch (this) {
        Tristate.yes => true,
        Tristate.no => false,
        Tristate.toggle => !(value ?? false),
      };
}

/// Extension to convert [bool] to [Tristate].
extension TriStateBoolX on bool? {
  /// Converts a boolean value to its corresponding [Tristate].
  ///
  /// Returns:
  /// - [Tristate.yes] if the boolean is true
  /// - [Tristate.no] if the boolean is false or null
  ///
  /// {@tool snippet}
  /// Usage:
  ///
  /// ```dart
  /// bool? isSelected = true;
  /// Tristate state = isSelected.toTristate; // Returns Tristate.yes
  /// ```
  /// {@end-tool}
  Tristate get toTristate => (this ?? false) ? Tristate.yes : Tristate.no;
}
