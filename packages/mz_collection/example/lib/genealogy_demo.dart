import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mz_collection/mz_collection.dart';

import 'wikitree_service.dart';

/// Demonstrates a genealogy graph using Node + LinkManager.
/// Fetches real family data from WikiTree API.
class GenealogyDemo extends StatefulWidget {
  const GenealogyDemo({super.key});

  @override
  State<GenealogyDemo> createState() => _GenealogyDemoState();
}

class _GenealogyDemoState extends State<GenealogyDemo>
    with SingleTickerProviderStateMixin {
  // Services
  late final WikiTreeService _wikiTree;

  // Data structures
  late final Node<Person> _familyTree;
  final LinkManager _linkManager = LinkManager();

  // UI state
  final Map<String, Offset> _positions = {};
  final Set<String> _loadedPersons = {};
  final Set<String> _expandedPersons = {};
  String? _selectedPersonId;
  String? _errorMessage;
  bool _isLoading = false;

  // Canvas state
  Offset _canvasOffset = Offset.zero;
  double _canvasScale = 1.0;

  // Layout animation
  late final AnimationController _layoutController;
  bool _isLayoutRunning = false;
  final Map<String, Offset> _velocities = {};

  // Layout parameters for force simulation
  static const _repulsionStrength = 5000.0;
  static const _springStrength = 0.02;
  static const _springLength = 120.0;
  static const _damping = 0.85;
  static const _minVelocity = 0.3;

  // Hierarchical layout spacing
  static const _generationSpacing = 150.0; // Vertical space between generations
  static const _nodeSpacing =
      120.0; // Horizontal space between siblings/children
  static const _spouseSpacing = 100.0; // Horizontal space between spouses

  // Patrilineal mode - only show males in the graph
  bool _patrilinealMode = true;

  // Famous people to start with
  static const _famousPeople = [
    ('Churchill-4', 'Winston Churchill'),
    ('Einstein-1', 'Albert Einstein'),
    ('Darwin-26', 'Charles Darwin'),
    ('Washington-1', 'George Washington'),
    ('Mozart-1', 'Wolfgang Mozart'),
  ];

  @override
  void initState() {
    super.initState();
    _wikiTree = WikiTreeService();
    _familyTree = Node<Person>(
      id: 'root',
      keyOf: (p) => p.id,
    );
    _layoutController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(_updateLayout);
  }

  @override
  void dispose() {
    _layoutController.dispose();
    _wikiTree.dispose();
    super.dispose();
  }

  Future<void> _loadPerson(String wikiTreeId) async {
    if (_loadedPersons.contains(wikiTreeId)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch person and their relatives
      final relatives = await _wikiTree.getRelatives(wikiTreeId);

      // Get existing person or create new one
      final existingPerson = _familyTree.firstWhere(
        (p) => p.wikiTreeId == wikiTreeId,
        orElse: () => _createPerson(relatives.person, 0),
      );

      final person = existingPerson;
      final isFirstPerson = _familyTree.isEmpty;

      // Add to tree if not exists
      if (!_familyTree.containsKey(person.id)) {
        _familyTree.add(person);
        _loadedPersons.add(person.id);
      }

      // Get focal person's position (or center for first person)
      final focalPos = _positions[person.id] ?? Offset.zero;
      if (!_positions.containsKey(person.id)) {
        _positions[person.id] = focalPos;
      }

      // Position parents above
      final parents = relatives.parents;
      final parentY = focalPos.dy - _generationSpacing;
      final parentStartX =
          focalPos.dx - (parents.length - 1) * _nodeSpacing / 2;

      for (var i = 0; i < parents.length; i++) {
        final parentPerson = _createPerson(parents[i], person.generation - 1);
        if (!_familyTree.containsKey(parentPerson.id)) {
          _familyTree.add(parentPerson);
          _loadedPersons.add(parentPerson.id);
          _positions[parentPerson.id] = Offset(
            parentStartX + i * _nodeSpacing,
            parentY,
          );
        }
        _addParentLink(parentPerson.id, person.id);
      }

      // Position spouses to the right of focal person
      final spouses = relatives.spouses;
      for (var i = 0; i < spouses.length; i++) {
        final spousePerson = _createPerson(spouses[i], person.generation);
        if (!_familyTree.containsKey(spousePerson.id)) {
          _familyTree.add(spousePerson);
          _loadedPersons.add(spousePerson.id);
          _positions[spousePerson.id] = Offset(
            focalPos.dx + (i + 1) * _spouseSpacing,
            focalPos.dy,
          );
        }
        _addSpouseLink(person.id, spousePerson.id);
      }

      // Position children below (centered under parents)
      final children = relatives.children;
      final childY = focalPos.dy + _generationSpacing;
      final coupleCenter =
          spouses.isNotEmpty ? focalPos.dx + _spouseSpacing / 2 : focalPos.dx;
      final childStartX =
          coupleCenter - (children.length - 1) * _nodeSpacing / 2;

      for (var i = 0; i < children.length; i++) {
        final childPerson = _createPerson(children[i], person.generation + 1);
        if (!_familyTree.containsKey(childPerson.id)) {
          _familyTree.add(childPerson);
          _loadedPersons.add(childPerson.id);
          _positions[childPerson.id] = Offset(
            childStartX + i * _nodeSpacing,
            childY,
          );
        }
        _addParentLink(person.id, childPerson.id);
      }

      // Position siblings to the left of focal person
      final siblings = relatives.siblings;
      for (var i = 0; i < siblings.length; i++) {
        final siblingPerson = _createPerson(siblings[i], person.generation);
        if (!_familyTree.containsKey(siblingPerson.id)) {
          _familyTree.add(siblingPerson);
          _loadedPersons.add(siblingPerson.id);
          _positions[siblingPerson.id] = Offset(
            focalPos.dx - (i + 1) * _nodeSpacing,
            focalPos.dy,
          );
        }
        _addSiblingLink(person.id, siblingPerson.id);
      }

      _expandedPersons.add(person.id);

      // Center on first person loaded
      if (isFirstPerson) {
        _centerGraph();
      }

      setState(() => _isLoading = false);
    } on WikiTreeException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Person _createPerson(WikiTreePerson wtp, int generation) {
    // Check if already exists to preserve generation
    final existing = _familyTree[wtp.id];
    if (existing != null) return existing;

    return Person(
      id: wtp.id,
      wikiTreeId: wtp.wikiTreeId,
      name: wtp.fullName,
      birthYear: wtp.birthYear,
      deathYear: wtp.deathYear,
      gender: wtp.gender == WikiTreeGender.male ? Gender.male : Gender.female,
      generation: generation,
    );
  }

  void _addParentLink(String parentId, String childId) {
    final linkId = 'parent-$parentId-$childId';
    if (_linkManager.getLinkBetween(parentId, childId, type: 'parent') !=
        null) {
      return;
    }
    _linkManager.add(NodeLink(
      id: linkId,
      sourceId: parentId,
      targetId: childId,
      type: 'parent',
      direction: LinkDirection.outgoing,
    ));
  }

  void _addSpouseLink(String personA, String personB) {
    if (_linkManager.areLinked(personA, personB, type: 'spouse')) return;
    final linkId = 'spouse-$personA-$personB';
    _linkManager.add(NodeLink(
      id: linkId,
      sourceId: personA,
      targetId: personB,
      type: 'spouse',
      direction: LinkDirection.bidirectional,
    ));
  }

  void _addSiblingLink(String personA, String personB) {
    if (_linkManager.areLinked(personA, personB, type: 'sibling')) return;
    final linkId = 'sibling-$personA-$personB';
    _linkManager.add(NodeLink(
      id: linkId,
      sourceId: personA,
      targetId: personB,
      type: 'sibling',
      direction: LinkDirection.bidirectional,
    ));
  }

  void _startAutoLayout() {
    if (_isLayoutRunning) {
      _stopAutoLayout();
      return;
    }

    for (final person in _familyTree) {
      _velocities[person.id] = Offset.zero;
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

    final persons = _familyTree.toList();
    final personIds = persons.map((p) => p.id).toList();

    final forces = <String, Offset>{};
    for (final id in personIds) {
      forces[id] = Offset.zero;
    }

    // 1. Repulsion between all nodes
    for (var i = 0; i < personIds.length; i++) {
      for (var j = i + 1; j < personIds.length; j++) {
        final idA = personIds[i];
        final idB = personIds[j];
        final posA = _positions[idA] ?? Offset.zero;
        final posB = _positions[idB] ?? Offset.zero;

        final delta = posA - posB;
        final distance = delta.distance.clamp(1.0, 500.0);
        final forceMagnitude = _repulsionStrength / (distance * distance);
        final force = (delta / distance) * forceMagnitude;

        forces[idA] = forces[idA]! + force;
        forces[idB] = forces[idB]! - force;
      }
    }

    // 2. Spring forces along links
    for (final link in _linkManager.links) {
      final posA = _positions[link.sourceId];
      final posB = _positions[link.targetId];
      if (posA == null || posB == null) continue;

      final delta = posB - posA;
      final distance = delta.distance.clamp(1.0, 500.0);

      // Shorter springs for spouses
      final idealLength = link.type == 'spouse' ? 100.0 : _springLength;
      final displacement = distance - idealLength;
      final forceMagnitude = _springStrength * displacement;
      final force = (delta / distance) * forceMagnitude;

      if (forces.containsKey(link.sourceId)) {
        forces[link.sourceId] = forces[link.sourceId]! + force;
      }
      if (forces.containsKey(link.targetId)) {
        forces[link.targetId] = forces[link.targetId]! - force;
      }
    }

    // 3. Generation alignment force (strong pull toward generation row)
    for (final person in persons) {
      final pos = _positions[person.id] ?? Offset.zero;
      final targetY = person.generation * _generationSpacing;
      final yForce = (targetY - pos.dy) * 0.1; // Strong Y alignment
      forces[person.id] = forces[person.id]! + Offset(0, yForce);
    }

    // 4. Spouse alignment (keep spouses at same Y level)
    for (final link in _linkManager.links) {
      if (link.type != 'spouse') continue;
      final posA = _positions[link.sourceId];
      final posB = _positions[link.targetId];
      if (posA == null || posB == null) continue;

      final yDiff = posB.dy - posA.dy;
      final alignForce = yDiff * 0.05;
      if (forces.containsKey(link.sourceId)) {
        forces[link.sourceId] = forces[link.sourceId]! + Offset(0, alignForce);
      }
      if (forces.containsKey(link.targetId)) {
        forces[link.targetId] = forces[link.targetId]! - Offset(0, alignForce);
      }
    }

    // 6. Update velocities and positions
    var totalVelocity = 0.0;

    for (final id in personIds) {
      var velocity = _velocities[id] ?? Offset.zero;
      velocity = (velocity + forces[id]!) * _damping;
      _velocities[id] = velocity;

      final currentPos = _positions[id] ?? Offset.zero;
      _positions[id] = currentPos + velocity;

      totalVelocity += velocity.distance;
    }

    // 7. Check if settled
    if (totalVelocity / personIds.length < _minVelocity) {
      _stopAutoLayout();
    }

    setState(() {});
  }

  void _centerGraph() {
    if (_positions.isEmpty) return;

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

    final graphCenter = Offset((minX + maxX) / 2, (minY + maxY) / 2);

    setState(() {
      for (final entry in _positions.entries) {
        _positions[entry.key] = entry.value - graphCenter;
      }
      _canvasOffset = Offset.zero;
    });
  }

  void _clearGraph() {
    _stopAutoLayout();
    setState(() {
      _familyTree.clear();
      _linkManager.clear();
      _positions.clear();
      _loadedPersons.clear();
      _expandedPersons.clear();
      _velocities.clear();
      _selectedPersonId = null;
      _canvasOffset = Offset.zero;
      _canvasScale = 1.0;
    });
  }

  void _onCanvasPan(Offset delta) {
    setState(() => _canvasOffset += delta);
  }

  void _onCanvasScale(double scale, Offset focalPoint) {
    setState(() {
      final newScale = (_canvasScale * scale).clamp(0.2, 4.0);
      if (newScale != _canvasScale) {
        final focalInCanvas = (focalPoint - _canvasOffset) / _canvasScale;
        _canvasScale = newScale;
        _canvasOffset = focalPoint - focalInCanvas * _canvasScale;
      }
    });
  }

  void _onNodeDrag(String personId, Offset delta) {
    setState(() {
      final current = _positions[personId] ?? Offset.zero;
      _positions[personId] = current + delta / _canvasScale;
    });
  }

  void _onNodeTap(Person person) {
    setState(() {
      _selectedPersonId = _selectedPersonId == person.id ? null : person.id;
    });
  }

  void _onNodeDoubleTap(Person person) {
    if (!_expandedPersons.contains(person.id)) {
      _loadPerson(person.wikiTreeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Genealogy Graph', style: TextStyle(fontSize: 16)),
            Text(
              '${_familyTree.length} people, ${_linkManager.length} relationships',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: Icon(_patrilinealMode ? Icons.male : Icons.people),
            onPressed: () =>
                setState(() => _patrilinealMode = !_patrilinealMode),
            tooltip: _patrilinealMode ? 'Patrilineal (males only)' : 'Show all',
          ),
          IconButton(
            icon: Icon(_isLayoutRunning ? Icons.stop : Icons.auto_fix_high),
            onPressed: _familyTree.isNotEmpty ? _startAutoLayout : null,
            tooltip: _isLayoutRunning ? 'Stop Layout' : 'Auto Layout',
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _familyTree.isNotEmpty ? _centerGraph : null,
            tooltip: 'Center Graph',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _familyTree.isNotEmpty ? _clearGraph : null,
            tooltip: 'Clear',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStarterPanel(),
          if (_errorMessage != null) _buildErrorBanner(),
          Expanded(child: _buildCanvas()),
          if (_selectedPersonId != null) _buildInfoPanel(),
        ],
      ),
    );
  }

  Widget _buildStarterPanel() {
    if (_familyTree.isNotEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start with a famous person:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _famousPeople.map((entry) {
              final (id, name) = entry;
              return ActionChip(
                label: Text(name),
                onPressed: _isLoading ? null : () => _loadPerson(id),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Note: WikiTree API requires native platform (macOS/iOS/Android). '
            'Web has CORS restrictions.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return MaterialBanner(
      content: Text(_errorMessage!),
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      actions: [
        TextButton(
          onPressed: () => setState(() => _errorMessage = null),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }

  Widget _buildCanvas() {
    // Filter to only males if in patrilineal mode
    final visiblePersons = _patrilinealMode
        ? _familyTree.where((p) => p.gender == Gender.male)
        : _familyTree;

    // Filter positions to only visible persons
    final visiblePositions = Map.fromEntries(
      _positions.entries.where((e) {
        final person = _familyTree[e.key];
        return person != null &&
            (!_patrilinealMode || person.gender == Gender.male);
      }),
    );

    // Filter links - in patrilineal mode, only show parent links between males
    final visibleLinks = _patrilinealMode
        ? _linkManager.links.where((link) {
            if (link.type == 'spouse') return false; // Hide spouse links
            final source = _familyTree[link.sourceId];
            final target = _familyTree[link.targetId];
            return source?.gender == Gender.male &&
                target?.gender == Gender.male;
          })
        : _linkManager.links;

    return _GenealogyCanvas(
      positions: visiblePositions,
      links: visibleLinks,
      familyTree: visiblePersons,
      selectedPersonId: _selectedPersonId,
      expandedPersonIds: _expandedPersons,
      canvasOffset: _canvasOffset,
      canvasScale: _canvasScale,
      patrilinealMode: _patrilinealMode,
      onPanUpdate: _onCanvasPan,
      onScaleUpdate: _onCanvasScale,
      onNodeTap: _onNodeTap,
      onNodeDoubleTap: _onNodeDoubleTap,
      onNodeDrag: _onNodeDrag,
    );
  }

  Widget _buildInfoPanel() {
    final person = _familyTree[_selectedPersonId!];
    if (person == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    // Get spouse persons (full objects for more info)
    final spousePersons = _linkManager
        .getLinkedNodeIds(_selectedPersonId!, type: 'spouse')
        .map((id) => _familyTree[id])
        .whereType<Person>()
        .toList();

    final parents = _linkManager
        .getIncomingLinks(_selectedPersonId!, type: 'parent')
        .map((l) => _familyTree[l.sourceId]?.name ?? l.sourceId)
        .toList();

    // In patrilineal mode, only show male children
    final childLinks = _linkManager.getOutgoingLinks(
      _selectedPersonId!,
      type: 'parent',
    );
    final children = childLinks
        .map((l) => _familyTree[l.targetId])
        .whereType<Person>()
        .where((p) => !_patrilinealMode || p.gender == Gender.male)
        .map((p) => p.name)
        .toList();

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
              Icon(
                person.gender == Gender.male ? Icons.male : Icons.female,
                color: person.gender == Gender.male
                    ? Colors.blue
                    : Colors.pink.shade300,
              ),
              const SizedBox(width: 8),
              Text(
                person.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              if (person.birthYear != null || person.deathYear != null)
                Text(
                  '(${person.birthYear ?? '?'} - ${person.deathYear ?? '?'})',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              const Spacer(),
              if (!_expandedPersons.contains(person.id))
                FilledButton.tonalIcon(
                  onPressed: () => _loadPerson(person.wikiTreeId),
                  icon: const Icon(Icons.expand, size: 18),
                  label: const Text('Load Family'),
                ),
            ],
          ),
          // In patrilineal mode, show spouse info prominently
          if (_patrilinealMode && spousePersons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.pink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.pink.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.female,
                        size: 16,
                        color: Colors.pink.shade300,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Spouse${spousePersons.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.pink.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...spousePersons.map((spouse) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${spouse.name} ${spouse.lifespan.isNotEmpty ? "(${spouse.lifespan})" : ""}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              if (parents.isNotEmpty)
                Text(
                  'Parents: ${parents.join(', ')}',
                  style: const TextStyle(fontSize: 12),
                ),
              if (!_patrilinealMode && spousePersons.isNotEmpty)
                Text(
                  'Spouse: ${spousePersons.map((s) => s.name).join(', ')}',
                  style: const TextStyle(fontSize: 12),
                ),
              if (children.isNotEmpty)
                Text(
                  'Children: ${children.join(', ')}',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A person in the family tree.
class Person {
  const Person({
    required this.id,
    required this.wikiTreeId,
    required this.name,
    required this.gender,
    required this.generation,
    this.birthYear,
    this.deathYear,
  });

  final String id;
  final String wikiTreeId;
  final String name;
  final Gender gender;
  final int generation;
  final int? birthYear;
  final int? deathYear;

  String get lifespan {
    if (birthYear == null && deathYear == null) return '';
    return '${birthYear ?? '?'}-${deathYear ?? '?'}';
  }
}

enum Gender { male, female }

/// Canvas widget for rendering the genealogy graph.
class _GenealogyCanvas extends StatefulWidget {
  const _GenealogyCanvas({
    required this.positions,
    required this.links,
    required this.familyTree,
    required this.selectedPersonId,
    required this.expandedPersonIds,
    required this.canvasOffset,
    required this.canvasScale,
    required this.patrilinealMode,
    required this.onPanUpdate,
    required this.onScaleUpdate,
    required this.onNodeTap,
    required this.onNodeDoubleTap,
    required this.onNodeDrag,
  });

  final Map<String, Offset> positions;
  final Iterable<NodeLink> links;
  final Iterable<Person> familyTree;
  final String? selectedPersonId;
  final Set<String> expandedPersonIds;
  final Offset canvasOffset;
  final double canvasScale;
  final bool patrilinealMode;
  final void Function(Offset delta) onPanUpdate;
  final void Function(double scale, Offset focalPoint) onScaleUpdate;
  final void Function(Person person) onNodeTap;
  final void Function(Person person) onNodeDoubleTap;
  final void Function(String personId, Offset delta) onNodeDrag;

  @override
  State<_GenealogyCanvas> createState() => _GenealogyCanvasState();
}

class _GenealogyCanvasState extends State<_GenealogyCanvas> {
  bool _isDraggingNode = false;
  double _lastScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (_) => _lastScale = 1.0,
      onScaleUpdate: (details) {
        if (_isDraggingNode) return;
        if (details.pointerCount == 1) {
          widget.onPanUpdate(details.focalPointDelta);
        } else {
          final scaleDelta = details.scale / _lastScale;
          _lastScale = details.scale;
          widget.onScaleUpdate(scaleDelta, details.localFocalPoint);
        }
      },
      child: ClipRect(
        child: CustomPaint(
          painter: _GridPainter(
            offset: widget.canvasOffset,
            scale: widget.canvasScale,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Links layer
              Positioned.fill(
                child: CustomPaint(
                  painter: _GenealogyLinkPainter(
                    links: widget.links,
                    positions: widget.positions,
                    offset: widget.canvasOffset,
                    scale: widget.canvasScale,
                    selectedPersonId: widget.selectedPersonId,
                    patrilinealMode: widget.patrilinealMode,
                  ),
                ),
              ),
              // Nodes layer
              ...widget.familyTree.map(_buildPersonNode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonNode(Person person) {
    final pos = widget.positions[person.id] ?? Offset.zero;
    final screenPos = pos * widget.canvasScale + widget.canvasOffset;
    final isSelected = widget.selectedPersonId == person.id;
    final isExpanded = widget.expandedPersonIds.contains(person.id);

    return Positioned(
      left: screenPos.dx - 40 * widget.canvasScale,
      top: screenPos.dy - 30 * widget.canvasScale,
      child: GestureDetector(
        onTap: () => widget.onNodeTap(person),
        onDoubleTap: () => widget.onNodeDoubleTap(person),
        onPanStart: (_) => _isDraggingNode = true,
        onPanUpdate: (d) => widget.onNodeDrag(person.id, d.delta),
        onPanEnd: (_) => _isDraggingNode = false,
        onPanCancel: () => _isDraggingNode = false,
        child: Transform.scale(
          scale: widget.canvasScale,
          child: _PersonNodeWidget(
            person: person,
            isSelected: isSelected,
            isExpanded: isExpanded,
          ),
        ),
      ),
    );
  }
}

/// Widget for rendering a person node.
class _PersonNodeWidget extends StatelessWidget {
  const _PersonNodeWidget({
    required this.person,
    required this.isSelected,
    required this.isExpanded,
  });

  final Person person;
  final bool isSelected;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMale = person.gender == Gender.male;

    final bgColor = isMale
        ? Colors.blue.withValues(alpha: 0.15)
        : Colors.pink.withValues(alpha: 0.15);
    final borderColor = isSelected
        ? colorScheme.primary
        : (isMale ? Colors.blue.shade300 : Colors.pink.shade300);

    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: isSelected ? 2.5 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gender icon
          Icon(
            isMale ? Icons.male : Icons.female,
            size: 16,
            color: isMale ? Colors.blue : Colors.pink.shade300,
          ),
          const SizedBox(height: 2),
          // Name
          Text(
            person.name.split(' ').first, // First name only
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Lifespan
          if (person.lifespan.isNotEmpty)
            Text(
              person.lifespan,
              style: TextStyle(
                fontSize: 8,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          // Expand indicator
          if (!isExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.add_circle_outline,
                size: 12,
                color: colorScheme.outline,
              ),
            ),
        ],
      ),
    );
  }
}

/// Paints the grid background.
class _GridPainter extends CustomPainter {
  _GridPainter({required this.offset, required this.scale});

  final Offset offset;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    const gridSize = 50.0;
    final scaledGrid = gridSize * scale;

    final startX = offset.dx % scaledGrid;
    final startY = offset.dy % scaledGrid;

    for (var x = startX; x < size.width; x += scaledGrid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = startY; y < size.height; y += scaledGrid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.offset != offset || old.scale != scale;
}

/// Paints the relationship links between people.
class _GenealogyLinkPainter extends CustomPainter {
  _GenealogyLinkPainter({
    required this.links,
    required this.positions,
    required this.offset,
    required this.scale,
    this.selectedPersonId,
    this.patrilinealMode = false,
  });

  final Iterable<NodeLink> links;
  final Map<String, Offset> positions;
  final Offset offset;
  final double scale;
  final String? selectedPersonId;
  final double cornerRadius = 8.0;
  final bool patrilinealMode;

  Offset _transform(Offset pos) => pos * scale + offset;

  @override
  void paint(Canvas canvas, Size size) {
    // Group links by type for layered drawing
    final parentLinks = <NodeLink>[];
    final spouseLinks = <NodeLink>[];
    final siblingLinks = <NodeLink>[];

    for (final link in links) {
      switch (link.type) {
        case 'parent':
          parentLinks.add(link);
        case 'spouse':
          spouseLinks.add(link);
        case 'sibling':
          siblingLinks.add(link);
      }
    }

    // In patrilineal mode, skip spouse and sibling links
    final marriageBars = <String, _MarriageBar>{};

    if (!patrilinealMode) {
      // Draw spouse links first (marriage bars)
      for (final link in spouseLinks) {
        final startPos = positions[link.sourceId];
        final endPos = positions[link.targetId];
        if (startPos == null || endPos == null) continue;

        final start = _transform(startPos);
        final end = _transform(endPos);
        final barY = (start.dy + end.dy) / 2;

        final involvesSelected = selectedPersonId != null &&
            (link.sourceId == selectedPersonId ||
                link.targetId == selectedPersonId);

        final paint = Paint()
          ..color = involvesSelected
              ? Colors.red.shade400
              : Colors.red.withValues(alpha: 0.6)
          ..strokeWidth = (involvesSelected ? 3.0 : 2.0) * scale
          ..style = PaintingStyle.stroke;

        // Draw the marriage bar
        canvas.drawLine(start, end, paint);

        // Store bar info for child connections
        final barKey = _makeBarKey(link.sourceId, link.targetId);
        final barCenter = Offset((start.dx + end.dx) / 2, barY);
        marriageBars[barKey] = _MarriageBar(
          leftId: start.dx < end.dx ? link.sourceId : link.targetId,
          rightId: start.dx < end.dx ? link.targetId : link.sourceId,
          center: barCenter,
          y: barY,
        );
      }
    }

    // Draw parent-child links
    for (final link in parentLinks) {
      final parentPos = positions[link.sourceId];
      final childPos = positions[link.targetId];
      if (parentPos == null || childPos == null) continue;

      final parent = _transform(parentPos);
      final child = _transform(childPos);

      final involvesSelected = selectedPersonId != null &&
          (link.sourceId == selectedPersonId ||
              link.targetId == selectedPersonId);

      final paint = Paint()
        ..color = involvesSelected
            ? Colors.green.shade600
            : Colors.green.withValues(alpha: 0.6)
        ..strokeWidth = (involvesSelected ? 2.5 : 1.5) * scale
        ..style = PaintingStyle.stroke;

      if (patrilinealMode) {
        // Direct connection in patrilineal mode
        _drawOrthogonalPath(canvas, parent, child, paint);
      } else {
        // Check if parent has a spouse (marriage bar)
        _MarriageBar? bar;
        for (final entry in marriageBars.entries) {
          if (entry.key.contains(link.sourceId)) {
            bar = entry.value;
            break;
          }
        }

        if (bar != null) {
          // Connect from marriage bar center down to child
          _drawOrthogonalPath(
            canvas,
            Offset(bar.center.dx, bar.y),
            child,
            paint,
            dropFromBar: true,
          );
        } else {
          // Single parent - connect directly
          _drawOrthogonalPath(canvas, parent, child, paint);
        }
      }
    }

    // Draw sibling links (curved arc above) - skip in patrilineal mode
    if (!patrilinealMode) {
      for (final link in siblingLinks) {
        final startPos = positions[link.sourceId];
        final endPos = positions[link.targetId];
        if (startPos == null || endPos == null) continue;

        final start = _transform(startPos);
        final end = _transform(endPos);

        final involvesSelected = selectedPersonId != null &&
            (link.sourceId == selectedPersonId ||
                link.targetId == selectedPersonId);

        final paint = Paint()
          ..color = involvesSelected
              ? Colors.orange.shade400
              : Colors.orange.withValues(alpha: 0.4)
          ..strokeWidth = scale
          ..style = PaintingStyle.stroke;

        _drawSiblingArc(canvas, start, end, paint);
      }
    }
  }

  String _makeBarKey(String id1, String id2) {
    return id1.compareTo(id2) < 0 ? '$id1-$id2' : '$id2-$id1';
  }

  void _drawOrthogonalPath(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    bool dropFromBar = false,
  }) {
    final r = cornerRadius * scale;
    final midY = (start.dy + end.dy) / 2;

    final dx = (end.dx - start.dx).abs();

    // If nearly vertical, just draw a straight line
    if (dx < r * 2) {
      canvas.drawLine(start, end, paint);
      return;
    }

    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Going down from start to midY, then horizontal to end.dx, then down to end
    // Corner 1: at (start.dx, midY) - turning from vertical to horizontal
    // Corner 2: at (end.dx, midY) - turning from horizontal to vertical

    final goingRight = end.dx > start.dx;

    // Vertical down to first corner
    path.lineTo(start.dx, midY - r);

    // First corner: vertical to horizontal
    // Use quadratic bezier for smooth corner
    path.quadraticBezierTo(
      start.dx, // control point x
      midY, // control point y (the actual corner)
      start.dx + (goingRight ? r : -r), // end x
      midY, // end y
    );

    // Horizontal segment
    path.lineTo(end.dx + (goingRight ? -r : r), midY);

    // Second corner: horizontal to vertical
    path.quadraticBezierTo(
      end.dx, // control point x (the actual corner)
      midY, // control point y
      end.dx, // end x
      midY + r, // end y
    );

    // Vertical down to end
    path.lineTo(end.dx, end.dy);

    canvas.drawPath(path, paint);
  }

  void _drawSiblingArc(Canvas canvas, Offset start, Offset end, Paint paint) {
    // Draw an arc above the siblings
    final midX = (start.dx + end.dx) / 2;
    final arcHeight = 20.0 * scale;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(
        midX,
        start.dy - arcHeight,
        end.dx,
        end.dy,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GenealogyLinkPainter old) =>
      old.links != links ||
      old.positions != positions ||
      old.offset != offset ||
      old.scale != scale ||
      old.selectedPersonId != selectedPersonId ||
      old.patrilinealMode != patrilinealMode;
}

/// Represents a marriage bar between two spouses.
class _MarriageBar {
  const _MarriageBar({
    required this.leftId,
    required this.rightId,
    required this.center,
    required this.y,
  });

  final String leftId;
  final String rightId;
  final Offset center;
  final double y;
}
