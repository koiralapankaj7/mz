// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

/// {@template mz_collection.collection_controller_library}
/// A reactive controller that orchestrates data loading, filtering, sorting,
/// grouping, and state management.
///
/// ## Design Philosophy
///
/// [CollectionController] is a **coordination layer** that:
///
/// - **Owns data directly** - items stored in flat list with O(1) key lookup
/// - **Fetches via DataLoader** - optional function for external sources
/// - **Applies transformations** via managers (filter, sort, search, group)
/// - **Exposes structure** as [Node] tree for consumption
/// - **Manages reactivity** - responds to changes and notifies listeners
///
/// ## Architecture
///
/// ```text
/// +---------------------------------------------------------------------+
/// |                     CollectionController                             |
/// |  - Owns items directly (_items list + _itemIndex map)                 |
/// |  - Uses DataLoader to fetch from external sources                     |
/// |  - Builds Node<T> structure from items                                 |
/// |  - Applies local filter/sort via managers                             |
/// |  - Exposes root Node for consumption                                 |
/// +---------------------------------------------------------------------+
///                                |
///              +-----------------+-----------------+
///              v                 v                 v
///       DataLoader<T>       Managers          Node<T>
///       (fetch data)     (transformations)    (output)
/// ```
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Creating a controller with a dataLoader:
///
/// ```dart
/// final controller = CollectionController<Task>(
///   keyOf: (task) => task.id,
///   dataLoader: (request) async {
///     final response = await api.fetchTasks(
///       offset: request.token.offset,
///       limit: request.limit,
///       filters: request.filters,
///     );
///     return PageResponse(
///       items: response.tasks,
///       nextToken: PageToken.offset(response.nextOffset),
///     );
///   },
///   filter: myFilterManager,
///   sort: mySortManager,
/// );
///
/// // Load initial data
/// await controller.load();
///
/// // Change filter - automatically rebuilds
/// controller.filter?['status']?.add('active');
///
/// // Access structured data
/// for (final task in controller.root) {
///   print(task.title);
/// }
/// ```
/// {@end-tool}
///
/// ## With Grouping
///
/// {@tool snippet}
/// Using grouping to organize items hierarchically:
///
/// ```dart
/// final controller = CollectionController<Task>(
///   keyOf: (task) => task.id,
///   group: GroupManager(options: [
///     GroupOption(id: 'status', valueBuilder: (t) => t.status),
///   ]),
/// );
///
/// await controller.load();
///
/// // Root contains group nodes
/// for (final groupNode in controller.root.children) {
///   print('${groupNode.id}: ${groupNode.length} items');
/// }
/// ```
/// {@end-tool}
/// {@endtemplate}
library;

import 'dart:async';

import 'package:meta/meta.dart';

import 'filter_manager.dart';
import 'group_manager.dart';
import 'node.dart';
import 'pagination.dart';
import 'selection_manager.dart';
import 'sort_manager.dart';

// =============================================================================
// Data Loader
// =============================================================================

/// Function type for loading a page of data.
///
/// Use this with `CollectionController`'s `dataLoader` parameter to fetch
/// data from external sources (APIs, databases, etc.).
///
/// ## Example
///
/// ```dart
/// final controller = CollectionController<User>(
///   keyOf: (user) => user.id,
///   dataLoader: (request) async {
///     final response = await api.fetchUsers(
///       offset: request.token is OffsetToken
///           ? (request.token as OffsetToken).offset
///           : 0,
///       limit: request.limit,
///     );
///     return PageResponse(
///       items: response.users,
///       nextToken: response.hasMore
///           ? PageToken.offset(response.nextOffset)
///           : PageToken.end,
///     );
///   },
/// );
/// ```
typedef DataLoader<T> = Future<PageResponse<T>> Function(PageRequest request);

// =============================================================================
// CollectionController
// =============================================================================

/// {@template mz_collection.collection_controller}
/// A reactive controller that coordinates data, managers, and tree structure.
///
/// {@macro mz_collection.collection_controller_library}
/// {@endtemplate}
class CollectionController<T> with Listenable {
  /// Creates a collection controller.
  ///
  /// - [keyOf] - Function to extract unique key from item (required)
  /// - [dataLoader] - Optional function to fetch data from external source
  /// - [filter], [sort], [group], [selection] - Optional managers
  CollectionController({
    required this.keyOf,
    DataLoader<T>? dataLoader,
    FilterManager<T>? filter,
    SortManager<T>? sort,
    GroupManager<T>? group,
    SelectionManager? selection,
    int defaultPageSize = 20,
  })  : _dataLoader = dataLoader,
        _filter = filter,
        _sort = sort,
        _group = group,
        _selection = selection ?? SelectionManager(),
        _defaultPageSize = defaultPageSize,
        _ownsSelection = selection == null {
    _setupListeners();
    _initRoot();
  }

  /// Function to extract a unique string key from an item.
  final String Function(T item) keyOf;

  // ===========================================================================
  // Configuration
  // ===========================================================================

  final int _defaultPageSize;

  // ===========================================================================
  // Data Storage
  // ===========================================================================

  final DataLoader<T>? _dataLoader;
  final List<T> _items = [];
  final Map<String, T> _itemIndex = {};

  /// Optional function to load data from external source.
  DataLoader<T>? get dataLoader => _dataLoader;

  // ===========================================================================
  // Managers
  // ===========================================================================

  final FilterManager<T>? _filter;
  final SortManager<T>? _sort;
  final GroupManager<T>? _group;
  final SelectionManager _selection;
  final bool _ownsSelection;

  /// Filter manager for applying filters.
  FilterManager<T>? get filter => _filter;

  /// Sort manager for sorting items.
  SortManager<T>? get sort => _sort;

  /// Group manager for hierarchical grouping.
  GroupManager<T>? get group => _group;

  /// Selection manager for tracking selected items.
  SelectionManager get selection => _selection;

  // ===========================================================================
  // Pagination State
  // ===========================================================================

  final PaginationState _pagination = PaginationState();

  /// Pagination state for tracking loading status per edge.
  PaginationState get pagination => _pagination;

  // ===========================================================================
  // Tree Building State
  // ===========================================================================

  late Node<T> _root;
  List<T>? _cachedFilteredItems;
  int _rebuildVersion = 0;

  /// The root node containing all data.
  Node<T> get root => _root;

  // ===========================================================================
  // Public API - Root Node (Output)
  // ===========================================================================

  /// Convenience getter for flat iteration over root items.
  Iterable<T> get items =>
      _group != null && _group.isNotEmpty ? _root.flattenedItems : _root;

  /// Total number of items (after filtering).
  int get length => _group != null && _group.isNotEmpty
      ? _root.flattenedLength
      : _root.length;

  /// Whether the collection is empty (after filtering).
  bool get isEmpty => length == 0;

  /// Whether the collection has items (after filtering).
  bool get isNotEmpty => length > 0;

  /// Gets an item by key.
  T? operator [](String key) => _itemIndex[key];

  /// Whether an item with the given key exists.
  bool containsKey(String key) => _itemIndex.containsKey(key);

  /// Default page size for pagination.
  int get defaultPageSize => _defaultPageSize;

  // ===========================================================================
  // Initialization
  // ===========================================================================

  void _initRoot() {
    _root = Node<T>(id: 'root', keyOf: keyOf);
    _rebuildRoot();
  }

  void _setupListeners() {
    _filter?.addChangeListener(_onQueryChanged);
    _sort?.addChangeListener(_onSortChanged);
    _group?.addChangeListener(_onGroupChanged);
    _selection.addChangeListener(notifyChanged);
    _pagination.addChangeListener(notifyChanged);
  }

  // ===========================================================================
  // Change Handlers
  // ===========================================================================

  void _onDataChanged() {
    _invalidateFilteredCache();
    _rebuildRoot();
    notifyChanged();
  }

  void _onQueryChanged() {
    _invalidateFilteredCache();
    _rebuildRoot();
    notifyChanged();

    if (_filter?.remoteFilters.isNotEmpty ?? false) {
      unawaited(refresh());
    }
  }

  void _onSortChanged() {
    if (_sort?.remoteSorts.isNotEmpty ?? false) {
      unawaited(refresh());
      return;
    }
    unawaited(_rebuildRootAsync());
  }

  void _onGroupChanged() {
    _rebuildRoot();
    notifyChanged();
  }

  // ===========================================================================
  // Public API - CRUD Operations
  // ===========================================================================

  /// Adds an item to the collection.
  bool add(T item) {
    final key = keyOf(item);
    if (_itemIndex.containsKey(key)) return false;

    _items.add(item);
    _itemIndex[key] = item;
    _onDataChanged();
    return true;
  }

  /// Adds multiple items to the collection.
  int addAll(Iterable<T> items) {
    var count = 0;
    for (final item in items) {
      final key = keyOf(item);
      if (!_itemIndex.containsKey(key)) {
        _items.add(item);
        _itemIndex[key] = item;
        count++;
      }
    }
    if (count > 0) _onDataChanged();
    return count;
  }

  /// Removes an item by key.
  T? remove(String key) {
    final item = _itemIndex.remove(key);
    if (item == null) return null;

    _items.remove(item);
    _onDataChanged();
    return item;
  }

  /// Updates an item in the collection.
  void update(String key, T Function(T item) updater) {
    final oldItem = _itemIndex[key];
    if (oldItem == null) return;

    final newItem = updater(oldItem);
    final index = _items.indexOf(oldItem);
    if (index >= 0) {
      _items[index] = newItem;
      _itemIndex[key] = newItem;
      _onDataChanged();
    }
  }

  /// Clears all items from the collection.
  void clear() {
    if (_items.isEmpty) return;

    _items.clear();
    _itemIndex.clear();
    _pagination.resetAll();
    _onDataChanged();
  }

  /// Adds or updates an item in the collection.
  ///
  /// If an item with the same key exists, it is replaced. Otherwise, the item
  /// is added to the collection.
  ///
  /// Returns `true` if the item was added (new), `false` if updated (replaced).
  bool upsert(T item) {
    final key = keyOf(item);
    final isNew = !_itemIndex.containsKey(key);

    if (isNew) {
      _items.add(item);
    } else {
      final oldItem = _itemIndex[key];
      if (oldItem != null) {
        final index = _items.indexOf(oldItem);
        if (index >= 0) _items[index] = item;
      }
    }

    _itemIndex[key] = item;
    _onDataChanged();
    return isNew;
  }

  /// Adds or updates multiple items in the collection.
  ///
  /// For each item, if an item with the same key exists, it is replaced.
  /// Otherwise, the item is added.
  ///
  /// Returns the count of newly added items (not updates).
  int upsertAll(Iterable<T> items) {
    var addedCount = 0;

    for (final item in items) {
      final key = keyOf(item);
      final isNew = !_itemIndex.containsKey(key);

      if (isNew) {
        _items.add(item);
        addedCount++;
      } else {
        final oldItem = _itemIndex[key];
        if (oldItem != null) {
          final index = _items.indexOf(oldItem);
          if (index >= 0) _items[index] = item;
        }
      }

      _itemIndex[key] = item;
    }

    if (addedCount > 0 || items.isNotEmpty) _onDataChanged();
    return addedCount;
  }

  /// Removes multiple items by their keys.
  ///
  /// Returns the list of removed items.
  List<T> removeAll(Iterable<String> keys) {
    final removed = <T>[];

    for (final key in keys) {
      final item = _itemIndex.remove(key);
      if (item != null) {
        _items.remove(item);
        removed.add(item);
      }
    }

    if (removed.isNotEmpty) _onDataChanged();
    return removed;
  }

  /// Removes all items matching the predicate.
  ///
  /// Returns the count of removed items.
  int removeWhere(bool Function(T item) test) {
    final toRemove = <T>[];

    for (final item in _items) {
      if (test(item)) toRemove.add(item);
    }

    for (final item in toRemove) {
      final key = keyOf(item);
      _itemIndex.remove(key);
      _items.remove(item);
    }

    if (toRemove.isNotEmpty) _onDataChanged();
    return toRemove.length;
  }

  /// Gets multiple items by their keys.
  ///
  /// Returns a list of items that exist for the given keys.
  /// Items that don't exist are omitted from the result.
  List<T> getAll(Iterable<String> keys) {
    final result = <T>[];
    for (final key in keys) {
      final item = _itemIndex[key];
      if (item != null) result.add(item);
    }
    return result;
  }

  // ===========================================================================
  // Public API - Data Loading
  // ===========================================================================

  /// Loads data from the data loader.
  ///
  /// Automatically determines whether this is an initial load or a "load more":
  /// - **Initial load**: Clears existing items and fetches from the beginning
  /// - **Load more**: Appends to existing items using the current
  ///   pagination token
  ///
  /// Does nothing if:
  /// - No data loader is configured
  /// - Already loading
  /// - No more data available (pagination exhausted)
  ///
  /// {@tool snippet}
  /// Basic usage:
  ///
  /// ```dart
  /// // First call - initial load
  /// await controller.load();
  ///
  /// // Subsequent calls - loads more
  /// await controller.load();
  /// await controller.load();
  ///
  /// // Force fresh reload
  /// await controller.refresh();
  /// ```
  /// {@end-tool}
  Future<void> load({PaginationEdge edge = PaginationEdge.trailing}) async {
    final loader = _dataLoader;
    if (loader == null) return;

    final edgeState = _pagination.getState(edge.id);
    final isInitialLoad = edgeState == null;

    // For subsequent loads, check if we can load more
    if (!isInitialLoad) {
      if (!_pagination.canLoad(edge.id)) return;
      if (!_pagination.startLoading(edge.id)) return;
    }

    try {
      if (isInitialLoad) {
        _items.clear();
        _itemIndex.clear();
      }

      final token = isInitialLoad ? PageToken.empty : edgeState.token;
      final request = _buildRequest(edge: edge, token: token);
      final response = await loader(request);

      _addItemsInternal(response.items);

      if (isInitialLoad && !_pagination.isRegistered(edge.id)) {
        _pagination.register(edge.id);
      }
      _pagination.complete(edge.id, nextToken: response.nextToken);
    } on Exception catch (e) {
      if (!isInitialLoad) {
        _pagination.fail(edge.id, e);
      }
      rethrow;
    }
  }

  /// Refreshes the collection by reloading from the beginning.
  ///
  /// Resets pagination state and performs a fresh initial load.
  Future<void> refresh({PaginationEdge edge = PaginationEdge.trailing}) async {
    _pagination.reset(edge.id);
    await load(edge: edge);
  }

  void _addItemsInternal(Iterable<T> items) {
    var added = false;
    for (final item in items) {
      final key = keyOf(item);
      if (!_itemIndex.containsKey(key)) {
        _items.add(item);
        _itemIndex[key] = item;
        added = true;
      }
    }
    if (added) {
      _invalidateFilteredCache();
      _rebuildRoot();
    }
  }

  // ===========================================================================
  // Public API - Lazy Loading Children
  // ===========================================================================

  /// Whether a node may have children that aren't loaded yet.
  bool mayHaveChildren(String nodeId) {
    final node = _root.findNode(nodeId);
    if (node == null) return false;

    if (node.children.isNotEmpty || node.isNotEmpty) return true;
    return _pagination.hasHint(nodeId);
  }

  /// Loads children for a specific node.
  ///
  /// Automatically handles both initial load and "load more":
  /// - **Initial load**: Fetches first page of children
  /// - **Load more**: Appends additional children using current token
  ///
  /// Does nothing if already loading or no more data available.
  Future<void> loadChildren(
    String nodeId, {
    PaginationEdge edge = PaginationEdge.trailing,
  }) async {
    if (_pagination.isLoading(nodeId)) return;
    if (!_pagination.canLoad(nodeId)) return;

    _pagination.startLoading(nodeId);
    notifyChanged();

    final loader = _dataLoader;
    if (loader == null) return;

    try {
      final request = _buildRequest(
        edge: edge,
        token: _pagination.getToken(nodeId),
      );

      final response = await loader(request);

      _addItemsInternal(response.items);

      final node = _root.findNode(nodeId);
      if (node != null) {
        if (request.token.isEmpty) {
          node.clearChildren(notify: false);
        }
        _addChildrenToNode(node, response.items);
      }

      if (response.childHints != null && response.childHints!.isNotEmpty) {
        _pagination.setHints(response.childHints!);
      }

      _pagination.complete(nodeId, nextToken: response.nextToken);
    } on Exception catch (e) {
      _pagination.fail(nodeId, e);
      rethrow;
    } finally {
      notifyChanged();
    }
  }

  /// Refreshes children for a node.
  Future<void> refreshChildren(
    String nodeId, {
    PaginationEdge edge = PaginationEdge.trailing,
  }) async {
    final node = _root.findNode(nodeId);
    if (node == null) return;

    node.clearChildren(notify: false);
    _pagination.reset(nodeId);
    await loadChildren(nodeId, edge: edge);
  }

  // ===========================================================================
  // Public API - State Serialization
  // ===========================================================================

  /// Returns a [CollectionSnapshot] containing all serializable state.
  CollectionSnapshot captureState() {
    return CollectionSnapshot(
      filter: _filter?.captureState(),
      sort: _sort?.captureState(),
      group: _group?.captureState(),
      selection: _selection.captureState(),
      collapse: _root.captureCollapseState(),
      pagination: _pagination.captureState(),
    );
  }

  /// Restores collection state from a [CollectionSnapshot].
  void restoreState(CollectionSnapshot snapshot) {
    if (snapshot.filter != null) {
      _filter?.restoreState(snapshot.filter!);
    }
    if (snapshot.sort != null) {
      _sort?.restoreState(snapshot.sort!);
    }
    if (snapshot.group != null) {
      _group?.restoreState(snapshot.group!);
    }
    if (snapshot.selection != null) {
      _selection.restoreState(snapshot.selection!);
    }
    if (snapshot.collapse != null) {
      _root.restoreCollapseState(snapshot.collapse!, notify: false);
    }
    if (snapshot.pagination != null) {
      _pagination.restoreState(snapshot.pagination!);
    }
    notifyChanged();
  }

  // ===========================================================================
  // Tree Building - Internal
  // ===========================================================================

  void _invalidateFilteredCache() {
    _cachedFilteredItems = null;
  }

  void _rebuildRoot() {
    if (_cachedFilteredItems != null) {
      _root = _buildNodeStructure(_cachedFilteredItems!);
      return;
    }

    final filteredItems = _applyLocalFilter(_items);
    final filteredList =
        filteredItems is List<T> ? filteredItems : filteredItems.toList();
    _cachedFilteredItems = filteredList;

    _root = _buildNodeStructure(filteredList);
  }

  Future<void> _rebuildRootAsync() async {
    final version = ++_rebuildVersion;
    notifyChanged();

    await Future<void>.delayed(Duration.zero);
    if (version != _rebuildVersion) return;

    final filtered = _applyLocalFilter(_items);

    await Future<void>.delayed(Duration.zero);
    if (version != _rebuildVersion) return;

    final filteredList = filtered.toList();
    _cachedFilteredItems = filteredList;

    _root = _buildNodeStructure(filteredList);

    notifyChanged();
  }

  Iterable<T> _applyLocalFilter(Iterable<T> items) {
    final filterMgr = _filter;
    if (filterMgr == null) return items;
    return filterMgr.filter(items);
  }

  Node<T> _buildNodeStructure(Iterable<T> items) {
    final groupMgr = _group;

    if (groupMgr == null || !groupMgr.isNotEmpty) {
      final itemList = items is List<T> ? items : items.toList();
      final sortedList = _sortItems(itemList);
      return Node<T>(id: 'root', keyOf: keyOf, items: sortedList);
    }

    return _buildGroupedNodes(items, groupMgr);
  }

  Node<T> _buildGroupedNodes(Iterable<T> items, GroupManager<T> groupMgr) {
    final root = Node<T>(id: 'root', keyOf: keyOf);

    final options = groupMgr.options.toList();
    if (options.isEmpty) {
      final itemList = items is List<T> ? items : items.toList();
      final sortedList = _sortItems(itemList);
      root.addAll(sortedList);
      return root;
    }

    _groupItemsRecursively(
      parentNode: root,
      items: items.toList(),
      options: options,
      optionIndex: 0,
    );

    return root;
  }

  void _groupItemsRecursively({
    required Node<T> parentNode,
    required List<T> items,
    required List<GroupOption<T, dynamic>> options,
    required int optionIndex,
  }) {
    if (optionIndex >= options.length) {
      final sortedItems = _sortItems(items);
      parentNode.addAll(sortedItems);
      return;
    }

    final option = options[optionIndex];
    final groups = <String, List<T>>{};
    final directItems = <T>[];

    if (option.isMultiValue) {
      for (final item in items) {
        final keys = option.groupKeysFor(item);
        if (keys.isEmpty) {
          directItems.add(item);
        } else {
          for (final key in keys) {
            (groups[key] ??= <T>[]).add(item);
          }
        }
      }
    } else {
      for (final item in items) {
        final key = option.groupKeyFor(item);
        if (key == null) {
          directItems.add(item);
        } else {
          (groups[key] ??= <T>[]).add(item);
        }
      }
    }

    if (directItems.isNotEmpty) {
      final sortedDirectItems = _sortItems(directItems);
      parentNode.addAll(sortedDirectItems);
    }

    final sortedGroupEntries = _sortGroups(groups, option);

    for (final entry in sortedGroupEntries) {
      final groupId = parentNode.id.isEmpty || parentNode.id == 'root'
          ? entry.key
          : '${parentNode.id}/${entry.key}';

      final groupNode = Node<T>(id: groupId, keyOf: keyOf, extra: option);

      _groupItemsRecursively(
        parentNode: groupNode,
        items: entry.value,
        options: options,
        optionIndex: optionIndex + 1,
      );

      parentNode.addChild(groupNode, notify: false);
    }
  }

  List<T> _sortItems(List<T> items) {
    final sortMgr = _sort;
    if (sortMgr == null) return items;
    return sortMgr.sort(items);
  }

  List<MapEntry<String, List<T>>> _sortGroups(
    Map<String, List<T>> groups,
    GroupOption<T, dynamic> option,
  ) {
    final entries = groups.entries.toList();
    final sortOption = option.sortOption;

    if (sortOption == null || entries.length <= 1) {
      return entries;
    }

    entries.sort((a, b) {
      final valueA =
          a.value.isNotEmpty ? option.valueBuilder(a.value.first) : null;
      final valueB =
          b.value.isNotEmpty ? option.valueBuilder(b.value.first) : null;
      return sortOption.compare(valueA, valueB);
    });

    return entries;
  }

  void _addChildrenToNode(Node<T> node, List<T> items) {
    final groupMgr = _group;

    if (groupMgr != null && groupMgr.isNotEmpty) {
      _groupItemsRecursively(
        parentNode: node,
        items: items,
        options: groupMgr.options.toList(),
        optionIndex: 0,
      );
    } else {
      final sortedItems = _sortItems(items);
      node.addAll(sortedItems, notify: false);
    }
  }

  // ===========================================================================
  // Request Building - Internal
  // ===========================================================================

  PageRequest _buildRequest({
    required PaginationEdge edge,
    required PageToken token,
  }) {
    String? searchTerm;
    final searchFilter =
        _filter?.filters.whereType<SearchFilter<T>>().firstOrNull;
    if (searchFilter != null && searchFilter.isNotEmpty) {
      searchTerm = searchFilter.query;
    }

    return PageRequest(
      edge: edge,
      token: token,
      limit: _defaultPageSize,
      search: searchTerm,
      filters: _filter?.filters
          .where((f) => f.isNotEmpty && f is! SearchFilter<T>)
          .map(
            (f) => FilterCriteria(id: f.id, values: f.values.cast<Object?>()),
          )
          .toList(),
      sort: _sort?.activeSorts
          .map((s) => SortCriteria(id: s.id, order: s.sortOrder))
          .toList(),
      group: _group?.options.firstOrNull != null
          ? GroupCriteria(id: _group!.options.first.id)
          : null,
    );
  }

  // ===========================================================================
  // Disposal
  // ===========================================================================

  @override
  void dispose() {
    _filter?.removeChangeListener(_onQueryChanged);
    _sort?.removeChangeListener(_onSortChanged);
    _group?.removeChangeListener(_onGroupChanged);
    _selection.removeChangeListener(notifyChanged);
    _pagination.removeChangeListener(notifyChanged);

    if (_ownsSelection) {
      _selection.dispose();
    }

    _pagination.dispose();
    _root.dispose();

    _items.clear();
    _itemIndex.clear();

    super.dispose();
  }
}

// =============================================================================
// Collection Snapshot (Serialization)
// =============================================================================

/// {@template mz_collection.collection_snapshot}
/// A combined snapshot of all collection state components.
///
/// Aggregates snapshots from:
/// - [FilterSnapshot] - Active filter values
/// - [SortSnapshot] - Active sort options and orders
/// - [GroupSnapshot] - Active grouping configuration
/// - [SelectionSnapshot] - Selected item keys
/// - [CollapseSnapshot] - Collapsed node IDs
/// - [PaginationSnapshot] - Current page/offset positions
///
/// Use this for complete state persistence or deep linking.
/// {@endtemplate}
@immutable
class CollectionSnapshot {
  /// Creates a collection snapshot with the given components.
  const CollectionSnapshot({
    this.filter,
    this.sort,
    this.group,
    this.selection,
    this.collapse,
    this.pagination,
  });

  /// Creates an empty collection snapshot.
  const CollectionSnapshot.empty()
      : filter = null,
        sort = null,
        group = null,
        selection = null,
        collapse = null,
        pagination = null;

  /// Creates a snapshot from a JSON map.
  factory CollectionSnapshot.fromJson(Map<String, dynamic> json) {
    return CollectionSnapshot(
      filter: json['filter'] != null
          ? FilterSnapshot.fromJson(json['filter'] as Map<String, dynamic>)
          : null,
      sort: json['sort'] != null
          ? SortSnapshot.fromJson(json['sort'] as Map<String, dynamic>)
          : null,
      group: json['group'] != null
          ? GroupSnapshot.fromJson(json['group'] as Map<String, dynamic>)
          : null,
      selection: json['selection'] != null
          ? SelectionSnapshot.fromJson(
              json['selection'] as Map<String, dynamic>,
            )
          : null,
      collapse: json['collapse'] != null
          ? CollapseSnapshot.fromJson(json['collapse'] as Map<String, dynamic>)
          : null,
      pagination: json['pagination'] != null
          ? PaginationSnapshot.fromJson(
              json['pagination'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Creates a snapshot from a URL query string.
  factory CollectionSnapshot.fromQueryString(String queryString) {
    if (queryString.isEmpty) return const CollectionSnapshot.empty();

    return CollectionSnapshot(
      filter: FilterSnapshot.fromQueryString(queryString),
      sort: SortSnapshot.fromQueryString(queryString),
      group: GroupSnapshot.fromQueryString(queryString),
      selection: SelectionSnapshot.fromQueryString(queryString),
      collapse: CollapseSnapshot.fromQueryString(queryString),
      pagination: PaginationSnapshot.fromQueryString(queryString),
    );
  }

  /// Filter state snapshot.
  final FilterSnapshot? filter;

  /// Sort state snapshot.
  final SortSnapshot? sort;

  /// Group state snapshot.
  final GroupSnapshot? group;

  /// Selection state snapshot.
  final SelectionSnapshot? selection;

  /// Collapse state snapshot.
  final CollapseSnapshot? collapse;

  /// Pagination state snapshot.
  final PaginationSnapshot? pagination;

  /// Whether all components are empty/null.
  bool get isEmpty =>
      (filter?.isEmpty ?? true) &&
      (sort?.isEmpty ?? true) &&
      (group?.isEmpty ?? true) &&
      (selection?.isEmpty ?? true) &&
      (collapse?.isEmpty ?? true) &&
      (pagination?.isEmpty ?? true);

  /// Whether any component has state.
  bool get isNotEmpty => !isEmpty;

  /// Converts this snapshot to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    final filterJson = filter?.toJson();
    if (filterJson != null && filterJson.isNotEmpty) {
      json['filter'] = filterJson;
    }

    final sortJson = sort?.toJson();
    if (sortJson != null) {
      json['sort'] = sortJson;
    }

    final groupJson = group?.toJson();
    if (groupJson != null) {
      json['group'] = groupJson;
    }

    final selectionJson = selection?.toJson();
    if (selectionJson != null) {
      json['selection'] = selectionJson;
    }

    final collapseJson = collapse?.toJson();
    if (collapseJson != null) {
      json['collapse'] = collapseJson;
    }

    final paginationJson = pagination?.toJson();
    if (paginationJson != null) {
      json['pagination'] = paginationJson;
    }

    return json;
  }

  /// Converts this snapshot to a URL query string.
  String toQueryString() {
    final parts = <String>[];

    final filterQuery = filter?.toQueryString();
    if (filterQuery != null && filterQuery.isNotEmpty) {
      parts.add(filterQuery);
    }

    final sortQuery = sort?.toQueryString();
    if (sortQuery != null && sortQuery.isNotEmpty) {
      parts.add(sortQuery);
    }

    final groupQuery = group?.toQueryString();
    if (groupQuery != null && groupQuery.isNotEmpty) {
      parts.add(groupQuery);
    }

    final selectionQuery = selection?.toQueryString();
    if (selectionQuery != null && selectionQuery.isNotEmpty) {
      parts.add(selectionQuery);
    }

    final collapseQuery = collapse?.toQueryString();
    if (collapseQuery != null && collapseQuery.isNotEmpty) {
      parts.add(collapseQuery);
    }

    final paginationQuery = pagination?.toQueryString();
    if (paginationQuery != null && paginationQuery.isNotEmpty) {
      parts.add(paginationQuery);
    }

    return parts.join('&');
  }

  /// Creates a copy with modified components.
  CollectionSnapshot copyWith({
    FilterSnapshot? filter,
    SortSnapshot? sort,
    GroupSnapshot? group,
    SelectionSnapshot? selection,
    CollapseSnapshot? collapse,
    PaginationSnapshot? pagination,
  }) {
    return CollectionSnapshot(
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      group: group ?? this.group,
      selection: selection ?? this.selection,
      collapse: collapse ?? this.collapse,
      pagination: pagination ?? this.pagination,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CollectionSnapshot) return false;
    return filter == other.filter &&
        sort == other.sort &&
        group == other.group &&
        selection == other.selection &&
        collapse == other.collapse &&
        pagination == other.pagination;
  }

  @override
  int get hashCode => Object.hash(
        filter,
        sort,
        group,
        selection,
        collapse,
        pagination,
      );

  @override
  String toString() {
    final parts = <String>[];
    if (filter?.isNotEmpty ?? false) parts.add('filter');
    if (sort?.isNotEmpty ?? false) parts.add('sort');
    if (group?.isNotEmpty ?? false) parts.add('group');
    if (selection?.isNotEmpty ?? false) parts.add('selection');
    if (collapse?.isNotEmpty ?? false) parts.add('collapse');
    if (pagination?.isNotEmpty ?? false) parts.add('pagination');
    return 'CollectionSnapshot(${parts.join(', ')})';
  }
}

// =============================================================================
// Page Request
// =============================================================================

/// {@template mz_collection.page_request}
/// Request for fetching a page of data.
///
/// Contains all context needed for the fetch: edge, token, limit, and
/// optional filter/sort/group criteria.
/// {@endtemplate}
@immutable
class PageRequest {
  /// Creates a page request.
  const PageRequest({
    this.edge = PaginationEdge.trailing,
    this.token = PageToken.empty,
    this.limit = 20,
    this.search,
    this.filters,
    this.sort,
    this.group,
  });

  /// Creates a page request from query parameters.
  factory PageRequest.fromQueryParams(
    Map<String, String> params, {
    PaginationEdge edge = PaginationEdge.trailing,
  }) {
    final PageToken token;
    if (int.tryParse(params['offset'] ?? '') case final int offset) {
      token = PageToken.offset(offset);
    } else if (params['cursor'] case final String cursor
        when cursor.isNotEmpty) {
      token = PageToken.cursor(cursor);
    } else {
      token = PageToken.empty;
    }

    return PageRequest(
      edge: edge,
      token: token,
      limit: int.tryParse(params['limit'] ?? '') ?? 20,
      search: params['search'],
      filters: FilterCriteria.fromQueryParams(params),
      sort: SortCriteria.fromQueryParams(params),
      group: GroupCriteria.fromQueryParams(params),
    );
  }

  /// The edge being paginated.
  final PaginationEdge edge;

  /// Current pagination token.
  final PageToken token;

  /// Maximum number of items to fetch.
  final int limit;

  /// Active search term.
  final String? search;

  /// Active filter criteria.
  final List<FilterCriteria>? filters;

  /// Active sort criteria.
  final List<SortCriteria>? sort;

  /// Active grouping criterion.
  final GroupCriteria? group;

  /// Whether this is an initial load (empty token).
  bool get isInitialLoad => token.isEmpty;

  /// Whether there are any active filters.
  bool get hasFilters => filters != null && filters!.isNotEmpty;

  /// Whether there is any active sorting.
  bool get hasSort => sort != null && sort!.any((s) => s.isActive);

  /// Whether there is active grouping.
  bool get hasGroup => group != null;

  /// Whether there is an active search.
  bool get hasSearch => search != null && search!.isNotEmpty;

  /// Converts this request to query parameters.
  Map<String, String> toQueryParams() {
    final params = <String, String>{};

    params['limit'] = limit.toString();
    if (token is OffsetToken) {
      params['offset'] = (token as OffsetToken).offset.toString();
    } else if (token is CursorToken) {
      params['cursor'] = (token as CursorToken).cursor;
    }

    if (search != null && search!.isNotEmpty) {
      params['search'] = search!;
    }

    if (filters != null) {
      for (final filter in filters!) {
        params.addAll(filter.toQueryParams());
      }
    }

    if (sort != null) {
      params.addAll(SortCriteria.listToQueryParams(sort!));
    }

    if (group != null) {
      params.addAll(group!.toQueryParams());
    }

    return params;
  }

  /// Creates a copy with modified values.
  PageRequest copyWith({
    PaginationEdge? edge,
    PageToken? token,
    int? limit,
    String? search,
    List<FilterCriteria>? filters,
    List<SortCriteria>? sort,
    GroupCriteria? group,
    bool clearSearch = false,
    bool clearFilters = false,
    bool clearSort = false,
    bool clearGroup = false,
  }) {
    return PageRequest(
      edge: edge ?? this.edge,
      token: token ?? this.token,
      limit: limit ?? this.limit,
      search: clearSearch ? null : (search ?? this.search),
      filters: clearFilters ? null : (filters ?? this.filters),
      sort: clearSort ? null : (sort ?? this.sort),
      group: clearGroup ? null : (group ?? this.group),
    );
  }

  @override
  String toString() {
    final parts = <String>[
      'edge: ${edge.id}',
      'token: $token',
      'limit: $limit',
    ];
    if (hasSearch) parts.add('search: $search');
    if (hasFilters) parts.add('filters: ${filters!.length}');
    if (hasSort) parts.add('sort: ${sort!.length}');
    if (hasGroup) parts.add('group: ${group!.id}');
    return 'PageRequest(${parts.join(', ')})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageRequest &&
          edge == other.edge &&
          token == other.token &&
          limit == other.limit &&
          search == other.search &&
          group == other.group &&
          _listEquals(filters, other.filters) &&
          _listEquals(sort, other.sort);

  @override
  int get hashCode => Object.hash(
        edge,
        token,
        limit,
        search,
        group,
        filters != null ? Object.hashAll(filters!) : null,
        sort != null ? Object.hashAll(sort!) : null,
      );

  static bool _listEquals<E>(List<E>? a, List<E>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// =============================================================================
// Page Response
// =============================================================================

/// {@template mz_collection.page_response}
/// Response from fetching a page of data.
///
/// Contains the items and the next token for continued pagination.
/// {@endtemplate}
class PageResponse<T> {
  /// Creates a page response.
  const PageResponse({
    required this.items,
    this.nextToken,
    this.totalCount,
    this.childHints,
  });

  /// Creates an empty response (end of data).
  const PageResponse.empty()
      : items = const [],
        nextToken = const EndToken(),
        totalCount = null,
        childHints = null;

  /// The fetched items.
  final List<T> items;

  /// Token for fetching the next page, or null/EndToken if done.
  final PageToken? nextToken;

  /// Total count of items (if known by the server).
  final int? totalCount;

  /// Hints indicating which items have unloaded children.
  final Map<String, bool>? childHints;

  /// Whether there are more pages.
  bool get hasMore => nextToken != null && !nextToken!.isEnd;

  /// Whether this response is empty.
  bool get isEmpty => items.isEmpty;

  /// Whether this response includes child hints.
  bool get hasChildHints => childHints != null && childHints!.isNotEmpty;

  @override
  String toString() {
    final hints = hasChildHints ? ', hints: ${childHints!.length}' : '';
    return 'PageResponse(items: ${items.length}, '
        'nextToken: $nextToken, hasMore: $hasMore$hints)';
  }
}
