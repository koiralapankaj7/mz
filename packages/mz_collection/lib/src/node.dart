// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

/// {@template mz_collection.node_library}
/// A pure Dart tree node system for hierarchical collection management.
///
/// ## Why Node?
///
/// Traditional list-based collections fall short when applications need:
///
/// - **Hierarchical organization** - Items naturally form parent-child
///   relationships (folders, categories, org charts, nested menus)
/// - **O(1) key lookups** - Fast access to items by unique key without
///   scanning the entire collection
/// - **Collapse/expand state** - Tree views need to track visibility of
///   subtrees independently of data structure
/// - **Flexible traversal** - BFS or DFS iteration, visible-only filtering,
///   path queries, and ancestor/descendant navigation
/// - **Framework independence** - Tree logic that works in Flutter, CLI
///   tools, servers, or any Dart environment
///
/// Node combines what typically requires separate tree, map, and state
/// management packages into a unified solution.
///
/// ## Key Features
///
/// ```text
/// +---------------------------+--------------------------------------+
/// |          Feature          |            Description               |
/// +---------------------------+--------------------------------------+
/// | Generic items (T)         | No interface requirements on items   |
/// | O(1) key lookups          | Internal Map for fast access by key  |
/// | Iterable<T> support       | Use where(), map(), for-in directly  |
/// | Collapse/expand state     | Built-in visibility for tree views   |
/// | BFS/DFS traversal         | descendants(), visibleDescendants()  |
/// | Tree manipulation         | moveTo(), detach(), replaceWith()    |
/// | Path navigation           | pathFromRoot, parents, siblings      |
/// | Pure Dart                 | No Flutter dependency required       |
/// +---------------------------+--------------------------------------+
/// ```
///
/// ## Tree Structure
///
/// ```text
/// +-------------------------------------------------------------------+
/// |                          Node<T>                                  |
/// |                                                                   |
/// |  |   List<T>         |     |  Map<String, T>   |                  |
/// |  | (ordered storage) |     | (O(1) lookup)     |                  |
/// |  +-------------------+     +-------------------+                  |
/// |                                                                   |
/// |                    +-------------------+                          |
/// |                    |    _children      |                          |
/// |                    | Map<String, Node> |                          |
/// |                    +--------+----------+                          |
/// |                             |                                     |
/// |         +-------------------+-------------------+                 |
/// |         |                   |                   |                 |
/// |         v                   v                   v                 |
/// |  +------------+      +------------+      +------------+           |
/// |  | Node 'a'   |      | Node 'b'   |      | Node 'c'   |           |
/// |  | depth: 1   |      | depth: 1   |      | depth: 1   |           |
/// |  +-----+------+      +------------+      +-----+------+           |
/// |        |                                       |                  |
/// |        v                                       v                  |
/// |  +------------+                         +------------+            |
/// |  | Node 'a1'  |                         | Node 'c1'  |            |
/// |  | depth: 2   |                         | depth: 2   |            |
/// |  +------------+                         +------------+            |
/// +-------------------------------------------------------------------+
/// ```
///
/// ## Quick Start
///
/// {@tool snippet}
/// Basic tree operations:
///
/// ```dart
/// // Create a root node with User items
/// final root = Node<User>(
///   id: 'users',
///   keyOf: (user) => user.id,
/// );
///
/// // Add items to the node
/// root.add(User(id: '1', name: 'Alice'));
/// root.add(User(id: '2', name: 'Bob'));
///
/// // O(1) lookup by key
/// final alice = root['1'];
///
/// // Iterate directly (Iterable<T>)
/// for (final user in root) {
///   print(user.name);
/// }
///
/// // Use Iterable methods
/// final admins = root.where((u) => u.isAdmin);
/// ```
/// {@end-tool}
///
/// {@tool snippet}
/// Building hierarchical structures:
///
/// ```dart
/// final root = Node<String, Task>(id: 'root', keyOf: (t) => t.id);
///
/// // Create child nodes
/// final inbox = Node<String, Task>(id: 'inbox', keyOf: (t) => t.id);
/// final work = Node<String, Task>(id: 'work', keyOf: (t) => t.id);
///
/// root.addChild(inbox);
/// root.addChild(work);
///
/// // Add items to children
/// inbox.add(Task(id: 't1', title: 'Review PR'));
/// work.add(Task(id: 't2', title: 'Write docs'));
///
/// // Traverse all nodes (BFS by default)
/// for (final node in root.descendants()) {
///   print('${node.id}: ${node.length} items');
/// }
///
/// // Get all items across the tree
/// final allTasks = root.flattenedItems.toList();
/// ```
/// {@end-tool}
///
/// {@tool snippet}
/// Collapse and expand for tree views:
///
/// ```dart
/// // Collapse a node (hides children in visibleDescendants)
/// inbox.collapse(state: Tristate.yes);
///
/// // Only visible nodes (respects collapse state)
/// for (final node in root.visibleDescendants()) {
///   renderNode(node);
/// }
///
/// // Expand to reveal a specific node
/// deeplyNestedNode.expandToThis();
///
/// // Collapse everything beyond level 2
/// root.collapseToLevel(2);
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [KeyOf] - Function type for extracting keys from items.
/// * [Tristate] - Three-way state for collapse toggle operations.
/// * [Listenable] - Pure Dart change notification mixin.
/// {@endtemplate}
library;

import 'dart:collection' show Queue;
import 'package:meta/meta.dart';
import 'core.dart';
export 'core.dart' show Listenable, Listener, Tristate;

/// Extracts a unique string key from an item.
typedef KeyOf<T> = String Function(T item);

/// {@template mz_collection.node}
/// A tree node that stores items and child nodes.
///
/// Implements [Iterable<T>] for direct iteration over items.
///
/// ## Storage
///
/// Items are stored in both a [List] (for ordering) and a [Map] (for O(1)
/// lookup by key). This trades memory for speed.
///
/// ## Example
///
/// ```dart
/// final root = Node<String, Task>(id: 'root', keyOf: (t) => t.id);
///
/// // Add items
/// root.add(Task(id: '1', title: 'Buy milk'));
/// root.addAll([task2, task3]);
///
/// // Create hierarchy
/// final inbox = Node<String, Task>(id: 'inbox', keyOf: (t) => t.id);
/// root.addChild(inbox);
///
/// // Iterate (Iterable<T>)
/// for (final task in root) { }
/// root.where((t) => t.isDone);
/// root.map((t) => t.title);
///
/// // O(1) lookup
/// final task = root['1'];
/// ```
/// {@endtemplate}
class Node<T> with Listenable, Iterable<T> {
  /// {@macro mz_collection.node}
  Node({
    required this.id,
    required this.keyOf,
    this.extra,
    Iterable<T>? items,
    Iterable<Node<T>>? children,
  }) {
    if (items != null) addAll(items, notify: false);
    if (children != null) {
      for (final child in children) {
        addChild(child, notify: false);
      }
    }
  }

  /// Unique identifier for this node.
  final String id;

  /// Extracts a unique string key from an item.
  final KeyOf<T> keyOf;

  /// Additional data associated with this node.
  final Object? extra;

  // ===========================================================================
  // Storage
  // ===========================================================================

  final List<T> _items = [];
  final Map<String, T> _byKey = {};
  final Map<String, Node<T>> _children = {};
  Node<T>? _parent;
  int _depth = 0;
  int _version = 0;
  bool _isCollapsed = false;
  int? _cachedHeight;

  // ---------------------------------------------------------------------------
  // Recursion Safety
  // ---------------------------------------------------------------------------
  // HYBRID RECURSION STRATEGY: Tree methods use recursion for readability and
  // performance, but switch to iterative approach when depth exceeds threshold.
  // This prevents stack overflow on deep trees (10,000+ nodes in a chain) while
  // maintaining optimal performance for typical trees (depth < 100).
  //
  // Methods using this pattern: findNode, findNodeByKey, flattenedLength,
  // leaves, clone, deepEquals.
  //
  // See: memory_benchmark.dart for deep tree test cases.
  static const _recursionThreshold = 100;

  // ===========================================================================
  // Iterable<T> Implementation
  // ===========================================================================

  @override
  Iterator<T> get iterator => _items.iterator;

  @override
  int get length => _items.length;

  @override
  bool get isEmpty => _items.isEmpty;

  @override
  bool get isNotEmpty => _items.isNotEmpty;

  // ===========================================================================
  // Item Operations
  // ===========================================================================

  /// Adds an item. Returns `true` if added, `false` if key already exists.
  bool add(T item, {bool notify = true}) {
    final key = keyOf(item);
    if (_byKey.containsKey(key)) return false;

    _items.add(item);
    _byKey[key] = item;
    _version++;

    if (notify) notifyChanged();
    return true;
  }

  /// Adds multiple items. Returns count of items added.
  int addAll(Iterable<T> items, {bool notify = true}) {
    var count = 0;
    for (final item in items) {
      if (add(item, notify: false)) count++;
    }
    if (notify && count > 0) notifyChanged();
    return count;
  }

  /// Inserts an item at index. Returns `false` if key exists.
  bool insert(int index, T item, {bool notify = true}) {
    final key = keyOf(item);
    if (_byKey.containsKey(key)) return false;

    _items.insert(index, item);
    _byKey[key] = item;
    _version++;

    if (notify) notifyChanged();
    return true;
  }

  /// Removes an item. Returns the removed item or null.
  T? remove(T item, {bool notify = true}) {
    final key = keyOf(item);
    final existing = _byKey.remove(key);
    if (existing == null) return null;

    _items.remove(existing);
    _version++;

    if (notify) notifyChanged();
    return existing;
  }

  /// Removes an item by key. Returns the removed item or null.
  T? removeByKey(String key, {bool notify = true}) {
    final item = _byKey.remove(key);
    if (item == null) return null;

    _items.remove(item);
    _version++;

    if (notify) notifyChanged();
    return item;
  }

  /// Removes items matching [test]. Returns removed items.
  List<T> removeWhere(bool Function(T) test, {bool notify = true}) {
    final removed = <T>[];
    _items.removeWhere((item) {
      if (test(item)) {
        _byKey.remove(keyOf(item));
        removed.add(item);
        return true;
      }
      return false;
    });

    if (removed.isNotEmpty) {
      _version++;
      if (notify) notifyChanged();
    }
    return removed;
  }

  /// Replaces an item with the same key, or adds if not found.
  ///
  /// Returns `true` if replaced, `false` if added new.
  bool replace(T item, {bool notify = true}) {
    final key = keyOf(item);

    // O(1) map lookup to check existence first
    if (!_byKey.containsKey(key)) {
      // Key doesn't exist - add new item without scanning
      add(item, notify: notify);
      return false;
    }

    // Key exists - need to find index for list update
    // This is O(n) but only runs when actually replacing
    final index = _items.indexWhere((e) => keyOf(e) == key);
    if (index != -1) {
      _items[index] = item;
    }
    _byKey[key] = item;
    _version++;
    if (notify) notifyChanged();
    return true;
  }

  /// Replaces item at [oldKey] with [item]. Handles key changes.
  bool replaceByKey(String oldKey, T item, {bool notify = true}) {
    // O(1) map lookup to check existence first
    if (!_byKey.containsKey(oldKey)) {
      return false;
    }

    // Key exists - find index for list update
    final index = _items.indexWhere((e) => keyOf(e) == oldKey);
    if (index == -1) return false;

    final newKey = keyOf(item);
    _byKey.remove(oldKey);
    _items[index] = item;
    _byKey[newKey] = item;
    _version++;

    if (notify) notifyChanged();
    return true;
  }

  /// Clears all items. Returns `true` if any were removed.
  bool clear({bool notify = true}) {
    if (_items.isEmpty) return false;

    _items.clear();
    _byKey.clear();
    _version++;

    if (notify) notifyChanged();
    return true;
  }

  /// Adds or updates an item based on key existence.
  ///
  /// Returns `true` if the item was added (new), `false` if updated (replaced).
  bool upsert(T item, {bool notify = true}) {
    final key = keyOf(item);
    final isNew = !_byKey.containsKey(key);

    if (isNew) {
      _items.add(item);
    } else {
      final index = _items.indexWhere((e) => keyOf(e) == key);
      if (index != -1) _items[index] = item;
    }

    _byKey[key] = item;
    _version++;
    if (notify) notifyChanged();
    return isNew;
  }

  /// Adds or updates multiple items based on key existence.
  ///
  /// Returns the count of newly added items (not updates).
  int upsertAll(Iterable<T> items, {bool notify = true}) {
    var addedCount = 0;

    for (final item in items) {
      final key = keyOf(item);
      final isNew = !_byKey.containsKey(key);

      if (isNew) {
        _items.add(item);
        addedCount++;
      } else {
        final index = _items.indexWhere((e) => keyOf(e) == key);
        if (index != -1) _items[index] = item;
      }

      _byKey[key] = item;
    }

    if (items.isNotEmpty) {
      _version++;
      if (notify) notifyChanged();
    }
    return addedCount;
  }

  /// Updates all items using the provided transform function.
  ///
  /// The transform receives each item and should return the updated item.
  /// Keys must remain the same after transformation.
  void updateAll(T Function(T item) transform, {bool notify = true}) {
    if (_items.isEmpty) return;

    for (var i = 0; i < _items.length; i++) {
      final oldItem = _items[i];
      final newItem = transform(oldItem);
      final oldKey = keyOf(oldItem);
      final newKey = keyOf(newItem);

      assert(
        oldKey == newKey,
        'updateAll transform must not change item key: $oldKey -> $newKey',
      );

      _items[i] = newItem;
      _byKey[newKey] = newItem;
    }

    _version++;
    if (notify) notifyChanged();
  }

  /// Sorts items using [compare]. If null, items must be Comparable.
  void sort([Comparator<T>? compare]) {
    _items.sort(compare);
    _version++;
    notifyChanged();
  }

  // ===========================================================================
  // Item Navigation
  // ===========================================================================

  /// Returns the item after [item], or null if at end or not found.
  T? next(T item) {
    final index = indexOf(item);
    if (index == -1 || index >= _items.length - 1) return null;
    return _items[index + 1];
  }

  /// Returns the item before [item], or null if at start or not found.
  T? prev(T item) {
    final index = indexOf(item);
    if (index <= 0) return null;
    return _items[index - 1];
  }

  // ===========================================================================
  // Item Queries
  // ===========================================================================

  /// Returns item by key, or null. O(1).
  T? operator [](String key) => _byKey[key];

  /// Returns item at index.
  T at(int index) => _items[index];

  /// Returns item at index, or null if out of bounds.
  T? atOrNull(int index) =>
      index >= 0 && index < _items.length ? _items[index] : null;

  /// Returns index of item by key, or -1 if not found.
  ///
  /// Uses [keyOf] to match items, providing O(n) lookup by key comparison
  /// rather than relying on item equality.
  int indexOf(T item) {
    final key = keyOf(item);
    for (var i = 0; i < _items.length; i++) {
      if (keyOf(_items[i]) == key) return i;
    }
    return -1;
  }

  /// Whether node contains key. O(1).
  bool containsKey(String key) => _byKey.containsKey(key);

  /// All keys in this node.
  Iterable<String> get keys => _byKey.keys;

  /// Version number, incremented on each modification.
  int get version => _version;

  // ===========================================================================
  // Child Operations
  // ===========================================================================

  /// Adds a child node.
  void addChild(Node<T> child, {bool notify = true}) {
    child
      .._parent = this
      .._depth = _depth + 1;
    _children[child.id] = child;
    _version++;
    _invalidateHeight();

    if (notify) notifyChanged();
  }

  /// Removes a child node. Returns the removed node or null.
  Node<T>? removeChild(String childId, {bool notify = true}) {
    final child = _children.remove(childId);
    if (child == null) return null;

    child._parent = null;
    _version++;
    _invalidateHeight();

    if (notify) notifyChanged();
    return child;
  }

  /// Clears all children. Returns `true` if any were removed.
  bool clearChildren({bool notify = true}) {
    if (_children.isEmpty) return false;

    for (final child in _children.values) {
      child._parent = null;
    }
    _children.clear();
    _version++;
    _invalidateHeight();

    if (notify) notifyChanged();
    return true;
  }

  /// Returns child by id, or null. O(1).
  Node<T>? child(String childId) => _children[childId];

  /// Immediate children.
  Iterable<Node<T>> get children => _children.values;

  /// Child ids.
  Iterable<String> get childIds => _children.keys;

  /// Number of immediate children.
  int get childCount => _children.length;

  /// Whether this node has children.
  bool get hasChildren => _children.isNotEmpty;

  /// Whether this node is a leaf (has no children).
  bool get isLeaf => _children.isEmpty;

  /// Whether this node is a branch (has children).
  bool get isBranch => _children.isNotEmpty;

  /// Index of this node in parent's children (-1 if root).
  int get childIndex {
    final p = _parent;
    if (p == null) return -1;
    // Use indexed access since we're iterating anyway
    final childKeys = p._children.keys.toList();
    return childKeys.indexOf(id);
  }

  /// Returns child at [index], or `null` if out of bounds.
  Node<T>? childAt(int index) {
    if (index < 0 || index >= _children.length) return null;
    return _children.values.elementAt(index);
  }

  /// Adds multiple child nodes.
  ///
  /// Returns count of children added.
  int addChildren(Iterable<Node<T>> children, {bool notify = true}) {
    var count = 0;
    for (final child in children) {
      child
        .._parent = this
        .._depth = _depth + 1;
      _children[child.id] = child;
      count++;
    }
    if (count > 0) {
      _version++;
      _invalidateHeight();
      if (notify) notifyChanged();
    }
    return count;
  }

  /// Removes multiple children by id.
  ///
  /// Returns list of removed nodes.
  List<Node<T>> removeChildren(
    Iterable<String> childIds, {
    bool notify = true,
  }) {
    final removed = <Node<T>>[];
    for (final childId in childIds) {
      final child = _children.remove(childId);
      if (child != null) {
        child._parent = null;
        removed.add(child);
      }
    }
    if (removed.isNotEmpty) {
      _version++;
      _invalidateHeight();
      if (notify) notifyChanged();
    }
    return removed;
  }

  /// Inserts a child at a specific index position.
  ///
  /// If [index] is out of bounds, the child is added at the end.
  void insertChildAt(int index, Node<T> child, {bool notify = true}) {
    child
      .._parent = this
      .._depth = _depth + 1;

    final entries = _children.entries.toList();
    final clampedIndex = index.clamp(0, entries.length);

    // Rebuild map with child inserted at position
    final newChildren = <String, Node<T>>{};
    var i = 0;
    for (final entry in entries) {
      if (i == clampedIndex) {
        newChildren[child.id] = child;
      }
      newChildren[entry.key] = entry.value;
      i++;
    }
    // Handle append case
    if (clampedIndex >= entries.length) {
      newChildren[child.id] = child;
    }

    _children
      ..clear()
      ..addAll(newChildren);

    _version++;
    _invalidateHeight();
    if (notify) notifyChanged();
  }

  /// Moves a child from one index to another.
  ///
  /// Returns `true` if reordered, `false` if indices are invalid or same.
  bool reorderChild(int fromIndex, int toIndex, {bool notify = true}) {
    if (fromIndex == toIndex) return false;
    if (fromIndex < 0 || fromIndex >= _children.length) return false;
    if (toIndex < 0 || toIndex >= _children.length) return false;

    final entries = _children.entries.toList();
    final moved = entries.removeAt(fromIndex);
    entries.insert(toIndex, moved);

    _children
      ..clear()
      ..addEntries(entries);

    _version++;
    if (notify) notifyChanged();
    return true;
  }

  /// Swaps two children by their ids.
  ///
  /// Returns `true` if swapped, `false` if either child not found.
  bool swapChildren(String childId1, String childId2, {bool notify = true}) {
    if (childId1 == childId2) return false;
    if (!_children.containsKey(childId1)) return false;
    if (!_children.containsKey(childId2)) return false;

    final entries = _children.entries.toList();
    final index1 = entries.indexWhere((e) => e.key == childId1);
    final index2 = entries.indexWhere((e) => e.key == childId2);

    final temp = entries[index1];
    entries[index1] = entries[index2];
    entries[index2] = temp;

    _children
      ..clear()
      ..addEntries(entries);

    _version++;
    if (notify) notifyChanged();
    return true;
  }

  // ===========================================================================
  // Tree Navigation
  // ===========================================================================

  /// Parent node, or null if root.
  Node<T>? get parent => _parent;

  /// Whether this node has a parent.
  bool get hasParent => _parent != null;

  /// Depth in tree (root = 0).
  int get depth => _depth;

  /// Height of the subtree (0 for leaf nodes).
  ///
  /// Height is the length of the longest path from this node to a leaf.
  /// This value is cached and only recomputed when the tree structure changes.
  ///
  /// ```dart
  /// // Leaf node: height = 0
  /// // Node with only leaf children: height = 1
  /// // Node with grandchildren: height >= 2
  /// ```
  int get height {
    if (_cachedHeight != null) return _cachedHeight!;

    if (_children.isEmpty) {
      _cachedHeight = 0;
      return 0;
    }

    var maxChildHeight = 0;
    for (final child in _children.values) {
      final childHeight = child.height;
      if (childHeight > maxChildHeight) maxChildHeight = childHeight;
    }
    _cachedHeight = maxChildHeight + 1;
    return _cachedHeight!;
  }

  /// Invalidates the cached height and propagates to ancestors.
  void _invalidateHeight() {
    _cachedHeight = null;
    _parent?._invalidateHeight();
  }

  /// Root node of the tree.
  Node<T> get root {
    var node = this;
    while (node._parent != null) {
      node = node._parent!;
    }
    return node;
  }

  /// Parents from immediate to root.
  Iterable<Node<T>> get parents sync* {
    var p = _parent;
    while (p != null) {
      yield p;
      p = p._parent;
    }
  }

  // ===========================================================================
  // Tree Search
  // ===========================================================================

  /// Finds node by id in subtree. O(n) worst case.
  ///
  /// Uses hybrid recursion: recursive for shallow trees, iterative for deep.
  Node<T>? findNode(String nodeId) => _findNode(nodeId, 0);

  Node<T>? _findNode(String nodeId, int depth) {
    if (id == nodeId) return this;

    // Switch to iterative if we're too deep (prevents stack overflow)
    if (depth > _recursionThreshold) {
      return _findNodeIterative(nodeId);
    }

    for (final child in _children.values) {
      final found = child._findNode(nodeId, depth + 1);
      if (found != null) return found;
    }
    return null;
  }

  Node<T>? _findNodeIterative(String nodeId) {
    final stack = <Node<T>>[this];
    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      if (node.id == nodeId) return node;
      node._children.values.forEach(stack.add);
    }
    return null;
  }

  /// Finds node containing key in subtree.
  ///
  /// Uses hybrid recursion: recursive for shallow trees, iterative for deep.
  Node<T>? findNodeByKey(String key) => _findNodeByKey(key, 0);

  Node<T>? _findNodeByKey(String key, int depth) {
    if (_byKey.containsKey(key)) return this;

    // Switch to iterative if we're too deep (prevents stack overflow)
    if (depth > _recursionThreshold) {
      return _findNodeByKeyIterative(key);
    }

    for (final child in _children.values) {
      final found = child._findNodeByKey(key, depth + 1);
      if (found != null) return found;
    }
    return null;
  }

  Node<T>? _findNodeByKeyIterative(String key) {
    final stack = <Node<T>>[this];
    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      if (node._byKey.containsKey(key)) return node;
      node._children.values.forEach(stack.add);
    }
    return null;
  }

  /// Finds node containing item in subtree.
  Node<T>? findNodeByItem(T item) => findNodeByKey(keyOf(item));

  // ===========================================================================
  // Tree Manipulation
  // ===========================================================================

  /// Detaches this node from its parent.
  ///
  /// Does nothing if already detached.
  ///
  /// ```dart
  /// final child = parent.child('child1');
  /// child?.detach(); // Now child has no parent
  /// ```
  void detach({bool notify = true}) {
    final p = _parent;
    if (p == null) return;

    p._children.remove(id);
    p._version++;
    _parent = null;
    _updateDepthRecursive(0);
    p._invalidateHeight();

    if (notify) p.notifyChanged();
  }

  /// Moves this node to a new parent.
  ///
  /// Detaches from current parent (if any) and attaches to [newParent].
  /// Returns `true` if move was successful.
  ///
  /// ```dart
  /// folder.moveTo(anotherFolder);
  /// ```
  bool moveTo(Node<T> newParent, {bool notify = true}) {
    // Prevent moving to self or descendant
    if (newParent.id == id || isAncestorOf(newParent)) return false;

    final oldParent = _parent;
    final changed = oldParent != null || _parent != newParent;

    // Detach from old parent
    if (oldParent != null) {
      oldParent._children.remove(id);
      oldParent._version++;
      oldParent._invalidateHeight();
    }

    // Attach to new parent
    _parent = newParent;
    newParent._children[id] = this;
    newParent._version++;
    _updateDepthRecursive(newParent._depth + 1);
    newParent._invalidateHeight();

    if (notify && changed) {
      oldParent?.notifyChanged();
      newParent.notifyChanged();
    }
    return true;
  }

  /// Replaces this node with [other] in the tree.
  ///
  /// This node is detached and [other] takes its place in the parent.
  /// Returns `true` if replacement was successful.
  ///
  /// ```dart
  /// oldNode.replaceWith(newNode);
  /// // newNode is now in oldNode's position
  /// ```
  bool replaceWith(Node<T> other, {bool notify = true}) {
    final p = _parent;
    if (p == null) return false;

    // Remove this node
    p._children.remove(id);
    _parent = null;
    _updateDepthRecursive(0);

    // Add other node
    other._parent = p;
    p._children[other.id] = other;
    other._updateDepthRecursive(p._depth + 1);
    p._version++;
    p._invalidateHeight();

    if (notify) p.notifyChanged();
    return true;
  }

  /// Updates depth for this node and all descendants.
  void _updateDepthRecursive(int newDepth) {
    _depth = newDepth;
    for (final child in _children.values) {
      child._updateDepthRecursive(newDepth + 1);
    }
  }

  // ===========================================================================
  // Collapse State
  // ===========================================================================

  /// Whether this node is collapsed.
  ///
  /// Collapsed nodes hide their children in tree views.
  bool get isCollapsed => _isCollapsed;

  /// Whether this node is expanded (not collapsed).
  bool get isExpanded => !_isCollapsed;

  /// Toggles the collapse state.
  ///
  /// Returns the new collapse state.
  bool toggle({bool notify = true}) {
    return collapse(notify: notify);
  }

  /// Modifies the collapse state.
  ///
  /// The [state] parameter controls the operation:
  /// - [Tristate.yes] - Collapse the node
  /// - [Tristate.no] - Expand the node
  /// - [Tristate.toggle] - Toggle current state (default)
  ///
  /// Returns the new collapse state.
  bool collapse({Tristate state = Tristate.toggle, bool notify = true}) {
    final shouldCollapse = switch (state) {
      Tristate.yes => true,
      Tristate.no => false,
      Tristate.toggle => !_isCollapsed,
    };

    if (shouldCollapse == _isCollapsed) return _isCollapsed;

    _isCollapsed = shouldCollapse;
    _version++;

    if (notify) notifyChanged();
    return _isCollapsed;
  }

  /// Expands all ancestors so this node becomes visible.
  ///
  /// Useful for "reveal in tree" functionality.
  void expandToThis({bool notify = true}) {
    var changed = false;
    for (final ancestor in parents) {
      if (ancestor._isCollapsed) {
        ancestor._isCollapsed = false;
        ancestor._version++;
        changed = true;
      }
    }
    if (notify && changed) {
      // Notify from root down (reverse iteration without extra allocation)
      final ancestorList = parents.toList();
      for (var i = ancestorList.length - 1; i >= 0; i--) {
        ancestorList[i].notifyChanged();
      }
    }
  }

  /// Collapses nodes beyond [level] depth from this node.
  ///
  /// - Level 0: This node is collapsed
  /// - Level 1: This node expanded, children collapsed
  /// - Level 2: This + children expanded, grandchildren collapsed
  ///
  /// ```dart
  /// // Expand first 2 levels, collapse everything deeper
  /// root.collapseToLevel(2);
  /// ```
  void collapseToLevel(int level, {bool notify = true}) {
    final changed = <Node<T>>[];

    void traverse(Node<T> node, int currentLevel) {
      final shouldCollapse = currentLevel >= level;
      if (node._isCollapsed != shouldCollapse) {
        node._isCollapsed = shouldCollapse;
        node._version++;
        changed.add(node);
      }
      for (final child in node._children.values) {
        traverse(child, currentLevel + 1);
      }
    }

    traverse(this, 0);

    if (notify && changed.isNotEmpty) {
      for (final node in changed) {
        node.notifyChanged();
      }
    }
  }

  /// Expands all nodes in the subtree.
  void expandAll({bool notify = true}) {
    final changed = <Node<T>>[];

    for (final node in descendants()) {
      if (node._isCollapsed) {
        node._isCollapsed = false;
        node._version++;
        changed.add(node);
      }
    }

    if (notify && changed.isNotEmpty) {
      for (final node in changed) {
        node.notifyChanged();
      }
    }
  }

  /// Collapses all nodes in the subtree.
  void collapseAll({bool notify = true}) {
    final changed = <Node<T>>[];

    for (final node in descendants()) {
      if (!node._isCollapsed) {
        node._isCollapsed = true;
        node._version++;
        changed.add(node);
      }
    }

    if (notify && changed.isNotEmpty) {
      for (final node in changed) {
        node.notifyChanged();
      }
    }
  }

  // ===========================================================================
  // Tree Iteration
  // ===========================================================================

  /// All nodes in subtree, including this node.
  ///
  /// By default uses breadth-first (BFS) traversal. Set [depthFirst] to `true`
  /// for depth-first (DFS) pre-order traversal.
  ///
  /// ```dart
  /// // BFS: root, child1, child2, grandchild1, grandchild2
  /// for (final node in root.descendants()) { }
  ///
  /// // DFS: root, child1, grandchild1, child2, grandchild2
  /// for (final node in root.descendants(depthFirst: true)) { }
  /// ```
  Iterable<Node<T>> descendants({bool depthFirst = false}) sync* {
    if (depthFirst) {
      // DFS pre-order using stack
      final stack = <Node<T>>[this];
      while (stack.isNotEmpty) {
        final node = stack.removeLast();
        yield node;
        // Add children in reverse so first child is processed first
        final children = node._children.values.toList();
        for (var i = children.length - 1; i >= 0; i--) {
          stack.add(children[i]);
        }
      }
    } else {
      // BFS using queue
      final queue = Queue<Node<T>>()..add(this);
      while (queue.isNotEmpty) {
        final node = queue.removeFirst();
        yield node;
        queue.addAll(node._children.values);
      }
    }
  }

  /// Visible nodes in subtree (skips children of collapsed nodes).
  ///
  /// Useful for rendering tree views where collapsed nodes hide children.
  ///
  /// By default uses breadth-first (BFS) traversal. Set [depthFirst] to `true`
  /// for depth-first (DFS) pre-order traversal.
  Iterable<Node<T>> visibleDescendants({bool depthFirst = false}) sync* {
    if (depthFirst) {
      final stack = <Node<T>>[this];
      while (stack.isNotEmpty) {
        final node = stack.removeLast();
        yield node;
        if (!node._isCollapsed) {
          final children = node._children.values.toList();
          for (var i = children.length - 1; i >= 0; i--) {
            stack.add(children[i]);
          }
        }
      }
      return;
    }

    final queue = Queue<Node<T>>()..add(this);
    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      yield node;
      if (!node._isCollapsed) {
        queue.addAll(node._children.values);
      }
    }
  }

  /// All items in subtree.
  Iterable<T> get flattenedItems sync* {
    for (final node in descendants()) {
      yield* node._items;
    }
  }

  /// All keys in subtree.
  Iterable<String> get flattenedKeys sync* {
    for (final node in descendants()) {
      yield* node._byKey.keys;
    }
  }

  /// Total item count in subtree.
  ///
  /// Uses hybrid recursion: recursive for shallow trees, iterative for deep.
  int get flattenedLength => _flattenedLength(0);

  int _flattenedLength(int depth) {
    // Switch to iterative if we're too deep (prevents stack overflow)
    if (depth > _recursionThreshold) {
      return _flattenedLengthIterative();
    }

    var count = _items.length;
    for (final child in _children.values) {
      count += child._flattenedLength(depth + 1);
    }
    return count;
  }

  int _flattenedLengthIterative() {
    var count = 0;
    final stack = <Node<T>>[this];
    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      count += node._items.length;
      node._children.values.forEach(stack.add);
    }
    return count;
  }

  /// Leaf nodes (nodes with no children).
  ///
  /// Uses hybrid recursion: recursive for shallow trees, iterative for deep.
  Iterable<Node<T>> get leaves => _leaves(0);

  Iterable<Node<T>> _leaves(int depth) sync* {
    // Switch to iterative if we're too deep (prevents stack overflow)
    if (depth > _recursionThreshold) {
      yield* _leavesIterative();
      return;
    }

    if (_children.isEmpty) {
      yield this;
    } else {
      for (final child in _children.values) {
        yield* child._leaves(depth + 1);
      }
    }
  }

  Iterable<Node<T>> _leavesIterative() sync* {
    final stack = <Node<T>>[this];
    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      if (node._children.isEmpty) {
        yield node;
      } else {
        node._children.values.forEach(stack.add);
      }
    }
  }

  /// Nodes at specific depth from this node.
  Iterable<Node<T>> nodesAtDepth(int targetDepth) sync* {
    if (targetDepth == 0) {
      yield this;
    } else {
      for (final child in _children.values) {
        yield* child.nodesAtDepth(targetDepth - 1);
      }
    }
  }

  // ===========================================================================
  // Item Iteration
  // ===========================================================================

  /// Items in this node in reverse order.
  Iterable<T> get reversedItems => _items.reversed;

  /// All items in subtree, with option to traverse depth-first.
  ///
  /// By default uses breadth-first traversal.
  Iterable<T> flattenedItemsDfs({bool depthFirst = false}) sync* {
    for (final node in descendants(depthFirst: depthFirst)) {
      yield* node._items;
    }
  }

  // ===========================================================================
  // Tree Utilities
  // ===========================================================================

  /// Sibling nodes (nodes with the same parent), excluding this node.
  ///
  /// Returns empty if this is a root node.
  Iterable<Node<T>> get siblings sync* {
    final p = _parent;
    if (p == null) return;
    for (final child in p._children.values) {
      if (child.id != id) yield child;
    }
  }

  /// Path from root to this node (inclusive).
  ///
  /// Useful for breadcrumb navigation.
  ///
  /// ```dart
  /// // For node at path: root > folder > subfolder
  /// final path = subfolder.pathFromRoot;
  /// // Returns: [root, folder, subfolder]
  /// ```
  List<Node<T>> get pathFromRoot {
    final path = <Node<T>>[this];
    var p = _parent;
    while (p != null) {
      path.add(p);
      p = p._parent;
    }
    // Reverse in place instead of creating new list
    for (var i = 0; i < path.length ~/ 2; i++) {
      final j = path.length - 1 - i;
      final temp = path[i];
      path[i] = path[j];
      path[j] = temp;
    }
    return path;
  }

  /// Whether this node is an ancestor of [other].
  ///
  /// Returns `false` if [other] is this node.
  bool isAncestorOf(Node<T> other) {
    var p = other._parent;
    while (p != null) {
      if (p.id == id) return true;
      p = p._parent;
    }
    return false;
  }

  /// Whether this node is a descendant of [other].
  ///
  /// Returns `false` if [other] is this node.
  bool isDescendantOf(Node<T> other) => other.isAncestorOf(this);

  /// Whether this node is a sibling of [other].
  bool isSiblingOf(Node<T> other) =>
      _parent != null && _parent == other._parent && id != other.id;

  /// Lowest common ancestor of this node and [other].
  ///
  /// Returns `null` if nodes are in different trees.
  Node<T>? commonAncestorWith(Node<T> other) {
    final thisAncestors = <String>{id};
    for (final p in parents) {
      thisAncestors.add(p.id);
    }

    if (thisAncestors.contains(other.id)) return other;
    for (final p in other.parents) {
      if (thisAncestors.contains(p.id)) return p;
    }
    return null;
  }

  // ===========================================================================
  // Search Utilities
  // ===========================================================================

  /// Finds first item matching [test] in this node and descendants.
  ///
  /// Returns `null` if no match found.
  ///
  /// ```dart
  /// final task = root.findFirstItem((t) => t.id == 'task-123');
  /// ```
  T? findFirstItem(bool Function(T item) test, {bool depthFirst = false}) {
    for (final node in descendants(depthFirst: depthFirst)) {
      for (final item in node._items) {
        if (test(item)) return item;
      }
    }
    return null;
  }

  /// Finds all items matching [test] in this node and descendants.
  ///
  /// ```dart
  /// final completedTasks = root.findAllItems((t) => t.isDone);
  /// ```
  Iterable<T> findAllItems(
    bool Function(T item) test, {
    bool depthFirst = false,
  }) sync* {
    for (final node in descendants(depthFirst: depthFirst)) {
      for (final item in node._items) {
        if (test(item)) yield item;
      }
    }
  }

  /// Finds first node matching [test] in this node and descendants.
  ///
  /// Returns `null` if no match found.
  ///
  /// ```dart
  /// final inboxNode = root.findFirstNode((n) => n.id == 'inbox');
  /// final nodeWithItems = root.findFirstNode((n) => n.isNotEmpty);
  /// ```
  Node<T>? findFirstNode(
    bool Function(Node<T> node) test, {
    bool depthFirst = false,
  }) {
    for (final node in descendants(depthFirst: depthFirst)) {
      if (test(node)) return node;
    }
    return null;
  }

  /// Finds all nodes matching [test] in this node and descendants.
  ///
  /// ```dart
  /// final emptyNodes = root.findAllNodes((n) => n.isEmpty);
  /// final expandedNodes = root.findAllNodes((n) => n.isExpanded);
  /// ```
  Iterable<Node<T>> findAllNodes(
    bool Function(Node<T> node) test, {
    bool depthFirst = false,
  }) sync* {
    for (final node in descendants(depthFirst: depthFirst)) {
      if (test(node)) yield node;
    }
  }

  /// Whether any item in the subtree matches [test].
  bool anyItem(bool Function(T item) test, {bool depthFirst = false}) {
    return findFirstItem(test, depthFirst: depthFirst) != null;
  }

  /// Whether all items in the subtree match [test].
  ///
  /// Returns `true` for empty tree.
  bool everyItem(bool Function(T item) test, {bool depthFirst = false}) {
    for (final node in descendants(depthFirst: depthFirst)) {
      for (final item in node._items) {
        if (!test(item)) return false;
      }
    }
    return true;
  }

  // ===========================================================================
  // Clone and Copy
  // ===========================================================================

  /// Creates a copy of this node.
  ///
  /// By default creates a deep copy including all descendants. Set [deep] to
  /// `false` for a shallow copy (only this node's items, no children).
  ///
  /// The [newId] parameter allows specifying a different id for the clone.
  ///
  /// Uses hybrid recursion: recursive for shallow trees, iterative for deep.
  ///
  /// ```dart
  /// // Deep copy - includes all children
  /// final copy = node.clone();
  ///
  /// // Shallow copy - only items, no children
  /// final shallow = node.clone(deep: false);
  ///
  /// // Clone with new id
  /// final renamed = node.clone(newId: 'copy-of-node');
  /// ```
  Node<T> clone({bool deep = true, String? newId}) {
    if (deep) {
      return _cloneDeep(newId, 0);
    }
    return _cloneShallow(newId);
  }

  Node<T> _cloneShallow(String? newId) {
    return Node<T>(
      id: newId ?? id,
      keyOf: keyOf,
      extra: extra,
      items: _items,
    ).._isCollapsed = _isCollapsed;
  }

  Node<T> _cloneDeep(String? newId, int depth) {
    // Switch to iterative if we're too deep (prevents stack overflow)
    if (depth > _recursionThreshold) {
      return _cloneDeepIterative(newId);
    }

    final cloned = _cloneShallow(newId);
    for (final child in _children.values) {
      final childClone = child._cloneDeep(null, depth + 1);
      cloned.addChild(childClone, notify: false);
    }
    return cloned;
  }

  Node<T> _cloneDeepIterative(String? newId) {
    // Clone tree iteratively using parallel stacks for original and
    // cloned nodes
    final cloned = _cloneShallow(newId);

    // Stack of (original, clonedParent) pairs to process
    final stack = <(Node<T>, Node<T>)>[];
    for (final child in _children.values) {
      stack.add((child, cloned));
    }

    while (stack.isNotEmpty) {
      final (original, clonedParent) = stack.removeLast();
      final childClone = original._cloneShallow(null);
      clonedParent.addChild(childClone, notify: false);

      for (final grandchild in original._children.values) {
        stack.add((grandchild, childClone));
      }
    }

    return cloned;
  }

  /// Creates a new node with optionally modified properties.
  ///
  /// All unspecified properties are copied from this node.
  /// Items and children can be optionally replaced.
  ///
  /// ```dart
  /// final modified = node.copyWith(
  ///   id: 'new-id',
  ///   extra: {'label': 'Modified'},
  /// );
  /// ```
  Node<T> copyWith({
    String? id,
    KeyOf<T>? keyOf,
    Object? extra,
    Iterable<T>? items,
    Iterable<Node<T>>? children,
    bool? isCollapsed,
  }) {
    return Node<T>(
      id: id ?? this.id,
      keyOf: keyOf ?? this.keyOf,
      extra: extra ?? this.extra,
      items: items ?? _items,
      children: children ?? _children.values,
    ).._isCollapsed = isCollapsed ?? _isCollapsed;
  }

  // ===========================================================================
  // Comparison
  // ===========================================================================

  /// Compares only this node's items with [other]'s items (shallow comparison).
  ///
  /// Does not compare children. Uses [keyOf] to compare item identity.
  ///
  /// ```dart
  /// if (node1.shallowEquals(node2)) {
  ///   print('Same items in this level');
  /// }
  /// ```
  bool shallowEquals(Node<T> other) {
    if (length != other.length) return false;

    for (var i = 0; i < _items.length; i++) {
      if (keyOf(_items[i]) != other.keyOf(other._items[i])) return false;
    }
    return true;
  }

  /// Compares this node and all descendants with [other] (deep comparison).
  ///
  /// Compares structure, items, and collapse state.
  ///
  /// Uses hybrid recursion: recursive for shallow trees, iterative for deep.
  bool deepEquals(Node<T> other) => _deepEquals(other, 0);

  bool _deepEquals(Node<T> other, int depth) {
    if (id != other.id) return false;
    if (!shallowEquals(other)) return false;
    if (_isCollapsed != other._isCollapsed) return false;
    if (childCount != other.childCount) return false;

    // Switch to iterative if we're too deep (prevents stack overflow)
    if (depth > _recursionThreshold) {
      return _deepEqualsIterative(other);
    }

    for (final child in _children.values) {
      final otherChild = other._children[child.id];
      if (otherChild == null) return false;
      if (!child._deepEquals(otherChild, depth + 1)) return false;
    }
    return true;
  }

  bool _deepEqualsIterative(Node<T> other) {
    // Stack of (thisNode, otherNode) pairs to compare
    final stack = <(Node<T>, Node<T>)>[(this, other)];

    while (stack.isNotEmpty) {
      final (a, b) = stack.removeLast();

      if (a.id != b.id) return false;
      if (!a.shallowEquals(b)) return false;
      if (a._isCollapsed != b._isCollapsed) return false;
      if (a.childCount != b.childCount) return false;

      for (final child in a._children.values) {
        final otherChild = b._children[child.id];
        if (otherChild == null) return false;
        stack.add((child, otherChild));
      }
    }
    return true;
  }

  // ===========================================================================
  // State Serialization
  // ===========================================================================

  /// Returns a [CollapseSnapshot] containing the IDs of all collapsed nodes
  /// in the subtree rooted at this node.
  ///
  /// Use this to persist expand/collapse state for tree views.
  ///
  /// {@tool snippet}
  /// Capturing and restoring collapse state:
  ///
  /// ```dart
  /// // Capture current collapse state
  /// final snapshot = root.captureCollapseState();
  ///
  /// // Serialize to JSON for storage
  /// final json = snapshot.toJson();
  /// localStorage.setItem('collapse', jsonEncode(json));
  ///
  /// // Or convert to URL query string
  /// final url = '/tree?${snapshot.toQueryString()}';
  ///
  /// // Later, restore the state
  /// final savedJson = jsonDecode(localStorage.getItem('collapse'));
  /// final restored = CollapseSnapshot.fromJson(savedJson);
  /// root.restoreCollapseState(restored);
  /// ```
  /// {@end-tool}
  CollapseSnapshot captureCollapseState() {
    final collapsedIds = <String>{};

    for (final node in descendants()) {
      if (node._isCollapsed) {
        collapsedIds.add(node.id);
      }
    }

    return CollapseSnapshot._(Set.unmodifiable(collapsedIds));
  }

  /// Restores collapse state from a [CollapseSnapshot].
  ///
  /// Nodes with IDs in the snapshot are collapsed; all others are expanded.
  /// Node IDs in the snapshot that don't exist in this tree are ignored.
  ///
  /// {@tool snippet}
  /// Restoring collapse state from a URL:
  ///
  /// ```dart
  /// // From URL query string
  /// final snapshot = CollapseSnapshot.fromQueryString(
  ///   Uri.parse(url).query,
  /// );
  /// root.restoreCollapseState(snapshot);
  ///
  /// // From stored JSON
  /// final snapshot = CollapseSnapshot.fromJson(savedJson);
  /// root.restoreCollapseState(snapshot);
  /// ```
  /// {@end-tool}
  void restoreCollapseState(CollapseSnapshot snapshot, {bool notify = true}) {
    final changed = <Node<T>>[];

    for (final node in descendants()) {
      final shouldCollapse = snapshot._collapsedIds.contains(node.id);
      if (node._isCollapsed != shouldCollapse) {
        node._isCollapsed = shouldCollapse;
        node._version++;
        changed.add(node);
      }
    }

    if (notify && changed.isNotEmpty) {
      for (final node in changed) {
        node.notifyChanged();
      }
    }
  }

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  @override
  void dispose() {
    // IMPORTANT: Use iterative (not recursive) disposal to avoid stack
    // overflow.
    // Deep trees (e.g., 10,000+ nodes in a linear chain) will overflow the call
    // stack with recursive dispose. See memory_benchmark.dart for test cases.
    final stack = <Node<T>>[this];

    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      node._items.clear();
      node._byKey.clear();

      // Add children to stack for processing
      node._children.values.forEach(stack.add);
      node._children.clear();
    }

    super.dispose();
  }

  @override
  String toString() => 'Node($id, items: $length, children: $childCount)';
}

// =============================================================================
// Collapse Snapshot (Serialization)
// =============================================================================

/// {@template mz_collection.collapse_snapshot}
/// A serializable snapshot of tree collapse/expand state.
///
/// Use this to persist the expand/collapse state of tree views, create
/// shareable URLs, or restore tree configurations.
///
/// ## JSON Serialization
///
/// {@tool snippet}
/// Serialize collapse state to JSON:
///
/// ```dart
/// final snapshot = root.captureCollapseState();
///
/// // To JSON
/// final json = snapshot.toJson();
/// // Result: {'collapsedIds': ['folder-1', 'folder-2']}
///
/// // From JSON
/// final restored = CollapseSnapshot.fromJson(json);
/// ```
/// {@end-tool}
///
/// ## URL Query String
///
/// {@tool snippet}
/// Serialize collapse state to URL query string:
///
/// ```dart
/// final snapshot = root.captureCollapseState();
///
/// // To query string
/// final query = snapshot.toQueryString();
/// // Result: 'collapsed=folder-1,folder-2'
///
/// // Build URL
/// final url = '/tree?$query';
///
/// // From query string
/// final restored = CollapseSnapshot.fromQueryString(query);
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [Node.captureCollapseState] - Creates a snapshot from current state.
/// * [Node.restoreCollapseState] - Restores state from a snapshot.
/// {@endtemplate}
@immutable
class CollapseSnapshot {
  const CollapseSnapshot._(this._collapsedIds);

  /// Creates an empty collapse snapshot (all nodes expanded).
  const CollapseSnapshot.empty() : _collapsedIds = const {};

  /// Creates a collapse snapshot from a set of collapsed node IDs.
  factory CollapseSnapshot.fromIds(Set<String> collapsedIds) {
    if (collapsedIds.isEmpty) return const CollapseSnapshot.empty();
    return CollapseSnapshot._(Set.unmodifiable(collapsedIds));
  }

  /// Creates a snapshot from a JSON map.
  ///
  /// The map should have a 'collapsedIds' field with a list of node IDs.
  factory CollapseSnapshot.fromJson(Map<String, dynamic> json) {
    final idsList = json['collapsedIds'] as List<dynamic>?;
    if (idsList == null || idsList.isEmpty) {
      return const CollapseSnapshot.empty();
    }
    final ids = idsList.whereType<String>().toSet();
    if (ids.isEmpty) return const CollapseSnapshot.empty();
    return CollapseSnapshot._(Set.unmodifiable(ids));
  }

  /// Creates a snapshot from a URL query string.
  ///
  /// Parses the `collapsed` parameter with comma-separated node IDs.
  factory CollapseSnapshot.fromQueryString(String queryString) {
    if (queryString.isEmpty) return const CollapseSnapshot.empty();

    final params = Uri.splitQueryString(queryString);
    final collapsedValue = params['collapsed'];
    if (collapsedValue == null || collapsedValue.isEmpty) {
      return const CollapseSnapshot.empty();
    }

    final ids = collapsedValue.split(',').map(Uri.decodeComponent).toSet();
    if (ids.isEmpty) return const CollapseSnapshot.empty();
    return CollapseSnapshot._(Set.unmodifiable(ids));
  }

  final Set<String> _collapsedIds;

  /// Returns all collapsed node IDs in this snapshot.
  Set<String> get collapsedIds => _collapsedIds;

  /// Whether this snapshot has any collapsed nodes.
  bool get isEmpty => _collapsedIds.isEmpty;

  /// Whether this snapshot has collapsed nodes.
  bool get isNotEmpty => _collapsedIds.isNotEmpty;

  /// The number of collapsed nodes in this snapshot.
  int get length => _collapsedIds.length;

  /// Whether a node is collapsed in this snapshot.
  bool isCollapsed(String nodeId) => _collapsedIds.contains(nodeId);

  /// Converts this snapshot to a JSON-serializable map.
  ///
  /// The resulting map can be encoded with `jsonEncode` and stored or
  /// transmitted.
  Map<String, dynamic> toJson() {
    return {
      'collapsedIds': _collapsedIds.toList(),
    };
  }

  /// Converts this snapshot to a URL query string.
  ///
  /// Format: `collapsed={id1},{id2},{id3}`
  ///
  /// IDs are URL-encoded. Empty snapshots produce an empty string.
  String toQueryString() {
    if (_collapsedIds.isEmpty) return '';

    final encodedIds = _collapsedIds.map(Uri.encodeComponent).join(',');
    return 'collapsed=$encodedIds';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CollapseSnapshot) return false;
    if (_collapsedIds.length != other._collapsedIds.length) return false;
    return _collapsedIds.containsAll(other._collapsedIds);
  }

  @override
  int get hashCode => Object.hashAll(_collapsedIds);

  @override
  String toString() => 'CollapseSnapshot($_collapsedIds)';
}
