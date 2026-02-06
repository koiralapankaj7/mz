import 'package:mz_collection/mz_collection.dart';
import 'package:test/test.dart';

void main() {
  group('levenshteinDistance', () {
    test('returns 0 for identical strings', () {
      expect(levenshteinDistance('hello', 'hello'), equals(0));
      expect(levenshteinDistance('', ''), equals(0));
      expect(levenshteinDistance('abc', 'abc'), equals(0));
    });

    test('returns length of other string when one is empty', () {
      expect(levenshteinDistance('', 'hello'), equals(5));
      expect(levenshteinDistance('hello', ''), equals(5));
      expect(levenshteinDistance('', 'abc'), equals(3));
    });

    test('returns 1 for single character difference', () {
      expect(levenshteinDistance('hello', 'helo'), equals(1)); // deletion
      expect(levenshteinDistance('hello', 'helloo'), equals(1)); // insertion
      expect(levenshteinDistance('hello', 'hallo'), equals(1)); // substitution
    });

    test('handles insertions', () {
      expect(levenshteinDistance('abc', 'abcd'), equals(1));
      expect(levenshteinDistance('abc', 'abcde'), equals(2));
      expect(levenshteinDistance('abc', 'xabc'), equals(1));
    });

    test('handles deletions', () {
      expect(levenshteinDistance('abcd', 'abc'), equals(1));
      expect(levenshteinDistance('abcde', 'abc'), equals(2));
      expect(levenshteinDistance('xabc', 'abc'), equals(1));
    });

    test('handles substitutions', () {
      expect(levenshteinDistance('abc', 'axc'), equals(1));
      expect(levenshteinDistance('abc', 'xyz'), equals(3));
      expect(levenshteinDistance('kitten', 'sitten'), equals(1));
    });

    test('classic example: kitten to sitting', () {
      expect(levenshteinDistance('kitten', 'sitting'), equals(3));
    });

    test('is symmetric', () {
      expect(
        levenshteinDistance('abc', 'xyz'),
        equals(levenshteinDistance('xyz', 'abc')),
      );
      expect(
        levenshteinDistance('hello', 'hallo'),
        equals(levenshteinDistance('hallo', 'hello')),
      );
    });

    test('handles mixed operations', () {
      expect(levenshteinDistance('intention', 'execution'), equals(5));
      expect(levenshteinDistance('saturday', 'sunday'), equals(3));
    });

    test('satisfies triangle inequality', () {
      // d(a,c) <= d(a,b) + d(b,c) for all strings a, b, c
      final strings = ['abc', 'abd', 'acd', 'bcd'];
      for (final a in strings) {
        for (final b in strings) {
          for (final c in strings) {
            final dAC = levenshteinDistance(a, c);
            final dAB = levenshteinDistance(a, b);
            final dBC = levenshteinDistance(b, c);
            expect(
              dAC <= dAB + dBC,
              isTrue,
              reason:
                  'd($a,$c)=$dAC should be <= d($a,$b)+d($b,$c)=${dAB + dBC}',
            );
          }
        }
      }
    });

    test('handles very long strings', () {
      final longString = 'a' * 1000;
      final similarString = 'a' * 999 + 'b';
      expect(levenshteinDistance(longString, similarString), equals(1));
    });

    test('handles strings with only spaces', () {
      expect(levenshteinDistance('   ', '  '), equals(1));
    });
  });

  group('damerauLevenshteinDistance', () {
    test('returns 0 for identical strings', () {
      expect(damerauLevenshteinDistance('hello', 'hello'), equals(0));
      expect(damerauLevenshteinDistance('', ''), equals(0));
    });

    test('returns length of other string when one is empty', () {
      expect(damerauLevenshteinDistance('', 'hello'), equals(5));
      expect(damerauLevenshteinDistance('hello', ''), equals(5));
    });

    test('counts transpositions as 1 edit', () {
      expect(damerauLevenshteinDistance('teh', 'the'), equals(1));
      expect(damerauLevenshteinDistance('ab', 'ba'), equals(1));
      expect(damerauLevenshteinDistance('abc', 'bac'), equals(1));
    });

    test('is lower than Levenshtein for transpositions', () {
      // Levenshtein would count 'teh' -> 'the' as 2 (delete + insert)
      expect(levenshteinDistance('teh', 'the'), equals(2));
      expect(damerauLevenshteinDistance('teh', 'the'), equals(1));
    });

    test('handles other operations like Levenshtein', () {
      expect(damerauLevenshteinDistance('kitten', 'sitting'), equals(3));
      expect(damerauLevenshteinDistance('hello', 'hallo'), equals(1));
    });

    test('matches Levenshtein when no transpositions', () {
      // Non-transposition cases should match standard Levenshtein
      final cases = [
        ('kitten', 'sitting'),
        ('abc', 'def'),
        ('hello', 'world'),
        ('test', 'testing'),
      ];
      for (final (s1, s2) in cases) {
        expect(
          damerauLevenshteinDistance(s1, s2),
          equals(levenshteinDistance(s1, s2)),
          reason: '"$s1" vs "$s2" should have same distance',
        );
      }
    });
  });

  group('similarity', () {
    test('returns 1.0 for identical strings', () {
      expect(similarity('hello', 'hello'), equals(1.0));
      expect(similarity('', ''), equals(1.0));
      expect(similarity('abc', 'abc'), equals(1.0));
    });

    test('returns 0.0 for completely different strings', () {
      expect(similarity('abc', 'xyz'), equals(0.0));
    });

    test('returns correct ratio for partial matches', () {
      // hello vs helo: 1 edit out of 5 chars = 0.8 similarity
      expect(similarity('hello', 'helo'), equals(0.8));

      // hello vs hallo: 1 edit out of 5 chars = 0.8 similarity
      expect(similarity('hello', 'hallo'), equals(0.8));
    });

    test('handles empty vs non-empty', () {
      // 5 edits out of 5 chars = 0.0 similarity
      expect(similarity('', 'hello'), equals(0.0));
      expect(similarity('hello', ''), equals(0.0));
    });

    test('partial matches have correct ratio', () {
      // 'abcdef' vs 'abcxyz' = 3 edits / 6 chars = 0.5 similarity
      expect(similarity('abcdef', 'abcxyz'), closeTo(0.5, 0.01));
    });
  });

  group('findBestMatch', () {
    test('returns exact match with distance 0', () {
      final result = findBestMatch('hello', ['hello', 'world', 'help']);
      expect(result, isNotNull);
      expect(result!.candidate, equals('hello'));
      expect(result.distance, equals(0));
    });

    test('returns closest match', () {
      final result = findBestMatch('helo', ['hello', 'world', 'help']);
      expect(result, isNotNull);
      expect(result!.candidate, equals('hello'));
      expect(result.distance, equals(1));
    });

    test('returns null when all exceed maxDistance', () {
      final result = findBestMatch(
        'xyz',
        ['hello', 'world'],
        maxDistance: 1,
      );
      expect(result, isNull);
    });

    test('is case insensitive by default', () {
      final result = findBestMatch('HELLO', ['hello', 'world']);
      expect(result, isNotNull);
      expect(result!.candidate, equals('hello'));
      expect(result.distance, equals(0));
    });

    test('can be case sensitive', () {
      final result = findBestMatch(
        'HELLO',
        ['hello', 'HELLO'],
        caseSensitive: true,
      );
      expect(result, isNotNull);
      expect(result!.candidate, equals('HELLO'));
      expect(result.distance, equals(0));
    });

    test('returns null for empty candidates', () {
      final result = findBestMatch('hello', []);
      expect(result, isNull);
    });
  });

  group('findAllMatches', () {
    test('returns all matches within distance', () {
      final matches = findAllMatches('helo', ['hello', 'help', 'world']);
      expect(matches, hasLength(2));
      expect(matches.map((m) => m.candidate), containsAll(['hello', 'help']));
    });

    test('returns matches sorted by distance', () {
      final matches = findAllMatches('hello', ['helo', 'hello', 'hallo']);
      expect(matches, hasLength(3));
      expect(matches[0].candidate, equals('hello'));
      expect(matches[0].distance, equals(0));
      expect(matches[1].distance, equals(1));
      expect(matches[2].distance, equals(1));
    });

    test('respects maxDistance parameter', () {
      final matches = findAllMatches(
        'hello',
        ['helo', 'world', 'help'],
        maxDistance: 1,
      );
      expect(matches, hasLength(1));
      expect(matches[0].candidate, equals('helo'));
    });

    test('returns empty list when no matches', () {
      final matches = findAllMatches('xyz', ['hello', 'world'], maxDistance: 1);
      expect(matches, isEmpty);
    });

    test('is case insensitive by default', () {
      final matches = findAllMatches('HELLO', ['hello', 'HELP']);
      expect(matches, hasLength(2));
    });
  });

  group('FuzzyMatch', () {
    test('stores candidate and distance', () {
      const match = FuzzyMatch(candidate: 'hello', distance: 1);
      expect(match.candidate, equals('hello'));
      expect(match.distance, equals(1));
    });

    test('calculates similarity', () {
      const match = FuzzyMatch(candidate: 'hello', distance: 1);
      expect(match.similarity, equals(0.8)); // 1 - 1/5
    });

    test('toString returns formatted string', () {
      const match = FuzzyMatch(candidate: 'hello', distance: 2);
      expect(match.toString(), contains('hello'));
      expect(match.toString(), contains('2'));
    });
  });

  group('SubstringMatch', () {
    test('stores all properties correctly', () {
      const match = SubstringMatch(
        start: 5,
        end: 10,
        distance: 1,
        matchedText: 'hello',
      );
      expect(match.start, equals(5));
      expect(match.end, equals(10));
      expect(match.distance, equals(1));
      expect(match.matchedText, equals('hello'));
    });

    test('isExact returns true when distance is 0', () {
      const exactMatch = SubstringMatch(
        start: 0,
        end: 5,
        distance: 0,
        matchedText: 'hello',
      );
      expect(exactMatch.isExact, isTrue);

      const fuzzyMatch = SubstringMatch(
        start: 0,
        end: 5,
        distance: 1,
        matchedText: 'hello',
      );
      expect(fuzzyMatch.isExact, isFalse);
    });

    test('similarity calculates correct ratio', () {
      const match = SubstringMatch(
        start: 0,
        end: 5,
        distance: 1,
        matchedText: 'hello',
      );
      // 1 - (1 / 5) = 0.8
      expect(match.similarity, equals(0.8));
    });

    test('similarity returns 1.0 for empty matched text with no distance', () {
      const match = SubstringMatch(
        start: 0,
        end: 0,
        distance: 0,
        matchedText: '',
      );
      // maxLen = max(0, 0) = 0, so returns 1.0
      expect(match.similarity, equals(1.0));
    });

    test('toString returns formatted string with position info', () {
      const match = SubstringMatch(
        start: 5,
        end: 10,
        distance: 1,
        matchedText: 'hello',
      );
      final str = match.toString();
      expect(str, contains('hello'));
      expect(str, contains('5'));
      expect(str, contains('10'));
      expect(str, contains('1'));
    });
  });

  group('findBestSubstringMatch', () {
    test('returns null for empty query', () {
      final result = findBestSubstringMatch('hello world', '');
      expect(result, isNull);
    });

    test('returns null for empty text', () {
      final result = findBestSubstringMatch('', 'hello');
      expect(result, isNull);
    });

    test('finds exact substring match', () {
      final result = findBestSubstringMatch('hello world', 'world');
      expect(result, isNotNull);
      expect(result!.matchedText, equals('world'));
      expect(result.distance, equals(0));
      expect(result.start, equals(6));
      expect(result.end, equals(11));
    });

    test('finds fuzzy match at word boundary', () {
      final result = findBestSubstringMatch(
        'hello world',
        'wrld',
        maxDistance: 1,
      );
      expect(result, isNotNull);
      expect(result!.matchedText, equals('world'));
      expect(result.distance, equals(1));
    });

    test('returns null when no match within distance', () {
      final result = findBestSubstringMatch(
        'hello world',
        'xyz',
        maxDistance: 1,
      );
      expect(result, isNull);
    });

    test('is case insensitive by default', () {
      final result = findBestSubstringMatch('Hello World', 'HELLO');
      expect(result, isNotNull);
      expect(result!.matchedText, equals('Hello'));
      expect(result.distance, equals(0));
    });

    test('can be case sensitive', () {
      final result = findBestSubstringMatch(
        'Hello World',
        'hello',
        maxDistance: 0, // Require exact match
        caseSensitive: true,
      );
      // Won't find exact match due to case difference
      expect(result, isNull);
    });

    test('finds partial matches via sliding window', () {
      final result = findBestSubstringMatch(
        'programming',
        'gram',
        maxDistance: 0,
      );
      expect(result, isNotNull);
      expect(result!.matchedText, equals('gram'));
      expect(result.distance, equals(0));
    });

    test('finds fuzzy match via sliding window when no exact match exists', () {
      // 'rogrammin' is not a word and not an exact substring.
      // Sliding window finds 'rogram' which is close to 'rogran' (1 edit).
      final result = findBestSubstringMatch(
        'programming',
        'rogran', // Not exact substring, needs sliding window
        maxDistance: 1,
      );
      expect(result, isNotNull);
      expect(result!.distance, lessThanOrEqualTo(1));
    });

    test('sliding window finds exact match in middle of text', () {
      // A query that's not a word but exists as exact substring
      // The fast path should find this
      final result = findBestSubstringMatch(
        'abcdefghij',
        'cdef',
        maxDistance: 0,
      );
      expect(result, isNotNull);
      expect(result!.matchedText, equals('cdef'));
      expect(result.distance, equals(0));
    });

    test('sliding window early exit on exact match', () {
      // Query that requires sliding window and finds exact match
      // 'bcde' is not a word but is an exact substring
      final result = findBestSubstringMatch(
        'abcdefgh',
        'bcde',
      );
      expect(result, isNotNull);
      expect(result!.matchedText, equals('bcde'));
      expect(result.distance, equals(0));
    });

    test('sliding window finds fuzzy match in single continuous text', () {
      // Text with no word boundaries, query not exact substring.
      // 'abcde' is close to 'abcdf' (1 edit).
      final result = findBestSubstringMatch(
        'abcdefghij', // Single word, no spaces
        'abcdf', // Not exact substring, 1 edit from 'abcde'
        maxDistance: 1,
      );
      expect(result, isNotNull);
      expect(result!.distance, lessThanOrEqualTo(1));
    });

    test('sliding window creates match when word boundary gives worse result',
        () {
      // The whole text is one word, sliding window should find partial match
      final result = findBestSubstringMatch(
        'thequickbrownfox',
        'quikc', // Typo for 'quick', not exact substring
      );
      expect(result, isNotNull);
      expect(result!.distance, lessThanOrEqualTo(2));
    });

    test('returns best match when multiple words qualify', () {
      final result = findBestSubstringMatch(
        'John met Jon',
        'Jon',
        maxDistance: 1,
      );
      expect(result, isNotNull);
      // Should find 'Jon' exactly (distance 0) rather than 'John' (distance 1)
      expect(result!.distance, equals(0));
      expect(result.matchedText, equals('Jon'));
    });

    test('finds match via word boundary with exact word match', () {
      final result = findBestSubstringMatch(
        'The quick brown fox',
        'quick',
        maxDistance: 0,
      );
      expect(result, isNotNull);
      expect(result!.matchedText, equals('quick'));
      expect(result.distance, equals(0));
    });
  });

  group('findAllSubstringMatches', () {
    test('returns empty list for empty query', () {
      final result = findAllSubstringMatches('hello world', '');
      expect(result, isEmpty);
    });

    test('returns empty list for empty text', () {
      final result = findAllSubstringMatches('', 'hello');
      expect(result, isEmpty);
    });

    test('finds all exact matches', () {
      final result = findAllSubstringMatches(
        'John met John again',
        'John',
        maxDistance: 0,
      );
      expect(result, hasLength(2));
      expect(result.every((m) => m.distance == 0), isTrue);
      expect(result.every((m) => m.matchedText == 'John'), isTrue);
    });

    test('finds fuzzy matches at word boundaries', () {
      final result = findAllSubstringMatches(
        'John met Jon and Jonathan',
        'john',
        maxDistance: 1,
      );
      // Should find 'John' (exact) and 'Jon' (distance 1)
      expect(result.length, greaterThanOrEqualTo(2));
      expect(result.any((m) => m.matchedText == 'John'), isTrue);
      expect(result.any((m) => m.matchedText == 'Jon'), isTrue);
    });

    test('returns matches sorted by distance then position', () {
      final result = findAllSubstringMatches(
        'Jon met John',
        'john',
        maxDistance: 1,
      );
      // Exact match 'John' should come before fuzzy match 'Jon'
      expect(result.first.distance, lessThanOrEqualTo(result.last.distance));
    });

    test('is case insensitive by default', () {
      final result = findAllSubstringMatches(
        'Hello HELLO HeLLo',
        'hello',
        maxDistance: 0,
      );
      expect(result, hasLength(3));
    });

    test('can be case sensitive', () {
      final result = findAllSubstringMatches(
        'Hello HELLO HeLLo',
        'Hello',
        maxDistance: 0,
        caseSensitive: true,
      );
      expect(result, hasLength(1));
      expect(result.first.matchedText, equals('Hello'));
    });

    test('respects maxDistance parameter', () {
      final result = findAllSubstringMatches(
        'hello helo heo',
        'hello',
        maxDistance: 1,
      );
      // 'hello' (0 distance) and 'helo' (1 distance) should match
      // 'heo' (2 distance) should not match
      expect(result.every((m) => m.distance <= 1), isTrue);
    });

    test('does not duplicate matches at same position', () {
      final result = findAllSubstringMatches(
        'test test',
        'test',
        maxDistance: 0,
      );
      // Should have 2 matches at different positions
      final positions = result.map((m) => m.start).toSet();
      expect(positions.length, equals(result.length));
    });
  });

  group('FuzzySearchFilter', () {
    group('basic functionality', () {
      test('matches exact strings', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
        );
        filter.query = 'hello';

        expect(filter.apply('hello'), isTrue);
        expect(filter.apply('world'), isFalse);
      });

      test('matches with typos within maxDistance', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
        );
        filter.query = 'hello';

        expect(filter.apply('helo'), isTrue); // 1 typo
        expect(filter.apply('hllo'), isTrue); // 1 typo
        expect(filter.apply('heo'), isTrue); // 2 typos
        expect(filter.apply('xyz'), isFalse); // too different
      });

      test('empty query matches everything', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
        );
        filter.query = '';

        expect(filter.apply('anything'), isTrue);
        expect(filter.apply(''), isTrue);
      });

      test('is case insensitive by default', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
        );
        filter.query = 'hello';

        expect(filter.apply('HELLO'), isTrue);
        expect(filter.apply('HeLLo'), isTrue);
      });

      test('can be case sensitive', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          caseSensitive: true,
        );
        filter.query = 'hello';

        expect(filter.apply('hello'), isTrue);
        expect(filter.apply('HELLO'), isFalse);
      });
    });

    group('query property', () {
      test('get returns current query', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          query: 'test',
        );

        expect(filter.query, equals('test'));
      });

      test('set updates the query', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
        );

        filter.query = 'hello';
        expect(filter.query, equals('hello'));

        filter.query = 'world';
        expect(filter.query, equals('world'));
      });

      test('set empty clears the query', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          query: 'hello',
        );

        filter.query = '';
        expect(filter.query, isEmpty);
      });
    });

    group('FuzzyMatchStrategy.contains', () {
      late FuzzySearchFilter<String> filter;

      setUp(() {
        filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
        );
      });

      test('matches substring exactly', () {
        filter.query = 'test';
        expect(filter.apply('this is a test'), isTrue);
        expect(filter.apply('testing'), isTrue);
      });

      test('fuzzy matches words', () {
        filter.query = 'tset'; // typo
        expect(filter.apply('test'), isTrue);
      });

      test('fuzzy matches prefix', () {
        filter.query = 'helo';
        expect(filter.apply('hello world'), isTrue);
      });
    });

    group('FuzzyMatchStrategy.startsWith', () {
      late FuzzySearchFilter<String> filter;

      setUp(() {
        filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          strategy: FuzzyMatchStrategy.startsWith,
          maxDistance: 1,
        );
      });

      test('matches exact prefix', () {
        filter.query = 'hello';
        expect(filter.apply('hello world'), isTrue);
        expect(filter.apply('world hello'), isFalse);
      });

      test('fuzzy matches prefix', () {
        filter.query = 'helo';
        expect(filter.apply('hello world'), isTrue);
      });

      test('does not match suffix', () {
        filter.query = 'world';
        expect(filter.apply('hello world'), isFalse);
      });

      test('handles value shorter than query with tolerance', () {
        // Query is longer than value - test the else branch in _fuzzyStartsWith
        final shortFilter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          strategy: FuzzyMatchStrategy.startsWith,
        );
        shortFilter.query = 'hello';
        // Value 'hel' is shorter than query 'hello' - 2 edits away
        expect(shortFilter.apply('hel'), isTrue);
      });

      test('rejects value shorter than query when too many edits needed', () {
        final strictFilter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          strategy: FuzzyMatchStrategy.startsWith,
          maxDistance: 1,
        );
        strictFilter.query = 'hello';
        // Value 'he' is shorter than query 'hello' - 3 edits away
        expect(strictFilter.apply('he'), isFalse);
      });
    });

    group('FuzzyMatchStrategy.wholeWord', () {
      late FuzzySearchFilter<String> filter;

      setUp(() {
        filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          strategy: FuzzyMatchStrategy.wholeWord,
        );
      });

      test('requires all query words to match', () {
        filter.query = 'john smith';
        expect(filter.apply('john smith'), isTrue);
        expect(filter.apply('john'), isFalse); // missing smith
        expect(filter.apply('smith'), isFalse); // missing john
      });

      test('fuzzy matches individual words', () {
        filter.query = 'jonh smth'; // typos (2 edits each)
        expect(filter.apply('john smith'), isTrue);
      });

      test('order does not matter', () {
        filter.query = 'smith john';
        expect(filter.apply('john smith'), isTrue);
      });

      test('strict mode rejects large differences', () {
        final strictFilter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          strategy: FuzzyMatchStrategy.wholeWord,
          maxDistance: 1,
        );
        strictFilter.query = 'xyz';
        // 'xyz' -> 'john' requires many edits, so fails
        expect(strictFilter.apply('john'), isFalse);
      });
    });

    group('FuzzyMatchStrategy.anywhere', () {
      late FuzzySearchFilter<String> filter;

      setUp(() {
        filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          strategy: FuzzyMatchStrategy.anywhere,
        );
      });

      test('matches if any query word matches any value word', () {
        filter.query = 'john xyz';
        expect(filter.apply('john smith'), isTrue);
        expect(filter.apply('abc def'), isFalse);
      });

      test('fuzzy matches words', () {
        filter.query = 'jonh'; // 2 edits from 'john'
        expect(filter.apply('john smith'), isTrue);
      });

      test('strict matching rejects too many typos', () {
        final strictFilter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          strategy: FuzzyMatchStrategy.anywhere,
          maxDistance: 1,
        );
        strictFilter.query = 'xyz';
        expect(strictFilter.apply('john smith'), isFalse);
      });
    });

    group('minSimilarity', () {
      test('uses similarity ratio instead of distance', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          maxDistance: 0, // Would normally require exact match
          minSimilarity: 0.7, // But allow 70% similar
        );

        filter.query = 'hello';
        expect(filter.apply('hello'), isTrue); // exact match
        // 'helo' vs 'hello' = 1 edit / 5 chars = 0.8 similarity
        // But maxDistance=0 fails first, then minSimilarity kicks in
        expect(filter.apply('helo'), isTrue); // 80% similar
        expect(filter.apply('xyz'), isFalse); // too different
      });

      test('minSimilarity works with longer strings', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          maxDistance: 1, // Low distance
          minSimilarity: 0.8, // Allow 80% similar
        );

        filter.query = 'programming';
        // 'programing' = 1 edit / 11 chars = 0.91 similarity
        expect(filter.apply('programing'), isTrue);
      });
    });

    group('multiple values', () {
      test('matches if any value matches', () {
        final filter = FuzzySearchFilter<_Person>(
          valuesRetriever: (p) => [p.name, p.email],
          maxDistance: 1, // Use strict distance to avoid false positives
        );

        filter.query = 'john';
        expect(
          filter.apply(_Person(name: 'john', email: 'test@test.com')),
          isTrue,
        );
        expect(
          filter.apply(_Person(name: 'jane', email: 'john@test.com')),
          isTrue,
        );
        expect(
          filter.apply(_Person(name: 'alice', email: 'alice@test.com')),
          isFalse,
        );
      });

      test('fuzzy matches across values', () {
        final filter = FuzzySearchFilter<_Person>(
          valuesRetriever: (p) => [p.name, p.email],
        );

        filter.query = 'jonh'; // typo
        expect(
          filter.apply(_Person(name: 'john', email: 'test@test.com')),
          isTrue,
        );
      });
    });

    group('remote filter', () {
      test('always returns true for apply', () {
        final filter = FuzzySearchFilter<String>.remote(query: 'test');

        expect(filter.apply('anything'), isTrue);
        expect(filter.apply('not matching'), isTrue);
      });

      test('stores query for API use', () {
        final filter = FuzzySearchFilter<String>.remote(query: 'search term');

        expect(filter.query, equals('search term'));
        expect(filter.source, equals(TransformSource.remote));
      });

      test('accepts all remote factory parameters', () {
        var changeCount = 0;
        final filter = FuzzySearchFilter<String>.remote(
          id: 'remote_search',
          query: 'test query',
          label: 'Remote Search',
          maxDistance: 3,
          onChanged: (_) => changeCount++,
        );

        expect(filter.id, equals('remote_search'));
        expect(filter.query, equals('test query'));
        expect(filter.label, equals('Remote Search'));
        expect(filter.maxDistance, equals(3));

        // Verify callback works
        filter.query = 'new query';
        expect(changeCount, greaterThanOrEqualTo(1));
      });

      test('remote filter with no query', () {
        final filter = FuzzySearchFilter<String>.remote();
        expect(filter.query, isEmpty);
        expect(filter.apply('anything'), isTrue);
      });

      test('remote filter test function uses empty valuesRetriever', () {
        final filter = FuzzySearchFilter<String>.remote(query: 'test');

        // Directly invoke the test function to execute the valuesRetriever
        // The remote filter's valuesRetriever returns empty list
        final result = filter.test('any item', 'test');

        // With empty valuesRetriever returning [], no values match query
        expect(result, isFalse);
      });
    });

    group('with FilterManager', () {
      test('integrates with FilterManager', () {
        final manager = FilterManager<String>(
          filters: [
            FuzzySearchFilter<String>(
              id: 'search',
              valuesRetriever: (s) => [s],
              maxDistance: 1,
            ),
          ],
        );

        final searchFilter = manager.getFilter<String>('search')!;
        searchFilter.add('helo');

        expect(manager.apply('hello'), isTrue);
        expect(manager.apply('world'), isFalse);
      });

      test('notifies changes', () {
        var changeCount = 0;
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          onChanged: (_) => changeCount++,
        );

        filter.query = 'test';
        expect(changeCount, greaterThanOrEqualTo(1));

        final prevCount = changeCount;
        filter.query = 'another';
        expect(changeCount, greaterThan(prevCount));
      });
    });

    group('edge cases', () {
      test('handles null values in retriever', () {
        final filter = FuzzySearchFilter<_Person>(
          valuesRetriever: (p) => [p.name, p.nickname],
        );

        filter.query = 'john';
        expect(
          filter.apply(_Person(name: 'john', email: 'test@test.com')),
          isTrue,
        );
      });

      test('handles special characters', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
        );

        filter.query = 'hello-world';
        expect(filter.apply('hello-world'), isTrue);
        expect(filter.apply('hello world'), isTrue); // word boundary
      });

      test('handles unicode', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
        );

        filter.query = 'café';
        expect(filter.apply('café'), isTrue);
      });

      test('empty value does not match non-empty query', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
        );

        filter.query = 'hello';
        expect(filter.apply(''), isFalse);
      });

      test('handles retriever returning all non-string values', () {
        final filter = FuzzySearchFilter<_Person>(
          valuesRetriever: (p) => [null, null], // all nulls
        );

        filter.query = 'test';
        expect(
          filter.apply(_Person(name: 'test', email: 'test@test.com')),
          isFalse,
        );
      });

      test('minSimilarity with length difference check bypass', () {
        // Test the case where minSimilarity is set and length difference
        // would exceed maxDistance, but minSimilarity might still pass
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          maxDistance: 1,
          minSimilarity: 0.5, // 50% similarity threshold
        );

        filter.query = 'ab';
        // 'abcd' has length difference of 2 (> maxDistance=1)
        // But with minSimilarity, it checks the ratio instead
        expect(filter.apply('abcd'), isTrue);
      });

      test('minSimilarity handles empty strings', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          maxDistance: 0,
          minSimilarity: 0.5,
        );

        filter.query = '';
        // Empty query matches everything
        expect(filter.apply('test'), isTrue);
      });

      test('wholeWord strategy with empty value words', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          strategy: FuzzyMatchStrategy.wholeWord,
        );

        filter.query = 'test';
        // Value with only separators produces no words
        expect(filter.apply('---'), isFalse);
      });

      test('anywhere strategy with empty value words', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          strategy: FuzzyMatchStrategy.anywhere,
        );

        filter.query = 'test';
        // Value with only separators produces no words
        expect(filter.apply('   '), isFalse);
      });

      test('contains strategy with exact substring match', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
        );

        filter.query = 'lo wo';
        // Exact substring match in the middle
        expect(filter.apply('hello world'), isTrue);
      });

      test('anywhere strategy with exact substring match', () {
        final filter = FuzzySearchFilter<String>(
          valuesRetriever: (s) => [s],
          strategy: FuzzyMatchStrategy.anywhere,
        );

        filter.query = 'llo';
        // Exact substring match
        expect(filter.apply('hello'), isTrue);
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final filter = FuzzySearchFilter<String>(
          id: 'search',
          valuesRetriever: (s) => [s],
          query: 'test',
        );

        final str = filter.toString();
        expect(str, contains('FuzzySearchFilter'));
        expect(str, contains('search'));
        expect(str, contains('test'));
        expect(str, contains('2'));
      });
    });
  });
}

class _Person {
  _Person({required this.name, required this.email});
  final String name;
  final String email;
  final String? nickname = null;
}
