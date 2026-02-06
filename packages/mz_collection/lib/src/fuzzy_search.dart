// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

/// {@template mz_collection.fuzzy_search_library}
/// Fuzzy text search with typo tolerance using Levenshtein distance.
///
/// ## Overview
///
/// [FuzzySearchFilter] provides typo-tolerant search by finding items where
/// any searchable field is "close enough" to the query. This enables users
/// to find results even with spelling mistakes.
///
/// ## Algorithm
///
/// Uses **Levenshtein distance** (edit distance) to measure similarity:
/// - Distance of 0 = exact match
/// - Distance of 1 = one character different (typo, insertion, deletion)
/// - Distance of 2 = two edits needed
///
/// ## Matching Strategies
///
/// ```text
/// ┌────────────────────┬────────────────────────────────────────────────┐
/// │     Strategy       │              Description                       │
/// ├────────────────────┼────────────────────────────────────────────────┤
/// │ FuzzyMatchStrategy │                                                │
/// │   .contains        │ Fuzzy prefix/suffix + contains (default)       │
/// │   .startsWith      │ Fuzzy prefix matching only                     │
/// │   .wholeWord       │ Each word must fuzzy-match a word in value     │
/// │   .anywhere        │ Fuzzy match anywhere (most permissive)         │
/// └────────────────────┴────────────────────────────────────────────────┘
/// ```
///
/// ## Quick Start
///
/// {@tool snippet}
/// Basic fuzzy search usage:
///
/// ```dart
/// final filter = FuzzySearchFilter<User>(
///   valuesRetriever: (user) => [user.name, user.email],
///   maxDistance: 2,  // Allow up to 2 typos
/// );
///
/// // Set search query
/// filter.query = 'jonh';  // Will match "John" (1 edit)
///
/// // Apply to items
/// final matches = users.where(filter.apply);
/// ```
/// {@end-tool}
///
/// ## With FilterManager
///
/// {@tool snippet}
/// Using fuzzy search with FilterManager:
///
/// ```dart
/// final filterManager = FilterManager<User>(
///   filters: [
///     FuzzySearchFilter<User>(
///       id: 'search',
///       valuesRetriever: (u) => [u.name, u.email, u.department],
///       maxDistance: 2,
///     ),
///     // ... other filters
///   ],
/// );
///
/// // Update search
/// filterManager.getFilter<String>('search')?.add('marekting');  // finds "marketing"
/// ```
/// {@end-tool}
/// {@endtemplate}
library;

import 'dart:math' as math;

import 'filter_manager.dart';

/// {@template mz_collection.fuzzy_match_strategy}
/// Strategy for how fuzzy matching is applied to text.
/// {@endtemplate}
enum FuzzyMatchStrategy {
  /// Fuzzy match with contains semantics.
  ///
  /// The query can match anywhere in the value. If no exact substring match,
  /// checks if any word in the value is within edit distance of query.
  /// This is the default and most intuitive for general search.
  contains,

  /// Fuzzy match at the start of the value only.
  ///
  /// Good for autocomplete-style matching where you expect the user
  /// to type from the beginning.
  startsWith,

  /// Each query word must fuzzy-match a word in the value.
  ///
  /// Best for multi-word searches like "John Smith" where both words
  /// should match (with typo tolerance) words in the target.
  wholeWord,

  /// Most permissive - any word in value within distance of any query word.
  ///
  /// Use when you want maximum recall at the cost of precision.
  anywhere,
}

/// {@template mz_collection.fuzzy_search_filter}
/// A search filter with typo tolerance using Levenshtein distance.
///
/// Unlike [SearchFilter] which requires exact substring matches,
/// [FuzzySearchFilter] allows approximate matches based on edit distance.
///
/// ## Configuration
///
/// - [maxDistance]: Maximum allowed edit distance (default: 2)
/// - [minSimilarity]: Minimum similarity ratio 0.0-1.0 (optional alternative)
/// - [strategy]: How matching is applied (default: contains)
/// - [caseSensitive]: Whether matching is case-sensitive (default: false)
///
/// ## Examples
///
/// {@tool snippet}
/// Various FuzzySearchFilter configurations:
///
/// ```dart
/// // Basic usage
/// final filter = FuzzySearchFilter<Product>(
///   valuesRetriever: (p) => [p.name, p.description],
/// );
/// filter.query = 'laptpo';  // Matches "laptop" (distance 1)
///
/// // Stricter matching
/// final strict = FuzzySearchFilter<Product>(
///   valuesRetriever: (p) => [p.name],
///   maxDistance: 1,  // Only allow 1 typo
/// );
///
/// // Word-based matching for names
/// final nameSearch = FuzzySearchFilter<Contact>(
///   valuesRetriever: (c) => [c.fullName],
///   strategy: FuzzyMatchStrategy.wholeWord,
/// );
/// nameSearch.query = 'Jon Smth';  // Matches "John Smith"
/// ```
/// {@end-tool}
/// {@endtemplate}
class FuzzySearchFilter<T> extends Filter<T, String> {
  /// Creates a fuzzy search filter.
  ///
  /// The [valuesRetriever] extracts searchable strings from each item.
  ///
  /// Set [maxDistance] to control typo tolerance (default: 2).
  /// Alternatively, use [minSimilarity] for ratio-based matching.
  ///
  /// The [strategy] determines how matching is applied.
  FuzzySearchFilter({
    required ValuesRetriever<T> valuesRetriever,
    super.id = 'fuzzy_search',
    this.maxDistance = 2,
    this.minSimilarity,
    this.strategy = FuzzyMatchStrategy.contains,
    this.caseSensitive = false,
    super.source = TransformSource.local,
    String? query,
    super.label,
    super.onChanged,
  }) : super(
          test: _createFuzzyTest(
            valuesRetriever,
            maxDistance,
            minSimilarity,
            strategy,
            caseSensitive,
          ),
          singleSelect: true,
        ) {
    if (query != null && query.isNotEmpty) {
      add(query);
    }
  }

  /// Creates a remote-only fuzzy search filter.
  ///
  /// This filter always returns true for [apply] since filtering
  /// happens server-side. Use [query] to get the search string for API calls.
  factory FuzzySearchFilter.remote({
    String id = 'fuzzy_search',
    String? query,
    String? label,
    int maxDistance = 2,
    ValueListener<Filter<T, String>>? onChanged,
  }) {
    return FuzzySearchFilter<T>(
      id: id,
      valuesRetriever: (_) => const [],
      source: TransformSource.remote,
      maxDistance: maxDistance,
      query: query,
      label: label,
      onChanged: onChanged,
    );
  }

  /// Maximum Levenshtein distance allowed for a match.
  ///
  /// Lower values are stricter:
  /// - 0 = exact match only
  /// - 1 = one typo allowed
  /// - 2 = two typos allowed (default)
  /// - 3+ = very permissive
  final int maxDistance;

  /// Minimum similarity ratio (0.0 to 1.0) for a match.
  ///
  /// If set, this takes precedence over [maxDistance] for longer strings.
  /// Similarity is calculated as: 1 - (distance / maxLength)
  ///
  /// - 1.0 = exact match only
  /// - 0.8 = 80% similar (recommended for most uses)
  /// - 0.6 = 60% similar (very permissive)
  final double? minSimilarity;

  /// The matching strategy to use.
  final FuzzyMatchStrategy strategy;

  /// Whether matching is case-sensitive.
  final bool caseSensitive;

  /// The current search query.
  String get query => values.firstOrNull ?? '';
  set query(String value) {
    clear();
    if (value.isNotEmpty) add(value);
  }

  static FilterPredicate<T, String> _createFuzzyTest<T>(
    ValuesRetriever<T> valuesRetriever,
    int maxDistance,
    double? minSimilarity,
    FuzzyMatchStrategy strategy,
    bool caseSensitive,
  ) {
    return (item, query) {
      if (query.isEmpty) return true;

      final queryNorm = caseSensitive ? query : query.toLowerCase();
      final values = valuesRetriever(item).whereType<String>();

      for (final value in values) {
        final valueNorm = caseSensitive ? value : value.toLowerCase();

        if (_fuzzyMatch(
          valueNorm,
          queryNorm,
          maxDistance,
          minSimilarity,
          strategy,
        )) {
          return true;
        }
      }

      return false;
    };
  }

  static bool _fuzzyMatch(
    String value,
    String query,
    int maxDistance,
    double? minSimilarity,
    FuzzyMatchStrategy strategy,
  ) {
    // Empty query matches everything
    if (query.isEmpty) return true;

    // Empty value can't match non-empty query
    if (value.isEmpty) return false;

    switch (strategy) {
      case FuzzyMatchStrategy.contains:
        // Exact substring match is accepted for contains
        if (value.contains(query)) return true;
        return _fuzzyContains(value, query, maxDistance, minSimilarity);

      case FuzzyMatchStrategy.startsWith:
        // Exact prefix match is accepted for startsWith
        if (value.startsWith(query)) return true;
        return _fuzzyStartsWith(value, query, maxDistance, minSimilarity);

      case FuzzyMatchStrategy.wholeWord:
        return _fuzzyWholeWord(value, query, maxDistance, minSimilarity);

      case FuzzyMatchStrategy.anywhere:
        // Exact substring match is accepted for anywhere
        if (value.contains(query)) return true;
        return _fuzzyAnywhere(value, query, maxDistance, minSimilarity);
    }
  }

  /// Contains strategy: check if any word in value fuzzy-matches query.
  static bool _fuzzyContains(
    String value,
    String query,
    int maxDistance,
    double? minSimilarity,
  ) {
    // Split value into words and check each
    final words = _splitIntoWords(value);

    for (final word in words) {
      if (_isWithinDistance(word, query, maxDistance, minSimilarity)) {
        return true;
      }
    }

    // Also check prefix match for partial typing
    if (value.length >= query.length) {
      final prefix = value.substring(0, query.length);
      if (_isWithinDistance(prefix, query, maxDistance, minSimilarity)) {
        return true;
      }
    }

    return false;
  }

  /// StartsWith strategy: fuzzy match at beginning only.
  static bool _fuzzyStartsWith(
    String value,
    String query,
    int maxDistance,
    double? minSimilarity,
  ) {
    // Check the first word of the value
    final words = _splitIntoWords(value);
    if (words.isNotEmpty) {
      if (_isWithinDistance(words.first, query, maxDistance, minSimilarity)) {
        return true;
      }
    }

    // Also check character-based prefix for values without word boundaries
    if (value.length >= query.length) {
      final prefix = value.substring(0, query.length);
      if (_isWithinDistance(prefix, query, maxDistance, minSimilarity)) {
        return true;
      }
    } else {
      // Value shorter than query - check if it's a prefix with tolerance
      if (_isWithinDistance(value, query, maxDistance, minSimilarity)) {
        return true;
      }
    }

    return false;
  }

  /// WholeWord strategy: each query word must match a value word.
  static bool _fuzzyWholeWord(
    String value,
    String query,
    int maxDistance,
    double? minSimilarity,
  ) {
    final queryWords = _splitIntoWords(query);
    final valueWords = _splitIntoWords(value);

    if (queryWords.isEmpty) return true;
    if (valueWords.isEmpty) return false;

    // Each query word must fuzzy-match at least one value word
    for (final qWord in queryWords) {
      var matched = false;
      for (final vWord in valueWords) {
        if (_isWithinDistance(vWord, qWord, maxDistance, minSimilarity)) {
          matched = true;
          break;
        }
      }
      if (!matched) return false;
    }

    return true;
  }

  /// Anywhere strategy: any query word matches any value word.
  static bool _fuzzyAnywhere(
    String value,
    String query,
    int maxDistance,
    double? minSimilarity,
  ) {
    final queryWords = _splitIntoWords(query);
    final valueWords = _splitIntoWords(value);

    if (queryWords.isEmpty) return true;
    if (valueWords.isEmpty) return false;

    // Any query word matching any value word is enough
    for (final qWord in queryWords) {
      for (final vWord in valueWords) {
        if (_isWithinDistance(vWord, qWord, maxDistance, minSimilarity)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Splits text into words (alphanumeric sequences).
  static List<String> _splitIntoWords(String text) {
    return text
        .split(RegExp(r'[\s\-_.,;:!?()]+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  /// Checks if two strings are within the allowed edit distance.
  static bool _isWithinDistance(
    String a,
    String b,
    int maxDistance,
    double? minSimilarity,
  ) {
    final lengthDiff = (a.length - b.length).abs();

    // Quick length check - but only if minSimilarity not set
    // (minSimilarity might still match even with large length differences)
    if (minSimilarity == null && lengthDiff > maxDistance) {
      return false;
    }

    // Calculate actual distance
    final distance = levenshteinDistance(a, b);

    // Check against max distance
    if (distance <= maxDistance) return true;

    // Check against similarity ratio if specified
    if (minSimilarity != null) {
      final maxLen = math.max(a.length, b.length);
      if (maxLen == 0) return true;
      final sim = 1.0 - (distance / maxLen);
      return sim >= minSimilarity;
    }

    return false;
  }

  @override
  String toString() =>
      'FuzzySearchFilter(id: $id, query: $query, maxDistance: $maxDistance)';
}

// =============================================================================
// Fuzzy Matching Algorithms
// =============================================================================

/// Computes the Levenshtein distance between two strings.
///
/// The Levenshtein distance is the minimum number of single-character edits
/// (insertions, deletions, substitutions) required to change one string
/// into the other.
///
/// ## Examples
///
/// {@tool snippet}
/// Computing edit distance between strings:
///
/// ```dart
/// levenshteinDistance('kitten', 'sitting'); // 3
/// levenshteinDistance('hello', 'helo');     // 1
/// levenshteinDistance('abc', 'abc');        // 0
/// ```
/// {@end-tool}
///
/// ## Performance
///
/// Time complexity: O(m * n) where m and n are string lengths.
/// Space complexity: O(min(m, n)) using optimized single-row approach.
int levenshteinDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  // Ensure shorter is the shorter string for space optimization
  final shorter = a.length <= b.length ? a : b;
  final longer = a.length > b.length ? a : b;

  final m = shorter.length;
  final n = longer.length;

  // Use single row optimization - O(min(m,n)) space instead of O(m*n)
  var previousRow = List<int>.generate(m + 1, (i) => i);
  var currentRow = List<int>.filled(m + 1, 0);

  for (var j = 1; j <= n; j++) {
    currentRow[0] = j;

    for (var i = 1; i <= m; i++) {
      final cost = shorter[i - 1] == longer[j - 1] ? 0 : 1;

      currentRow[i] = _min3(
        previousRow[i] + 1, // deletion
        currentRow[i - 1] + 1, // insertion
        previousRow[i - 1] + cost, // substitution
      );
    }

    // Swap rows
    final temp = previousRow;
    previousRow = currentRow;
    currentRow = temp;
  }

  return previousRow[m];
}

/// Computes the similarity ratio between two strings.
///
/// Returns a value between 0.0 (completely different) and 1.0 (identical).
///
/// Formula: 1 - (levenshteinDistance / maxLength)
///
/// {@tool snippet}
/// Computing similarity ratio:
///
/// ```dart
/// similarity('hello', 'hello'); // 1.0
/// similarity('hello', 'helo');  // 0.8 (1 edit out of 5)
/// similarity('abc', 'xyz');     // 0.0
/// ```
/// {@end-tool}
double similarity(String a, String b) {
  if (a == b) return 1;

  final maxLen = math.max(a.length, b.length);
  if (maxLen == 0) return 1;

  final distance = levenshteinDistance(a, b);
  return 1 - (distance / maxLen);
}

/// Computes Damerau-Levenshtein distance (includes transpositions).
///
/// Like Levenshtein but also counts adjacent character swaps as single edits.
/// Better for keyboard typos like "teh" -> "the".
///
/// {@tool snippet}
/// Comparing Damerau-Levenshtein vs Levenshtein:
///
/// ```dart
/// damerauLevenshteinDistance('teh', 'the');  // 1 (transposition)
/// levenshteinDistance('teh', 'the');         // 2 (delete + insert)
/// ```
/// {@end-tool}
int damerauLevenshteinDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final m = a.length;
  final n = b.length;

  // Need full matrix for transposition detection
  final d = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

  for (var i = 0; i <= m; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= n; j++) {
    d[0][j] = j;
  }

  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;

      d[i][j] = _min3(
        d[i - 1][j] + 1, // deletion
        d[i][j - 1] + 1, // insertion
        d[i - 1][j - 1] + cost, // substitution
      );

      // Transposition
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        d[i][j] = math.min(d[i][j], d[i - 2][j - 2] + cost);
      }
    }
  }

  return d[m][n];
}

/// Finds the best fuzzy match for a query in a list of candidates.
///
/// Returns the candidate with the lowest edit distance, or null if
/// all candidates exceed [maxDistance].
///
/// {@tool snippet}
/// Finding the best match from candidates:
///
/// ```dart
/// final best = findBestMatch('jonh', ['John', 'Jane', 'Bob']);
/// print(best?.candidate); // 'John'
/// print(best?.distance);  // 1
/// ```
/// {@end-tool}
FuzzyMatch? findBestMatch(
  String query,
  Iterable<String> candidates, {
  int? maxDistance,
  bool caseSensitive = false,
}) {
  final queryNorm = caseSensitive ? query : query.toLowerCase();
  FuzzyMatch? best;

  for (final candidate in candidates) {
    final candidateNorm = caseSensitive ? candidate : candidate.toLowerCase();
    final distance = levenshteinDistance(queryNorm, candidateNorm);

    if (maxDistance != null && distance > maxDistance) continue;

    if (best == null || distance < best.distance) {
      best = FuzzyMatch(candidate: candidate, distance: distance);
    }

    // Early exit on exact match
    if (distance == 0) break;
  }

  return best;
}

/// Finds all fuzzy matches for a query in a list of candidates.
///
/// Returns matches sorted by distance (best first).
///
/// {@tool snippet}
/// Finding all matches within distance:
///
/// ```dart
/// final matches = findAllMatches('jon', ['John', 'Jane', 'Jonathan']);
/// // Returns: [FuzzyMatch('John', 1), FuzzyMatch('Jonathan', 4)]
/// ```
/// {@end-tool}
List<FuzzyMatch> findAllMatches(
  String query,
  Iterable<String> candidates, {
  int maxDistance = 2,
  bool caseSensitive = false,
}) {
  final queryNorm = caseSensitive ? query : query.toLowerCase();
  final matches = <FuzzyMatch>[];

  for (final candidate in candidates) {
    final candidateNorm = caseSensitive ? candidate : candidate.toLowerCase();
    final distance = levenshteinDistance(queryNorm, candidateNorm);

    if (distance <= maxDistance) {
      matches.add(FuzzyMatch(candidate: candidate, distance: distance));
    }
  }

  // Sort by distance (best matches first)
  matches.sort((a, b) => a.distance.compareTo(b.distance));

  return matches;
}

/// Result of a fuzzy match operation.
class FuzzyMatch {
  /// Creates a fuzzy match result.
  const FuzzyMatch({
    required this.candidate,
    required this.distance,
  });

  /// The matched string.
  final String candidate;

  /// The edit distance from the query.
  final int distance;

  /// The similarity ratio (0.0 to 1.0).
  double get similarity => 1.0 - (distance / candidate.length);

  @override
  String toString() => 'FuzzyMatch($candidate, distance: $distance)';
}

/// Result of a substring fuzzy match with position information.
///
/// Used by [findBestSubstringMatch] to return both the matched text
/// and its location within the source string.
class SubstringMatch {
  /// Creates a substring match result.
  const SubstringMatch({
    required this.start,
    required this.end,
    required this.distance,
    required this.matchedText,
  });

  /// Start index of the match in the source string.
  final int start;

  /// End index (exclusive) of the match in the source string.
  final int end;

  /// The edit distance from the query.
  final int distance;

  /// The actual text that was matched.
  final String matchedText;

  /// Whether this is an exact match (distance == 0).
  bool get isExact => distance == 0;

  /// The similarity ratio (0.0 to 1.0).
  double get similarity {
    final maxLen = math.max(matchedText.length, end - start);
    if (maxLen == 0) return 1;
    return 1 - (distance / maxLen);
  }

  @override
  String toString() =>
      'SubstringMatch("$matchedText", [$start:$end], distance: $distance)';
}

/// Finds the best fuzzy matching substring within [text] for [query].
///
/// Returns the position and details of the best match, or null if no match
/// is found within [maxDistance].
///
/// This is useful for highlighting matched text in UI:
///
/// {@tool snippet}
/// Finding and highlighting matched text:
///
/// ```dart
/// final match = findBestSubstringMatch('Hello World', 'wrld', maxDistance: 1);
/// if (match != null) {
///   final before = text.substring(0, match.start);
///   final matched = text.substring(match.start, match.end);
///   final after = text.substring(match.end);
///   // Build highlighted text span...
/// }
/// ```
/// {@end-tool}
///
/// ## Matching Strategy
///
/// 1. First checks for exact substring match (fastest path)
/// 2. Then checks each word boundary for fuzzy matches
/// 3. Finally uses sliding window for partial matches
///
/// ## Parameters
///
/// - [text]: The text to search within
/// - [query]: The search query
/// - [maxDistance]: Maximum edit distance allowed (default: 2)
/// - [caseSensitive]: Whether matching is case-sensitive (default: false)
SubstringMatch? findBestSubstringMatch(
  String text,
  String query, {
  int maxDistance = 2,
  bool caseSensitive = false,
}) {
  if (query.isEmpty || text.isEmpty) return null;

  final textNorm = caseSensitive ? text : text.toLowerCase();
  final queryNorm = caseSensitive ? query : query.toLowerCase();

  // Fast path: exact substring match
  final exactIndex = textNorm.indexOf(queryNorm);
  if (exactIndex != -1) {
    return SubstringMatch(
      start: exactIndex,
      end: exactIndex + query.length,
      distance: 0,
      matchedText: text.substring(exactIndex, exactIndex + query.length),
    );
  }

  SubstringMatch? bestMatch;
  var bestDistance = maxDistance + 1;

  // Check word boundaries for better semantic matches
  final wordPattern = RegExp(r'\S+');
  for (final wordMatch in wordPattern.allMatches(text)) {
    final word = text.substring(wordMatch.start, wordMatch.end);
    final wordNorm = caseSensitive ? word : word.toLowerCase();
    final distance = levenshteinDistance(wordNorm, queryNorm);

    if (distance <= maxDistance && distance < bestDistance) {
      bestDistance = distance;
      bestMatch = SubstringMatch(
        start: wordMatch.start,
        end: wordMatch.end,
        distance: distance,
        matchedText: word,
      );

      // Early exit on exact word match
      if (distance == 0) return bestMatch;
    }
  }

  // Sliding window for partial/substring matches
  final minLen = math.max(1, (query.length * 0.7).floor());
  final maxLen = math.min(text.length, (query.length * 1.3).ceil());

  for (var windowSize = minLen; windowSize <= maxLen; windowSize++) {
    for (var i = 0; i <= text.length - windowSize; i++) {
      final substring = textNorm.substring(i, i + windowSize);
      final distance = levenshteinDistance(substring, queryNorm);

      if (distance <= maxDistance && distance < bestDistance) {
        bestDistance = distance;
        bestMatch = SubstringMatch(
          start: i,
          end: i + windowSize,
          distance: distance,
          matchedText: text.substring(i, i + windowSize),
        );

        // Early exit on exact match
        if (distance == 0) return bestMatch;
      }
    }
  }

  return bestMatch;
}

/// Finds all fuzzy matching substrings within [text] for [query].
///
/// Returns all matches sorted by distance (best first). Useful when you
/// want to highlight all occurrences of a fuzzy match.
///
/// {@tool snippet}
/// Finding all substring matches for highlighting:
///
/// ```dart
/// final matches = findAllSubstringMatches(
///   'John met Jon and Jonathan',
///   'john',
///   maxDistance: 1,
/// );
/// // Returns matches for "John" and "Jon"
/// ```
/// {@end-tool}
///
/// Note: Overlapping matches are included. Use [findBestSubstringMatch]
/// if you only need the single best match.
List<SubstringMatch> findAllSubstringMatches(
  String text,
  String query, {
  int maxDistance = 2,
  bool caseSensitive = false,
}) {
  if (query.isEmpty || text.isEmpty) return const [];

  final textNorm = caseSensitive ? text : text.toLowerCase();
  final queryNorm = caseSensitive ? query : query.toLowerCase();
  final matches = <SubstringMatch>[];
  final seenPositions = <int>{};

  // Check exact substring matches
  var searchStart = 0;
  while (true) {
    final index = textNorm.indexOf(queryNorm, searchStart);
    if (index == -1) break;

    if (!seenPositions.contains(index)) {
      seenPositions.add(index);
      matches.add(
        SubstringMatch(
          start: index,
          end: index + query.length,
          distance: 0,
          matchedText: text.substring(index, index + query.length),
        ),
      );
    }
    searchStart = index + 1;
  }

  // Check word boundaries
  final wordPattern = RegExp(r'\S+');
  for (final wordMatch in wordPattern.allMatches(text)) {
    if (seenPositions.contains(wordMatch.start)) continue;

    final word = text.substring(wordMatch.start, wordMatch.end);
    final wordNorm = caseSensitive ? word : word.toLowerCase();
    final distance = levenshteinDistance(wordNorm, queryNorm);

    if (distance <= maxDistance && distance > 0) {
      seenPositions.add(wordMatch.start);
      matches.add(
        SubstringMatch(
          start: wordMatch.start,
          end: wordMatch.end,
          distance: distance,
          matchedText: word,
        ),
      );
    }
  }

  // Sort by distance (best first), then by position
  matches.sort((a, b) {
    final distCmp = a.distance.compareTo(b.distance);
    if (distCmp != 0) return distCmp;
    return a.start.compareTo(b.start);
  });

  return matches;
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Returns the minimum of three integers.
@pragma('vm:prefer-inline')
int _min3(int a, int b, int c) {
  if (a <= b && a <= c) return a;
  if (b <= c) return b;
  return c;
}
