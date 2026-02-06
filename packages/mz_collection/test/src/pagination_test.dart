// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

import 'package:mz_collection/src/collection_controller.dart';
import 'package:mz_collection/src/filter_manager.dart' show FilterCriteria;
import 'package:mz_collection/src/pagination.dart';
import 'package:mz_collection/src/sort_manager.dart'
    show SortCriteria, SortOrder;
import 'package:test/test.dart';

void main() {
  group('PageToken', () {
    group('EmptyToken', () {
      test('isEmpty returns true', () {
        expect(PageToken.empty.isEmpty, true);
        expect(PageToken.empty.isEnd, false);
        expect(PageToken.empty.hasMore, false);
      });

      test('toString returns descriptive string', () {
        expect(PageToken.empty.toString(), 'EmptyToken');
      });
    });

    group('EndToken', () {
      test('isEnd returns true', () {
        expect(PageToken.end.isEnd, true);
        expect(PageToken.end.isEmpty, false);
        expect(PageToken.end.hasMore, false);
      });

      test('toString returns descriptive string', () {
        expect(PageToken.end.toString(), 'EndToken');
      });
    });

    group('OffsetToken', () {
      test('stores offset and total', () {
        const token = OffsetToken(20, total: 100);

        expect(token.offset, 20);
        expect(token.total, 100);
        expect(token.hasMore, true);
      });

      test('hasMoreItems works with total', () {
        const token = OffsetToken(80, total: 100);

        expect(token.hasMoreItems(10), true); // 80 + 10 < 100
        expect(token.hasMoreItems(20), false); // 80 + 20 >= 100
        expect(token.hasMoreItems(25), false); // 80 + 25 > 100
      });

      test('hasMoreItems returns true when total unknown', () {
        const token = OffsetToken(80);

        expect(token.hasMoreItems(10), true);
        expect(token.hasMoreItems(100), true);
      });

      test('equality works correctly', () {
        const token1 = OffsetToken(20, total: 100);
        const token2 = OffsetToken(20, total: 100);
        const token3 = OffsetToken(20, total: 200);
        const token4 = OffsetToken(30, total: 100);

        expect(token1, equals(token2));
        expect(token1, isNot(equals(token3)));
        expect(token1, isNot(equals(token4)));
      });

      test('hashCode is consistent with equality', () {
        const token1 = OffsetToken(20, total: 100);
        const token2 = OffsetToken(20, total: 100);
        const token3 = OffsetToken(30, total: 100);

        expect(token1.hashCode, equals(token2.hashCode));
        // Different tokens should (usually) have different hashCodes
        expect(token1.hashCode, isNot(equals(token3.hashCode)));
      });

      test('toString returns descriptive string', () {
        expect(const OffsetToken(20).toString(), 'OffsetToken(20)');
        expect(
          const OffsetToken(20, total: 100).toString(),
          'OffsetToken(20, total: 100)',
        );
      });
    });

    group('CursorToken', () {
      test('stores cursor string', () {
        const token = CursorToken('abc123');

        expect(token.cursor, 'abc123');
        expect(token.hasMore, true);
      });

      test('equality works correctly', () {
        const token1 = CursorToken('abc');
        const token2 = CursorToken('abc');
        const token3 = CursorToken('def');

        expect(token1, equals(token2));
        expect(token1, isNot(equals(token3)));
      });

      test('hashCode is consistent with equality', () {
        const token1 = CursorToken('abc');
        const token2 = CursorToken('abc');
        const token3 = CursorToken('def');

        expect(token1.hashCode, equals(token2.hashCode));
        // Different tokens should (usually) have different hashCodes
        expect(token1.hashCode, isNot(equals(token3.hashCode)));
      });

      test('toString returns descriptive string', () {
        expect(const CursorToken('abc').toString(), 'CursorToken(abc)');
      });
    });

    group('factory methods', () {
      test('PageToken.offset creates OffsetToken', () {
        const token = PageToken.offset(10, total: 50);

        expect(token, isA<OffsetToken>());
        expect((token as OffsetToken).offset, 10);
        expect(token.total, 50);
      });

      test('PageToken.cursor creates CursorToken', () {
        const token = PageToken.cursor('xyz');

        expect(token, isA<CursorToken>());
        expect((token as CursorToken).cursor, 'xyz');
      });
    });
  });

  group('PaginationEdge', () {
    test('predefined edges have correct ids', () {
      expect(PaginationEdge.leading.id, 'leading');
      expect(PaginationEdge.trailing.id, 'trailing');
      expect(PaginationEdge.top.id, 'top');
      expect(PaginationEdge.bottom.id, 'bottom');
      expect(PaginationEdge.left.id, 'left');
      expect(PaginationEdge.right.id, 'right');
    });

    test('custom edge works', () {
      const edge = PaginationEdge('ancestors');

      expect(edge.id, 'ancestors');
    });

    test('equality works correctly', () {
      const edge1 = PaginationEdge('custom');
      const edge2 = PaginationEdge('custom');
      const edge3 = PaginationEdge('other');

      expect(edge1, equals(edge2));
      expect(edge1, isNot(equals(edge3)));
    });

    test('toString returns descriptive string', () {
      expect(PaginationEdge.trailing.toString(), 'PaginationEdge(trailing)');
    });
  });

  group('EdgeState', () {
    test('default state is idle with empty token', () {
      const state = EdgeState();

      expect(state.status, LoadingStatus.idle);
      expect(state.token, isA<EmptyToken>());
      expect(state.error, isNull);
      expect(state.retryCount, 0);
    });

    test('canLoad returns true for idle state', () {
      const state = EdgeState();

      expect(state.canLoad, true);
    });

    test('canLoad returns false for loading state', () {
      const state = EdgeState(status: LoadingStatus.loading);

      expect(state.canLoad, false);
      expect(state.isLoading, true);
    });

    test('canLoad returns false for exhausted state', () {
      const state = EdgeState(status: LoadingStatus.exhausted);

      expect(state.canLoad, false);
      expect(state.isExhausted, true);
    });

    test('canLoad returns false for end token', () {
      const state = EdgeState(token: PageToken.end);

      expect(state.canLoad, false);
      expect(state.isExhausted, true);
    });

    test('hasError returns true for error state', () {
      const state = EdgeState(
        status: LoadingStatus.error,
        error: 'Network error',
      );

      expect(state.hasError, true);
      expect(state.error, 'Network error');
    });

    test('copyWith works correctly', () {
      const state = EdgeState();
      final updated = state.copyWith(
        status: LoadingStatus.loading,
        retryCount: 1,
      );

      expect(updated.status, LoadingStatus.loading);
      expect(updated.retryCount, 1);
      expect(updated.token, state.token);
    });

    test('copyWith clearError removes error', () {
      const state = EdgeState(
        status: LoadingStatus.error,
        error: 'Error',
      );
      final updated = state.copyWith(clearError: true);

      expect(updated.error, isNull);
    });

    test('toString returns descriptive string', () {
      const state = EdgeState();
      expect(state.toString(), contains('EdgeState'));
      expect(state.toString(), contains('EmptyToken'));

      const errorState = EdgeState(
        status: LoadingStatus.error,
        error: 'Network error',
      );
      expect(errorState.toString(), contains('error:'));
    });
  });

  group('PaginationState', () {
    late PaginationState state;

    setUp(() {
      state = PaginationState();
    });

    tearDown(() {
      state.dispose();
    });

    group('construction', () {
      test('creates with initial IDs', () {
        final stateWithIds = PaginationState(
          ids: ['leading', 'trailing'],
        );

        expect(stateWithIds.hasEdge(PaginationEdge.leading), isTrue);
        expect(stateWithIds.hasEdge(PaginationEdge.trailing), isTrue);
        expect(stateWithIds.count, 2);

        stateWithIds.dispose();
      });

      test('ids getter returns registered IDs', () {
        state.addEdges([
          PaginationEdge.leading,
          PaginationEdge.trailing,
          PaginationEdge.top,
        ]);

        final ids = state.ids.toList();
        expect(ids.length, 3);
        expect(ids, contains('leading'));
        expect(ids, contains('trailing'));
        expect(ids, contains('top'));
      });
    });

    group('edge management', () {
      test('addEdge registers edge', () {
        state.addEdge(PaginationEdge.trailing);

        expect(state.hasEdge(PaginationEdge.trailing), true);
        expect(state.count, 1);
      });

      test('addEdges registers multiple edges', () {
        state.addEdges([
          PaginationEdge.top,
          PaginationEdge.bottom,
          PaginationEdge.left,
          PaginationEdge.right,
        ]);

        expect(state.count, 4);
        expect(state.hasEdge(PaginationEdge.top), true);
        expect(state.hasEdge(PaginationEdge.right), true);
      });

      test('removeEdge removes edge', () {
        state.addEdge(PaginationEdge.trailing);
        state.removeEdge(PaginationEdge.trailing);

        expect(state.hasEdge(PaginationEdge.trailing), false);
        expect(state.count, 0);
      });

      test('getState returns edge state', () {
        state.addEdge(PaginationEdge.trailing);

        final edgeState = state.getState('trailing');

        expect(edgeState, isNotNull);
        expect(edgeState!.status, LoadingStatus.idle);
      });

      test('getState returns null for unknown edge', () {
        expect(state.getState('trailing'), isNull);
      });
    });

    group('loading lifecycle', () {
      setUp(() {
        state.addEdge(PaginationEdge.trailing);
      });

      test('startLoading sets loading status', () {
        final result = state.startLoading('trailing');

        expect(result, true);
        expect(state.isLoading('trailing'), true);
        expect(state.isAnyLoading, true);
      });

      test('startLoading auto-registers unknown ID', () {
        // New API auto-registers unknown IDs
        final result = state.startLoading('leading');

        expect(result, true);
        expect(state.isLoading('leading'), true);
      });

      test('startLoading returns false if already loading', () {
        state.startLoading('trailing');
        final result = state.startLoading('trailing');

        expect(result, false);
      });

      test('complete sets idle status with new token', () {
        state.startLoading('trailing');
        state.complete(
          'trailing',
          nextToken: const PageToken.cursor('page2'),
        );

        expect(state.isLoading('trailing'), false);
        expect(state.getToken('trailing'), isA<CursorToken>());
        expect(state.canLoad('trailing'), true);
      });

      test('complete with null token sets exhausted', () {
        state.startLoading('trailing');
        state.complete('trailing');

        expect(state.isExhausted('trailing'), true);
        expect(state.canLoad('trailing'), false);
      });

      test('complete with EndToken sets exhausted', () {
        state.startLoading('trailing');
        state.complete(
          'trailing',
          nextToken: PageToken.end,
        );

        expect(state.isExhausted('trailing'), true);
      });

      test('fail sets error status', () {
        state.startLoading('trailing');
        state.fail('trailing', 'Network error');

        expect(state.hasError('trailing'), true);
        expect(state.getError('trailing'), 'Network error');
        expect(state.getState('trailing')?.retryCount, 1);
      });

      test('multiple failures increment retryCount', () {
        state.startLoading('trailing');
        state.fail('trailing', 'Error 1');

        state.startLoading('trailing');
        state.fail('trailing', 'Error 2');

        expect(state.getState('trailing')?.retryCount, 2);
      });

      test('complete with unknown id does nothing', () {
        // Calling complete on an unregistered ID should not throw
        // and should not create a new state
        state.complete('unknown_id');
        expect(state.getState('unknown_id'), isNull);
      });

      test('fail with unknown id does nothing', () {
        // Calling fail on an unregistered ID should not throw
        // and should not create a new state
        state.fail('unknown_id', 'Some error');
        expect(state.getState('unknown_id'), isNull);
      });
    });

    group('reset', () {
      test('reset resets single ID', () {
        state.addEdge(PaginationEdge.trailing);
        state.startLoading('trailing');
        state.complete(
          'trailing',
          nextToken: const PageToken.cursor('page2'),
        );

        state.reset('trailing');

        final edgeState = state.getState('trailing');
        expect(edgeState?.token, isA<EmptyToken>());
        expect(edgeState?.status, LoadingStatus.idle);
      });

      test('resetAll resets all IDs', () {
        state.addEdges([PaginationEdge.leading, PaginationEdge.trailing]);
        state.startLoading('trailing');
        state.complete(
          'trailing',
          nextToken: const PageToken.cursor('page2'),
        );

        state.resetAll();

        expect(
          state.getState('leading')?.token,
          isA<EmptyToken>(),
        );
        expect(
          state.getState('trailing')?.token,
          isA<EmptyToken>(),
        );
      });
    });

    group('queries', () {
      test('loadableIds returns IDs that can load', () {
        state.addEdges([PaginationEdge.leading, PaginationEdge.trailing]);
        state.startLoading('leading');

        final loadable = state.loadableIds.toList();

        expect(loadable.length, 1);
        expect(loadable.first, 'trailing');
      });

      test('isAllExhausted returns true when all exhausted', () {
        state.addEdges([PaginationEdge.leading, PaginationEdge.trailing]);

        state.startLoading('leading');
        state.complete('leading');

        state.startLoading('trailing');
        state.complete('trailing');

        expect(state.isAllExhausted, true);
      });

      test('isAllExhausted returns false when some can load', () {
        state.addEdges([PaginationEdge.leading, PaginationEdge.trailing]);

        state.startLoading('leading');
        state.complete('leading');

        expect(state.isAllExhausted, false);
      });
    });

    group('notifications', () {
      test('addEdge notifies listeners', () {
        var notified = false;
        state.addChangeListener(() => notified = true);

        state.addEdge(PaginationEdge.trailing);

        expect(notified, true);
      });

      test('startLoading notifies listeners', () {
        state.addEdge(PaginationEdge.trailing);

        var notified = false;
        state.addChangeListener(() => notified = true);

        state.startLoading('trailing');

        expect(notified, true);
      });

      test('complete notifies listeners', () {
        state.addEdge(PaginationEdge.trailing);
        state.startLoading('trailing');

        var notified = false;
        state.addChangeListener(() => notified = true);

        state.complete('trailing');

        expect(notified, true);
      });
    });

    group('toString', () {
      test('returns descriptive string for empty state', () {
        final str = state.toString();
        expect(str, contains('PaginationState'));
      });

      test('returns descriptive string with IDs', () {
        state.addEdges([PaginationEdge.leading, PaginationEdge.trailing]);
        state.startLoading('trailing');

        final str = state.toString();
        expect(str, contains('PaginationState'));
        expect(str, contains('trailing'));
      });

      test('includes ID count when IDs present', () {
        state.setHint('node1', hasMore: true);
        state.startLoading('node1');
        state.complete('node1', nextToken: const PageToken.cursor('next'));

        final str = state.toString();
        expect(str, contains('PaginationState'));
        expect(str, contains('node1'));
      });

      test('includes hints count when hints present', () {
        state.setHint('node1', hasMore: true);
        state.setHint('node2', hasMore: true);

        final str = state.toString();
        expect(str, contains('hints'));
      });
    });
  });

  group('PageRequest', () {
    test('stores all properties', () {
      const request = PageRequest(
        edge: PaginationEdge.leading,
        token: PageToken.offset(20),
        limit: 50,
        search: 'test query',
      );

      expect(request.edge, PaginationEdge.leading);
      expect(request.token, isA<OffsetToken>());
      expect(request.limit, 50);
      expect(request.search, 'test query');
    });

    test('has default edge and limit', () {
      const request = PageRequest();

      expect(request.edge, PaginationEdge.trailing);
      expect(request.limit, 20);
    });

    test('stores filters and sort', () {
      const filter = FilterCriteria(id: 'status', values: {'active'});
      const sort = SortCriteria(id: 'name', order: SortOrder.ascending);

      const request = PageRequest(
        filters: [filter],
        sort: [sort],
      );

      expect(request.filters?.length, 1);
      expect(request.filters?.first.id, 'status');
      expect(request.sort?.length, 1);
      expect(request.sort?.first.id, 'name');
    });

    test('copyWith creates modified copy', () {
      const original = PageRequest(
        token: PageToken.offset(0),
        search: 'original',
      );

      final modified = original.copyWith(
        edge: PaginationEdge.leading,
        token: const PageToken.offset(20),
        limit: 50,
        search: 'modified',
      );

      expect(modified.edge, PaginationEdge.leading);
      expect((modified.token as OffsetToken).offset, 20);
      expect(modified.limit, 50);
      expect(modified.search, 'modified');

      // Original unchanged
      expect(original.edge, PaginationEdge.trailing);
      expect((original.token as OffsetToken).offset, 0);
    });

    test('copyWith preserves unspecified values', () {
      const filter = FilterCriteria(id: 'status', values: {'active'});
      const sort = SortCriteria(id: 'name', order: SortOrder.ascending);

      const original = PageRequest(
        token: PageToken.offset(0),
        search: 'test',
        filters: [filter],
        sort: [sort],
      );

      final modified = original.copyWith(limit: 50);

      expect(modified.edge, PaginationEdge.trailing);
      expect(modified.token, original.token);
      expect(modified.limit, 50);
      expect(modified.search, 'test');
      expect(modified.filters, original.filters);
      expect(modified.sort, original.sort);
    });

    test('copyWith preserves limit when not specified', () {
      const original = PageRequest(
        token: PageToken.offset(0),
        limit: 25,
        search: 'test',
      );

      // Don't pass limit - should preserve original.limit (25)
      final modified = original.copyWith(search: 'new search');

      expect(modified.limit, 25); // Original limit preserved
      expect(modified.search, 'new search');
    });

    test('toString returns descriptive string', () {
      const request = PageRequest(
        token: PageToken.offset(20),
        limit: 50,
      );

      final str = request.toString();
      expect(str, contains('PageRequest'));
      expect(str, contains('trailing'));
      expect(str, contains('50'));
    });

    test('isInitialLoad returns true for empty token', () {
      const request = PageRequest();
      expect(request.isInitialLoad, isTrue);
    });

    test('isInitialLoad returns false for non-empty token', () {
      const request = PageRequest(
        token: PageToken.offset(10),
      );
      expect(request.isInitialLoad, isFalse);
    });
  });

  group('PageResponse', () {
    test('stores items and token', () {
      const response = PageResponse<String>(
        items: ['a', 'b', 'c'],
        nextToken: PageToken.cursor('next'),
        totalCount: 100,
      );

      expect(response.items, ['a', 'b', 'c']);
      expect(response.nextToken, isA<CursorToken>());
      expect(response.totalCount, 100);
      expect(response.hasMore, true);
      expect(response.isEmpty, false);
    });

    test('empty response has no more', () {
      // Use non-const to ensure coverage of the constructor
      // ignore: prefer_const_constructors
      final response = PageResponse<String>.empty();

      expect(response.items, isEmpty);
      expect(response.hasMore, false);
      expect(response.isEmpty, true);
    });

    test('toString returns descriptive string', () {
      const response = PageResponse<String>(
        items: ['a', 'b', 'c'],
        nextToken: PageToken.cursor('next'),
      );

      final str = response.toString();
      expect(str, contains('PageResponse'));
      expect(str, contains('items: 3'));
      expect(str, contains('hasMore: true'));
    });

    test('toString shows no more when exhausted', () {
      const response = PageResponse<String>.empty();

      final str = response.toString();
      expect(str, contains('hasMore: false'));
    });

    test('hasChildHints returns false when null', () {
      const response = PageResponse<int>(items: [1, 2, 3]);
      expect(response.hasChildHints, isFalse);
    });

    test('hasChildHints returns false when empty', () {
      const response = PageResponse<int>(items: [1, 2, 3], childHints: {});
      expect(response.hasChildHints, isFalse);
    });

    test('hasChildHints returns true when has hints', () {
      const response = PageResponse<int>(
        items: [1, 2, 3],
        childHints: {'node-1': true, 'node-2': false},
      );
      expect(response.hasChildHints, isTrue);
    });

    test('toString includes hints when present', () {
      const response = PageResponse<int>(
        items: [1, 2, 3],
        childHints: {'node-1': true, 'node-2': false},
      );

      final str = response.toString();
      expect(str, contains('hints'));
    });
  });

  group('PaginationState - Unified ID-Based API', () {
    late PaginationState state;

    setUp(() {
      state = PaginationState();
    });

    tearDown(() {
      state.dispose();
    });

    group('hints', () {
      test('hintedIds returns IDs with hints', () {
        state.setHint('node1', hasMore: true);
        state.setHint('node2', hasMore: true);

        final hints = state.hintedIds.toList();
        expect(hints.length, 2);
        expect(hints, contains('node1'));
        expect(hints, contains('node2'));
      });

      test('ids returns registered IDs', () {
        state.setHint('node1', hasMore: true);
        state.setHint('node2', hasMore: true);
        state.startLoading('node1');
        state.complete('node1', nextToken: const PageToken.cursor('next'));

        final registered = state.ids.toList();
        expect(registered.length, 1);
        expect(registered, contains('node1'));
      });

      test('isRegistered returns false for unregistered ID', () {
        state.setHint('node1', hasMore: true);

        expect(state.isRegistered('node1'), isFalse);
      });

      test('isRegistered returns true after loading', () {
        state.setHint('node1', hasMore: true);
        state.startLoading('node1');
        state.complete('node1');

        expect(state.isRegistered('node1'), isTrue);
      });

      test('getState returns null for unknown ID', () {
        expect(state.getState('unknown'), isNull);
      });

      test('getState returns state after loading', () {
        state.setHint('node1', hasMore: true);
        state.startLoading('node1');
        state.complete('node1', nextToken: const PageToken.cursor('next'));

        final nodeState = state.getState('node1');
        expect(nodeState, isNotNull);
        expect(nodeState!.status, LoadingStatus.idle);
        expect(nodeState.token, isA<CursorToken>());
      });

      test('hasError returns false for no error', () {
        state.setHint('node1', hasMore: true);
        state.startLoading('node1');
        state.complete('node1');

        expect(state.hasError('node1'), isFalse);
      });

      test('hasError returns true after failure', () {
        state.setHint('node1', hasMore: true);
        state.startLoading('node1');
        state.fail('node1', Exception('Test error'));

        expect(state.hasError('node1'), isTrue);
      });

      test('hasError returns false for unknown ID', () {
        expect(state.hasError('unknown'), isFalse);
      });

      test('getError returns null for no error', () {
        state.setHint('node1', hasMore: true);
        state.startLoading('node1');
        state.complete('node1');

        expect(state.getError('node1'), isNull);
      });

      test('getError returns error after failure', () {
        state.setHint('node1', hasMore: true);
        state.startLoading('node1');
        state.fail('node1', 'Test error');

        expect(state.getError('node1'), equals('Test error'));
      });

      test('getError returns null for unknown ID', () {
        expect(state.getError('unknown'), isNull);
      });
    });

    group('hint management', () {
      test('setHint sets hint', () {
        state.setHint('node1', hasMore: true);

        expect(state.hasHint('node1'), isTrue);
      });

      test('setHints sets multiple hints', () {
        state.setHints({
          'node1': true,
          'node2': true,
          'node3': true,
        });

        expect(state.hasHint('node1'), isTrue);
        expect(state.hasHint('node2'), isTrue);
        expect(state.hasHint('node3'), isTrue);
      });

      test('clearHint removes hint', () {
        state.setHint('node1', hasMore: true);
        state.clearHint('node1');

        expect(state.hasHint('node1'), isFalse);
      });

      test('hasHint returns false for unknown ID', () {
        expect(state.hasHint('unknown'), isFalse);
      });

      test('notifies listeners when setting hints', () {
        var notified = false;
        state.addChangeListener(() => notified = true);

        state.setHint('node1', hasMore: true);

        expect(notified, isTrue);
      });

      test('notifies listeners when clearing hints', () {
        state.setHint('node1', hasMore: true);

        var notified = false;
        state.addChangeListener(() => notified = true);

        state.clearHint('node1');

        expect(notified, isTrue);
      });
    });

    group('canLoad', () {
      test('returns true when ID has hint', () {
        state.setHint('node1', hasMore: true);

        expect(state.canLoad('node1'), isTrue);
      });

      test('returns false when ID has no hint and not registered', () {
        expect(state.canLoad('node1'), isFalse);
      });

      test('returns false when ID is already loading', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1');

        expect(state.canLoad('node1'), isFalse);
      });

      test('returns false when ID is exhausted', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1')
          ..complete('node1');

        expect(state.canLoad('node1'), isFalse);
      });

      test('returns true when ID has more pages', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1')
          ..complete('node1', nextToken: const PageToken.cursor('next'));

        expect(state.canLoad('node1'), isTrue);
      });
    });

    group('isLoading', () {
      test('returns false initially', () {
        expect(state.isLoading('node1'), isFalse);
      });

      test('returns true when loading', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1');

        expect(state.isLoading('node1'), isTrue);
      });

      test('returns false after completion', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1')
          ..complete('node1');

        expect(state.isLoading('node1'), isFalse);
      });
    });

    group('isExhausted', () {
      test('returns false initially', () {
        expect(state.isExhausted('node1'), isFalse);
      });

      test('returns true when completed without next token', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1')
          ..complete('node1');

        expect(state.isExhausted('node1'), isTrue);
      });

      test('returns false when completed with next token', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1')
          ..complete('node1', nextToken: const PageToken.cursor('next'));

        expect(state.isExhausted('node1'), isFalse);
      });
    });

    group('getToken', () {
      test('returns empty token initially', () {
        final token = state.getToken('node1');

        expect(token.isEmpty, isTrue);
      });

      test('returns token after completion', () {
        const nextToken = CursorToken('abc123');
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1')
          ..complete('node1', nextToken: nextToken);

        final token = state.getToken('node1');

        expect(token, equals(nextToken));
      });
    });

    group('startLoading', () {
      test('returns true and sets loading state', () {
        state.setHint('node1', hasMore: true);

        final started = state.startLoading('node1');

        expect(started, isTrue);
        expect(state.isLoading('node1'), isTrue);
      });

      test('returns false when already loading', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1');

        final started = state.startLoading('node1');

        expect(started, isFalse);
      });

      test('notifies listeners', () {
        state.setHint('node1', hasMore: true);

        var notified = false;
        state.addChangeListener(() => notified = true);

        state.startLoading('node1');

        expect(notified, isTrue);
      });

      test('auto-registers ID', () {
        // startLoading auto-registers if ID doesn't exist
        state.startLoading('node1');

        expect(state.isRegistered('node1'), isTrue);
        expect(state.isLoading('node1'), isTrue);
      });
    });

    group('complete', () {
      test('clears loading state', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1');

        state.complete('node1');

        expect(state.isLoading('node1'), isFalse);
      });

      test('stores next token', () {
        const nextToken = CursorToken('next');
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1')
          ..complete('node1', nextToken: nextToken);

        expect(state.getToken('node1'), equals(nextToken));
      });

      test('marks as exhausted when no next token', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1')
          ..complete('node1');

        expect(state.isExhausted('node1'), isTrue);
      });

      test('notifies listeners', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1');

        var notified = false;
        state.addChangeListener(() => notified = true);

        state.complete('node1');

        expect(notified, isTrue);
      });
    });

    group('fail', () {
      test('clears loading state', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1');

        state.fail('node1', Exception('Failed'));

        expect(state.isLoading('node1'), isFalse);
      });

      test('notifies listeners', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1');

        var notified = false;
        state.addChangeListener(() => notified = true);

        state.fail('node1', Exception('Failed'));

        expect(notified, isTrue);
      });
    });

    group('reset', () {
      test('resets ID state', () {
        const token = CursorToken('token');
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1')
          ..complete('node1', nextToken: token);

        state.reset('node1');

        expect(state.getToken('node1').isEmpty, isTrue);
        expect(state.isLoading('node1'), isFalse);
        expect(state.isExhausted('node1'), isFalse);
      });

      test('keeps hint by default', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1')
          // Pass a nextToken so the ID is NOT exhausted and hint is preserved
          ..complete('node1', nextToken: const PageToken.cursor('next'));

        state.reset('node1');

        expect(state.hasHint('node1'), isTrue);
      });

      test('removes hint when keepHint is false', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1')
          ..complete('node1');

        state.reset('node1', keepHint: false);

        expect(state.hasHint('node1'), isFalse);
      });

      test('notifies listeners', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1')
          ..complete('node1');

        var notified = false;
        state.addChangeListener(() => notified = true);

        state.reset('node1');

        expect(notified, isTrue);
      });
    });

    group('unregister', () {
      test('removes all data for ID', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1')
          ..complete('node1', nextToken: const PageToken.cursor('next'));

        state.unregister('node1');

        expect(state.hasHint('node1'), isFalse);
        expect(state.isLoading('node1'), isFalse);
        expect(state.canLoad('node1'), isFalse);
      });

      test('notifies listeners', () {
        state.setHint('node1', hasMore: true);

        var notified = false;
        state.addChangeListener(() => notified = true);

        state.unregister('node1');

        expect(notified, isTrue);
      });

      test('does nothing for non-existent ID', () {
        var notified = false;
        state.addChangeListener(() => notified = true);

        state.unregister('nonexistent');

        // Should NOT notify when nothing was removed
        expect(notified, isFalse);
      });
    });

    group('resetAll', () {
      test('resets all IDs', () {
        state
          ..setHint('node1', hasMore: true)
          ..setHint('node2', hasMore: true)
          ..startLoading('node1')
          ..startLoading('node2')
          ..complete('node1', nextToken: const PageToken.cursor('t1'))
          ..complete('node2', nextToken: const PageToken.cursor('t2'));

        state.resetAll();

        expect(state.getToken('node1').isEmpty, isTrue);
        expect(state.getToken('node2').isEmpty, isTrue);
      });

      test('keeps hints when keepHints is true', () {
        state
          ..setHint('node1', hasMore: true)
          ..setHint('node2', hasMore: true);

        state.resetAll(keepHints: true);

        expect(state.hasHint('node1'), isTrue);
        expect(state.hasHint('node2'), isTrue);
      });

      test('removes hints when keepHints is false', () {
        state
          ..setHint('node1', hasMore: true)
          ..setHint('node2', hasMore: true);

        state.resetAll();

        expect(state.hasHint('node1'), isFalse);
        expect(state.hasHint('node2'), isFalse);
      });

      test('notifies listeners', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1')
          ..complete('node1');

        var notified = false;
        state.addChangeListener(() => notified = true);

        state.resetAll();

        expect(notified, isTrue);
      });

      test('always notifies even when no IDs', () {
        var notified = false;
        state.addChangeListener(() => notified = true);

        state.resetAll();

        // resetAll always notifies for consistency
        expect(notified, isTrue);
      });
    });

    group('integration scenarios', () {
      test('full pagination cycle for ID', () {
        // Initial load
        state.setHint('node1', hasMore: true);
        expect(state.canLoad('node1'), isTrue);

        // Start loading
        final started = state.startLoading('node1');
        expect(started, isTrue);
        expect(state.isLoading('node1'), isTrue);

        // Complete with more pages
        state.complete(
          'node1',
          nextToken: const PageToken.cursor('page2'),
        );
        expect(state.isLoading('node1'), isFalse);
        expect(state.canLoad('node1'), isTrue);

        // Load next page
        state.startLoading('node1');
        state.complete('node1'); // No next token

        expect(state.isExhausted('node1'), isTrue);
        expect(state.canLoad('node1'), isFalse);
      });

      test('multiple IDs tracked independently', () {
        state.setHint('node1', hasMore: true);
        state.setHint('node2', hasMore: true);

        // Load node1
        state
          ..startLoading('node1')
          ..complete(
            'node1',
            nextToken: const PageToken.cursor('n1-page2'),
          );

        // Load node2
        state
          ..startLoading('node2')
          ..complete(
            'node2',
            nextToken: const PageToken.cursor('n2-page2'),
          );

        // Both have different tokens
        expect(
          state.getToken('node1'),
          equals(const CursorToken('n1-page2')),
        );
        expect(
          state.getToken('node2'),
          equals(const CursorToken('n2-page2')),
        );
      });

      test('error recovery', () {
        state
          ..setHint('node1', hasMore: true)
          ..startLoading('node1')
          ..fail('node1', Exception('Network error'));

        // Can retry after error
        expect(state.canLoad('node1'), isTrue);
        expect(state.isLoading('node1'), isFalse);
      });
    });
  });

  group('PaginationState state serialization', () {
    group('captureState', () {
      test('should return empty snapshot when no offsets', () {
        final state = PaginationState();

        final snapshot = state.captureState();

        expect(snapshot.isEmpty, isTrue);
        expect(snapshot.offsets, isEmpty);
      });

      test('should capture offset tokens for edges', () {
        final state = PaginationState();
        state.addEdge(PaginationEdge.trailing);
        state.complete(
          'trailing',
          nextToken: const OffsetToken(20),
        );

        final snapshot = state.captureState();

        expect(snapshot.isNotEmpty, isTrue);
        expect(snapshot['trailing'], equals(20));
      });

      test('should capture multiple edge offsets', () {
        final state = PaginationState();
        state.addEdge(PaginationEdge.trailing);
        state.addEdge(PaginationEdge.leading);
        state.complete(
          'trailing',
          nextToken: const OffsetToken(40),
        );
        state.complete(
          'leading',
          nextToken: const OffsetToken(10),
        );

        final snapshot = state.captureState();

        expect(snapshot['trailing'], equals(40));
        expect(snapshot['leading'], equals(10));
      });

      test('should skip cursor tokens (not serializable)', () {
        final state = PaginationState();
        state.addEdge(PaginationEdge.trailing);
        state.complete(
          'trailing',
          nextToken: const CursorToken('abc123'),
        );

        final snapshot = state.captureState();

        expect(snapshot.isEmpty, isTrue);
      });
    });

    group('restoreState', () {
      test('should restore offset tokens for edges', () {
        final state = PaginationState();
        state.addEdge(PaginationEdge.trailing);

        final snapshot = PaginationSnapshot.fromOffsets(const {'trailing': 20});
        state.restoreState(snapshot);

        expect(
          state.getToken('trailing'),
          equals(const OffsetToken(20)),
        );
      });

      test('should reset edges not in snapshot', () {
        final state = PaginationState();
        state.addEdge(PaginationEdge.trailing);
        state.complete(
          'trailing',
          nextToken: const OffsetToken(50),
        );

        const snapshot = PaginationSnapshot.empty();
        state.restoreState(snapshot);

        expect(
          state.getToken('trailing'),
          equals(PageToken.empty),
        );
      });

      test('should notify listeners', () {
        final state = PaginationState();
        state.addEdge(PaginationEdge.trailing);
        var notified = false;
        state.addChangeListener(() => notified = true);

        final snapshot = PaginationSnapshot.fromOffsets(const {'trailing': 20});
        state.restoreState(snapshot);

        expect(notified, isTrue);
      });
    });
  });

  group('PaginationSnapshot', () {
    group('construction', () {
      test('empty() should create empty snapshot', () {
        const snapshot = PaginationSnapshot.empty();

        expect(snapshot.isEmpty, isTrue);
        expect(snapshot.isNotEmpty, isFalse);
        expect(snapshot.length, equals(0));
        expect(snapshot.offsets, isEmpty);
        expect(snapshot.edgeIds, isEmpty);
      });

      test('fromOffsets should create snapshot with given offsets', () {
        final snapshot = PaginationSnapshot.fromOffsets(const {
          'trailing': 20,
          'leading': 10,
        });

        expect(snapshot.isEmpty, isFalse);
        expect(snapshot.isNotEmpty, isTrue);
        expect(snapshot.length, equals(2));
        expect(snapshot['trailing'], equals(20));
        expect(snapshot['leading'], equals(10));
      });

      test('fromOffsets with empty map should return empty snapshot', () {
        final snapshot = PaginationSnapshot.fromOffsets(const <String, int>{});

        expect(snapshot.isEmpty, isTrue);
      });
    });

    group('operator []', () {
      test('should return offset for edge ID', () {
        final snapshot = PaginationSnapshot.fromOffsets(const {'trailing': 20});

        expect(snapshot['trailing'], equals(20));
      });

      test('should return null for unknown edge ID', () {
        final snapshot = PaginationSnapshot.fromOffsets(const {'trailing': 20});

        expect(snapshot['unknown'], isNull);
      });
    });

    group('toJson', () {
      test('should serialize offsets', () {
        final snapshot = PaginationSnapshot.fromOffsets(const {
          'trailing': 20,
          'leading': 10,
        });

        final json = snapshot.toJson();

        expect(json['offsets'], equals({'trailing': 20, 'leading': 10}));
      });

      test('should serialize empty snapshot', () {
        const snapshot = PaginationSnapshot.empty();

        final json = snapshot.toJson();

        expect(json['offsets'], isEmpty);
      });
    });

    group('fromJson', () {
      test('should deserialize offsets', () {
        final json = {
          'offsets': {'trailing': 20, 'leading': 10},
        };

        final snapshot = PaginationSnapshot.fromJson(json);

        expect(snapshot['trailing'], equals(20));
        expect(snapshot['leading'], equals(10));
      });

      test('should return empty snapshot for null offsets', () {
        final json = <String, dynamic>{'offsets': null};

        final snapshot = PaginationSnapshot.fromJson(json);

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty snapshot for empty offsets', () {
        final json = <String, dynamic>{'offsets': <String, int>{}};

        final snapshot = PaginationSnapshot.fromJson(json);

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty snapshot for missing field', () {
        final json = <String, dynamic>{};

        final snapshot = PaginationSnapshot.fromJson(json);

        expect(snapshot.isEmpty, isTrue);
      });

      test('should filter out non-int values', () {
        final json = {
          'offsets': {'trailing': 20, 'invalid': 'not an int', 'leading': 10},
        };

        final snapshot = PaginationSnapshot.fromJson(json);

        expect(snapshot['trailing'], equals(20));
        expect(snapshot['leading'], equals(10));
        expect(snapshot['invalid'], isNull);
      });
    });

    group('toQueryString', () {
      test('should serialize offsets with page. prefix', () {
        final snapshot = PaginationSnapshot.fromOffsets(const {'trailing': 20});

        final query = snapshot.toQueryString();

        expect(query, equals('page.trailing=20'));
      });

      test('should serialize multiple offsets', () {
        final snapshot = PaginationSnapshot.fromOffsets(const {
          'trailing': 20,
          'leading': 10,
        });

        final query = snapshot.toQueryString();

        expect(query, contains('page.trailing=20'));
        expect(query, contains('page.leading=10'));
        expect(query, contains('&'));
      });

      test('should URL encode edge IDs', () {
        final snapshot =
            PaginationSnapshot.fromOffsets(const {'special edge': 20});

        final query = snapshot.toQueryString();

        expect(query, contains('page.special%20edge=20'));
      });

      test('should return empty string for empty snapshot', () {
        const snapshot = PaginationSnapshot.empty();

        final query = snapshot.toQueryString();

        expect(query, isEmpty);
      });
    });

    group('fromQueryString', () {
      test('should parse offsets with page. prefix', () {
        const query = 'page.trailing=20&page.leading=10';

        final snapshot = PaginationSnapshot.fromQueryString(query);

        expect(snapshot['trailing'], equals(20));
        expect(snapshot['leading'], equals(10));
      });

      test('should ignore non-page parameters', () {
        const query = 'filter=active&page.trailing=20&sort=name';

        final snapshot = PaginationSnapshot.fromQueryString(query);

        expect(snapshot['trailing'], equals(20));
        expect(snapshot.length, equals(1));
      });

      test('should return empty snapshot for empty query', () {
        final snapshot = PaginationSnapshot.fromQueryString('');

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty snapshot for no page params', () {
        const query = 'filter=active&sort=name';

        final snapshot = PaginationSnapshot.fromQueryString(query);

        expect(snapshot.isEmpty, isTrue);
      });

      test('should skip invalid offset values', () {
        const query = 'page.trailing=20&page.invalid=abc';

        final snapshot = PaginationSnapshot.fromQueryString(query);

        expect(snapshot['trailing'], equals(20));
        expect(snapshot['invalid'], isNull);
      });

      test('should skip empty edge IDs', () {
        const query = 'page.=20';

        final snapshot = PaginationSnapshot.fromQueryString(query);

        expect(snapshot.isEmpty, isTrue);
      });
    });

    group('equality', () {
      test('identical snapshots are equal', () {
        final snapshot = PaginationSnapshot.fromOffsets(const {'trailing': 20});
        expect(snapshot == snapshot, isTrue);
      });

      test('should be equal for same offsets', () {
        final snapshot1 =
            PaginationSnapshot.fromOffsets(const {'trailing': 20});
        final snapshot2 =
            PaginationSnapshot.fromOffsets(const {'trailing': 20});

        expect(snapshot1, equals(snapshot2));
        expect(snapshot1.hashCode, equals(snapshot2.hashCode));
      });

      test('should not be equal for different offsets', () {
        final snapshot1 =
            PaginationSnapshot.fromOffsets(const {'trailing': 20});
        final snapshot2 =
            PaginationSnapshot.fromOffsets(const {'trailing': 30});

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('should not be equal for different edge IDs', () {
        final snapshot1 =
            PaginationSnapshot.fromOffsets(const {'trailing': 20});
        final snapshot2 = PaginationSnapshot.fromOffsets(const {'leading': 20});

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('toString returns descriptive string', () {
        final snapshot = PaginationSnapshot.fromOffsets(const {'trailing': 20});
        final str = snapshot.toString();

        expect(str, contains('PaginationSnapshot'));
      });
    });
  });

  // ===========================================================================
  // PaginationState Additional Coverage Tests
  // ===========================================================================

  group('PaginationState getHint', () {
    test('getHint returns null for unknown ID', () {
      final state = PaginationState();

      final hint = state.getHint('unknown');

      expect(hint, isNull);
    });

    test('getHint returns hint value after setHint', () {
      final state = PaginationState();
      state.setHint('test', hasMore: true);

      final hint = state.getHint('test');

      expect(hint, isTrue);
    });
  });
}
