// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

/// {@template mz_collection.selection_manager_library}
/// A pure Dart selection management system with flat storage and optional
/// scopes.
///
/// ## Why This Design?
///
/// Traditional selection managers store selections by group key. This breaks
/// when UI grouping changes dynamically (e.g., user switches from grouping
/// by "Status" to "Priority"). Selections tied to old group keys become stale.
///
/// This manager uses **flat storage** as the source of truth:
/// - Selections persist across regrouping
/// - Consumer provides current group membership at query time
/// - Optional scopes for truly independent selection sets (tabs, etc.)
///
/// ## Key Features
///
/// ```text
/// ┌───────────────────────────┬──────────────────────────────────────┐
/// │          Feature          │            Description               │
/// ├───────────────────────────┼──────────────────────────────────────┤
/// │ Flat storage              │ Selections stored by key, not group  │
/// │ Query-time grouping       │ Pass keys[] to get group state       │
/// │ Optional scopes           │ Independent selection sets (tabs)    │
/// │ Tri-state aggregation     │ none/partial/all for checkbox UI     │
/// │ O(1) lookups              │ Set-based storage for fast access    │
/// │ Pure Dart Listenable      │ No Flutter dependency required       │
/// └───────────────────────────┴──────────────────────────────────────┘
/// ```
///
/// ## Architecture
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────────┐
/// │                      SelectionManager                             │
/// │                                                                   │
/// │  ┌─────────────────────────────────────────────────────────────┐  │
/// │  │           _byScope: Map<Object?, Set<String>>               │  │
/// │  │                                                             │  │
/// │  │  null (default) ──► {key1, key2, key3}  // Main selections  │  │
/// │  │  'tabA' ──► {key4, key5}                // Tab A scope      │  │
/// │  │  'tabB' ──► {key1, key6}                // Tab B scope      │  │
/// │  └─────────────────────────────────────────────────────────────┘  │
/// │                                                                   │
/// │  Query-time grouping (consumer provides keys):                    │
/// │  ┌─────────────────────────────────────────────────────────────┐  │
/// │  │  stateOf(['key1', 'key2', 'key3'])  // "Active" group       │  │
/// │  │  stateOf(['key1', 'key4'])          // "High Priority"      │  │
/// │  │                                                             │  │
/// │  │  Same keys, different groupings - selections persist!       │  │
/// │  └─────────────────────────────────────────────────────────────┘  │
/// └───────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Basic Usage (Flat Storage)
///
/// {@tool snippet}
/// Selections persist across dynamic regrouping:
///
/// ```dart
/// final selection = SelectionManager<String>();
///
/// // Select items (stored flat)
/// selection.select('task1');
/// selection.select('task2');
/// selection.select('task3');
///
/// // Query by current grouping (user grouped by Status)
/// final activeItems = ['task1', 'task2', 'task4', 'task5'];
/// final completedItems = ['task3', 'task6'];
///
/// selection.stateOf(activeItems);     // partial (2 of 4)
/// selection.stateOf(completedItems);  // partial (1 of 2)
///
/// // User changes grouping to Priority
/// final highPriority = ['task1', 'task3'];
/// final lowPriority = ['task2', 'task4', 'task5', 'task6'];
///
/// // Same selections, different grouping - still works!
/// selection.stateOf(highPriority);    // all (2 of 2)
/// selection.stateOf(lowPriority);     // partial (1 of 4)
/// ```
/// {@end-tool}
///
/// ## Scoped Selections (Independent Sets)
///
/// {@tool snippet}
/// Use scopes for truly independent selection sets:
///
/// ```dart
/// final selection = SelectionManager<String>();
///
/// // Tab A has its own selections
/// selection.select('item1', scope: 'tabA');
/// selection.select('item2', scope: 'tabA');
///
/// // Tab B has independent selections
/// selection.select('item1', scope: 'tabB');  // Same item, different scope
/// selection.select('item3', scope: 'tabB');
///
/// // Query within scope
/// selection.isSelected('item1', scope: 'tabA');  // true
/// selection.isSelected('item1', scope: 'tabB');  // true
/// selection.isSelected('item2', scope: 'tabB');  // false
///
/// // Clear only Tab A
/// selection.clear(scope: 'tabA');
/// selection.isSelected('item1', scope: 'tabB');  // still true
/// ```
/// {@end-tool}
///
/// ## Tree Aggregation
///
/// {@tool snippet}
/// For tree structures, flatten to get all keys:
///
/// ```dart
/// final selection = SelectionManager<String>();
///
/// // Select some files
/// selection.select('src/main.dart');
/// selection.select('src/utils.dart');
///
/// // Get all files in a folder (consumer knows the tree)
/// final filesInSrc = ['src/main.dart', 'src/utils.dart', 'src/app.dart'];
///
/// selection.stateOf(filesInSrc);  // partial (2 of 3)
///
/// // For nested folders, flatten the tree
/// final allFilesInProject = getAllFilesRecursively('project');
/// selection.stateOf(allFilesInProject);
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [SelectionState] - Tri-state enum for checkbox UI.
/// * [Tristate] - Three-state value for operations.
/// {@endtemplate}
library;

import 'package:meta/meta.dart';

import 'core.dart';

export 'core.dart' show Listenable, Listener, TriStateX, Tristate;

/// {@template mz_collection.selection_state}
/// Represents the aggregated selection state of a set of items.
///
/// Used for checkbox tri-state UI where a parent's checkbox should
/// reflect the selection state of its children.
///
/// ```text
/// ┌─────────────────────────────────────────────────────────────────┐
/// │                    SelectionState Values                        │
/// │                                                                 │
/// │  ┌─────────┐  ┌─────────┐  ┌─────────┐                          │
/// │  │  none   │  │ partial │  │   all   │                          │
/// │  │   [ ]   │  │   [-]   │  │   [✓]   │                          │
/// │  │         │  │         │  │         │                          │
/// │  │ 0 of N  │  │ K of N  │  │ N of N  │                          │
/// │  │selected │  │selected │  │selected │                          │
/// │  └─────────┘  └─────────┘  └─────────┘                          │
/// └─────────────────────────────────────────────────────────────────┘
/// ```
/// {@endtemplate}
enum SelectionState {
  /// No items are selected.
  none,

  /// Some but not all items are selected.
  partial,

  /// All items are selected.
  all,
}

/// {@template mz_collection.children_of_callback}
/// Returns the child keys for a given key.
///
/// Used for tree traversal operations.
/// {@endtemplate}
typedef ChildrenOf = Iterable<String> Function(String key);

/// {@template mz_collection.selection_manager}
/// Manages selection state with flat storage and optional scopes.
///
/// ## Design Principles
///
/// 1. **Flat Storage** - Selections stored by key, not by group
/// 2. **Query-Time Grouping** - Consumer provides keys for group queries
/// 3. **Optional Scopes** - Independent selection sets when needed
/// 4. **Persist Across Regrouping** - Selections survive UI grouping changes
///
/// ## Storage Model
///
/// ```text
/// ┌─────────────────────────────────────────────────────────────────┐
/// │                  Scope-Based Storage                            │
/// │                                                                 │
/// │  _byScope: Map<Object?, Set<K>>                                 │
/// │                                                                 │
/// │  ┌──────────────────────────────────────────────────────────┐   │
/// │  │  null (default scope)                                    │   │
/// │  │    └── {key1, key2, key3}                                │   │
/// │  │                                                          │   │
/// │  │  'tabA' (custom scope)                                   │   │
/// │  │    └── {key4, key5}                                      │   │
/// │  │                                                          │   │
/// │  │  'tabB' (custom scope)                                   │   │
/// │  │    └── {key1, key6}  // key1 can be in multiple scopes   │   │
/// │  └──────────────────────────────────────────────────────────┘   │
/// └─────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Scope vs Group
///
/// - **Scope**: Isolation mechanism for independent selection sets
/// - **Group**: UI presentation that changes dynamically
///
/// Scopes are stable (tabs, sections). Groups are fluid (sort/filter).
/// {@endtemplate}
class SelectionManager with Listenable {
  /// Creates a selection manager with flat storage.
  SelectionManager();

  /// Storage: scope → `Set<String>`
  ///
  /// The null key represents the default scope.
  final Map<Object?, Set<String>> _byScope = {};

  // ===========================================================================
  // Selection Operations
  // ===========================================================================

  /// {@template mz_collection.selection_manager_select}
  /// Modifies the selection state of [key].
  ///
  /// The [scope] parameter specifies which selection set to use.
  /// If null, uses the default scope.
  ///
  /// The [state] parameter controls the operation:
  /// - [Tristate.yes] - Select the key
  /// - [Tristate.no] - Deselect the key
  /// - [Tristate.toggle] - Toggle current state (default)
  ///
  /// Returns the new selection state of the key.
  ///
  /// ```dart
  /// selection.select('item1');                          // Toggle in default
  /// selection.select('item2', state: Tristate.yes);     // Force select
  /// selection.select('item3', scope: 'tabA');           // Toggle in tabA
  /// ```
  /// {@endtemplate}
  bool select(String key, {Object? scope, Tristate state = Tristate.toggle}) {
    final set = _byScope.putIfAbsent(scope, () => <String>{});
    final wasSelected = set.contains(key);

    final shouldSelect = switch (state) {
      Tristate.yes => true,
      Tristate.no => false,
      Tristate.toggle => !wasSelected,
    };

    if (shouldSelect == wasSelected) return wasSelected;

    if (shouldSelect) {
      set.add(key);
    } else {
      set.remove(key);
      if (set.isEmpty) _byScope.remove(scope);
    }

    notifyChanged();
    return shouldSelect;
  }

  /// {@template mz_collection.selection_manager_select_all}
  /// Selects or deselects all [keys].
  ///
  /// The [state] parameter controls the operation:
  /// - [Tristate.yes] - Select all keys (default)
  /// - [Tristate.no] - Deselect all keys
  /// - [Tristate.toggle] - Toggle each key individually
  ///
  /// Notifies listeners once after all changes.
  ///
  /// ```dart
  /// selection.selectAll(['a', 'b', 'c']);                    // Select all
  /// selection.selectAll(['a', 'b'], state: Tristate.no);     // Deselect
  /// selection.selectAll(['a', 'b'], scope: 'tabA');          // In scope
  /// ```
  /// {@endtemplate}
  void selectAll(
    Iterable<String> keys, {
    Object? scope,
    Tristate state = Tristate.yes,
  }) {
    var changed = false;
    final set = _byScope.putIfAbsent(scope, () => <String>{});

    for (final key in keys) {
      final wasSelected = set.contains(key);

      final shouldSelect = switch (state) {
        Tristate.yes => true,
        Tristate.no => false,
        Tristate.toggle => !wasSelected,
      };

      if (shouldSelect != wasSelected) {
        if (shouldSelect) {
          set.add(key);
        } else {
          set.remove(key);
        }
        changed = true;
      }
    }

    if (set.isEmpty) _byScope.remove(scope);
    if (changed) notifyChanged();
  }

  /// {@template mz_collection.selection_manager_is_selected}
  /// Returns whether [key] is selected.
  ///
  /// If [scope] is provided, checks within that scope.
  /// If [scope] is null, checks the default scope.
  /// {@endtemplate}
  bool isSelected(String key, {Object? scope}) {
    return _byScope[scope]?.contains(key) ?? false;
  }

  /// {@template mz_collection.selection_manager_clear}
  /// Clears selections.
  ///
  /// If [scope] is provided, clears only that scope.
  /// If [scope] is null, clears the default scope.
  /// Use [clearAll] to clear all scopes.
  /// {@endtemplate}
  void clear({Object? scope}) {
    final removed = _byScope.remove(scope);
    if (removed != null && removed.isNotEmpty) {
      notifyChanged();
    }
  }

  /// Clears all selections across all scopes.
  void clearAll() {
    if (_byScope.isNotEmpty) {
      _byScope.clear();
      notifyChanged();
    }
  }

  // ===========================================================================
  // Query Operations (Consumer provides keys)
  // ===========================================================================

  /// {@template mz_collection.selection_manager_count_in}
  /// Returns how many of the given [keys] are selected.
  ///
  /// Use this for dynamic grouping where group membership changes.
  ///
  /// ```dart
  /// final activeItems = ['task1', 'task2', 'task3'];
  /// final selectedCount = selection.countIn(activeItems);
  /// ```
  /// {@endtemplate}
  int countIn(Iterable<String> keys, {Object? scope}) {
    final set = _byScope[scope];
    if (set == null || set.isEmpty) return 0;
    // Direct loop avoids iterator allocation from .where()
    var count = 0;
    for (final k in keys) {
      if (set.contains(k)) count++;
    }
    return count;
  }

  /// {@template mz_collection.selection_manager_selected_in}
  /// Returns which of the given [keys] are selected.
  ///
  /// ```dart
  /// final activeItems = ['task1', 'task2', 'task3'];
  /// final selected = selection.selectedIn(activeItems);
  /// // Returns subset of activeItems that are selected
  /// ```
  /// {@endtemplate}
  Set<String> selectedIn(Iterable<String> keys, {Object? scope}) {
    final set = _byScope[scope];
    if (set == null || set.isEmpty) return const {};
    // Build result directly without intermediate where() iterator
    final result = <String>{};
    for (final k in keys) {
      if (set.contains(k)) result.add(k);
    }
    return result;
  }

  /// {@template mz_collection.selection_manager_state_of}
  /// Returns the selection state for the given [keys].
  ///
  /// Returns:
  /// - [SelectionState.none] if no keys are selected
  /// - [SelectionState.all] if all keys are selected
  /// - [SelectionState.partial] otherwise
  ///
  /// ```dart
  /// final activeItems = ['task1', 'task2', 'task3'];
  /// final state = selection.stateOf(activeItems);
  /// // Use for checkbox tri-state rendering
  /// ```
  /// {@endtemplate}
  SelectionState stateOf(Iterable<String> keys, {Object? scope}) {
    final set = _byScope[scope];
    if (set == null || set.isEmpty) {
      // No selections - check if keys is empty too
      return keys.isEmpty ? SelectionState.none : SelectionState.none;
    }

    // Single pass with early exit for partial state detection
    var hasSelected = false;
    var hasUnselected = false;

    for (final k in keys) {
      if (set.contains(k)) {
        hasSelected = true;
      } else {
        hasUnselected = true;
      }
      // Early exit: if we have both, it's partial
      if (hasSelected && hasUnselected) {
        return SelectionState.partial;
      }
    }

    if (!hasSelected && !hasUnselected) return SelectionState.none;
    if (hasSelected && !hasUnselected) return SelectionState.all;
    return SelectionState.none;
  }

  // ===========================================================================
  // Scope-Wide Queries
  // ===========================================================================

  /// Returns all selected keys in the given [scope].
  ///
  /// If [scope] is null, returns selections from the default scope.
  Set<String> allSelectedIn({Object? scope}) {
    final set = _byScope[scope];
    return set != null ? Set.unmodifiable(set) : const {};
  }

  /// Returns the count of all selections in the given [scope].
  int countAllIn({Object? scope}) => _byScope[scope]?.length ?? 0;

  // ===========================================================================
  // Global Queries (All Scopes)
  // ===========================================================================

  /// Returns true if no items are selected in any scope.
  bool get isEmpty => _byScope.isEmpty;

  /// Returns true if any items are selected in any scope.
  bool get isNotEmpty => _byScope.isNotEmpty;

  /// Returns total selection count across all scopes.
  int get count => _byScope.values.fold(0, (sum, set) => sum + set.length);

  /// Returns all selected keys across all scopes.
  ///
  /// Note: A key selected in multiple scopes appears once.
  Set<String> get allSelected {
    final result = <String>{};
    _byScope.values.forEach(result.addAll);
    return result;
  }

  /// Returns all scopes that have selections.
  Iterable<Object?> get scopes => _byScope.keys;

  // ===========================================================================
  // Tree Operations
  // ===========================================================================

  /// {@template mz_collection.selection_manager_count_in_tree}
  /// Returns the selection count for a tree rooted at [root].
  ///
  /// The [keysIn] callback returns the selectable keys at each node.
  /// The [childrenOf] callback returns child nodes for traversal.
  ///
  /// ```dart
  /// final count = selection.countInTree(
  ///   'src',
  ///   scope: scope,
  ///   keysIn: (folder) => filesInFolder[folder] ?? [],
  ///   childrenOf: (folder) => subfolders[folder] ?? [],
  /// );
  /// ```
  /// {@endtemplate}
  int countInTree(
    String root, {
    required Iterable<String> Function(String node) keysIn,
    required ChildrenOf childrenOf,
    Object? scope,
  }) {
    var total = countIn(keysIn(root), scope: scope);
    for (final child in childrenOf(root)) {
      total += countInTree(
        child,
        scope: scope,
        keysIn: keysIn,
        childrenOf: childrenOf,
      );
    }
    return total;
  }

  /// {@template mz_collection.selection_manager_state_of_tree}
  /// Returns the selection state for a tree rooted at [root].
  ///
  /// The [totalKeys] parameter is the total number of selectable keys
  /// in the entire subtree.
  ///
  /// ```dart
  /// final state = selection.stateOfTree(
  ///   'src',
  ///   totalKeys: 50,
  ///   scope: scope,
  ///   keysIn: (folder) => filesInFolder[folder] ?? [],
  ///   childrenOf: (folder) => subfolders[folder] ?? [],
  /// );
  /// ```
  /// {@endtemplate}
  SelectionState stateOfTree(
    String root, {
    required int totalKeys,
    required Iterable<String> Function(String node) keysIn,
    required ChildrenOf childrenOf,
    Object? scope,
  }) {
    if (totalKeys <= 0) return SelectionState.none;

    final selectedCount = countInTree(
      root,
      scope: scope,
      keysIn: keysIn,
      childrenOf: childrenOf,
    );

    if (selectedCount == 0) return SelectionState.none;
    if (selectedCount >= totalKeys) return SelectionState.all;
    return SelectionState.partial;
  }

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  @override
  void dispose() {
    _byScope.clear();
    super.dispose();
  }

  @override
  String toString() {
    final scopeCount = _byScope.length;
    final totalCount = count;
    return 'SelectionManager(scopes: $scopeCount, selected: $totalCount)';
  }

  // ===========================================================================
  // State Serialization
  // ===========================================================================

  /// Returns a [SelectionSnapshot] containing selections from the default scope
  /// that can be serialized to JSON or a query string for persistence, deep
  /// linking, or sharing.
  ///
  /// Only the default scope (null) is serialized. Scoped selections are
  /// considered transient UI state and are not included.
  ///
  /// {@tool snippet}
  /// Capturing and restoring selection state:
  ///
  /// ```dart
  /// // Capture current state (default scope only)
  /// final snapshot = selection.captureState();
  ///
  /// // Serialize to JSON for storage
  /// final json = snapshot.toJson();
  /// localStorage.setItem('selection', jsonEncode(json));
  ///
  /// // Or convert to URL query string
  /// final url = '/items?${snapshot.toQueryString()}';
  ///
  /// // Later, restore the state
  /// final savedJson = jsonDecode(localStorage.getItem('selection'));
  /// final restored = SelectionSnapshot.fromJson(savedJson);
  /// selection.restoreState(restored);
  /// ```
  /// {@end-tool}
  SelectionSnapshot captureState() {
    final defaultSelection = _byScope[null];
    if (defaultSelection == null || defaultSelection.isEmpty) {
      return const SelectionSnapshot.empty();
    }
    return SelectionSnapshot._(Set.unmodifiable(defaultSelection));
  }

  /// Restores selection state from a [SelectionSnapshot].
  ///
  /// Only restores to the default scope. Existing selections in the default
  /// scope are replaced. Scoped selections are not affected.
  ///
  /// {@tool snippet}
  /// Restoring selection state from a URL:
  ///
  /// ```dart
  /// // From URL query string
  /// final snapshot = SelectionSnapshot<String>.fromQueryString(
  ///   Uri.parse(url).query,
  /// );
  /// selection.restoreState(snapshot);
  ///
  /// // From stored JSON
  /// final snapshot = SelectionSnapshot<String>.fromJson(savedJson);
  /// selection.restoreState(snapshot);
  /// ```
  /// {@end-tool}
  void restoreState(SelectionSnapshot snapshot) {
    if (snapshot.isEmpty) {
      clear();
      return;
    }

    _byScope[null] = Set<String>.from(snapshot._keys);
    notifyChanged();
  }
}

// =============================================================================
// Selection Snapshot (Serialization)
// =============================================================================

/// {@template mz_collection.selection_snapshot}
/// A serializable snapshot of selection state (default scope only).
///
/// Use this to persist selection state, create shareable URLs, or restore
/// selection configurations.
///
/// Note: Only selections from the default scope are captured. Scoped selections
/// are considered transient UI state (e.g., tabs) and are not serialized.
///
/// ## JSON Serialization
///
/// {@tool snippet}
/// Serialize selection state to JSON:
///
/// ```dart
/// final snapshot = selection.captureState();
///
/// // To JSON
/// final json = snapshot.toJson();
/// // Result: {'keys': ['item1', 'item2', 'item3']}
///
/// // From JSON
/// final restored = SelectionSnapshot<String>.fromJson(json);
/// ```
/// {@end-tool}
///
/// ## URL Query String
///
/// {@tool snippet}
/// Serialize selection state to URL query string:
///
/// ```dart
/// final snapshot = selection.captureState();
///
/// // To query string
/// final query = snapshot.toQueryString();
/// // Result: 'selected=item1,item2,item3'
///
/// // Build URL
/// final url = '/items?$query';
///
/// // From query string
/// final restored = SelectionSnapshot<String>.fromQueryString(query);
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [SelectionManager.captureState] - Creates a snapshot from current state.
/// * [SelectionManager.restoreState] - Restores state from a snapshot.
/// {@endtemplate}
@immutable
class SelectionSnapshot {
  const SelectionSnapshot._(this._keys);

  /// Creates an empty selection snapshot.
  const SelectionSnapshot.empty() : _keys = const {};

  /// Creates a selection snapshot from a set of keys.
  factory SelectionSnapshot.fromKeys(Set<String> keys) {
    if (keys.isEmpty) return const SelectionSnapshot.empty();
    return SelectionSnapshot._(Set.unmodifiable(keys));
  }

  /// Creates a snapshot from a JSON map.
  ///
  /// The map should have a 'keys' field with a list of key values.
  factory SelectionSnapshot.fromJson(Map<String, dynamic> json) {
    final keysList = json['keys'] as List<dynamic>?;
    if (keysList == null || keysList.isEmpty) {
      return const SelectionSnapshot.empty();
    }
    final keys = keysList.cast<String>().toSet();
    return SelectionSnapshot._(Set.unmodifiable(keys));
  }

  /// Creates a snapshot from a URL query string.
  ///
  /// Parses the `selected` parameter with comma-separated keys.
  factory SelectionSnapshot.fromQueryString(String queryString) {
    if (queryString.isEmpty) return const SelectionSnapshot.empty();

    final params = Uri.splitQueryString(queryString);
    final selectedValue = params['selected'];
    if (selectedValue == null || selectedValue.isEmpty) {
      return const SelectionSnapshot.empty();
    }

    final keyStrings = selectedValue.split(',');
    final keys = <String>{};

    for (final keyString in keyStrings) {
      keys.add(Uri.decodeComponent(keyString));
    }

    if (keys.isEmpty) return const SelectionSnapshot.empty();
    return SelectionSnapshot._(Set.unmodifiable(keys));
  }

  final Set<String> _keys;

  /// Returns all selected keys in this snapshot.
  Set<String> get keys => _keys;

  /// Whether this snapshot has any selections.
  bool get isEmpty => _keys.isEmpty;

  /// Whether this snapshot has selections.
  bool get isNotEmpty => _keys.isNotEmpty;

  /// The number of selections in this snapshot.
  int get length => _keys.length;

  /// Whether a key is selected in this snapshot.
  bool contains(String key) => _keys.contains(key);

  /// Converts this snapshot to a JSON-serializable map.
  ///
  /// The resulting map can be encoded with `jsonEncode` and stored or
  /// transmitted.
  ///
  Map<String, dynamic> toJson() {
    return {
      'keys': _keys.toList(),
    };
  }

  /// Converts this snapshot to a URL query string.
  ///
  /// Format: `selected={key1},{key2},{key3}`
  ///
  /// Keys are URL-encoded. Empty selections are omitted.
  String toQueryString() {
    if (_keys.isEmpty) return '';

    final encodedKeys = _keys.map(Uri.encodeComponent).join(',');
    return 'selected=$encodedKeys';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SelectionSnapshot) return false;
    if (_keys.length != other._keys.length) return false;
    return _keys.containsAll(other._keys);
  }

  @override
  int get hashCode => Object.hashAll(_keys);

  @override
  String toString() => 'SelectionSnapshot($_keys)';
}
