// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

/// {@template mz_collection.pagination_library}
/// A flexible, composable pagination system for any direction.
///
/// ## Design Philosophy
///
/// This pagination system is designed to be:
///
/// - **Direction-agnostic**: Not limited to up/down - supports any edge
/// - **Token-flexible**: Offset, cursor, or custom token types
/// - **Composable**: Use only what you need
/// - **Pure Dart**: No Flutter dependency
///
/// ## Key Concepts
///
/// - **PageToken**: Identifies where to fetch next (offset, cursor, or custom)
/// - **PaginationEdge**: A direction/edge where pagination can occur
/// - **EdgeState**: Loading state for a single edge
/// - **PaginationState**: Manages state across all edges
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Setting up pagination edges:
///
/// ```dart
/// // Simple vertical list
/// final state = PaginationState();
/// state.addEdge(PaginationEdge.trailing);
///
/// // Family tree (all directions)
/// final treeState = PaginationState();
/// treeState.addEdge(PaginationEdge.top);
/// treeState.addEdge(PaginationEdge.bottom);
/// treeState.addEdge(PaginationEdge.left);
/// treeState.addEdge(PaginationEdge.right);
/// ```
/// {@end-tool}
/// {@endtemplate}
library;

import 'package:meta/meta.dart';

import 'core.dart';

// =============================================================================
// Page Tokens
// =============================================================================

/// {@template mz_collection.page_token}
/// Represents a position in paginated data.
///
/// Tokens are immutable identifiers that tell the data source where to
/// fetch the next page from.
///
/// ## Built-in Tokens
///
/// - [EmptyToken]: Initial state, no pagination yet
/// - [OffsetToken]: Offset-based pagination (offset + limit)
/// - [CursorToken]: Cursor-based pagination (opaque string)
/// - [EndToken]: No more data available
///
/// ## Custom Tokens
///
/// Extend [PageToken] for custom pagination schemes:
///
/// {@tool snippet}
/// Creating a custom grid-based token:
///
/// ```dart
/// class GridToken extends PageToken {
///   const GridToken(this.row, this.column);
///   final int row;
///   final int column;
/// }
/// ```
/// {@end-tool}
///
/// {@tool snippet}
/// Creating a node-aware token for hierarchical pagination:
///
/// ```dart
/// class NodeToken<K, T> extends PageToken {
///   const NodeToken({required this.node, this.offset = 0});
///   final Node<K, T> node;
///   final int offset;
/// }
/// ```
/// {@end-tool}
/// {@endtemplate}
abstract class PageToken {
  /// Creates a page token.
  const PageToken();

  /// Creates an offset-based token.
  const factory PageToken.offset(int offset, {int? total}) = OffsetToken;

  /// Creates a cursor-based token.
  const factory PageToken.cursor(String cursor) = CursorToken;

  /// Initial empty token.
  static const PageToken empty = EmptyToken();

  /// End of data token.
  static const PageToken end = EndToken();

  /// Whether this token represents the end of data.
  bool get isEnd => this is EndToken;

  /// Whether this token is empty (initial state).
  bool get isEmpty => this is EmptyToken;

  /// Whether this token has more data to load.
  bool get hasMore => !isEnd && !isEmpty;
}

/// Initial empty token - no pagination has occurred yet.
@immutable
class EmptyToken extends PageToken {
  /// Creates an empty token.
  const EmptyToken();

  @override
  String toString() => 'EmptyToken';
}

/// End of data - no more pages available.
@immutable
class EndToken extends PageToken {
  /// Creates an end token.
  const EndToken();

  @override
  String toString() => 'EndToken';
}

/// Offset-based pagination token.
///
/// Used when the API supports offset/limit style pagination.
///
/// {@tool snippet}
/// Creating offset tokens:
///
/// ```dart
/// final token = OffsetToken(0); // Start
/// final next = OffsetToken(20, total: 100); // Page 2, 100 total items
/// ```
/// {@end-tool}
@immutable
class OffsetToken extends PageToken {
  /// Creates an offset token.
  const OffsetToken(this.offset, {this.total});

  /// The current offset position.
  final int offset;

  /// Total count of items (if known).
  final int? total;

  /// Whether there are more items based on total count.
  ///
  /// Returns `true` if total is unknown.
  bool hasMoreItems(int currentCount) {
    final t = total;
    if (t == null) return true;
    return offset + currentCount < t;
  }

  @override
  bool operator ==(Object other) =>
      other is OffsetToken && other.offset == offset && other.total == total;

  @override
  int get hashCode => Object.hash(offset, total);

  @override
  String toString() =>
      'OffsetToken($offset${total != null ? ', total: $total' : ''})';
}

/// Cursor-based pagination token.
///
/// Used when the API returns opaque cursors for pagination.
///
/// {@tool snippet}
/// Creating a cursor token:
///
/// ```dart
/// final token = CursorToken('eyJpZCI6MTIzfQ==');
/// ```
/// {@end-tool}
@immutable
class CursorToken extends PageToken {
  /// Creates a cursor token.
  const CursorToken(this.cursor);

  /// The opaque cursor string.
  final String cursor;

  @override
  bool operator ==(Object other) =>
      other is CursorToken && other.cursor == cursor;

  @override
  int get hashCode => cursor.hashCode;

  @override
  String toString() => 'CursorToken($cursor)';
}

// =============================================================================
// Pagination Edge
// =============================================================================

/// {@template mz_collection.pagination_edge}
/// Represents a direction/edge where pagination can occur.
///
/// ## Built-in Edges
///
/// For vertical lists:
/// - [PaginationEdge.leading] / [PaginationEdge.top]: Load older/previous items
/// - [PaginationEdge.trailing] / [PaginationEdge.bottom]: Load newer/next items
///
/// For horizontal lists:
/// - [PaginationEdge.left]: Load items to the left
/// - [PaginationEdge.right]: Load items to the right
///
/// ## Custom Edges
///
/// For complex layouts (family trees, graphs):
///
/// {@tool snippet}
/// Creating custom pagination edges:
///
/// ```dart
/// const ancestorsEdge = PaginationEdge('ancestors');
/// const descendantsEdge = PaginationEdge('descendants');
/// const siblingsEdge = PaginationEdge('siblings');
/// ```
/// {@end-tool}
/// {@endtemplate}
@immutable
class PaginationEdge {
  /// Creates a custom pagination edge.
  const PaginationEdge(this.id);

  /// Unique identifier for this edge.
  final String id;

  // ---------------------------------------------------------------------------
  // Common edges
  // ---------------------------------------------------------------------------

  /// Leading edge (top in vertical, left in horizontal LTR).
  static const leading = PaginationEdge('leading');

  /// Trailing edge (bottom in vertical, right in horizontal LTR).
  static const trailing = PaginationEdge('trailing');

  /// Top edge (alias for leading in vertical layouts).
  static const top = PaginationEdge('top');

  /// Bottom edge (alias for trailing in vertical layouts).
  static const bottom = PaginationEdge('bottom');

  /// Left edge (for horizontal or grid layouts).
  static const left = PaginationEdge('left');

  /// Right edge (for horizontal or grid layouts).
  static const right = PaginationEdge('right');

  @override
  bool operator ==(Object other) => other is PaginationEdge && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PaginationEdge($id)';
}

// =============================================================================
// Edge State
// =============================================================================

/// Loading status for a pagination edge.
enum LoadingStatus {
  /// Ready to load, not currently loading.
  idle,

  /// Currently loading data.
  loading,

  /// Last load resulted in an error.
  error,

  /// No more data available at this edge.
  exhausted,
}

/// {@template mz_collection.edge_state}
/// State of pagination for a single edge.
///
/// Tracks the next token, loading status, and any errors.
/// {@endtemplate}
class EdgeState {
  /// Creates an edge state.
  const EdgeState({
    this.token = const EmptyToken(),
    this.status = LoadingStatus.idle,
    this.error,
    this.retryCount = 0,
  });

  /// The next token to use for fetching.
  final PageToken token;

  /// Current loading status.
  final LoadingStatus status;

  /// Error from last failed load attempt.
  final Object? error;

  /// Number of retry attempts after errors.
  final int retryCount;

  /// Whether this edge can load more data.
  bool get canLoad =>
      status != LoadingStatus.loading &&
      status != LoadingStatus.exhausted &&
      !token.isEnd;

  /// Whether this edge is currently loading.
  bool get isLoading => status == LoadingStatus.loading;

  /// Whether this edge has an error.
  bool get hasError => status == LoadingStatus.error;

  /// Whether this edge has no more data.
  bool get isExhausted => status == LoadingStatus.exhausted || token.isEnd;

  /// Creates a copy with modified values.
  EdgeState copyWith({
    PageToken? token,
    LoadingStatus? status,
    Object? error,
    int? retryCount,
    bool clearError = false,
  }) {
    return EdgeState(
      token: token ?? this.token,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      retryCount: retryCount ?? this.retryCount,
    );
  }

  @override
  String toString() {
    final errorPart = error != null ? ', error: $error' : '';
    return 'EdgeState(token: $token, status: $status$errorPart)';
  }
}

// =============================================================================
// Pagination State
// =============================================================================

/// {@template mz_collection.pagination_state}
/// Manages pagination state using a unified ID-based approach.
///
/// Each pagination context is identified by a string ID. This supports:
/// - Simple lists: `'trailing'`, `'leading'`
/// - Tree nodes: `'folder_1'`, `'folder_1/subfolder'`
/// - Grids: `'row_5'`, `'column_3'`
/// - Any custom scheme you need
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Simple infinite scroll:
///
/// ```dart
/// final state = PaginationState();
///
/// // Register and start loading
/// state.register('trailing');
/// state.startLoading('trailing');
///
/// // Complete with next token
/// state.complete('trailing', nextToken: PageToken.offset(20));
///
/// // Check state
/// if (state.canLoad('trailing')) {
///   // Can load more
/// }
/// ```
/// {@end-tool}
///
/// ## Tree/Hierarchical Data
///
/// {@tool snippet}
/// Lazy loading children for tree nodes:
///
/// ```dart
/// // Set hint that node has children (for expand arrow)
/// state.setHint('folder_1', hasMore: true);
///
/// // User expands folder - start loading
/// state.register('folder_1');
/// state.startLoading('folder_1');
///
/// // Complete loading
/// state.complete('folder_1', nextToken: cursor);
///
/// // Check state for UI
/// if (state.canLoad('folder_1')) {
///   // Show "Load more" button
/// }
/// ```
/// {@end-tool}
///
/// ## Bidirectional Pagination
///
/// {@tool snippet}
/// Chat-style bidirectional loading:
///
/// ```dart
/// state.register('leading');   // Load older messages
/// state.register('trailing');  // Load newer messages
///
/// // Load in either direction
/// state.startLoading('leading');
/// ```
/// {@end-tool}
/// {@endtemplate}
class PaginationState with Listenable {
  /// Creates a pagination state with optional initial IDs.
  PaginationState({Iterable<String>? ids}) {
    if (ids != null) {
      ids.forEach(register);
    }
  }

  // ---------------------------------------------------------------------------
  // State Storage
  // ---------------------------------------------------------------------------

  /// Unified state map: ID → EdgeState
  final Map<String, EdgeState> _states = {};

  /// Hints for IDs that may have more data (e.g., nodes with children).
  final Map<String, bool> _hints = {};

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Registers a pagination context.
  ///
  /// Call this before starting to load data for an ID.
  void register(String id, {PageToken? initialToken}) {
    _states[id] = EdgeState(token: initialToken ?? PageToken.empty);
    notifyChanged();
  }

  /// Registers multiple pagination contexts.
  void registerAll(Iterable<String> ids) {
    for (final id in ids) {
      _states[id] = const EdgeState();
    }
    notifyChanged();
  }

  /// Removes a pagination context.
  void unregister(String id) {
    final hadState = _states.remove(id) != null;
    final hadHint = _hints.remove(id) != null;
    if (hadState || hadHint) {
      notifyChanged();
    }
  }

  /// Whether an ID is registered.
  bool isRegistered(String id) => _states.containsKey(id);

  /// All registered IDs.
  Iterable<String> get ids => _states.keys;

  /// Number of registered IDs.
  int get count => _states.length;

  // ---------------------------------------------------------------------------
  // Loading Lifecycle
  // ---------------------------------------------------------------------------

  /// Marks an ID as loading.
  ///
  /// If the ID is not registered, it will be auto-registered.
  /// Returns `false` if already loading or exhausted.
  bool startLoading(String id) {
    var state = _states[id];

    // Auto-register if not exists
    if (state == null) {
      state = const EdgeState();
      _states[id] = state;
    }

    if (!state.canLoad) return false;

    _states[id] = state.copyWith(
      status: LoadingStatus.loading,
      clearError: true,
    );
    notifyChanged();
    return true;
  }

  /// Marks an ID as successfully loaded.
  ///
  /// If [nextToken] is null or [EndToken], the ID is marked exhausted.
  void complete(String id, {PageToken? nextToken}) {
    final state = _states[id];
    if (state == null) return;

    final isExhausted = nextToken == null || nextToken.isEnd;
    _states[id] = state.copyWith(
      token: nextToken ?? PageToken.end,
      status: isExhausted ? LoadingStatus.exhausted : LoadingStatus.idle,
      retryCount: 0,
      clearError: true,
    );

    // If exhausted, clear hint
    if (isExhausted) {
      _hints.remove(id);
    }

    notifyChanged();
  }

  /// Marks an ID as failed with an error.
  void fail(String id, Object error) {
    final state = _states[id];
    if (state == null) return;

    _states[id] = state.copyWith(
      status: LoadingStatus.error,
      error: error,
      retryCount: state.retryCount + 1,
    );
    notifyChanged();
  }

  /// Resets an ID to initial state.
  ///
  /// Keeps the hint if [keepHint] is true.
  void reset(String id, {PageToken? token, bool keepHint = true}) {
    if (!_states.containsKey(id)) return;

    _states[id] = EdgeState(token: token ?? PageToken.empty);
    if (!keepHint) {
      _hints.remove(id);
    }
    notifyChanged();
  }

  /// Resets all IDs to initial state.
  void resetAll({bool keepHints = false}) {
    for (final id in _states.keys) {
      _states[id] = const EdgeState();
    }
    if (!keepHints) {
      _hints.clear();
    }
    notifyChanged();
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Gets the state for an ID.
  EdgeState? getState(String id) => _states[id];

  /// Gets the token for an ID.
  PageToken getToken(String id) => _states[id]?.token ?? PageToken.empty;

  /// Whether an ID can load more data.
  ///
  /// Returns true if:
  /// - ID is registered and not loading/exhausted
  /// - OR ID has a hint (may have data to load)
  bool canLoad(String id) {
    final state = _states[id];
    if (state != null) return state.canLoad;
    // Not registered but has hint - can start loading
    return _hints[id] ?? false;
  }

  /// Whether an ID is loading.
  bool isLoading(String id) => _states[id]?.isLoading ?? false;

  /// Whether an ID has an error.
  bool hasError(String id) => _states[id]?.hasError ?? false;

  /// Whether an ID is exhausted (no more data).
  bool isExhausted(String id) => _states[id]?.isExhausted ?? false;

  /// Gets the error for an ID.
  Object? getError(String id) => _states[id]?.error;

  /// Whether any ID is currently loading.
  bool get isAnyLoading => _states.values.any((e) => e.isLoading);

  /// Whether all IDs are exhausted.
  bool get isAllExhausted =>
      _states.isNotEmpty && _states.values.every((e) => e.isExhausted);

  /// IDs that can load more data.
  Iterable<String> get loadableIds =>
      _states.entries.where((e) => e.value.canLoad).map((e) => e.key);

  // ---------------------------------------------------------------------------
  // Hints (for lazy loading, e.g., "has children")
  // ---------------------------------------------------------------------------

  /// Sets a hint for an ID.
  ///
  /// Use this to indicate that an ID may have data to load, even before
  /// registration. Common use case: marking tree nodes as having children.
  void setHint(String id, {required bool hasMore}) {
    if (_hints[id] != hasMore) {
      _hints[id] = hasMore;
      notifyChanged();
    }
  }

  /// Sets hints for multiple IDs.
  void setHints(Map<String, bool> hints) {
    var changed = false;
    for (final entry in hints.entries) {
      if (_hints[entry.key] != entry.value) {
        _hints[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) notifyChanged();
  }

  /// Gets the hint for an ID.
  ///
  /// Returns null if no hint is set.
  bool? getHint(String id) => _hints[id];

  /// Whether an ID has a "has more" hint.
  bool hasHint(String id) => _hints[id] ?? false;

  /// Clears the hint for an ID.
  void clearHint(String id) {
    if (_hints.remove(id) != null) {
      notifyChanged();
    }
  }

  /// All IDs with hints.
  Iterable<String> get hintedIds => _hints.keys;

  // ---------------------------------------------------------------------------
  // Convenience for PaginationEdge compatibility
  // ---------------------------------------------------------------------------

  /// Registers an edge (convenience for `register(edge.id)`).
  void addEdge(PaginationEdge edge, {PageToken? initialToken}) {
    register(edge.id, initialToken: initialToken);
  }

  /// Registers multiple edges.
  void addEdges(Iterable<PaginationEdge> edges) {
    registerAll(edges.map((e) => e.id));
  }

  /// Removes an edge (convenience for `unregister(edge.id)`).
  void removeEdge(PaginationEdge edge) => unregister(edge.id);

  /// Whether an edge is registered.
  bool hasEdge(PaginationEdge edge) => isRegistered(edge.id);

  // ---------------------------------------------------------------------------
  // toString
  // ---------------------------------------------------------------------------

  @override
  String toString() {
    final buffer = StringBuffer('PaginationState(');
    buffer.write(
      _states.entries.map((e) => '${e.key}: ${e.value.status.name}').join(', '),
    );
    if (_hints.isNotEmpty) {
      buffer.write(', hints: ${_hints.length}');
    }
    buffer.write(')');
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // State Serialization
  // ---------------------------------------------------------------------------

  /// Returns a [PaginationSnapshot] containing the current page/offset state.
  ///
  /// Note: Only offset-based tokens are serializable. Cursor-based tokens
  /// are typically session-specific and are not included.
  PaginationSnapshot captureState() {
    final offsets = <String, int>{};

    for (final entry in _states.entries) {
      final token = entry.value.token;
      if (token is OffsetToken) {
        offsets[entry.key] = token.offset;
      }
    }

    return PaginationSnapshot.fromOffsets(offsets);
  }

  /// Restores pagination state from a [PaginationSnapshot].
  ///
  /// Only restores offset-based pagination. IDs not present in the snapshot
  /// are reset to initial state. IDs in the snapshot that don't exist are
  /// auto-registered.
  void restoreState(PaginationSnapshot snapshot) {
    // Reset existing IDs not in snapshot
    for (final id in _states.keys) {
      if (!snapshot.offsets.containsKey(id)) {
        _states[id] = const EdgeState();
      }
    }

    // Restore/register IDs from snapshot
    for (final entry in snapshot.offsets.entries) {
      _states[entry.key] = EdgeState(token: OffsetToken(entry.value));
    }

    notifyChanged();
  }
}

// =============================================================================
// Pagination Snapshot (Serialization)
// =============================================================================

/// {@template mz_collection.pagination_snapshot}
/// A serializable snapshot of pagination state (offset-based only).
///
/// Use this to persist the current page/offset state for deep linking or
/// restoring scroll position.
///
/// Note: Only offset-based pagination is serializable. Cursor-based pagination
/// tokens are typically session-specific and are not included.
///
/// ## JSON Serialization
///
/// {@tool snippet}
/// Serialize pagination state to JSON:
///
/// ```dart
/// final snapshot = pagination.captureState();
///
/// // To JSON
/// final json = snapshot.toJson();
/// // Result: {'offsets': {'trailing': 40, 'leading': 0}}
///
/// // From JSON
/// final restored = PaginationSnapshot.fromJson(json);
/// ```
/// {@end-tool}
///
/// ## URL Query String
///
/// {@tool snippet}
/// Serialize pagination state to URL query string:
///
/// ```dart
/// final snapshot = pagination.captureState();
///
/// // To query string
/// final query = snapshot.toQueryString();
/// // Result: 'page.trailing=40&page.leading=0'
///
/// // Build URL
/// final url = '/items?$query';
///
/// // From query string
/// final restored = PaginationSnapshot.fromQueryString(query);
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [PaginationState.captureState] - Creates a snapshot from current state.
/// * [PaginationState.restoreState] - Restores state from a snapshot.
/// {@endtemplate}
@immutable
class PaginationSnapshot {
  const PaginationSnapshot._(this._offsets);

  /// Creates an empty pagination snapshot.
  const PaginationSnapshot.empty() : _offsets = const {};

  /// Creates a pagination snapshot from offset values per edge.
  factory PaginationSnapshot.fromOffsets(Map<String, int> offsets) {
    if (offsets.isEmpty) return const PaginationSnapshot.empty();
    return PaginationSnapshot._(Map.unmodifiable(offsets));
  }

  /// Creates a snapshot from a JSON map.
  ///
  /// The map should have an 'offsets' field with a map of edge IDs to offsets.
  factory PaginationSnapshot.fromJson(Map<String, dynamic> json) {
    final offsetsMap = json['offsets'] as Map<String, dynamic>?;
    if (offsetsMap == null || offsetsMap.isEmpty) {
      return const PaginationSnapshot.empty();
    }

    final offsets = <String, int>{};
    for (final entry in offsetsMap.entries) {
      if (entry.value is int) {
        offsets[entry.key] = entry.value as int;
      }
    }

    if (offsets.isEmpty) return const PaginationSnapshot.empty();
    return PaginationSnapshot._(Map.unmodifiable(offsets));
  }

  /// Creates a snapshot from a URL query string.
  ///
  /// Parses parameters with `page.` prefix.
  factory PaginationSnapshot.fromQueryString(String queryString) {
    if (queryString.isEmpty) return const PaginationSnapshot.empty();

    final offsets = <String, int>{};
    final params = Uri.splitQueryString(queryString);

    for (final entry in params.entries) {
      if (!entry.key.startsWith('page.')) continue;

      final edgeId = entry.key.substring(5); // Remove 'page.' prefix
      if (edgeId.isEmpty) continue;

      final offset = int.tryParse(entry.value);
      if (offset != null) {
        offsets[edgeId] = offset;
      }
    }

    if (offsets.isEmpty) return const PaginationSnapshot.empty();
    return PaginationSnapshot._(Map.unmodifiable(offsets));
  }

  final Map<String, int> _offsets;

  /// Returns the offset for a specific edge.
  int? operator [](String edgeId) => _offsets[edgeId];

  /// Returns all edge IDs that have offsets in this snapshot.
  Iterable<String> get edgeIds => _offsets.keys;

  /// Returns all offsets as a map.
  Map<String, int> get offsets => _offsets;

  /// Whether this snapshot has any pagination state.
  bool get isEmpty => _offsets.isEmpty;

  /// Whether this snapshot has pagination state.
  bool get isNotEmpty => _offsets.isNotEmpty;

  /// The number of edges with offset state in this snapshot.
  int get length => _offsets.length;

  /// Converts this snapshot to a JSON-serializable map.
  ///
  /// The resulting map can be encoded with `jsonEncode` and stored or
  /// transmitted.
  Map<String, dynamic> toJson() {
    return {
      'offsets': _offsets,
    };
  }

  /// Converts this snapshot to a URL query string.
  ///
  /// Format: `page.{edgeId}={offset}&page.{edgeId}={offset}`
  ///
  /// Values are URL-encoded. Empty snapshots produce an empty string.
  String toQueryString() {
    if (_offsets.isEmpty) return '';

    final parts = <String>[];
    for (final entry in _offsets.entries) {
      parts.add('page.${Uri.encodeComponent(entry.key)}=${entry.value}');
    }
    return parts.join('&');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PaginationSnapshot) return false;
    if (_offsets.length != other._offsets.length) return false;
    for (final key in _offsets.keys) {
      if (_offsets[key] != other._offsets[key]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        _offsets.entries.map((e) => Object.hash(e.key, e.value)),
      );

  @override
  String toString() => 'PaginationSnapshot($_offsets)';
}
