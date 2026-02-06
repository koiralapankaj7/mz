// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

import 'package:meta/meta.dart';
import 'package:mz_collection/src/node.dart';
import 'package:test/test.dart';

/// Simple test item.
@immutable
class Item {
  const Item(this.id, {this.value = 0});

  final String id;
  final int value;

  @override
  bool operator ==(Object other) =>
      other is Item && other.id == id && other.value == value;

  @override
  int get hashCode => Object.hash(id, value);

  @override
  String toString() => 'Item($id, $value)';
}

void main() {
  group('Node', () {
    late Node<Item> node;

    setUp(() {
      node = Node<Item>(
        id: 'root',
        keyOf: (item) => item.id,
      );
    });

    group('constructor', () {
      test('creates empty node', () {
        expect(node.id, 'root');
        expect(node.isEmpty, true);
        expect(node.length, 0);
        expect(node.childCount, 0);
      });

      test('creates node with initial items', () {
        final n = Node<Item>(
          id: 'test',
          keyOf: (i) => i.id,
          items: [const Item('a'), const Item('b'), const Item('c')],
        );
        expect(n.length, 3);
        expect(n['a'], isNotNull);
        expect(n['b'], isNotNull);
        expect(n['c'], isNotNull);
      });

      test('creates node with initial children', () {
        final child1 = Node<Item>(id: 'c1', keyOf: (i) => i.id);
        final child2 = Node<Item>(id: 'c2', keyOf: (i) => i.id);
        final n = Node<Item>(
          id: 'test',
          keyOf: (i) => i.id,
          children: [child1, child2],
        );
        expect(n.childCount, 2);
        expect(n.child('c1'), child1);
        expect(n.child('c2'), child2);
        expect(child1.parent, n);
        expect(child2.parent, n);
      });

      test('stores extra data', () {
        final n = Node<Item>(
          id: 'test',
          keyOf: (i) => i.id,
          extra: {'metadata': 'value'},
        );
        expect(n.extra, {'metadata': 'value'});
      });
    });

    group('add', () {
      test('adds item to node', () {
        final result = node.add(const Item('1'));
        expect(result, true);
        expect(node.length, 1);
        expect(node['1'], isNotNull);
      });

      test('returns false if key already exists', () {
        node.add(const Item('1'));
        final result = node.add(const Item('1', value: 99));
        expect(result, false);
        expect(node.length, 1);
        expect(node['1']!.value, 0); // Original item unchanged
      });

      test('increments version', () {
        final v = node.version;
        node.add(const Item('1'));
        expect(node.version, v + 1);
      });

      test('notifies listeners', () {
        var notified = false;
        node.addChangeListener(() => notified = true);
        node.add(const Item('1'));
        expect(notified, true);
      });

      test('does not notify when notify: false', () {
        var notified = false;
        node.addChangeListener(() => notified = true);
        node.add(const Item('1'), notify: false);
        expect(notified, false);
      });
    });

    group('addAll', () {
      test('adds multiple items', () {
        final count =
            node.addAll([const Item('a'), const Item('b'), const Item('c')]);
        expect(count, 3);
        expect(node.length, 3);
      });

      test('returns count of items actually added', () {
        node.add(const Item('b'));
        final count =
            node.addAll([const Item('a'), const Item('b'), const Item('c')]);
        expect(count, 2); // 'b' already exists
        expect(node.length, 3);
      });

      test('notifies once', () {
        var notifyCount = 0;
        node.addChangeListener(() => notifyCount++);
        node.addAll([const Item('a'), const Item('b'), const Item('c')]);
        expect(notifyCount, 1);
      });

      test('does not notify if no items added', () {
        node.add(const Item('a'));
        var notified = false;
        node.addChangeListener(() => notified = true);
        node.addAll([const Item('a')]);
        expect(notified, false);
      });
    });

    group('insert', () {
      test('inserts at index', () {
        node.addAll([const Item('a'), const Item('c')]);
        final result = node.insert(1, const Item('b'));
        expect(result, true);
        expect(node.at(0).id, 'a');
        expect(node.at(1).id, 'b');
        expect(node.at(2).id, 'c');
      });

      test('returns false if key exists', () {
        node.add(const Item('a'));
        final result = node.insert(0, const Item('a'));
        expect(result, false);
      });
    });

    group('remove', () {
      test('removes item', () {
        node.add(const Item('1'));
        final removed = node.remove(const Item('1'));
        expect(removed, isNotNull);
        expect(removed!.id, '1');
        expect(node.isEmpty, true);
      });

      test('returns null if not found', () {
        final removed = node.remove(const Item('nonexistent'));
        expect(removed, isNull);
      });

      test('removes from both list and map', () {
        node.add(const Item('1'));
        node.remove(const Item('1'));
        expect(node.containsKey('1'), false);
        expect(node.length, 0);
      });
    });

    group('removeByKey', () {
      test('removes item by key', () {
        node.add(const Item('1'));
        final removed = node.removeByKey('1');
        expect(removed!.id, '1');
        expect(node.isEmpty, true);
      });

      test('returns null if key not found', () {
        final removed = node.removeByKey('nonexistent');
        expect(removed, isNull);
      });
    });

    group('removeWhere', () {
      test('removes matching items', () {
        node.addAll(
          [
            const Item('a', value: 1),
            const Item('b', value: 2),
            const Item('c', value: 3),
          ],
        );
        final removed = node.removeWhere((i) => i.value > 1);
        expect(removed.length, 2);
        expect(node.length, 1);
        expect(node['a'], isNotNull);
      });

      test('returns empty list if none match', () {
        node.addAll([const Item('a'), const Item('b')]);
        final removed = node.removeWhere((i) => i.value > 100);
        expect(removed, isEmpty);
      });

      test('does not notify if none removed', () {
        node.add(const Item('a'));
        var notified = false;
        node.addChangeListener(() => notified = true);
        node.removeWhere((i) => i.value > 100);
        expect(notified, false);
      });
    });

    group('replace', () {
      test('replaces existing item', () {
        node.add(const Item('1', value: 10));
        final replaced = node.replace(const Item('1', value: 20));
        expect(replaced, true);
        expect(node['1']!.value, 20);
        expect(node.length, 1);
      });

      test('adds if not found', () {
        final replaced = node.replace(const Item('1'));
        expect(replaced, false);
        expect(node.length, 1);
      });
    });

    group('replaceByKey', () {
      test('replaces at old key', () {
        node.add(const Item('old', value: 10));
        final result = node.replaceByKey('old', const Item('new', value: 20));
        expect(result, true);
        expect(node.containsKey('old'), false);
        expect(node['new']!.value, 20);
      });

      test('returns false if old key not found', () {
        final result = node.replaceByKey('nonexistent', const Item('new'));
        expect(result, false);
      });
    });

    group('clear', () {
      test('clears all items', () {
        node.addAll([const Item('a'), const Item('b'), const Item('c')]);
        final result = node.clear();
        expect(result, true);
        expect(node.isEmpty, true);
      });

      test('returns false if already empty', () {
        final result = node.clear();
        expect(result, false);
      });
    });

    group('sort', () {
      test('sorts items', () {
        node.addAll(
          [
            const Item('c', value: 3),
            const Item('a', value: 1),
            const Item('b', value: 2),
          ],
        );
        node.sort((a, b) => a.value.compareTo(b.value));
        expect(node.at(0).id, 'a');
        expect(node.at(1).id, 'b');
        expect(node.at(2).id, 'c');
      });
    });

    group('upsert', () {
      test('adds new item and returns true', () {
        final result = node.upsert(const Item('a', value: 1));
        expect(result, true);
        expect(node.length, 1);
        expect(node['a']!.value, 1);
      });

      test('updates existing item and returns false', () {
        node.add(const Item('a', value: 1));
        final result = node.upsert(const Item('a', value: 2));
        expect(result, false);
        expect(node.length, 1);
        expect(node['a']!.value, 2);
      });
    });

    group('upsertAll', () {
      test('adds new items and returns count', () {
        final count = node.upsertAll([
          const Item('a', value: 1),
          const Item('b', value: 2),
        ]);
        expect(count, 2);
        expect(node.length, 2);
      });

      test('updates existing and adds new', () {
        node.add(const Item('a', value: 1));
        final count = node.upsertAll([
          const Item('a', value: 10), // update
          const Item('b', value: 2), // add
        ]);
        expect(count, 1); // only 1 was added
        expect(node.length, 2);
        expect(node['a']!.value, 10);
        expect(node['b']!.value, 2);
      });
    });

    group('updateAll', () {
      test('transforms all items', () {
        node.addAll([
          const Item('a', value: 1),
          const Item('b', value: 2),
        ]);
        node.updateAll((item) => Item(item.id, value: item.value * 10));
        expect(node['a']!.value, 10);
        expect(node['b']!.value, 20);
      });
    });

    group('next and prev', () {
      setUp(() {
        node.addAll([
          const Item('a'),
          const Item('b'),
          const Item('c'),
        ]);
      });

      test('next returns next item', () {
        expect(node.next(const Item('a'))!.id, 'b');
        expect(node.next(const Item('b'))!.id, 'c');
      });

      test('next returns null at end', () {
        expect(node.next(const Item('c')), isNull);
      });

      test('prev returns previous item', () {
        expect(node.prev(const Item('b'))!.id, 'a');
        expect(node.prev(const Item('c'))!.id, 'b');
      });

      test('prev returns null at start', () {
        expect(node.prev(const Item('a')), isNull);
      });
    });

    group('item queries', () {
      setUp(() {
        node.addAll(
          [
            const Item('a', value: 1),
            const Item('b', value: 2),
            const Item('c', value: 3),
          ],
        );
      });

      test('operator [] returns item by key', () {
        expect(node['a']!.value, 1);
        expect(node['nonexistent'], isNull);
      });

      test('at returns item at index', () {
        expect(node.at(0).id, 'a');
        expect(node.at(1).id, 'b');
        expect(node.at(2).id, 'c');
      });

      test('atOrNull returns null for invalid index', () {
        expect(node.atOrNull(-1), isNull);
        expect(node.atOrNull(100), isNull);
        expect(node.atOrNull(0), isNotNull);
      });

      test('indexOf returns correct index', () {
        expect(node.indexOf(const Item('a', value: 1)), 0);
        expect(node.indexOf(const Item('b', value: 2)), 1);
        expect(node.indexOf(const Item('nonexistent')), -1);
      });

      test('indexOf uses keyOf for matching', () {
        final n = Node<Item>(
          id: 'test',
          keyOf: (i) => i.id,
        );
        n.addAll([const Item('a', value: 1), const Item('b', value: 2)]);
        // Should match by key (id) only, ignoring value
        expect(n.indexOf(const Item('a', value: 999)), 0);
      });

      test('containsKey is O(1)', () {
        expect(node.containsKey('a'), true);
        expect(node.containsKey('nonexistent'), false);
      });

      test('keys returns all keys', () {
        expect(node.keys.toList(), containsAll(['a', 'b', 'c']));
      });
    });

    group('Iterable implementation', () {
      setUp(() {
        node.addAll([const Item('a'), const Item('b'), const Item('c')]);
      });

      test('can iterate with for-in', () {
        final ids = <String>[];
        for (final item in node) {
          ids.add(item.id);
        }
        expect(ids, ['a', 'b', 'c']);
      });

      test('where filters items', () {
        node.clear();
        node.addAll(
          [
            const Item('a', value: 1),
            const Item('b', value: 2),
            const Item('c', value: 3),
          ],
        );
        final high = node.where((i) => i.value > 1);
        expect(high.map((i) => i.id).toList(), ['b', 'c']);
      });

      test('map transforms items', () {
        final ids = node.map((i) => i.id).toList();
        expect(ids, ['a', 'b', 'c']);
      });

      test('any checks condition', () {
        expect(node.any((i) => i.id == 'a'), true);
        expect(node.any((i) => i.id == 'z'), false);
      });

      test('every checks all items', () {
        expect(node.every((i) => i.id.isNotEmpty), true);
        expect(node.every((i) => i.id == 'a'), false);
      });

      test('firstWhere finds item', () {
        final item = node.firstWhere((i) => i.id == 'b');
        expect(item.id, 'b');
      });

      test('fold accumulates', () {
        node.clear();
        node.addAll(
          [
            const Item('a', value: 1),
            const Item('b', value: 2),
            const Item('c', value: 3),
          ],
        );
        final sum = node.fold(0, (acc, i) => acc + i.value);
        expect(sum, 6);
      });

      test('take limits items', () {
        expect(node.take(2).map((i) => i.id).toList(), ['a', 'b']);
      });

      test('skip skips items', () {
        expect(node.skip(1).map((i) => i.id).toList(), ['b', 'c']);
      });

      test('first and last', () {
        expect(node.first.id, 'a');
        expect(node.last.id, 'c');
      });
    });

    group('child operations', () {
      late Node<Item> child1;
      late Node<Item> child2;

      setUp(() {
        child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
      });

      test('addChild adds child with correct parent', () {
        node.addChild(child1);
        expect(node.childCount, 1);
        expect(child1.parent, node);
        expect(child1.depth, 1);
      });

      test('removeChild removes and clears parent', () {
        node.addChild(child1);
        final removed = node.removeChild('child1');
        expect(removed, child1);
        expect(child1.parent, isNull);
        expect(node.childCount, 0);
      });

      test('removeChild returns null if not found', () {
        final removed = node.removeChild('nonexistent');
        expect(removed, isNull);
      });

      test('clearChildren removes all', () {
        node.addChild(child1);
        node.addChild(child2);
        final result = node.clearChildren();
        expect(result, true);
        expect(node.childCount, 0);
        expect(child1.parent, isNull);
        expect(child2.parent, isNull);
      });

      test('child returns child by id', () {
        node.addChild(child1);
        expect(node.child('child1'), child1);
        expect(node.child('nonexistent'), isNull);
      });

      test('children returns all children', () {
        node.addChild(child1);
        node.addChild(child2);
        expect(node.children.toList(), [child1, child2]);
      });

      test('childIds returns all child ids', () {
        node.addChild(child1);
        node.addChild(child2);
        expect(node.childIds.toList(), ['child1', 'child2']);
      });

      test('hasChildren is accurate', () {
        expect(node.hasChildren, false);
        node.addChild(child1);
        expect(node.hasChildren, true);
      });
    });

    group('tree navigation', () {
      late Node<Item> child;
      late Node<Item> grandchild;

      setUp(() {
        child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        grandchild = Node<Item>(id: 'grandchild', keyOf: (i) => i.id);
        node.addChild(child);
        child.addChild(grandchild);
      });

      test('parent is correct', () {
        expect(node.parent, isNull);
        expect(child.parent, node);
        expect(grandchild.parent, child);
      });

      test('hasParent is accurate', () {
        expect(node.hasParent, false);
        expect(child.hasParent, true);
      });

      test('depth is correct', () {
        expect(node.depth, 0);
        expect(child.depth, 1);
        expect(grandchild.depth, 2);
      });

      test('root returns root node', () {
        expect(node.root, node);
        expect(child.root, node);
        expect(grandchild.root, node);
      });

      test('parents returns path to root', () {
        final parents = grandchild.parents.toList();
        expect(parents, [child, node]);
      });
    });

    group('tree search', () {
      late Node<Item> child;
      late Node<Item> grandchild;

      setUp(() {
        child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        grandchild = Node<Item>(id: 'grandchild', keyOf: (i) => i.id);
        node.addChild(child);
        child.addChild(grandchild);

        node.add(const Item('root-item'));
        child.add(const Item('child-item'));
        grandchild.add(const Item('grandchild-item'));
      });

      test('findNode finds node by id', () {
        expect(node.findNode('root'), node);
        expect(node.findNode('child'), child);
        expect(node.findNode('grandchild'), grandchild);
        expect(node.findNode('nonexistent'), isNull);
      });

      test('findNodeByKey finds node containing key', () {
        expect(node.findNodeByKey('root-item'), node);
        expect(node.findNodeByKey('child-item'), child);
        expect(node.findNodeByKey('grandchild-item'), grandchild);
        expect(node.findNodeByKey('nonexistent'), isNull);
      });

      test('findNodeByItem finds node containing item', () {
        expect(node.findNodeByItem(const Item('root-item')), node);
        expect(node.findNodeByItem(const Item('child-item')), child);
      });
    });

    group('tree iteration', () {
      late Node<Item> child1;
      late Node<Item> child2;
      late Node<Item> grandchild;

      setUp(() {
        child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        grandchild = Node<Item>(id: 'grandchild', keyOf: (i) => i.id);

        node.addChild(child1);
        node.addChild(child2);
        child1.addChild(grandchild);

        node.add(const Item('a'));
        child1.add(const Item('b'));
        child2.add(const Item('c'));
        grandchild.add(const Item('d'));
      });

      test('descendants returns all nodes in BFS order', () {
        final ids = node.descendants().map((n) => n.id).toList();
        expect(ids, ['root', 'child1', 'child2', 'grandchild']);
      });

      test('flattenedItems returns all items', () {
        final ids = node.flattenedItems.map((i) => i.id).toList();
        expect(ids, containsAll(['a', 'b', 'c', 'd']));
      });

      test('flattenedKeys returns all keys', () {
        final keys = node.flattenedKeys.toList();
        expect(keys, containsAll(['a', 'b', 'c', 'd']));
      });

      test('flattenedLength counts all items', () {
        expect(node.flattenedLength, 4);
      });

      test('leaves returns leaf nodes', () {
        final ids = node.leaves.map((n) => n.id).toList();
        expect(ids, containsAll(['grandchild', 'child2']));
      });

      test('nodesAtDepth returns nodes at depth', () {
        expect(node.nodesAtDepth(0).map((n) => n.id).toList(), ['root']);
        expect(
          node.nodesAtDepth(1).map((n) => n.id).toList(),
          ['child1', 'child2'],
        );
        expect(node.nodesAtDepth(2).map((n) => n.id).toList(), ['grandchild']);
        expect(node.nodesAtDepth(3).toList(), isEmpty);
      });
    });

    group('listener notification', () {
      test('add notifies', () {
        var count = 0;
        node.addChangeListener(() => count++);
        node.add(const Item('a'));
        expect(count, 1);
      });

      test('remove notifies', () {
        node.add(const Item('a'));
        var count = 0;
        node.addChangeListener(() => count++);
        node.remove(const Item('a'));
        expect(count, 1);
      });

      test('addChild notifies', () {
        var count = 0;
        node.addChangeListener(() => count++);
        node.addChild(
          Node<Item>(id: 'child', keyOf: (i) => i.id),
        );
        expect(count, 1);
      });

      test('removeListener stops notifications', () {
        var count = 0;
        void listener() => count++;
        node.addChangeListener(listener);
        node.add(const Item('a'));
        expect(count, 1);
        node.removeChangeListener(listener);
        node.add(const Item('b'));
        expect(count, 1);
      });
    });

    group('dispose', () {
      test('clears items and children', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        node.add(const Item('a'));
        node.addChild(child);
        child.add(const Item('b'));

        node.dispose();

        expect(node.isEmpty, true);
        expect(node.childCount, 0);
        expect(child.isEmpty, true);
      });
    });

    group('version tracking', () {
      test('increments on modifications', () {
        expect(node.version, 0);
        node.add(const Item('a'));
        expect(node.version, 1);
        node.add(const Item('b'));
        expect(node.version, 2);
        node.remove(const Item('a'));
        expect(node.version, 3);
        node.clear();
        expect(node.version, 4);
      });

      test('increments on child modifications', () {
        final v = node.version;
        node.addChild(Node<Item>(id: 'c', keyOf: (i) => i.id));
        expect(node.version, v + 1);
        node.removeChild('c');
        expect(node.version, v + 2);
      });
    });

    group('edge cases', () {
      test('empty node iteration', () {
        expect(node.toList(), isEmpty);
        expect(node.flattenedItems.toList(), isEmpty);
      });

      test('single item', () {
        node.add(const Item('only'));
        expect(node.first.id, 'only');
        expect(node.last.id, 'only');
        expect(node.length, 1);
      });

      test('deep nesting', () {
        var current = node;
        for (var i = 0; i < 10; i++) {
          final child = Node<Item>(
            id: 'level$i',
            keyOf: (item) => item.id,
          );
          current.addChild(child);
          current = child;
        }
        expect(current.depth, 10);
        expect(current.root, node);
        expect(current.parents.length, 10);
      });

      test('wide tree', () {
        for (var i = 0; i < 100; i++) {
          node.addChild(
            Node<Item>(id: 'child$i', keyOf: (item) => item.id),
          );
        }
        expect(node.childCount, 100);
        expect(node.descendants().length, 101); // Root + 100 children
      });
    });

    group('collapse state', () {
      test('starts expanded', () {
        expect(node.isCollapsed, false);
        expect(node.isExpanded, true);
      });

      test('toggle collapses expanded node', () {
        final result = node.toggle();
        expect(result, true);
        expect(node.isCollapsed, true);
        expect(node.isExpanded, false);
      });

      test('toggle expands collapsed node', () {
        node.toggle(); // collapse
        final result = node.toggle(); // expand
        expect(result, false);
        expect(node.isCollapsed, false);
      });

      test('collapse with Tristate.yes forces collapse', () {
        node.collapse(state: Tristate.yes);
        expect(node.isCollapsed, true);

        // Already collapsed, should stay collapsed
        node.collapse(state: Tristate.yes);
        expect(node.isCollapsed, true);
      });

      test('collapse with Tristate.no forces expand', () {
        node.toggle(); // collapse first
        node.collapse(state: Tristate.no);
        expect(node.isCollapsed, false);

        // Already expanded, should stay expanded
        node.collapse(state: Tristate.no);
        expect(node.isCollapsed, false);
      });

      test('collapse notifies listeners', () {
        var notified = false;
        node.addChangeListener(() => notified = true);
        node.toggle();
        expect(notified, true);
      });

      test('collapse does not notify when notify: false', () {
        var notified = false;
        node.addChangeListener(() => notified = true);
        node.toggle(notify: false);
        expect(notified, false);
      });

      test('collapse does not notify when state unchanged', () {
        var count = 0;
        node.addChangeListener(() => count++);
        node.collapse(state: Tristate.no); // already expanded
        expect(count, 0);
      });

      test('collapse increments version', () {
        final v = node.version;
        node.toggle();
        expect(node.version, v + 1);
      });
    });

    group('expandToThis', () {
      late Node<Item> grandchild;

      setUp(() {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        grandchild = Node<Item>(id: 'grandchild', keyOf: (i) => i.id);
        node.addChild(child);
        child.addChild(grandchild);

        // Collapse ancestors
        node.toggle();
        child.toggle();
      });

      test('expands all ancestors', () {
        expect(node.isCollapsed, true);
        expect(node.child('child')!.isCollapsed, true);

        grandchild.expandToThis();

        expect(node.isCollapsed, false);
        expect(node.child('child')!.isCollapsed, false);
        expect(grandchild.isCollapsed, false); // unchanged
      });

      test('notifies ancestors', () {
        var nodeNotified = false;
        var childNotified = false;
        node.addChangeListener(() => nodeNotified = true);
        node.child('child')!.addChangeListener(() => childNotified = true);

        grandchild.expandToThis();

        expect(nodeNotified, true);
        expect(childNotified, true);
      });

      test('does not notify when notify: false', () {
        var notified = false;
        node.addChangeListener(() => notified = true);

        grandchild.expandToThis(notify: false);

        expect(notified, false);
        expect(node.isExpanded, true); // still expanded
      });
    });

    group('collapseToLevel', () {
      late Node<Item> child1;
      late Node<Item> child2;
      late Node<Item> grandchild;

      setUp(() {
        child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        grandchild = Node<Item>(id: 'grandchild', keyOf: (i) => i.id);

        node.addChild(child1);
        node.addChild(child2);
        child1.addChild(grandchild);
      });

      test('level 0 collapses root', () {
        node.collapseToLevel(0);

        expect(node.isCollapsed, true);
        expect(child1.isCollapsed, true);
        expect(child2.isCollapsed, true);
        expect(grandchild.isCollapsed, true);
      });

      test('level 1 expands root, collapses children', () {
        node.collapseToLevel(1);

        expect(node.isCollapsed, false);
        expect(child1.isCollapsed, true);
        expect(child2.isCollapsed, true);
        expect(grandchild.isCollapsed, true);
      });

      test('level 2 expands root and children', () {
        node.collapseToLevel(2);

        expect(node.isCollapsed, false);
        expect(child1.isCollapsed, false);
        expect(child2.isCollapsed, false);
        expect(grandchild.isCollapsed, true);
      });

      test('high level expands everything', () {
        // First collapse everything
        node.collapseAll();

        node.collapseToLevel(100);

        expect(node.isCollapsed, false);
        expect(child1.isCollapsed, false);
        expect(child2.isCollapsed, false);
        expect(grandchild.isCollapsed, false);
      });

      test('notifies changed nodes', () {
        var nodeCount = 0;
        var child1Count = 0;
        node.addChangeListener(() => nodeCount++);
        child1.addChangeListener(() => child1Count++);

        node.collapseToLevel(1);

        expect(child1Count, 1); // collapsed
        // node might or might not notify depending on initial state
      });
    });

    group('expandAll', () {
      test('expands all descendants', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        final grandchild = Node<Item>(
          id: 'grandchild',
          keyOf: (i) => i.id,
        );
        node.addChild(child);
        child.addChild(grandchild);

        // Collapse all
        node.toggle();
        child.toggle();
        grandchild.toggle();

        node.expandAll();

        expect(node.isExpanded, true);
        expect(child.isExpanded, true);
        expect(grandchild.isExpanded, true);
      });

      test('does nothing when all expanded', () {
        var notified = false;
        node.addChangeListener(() => notified = true);

        node.expandAll();

        expect(notified, false);
      });
    });

    group('collapseAll', () {
      test('collapses all descendants', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        final grandchild = Node<Item>(
          id: 'grandchild',
          keyOf: (i) => i.id,
        );
        node.addChild(child);
        child.addChild(grandchild);

        node.collapseAll();

        expect(node.isCollapsed, true);
        expect(child.isCollapsed, true);
        expect(grandchild.isCollapsed, true);
      });

      test('does nothing when all collapsed', () {
        node.toggle(); // collapse

        var notified = false;
        node.addChangeListener(() => notified = true);

        node.collapseAll();

        expect(notified, false);
      });
    });

    group('visibleDescendants', () {
      test('returns all when nothing collapsed', () {
        final child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        final child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        final grandchild = Node<Item>(
          id: 'grandchild',
          keyOf: (i) => i.id,
        );
        node.addChild(child1);
        node.addChild(child2);
        child1.addChild(grandchild);

        final visible = node.visibleDescendants().toList();
        expect(visible.length, 4);
        expect(
          visible.map((n) => n.id),
          ['root', 'child1', 'child2', 'grandchild'],
        );
      });

      test('hides children of collapsed nodes', () {
        final child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        final child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        final grandchild = Node<Item>(
          id: 'grandchild',
          keyOf: (i) => i.id,
        );
        node.addChild(child1);
        node.addChild(child2);
        child1.addChild(grandchild);

        child1.toggle(); // collapse child1

        final visible = node.visibleDescendants().toList();
        expect(visible.length, 3);
        expect(visible.map((n) => n.id), ['root', 'child1', 'child2']);
        // grandchild is hidden because child1 is collapsed
      });

      test('collapsed root only shows root', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        node.addChild(child);

        node.toggle(); // collapse root

        final visible = node.visibleDescendants().toList();
        expect(visible.length, 1);
        expect(visible.first.id, 'root');
      });
    });

    group('DFS traversal', () {
      late Node<Item> child1;
      late Node<Item> child2;
      late Node<Item> grandchild1;
      late Node<Item> grandchild2;

      setUp(() {
        child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        grandchild1 = Node<Item>(id: 'grandchild1', keyOf: (i) => i.id);
        grandchild2 = Node<Item>(id: 'grandchild2', keyOf: (i) => i.id);

        node.addChild(child1);
        node.addChild(child2);
        child1.addChild(grandchild1);
        child2.addChild(grandchild2);
      });

      test('descendants defaults to BFS order', () {
        final ids = node.descendants().map((n) => n.id).toList();
        expect(ids, ['root', 'child1', 'child2', 'grandchild1', 'grandchild2']);
      });

      test('descendants with depthFirst true uses DFS order', () {
        final ids =
            node.descendants(depthFirst: true).map((n) => n.id).toList();
        expect(ids, ['root', 'child1', 'grandchild1', 'child2', 'grandchild2']);
      });

      test('visibleDescendants defaults to BFS order', () {
        final ids = node.visibleDescendants().map((n) => n.id).toList();
        expect(ids, ['root', 'child1', 'child2', 'grandchild1', 'grandchild2']);
      });

      test('visibleDescendants with depthFirst true uses DFS order', () {
        final ids =
            node.visibleDescendants(depthFirst: true).map((n) => n.id).toList();
        expect(ids, ['root', 'child1', 'grandchild1', 'child2', 'grandchild2']);
      });
    });

    group('reversedItems', () {
      test('returns items in reverse order', () {
        node.add(const Item('a'));
        node.add(const Item('b'));
        node.add(const Item('c'));

        final ids = node.reversedItems.map((i) => i.id).toList();
        expect(ids, ['c', 'b', 'a']);
      });

      test('returns empty for node without items', () {
        expect(node.reversedItems.isEmpty, true);
      });
    });

    group('siblings', () {
      late Node<Item> child1;
      late Node<Item> child2;
      late Node<Item> child3;

      setUp(() {
        child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        child3 = Node<Item>(id: 'child3', keyOf: (i) => i.id);

        node.addChild(child1);
        node.addChild(child2);
        node.addChild(child3);
      });

      test('returns siblings excluding self', () {
        final siblingIds = child2.siblings.map((n) => n.id).toList();
        expect(siblingIds, ['child1', 'child3']);
      });

      test('returns empty for root node', () {
        expect(node.siblings.isEmpty, true);
      });

      test('returns empty for only child', () {
        final parent = Node<Item>(id: 'parent', keyOf: (i) => i.id);
        final onlyChild = Node<Item>(id: 'only', keyOf: (i) => i.id);
        parent.addChild(onlyChild);

        expect(onlyChild.siblings.isEmpty, true);
      });
    });

    group('pathFromRoot', () {
      late Node<Item> child;
      late Node<Item> grandchild;
      late Node<Item> greatGrandchild;

      setUp(() {
        child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        grandchild = Node<Item>(id: 'grandchild', keyOf: (i) => i.id);
        greatGrandchild = Node<Item>(id: 'greatGrandchild', keyOf: (i) => i.id);

        node.addChild(child);
        child.addChild(grandchild);
        grandchild.addChild(greatGrandchild);
      });

      test('returns path from root to node', () {
        final path = greatGrandchild.pathFromRoot.map((n) => n.id).toList();
        expect(path, ['root', 'child', 'grandchild', 'greatGrandchild']);
      });

      test('returns single element for root', () {
        final path = node.pathFromRoot.map((n) => n.id).toList();
        expect(path, ['root']);
      });
    });

    group('ancestry checks', () {
      late Node<Item> child;
      late Node<Item> grandchild;
      late Node<Item> unrelated;

      setUp(() {
        child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        grandchild = Node<Item>(id: 'grandchild', keyOf: (i) => i.id);
        unrelated = Node<Item>(id: 'unrelated', keyOf: (i) => i.id);

        node.addChild(child);
        child.addChild(grandchild);
      });

      test('isAncestorOf returns true for descendant', () {
        expect(node.isAncestorOf(grandchild), true);
        expect(node.isAncestorOf(child), true);
        expect(child.isAncestorOf(grandchild), true);
      });

      test('isAncestorOf returns false for self', () {
        expect(node.isAncestorOf(node), false);
      });

      test('isAncestorOf returns false for ancestor', () {
        expect(grandchild.isAncestorOf(node), false);
      });

      test('isAncestorOf returns false for unrelated', () {
        expect(node.isAncestorOf(unrelated), false);
      });

      test('isDescendantOf returns true for ancestor', () {
        expect(grandchild.isDescendantOf(node), true);
        expect(grandchild.isDescendantOf(child), true);
        expect(child.isDescendantOf(node), true);
      });

      test('isDescendantOf returns false for self', () {
        expect(node.isDescendantOf(node), false);
      });

      test('isDescendantOf returns false for descendant', () {
        expect(node.isDescendantOf(grandchild), false);
      });

      test('isSiblingOf returns true for siblings', () {
        final child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        node.addChild(child2);

        expect(child.isSiblingOf(child2), true);
        expect(child2.isSiblingOf(child), true);
      });

      test('isSiblingOf returns false for self', () {
        expect(child.isSiblingOf(child), false);
      });

      test('isSiblingOf returns false for non-siblings', () {
        expect(child.isSiblingOf(grandchild), false);
        expect(node.isSiblingOf(child), false);
      });
    });

    group('commonAncestorWith', () {
      late Node<Item> child1;
      late Node<Item> child2;
      late Node<Item> grandchild1;
      late Node<Item> grandchild2;

      setUp(() {
        child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        grandchild1 = Node<Item>(id: 'grandchild1', keyOf: (i) => i.id);
        grandchild2 = Node<Item>(id: 'grandchild2', keyOf: (i) => i.id);

        node.addChild(child1);
        node.addChild(child2);
        child1.addChild(grandchild1);
        child2.addChild(grandchild2);
      });

      test('returns root for cousins', () {
        final ancestor = grandchild1.commonAncestorWith(grandchild2);
        expect(ancestor?.id, 'root');
      });

      test('returns parent for siblings', () {
        final ancestor = child1.commonAncestorWith(child2);
        expect(ancestor?.id, 'root');
      });

      test('returns parent for direct parent-child', () {
        final ancestor = grandchild1.commonAncestorWith(child1);
        expect(ancestor?.id, 'child1');
      });

      test('returns self for same node', () {
        final ancestor = grandchild1.commonAncestorWith(grandchild1);
        expect(ancestor?.id, 'grandchild1');
      });

      test('returns null for unrelated nodes', () {
        final unrelated = Node<Item>(id: 'unrelated', keyOf: (i) => i.id);
        final ancestor = grandchild1.commonAncestorWith(unrelated);
        expect(ancestor, isNull);
      });
    });

    group('search utilities', () {
      late Node<Item> child1;
      late Node<Item> child2;

      setUp(() {
        child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);

        node.add(const Item('a'));
        node.add(const Item('b'));
        child1.add(const Item('c'));
        child1.add(const Item('d'));
        child2.add(const Item('e'));

        node.addChild(child1);
        node.addChild(child2);
      });

      test('findFirstItem finds matching item', () {
        final item = node.findFirstItem((i) => i.id == 'c');
        expect(item?.id, 'c');
      });

      test('findFirstItem returns null when not found', () {
        final item = node.findFirstItem((i) => i.id == 'z');
        expect(item, isNull);
      });

      test('findAllItems finds all matching items', () {
        final items =
            node.findAllItems((i) => i.id == 'a' || i.id == 'e').toList();
        expect(items.length, 2);
        expect(items.map((i) => i.id), containsAll(['a', 'e']));
      });

      test('findFirstNode finds matching node', () {
        final found = node.findFirstNode((n) => n.id == 'child1');
        expect(found?.id, 'child1');
      });

      test('findFirstNode returns null when not found', () {
        final found = node.findFirstNode((n) => n.id == 'nonexistent');
        expect(found, isNull);
      });

      test('findAllNodes finds all matching nodes', () {
        final nodes =
            node.findAllNodes((n) => n.id.startsWith('child')).toList();
        expect(nodes.length, 2);
        expect(nodes.map((n) => n.id), containsAll(['child1', 'child2']));
      });

      test('anyItem returns true when any item matches', () {
        expect(node.anyItem((i) => i.id == 'c'), true);
      });

      test('anyItem returns false when no item matches', () {
        expect(node.anyItem((i) => i.id == 'z'), false);
      });

      test('everyItem returns true when all items match', () {
        expect(node.everyItem((i) => i.id.length == 1), true);
      });

      test('everyItem returns false when any item fails', () {
        child1.add(const Item('long_id'));
        expect(node.everyItem((i) => i.id.length == 1), false);
      });

      test('everyItem returns true for empty tree', () {
        final empty = Node<Item>(id: 'empty', keyOf: (i) => i.id);
        expect(empty.everyItem((i) => false), true);
      });
    });

    group('isLeaf and isBranch', () {
      test('isLeaf returns true for node without children', () {
        expect(node.isLeaf, true);
        expect(node.isBranch, false);
      });

      test('isBranch returns true for node with children', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        node.addChild(child);

        expect(node.isLeaf, false);
        expect(node.isBranch, true);
      });
    });

    group('height', () {
      test('returns 0 for leaf node', () {
        expect(node.height, 0);
      });

      test('returns 1 for node with only leaf children', () {
        final child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        final child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        node.addChild(child1);
        node.addChild(child2);

        expect(node.height, 1);
      });

      test('returns correct height for deep tree', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        final grandchild = Node<Item>(id: 'grandchild', keyOf: (i) => i.id);
        final greatGrandchild =
            Node<Item>(id: 'greatGrandchild', keyOf: (i) => i.id);

        node.addChild(child);
        child.addChild(grandchild);
        grandchild.addChild(greatGrandchild);

        expect(node.height, 3);
        expect(child.height, 2);
        expect(grandchild.height, 1);
        expect(greatGrandchild.height, 0);
      });
    });

    group('childIndex', () {
      test('returns -1 for root node', () {
        expect(node.childIndex, -1);
      });

      test('returns correct index for children', () {
        final child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        final child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        final child3 = Node<Item>(id: 'child3', keyOf: (i) => i.id);

        node.addChild(child1);
        node.addChild(child2);
        node.addChild(child3);

        expect(child1.childIndex, 0);
        expect(child2.childIndex, 1);
        expect(child3.childIndex, 2);
      });
    });

    group('childAt', () {
      test('returns child at index', () {
        final child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        final child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        node.addChild(child1);
        node.addChild(child2);

        expect(node.childAt(0)?.id, 'child1');
        expect(node.childAt(1)?.id, 'child2');
      });

      test('returns null for out of bounds index', () {
        expect(node.childAt(0), isNull);
        expect(node.childAt(-1), isNull);
        expect(node.childAt(100), isNull);
      });
    });

    group('addChildren', () {
      test('adds multiple children', () {
        final children = [
          Node<Item>(id: 'child1', keyOf: (i) => i.id),
          Node<Item>(id: 'child2', keyOf: (i) => i.id),
          Node<Item>(id: 'child3', keyOf: (i) => i.id),
        ];

        final count = node.addChildren(children);

        expect(count, 3);
        expect(node.childCount, 3);
        expect(node.child('child1'), isNotNull);
        expect(node.child('child2'), isNotNull);
        expect(node.child('child3'), isNotNull);
      });

      test('sets parent and depth on all children', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        final children = [
          Node<Item>(id: 'gc1', keyOf: (i) => i.id),
          Node<Item>(id: 'gc2', keyOf: (i) => i.id),
        ];

        node.addChild(child);
        child.addChildren(children);

        expect(children[0].parent, child);
        expect(children[0].depth, 2);
        expect(children[1].parent, child);
        expect(children[1].depth, 2);
      });

      test('notifies listeners', () {
        var notified = false;
        node.addChangeListener(() => notified = true);

        node.addChildren([
          Node<Item>(id: 'child', keyOf: (i) => i.id),
        ]);

        expect(notified, true);
      });
    });

    group('removeChildren', () {
      late Node<Item> child1;
      late Node<Item> child2;
      late Node<Item> child3;

      setUp(() {
        child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        child3 = Node<Item>(id: 'child3', keyOf: (i) => i.id);
        node.addChildren([child1, child2, child3]);
      });

      test('removes multiple children', () {
        final removed = node.removeChildren(['child1', 'child3']);

        expect(removed.length, 2);
        expect(removed.map((n) => n.id), containsAll(['child1', 'child3']));
        expect(node.childCount, 1);
        expect(node.child('child2'), isNotNull);
      });

      test('clears parent on removed children', () {
        node.removeChildren(['child1']);

        expect(child1.parent, isNull);
      });

      test('ignores non-existent ids', () {
        final removed = node.removeChildren(['nonexistent', 'child1']);

        expect(removed.length, 1);
        expect(removed.first.id, 'child1');
      });

      test('returns empty list when none match', () {
        final removed = node.removeChildren(['nonexistent']);

        expect(removed, isEmpty);
      });
    });

    group('insertChildAt', () {
      test('inserts at beginning', () {
        final child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        final child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        final child3 = Node<Item>(id: 'child3', keyOf: (i) => i.id);

        node.addChildren([child1, child2]);
        node.insertChildAt(0, child3);

        expect(node.childIds.toList(), ['child3', 'child1', 'child2']);
      });

      test('inserts at middle', () {
        final child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        final child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        final child3 = Node<Item>(id: 'child3', keyOf: (i) => i.id);

        node.addChildren([child1, child2]);
        node.insertChildAt(1, child3);

        expect(node.childIds.toList(), ['child1', 'child3', 'child2']);
      });

      test('inserts at end with large index', () {
        final child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        final child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);

        node.addChild(child1);
        node.insertChildAt(100, child2);

        expect(node.childIds.toList(), ['child1', 'child2']);
      });

      test('sets parent correctly', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        node.insertChildAt(0, child);

        expect(child.parent, node);
      });
    });

    group('reorderChild', () {
      late Node<Item> child1;
      late Node<Item> child2;
      late Node<Item> child3;

      setUp(() {
        child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        child3 = Node<Item>(id: 'child3', keyOf: (i) => i.id);
        node.addChildren([child1, child2, child3]);
      });

      test('moves child forward', () {
        final result = node.reorderChild(0, 2);

        expect(result, true);
        expect(node.childIds.toList(), ['child2', 'child3', 'child1']);
      });

      test('moves child backward', () {
        final result = node.reorderChild(2, 0);

        expect(result, true);
        expect(node.childIds.toList(), ['child3', 'child1', 'child2']);
      });

      test('returns false for same index', () {
        final result = node.reorderChild(1, 1);

        expect(result, false);
      });

      test('returns false for invalid from index', () {
        final result = node.reorderChild(-1, 1);

        expect(result, false);
      });

      test('returns false for invalid to index', () {
        final result = node.reorderChild(0, 100);

        expect(result, false);
      });
    });

    group('swapChildren', () {
      late Node<Item> child1;
      late Node<Item> child2;
      late Node<Item> child3;

      setUp(() {
        child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        child3 = Node<Item>(id: 'child3', keyOf: (i) => i.id);
        node.addChildren([child1, child2, child3]);
      });

      test('swaps two children', () {
        final result = node.swapChildren('child1', 'child3');

        expect(result, true);
        expect(node.childIds.toList(), ['child3', 'child2', 'child1']);
      });

      test('returns false for same id', () {
        final result = node.swapChildren('child1', 'child1');

        expect(result, false);
      });

      test('returns false for non-existent first child', () {
        final result = node.swapChildren('nonexistent', 'child1');

        expect(result, false);
      });

      test('returns false for non-existent second child', () {
        final result = node.swapChildren('child1', 'nonexistent');

        expect(result, false);
      });
    });

    group('detach', () {
      test('removes node from parent', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        node.addChild(child);

        child.detach();

        expect(child.parent, isNull);
        expect(node.child('child'), isNull);
      });

      test('detaches child from parent', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        node.addChild(child);

        child.detach();

        expect(child.parent, isNull);
        expect(node.children, isEmpty);
      });

      test('does nothing for root node', () {
        node.detach();

        expect(node.parent, isNull);
      });

      test('updates depth to 0', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        final grandchild = Node<Item>(id: 'grandchild', keyOf: (i) => i.id);
        node.addChild(child);
        child.addChild(grandchild);

        expect(grandchild.depth, 2);

        child.detach();

        expect(child.depth, 0);
        expect(grandchild.depth, 1);
      });

      test('notifies parent listeners', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        node.addChild(child);

        var notified = false;
        node.addChangeListener(() => notified = true);

        child.detach();

        expect(notified, true);
      });
    });

    group('moveTo', () {
      late Node<Item> child;
      late Node<Item> otherParent;

      setUp(() {
        child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        otherParent = Node<Item>(id: 'other', keyOf: (i) => i.id);
        node.addChild(child);
      });

      test('moves node to new parent', () {
        final result = child.moveTo(otherParent);

        expect(result, true);
        expect(child.parent, otherParent);
        expect(node.child('child'), isNull);
        expect(otherParent.child('child'), isNotNull);
      });

      test('updates depth correctly', () {
        final grandchild = Node<Item>(id: 'grandchild', keyOf: (i) => i.id);
        child.addChild(grandchild);

        // Move child under otherParent which is at depth 0
        child.moveTo(otherParent);

        expect(child.depth, 1);
        expect(grandchild.depth, 2);
      });

      test('prevents moving to self', () {
        final result = child.moveTo(child);

        expect(result, false);
        expect(child.parent, node);
      });

      test('prevents moving to descendant', () {
        final grandchild = Node<Item>(id: 'grandchild', keyOf: (i) => i.id);
        child.addChild(grandchild);

        final result = child.moveTo(grandchild);

        expect(result, false);
        expect(child.parent, node);
      });

      test('notifies both old and new parent', () {
        var oldNotified = false;
        var newNotified = false;
        node.addChangeListener(() => oldNotified = true);
        otherParent.addChangeListener(() => newNotified = true);

        child.moveTo(otherParent);

        expect(oldNotified, true);
        expect(newNotified, true);
      });
    });

    group('replaceWith', () {
      late Node<Item> child;
      late Node<Item> replacement;

      setUp(() {
        child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        replacement = Node<Item>(id: 'replacement', keyOf: (i) => i.id);
        node.addChild(child);
      });

      test('replaces node in parent', () {
        final result = child.replaceWith(replacement);

        expect(result, true);
        expect(child.parent, isNull);
        expect(replacement.parent, node);
        expect(node.child('child'), isNull);
        expect(node.child('replacement'), isNotNull);
      });

      test('updates replacement depth', () {
        child.replaceWith(replacement);

        expect(replacement.depth, 1);
      });

      test('returns false for root node', () {
        final result = node.replaceWith(replacement);

        expect(result, false);
      });

      test('notifies parent listeners', () {
        var notified = false;
        node.addChangeListener(() => notified = true);

        child.replaceWith(replacement);

        expect(notified, true);
      });
    });

    group('clone', () {
      setUp(() {
        node.add(const Item('a'));
        node.add(const Item('b'));
      });

      test('creates deep copy by default', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        child.add(const Item('c'));
        node.addChild(child);

        final cloned = node.clone();

        expect(cloned.id, 'root');
        expect(cloned.length, 2);
        expect(cloned.childCount, 1);
        expect(cloned.child('child')?.length, 1);
      });

      test('deep copy creates independent tree', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        node.addChild(child);

        final cloned = node.clone();
        cloned.add(const Item('new'));
        cloned.child('child')?.add(const Item('newChild'));

        expect(node.length, 2);
        expect(child.length, 0);
      });

      test('shallow copy excludes children', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        node.addChild(child);

        final cloned = node.clone(deep: false);

        expect(cloned.length, 2);
        expect(cloned.childCount, 0);
      });

      test('clones collapse state', () {
        node.toggle();
        expect(node.isCollapsed, true);

        final cloned = node.clone();

        expect(cloned.isCollapsed, true);
      });

      test('allows custom id', () {
        final cloned = node.clone(newId: 'cloned-node');

        expect(cloned.id, 'cloned-node');
      });

      test('cloned node has no parent', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        node.addChild(child);

        final cloned = child.clone();

        expect(cloned.parent, isNull);
        expect(cloned.depth, 0);
      });
    });

    group('copyWith', () {
      setUp(() {
        node.add(const Item('a'));
      });

      test('copies with new id', () {
        final copy = node.copyWith(id: 'new-id');

        expect(copy.id, 'new-id');
        expect(copy.length, 1);
      });

      test('copies with new extra', () {
        final copy = node.copyWith(extra: 'new extra');

        expect(copy.extra, 'new extra');
      });

      test('copies with new items', () {
        final copy = node.copyWith(items: [const Item('x'), const Item('y')]);

        expect(copy.length, 2);
        expect(copy['x'], isNotNull);
        expect(copy['y'], isNotNull);
      });

      test('copies with new collapse state', () {
        final copy = node.copyWith(isCollapsed: true);

        expect(copy.isCollapsed, true);
        expect(node.isCollapsed, false);
      });

      test('preserves all properties when none specified', () {
        node.toggle();
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        node.addChild(child);

        final copy = node.copyWith();

        expect(copy.id, node.id);
        expect(copy.length, node.length);
        expect(copy.childCount, node.childCount);
        expect(copy.isCollapsed, node.isCollapsed);
      });
    });

    group('shallowEquals', () {
      test('returns true for nodes with same items', () {
        final other = Node<Item>(id: 'other', keyOf: (i) => i.id);
        node.add(const Item('a'));
        node.add(const Item('b'));
        other.add(const Item('a'));
        other.add(const Item('b'));

        expect(node.shallowEquals(other), true);
      });

      test('returns false for different item count', () {
        final other = Node<Item>(id: 'other', keyOf: (i) => i.id);
        node.add(const Item('a'));
        other.add(const Item('a'));
        other.add(const Item('b'));

        expect(node.shallowEquals(other), false);
      });

      test('returns false for different items', () {
        final other = Node<Item>(id: 'other', keyOf: (i) => i.id);
        node.add(const Item('a'));
        other.add(const Item('b'));

        expect(node.shallowEquals(other), false);
      });

      test('ignores children', () {
        final other = Node<Item>(id: 'other', keyOf: (i) => i.id);
        node.add(const Item('a'));
        other.add(const Item('a'));

        node.addChild(Node<Item>(id: 'child', keyOf: (i) => i.id));
        // other has no children

        expect(node.shallowEquals(other), true);
      });
    });

    group('deepEquals', () {
      test('returns true for identical trees', () {
        final other = Node<Item>(id: 'root', keyOf: (i) => i.id);
        node.add(const Item('a'));
        other.add(const Item('a'));

        final child1 = Node<Item>(id: 'child', keyOf: (i) => i.id);
        final child2 = Node<Item>(id: 'child', keyOf: (i) => i.id);
        child1.add(const Item('b'));
        child2.add(const Item('b'));
        node.addChild(child1);
        other.addChild(child2);

        expect(node.deepEquals(other), true);
      });

      test('returns false for different ids', () {
        final other = Node<Item>(id: 'different', keyOf: (i) => i.id);

        expect(node.deepEquals(other), false);
      });

      test('returns false for different items', () {
        final other = Node<Item>(id: 'root', keyOf: (i) => i.id);
        node.add(const Item('a'));
        other.add(const Item('b'));

        expect(node.deepEquals(other), false);
      });

      test('returns false for different children', () {
        final other = Node<Item>(id: 'root', keyOf: (i) => i.id);
        node.addChild(Node<Item>(id: 'child1', keyOf: (i) => i.id));
        other.addChild(Node<Item>(id: 'child2', keyOf: (i) => i.id));

        expect(node.deepEquals(other), false);
      });

      test('returns false for different collapse state', () {
        final other = Node<Item>(id: 'root', keyOf: (i) => i.id);
        node.toggle();

        expect(node.deepEquals(other), false);
      });

      test('compares entire subtree', () {
        final other = Node<Item>(id: 'root', keyOf: (i) => i.id);

        final child1 = Node<Item>(id: 'child', keyOf: (i) => i.id);
        final child2 = Node<Item>(id: 'child', keyOf: (i) => i.id);
        final gc1 = Node<Item>(id: 'gc', keyOf: (i) => i.id);
        final gc2 = Node<Item>(id: 'gc', keyOf: (i) => i.id);

        gc1.add(const Item('deep'));
        gc2.add(const Item('different'));

        child1.addChild(gc1);
        child2.addChild(gc2);
        node.addChild(child1);
        other.addChild(child2);

        expect(node.deepEquals(other), false);
      });
    });

    group('shallowEquals', () {
      test('uses keyOf for comparison', () {
        final node = Node<Item>(
          id: 'root',
          keyOf: (i) => i.id,
        );
        final other = Node<Item>(
          id: 'root',
          keyOf: (i) => i.id,
        );

        node.add(const Item('1'));
        other.add(const Item('1'));

        expect(node.shallowEquals(other), true);
      });
    });

    group('indexOf not found', () {
      test('returns -1 when key not found', () {
        final node = Node<Item>(
          id: 'root',
          keyOf: (i) => i.id,
        );

        node.add(const Item('1'));
        node.add(const Item('2'));

        // Search for non-existent item
        final result = node.indexOf(const Item('3'));
        expect(result, equals(-1));
      });
    });

    group('flattenedItemsDfs', () {
      test('returns items in depth-first order', () {
        final root = Node<Item>(id: 'root', keyOf: (i) => i.id);
        final child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        final child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);

        root.add(const Item('r'));
        child1.add(const Item('c1'));
        child2.add(const Item('c2'));

        root.addChild(child1);
        root.addChild(child2);

        final items = root.flattenedItemsDfs(depthFirst: true).toList();
        expect(items.length, equals(3));
        expect(items[0].id, equals('r'));
      });
    });

    group('toString', () {
      test('returns descriptive string', () {
        final node = Node<Item>(id: 'mynode', keyOf: (i) => i.id);
        node.add(const Item('1'));
        node.add(const Item('2'));

        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        node.addChild(child);

        expect(node.toString(), equals('Node(mynode, items: 2, children: 1)'));
      });
    });

    group('moveTo from root', () {
      test('moves root node to new parent', () {
        final orphan = Node<Item>(id: 'orphan', keyOf: (i) => i.id);
        final newParent = Node<Item>(
          id: 'newParent',
          keyOf: (i) => i.id,
        );

        // orphan has no parent initially
        expect(orphan.parent, isNull);

        final result = orphan.moveTo(newParent);
        expect(result, isTrue);
        expect(orphan.parent, equals(newParent));
      });
    });
  });

  group('Node collapse state serialization', () {
    group('captureCollapseState', () {
      test('should return empty snapshot when no nodes are collapsed', () {
        final root = Node<Item>(id: 'root', keyOf: (i) => i.id);
        root.addChild(Node<Item>(id: 'child1', keyOf: (i) => i.id));
        root.addChild(Node<Item>(id: 'child2', keyOf: (i) => i.id));

        final snapshot = root.captureCollapseState();

        expect(snapshot.isEmpty, isTrue);
        expect(snapshot.collapsedIds, isEmpty);
      });

      test('should capture collapsed node IDs', () {
        final root = Node<Item>(id: 'root', keyOf: (i) => i.id);
        final child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        final child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        root
          ..addChild(child1)
          ..addChild(child2);

        child1.collapse();
        child2.collapse();

        final snapshot = root.captureCollapseState();

        expect(snapshot.isNotEmpty, isTrue);
        expect(snapshot.collapsedIds, equals({'child1', 'child2'}));
      });

      test('should capture nested collapsed nodes', () {
        final root = Node<Item>(id: 'root', keyOf: (i) => i.id);
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        final grandchild = Node<Item>(id: 'grandchild', keyOf: (i) => i.id);
        root.addChild(child);
        child.addChild(grandchild);

        grandchild.collapse();

        final snapshot = root.captureCollapseState();

        expect(snapshot.collapsedIds, equals({'grandchild'}));
      });

      test('should return immutable set', () {
        final root = Node<Item>(id: 'root', keyOf: (i) => i.id);
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        root.addChild(child);
        child.collapse();

        final snapshot = root.captureCollapseState();

        expect(
          () => (snapshot.collapsedIds as Set).add('x'),
          throwsUnsupportedError,
        );
      });
    });

    group('restoreCollapseState', () {
      test('should collapse nodes from snapshot', () {
        final root = Node<Item>(id: 'root', keyOf: (i) => i.id);
        final child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        final child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        root
          ..addChild(child1)
          ..addChild(child2);

        final snapshot = CollapseSnapshot.fromIds(const {'child1'});
        root.restoreCollapseState(snapshot);

        expect(child1.isCollapsed, isTrue);
        expect(child2.isCollapsed, isFalse);
      });

      test('should expand nodes not in snapshot', () {
        final root = Node<Item>(id: 'root', keyOf: (i) => i.id);
        final child1 = Node<Item>(id: 'child1', keyOf: (i) => i.id);
        final child2 = Node<Item>(id: 'child2', keyOf: (i) => i.id);
        root
          ..addChild(child1)
          ..addChild(child2);

        // Initially collapse both
        child1.collapse();
        child2.collapse();

        // Restore with only child1 collapsed
        final snapshot = CollapseSnapshot.fromIds(const {'child1'});
        root.restoreCollapseState(snapshot);

        expect(child1.isCollapsed, isTrue);
        expect(child2.isCollapsed, isFalse);
      });

      test('should ignore non-existent node IDs', () {
        final root = Node<Item>(id: 'root', keyOf: (i) => i.id);
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        root.addChild(child);

        final snapshot =
            CollapseSnapshot.fromIds(const {'child', 'nonExistent'});
        root.restoreCollapseState(snapshot);

        expect(child.isCollapsed, isTrue);
      });

      test('should handle empty snapshot by expanding all', () {
        final root = Node<Item>(id: 'root', keyOf: (i) => i.id);
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        root.addChild(child);
        child.collapse();

        const snapshot = CollapseSnapshot.empty();
        root.restoreCollapseState(snapshot);

        expect(child.isCollapsed, isFalse);
      });

      test('should notify listeners when notify is true', () {
        final root = Node<Item>(id: 'root', keyOf: (i) => i.id);
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        root.addChild(child);

        var notified = false;
        child.addChangeListener(() => notified = true);

        final snapshot = CollapseSnapshot.fromIds(const {'child'});
        root.restoreCollapseState(snapshot);

        expect(notified, isTrue);
      });

      test('should not notify listeners when notify is false', () {
        final root = Node<Item>(id: 'root', keyOf: (i) => i.id);
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        root.addChild(child);

        var notified = false;
        child.addChangeListener(() => notified = true);

        final snapshot = CollapseSnapshot.fromIds(const {'child'});
        root.restoreCollapseState(snapshot, notify: false);

        expect(notified, isFalse);
      });

      test('should not notify when state does not change', () {
        final root = Node<Item>(id: 'root', keyOf: (i) => i.id);
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        root.addChild(child);
        child.collapse();

        var notifyCount = 0;
        child.addChangeListener(() => notifyCount++);

        // Restore same state
        final snapshot = CollapseSnapshot.fromIds(const {'child'});
        root.restoreCollapseState(snapshot);

        expect(notifyCount, equals(0));
      });
    });
  });

  group('CollapseSnapshot', () {
    group('construction', () {
      test('empty() should create empty snapshot', () {
        const snapshot = CollapseSnapshot.empty();

        expect(snapshot.isEmpty, isTrue);
        expect(snapshot.isNotEmpty, isFalse);
        expect(snapshot.length, equals(0));
        expect(snapshot.collapsedIds, isEmpty);
      });

      test('fromIds should create snapshot with given IDs', () {
        final snapshot = CollapseSnapshot.fromIds(const {'a', 'b', 'c'});

        expect(snapshot.isEmpty, isFalse);
        expect(snapshot.isNotEmpty, isTrue);
        expect(snapshot.length, equals(3));
        expect(snapshot.collapsedIds, equals({'a', 'b', 'c'}));
      });

      test('fromIds with empty set should return empty snapshot', () {
        final snapshot = CollapseSnapshot.fromIds(const <String>{});

        expect(snapshot.isEmpty, isTrue);
      });
    });

    group('isCollapsed', () {
      test('should return true for collapsed node IDs', () {
        final snapshot = CollapseSnapshot.fromIds(const {'a', 'b'});

        expect(snapshot.isCollapsed('a'), isTrue);
        expect(snapshot.isCollapsed('b'), isTrue);
      });

      test('should return false for non-collapsed node IDs', () {
        final snapshot = CollapseSnapshot.fromIds(const {'a', 'b'});

        expect(snapshot.isCollapsed('c'), isFalse);
        expect(snapshot.isCollapsed('x'), isFalse);
      });
    });

    group('toJson', () {
      test('should serialize collapsed IDs', () {
        final snapshot = CollapseSnapshot.fromIds(const {'a', 'b', 'c'});

        final json = snapshot.toJson();

        expect(
          json,
          containsPair('collapsedIds', containsAll(['a', 'b', 'c'])),
        );
      });

      test('should serialize empty snapshot', () {
        const snapshot = CollapseSnapshot.empty();

        final json = snapshot.toJson();

        expect(json, containsPair('collapsedIds', isEmpty));
      });
    });

    group('fromJson', () {
      test('should deserialize collapsed IDs', () {
        final json = {
          'collapsedIds': ['a', 'b', 'c'],
        };

        final snapshot = CollapseSnapshot.fromJson(json);

        expect(snapshot.collapsedIds, equals({'a', 'b', 'c'}));
      });

      test('should return empty snapshot for null collapsedIds', () {
        final json = <String, dynamic>{'collapsedIds': null};

        final snapshot = CollapseSnapshot.fromJson(json);

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty snapshot for empty collapsedIds', () {
        final json = <String, dynamic>{'collapsedIds': <String>[]};

        final snapshot = CollapseSnapshot.fromJson(json);

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty snapshot for missing field', () {
        final json = <String, dynamic>{};

        final snapshot = CollapseSnapshot.fromJson(json);

        expect(snapshot.isEmpty, isTrue);
      });

      test('should filter out non-string values', () {
        final json = {
          'collapsedIds': ['a', 123, 'b', null, 'c'],
        };

        final snapshot = CollapseSnapshot.fromJson(json);

        expect(snapshot.collapsedIds, equals({'a', 'b', 'c'}));
      });
    });

    group('toQueryString', () {
      test('should serialize collapsed IDs', () {
        final snapshot = CollapseSnapshot.fromIds(const {'a', 'b', 'c'});

        final query = snapshot.toQueryString();

        expect(query, startsWith('collapsed='));
        expect(query, contains('a'));
        expect(query, contains('b'));
        expect(query, contains('c'));
      });

      test('should URL encode special characters', () {
        final snapshot = CollapseSnapshot.fromIds(const {'hello world', 'a/b'});

        final query = snapshot.toQueryString();

        expect(query, contains('hello%20world'));
        expect(query, contains('a%2Fb'));
      });

      test('should return empty string for empty snapshot', () {
        const snapshot = CollapseSnapshot.empty();

        final query = snapshot.toQueryString();

        expect(query, isEmpty);
      });
    });

    group('fromQueryString', () {
      test('should parse collapsed IDs', () {
        const query = 'collapsed=a,b,c';

        final snapshot = CollapseSnapshot.fromQueryString(query);

        expect(snapshot.collapsedIds, equals({'a', 'b', 'c'}));
      });

      test('should URL decode special characters', () {
        const query = 'collapsed=hello%20world,a%2Fb';

        final snapshot = CollapseSnapshot.fromQueryString(query);

        expect(snapshot.collapsedIds, contains('hello world'));
        expect(snapshot.collapsedIds, contains('a/b'));
      });

      test('should return empty snapshot for empty query', () {
        final snapshot = CollapseSnapshot.fromQueryString('');

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty snapshot for missing collapsed param', () {
        const query = 'other=value';

        final snapshot = CollapseSnapshot.fromQueryString(query);

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty snapshot for empty collapsed value', () {
        const query = 'collapsed=';

        final snapshot = CollapseSnapshot.fromQueryString(query);

        expect(snapshot.isEmpty, isTrue);
      });

      test('should handle query with other parameters', () {
        const query = 'filter=active&collapsed=a,b&sort=name';

        final snapshot = CollapseSnapshot.fromQueryString(query);

        expect(snapshot.collapsedIds, equals({'a', 'b'}));
      });
    });

    group('equality', () {
      test('should be equal for same IDs', () {
        final snapshot1 = CollapseSnapshot.fromIds(const {'a', 'b'});
        final snapshot2 = CollapseSnapshot.fromIds(const {'a', 'b'});

        expect(snapshot1, equals(snapshot2));
        expect(snapshot1.hashCode, equals(snapshot2.hashCode));
      });

      test('should not be equal for different IDs', () {
        final snapshot1 = CollapseSnapshot.fromIds(const {'a', 'b'});
        final snapshot2 = CollapseSnapshot.fromIds(const {'a', 'c'});

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('should not be equal for different ID count', () {
        final snapshot1 = CollapseSnapshot.fromIds(const {'a', 'b'});
        final snapshot2 = CollapseSnapshot.fromIds(const {'a', 'b', 'c'});

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('should be equal to itself', () {
        final snapshot = CollapseSnapshot.fromIds(const {'a', 'b'});

        expect(snapshot, equals(snapshot));
      });

      test('should not be equal to different type', () {
        final snapshot = CollapseSnapshot.fromIds(const {'a', 'b'});
        // Comparing with a different type to test the equality operator.
        const dynamic other = 'not a snapshot';

        expect(snapshot == other, isFalse);
      });

      test('empty snapshots should be equal', () {
        const snapshot1 = CollapseSnapshot.empty();
        const snapshot2 = CollapseSnapshot.empty();

        expect(snapshot1, equals(snapshot2));
      });
    });

    group('toString', () {
      test('should return readable representation', () {
        final snapshot = CollapseSnapshot.fromIds(const {'a', 'b'});

        expect(snapshot.toString(), contains('CollapseSnapshot'));
        expect(snapshot.toString(), contains('a'));
        expect(snapshot.toString(), contains('b'));
      });
    });

    group('roundtrip', () {
      test('should roundtrip through JSON', () {
        final original = CollapseSnapshot.fromIds(const {'a', 'b', 'c'});

        final json = original.toJson();
        final restored = CollapseSnapshot.fromJson(json);

        expect(restored, equals(original));
      });

      test('should roundtrip through query string', () {
        final original = CollapseSnapshot.fromIds(const {'a', 'b', 'c'});

        final query = original.toQueryString();
        final restored = CollapseSnapshot.fromQueryString(query);

        expect(restored.collapsedIds, equals(original.collapsedIds));
      });
    });
  });

  // ===========================================================================
  // Additional Coverage Tests
  // ===========================================================================

  group('Node additional coverage', () {
    late Node<Item> node;

    setUp(() {
      node = Node<Item>(id: 'root', keyOf: (i) => i.id);
    });

    group('upsert operations', () {
      test('upsert should add new item and return true', () {
        final result = node.upsert(const Item('a', value: 1));
        expect(result, isTrue);
        expect(node['a']?.value, 1);
      });

      test('upsert should update existing item and return false', () {
        node.add(const Item('a', value: 1));
        final result = node.upsert(const Item('a', value: 2));
        expect(result, isFalse);
        expect(node['a']?.value, 2);
      });

      test('upsertAll should add and update multiple items', () {
        node.add(const Item('a', value: 1));
        final added = node.upsertAll([
          const Item('a', value: 10), // update
          const Item('b', value: 2), // add
          const Item('c', value: 3), // add
        ]);
        expect(added, 2);
        expect(node['a']?.value, 10);
        expect(node['b']?.value, 2);
        expect(node['c']?.value, 3);
      });

      test('upsertAll with empty iterable returns 0', () {
        final added = node.upsertAll([]);
        expect(added, 0);
      });
    });

    group('updateAll operation', () {
      test('updateAll should transform all items', () {
        node.addAll([
          const Item('a', value: 1),
          const Item('b', value: 2),
        ]);
        node.updateAll((item) => Item(item.id, value: item.value * 10));
        expect(node['a']?.value, 10);
        expect(node['b']?.value, 20);
      });

      test('updateAll on empty node does nothing', () {
        var notified = false;
        node.addChangeListener(() => notified = true);
        node.updateAll((item) => item);
        expect(notified, isFalse);
      });
    });

    group('item navigation', () {
      test('next returns null when item not found', () {
        expect(node.next(const Item('missing')), isNull);
      });

      test('next returns null when at last item', () {
        node.addAll([const Item('a'), const Item('b')]);
        expect(node.next(const Item('b')), isNull);
      });

      test('prev returns null when item not found', () {
        expect(node.prev(const Item('missing')), isNull);
      });

      test('prev returns null when at first item', () {
        node.addAll([const Item('a'), const Item('b')]);
        expect(node.prev(const Item('a')), isNull);
      });
    });

    group('atOrNull', () {
      test('returns null for negative index', () {
        node.add(const Item('a'));
        expect(node.atOrNull(-1), isNull);
      });

      test('returns null for index out of bounds', () {
        node.add(const Item('a'));
        expect(node.atOrNull(10), isNull);
      });
    });

    group('child operations', () {
      test('childAt returns null for negative index', () {
        expect(node.childAt(-1), isNull);
      });

      test('childAt returns null for index out of bounds', () {
        expect(node.childAt(0), isNull);
      });

      test('addChildren returns count', () {
        final children = [
          Node<Item>(id: 'c1', keyOf: (i) => i.id),
          Node<Item>(id: 'c2', keyOf: (i) => i.id),
        ];
        final count = node.addChildren(children);
        expect(count, 2);
        expect(node.childCount, 2);
      });

      test('addChildren with empty iterable returns 0', () {
        final count = node.addChildren([]);
        expect(count, 0);
      });

      test('removeChildren returns removed nodes', () {
        node.addChild(Node<Item>(id: 'c1', keyOf: (i) => i.id));
        node.addChild(Node<Item>(id: 'c2', keyOf: (i) => i.id));
        final removed = node.removeChildren(['c1', 'c3']);
        expect(removed.length, 1);
        expect(removed.first.id, 'c1');
      });

      test('removeChildren with no matches returns empty', () {
        final removed = node.removeChildren(['x', 'y']);
        expect(removed, isEmpty);
      });

      test('insertChildAt at beginning', () {
        node.addChild(Node<Item>(id: 'c2', keyOf: (i) => i.id));
        node.insertChildAt(0, Node<Item>(id: 'c1', keyOf: (i) => i.id));
        expect(node.childIds.first, 'c1');
      });

      test('insertChildAt at end', () {
        node.addChild(Node<Item>(id: 'c1', keyOf: (i) => i.id));
        node.insertChildAt(100, Node<Item>(id: 'c2', keyOf: (i) => i.id));
        expect(node.childIds.last, 'c2');
      });

      test('reorderChild with same indices returns false', () {
        node.addChild(Node<Item>(id: 'c1', keyOf: (i) => i.id));
        expect(node.reorderChild(0, 0), isFalse);
      });

      test('reorderChild with invalid fromIndex returns false', () {
        expect(node.reorderChild(-1, 0), isFalse);
      });

      test('reorderChild with invalid toIndex returns false', () {
        node.addChild(Node<Item>(id: 'c1', keyOf: (i) => i.id));
        expect(node.reorderChild(0, 5), isFalse);
      });

      test('swapChildren with same id returns false', () {
        expect(node.swapChildren('a', 'a'), isFalse);
      });

      test('swapChildren with missing first child returns false', () {
        node.addChild(Node<Item>(id: 'c1', keyOf: (i) => i.id));
        expect(node.swapChildren('missing', 'c1'), isFalse);
      });

      test('swapChildren with missing second child returns false', () {
        node.addChild(Node<Item>(id: 'c1', keyOf: (i) => i.id));
        expect(node.swapChildren('c1', 'missing'), isFalse);
      });
    });

    group('tree navigation', () {
      test('childIndex returns -1 for root', () {
        expect(node.childIndex, -1);
      });

      test('height is cached', () {
        node.addChild(Node<Item>(id: 'c1', keyOf: (i) => i.id));
        final h1 = node.height;
        final h2 = node.height;
        expect(h1, h2);
        expect(h1, 1);
      });

      test('parents yields ancestor chain', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        node.addChild(child);
        final grandchild = Node<Item>(id: 'grandchild', keyOf: (i) => i.id);
        child.addChild(grandchild);

        final parents = grandchild.parents.toList();
        expect(parents.length, 2);
        expect(parents[0].id, 'child');
        expect(parents[1].id, 'root');
      });
    });

    group('deep tree iterative fallback', () {
      test('findNode uses iterative for very deep trees', () {
        // Create a chain deeper than recursion threshold
        var current = node;
        for (var i = 0; i < 110; i++) {
          final child = Node<Item>(id: 'n$i', keyOf: (j) => j.id);
          current.addChild(child);
          current = child;
        }
        // Should find using iterative approach
        final found = node.findNode('n105');
        expect(found?.id, 'n105');
      });

      test('findNodeByKey uses iterative for very deep trees', () {
        var current = node;
        for (var i = 0; i < 110; i++) {
          final child = Node<Item>(id: 'n$i', keyOf: (j) => j.id);
          child.add(Item('item$i'));
          current.addChild(child);
          current = child;
        }
        final found = node.findNodeByKey('item105');
        expect(found?.id, 'n105');
      });
    });

    group('tree manipulation', () {
      test('detach does nothing on root', () {
        node.detach();
        expect(node.parent, isNull);
      });

      test('moveTo prevents moving to self', () {
        final result = node.moveTo(node);
        expect(result, isFalse);
      });

      test('moveTo prevents moving to descendant', () {
        final child = Node<Item>(id: 'child', keyOf: (i) => i.id);
        node.addChild(child);
        final result = node.moveTo(child);
        expect(result, isFalse);
      });

      test('isAncestorOf returns false for self', () {
        expect(node.isAncestorOf(node), isFalse);
      });
    });

    group('clear operations', () {
      test('clear returns false when already empty', () {
        expect(node.clear(), isFalse);
      });

      test('clearChildren returns false when no children', () {
        expect(node.clearChildren(), isFalse);
      });

      test('clear and clearChildren together clears everything', () {
        node.add(const Item('a'));
        node.addChild(Node<Item>(id: 'c1', keyOf: (i) => i.id));
        node.clear();
        node.clearChildren();
        expect(node.isEmpty, isTrue);
        expect(node.childCount, 0);
      });
    });

    group('replace operations', () {
      test('replace adds new item and returns false', () {
        final result = node.replace(const Item('a'));
        expect(result, isFalse);
        expect(node.containsKey('a'), isTrue);
      });

      test('replaceByKey returns false for non-existent key', () {
        final result = node.replaceByKey('missing', const Item('a'));
        expect(result, isFalse);
      });
    });

    group('removeWhere', () {
      test('removeWhere returns empty list when no matches', () {
        node.addAll([const Item('a'), const Item('b')]);
        final removed = node.removeWhere((i) => i.value > 100);
        expect(removed, isEmpty);
      });
    });
  });

  group('Node collapse/expand', () {
    late Node<Item> node;

    setUp(() {
      node = Node<Item>(id: 'root', keyOf: (i) => i.id);
      node.addChild(Node<Item>(id: 'c1', keyOf: (i) => i.id));
      node.addChild(Node<Item>(id: 'c2', keyOf: (i) => i.id));
    });

    test('collapse with toggle inverts state', () {
      expect(node.isCollapsed, isFalse);
      node.collapse(state: Tristate.toggle);
      expect(node.isCollapsed, isTrue);
      node.collapse(state: Tristate.toggle);
      expect(node.isCollapsed, isFalse);
    });

    test('collapse with yes collapses', () {
      node.collapse(state: Tristate.yes);
      expect(node.isCollapsed, isTrue);
    });

    test('collapse with no expands', () {
      node.collapse(state: Tristate.yes);
      node.collapse(state: Tristate.no);
      expect(node.isCollapsed, isFalse);
    });

    test('collapse returns early when state unchanged', () {
      var count = 0;
      node.addChangeListener(() => count++);
      node.collapse(state: Tristate.no); // Already expanded
      expect(count, 0);
    });

    test('expandToThis expands ancestors', () {
      final child = node.child('c1')!;
      final grandchild = Node<Item>(id: 'gc1', keyOf: (i) => i.id);
      child.addChild(grandchild);
      node.collapse(state: Tristate.yes);
      child.collapse(state: Tristate.yes);

      grandchild.expandToThis();
      expect(node.isCollapsed, isFalse);
      expect(child.isCollapsed, isFalse);
    });

    test('collapseToLevel collapses nodes beyond level', () {
      final child = node.child('c1')!;
      child.addChild(Node<Item>(id: 'gc1', keyOf: (i) => i.id));

      node.collapseToLevel(1);
      expect(node.isCollapsed, isFalse);
      expect(child.isCollapsed, isTrue);
    });

    test('expandAll expands all descendants', () {
      node.child('c1')?.collapse(state: Tristate.yes);
      node.child('c2')?.collapse(state: Tristate.yes);
      node.expandAll();
      expect(node.child('c1')?.isCollapsed, isFalse);
      expect(node.child('c2')?.isCollapsed, isFalse);
    });

    test('collapseAll collapses all descendants', () {
      node.collapseAll();
      expect(node.child('c1')?.isCollapsed, isTrue);
      expect(node.child('c2')?.isCollapsed, isTrue);
    });
  });

  group('Node flattening', () {
    late Node<Item> node;

    setUp(() {
      node = Node<Item>(id: 'root', keyOf: (i) => i.id);
      node.add(const Item('r1'));
      final c1 = Node<Item>(id: 'c1', keyOf: (i) => i.id);
      c1.add(const Item('c1-i1'));
      node.addChild(c1);
    });

    test('flattenedLength uses iterative for deep trees', () {
      var current = node;
      for (var i = 0; i < 110; i++) {
        final child = Node<Item>(id: 'n$i', keyOf: (j) => j.id);
        child.add(Item('item$i'));
        current.addChild(child);
        current = child;
      }
      final len = node.flattenedLength;
      expect(len, greaterThan(100));
    });

    test('leaves uses iterative for deep trees', () {
      var current = node;
      for (var i = 0; i < 110; i++) {
        final child = Node<Item>(id: 'n$i', keyOf: (j) => j.id);
        current.addChild(child);
        current = child;
      }
      final leafList = node.leaves.toList();
      // c1 from setUp + the deepest node in chain
      expect(leafList.length, greaterThanOrEqualTo(1));
    });
  });

  group('Node cloning', () {
    test('clone uses iterative for deep trees', () {
      final root = Node<Item>(id: 'root', keyOf: (i) => i.id);
      var current = root;
      for (var i = 0; i < 110; i++) {
        final child = Node<Item>(id: 'n$i', keyOf: (j) => j.id);
        current.addChild(child);
        current = child;
      }
      final cloned = root.clone();
      expect(cloned.id, 'root');
      expect(cloned.findNode('n105'), isNotNull);
    });
  });

  group('Node deep equality', () {
    test('deepEquals uses iterative for deep trees', () {
      final root1 = Node<Item>(id: 'root', keyOf: (i) => i.id);
      final root2 = Node<Item>(id: 'root', keyOf: (i) => i.id);

      var current1 = root1;
      var current2 = root2;
      for (var i = 0; i < 110; i++) {
        final child1 = Node<Item>(id: 'n$i', keyOf: (j) => j.id);
        final child2 = Node<Item>(id: 'n$i', keyOf: (j) => j.id);
        current1.addChild(child1);
        current2.addChild(child2);
        current1 = child1;
        current2 = child2;
      }
      expect(root1.deepEquals(root2), isTrue);
    });

    test('deepEquals returns false for different structures', () {
      final root1 = Node<Item>(id: 'root', keyOf: (i) => i.id);
      final root2 = Node<Item>(id: 'root', keyOf: (i) => i.id);
      root1.addChild(Node<Item>(id: 'c1', keyOf: (i) => i.id));
      expect(root1.deepEquals(root2), isFalse);
    });

    test('deepEquals returns false for different item counts', () {
      final root1 = Node<Item>(id: 'root', keyOf: (i) => i.id);
      final root2 = Node<Item>(id: 'root', keyOf: (i) => i.id);
      root1.add(const Item('a', value: 1));
      root1.add(const Item('b', value: 2));
      root2.add(const Item('a', value: 1));
      expect(root1.deepEquals(root2), isFalse);
    });

    test('deepEquals iterative returns false for different child IDs', () {
      // Create two deep trees that trigger iterative comparison (depth > 100)
      final root1 = Node<Item>(id: 'root', keyOf: (i) => i.id);
      final root2 = Node<Item>(id: 'root', keyOf: (i) => i.id);

      var current1 = root1;
      var current2 = root2;
      // Build identical structure for 105 levels
      for (var i = 0; i < 105; i++) {
        final child1 = Node<Item>(id: 'n$i', keyOf: (j) => j.id);
        final child2 = Node<Item>(id: 'n$i', keyOf: (j) => j.id);
        current1.addChild(child1);
        current2.addChild(child2);
        current1 = child1;
        current2 = child2;
      }

      // At the deepest level, add children with same count but different IDs
      // This will be compared in the iterative path (depth > 100)
      current1.addChild(Node<Item>(id: 'different_a', keyOf: (j) => j.id));
      current2.addChild(Node<Item>(id: 'different_b', keyOf: (j) => j.id));

      // Should return false because child IDs don't match
      expect(root1.deepEquals(root2), isFalse);
    });
  });

  group('Node toString', () {
    test('toString includes id and counts', () {
      final n = Node<Item>(id: 'test', keyOf: (i) => i.id);
      n.add(const Item('a'));
      n.addChild(Node<Item>(id: 'c1', keyOf: (i) => i.id));
      final str = n.toString();
      expect(str, contains('test'));
      expect(str, contains('items: 1'));
      expect(str, contains('children: 1'));
    });
  });

  group('updateAll assertion coverage', () {
    test('throws AssertionError when transform changes item key', () {
      final node = Node<Item>(id: 'test', keyOf: (i) => i.id);
      node.addAll([
        const Item('a', value: 1),
        const Item('b', value: 2),
      ]);

      // Transform that changes the key should trigger assertion
      expect(
        () => node.updateAll(
          (item) => Item('changed_${item.id}', value: item.value),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
