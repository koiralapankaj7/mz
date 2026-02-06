// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

import 'package:meta/meta.dart';
import 'package:mz_collection/src/sort_manager.dart';
import 'package:test/test.dart';

/// Test data model.
@immutable
class User {
  const User({
    required this.id,
    required this.name,
    this.age,
    this.joinDate,
    this.priority = 0,
  });

  final String id;
  final String name;
  final int? age;
  final DateTime? joinDate;
  final int priority;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is User && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'User($id, $name)';
}

void main() {
  group('SortOrder', () {
    test('should have correct code values', () {
      expect(SortOrder.ascending.code, equals('asc'));
      expect(SortOrder.descending.code, equals('desc'));
      expect(SortOrder.none.code, equals(''));
    });

    test('should have correct isAscending values', () {
      expect(SortOrder.ascending.isAscending, isTrue);
      expect(SortOrder.descending.isAscending, isFalse);
      expect(SortOrder.none.isAscending, isFalse);
    });

    test('should have correct isDescending values', () {
      expect(SortOrder.ascending.isDescending, isFalse);
      expect(SortOrder.descending.isDescending, isTrue);
      expect(SortOrder.none.isDescending, isFalse);
    });

    test('should have correct isNone values', () {
      expect(SortOrder.ascending.isNone, isFalse);
      expect(SortOrder.descending.isNone, isFalse);
      expect(SortOrder.none.isNone, isTrue);
    });

    group('toggle', () {
      test('should toggle through all three states with triState true', () {
        expect(SortOrder.ascending.toggle(), equals(SortOrder.descending));
        expect(SortOrder.descending.toggle(), equals(SortOrder.none));
        expect(SortOrder.none.toggle(), equals(SortOrder.ascending));
      });

      test('should toggle between two states with triState false', () {
        expect(
          SortOrder.ascending.toggle(triState: false),
          equals(SortOrder.descending),
        );
        expect(
          SortOrder.descending.toggle(triState: false),
          equals(SortOrder.ascending),
        );
        expect(
          SortOrder.none.toggle(triState: false),
          equals(SortOrder.ascending),
        );
      });
    });
  });

  group('SortValue', () {
    test('should create with required parameters', () {
      final value = SortValue<User>(
        id: 'name',
        value: (user) => user.name,
      );

      expect(value.id, equals('name'));
      expect(value.label, isNull);
    });

    test('should create with optional label', () {
      final value = SortValue<User>(
        id: 'name',
        label: 'User Name',
        value: (user) => user.name,
      );

      expect(value.label, equals('User Name'));
    });

    test('should extract value correctly', () {
      final value = SortValue<User>(
        id: 'name',
        value: (user) => user.name,
      );

      const user = User(id: '1', name: 'Alice');
      expect(value.value(user), equals('Alice'));
    });

    test('should be equal when ids match', () {
      final value1 = SortValue<User>(
        id: 'name',
        value: (user) => user.name,
      );
      final value2 = SortValue<User>(
        id: 'name',
        value: (user) => user.name.toUpperCase(),
      );

      expect(value1, equals(value2));
      expect(value1.hashCode, equals(value2.hashCode));
    });

    test('should not be equal when ids differ', () {
      final value1 = SortValue<User>(
        id: 'name',
        value: (user) => user.name,
      );
      final value2 = SortValue<User>(
        id: 'age',
        value: (user) => user.age,
      );

      expect(value1, isNot(equals(value2)));
    });

    test('should have toString representation', () {
      final value = SortValue<User>(
        id: 'name',
        value: (user) => user.name,
      );

      expect(value.toString(), contains('name'));
    });
  });

  group('ValueSortOption', () {
    late SortOption<User, String> nameSort;

    setUp(() {
      nameSort = SortOption<User, String>(
        id: 'name',
        label: 'Name',
        sortIdentifier: (user) => user.name,
      );
    });

    group('constructor', () {
      test('should create with default values', () {
        final sort = SortOption<User, String>(
          id: 'test',
          sortIdentifier: (user) => user.name,
        );

        expect(sort.id, equals('test'));
        expect(sort.label, isNull);
        expect(sort.sortOrder, equals(SortOrder.ascending));
        expect(sort.enabled, isTrue);
      });

      test('should create with custom values', () {
        final sort = SortOption<User, String>(
          id: 'test',
          label: 'Test Label',
          sortIdentifier: (user) => user.name,
          sortOrder: SortOrder.descending,
          enabled: false,
        );

        expect(sort.label, equals('Test Label'));
        expect(sort.sortOrder, equals(SortOrder.descending));
        expect(sort.enabled, isFalse);
      });
    });

    group('compare', () {
      const alice = User(id: '1', name: 'Alice');
      const bob = User(id: '2', name: 'Bob');
      const charlie = User(id: '3', name: 'Charlie');

      test('should compare ascending', () {
        expect(nameSort.compare(alice, bob), lessThan(0));
        expect(nameSort.compare(bob, alice), greaterThan(0));
        expect(nameSort.compare(alice, alice), equals(0));
      });

      test('should compare descending', () {
        nameSort.sortOrder = SortOrder.descending;

        expect(nameSort.compare(alice, bob), greaterThan(0));
        expect(nameSort.compare(bob, alice), lessThan(0));
      });

      test('should return 0 when sortOrder is none', () {
        nameSort.sortOrder = SortOrder.none;

        expect(nameSort.compare(alice, bob), equals(0));
        expect(nameSort.compare(bob, alice), equals(0));
      });

      test('should sort list correctly', () {
        final users = [charlie, alice, bob];
        users.sort(nameSort.compare);

        expect(users, equals([alice, bob, charlie]));
      });

      test('should handle null items', () {
        expect(nameSort.compare(null, alice), lessThan(0));
        expect(nameSort.compare(alice, null), greaterThan(0));
        expect(nameSort.compare(null, null), equals(0));
      });
    });

    group('nullable values', () {
      late SortOption<User, int?> ageSort;

      setUp(() {
        ageSort = SortOption<User, int?>(
          id: 'age',
          sortIdentifier: (user) => user.age,
        );
      });

      test('should handle nullable values', () {
        const alice = User(id: '1', name: 'Alice', age: 30);
        const bob = User(id: '2', name: 'Bob');
        const charlie = User(id: '3', name: 'Charlie', age: 25);

        expect(ageSort.compare(alice, bob), greaterThan(0));
        expect(ageSort.compare(bob, charlie), lessThan(0));
        expect(ageSort.compare(alice, charlie), greaterThan(0));
      });
    });

    group('sortString', () {
      test('should return id:asc for ascending', () {
        expect(nameSort.sortString, equals('name:asc'));
      });

      test('should return id:desc for descending', () {
        nameSort.sortOrder = SortOrder.descending;
        expect(nameSort.sortString, equals('name:desc'));
      });

      test('should return empty string for none', () {
        nameSort.sortOrder = SortOrder.none;
        expect(nameSort.sortString, equals(''));
      });

      test('should return empty string for empty id', () {
        final sort = SortOption<User, String>(
          id: '',
          sortIdentifier: (user) => user.name,
        );
        expect(sort.sortString, equals(''));
      });

      test('should return empty string for whitespace id', () {
        final sort = SortOption<User, String>(
          id: '   ',
          sortIdentifier: (user) => user.name,
        );
        expect(sort.sortString, equals(''));
      });
    });

    group('toggle', () {
      test('should toggle through all three states', () {
        expect(nameSort.sortOrder, equals(SortOrder.ascending));

        nameSort.toggle();
        expect(nameSort.sortOrder, equals(SortOrder.descending));

        nameSort.toggle();
        expect(nameSort.sortOrder, equals(SortOrder.none));

        nameSort.toggle();
        expect(nameSort.sortOrder, equals(SortOrder.ascending));
      });

      test('should toggle between two states with triState false', () {
        expect(nameSort.sortOrder, equals(SortOrder.ascending));

        nameSort.toggle(triState: false);
        expect(nameSort.sortOrder, equals(SortOrder.descending));

        nameSort.toggle(triState: false);
        expect(nameSort.sortOrder, equals(SortOrder.ascending));
      });
    });

    group('silentUpdate', () {
      test('should update sortOrder without notifying', () {
        var notified = false;
        nameSort.addChangeListener(() => notified = true);

        nameSort.silentUpdate(SortOrder.descending);

        expect(nameSort.sortOrder, equals(SortOrder.descending));
        expect(notified, isFalse);
      });

      test('should not update if value is null', () {
        nameSort.silentUpdate(null);
        expect(nameSort.sortOrder, equals(SortOrder.ascending));
      });

      test('should not update if value is same', () {
        nameSort.silentUpdate(SortOrder.ascending);
        expect(nameSort.sortOrder, equals(SortOrder.ascending));
      });
    });

    group('sortOrder setter', () {
      test('should notify listeners when changed', () {
        var notified = false;
        nameSort.addChangeListener(() => notified = true);

        nameSort.sortOrder = SortOrder.descending;

        expect(notified, isTrue);
      });

      test('should not notify if value is same', () {
        var notified = false;
        nameSort.addChangeListener(() => notified = true);

        nameSort.sortOrder = SortOrder.ascending;

        expect(notified, isFalse);
      });
    });

    group('ascending getter', () {
      test('should return true for ascending order', () {
        expect(nameSort.ascending, isTrue);
      });

      test('should return false for descending order', () {
        nameSort.sortOrder = SortOrder.descending;
        expect(nameSort.ascending, isFalse);
      });

      test('should return false for none order', () {
        nameSort.sortOrder = SortOrder.none;
        expect(nameSort.ascending, isFalse);
      });
    });

    group('copyWith', () {
      test('should create copy with new id', () {
        final copy = nameSort.copyWith(id: 'newId');

        expect(copy.id, equals('newId'));
        expect(copy.label, equals(nameSort.label));
      });

      test('should create copy with new label', () {
        final copy = nameSort.copyWith(label: 'New Label');

        expect(copy.label, equals('New Label'));
      });

      test('should create copy with new sortOrder', () {
        final copy = nameSort.copyWith(sortOrder: SortOrder.descending);

        expect(copy.sortOrder, equals(SortOrder.descending));
      });

      test('should create copy with new enabled', () {
        final copy = nameSort.copyWith(enabled: false);

        expect(copy.enabled, isFalse);
      });

      test('should preserve values when not specified', () {
        final copy = nameSort.copyWith();

        expect(copy.id, equals(nameSort.id));
        expect(copy.label, equals(nameSort.label));
        expect(copy.sortOrder, equals(nameSort.sortOrder));
        expect(copy.enabled, equals(nameSort.enabled));
      });
    });

    group('equality', () {
      test('should be equal when id and sortOrder match', () {
        final sort1 = SortOption<User, String>(
          id: 'name',
          sortIdentifier: (user) => user.name,
        );
        final sort2 = SortOption<User, String>(
          id: 'name',
          sortIdentifier: (user) => user.name.toUpperCase(),
        );

        expect(sort1, equals(sort2));
      });

      test('should not be equal when ids differ', () {
        final sort1 = SortOption<User, String>(
          id: 'name',
          sortIdentifier: (user) => user.name,
        );
        final sort2 = SortOption<User, String>(
          id: 'other',
          sortIdentifier: (user) => user.name,
        );

        expect(sort1, isNot(equals(sort2)));
      });

      test('should not be equal when sortOrder differs', () {
        final sort1 = SortOption<User, String>(
          id: 'name',
          sortIdentifier: (user) => user.name,
        );
        final sort2 = SortOption<User, String>(
          id: 'name',
          sortIdentifier: (user) => user.name,
          sortOrder: SortOrder.descending,
        );

        expect(sort1, isNot(equals(sort2)));
      });

      test('should have matching hashCodes when equal', () {
        final sort1 = SortOption<User, String>(
          id: 'name',
          sortIdentifier: (user) => user.name,
        );
        final sort2 = SortOption<User, String>(
          id: 'name',
          sortIdentifier: (user) => user.name,
        );

        expect(sort1.hashCode, equals(sort2.hashCode));
      });
    });

    group('toString', () {
      test('should return string representation', () {
        final str = nameSort.toString();

        expect(str, contains('name'));
        expect(str, contains('ascending'));
      });
    });
  });

  group('ComparableSortOption', () {
    late SortOption<User, Never> multiSort;

    setUp(() {
      multiSort = SortOption<User, Never>.withComparable(
        id: 'name_age',
        label: 'Name then Age',
        comparables: (user) => [user.name, user.age],
      );
    });

    group('compare', () {
      test('should compare using multiple fields', () {
        const alice30 = User(id: '1', name: 'Alice', age: 30);
        const alice25 = User(id: '2', name: 'Alice', age: 25);
        const bob30 = User(id: '3', name: 'Bob', age: 30);

        expect(multiSort.compare(alice30, alice25), greaterThan(0));
        expect(multiSort.compare(alice25, alice30), lessThan(0));
        expect(multiSort.compare(alice30, bob30), lessThan(0));
      });

      test('should handle null values in comparables with single-field sort',
          () {
        final ageOnlySort = SortOption<User, Never>.withComparable(
          id: 'age_only',
          comparables: (user) => [user.age],
        );

        const alice = User(id: '1', name: 'Alice', age: 30);
        const bob = User(id: '2', name: 'Bob');

        // null age should come before non-null age
        expect(ageOnlySort.compare(bob, alice), lessThan(0));
        expect(ageOnlySort.compare(alice, bob), greaterThan(0));
      });

      test('should return 0 when sortOrder is none', () {
        multiSort.sortOrder = SortOrder.none;

        const alice = User(id: '1', name: 'Alice', age: 30);
        const bob = User(id: '2', name: 'Bob', age: 25);

        expect(multiSort.compare(alice, bob), equals(0));
      });

      test('should handle null items as empty comparables', () {
        const alice = User(id: '1', name: 'Alice', age: 30);

        // ComparableSortOption treats null items as empty lists
        // Empty list vs non-empty list returns 0 (no elements to compare)
        expect(multiSort.compare(null, alice), equals(0));
        expect(multiSort.compare(alice, null), equals(0));
        expect(multiSort.compare(null, null), equals(0));
      });

      test('should compare descending', () {
        multiSort.sortOrder = SortOrder.descending;

        const alice = User(id: '1', name: 'Alice', age: 30);
        const bob = User(id: '2', name: 'Bob', age: 25);

        expect(multiSort.compare(alice, bob), greaterThan(0));
      });

      test('should handle lists of different lengths', () {
        final shortSort = SortOption<User, Never>.withComparable(
          id: 'short',
          comparables: (user) => [user.name],
        );

        const alice30 = User(id: '1', name: 'Alice', age: 30);
        const alice25 = User(id: '2', name: 'Alice', age: 25);

        expect(shortSort.compare(alice30, alice25), equals(0));
      });
    });

    group('copyWith', () {
      test('should create copy with new values', () {
        final copy = multiSort.copyWith(
          id: 'newId',
          sortOrder: SortOrder.descending,
        );

        expect(copy.id, equals('newId'));
        expect(copy.sortOrder, equals(SortOrder.descending));
      });

      test('should create copy with new comparables function', () {
        final concreteSort = multiSort as ComparableSortOption<User>;
        final copy = concreteSort.copyWith(
          comparables: (user) => [user.priority],
        );

        const highPriority = User(id: '1', name: 'Alice', priority: 10);
        const lowPriority = User(id: '2', name: 'Bob', priority: 1);

        expect(copy.compare(lowPriority, highPriority), lessThan(0));
      });
    });

    group('toString', () {
      test('should return string representation', () {
        expect(multiSort.toString(), contains('ComparableSortOption'));
        expect(multiSort.toString(), contains('name_age'));
      });
    });
  });

  group('ComparatorSortOption', () {
    late ComparatorSortOption<User> prioritySort;

    setUp(() {
      prioritySort = SortOption<User, Never>.withComparator(
        id: 'priority',
        label: 'Priority',
        comparator: (a, b) => a.priority.compareTo(b.priority),
      ) as ComparatorSortOption<User>;
    });

    group('compare', () {
      test('should use custom comparator', () {
        const high = User(id: '1', name: 'High', priority: 10);
        const low = User(id: '2', name: 'Low', priority: 1);

        expect(prioritySort.compare(low, high), lessThan(0));
        expect(prioritySort.compare(high, low), greaterThan(0));
      });

      test('should compare descending', () {
        prioritySort.sortOrder = SortOrder.descending;

        const high = User(id: '1', name: 'High', priority: 10);
        const low = User(id: '2', name: 'Low', priority: 1);

        expect(prioritySort.compare(low, high), greaterThan(0));
      });

      test('should return 0 when sortOrder is none', () {
        prioritySort.sortOrder = SortOrder.none;

        const high = User(id: '1', name: 'High', priority: 10);
        const low = User(id: '2', name: 'Low', priority: 1);

        expect(prioritySort.compare(low, high), equals(0));
      });

      test('should return 0 for null items', () {
        const user = User(id: '1', name: 'Test', priority: 5);

        expect(prioritySort.compare(null, user), equals(0));
        expect(prioritySort.compare(user, null), equals(0));
      });
    });

    group('secondary comparator', () {
      late ComparatorSortOption<User> withSecondary;

      setUp(() {
        withSecondary = SortOption<User, Never>.withComparator(
          id: 'priority',
          comparator: (a, b) => a.priority.compareTo(b.priority),
          secondaryId: 'name',
          secondaryComparator: (a, b) => a.name.compareTo(b.name),
        ) as ComparatorSortOption<User>;
      });

      test('should use secondary comparator for tie-breaking', () {
        const alice = User(id: '1', name: 'Alice', priority: 5);
        const bob = User(id: '2', name: 'Bob', priority: 5);

        expect(withSecondary.compare(alice, bob), lessThan(0));
        expect(withSecondary.compare(bob, alice), greaterThan(0));
      });

      test('should respect secondary sort order', () {
        withSecondary.secondarySortOrder = SortOrder.descending;

        const alice = User(id: '1', name: 'Alice', priority: 5);
        const bob = User(id: '2', name: 'Bob', priority: 5);

        expect(withSecondary.compare(alice, bob), greaterThan(0));
      });

      test('should have hasSecondary true', () {
        expect(withSecondary.hasSecondary, isTrue);
      });

      test('should have hasSecondary false when no secondary', () {
        expect(prioritySort.hasSecondary, isFalse);
      });

      test('should notify when secondarySortOrder changes', () {
        var notified = false;
        withSecondary.addChangeListener(() => notified = true);

        withSecondary.secondarySortOrder = SortOrder.descending;

        expect(notified, isTrue);
      });

      test('should not notify if secondarySortOrder unchanged', () {
        var notified = false;
        withSecondary.addChangeListener(() => notified = true);

        withSecondary.secondarySortOrder = SortOrder.ascending;

        expect(notified, isFalse);
      });

      test('should return correct secondaryAscending', () {
        expect(withSecondary.secondaryAscending, isTrue);

        withSecondary.secondarySortOrder = SortOrder.descending;
        expect(withSecondary.secondaryAscending, isFalse);
      });
    });

    group('sortString', () {
      test('should include only primary when no secondary', () {
        expect(prioritySort.sortString, equals('priority:asc'));
      });

      test('should include secondary when present', () {
        final withSecondary = SortOption<User, Never>.withComparator(
          id: 'priority',
          comparator: (a, b) => a.priority.compareTo(b.priority),
          secondaryId: 'name',
          secondaryComparator: (a, b) => a.name.compareTo(b.name),
        ) as ComparatorSortOption<User>;

        expect(withSecondary.sortString, equals('priority:asc,name:asc'));
      });

      test('should respect sort orders', () {
        final withSecondary = SortOption<User, Never>.withComparator(
          id: 'priority',
          comparator: (a, b) => a.priority.compareTo(b.priority),
          sortOrder: SortOrder.descending,
          secondaryId: 'name',
          secondaryComparator: (a, b) => a.name.compareTo(b.name),
          secondarySortOrder: SortOrder.descending,
        ) as ComparatorSortOption<User>;

        expect(withSecondary.sortString, equals('priority:desc,name:desc'));
      });

      test('should exclude none orders', () {
        final withSecondary = SortOption<User, Never>.withComparator(
          id: 'priority',
          comparator: (a, b) => a.priority.compareTo(b.priority),
          sortOrder: SortOrder.none,
          secondaryId: 'name',
          secondaryComparator: (a, b) => a.name.compareTo(b.name),
        ) as ComparatorSortOption<User>;

        expect(withSecondary.sortString, equals('name:asc'));
      });
    });

    group('copyWith', () {
      test('should create copy with new values', () {
        final copy = prioritySort.copyWith(
          id: 'newId',
          sortOrder: SortOrder.descending,
        );

        expect(copy.id, equals('newId'));
        expect(copy.sortOrder, equals(SortOrder.descending));
      });

      test('should copy secondary comparator', () {
        final withSecondary = SortOption<User, Never>.withComparator(
          id: 'priority',
          comparator: (a, b) => a.priority.compareTo(b.priority),
          secondaryId: 'name',
          secondaryComparator: (a, b) => a.name.compareTo(b.name),
        ) as ComparatorSortOption<User>;

        final copy = withSecondary.copyWith() as ComparatorSortOption<User>;

        expect(copy.hasSecondary, isTrue);
        expect(copy.secondaryId, equals('name'));
      });
    });

    group('toString', () {
      test('should return string representation', () {
        expect(prioritySort.toString(), contains('ComparatorSortOption'));
        expect(prioritySort.toString(), contains('priority'));
      });
    });
  });

  group('CustomSortOption', () {
    late CustomSortOption<User> flexibleSort;

    setUp(() {
      flexibleSort = SortOption<User, Never>.custom(
        id: 'flexible',
        label: 'Flexible Sort',
        values: [
          SortValue(id: 'name', label: 'Name', value: (u) => u.name),
          SortValue(id: 'age', label: 'Age', value: (u) => u.age),
          SortValue(
            id: 'priority',
            label: 'Priority',
            value: (u) => u.priority,
          ),
        ],
      ) as CustomSortOption<User>;
    });

    group('constructor', () {
      test('should create with values and default index', () {
        expect(flexibleSort.values, hasLength(3));
        expect(flexibleSort.current?.id, equals('name'));
      });

      test('should create with custom initial index', () {
        final sort = SortOption<User, Never>.custom(
          id: 'test',
          values: [
            SortValue(id: 'a', value: (u) => u.name),
            SortValue(id: 'b', value: (u) => u.age),
          ],
          initialIndex: 1,
        ) as CustomSortOption<User>;

        expect(sort.current?.id, equals('b'));
      });

      test('should clamp initial index', () {
        final sort = SortOption<User, Never>.custom(
          id: 'test',
          values: [
            SortValue(id: 'a', value: (u) => u.name),
          ],
          initialIndex: 10,
        ) as CustomSortOption<User>;

        expect(sort.current?.id, equals('a'));
      });

      test('should handle empty values', () {
        final sort = SortOption<User, Never>.custom(
          id: 'test',
          values: [],
        ) as CustomSortOption<User>;

        expect(sort.current, isNull);
      });
    });

    group('current setter', () {
      test('should set current value', () {
        final ageValue = flexibleSort.values[1];
        flexibleSort.current = ageValue;

        expect(flexibleSort.current?.id, equals('age'));
      });

      test('should notify listeners when changed', () {
        var notified = false;
        flexibleSort.addChangeListener(() => notified = true);

        flexibleSort.current = flexibleSort.values[1];

        expect(notified, isTrue);
      });

      test('should not notify if setting same value', () {
        var notified = false;
        flexibleSort.addChangeListener(() => notified = true);

        flexibleSort.current = flexibleSort.values[0];

        expect(notified, isFalse);
      });

      test('should ignore null value', () {
        final originalCurrent = flexibleSort.current;
        flexibleSort.current = null;

        expect(flexibleSort.current, equals(originalCurrent));
      });

      test('should ignore value not in list', () {
        final foreignValue = SortValue<User>(
          id: 'foreign',
          value: (u) => u.name,
        );
        final originalCurrent = flexibleSort.current;

        flexibleSort.current = foreignValue;

        expect(flexibleSort.current, equals(originalCurrent));
      });
    });

    group('setCurrentIndex', () {
      test('should set current by index', () {
        flexibleSort.setCurrentIndex(2);

        expect(flexibleSort.current?.id, equals('priority'));
      });

      test('should clamp index to valid range', () {
        flexibleSort.setCurrentIndex(100);
        expect(flexibleSort.current?.id, equals('priority'));

        flexibleSort.setCurrentIndex(-5);
        expect(flexibleSort.current?.id, equals('name'));
      });

      test('should notify listeners when changed', () {
        var notified = false;
        flexibleSort.addChangeListener(() => notified = true);

        flexibleSort.setCurrentIndex(1);

        expect(notified, isTrue);
      });

      test('should not notify if index unchanged', () {
        var notified = false;
        flexibleSort.addChangeListener(() => notified = true);

        flexibleSort.setCurrentIndex(0);

        expect(notified, isFalse);
      });
    });

    group('compare', () {
      const alice = User(id: '1', name: 'Alice', age: 30, priority: 5);
      const bob = User(id: '2', name: 'Bob', age: 25, priority: 10);

      test('should compare using current value', () {
        expect(flexibleSort.compare(alice, bob), lessThan(0));

        flexibleSort.setCurrentIndex(1);
        expect(flexibleSort.compare(alice, bob), greaterThan(0));

        flexibleSort.setCurrentIndex(2);
        expect(flexibleSort.compare(alice, bob), lessThan(0));
      });

      test('should return 0 when sortOrder is none', () {
        flexibleSort.sortOrder = SortOrder.none;

        expect(flexibleSort.compare(alice, bob), equals(0));
      });

      test('should return 0 when current is null', () {
        final emptySort = SortOption<User, Never>.custom(
          id: 'empty',
          values: [],
        ) as CustomSortOption<User>;

        expect(emptySort.compare(alice, bob), equals(0));
      });

      test('should handle null items', () {
        expect(flexibleSort.compare(null, alice), lessThan(0));
        expect(flexibleSort.compare(alice, null), greaterThan(0));
      });

      test('should respect sort order', () {
        flexibleSort.sortOrder = SortOrder.descending;

        expect(flexibleSort.compare(alice, bob), greaterThan(0));
      });
    });

    group('sortString', () {
      test('should return current value id', () {
        expect(flexibleSort.sortString, equals('name:asc'));

        flexibleSort.setCurrentIndex(1);
        expect(flexibleSort.sortString, equals('age:asc'));
      });

      test('should respect sort order', () {
        flexibleSort.sortOrder = SortOrder.descending;
        expect(flexibleSort.sortString, equals('name:desc'));
      });

      test('should return empty when sortOrder is none', () {
        flexibleSort.sortOrder = SortOrder.none;
        expect(flexibleSort.sortString, equals(''));
      });

      test('should return empty when current is null', () {
        final emptySort = SortOption<User, Never>.custom(
          id: 'empty',
          values: [],
        ) as CustomSortOption<User>;

        expect(emptySort.sortString, equals(''));
      });
    });

    group('copyWith', () {
      test('should create copy with new values', () {
        final copy = flexibleSort.copyWith(
          id: 'newId',
          sortOrder: SortOrder.descending,
        ) as CustomSortOption<User>;

        expect(copy.id, equals('newId'));
        expect(copy.sortOrder, equals(SortOrder.descending));
      });

      test('should preserve current index', () {
        flexibleSort.setCurrentIndex(2);
        final copy = flexibleSort.copyWith() as CustomSortOption<User>;

        expect(copy.current?.id, equals('priority'));
      });
    });

    group('equality', () {
      test('should be equal when id, sortOrder, and currentIndex match', () {
        final sort1 = SortOption<User, Never>.custom(
          id: 'test',
          values: [SortValue(id: 'a', value: (u) => u.name)],
        ) as CustomSortOption<User>;
        final sort2 = SortOption<User, Never>.custom(
          id: 'test',
          values: [SortValue(id: 'a', value: (u) => u.name)],
        ) as CustomSortOption<User>;

        expect(sort1, equals(sort2));
        expect(sort1.hashCode, equals(sort2.hashCode));
      });

      test('should not be equal when currentIndex differs', () {
        final sort1 = SortOption<User, Never>.custom(
          id: 'test',
          values: [
            SortValue(id: 'a', value: (u) => u.name),
            SortValue(id: 'b', value: (u) => u.age),
          ],
        ) as CustomSortOption<User>;
        final sort2 = SortOption<User, Never>.custom(
          id: 'test',
          values: [
            SortValue(id: 'a', value: (u) => u.name),
            SortValue(id: 'b', value: (u) => u.age),
          ],
          initialIndex: 1,
        ) as CustomSortOption<User>;

        expect(sort1, isNot(equals(sort2)));
        expect(sort1.hashCode, isNot(equals(sort2.hashCode)));
      });
    });

    group('toString', () {
      test('should return string representation', () {
        expect(flexibleSort.toString(), contains('CustomSortOption'));
        expect(flexibleSort.toString(), contains('flexible'));
        expect(flexibleSort.toString(), contains('name'));
      });
    });
  });

  group('SortOption.none', () {
    test('should always return 0 from compare', () {
      final none = SortOption.none;

      expect(none.compare(null, null), equals(0));
    });

    test('should have empty id', () {
      expect(SortOption.none.id, equals(''));
    });

    test('should not be enabled', () {
      expect(SortOption.none.enabled, isFalse);
    });

    test('should ignore sortOrder setter', () {
      SortOption.none.sortOrder = SortOrder.descending;
      expect(SortOption.none.sortOrder, equals(SortOrder.ascending));
    });

    test('should return _NoSort from copyWith', () {
      final copy = SortOption.none.copyWith(id: 'test');
      expect(copy.id, equals(''));
    });

    test('should have correct toString', () {
      expect(SortOption.none.toString(), equals('SortOption.none'));
    });
  });

  group('SortManager', () {
    late SortManager<User> manager;
    late SortOption<User, String> nameSort;
    late SortOption<User, int?> ageSort;
    late SortOption<User, DateTime?> dateSort;

    setUp(() {
      nameSort = SortOption<User, String>(
        id: 'name',
        label: 'Name',
        sortIdentifier: (user) => user.name,
      );
      ageSort = SortOption<User, int?>(
        id: 'age',
        label: 'Age',
        sortIdentifier: (user) => user.age,
      );
      dateSort = SortOption<User, DateTime?>(
        id: 'date',
        label: 'Join Date',
        sortIdentifier: (user) => user.joinDate,
      );
      manager = SortManager<User>();
    });

    group('constructor', () {
      test('should create empty manager', () {
        final mgr = SortManager<User>();

        expect(mgr.length, equals(0));
        expect(mgr.isEmpty, isTrue);
      });

      test('should create manager with initial options', () {
        final mgr = SortManager<User>(
          options: [nameSort, ageSort, dateSort],
        );

        expect(mgr.length, equals(3));
        expect(mgr['name'], equals(nameSort));
      });

      test('should set current option by index', () {
        final mgr = SortManager<User>(
          options: [nameSort, ageSort, dateSort],
          currentOptionIndex: 1,
        );

        expect(mgr.current?.id, equals('age'));
        expect(mgr.activeSortCount, equals(1));
      });

      test('should use triState setting', () {
        final mgr = SortManager<User>(triState: false);
        expect(mgr.triState, isFalse);
      });

      test('should call onSortChanged callback', () {
        SortOption<User, dynamic>? changedOption;
        final mgr = SortManager<User>(
          options: [nameSort],
          onSortChanged: (opt) => changedOption = opt,
        );

        mgr.toggleOrder();

        expect(changedOption, equals(nameSort));
      });
    });

    group('allOptions getter', () {
      test('should return all registered options', () {
        manager.add(nameSort);
        manager.add(ageSort);

        final options = manager.allOptions;

        expect(options, hasLength(2));
        expect(options, contains(nameSort));
        expect(options, contains(ageSort));
      });
    });

    group('activeSorts getter', () {
      test('should return unmodifiable list', () {
        manager.add(nameSort);
        manager.setCurrent(nameSort);

        final active = manager.activeSorts;

        expect(() => active.add(ageSort), throwsUnsupportedError);
      });

      test('should maintain order of active sorts', () {
        manager.add(nameSort);
        manager.add(ageSort);
        manager.setCurrent(nameSort);
        manager.add(ageSort);

        final active = manager.activeSorts;

        expect(active[0].id, equals('name'));
        expect(active[1].id, equals('age'));
      });
    });

    group('isEmpty/isNotEmpty', () {
      test('should return correct values based on active sorts', () {
        expect(manager.isEmpty, isTrue);
        expect(manager.isNotEmpty, isFalse);

        manager.add(nameSort);
        manager.setCurrent(nameSort);

        expect(manager.isEmpty, isFalse);
        expect(manager.isNotEmpty, isTrue);
      });
    });

    group('operator []', () {
      test('should return option by id', () {
        manager.add(nameSort);

        expect(manager['name'], equals(nameSort));
        expect(manager['nonexistent'], isNull);
      });
    });

    group('getOptionById', () {
      test('should return option by id', () {
        manager.add(nameSort);

        expect(manager.getOptionById('name'), equals(nameSort));
        expect(manager.getOptionById('nonexistent'), isNull);
      });
    });

    group('getOption<V>', () {
      test('should return typed option', () {
        manager.add(nameSort);

        final opt = manager.getOption<String>('name');

        expect(opt, equals(nameSort));
      });
    });

    group('current getter', () {
      test('should return first active sort', () {
        manager.add(nameSort);
        manager.add(ageSort);
        manager.setCurrent(nameSort);
        manager.add(ageSort);

        expect(manager.current, equals(nameSort));
      });

      test('should return first option when no active sorts', () {
        manager.add(nameSort);
        manager.add(ageSort);

        expect(manager.current, equals(nameSort));
      });

      test('should return null when no options', () {
        expect(manager.current, isNull);
      });
    });

    group('currentOrder getter', () {
      test('should return current sort order', () {
        manager.add(nameSort);

        expect(manager.currentOrder, equals(SortOrder.ascending));

        nameSort.sortOrder = SortOrder.descending;
        expect(manager.currentOrder, equals(SortOrder.descending));
      });

      test('should return ascending when no current', () {
        expect(manager.currentOrder, equals(SortOrder.ascending));
      });
    });

    group('add', () {
      test('should add option and return true', () {
        final result = manager.add(nameSort);

        expect(result, isTrue);
        expect(manager.length, equals(1));
        expect(manager['name'], equals(nameSort));
      });

      test('should update existing option in chain', () {
        manager.add(nameSort);

        // Adding same option again updates it (no duplicate)
        final result = manager.add(nameSort, order: SortOrder.descending);

        expect(result, isTrue);
        expect(manager.activeSortCount, equals(1));
        expect(nameSort.sortOrder, equals(SortOrder.descending));
      });

      test('should append to chain when adding different option', () {
        manager.add(nameSort);
        manager.add(ageSort);

        expect(manager.activeSortCount, equals(2));
        expect(manager.activeSorts[0].id, equals('name'));
        expect(manager.activeSorts[1].id, equals('age'));
      });

      test('should reset chain when reset is true', () {
        manager.add(nameSort);
        manager.add(ageSort);

        manager.add(dateSort, reset: true);

        expect(manager.activeSortCount, equals(1));
        expect(manager.activeSorts[0].id, equals('date'));
      });

      test('should toggle when adding same option with reset', () {
        manager.add(nameSort);
        expect(nameSort.sortOrder, equals(SortOrder.ascending));

        manager.add(nameSort, reset: true);
        expect(nameSort.sortOrder, equals(SortOrder.descending));

        manager.add(nameSort, reset: true);
        expect(nameSort.sortOrder, equals(SortOrder.none));
      });

      test('should notify listeners', () {
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.add(nameSort);

        expect(notified, isTrue);
      });
    });

    group('addAll', () {
      test('should add multiple options', () {
        manager.addAll([nameSort, ageSort, dateSort]);

        expect(manager.length, equals(3));
      });

      test('should notify once after adding all', () {
        var notificationCount = 0;
        manager.addChangeListener(() => notificationCount++);

        manager.addAll([nameSort, ageSort]);

        expect(notificationCount, equals(1));
      });

      test('should not notify when silent is true', () {
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.addAll([nameSort, ageSort], silent: true);

        expect(notified, isFalse);
      });

      test('should handle null options', () {
        manager.addAll(null);

        expect(manager.length, equals(0));
      });

      test('should preserve sort order for existing current option', () {
        manager.add(nameSort);
        manager.setCurrent(nameSort);
        nameSort.sortOrder = SortOrder.descending;

        final newNameSort = SortOption<User, String>(
          id: 'name',
          sortIdentifier: (user) => user.name,
        );
        manager.addAll([newNameSort]);

        expect(newNameSort.sortOrder, equals(SortOrder.descending));
      });
    });

    group('remove', () {
      test('should remove option and return it', () {
        manager.add(nameSort);
        final removed = manager.remove('name');

        expect(removed, equals(nameSort));
        expect(manager.length, equals(0));
      });

      test('should return null when option not found', () {
        final removed = manager.remove('nonexistent');

        expect(removed, isNull);
      });

      test('should remove from active sorts', () {
        manager.add(nameSort);
        manager.setCurrent(nameSort);

        manager.remove('name');

        expect(manager.activeSortCount, equals(0));
      });

      test('should notify listeners when removed', () {
        var notified = false;
        manager.add(nameSort);
        manager.addChangeListener(() => notified = true);

        manager.remove('name');

        expect(notified, isTrue);
      });

      test('should not notify when option not found', () {
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.remove('nonexistent');

        expect(notified, isFalse);
      });
    });

    group('removeAll', () {
      test('should remove multiple options', () {
        manager.addAll([nameSort, ageSort, dateSort]);

        manager.removeAll([nameSort, ageSort]);

        expect(manager.length, equals(1));
        expect(manager['date'], equals(dateSort));
      });

      test('should call onSortChanged when removing current', () {
        SortOption<User, dynamic>? changedOption = nameSort;
        final mgr = SortManager<User>(
          onSortChanged: (opt) => changedOption = opt,
        );
        mgr.add(nameSort);
        mgr.setCurrent(nameSort);

        mgr.removeAll([nameSort]);

        expect(changedOption, isNull);
      });

      test('should not notify when silent is true', () {
        var notified = false;
        manager.addAll([nameSort, ageSort]);
        manager.addChangeListener(() => notified = true);

        manager.removeAll([nameSort], silent: true);

        expect(notified, isFalse);
      });
    });

    group('clear', () {
      test('should remove all options and notify', () {
        manager.addAll([nameSort, ageSort, dateSort]);

        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.clear();

        expect(manager.length, equals(0));
        expect(manager.allOptions, isEmpty);
        expect(notified, isTrue);
      });

      test('should clear active sorts', () {
        manager.addAll([nameSort, ageSort]);
        manager.setCurrent(nameSort);
        manager.add(ageSort);

        manager.clear();

        expect(manager.activeSortCount, equals(0));
        expect(manager.isEmpty, isTrue);
      });

      test('should do nothing when already empty', () {
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.clear();

        expect(notified, isFalse);
      });

      test('should call onSortChanged with null', () {
        SortOption<User, dynamic>? changedOption = nameSort;
        final mgr = SortManager<User>(
          onSortChanged: (opt) => changedOption = opt,
        );
        mgr.add(nameSort);
        mgr.setCurrent(nameSort);

        mgr.clear();

        expect(changedOption, isNull);
      });
    });

    group('setCurrent', () {
      test('should set option as primary sort', () {
        manager.add(nameSort);
        manager.setCurrent(nameSort);

        expect(manager.current, equals(nameSort));
        expect(manager.activeSortCount, equals(1));
      });

      test('should clear existing sorts and add new one', () {
        manager.add(nameSort);
        manager.add(ageSort);
        manager.setCurrent(nameSort);
        manager.add(ageSort);

        manager.setCurrent(dateSort);

        expect(manager.activeSortCount, equals(1));
        expect(manager.current?.id, equals('date'));
      });

      test('should toggle order when setting same option', () {
        // First setCurrent adds and sets as primary (ascending)
        manager.setCurrent(nameSort);
        expect(nameSort.sortOrder, equals(SortOrder.ascending));

        // Second setCurrent toggles to descending
        manager.setCurrent(nameSort);
        expect(nameSort.sortOrder, equals(SortOrder.descending));

        // Third setCurrent toggles to none
        manager.setCurrent(nameSort);
        expect(nameSort.sortOrder, equals(SortOrder.none));
      });

      test('should use triState parameter for toggling', () {
        // First setCurrent adds and sets as primary (ascending)
        manager.setCurrent(nameSort);
        expect(nameSort.sortOrder, equals(SortOrder.ascending));

        // Toggle with triState: false (two-state toggle)
        manager.setCurrent(nameSort, triState: false);
        expect(nameSort.sortOrder, equals(SortOrder.descending));

        // Toggle again with triState: false
        manager.setCurrent(nameSort, triState: false);
        expect(nameSort.sortOrder, equals(SortOrder.ascending));
      });

      test('should not notify when silent is true', () {
        var notified = false;
        // First add the option (this will notify)
        manager.setCurrent(nameSort);
        // Now add listener
        manager.addChangeListener(() => notified = true);

        // Toggle with silent: true should not notify
        manager.setCurrent(nameSort, silent: true);

        expect(notified, isFalse);
      });

      test('should do nothing when option is null', () {
        manager.setCurrent(null);

        expect(manager.activeSortCount, equals(0));
      });

      test('should add option to registry if not present', () {
        manager.setCurrent(nameSort);

        expect(manager['name'], equals(nameSort));
      });

      test('should call onSortChanged callback', () {
        SortOption<User, dynamic>? changedOption;
        final mgr = SortManager<User>(
          onSortChanged: (opt) => changedOption = opt,
        );

        mgr.setCurrent(nameSort);

        expect(changedOption, equals(nameSort));
      });
    });

    group('setCurrentById', () {
      test('should set current by id', () {
        manager.add(nameSort);
        manager.add(ageSort);

        manager.setCurrentById('age');

        expect(manager.current?.id, equals('age'));
      });

      test('should do nothing when id not found', () {
        manager.add(nameSort);
        manager.setCurrent(nameSort);

        manager.setCurrentById('nonexistent');

        expect(manager.current?.id, equals('name'));
      });
    });

    group('add to chain', () {
      test('should add option to sort chain', () {
        manager.setCurrent(nameSort);
        manager.add(ageSort);

        expect(manager.activeSortCount, equals(2));
        expect(manager.activeSorts[1].id, equals('age'));
      });

      test('should set order for added option', () {
        manager.setCurrent(nameSort);
        manager.add(ageSort, order: SortOrder.descending);

        expect(ageSort.sortOrder, equals(SortOrder.descending));
      });

      test('should update order when option already in chain', () {
        manager.setCurrent(nameSort);
        manager.add(ageSort);

        expect(ageSort.sortOrder, equals(SortOrder.ascending));

        manager.add(ageSort, order: SortOrder.descending);

        expect(manager.activeSortCount, equals(2));
        expect(ageSort.sortOrder, equals(SortOrder.descending));
      });

      test('should add option to registry if not present', () {
        manager.setCurrent(nameSort);
        manager.add(ageSort);

        expect(manager['age'], equals(ageSort));
      });

      test('should call onSortChanged callback', () {
        SortOption<User, dynamic>? changedOption;
        final mgr = SortManager<User>(
          onSortChanged: (opt) => changedOption = opt,
        );
        mgr.setCurrent(nameSort);

        mgr.add(ageSort);

        expect(changedOption, equals(ageSort));
      });

      test('should notify listeners', () {
        var notified = false;
        manager.setCurrent(nameSort, silent: true);
        manager.addChangeListener(() => notified = true);

        manager.add(ageSort);

        expect(notified, isTrue);
      });
    });

    group('removeFromChain', () {
      test('should remove option from active chain', () {
        manager.setCurrent(nameSort);
        manager.add(ageSort);
        manager.add(dateSort);

        manager.removeFromChain('age');

        expect(manager.activeSortCount, equals(2));
        expect(manager.activeSorts.map((o) => o.id), equals(['name', 'date']));
      });

      test('should do nothing when option not in chain', () {
        manager.setCurrent(nameSort);

        manager.removeFromChain('nonexistent');

        expect(manager.activeSortCount, equals(1));
      });

      test('should call onSortChanged callback', () {
        SortOption<User, dynamic>? changedOption;
        final mgr = SortManager<User>(
          onSortChanged: (opt) => changedOption = opt,
        );
        mgr.setCurrent(nameSort);
        mgr.add(ageSort);

        mgr.removeFromChain('age');

        expect(changedOption, equals(nameSort));
      });

      test('should notify listeners', () {
        var notified = false;
        manager.setCurrent(nameSort, silent: true);
        manager.add(ageSort);
        manager.addChangeListener(() => notified = true);

        manager.removeFromChain('age');

        expect(notified, isTrue);
      });
    });

    group('clearSorts', () {
      test('should clear all active sorts', () {
        manager.setCurrent(nameSort);
        manager.add(ageSort);

        manager.clearSorts();

        expect(manager.activeSortCount, equals(0));
        expect(manager.isEmpty, isTrue);
      });

      test('should do nothing when already empty', () {
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.clearSorts();

        expect(notified, isFalse);
      });

      test('should call onSortChanged with null', () {
        SortOption<User, dynamic>? changedOption = nameSort;
        final mgr = SortManager<User>(
          onSortChanged: (opt) => changedOption = opt,
        );
        mgr.setCurrent(nameSort);

        mgr.clearSorts();

        expect(changedOption, isNull);
      });
    });

    group('setSortOrder', () {
      test('should set order for primary sort', () {
        manager.setCurrent(nameSort);

        manager.setSortOrder(SortOrder.descending);

        expect(nameSort.sortOrder, equals(SortOrder.descending));
      });

      test('should do nothing when no active sort', () {
        manager.setSortOrder(SortOrder.descending);

        expect(manager.currentOrder, equals(SortOrder.ascending));
      });

      test('should do nothing when order unchanged', () {
        var notified = false;
        manager.setCurrent(nameSort);
        manager.addChangeListener(() => notified = true);

        manager.setSortOrder(SortOrder.ascending);

        expect(notified, isFalse);
      });
    });

    group('toggleOrder', () {
      test('should toggle primary sort order', () {
        manager.setCurrent(nameSort);

        manager.toggleOrder();
        expect(nameSort.sortOrder, equals(SortOrder.descending));

        manager.toggleOrder();
        expect(nameSort.sortOrder, equals(SortOrder.none));
      });

      test('should use manager triState setting by default', () {
        final mgr = SortManager<User>(triState: false);
        mgr.setCurrent(nameSort);

        mgr.toggleOrder();
        expect(nameSort.sortOrder, equals(SortOrder.descending));

        mgr.toggleOrder();
        expect(nameSort.sortOrder, equals(SortOrder.ascending));
      });

      test('should use provided triState parameter', () {
        manager.setCurrent(nameSort);

        manager.toggleOrder(triState: false);
        expect(nameSort.sortOrder, equals(SortOrder.descending));

        manager.toggleOrder(triState: false);
        expect(nameSort.sortOrder, equals(SortOrder.ascending));
      });

      test('should do nothing when no active sort', () {
        manager.toggleOrder();

        expect(manager.currentOrder, equals(SortOrder.ascending));
      });
    });

    group('compare', () {
      const alice = User(id: '1', name: 'Alice', age: 30, priority: 5);
      const bob = User(id: '2', name: 'Bob', age: 25, priority: 10);
      const charlie = User(id: '3', name: 'Alice', age: 25, priority: 5);

      test('should return 0 when no active sorts', () {
        expect(manager.compare(alice, bob), equals(0));
      });

      test('should compare using primary sort', () {
        manager.setCurrent(nameSort);

        expect(manager.compare(alice, bob), lessThan(0));
        expect(manager.compare(bob, alice), greaterThan(0));
      });

      test('should apply sorts in chain order', () {
        manager.setCurrent(nameSort);
        manager.add(ageSort);

        expect(manager.compare(alice, charlie), greaterThan(0));
        expect(manager.compare(charlie, alice), lessThan(0));
      });

      test('should sort list correctly', () {
        manager.setCurrent(nameSort);
        manager.add(ageSort);

        final users = [bob, alice, charlie];
        users.sort(manager.compare);

        expect(users, equals([charlie, alice, bob]));
      });

      test('should stop at first non-zero result', () {
        manager.setCurrent(nameSort);
        manager.add(ageSort);

        expect(manager.compare(alice, bob), lessThan(0));
      });
    });

    group('comparator getter', () {
      test('should return compare function', () {
        manager.setCurrent(nameSort);

        final comparator = manager.comparator;
        const alice = User(id: '1', name: 'Alice');
        const bob = User(id: '2', name: 'Bob');

        expect(comparator(alice, bob), lessThan(0));
      });
    });

    group('sortString', () {
      test('should return combined sort string', () {
        manager.setCurrent(nameSort);
        manager.add(ageSort, order: SortOrder.descending);

        expect(manager.sortString, equals('name:asc,age:desc'));
      });

      test('should return empty string when no active sorts', () {
        expect(manager.sortString, equals(''));
      });

      test('should skip options with none sort order', () {
        manager.setCurrent(nameSort);
        manager.add(ageSort);
        ageSort.sortOrder = SortOrder.none;

        expect(manager.sortString, equals('name:asc'));
      });
    });

    group('listener management', () {
      test('should notify when option changes', () {
        var notified = false;
        manager.setCurrent(nameSort);
        manager.addChangeListener(() => notified = true);

        nameSort.sortOrder = SortOrder.descending;

        expect(notified, isTrue);
      });

      test('should stop listening after removing from chain', () {
        var notified = false;
        manager.setCurrent(nameSort);
        manager.removeFromChain('name');
        manager.addChangeListener(() => notified = true);

        nameSort.sortOrder = SortOrder.descending;

        expect(notified, isFalse);
      });

      test('should handle re-adding same option', () {
        var notificationCount = 0;
        manager.addChangeListener(() => notificationCount++);

        manager.setCurrent(nameSort);
        manager.clearSorts();
        manager.setCurrent(nameSort);

        notificationCount = 0;
        nameSort.sortOrder = SortOrder.descending;

        expect(notificationCount, equals(1));
      });

      test('should not accumulate listeners when replacing option', () {
        var notificationCount = 0;
        manager.addChangeListener(() => notificationCount++);

        manager.setCurrent(nameSort);
        manager.setCurrent(ageSort);
        manager.setCurrent(nameSort);

        notificationCount = 0;
        nameSort.sortOrder = SortOrder.descending;

        expect(notificationCount, equals(1));
      });

      test('should update sort order when adding existing option via add', () {
        manager.setCurrent(nameSort);
        manager.add(ageSort);

        // Re-adding nameSort should update its order, not add duplicate
        manager.add(nameSort, order: SortOrder.descending);

        expect(manager.activeSortCount, equals(2));
        expect(nameSort.sortOrder, equals(SortOrder.descending));
      });
    });

    group('dispose', () {
      test('should clear active sorts', () {
        manager.setCurrent(nameSort);
        manager.add(ageSort);

        manager.dispose();

        expect(manager.activeSortCount, equals(0));
      });

      test('should clear options', () {
        manager.add(nameSort);
        manager.add(ageSort);

        manager.dispose();

        expect(manager.length, equals(0));
      });

      test('should stop listening to options', () {
        var notified = false;
        manager.setCurrent(nameSort);
        manager.addChangeListener(() => notified = true);

        manager.dispose();
        nameSort.sortOrder = SortOrder.descending;

        expect(notified, isFalse);
      });
    });

    group('toString', () {
      test('should return string representation', () {
        manager.add(nameSort);
        manager.add(ageSort);

        final str = manager.toString();

        // 2 options, 2 active
        expect(str, contains('options: 2'));
        expect(str, contains('active: 2'));
      });
    });
  });

  group('case-insensitive string comparison', () {
    test('should compare strings case-insensitively', () {
      final sort = SortOption<User, String>(
        id: 'name',
        sortIdentifier: (user) => user.name,
      );

      const alice = User(id: '1', name: 'alice');
      const bob = User(id: '2', name: 'Bob');
      const alice2 = User(id: '3', name: 'ALICE');

      expect(sort.compare(alice, bob), lessThan(0));
      expect(sort.compare(alice, alice2), equals(0));
    });
  });

  group('non-Comparable value comparison', () {
    test('should compare non-Comparable values using toString', () {
      // Use a sort option that returns non-Comparable values
      final sort = SortOption<_TestItem, Object>(
        id: 'nonComparable',
        sortIdentifier: (item) => item.nonComparableValue,
      );

      final itemA = _TestItem(_NonComparable('AAA'));
      final itemB = _TestItem(_NonComparable('BBB'));

      // Should compare using toString
      expect(sort.compare(itemA, itemB), lessThan(0));
      expect(sort.compare(itemB, itemA), greaterThan(0));
    });
  });

  group('type aliases', () {
    test('SortByString should work', () {
      final sort = SortByString<User>(
        id: 'name',
        sortIdentifier: (user) => user.name,
      );

      expect(sort, isA<SortOption<User, String>>());
    });

    test('SortByInt should work', () {
      final sort = SortByInt<User>(
        id: 'priority',
        sortIdentifier: (user) => user.priority,
      );

      expect(sort, isA<SortOption<User, int>>());
    });

    test('SortByDate should work', () {
      final sort = SortByDate<User>(
        id: 'date',
        sortIdentifier: (user) => user.joinDate,
      );

      expect(sort, isA<SortOption<User, DateTime>>());
    });
  });

  group('Listenable integration', () {
    test('SortOption should have hasListeners', () {
      final sort = SortOption<User, String>(
        id: 'name',
        sortIdentifier: (user) => user.name,
      );

      expect(sort.hasListeners, isFalse);

      sort.addChangeListener(() {});
      expect(sort.hasListeners, isTrue);
    });

    test('SortManager should have hasListeners', () {
      final manager = SortManager<User>();

      expect(manager.hasListeners, isFalse);

      manager.addChangeListener(() {});
      expect(manager.hasListeners, isTrue);
    });
  });

  group('SortOption source properties', () {
    test('isRemote should return true for remote source', () {
      final sort = SortOption<User, String>(
        id: 'name',
        sortIdentifier: (user) => user.name,
        source: TransformSource.remote,
      );

      expect(sort.isRemote, isTrue);
      expect(sort.isLocal, isFalse);
    });

    test('isRemote should return true for combined source', () {
      final sort = SortOption<User, String>(
        id: 'name',
        sortIdentifier: (user) => user.name,
        source: TransformSource.combined,
      );

      expect(sort.isRemote, isTrue);
      expect(sort.isLocal, isTrue);
    });

    test('isLocal should return true for local source', () {
      final sort = SortOption<User, String>(
        id: 'name',
        sortIdentifier: (user) => user.name,
      );

      expect(sort.isRemote, isFalse);
      expect(sort.isLocal, isTrue);
    });
  });

  group('ValueSortOption copyWith sortIdentifier', () {
    test('should create copy with new sortIdentifier', () {
      final original = ValueSortOption<User, String>(
        id: 'name',
        sortIdentifier: (user) => user.name,
      );

      final copy = original.copyWith(
        sortIdentifier: (user) => user.id,
      );

      const alice = User(id: 'a', name: 'Zoe');
      const bob = User(id: 'b', name: 'Alice');

      // Original sorts by name
      expect(original.compare(alice, bob), greaterThan(0));
      // Copy sorts by id
      expect(copy.compare(alice, bob), lessThan(0));
    });
  });

  group('ComparableSortOption copyWith', () {
    test('should create copy with new comparables function', () {
      final original = ComparableSortOption<User>(
        id: 'full',
        comparables: (user) => [user.name],
      );

      final copy = original.copyWith(
        comparables: (user) => [user.id],
      );

      const alice = User(id: 'z', name: 'Alice');
      const bob = User(id: 'a', name: 'Bob');

      // Original sorts by name
      expect(original.compare(alice, bob), lessThan(0));
      // Copy sorts by id
      expect(copy.compare(alice, bob), greaterThan(0));
    });
  });

  group('ComparatorSortOption', () {
    test('should create with all parameters', () {
      final sort = ComparatorSortOption<User>(
        id: 'priority',
        label: 'Priority',
        comparator: (a, b) => a.priority.compareTo(b.priority),
        sortOrder: SortOrder.descending,
        enabled: false,
        secondaryId: 'name',
        secondarySortOrder: SortOrder.ascending,
        secondaryComparator: (a, b) => a.name.compareTo(b.name),
      );

      expect(sort.id, equals('priority'));
      expect(sort.label, equals('Priority'));
      expect(sort.sortOrder, equals(SortOrder.descending));
      expect(sort.enabled, isFalse);
      expect(sort.secondaryId, equals('name'));
      expect(sort.secondarySortOrder, equals(SortOrder.ascending));
      expect(sort.hasSecondary, isTrue);
    });

    test('sortString should include both when secondary is present', () {
      final sort = ComparatorSortOption<User>(
        id: 'priority',
        comparator: (a, b) => a.priority.compareTo(b.priority),
        sortOrder: SortOrder.descending,
        secondaryId: 'name',
        secondarySortOrder: SortOrder.ascending,
        secondaryComparator: (a, b) => a.name.compareTo(b.name),
      );

      expect(sort.sortString, equals('priority:desc,name:asc'));
    });

    test('sortString should handle none primary with valid secondary', () {
      final sort = ComparatorSortOption<User>(
        id: 'priority',
        comparator: (a, b) => a.priority.compareTo(b.priority),
        sortOrder: SortOrder.none,
        secondaryId: 'name',
        secondarySortOrder: SortOrder.ascending,
        secondaryComparator: (a, b) => a.name.compareTo(b.name),
      );

      expect(sort.sortString, equals('name:asc'));
    });

    group('copyWith', () {
      test('should copy all fields', () {
        final original = ComparatorSortOption<User>(
          id: 'priority',
          comparator: (a, b) => a.priority.compareTo(b.priority),
          secondaryId: 'name',
          secondaryComparator: (a, b) => a.name.compareTo(b.name),
        );

        final copy = original.copyWith(
          id: 'new_id',
          label: 'New Label',
          sortOrder: SortOrder.descending,
          source: TransformSource.remote,
          enabled: false,
          secondaryId: 'new_secondary',
          secondarySortOrder: SortOrder.descending,
        ) as ComparatorSortOption<User>;

        expect(copy.id, equals('new_id'));
        expect(copy.label, equals('New Label'));
        expect(copy.sortOrder, equals(SortOrder.descending));
        expect(copy.source, equals(TransformSource.remote));
        expect(copy.enabled, isFalse);
        expect(copy.secondaryId, equals('new_secondary'));
        expect(copy.secondarySortOrder, equals(SortOrder.descending));
      });

      test('should copy comparator functions', () {
        final original = ComparatorSortOption<User>(
          id: 'priority',
          comparator: (a, b) => a.priority.compareTo(b.priority),
        );

        int newComparator(User a, User b) => a.name.compareTo(b.name);
        int newSecondary(User a, User b) => a.id.compareTo(b.id);

        final copy = original.copyWith(
          comparator: newComparator,
          secondaryComparator: newSecondary,
        );

        const alice = User(id: 'b', name: 'Alice', priority: 2);
        const bob = User(id: 'a', name: 'Bob', priority: 1);

        // Original compares by priority
        expect(original.compare(alice, bob), greaterThan(0));
        // Copy compares by name
        expect(copy.compare(alice, bob), lessThan(0));
      });
    });
  });

  group('CustomSortOption copyWith with values', () {
    test('should create copy with new values list', () {
      final originalValues = [
        SortValue<User>(id: 'name', value: (u) => u.name),
      ];
      final original = CustomSortOption<User>(
        id: 'custom',
        values: originalValues,
      );

      final newValues = [
        SortValue<User>(id: 'id', value: (u) => u.id),
        SortValue<User>(id: 'priority', value: (u) => u.priority),
      ];
      final copy =
          original.copyWith(values: newValues) as CustomSortOption<User>;

      expect(copy.values.length, equals(2));
      expect(copy.values[0].id, equals('id'));
    });

    test('should create copy with new initialIndex', () {
      final values = [
        SortValue<User>(id: 'name', value: (u) => u.name),
        SortValue<User>(id: 'id', value: (u) => u.id),
      ];
      final original = CustomSortOption<User>(
        id: 'custom',
        values: values,
      );

      final copy = original.copyWith(initialIndex: 1) as CustomSortOption<User>;

      expect(copy.current?.id, equals('id'));
    });
  });

  group('SortManager remoteSorts and localSorts', () {
    test('remoteSorts should return only remote sorts', () {
      final localSort = SortOption<User, String>(
        id: 'local',
        sortIdentifier: (u) => u.name,
      );
      final remoteSort = SortOption<User, String>(
        id: 'remote',
        sortIdentifier: (u) => u.id,
        source: TransformSource.remote,
      );
      final combinedSort = SortOption<User, int>(
        id: 'combined',
        sortIdentifier: (u) => u.priority,
        source: TransformSource.combined,
      );

      final manager = SortManager<User>();
      manager.add(localSort);
      manager.add(remoteSort);
      manager.add(combinedSort);

      final remoteSorts = manager.remoteSorts;

      expect(remoteSorts.length, equals(2));
      expect(remoteSorts.any((s) => s.id == 'remote'), isTrue);
      expect(remoteSorts.any((s) => s.id == 'combined'), isTrue);
      expect(remoteSorts.any((s) => s.id == 'local'), isFalse);
    });

    test('localSorts should return only local sorts', () {
      final localSort = SortOption<User, String>(
        id: 'local',
        sortIdentifier: (u) => u.name,
      );
      final remoteSort = SortOption<User, String>(
        id: 'remote',
        sortIdentifier: (u) => u.id,
        source: TransformSource.remote,
      );
      final combinedSort = SortOption<User, int>(
        id: 'combined',
        sortIdentifier: (u) => u.priority,
        source: TransformSource.combined,
      );

      final manager = SortManager<User>();
      manager.add(localSort);
      manager.add(remoteSort);
      manager.add(combinedSort);

      final localSorts = manager.localSorts;

      expect(localSorts.length, equals(2));
      expect(localSorts.any((s) => s.id == 'local'), isTrue);
      expect(localSorts.any((s) => s.id == 'combined'), isTrue);
      expect(localSorts.any((s) => s.id == 'remote'), isFalse);
    });
  });

  group('SortManager.sort method', () {
    late SortManager<User> manager;
    late SortOption<User, String> nameSort;
    late SortOption<User, int> prioritySort;

    setUp(() {
      nameSort = SortOption<User, String>(
        id: 'name',
        sortIdentifier: (u) => u.name,
      );
      prioritySort = SortOption<User, int>(
        id: 'priority',
        sortIdentifier: (u) => u.priority,
      );
      manager = SortManager<User>();
    });

    test('should return original list when no active sorts', () {
      final users = [
        const User(id: '1', name: 'Bob'),
        const User(id: '2', name: 'Alice'),
      ];

      final result = manager.sort(users);

      expect(result, same(users));
    });

    test('should return original list when less than 2 items', () {
      manager.add(nameSort);
      final users = [const User(id: '1', name: 'Alice')];

      final result = manager.sort(users);

      expect(result, same(users));
    });

    test('should return original list for empty list', () {
      manager.add(nameSort);
      final users = <User>[];

      final result = manager.sort(users);

      expect(result, same(users));
    });

    test('should sort small list using simple sort', () {
      manager.add(nameSort);
      final users = [
        const User(id: '1', name: 'Charlie'),
        const User(id: '2', name: 'Alice'),
        const User(id: '3', name: 'Bob'),
      ];

      final result = manager.sort(users);

      expect(result[0].name, equals('Alice'));
      expect(result[1].name, equals('Bob'));
      expect(result[2].name, equals('Charlie'));
    });

    test('should sort with multiple sort options', () {
      manager.add(prioritySort);
      manager.add(nameSort);

      final users = [
        const User(id: '1', name: 'Bob', priority: 1),
        const User(id: '2', name: 'Alice', priority: 1),
        const User(id: '3', name: 'Charlie', priority: 2),
      ];

      final result = manager.sort(users);

      // First by priority (ascending), then by name
      expect(result[0].name, equals('Alice'));
      expect(result[1].name, equals('Bob'));
      expect(result[2].name, equals('Charlie'));
    });

    test('should skip remote-only sorts', () {
      final remoteSort = SortOption<User, String>(
        id: 'remote',
        sortIdentifier: (u) => u.id,
        source: TransformSource.remote,
      );
      manager.add(remoteSort);

      final users = [
        const User(id: '2', name: 'Bob'),
        const User(id: '1', name: 'Alice'),
      ];

      final result = manager.sort(users);

      // Should return original since only sort is remote
      expect(result, same(users));
    });

    test('should use Schwartzian transform for large lists', () {
      manager.add(nameSort);

      // Create a list larger than the threshold (1000)
      // Use padded numbers for correct alphabetical sorting
      final users = List.generate(
        1100,
        (i) => User(
          id: '$i',
          name: 'User${(1100 - i).toString().padLeft(4, '0')}',
        ),
      );

      final result = manager.sort(users);

      // Verify sorted correctly (alphabetically)
      expect(result[0].name, equals('User0001'));
      expect(result[1099].name, equals('User1100'));
    });

    test('should handle CustomSortOption in Schwartzian sort', () {
      final customSort = CustomSortOption<User>(
        id: 'custom',
        values: [
          SortValue<User>(id: 'name', value: (u) => u.name),
        ],
      );
      manager.add(customSort);

      // Create a list larger than the threshold with padded names
      final users = List.generate(
        1100,
        (i) => User(
          id: '$i',
          name: 'User${(1100 - i).toString().padLeft(4, '0')}',
        ),
      );

      final result = manager.sort(users);

      expect(result[0].name, equals('User0001'));
    });

    test('should handle ComparatorSortOption in Schwartzian sort', () {
      final comparatorSort = ComparatorSortOption<User>(
        id: 'comparator',
        comparator: (a, b) => a.name.compareTo(b.name),
      );
      manager.add(comparatorSort);

      // Create a list larger than the threshold with padded names
      final users = List.generate(
        1100,
        (i) => User(
          id: '$i',
          name: 'User${(1100 - i).toString().padLeft(4, '0')}',
        ),
      );

      final result = manager.sort(users);

      // ComparatorSortOption returns null key, falls back to full compare
      expect(result[0].name, equals('User0001'));
    });

    test('should handle null values in sort key extraction', () {
      final ageSort = SortOption<User, int?>(
        id: 'age',
        sortIdentifier: (u) => u.age,
      );
      manager.add(ageSort);

      // Create a large list with some null ages
      final users = List.generate(1100, (i) {
        return User(
          id: '$i',
          name: 'User$i',
          age: i % 3 == 0 ? null : i,
        );
      });

      final result = manager.sort(users);

      // Null values should come first (ascending)
      expect(result[0].age, isNull);
    });

    test('should handle descending order in Schwartzian sort', () {
      nameSort.sortOrder = SortOrder.descending;
      manager.add(nameSort);

      final users = List.generate(
        1100,
        (i) => User(id: '$i', name: 'User${i.toString().padLeft(4, '0')}'),
      );

      final result = manager.sort(users);

      // Descending order
      expect(result[0].name, equals('User1099'));
      expect(result[1099].name, equals('User0000'));
    });

    test('should handle equal primary keys with secondary sort', () {
      manager.add(prioritySort);
      manager.add(nameSort);

      // Create a large list with same priority and padded names
      final users = List.generate(1100, (i) {
        return User(
          id: '$i',
          name: 'User${(1100 - i).toString().padLeft(4, '0')}',
          priority: 1, // All same priority
        );
      });

      final result = manager.sort(users);

      // Should fall back to name sort
      expect(result[0].name, equals('User0001'));
    });
  });

  group('SortManager.add silent parameter', () {
    test('should not notify when adding new option with silent true', () {
      final manager = SortManager<User>();
      final nameSort = SortOption<User, String>(
        id: 'name',
        sortIdentifier: (u) => u.name,
      );

      var notified = false;
      manager.addChangeListener(() => notified = true);

      manager.add(nameSort, silent: true);

      expect(notified, isFalse);
      expect(manager.activeSortCount, equals(1));
    });
  });

  group('SortManager constructor with onSortChanged', () {
    test('should call onSortChanged when sort changes after construction', () {
      SortOption<User, dynamic>? changedOption;
      final nameSort = SortOption<User, String>(
        id: 'name',
        sortIdentifier: (u) => u.name,
      );
      final ageSort = SortOption<User, int>(
        id: 'age',
        sortIdentifier: (u) => u.priority,
      );

      final manager = SortManager<User>(
        options: [nameSort, ageSort],
        onSortChanged: (opt) => changedOption = opt,
      );

      // Constructor uses silent: true, so callback not called yet
      expect(changedOption, isNull);

      // Now trigger a change
      manager.setCurrent(ageSort);
      expect(changedOption, equals(ageSort));
    });

    test('should not set current when index out of range', () {
      final nameSort = SortOption<User, String>(
        id: 'name',
        sortIdentifier: (u) => u.name,
      );

      final manager = SortManager<User>(
        options: [nameSort],
        currentOptionIndex: 5, // Out of range
      );

      // Should still register the option but not have it active
      expect(manager.length, equals(1));
    });
  });

  group('_compareKeys edge cases', () {
    test('should handle both null values', () {
      final sort = SortOption<User, int?>(
        id: 'age',
        sortIdentifier: (u) => u.age,
      );
      final manager = SortManager<User>();
      manager.add(sort);

      // Large list to trigger Schwartzian
      final users = List.generate(1100, (i) {
        return User(id: '$i', name: 'User$i');
      });

      // Should not throw with all null values
      final result = manager.sort(users);
      expect(result.length, equals(1100));
    });

    test('should handle first value null', () {
      final sort = SortOption<User, int?>(
        id: 'age',
        sortIdentifier: (u) => u.age,
      );
      final manager = SortManager<User>();
      manager.add(sort);

      final users = List.generate(1100, (i) {
        return User(id: '$i', name: 'User$i', age: i == 0 ? null : i);
      });

      final result = manager.sort(users);
      // Null should be first in ascending
      expect(result[0].age, isNull);
    });

    test('should handle second value null', () {
      final sort = SortOption<User, int?>(
        id: 'age',
        sortIdentifier: (u) => u.age,
      );
      final manager = SortManager<User>();
      manager.add(sort);

      final users = List.generate(1100, (i) {
        return User(id: '$i', name: 'User$i', age: i == 1 ? null : i);
      });

      final result = manager.sort(users);
      // Null should be first in ascending
      expect(result[0].age, isNull);
    });

    test('should handle second value null in comparison (a not null, b null)',
        () {
      final sort = SortOption<User, int?>(
        id: 'age',
        sortIdentifier: (u) => u.age,
      );
      final manager = SortManager<User>();
      manager.add(sort);

      // Create list with alternating null and non-null ages.
      // This ensures we hit all comparison branches including
      // (a not null, b null).
      final users = List.generate(1100, (i) {
        // Alternate between having age and null age.
        return User(id: '$i', name: 'User$i', age: i.isEven ? i : null);
      });

      final result = manager.sort(users);
      // Nulls should be first in ascending, then actual values
      expect(result[0].age, isNull);
      expect(result.last.age, isNotNull);
    });

    test('should compare (a not null, b null) in Schwartzian sort', () {
      // This test specifically targets the branch: if (b == null) return ...
      final sort = SortOption<User, int?>(
        id: 'age',
        sortIdentifier: (u) => u.age,
      );
      final manager = SortManager<User>();
      manager.add(sort);

      // Create a large list where items at the beginning have values
      // and items later have nulls. The sort algorithm will compare
      // items with values against items with nulls in various orders.
      final users = List.generate(1100, (i) {
        // First 550 items have values, last 550 have null
        return User(id: '$i', name: 'User$i', age: i < 550 ? 1000 - i : null);
      });

      final result = manager.sort(users);
      // Nulls should be first in ascending
      expect(result[0].age, isNull);
      expect(result[549].age, isNull);
      expect(result[550].age, isNotNull);
    });

    test('should handle descending sort with mixed null values', () {
      // Descending sort to ensure we hit both branches of null comparison
      final sort = SortOption<User, int?>(
        id: 'age',
        sortIdentifier: (u) => u.age,
        sortOrder: SortOrder.descending,
      );
      final manager = SortManager<User>();
      manager.add(sort);

      // Create a large list with values first, nulls second
      final users = List.generate(1100, (i) {
        return User(id: '$i', name: 'User$i', age: i < 550 ? i : null);
      });

      final result = manager.sort(users);
      // In descending, non-nulls come first (higher values first)
      expect(result[0].age, isNotNull);
      expect(result.last.age, isNull);
    });

    test('should handle descending with null values', () {
      final sort = SortOption<User, int?>(
        id: 'age',
        sortIdentifier: (u) => u.age,
      );
      sort.sortOrder = SortOrder.descending;

      final manager = SortManager<User>();
      manager.add(sort);

      final users = List.generate(1100, (i) {
        return User(id: '$i', name: 'User$i', age: i % 100 == 0 ? null : i);
      });

      final result = manager.sort(users);
      // In descending, null should be last (actually first due to -1)
      // The _compareKeys returns ascending ? -1 : 1 for null first
      expect(result.last.age, isNull);
    });

    test('should handle non-Comparable values in large list', () {
      // Use a sort option that returns non-Comparable values
      final sort = SortOption<_TestItem, Object>(
        id: 'nonComparable',
        sortIdentifier: (item) => item.nonComparableValue,
      );

      final manager = SortManager<_TestItem>();
      manager.add(sort);

      // Create a large list with non-Comparable values
      final items = List.generate(1100, (i) {
        return _TestItem(
          _NonComparable('Item${(1100 - i).toString().padLeft(4, '0')}'),
        );
      });

      final result = manager.sort(items);

      // Should sort using toString comparison
      expect(result[0].nonComparableValue.toString(), equals('Item0001'));
    });
  });

  group('SortManager.removeAll coverage', () {
    test('should notify when removing options silently false', () {
      final manager = SortManager<User>();
      final nameSort = SortOption<User, String>(
        id: 'name',
        sortIdentifier: (u) => u.name,
      );
      final ageSort = SortOption<User, int>(
        id: 'age',
        sortIdentifier: (u) => u.priority,
      );

      manager.add(nameSort);
      manager.add(ageSort);

      var notified = false;
      manager.addChangeListener(() => notified = true);

      manager.removeAll([nameSort, ageSort]);

      expect(notified, isTrue);
      expect(manager.length, equals(0));
    });

    test('should call onSortChanged when removing current option', () {
      SortOption<User, dynamic>? changedOption =
          SortOption.none as SortOption<User, dynamic>;
      final nameSort = SortOption<User, String>(
        id: 'name',
        sortIdentifier: (u) => u.name,
      );

      final manager = SortManager<User>(
        onSortChanged: (opt) => changedOption = opt,
      );
      manager.add(nameSort);

      manager.removeAll([nameSort]);

      // onSortChanged should have been called with null
      expect(changedOption, isNull);
    });
  });

  group('ValueSortOption.copyWith full coverage', () {
    test('should copy all parameters including source', () {
      final original = ValueSortOption<User, String>(
        id: 'name',
        label: 'Name',
        sortIdentifier: (u) => u.name,
        sortOrder: SortOrder.ascending,
      );

      final copy = original.copyWith(
        id: 'new_id',
        label: 'New Label',
        sortOrder: SortOrder.descending,
        source: TransformSource.remote,
        enabled: false,
      );

      expect(copy.id, equals('new_id'));
      expect(copy.label, equals('New Label'));
      expect(copy.sortOrder, equals(SortOrder.descending));
      expect(copy.source, equals(TransformSource.remote));
      expect(copy.enabled, isFalse);
    });
  });

  group('ComparableSortOption full coverage', () {
    test('should create with all constructor parameters', () {
      final sort = ComparableSortOption<User>(
        id: 'full',
        label: 'Full Name',
        comparables: (u) => [u.name, u.id],
        sortOrder: SortOrder.descending,
        source: TransformSource.combined,
        enabled: false,
      );

      expect(sort.id, equals('full'));
      expect(sort.label, equals('Full Name'));
      expect(sort.sortOrder, equals(SortOrder.descending));
      expect(sort.source, equals(TransformSource.combined));
      expect(sort.enabled, isFalse);
    });

    test('copyWith should copy all fields including source', () {
      final original = ComparableSortOption<User>(
        id: 'full',
        comparables: (u) => [u.name],
      );

      final copy = original.copyWith(
        id: 'new_id',
        label: 'New Label',
        sortOrder: SortOrder.descending,
        source: TransformSource.remote,
        enabled: false,
      );

      expect(copy.id, equals('new_id'));
      expect(copy.label, equals('New Label'));
      expect(copy.sortOrder, equals(SortOrder.descending));
      expect(copy.source, equals(TransformSource.remote));
      expect(copy.enabled, isFalse);
    });
  });

  group('ComparatorSortOption full coverage', () {
    test('should create with source parameter', () {
      final sort = ComparatorSortOption<User>(
        id: 'priority',
        comparator: (a, b) => a.priority.compareTo(b.priority),
        source: TransformSource.combined,
      );

      expect(sort.source, equals(TransformSource.combined));
    });

    test('copyWith should copy source', () {
      final original = ComparatorSortOption<User>(
        id: 'priority',
        comparator: (a, b) => a.priority.compareTo(b.priority),
      );

      final copy = original.copyWith(
        source: TransformSource.remote,
      );

      expect(copy.source, equals(TransformSource.remote));
    });

    test('should use secondary comparator when primary returns 0', () {
      final sort = ComparatorSortOption<User>(
        id: 'priority',
        comparator: (a, b) => 0, // Always tie
        secondaryId: 'name',
        secondaryComparator: (a, b) => a.name.compareTo(b.name),
      );

      const alice = User(id: '1', name: 'Alice');
      const bob = User(id: '2', name: 'Bob');

      expect(sort.compare(alice, bob), lessThan(0));
    });

    test('should handle secondary with descending order', () {
      final sort = ComparatorSortOption<User>(
        id: 'priority',
        comparator: (a, b) => 0, // Always tie
        secondaryId: 'name',
        secondarySortOrder: SortOrder.descending,
        secondaryComparator: (a, b) => a.name.compareTo(b.name),
      );

      const alice = User(id: '1', name: 'Alice');
      const bob = User(id: '2', name: 'Bob');

      expect(sort.compare(alice, bob), greaterThan(0)); // Reversed
    });
  });

  group('CustomSortOption.copyWith full coverage', () {
    test('should copy all fields including source', () {
      final values = [
        SortValue<User>(id: 'name', value: (u) => u.name),
      ];
      final original = CustomSortOption<User>(
        id: 'custom',
        values: values,
      );

      final copy = original.copyWith(
        id: 'new_id',
        label: 'New Label',
        sortOrder: SortOrder.descending,
        source: TransformSource.remote,
        enabled: false,
      ) as CustomSortOption<User>;

      expect(copy.id, equals('new_id'));
      expect(copy.label, equals('New Label'));
      expect(copy.sortOrder, equals(SortOrder.descending));
      expect(copy.source, equals(TransformSource.remote));
      expect(copy.enabled, isFalse);
    });
  });

  group('_NoSort coverage', () {
    test('copyWith should return new _NoSort ignoring all parameters', () {
      final noSort = SortOption.none;
      final copy = noSort.copyWith(
        id: 'test',
        label: 'Test Label',
        sortOrder: SortOrder.descending,
        source: TransformSource.remote,
        enabled: true,
      );

      // _NoSort.copyWith ignores all parameters
      expect(copy.id, equals(''));
      expect(copy.label, isNull);
      expect(copy.sortOrder, equals(SortOrder.ascending));
      expect(copy.source, equals(TransformSource.local));
      expect(copy.enabled, isFalse);
      expect(copy.toString(), equals('SortOption.none'));
    });
  });

  group('SortManager.addAll coverage', () {
    test('should preserve sort order for matching current option', () {
      final manager = SortManager<User>();
      final nameSort = SortOption<User, String>(
        id: 'name',
        sortIdentifier: (u) => u.name,
        sortOrder: SortOrder.descending,
      );

      // Set as current first
      manager.setCurrent(nameSort);
      expect(nameSort.sortOrder, equals(SortOrder.descending));

      // Now addAll with same option
      final newNameSort = SortOption<User, String>(
        id: 'name',
        sortIdentifier: (u) => u.name,
        sortOrder: SortOrder.ascending,
      );

      manager.addAll([newNameSort]);

      // The new option should have the current's sort order
      expect(newNameSort.sortOrder, equals(SortOrder.descending));
    });
  });

  group('SortManager.setCurrentById coverage', () {
    test('should set current when id exists', () {
      final manager = SortManager<User>();
      final nameSort = SortOption<User, String>(
        id: 'name',
        sortIdentifier: (u) => u.name,
      );
      final ageSort = SortOption<User, int>(
        id: 'age',
        sortIdentifier: (u) => u.priority,
      );

      manager.add(nameSort);
      manager.add(ageSort);

      manager.setCurrentById('age');

      expect(manager.current?.id, equals('age'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // SortEntry Tests
  // ══════════════════════════════════════════════════════════════════════════

  group('SortEntry', () {
    group('constructor', () {
      test('should create with id and order', () {
        const entry = SortEntry(id: 'name', order: SortOrder.ascending);

        expect(entry.id, equals('name'));
        expect(entry.order, equals(SortOrder.ascending));
      });
    });

    group('fromJson', () {
      test('should parse from JSON with asc order', () {
        final entry = SortEntry.fromJson(const {
          'id': 'name',
          'order': 'asc',
        });

        expect(entry.id, equals('name'));
        expect(entry.order, equals(SortOrder.ascending));
      });

      test('should parse from JSON with desc order', () {
        final entry = SortEntry.fromJson(const {
          'id': 'name',
          'order': 'desc',
        });

        expect(entry.order, equals(SortOrder.descending));
      });

      test('should default to ascending for unknown order', () {
        final entry = SortEntry.fromJson(const {
          'id': 'name',
          'order': 'unknown',
        });

        expect(entry.order, equals(SortOrder.ascending));
      });

      test('should default to ascending for null order', () {
        final entry = SortEntry.fromJson(const {
          'id': 'name',
          'order': null,
        });

        expect(entry.order, equals(SortOrder.ascending));
      });
    });

    group('toJson', () {
      test('should serialize to JSON', () {
        const entry = SortEntry(id: 'name', order: SortOrder.ascending);

        final json = entry.toJson();

        expect(json['id'], equals('name'));
        expect(json['order'], equals('asc'));
      });
    });

    group('equality', () {
      test('should be equal for same id and order', () {
        const entry1 = SortEntry(id: 'name', order: SortOrder.ascending);
        const entry2 = SortEntry(id: 'name', order: SortOrder.ascending);

        expect(entry1, equals(entry2));
        expect(entry1.hashCode, equals(entry2.hashCode));
      });

      test('should not be equal for different id', () {
        const entry1 = SortEntry(id: 'name', order: SortOrder.ascending);
        const entry2 = SortEntry(id: 'age', order: SortOrder.ascending);

        expect(entry1, isNot(equals(entry2)));
      });

      test('should not be equal for different order', () {
        const entry1 = SortEntry(id: 'name', order: SortOrder.ascending);
        const entry2 = SortEntry(id: 'name', order: SortOrder.descending);

        expect(entry1, isNot(equals(entry2)));
      });
    });

    group('toString', () {
      test('should include id and order code', () {
        const entry = SortEntry(id: 'name', order: SortOrder.ascending);

        expect(entry.toString(), equals('SortEntry(name:asc)'));
      });
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // SortSnapshot Tests
  // ══════════════════════════════════════════════════════════════════════════

  group('SortSnapshot', () {
    group('constructor', () {
      test('empty() should create empty snapshot', () {
        const snapshot = SortSnapshot.empty();

        expect(snapshot.isEmpty, isTrue);
        expect(snapshot.isNotEmpty, isFalse);
        expect(snapshot.length, equals(0));
        expect(snapshot.entries, isEmpty);
      });

      test('fromEntries should create snapshot with entries', () {
        final snapshot = SortSnapshot.fromEntries(const [
          SortEntry(id: 'name', order: SortOrder.ascending),
          SortEntry(id: 'age', order: SortOrder.descending),
        ]);

        expect(snapshot.length, equals(2));
        expect(snapshot.isNotEmpty, isTrue);
      });
    });

    group('toJson', () {
      test('should serialize entries to JSON', () {
        final snapshot = SortSnapshot.fromEntries(const [
          SortEntry(id: 'name', order: SortOrder.ascending),
        ]);

        final json = snapshot.toJson();

        expect(json['sorts'], isA<List<dynamic>>());
        final sorts = json['sorts']! as List<dynamic>;
        expect((sorts.first as Map<String, dynamic>)['id'], equals('name'));
      });
    });

    group('fromJson', () {
      test('should deserialize from JSON', () {
        const json = {
          'sorts': [
            {'id': 'name', 'order': 'asc'},
            {'id': 'age', 'order': 'desc'},
          ],
        };

        final snapshot = SortSnapshot.fromJson(json);

        expect(snapshot.length, equals(2));
        expect(snapshot.entries[0].id, equals('name'));
        expect(snapshot.entries[1].order, equals(SortOrder.descending));
      });

      test('should return empty for null entries', () {
        final snapshot = SortSnapshot.fromJson(const <String, dynamic>{});

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty for empty entries list', () {
        final snapshot = SortSnapshot.fromJson(const {'sorts': <dynamic>[]});

        expect(snapshot.isEmpty, isTrue);
      });

      test('should filter non-map entries', () {
        final json = {
          'sorts': [
            {'id': 'name', 'order': 'asc'},
            'invalid',
            123,
          ],
        };

        final snapshot = SortSnapshot.fromJson(json);

        expect(snapshot.length, equals(1));
      });
    });

    group('toQueryString', () {
      test('should return empty string for empty snapshot', () {
        const snapshot = SortSnapshot.empty();

        expect(snapshot.toQueryString(), isEmpty);
      });

      test('should encode as comma-separated id:order pairs', () {
        final snapshot = SortSnapshot.fromEntries(const [
          SortEntry(id: 'name', order: SortOrder.ascending),
        ]);

        final query = snapshot.toQueryString();

        expect(query, equals('sort=name:asc'));
      });

      test('should encode multiple entries', () {
        final snapshot = SortSnapshot.fromEntries(const [
          SortEntry(id: 'name', order: SortOrder.ascending),
          SortEntry(id: 'age', order: SortOrder.descending),
        ]);

        final query = snapshot.toQueryString();

        expect(query, equals('sort=name:asc,age:desc'));
      });

      test('should URL-encode special characters in id', () {
        final snapshot = SortSnapshot.fromEntries(const [
          SortEntry(id: 'first/name', order: SortOrder.ascending),
        ]);

        final query = snapshot.toQueryString();

        expect(query, contains('first%2Fname'));
      });
    });

    group('fromQueryString', () {
      test('should return empty for empty query', () {
        final snapshot = SortSnapshot.fromQueryString('');

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty for missing sort param', () {
        final snapshot = SortSnapshot.fromQueryString('foo=bar');

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty for empty sort value', () {
        final snapshot = SortSnapshot.fromQueryString('sort=');

        expect(snapshot.isEmpty, isTrue);
      });

      test('should parse single entry', () {
        final snapshot = SortSnapshot.fromQueryString('sort=name:asc');

        expect(snapshot.length, equals(1));
        expect(snapshot.entries[0].id, equals('name'));
        expect(snapshot.entries[0].order, equals(SortOrder.ascending));
      });

      test('should parse multiple entries', () {
        final snapshot = SortSnapshot.fromQueryString('sort=name:asc,age:desc');

        expect(snapshot.length, equals(2));
        expect(snapshot.entries[0].id, equals('name'));
        expect(snapshot.entries[1].id, equals('age'));
        expect(snapshot.entries[1].order, equals(SortOrder.descending));
      });

      test('should default order to asc when not specified', () {
        final snapshot = SortSnapshot.fromQueryString('sort=name');

        expect(snapshot.entries[0].order, equals(SortOrder.ascending));
      });

      test('should handle empty pairs by creating entries with empty ids', () {
        // Current implementation creates entries even for empty pairs
        // This tests the actual behavior
        final snapshot = SortSnapshot.fromQueryString('sort=,name:asc,');

        // Three entries are created: '', 'name', ''
        expect(snapshot.length, equals(3));
        expect(snapshot.entries[0].id, equals(''));
        expect(snapshot.entries[1].id, equals('name'));
        expect(snapshot.entries[2].id, equals(''));
      });

      test('should URL-decode special characters in id', () {
        final snapshot = SortSnapshot.fromQueryString('sort=first%2Fname:asc');

        expect(snapshot.entries[0].id, equals('first/name'));
      });
    });

    group('equality', () {
      test('should be equal for same entries', () {
        final snapshot1 = SortSnapshot.fromEntries(const [
          SortEntry(id: 'name', order: SortOrder.ascending),
        ]);
        final snapshot2 = SortSnapshot.fromEntries(const [
          SortEntry(id: 'name', order: SortOrder.ascending),
        ]);

        expect(snapshot1, equals(snapshot2));
        expect(snapshot1.hashCode, equals(snapshot2.hashCode));
      });

      test('should not be equal for different entries', () {
        final snapshot1 = SortSnapshot.fromEntries(const [
          SortEntry(id: 'name', order: SortOrder.ascending),
        ]);
        final snapshot2 = SortSnapshot.fromEntries(const [
          SortEntry(id: 'age', order: SortOrder.ascending),
        ]);

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('should not be equal for different lengths', () {
        final snapshot1 = SortSnapshot.fromEntries(const [
          SortEntry(id: 'name', order: SortOrder.ascending),
        ]);
        final snapshot2 = SortSnapshot.fromEntries(const [
          SortEntry(id: 'name', order: SortOrder.ascending),
          SortEntry(id: 'age', order: SortOrder.descending),
        ]);

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('should not be equal to non-SortSnapshot', () {
        final snapshot = SortSnapshot.fromEntries(const [
          SortEntry(id: 'name', order: SortOrder.ascending),
        ]);

        expect(snapshot, isNot(equals('not a snapshot')));
      });

      test('identical snapshots should be equal', () {
        final snapshot = SortSnapshot.fromEntries(const [
          SortEntry(id: 'name', order: SortOrder.ascending),
        ]);

        expect(snapshot, equals(snapshot));
      });
    });

    group('toString', () {
      test('should include entries', () {
        final snapshot = SortSnapshot.fromEntries(const [
          SortEntry(id: 'name', order: SortOrder.ascending),
        ]);

        expect(snapshot.toString(), contains('SortSnapshot'));
      });
    });

    group('roundtrip', () {
      test('should roundtrip through JSON', () {
        final original = SortSnapshot.fromEntries(const [
          SortEntry(id: 'name', order: SortOrder.ascending),
          SortEntry(id: 'age', order: SortOrder.descending),
        ]);

        final json = original.toJson();
        final restored = SortSnapshot.fromJson(json);

        expect(restored, equals(original));
      });

      test('should roundtrip through query string', () {
        final original = SortSnapshot.fromEntries(const [
          SortEntry(id: 'name', order: SortOrder.ascending),
          SortEntry(id: 'age', order: SortOrder.descending),
        ]);

        final query = original.toQueryString();
        final restored = SortSnapshot.fromQueryString(query);

        expect(restored, equals(original));
      });
    });
  });

  // ===========================================================================
  // SortCriteria Additional Coverage Tests
  // ===========================================================================

  group('SortCriteria', () {
    test('ascending factory creates ascending criteria', () {
      const criteria = SortCriteria.ascending('name');

      expect(criteria.id, equals('name'));
      expect(criteria.order, equals(SortOrder.ascending));
    });

    test('descending factory creates descending criteria', () {
      const criteria = SortCriteria.descending('name');

      expect(criteria.id, equals('name'));
      expect(criteria.order, equals(SortOrder.descending));
    });

    test('fromJson parses valid JSON', () {
      final json = {'id': 'name', 'order': 'asc'};
      final criteria = SortCriteria.fromJson(json);

      expect(criteria.id, equals('name'));
      expect(criteria.order, equals(SortOrder.ascending));
    });

    test('fromJson parses descending order', () {
      final json = {'id': 'age', 'order': 'desc'};
      final criteria = SortCriteria.fromJson(json);

      expect(criteria.id, equals('age'));
      expect(criteria.order, equals(SortOrder.descending));
    });

    test('fromJson defaults to none for invalid order', () {
      final json = {'id': 'name', 'order': 'invalid'};
      final criteria = SortCriteria.fromJson(json);

      expect(criteria.order, equals(SortOrder.none));
    });

    test('fromJson throws on invalid JSON structure', () {
      final json = {'invalid': 'data'};

      expect(
        () => SortCriteria.fromJson(json),
        throwsFormatException,
      );
    });

    test('fromQueryParams parses sort parameter', () {
      final params = {'sort': 'name:asc,age:desc'};
      final criteria = SortCriteria.fromQueryParams(params);

      expect(criteria.length, equals(2));
      expect(criteria[0].id, equals('name'));
      expect(criteria[0].order, equals(SortOrder.ascending));
      expect(criteria[1].id, equals('age'));
      expect(criteria[1].order, equals(SortOrder.descending));
    });

    test('fromQueryParams handles field without direction', () {
      final params = {'sort': 'name'};
      final criteria = SortCriteria.fromQueryParams(params);

      expect(criteria.length, equals(1));
      expect(criteria[0].id, equals('name'));
      expect(criteria[0].order, equals(SortOrder.ascending)); // default
    });

    test('fromQueryParams returns empty list for empty param', () {
      final criteria = SortCriteria.fromQueryParams({});

      expect(criteria, isEmpty);
    });

    test('fromQueryParams returns empty list for empty sort value', () {
      final params = {'sort': ''};
      final criteria = SortCriteria.fromQueryParams(params);

      expect(criteria, isEmpty);
    });

    test('listToQueryParams converts criteria list', () {
      final criteria = [
        const SortCriteria(id: 'name', order: SortOrder.ascending),
        const SortCriteria(id: 'age', order: SortOrder.descending),
      ];
      final params = SortCriteria.listToQueryParams(criteria);

      expect(params['sort'], equals('name:asc,age:desc'));
    });

    test('listToQueryParams excludes inactive criteria', () {
      final criteria = [
        const SortCriteria(id: 'name', order: SortOrder.ascending),
        const SortCriteria(id: 'age', order: SortOrder.none),
      ];
      final params = SortCriteria.listToQueryParams(criteria);

      expect(params['sort'], equals('name:asc'));
    });

    test('listToQueryParams returns empty for all inactive', () {
      final criteria = [
        const SortCriteria(id: 'name', order: SortOrder.none),
      ];
      final params = SortCriteria.listToQueryParams(criteria);

      expect(params, isEmpty);
    });

    test('toJson converts to JSON map', () {
      const criteria = SortCriteria(id: 'name', order: SortOrder.ascending);
      final json = criteria.toJson();

      expect(json['id'], equals('name'));
      expect(json['order'], equals('asc'));
    });

    test('toString returns descriptive string', () {
      const criteria = SortCriteria(id: 'name', order: SortOrder.ascending);
      final str = criteria.toString();

      expect(str, contains('SortCriteria'));
      expect(str, contains('name'));
      expect(str, contains('asc'));
    });
  });

  // ===========================================================================
  // SortManager with ComparableSortOption (Schwartzian transform coverage)
  // ===========================================================================

  group('SortManager Schwartzian transform with ComparableSortOption', () {
    // Note: Schwartzian transform is used for lists >= 1000 items
    // We need to test with large lists to trigger _extractKey and _compareKeys

    List<User> generateUsers(int count) {
      // Use padded numbers to ensure correct lexicographic ordering
      return List.generate(
        count,
        (i) => User(
          id: '$i',
          name: 'User${(i % 100).toString().padLeft(3, '0')}',
          age: i % 50,
          priority: i % 10,
        ),
      );
    }

    test('sort uses _extractKey for ComparableSortOption on large list', () {
      final comparableSort = ComparableSortOption<User>(
        id: 'name_age',
        comparables: (user) => [user.name, user.age],
        sortOrder: SortOrder.ascending,
      );
      // Don't call setCurrent - option is already active from constructor
      final manager = SortManager<User>(options: [comparableSort]);

      final users = generateUsers(1001); // Trigger Schwartzian transform

      final sorted = manager.sort(users);

      // Verify sorting worked
      expect(sorted.length, equals(1001));
      // Verify list is sorted by name (case-insensitive)
      for (var i = 0; i < sorted.length - 1; i++) {
        final cmp = sorted[i].name.toLowerCase().compareTo(
              sorted[i + 1].name.toLowerCase(),
            );
        expect(cmp, lessThanOrEqualTo(0));
      }
    });

    test('sort handles list comparison in _compareKeys on large list', () {
      final comparableSort = ComparableSortOption<User>(
        id: 'priority_name',
        comparables: (user) => [user.priority, user.name],
        sortOrder: SortOrder.ascending,
      );
      // Don't call setCurrent - option is already active from constructor
      final manager = SortManager<User>(options: [comparableSort]);

      final users = generateUsers(1001);

      final sorted = manager.sort(users);

      expect(sorted.length, equals(1001));
      // Verify priority-based sorting (primary key)
      for (var i = 0; i < sorted.length - 1; i++) {
        expect(sorted[i].priority, lessThanOrEqualTo(sorted[i + 1].priority));
      }
    });

    test('sort with ComparatorSortOption triggers null key path', () {
      // ComparatorSortOption returns null from _extractKey
      // This tests line 1753-1756: both keys null, falls back to compare()
      final comparatorSort = ComparatorSortOption<User>(
        id: 'custom',
        comparator: (a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        sortOrder: SortOrder.ascending,
      );
      // Don't call setCurrent - option is already active from constructor
      final manager = SortManager<User>(options: [comparatorSort]);

      final users = generateUsers(1001);

      final sorted = manager.sort(users);

      expect(sorted.length, equals(1001));
      // Verify name-based sorting via comparator (case-insensitive)
      for (var i = 0; i < sorted.length - 1; i++) {
        final cmp = sorted[i].name.toLowerCase().compareTo(
              sorted[i + 1].name.toLowerCase(),
            );
        expect(cmp, lessThanOrEqualTo(0));
      }
    });

    test('sort handles null values in comparable list on large list', () {
      final comparableSort = ComparableSortOption<_NullableUser>(
        id: 'name_age',
        comparables: (user) => [user.name, user.age],
        sortOrder: SortOrder.ascending,
      );
      // Don't call setCurrent - option is already active from constructor
      final manager = SortManager<_NullableUser>(options: [comparableSort]);

      // Generate users with some null values
      final users = List.generate(
        1001,
        (i) {
          final nameNum = (i % 100).toString().padLeft(3, '0');
          return _NullableUser(
            id: '$i',
            name: i % 10 == 0 ? null : 'User$nameNum',
            age: i % 5 == 0 ? null : i % 50,
          );
        },
      );

      final sorted = manager.sort(users);

      expect(sorted.length, equals(1001));
      // Just verify sorting completes without error
      // Null handling is tested, specific order depends on implementation
    });

    test('_compareKeys returns 0 when both keys are null', () {
      // Use two ComparatorSortOptions - both return null from _extractKey
      // When items compare equal on first sort, it moves to second sort
      // where both keys are also null, hitting line 1787
      final sort1 = ComparatorSortOption<User>(
        id: 'sort1',
        comparator: (a, b) => 0, // Always equal - forces check of next sort
        sortOrder: SortOrder.ascending,
      );
      final sort2 = ComparatorSortOption<User>(
        id: 'sort2',
        comparator: (a, b) => a.name.compareTo(b.name),
        sortOrder: SortOrder.ascending,
      );
      final manager = SortManager<User>(options: [sort1, sort2]);

      final users = List.generate(
        1001,
        (i) => User(
          id: '$i',
          name: 'User${(i % 100).toString().padLeft(3, '0')}',
        ),
      );

      // This triggers Schwartzian sort where both sorts return null keys
      // For sort1, all comparisons return 0, so it checks sort2's keys
      // Both are null (ComparatorSortOption), hitting line 1787
      final sorted = manager.sort(users);

      expect(sorted.length, equals(1001));
    });
  });

  group('SortCriteria.fromQueryParams edge cases', () {
    test('throws FormatException for invalid sort parameter format', () {
      // Format with more than 2 parts after split by ':'
      final params = {'sort': 'field:asc:extra:parts'};

      expect(
        () => SortCriteria.fromQueryParams(params),
        throwsFormatException,
      );
    });
  });
}

// Helper class for nullable field tests
class _NullableUser {
  const _NullableUser({
    required this.id,
    this.name,
    this.age,
  });

  final String id;
  final String? name;
  final int? age;
}

// Helper class for non-Comparable test
class _NonComparable {
  _NonComparable(this.value);

  final String value;

  @override
  String toString() => value;
}

// Test item wrapper for non-Comparable values
class _TestItem {
  _TestItem(this.nonComparableValue);

  final _NonComparable nonComparableValue;
}
