// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

import 'package:mz_collection/src/selection_manager.dart';
import 'package:test/test.dart';

void main() {
  group('SelectionState', () {
    test('should have three values: none, partial, all', () {
      expect(SelectionState.values, hasLength(3));
      expect(SelectionState.none, isNotNull);
      expect(SelectionState.partial, isNotNull);
      expect(SelectionState.all, isNotNull);
    });
  });

  group('Tristate', () {
    test('should have three values: yes, no, toggle', () {
      expect(Tristate.values, hasLength(3));
      expect(Tristate.yes, isNotNull);
      expect(Tristate.no, isNotNull);
      expect(Tristate.toggle, isNotNull);
    });

    group('resolve', () {
      test('should always resolve to true for yes', () {
        expect(Tristate.yes.resolve(null), isTrue);
        expect(Tristate.yes.resolve(true), isTrue);
        expect(Tristate.yes.resolve(false), isTrue);
      });

      test('should always resolve to false for no', () {
        expect(Tristate.no.resolve(null), isFalse);
        expect(Tristate.no.resolve(true), isFalse);
        expect(Tristate.no.resolve(false), isFalse);
      });

      test('should invert the current value for toggle', () {
        expect(Tristate.toggle.resolve(true), isFalse);
        expect(Tristate.toggle.resolve(false), isTrue);
      });

      test('should treat null as false for toggle', () {
        expect(Tristate.toggle.resolve(null), isTrue);
      });
    });
  });

  group('SelectionManager', () {
    group('construction', () {
      test('should create empty manager with no parameters', () {
        final manager = SelectionManager();

        expect(manager.isEmpty, isTrue);
        expect(manager.isNotEmpty, isFalse);
        expect(manager.count, equals(0));
      });
    });

    group('select', () {
      test('selects item with toggle (default)', () {
        final manager = SelectionManager();

        final result = manager.select('item1');

        expect(result, isTrue);
        expect(manager.isSelected('item1'), isTrue);
        expect(manager.count, equals(1));
      });

      test('should deselect already selected item on toggle', () {
        final manager = SelectionManager();
        manager.select('item1');

        final result = manager.select('item1');

        expect(result, isFalse);
        expect(manager.isSelected('item1'), isFalse);
        expect(manager.count, equals(0));
      });

      test('should force select item with Tristate.yes', () {
        final manager = SelectionManager();

        final result = manager.select('item1', state: Tristate.yes);

        expect(result, isTrue);
        expect(manager.isSelected('item1'), isTrue);
      });

      test(
          'should return true with no change for Tristate.yes on selected item',
          () {
        final manager = SelectionManager();
        manager.select('item1', state: Tristate.yes);

        var notified = false;
        manager.addChangeListener(() => notified = true);

        final result = manager.select('item1', state: Tristate.yes);

        expect(result, isTrue);
        expect(notified, isFalse);
      });

      test('should force deselect item with Tristate.no', () {
        final manager = SelectionManager();
        manager.select('item1', state: Tristate.yes);

        final result = manager.select('item1', state: Tristate.no);

        expect(result, isFalse);
        expect(manager.isSelected('item1'), isFalse);
      });

      test('should return false with no change for Tristate.no on unselected',
          () {
        final manager = SelectionManager();

        var notified = false;
        manager.addChangeListener(() => notified = true);

        final result = manager.select('item1', state: Tristate.no);

        expect(result, isFalse);
        expect(notified, isFalse);
      });

      test('selects item in specific scope', () {
        final manager = SelectionManager();

        manager.select('item1', scope: 'scopeA');

        expect(manager.isSelected('item1', scope: 'scopeA'), isTrue);
        expect(manager.isSelected('item1'), isFalse);
        expect(manager.countAllIn(scope: 'scopeA'), equals(1));
        expect(manager.countAllIn(), equals(0));
      });

      test('should remove empty scope when last item deselected', () {
        final manager = SelectionManager();
        manager.select('item1', scope: 'scopeA');

        manager.select('item1', scope: 'scopeA', state: Tristate.no);

        expect(manager.scopes, isNot(contains('scopeA')));
      });

      test('should notify listeners when selection changes', () {
        final manager = SelectionManager();
        var notifyCount = 0;
        manager.addChangeListener(() => notifyCount++);

        manager.select('item1');
        manager.select('item2');
        manager.select('item1');

        expect(notifyCount, equals(3));
      });
    });

    group('selectAll', () {
      test('should select all items with Tristate.yes', () {
        final manager = SelectionManager();

        manager.selectAll(['a', 'b', 'c'], state: Tristate.yes);

        expect(manager.isSelected('a'), isTrue);
        expect(manager.isSelected('b'), isTrue);
        expect(manager.isSelected('c'), isTrue);
        expect(manager.count, equals(3));
      });

      test('should deselect all items with Tristate.no', () {
        final manager = SelectionManager();
        manager.selectAll(['a', 'b', 'c'], state: Tristate.yes);

        manager.selectAll(['a', 'b', 'c'], state: Tristate.no);

        expect(manager.isSelected('a'), isFalse);
        expect(manager.isSelected('b'), isFalse);
        expect(manager.isSelected('c'), isFalse);
        expect(manager.count, equals(0));
      });

      test('should toggle each item with Tristate.toggle', () {
        final manager = SelectionManager();
        manager.select('a', state: Tristate.yes);
        manager.select('c', state: Tristate.yes);

        manager.selectAll(['a', 'b', 'c'], state: Tristate.toggle);

        expect(manager.isSelected('a'), isFalse);
        expect(manager.isSelected('b'), isTrue);
        expect(manager.isSelected('c'), isFalse);
      });

      test('selects in specific scope', () {
        final manager = SelectionManager();

        manager.selectAll(['a', 'b'], scope: 'myScope', state: Tristate.yes);

        expect(manager.isSelected('a', scope: 'myScope'), isTrue);
        expect(manager.isSelected('b', scope: 'myScope'), isTrue);
        expect(manager.countAllIn(scope: 'myScope'), equals(2));
      });

      test('should not notify if no changes', () {
        final manager = SelectionManager();
        manager.selectAll(['a', 'b'], state: Tristate.yes);

        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.selectAll(['a', 'b'], state: Tristate.yes);

        expect(notified, isFalse);
      });

      test('should notify once for batch operation', () {
        final manager = SelectionManager();
        var notifyCount = 0;
        manager.addChangeListener(() => notifyCount++);

        manager.selectAll(['a', 'b', 'c', 'd', 'e'], state: Tristate.yes);

        expect(notifyCount, equals(1));
      });

      test('should remove empty scope after deselecting all', () {
        final manager = SelectionManager();
        manager.selectAll(['a', 'b'], scope: 'myScope', state: Tristate.yes);

        manager.selectAll(['a', 'b'], scope: 'myScope', state: Tristate.no);

        expect(manager.scopes, isNot(contains('myScope')));
      });
    });

    group('isSelected', () {
      test('should return false for non-selected item', () {
        final manager = SelectionManager();

        expect(manager.isSelected('item1'), isFalse);
      });

      test('should return true for selected item', () {
        final manager = SelectionManager();
        manager.select('item1');

        expect(manager.isSelected('item1'), isTrue);
      });

      test('should check within specific scope', () {
        final manager = SelectionManager();
        manager.select('item1', scope: 'scopeA');
        manager.select('item1', scope: 'scopeB');

        expect(manager.isSelected('item1', scope: 'scopeA'), isTrue);
        expect(manager.isSelected('item1', scope: 'scopeB'), isTrue);
        expect(manager.isSelected('item1'), isFalse);
      });

      test('should return false for non-existent scope', () {
        final manager = SelectionManager();

        expect(manager.isSelected('item1', scope: 'nonExistent'), isFalse);
      });
    });

    group('clear', () {
      test('should clear default scope selections', () {
        final manager = SelectionManager();
        manager.select('a');
        manager.select('b');
        manager.select('c', scope: 'scopeA');

        manager.clear();

        expect(manager.isSelected('a'), isFalse);
        expect(manager.isSelected('b'), isFalse);
        expect(manager.isSelected('c', scope: 'scopeA'), isTrue);
      });

      test('should clear specific scope', () {
        final manager = SelectionManager();
        manager.select('a', scope: 'scopeA');
        manager.select('b', scope: 'scopeB');

        manager.clear(scope: 'scopeA');

        expect(manager.isSelected('a', scope: 'scopeA'), isFalse);
        expect(manager.isSelected('b', scope: 'scopeB'), isTrue);
      });

      test('should notify listeners when cleared', () {
        final manager = SelectionManager();
        manager.select('a');
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.clear();

        expect(notified, isTrue);
      });

      test('should not notify if already empty', () {
        final manager = SelectionManager();
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.clear();

        expect(notified, isFalse);
      });

      test('should not notify if scope is empty', () {
        final manager = SelectionManager();
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.clear(scope: 'nonExistent');

        expect(notified, isFalse);
      });
    });

    group('clearAll', () {
      test('should clear all selections across all scopes', () {
        final manager = SelectionManager();
        manager.select('a');
        manager.select('b', scope: 'scopeA');
        manager.select('c', scope: 'scopeB');

        manager.clearAll();

        expect(manager.isEmpty, isTrue);
        expect(manager.count, equals(0));
      });

      test('should notify listeners when clearAll called', () {
        final manager = SelectionManager();
        manager.select('a');
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.clearAll();

        expect(notified, isTrue);
      });

      test('should not notify if already empty', () {
        final manager = SelectionManager();
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.clearAll();

        expect(notified, isFalse);
      });
    });

    group('count', () {
      test('should return 0 for empty manager', () {
        final manager = SelectionManager();

        expect(manager.count, equals(0));
      });

      test('should return total across all scopes', () {
        final manager = SelectionManager();
        manager.select('a');
        manager.select('b', scope: 'scopeA');
        manager.select('c', scope: 'scopeA');
        manager.select('d', scope: 'scopeB');

        expect(manager.count, equals(4));
      });
    });

    group('isEmpty and isNotEmpty', () {
      test('should be true for isEmpty when manager is empty', () {
        final manager = SelectionManager();

        expect(manager.isEmpty, isTrue);
        expect(manager.isNotEmpty, isFalse);
      });

      test('should be true for isNotEmpty when items selected', () {
        final manager = SelectionManager();
        manager.select('a');

        expect(manager.isEmpty, isFalse);
        expect(manager.isNotEmpty, isTrue);
      });
    });

    group('countIn (query-time grouping)', () {
      test('should return 0 for empty keys', () {
        final manager = SelectionManager();

        expect(manager.countIn(<String>[]), equals(0));
      });

      test('should return 0 when no keys are selected', () {
        final manager = SelectionManager();

        expect(manager.countIn(['a', 'b', 'c']), equals(0));
      });

      test('should return count of selected keys in provided list', () {
        final manager = SelectionManager();
        manager.selectAll(['a', 'b', 'c', 'd'], state: Tristate.yes);

        // Query with current grouping
        expect(manager.countIn(['a', 'b', 'e']), equals(2)); // a, b selected
        expect(manager.countIn(['c', 'd']), equals(2)); // c, d selected
        expect(manager.countIn(['e', 'f']), equals(0)); // none selected
      });

      test('should work with specific scope for countIn', () {
        final manager = SelectionManager();
        manager.selectAll(['a', 'b'], scope: 'tabA', state: Tristate.yes);
        manager.selectAll(['a', 'c'], scope: 'tabB', state: Tristate.yes);

        expect(manager.countIn(['a', 'b', 'c'], scope: 'tabA'), equals(2));
        expect(manager.countIn(['a', 'b', 'c'], scope: 'tabB'), equals(2));
        expect(manager.countIn(['a', 'b', 'c']), equals(0));
      });
    });

    group('selectedIn (query-time grouping)', () {
      test('should return empty set for empty keys', () {
        final manager = SelectionManager();

        expect(manager.selectedIn(<String>[]), isEmpty);
      });

      test('should return empty set when nothing selected', () {
        final manager = SelectionManager();

        final result = manager.selectedIn(['a', 'b', 'c']);

        expect(result, isEmpty);
      });

      test('should return selected keys from provided list', () {
        final manager = SelectionManager();
        manager.selectAll(['a', 'c', 'e'], state: Tristate.yes);

        final result = manager.selectedIn(['a', 'b', 'c', 'd']);

        expect(result, equals({'a', 'c'}));
      });

      test('should work with specific scope for selectedIn', () {
        final manager = SelectionManager();
        manager.selectAll(['a', 'b'], scope: 'tabA', state: Tristate.yes);

        final result = manager.selectedIn(['a', 'b', 'c'], scope: 'tabA');

        expect(result, equals({'a', 'b'}));
      });
    });

    group('allSelectedIn', () {
      test('should return empty set for non-existent scope', () {
        final manager = SelectionManager();

        final result = manager.allSelectedIn(scope: 'nonExistent');

        expect(result, isEmpty);
      });

      test('should return unmodifiable set of all selected keys in scope', () {
        final manager = SelectionManager();
        manager.select('a', scope: 'scopeA');
        manager.select('b', scope: 'scopeA');

        final result = manager.allSelectedIn(scope: 'scopeA');

        expect(result, equals({'a', 'b'}));
        expect(() => (result as Set).add('c'), throwsUnsupportedError);
      });

      test('should return default scope selections when scope is null', () {
        final manager = SelectionManager();
        manager.select('a');
        manager.select('b');

        final result = manager.allSelectedIn();

        expect(result, equals({'a', 'b'}));
      });
    });

    group('countAllIn', () {
      test('should return 0 for non-existent scope', () {
        final manager = SelectionManager();

        expect(manager.countAllIn(scope: 'nonExistent'), equals(0));
      });

      test('should return count in specific scope', () {
        final manager = SelectionManager();
        manager.select('a', scope: 'scopeA');
        manager.select('b', scope: 'scopeA');
        manager.select('c', scope: 'scopeB');

        expect(manager.countAllIn(scope: 'scopeA'), equals(2));
        expect(manager.countAllIn(scope: 'scopeB'), equals(1));
        expect(manager.countAllIn(), equals(0));
      });
    });

    group('allSelected', () {
      test('should return empty set for empty manager', () {
        final manager = SelectionManager();

        expect(manager.allSelected, isEmpty);
      });

      test('should return all selected keys across all scopes', () {
        final manager = SelectionManager();
        manager.select('a');
        manager.select('b', scope: 'scopeA');
        manager.select('c', scope: 'scopeB');

        final result = manager.allSelected;

        expect(result, equals({'a', 'b', 'c'}));
      });

      test('should deduplicate keys selected in multiple scopes', () {
        final manager = SelectionManager();
        manager.select('a');
        manager.select('a', scope: 'scopeA');
        manager.select('a', scope: 'scopeB');

        final result = manager.allSelected;

        expect(result, equals({'a'}));
      });
    });

    group('scopes', () {
      test('should return empty for empty manager', () {
        final manager = SelectionManager();

        expect(manager.scopes, isEmpty);
      });

      test('should return all scope keys including null', () {
        final manager = SelectionManager();
        manager.select('a');
        manager.select('b', scope: 'scopeA');
        manager.select('c', scope: 'scopeB');

        final result = manager.scopes.toList();

        expect(result, containsAll([null, 'scopeA', 'scopeB']));
      });
    });

    group('stateOf (query-time grouping)', () {
      test('should return none when no items selected', () {
        final manager = SelectionManager();

        expect(
          manager.stateOf(['a', 'b', 'c']),
          equals(SelectionState.none),
        );
      });

      test('should return none when keys list is empty', () {
        final manager = SelectionManager();
        manager.select('a');

        expect(manager.stateOf(<String>[]), equals(SelectionState.none));
      });

      test('should return all when all items selected', () {
        final manager = SelectionManager();
        manager.selectAll(['a', 'b', 'c'], state: Tristate.yes);

        expect(manager.stateOf(['a', 'b', 'c']), equals(SelectionState.all));
      });

      test('should return partial when some items selected', () {
        final manager = SelectionManager();
        manager.selectAll(['a', 'b'], state: Tristate.yes);

        expect(
          manager.stateOf(['a', 'b', 'c', 'd', 'e']),
          equals(SelectionState.partial),
        );
      });

      test('should work with dynamic regrouping', () {
        final manager = SelectionManager();
        manager.selectAll(['task1', 'task2', 'task3'], state: Tristate.yes);

        // User groups by Status
        final activeItems = ['task1', 'task2', 'task4', 'task5'];
        final completedItems = ['task3', 'task6'];

        expect(manager.stateOf(activeItems), equals(SelectionState.partial));
        expect(manager.stateOf(completedItems), equals(SelectionState.partial));

        // User changes grouping to Priority
        final highPriority = ['task1', 'task3'];
        final lowPriority = ['task2', 'task4', 'task5', 'task6'];

        // Same selections, different grouping - still works!
        expect(manager.stateOf(highPriority), equals(SelectionState.all));
        expect(manager.stateOf(lowPriority), equals(SelectionState.partial));
      });

      test('should work with specific scope for stateOf', () {
        final manager = SelectionManager();
        manager.selectAll(['a', 'b', 'c'], scope: 'tabA', state: Tristate.yes);

        expect(
          manager.stateOf(['a', 'b', 'c'], scope: 'tabA'),
          equals(SelectionState.all),
        );
        expect(
          manager.stateOf(['a', 'b', 'c']),
          equals(SelectionState.none),
        );
      });
    });

    group('tree operations', () {
      late SelectionManager manager;
      late Map<String, List<String>> tree;
      late Map<String, List<String>> filesInFolder;

      Iterable<String> childrenOf(String key) => tree[key] ?? const [];
      Iterable<String> keysIn(String folder) => filesInFolder[folder] ?? [];

      setUp(() {
        // Tree structure: folders contain subfolders
        tree = {
          'root': ['folder1', 'folder2'],
          'folder1': [],
          'folder2': [],
        };

        // Files in each folder (selectable items)
        filesInFolder = {
          'folder1': ['file1', 'file2'],
          'folder2': ['file3', 'file4'],
        };

        manager = SelectionManager();
      });

      group('countInTree', () {
        test('should count selections in node and all descendants', () {
          manager.selectAll(['file1', 'file2', 'file3'], state: Tristate.yes);

          expect(
            manager.countInTree(
              'root',
              keysIn: keysIn,
              childrenOf: childrenOf,
            ),
            equals(3),
          );
          expect(
            manager.countInTree(
              'folder1',
              keysIn: keysIn,
              childrenOf: childrenOf,
            ),
            equals(2),
          );
          expect(
            manager.countInTree(
              'folder2',
              keysIn: keysIn,
              childrenOf: childrenOf,
            ),
            equals(1),
          );
        });

        test('should handle leaf nodes with no children or keys', () {
          expect(
            manager.countInTree(
              'nonExistent',
              keysIn: keysIn,
              childrenOf: childrenOf,
            ),
            equals(0),
          );
        });

        test('should return 0 for empty tree', () {
          expect(
            manager.countInTree(
              'root',
              keysIn: keysIn,
              childrenOf: childrenOf,
            ),
            equals(0),
          );
        });

        test('should work with specific scope for countInTree', () {
          manager.selectAll(
            ['file1', 'file2'],
            scope: 'tabA',
            state: Tristate.yes,
          );

          expect(
            manager.countInTree(
              'root',
              scope: 'tabA',
              keysIn: keysIn,
              childrenOf: childrenOf,
            ),
            equals(2),
          );
          expect(
            manager.countInTree(
              'root',
              keysIn: keysIn,
              childrenOf: childrenOf,
            ),
            equals(0),
          );
        });
      });

      group('stateOfTree', () {
        test('should return none when no selections in tree', () {
          expect(
            manager.stateOfTree(
              'root',
              totalKeys: 4,
              keysIn: keysIn,
              childrenOf: childrenOf,
            ),
            equals(SelectionState.none),
          );
        });

        test('should return all when all selections in tree', () {
          manager.selectAll(
            ['file1', 'file2', 'file3', 'file4'],
            state: Tristate.yes,
          );

          expect(
            manager.stateOfTree(
              'root',
              totalKeys: 4,
              keysIn: keysIn,
              childrenOf: childrenOf,
            ),
            equals(SelectionState.all),
          );
        });

        test('should return partial when some selections in tree', () {
          manager.selectAll(['file1', 'file3'], state: Tristate.yes);

          expect(
            manager.stateOfTree(
              'root',
              totalKeys: 4,
              keysIn: keysIn,
              childrenOf: childrenOf,
            ),
            equals(SelectionState.partial),
          );
        });

        test('should return none when totalKeys is 0', () {
          manager.select('file1');

          expect(
            manager.stateOfTree(
              'root',
              totalKeys: 0,
              keysIn: keysIn,
              childrenOf: childrenOf,
            ),
            equals(SelectionState.none),
          );
        });

        test('should return none when totalKeys is negative', () {
          manager.select('file1');

          expect(
            manager.stateOfTree(
              'root',
              totalKeys: -1,
              keysIn: keysIn,
              childrenOf: childrenOf,
            ),
            equals(SelectionState.none),
          );
        });

        test('should work with specific scope for stateOfTree', () {
          manager.selectAll(
            ['file1', 'file2', 'file3', 'file4'],
            scope: 'tabA',
            state: Tristate.yes,
          );

          expect(
            manager.stateOfTree(
              'root',
              totalKeys: 4,
              scope: 'tabA',
              keysIn: keysIn,
              childrenOf: childrenOf,
            ),
            equals(SelectionState.all),
          );
          expect(
            manager.stateOfTree(
              'root',
              totalKeys: 4,
              keysIn: keysIn,
              childrenOf: childrenOf,
            ),
            equals(SelectionState.none),
          );
        });
      });
    });

    group('Listenable', () {
      test('should add and remove listeners correctly', () {
        final manager = SelectionManager();
        var notifyCount = 0;
        void listener() => notifyCount++;

        manager.addChangeListener(listener);
        manager.select('a');
        expect(notifyCount, equals(1));

        manager.removeChangeListener(listener);
        manager.select('b');
        expect(notifyCount, equals(1));
      });

      test('should return correct state from hasListeners', () {
        final manager = SelectionManager();
        void listener() {}

        expect(manager.hasListeners, isFalse);

        manager.addChangeListener(listener);
        expect(manager.hasListeners, isTrue);

        manager.removeChangeListener(listener);
        expect(manager.hasListeners, isFalse);
      });
    });

    group('dispose', () {
      test('should clear all selections', () {
        final manager = SelectionManager();
        manager.select('a');
        manager.select('b', scope: 'scopeA');

        manager.dispose();

        expect(manager.isEmpty, isTrue);
      });

      test('should clear listeners', () {
        final manager = SelectionManager();
        manager.addChangeListener(() {});

        manager.dispose();

        expect(manager.hasListeners, isFalse);
      });
    });

    group('toString', () {
      test('should return descriptive string', () {
        final manager = SelectionManager();
        manager.select('a');
        manager.select('b', scope: 'scopeA');

        final result = manager.toString();

        expect(result, contains('SelectionManager'));
        expect(result, contains('scopes: 2'));
        expect(result, contains('selected: 2'));
      });
    });
  });

  group('integration scenarios', () {
    test('should persist selections with dynamic grouping in table', () {
      final manager = SelectionManager();

      // Select items (flat storage)
      manager.selectAll(['1', '2', '3', '4', '5'], state: Tristate.yes);

      // User groups by Status
      final activeItems = ['1', '2', '3'];
      final archivedItems = ['4', '5', '6', '7', '8'];

      expect(manager.stateOf(activeItems), equals(SelectionState.all));
      expect(manager.stateOf(archivedItems), equals(SelectionState.partial));
      expect(manager.count, equals(5));

      // User changes grouping to Priority - selections persist!
      final highPriority = ['1', '4'];
      final lowPriority = ['2', '3', '5', '6', '7', '8'];

      expect(manager.stateOf(highPriority), equals(SelectionState.all));
      expect(manager.stateOf(lowPriority), equals(SelectionState.partial));
    });

    test('should maintain independent selections using scopes in tabs', () {
      final manager = SelectionManager();

      // Tab A selections
      manager.selectAll(['a', 'b', 'c'], scope: 'tabA', state: Tristate.yes);

      // Tab B selections (same items, different scope)
      manager.selectAll(['a', 'd', 'e'], scope: 'tabB', state: Tristate.yes);

      // Query Tab A
      expect(
        manager.stateOf(['a', 'b', 'c'], scope: 'tabA'),
        equals(SelectionState.all),
      );
      expect(manager.countAllIn(scope: 'tabA'), equals(3));

      // Query Tab B
      expect(
        manager.stateOf(['a', 'd', 'e'], scope: 'tabB'),
        equals(SelectionState.all),
      );
      expect(manager.countAllIn(scope: 'tabB'), equals(3));

      // Clear only Tab A
      manager.clear(scope: 'tabA');

      expect(manager.countAllIn(scope: 'tabA'), equals(0));
      expect(manager.countAllIn(scope: 'tabB'), equals(3));
    });

    test('should handle file tree with nested folders', () {
      // Tree structure
      final tree = <String, List<String>>{
        'src': ['src/lib', 'src/test'],
        'src/lib': [],
        'src/test': [],
      };

      // Files in each folder
      final filesInFolder = <String, List<String>>{
        'src/lib': ['src/lib/main.dart', 'src/lib/utils.dart'],
        'src/test': ['src/test/main_test.dart'],
      };

      Iterable<String> childrenOf(String key) => tree[key] ?? const [];
      Iterable<String> keysIn(String folder) => filesInFolder[folder] ?? [];

      final manager = SelectionManager();

      manager.select('src/lib/main.dart');

      expect(
        manager.stateOfTree(
          'src',
          totalKeys: 3,
          keysIn: keysIn,
          childrenOf: childrenOf,
        ),
        equals(SelectionState.partial),
      );
      expect(
        manager.stateOfTree(
          'src/lib',
          totalKeys: 2,
          keysIn: keysIn,
          childrenOf: childrenOf,
        ),
        equals(SelectionState.partial),
      );

      manager.select('src/lib/utils.dart');

      expect(
        manager.stateOfTree(
          'src/lib',
          totalKeys: 2,
          keysIn: keysIn,
          childrenOf: childrenOf,
        ),
        equals(SelectionState.all),
      );
      expect(
        manager.stateOfTree(
          'src',
          totalKeys: 3,
          keysIn: keysIn,
          childrenOf: childrenOf,
        ),
        equals(SelectionState.partial),
      );

      manager.select('src/test/main_test.dart');

      expect(
        manager.stateOfTree(
          'src',
          totalKeys: 3,
          keysIn: keysIn,
          childrenOf: childrenOf,
        ),
        equals(SelectionState.all),
      );
    });

    test('should handle checkbox toggle behavior with query-time grouping', () {
      final manager = SelectionManager();

      final items = ['a', 'b', 'c', 'd', 'e'];

      var currentState = manager.stateOf(items);
      expect(currentState, equals(SelectionState.none));

      // Click "Select All" when none selected
      if (currentState == SelectionState.none) {
        manager.selectAll(items, state: Tristate.yes);
      }
      expect(manager.stateOf(items), equals(SelectionState.all));

      // Deselect one item
      manager.select('c', state: Tristate.no);
      expect(manager.stateOf(items), equals(SelectionState.partial));

      // Click "Select All" when partial - should select all
      currentState = manager.stateOf(items);
      if (currentState == SelectionState.partial) {
        manager.selectAll(items, state: Tristate.yes);
      }
      expect(manager.stateOf(items), equals(SelectionState.all));

      // Click "Select All" when all selected - should deselect all
      currentState = manager.stateOf(items);
      if (currentState == SelectionState.all) {
        manager.selectAll(items, state: Tristate.no);
      }
      expect(manager.stateOf(items), equals(SelectionState.none));
    });

    test('should support injection pattern where controller owns tree', () {
      final manager = SelectionManager();

      // Controller owns the tree structure
      final tree = <String, List<String>>{
        'root': ['group1', 'group2'],
        'group1': [],
        'group2': [],
      };
      final itemsInGroup = <String, List<String>>{
        'group1': ['item1', 'item2'],
        'group2': ['item3'],
      };

      Iterable<String> childrenOf(String key) => tree[key] ?? const [];
      Iterable<String> keysIn(String key) => itemsInGroup[key] ?? [];

      // Select an item
      manager.select('item1');

      final state = manager.stateOfTree(
        'root',
        totalKeys: 3,
        keysIn: keysIn,
        childrenOf: childrenOf,
      );

      expect(state, equals(SelectionState.partial));

      // Select remaining items
      manager.select('item2');
      manager.select('item3');

      final finalState = manager.stateOfTree(
        'root',
        totalKeys: 3,
        keysIn: keysIn,
        childrenOf: childrenOf,
      );

      expect(finalState, equals(SelectionState.all));
    });
  });

  group('SelectionManager state serialization', () {
    group('captureState', () {
      test('should return empty snapshot for empty manager', () {
        final manager = SelectionManager();

        final snapshot = manager.captureState();

        expect(snapshot.isEmpty, isTrue);
        expect(snapshot.isNotEmpty, isFalse);
        expect(snapshot.length, equals(0));
        expect(snapshot.keys, isEmpty);
      });

      test('should capture selections from default scope only', () {
        final manager = SelectionManager();
        manager.select('a');
        manager.select('b');
        manager.select('c', scope: 'otherScope');

        final snapshot = manager.captureState();

        expect(snapshot.keys, equals({'a', 'b'}));
        expect(snapshot.contains('a'), isTrue);
        expect(snapshot.contains('b'), isTrue);
        expect(snapshot.contains('c'), isFalse);
      });

      test('should return immutable snapshot', () {
        final manager = SelectionManager();
        manager.select('a');

        final snapshot = manager.captureState();

        expect(
          () => (snapshot.keys as Set).add('x'),
          throwsUnsupportedError,
        );
      });
    });

    group('restoreState', () {
      test('should restore empty snapshot by clearing default scope', () {
        final manager = SelectionManager();
        manager.select('a');
        manager.select('b');

        manager.restoreState(const SelectionSnapshot.empty());

        expect(manager.isEmpty, isTrue);
      });

      test('should restore snapshot to default scope', () {
        final manager = SelectionManager();

        final snapshot = SelectionSnapshot.fromKeys(const {'x', 'y', 'z'});
        manager.restoreState(snapshot);

        expect(manager.isSelected('x'), isTrue);
        expect(manager.isSelected('y'), isTrue);
        expect(manager.isSelected('z'), isTrue);
        expect(manager.count, equals(3));
      });

      test('should replace existing default scope selections', () {
        final manager = SelectionManager();
        manager.select('a');
        manager.select('b');

        final snapshot = SelectionSnapshot.fromKeys(const {'x', 'y'});
        manager.restoreState(snapshot);

        expect(manager.isSelected('a'), isFalse);
        expect(manager.isSelected('b'), isFalse);
        expect(manager.isSelected('x'), isTrue);
        expect(manager.isSelected('y'), isTrue);
      });

      test('should not affect scoped selections', () {
        final manager = SelectionManager();
        manager.select('scopedItem', scope: 'myScope');

        final snapshot = SelectionSnapshot.fromKeys(const {'x'});
        manager.restoreState(snapshot);

        expect(manager.isSelected('scopedItem', scope: 'myScope'), isTrue);
        expect(manager.isSelected('x'), isTrue);
      });

      test('should notify listeners', () {
        final manager = SelectionManager();
        var notified = false;
        manager.addChangeListener(() => notified = true);

        final snapshot = SelectionSnapshot.fromKeys(const {'x'});
        manager.restoreState(snapshot);

        expect(notified, isTrue);
      });
    });
  });

  group('SelectionSnapshot', () {
    group('construction', () {
      test('empty() should create empty snapshot', () {
        const snapshot = SelectionSnapshot.empty();

        expect(snapshot.isEmpty, isTrue);
        expect(snapshot.isNotEmpty, isFalse);
        expect(snapshot.length, equals(0));
        expect(snapshot.keys, isEmpty);
      });

      test('fromKeys should create snapshot with given keys', () {
        final snapshot = SelectionSnapshot.fromKeys(const {'a', 'b', 'c'});

        expect(snapshot.isEmpty, isFalse);
        expect(snapshot.isNotEmpty, isTrue);
        expect(snapshot.length, equals(3));
        expect(snapshot.keys, equals({'a', 'b', 'c'}));
      });

      test('fromKeys with empty set should return empty snapshot', () {
        final snapshot = SelectionSnapshot.fromKeys(const <String>{});

        expect(snapshot.isEmpty, isTrue);
      });
    });

    group('contains', () {
      test('should return true for keys in snapshot', () {
        final snapshot = SelectionSnapshot.fromKeys(const {'a', 'b'});

        expect(snapshot.contains('a'), isTrue);
        expect(snapshot.contains('b'), isTrue);
      });

      test('should return false for keys not in snapshot', () {
        final snapshot = SelectionSnapshot.fromKeys(const {'a', 'b'});

        expect(snapshot.contains('c'), isFalse);
        expect(snapshot.contains('x'), isFalse);
      });
    });

    group('toJson', () {
      test('should serialize String keys', () {
        final snapshot = SelectionSnapshot.fromKeys(const {'a', 'b', 'c'});

        final json = snapshot.toJson();

        expect(json, containsPair('keys', containsAll(['a', 'b', 'c'])));
      });

      test('should serialize numeric string keys', () {
        final snapshot = SelectionSnapshot.fromKeys(const {'1', '2', '3'});

        final json = snapshot.toJson();

        expect(json, containsPair('keys', containsAll(['1', '2', '3'])));
      });

      test('should serialize empty snapshot', () {
        const snapshot = SelectionSnapshot.empty();

        final json = snapshot.toJson();

        expect(json, containsPair('keys', isEmpty));
      });
    });

    group('fromJson', () {
      test('should deserialize String keys', () {
        final json = {
          'keys': ['a', 'b', 'c'],
        };

        final snapshot = SelectionSnapshot.fromJson(json);

        expect(snapshot.keys, equals({'a', 'b', 'c'}));
      });

      test('should deserialize numeric string keys', () {
        final json = {
          'keys': ['1', '2', '3'],
        };

        final snapshot = SelectionSnapshot.fromJson(json);

        expect(snapshot.keys, equals({'1', '2', '3'}));
      });

      test('should return empty snapshot for null keys', () {
        final json = <String, dynamic>{'keys': null};

        final snapshot = SelectionSnapshot.fromJson(json);

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty snapshot for empty keys list', () {
        final json = <String, dynamic>{'keys': <String>[]};

        final snapshot = SelectionSnapshot.fromJson(json);

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty snapshot for missing keys field', () {
        final json = <String, dynamic>{};

        final snapshot = SelectionSnapshot.fromJson(json);

        expect(snapshot.isEmpty, isTrue);
      });
    });

    group('toQueryString', () {
      test('should serialize String keys', () {
        final snapshot = SelectionSnapshot.fromKeys(const {'a', 'b', 'c'});

        final query = snapshot.toQueryString();

        expect(query, startsWith('selected='));
        expect(query, contains('a'));
        expect(query, contains('b'));
        expect(query, contains('c'));
      });

      test('should URL encode special characters', () {
        final snapshot =
            SelectionSnapshot.fromKeys(const {'hello world', 'a=b'});

        final query = snapshot.toQueryString();

        expect(query, contains('hello%20world'));
        expect(query, contains('a%3Db'));
      });

      test('should return empty string for empty snapshot', () {
        const snapshot = SelectionSnapshot.empty();

        final query = snapshot.toQueryString();

        expect(query, isEmpty);
      });

      test('should serialize numeric string keys', () {
        final snapshot = SelectionSnapshot.fromKeys(const {'1', '2', '3'});

        final query = snapshot.toQueryString();

        expect(query, startsWith('selected='));
        expect(query, contains('1'));
        expect(query, contains('2'));
        expect(query, contains('3'));
      });
    });

    group('fromQueryString', () {
      test('should parse String keys', () {
        const query = 'selected=a,b,c';

        final snapshot = SelectionSnapshot.fromQueryString(query);

        expect(snapshot.keys, equals({'a', 'b', 'c'}));
      });

      test('should parse numeric string keys', () {
        const query = 'selected=1,2,3';

        final snapshot = SelectionSnapshot.fromQueryString(query);

        expect(snapshot.keys, equals({'1', '2', '3'}));
      });

      test('should URL decode special characters', () {
        const query = 'selected=hello%20world,a%3Db';

        final snapshot = SelectionSnapshot.fromQueryString(query);

        expect(snapshot.keys, contains('hello world'));
        expect(snapshot.keys, contains('a=b'));
      });

      test('should return empty snapshot for empty query', () {
        final snapshot = SelectionSnapshot.fromQueryString('');

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty snapshot for missing selected param', () {
        const query = 'other=value';

        final snapshot = SelectionSnapshot.fromQueryString(query);

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty snapshot for empty selected value', () {
        const query = 'selected=';

        final snapshot = SelectionSnapshot.fromQueryString(query);

        expect(snapshot.isEmpty, isTrue);
      });

      test('should handle query with other parameters', () {
        const query = 'filter=active&selected=a,b&sort=name';

        final snapshot = SelectionSnapshot.fromQueryString(query);

        expect(snapshot.keys, equals({'a', 'b'}));
      });
    });

    // Note: fromQueryStringWith was removed when K type param was removed.
    // Keys are now always String, parsed directly from the query string.

    group('equality', () {
      test('should be equal for same keys', () {
        final snapshot1 = SelectionSnapshot.fromKeys(const {'a', 'b'});
        final snapshot2 = SelectionSnapshot.fromKeys(const {'a', 'b'});

        expect(snapshot1, equals(snapshot2));
        expect(snapshot1.hashCode, equals(snapshot2.hashCode));
      });

      test('should not be equal for different keys', () {
        final snapshot1 = SelectionSnapshot.fromKeys(const {'a', 'b'});
        final snapshot2 = SelectionSnapshot.fromKeys(const {'a', 'c'});

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('should not be equal for different key count', () {
        final snapshot1 = SelectionSnapshot.fromKeys(const {'a', 'b'});
        final snapshot2 = SelectionSnapshot.fromKeys(const {'a', 'b', 'c'});

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('should be equal to itself', () {
        final snapshot = SelectionSnapshot.fromKeys(const {'a', 'b'});

        expect(snapshot, equals(snapshot));
      });

      test('should not be equal to different type', () {
        final snapshot = SelectionSnapshot.fromKeys(const {'a', 'b'});
        // Comparing with a different type to test the equality operator.
        const dynamic other = 'not a snapshot';

        expect(snapshot == other, isFalse);
      });

      test('empty snapshots should be equal', () {
        const snapshot1 = SelectionSnapshot.empty();
        const snapshot2 = SelectionSnapshot.empty();

        expect(snapshot1, equals(snapshot2));
      });
    });

    group('toString', () {
      test('should return readable representation', () {
        final snapshot = SelectionSnapshot.fromKeys(const {'a', 'b'});

        expect(snapshot.toString(), contains('SelectionSnapshot'));
        expect(snapshot.toString(), contains('a'));
        expect(snapshot.toString(), contains('b'));
      });
    });

    group('roundtrip', () {
      test('should roundtrip through JSON', () {
        final original = SelectionSnapshot.fromKeys(const {'a', 'b', 'c'});

        final json = original.toJson();
        final restored = SelectionSnapshot.fromJson(json);

        expect(restored, equals(original));
      });

      test('should roundtrip through query string', () {
        final original = SelectionSnapshot.fromKeys(const {'a', 'b', 'c'});

        final query = original.toQueryString();
        final restored = SelectionSnapshot.fromQueryString(query);

        expect(restored.keys, equals(original.keys));
      });

      test('should roundtrip numeric string keys through JSON', () {
        final original = SelectionSnapshot.fromKeys(const {'1', '2', '3'});

        final json = original.toJson();
        final restored = SelectionSnapshot.fromJson(json);

        expect(restored, equals(original));
      });
    });

    // Note: Complex type tests removed - keys are now always String.
    // Tests for int, bool, List, and custom object keys are no longer needed.
  });
}
// Note: Helper classes _JsonableKey and _NonJsonableKey were removed
// when K type parameter was removed. Keys are now always String.
