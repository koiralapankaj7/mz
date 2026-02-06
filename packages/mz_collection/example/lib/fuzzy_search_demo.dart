// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

// Example uses RadioListTile deprecated API for compatibility with older SDK.
// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mz_collection/mz_collection.dart';

import 'fuzzy_search_scope.dart';

// =============================================================================
// Highlight Utilities
// =============================================================================

/// Result of finding a fuzzy match in text.
class HighlightMatch {
  const HighlightMatch({
    required this.start,
    required this.end,
    required this.distance,
    required this.matchedText,
  });

  final int start;
  final int end;
  final int distance;
  final String matchedText;
}

/// Finds the best fuzzy matching substring in [text] for [query].
/// Returns null if no good match is found within [maxDistance].
HighlightMatch? findBestSubstringMatch(
  String text,
  String query, {
  int maxDistance = 2,
  bool caseSensitive = false,
}) {
  if (query.isEmpty || text.isEmpty) return null;

  final textNorm = caseSensitive ? text : text.toLowerCase();
  final queryNorm = caseSensitive ? query : query.toLowerCase();

  // First check for exact substring match
  final exactIndex = textNorm.indexOf(queryNorm);
  if (exactIndex != -1) {
    return HighlightMatch(
      start: exactIndex,
      end: exactIndex + query.length,
      distance: 0,
      matchedText: text.substring(exactIndex, exactIndex + query.length),
    );
  }

  // Try to find best fuzzy match by sliding window
  HighlightMatch? bestMatch;
  final minLen = math.max(1, query.length - maxDistance);
  final maxLen = query.length + maxDistance;

  for (var windowSize = minLen; windowSize <= maxLen; windowSize++) {
    if (windowSize > text.length) break;

    for (var i = 0; i <= text.length - windowSize; i++) {
      final substring = textNorm.substring(i, i + windowSize);
      final distance = levenshteinDistance(substring, queryNorm);

      if (distance <= maxDistance) {
        if (bestMatch == null || distance < bestMatch.distance) {
          bestMatch = HighlightMatch(
            start: i,
            end: i + windowSize,
            distance: distance,
            matchedText: text.substring(i, i + windowSize),
          );
        }
        // Early exit on exact match
        if (distance == 0) return bestMatch;
      }
    }
  }

  // Also check word boundaries for better matches
  final words = text.split(RegExp(r'\s+'));
  var wordStart = 0;
  for (final word in words) {
    final wordNorm = caseSensitive ? word : word.toLowerCase();
    final distance = levenshteinDistance(wordNorm, queryNorm);

    if (distance <= maxDistance) {
      if (bestMatch == null || distance < bestMatch.distance) {
        final start = text.indexOf(word, wordStart);
        bestMatch = HighlightMatch(
          start: start,
          end: start + word.length,
          distance: distance,
          matchedText: word,
        );
      }
    }
    wordStart += word.length + 1;
  }

  return bestMatch;
}

/// Builds a TextSpan with the matched portion highlighted.
TextSpan buildHighlightedText(
  String text,
  String query, {
  int maxDistance = 2,
  bool caseSensitive = false,
  TextStyle? normalStyle,
  TextStyle? highlightStyle,
}) {
  if (query.isEmpty) {
    return TextSpan(text: text, style: normalStyle);
  }

  final match = findBestSubstringMatch(
    text,
    query,
    maxDistance: maxDistance,
    caseSensitive: caseSensitive,
  );

  if (match == null) {
    return TextSpan(text: text, style: normalStyle);
  }

  return TextSpan(
    children: [
      if (match.start > 0)
        TextSpan(text: text.substring(0, match.start), style: normalStyle),
      TextSpan(
        text: text.substring(match.start, match.end),
        style: highlightStyle,
      ),
      if (match.end < text.length)
        TextSpan(text: text.substring(match.end), style: normalStyle),
    ],
  );
}

// =============================================================================
// Data Model
// =============================================================================

class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    required this.title,
  });

  final String id;
  final String name;
  final String email;
  final String department;
  final String title;

  @override
  String toString() => name;
}

// =============================================================================
// Sample Data - Names designed to demonstrate fuzzy matching
// =============================================================================

final _sampleContacts = [
  // Common names with similar spellings
  Contact(
    id: '1',
    name: 'John Smith',
    email: 'john.smith@company.com',
    department: 'Engineering',
    title: 'Software Engineer',
  ),
  Contact(
    id: '2',
    name: 'Jon Smyth',
    email: 'jon.smyth@company.com',
    department: 'Engineering',
    title: 'Senior Developer',
  ),
  Contact(
    id: '3',
    name: 'Jonathan Schmidt',
    email: 'j.schmidt@company.com',
    department: 'Marketing',
    title: 'Marketing Manager',
  ),
  Contact(
    id: '4',
    name: 'Jane Doe',
    email: 'jane.doe@company.com',
    department: 'Sales',
    title: 'Sales Representative',
  ),
  Contact(
    id: '5',
    name: 'Janet Douglas',
    email: 'janet.d@company.com',
    department: 'HR',
    title: 'HR Specialist',
  ),
  Contact(
    id: '6',
    name: 'Michael Johnson',
    email: 'michael.j@company.com',
    department: 'Engineering',
    title: 'Tech Lead',
  ),
  Contact(
    id: '7',
    name: 'Michelle Johnston',
    email: 'michelle.j@company.com',
    department: 'Design',
    title: 'UX Designer',
  ),
  Contact(
    id: '8',
    name: 'Robert Williams',
    email: 'rob.williams@company.com',
    department: 'Finance',
    title: 'Financial Analyst',
  ),
  Contact(
    id: '9',
    name: 'Roberto Williamson',
    email: 'roberto.w@company.com',
    department: 'Operations',
    title: 'Operations Manager',
  ),
  Contact(
    id: '10',
    name: 'Sarah Connor',
    email: 'sarah.c@company.com',
    department: 'Engineering',
    title: 'DevOps Engineer',
  ),
  Contact(
    id: '11',
    name: 'Sara Conner',
    email: 'sara.conner@company.com',
    department: 'Support',
    title: 'Support Lead',
  ),
  Contact(
    id: '12',
    name: 'Christopher Lee',
    email: 'chris.lee@company.com',
    department: 'Engineering',
    title: 'Backend Developer',
  ),
  Contact(
    id: '13',
    name: 'Kristopher Leigh',
    email: 'kris.leigh@company.com',
    department: 'Engineering',
    title: 'Frontend Developer',
  ),
  Contact(
    id: '14',
    name: 'Elizabeth Taylor',
    email: 'liz.taylor@company.com',
    department: 'Marketing',
    title: 'Content Writer',
  ),
  Contact(
    id: '15',
    name: 'Elisabeth Tailor',
    email: 'e.tailor@company.com',
    department: 'Design',
    title: 'Graphic Designer',
  ),
];

// =============================================================================
// Main Demo
// =============================================================================

class FuzzySearchDemo extends StatefulWidget {
  const FuzzySearchDemo({super.key});

  @override
  State<FuzzySearchDemo> createState() => _FuzzySearchDemoState();
}

class _FuzzySearchDemoState extends State<FuzzySearchDemo>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  late FuzzySearchController _scopeController;
  final _scopeScrollController = ScrollController();

  // Configuration
  FuzzyMatchStrategy _strategy = FuzzyMatchStrategy.contains;
  int _maxDistance = 2;
  double? _minSimilarity;
  bool _caseSensitive = false;
  bool _searchName = true;
  bool _searchEmail = true;
  bool _searchDepartment = false;

  // Fuzzy filter
  late FuzzySearchFilter<Contact> _fuzzyFilter;
  late FilterManager<Contact> _filterManager;

  // Results
  List<Contact> _results = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _scopeController = FuzzySearchController(maxDistance: _maxDistance);
    _initializeFilter();
  }

  void _initializeFilter() {
    _fuzzyFilter = FuzzySearchFilter<Contact>(
      id: 'fuzzy_search',
      valuesRetriever: _getSearchableValues,
      maxDistance: _maxDistance,
      minSimilarity: _minSimilarity,
      strategy: _strategy,
      caseSensitive: _caseSensitive,
      onChanged: (_) => _updateResults(),
    );

    _filterManager = FilterManager<Contact>(filters: [_fuzzyFilter]);
    _updateResults();
  }

  List<String?> _getSearchableValues(Contact contact) {
    return [
      if (_searchName) contact.name,
      if (_searchEmail) contact.email,
      if (_searchDepartment) contact.department,
    ];
  }

  void _updateResults() {
    setState(() {
      _results = _sampleContacts.where(_filterManager.apply).toList();
    });
  }

  void _rebuildFilter() {
    _filterManager.dispose();
    _initializeFilter();
    if (_query.isNotEmpty) {
      _fuzzyFilter.query = _query;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scopeController.dispose();
    _scopeScrollController.dispose();
    _filterManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuzzy Search Demo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Search'),
            Tab(icon: Icon(Icons.select_all), text: 'Scope'),
            Tab(icon: Icon(Icons.tune), text: 'Settings'),
            Tab(icon: Icon(Icons.code), text: 'Algorithms'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchTab(theme, colorScheme),
          _buildScopeTab(theme, colorScheme),
          _buildSettingsTab(theme),
          _buildAlgorithmsTab(theme, colorScheme),
        ],
      ),
    );
  }

  // ===========================================================================
  // Search Tab
  // ===========================================================================

  Widget _buildSearchTab(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        // Search input
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Try: "jonh" (typo), "smth", "micheal"...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                            _fuzzyFilter.query = '';
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() => _query = value);
                  _fuzzyFilter.query = value;
                },
              ),
              const SizedBox(height: 8),
              // Quick search chips
              Wrap(
                spacing: 8,
                children: [
                  _quickSearchChip('jonh', 'Typo for "John"'),
                  _quickSearchChip('smth', 'Typo for "Smith"'),
                  _quickSearchChip('micheal', 'Typo for "Michael"'),
                  _quickSearchChip('sara conor', 'Missing letters'),
                  _quickSearchChip('kris', 'Partial name'),
                ],
              ),
            ],
          ),
        ),

        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Text(
                '${_results.length} of ${_sampleContacts.length} contacts',
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              Text(
                'Strategy: ${_strategy.name}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Max distance: $_maxDistance',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Results
        Expanded(
          child: _results.isEmpty && _query.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off,
                          size: 64, color: colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('No matches found for "$_query"',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Try increasing max distance or changing strategy',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.outline),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final contact = _results[index];
                    return _buildContactTile(contact, theme, colorScheme);
                  },
                ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Scope Tab - Demonstrates FuzzySearchScope with regular Text widgets
  // ===========================================================================

  // Sample data for large list testing
  static const _loremWords = [
    'Flutter',
    'widget',
    'Dart',
    'application',
    'development',
    'mobile',
    'cross-platform',
    'framework',
    'reactive',
    'declarative',
    'stateless',
    'stateful',
    'build',
    'context',
    'scaffold',
    'material',
    'cupertino',
    'navigation',
    'routing',
    'state',
    'management',
    'provider',
    'bloc',
    'riverpod',
    'getx',
    'animation',
    'gesture',
    'layout',
    'rendering',
    'painting',
    'John',
    'Jane',
    'Michael',
    'Sarah',
    'David',
    'performance',
    'optimization',
    'testing',
    'debugging',
    'profiling',
  ];

  String _generateSentence(int seed) {
    final random = math.Random(seed);
    final wordCount = 8 + random.nextInt(12);
    final words = List.generate(
      wordCount,
      (_) => _loremWords[random.nextInt(_loremWords.length)],
    );
    return '${words.join(' ')}.';
  }

  Widget _buildScopeTab(ThemeData theme, ColorScheme colorScheme) {
    return ListenableBuilder(
      listenable: _scopeController,
      builder: (context, _) {
        final stats = _scopeController.statistics;

        return Column(
          children: [
            // Header with description
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.highlight, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'FuzzySearchScope Demo',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '500+ Text widgets with fuzzy highlighting, navigation, '
                    'and auto-scroll. Use ↑↓ or Enter/Shift+Enter to navigate.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            // FuzzySearchBar - pre-built search widget with all features
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FuzzySearchBar(
                controller: _scopeController,
                hintText: 'Try: "flutter", "widgt", "jonh"...',
                showStatistics: true,
                showHistory: true,
                showRegexToggle: true,
                showCaseSensitiveToggle: true,
                showNavigationButtons: true,
              ),
            ),

            const SizedBox(height: 8),

            // Quick search chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _scopeQuickChip('flutter', colorScheme),
                  _scopeQuickChip('widgt', colorScheme),
                  _scopeQuickChip('jonh', colorScheme),
                  _scopeQuickChip('micheal', colorScheme),
                  ActionChip(
                    avatar: Icon(
                      Icons.code,
                      size: 16,
                      color: colorScheme.secondary,
                    ),
                    label: const Text('Flu.*er'),
                    onPressed: () {
                      _scopeController
                        ..useRegex = true
                        ..query = 'Flu.*er';
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Statistics bar
            if (_scopeController.query.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    // Match count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: stats.totalMatches > 0
                            ? colorScheme.primaryContainer
                            : colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${stats.totalMatches}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: stats.totalMatches > 0
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Match breakdown
                    if (stats.totalMatches > 0)
                      Expanded(
                        child: Text(
                          '${stats.exactMatches} exact, '
                          '${stats.fuzzyMatches} fuzzy',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          'no matches found',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    // Settings indicators
                    if (_scopeController.useRegex)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: const Text('Regex'),
                          avatar: const Icon(Icons.code, size: 14),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          labelStyle: theme.textTheme.labelSmall,
                        ),
                      ),
                    if (_scopeController.caseSensitive)
                      Chip(
                        label: const Text('Aa'),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        labelStyle: theme.textTheme.labelSmall,
                      ),
                  ],
                ),
              ),

            const Divider(height: 1),

            // Content wrapped in FuzzySearchScope
            Expanded(
              child: FuzzySearchScope(
                controller: _scopeController,
                highlightColor: colorScheme.primaryContainer,
                currentMatchColor: colorScheme.primary,
                scrollController: _scopeScrollController,
                onHighlightTap: (hit) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Tapped: "${hit.matchedText}" '
                        '(distance: ${hit.distance})',
                      ),
                      duration: const Duration(seconds: 2),
                      action: SnackBarAction(
                        label: 'Full Text',
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Full Paragraph'),
                              content: SingleChildScrollView(
                                child: Text(hit.fullText),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                child: CustomScrollView(
                  controller: _scopeScrollController,
                  slivers: [
                    // Section header for non-lazy content
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: colorScheme.primaryContainer,
                        child: Text(
                          '📦 Non-Lazy Section (Column with 20 items)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),

                    // Non-lazy content using SliverToBoxAdapter with Column
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(20, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Non-Lazy Item ${index + 1}',
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(_generateSentence(index)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Flutter widget development with Dart',
                                        style: TextStyle(
                                          color: colorScheme.primary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),

                    // Section header for lazy content
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: colorScheme.secondaryContainer,
                        child: Text(
                          '⚡ Lazy Section (SliverList.builder with 500 items)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),

                    // Lazy content using SliverList.builder
                    SliverList.builder(
                      itemCount: 500,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.tertiaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'LAZY',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                colorScheme.onTertiaryContainer,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Lazy Item ${index + 1}',
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(_generateSentence(index + 1000)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _generateSentence(index + 2000),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person,
                                        size: 14,
                                        color: colorScheme.outline,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        index % 3 == 0
                                            ? 'John Smith'
                                            : index % 3 == 1
                                                ? 'Jane Doe'
                                                : 'Michael Johnson',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.outline,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(
                                        Icons.code,
                                        size: 14,
                                        color: colorScheme.outline,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Flutter & Dart',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Footer
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            '— End of 520 items —',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _scopeQuickChip(String query, ColorScheme colorScheme) {
    return ActionChip(
      label: Text(query),
      onPressed: () {
        _scopeController
          ..useRegex = false
          ..query = query;
      },
    );
  }

  Widget _quickSearchChip(String query, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: ActionChip(
        label: Text(query),
        onPressed: () {
          _searchController.text = query;
          setState(() => _query = query);
          _fuzzyFilter.query = query;
        },
      ),
    );
  }

  Widget _buildContactTile(
    Contact contact,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // Highlight styles
    final normalStyle = theme.textTheme.bodyLarge;
    final highlightStyle = theme.textTheme.bodyLarge?.copyWith(
      backgroundColor: colorScheme.primaryContainer,
      color: colorScheme.onPrimaryContainer,
      fontWeight: FontWeight.bold,
    );
    final subtitleStyle = theme.textTheme.bodyMedium;
    final subtitleHighlightStyle = theme.textTheme.bodyMedium?.copyWith(
      backgroundColor: colorScheme.tertiaryContainer,
      color: colorScheme.onTertiaryContainer,
      fontWeight: FontWeight.bold,
    );
    final emailStyle = TextStyle(fontSize: 12, color: colorScheme.outline);
    final emailHighlightStyle = TextStyle(
      fontSize: 12,
      backgroundColor: colorScheme.secondaryContainer,
      color: colorScheme.onSecondaryContainer,
      fontWeight: FontWeight.bold,
    );

    // Find matches and calculate info
    String? matchInfo;
    String? matchedField;
    var matchDistance = -1; // -1 means no match found

    if (_query.isNotEmpty) {
      // Check name
      if (_searchName) {
        final match = findBestSubstringMatch(
          contact.name,
          _query,
          maxDistance: _maxDistance,
          caseSensitive: _caseSensitive,
        );
        if (match != null &&
            (matchDistance < 0 || match.distance < matchDistance)) {
          matchDistance = match.distance;
          matchedField = 'name';
        }
      }

      // Check email
      if (_searchEmail) {
        final match = findBestSubstringMatch(
          contact.email,
          _query,
          maxDistance: _maxDistance,
          caseSensitive: _caseSensitive,
        );
        if (match != null &&
            (matchDistance < 0 || match.distance < matchDistance)) {
          matchDistance = match.distance;
          matchedField = 'email';
        }
      }

      // Check department
      if (_searchDepartment) {
        final match = findBestSubstringMatch(
          contact.department,
          _query,
          maxDistance: _maxDistance,
          caseSensitive: _caseSensitive,
        );
        if (match != null &&
            (matchDistance < 0 || match.distance < matchDistance)) {
          matchDistance = match.distance;
          matchedField = 'department';
        }
      }

      if (matchDistance >= 0 && matchedField != null) {
        final sim = 1.0 -
            (matchDistance / math.max(_query.length, matchedField.length));
        matchInfo =
            'Matched in $matchedField (distance: $matchDistance, ~${(sim * 100).toStringAsFixed(0)}% similar)';
      }
    }

    // Convert -1 to null for display logic
    final hasMatch = matchDistance >= 0;
    final displayDistance = hasMatch ? matchDistance : null;

    // Build highlighted text spans
    final nameSpan = _query.isNotEmpty && _searchName
        ? buildHighlightedText(
            contact.name,
            _query,
            maxDistance: _maxDistance,
            caseSensitive: _caseSensitive,
            normalStyle: normalStyle,
            highlightStyle: highlightStyle,
          )
        : TextSpan(text: contact.name, style: normalStyle);

    final emailSpan = _query.isNotEmpty && _searchEmail
        ? buildHighlightedText(
            contact.email,
            _query,
            maxDistance: _maxDistance,
            caseSensitive: _caseSensitive,
            normalStyle: emailStyle,
            highlightStyle: emailHighlightStyle,
          )
        : TextSpan(text: contact.email, style: emailStyle);

    final deptSpan = _query.isNotEmpty && _searchDepartment
        ? buildHighlightedText(
            contact.department,
            _query,
            maxDistance: _maxDistance,
            caseSensitive: _caseSensitive,
            normalStyle: subtitleStyle,
            highlightStyle: subtitleHighlightStyle,
          )
        : TextSpan(text: contact.department, style: subtitleStyle);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: displayDistance == 0
            ? colorScheme.primary
            : hasMatch
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
        child: Text(
          contact.name.substring(0, 1),
          style: TextStyle(
            color: displayDistance == 0
                ? colorScheme.onPrimary
                : hasMatch
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      title: RichText(text: nameSpan),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '${contact.title} - ', style: subtitleStyle),
                deptSpan,
              ],
            ),
          ),
          RichText(text: emailSpan),
          if (matchInfo != null)
            Text(
              matchInfo,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      isThreeLine: true,
    );
  }

  // ===========================================================================
  // Settings Tab
  // ===========================================================================

  Widget _buildSettingsTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Strategy
        Text('Match Strategy', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...FuzzyMatchStrategy.values.map((strategy) {
          return RadioListTile<FuzzyMatchStrategy>(
            title: Text(strategy.name),
            subtitle: Text(_strategyDescription(strategy)),
            value: strategy,
            groupValue: _strategy,
            onChanged: (value) {
              setState(() => _strategy = value!);
              _rebuildFilter();
            },
          );
        }),
        const Divider(height: 32),

        // Max Distance
        Text('Max Edit Distance: $_maxDistance',
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Slider(
          value: _maxDistance.toDouble(),
          min: 0,
          max: 5,
          divisions: 5,
          label: '$_maxDistance',
          onChanged: (value) {
            setState(() => _maxDistance = value.toInt());
            _rebuildFilter();
          },
        ),
        Text(
          _maxDistanceDescription(_maxDistance),
          style: theme.textTheme.bodySmall,
        ),
        const Divider(height: 32),

        // Min Similarity
        Row(
          children: [
            Text('Use Similarity Threshold', style: theme.textTheme.titleSmall),
            const Spacer(),
            Switch(
              value: _minSimilarity != null,
              onChanged: (value) {
                setState(() => _minSimilarity = value ? 0.7 : null);
                _rebuildFilter();
              },
            ),
          ],
        ),
        if (_minSimilarity != null) ...[
          const SizedBox(height: 8),
          Slider(
            value: _minSimilarity!,
            min: 0.5,
            max: 1.0,
            divisions: 10,
            label: '${(_minSimilarity! * 100).toInt()}%',
            onChanged: (value) {
              setState(() => _minSimilarity = value);
              _rebuildFilter();
            },
          ),
          Text(
            'Minimum ${(_minSimilarity! * 100).toInt()}% similarity required',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const Divider(height: 32),

        // Search Fields
        Text('Search Fields', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        CheckboxListTile(
          title: const Text('Name'),
          value: _searchName,
          onChanged: (value) {
            setState(() => _searchName = value!);
            _rebuildFilter();
          },
        ),
        CheckboxListTile(
          title: const Text('Email'),
          value: _searchEmail,
          onChanged: (value) {
            setState(() => _searchEmail = value!);
            _rebuildFilter();
          },
        ),
        CheckboxListTile(
          title: const Text('Department'),
          value: _searchDepartment,
          onChanged: (value) {
            setState(() => _searchDepartment = value!);
            _rebuildFilter();
          },
        ),
        const Divider(height: 32),

        // Case Sensitivity
        SwitchListTile(
          title: const Text('Case Sensitive'),
          subtitle: const Text('Match exact letter case'),
          value: _caseSensitive,
          onChanged: (value) {
            setState(() => _caseSensitive = value);
            _rebuildFilter();
          },
        ),
      ],
    );
  }

  String _strategyDescription(FuzzyMatchStrategy strategy) {
    return switch (strategy) {
      FuzzyMatchStrategy.contains =>
        'Matches if query appears anywhere (with typos)',
      FuzzyMatchStrategy.startsWith => 'Matches only at the beginning of text',
      FuzzyMatchStrategy.wholeWord =>
        'Each query word must match a word in the value',
      FuzzyMatchStrategy.anywhere => 'Most permissive - any word match counts',
    };
  }

  String _maxDistanceDescription(int distance) {
    return switch (distance) {
      0 => 'Exact match only - no typos allowed',
      1 => 'Allow 1 typo (e.g., "jonh" matches "john")',
      2 => 'Allow 2 typos (recommended for general search)',
      3 => 'Allow 3 typos (permissive)',
      _ => 'Very permissive - may match unrelated terms',
    };
  }

  // ===========================================================================
  // Algorithms Tab
  // ===========================================================================

  Widget _buildAlgorithmsTab(ThemeData theme, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Levenshtein Distance Calculator
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Levenshtein Distance Calculator',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'The minimum number of single-character edits '
                  '(insertions, deletions, substitutions) to change one '
                  'string into another.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _LevenshteinCalculator(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Damerau-Levenshtein
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Damerau-Levenshtein Distance',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Like Levenshtein but also counts adjacent character '
                  'transpositions as a single edit. Better for keyboard typos.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _DamerauCalculator(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Find Best Match
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Find Best Match', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Find the closest matching string from a list of candidates.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _BestMatchFinder(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Find All Matches
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Find All Matches', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Find all strings within a given edit distance, sorted by '
                  'closeness.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _AllMatchesFinder(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Algorithm Demo Widgets
// =============================================================================

class _LevenshteinCalculator extends StatefulWidget {
  @override
  State<_LevenshteinCalculator> createState() => _LevenshteinCalculatorState();
}

class _LevenshteinCalculatorState extends State<_LevenshteinCalculator> {
  final _string1Controller = TextEditingController(text: 'kitten');
  final _string2Controller = TextEditingController(text: 'sitting');

  @override
  void dispose() {
    _string1Controller.dispose();
    _string2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s1 = _string1Controller.text;
    final s2 = _string2Controller.text;
    final distance = levenshteinDistance(s1, s2);
    final sim = similarity(s1, s2);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _string1Controller,
                decoration: const InputDecoration(
                  labelText: 'String 1',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _string2Controller,
                decoration: const InputDecoration(
                  labelText: 'String 2',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '$distance',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const Text('Edit Distance'),
                ],
              ),
              Column(
                children: [
                  Text(
                    '${(sim * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const Text('Similarity'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DamerauCalculator extends StatefulWidget {
  @override
  State<_DamerauCalculator> createState() => _DamerauCalculatorState();
}

class _DamerauCalculatorState extends State<_DamerauCalculator> {
  final _string1Controller = TextEditingController(text: 'teh');
  final _string2Controller = TextEditingController(text: 'the');

  @override
  void dispose() {
    _string1Controller.dispose();
    _string2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s1 = _string1Controller.text;
    final s2 = _string2Controller.text;
    final levenDist = levenshteinDistance(s1, s2);
    final damerauDist = damerauLevenshteinDistance(s1, s2);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _string1Controller,
                decoration: const InputDecoration(
                  labelText: 'String 1',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _string2Controller,
                decoration: const InputDecoration(
                  labelText: 'String 2',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '$levenDist',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                  ),
                  const Text('Levenshtein'),
                ],
              ),
              Column(
                children: [
                  Text(
                    '$damerauDist',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                  ),
                  const Text('Damerau-Levenshtein'),
                ],
              ),
            ],
          ),
        ),
        if (levenDist != damerauDist)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Transposition detected! Damerau counts it as 1 edit.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _BestMatchFinder extends StatefulWidget {
  @override
  State<_BestMatchFinder> createState() => _BestMatchFinderState();
}

class _BestMatchFinderState extends State<_BestMatchFinder> {
  final _queryController = TextEditingController(text: 'jonh');
  final _candidates = ['John', 'Jane', 'Jonathan', 'Joan', 'Jonas'];
  int _maxDistance = 2;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text;
    final match = findBestMatch(query, _candidates, maxDistance: _maxDistance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _queryController,
          decoration: const InputDecoration(
            labelText: 'Query',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Text('Candidates: ${_candidates.join(", ")}'),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Max distance: '),
            DropdownButton<int>(
              value: _maxDistance,
              items: [1, 2, 3, 4, 5]
                  .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                  .toList(),
              onChanged: (value) => setState(() => _maxDistance = value!),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: match != null
                ? Theme.of(context).colorScheme.tertiaryContainer
                : Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                match != null ? Icons.check_circle : Icons.error,
                color: match != null
                    ? Theme.of(context).colorScheme.onTertiaryContainer
                    : Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Text(
                match != null
                    ? 'Best match: "${match.candidate}" (distance: ${match.distance})'
                    : 'No match found within distance $_maxDistance',
                style: TextStyle(
                  color: match != null
                      ? Theme.of(context).colorScheme.onTertiaryContainer
                      : Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AllMatchesFinder extends StatefulWidget {
  @override
  State<_AllMatchesFinder> createState() => _AllMatchesFinderState();
}

class _AllMatchesFinderState extends State<_AllMatchesFinder> {
  final _queryController = TextEditingController(text: 'sara');
  final _candidates = [
    'Sarah',
    'Sara',
    'Zara',
    'Clara',
    'Maria',
    'Tara',
    'Kara',
  ];
  int _maxDistance = 2;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text;
    final matches =
        findAllMatches(query, _candidates, maxDistance: _maxDistance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _queryController,
          decoration: const InputDecoration(
            labelText: 'Query',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Text('Candidates: ${_candidates.join(", ")}'),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Max distance: '),
            DropdownButton<int>(
              value: _maxDistance,
              items: [1, 2, 3, 4, 5]
                  .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                  .toList(),
              onChanged: (value) => setState(() => _maxDistance = value!),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Found ${matches.length} matches:',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (matches.isEmpty)
          const Text('No matches found')
        else
          ...matches.map((m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${m.distance}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(m.candidate),
                    const Spacer(),
                    Text(
                      '${(m.similarity * 100).toStringAsFixed(0)}% similar',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}
