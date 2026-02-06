import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mz_collection/mz_collection.dart';

/// Demonstrates Node tree structure combined with LinkManager for graph
/// relationships. Shows a visual knowledge graph with draggable nodes.
class GraphViewDemo extends StatefulWidget {
  const GraphViewDemo({super.key});

  @override
  State<GraphViewDemo> createState() => _GraphViewDemoState();
}

class _GraphViewDemoState extends State<GraphViewDemo>
    with SingleTickerProviderStateMixin {
  // Tree structure for hierarchical relationships
  late final Node<GraphNode> _root;

  // Link manager for cross-cutting relationships (non-tree edges)
  final LinkManager _linkManager = LinkManager();

  // Node positions for rendering
  final Map<String, Offset> _positions = {};

  // Currently selected node (for creating links)
  String? _selectedNodeId;

  // Link creation mode
  bool _linkMode = false;
  String? _linkSourceId;

  // Path finding
  List<String>? _highlightedPath;

  // Infinite canvas state
  Offset _canvasOffset = Offset.zero;
  double _canvasScale = 1.0;

  // Force-directed layout animation
  late final AnimationController _layoutController;
  bool _isLayoutRunning = false;

  // Force-directed layout parameters
  static const _repulsionStrength = 5000.0; // How strongly nodes repel
  static const _springStrength = 0.05; // How strongly edges pull
  static const _springLength = 120.0; // Ideal edge length
  static const _damping = 0.85; // Velocity damping (0-1)
  static const _minVelocity = 0.5; // Stop when velocity is below this

  // Node velocities for physics simulation
  final Map<String, Offset> _velocities = {};

  @override
  void initState() {
    super.initState();
    _layoutController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(_updateLayout);
    _initializeGraph();
  }

  void _initializeGraph() {
    // Create root node for the tree
    _root = Node<GraphNode>(
      id: 'root',
      keyOf: (node) => node.id,
    );

    // Create concept nodes
    final concepts = [
      GraphNode(id: 'flutter', label: 'Flutter', color: Colors.blue),
      GraphNode(id: 'dart', label: 'Dart', color: Colors.teal),
      GraphNode(id: 'widgets', label: 'Widgets', color: Colors.purple),
      GraphNode(id: 'state', label: 'State', color: Colors.orange),
      GraphNode(id: 'async', label: 'Async', color: Colors.green),
      GraphNode(id: 'streams', label: 'Streams', color: Colors.cyan),
      GraphNode(id: 'futures', label: 'Futures', color: Colors.lime),
      GraphNode(id: 'ui', label: 'UI', color: Colors.pink),
      GraphNode(id: 'animations', label: 'Animations', color: Colors.amber),
    ];

    // Add all concepts to root (flat structure for simplicity)
    for (final concept in concepts) {
      _root.add(concept);
    }

    // Create hierarchical child nodes for some concepts
    final flutterNode = Node<GraphNode>(
      id: 'flutter_node',
      keyOf: (n) => n.id,
    );
    flutterNode.add(concepts[0]); // Flutter

    final dartNode = Node<GraphNode>(
      id: 'dart_node',
      keyOf: (n) => n.id,
    );
    dartNode.add(concepts[1]); // Dart

    // Set up initial positions in a circle
    _layoutNodesInCircle();

    // Add some initial links (cross-cutting relationships)
    _linkManager.addAll([
      // Flutter uses Dart
      NodeLink(
        id: 'flutter-dart',
        sourceId: 'flutter',
        targetId: 'dart',
        type: 'uses',
        direction: LinkDirection.outgoing,
      ),
      // Flutter has Widgets
      NodeLink(
        id: 'flutter-widgets',
        sourceId: 'flutter',
        targetId: 'widgets',
        type: 'contains',
        direction: LinkDirection.outgoing,
      ),
      // Widgets have State
      NodeLink(
        id: 'widgets-state',
        sourceId: 'widgets',
        targetId: 'state',
        type: 'manages',
        direction: LinkDirection.outgoing,
      ),
      // Dart has Async
      NodeLink(
        id: 'dart-async',
        sourceId: 'dart',
        targetId: 'async',
        type: 'provides',
        direction: LinkDirection.outgoing,
      ),
      // Async includes Streams and Futures
      NodeLink(
        id: 'async-streams',
        sourceId: 'async',
        targetId: 'streams',
        type: 'includes',
        direction: LinkDirection.outgoing,
      ),
      NodeLink(
        id: 'async-futures',
        sourceId: 'async',
        targetId: 'futures',
        type: 'includes',
        direction: LinkDirection.outgoing,
      ),
      // Flutter builds UI
      NodeLink(
        id: 'flutter-ui',
        sourceId: 'flutter',
        targetId: 'ui',
        type: 'creates',
        direction: LinkDirection.outgoing,
      ),
      // UI has Animations
      NodeLink(
        id: 'ui-animations',
        sourceId: 'ui',
        targetId: 'animations',
        type: 'includes',
        direction: LinkDirection.outgoing,
      ),
      // State affects UI (bidirectional)
      NodeLink(
        id: 'state-ui',
        sourceId: 'state',
        targetId: 'ui',
        type: 'affects',
        direction: LinkDirection.bidirectional,
      ),
      // Streams can update State
      NodeLink(
        id: 'streams-state',
        sourceId: 'streams',
        targetId: 'state',
        type: 'updates',
        direction: LinkDirection.outgoing,
      ),
    ]);

    _linkManager.addChangeListener(_onLinksChanged);
  }

  void _layoutNodesInCircle() {
    final items = _root.toList();
    final center = const Offset(200, 200);
    const radius = 150.0;

    for (var i = 0; i < items.length; i++) {
      final angle = (2 * pi * i / items.length) - pi / 2;
      _positions[items[i].id] = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
    }
  }

  void _onLinksChanged() {
    if (mounted) setState(() {});
  }

  void _onNodeTap(GraphNode node) {
    if (_linkMode && _linkSourceId != null) {
      // Create link from source to this node
      if (_linkSourceId != node.id) {
        final linkId =
            '$_linkSourceId-${node.id}-${DateTime.now().millisecondsSinceEpoch}';
        _linkManager.add(NodeLink(
          id: linkId,
          sourceId: _linkSourceId!,
          targetId: node.id,
          type: 'related',
          direction: LinkDirection.outgoing,
        ));
      }
      setState(() {
        _linkMode = false;
        _linkSourceId = null;
      });
    } else {
      setState(() {
        _selectedNodeId = _selectedNodeId == node.id ? null : node.id;
        _highlightedPath = null;
      });
    }
  }

  void _onNodeDrag(String nodeId, Offset delta) {
    setState(() {
      final current = _positions[nodeId] ?? Offset.zero;
      // Adjust delta by scale so dragging feels natural at any zoom level
      _positions[nodeId] = current + delta / _canvasScale;
    });
  }

  void _startLinkMode() {
    if (_selectedNodeId != null) {
      setState(() {
        _linkMode = true;
        _linkSourceId = _selectedNodeId;
      });
    }
  }

  void _deleteSelectedLinks() {
    if (_selectedNodeId != null) {
      _linkManager.removeAllForNode(_selectedNodeId!);
      setState(() {});
    }
  }

  void _findPathToSelected() {
    if (_selectedNodeId == null) return;

    // Find path from 'flutter' to selected node
    final path = _linkManager.findPath('flutter', _selectedNodeId!);
    setState(() {
      _highlightedPath = path;
    });
  }

  void _showReachableNodes() {
    if (_selectedNodeId == null) return;

    final reachable = _linkManager.getReachableNodes(
      _selectedNodeId!,
      includeStart: true,
    );

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reachable from $_selectedNodeId'),
        content: Text(
          reachable.isEmpty ? 'No reachable nodes' : reachable.join(', '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _resetLayout() {
    _stopAutoLayout();
    _velocities.clear();
    setState(() {
      _layoutNodesInCircle();
      _highlightedPath = null;
      _canvasOffset = Offset.zero;
      _canvasScale = 1.0;
    });
  }

  void _onCanvasPan(Offset delta) {
    setState(() {
      _canvasOffset += delta;
    });
  }

  void _onCanvasScale(double scale, Offset focalPoint) {
    setState(() {
      final newScale = (_canvasScale * scale).clamp(0.25, 4.0);
      if (newScale != _canvasScale) {
        // Adjust offset to zoom toward focal point
        final focalPointInCanvas = (focalPoint - _canvasOffset) / _canvasScale;
        _canvasScale = newScale;
        _canvasOffset = focalPoint - focalPointInCanvas * _canvasScale;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Force-Directed Layout Algorithm
  // ─────────────────────────────────────────────────────────────────────────

  void _startAutoLayout() {
    if (_isLayoutRunning) {
      _stopAutoLayout();
      return;
    }

    // Initialize velocities
    for (final item in _root) {
      _velocities[item.id] = Offset.zero;
    }

    setState(() => _isLayoutRunning = true);
    _layoutController.repeat();
  }

  void _stopAutoLayout() {
    _layoutController.stop();
    setState(() => _isLayoutRunning = false);
  }

  void _updateLayout() {
    if (!_isLayoutRunning) return;

    final nodes = _root.toList();
    final nodeIds = nodes.map((n) => n.id).toList();

    // Calculate forces for each node
    final forces = <String, Offset>{};
    for (final nodeId in nodeIds) {
      forces[nodeId] = Offset.zero;
    }

    // 1. Repulsion forces between all node pairs
    for (var i = 0; i < nodeIds.length; i++) {
      for (var j = i + 1; j < nodeIds.length; j++) {
        final idA = nodeIds[i];
        final idB = nodeIds[j];
        final posA = _positions[idA] ?? Offset.zero;
        final posB = _positions[idB] ?? Offset.zero;

        final delta = posA - posB;
        final distance = delta.distance.clamp(1.0, 500.0);

        // Coulomb's law: F = k / d²
        final forceMagnitude = _repulsionStrength / (distance * distance);
        final forceDirection = delta / distance;
        final force = forceDirection * forceMagnitude;

        forces[idA] = forces[idA]! + force;
        forces[idB] = forces[idB]! - force;
      }
    }

    // 2. Spring forces along edges
    for (final link in _linkManager.links) {
      final posA = _positions[link.sourceId];
      final posB = _positions[link.targetId];

      if (posA == null || posB == null) continue;

      final delta = posB - posA;
      final distance = delta.distance.clamp(1.0, 500.0);

      // Hooke's law: F = k * (d - rest_length)
      final displacement = distance - _springLength;
      final forceMagnitude = _springStrength * displacement;
      final forceDirection = delta / distance;
      final force = forceDirection * forceMagnitude;

      if (forces.containsKey(link.sourceId)) {
        forces[link.sourceId] = forces[link.sourceId]! + force;
      }
      if (forces.containsKey(link.targetId)) {
        forces[link.targetId] = forces[link.targetId]! - force;
      }
    }

    // 3. Update velocities and positions
    var totalVelocity = 0.0;

    for (final nodeId in nodeIds) {
      // Update velocity with force and damping
      var velocity = _velocities[nodeId] ?? Offset.zero;
      velocity = (velocity + forces[nodeId]!) * _damping;
      _velocities[nodeId] = velocity;

      // Update position
      final currentPos = _positions[nodeId] ?? Offset.zero;
      _positions[nodeId] = currentPos + velocity;

      totalVelocity += velocity.distance;
    }

    // 4. Check if settled
    final avgVelocity = totalVelocity / nodeIds.length;
    if (avgVelocity < _minVelocity) {
      _stopAutoLayout();
    }

    setState(() {});
  }

  void _centerGraph() {
    if (_positions.isEmpty) return;

    // Calculate bounding box
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    for (final pos in _positions.values) {
      minX = min(minX, pos.dx);
      minY = min(minY, pos.dy);
      maxX = max(maxX, pos.dx);
      maxY = max(maxY, pos.dy);
    }

    // Center of the graph
    final graphCenter = Offset(
      (minX + maxX) / 2,
      (minY + maxY) / 2,
    );

    // Move all nodes so graph is centered at origin
    setState(() {
      for (final entry in _positions.entries) {
        _positions[entry.key] = entry.value - graphCenter;
      }
      _canvasOffset = Offset.zero;
    });
  }

  @override
  void dispose() {
    _layoutController.dispose();
    _linkManager.removeChangeListener(_onLinksChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Graph View', style: TextStyle(fontSize: 16)),
            Text(
              '${_root.length} nodes, ${_linkManager.length} links',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isLayoutRunning ? Icons.stop : Icons.auto_fix_high,
            ),
            onPressed: _startAutoLayout,
            tooltip: _isLayoutRunning ? 'Stop Layout' : 'Auto Layout',
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _centerGraph,
            tooltip: 'Center Graph',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetLayout,
            tooltip: 'Reset Layout',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _InfiniteCanvas(
                  positions: _positions,
                  linkManager: _linkManager,
                  highlightedPath: _highlightedPath,
                  selectedNodeId: _selectedNodeId,
                  onPanUpdate: _onCanvasPan,
                  onScaleUpdate: _onCanvasScale,
                  canvasOffset: _canvasOffset,
                  canvasScale: _canvasScale,
                  children: _buildNodes(),
                );
              },
            ),
          ),
          _buildInfoPanel(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // Link mode indicator
          if (_linkMode) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.link,
                    size: 16,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Click target node',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() {
                _linkMode = false;
                _linkSourceId = null;
              }),
              child: const Text('Cancel'),
            ),
          ] else ...[
            // Normal toolbar
            FilledButton.tonalIcon(
              onPressed: _selectedNodeId != null ? _startLinkMode : null,
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Add Link'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _selectedNodeId != null ? _deleteSelectedLinks : null,
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('Remove Links'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _selectedNodeId != null ? _findPathToSelected : null,
              icon: const Icon(Icons.route, size: 18),
              label: const Text('Path from Flutter'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _selectedNodeId != null ? _showReachableNodes : null,
              icon: const Icon(Icons.hub, size: 18),
              label: const Text('Reachable'),
            ),
          ],
        ],
      ),
    );
  }

  List<_CanvasNode> _buildNodes() {
    return _root.map((item) {
      final position = _positions[item.id] ?? Offset.zero;
      final isSelected = _selectedNodeId == item.id;
      final isLinkSource = _linkSourceId == item.id;
      final isInPath = _highlightedPath?.contains(item.id) ?? false;

      return _CanvasNode(
        id: item.id,
        position: position,
        onTap: () => _onNodeTap(item),
        onDrag: (delta) => _onNodeDrag(item.id, delta),
        child: _GraphNodeWidget(
          node: item,
          isSelected: isSelected,
          isLinkSource: isLinkSource,
          isInPath: isInPath,
          linkCount: _linkManager.linkCount(item.id),
        ),
      );
    }).toList();
  }

  Widget _buildInfoPanel() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_selectedNodeId == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: const Text(
          'Tap a node to select it. Drag nodes to reposition. '
          'Use toolbar to add/remove links or find paths.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    final node = _root[_selectedNodeId!];
    if (node == null) return const SizedBox.shrink();

    final outgoing = _linkManager.getOutgoingLinks(_selectedNodeId!);
    final incoming = _linkManager.getIncomingLinks(_selectedNodeId!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: node.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                node.label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'ID: ${node.id}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: [
              if (outgoing.isNotEmpty)
                Text(
                  'Outgoing: ${outgoing.map((l) => '${l.type}→${l.targetId}').join(', ')}',
                  style: const TextStyle(fontSize: 12),
                ),
              if (incoming.isNotEmpty)
                Text(
                  'Incoming: ${incoming.map((l) => '${l.sourceId}→${l.type}').join(', ')}',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A node in the graph.
class GraphNode {
  const GraphNode({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;
  final String label;
  final Color color;
}

/// Widget for rendering a graph node.
class _GraphNodeWidget extends StatelessWidget {
  const _GraphNodeWidget({
    required this.node,
    required this.isSelected,
    required this.isLinkSource,
    required this.isInPath,
    required this.linkCount,
  });

  final GraphNode node;
  final bool isSelected;
  final bool isLinkSource;
  final bool isInPath;
  final int linkCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color borderColor;
    double borderWidth;

    if (isLinkSource) {
      borderColor = Colors.green;
      borderWidth = 3;
    } else if (isInPath) {
      borderColor = Colors.amber;
      borderWidth = 3;
    } else if (isSelected) {
      borderColor = colorScheme.primary;
      borderWidth = 3;
    } else {
      borderColor = colorScheme.outline;
      borderWidth = 1;
    }

    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: node.color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            node.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            '$linkCount links',
            style: TextStyle(
              fontSize: 8,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Data class for a node to be rendered on the infinite canvas.
class _CanvasNode {
  const _CanvasNode({
    required this.id,
    required this.position,
    required this.onTap,
    required this.onDrag,
    required this.child,
  });

  final String id;
  final Offset position;
  final VoidCallback onTap;
  final void Function(Offset delta) onDrag;
  final Widget child;
}

/// An infinite canvas that supports panning and zooming.
class _InfiniteCanvas extends StatefulWidget {
  const _InfiniteCanvas({
    required this.positions,
    required this.linkManager,
    required this.highlightedPath,
    required this.selectedNodeId,
    required this.onPanUpdate,
    required this.onScaleUpdate,
    required this.canvasOffset,
    required this.canvasScale,
    required this.children,
  });

  final Map<String, Offset> positions;
  final LinkManager linkManager;
  final List<String>? highlightedPath;
  final String? selectedNodeId;
  final void Function(Offset delta) onPanUpdate;
  final void Function(double scale, Offset focalPoint) onScaleUpdate;
  final Offset canvasOffset;
  final double canvasScale;
  final List<_CanvasNode> children;

  @override
  State<_InfiniteCanvas> createState() => _InfiniteCanvasState();
}

class _InfiniteCanvasState extends State<_InfiniteCanvas> {
  // Track if we're currently dragging a node (to prevent canvas pan)
  bool _isDraggingNode = false;
  double _lastScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: ClipRect(
        child: CustomPaint(
          painter: _GridPainter(
            offset: widget.canvasOffset,
            scale: widget.canvasScale,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Links layer (transformed)
              Positioned.fill(
                child: CustomPaint(
                  painter: _TransformedLinkPainter(
                    links: widget.linkManager.links,
                    positions: widget.positions,
                    highlightedPath: widget.highlightedPath,
                    selectedNodeId: widget.selectedNodeId,
                    offset: widget.canvasOffset,
                    scale: widget.canvasScale,
                  ),
                ),
              ),
              // Nodes layer (transformed)
              ...widget.children.map(_buildNode),
            ],
          ),
        ),
      ),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastScale = 1.0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_isDraggingNode) return;

    if (details.pointerCount == 1) {
      // Single finger: pan
      widget.onPanUpdate(details.focalPointDelta);
    } else {
      // Multi-finger: zoom
      final scaleDelta = details.scale / _lastScale;
      _lastScale = details.scale;
      widget.onScaleUpdate(scaleDelta, details.localFocalPoint);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastScale = 1.0;
  }

  Widget _buildNode(_CanvasNode node) {
    // Transform position to screen coordinates
    final screenPos = node.position * widget.canvasScale + widget.canvasOffset;

    return Positioned(
      left: screenPos.dx - 35 * widget.canvasScale,
      top: screenPos.dy - 35 * widget.canvasScale,
      child: GestureDetector(
        onTap: node.onTap,
        onPanStart: (_) => _isDraggingNode = true,
        onPanUpdate: (details) => node.onDrag(details.delta),
        onPanEnd: (_) => _isDraggingNode = false,
        onPanCancel: () => _isDraggingNode = false,
        child: Transform.scale(
          scale: widget.canvasScale,
          child: node.child,
        ),
      ),
    );
  }
}

/// Paints a subtle grid background for the infinite canvas.
class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.offset,
    required this.scale,
  });

  final Offset offset;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    const gridSize = 50.0;
    final scaledGridSize = gridSize * scale;

    // Calculate starting positions based on offset
    final startX = offset.dx % scaledGridSize;
    final startY = offset.dy % scaledGridSize;

    // Draw vertical lines
    for (var x = startX; x < size.width; x += scaledGridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (var y = startY; y < size.height; y += scaledGridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw origin marker
    final origin = offset;
    if (origin.dx >= 0 &&
        origin.dx <= size.width &&
        origin.dy >= 0 &&
        origin.dy <= size.height) {
      final originPaint = Paint()
        ..color = Colors.grey.withValues(alpha: 0.3)
        ..strokeWidth = 2;
      canvas.drawCircle(origin, 5, originPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.offset != offset || oldDelegate.scale != scale;
  }
}

/// Custom painter that draws links with canvas transform applied.
class _TransformedLinkPainter extends CustomPainter {
  _TransformedLinkPainter({
    required this.links,
    required this.positions,
    required this.offset,
    required this.scale,
    this.highlightedPath,
    this.selectedNodeId,
  });

  final Iterable<NodeLink> links;
  final Map<String, Offset> positions;
  final Offset offset;
  final double scale;
  final List<String>? highlightedPath;
  final String? selectedNodeId;

  Offset _transform(Offset pos) => pos * scale + offset;

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in links) {
      final startPos = positions[link.sourceId];
      final endPos = positions[link.targetId];

      if (startPos == null || endPos == null) continue;

      final start = _transform(startPos);
      final end = _transform(endPos);

      // Check if this link is part of highlighted path
      final isHighlighted = _isLinkInPath(link);
      final involvesSelected = link.involves(selectedNodeId ?? '');

      final paint = Paint()
        ..strokeWidth = (isHighlighted ? 3 : (involvesSelected ? 2 : 1)) * scale
        ..style = PaintingStyle.stroke;

      if (isHighlighted) {
        paint.color = Colors.amber;
      } else if (involvesSelected) {
        paint.color = Colors.blue;
      } else {
        paint.color = Colors.grey.withValues(alpha: 0.5);
      }

      // Draw the line
      canvas.drawLine(start, end, paint);

      // Draw arrow for directed links
      if (link.direction != LinkDirection.incoming) {
        _drawArrow(canvas, start, end, paint);
      }

      // Draw reverse arrow for bidirectional
      if (link.direction == LinkDirection.bidirectional) {
        _drawArrow(canvas, end, start, paint);
      }

      // Draw link type label
      if (involvesSelected || isHighlighted) {
        _drawLabel(canvas, start, end, link.type);
      }
    }
  }

  bool _isLinkInPath(NodeLink link) {
    if (highlightedPath == null || highlightedPath!.length < 2) return false;

    for (var i = 0; i < highlightedPath!.length - 1; i++) {
      final from = highlightedPath![i];
      final to = highlightedPath![i + 1];

      if ((link.sourceId == from && link.targetId == to) ||
          (link.direction == LinkDirection.bidirectional &&
              link.sourceId == to &&
              link.targetId == from)) {
        return true;
      }
    }
    return false;
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    final direction = (end - start).direction;
    final arrowLength = 10.0 * scale;
    const arrowAngle = 0.5;

    // Move arrow back from the edge of the node
    final nodeRadius = 35 * scale;
    final adjustedEnd = Offset(
      end.dx - nodeRadius * cos(direction),
      end.dy - nodeRadius * sin(direction),
    );

    final path = Path();
    path.moveTo(adjustedEnd.dx, adjustedEnd.dy);
    path.lineTo(
      adjustedEnd.dx - arrowLength * cos(direction - arrowAngle),
      adjustedEnd.dy - arrowLength * sin(direction - arrowAngle),
    );
    path.moveTo(adjustedEnd.dx, adjustedEnd.dy);
    path.lineTo(
      adjustedEnd.dx - arrowLength * cos(direction + arrowAngle),
      adjustedEnd.dy - arrowLength * sin(direction + arrowAngle),
    );

    canvas.drawPath(path, paint);
  }

  void _drawLabel(Canvas canvas, Offset start, Offset end, String label) {
    final mid = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 9 * scale,
          color: Colors.grey.shade700,
          backgroundColor: Colors.white.withValues(alpha: 0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(mid.dx - textPainter.width / 2, mid.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _TransformedLinkPainter oldDelegate) {
    return oldDelegate.links != links ||
        oldDelegate.positions != positions ||
        oldDelegate.offset != offset ||
        oldDelegate.scale != scale ||
        oldDelegate.highlightedPath != highlightedPath ||
        oldDelegate.selectedNodeId != selectedNodeId;
  }
}
