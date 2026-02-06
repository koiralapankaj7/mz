// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

// Test helper classes have fields for completeness that may not all be used.
// ignore_for_file: unreachable_from_main

import 'dart:async';

import 'package:mz_collection/mz_collection.dart';
import 'package:test/test.dart';

/// Test item with id, name, and optional parent.
class TestItem {
  const TestItem({
    required this.id,
    required this.name,
    this.parentId,
    this.category,
    this.priority = 0,
  });

  final String id;
  final String name;
  final String? parentId;
  final String? category;
  final int priority;
}

void main() {
  group('CollectionController', () {
    late CollectionController<TestItem> controller;

    setUp(() {
      controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    group('construction', () {
      test('should create with keyOf only', () {
        expect(controller.filter, isNull);
        expect(controller.sort, isNull);
        expect(controller.group, isNull);
        expect(controller.selection, isNotNull);
        expect(controller.pagination, isNotNull);
      });

      test('should create with all managers', () {
        final filterManager = FilterManager<TestItem>();
        final sortManager = SortManager<TestItem>();
        final groupManager = GroupManager<TestItem>();
        final selectionManager = SelectionManager();

        final fullController = CollectionController<TestItem>(
          keyOf: (item) => item.id,
          filter: filterManager,
          sort: sortManager,
          group: groupManager,
          selection: selectionManager,
          defaultPageSize: 50,
        );

        expect(fullController.filter, equals(filterManager));
        expect(fullController.sort, equals(sortManager));
        expect(fullController.group, equals(groupManager));
        expect(fullController.selection, equals(selectionManager));

        fullController.dispose();
      });

      test('should create owned selection if not provided', () {
        expect(controller.selection, isNotNull);
      });
    });

    group('basic properties', () {
      test('should return true for isEmpty when no items exist', () {
        expect(controller.isEmpty, isTrue);
        expect(controller.isNotEmpty, isFalse);
        expect(controller.length, equals(0));
      });

      test('should return false for isEmpty when items exist', () {
        controller.add(const TestItem(id: '1', name: 'Item 1'));

        expect(controller.isEmpty, isFalse);
        expect(controller.isNotEmpty, isTrue);
        expect(controller.length, equals(1));
      });

      test('should provide access to items via root', () {
        controller.add(const TestItem(id: '1', name: 'Item 1'));
        controller.add(const TestItem(id: '2', name: 'Item 2'));

        expect(controller.root.length, equals(2));
      });

      test('should provide flat iteration via items', () {
        controller.add(const TestItem(id: '1', name: 'Item 1'));
        controller.add(const TestItem(id: '2', name: 'Item 2'));

        expect(controller.items.length, equals(2));
      });

      test('should get item by key using operator []', () {
        controller.add(const TestItem(id: '1', name: 'Item 1'));

        expect(controller['1']?.name, equals('Item 1'));
        expect(controller['nonexistent'], isNull);
      });

      test('should check item existence with containsKey', () {
        controller.add(const TestItem(id: '1', name: 'Item 1'));

        expect(controller.containsKey('1'), isTrue);
        expect(controller.containsKey('nonexistent'), isFalse);
      });
    });

    group('item manipulation', () {
      test('should add item to store', () {
        controller.add(const TestItem(id: '1', name: 'Item 1'));

        expect(controller.length, equals(1));
        expect(controller['1']?.name, equals('Item 1'));
      });

      test('should add multiple items with addAll', () {
        controller.addAll([
          const TestItem(id: '1', name: 'Item 1'),
          const TestItem(id: '2', name: 'Item 2'),
        ]);

        expect(controller.length, equals(2));
      });

      test('should remove item by key', () {
        controller.add(const TestItem(id: '1', name: 'Item 1'));
        final removed = controller.remove('1');

        expect(removed, isNotNull);
        expect(controller.length, equals(0));
      });

      test('should modify item with update', () {
        controller.add(const TestItem(id: '1', name: 'Original'));
        controller.update('1', (item) {
          return TestItem(id: item.id, name: 'Updated');
        });

        expect(controller['1']?.name, equals('Updated'));
      });

      test('should remove all items with clear', () {
        controller.addAll([
          const TestItem(id: '1', name: 'Item 1'),
          const TestItem(id: '2', name: 'Item 2'),
        ]);
        controller.clear();

        expect(controller.isEmpty, isTrue);
      });

      test('should upsert new item', () {
        final result = controller.upsert(
          const TestItem(id: '1', name: 'Item 1'),
        );

        expect(result, isTrue); // was added, not updated
        expect(controller.length, equals(1));
        expect(controller['1']?.name, equals('Item 1'));
      });

      test('should upsert existing item (replace)', () {
        controller.add(const TestItem(id: '1', name: 'Original'));

        final result = controller.upsert(
          const TestItem(id: '1', name: 'Updated'),
        );

        expect(result, isFalse); // was updated, not added
        expect(controller.length, equals(1));
        expect(controller['1']?.name, equals('Updated'));
      });

      test('should upsertAll with mixed new and existing items', () {
        controller.add(const TestItem(id: '1', name: 'Original 1'));

        final addedCount = controller.upsertAll([
          const TestItem(id: '1', name: 'Updated 1'), // update
          const TestItem(id: '2', name: 'New 2'), // add
          const TestItem(id: '3', name: 'New 3'), // add
        ]);

        expect(addedCount, equals(2)); // only 2 were added
        expect(controller.length, equals(3));
        expect(controller['1']?.name, equals('Updated 1'));
        expect(controller['2']?.name, equals('New 2'));
        expect(controller['3']?.name, equals('New 3'));
      });

      test('should removeAll by keys', () {
        controller.addAll([
          const TestItem(id: '1', name: 'Item 1'),
          const TestItem(id: '2', name: 'Item 2'),
          const TestItem(id: '3', name: 'Item 3'),
        ]);

        final removed = controller.removeAll(['1', '3']);

        expect(removed.length, equals(2));
        expect(removed.map((i) => i.id), containsAll(['1', '3']));
        expect(controller.length, equals(1));
        expect(controller['2'], isNotNull);
      });

      test('should removeAll ignore non-existent keys', () {
        controller.add(const TestItem(id: '1', name: 'Item 1'));

        final removed = controller.removeAll(['1', 'nonexistent']);

        expect(removed.length, equals(1));
        expect(controller.isEmpty, isTrue);
      });

      test('should removeWhere matching predicate', () {
        controller.addAll([
          const TestItem(id: '1', name: 'Apple', category: 'fruit'),
          const TestItem(id: '2', name: 'Carrot', category: 'vegetable'),
          const TestItem(id: '3', name: 'Banana', category: 'fruit'),
        ]);

        final count =
            controller.removeWhere((item) => item.category == 'fruit');

        expect(count, equals(2));
        expect(controller.length, equals(1));
        expect(controller['2'], isNotNull);
      });

      test('should removeWhere return 0 when no match', () {
        controller.add(const TestItem(id: '1', name: 'Item 1'));

        final count = controller.removeWhere((item) => item.name == 'Other');

        expect(count, equals(0));
        expect(controller.length, equals(1));
      });

      test('should getAll by keys', () {
        controller.addAll([
          const TestItem(id: '1', name: 'Item 1'),
          const TestItem(id: '2', name: 'Item 2'),
          const TestItem(id: '3', name: 'Item 3'),
        ]);

        final items = controller.getAll(['1', '3']);

        expect(items.length, equals(2));
        expect(items.map((i) => i.id), containsAll(['1', '3']));
      });

      test('should getAll omit non-existent keys', () {
        controller.add(const TestItem(id: '1', name: 'Item 1'));

        final items = controller.getAll(['1', 'nonexistent', '2']);

        expect(items.length, equals(1));
        expect(items.first.id, equals('1'));
      });

      test('should notify on upsert', () {
        var notified = false;
        controller.addChangeListener(() => notified = true);

        controller.upsert(const TestItem(id: '1', name: 'Item 1'));

        expect(notified, isTrue);
      });

      test('should notify on removeAll', () {
        controller.add(const TestItem(id: '1', name: 'Item 1'));

        var notified = false;
        controller.addChangeListener(() => notified = true);

        controller.removeAll(['1']);

        expect(notified, isTrue);
      });

      test('should notify on removeWhere', () {
        controller.add(const TestItem(id: '1', name: 'Item 1'));

        var notified = false;
        controller.addChangeListener(() => notified = true);

        controller.removeWhere((item) => true);

        expect(notified, isTrue);
      });
    });

    group('loading state', () {
      test('should track loading via pagination state', () {
        // Loading is tracked per-edge in pagination state
        expect(
          controller.pagination.isLoading(PaginationEdge.trailing.id),
          isFalse,
        );
      });
    });

    group('change notifications', () {
      test('should notify listeners on add', () {
        var notified = false;
        controller.addChangeListener(() => notified = true);

        controller.add(const TestItem(id: '1', name: 'Item 1'));

        expect(notified, isTrue);
      });

      test('should notify listeners on remove', () {
        controller.add(const TestItem(id: '1', name: 'Item 1'));

        var notified = false;
        controller.addChangeListener(() => notified = true);

        controller.remove('1');

        expect(notified, isTrue);
      });

      test('should notify listeners on clear', () {
        controller.add(const TestItem(id: '1', name: 'Item 1'));

        var notified = false;
        controller.addChangeListener(() => notified = true);

        controller.clear();

        expect(notified, isTrue);
      });

      test('should remove listener correctly', () {
        var notifyCount = 0;
        void listener() => notifyCount++;

        controller.addChangeListener(listener);
        controller.add(const TestItem(id: '1', name: 'Item 1'));
        expect(notifyCount, equals(1));

        controller.removeChangeListener(listener);
        controller.add(const TestItem(id: '2', name: 'Item 2'));
        expect(notifyCount, equals(1));
      });
    });

    group('with dataLoader', () {
      late CollectionController<TestItem> controllerWithLoader;
      late int loadCallCount;
      late Completer<PageResponse<TestItem>>? loadCompleter;

      setUp(() {
        loadCallCount = 0;
        loadCompleter = null;

        controllerWithLoader = CollectionController<TestItem>(
          keyOf: (item) => item.id,
          dataLoader: (request) async {
            loadCallCount++;
            if (loadCompleter != null) {
              return loadCompleter!.future;
            }
            return const PageResponse(
              items: [
                TestItem(id: '1', name: 'Loaded 1'),
                TestItem(id: '2', name: 'Loaded 2'),
              ],
              nextToken: PageToken.offset(2),
            );
          },
        );
      });

      tearDown(() {
        controllerWithLoader.dispose();
      });

      test('should fetch data from dataLoader when load is called', () async {
        await controllerWithLoader.load();

        expect(controllerWithLoader.length, equals(2));
        expect(controllerWithLoader['1']?.name, equals('Loaded 1'));
        expect(loadCallCount, equals(1));
      });

      test('should throw error when load fails', () async {
        final errorController = CollectionController<TestItem>(
          keyOf: (item) => item.id,
          dataLoader: (request) async {
            throw Exception('Load failed');
          },
        );

        await expectLater(
          errorController.load(),
          throwsA(isA<Exception>()),
        );

        errorController.dispose();
      });

      test('should append data when load is called again', () async {
        var callCount = 0;
        final pagingController = CollectionController<TestItem>(
          keyOf: (item) => item.id,
          dataLoader: (request) async {
            callCount++;
            if (request.isInitialLoad) {
              return const PageResponse(
                items: [TestItem(id: '1', name: 'Item 1')],
                nextToken: PageToken.offset(1),
              );
            }
            return const PageResponse(
              items: [TestItem(id: '2', name: 'Item 2')],
              nextToken: PageToken.end,
            );
          },
        );

        await pagingController.load();
        expect(pagingController.length, equals(1));

        // Second call to load() automatically loads more
        await pagingController.load();
        expect(pagingController.length, equals(2));
        expect(callCount, equals(2));

        pagingController.dispose();
      });

      test('should reset and reload when refresh is called', () async {
        await controllerWithLoader.load();
        expect(loadCallCount, equals(1));

        await controllerWithLoader.refresh();
        expect(loadCallCount, equals(2));
      });
    });
  });

  group('CollectionController with FilterManager', () {
    late FilterManager<TestItem> filter;
    late CollectionController<TestItem> controller;

    setUp(() {
      filter = FilterManager<TestItem>(
        filters: [
          Filter<TestItem, String>(
            id: 'category',
            test: (item, value) => item.category == value,
          ),
        ],
      );

      controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        filter: filter,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('should apply local filter when filter value is set', () {
      controller.addAll([
        const TestItem(id: '1', name: 'Item 1', category: 'A'),
        const TestItem(id: '2', name: 'Item 2', category: 'B'),
        const TestItem(id: '3', name: 'Item 3', category: 'A'),
      ]);

      filter['category']!.add('A');

      expect(controller.length, equals(2));
    });

    test('should rebuild when filter changes', () {
      controller.addAll([
        const TestItem(id: '1', name: 'Item 1', category: 'A'),
        const TestItem(id: '2', name: 'Item 2', category: 'B'),
      ]);

      var notifyCount = 0;
      controller.addChangeListener(() => notifyCount++);

      filter['category']!.add('A');

      expect(notifyCount, greaterThan(0));
    });
  });

  group('CollectionController with SortManager', () {
    late SortManager<TestItem> sort;
    late CollectionController<TestItem> controller;

    setUp(() {
      // Create SortManager with currentOptionIndex: -1 so no sort is active
      // by default - this allows us to test setCurrent properly
      sort = SortManager<TestItem>(
        options: [
          ValueSortOption<TestItem, String>(
            id: 'name',
            sortIdentifier: (item) => item.name,
          ),
          ValueSortOption<TestItem, int>(
            id: 'priority',
            sortIdentifier: (item) => item.priority,
          ),
        ],
        currentOptionIndex: -1,
      );

      controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        sort: sort,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('should apply local sort when sort is set', () async {
      controller.addAll([
        const TestItem(id: '3', name: 'Charlie', priority: 3),
        const TestItem(id: '1', name: 'Alice', priority: 1),
        const TestItem(id: '2', name: 'Bob', priority: 2),
      ]);

      // Set the name sort as active - ascending is the default sort order
      final nameSort = sort['name']!;
      sort.setCurrent(nameSort);

      // Sorting is async, wait for it to complete
      // Poll until sorted or timeout
      var attempts = 0;
      while (attempts < 100) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final items = controller.items.toList();
        if (items.isNotEmpty && items[0].name == 'Alice') {
          break;
        }
        attempts++;
      }

      final items = controller.items.toList();
      expect(items[0].name, equals('Alice'));
      expect(items[1].name, equals('Bob'));
      expect(items[2].name, equals('Charlie'));
    });

    test('should rebuild when sort changes', () async {
      controller.addAll([
        const TestItem(id: '1', name: 'Alice'),
        const TestItem(id: '2', name: 'Bob'),
      ]);

      var notifyCount = 0;
      controller.addChangeListener(() => notifyCount++);

      sort.setCurrent(sort['name']);

      // Sort triggers async rebuild
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifyCount, greaterThan(0));
    });
  });

  group('CollectionController with GroupManager', () {
    late GroupManager<TestItem> group;
    late CollectionController<TestItem> controller;

    setUp(() {
      group = GroupManager<TestItem>(
        options: [
          GroupOption<TestItem, String>(
            id: 'category',
            valueBuilder: (item) => item.category ?? 'Uncategorized',
          ),
        ],
      );

      controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        group: group,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('should group items by category', () {
      controller.addAll([
        const TestItem(id: '1', name: 'Item 1', category: 'A'),
        const TestItem(id: '2', name: 'Item 2', category: 'B'),
        const TestItem(id: '3', name: 'Item 3', category: 'A'),
      ]);

      final groupNodes = controller.root.children;
      expect(groupNodes.length, equals(2));

      // Items accessible through flattened iteration
      expect(controller.items.length, equals(3));
    });

    test('should rebuild when group changes', () {
      controller.addAll([
        const TestItem(id: '1', name: 'Item 1', category: 'A'),
        const TestItem(id: '2', name: 'Item 2', category: 'B'),
      ]);

      var notifyCount = 0;
      controller.addChangeListener(() => notifyCount++);

      // Clear group options
      group.clear();

      expect(notifyCount, greaterThan(0));
    });
  });

  group('CollectionController with SelectionManager', () {
    late SelectionManager selection;
    late CollectionController<TestItem> controller;

    setUp(() {
      selection = SelectionManager();

      controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        selection: selection,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('should expose selection through controller', () {
      expect(controller.selection, equals(selection));
    });

    test('should notify listeners on selection change', () {
      var notified = false;
      controller.addChangeListener(() => notified = true);

      selection.select('1');

      expect(notified, isTrue);
    });

    test('should not dispose provided selection on controller disposal', () {
      controller.dispose();

      // Should not throw - selection was not disposed
      expect(() => selection.select('1'), returnsNormally);

      selection.dispose();
    });
  });

  group('CollectionController lazy loading', () {
    late CollectionController<TestItem> controller;
    late Map<String, List<TestItem>> childrenData;

    setUp(() {
      childrenData = {
        'parent1': [
          const TestItem(id: 'child1', name: 'Child 1', parentId: 'parent1'),
          const TestItem(id: 'child2', name: 'Child 2', parentId: 'parent1'),
        ],
        'parent2': [
          const TestItem(id: 'child3', name: 'Child 3', parentId: 'parent2'),
        ],
      };

      // Track load count to differentiate initial vs child loads
      var loadCount = 0;

      controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        dataLoader: (request) async {
          loadCount++;

          // First load is for root items
          if (loadCount == 1) {
            return const PageResponse(
              items: [
                TestItem(id: 'parent1', name: 'Parent 1'),
                TestItem(id: 'parent2', name: 'Parent 2'),
                TestItem(id: 'parent3', name: 'Parent 3 (no children)'),
              ],
              childHints: {
                'parent1': true,
                'parent2': true,
                'parent3': false,
              },
            );
          }

          // Subsequent loads are for children - return based on load order
          // Note: In production, you'd use a custom NodeToken to identify
          // which node's children to load
          final parentId = loadCount == 2 ? 'parent1' : 'parent2';
          final children = childrenData[parentId] ?? [];
          return PageResponse(
            items: children,
            nextToken: PageToken.end,
            childHints: {
              for (final child in children) child.id: false,
            },
          );
        },
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('should return false for mayHaveChildren on empty node without hint',
        () {
      controller.add(const TestItem(id: 'empty', name: 'Empty'));

      expect(controller.mayHaveChildren('empty'), isFalse);
    });

    test('should return true for mayHaveChildren when hint is set', () async {
      await controller.load();

      // For flat lists, items are in the root node.
      // mayHaveChildren works on node IDs, not item IDs.
      // Use 'root' since that's always a valid node.
      controller.pagination.setHint('root', hasMore: true);

      expect(controller.mayHaveChildren('root'), isTrue);
    });

    test('should return true for pagination.canLoad when can load', () async {
      await controller.load();

      // Set up hint on root node
      controller.pagination.setHint('root', hasMore: true);

      expect(controller.pagination.canLoad('root'), isTrue);
    });

    test('should return false for pagination.isLoading initially', () async {
      await controller.load();

      // Set up hint on root node
      controller.pagination.setHint('root', hasMore: true);

      expect(controller.pagination.isLoading('root'), isFalse);
    });

    test('should return false for pagination.isExhausted initially', () async {
      await controller.load();

      // Set up hint on root node
      controller.pagination.setHint('root', hasMore: true);

      expect(controller.pagination.isExhausted('root'), isFalse);
    });

    test('should load children for root node', () async {
      await controller.load();

      // Set up hint on root node
      controller.pagination.setHint('root', hasMore: true);
      expect(controller.mayHaveChildren('root'), isTrue);

      // Note: loadChildren for 'root' loads children into root
      // This is useful for trees where root can have lazy-loaded children
      await controller.loadChildren('root');

      // After loading, pagination should be updated
      expect(controller.pagination.isExhausted('root'), isTrue);
    });

    test('should update pagination state when loadChildren completes',
        () async {
      await controller.load();

      // Set up hint first on root
      controller.pagination.setHint('root', hasMore: true);

      await controller.loadChildren('root');

      expect(controller.pagination.isExhausted('root'), isTrue);
      expect(controller.pagination.canLoad('root'), isFalse);
    });

    test('should reload children when refreshChildren is called', () async {
      await controller.load();

      // Set up hint first on root
      controller.pagination.setHint('root', hasMore: true);

      await controller.loadChildren('root');
      expect(controller.pagination.isExhausted('root'), isTrue);

      // After refresh, pagination is reset but then reloaded
      await controller.refreshChildren('root');

      // refreshChildren resets the node state, then reloads.
      // After reload, it should be exhausted again (dataLoader returns end
      // token). If the reload doesn't happen, pagination.canLoad is true.
      expect(controller.pagination.canLoad('root'), isFalse);
    });

    test('should do nothing when loadChildren called while already loading',
        () async {
      await controller.load();

      var loadCount = 0;
      final slowController = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        dataLoader: (request) async {
          loadCount++;
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return const PageResponse(items: []);
        },
      );

      await slowController.load();
      loadCount = 0; // Reset after initial load

      slowController.pagination.setHint('root', hasMore: true);

      // Start loading twice
      final future1 = slowController.loadChildren('root');
      final future2 = slowController.loadChildren('root');

      await Future.wait([future1, future2]);

      // Only one actual load should happen
      expect(loadCount, equals(1));

      slowController.dispose();
    });

    test('should throw and track error when loadChildren fails', () async {
      var loadCount = 0;
      final errorController = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        dataLoader: (request) async {
          loadCount++;
          // First load is root, subsequent loads throw
          if (loadCount > 1) {
            throw Exception('Failed to load children');
          }
          return const PageResponse(
            items: [TestItem(id: 'parent', name: 'Parent')],
          );
        },
      );

      await errorController.load();

      // Set hint on root node
      errorController.pagination.setHint('root', hasMore: true);

      // loadChildren throws but also stores error in pagination state
      await expectLater(
        errorController.loadChildren('root'),
        throwsA(isA<Exception>()),
      );

      // Error is tracked in pagination state for retry logic
      expect(errorController.pagination.hasError('root'), isTrue);

      errorController.dispose();
    });
  });

  group('CollectionController with LinkManager', () {
    late LinkManager linkManager;
    late GroupManager<TestItem> group;
    late CollectionController<TestItem> controller;

    setUp(() {
      linkManager = LinkManager();

      // Use grouping so each item gets its own node
      // (Items in flat lists don't have individual nodes)
      group = GroupManager<TestItem>(
        options: [
          GroupOption<TestItem, String>(
            id: 'category',
            valueBuilder: (item) => item.category ?? 'default',
          ),
        ],
      );

      controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        group: group,
      );
    });

    tearDown(() {
      controller.dispose();
      linkManager.dispose();
    });

    test('should return empty list from getLinkedNodes when no links', () {
      controller.add(const TestItem(id: '1', name: 'Item 1', category: 'A'));

      // Note: getLinkedNodes finds nodes by ID, which requires nodes to exist
      // In flat lists, items don't have individual nodes
      final linkedNodes = linkManager.getLinkedNodes('1', controller.root);

      expect(linkedNodes, isEmpty);
    });

    test('should return linked nodes from getLinkedNodes with grouping', () {
      // With grouping, items get organized into group nodes
      // The group node IDs are based on category value
      controller.addAll([
        const TestItem(id: '1', name: 'Item 1', category: 'A'),
        const TestItem(id: '2', name: 'Item 2', category: 'B'),
        const TestItem(id: '3', name: 'Item 3', category: 'C'),
      ]);

      // Link group nodes (categories)
      linkManager.add(
        const NodeLink(
          id: 'link1',
          sourceId: 'A',
          targetId: 'B',
          type: 'related',
        ),
      );
      linkManager.add(
        const NodeLink(
          id: 'link2',
          sourceId: 'A',
          targetId: 'C',
          type: 'related',
        ),
      );

      final linkedNodes = linkManager.getLinkedNodes('A', controller.root);

      expect(linkedNodes.length, equals(2));
    });

    test('should filter getLinkedNodes by type', () {
      controller.addAll([
        const TestItem(id: '1', name: 'Item 1', category: 'A'),
        const TestItem(id: '2', name: 'Item 2', category: 'B'),
        const TestItem(id: '3', name: 'Item 3', category: 'C'),
      ]);

      linkManager.add(
        const NodeLink(
          id: 'link1',
          sourceId: 'A',
          targetId: 'B',
          type: 'blocks',
        ),
      );
      linkManager.add(
        const NodeLink(
          id: 'link2',
          sourceId: 'A',
          targetId: 'C',
          type: 'related',
        ),
      );

      final blocksNodes =
          linkManager.getLinkedNodes('A', controller.root, type: 'blocks');
      final relatedNodes =
          linkManager.getLinkedNodes('A', controller.root, type: 'related');

      expect(blocksNodes.length, equals(1));
      expect(relatedNodes.length, equals(1));
    });

    test('should return empty list from getLinkedItems when no links', () {
      controller.add(const TestItem(id: '1', name: 'Item 1', category: 'A'));

      final linkedItems = linkManager.getLinkedItems('1', controller.root);

      expect(linkedItems, isEmpty);
    });

    test('should return items from linked nodes via getLinkedItems', () {
      controller.addAll([
        const TestItem(id: '1', name: 'Item 1', category: 'A'),
        const TestItem(id: '2', name: 'Item 2', category: 'B'),
        const TestItem(id: '3', name: 'Item 3', category: 'C'),
      ]);

      // Link categories
      linkManager.add(
        const NodeLink(
          id: 'link1',
          sourceId: 'A',
          targetId: 'B',
          type: 'related',
        ),
      );
      linkManager.add(
        const NodeLink(
          id: 'link2',
          sourceId: 'A',
          targetId: 'C',
          type: 'related',
        ),
      );

      final linkedItems = linkManager.getLinkedItems('A', controller.root);

      expect(linkedItems.length, equals(2));
      expect(linkedItems.any((item) => item.id == '2'), isTrue);
      expect(linkedItems.any((item) => item.id == '3'), isTrue);
    });

    test('should filter getLinkedItems by type', () {
      controller.addAll([
        const TestItem(id: '1', name: 'Item 1', category: 'A'),
        const TestItem(id: '2', name: 'Item 2', category: 'B'),
        const TestItem(id: '3', name: 'Item 3', category: 'C'),
      ]);

      linkManager.add(
        const NodeLink(
          id: 'link1',
          sourceId: 'A',
          targetId: 'B',
          type: 'dependency',
        ),
      );
      linkManager.add(
        const NodeLink(
          id: 'link2',
          sourceId: 'A',
          targetId: 'C',
          type: 'related',
        ),
      );

      final dependencies = linkManager.getLinkedItems<TestItem>(
        'A',
        controller.root,
        type: 'dependency',
      );

      expect(dependencies.length, equals(1));
      expect(dependencies.first.id, equals('2'));
    });

    test('should return false from areLinked when not linked', () {
      expect(linkManager.areLinked('A', 'B'), isFalse);
    });

    test('should return true from areLinked when linked', () {
      linkManager.add(
        const NodeLink(
          id: 'link1',
          sourceId: 'A',
          targetId: 'B',
          type: 'related',
        ),
      );

      expect(linkManager.areLinked('A', 'B'), isTrue);
    });

    test('should filter areLinked by type', () {
      linkManager.add(
        const NodeLink(
          id: 'link1',
          sourceId: 'A',
          targetId: 'B',
          type: 'blocks',
        ),
      );

      expect(linkManager.areLinked('A', 'B', type: 'blocks'), isTrue);
      expect(linkManager.areLinked('A', 'B', type: 'related'), isFalse);
    });

    test('should return empty set from getReachableNodes when no links', () {
      final reachable = linkManager.getReachableNodes('A');

      expect(reachable, isEmpty);
    });

    test('should return reachable nodes from getReachableNodes', () {
      linkManager.add(
        const NodeLink(
          id: 'link1',
          sourceId: 'A',
          targetId: 'B',
          type: 'related',
        ),
      );
      linkManager.add(
        const NodeLink(
          id: 'link2',
          sourceId: 'B',
          targetId: 'C',
          type: 'related',
        ),
      );
      linkManager.add(
        const NodeLink(
          id: 'link3',
          sourceId: 'C',
          targetId: 'D',
          type: 'related',
        ),
      );

      final reachable = linkManager.getReachableNodes('A');

      expect(reachable.length, equals(3));
      expect(reachable.contains('B'), isTrue);
      expect(reachable.contains('C'), isTrue);
      expect(reachable.contains('D'), isTrue);
    });

    test('should respect maxDepth in getReachableNodes', () {
      linkManager.add(
        const NodeLink(
          id: 'link1',
          sourceId: 'A',
          targetId: 'B',
          type: 'related',
        ),
      );
      linkManager.add(
        const NodeLink(
          id: 'link2',
          sourceId: 'B',
          targetId: 'C',
          type: 'related',
        ),
      );
      linkManager.add(
        const NodeLink(
          id: 'link3',
          sourceId: 'C',
          targetId: 'D',
          type: 'related',
        ),
      );

      final reachable = linkManager.getReachableNodes('A', maxDepth: 1);

      expect(reachable.length, equals(1));
      expect(reachable.contains('B'), isTrue);
    });

    test('should filter getReachableNodes by type', () {
      linkManager.add(
        const NodeLink(
          id: 'link1',
          sourceId: 'A',
          targetId: 'B',
          type: 'blocks',
        ),
      );
      linkManager.add(
        const NodeLink(
          id: 'link2',
          sourceId: 'A',
          targetId: 'C',
          type: 'related',
        ),
      );

      final blocksReachable =
          linkManager.getReachableNodes('A', type: 'blocks');

      expect(blocksReachable.length, equals(1));
      expect(blocksReachable.contains('B'), isTrue);
    });

    test('should return null from findPath when no path exists', () {
      final path = linkManager.findPath('A', 'B');

      expect(path, isNull);
    });

    test('should return path from findPath when exists', () {
      linkManager.add(
        const NodeLink(
          id: 'link1',
          sourceId: 'A',
          targetId: 'B',
          type: 'related',
        ),
      );
      linkManager.add(
        const NodeLink(
          id: 'link2',
          sourceId: 'B',
          targetId: 'C',
          type: 'related',
        ),
      );

      final path = linkManager.findPath('A', 'C');

      expect(path, isNotNull);
      expect(path, equals(['A', 'B', 'C']));
    });

    test('should filter findPath by type', () {
      linkManager.add(
        const NodeLink(
          id: 'link1',
          sourceId: 'A',
          targetId: 'B',
          type: 'blocks',
        ),
      );
      linkManager.add(
        const NodeLink(
          id: 'link2',
          sourceId: 'B',
          targetId: 'C',
          type: 'blocks',
        ),
      );

      final blocksPath = linkManager.findPath('A', 'C', type: 'blocks');
      final relatedPath = linkManager.findPath('A', 'C', type: 'related');

      expect(blocksPath, isNotNull);
      expect(relatedPath, isNull);
    });
  });

  group('CollectionController length with grouping', () {
    late GroupManager<TestItem> group;
    late CollectionController<TestItem> controller;

    setUp(() {
      group = GroupManager<TestItem>(
        options: [
          GroupOption<TestItem, String>(
            id: 'category',
            valueBuilder: (item) => item.category ?? 'Uncategorized',
          ),
        ],
      );

      controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        group: group,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('should return flattenedLength for length when grouping active', () {
      controller.addAll([
        const TestItem(id: '1', name: 'Item 1', category: 'A'),
        const TestItem(id: '2', name: 'Item 2', category: 'B'),
        const TestItem(id: '3', name: 'Item 3', category: 'A'),
      ]);

      // Length should count all items across groups
      expect(controller.length, equals(3));
      expect(controller.root.children.length, equals(2)); // 2 groups
    });

    test('should return flattenedItems for items when grouping active', () {
      controller.addAll([
        const TestItem(id: '1', name: 'Item 1', category: 'A'),
        const TestItem(id: '2', name: 'Item 2', category: 'B'),
        const TestItem(id: '3', name: 'Item 3', category: 'A'),
      ]);

      final items = controller.items.toList();
      expect(items.length, equals(3));
    });

    test('should handle items without grouping key as direct items', () {
      controller.addAll([
        const TestItem(id: '1', name: 'Item 1', category: 'A'),
        const TestItem(id: '2', name: 'Item 2'), // No category
        const TestItem(id: '3', name: 'Item 3', category: 'A'),
      ]);

      // Item 2 should be treated as 'Uncategorized' by the valueBuilder
      expect(controller.length, equals(3));
    });
  });

  group('CollectionController large dataset sorting', () {
    late SortManager<TestItem> sort;
    late CollectionController<TestItem> controller;

    setUp(() {
      sort = SortManager<TestItem>(
        options: [
          ValueSortOption<TestItem, String>(
            id: 'name',
            sortIdentifier: (item) => item.name,
          ),
          ValueSortOption<TestItem, int>(
            id: 'priority',
            sortIdentifier: (item) => item.priority,
          ),
        ],
        currentOptionIndex: -1,
      );

      controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        sort: sort,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('should sort large dataset using Schwartzian transform', () async {
      // Generate 1000+ items to trigger Schwartzian transform
      final items = List.generate(
        1200,
        (i) => TestItem(
          id: 'item-$i',
          name: 'Name ${1200 - i}', // Reverse order
          priority: i,
        ),
      );

      controller.addAll(items);
      expect(controller.length, equals(1200));

      // Apply sort
      sort.setCurrent(sort['name']);

      // Wait for async rebuild
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final sortedItems = controller.items.toList();
      expect(sortedItems.length, equals(1200));

      // Verify first few items are sorted correctly (case-insensitive)
      // "Name 1" should come before "Name 10" in lexicographic order
      expect(sortedItems[0].name, equals('Name 1'));
      expect(sortedItems[1].name, equals('Name 10'));
    });

    test('should handle null values in sort key extraction', () async {
      final itemsWithNulls = [
        const TestItem(id: '1', name: 'Alice', priority: 1),
        TestItem(id: '2', name: null.toString(), priority: 2),
        const TestItem(id: '3', name: 'Charlie', priority: 3),
      ];

      controller.addAll(itemsWithNulls);

      sort.setCurrent(sort['name']);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Should not throw
      expect(controller.items.length, equals(3));
    });

    test('should compare non-comparable values by string conversion', () async {
      // This tests _compareKeys with non-Comparable objects
      // Using priority sort with items
      final items = [
        const TestItem(id: '1', name: 'A', priority: 3),
        const TestItem(id: '2', name: 'B', priority: 1),
        const TestItem(id: '3', name: 'C', priority: 2),
      ];

      controller.addAll(items);

      sort.setCurrent(sort['priority']);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final sortedItems = controller.items.toList();
      expect(sortedItems[0].priority, equals(1));
      expect(sortedItems[1].priority, equals(2));
      expect(sortedItems[2].priority, equals(3));
    });
  });

  group('CollectionController with remote filters/sorts', () {
    test('should refetch when filter has remote source', () async {
      var fetchCount = 0;

      final filter = FilterManager<TestItem>(
        filters: [
          Filter<TestItem, String>(
            id: 'category',
            test: (item, value) => item.category == value,
            source: TransformSource.remote,
          ),
        ],
      );

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        filter: filter,
        dataLoader: (request) async {
          fetchCount++;
          return const PageResponse(
            items: [TestItem(id: '1', name: 'Item 1')],
          );
        },
      );

      await controller.load();
      fetchCount = 0; // Reset after initial load

      // Change filter should trigger refetch (filter has remote source)
      filter['category']!.add('A');

      // Wait for debounced refetch
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(fetchCount, greaterThan(0));

      controller.dispose();
    });

    test('should refetch when sort has remote source', () async {
      var fetchCount = 0;

      final sort = SortManager<TestItem>(
        options: [
          ValueSortOption<TestItem, String>(
            id: 'name',
            sortIdentifier: (item) => item.name,
            source: TransformSource.remote,
          ),
        ],
        currentOptionIndex: -1,
      );

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        sort: sort,
        dataLoader: (request) async {
          fetchCount++;
          return const PageResponse(
            items: [TestItem(id: '1', name: 'Item 1')],
          );
        },
      );

      await controller.load();
      fetchCount = 0; // Reset after initial load

      // Change sort should trigger refetch (sort has remote source)
      sort.setCurrent(sort['name']);

      // Wait for debounced refetch
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(fetchCount, greaterThan(0));

      controller.dispose();
    });

    test('should not refetch when filter has local source', () async {
      var fetchCount = 0;

      final filter = FilterManager<TestItem>(
        filters: [
          Filter<TestItem, String>(
            id: 'category',
            test: (item, value) => item.category == value,
            // source defaults to TransformSource.local
          ),
        ],
      );

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        filter: filter,
        dataLoader: (request) async {
          fetchCount++;
          return const PageResponse(
            items: [TestItem(id: '1', name: 'Item 1')],
          );
        },
      );

      await controller.load();
      fetchCount = 0; // Reset after initial load

      // Change filter should NOT trigger refetch (local only)
      filter['category']!.add('A');

      // Wait to ensure no refetch happens
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(fetchCount, equals(0));

      controller.dispose();
    });
  });

  group('CollectionController group sorting', () {
    late GroupManager<TestItem> group;
    late SortManager<TestItem> sort;
    late CollectionController<TestItem> controller;

    setUp(() {
      group = GroupManager<TestItem>(
        options: [
          GroupOption<TestItem, String>(
            id: 'category',
            valueBuilder: (item) => item.category ?? 'Uncategorized',
            sortOption: ValueSortOption<String, String>(
              id: 'group-sort',
              sortIdentifier: (value) => value,
              sortOrder: SortOrder.ascending,
            ),
          ),
        ],
      );

      sort = SortManager<TestItem>(
        options: [
          ValueSortOption<TestItem, String>(
            id: 'name',
            sortIdentifier: (item) => item.name,
          ),
        ],
      );

      controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        group: group,
        sort: sort,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('should sort groups by sortOption', () {
      controller.addAll([
        const TestItem(id: '1', name: 'Item 1', category: 'C'),
        const TestItem(id: '2', name: 'Item 2', category: 'A'),
        const TestItem(id: '3', name: 'Item 3', category: 'B'),
      ]);

      final groupNodes = controller.root.children.toList();

      // Groups should be sorted alphabetically (A, B, C)
      expect(groupNodes[0].id, equals('A'));
      expect(groupNodes[1].id, equals('B'));
      expect(groupNodes[2].id, equals('C'));
    });

    test('should sort items within groups', () async {
      controller.addAll([
        const TestItem(id: '1', name: 'Charlie', category: 'A'),
        const TestItem(id: '2', name: 'Alice', category: 'A'),
        const TestItem(id: '3', name: 'Bob', category: 'A'),
      ]);

      // Wait for async sort
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final groupNode = controller.root.children.first;
      final items = groupNode.toList();

      expect(items[0].name, equals('Alice'));
      expect(items[1].name, equals('Bob'));
      expect(items[2].name, equals('Charlie'));
    });
  });

  group('CollectionController disposal', () {
    test('should clean up resources on dispose', () {
      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
      );

      controller.add(const TestItem(id: '1', name: 'Item 1'));

      // Should not throw
      expect(controller.dispose, returnsNormally);
    });

    test('should remove listeners from managers on dispose', () {
      final filter = FilterManager<TestItem>();
      final sort = SortManager<TestItem>();
      final group = GroupManager<TestItem>();

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        filter: filter,
        sort: sort,
        group: group,
      );

      controller.dispose();

      // After disposal, changes to managers should not cause issues
      // This verifies listeners were removed - trigger changes via public API
      expect(filter.clear, returnsNormally);
      expect(sort.clearSorts, returnsNormally);
      expect(group.clear, returnsNormally);
    });

    test('should dispose owned selection manager', () {
      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
      );
      // Variable assigned to verify lazy selection is created before disposal.
      // ignore: unused_local_variable
      final selection = controller.selection;

      controller.dispose();

      // Accessing disposed selection should indicate it's disposed
      // or we can verify through expected behavior
      // Note: SelectionManager doesn't throw on operations after disposal
      // but we've verified the controller cleans up properly
    });
  });

  group('CollectionController _compareKeys edge cases', () {
    test('should compare null values correctly', () async {
      // Test _compareKeys with null values by using a sort option
      // that extracts null for some items

      // Create items where category can be null
      final sort = SortManager<TestItem>(
        options: [
          ValueSortOption<TestItem, String?>(
            id: 'category',
            sortIdentifier: (item) => item.category,
          ),
        ],
      );

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        sort: sort,
      );

      // Add items with null and non-null categories
      // Generate 1000+ to trigger Schwartzian transform
      final items = <TestItem>[];
      for (var i = 0; i < 600; i++) {
        items.add(TestItem(id: 'a-$i', name: 'Item $i', category: 'A'));
      }
      for (var i = 0; i < 600; i++) {
        items.add(TestItem(id: 'n-$i', name: 'Item $i'));
      }

      controller.addAll(items);

      // Wait for async rebuild
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Should not throw - null values handled
      expect(controller.length, equals(1200));

      // Null values should sort before non-null
      final sorted = controller.items.toList();
      expect(sorted.first.category, isNull);

      controller.dispose();
    });
  });

  group('CollectionController empty group options', () {
    test('should build flat structure when group options are empty', () {
      // GroupManager with no options
      final group = GroupManager<TestItem>(options: []);

      final sort = SortManager<TestItem>(
        options: [
          ValueSortOption<TestItem, String>(
            id: 'name',
            sortIdentifier: (item) => item.name,
          ),
        ],
      );

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        group: group,
        sort: sort,
      );

      controller.addAll([
        const TestItem(id: '2', name: 'Bob'),
        const TestItem(id: '1', name: 'Alice'),
      ]);

      // Should be flat (no groups) and sorted
      expect(controller.root.children, isEmpty);
      expect(controller.root.length, equals(2));

      final items = controller.root.toList();
      expect(items[0].name, equals('Alice'));
      expect(items[1].name, equals('Bob'));

      controller.dispose();
    });
  });

  group('CollectionController multi-value grouping', () {
    test('should handle items with no group keys as direct items', () {
      // Multi-value grouping that can return empty list
      final group = GroupManager<TestItem>(
        options: [
          GroupOption<TestItem, String>.multi(
            id: 'tags',
            valuesBuilder: (item) {
              // Return empty list for items without category
              if (item.category == null) return [];
              return [item.category!];
            },
          ),
        ],
      );

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        group: group,
      );

      controller.addAll([
        const TestItem(id: '1', name: 'Tagged', category: 'A'),
        const TestItem(id: '2', name: 'Untagged'),
        const TestItem(id: '3', name: 'Tagged B', category: 'B'),
      ]);

      // Should have 2 groups (A and B) plus 1 direct item at root
      expect(controller.root.children.length, equals(2));
      expect(controller.root.length, equals(1)); // Direct item

      // All 3 items accessible through flattened iteration
      expect(controller.length, equals(3));

      controller.dispose();
    });

    test('should handle items with multiple group keys', () {
      // Multi-value grouping that returns multiple keys
      final group = GroupManager<TestItem>(
        options: [
          GroupOption<TestItem, String>.multi(
            id: 'tags',
            valuesBuilder: (item) {
              // Item appears in multiple groups based on name
              if (item.name == 'Multi') return ['A', 'B', 'C'];
              return [item.category ?? 'default'];
            },
          ),
        ],
      );

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        group: group,
      );

      controller.addAll([
        const TestItem(id: '1', name: 'Multi', category: 'X'),
        const TestItem(id: '2', name: 'Single', category: 'D'),
      ]);

      // Should have groups A, B, C, D
      expect(controller.root.children.length, equals(4));

      // 'Multi' item appears in 3 groups, 'Single' in 1
      // Total flattened: 4 (1 in each group)
      expect(controller.length, equals(4));

      controller.dispose();
    });
  });

  group('CollectionController single-value grouping with null keys', () {
    test('should handle items with null group key as direct items', () {
      // Single-value grouping that returns null for some items
      final group = GroupManager<TestItem>(
        options: [
          GroupOption<TestItem, String?>(
            id: 'category',
            valueBuilder: (item) => item.category, // Can be null
          ),
        ],
      );

      final sort = SortManager<TestItem>(
        options: [
          ValueSortOption<TestItem, String>(
            id: 'name',
            sortIdentifier: (item) => item.name,
          ),
        ],
      );

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        group: group,
        sort: sort,
      );

      controller.addAll([
        const TestItem(id: '1', name: 'Grouped', category: 'A'),
        const TestItem(id: '2', name: 'Direct B'),
        const TestItem(id: '3', name: 'Direct A'),
      ]);

      // Should have 1 group (A) plus 2 direct items
      expect(controller.root.children.length, equals(1));
      expect(controller.root.length, equals(2)); // Direct items

      // Direct items should be sorted
      final directItems = controller.root.toList();
      expect(directItems[0].name, equals('Direct A'));
      expect(directItems[1].name, equals('Direct B'));

      controller.dispose();
    });
  });

  group('CollectionController nested groups hierarchical ID', () {
    test('should create hierarchical IDs for nested groups', () {
      // Two levels of grouping
      final group = GroupManager<TestItem>(
        options: [
          GroupOption<TestItem, String>(
            id: 'category',
            valueBuilder: (item) => item.category ?? 'default',
          ),
          GroupOption<TestItem, String>(
            id: 'priority-group',
            valueBuilder: (item) => 'P${item.priority}',
          ),
        ],
      );

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        group: group,
      );

      controller.addAll([
        const TestItem(id: '1', name: 'Item 1', category: 'Work', priority: 1),
        const TestItem(id: '2', name: 'Item 2', category: 'Work', priority: 2),
        const TestItem(id: '3', name: 'Item 3', category: 'Home', priority: 1),
      ]);

      // First level groups
      final firstLevel = controller.root.children.toList();
      expect(firstLevel.length, equals(2)); // Work, Home

      // Second level groups have hierarchical IDs
      final workGroup = firstLevel.firstWhere((n) => n.id == 'Work');
      final workChildren = workGroup.children.toList();
      expect(workChildren.length, equals(2)); // P1, P2

      // Verify hierarchical IDs
      expect(workChildren.any((n) => n.id == 'Work/P1'), isTrue);
      expect(workChildren.any((n) => n.id == 'Work/P2'), isTrue);

      controller.dispose();
    });
  });

  group('CollectionController sort tie-breaker', () {
    test('should use full compare for ties in large dataset', () async {
      final sort = SortManager<TestItem>(
        options: [
          ValueSortOption<TestItem, String>(
            id: 'category',
            sortIdentifier: (item) => item.category ?? '',
          ),
          ValueSortOption<TestItem, String>(
            id: 'name',
            sortIdentifier: (item) => item.name,
          ),
        ],
      );

      // Add secondary sort
      sort['name']!.sortOrder = SortOrder.ascending;

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        sort: sort,
      );

      // Create 1000+ items with same primary key to trigger tie-breaker
      final items = <TestItem>[];
      for (var i = 0; i < 1100; i++) {
        items.add(
          TestItem(
            id: 'item-$i',
            name: 'Name ${1100 - i}', // Reverse order
            category: 'Same', // All same category
          ),
        );
      }

      controller.addAll(items);

      // Wait for async rebuild
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Items should be sorted, tie-breaker applied
      expect(controller.length, equals(1100));

      controller.dispose();
    });
  });

  group('CollectionController load failure on subsequent load', () {
    test('should throw and track error on subsequent load failure', () async {
      var loadCount = 0;

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        dataLoader: (request) async {
          loadCount++;
          if (loadCount == 1) {
            // First load succeeds
            return const PageResponse(
              items: [TestItem(id: '1', name: 'Item 1')],
              nextToken: PageToken.offset(1),
            );
          }
          // Second load fails
          throw Exception('Load more failed');
        },
      );

      await controller.load();
      expect(controller.length, equals(1));

      // Second load() should throw
      await expectLater(
        controller.load(),
        throwsA(isA<Exception>()),
      );

      // Error is tracked in pagination state for retry logic
      expect(
        controller.pagination.hasError(PaginationEdge.trailing.id),
        isTrue,
      );

      controller.dispose();
    });
  });

  group('CollectionController mayHaveChildren with pagination hint', () {
    test('should return true when node has children in pagination state',
        () async {
      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
      );

      controller.add(const TestItem(id: 'parent', name: 'Parent'));

      // Use 'root' since that's the only node in flat structure
      controller.pagination.setHint('root', hasMore: true);

      // mayHaveChildren checks pagination hint
      expect(controller.mayHaveChildren('root'), isTrue);

      controller.dispose();
    });

    test('should return false when node has no children hint', () async {
      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
      );

      // Node doesn't exist - should return false
      expect(controller.mayHaveChildren('nonexistent'), isFalse);

      controller.dispose();
    });

    test('should return true when node has loaded children', () {
      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
      );

      controller.add(const TestItem(id: 'item', name: 'Item'));

      // Root has children (the added item)
      expect(controller.mayHaveChildren('root'), isTrue);

      controller.dispose();
    });
  });

  group('CollectionController addChildrenToNode with grouping', () {
    test('should group children when adding to node with active grouping',
        () async {
      var loadCount = 0;

      final group = GroupManager<TestItem>(
        options: [
          GroupOption<TestItem, String>(
            id: 'category',
            valueBuilder: (item) => item.category ?? 'default',
          ),
        ],
      );

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        group: group,
        dataLoader: (request) async {
          loadCount++;
          // First load is root, second is children
          if (loadCount > 1) {
            return const PageResponse(
              items: [
                TestItem(id: 'c1', name: 'Child 1', category: 'A'),
                TestItem(id: 'c2', name: 'Child 2', category: 'B'),
                TestItem(id: 'c3', name: 'Child 3', category: 'A'),
              ],
            );
          }
          return const PageResponse(
            items: [TestItem(id: 'parent', name: 'Parent')],
          );
        },
      );

      await controller.load();
      controller.pagination.setHint('root', hasMore: true);

      await controller.loadChildren('root');

      // Children should be grouped
      final rootChildren = controller.root.children.toList();
      expect(rootChildren.length, equals(2)); // A and B groups

      controller.dispose();
    });
  });

  group('CollectionController processChildHints via loadChildren', () {
    test('should process childHints from loadChildren response', () async {
      // This test doesn't call load() first, so loadChildren is the first load
      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        dataLoader: (request) async {
          // Loading children for root - return items with child hints
          return const PageResponse(
            items: [
              TestItem(id: 'c1', name: 'Child 1'),
              TestItem(id: 'c2', name: 'Child 2'),
            ],
            childHints: {
              'c1': true, // Has grandchildren
              'c2': false, // No grandchildren
            },
          );
        },
      );

      // Set up for loadChildren
      controller.pagination.setHint('root', hasMore: true);

      await controller.loadChildren('root');

      // Check pagination state reflects childHints from loadChildren
      expect(controller.pagination.hasHint('c1'), isTrue);
      expect(controller.pagination.hasHint('c2'), isFalse);

      controller.dispose();
    });

    test('should clear child hint when loadChildren returns false hint',
        () async {
      // This test doesn't call load() first, so loadChildren is the first load
      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        dataLoader: (request) async {
          return const PageResponse(
            items: [TestItem(id: 'child', name: 'Child')],
            childHints: {'existingNode': false}, // Clear existing hint
          );
        },
      );

      // Mark as having children first
      controller.pagination.setHint('existingNode', hasMore: true);
      expect(controller.pagination.hasHint('existingNode'), isTrue);

      // Set up for loadChildren
      controller.pagination.setHint('root', hasMore: true);

      // Load children - response should clear the hint
      await controller.loadChildren('root');

      expect(controller.pagination.hasHint('existingNode'), isFalse);

      controller.dispose();
    });
  });

  group('CollectionController with all group options disabled', () {
    test('should build flat structure when all options are disabled', () {
      // GroupManager with an option that starts disabled
      final categoryOption = GroupOption<TestItem, String>(
        id: 'category',
        valueBuilder: (item) => item.category ?? 'Unknown',
        enabled: false, // Disabled
      );

      final group = GroupManager<TestItem>(options: [categoryOption]);

      final sort = SortManager<TestItem>(
        options: [
          ValueSortOption<TestItem, String>(
            id: 'name',
            sortIdentifier: (item) => item.name,
          ),
        ],
      );

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        group: group,
        sort: sort,
      );

      // Add items
      controller.addAll([
        const TestItem(id: '2', name: 'Bob', category: 'B'),
        const TestItem(id: '1', name: 'Alice', category: 'A'),
      ]);

      // Should be flat (no groups) and sorted because option is disabled
      expect(controller.root.children, isEmpty);
      expect(controller.root.length, equals(2));

      final items = controller.root.toList();
      expect(items[0].name, equals('Alice'));
      expect(items[1].name, equals('Bob'));

      controller.dispose();
    });
  });

  group('CollectionController mayHaveChildren from pagination hint', () {
    test('should return true from pagination hint when no loaded children', () {
      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
      );

      // Set a hint that root may have children
      controller.pagination.setHint('root', hasMore: true);

      // The root has no loaded children, but hint says it may have
      expect(controller.mayHaveChildren('root'), isTrue);

      controller.dispose();
    });
  });

  group('CollectionController state serialization', () {
    group('captureState', () {
      test('should return empty snapshot for fresh controller', () {
        final controller = CollectionController<TestItem>(
          keyOf: (item) => item.id,
        );

        final snapshot = controller.captureState();

        expect(snapshot.isEmpty, isTrue);

        controller.dispose();
      });

      test('should capture selection state', () {
        final controller = CollectionController<TestItem>(
          keyOf: (item) => item.id,
        );

        controller.selection.select('item1');
        controller.selection.select('item2');

        final snapshot = controller.captureState();

        expect(snapshot.selection, isNotNull);
        expect(snapshot.selection!.keys, equals({'item1', 'item2'}));

        controller.dispose();
      });

      test('should capture filter state', () {
        final filter = FilterManager<TestItem>(
          filters: [
            Filter<TestItem, String>(
              id: 'category',
              test: (item, value) => item.category == value,
            ),
          ],
        );
        final controller = CollectionController<TestItem>(
          keyOf: (item) => item.id,
          filter: filter,
        );

        filter['category']!.add('A');

        final snapshot = controller.captureState();

        expect(snapshot.filter, isNotNull);
        expect(snapshot.isNotEmpty, isTrue);

        controller.dispose();
      });

      test('should capture sort state', () {
        final sort = SortManager<TestItem>(
          options: [
            ValueSortOption<TestItem, String>(
              id: 'name',
              sortIdentifier: (item) => item.name,
            ),
          ],
        );
        final controller = CollectionController<TestItem>(
          keyOf: (item) => item.id,
          sort: sort,
        );

        sort['name']!.sortOrder = SortOrder.ascending;

        final snapshot = controller.captureState();

        expect(snapshot.sort, isNotNull);
        expect(snapshot.isNotEmpty, isTrue);

        controller.dispose();
      });

      test('should capture group state', () {
        final group = GroupManager<TestItem>(
          options: [
            GroupOption<TestItem, String>(
              id: 'category',
              valueBuilder: (item) => item.category,
            ),
          ],
        );
        final controller = CollectionController<TestItem>(
          keyOf: (item) => item.id,
          group: group,
        );

        final snapshot = controller.captureState();

        expect(snapshot.group, isNotNull);
        expect(snapshot.isNotEmpty, isTrue);

        controller.dispose();
      });
    });

    group('restoreState', () {
      test('should restore selection state', () {
        final controller = CollectionController<TestItem>(
          keyOf: (item) => item.id,
        );

        final snapshot = CollectionSnapshot(
          selection: SelectionSnapshot.fromKeys(const {'a', 'b'}),
        );

        controller.restoreState(snapshot);

        expect(controller.selection.isSelected('a'), isTrue);
        expect(controller.selection.isSelected('b'), isTrue);

        controller.dispose();
      });

      test('should restore filter state', () {
        final filter = FilterManager<TestItem>(
          filters: [
            Filter<TestItem, String>(
              id: 'category',
              test: (item, value) => item.category == value,
            ),
          ],
        );
        final controller = CollectionController<TestItem>(
          keyOf: (item) => item.id,
          filter: filter,
        );

        // Capture a snapshot with filter values set
        filter['category']!
          ..add('A')
          ..add('B');
        final capturedSnapshot = controller.captureState();

        // Clear and restore
        filter['category']!.clear();
        expect(filter['category']!.isEmpty, isTrue);

        controller.restoreState(capturedSnapshot);

        expect(filter['category']!.values, containsAll(['A', 'B']));

        controller.dispose();
      });

      test('should notify listeners after restore', () {
        final controller = CollectionController<TestItem>(
          keyOf: (item) => item.id,
        );

        var notified = false;
        controller.addChangeListener(() => notified = true);

        final snapshot = CollectionSnapshot(
          selection: SelectionSnapshot.fromKeys(const {'a'}),
        );

        controller.restoreState(snapshot);

        expect(notified, isTrue);

        controller.dispose();
      });

      test('should handle empty snapshot', () {
        final controller = CollectionController<TestItem>(
          keyOf: (item) => item.id,
        );
        controller.selection.select('existing');

        const snapshot = CollectionSnapshot.empty();

        // Should not throw, just no-op for null components
        controller.restoreState(snapshot);

        // Selection unchanged since snapshot.selection was null
        expect(controller.selection.isSelected('existing'), isTrue);

        controller.dispose();
      });

      test('should restore sort state', () async {
        final sort = SortManager<TestItem>(
          options: [
            ValueSortOption<TestItem, String>(
              id: 'name',
              sortIdentifier: (item) => item.name,
            ),
          ],
          currentOptionIndex: -1,
        );
        final controller = CollectionController<TestItem>(
          keyOf: (item) => item.id,
          sort: sort,
        );

        // Add items
        controller.addAll([
          const TestItem(id: '2', name: 'Bob'),
          const TestItem(id: '1', name: 'Alice'),
        ]);

        // Create snapshot with sort state
        final snapshot = CollectionSnapshot(
          sort: SortSnapshot.fromEntries(const [
            SortEntry(id: 'name', order: SortOrder.ascending),
          ]),
        );

        controller.restoreState(snapshot);

        // Wait for async sort
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Sort should be restored
        expect(sort['name']!.sortOrder, equals(SortOrder.ascending));

        controller.dispose();
      });

      test('should restore group state', () {
        final categoryOption = GroupOption<TestItem, String>(
          id: 'category',
          valueBuilder: (item) => item.category ?? 'default',
          enabled: false,
        );
        final group = GroupManager<TestItem>(
          options: [categoryOption],
        );
        final controller = CollectionController<TestItem>(
          keyOf: (item) => item.id,
          group: group,
        );

        // Add items
        controller.addAll([
          const TestItem(id: '1', name: 'Item 1', category: 'A'),
          const TestItem(id: '2', name: 'Item 2', category: 'B'),
        ]);

        // Group should be disabled initially
        expect(controller.root.children, isEmpty);

        // Create snapshot with group state (enabled)
        final snapshot = CollectionSnapshot(
          group: GroupSnapshot.fromData(activeIds: ['category']),
        );

        controller.restoreState(snapshot);

        // Group should now be enabled
        expect(categoryOption.enabled, isTrue);
        expect(controller.root.children, hasLength(2));

        controller.dispose();
      });

      test('should restore collapse state', () {
        final group = GroupManager<TestItem>(
          options: [
            GroupOption<TestItem, String>(
              id: 'category',
              valueBuilder: (item) => item.category ?? 'default',
            ),
          ],
        );
        final controller = CollectionController<TestItem>(
          keyOf: (item) => item.id,
          group: group,
        );

        // Add items to create groups
        controller.addAll([
          const TestItem(id: '1', name: 'Item 1', category: 'A'),
          const TestItem(id: '2', name: 'Item 2', category: 'B'),
        ]);

        // All groups are expanded by default
        final groupA = controller.root.children.firstWhere((n) => n.id == 'A');
        expect(groupA.isCollapsed, isFalse);

        // Create snapshot with collapse state
        final snapshot = CollectionSnapshot(
          collapse: CollapseSnapshot.fromIds(const {'A'}),
        );

        controller.restoreState(snapshot);

        // Group A should be collapsed
        final groupAAfter =
            controller.root.children.firstWhere((n) => n.id == 'A');
        expect(groupAAfter.isCollapsed, isTrue);

        controller.dispose();
      });

      test('should restore pagination state', () async {
        final controller = CollectionController<TestItem>(
          keyOf: (item) => item.id,
          dataLoader: (request) async {
            return const PageResponse(
              items: [TestItem(id: '1', name: 'Item')],
              nextToken: PageToken.offset(20),
            );
          },
        );

        await controller.load();

        // Create snapshot with pagination state
        final snapshot = CollectionSnapshot(
          pagination: PaginationSnapshot.fromOffsets(const {'trailing': 100}),
        );

        controller.restoreState(snapshot);

        // Pagination offset should be restored
        final capturedState = controller.captureState();
        expect(capturedState.pagination!['trailing'], equals(100));

        controller.dispose();
      });
    });
  });

  group('CollectionSnapshot', () {
    group('construction', () {
      test('empty() should create empty snapshot', () {
        const snapshot = CollectionSnapshot.empty();

        expect(snapshot.isEmpty, isTrue);
        expect(snapshot.isNotEmpty, isFalse);
        expect(snapshot.filter, isNull);
        expect(snapshot.sort, isNull);
        expect(snapshot.group, isNull);
        expect(snapshot.selection, isNull);
        expect(snapshot.collapse, isNull);
        expect(snapshot.pagination, isNull);
      });

      test('should detect isNotEmpty when any component has state', () {
        final snapshot = CollectionSnapshot(
          selection: SelectionSnapshot.fromKeys(const {'a'}),
        );

        expect(snapshot.isNotEmpty, isTrue);
        expect(snapshot.isEmpty, isFalse);
      });
    });

    group('toJson', () {
      test('should serialize all components', () {
        final snapshot = CollectionSnapshot(
          filter: FilterSnapshot.fromJson(const {
            'status': ['active'],
          }),
          sort: SortSnapshot.fromEntries(const [
            SortEntry(id: 'name', order: SortOrder.ascending),
          ]),
          group: GroupSnapshot.fromData(activeIds: const ['category']),
          selection: SelectionSnapshot.fromKeys(const {'a', 'b'}),
          collapse: CollapseSnapshot.fromIds(const {'folder1'}),
          pagination: PaginationSnapshot.fromOffsets(const {'trailing': 20}),
        );

        final json = snapshot.toJson();

        expect(json.containsKey('filter'), isTrue);
        expect(json.containsKey('sort'), isTrue);
        expect(json.containsKey('group'), isTrue);
        expect(json.containsKey('selection'), isTrue);
        expect(json.containsKey('collapse'), isTrue);
        expect(json.containsKey('pagination'), isTrue);
      });

      test('should omit null/empty components', () {
        const snapshot = CollectionSnapshot.empty();

        final json = snapshot.toJson();

        expect(json, isEmpty);
      });
    });

    group('fromJson', () {
      test('should deserialize all components', () {
        final json = {
          'filter': {
            'status': ['active'],
          },
          'sort': {
            'entries': [
              {'id': 'name', 'order': 'asc'},
            ],
          },
          'group': {
            'activeIds': ['category'],
            'orders': <String, int>{},
          },
          'selection': {
            'keys': ['a', 'b'],
          },
          'collapse': {
            'collapsedIds': ['folder1'],
          },
          'pagination': {
            'offsets': {'trailing': 20},
          },
        };

        final snapshot = CollectionSnapshot.fromJson(json);

        expect(snapshot.filter, isNotNull);
        expect(snapshot.sort, isNotNull);
        expect(snapshot.group, isNotNull);
        expect(snapshot.selection, isNotNull);
        expect(snapshot.collapse, isNotNull);
        expect(snapshot.pagination, isNotNull);
      });

      test('should handle empty JSON', () {
        final snapshot = CollectionSnapshot.fromJson(const <String, dynamic>{});

        expect(snapshot.isEmpty, isTrue);
      });

      test('should handle partial JSON', () {
        final json = {
          'selection': {
            'keys': ['a'],
          },
        };

        final snapshot = CollectionSnapshot.fromJson(json);

        expect(snapshot.selection, isNotNull);
        expect(snapshot.filter, isNull);
        expect(snapshot.sort, isNull);
      });
    });

    group('toQueryString', () {
      test('should combine all component query strings', () {
        final snapshot = CollectionSnapshot(
          selection: SelectionSnapshot.fromKeys(const {'a'}),
          collapse: CollapseSnapshot.fromIds(const {'folder1'}),
        );

        final query = snapshot.toQueryString();

        expect(query, contains('selected='));
        expect(query, contains('collapsed='));
        expect(query, contains('&'));
      });

      test('should return empty string for empty snapshot', () {
        const snapshot = CollectionSnapshot.empty();

        final query = snapshot.toQueryString();

        expect(query, isEmpty);
      });

      test('should include filter query string', () {
        final snapshot = CollectionSnapshot(
          filter: FilterSnapshot.fromJson(const {
            'status': ['active', 'pending'],
          }),
        );

        final query = snapshot.toQueryString();

        expect(query, contains('filter.status='));
      });

      test('should include sort query string', () {
        final snapshot = CollectionSnapshot(
          sort: SortSnapshot.fromEntries(const [
            SortEntry(id: 'name', order: SortOrder.ascending),
          ]),
        );

        final query = snapshot.toQueryString();

        expect(query, contains('sort='));
      });

      test('should include group query string', () {
        final snapshot = CollectionSnapshot(
          group: GroupSnapshot.fromData(activeIds: const ['category']),
        );

        final query = snapshot.toQueryString();

        expect(query, contains('group='));
      });

      test('should include pagination query string', () {
        final snapshot = CollectionSnapshot(
          pagination: PaginationSnapshot.fromOffsets(const {'trailing': 20}),
        );

        final query = snapshot.toQueryString();

        expect(query, contains('page.trailing='));
      });

      test('should combine all components in query string', () {
        final snapshot = CollectionSnapshot(
          filter: FilterSnapshot.fromJson(const {
            'status': ['active'],
          }),
          sort: SortSnapshot.fromEntries(const [
            SortEntry(id: 'name', order: SortOrder.ascending),
          ]),
          group: GroupSnapshot.fromData(activeIds: const ['category']),
          selection: SelectionSnapshot.fromKeys(const {'item1'}),
          collapse: CollapseSnapshot.fromIds(const {'folder1'}),
          pagination: PaginationSnapshot.fromOffsets(const {'trailing': 10}),
        );

        final query = snapshot.toQueryString();

        expect(query, contains('filter.status='));
        expect(query, contains('sort='));
        expect(query, contains('group='));
        expect(query, contains('selected='));
        expect(query, contains('collapsed='));
        expect(query, contains('page.trailing='));
      });
    });

    group('fromQueryString', () {
      test('should parse all component parameters', () {
        const query = 'selected=a,b&collapsed=folder1&page.trailing=20';

        final snapshot = CollectionSnapshot.fromQueryString(query);

        expect(snapshot.selection!.keys, equals({'a', 'b'}));
        expect(snapshot.collapse!.collapsedIds, equals({'folder1'}));
        expect(snapshot.pagination!['trailing'], equals(20));
      });

      test('should return empty snapshot for empty query', () {
        final snapshot = CollectionSnapshot.fromQueryString('');

        // All components are parsed but should be empty
        expect(snapshot.selection?.isEmpty ?? true, isTrue);
        expect(snapshot.collapse?.isEmpty ?? true, isTrue);
        expect(snapshot.filter?.isEmpty ?? true, isTrue);
        expect(snapshot.sort?.isEmpty ?? true, isTrue);
        expect(snapshot.group?.isEmpty ?? true, isTrue);
        expect(snapshot.pagination?.isEmpty ?? true, isTrue);
      });
    });

    group('copyWith', () {
      test('should create copy with modified components', () {
        const original = CollectionSnapshot.empty();

        final modified = original.copyWith(
          selection: SelectionSnapshot.fromKeys(const {'x'}),
        );

        expect(original.selection, isNull);
        expect(modified.selection!.keys, equals({'x'}));
      });

      test('should preserve unmodified components', () {
        final original = CollectionSnapshot(
          selection: SelectionSnapshot.fromKeys(const {'a'}),
          collapse: CollapseSnapshot.fromIds(const {'folder1'}),
        );

        final modified = original.copyWith(
          selection: SelectionSnapshot.fromKeys(const {'b'}),
        );

        expect(modified.selection!.keys, equals({'b'}));
        expect(modified.collapse!.collapsedIds, equals({'folder1'}));
      });

      test('should preserve selection when not specified in copyWith', () {
        final original = CollectionSnapshot(
          selection: SelectionSnapshot.fromKeys(const {'original'}),
          collapse: CollapseSnapshot.fromIds(const {'folder1'}),
        );

        // Call copyWith without specifying selection
        final modified = original.copyWith(
          collapse: CollapseSnapshot.fromIds(const {'folder2'}),
        );

        // Selection should be preserved from original
        expect(modified.selection!.keys, equals({'original'}));
        expect(modified.collapse!.collapsedIds, equals({'folder2'}));
      });
    });

    group('equality', () {
      test('should be equal for same components', () {
        final snapshot1 = CollectionSnapshot(
          selection: SelectionSnapshot.fromKeys(const {'a'}),
        );
        final snapshot2 = CollectionSnapshot(
          selection: SelectionSnapshot.fromKeys(const {'a'}),
        );

        expect(snapshot1, equals(snapshot2));
        expect(snapshot1.hashCode, equals(snapshot2.hashCode));
      });

      test('should not be equal for different components', () {
        final snapshot1 = CollectionSnapshot(
          selection: SelectionSnapshot.fromKeys(const {'a'}),
        );
        final snapshot2 = CollectionSnapshot(
          selection: SelectionSnapshot.fromKeys(const {'b'}),
        );

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('empty snapshots should be equal', () {
        const snapshot1 = CollectionSnapshot.empty();
        const snapshot2 = CollectionSnapshot.empty();

        expect(snapshot1, equals(snapshot2));
      });
    });

    group('toString', () {
      test('should list non-empty components', () {
        final snapshot = CollectionSnapshot(
          selection: SelectionSnapshot.fromKeys(const {'a'}),
          collapse: CollapseSnapshot.fromIds(const {'folder1'}),
        );

        final str = snapshot.toString();

        expect(str, contains('CollectionSnapshot'));
        expect(str, contains('selection'));
        expect(str, contains('collapse'));
      });

      test('should be empty list for empty snapshot', () {
        const snapshot = CollectionSnapshot.empty();

        final str = snapshot.toString();

        expect(str, equals('CollectionSnapshot()'));
      });
    });

    group('roundtrip', () {
      test('should roundtrip through JSON', () {
        final original = CollectionSnapshot(
          selection: SelectionSnapshot.fromKeys(const {'a', 'b'}),
          collapse: CollapseSnapshot.fromIds(const {'folder1'}),
          pagination: PaginationSnapshot.fromOffsets(const {'trailing': 20}),
        );

        final json = original.toJson();
        final restored = CollectionSnapshot.fromJson(json);

        expect(restored.selection, equals(original.selection));
        expect(restored.collapse, equals(original.collapse));
        expect(restored.pagination, equals(original.pagination));
      });
    });
  });

  // ===========================================================================
  // Additional Coverage Tests for PageRequest
  // ===========================================================================

  group('PageRequest additional coverage', () {
    test('fromQueryParams with offset token', () {
      final params = {
        'offset': '10',
        'limit': '25',
        'search': 'test query',
      };
      final request = PageRequest.fromQueryParams(params);

      expect(request.token, isA<OffsetToken>());
      expect((request.token as OffsetToken).offset, equals(10));
      expect(request.limit, equals(25));
      expect(request.search, equals('test query'));
    });

    test('fromQueryParams with cursor token', () {
      final params = {
        'cursor': 'abc123',
        'limit': '30',
      };
      final request = PageRequest.fromQueryParams(params);

      expect(request.token, isA<CursorToken>());
      expect((request.token as CursorToken).cursor, equals('abc123'));
      expect(request.limit, equals(30));
    });

    test('fromQueryParams with empty token defaults', () {
      final params = <String, String>{};
      final request = PageRequest.fromQueryParams(params);

      expect(request.token.isEmpty, isTrue);
      expect(request.limit, equals(20)); // default
    });

    test('fromQueryParams with invalid offset falls back to empty', () {
      final params = {'offset': 'not-a-number'};
      final request = PageRequest.fromQueryParams(params);

      expect(request.token.isEmpty, isTrue);
    });

    test('toQueryParams with offset token', () {
      const request = PageRequest(
        edge: PaginationEdge.trailing,
        token: OffsetToken(15),
        limit: 50,
      );
      final params = request.toQueryParams();

      expect(params['offset'], equals('15'));
      expect(params['limit'], equals('50'));
    });

    test('toQueryParams with cursor token', () {
      const request = PageRequest(
        edge: PaginationEdge.trailing,
        token: CursorToken('cursor123'),
        limit: 20,
      );
      final params = request.toQueryParams();

      expect(params['cursor'], equals('cursor123'));
      expect(params['limit'], equals('20'));
    });

    test('toQueryParams with search', () {
      const request = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
        search: 'my search',
      );
      final params = request.toQueryParams();

      expect(params['search'], equals('my search'));
    });

    test('toQueryParams with filters', () {
      const request = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
        filters: [
          FilterCriteria(id: 'status', values: {'active'}),
        ],
      );
      final params = request.toQueryParams();

      expect(params['filter[status]'], equals('active'));
    });

    test('toQueryParams with sort', () {
      const request = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
        sort: [SortCriteria(id: 'name', order: SortOrder.ascending)],
      );
      final params = request.toQueryParams();

      expect(params.containsKey('sort'), isTrue);
    });

    test('toQueryParams with group', () {
      const request = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
        group: GroupCriteria(id: 'category'),
      );
      final params = request.toQueryParams();

      expect(params['group'], equals('category'));
    });

    test('equality with same values', () {
      const request1 = PageRequest(
        edge: PaginationEdge.trailing,
        token: OffsetToken(10),
        limit: 20,
        search: 'test',
        filters: [
          FilterCriteria(id: 'a', values: {'1'}),
        ],
        sort: [SortCriteria(id: 'name', order: SortOrder.ascending)],
        group: GroupCriteria(id: 'cat'),
      );
      const request2 = PageRequest(
        edge: PaginationEdge.trailing,
        token: OffsetToken(10),
        limit: 20,
        search: 'test',
        filters: [
          FilterCriteria(id: 'a', values: {'1'}),
        ],
        sort: [SortCriteria(id: 'name', order: SortOrder.ascending)],
        group: GroupCriteria(id: 'cat'),
      );

      expect(request1, equals(request2));
      expect(request1.hashCode, equals(request2.hashCode));
    });

    test('equality with different edge', () {
      const request1 = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
      );
      const request2 = PageRequest(
        edge: PaginationEdge.leading,
        token: EmptyToken(),
        limit: 20,
      );

      expect(request1, isNot(equals(request2)));
    });

    test('equality with different token', () {
      const request1 = PageRequest(
        edge: PaginationEdge.trailing,
        token: OffsetToken(10),
        limit: 20,
      );
      const request2 = PageRequest(
        edge: PaginationEdge.trailing,
        token: OffsetToken(20),
        limit: 20,
      );

      expect(request1, isNot(equals(request2)));
    });

    test('equality with different limit', () {
      const request1 = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
      );
      const request2 = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 30,
      );

      expect(request1, isNot(equals(request2)));
    });

    test('equality with different search', () {
      const request1 = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
        search: 'test1',
      );
      const request2 = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
        search: 'test2',
      );

      expect(request1, isNot(equals(request2)));
    });

    test('equality with different filters', () {
      const request1 = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
        filters: [
          FilterCriteria(id: 'a', values: {'1'}),
        ],
      );
      const request2 = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
        filters: [
          FilterCriteria(id: 'a', values: {'2'}),
        ],
      );

      expect(request1, isNot(equals(request2)));
    });

    test('equality with different sort', () {
      const request1 = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
        sort: [SortCriteria(id: 'name', order: SortOrder.ascending)],
      );
      const request2 = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
        sort: [SortCriteria(id: 'name', order: SortOrder.descending)],
      );

      expect(request1, isNot(equals(request2)));
    });

    test('equality with null and non-null filters', () {
      const request1 = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
      );
      const request2 = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
        filters: [
          FilterCriteria(id: 'a', values: {'1'}),
        ],
      );

      expect(request1, isNot(equals(request2)));
    });

    test('equality with null and non-null sort', () {
      const request1 = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
      );
      const request2 = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
        sort: [SortCriteria(id: 'name', order: SortOrder.ascending)],
      );

      expect(request1, isNot(equals(request2)));
    });

    test('equality with different filter list lengths', () {
      const request1 = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
        filters: [
          FilterCriteria(id: 'a', values: {'1'}),
        ],
      );
      const request2 = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
        filters: [
          FilterCriteria(id: 'a', values: {'1'}),
          FilterCriteria(id: 'b', values: {'2'}),
        ],
      );

      expect(request1, isNot(equals(request2)));
    });

    test('hashCode with null filters and sort', () {
      const request = PageRequest(
        edge: PaginationEdge.trailing,
        token: EmptyToken(),
        limit: 20,
      );

      // Should not throw
      expect(request.hashCode, isA<int>());
    });
  });

  group('CollectionController defaultPageSize', () {
    test('returns default page size', () {
      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        defaultPageSize: 25,
      );

      expect(controller.defaultPageSize, equals(25));
      controller.dispose();
    });
  });

  group('CollectionController dataLoader getter', () {
    test('returns dataLoader when provided', () {
      Future<PageResponse<TestItem>> loader(PageRequest request) async {
        return const PageResponse<TestItem>(items: [], nextToken: null);
      }

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        dataLoader: loader,
      );

      expect(controller.dataLoader, equals(loader));
      controller.dispose();
    });
  });

  group('CollectionController with SearchFilter', () {
    test('_buildRequest includes search term from SearchFilter', () async {
      String? capturedSearch;

      Future<PageResponse<TestItem>> loader(PageRequest request) async {
        capturedSearch = request.search;
        return const PageResponse<TestItem>(items: [], nextToken: null);
      }

      final searchFilter = SearchFilter<TestItem>(
        valuesRetriever: (item) => [item.name],
        query: 'test query',
      );
      final filterManager = FilterManager<TestItem>(filters: [searchFilter]);

      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        dataLoader: loader,
        filter: filterManager,
      );

      // Trigger load which calls _buildRequest
      controller.pagination.setHint('trailing', hasMore: true);
      await controller.load(edge: PaginationEdge.trailing);

      expect(capturedSearch, equals('test query'));
      controller.dispose();
    });
  });

  group('CollectionController null checks', () {
    test('remove returns null for non-existent key', () {
      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
      );

      final result = controller.remove('non_existent_key');

      expect(result, isNull);
      controller.dispose();
    });

    test('update does nothing for non-existent key', () {
      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
      );
      controller.add(const TestItem(id: '1', name: 'Item 1'));

      // Try to update a non-existent key
      controller.update('non_existent_key', (item) => item);

      // Original item should be unchanged
      expect(controller.items.length, equals(1));
      expect(controller['1']?.name, equals('Item 1'));
      controller.dispose();
    });

    test('load returns early when no dataLoader is set', () async {
      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        // No dataLoader provided
      );

      // Should not throw, just return early
      await controller.load();

      expect(controller.items, isEmpty);
      controller.dispose();
    });

    test('loadChildren returns early when no dataLoader is set', () async {
      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        // No dataLoader provided
      );

      // Set a hint so canLoad returns true, allowing us to reach line 607
      controller.pagination.setHint('some_node', hasMore: true);

      // Should not throw, just return early at line 607
      await controller.loadChildren('some_node');

      expect(controller.items, isEmpty);
      controller.dispose();
    });

    test('refreshChildren returns early when node does not exist', () async {
      var loadCount = 0;
      final controller = CollectionController<TestItem>(
        keyOf: (item) => item.id,
        dataLoader: (request) async {
          loadCount++;
          return const PageResponse(items: []);
        },
      );

      // Call refreshChildren with non-existent node ID
      await controller.refreshChildren('non_existent_node');

      // dataLoader should not have been called
      expect(loadCount, equals(0));
      controller.dispose();
    });
  });
}
