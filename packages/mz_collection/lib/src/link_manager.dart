// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

/// {@template mz_collection.link_manager_library}
/// Manages cross-cutting relationships between nodes for DAG support.
///
/// ## Why LinkManager?
///
/// While the `Node` class provides a tree hierarchy (single parent per node),
/// many real-world data structures require graph relationships:
///
/// - **Org charts**: Matrix reporting (employee reports to multiple managers)
/// - **Family trees**: Spouses, step-parents, blended families
/// - **File systems**: Shortcuts/symlinks (same file in multiple folders)
/// - **Social graphs**: Followers, friends, mentions
/// - **Knowledge bases**: Cross-references, related items
///
/// LinkManager provides these relationships **separately** from the tree,
/// keeping Node simple while enabling complex graph queries.
///
/// ## Architecture
///
/// ```text
/// ┌─────────────────────────────────────────────────────────────────┐
/// │                          Node Tree                              │
/// │                                                                 │
/// │                           Root                                  │
/// │                          /    \                                 │
/// │                      Alice    Bob                               │
/// │                      /           \                              │
/// │                  Charlie        Diana                           │
/// │                                                                 │
/// └─────────────────────────────────────────────────────────────────┘
///                              +
/// ┌─────────────────────────────────────────────────────────────────┐
/// │                        LinkManager                              │
/// │                                                                 │
/// │   Alice ──spouse──▶ Bob                                         │
/// │   Charlie ──mentor──▶ Diana                                     │
/// │   Diana ──reports_to──▶ Alice (dotted line)                     │
/// │                                                                 │
/// └─────────────────────────────────────────────────────────────────┘
///                              =
/// ┌─────────────────────────────────────────────────────────────────┐
/// │                    Full Graph Structure                         │
/// │                                                                 │
/// │  Tree hierarchy + cross-cutting relationships = DAG             │
/// │                                                                 │
/// └─────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Creating and querying links:
///
/// ```dart
/// final links = LinkManager();
///
/// // Add a bidirectional relationship (spouse)
/// links.add(NodeLink(
///   id: 'alice-bob-spouse',
///   sourceId: 'alice',
///   targetId: 'bob',
///   type: 'spouse',
///   direction: LinkDirection.bidirectional,
/// ));
///
/// // Query relationships
/// final spouses = links.getLinkedNodeIds('alice', type: 'spouse');
/// print(spouses); // ['bob']
///
/// // Check if linked
/// print(links.areLinked('alice', 'bob')); // true
/// ```
/// {@end-tool}
///
/// ## Link Types
///
/// Links are typed, enabling different relationship semantics:
///
/// {@tool snippet}
/// Using typed links for different relationships:
///
/// ```dart
/// // Family relationships
/// links.add(NodeLink(
///   id: '1', sourceId: 'child', targetId: 'parent1', type: 'parent'));
/// links.add(NodeLink(
///   id: '2', sourceId: 'child', targetId: 'parent2', type: 'parent'));
///
/// // Org relationships
/// links.add(NodeLink(
///   id: '3', sourceId: 'emp', targetId: 'mgr', type: 'reports_to'));
/// links.add(NodeLink(
///   id: '4', sourceId: 'emp', targetId: 'mentor', type: 'mentored_by'));
///
/// // Query by type
/// final parents = links.getLinkedNodeIds('child', type: 'parent');
/// final managers = links.getLinkedNodeIds('emp', type: 'reports_to');
/// ```
/// {@end-tool}
///
/// {@endtemplate}
library;

import 'package:meta/meta.dart';

import 'node.dart';

// =============================================================================
// Link Direction
// =============================================================================

/// Direction of a relationship link.
///
/// Determines how the relationship can be traversed:
///
/// - [outgoing]: Source → Target only
/// - [incoming]: Target → Source only (reversed)
/// - [bidirectional]: Both directions (e.g., spouse, sibling)
enum LinkDirection {
  /// Link goes from source to target only.
  ///
  /// Example: "Alice reports_to Bob" - Alice → Bob
  outgoing,

  /// Link goes from target to source only.
  ///
  /// Rarely used directly; typically just reverse the source/target.
  incoming,

  /// Link goes both ways.
  ///
  /// Example: "Alice spouse Bob" - Alice ↔ Bob
  bidirectional,
}

// =============================================================================
// Node Link
// =============================================================================

/// {@template mz_collection.node_link}
/// A relationship between two nodes.
///
/// Links are the edges in a graph that connect nodes outside the tree
/// hierarchy. Each link has:
///
/// - **id**: Unique identifier for this link
/// - **sourceId**: Starting node ID
/// - **targetId**: Ending node ID
/// - **type**: Relationship type (e.g., 'spouse', 'reports_to', 'shortcut')
/// - **direction**: How the relationship can be traversed
/// - **metadata**: Optional additional data about the relationship
///
/// ## Example
///
/// {@tool snippet}
/// Creating different types of NodeLinks:
///
/// ```dart
/// // One-way relationship (employee → manager)
/// final reportsTo = NodeLink(
///   id: 'emp1-mgr1',
///   sourceId: 'employee-1',
///   targetId: 'manager-1',
///   type: 'reports_to',
/// );
///
/// // Two-way relationship (spouses)
/// final marriage = NodeLink(
///   id: 'alice-bob-spouse',
///   sourceId: 'alice',
///   targetId: 'bob',
///   type: 'spouse',
///   direction: LinkDirection.bidirectional,
/// );
///
/// // With metadata
/// final mentorship = NodeLink(
///   id: 'mentor-1',
///   sourceId: 'junior',
///   targetId: 'senior',
///   type: 'mentored_by',
///   metadata: {'since': '2024-01-01', 'area': 'engineering'},
/// );
/// ```
/// {@end-tool}
/// {@endtemplate}
@immutable
class NodeLink {
  /// Creates a node link.
  const NodeLink({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.type,
    this.direction = LinkDirection.outgoing,
    this.metadata,
  });

  /// Unique identifier for this link.
  final String id;

  /// Source node ID (starting point of the relationship).
  final String sourceId;

  /// Target node ID (ending point of the relationship).
  final String targetId;

  /// Relationship type (e.g., 'spouse', 'reports_to', 'shortcut').
  ///
  /// Types are user-defined and enable filtering queries by relationship kind.
  final String type;

  /// Direction of the relationship.
  ///
  /// - [LinkDirection.outgoing]: Can traverse source → target
  /// - [LinkDirection.bidirectional]: Can traverse both ways
  final LinkDirection direction;

  /// Optional metadata about the relationship.
  ///
  /// Can store additional context like dates, weights, labels, etc.
  final Map<String, dynamic>? metadata;

  /// Whether this link involves the given node (as source or target).
  bool involves(String nodeId) => sourceId == nodeId || targetId == nodeId;

  /// Gets the "other" node ID from the perspective of [fromNodeId].
  ///
  /// Returns null if [fromNodeId] is not part of this link.
  String? otherNode(String fromNodeId) {
    if (sourceId == fromNodeId) return targetId;
    if (targetId == fromNodeId) return sourceId;
    return null;
  }

  /// Whether this link can be traversed from [fromNodeId].
  ///
  /// For outgoing links, only traversable from source.
  /// For bidirectional links, traversable from either end.
  bool canTraverseFrom(String fromNodeId) {
    if (direction == LinkDirection.bidirectional) {
      return involves(fromNodeId);
    }
    return sourceId == fromNodeId;
  }

  /// Creates a copy with modified values.
  NodeLink copyWith({
    String? id,
    String? sourceId,
    String? targetId,
    String? type,
    LinkDirection? direction,
    Map<String, dynamic>? metadata,
  }) {
    return NodeLink(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      targetId: targetId ?? this.targetId,
      type: type ?? this.type,
      direction: direction ?? this.direction,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NodeLink && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    final dir = direction == LinkDirection.bidirectional ? '↔' : '→';
    return 'NodeLink($sourceId $dir $targetId, type: $type)';
  }
}

// =============================================================================
// Link Manager
// =============================================================================

/// {@template mz_collection.link_manager}
/// Manages cross-cutting relationships between nodes.
///
/// While the `Node` class provides tree hierarchy (single parent), LinkManager
/// provides
/// graph relationships (multi-parent, cross-references, arbitrary connections).
///
/// ## Features
///
/// - **O(1) lookups**: Indexed by source, target, and type
/// - **Typed relationships**: Filter queries by relationship kind
/// - **Bidirectional support**: Two-way relationships (spouse, sibling)
/// - **Graph traversal**: Find paths, reachable nodes
/// - **Reactive**: Notifies listeners on changes
///
/// ## Example: Org Chart with Matrix Reporting
///
/// {@tool snippet}
/// Matrix reporting with multiple managers:
///
/// ```dart
/// final links = LinkManager();
///
/// // Alice has two managers (matrix reporting)
/// links.add(NodeLink(
///   id: 'alice-bob',
///   sourceId: 'alice',
///   targetId: 'bob',
///   type: 'reports_to',
/// ));
/// links.add(NodeLink(
///   id: 'alice-carol',
///   sourceId: 'alice',
///   targetId: 'carol',
///   type: 'dotted_line',
/// ));
///
/// // Query all managers
/// final solidLine = links.getLinkedNodeIds('alice', type: 'reports_to');
/// final dottedLine = links.getLinkedNodeIds('alice', type: 'dotted_line');
/// final allManagers = links.getLinkedNodeIds('alice'); // Both
/// ```
/// {@end-tool}
///
/// ## Example: Family Tree
///
/// {@tool snippet}
/// Family relationships with multi-parent support:
///
/// ```dart
/// final links = LinkManager();
///
/// // John and Jane are married (bidirectional)
/// links.add(NodeLink(
///   id: 'john-jane',
///   sourceId: 'john',
///   targetId: 'jane',
///   type: 'spouse',
///   direction: LinkDirection.bidirectional,
/// ));
///
/// // Child has two parents (multi-parent)
/// links.add(NodeLink(
///   id: 'c1', sourceId: 'child', targetId: 'john', type: 'parent'));
/// links.add(NodeLink(
///   id: 'c2', sourceId: 'child', targetId: 'jane', type: 'parent'));
///
/// // Query
/// final parents = links.getLinkedNodeIds('child', type: 'parent');
/// print(parents); // ['john', 'jane']
/// ```
/// {@end-tool}
/// {@endtemplate}
class LinkManager with Listenable {
  /// Creates an empty link manager.
  LinkManager();

  // ---------------------------------------------------------------------------
  // Storage
  // ---------------------------------------------------------------------------

  /// All links by ID.
  final Map<String, NodeLink> _links = {};

  /// Index: sourceId → Set of link IDs.
  final Map<String, Set<String>> _outgoing = {};

  /// Index: targetId → Set of link IDs.
  final Map<String, Set<String>> _incoming = {};

  /// Index: type → Set of link IDs.
  final Map<String, Set<String>> _byType = {};

  // ---------------------------------------------------------------------------
  // Properties
  // ---------------------------------------------------------------------------

  /// All links.
  Iterable<NodeLink> get links => _links.values;

  /// Number of links.
  int get length => _links.length;

  /// Whether there are no links.
  bool get isEmpty => _links.isEmpty;

  /// Whether there are links.
  bool get isNotEmpty => _links.isNotEmpty;

  /// All unique link types currently in use.
  Set<String> get types => _byType.keys.toSet();

  /// All node IDs that have outgoing links.
  Set<String> get sourceNodes => _outgoing.keys.toSet();

  /// All node IDs that have incoming links.
  Set<String> get targetNodes => _incoming.keys.toSet();

  /// All node IDs that have any links (source or target).
  Set<String> get linkedNodes => {..._outgoing.keys, ..._incoming.keys};

  // ---------------------------------------------------------------------------
  // CRUD Operations
  // ---------------------------------------------------------------------------

  /// Gets a link by ID.
  NodeLink? operator [](String linkId) => _links[linkId];

  /// Adds a link.
  ///
  /// If a link with the same ID exists, it is replaced.
  void add(NodeLink link) {
    // Remove old version if exists (to update indices)
    if (_links.containsKey(link.id)) {
      _removeFromIndices(link.id);
    }

    _links[link.id] = link;

    // Update indices
    (_outgoing[link.sourceId] ??= {}).add(link.id);
    (_incoming[link.targetId] ??= {}).add(link.id);
    (_byType[link.type] ??= {}).add(link.id);

    // For bidirectional, index both directions
    if (link.direction == LinkDirection.bidirectional) {
      (_outgoing[link.targetId] ??= {}).add(link.id);
      (_incoming[link.sourceId] ??= {}).add(link.id);
    }

    notifyChanged();
  }

  /// Adds multiple links.
  void addAll(Iterable<NodeLink> links) {
    for (final link in links) {
      // Inline add without notifications
      if (_links.containsKey(link.id)) {
        _removeFromIndices(link.id);
      }

      _links[link.id] = link;

      (_outgoing[link.sourceId] ??= {}).add(link.id);
      (_incoming[link.targetId] ??= {}).add(link.id);
      (_byType[link.type] ??= {}).add(link.id);

      if (link.direction == LinkDirection.bidirectional) {
        (_outgoing[link.targetId] ??= {}).add(link.id);
        (_incoming[link.sourceId] ??= {}).add(link.id);
      }
    }
    notifyChanged();
  }

  /// Removes a link by ID.
  ///
  /// Returns the removed link, or null if not found.
  NodeLink? remove(String linkId) {
    if (!_links.containsKey(linkId)) return null;

    _removeFromIndices(linkId);
    final link = _links.remove(linkId);
    notifyChanged();
    return link;
  }

  void _removeFromIndices(String linkId) {
    // All callers verify link exists before calling this internal method
    final link = _links[linkId]!;

    _outgoing[link.sourceId]?.remove(linkId);
    _incoming[link.targetId]?.remove(linkId);
    _byType[link.type]?.remove(linkId);

    if (link.direction == LinkDirection.bidirectional) {
      _outgoing[link.targetId]?.remove(linkId);
      _incoming[link.sourceId]?.remove(linkId);
    }

    // Clean up empty sets
    if (_outgoing[link.sourceId]?.isEmpty ?? false) {
      _outgoing.remove(link.sourceId);
    }
    if (_incoming[link.targetId]?.isEmpty ?? false) {
      _incoming.remove(link.targetId);
    }
    if (_byType[link.type]?.isEmpty ?? false) {
      _byType.remove(link.type);
    }
  }

  /// Removes all links involving a node (as source or target).
  void removeAllForNode(String nodeId) {
    final linkIds = {
      ...?_outgoing[nodeId],
      ...?_incoming[nodeId],
    };

    for (final linkId in linkIds) {
      _removeFromIndices(linkId);
      _links.remove(linkId);
    }

    if (linkIds.isNotEmpty) {
      notifyChanged();
    }
  }

  /// Removes all links of a specific type.
  void removeAllOfType(String type) {
    final linkIds = _byType[type]?.toList() ?? [];

    for (final linkId in linkIds) {
      _removeFromIndices(linkId);
      _links.remove(linkId);
    }

    if (linkIds.isNotEmpty) {
      notifyChanged();
    }
  }

  /// Clears all links.
  void clear() {
    if (_links.isEmpty) return;

    _links.clear();
    _outgoing.clear();
    _incoming.clear();
    _byType.clear();
    notifyChanged();
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Gets all outgoing links from a node.
  ///
  /// For bidirectional links, this includes links where the node is either
  /// source or target.
  List<NodeLink> getOutgoingLinks(String nodeId, {String? type}) {
    final linkIds = _outgoing[nodeId];
    if (linkIds == null) return const [];

    return linkIds
        .map((id) => _links[id])
        .whereType<NodeLink>()
        .where((link) => type == null || link.type == type)
        .toList();
  }

  /// Gets all incoming links to a node.
  ///
  /// For bidirectional links, this includes links where the node is either
  /// source or target.
  List<NodeLink> getIncomingLinks(String nodeId, {String? type}) {
    final linkIds = _incoming[nodeId];
    if (linkIds == null) return const [];

    return linkIds
        .map((id) => _links[id])
        .whereType<NodeLink>()
        .where((link) => type == null || link.type == type)
        .toList();
  }

  /// Gets all links involving a node (both directions).
  List<NodeLink> getAllLinks(String nodeId, {String? type}) {
    final outgoing = getOutgoingLinks(nodeId, type: type);
    final incoming = getIncomingLinks(nodeId, type: type);

    // Dedupe (bidirectional links appear in both)
    final seen = <String>{};
    return [
      ...outgoing.where((l) => seen.add(l.id)),
      ...incoming.where((l) => seen.add(l.id)),
    ];
  }

  /// Gets IDs of nodes linked from this node.
  ///
  /// Returns the "other end" of each link from [nodeId].
  ///
  /// {@tool snippet}
  /// Querying linked node IDs:
  ///
  /// ```dart
  /// final managers = links.getLinkedNodeIds('employee', type: 'reports_to');
  /// ```
  /// {@end-tool}
  List<String> getLinkedNodeIds(String nodeId, {String? type}) {
    final nodeLinks = getAllLinks(nodeId, type: type);

    return nodeLinks
        .where((l) => l.canTraverseFrom(nodeId))
        .map((l) => l.otherNode(nodeId))
        .whereType<String>()
        .toList();
  }

  /// Gets all links of a specific type.
  List<NodeLink> getLinksByType(String type) {
    final linkIds = _byType[type];
    if (linkIds == null) return const [];

    return linkIds.map((id) => _links[id]).whereType<NodeLink>().toList();
  }

  /// Checks if two nodes are linked (directly).
  bool areLinked(String nodeA, String nodeB, {String? type}) {
    final nodeLinks = getAllLinks(nodeA, type: type);
    return nodeLinks.any((l) => l.involves(nodeB));
  }

  /// Gets the link between two nodes (if any).
  NodeLink? getLinkBetween(String nodeA, String nodeB, {String? type}) {
    final nodeLinks = getAllLinks(nodeA, type: type);
    for (final link in nodeLinks) {
      if (link.involves(nodeB)) return link;
    }
    return null;
  }

  /// Counts links for a node.
  int linkCount(String nodeId, {String? type}) {
    return getAllLinks(nodeId, type: type).length;
  }

  // ---------------------------------------------------------------------------
  // Graph Traversal
  // ---------------------------------------------------------------------------

  /// Gets all nodes reachable from [startNodeId] via links.
  ///
  /// Uses BFS traversal. Respects link direction.
  ///
  /// {@tool snippet}
  /// Finding all reachable nodes via graph traversal:
  ///
  /// ```dart
  /// // Find all reports (direct and indirect)
  /// final allReports = links.getReachableNodes(
  ///   'ceo',
  ///   type: 'reports_to',
  ///   maxDepth: 5,
  /// );
  /// ```
  /// {@end-tool}
  Set<String> getReachableNodes(
    String startNodeId, {
    String? type,
    bool includeStart = false,
    int? maxDepth,
  }) {
    final visited = <String>{};
    final queue = <(String, int)>[(startNodeId, 0)];

    while (queue.isNotEmpty) {
      final (nodeId, depth) = queue.removeAt(0);

      if (visited.contains(nodeId)) continue;
      if (maxDepth != null && depth > maxDepth) continue;

      visited.add(nodeId);

      final linkedIds = getLinkedNodeIds(nodeId, type: type);
      for (final linkedId in linkedIds) {
        if (!visited.contains(linkedId)) {
          queue.add((linkedId, depth + 1));
        }
      }
    }

    if (!includeStart) visited.remove(startNodeId);
    return visited;
  }

  /// Finds shortest path between two nodes via links.
  ///
  /// Returns list of node IDs from start to end, or null if no path exists.
  ///
  /// {@tool snippet}
  /// Finding the shortest path between nodes:
  ///
  /// ```dart
  /// final path = links.findPath('alice', 'diana', type: 'reports_to');
  /// print(path); // ['alice', 'bob', 'diana']
  /// ```
  /// {@end-tool}
  List<String>? findPath(
    String startNodeId,
    String endNodeId, {
    String? type,
  }) {
    if (startNodeId == endNodeId) return [startNodeId];

    final visited = <String>{};
    final queue = <List<String>>[
      [startNodeId],
    ];

    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final current = path.last;

      if (visited.contains(current)) continue;
      visited.add(current);

      final linkedIds = getLinkedNodeIds(current, type: type);
      for (final linkedId in linkedIds) {
        final newPath = [...path, linkedId];

        if (linkedId == endNodeId) return newPath;

        if (!visited.contains(linkedId)) {
          queue.add(newPath);
        }
      }
    }

    return null; // No path found
  }

  /// Finds all paths between two nodes (up to maxPaths).
  ///
  /// Uses DFS with cycle detection.
  List<List<String>> findAllPaths(
    String startNodeId,
    String endNodeId, {
    String? type,
    int maxPaths = 10,
    int maxDepth = 10,
  }) {
    final results = <List<String>>[];

    void dfs(String current, List<String> path, Set<String> visited) {
      if (results.length >= maxPaths) return;
      if (path.length > maxDepth) return;
      if (visited.contains(current)) return;

      final newPath = [...path, current];

      if (current == endNodeId) {
        results.add(newPath);
        return;
      }

      final newVisited = {...visited, current};
      final linkedIds = getLinkedNodeIds(current, type: type);

      for (final linkedId in linkedIds) {
        dfs(linkedId, newPath, newVisited);
      }
    }

    dfs(startNodeId, [], {});
    return results;
  }

  // ---------------------------------------------------------------------------
  // Node-Aware Queries
  // ---------------------------------------------------------------------------

  /// Gets all nodes linked to the given node.
  ///
  /// Requires [root] to look up nodes by ID. Returns nodes that exist in the
  /// tree and have links to/from [nodeId].
  ///
  /// {@tool snippet}
  /// Getting linked nodes:
  ///
  /// ```dart
  /// final linkedNodes = linkManager.getLinkedNodes(
  ///   'employee-1',
  ///   controller.root,
  ///   type: 'reports_to',
  /// );
  /// ```
  /// {@end-tool}
  List<Node<T>> getLinkedNodes<T>(
    String nodeId,
    Node<T> root, {
    String? type,
  }) {
    final linkedIds = getLinkedNodeIds(nodeId, type: type);
    final result = <Node<T>>[];

    for (final id in linkedIds) {
      final node = root.findNode(id);
      if (node != null) {
        result.add(node);
      }
    }

    return result;
  }

  /// Gets all items linked to the given node.
  ///
  /// Requires [root] to look up nodes by ID. Returns the first item from each
  /// linked node that exists in the tree.
  ///
  /// {@tool snippet}
  /// Getting linked items:
  ///
  /// ```dart
  /// final linkedItems = linkManager.getLinkedItems<Task>(
  ///   'task-1',
  ///   controller.root,
  ///   type: 'depends_on',
  /// );
  /// ```
  /// {@end-tool}
  List<T> getLinkedItems<T>(
    String nodeId,
    Node<T> root, {
    String? type,
  }) {
    final linkedIds = getLinkedNodeIds(nodeId, type: type);
    final result = <T>[];

    for (final id in linkedIds) {
      final node = root.findNode(id);
      if (node != null && node.isNotEmpty) {
        result.add(node.first);
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Disposal
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    clear();
    super.dispose();
  }

  @override
  String toString() {
    return 'LinkManager(links: ${_links.length}, types: ${types.length})';
  }
}
