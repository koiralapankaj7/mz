// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

// Test helper classes have fields for completeness that may not all be used.
// ignore_for_file: unreachable_from_main

import 'package:meta/meta.dart';
import 'package:mz_collection/src/filter_manager.dart';
import 'package:test/test.dart';

/// Test data model.
@immutable
class Item {
  const Item({
    required this.id,
    required this.name,
    required this.tags,
    required this.priority,
  });

  final String id;
  final String name;
  final List<String> tags;
  final int priority;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Item && id == other.id && name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

void main() {
  group('Listenable', () {
    late _TestListenable listenable;

    setUp(() {
      listenable = _TestListenable();
    });

    test('should add listener', () {
      var called = false;
      listenable.addChangeListener(() => called = true);

      listenable.triggerNotify();

      expect(called, isTrue);
      expect(listenable.hasListeners, isTrue);
    });

    test('should remove listener', () {
      var callCount = 0;
      void listener() => callCount++;

      listenable.addChangeListener(listener);
      listenable.triggerNotify();
      expect(callCount, equals(1));

      listenable.removeChangeListener(listener);
      listenable.triggerNotify();
      expect(callCount, equals(1));
      expect(listenable.hasListeners, isFalse);
    });

    test('should notify multiple listeners', () {
      var count1 = 0;
      var count2 = 0;

      listenable.addChangeListener(() => count1++);
      listenable.addChangeListener(() => count2++);

      listenable.triggerNotify();

      expect(count1, equals(1));
      expect(count2, equals(1));
    });

    test('should allow listener modification during notification', () {
      var called = false;

      void listener() {
        listenable.addChangeListener(() => called = true);
      }

      listenable.addChangeListener(listener);
      listenable.triggerNotify();

      expect(called, isFalse);

      listenable.triggerNotify();
      expect(called, isTrue);
    });

    test('should clear all listeners on dispose', () {
      var called = false;
      listenable.addChangeListener(() => called = true);

      listenable.dispose();
      listenable.triggerNotify();

      expect(called, isFalse);
      expect(listenable.hasListeners, isFalse);
    });
  });

  group('Filter', () {
    late Filter<Item, String> nameFilter;
    late Filter<Item, String> tagFilter;

    setUp(() {
      nameFilter = Filter<Item, String>(
        id: 'name',
        label: 'Name Filter',
        test: (item, value) => item.name.contains(value),
      );

      tagFilter = Filter<Item, String>(
        id: 'tags',
        test: (item, value) => item.tags.contains(value),
        mode: FilterMode.all,
      );
    });

    group('constructor', () {
      test('should create filter with default values', () {
        final filter = Filter<Item, String>(
          id: 'test',
          test: (item, value) => true,
        );

        expect(filter.id, equals('test'));
        expect(filter.label, isNull);
        expect(filter.mode, equals(FilterMode.any));
        expect(filter.singleSelect, isFalse);
        expect(filter.isEmpty, isTrue);
      });

      test('should create filter with initial values', () {
        final filter = Filter<Item, String>(
          id: 'test',
          test: (item, value) => true,
          values: const ['a', 'b'],
        );

        expect(filter.count, equals(2));
        expect(filter.contains('a'), isTrue);
        expect(filter.contains('b'), isTrue);
      });

      test('should create single-select filter', () {
        final filter = Filter<Item, String>(
          id: 'test',
          test: (item, value) => true,
          singleSelect: true,
        );

        expect(filter.singleSelect, isTrue);
      });
    });

    group('add', () {
      test('should add value and return true', () {
        final result = nameFilter.add('test');

        expect(result, isTrue);
        expect(nameFilter.count, equals(1));
        expect(nameFilter.contains('test'), isTrue);
      });

      test('should return false when adding duplicate value', () {
        nameFilter.add('test');
        final result = nameFilter.add('test');

        expect(result, isFalse);
        expect(nameFilter.count, equals(1));
      });

      test('should clear existing values in single-select mode', () {
        final filter = Filter<Item, String>(
          id: 'test',
          test: (item, value) => true,
          singleSelect: true,
        );

        filter.add('first');
        filter.add('second');

        expect(filter.count, equals(1));
        expect(filter.contains('second'), isTrue);
        expect(filter.contains('first'), isFalse);
      });

      test('should notify listeners', () {
        var notified = false;
        nameFilter.addChangeListener(() => notified = true);

        nameFilter.add('test');

        expect(notified, isTrue);
      });

      test('should call onChanged callback', () {
        Filter<Item, String>? changedFilter;
        final filter = Filter<Item, String>(
          id: 'test',
          test: (item, value) => true,
          onChanged: (f) => changedFilter = f,
        );

        filter.add('test');

        expect(changedFilter, equals(filter));
      });
    });

    group('remove', () {
      test('should remove value and return true', () {
        nameFilter.add('test');
        final result = nameFilter.remove('test');

        expect(result, isTrue);
        expect(nameFilter.isEmpty, isTrue);
      });

      test('should return false when removing non-existent value', () {
        final result = nameFilter.remove('test');

        expect(result, isFalse);
      });

      test('should notify listeners', () {
        var notified = false;
        nameFilter.add('test');
        nameFilter.addChangeListener(() => notified = true);

        nameFilter.remove('test');

        expect(notified, isTrue);
      });
    });

    group('toggle', () {
      test('should add value if not present and return true', () {
        final result = nameFilter.toggle('test');

        expect(result, isTrue);
        expect(nameFilter.contains('test'), isTrue);
      });

      test('should remove value if present and return false', () {
        nameFilter.add('test');
        final result = nameFilter.toggle('test');

        expect(result, isFalse);
        expect(nameFilter.contains('test'), isFalse);
      });

      test('should notify listeners', () {
        var notificationCount = 0;
        nameFilter.addChangeListener(() => notificationCount++);

        nameFilter.toggle('test');
        nameFilter.toggle('test');

        expect(notificationCount, equals(2));
      });
    });

    group('clear', () {
      test('should clear all values', () {
        nameFilter.add('a');
        nameFilter.add('b');

        nameFilter.clear();

        expect(nameFilter.isEmpty, isTrue);
      });

      test('should not notify if already empty', () {
        var notified = false;
        nameFilter.addChangeListener(() => notified = true);

        nameFilter.clear();

        expect(notified, isFalse);
      });

      test('should notify listeners when clearing non-empty filter', () {
        var notified = false;
        nameFilter.add('test');
        nameFilter.addChangeListener(() => notified = true);

        nameFilter.clear();

        expect(notified, isTrue);
      });
    });

    group('setAll', () {
      test('should replace all values', () {
        nameFilter.add('old1');
        nameFilter.add('old2');

        nameFilter.setAll(['new1', 'new2', 'new3']);

        expect(nameFilter.count, equals(3));
        expect(nameFilter.contains('new1'), isTrue);
        expect(nameFilter.contains('new2'), isTrue);
        expect(nameFilter.contains('new3'), isTrue);
        expect(nameFilter.contains('old1'), isFalse);
      });

      test('should notify listeners', () {
        var notified = false;
        nameFilter.addChangeListener(() => notified = true);

        nameFilter.setAll(['value']);

        expect(notified, isTrue);
      });

      test('should keep only last value in singleSelect mode', () {
        final singleFilter = Filter<Item, String>(
          id: 'single',
          test: (item, value) => item.name.contains(value),
          singleSelect: true,
        );

        singleFilter.setAll(['first', 'second', 'third']);

        expect(singleFilter.count, equals(1));
        expect(singleFilter.contains('third'), isTrue);
        expect(singleFilter.contains('first'), isFalse);
      });

      test('should handle empty values', () {
        nameFilter.add('existing');

        nameFilter.setAll([]);

        expect(nameFilter.isEmpty, isTrue);
      });

      test('should handle empty values in singleSelect mode', () {
        final singleFilter = Filter<Item, String>(
          id: 'single',
          test: (item, value) => item.name.contains(value),
          singleSelect: true,
        );
        singleFilter.add('existing');

        singleFilter.setAll([]);

        expect(singleFilter.isEmpty, isTrue);
      });
    });

    group('apply', () {
      const item = Item(
        id: '1',
        name: 'test item',
        tags: ['urgent', 'bug'],
        priority: 1,
      );

      test('should pass all items when filter is empty', () {
        expect(nameFilter.apply(item), isTrue);
      });

      test('should pass item matching any value with FilterMode.any', () {
        nameFilter.add('test');
        nameFilter.add('other');

        expect(nameFilter.apply(item), isTrue);
      });

      test('should fail item not matching any value with FilterMode.any', () {
        nameFilter.add('nomatch');

        expect(nameFilter.apply(item), isFalse);
      });

      test('should pass item matching all values with FilterMode.all', () {
        tagFilter.add('urgent');
        tagFilter.add('bug');

        expect(tagFilter.apply(item), isTrue);
      });

      test('should fail item not matching all values with FilterMode.all', () {
        tagFilter.add('urgent');
        tagFilter.add('missing');

        expect(tagFilter.apply(item), isFalse);
      });

      test('should always pass when source is remote', () {
        final remoteFilter = Filter<Item, String>(
          id: 'remote',
          test: (item, value) => item.name.contains(value),
          source: TransformSource.remote,
        );
        remoteFilter.add('nomatch');

        expect(remoteFilter.apply(item), isTrue);
      });
    });

    group('getters', () {
      test('should return unmodifiable values', () {
        nameFilter.add('test');
        final values = nameFilter.values;

        expect(values, contains('test'));
        expect(() => values.add('new'), throwsUnsupportedError);
      });

      test('should return correct count', () {
        expect(nameFilter.count, equals(0));
        nameFilter.add('a');
        expect(nameFilter.count, equals(1));
        nameFilter.add('b');
        expect(nameFilter.count, equals(2));
      });

      test('should return correct isEmpty', () {
        expect(nameFilter.isEmpty, isTrue);
        nameFilter.add('test');
        expect(nameFilter.isEmpty, isFalse);
      });

      test('should return correct isNotEmpty', () {
        expect(nameFilter.isNotEmpty, isFalse);
        nameFilter.add('test');
        expect(nameFilter.isNotEmpty, isTrue);
      });

      test('should return correct contains', () {
        expect(nameFilter.contains('test'), isFalse);
        nameFilter.add('test');
        expect(nameFilter.contains('test'), isTrue);
      });

      test('should return correct isRemote for local source', () {
        final localFilter = Filter<Item, String>(
          id: 'local',
          test: (item, value) => item.name.contains(value),
        );

        expect(localFilter.isRemote, isFalse);
        expect(localFilter.isLocal, isTrue);
      });

      test('should return correct isRemote for remote source', () {
        final remoteFilter = Filter<Item, String>(
          id: 'remote',
          test: (item, value) => item.name.contains(value),
          source: TransformSource.remote,
        );

        expect(remoteFilter.isRemote, isTrue);
        expect(remoteFilter.isLocal, isFalse);
      });

      test('should return correct isRemote for combined source', () {
        final combinedFilter = Filter<Item, String>(
          id: 'combined',
          test: (item, value) => item.name.contains(value),
          source: TransformSource.combined,
        );

        expect(combinedFilter.isRemote, isTrue);
        expect(combinedFilter.isLocal, isTrue);
      });
    });

    group('copyWith', () {
      test('should create copy with new id', () {
        final copy = nameFilter.copyWith(id: 'newId');

        expect(copy.id, equals('newId'));
        expect(copy.label, equals(nameFilter.label));
      });

      test('should create copy with new label', () {
        final copy = nameFilter.copyWith(label: 'New Label');

        expect(copy.label, equals('New Label'));
        expect(copy.id, equals(nameFilter.id));
      });

      test('should create copy with new mode', () {
        final copy = nameFilter.copyWith(mode: FilterMode.all);

        expect(copy.mode, equals(FilterMode.all));
      });

      test('should create copy with new singleSelect', () {
        final copy = nameFilter.copyWith(singleSelect: true);

        expect(copy.singleSelect, isTrue);
      });

      test('should create copy with new source', () {
        final copy = nameFilter.copyWith(source: TransformSource.remote);

        expect(copy.source, equals(TransformSource.remote));
        expect(copy.isRemote, isTrue);
      });

      test('should create copy with new values', () {
        nameFilter.add('old');
        final copy = nameFilter.copyWith(values: ['new']);

        expect(copy.contains('new'), isTrue);
        expect(copy.contains('old'), isFalse);
      });

      test('should preserve existing values when not specified', () {
        nameFilter.add('test');
        final copy = nameFilter.copyWith();

        expect(copy.contains('test'), isTrue);
      });

      test('should create copy with new test predicate', () {
        final copy = nameFilter.copyWith(
          test: (item, value) => item.name.startsWith(value),
        );

        const item = Item(id: '1', name: 'test', tags: [], priority: 1);
        copy.add('test');
        expect(copy.apply(item), isTrue);

        copy.clear();
        copy.add('est');
        expect(copy.apply(item), isFalse);
      });
    });

    group('equality', () {
      test('should be equal when ids match', () {
        final filter1 = Filter<Item, String>(
          id: 'test',
          test: (item, value) => true,
        );
        final filter2 = Filter<Item, String>(
          id: 'test',
          test: (item, value) => false,
        );

        expect(filter1, equals(filter2));
      });

      test('should not be equal when ids differ', () {
        final filter1 = Filter<Item, String>(
          id: 'test1',
          test: (item, value) => true,
        );
        final filter2 = Filter<Item, String>(
          id: 'test2',
          test: (item, value) => true,
        );

        expect(filter1, isNot(equals(filter2)));
      });

      test('should be identical when same instance', () {
        expect(nameFilter == nameFilter, isTrue);
      });

      test('should have matching hashCodes when equal', () {
        final filter1 = Filter<Item, String>(
          id: 'test',
          test: (item, value) => true,
        );
        final filter2 = Filter<Item, String>(
          id: 'test',
          test: (item, value) => false,
        );

        expect(filter1.hashCode, equals(filter2.hashCode));
      });
    });

    group('toString', () {
      test('should return string representation', () {
        nameFilter.add('a');
        nameFilter.add('b');

        final str = nameFilter.toString();

        expect(str, contains('name'));
        expect(str, contains('2'));
      });
    });
  });

  group('FilterExpression', () {
    late Filter<Item, String> nameFilter;
    late Filter<Item, String> tagFilter;
    const item = Item(
      id: '1',
      name: 'test',
      tags: ['urgent'],
      priority: 1,
    );

    setUp(() {
      nameFilter = Filter<Item, String>(
        id: 'name',
        test: (item, value) => item.name.contains(value),
      );
      tagFilter = Filter<Item, String>(
        id: 'tags',
        test: (item, value) => item.tags.contains(value),
      );
    });

    group('FilterRef', () {
      test('should apply filter', () {
        nameFilter.add('test');
        final ref = FilterRef<Item, String>(nameFilter);

        expect(ref.apply(item), isTrue);
      });

      test('should have toString', () {
        final ref = FilterRef<Item, String>(nameFilter);
        expect(ref.toString(), contains('name'));
      });
    });

    group('FilterAnd', () {
      test('should pass when all expressions pass', () {
        nameFilter.add('test');
        tagFilter.add('urgent');

        final and = FilterAnd<Item>([
          FilterRef(nameFilter),
          FilterRef(tagFilter),
        ]);

        expect(and.apply(item), isTrue);
      });

      test('should fail when any expression fails', () {
        nameFilter.add('test');
        tagFilter.add('missing');

        final and = FilterAnd<Item>([
          FilterRef(nameFilter),
          FilterRef(tagFilter),
        ]);

        expect(and.apply(item), isFalse);
      });

      test('should have toString', () {
        final and = FilterAnd<Item>([
          FilterRef(nameFilter),
          FilterRef(tagFilter),
        ]);

        expect(and.toString(), contains('2'));
      });

      test('should support & operator', () {
        nameFilter.add('test');
        tagFilter.add('urgent');

        final expr = FilterRef(nameFilter) & FilterRef(tagFilter);

        expect(expr, isA<FilterAnd<Item>>());
        expect(expr.apply(item), isTrue);
      });
    });

    group('FilterOr', () {
      test('should pass when any expression passes', () {
        nameFilter.add('test');
        tagFilter.add('missing');

        final or = FilterOr<Item>([
          FilterRef(nameFilter),
          FilterRef(tagFilter),
        ]);

        expect(or.apply(item), isTrue);
      });

      test('should fail when all expressions fail', () {
        nameFilter.add('nomatch');
        tagFilter.add('missing');

        final or = FilterOr<Item>([
          FilterRef(nameFilter),
          FilterRef(tagFilter),
        ]);

        expect(or.apply(item), isFalse);
      });

      test('should have toString', () {
        final or = FilterOr<Item>([
          FilterRef(nameFilter),
          FilterRef(tagFilter),
        ]);

        expect(or.toString(), contains('2'));
      });

      test('should support | operator', () {
        nameFilter.add('test');

        final expr = FilterRef(nameFilter) | FilterRef(tagFilter);

        expect(expr, isA<FilterOr<Item>>());
        expect(expr.apply(item), isTrue);
      });
    });

    group('FilterNot', () {
      test('should invert expression result', () {
        nameFilter.add('test');
        final not = FilterNot<Item>(FilterRef(nameFilter));

        expect(not.apply(item), isFalse);
      });

      test('should have toString', () {
        final not = FilterNot<Item>(FilterRef(nameFilter));
        expect(not.toString(), contains('FilterRef'));
      });

      test('should support ~ operator', () {
        nameFilter.add('test');
        final expr = ~FilterRef(nameFilter);

        expect(expr, isA<FilterNot<Item>>());
        expect(expr.apply(item), isFalse);
      });
    });

    group('FilterAlways', () {
      test('should always pass', () {
        const always = FilterAlways<Item>();

        expect(always.apply(item), isTrue);
      });

      test('should have toString', () {
        const always = FilterAlways<Item>();
        expect(always.toString(), equals('FilterAlways'));
      });
    });

    group('FilterNever', () {
      test('should never pass', () {
        // Use non-const to ensure coverage of the constructor
        // ignore: prefer_const_constructors
        final never = FilterNever<Item>();

        expect(never.apply(item), isFalse);
      });

      test('should have toString', () {
        const never = FilterNever<Item>();
        expect(never.toString(), equals('FilterNever'));
      });
    });

    group('FilterToExpression extension', () {
      test('should convert filter to FilterRef using .ref', () {
        nameFilter.add('test');
        final ref = nameFilter.ref;

        expect(ref, isA<FilterRef<Item, String>>());
        expect(ref.filter, equals(nameFilter));
        expect(ref.apply(item), isTrue);
      });

      test('should support chaining with operators using .ref', () {
        nameFilter.add('test');
        tagFilter.add('urgent');

        final expr = nameFilter.ref & tagFilter.ref;

        expect(expr, isA<FilterAnd<Item>>());
        expect(expr.apply(item), isTrue);
      });

      test('should support complex expressions using .ref', () {
        nameFilter.add('test');
        tagFilter.add('missing');

        // (name OR tags) should pass because name matches
        final expr = nameFilter.ref | tagFilter.ref;
        expect(expr.apply(item), isTrue);

        // NOT name should fail because name matches
        final notExpr = ~nameFilter.ref;
        expect(notExpr.apply(item), isFalse);
      });
    });
  });

  group('FilterManager', () {
    late FilterManager<Item> manager;
    late Filter<Item, String> nameFilter;
    late Filter<Item, String> tagFilter;

    setUp(() {
      nameFilter = Filter<Item, String>(
        id: 'name',
        test: (item, value) => item.name.contains(value),
      );
      tagFilter = Filter<Item, String>(
        id: 'tags',
        test: (item, value) => item.tags.contains(value),
        mode: FilterMode.all,
      );
      manager = FilterManager<Item>();
    });

    group('constructor', () {
      test('should create empty manager', () {
        final mgr = FilterManager<Item>();

        expect(mgr.filterCount, equals(0));
        expect(mgr.isEmpty, isTrue);
      });

      test('should create manager with initial filters', () {
        final mgr = FilterManager<Item>(
          filters: [nameFilter, tagFilter],
        );

        expect(mgr.filterCount, equals(2));
      });

      test('should use default composition mode', () {
        final mgr = FilterManager<Item>();

        expect(mgr.defaultMode, equals(CompositionMode.and));
      });

      test('should use custom composition mode', () {
        final mgr = FilterManager<Item>(
          defaultMode: CompositionMode.or,
        );

        expect(mgr.defaultMode, equals(CompositionMode.or));
      });
    });

    group('add', () {
      test('should add filter', () {
        manager.add(nameFilter);

        expect(manager.filterCount, equals(1));
        expect(manager['name'], equals(nameFilter));
      });

      test('should replace existing filter with same id', () {
        final filter1 = Filter<Item, String>(
          id: 'test',
          test: (item, value) => true,
        );
        final filter2 = Filter<Item, String>(
          id: 'test',
          test: (item, value) => false,
        );

        manager.add(filter1);
        manager.add(filter2);

        expect(manager.filterCount, equals(1));
        expect(manager['test'], equals(filter2));
      });

      test('should notify listeners', () {
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.add(nameFilter);

        expect(notified, isTrue);
      });

      test('should listen to filter changes', () {
        var managerNotified = false;
        manager.addChangeListener(() => managerNotified = true);
        manager.add(nameFilter);

        managerNotified = false;
        nameFilter.add('test');

        expect(managerNotified, isTrue);
      });

      test('should call onChanged when filter changes', () {
        Filter<Item, dynamic>? changedFilter;
        final mgr = FilterManager<Item>(
          onChanged: (f) => changedFilter = f,
        );
        mgr.add(nameFilter);

        nameFilter.add('test');

        expect(changedFilter, equals(nameFilter));
      });
    });

    group('addAll', () {
      test('should add multiple filters', () {
        manager.addAll([nameFilter, tagFilter]);

        expect(manager.filterCount, equals(2));
      });

      test('should notify once after adding all', () {
        var notificationCount = 0;
        manager.addChangeListener(() => notificationCount++);

        manager.addAll([nameFilter, tagFilter]);

        expect(notificationCount, equals(1));
      });

      test('should replace existing filters with same id', () {
        manager.add(nameFilter);
        nameFilter.add('old');

        final newNameFilter = Filter<Item, String>(
          id: 'name',
          test: (item, value) => item.name.startsWith(value),
        );
        newNameFilter.add('new');

        manager.addAll([newNameFilter, tagFilter]);

        expect(manager.filterCount, equals(2));
        expect(manager['name'], equals(newNameFilter));
        expect(manager['name']?.values, equals({'new'}));
      });

      test('should stop listening to replaced filters', () {
        manager.add(nameFilter);
        var managerNotified = false;

        final newNameFilter = Filter<Item, String>(
          id: 'name',
          test: (item, value) => true,
        );
        manager.addAll([newNameFilter]);
        manager.addChangeListener(() => managerNotified = true);

        nameFilter.add('test');

        expect(managerNotified, isFalse);
      });

      test('should listen to filters added via addAll', () {
        var managerNotified = false;
        manager.addAll([nameFilter, tagFilter]);
        manager.addChangeListener(() => managerNotified = true);

        nameFilter.add('test');

        expect(managerNotified, isTrue);
      });
    });

    group('remove', () {
      test('should remove filter and return it', () {
        manager.add(nameFilter);
        final removed = manager.remove('name');

        expect(removed, equals(nameFilter));
        expect(manager.filterCount, equals(0));
      });

      test('should return null when filter not found', () {
        final removed = manager.remove('nonexistent');

        expect(removed, isNull);
      });

      test('should notify listeners when filter removed', () {
        var notified = false;
        manager.add(nameFilter);
        manager.addChangeListener(() => notified = true);

        manager.remove('name');

        expect(notified, isTrue);
      });

      test('should not notify when filter not found', () {
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.remove('nonexistent');

        expect(notified, isFalse);
      });

      test('should stop listening to removed filter', () {
        var managerNotified = false;
        manager.add(nameFilter);
        manager.remove('name');
        manager.addChangeListener(() => managerNotified = true);

        nameFilter.add('test');

        expect(managerNotified, isFalse);
      });
    });

    group('clear', () {
      test('should clear values in all filters', () {
        manager.add(nameFilter);
        manager.add(tagFilter);
        nameFilter.add('test');
        tagFilter.add('urgent');

        manager.clear();

        expect(nameFilter.isEmpty, isTrue);
        expect(tagFilter.isEmpty, isTrue);
      });
    });

    group('clearAll', () {
      test('should remove all filters', () {
        manager.add(nameFilter);
        manager.add(tagFilter);

        manager.clearAll();

        expect(manager.filterCount, equals(0));
      });

      test('should notify listeners', () {
        var notified = false;
        manager.add(nameFilter);
        manager.addChangeListener(() => notified = true);

        manager.clearAll();

        expect(notified, isTrue);
      });

      test('should stop listening to all filters', () {
        var managerNotified = false;
        manager.add(nameFilter);
        manager.clearAll();
        manager.addChangeListener(() => managerNotified = true);

        nameFilter.add('test');

        expect(managerNotified, isFalse);
      });
    });

    group('getters', () {
      test('should return all filters', () {
        manager.add(nameFilter);
        manager.add(tagFilter);

        final filters = manager.filters.toList();

        expect(filters, hasLength(2));
        expect(filters, contains(nameFilter));
        expect(filters, contains(tagFilter));
      });

      test('should return correct filterCount', () {
        expect(manager.filterCount, equals(0));
        manager.add(nameFilter);
        expect(manager.filterCount, equals(1));
      });

      test('should return correct selectedCount', () {
        manager.add(nameFilter);
        manager.add(tagFilter);
        nameFilter.add('a');
        nameFilter.add('b');
        tagFilter.add('c');

        expect(manager.selectedCount, equals(3));
      });

      test('should return correct isEmpty', () {
        expect(manager.isEmpty, isTrue);
        manager.add(nameFilter);
        expect(manager.isEmpty, isTrue);
        nameFilter.add('test');
        expect(manager.isEmpty, isFalse);
      });

      test('should return correct isNotEmpty', () {
        expect(manager.isNotEmpty, isFalse);
        manager.add(nameFilter);
        nameFilter.add('test');
        expect(manager.isNotEmpty, isTrue);
      });

      test('should access filter by id using []', () {
        manager.add(nameFilter);

        expect(manager['name'], equals(nameFilter));
        expect(manager['nonexistent'], isNull);
      });

      test('should get typed filter using getFilter', () {
        manager.add(nameFilter);

        final filter = manager.getFilter<String>('name');

        expect(filter, equals(nameFilter));
      });

      test('should check if filter exists using contains', () {
        expect(manager.contains('name'), isFalse);

        manager.add(nameFilter);

        expect(manager.contains('name'), isTrue);
        expect(manager.contains('nonexistent'), isFalse);
      });

      test('should return remoteFilters', () {
        final localFilter = Filter<Item, String>(
          id: 'local',
          test: (item, value) => item.name.contains(value),
        );
        final remoteFilter = Filter<Item, String>(
          id: 'remote',
          test: (item, value) => item.name.contains(value),
          source: TransformSource.remote,
        );
        final combinedFilter = Filter<Item, String>(
          id: 'combined',
          test: (item, value) => item.name.contains(value),
          source: TransformSource.combined,
        );

        manager.add(localFilter);
        manager.add(remoteFilter);
        manager.add(combinedFilter);

        final remoteFilters = manager.remoteFilters.toList();

        expect(remoteFilters, hasLength(2));
        expect(remoteFilters, contains(remoteFilter));
        expect(remoteFilters, contains(combinedFilter));
        expect(remoteFilters, isNot(contains(localFilter)));
      });

      test('should return localFilters', () {
        final localFilter = Filter<Item, String>(
          id: 'local',
          test: (item, value) => item.name.contains(value),
        );
        final remoteFilter = Filter<Item, String>(
          id: 'remote',
          test: (item, value) => item.name.contains(value),
          source: TransformSource.remote,
        );
        final combinedFilter = Filter<Item, String>(
          id: 'combined',
          test: (item, value) => item.name.contains(value),
          source: TransformSource.combined,
        );

        manager.add(localFilter);
        manager.add(remoteFilter);
        manager.add(combinedFilter);

        final localFilters = manager.localFilters.toList();

        expect(localFilters, hasLength(2));
        expect(localFilters, contains(localFilter));
        expect(localFilters, contains(combinedFilter));
        expect(localFilters, isNot(contains(remoteFilter)));
      });
    });

    group('apply', () {
      const item = Item(
        id: '1',
        name: 'test',
        tags: ['urgent'],
        priority: 1,
      );

      test('should pass all items when no filters active', () {
        manager.add(nameFilter);

        expect(manager.apply(item), isTrue);
      });

      test('should use AND composition by default', () {
        manager.add(nameFilter);
        manager.add(tagFilter);
        nameFilter.add('test');
        tagFilter.add('urgent');

        expect(manager.apply(item), isTrue);

        tagFilter.add('missing');
        expect(manager.apply(item), isFalse);
      });

      test('should use OR composition when specified', () {
        final mgr = FilterManager<Item>(
          defaultMode: CompositionMode.or,
        );
        mgr.add(nameFilter);
        mgr.add(tagFilter);
        nameFilter.add('test');
        tagFilter.add('missing');

        expect(mgr.apply(item), isTrue);
      });

      test('should handle single active filter', () {
        manager.add(nameFilter);
        nameFilter.add('test');

        expect(manager.apply(item), isTrue);
      });

      test('should use custom expression when set', () {
        manager.add(nameFilter);
        manager.add(tagFilter);
        nameFilter.add('test');
        tagFilter.add('missing');

        manager.setExpression(
          FilterRef(nameFilter) | FilterRef(tagFilter),
        );

        expect(manager.apply(item), isTrue);
      });
    });

    group('setExpression', () {
      test('should set custom expression', () {
        const expr = FilterAlways<Item>();

        manager.setExpression(expr);

        expect(
          manager.apply(
            const Item(
              id: '1',
              name: 'test',
              tags: [],
              priority: 1,
            ),
          ),
          isTrue,
        );
      });

      test('should notify listeners', () {
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.setExpression(const FilterAlways<Item>());

        expect(notified, isTrue);
      });

      test('should revert to default mode when set to null', () {
        const item = Item(
          id: '1',
          name: 'test',
          tags: [],
          priority: 1,
        );

        manager.add(nameFilter);
        nameFilter.add('missing');
        manager.setExpression(const FilterAlways<Item>());
        expect(manager.apply(item), isTrue);

        manager.setExpression(null);
        expect(manager.apply(item), isFalse);
      });
    });

    group('predicate', () {
      test('should return function for use with where', () {
        const items = [
          Item(id: '1', name: 'test', tags: [], priority: 1),
          Item(id: '2', name: 'other', tags: [], priority: 2),
        ];

        manager.add(nameFilter);
        nameFilter.add('test');

        final filtered = items.where(manager.apply).toList();

        expect(filtered, hasLength(1));
        expect(filtered.first.id, equals('1'));
      });
    });

    group('dispose', () {
      test('should dispose all filters', () {
        var filterNotified = false;
        nameFilter.addChangeListener(() => filterNotified = true);
        manager.add(nameFilter);

        manager.dispose();

        nameFilter.add('test');
        expect(filterNotified, isFalse);
      });

      test('should clear filters map', () {
        manager.add(nameFilter);

        manager.dispose();

        expect(manager.filterCount, equals(0));
      });
    });

    group('toString', () {
      test('should return string representation', () {
        manager.add(nameFilter);
        nameFilter.add('a');
        nameFilter.add('b');

        final str = manager.toString();

        expect(str, contains('1'));
        expect(str, contains('2'));
      });
    });

    group('filter', () {
      const items = [
        Item(id: '1', name: 'test item', tags: ['urgent'], priority: 1),
        Item(id: '2', name: 'other item', tags: ['bug'], priority: 2),
        Item(id: '3', name: 'test data', tags: ['urgent', 'bug'], priority: 3),
      ];

      test('should return all items when no filters active', () {
        manager.add(nameFilter);

        final result = manager.filter(items).toList();

        expect(result, hasLength(3));
      });

      test('should filter items based on active filters', () {
        manager.add(nameFilter);
        nameFilter.add('test');

        final result = manager.filter(items).toList();

        expect(result, hasLength(2));
        expect(result.map((i) => i.id), containsAll(['1', '3']));
      });

      test('should return original items when only remote filters active', () {
        final remoteFilter = Filter<Item, String>(
          id: 'remote',
          test: (item, value) => item.name.contains(value),
          source: TransformSource.remote,
        );
        manager.add(remoteFilter);
        remoteFilter.add('test');

        final result = manager.filter(items);

        // Should return the exact same iterable since no local filtering
        expect(result, same(items));
      });

      test('should filter when local filters are active', () {
        final localFilter = Filter<Item, String>(
          id: 'local',
          test: (item, value) => item.name.contains(value),
        );
        manager.add(localFilter);
        localFilter.add('other');

        final result = manager.filter(items).toList();

        expect(result, hasLength(1));
        expect(result.first.id, equals('2'));
      });

      test('should filter when combined filters are active', () {
        final combinedFilter = Filter<Item, String>(
          id: 'combined',
          test: (item, value) => item.name.contains(value),
          source: TransformSource.combined,
        );
        manager.add(combinedFilter);
        combinedFilter.add('data');

        final result = manager.filter(items).toList();

        expect(result, hasLength(1));
        expect(result.first.id, equals('3'));
      });
    });
  });

  group('SearchFilter', () {
    test('should create search filter with query', () {
      final search = SearchFilter<Item>(
        valuesRetriever: (item) => [item.name],
        query: 'test',
      );

      expect(search.query, equals('test'));
      expect(search.id, equals('search'));
    });

    test('should create search filter with empty query string', () {
      final search = SearchFilter<Item>(
        valuesRetriever: (item) => [item.name],
        query: '',
      );

      expect(search.query, isEmpty);
      expect(search.isEmpty, isTrue);
    });

    test('should create search filter with custom id and label', () {
      final search = SearchFilter<Item>(
        id: 'custom_search',
        label: 'Custom Search',
        valuesRetriever: (item) => [item.name],
      );

      expect(search.id, equals('custom_search'));
      expect(search.label, equals('Custom Search'));
    });

    test('should set and get query', () {
      final search = SearchFilter<Item>(
        valuesRetriever: (item) => [item.name],
      );

      expect(search.query, isEmpty);

      search.query = 'hello';
      expect(search.query, equals('hello'));

      search.query = 'world';
      expect(search.query, equals('world'));
    });

    test('should clear query when set to empty', () {
      final search = SearchFilter<Item>(
        valuesRetriever: (item) => [item.name],
        query: 'initial',
      );

      search.query = '';

      expect(search.query, isEmpty);
      expect(search.isEmpty, isTrue);
    });

    test('should apply search filter', () {
      final search = SearchFilter<Item>(
        valuesRetriever: (item) => [item.name],
        query: 'test',
      );

      const matchingItem =
          Item(id: '1', name: 'test item', tags: [], priority: 1);
      const nonMatchingItem =
          Item(id: '2', name: 'other', tags: [], priority: 1);

      expect(search.apply(matchingItem), isTrue);
      expect(search.apply(nonMatchingItem), isFalse);
    });

    test('should pass all items when query is empty', () {
      final search = SearchFilter<Item>(
        valuesRetriever: (item) => [item.name],
      );

      const item = Item(id: '1', name: 'anything', tags: [], priority: 1);

      expect(search.apply(item), isTrue);
    });

    test('should pass all items when empty string added via add', () {
      final search = SearchFilter<Item>(
        valuesRetriever: (item) => [item.name],
      );
      // Directly add empty string to test the predicate's empty check
      search.add('');

      const item = Item(id: '1', name: 'anything', tags: [], priority: 1);

      expect(search.apply(item), isTrue);
    });

    test('should be case insensitive', () {
      final search = SearchFilter<Item>(
        valuesRetriever: (item) => [item.name],
        query: 'TEST',
      );

      const item = Item(id: '1', name: 'test item', tags: [], priority: 1);

      expect(search.apply(item), isTrue);
    });

    test('should search across multiple fields', () {
      final search = SearchFilter<Item>(
        valuesRetriever: (item) => [item.name, item.id, ...item.tags],
        query: 'urgent',
      );

      const item = Item(id: '1', name: 'test', tags: ['urgent'], priority: 1);

      expect(search.apply(item), isTrue);
    });

    test('should ignore null values in retriever', () {
      final search = SearchFilter<Item>(
        valuesRetriever: (item) => [null, item.name, null],
        query: 'test',
      );

      const item = Item(id: '1', name: 'test item', tags: [], priority: 1);

      expect(search.apply(item), isTrue);
    });

    test('should return false when no values match', () {
      final search = SearchFilter<Item>(
        valuesRetriever: (item) => [null, null],
        query: 'test',
      );

      const item = Item(id: '1', name: 'test item', tags: [], priority: 1);

      // All values are null, so no match possible
      expect(search.apply(item), isFalse);
    });

    test('should create remote search filter', () {
      final search = SearchFilter<Item>.remote(
        id: 'remote_search',
        query: 'test',
        label: 'Remote Search',
      );

      expect(search.id, equals('remote_search'));
      expect(search.query, equals('test'));
      expect(search.label, equals('Remote Search'));
      expect(search.source, equals(TransformSource.remote));
      expect(search.isRemote, isTrue);
      expect(search.isLocal, isFalse);
    });

    test('should create remote search filter with default id', () {
      final search = SearchFilter<Item>.remote();

      expect(search.id, equals('search'));
      expect(search.source, equals(TransformSource.remote));
    });

    test('should always pass apply for remote search filter', () {
      final search = SearchFilter<Item>.remote(query: 'test');

      const item = Item(id: '1', name: 'no match', tags: [], priority: 1);

      // Remote filters always return true for apply
      expect(search.apply(item), isTrue);
    });

    test('should create search filter with combined source', () {
      final search = SearchFilter<Item>(
        valuesRetriever: (item) => [item.name],
        source: TransformSource.combined,
        query: 'test',
      );

      expect(search.source, equals(TransformSource.combined));
      expect(search.isRemote, isTrue);
      expect(search.isLocal, isTrue);

      // Combined source should still apply locally
      const matchingItem =
          Item(id: '1', name: 'test item', tags: [], priority: 1);
      const nonMatchingItem =
          Item(id: '2', name: 'other', tags: [], priority: 1);

      expect(search.apply(matchingItem), isTrue);
      expect(search.apply(nonMatchingItem), isFalse);
    });

    test('should notify listeners when query changes', () {
      final search = SearchFilter<Item>(
        valuesRetriever: (item) => [item.name],
      );

      var notified = false;
      search.addChangeListener(() => notified = true);

      search.query = 'test';

      expect(notified, isTrue);
    });

    test('should call onChanged callback when query changes', () {
      Filter<Item, String>? changedFilter;
      final search = SearchFilter<Item>(
        valuesRetriever: (item) => [item.name],
        onChanged: (f) => changedFilter = f,
      );

      search.query = 'test';

      expect(changedFilter, equals(search));
    });

    test('should call onChanged callback on remote filter', () {
      Filter<Item, String>? changedFilter;
      final search = SearchFilter<Item>.remote(
        onChanged: (f) => changedFilter = f,
      );

      search.query = 'test';

      expect(changedFilter, equals(search));
    });

    test('should have correct toString', () {
      final search = SearchFilter<Item>(
        valuesRetriever: (item) => [item.name],
        query: 'test',
      );

      final str = search.toString();

      expect(str, contains('SearchFilter'));
      expect(str, contains('search'));
      expect(str, contains('test'));
    });

    test('noOpRetriever should return empty list', () {
      final result = SearchFilter.noOpRetriever(null);

      expect(result, isEmpty);
    });

    test('noOpRetriever should return empty list for any input', () {
      final result = SearchFilter.noOpRetriever(
        const Item(id: '1', name: 'test', tags: [], priority: 1),
      );

      expect(result, isEmpty);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // FilterSnapshot Tests
  // ══════════════════════════════════════════════════════════════════════════

  group('FilterSnapshot', () {
    group('constructor', () {
      test('empty() should create empty snapshot', () {
        const snapshot = FilterSnapshot.empty();

        expect(snapshot.isEmpty, isTrue);
        expect(snapshot.isNotEmpty, isFalse);
        expect(snapshot.filterIds, isEmpty);
      });

      test('fromJson should create snapshot from map', () {
        final snapshot = FilterSnapshot.fromJson(const {
          'status': ['active', 'pending'],
          'category': ['A'],
        });

        expect(snapshot.filterIds, containsAll(['status', 'category']));
        expect(snapshot['status'], equals(['active', 'pending']));
        expect(snapshot['category'], equals(['A']));
      });

      test('fromValues should create snapshot from values map', () {
        final snapshot = FilterSnapshot.fromValues(const {
          'status': ['active'],
          'priority': [1, 2, 3],
        });

        expect(snapshot['status'], equals(['active']));
        expect(snapshot['priority'], equals([1, 2, 3]));
        expect(snapshot.isNotEmpty, isTrue);
      });
    });

    group('operator []', () {
      test('should return values for existing filter', () {
        final snapshot = FilterSnapshot.fromJson(const {
          'status': ['active'],
        });

        expect(snapshot['status'], equals(['active']));
      });

      test('should return null for non-existing filter', () {
        final snapshot = FilterSnapshot.fromJson(const {
          'status': ['active'],
        });

        expect(snapshot['nonexistent'], isNull);
      });
    });

    group('toJson', () {
      test('should serialize values to JSON map', () {
        final snapshot = FilterSnapshot.fromJson(const {
          'status': ['active', 'pending'],
          'priority': [1, 2],
        });

        final json = snapshot.toJson();

        expect(json['status'], equals(['active', 'pending']));
        expect(json['priority'], equals([1, 2]));
      });

      test('should return empty map for empty snapshot', () {
        const snapshot = FilterSnapshot.empty();

        final json = snapshot.toJson();

        expect(json, isEmpty);
      });
    });

    group('fromJson', () {
      test('should return empty for null values', () {
        final snapshot = FilterSnapshot.fromJson(const <String, dynamic>{});

        expect(snapshot.isEmpty, isTrue);
      });
    });

    group('toQueryString', () {
      test('should return empty string for empty snapshot', () {
        const snapshot = FilterSnapshot.empty();

        expect(snapshot.toQueryString(), isEmpty);
      });

      test('should encode filter values with prefix', () {
        final snapshot = FilterSnapshot.fromJson(const {
          'status': ['active'],
        });

        final query = snapshot.toQueryString();

        expect(query, equals('filter.status=active'));
      });

      test('should join multiple values with comma', () {
        final snapshot = FilterSnapshot.fromJson(const {
          'status': ['active', 'pending'],
        });

        final query = snapshot.toQueryString();

        expect(query, contains('filter.status=active,pending'));
      });

      test('should encode numeric values', () {
        final snapshot = FilterSnapshot.fromJson(const {
          'priority': [1, 2, 3],
        });

        final query = snapshot.toQueryString();

        expect(query, contains('filter.priority=1,2,3'));
      });

      test('should encode boolean values', () {
        final snapshot = FilterSnapshot.fromJson(const {
          'completed': [true, false],
        });

        final query = snapshot.toQueryString();

        expect(query, contains('filter.completed=true,false'));
      });

      test('should skip filters with empty values', () {
        final snapshot = FilterSnapshot.fromJson(const {
          'status': <String>[],
          'category': ['A'],
        });

        final query = snapshot.toQueryString();

        expect(query, isNot(contains('filter.status')));
        expect(query, contains('filter.category=A'));
      });

      test('should encode list and map values as JSON', () {
        final snapshot = FilterSnapshot.fromJson(const {
          'complex': [
            [1, 2, 3],
            {'key': 'value'},
          ],
        });

        final query = snapshot.toQueryString();

        expect(query, contains('filter.complex='));
      });

      test('should handle null values in list', () {
        final snapshot = FilterSnapshot.fromValues(const {
          'status': <dynamic>[null, 'active', null],
        });

        final query = snapshot.toQueryString();

        // Null values should be converted to empty strings
        expect(query, contains('filter.status='));
        expect(query, contains('active'));
      });
    });

    group('fromQueryString', () {
      test('should return empty for empty query', () {
        final snapshot = FilterSnapshot.fromQueryString('');

        expect(snapshot.isEmpty, isTrue);
      });

      test('should parse filter params with prefix', () {
        final snapshot =
            FilterSnapshot.fromQueryString('filter.status=active,pending');

        expect(snapshot['status'], equals(['active', 'pending']));
      });

      test('should skip empty filter ids', () {
        final snapshot = FilterSnapshot.fromQueryString('filter.=value');

        expect(snapshot.isEmpty, isTrue);
      });

      test('should parse numeric values', () {
        final snapshot =
            FilterSnapshot.fromQueryString('filter.priority=1,2,3');

        expect(snapshot['priority'], equals([1, 2, 3]));
      });

      test('should parse double values', () {
        final snapshot = FilterSnapshot.fromQueryString('filter.price=1.5,2.5');

        expect(snapshot['price'], equals([1.5, 2.5]));
      });

      test('should parse boolean values', () {
        final snapshot =
            FilterSnapshot.fromQueryString('filter.completed=true,false');

        expect(snapshot['completed'], equals([true, false]));
      });

      test('should handle empty values', () {
        final snapshot = FilterSnapshot.fromQueryString('filter.status=');

        expect(snapshot['status'], equals(['']));
      });
    });

    group('equality', () {
      test('should be equal for same values', () {
        final snapshot1 = FilterSnapshot.fromJson(const {
          'status': ['active'],
        });
        final snapshot2 = FilterSnapshot.fromJson(const {
          'status': ['active'],
        });

        expect(snapshot1, equals(snapshot2));
        expect(snapshot1.hashCode, equals(snapshot2.hashCode));
      });

      test('should not be equal for different keys', () {
        final snapshot1 = FilterSnapshot.fromJson(const {
          'status': ['active'],
        });
        final snapshot2 = FilterSnapshot.fromJson(const {
          'category': ['active'],
        });

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('should not be equal for different values', () {
        final snapshot1 = FilterSnapshot.fromJson(const {
          'status': ['active'],
        });
        final snapshot2 = FilterSnapshot.fromJson(const {
          'status': ['pending'],
        });

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('should not be equal for different lengths', () {
        final snapshot1 = FilterSnapshot.fromJson(const {
          'status': ['active'],
        });
        final snapshot2 = FilterSnapshot.fromJson(const {
          'status': ['active'],
          'category': ['A'],
        });

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('should not be equal to non-FilterSnapshot', () {
        final snapshot = FilterSnapshot.fromJson(const {
          'status': ['active'],
        });

        expect(snapshot, isNot(equals('not a snapshot')));
      });

      test('identical snapshots should be equal', () {
        final snapshot = FilterSnapshot.fromJson(const {
          'status': ['active'],
        });

        expect(snapshot, equals(snapshot));
      });

      test('should not be equal for different value counts', () {
        final snapshot1 = FilterSnapshot.fromJson(const {
          'status': ['active', 'pending'],
        });
        final snapshot2 = FilterSnapshot.fromJson(const {
          'status': ['active'],
        });

        expect(snapshot1, isNot(equals(snapshot2)));
      });
    });

    group('toString', () {
      test('should include values', () {
        final snapshot = FilterSnapshot.fromJson(const {
          'status': ['active'],
        });

        expect(snapshot.toString(), contains('FilterSnapshot'));
        expect(snapshot.toString(), contains('status'));
      });
    });

    group('roundtrip', () {
      test('should roundtrip through JSON', () {
        final original = FilterSnapshot.fromJson(const {
          'status': ['active', 'pending'],
          'priority': [1, 2, 3],
        });

        final json = original.toJson();
        final restored = FilterSnapshot.fromJson(json);

        expect(restored, equals(original));
      });

      test('should roundtrip strings through query string', () {
        final original = FilterSnapshot.fromJson(const {
          'status': ['active', 'pending'],
        });

        final query = original.toQueryString();
        final restored = FilterSnapshot.fromQueryString(query);

        expect(restored['status'], equals(original['status']));
      });
    });

    group('toJson with complex types', () {
      test('should handle bool values', () {
        final snapshot = FilterSnapshot.fromValues(const {
          'enabled': [true, false],
        });

        final json = snapshot.toJson();

        expect(json['enabled'], containsAll([true, false]));
      });

      test('should handle List values', () {
        final snapshot = FilterSnapshot.fromValues(const {
          'tags': [
            ['a', 'b'],
            ['c', 'd'],
          ],
        });

        final json = snapshot.toJson();
        final values = json['tags'] as List;

        expect(values.length, equals(2));
      });

      test('should handle objects with toJson method', () {
        final snapshot = FilterSnapshot.fromValues(const {
          'items': [
            _JsonableValue('x'),
            _JsonableValue('y'),
          ],
        });

        final json = snapshot.toJson();
        final values = json['items'] as List;

        // Should call toJson on each value
        expect(
          values,
          containsAll(const [
            {'id': 'x'},
            {'id': 'y'},
          ]),
        );
      });

      test('should fallback to toString for objects without toJson', () {
        final snapshot = FilterSnapshot.fromValues(const {
          'items': [
            _NonJsonableValue('a'),
            _NonJsonableValue('b'),
          ],
        });

        final json = snapshot.toJson();
        final values = json['items'] as List;

        // Should fall back to toString
        expect(
          values,
          containsAll(const ['_NonJsonableValue(a)', '_NonJsonableValue(b)']),
        );
      });
    });
  });

  group('FilterManager restoreState', () {
    test('should restore filter values from snapshot', () {
      final filter = Filter<Item, String>(
        id: 'category',
        test: (item, value) => item.tags.contains(value),
      );
      final manager = FilterManager<Item>(filters: [filter]);

      // Add values and capture state
      filter
        ..add('A')
        ..add('B');
      final capturedSnapshot = manager.captureState();

      // Clear and verify empty
      filter.clear();
      expect(filter.isEmpty, isTrue);

      // Restore from captured snapshot
      manager.restoreState(capturedSnapshot);

      expect(filter.values, equals({'A', 'B'}));
    });

    test('should clear filter when snapshot has no values for filter', () {
      final filter = Filter<Item, String>(
        id: 'category',
        test: (item, value) => item.tags.contains(value),
      );
      final manager = FilterManager<Item>(filters: [filter]);

      // Add values
      filter.add('A');
      expect(filter.isNotEmpty, isTrue);

      // Restore empty snapshot - filter should be cleared
      const snapshot = FilterSnapshot.empty();
      manager.restoreState(snapshot);

      expect(filter.isEmpty, isTrue);
    });
  });

  // ===========================================================================
  // FilterCriteria Additional Coverage Tests
  // ===========================================================================

  group('FilterCriteria', () {
    test('single factory creates criterion with one value', () {
      final criteria = FilterCriteria.single('status', 'active');

      expect(criteria.id, equals('status'));
      expect(criteria.values, equals({'active'}));
    });

    test('fromJson parses valid JSON', () {
      final json = {
        'id': 'category',
        'values': ['food', 'drink'],
      };
      final criteria = FilterCriteria.fromJson(json);

      expect(criteria.id, equals('category'));
      expect(criteria.values, equals({'food', 'drink'}));
    });

    test('fromJson throws on invalid JSON', () {
      final json = {'invalid': 'data'};

      expect(
        () => FilterCriteria.fromJson(json),
        throwsFormatException,
      );
    });

    test('fromQueryParams parses filter parameters', () {
      final params = {
        'filter[status]': 'active,pending',
        'filter[category]': 'food',
        'other_param': 'ignored',
      };
      final criteria = FilterCriteria.fromQueryParams(params);

      expect(criteria.length, equals(2));
      expect(criteria.any((c) => c.id == 'status'), isTrue);
      expect(criteria.any((c) => c.id == 'category'), isTrue);
    });

    test('fromQueryParams handles empty params', () {
      final criteria = FilterCriteria.fromQueryParams({});

      expect(criteria, isEmpty);
    });

    test('isEmpty returns true for empty values', () {
      const criteria = FilterCriteria(id: 'test', values: {});

      expect(criteria.isEmpty, isTrue);
      expect(criteria.isNotEmpty, isFalse);
    });

    test('toJson converts to JSON map', () {
      const criteria =
          FilterCriteria(id: 'status', values: {'active', 'pending'});
      final json = criteria.toJson();

      expect(json['id'], equals('status'));
      expect(json['values'], isA<List<String?>>());
    });

    test('toString returns descriptive string', () {
      const criteria = FilterCriteria(id: 'status', values: {'active'});
      final str = criteria.toString();

      expect(str, contains('FilterCriteria'));
      expect(str, contains('status'));
    });
  });

  group('FilterManager isEmpty/isNotEmpty', () {
    test('isEmpty returns true when all filters are empty', () {
      final filter1 = Filter<Item, String>(
        id: 'a',
        test: (item, value) => true,
      );
      final filter2 = Filter<Item, String>(
        id: 'b',
        test: (item, value) => true,
      );
      final manager = FilterManager<Item>(filters: [filter1, filter2]);

      expect(manager.isEmpty, isTrue);
      expect(manager.isNotEmpty, isFalse);
    });

    test('isNotEmpty returns true when any filter has values', () {
      final filter1 = Filter<Item, String>(
        id: 'a',
        test: (item, value) => true,
      );
      final filter2 = Filter<Item, String>(
        id: 'b',
        test: (item, value) => true,
      );
      final manager = FilterManager<Item>(filters: [filter1, filter2]);

      filter1.add('value');

      expect(manager.isEmpty, isFalse);
      expect(manager.isNotEmpty, isTrue);
    });
  });

  group('FilterManager _onFilterChanged', () {
    test('onChanged callback is called when filter changes', () {
      var changedFilter = '';
      final filter = Filter<Item, String>(
        id: 'test',
        test: (item, value) => true,
      );
      FilterManager<Item>(
        filters: [filter],
        onChanged: (f) => changedFilter = f.id,
      );

      filter.add('value');

      expect(changedFilter, equals('test'));
    });
  });
}

// Test helper class that uses Listenable mixin
class _TestListenable with Listenable {
  void triggerNotify() {
    notifyChanged();
  }
}

/// Helper class with toJson method for testing.
@immutable
class _JsonableValue {
  const _JsonableValue(this.id);
  final String id;

  Map<String, dynamic> toJson() => {'id': id};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _JsonableValue && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Helper class without toJson method for testing.
@immutable
class _NonJsonableValue {
  const _NonJsonableValue(this.id);
  final String id;

  @override
  String toString() => '_NonJsonableValue($id)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _NonJsonableValue && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
