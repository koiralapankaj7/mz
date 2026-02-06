// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

import 'package:flutter/material.dart';
import 'package:mz_collection/mz_collection.dart';

// =============================================================================
// Data Model
// =============================================================================

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.status,
    required this.assignee,
    required this.project,
    required this.dueDate,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String category;
  final int priority;
  final String status;
  final String assignee;
  final String project;
  final DateTime dueDate;
  final List<String> tags;

  String get priorityLabel => ['', 'High', 'Medium', 'Low'][priority];
  Color get priorityColor =>
      [Colors.grey, Colors.red, Colors.orange, Colors.green][priority];

  /// Whether this task appears in multiple groups (has multiple tags).
  bool get isMultiGroup => tags.length > 1;

  @override
  String toString() => 'Task($id)';
}

// =============================================================================
// Sample Data
// =============================================================================

List<Task> generateTasks(int count) {
  final categories = ['Work', 'Personal', 'Shopping', 'Health', 'Finance'];
  final statuses = ['todo', 'in_progress', 'done'];
  final assignees = ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve'];
  final projects = ['Alpha', 'Beta', 'Gamma', 'Delta'];
  final titles = [
    'Review documentation',
    'Fix critical bug',
    'Update dependencies',
    'Write unit tests',
    'Deploy to staging',
    'Code review',
    'Refactor module',
    'Add feature flag',
    'Optimize query',
    'Update README',
  ];
  // Available tags for multi-value grouping demo
  final allTags = ['urgent', 'bug', 'feature', 'docs', 'refactor'];
  final now = DateTime.now();

  return List.generate(count, (i) {
    // Generate tags: some items have multiple tags (multi-group demo)
    // - i % 5 == 0: 3 tags (appears in 3 groups)
    // - i % 5 == 1: 2 tags (appears in 2 groups)
    // - i % 5 == 2: 2 tags (appears in 2 groups)
    // - i % 5 == 3: 1 tag (appears in 1 group)
    // - i % 5 == 4: 1 tag (appears in 1 group)
    final tagCount = switch (i % 5) {
      0 => 3,
      1 || 2 => 2,
      _ => 1,
    };
    final tags = <String>[];
    for (var t = 0; t < tagCount; t++) {
      tags.add(allTags[(i + t) % allTags.length]);
    }

    return Task(
      id: 'task_$i',
      title: 'Task ${i + 1}: ${titles[i % titles.length]}',
      category: categories[i % categories.length],
      priority: (i % 3) + 1,
      status: statuses[i % statuses.length],
      assignee: assignees[i % assignees.length],
      project: projects[i % projects.length],
      dueDate: now.add(Duration(days: i % 30)),
      tags: tags,
    );
  });
}

// =============================================================================
// Main Playground
// =============================================================================

class CollectionDemo extends StatefulWidget {
  const CollectionDemo({super.key});

  @override
  State<CollectionDemo> createState() => _CollectionDemoState();
}

class _CollectionDemoState extends State<CollectionDemo>
    with SingleTickerProviderStateMixin {
  // Configuration
  int _itemCount = 1000;
  bool _isInitializing = false;

  // Core components
  late FilterManager<Task> _filterManager;
  late SortManager<Task> _sortManager;
  late GroupManager<Task> _groupManager;
  late CollectionController<Task> _controller;
  late SlotManager<Task> _slotManager;
  late TabController _tabController;

  // Filters
  late Filter<Task, String> _statusFilter;
  late Filter<Task, int> _priorityFilter;
  late Filter<Task, String> _categoryFilter;
  late Filter<Task, String> _assigneeFilter;

  // Sort options
  late ValueSortOption<Task, String> _titleSort;
  late ValueSortOption<Task, int> _prioritySort;
  late ValueSortOption<Task, DateTime> _dueDateSort;

  // Group options
  late GroupOption<Task, String> _categoryGroup;
  late GroupOption<Task, String> _statusGroup;
  late GroupOption<Task, int> _priorityGroup;
  late GroupOption<Task, String> _assigneeGroup;
  late GroupOption<Task, String> _projectGroup;
  late GroupOption<Task, String> _tagsGroup; // Multi-value group
  late List<GroupOption<Task, dynamic>> _allGroups;
  List<GroupOption<Task, dynamic>> _activeGroups = [];

  // Search
  String _searchQuery = '';

  // UI
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _lastOperation = '';
  int _lastOperationMs = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeCollection();
  }

  Future<void> _initializeCollection() async {
    setState(() => _isInitializing = true);

    final tasks = generateTasks(_itemCount);

    // Filters
    _statusFilter = Filter(id: 'status', test: (t, v) => t.status == v);
    _priorityFilter = Filter(id: 'priority', test: (t, v) => t.priority == v);
    _categoryFilter = Filter(id: 'category', test: (t, v) => t.category == v);
    _assigneeFilter = Filter(id: 'assignee', test: (t, v) => t.assignee == v);
    _filterManager = FilterManager()
      ..addAll(
          [_statusFilter, _priorityFilter, _categoryFilter, _assigneeFilter]);

    // Sort options
    _titleSort = ValueSortOption(id: 'title', sortIdentifier: (t) => t.title);
    _prioritySort =
        ValueSortOption(id: 'priority', sortIdentifier: (t) => t.priority);
    _dueDateSort =
        ValueSortOption(id: 'dueDate', sortIdentifier: (t) => t.dueDate);
    _sortManager = SortManager()
      ..addAll([_titleSort, _prioritySort, _dueDateSort]);

    // Group options
    // Note: Assignee and Project return null for some items to demonstrate
    // folder-like behavior where items can exist at any grouping level.
    // Uses % 4 to decorrelate from priority (which uses % 3):
    // - index % 4 == 0: stays at Priority level (no Assignee/Project)
    // - index % 4 == 1 or 3: goes to Assignee level (no Project)
    // - index % 4 == 2: goes all the way to Project level
    _categoryGroup =
        GroupOption(id: 'Category', valueBuilder: (t) => t.category, order: 0);
    _statusGroup =
        GroupOption(id: 'Status', valueBuilder: (t) => t.status, order: 1);
    _priorityGroup =
        GroupOption(id: 'Priority', valueBuilder: (t) => t.priority, order: 2);
    _assigneeGroup = GroupOption(
      id: 'Assignee',
      valueBuilder: (t) {
        // Extract index from id (e.g., "task_5" -> 5)
        final index = int.tryParse(t.id.replaceFirst('task_', '')) ?? 0;
        // 1 in 4 items stay at parent level (no assignee grouping)
        return index % 4 == 0 ? null : t.assignee;
      },
      order: 3,
    );
    _projectGroup = GroupOption(
      id: 'Project',
      valueBuilder: (t) {
        final index = int.tryParse(t.id.replaceFirst('task_', '')) ?? 0;
        // 1 in 4 items get project grouping
        return index % 4 == 2 ? t.project : null;
      },
      order: 4,
    );
    // Multi-value group: items can appear in multiple tag groups
    // Uses .multi constructor - same item appears in all matching tag groups
    _tagsGroup = GroupOption.multi(
      id: 'Tags',
      valuesBuilder: (t) => t.tags,
      order: 5,
    );
    _allGroups = [
      _categoryGroup,
      _statusGroup,
      _priorityGroup,
      _assigneeGroup,
      _projectGroup,
      _tagsGroup,
    ];
    _activeGroups = [];
    _groupManager = GroupManager();

    // Controller - now owns data directly
    _controller = CollectionController(
      keyOf: (t) => t.id,
      filter: _filterManager,
      sort: _sortManager,
      group: _groupManager,
    );

    // Add initial items directly to controller
    _controller.addAll(tasks);

    // Slot manager
    _slotManager = SlotManager(controller: _controller);

    // Listeners
    _controller.addChangeListener(_refresh);
    _slotManager.addChangeListener(_refresh);

    setState(() => _isInitializing = false);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _track(String name, VoidCallback action) {
    final sw = Stopwatch()..start();
    action();
    sw.stop();
    setState(() {
      _lastOperation = name;
      _lastOperationMs = sw.elapsedMilliseconds;
    });
  }

  Future<void> _resetCollection() async {
    _controller.dispose();
    _slotManager.dispose();
    _filterManager.dispose();
    _sortManager.dispose();
    _groupManager.dispose();
    _searchQuery = '';
    _searchController.clear();
    await _initializeCollection();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _controller.removeChangeListener(_refresh);
    _slotManager.removeChangeListener(_refresh);
    _controller.dispose();
    _slotManager.dispose();
    _filterManager.dispose();
    _sortManager.dispose();
    _groupManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Demo'),
        elevation: 0,
        actions: [
          if (_lastOperation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Chip(
                avatar: const Icon(Icons.timer_outlined, size: 16),
                label: Text('$_lastOperation: ${_lastOperationMs}ms'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetCollection,
            tooltip: 'Reset',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.filter_list), text: 'Filter'),
            Tab(icon: Icon(Icons.sort), text: 'Sort'),
            Tab(icon: Icon(Icons.folder), text: 'Group'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Control panel
                SizedBox(
                  width: 320,
                  child: Column(
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search tasks...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setState(() => _searchQuery = value.toLowerCase());
                          },
                        ),
                      ),
                      // Tab content
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildFilterTab(),
                            _buildSortTab(),
                            _buildGroupTab(),
                            _buildSettingsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                VerticalDivider(width: 1, color: colorScheme.outlineVariant),
                // Main content
                Expanded(child: _buildMainContent()),
              ],
            ),
    );
  }

  // ===========================================================================
  // Filter Tab
  // ===========================================================================

  Widget _buildFilterTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildFilterSection(
            'Status', _statusFilter, ['todo', 'in_progress', 'done']),
        const SizedBox(height: 16),
        _buildFilterSection('Priority', _priorityFilter, [1, 2, 3],
            labelBuilder: (v) => ['', 'High', 'Medium', 'Low'][v]),
        const SizedBox(height: 16),
        _buildFilterSection('Category', _categoryFilter,
            ['Work', 'Personal', 'Shopping', 'Health', 'Finance']),
        const SizedBox(height: 16),
        _buildFilterSection('Assignee', _assigneeFilter,
            ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve']),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _track('Clear filters', () {
            _statusFilter.clear();
            _priorityFilter.clear();
            _categoryFilter.clear();
            _assigneeFilter.clear();
          }),
          icon: const Icon(Icons.clear_all),
          label: const Text('Clear All Filters'),
        ),
      ],
    );
  }

  Widget _buildFilterSection<V>(
    String title,
    Filter<Task, V> filter,
    List<V> values, {
    String Function(V)? labelBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            if (filter.isNotEmpty)
              TextButton(
                onPressed: () => filter.clear(),
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: values.map((v) {
            final label = labelBuilder?.call(v) ?? v.toString();
            final selected = filter.contains(v);
            return FilterChip(
              label: Text(label),
              selected: selected,
              onSelected: (s) => s ? filter.add(v) : filter.remove(v),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ===========================================================================
  // Sort Tab
  // ===========================================================================

  Widget _buildSortTab() {
    final current = _sortManager.current;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Sort By', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        _buildSortOption('Title', _titleSort, Icons.sort_by_alpha),
        _buildSortOption('Priority', _prioritySort, Icons.flag),
        _buildSortOption('Due Date', _dueDateSort, Icons.calendar_today),
        if (current != null) ...[
          const SizedBox(height: 24),
          Text('Sort Order', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          SegmentedButton<SortOrder>(
            segments: const [
              ButtonSegment(
                  value: SortOrder.ascending,
                  label: Text('Ascending'),
                  icon: Icon(Icons.arrow_upward)),
              ButtonSegment(
                  value: SortOrder.descending,
                  label: Text('Descending'),
                  icon: Icon(Icons.arrow_downward)),
            ],
            selected: {_sortManager.currentOrder},
            onSelectionChanged: (s) => _track(
                'Change order', () => _sortManager.setSortOrder(s.first)),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () =>
                _track('Clear sort', () => _sortManager.clearSorts()),
            icon: const Icon(Icons.clear),
            label: const Text('Clear Sort'),
          ),
        ],
      ],
    );
  }

  Widget _buildSortOption(
      String label, SortOption<Task, dynamic> option, IconData icon) {
    final isSelected = _sortManager.current?.id == option.id;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? Theme.of(context).colorScheme.primary : null),
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check) : null,
      selected: isSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () => _track('Sort by $label', () {
        if (isSelected) {
          _sortManager.clearSorts();
        } else {
          _sortManager.setCurrent(option);
        }
      }),
    );
  }

  // ===========================================================================
  // Group Tab
  // ===========================================================================

  Widget _buildGroupTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Available groups
        Text('Available Groups', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Folder-like: Add Priority → Assignee → Project (items at different depths).\n'
          'Multi-value: Add Tags to see items appear in multiple groups (starred items).',
          style: TextStyle(
              fontSize: 11, color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _allGroups
              .where((g) => !_activeGroups.contains(g))
              .map((g) => ActionChip(
                    avatar: Icon(
                      g.isMultiValue ? Icons.star : Icons.add,
                      size: 16,
                      color: g.isMultiValue ? Colors.amber.shade600 : null,
                    ),
                    label: Text(g.id),
                    tooltip: g.isMultiValue
                        ? 'Multi-value: items can appear in multiple groups'
                        : null,
                    onPressed: () => _track('Add group ${g.id}', () {
                      g.order = _activeGroups.length;
                      _activeGroups.add(g);
                      _groupManager.add(g);
                    }),
                  ))
              .toList(),
        ),

        if (_activeGroups.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Active Groups (drag to reorder)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _activeGroups.length,
            onReorder: (oldIndex, newIndex) {
              _track('Reorder groups', () {
                if (newIndex > oldIndex) newIndex--;
                final item = _activeGroups.removeAt(oldIndex);
                _activeGroups.insert(newIndex, item);
                _groupManager.reorder({
                  for (var i = 0; i < _activeGroups.length; i++)
                    _activeGroups[i].id: i,
                });
              });
            },
            itemBuilder: (context, index) {
              final g = _activeGroups[index];
              return Card(
                key: ValueKey(g.id),
                child: ListTile(
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                  title: Text('${index + 1}. ${g.id}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _track('Remove ${g.id}', () {
                      _activeGroups.remove(g);
                      _groupManager.remove(g.id);
                    }),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Collapse controls
          Text('Collapse Controls',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      _track('Expand all', () => _slotManager.expandAll()),
                  icon: const Icon(Icons.unfold_more),
                  label: const Text('Expand'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      _track('Collapse all', () => _slotManager.collapseAll()),
                  icon: const Icon(Icons.unfold_less),
                  label: const Text('Collapse'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Collapse to level
          Text('Collapse to Level',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: List.generate(_activeGroups.length + 1, (level) {
              return ActionChip(
                label: Text('Level $level'),
                onPressed: () => _track('Collapse to $level',
                    () => _slotManager.collapseToLevel(level)),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Smart collapse
          Text('Smart Collapse', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.filter_1, size: 16),
                label: const Text('< 5 items'),
                onPressed: () => _track('Collapse small', () {
                  _slotManager.collapseWhere((info) => info.itemCount < 5);
                }),
              ),
              ActionChip(
                avatar: const Icon(Icons.filter_2, size: 16),
                label: const Text('< 10 items'),
                onPressed: () => _track('Collapse < 10', () {
                  _slotManager.collapseWhere((info) => info.totalCount < 10);
                }),
              ),
              ActionChip(
                avatar: const Icon(Icons.layers, size: 16),
                label: const Text('Deep levels'),
                onPressed: () => _track('Collapse deep', () {
                  _slotManager.collapseWhere((info) => info.depth >= 2);
                }),
              ),
              ActionChip(
                avatar: const Icon(Icons.check_box_outline_blank, size: 16),
                label: const Text('Empty groups'),
                onPressed: () => _track('Collapse empty', () {
                  _slotManager.collapseWhere((info) => info.itemCount == 0);
                }),
              ),
            ],
          ),
          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () => _track('Clear groups', () {
              for (final g in [..._activeGroups]) {
                _groupManager.remove(g.id);
              }
              _activeGroups.clear();
            }),
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear All Groups'),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // Settings Tab
  // ===========================================================================

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Item count
        Text('Item Count: $_itemCount',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Slider(
          value: _itemCount.toDouble(),
          min: 100,
          max: 100000,
          divisions: 100,
          label: '$_itemCount',
          onChanged: (v) => setState(() => _itemCount = v.toInt()),
          onChangeEnd: (v) => _regenerateItems(),
        ),
        Wrap(
          spacing: 6,
          children: [100, 1000, 5000, 10000, 50000, 100000]
              .map((c) => ActionChip(
                    label: Text(_formatCount(c)),
                    onPressed: () {
                      setState(() => _itemCount = c);
                      _regenerateItems();
                    },
                  ))
              .toList(),
        ),
        const Divider(height: 32),

        // Stats
        Text('Statistics', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _statRow('Total Items', '${_controller.items.length}'),
        _statRow('Filtered Items', '${_controller.length}'),
        _statRow('Total Slots', '${_slotManager.totalSlots}'),
        _statRow('Unique Items', '${_slotManager.uniqueItemCount}'),
        if (_slotManager.uniqueItemCount != _slotManager.totalSlots &&
            _activeGroups.any((g) => g.isMultiValue))
          _statRow(
            'Multi-group Appearances',
            '${_slotManager.totalSlots - _slotManager.uniqueItemCount - _activeGroups.length} extra',
          ),
        _statRow('Group Levels', '${_activeGroups.length}'),
        _statRow('Selected', '${_controller.selection.count}'),
        const Divider(height: 32),

        // Selection
        Text('Selection', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _controller.selection.clearAll(),
                child: const Text('Clear'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  final keys =
                      _controller.items.take(100).map((t) => t.id).toList();
                  _controller.selection.selectAll(keys);
                },
                child: const Text('Select 100'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${count ~/ 1000}k';
    return '$count';
  }

  Future<void> _regenerateItems() async {
    _track('Generate $_itemCount items', () => _controller.clear());
    final tasks = generateTasks(_itemCount);
    _controller.addAll(tasks);
  }

  // ===========================================================================
  // Main Content
  // ===========================================================================

  Widget _buildMainContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Text(
                '${_slotManager.totalSlots} slots',
                style: theme.textTheme.titleSmall,
              ),
              if (_activeGroups.isNotEmpty) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _activeGroups.map((g) => g.id).join(' → '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              Text(
                '${_controller.selection.count} selected',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _slotManager.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 64, color: colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('No items to display',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your filters',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.outline),
                      ),
                    ],
                  ),
                )
              : Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _slotManager.totalSlots,
                    // Use simple extent check: header vs item (no per-item lookup)
                    itemExtentBuilder: (index, _) =>
                        _slotManager.isHeader(index)
                            ? _headerHeight
                            : _itemHeight,
                    itemBuilder: (context, index) {
                      final slot = _slotManager.getSlot(index);
                      if (slot == null) return const SizedBox.shrink();

                      return switch (slot) {
                        ItemSlot<Task>() => _buildItemTile(slot),
                        GroupHeaderSlot<Task>() => _buildGroupHeader(slot),
                      };
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // Uniform height for smooth scrolling (eliminates extent calculation issues)
  static const _itemHeight = 56.0;
  static const _headerHeight = 48.0;

  Widget _buildItemTile(ItemSlot<Task> slot) {
    final task = slot.item;
    final key = slot.key;
    final depth = slot.depth;

    // Apply search filter
    if (_searchQuery.isNotEmpty &&
        !task.title.toLowerCase().contains(_searchQuery) &&
        !task.category.toLowerCase().contains(_searchQuery) &&
        !task.assignee.toLowerCase().contains(_searchQuery)) {
      return const SizedBox.shrink();
    }

    final isSelected = _controller.selection.isSelected(key);
    final leftPadding = 12.0 + (depth * 20.0);
    final isHighPriority = task.priority == 1;

    // Simplified subtitle: category • assignee • [tags]
    final subtitle = task.isMultiGroup
        ? '${task.category} • ${task.assignee} • [${task.tags.join(", ")}]'
        : '${task.category} • ${task.assignee} • ${task.project}';

    // Use SizedBox to enforce exact height matching itemExtentBuilder
    return SizedBox(
      height: _itemHeight,
      child: Material(
        color: isSelected
            ? Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.3)
            : null,
        child: InkWell(
          onTap: () => _controller.selection.select(key),
          child: Padding(
            padding: EdgeInsets.only(left: leftPadding, right: 16),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (v) => _controller.selection.select(
                    key,
                    state: v == true ? Tristate.yes : Tristate.no,
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.isMultiGroup ? '★ ${task.title}' : task.title,
                        style: isHighPriority
                            ? const TextStyle(fontWeight: FontWeight.bold)
                            : null,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  task.priorityLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: task.priorityColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Cache colors to avoid recreating list on each build
  static const _headerColors = [
    Colors.indigo,
    Colors.teal,
    Colors.orange,
    Colors.purple,
    Colors.pink,
  ];

  Widget _buildGroupHeader(GroupHeaderSlot<Task> slot) {
    final color = _headerColors[slot.depth % _headerColors.length];
    final leftPadding = 12.0 + (slot.depth * 20.0);

    return Material(
      color: color.withValues(alpha: 0.08 + (slot.depth * 0.04)),
      child: InkWell(
        onTap: () => _track('Toggle ${slot.label}', () {
          _slotManager.toggleCollapse(slot.groupId);
        }),
        // Long press to select all in group (avoids expensive per-frame check)
        onLongPress: () {
          final groupKeys = slot.node.flattenedKeys.toList();
          _controller.selection.selectAll(groupKeys);
        },
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: EdgeInsets.only(left: leftPadding, right: 16),
            child: Row(
              children: [
                // Expand/collapse icon
                Icon(
                  slot.isCollapsed ? Icons.chevron_right : Icons.expand_more,
                  color: color,
                ),
                const SizedBox(width: 8),
                // Group label
                Expanded(
                  child: Text(
                    slot.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                // Item count (simple text, no Container/BoxDecoration)
                Text(
                  slot.isCollapsed ? '${slot.totalCount}' : '${slot.itemCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
