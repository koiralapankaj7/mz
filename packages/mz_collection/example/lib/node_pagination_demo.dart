import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mz_collection/mz_collection.dart';

import 'wikitree_service.dart';

/// Demonstrates node-based pagination with a realistic family tree example.
/// Supports both mock data and real WikiTree API data.
class NodePaginationDemo extends StatefulWidget {
  const NodePaginationDemo({super.key});

  @override
  State<NodePaginationDemo> createState() => _NodePaginationDemoState();
}

class _NodePaginationDemoState extends State<NodePaginationDemo> {
  late final PaginationState _paginationState;
  final ScrollController _scrollController = ScrollController();
  final WikiTreeService _wikiTreeService = WikiTreeService();

  // Loaded family members by parent ID
  final Map<String, List<FamilyMember>> _loadedChildren = {};

  // All members by ID for quick lookup
  final Map<String, FamilyMember> _memberMap = {};

  // Root members (starting point of the tree)
  final List<FamilyMember> _rootMembers = [];

  // Expanded nodes
  final Set<String> _expandedNodes = {};

  // Settings
  bool _autoLoadEnabled = true;
  bool _useWikiTree = false;
  bool _isLoading = false;
  String? _errorMessage;

  static const _scrollThreshold = 200.0;

  // For generating mock data
  final _random = Random(42);

  // Famous people for WikiTree demo
  static const _famousPeople = [
    ('Einstein-1', 'Albert Einstein'),
    ('Churchill-4', 'Winston Churchill'),
    ('Darwin-1', 'Charles Darwin'),
    ('Curie-1', 'Marie Curie'),
    ('Washington-1', 'George Washington'),
    ('Lincoln-1', 'Abraham Lincoln'),
  ];

  @override
  void initState() {
    super.initState();
    _paginationState = PaginationState();
    _paginationState.addChangeListener(_onPaginationChanged);
    _scrollController.addListener(_onScroll);
    _initializeMockData();
  }

  void _initializeMockData() {
    _rootMembers.clear();
    _memberMap.clear();
    _loadedChildren.clear();
    _expandedNodes.clear();
    _paginationState.resetAll();

    final root = FamilyMember(
      id: 'self',
      firstName: 'You',
      lastName: 'Anderson',
      birthYear: 1990,
      gender: Gender.male,
      relationship: 'Self',
      hasAncestors: true,
      hasDescendants: true,
    );

    _rootMembers.add(root);
    _memberMap[root.id] = root;
    _paginationState.setHint(root.id, hasMore: true);
  }

  Future<void> _loadFromWikiTree(String wikiTreeId, String name) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _useWikiTree = true;
    });

    try {
      final person = await _wikiTreeService.getPerson(wikiTreeId);

      _rootMembers.clear();
      _memberMap.clear();
      _loadedChildren.clear();
      _expandedNodes.clear();
      _paginationState.resetAll();

      final root = FamilyMember.fromWikiTree(person, 'Self', 0);
      _rootMembers.add(root);
      _memberMap[root.id] = root;

      if (person.hasParents) {
        _paginationState.setHint(root.id, hasMore: true);
      }

      setState(() => _isLoading = false);
    } on WikiTreeException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
        _useWikiTree = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: $e';
        _isLoading = false;
        _useWikiTree = false;
      });
    }
  }

  void _onPaginationChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_autoLoadEnabled) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;

    if (position.pixels >= position.maxScrollExtent - _scrollThreshold) {
      _autoLoadExpandedNodes();
    }
  }

  void _autoLoadExpandedNodes() {
    for (final nodeId in _expandedNodes) {
      if (_paginationState.canLoad(nodeId) &&
          _paginationState.isRegistered(nodeId) &&
          !_paginationState.isLoading(nodeId)) {
        final member = _memberMap[nodeId];
        if (member != null) {
          _loadFamilyMembers(member);
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _paginationState.removeChangeListener(_onPaginationChanged);
    _wikiTreeService.dispose();
    super.dispose();
  }

  Future<void> _toggleMember(FamilyMember member) async {
    if (_expandedNodes.contains(member.id)) {
      setState(() => _expandedNodes.remove(member.id));
    } else {
      setState(() => _expandedNodes.add(member.id));

      if (!_paginationState.isRegistered(member.id)) {
        await _loadFamilyMembers(member);
      }
    }
  }

  Future<void> _loadFamilyMembers(FamilyMember member) async {
    if (!_paginationState.canLoad(member.id)) return;
    if (!_paginationState.startLoading(member.id)) return;

    try {
      List<FamilyMember> relatives;

      if (_useWikiTree && member.wikiTreeId != null) {
        relatives = await _loadWikiTreeRelatives(member);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        relatives = _generateMockRelatives(member);
      }

      if (!mounted) return;

      final currentChildren = _loadedChildren[member.id] ?? [];

      setState(() {
        _loadedChildren[member.id] = [...currentChildren, ...relatives];
      });

      for (final relative in relatives) {
        _memberMap[relative.id] = relative;
        if (relative.hasAncestors || relative.hasDescendants) {
          _paginationState.setHint(relative.id, hasMore: true);
        }
      }

      // For WikiTree, we only load one page (all relatives at once)
      // For mock data, simulate pagination
      final hasMore = !_useWikiTree && currentChildren.isEmpty;

      _paginationState.complete(
        member.id,
        nextToken: hasMore ? PageToken.offset(1) : PageToken.end,
      );
    } catch (e) {
      _paginationState.fail(member.id, e);
    }
  }

  Future<List<FamilyMember>> _loadWikiTreeRelatives(FamilyMember member) async {
    if (member.wikiTreeId == null) return [];

    final relatives = await _wikiTreeService.getRelatives(member.wikiTreeId!);

    final members = <FamilyMember>[];
    final childGen = member.generation + 1;
    final parentGen = member.generation - 1;

    // Add parents
    for (final parent in relatives.parents) {
      final isFather = parent.gender == WikiTreeGender.male;
      members.add(FamilyMember.fromWikiTree(
        parent,
        isFather ? 'Father' : 'Mother',
        parentGen,
      ));
    }

    // Add spouses
    for (final spouse in relatives.spouses) {
      members
          .add(FamilyMember.fromWikiTree(spouse, 'Spouse', member.generation));
    }

    // Add children
    for (final child in relatives.children) {
      final isSon = child.gender == WikiTreeGender.male;
      members.add(FamilyMember.fromWikiTree(
        child,
        isSon ? 'Son' : 'Daughter',
        childGen,
      ));
    }

    // Add siblings
    for (final sibling in relatives.siblings) {
      members.add(
          FamilyMember.fromWikiTree(sibling, 'Sibling', member.generation));
    }

    return members;
  }

  List<FamilyMember> _generateMockRelatives(FamilyMember member) {
    final currentChildren = _loadedChildren[member.id]?.length ?? 0;
    if (currentChildren > 0) {
      // Second page: extended family
      return _generateExtendedFamily(member);
    }

    // First page: immediate family
    final members = <FamilyMember>[];

    if (member.hasAncestors && member.generation >= 0) {
      members.addAll(_generateParents(member));
    }
    if (member.hasDescendants) {
      members.addAll(_generateSpouseAndChildren(member));
    }

    return members;
  }

  List<FamilyMember> _generateParents(FamilyMember child) {
    final parentGen = child.generation - 1;
    final baseYear = 1990 - (child.generation * 25);

    return [
      FamilyMember(
        id: '${child.id}-father',
        firstName: _randomFirstName(Gender.male),
        lastName: child.lastName,
        birthYear: baseYear - 25 + _random.nextInt(10),
        gender: Gender.male,
        relationship: 'Father',
        generation: parentGen,
        hasAncestors: parentGen > -3,
        hasDescendants: false,
      ),
      FamilyMember(
        id: '${child.id}-mother',
        firstName: _randomFirstName(Gender.female),
        lastName: _randomLastName(),
        maidenName: _randomLastName(),
        birthYear: baseYear - 23 + _random.nextInt(10),
        gender: Gender.female,
        relationship: 'Mother',
        generation: parentGen,
        hasAncestors: parentGen > -3,
        hasDescendants: false,
      ),
    ];
  }

  List<FamilyMember> _generateSpouseAndChildren(FamilyMember parent) {
    final childGen = parent.generation + 1;
    final members = <FamilyMember>[];

    final spouseGender =
        parent.gender == Gender.male ? Gender.female : Gender.male;
    members.add(
      FamilyMember(
        id: '${parent.id}-spouse',
        firstName: _randomFirstName(spouseGender),
        lastName:
            parent.gender == Gender.male ? parent.lastName : _randomLastName(),
        birthYear: parent.birthYear! + _random.nextInt(6) - 3,
        gender: spouseGender,
        relationship: 'Spouse',
        generation: parent.generation,
        hasAncestors: false,
        hasDescendants: false,
      ),
    );

    final numChildren = 1 + _random.nextInt(3);
    for (var i = 0; i < numChildren; i++) {
      final gender = _random.nextBool() ? Gender.male : Gender.female;
      members.add(
        FamilyMember(
          id: '${parent.id}-child-$i',
          firstName: _randomFirstName(gender),
          lastName: parent.lastName,
          birthYear: parent.birthYear! + 25 + i * 2 + _random.nextInt(3),
          gender: gender,
          relationship: gender == Gender.male ? 'Son' : 'Daughter',
          generation: childGen,
          hasAncestors: false,
          hasDescendants: childGen < 2,
        ),
      );
    }

    return members;
  }

  List<FamilyMember> _generateExtendedFamily(FamilyMember member) {
    final members = <FamilyMember>[];
    final baseYear = member.birthYear ?? 1990;

    final numRelatives = 1 + _random.nextInt(3);
    for (var i = 0; i < numRelatives; i++) {
      final gender = _random.nextBool() ? Gender.male : Gender.female;
      final relationship = _random.nextBool()
          ? 'Sibling'
          : (_random.nextBool() ? 'Cousin' : 'Uncle/Aunt');

      members.add(
        FamilyMember(
          id: '${member.id}-ext-$i-${DateTime.now().microsecondsSinceEpoch}',
          firstName: _randomFirstName(gender),
          lastName: member.lastName,
          birthYear: baseYear + _random.nextInt(15) - 5,
          gender: gender,
          relationship: relationship,
          generation: member.generation,
          hasAncestors: false,
          hasDescendants: _random.nextBool() && member.generation < 2,
        ),
      );
    }

    return members;
  }

  String _randomFirstName(Gender gender) {
    const maleNames = [
      'James',
      'William',
      'Robert',
      'Michael',
      'David',
      'Richard',
      'Joseph',
      'Thomas',
      'Charles',
      'Daniel',
      'Matthew',
      'Anthony',
      'Mark',
      'Steven',
    ];
    const femaleNames = [
      'Mary',
      'Patricia',
      'Jennifer',
      'Linda',
      'Barbara',
      'Elizabeth',
      'Susan',
      'Jessica',
      'Sarah',
      'Karen',
      'Lisa',
      'Nancy',
      'Betty',
      'Margaret',
    ];
    final names = gender == Gender.male ? maleNames : femaleNames;
    return names[_random.nextInt(names.length)];
  }

  String _randomLastName() {
    const lastNames = [
      'Smith',
      'Johnson',
      'Williams',
      'Brown',
      'Jones',
      'Garcia',
      'Miller',
      'Davis',
      'Rodriguez',
      'Martinez',
      'Wilson',
      'Taylor',
      'Thomas',
      'Moore',
    ];
    return lastNames[_random.nextInt(lastNames.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_useWikiTree ? 'WikiTree Family' : 'Family Tree'),
        actions: [
          IconButton(
            icon: const Icon(Icons.unfold_less),
            onPressed: _collapseAll,
            tooltip: 'Collapse All',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Reset',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.cloud_download),
            tooltip: 'Load from WikiTree',
            onSelected: (value) {
              final person = _famousPeople.firstWhere((p) => p.$1 == value);
              _loadFromWikiTree(person.$1, person.$2);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                enabled: false,
                child: Text(
                  'Load Famous Person',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const PopupMenuDivider(),
              ..._famousPeople.map(
                (p) => PopupMenuItem(value: p.$1, child: Text(p.$2)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildInfoBar(),
          if (_errorMessage != null) _buildErrorBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    children: _buildMemberList(_rootMembers, isRoot: true),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar() {
    final loadedCount = _memberMap.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _useWikiTree ? Icons.cloud : Icons.people,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '$loadedCount members',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_useWikiTree) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('WikiTree', style: TextStyle(fontSize: 11)),
            ),
          ],
          const Spacer(),
          const Text('Auto-load', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          SizedBox(
            height: 24,
            child: Switch(
              value: _autoLoadEnabled,
              onChanged: (v) => setState(() => _autoLoadEnabled = v),
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

  List<Widget> _buildMemberList(
    List<FamilyMember> members, {
    bool isRoot = false,
    Set<String>? visited,
  }) {
    visited ??= <String>{};
    final widgets = <Widget>[];

    for (final member in members) {
      // Prevent infinite recursion from circular references
      if (visited.contains(member.id)) continue;
      visited.add(member.id);

      widgets.add(_buildMemberCard(member, isRoot: isRoot));

      if (_expandedNodes.contains(member.id)) {
        final children = _loadedChildren[member.id] ?? [];
        widgets.addAll(_buildMemberList(children, visited: visited));

        final isLoading = _paginationState.isLoading(member.id);
        final canLoadMore = _paginationState.canLoad(member.id) &&
            _paginationState.isRegistered(member.id);

        if (isLoading) {
          widgets.add(_buildLoadingIndicator(member));
        } else if (canLoadMore && !_autoLoadEnabled) {
          widgets.add(_buildLoadMoreTile(member));
        }
      }
    }

    return widgets;
  }

  Widget _buildMemberCard(FamilyMember member, {bool isRoot = false}) {
    final isExpanded = _expandedNodes.contains(member.id);
    final isLoading = _paginationState.isLoading(member.id);
    final canExpand = member.hasAncestors ||
        member.hasDescendants ||
        _paginationState.hasHint(member.id);

    final indent = isRoot ? 0.0 : (member.generation.abs() + 1) * 16.0;

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: isRoot ? 2 : 1,
        color: isExpanded
            ? Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.5)
            : null,
        child: InkWell(
          onTap: canExpand ? () => _toggleMember(member) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildAvatar(member),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              member.fullName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (member.maidenName != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(née ${member.maidenName})',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _buildRelationshipChip(member.relationship),
                          const SizedBox(width: 8),
                          if (member.birthYear != null)
                            Text(
                              'b. ${member.birthYear}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (member.deathYear != null)
                            Text(
                              ' - d. ${member.deathYear}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (canExpand)
                  isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Theme.of(context).colorScheme.primary,
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(FamilyMember member) {
    final color = member.gender == Gender.male
        ? Colors.blue.shade300
        : Colors.pink.shade300;

    return CircleAvatar(
      radius: 24,
      backgroundColor: color.withValues(alpha: 0.3),
      child: Text(
        member.initials,
        style: TextStyle(
          color: color.withValues(alpha: 0.8),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildRelationshipChip(String relationship) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        relationship,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(FamilyMember member) {
    final indent = (member.generation.abs() + 2) * 16.0;

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading family members...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreTile(FamilyMember member) {
    final indent = (member.generation.abs() + 2) * 16.0;

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: InkWell(
          onTap: () => _loadFamilyMembers(member),
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, size: 20),
                SizedBox(width: 8),
                Text('Load more relatives'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _collapseAll() {
    setState(() => _expandedNodes.clear());
  }

  void _reset() {
    setState(() {
      _useWikiTree = false;
      _errorMessage = null;
    });
    _initializeMockData();
    _scrollController.jumpTo(0);
    setState(() {});
  }
}

// =============================================================================
// Models
// =============================================================================

enum Gender { male, female }

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.relationship,
    this.wikiTreeId,
    this.maidenName,
    this.birthYear,
    this.deathYear,
    this.generation = 0,
    this.hasAncestors = false,
    this.hasDescendants = false,
  });

  factory FamilyMember.fromWikiTree(
    WikiTreePerson person,
    String relationship,
    int generation,
  ) {
    return FamilyMember(
      id: person.id,
      wikiTreeId: person.wikiTreeId,
      firstName: person.firstName.isEmpty ? 'Unknown' : person.firstName,
      lastName: person.lastName.isEmpty ? 'Unknown' : person.lastName,
      maidenName: person.lastNameAtBirth != person.lastName
          ? person.lastNameAtBirth
          : null,
      birthYear: person.birthYear,
      deathYear: person.deathYear,
      gender:
          person.gender == WikiTreeGender.male ? Gender.male : Gender.female,
      relationship: relationship,
      generation: generation,
      hasAncestors: person.hasParents,
      hasDescendants: false, // We'll discover this when we load children
    );
  }

  final String id;
  final String? wikiTreeId;
  final String firstName;
  final String lastName;
  final String? maidenName;
  final int? birthYear;
  final int? deathYear;
  final Gender gender;
  final String relationship;
  final int generation;
  final bool hasAncestors;
  final bool hasDescendants;

  String get fullName => '$firstName $lastName';
  String get initials {
    final first = firstName.isNotEmpty ? firstName[0] : '?';
    final last = lastName.isNotEmpty ? lastName[0] : '?';
    return '$first$last';
  }
}
