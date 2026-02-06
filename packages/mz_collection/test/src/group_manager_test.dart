// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

// Test helper classes have fields for completeness that may not all be used.
// ignore_for_file: unreachable_from_main

import 'package:mz_collection/src/group_manager.dart';
import 'package:mz_collection/src/sort_manager.dart';
import 'package:test/test.dart';

// ════════════════════════════════════════════════════════════════════════════
// Test Models
// ════════════════════════════════════════════════════════════════════════════

/// Test model for grouping operations.
class Task {
  const Task({
    required this.id,
    required this.category,
    this.title = '',
    this.priority = 0,
    this.isCompleted = false,
    this.createdAt,
    this.price = 0.0,
    this.tags,
  });

  final String id;
  final String title;
  final String category;
  final int priority;
  final bool isCompleted;
  final DateTime? createdAt;
  final double price;
  final List<String>? tags;
}

/// Status enum for testing enum-based grouping.
enum Status { open, inProgress, closed }

/// Test model with enum field.
class Ticket {
  const Ticket({
    required this.id,
    required this.status,
    required this.category,
  });

  final String id;
  final Status status;
  final String category;
}

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // GroupOption Tests
  // ══════════════════════════════════════════════════════════════════════════

  group('GroupOption', () {
    group('constructor', () {
      test('should create with required parameters', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        expect(option.id, equals('category'));
        expect(option.label, isEmpty);
        expect(option.extra, isNull);
        expect(option.selectable, isTrue);
        expect(option.collapsible, isTrue);
        expect(option.selected, isFalse);
        expect(option.collapsed, isFalse);
        expect(option.enabled, isTrue);
        expect(option.order, equals(0));
        expect(option.sortOption, isNull);
      });

      test('should create with all optional parameters', () {
        final sortOption = SortOption<String, String>(
          id: 'name',
          sortIdentifier: (s) => s,
        );

        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          label: 'Category',
          extra: {'icon': 'folder'},
          selectable: false,
          collapsible: false,
          selected: true,
          collapsed: true,
          enabled: false,
          order: 5,
          keyBuilder: (value) => 'key_$value',
          sortOption: sortOption,
        );

        expect(option.id, equals('category'));
        expect(option.label, equals('Category'));
        expect(option.extra, equals({'icon': 'folder'}));
        expect(option.selectable, isFalse);
        expect(option.collapsible, isFalse);
        expect(option.selected, isTrue);
        expect(option.collapsed, isTrue);
        expect(option.enabled, isFalse);
        expect(option.order, equals(5));
        expect(option.sortOption, equals(sortOption));
      });
    });

    group('groupKeyFor', () {
      test('should extract key using valueBuilder and toString', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        const task = Task(id: '1', category: 'Development');
        expect(option.groupKeyFor(task), equals('Development'));
      });

      test('should extract key using custom keyBuilder', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          keyBuilder: (value) => 'cat_${value.toLowerCase()}',
        );

        const task = Task(id: '1', category: 'Development');
        expect(option.groupKeyFor(task), equals('cat_development'));
      });

      test('should return null when keyBuilder returns null', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          keyBuilder: (value) => value == 'Skip' ? null : value,
        );

        const skipTask = Task(id: '1', category: 'Skip');
        const normalTask = Task(id: '2', category: 'Normal');

        expect(option.groupKeyFor(skipTask), isNull);
        expect(option.groupKeyFor(normalTask), equals('Normal'));
      });

      test('should handle null values from valueBuilder', () {
        final option = GroupOption<Task, String?>(
          id: 'category',
          valueBuilder: (task) => task.category.isEmpty ? null : task.category,
        );

        const taskWithEmpty = Task(id: '1', category: '');
        const taskWithValue = Task(id: '2', category: 'Work');

        // When valueBuilder returns null, groupKeyFor returns null
        // (item should not be grouped at this level)
        expect(option.groupKeyFor(taskWithEmpty), isNull);
        expect(option.groupKeyFor(taskWithValue), equals('Work'));
      });

      test('should handle enum values', () {
        final option = GroupOption<Ticket, Status>(
          id: 'status',
          valueBuilder: (ticket) => ticket.status,
        );

        const ticket = Ticket(id: '1', status: Status.open, category: 'Bug');
        expect(option.groupKeyFor(ticket), equals('Status.open'));
      });

      test('should handle enum with custom keyBuilder', () {
        final option = GroupOption<Ticket, Status>(
          id: 'status',
          valueBuilder: (ticket) => ticket.status,
          keyBuilder: (status) => status.name,
        );

        const ticket =
            Ticket(id: '1', status: Status.inProgress, category: 'Bug');
        expect(option.groupKeyFor(ticket), equals('inProgress'));
      });
    });

    group('groupKeysFor on single-value option', () {
      test('should return single-element list when key is non-null', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        const task = Task(id: '1', category: 'Development');
        expect(option.groupKeysFor(task), equals(['Development']));
      });

      test('should return empty list when key is null', () {
        final option = GroupOption<Task, String?>(
          id: 'category',
          valueBuilder: (task) => task.category.isEmpty ? null : task.category,
        );

        const taskWithEmpty = Task(id: '1', category: '');
        expect(option.groupKeysFor(taskWithEmpty), isEmpty);
      });
    });

    group('enabled property', () {
      test('should notify listeners when changed', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        var notified = false;
        option.addChangeListener(() => notified = true);

        option.enabled = false;

        expect(option.enabled, isFalse);
        expect(notified, isTrue);
      });

      test('should not notify when set to same value', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          enabled: true,
        );

        var notifyCount = 0;
        option.addChangeListener(() => notifyCount++);

        option.enabled = true;

        expect(notifyCount, equals(0));
      });
    });

    group('order property', () {
      test('should notify listeners when changed', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          order: 0,
        );

        var notified = false;
        option.addChangeListener(() => notified = true);

        option.order = 5;

        expect(option.order, equals(5));
        expect(notified, isTrue);
      });

      test('should not notify when set to same value', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          order: 3,
        );

        var notifyCount = 0;
        option.addChangeListener(() => notifyCount++);

        option.order = 3;

        expect(notifyCount, equals(0));
      });
    });

    group('sortOption', () {
      test('should notify when sortOption changes', () {
        final sortOption = SortOption<String, String>(
          id: 'name',
          sortIdentifier: (s) => s,
        );

        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          sortOption: sortOption,
        );

        var notified = false;
        option.addChangeListener(() => notified = true);

        sortOption.toggle();

        expect(notified, isTrue);
      });

      test('should unsubscribe from sortOption on dispose', () {
        final sortOption = SortOption<String, String>(
          id: 'name',
          sortIdentifier: (s) => s,
        );

        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          sortOption: sortOption,
        );

        var notifyCount = 0;
        option.addChangeListener(() => notifyCount++);

        option.dispose();
        sortOption.toggle();

        expect(notifyCount, equals(0));
      });
    });

    group('equality', () {
      test('should be equal if ids match', () {
        final option1 = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          order: 0,
        );

        final option2 = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.id,
          order: 5,
          label: 'Different',
        );

        expect(option1, equals(option2));
      });

      test('should not be equal if ids differ', () {
        final option1 = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        final option2 = GroupOption<Task, String>(
          id: 'priority',
          valueBuilder: (task) => task.category,
        );

        expect(option1, isNot(equals(option2)));
      });

      test('should be equal when identical', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        expect(option, equals(option));
      });
    });

    group('hashCode', () {
      test('should be based on id', () {
        final option1 = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        final option2 = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.id,
        );

        expect(option1.hashCode, equals(option2.hashCode));
        expect(option1.hashCode, equals('category'.hashCode));
      });
    });

    group('toString', () {
      test('should include all set properties', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          label: 'Category',
          order: 2,
          selected: true,
          collapsed: true,
        );

        final str = option.toString();

        expect(str, contains('id: category'));
        expect(str, contains('label: Category'));
        expect(str, contains('order: 2'));
        expect(str, contains('selectable'));
        expect(str, contains('collapsible'));
        expect(str, contains('selected'));
        expect(str, contains('collapsed'));
      });

      test('should show enabled: false when disabled', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          enabled: false,
        );

        expect(option.toString(), contains('enabled: false'));
      });

      test('should include sortOption when present', () {
        final sortOption = SortOption<String, String>(
          id: 'name',
          sortIdentifier: (s) => s,
        );

        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          sortOption: sortOption,
        );

        expect(option.toString(), contains('sortOption:'));
      });

      test('should omit empty label', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        expect(option.toString(), isNot(contains('label:')));
      });
    });

    group('dispose', () {
      test('should clear listeners', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        var notified = false;
        option.addChangeListener(() => notified = true);

        option.dispose();
        option.enabled = false;

        expect(notified, isFalse);
      });
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // GroupManager Tests
  // ══════════════════════════════════════════════════════════════════════════

  group('GroupManager', () {
    group('constructor', () {
      test('should create empty manager', () {
        final manager = GroupManager<Task>();

        expect(manager.isEmpty, isTrue);
        expect(manager.length, equals(0));
        expect(manager.allOptions, isEmpty);
      });

      test('should create with initial options sorted by order', () {
        final option1 = GroupOption<Task, int>(
          id: 'priority',
          valueBuilder: (task) => task.priority,
          order: 2,
        );
        final option2 = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          order: 0,
        );
        final option3 = GroupOption<Task, bool>(
          id: 'completed',
          valueBuilder: (task) => task.isCompleted,
          order: 1,
        );

        final manager = GroupManager<Task>(
          options: [option1, option2, option3],
        );

        final ids = manager.allOptions.map((o) => o.id).toList();
        expect(ids, equals(['category', 'completed', 'priority']));
      });

      test('should handle null options', () {
        final manager = GroupManager<Task>();

        expect(manager.isEmpty, isTrue);
      });
    });

    group('add', () {
      test('should add new option and notify', () {
        final manager = GroupManager<Task>();
        var notified = false;
        manager.addChangeListener(() => notified = true);

        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        final result = manager.add(option);

        expect(result, isTrue);
        expect(manager.length, equals(1));
        expect(notified, isTrue);
      });

      test('should not add duplicate option', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        final manager = GroupManager<Task>(options: [option]);

        var notifyCount = 0;
        manager.addChangeListener(() => notifyCount++);

        final anotherOption = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.id,
        );

        final result = manager.add(anotherOption);

        expect(result, isFalse);
        expect(manager.length, equals(1));
        expect(notifyCount, equals(0));
      });

      test('should replace existing option when replace=true', () {
        final original = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          label: 'Original',
        );

        final manager = GroupManager<Task>(options: [original]);

        var notifyCount = 0;
        manager.addChangeListener(() => notifyCount++);

        final replacement = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category.toUpperCase(),
          label: 'Replacement',
        );

        final result = manager.add(replacement, replace: true);

        expect(result, isTrue);
        expect(manager.length, equals(1));
        expect(manager.optionById('category')?.label, equals('Replacement'));
        expect(notifyCount, equals(1));
      });

      test('should maintain sorted order after add', () {
        final option0 = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          order: 0,
        );
        final option2 = GroupOption<Task, int>(
          id: 'priority',
          valueBuilder: (task) => task.priority,
          order: 2,
        );

        final manager = GroupManager<Task>(options: [option0, option2]);

        final option1 = GroupOption<Task, bool>(
          id: 'completed',
          valueBuilder: (task) => task.isCompleted,
          order: 1,
        );

        manager.add(option1);

        final ids = manager.allOptions.map((o) => o.id).toList();
        expect(ids, equals(['category', 'completed', 'priority']));
      });

      test('should subscribe to option changes', () {
        final manager = GroupManager<Task>();
        var notifyCount = 0;
        manager.addChangeListener(() => notifyCount++);

        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          order: 0,
        );

        manager.add(option);
        notifyCount = 0;

        option.enabled = false;

        expect(notifyCount, equals(1));
      });

      test('should re-sort when option order changes', () {
        final option1 = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          order: 0,
        );
        final option2 = GroupOption<Task, int>(
          id: 'priority',
          valueBuilder: (task) => task.priority,
          order: 1,
        );

        final manager = GroupManager<Task>(options: [option1, option2]);

        var ids = manager.allOptions.map((o) => o.id).toList();
        expect(ids, equals(['category', 'priority']));

        option1.order = 2;

        ids = manager.allOptions.map((o) => o.id).toList();
        expect(ids, equals(['priority', 'category']));
      });

      test('should unsubscribe from old option when replacing', () {
        final original = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        final manager = GroupManager<Task>(options: [original]);

        final replacement = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        manager.add(replacement, replace: true);

        var notifyCount = 0;
        manager.addChangeListener(() => notifyCount++);

        original.enabled = false;

        expect(notifyCount, equals(0));
      });
    });

    group('remove', () {
      test('should remove existing option and notify', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        final manager = GroupManager<Task>(options: [option]);

        var notified = false;
        manager.addChangeListener(() => notified = true);

        final removed = manager.remove('category');

        expect(removed, equals(option));
        expect(manager.isEmpty, isTrue);
        expect(notified, isTrue);
      });

      test('should return null when removing non-existent option', () {
        final manager = GroupManager<Task>();

        var notified = false;
        manager.addChangeListener(() => notified = true);

        final removed = manager.remove('nonexistent');

        expect(removed, isNull);
        expect(notified, isFalse);
      });

      test('should unsubscribe from removed option', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        final manager = GroupManager<Task>(options: [option]);

        manager.remove('category');

        var notifyCount = 0;
        manager.addChangeListener(() => notifyCount++);

        option.enabled = false;

        expect(notifyCount, equals(0));
      });
    });

    group('clear', () {
      test('should remove all options and notify', () {
        final option1 = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );
        final option2 = GroupOption<Task, int>(
          id: 'priority',
          valueBuilder: (task) => task.priority,
        );

        final manager = GroupManager<Task>(options: [option1, option2]);

        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.clear();

        expect(manager.isEmpty, isTrue);
        expect(manager.length, equals(0));
        expect(notified, isTrue);
      });

      test('should do nothing when already empty', () {
        final manager = GroupManager<Task>();

        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.clear();

        expect(manager.isEmpty, isTrue);
        expect(notified, isFalse);
      });

      test('should unsubscribe from all cleared options', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        final manager = GroupManager<Task>(options: [option]);
        manager.clear();

        var notifyCount = 0;
        manager.addChangeListener(() => notifyCount++);

        option.enabled = false;

        expect(notifyCount, equals(0));
      });
    });

    group('allOptions', () {
      test('should return all options including disabled', () {
        final enabled = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          enabled: true,
        );
        final disabled = GroupOption<Task, int>(
          id: 'priority',
          valueBuilder: (task) => task.priority,
          enabled: false,
        );

        final manager = GroupManager<Task>(options: [enabled, disabled]);

        expect(manager.allOptions.length, equals(2));
      });

      test('should return options in sorted order', () {
        final option2 = GroupOption<Task, int>(
          id: 'priority',
          valueBuilder: (task) => task.priority,
          order: 2,
        );
        final option0 = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          order: 0,
        );

        final manager = GroupManager<Task>(options: [option2, option0]);

        final orders = manager.allOptions.map((o) => o.order).toList();
        expect(orders, equals([0, 2]));
      });
    });

    group('options', () {
      test('should return only enabled options', () {
        final enabled1 = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          enabled: true,
        );
        final disabled = GroupOption<Task, int>(
          id: 'priority',
          valueBuilder: (task) => task.priority,
          enabled: false,
        );
        final enabled2 = GroupOption<Task, bool>(
          id: 'completed',
          valueBuilder: (task) => task.isCompleted,
          enabled: true,
        );

        final manager = GroupManager<Task>(
          options: [enabled1, disabled, enabled2],
        );

        final ids = manager.options.map((o) => o.id).toList();
        expect(ids, equals(['category', 'completed']));
      });

      test('should update when option enabled state changes', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          enabled: true,
        );

        final manager = GroupManager<Task>(options: [option]);

        expect(manager.options.length, equals(1));

        option.enabled = false;

        expect(manager.options.length, equals(0));
      });
    });

    group('optionById', () {
      test('should return option with matching id', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          label: 'My Category',
        );

        final manager = GroupManager<Task>(options: [option]);

        final found = manager.optionById('category');

        expect(found, equals(option));
        expect(found?.label, equals('My Category'));
      });

      test('should return null when id not found', () {
        final manager = GroupManager<Task>();

        final found = manager.optionById('nonexistent');

        expect(found, isNull);
      });
    });

    group('hasActiveGroups', () {
      test('should return true when at least one option is enabled', () {
        final enabled = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          enabled: true,
        );
        final disabled = GroupOption<Task, int>(
          id: 'priority',
          valueBuilder: (task) => task.priority,
          enabled: false,
        );

        final manager = GroupManager<Task>(options: [enabled, disabled]);

        expect(manager.hasActiveGroups, isTrue);
      });

      test('should return false when no options are enabled', () {
        final disabled = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
          enabled: false,
        );

        final manager = GroupManager<Task>(options: [disabled]);

        expect(manager.hasActiveGroups, isFalse);
      });

      test('should return false when no options exist', () {
        final manager = GroupManager<Task>();

        expect(manager.hasActiveGroups, isFalse);
      });
    });

    group('length, isEmpty, isNotEmpty', () {
      test('should reflect option count', () {
        final manager = GroupManager<Task>();

        expect(manager.length, equals(0));
        expect(manager.isEmpty, isTrue);
        expect(manager.isNotEmpty, isFalse);

        manager.add(
          GroupOption<Task, String>(
            id: 'category',
            valueBuilder: (task) => task.category,
          ),
        );

        expect(manager.length, equals(1));
        expect(manager.isEmpty, isFalse);
        expect(manager.isNotEmpty, isTrue);

        manager.add(
          GroupOption<Task, int>(
            id: 'priority',
            valueBuilder: (task) => task.priority,
          ),
        );

        expect(manager.length, equals(2));

        manager.remove('category');

        expect(manager.length, equals(1));

        manager.remove('priority');

        expect(manager.length, equals(0));
        expect(manager.isEmpty, isTrue);
      });
    });

    group('dispose', () {
      test('should clear all listeners', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        final manager = GroupManager<Task>(options: [option]);

        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.dispose();

        manager.add(
          GroupOption<Task, int>(
            id: 'priority',
            valueBuilder: (task) => task.priority,
          ),
        );

        expect(notified, isFalse);
      });

      test('should unsubscribe from all options', () {
        final option = GroupOption<Task, String>(
          id: 'category',
          valueBuilder: (task) => task.category,
        );

        final manager = GroupManager<Task>(options: [option]);

        var notifyCount = 0;
        manager.addChangeListener(() => notifyCount++);

        manager.dispose();

        option.enabled = false;

        expect(notifyCount, equals(0));
      });
    });

    group('listener management', () {
      test('should support multiple listeners', () {
        final manager = GroupManager<Task>();
        var count1 = 0;
        var count2 = 0;

        manager.addChangeListener(() => count1++);
        manager.addChangeListener(() => count2++);

        manager.add(
          GroupOption<Task, String>(
            id: 'category',
            valueBuilder: (task) => task.category,
          ),
        );

        expect(count1, equals(1));
        expect(count2, equals(1));
      });

      test('should allow removing listeners', () {
        final manager = GroupManager<Task>();
        var notified = false;
        void listener() => notified = true;

        manager.addChangeListener(listener);
        manager.removeChangeListener(listener);

        manager.add(
          GroupOption<Task, String>(
            id: 'category',
            valueBuilder: (task) => task.category,
          ),
        );

        expect(notified, isFalse);
      });

      test('should report hasListeners correctly', () {
        final manager = GroupManager<Task>();

        expect(manager.hasListeners, isFalse);

        void listener() {}
        manager.addChangeListener(listener);

        expect(manager.hasListeners, isTrue);

        manager.removeChangeListener(listener);

        expect(manager.hasListeners, isFalse);
      });
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Type Alias Tests
  // ══════════════════════════════════════════════════════════════════════════

  group('Type Aliases', () {
    test('should work with String values for GroupByString', () {
      final option = GroupByString<Task>(
        id: 'category',
        valueBuilder: (task) => task.category,
      );

      const task = Task(id: '1', category: 'Work');
      expect(option.groupKeyFor(task), equals('Work'));
    });

    test('should work with int values for GroupByInt', () {
      final option = GroupByInt<Task>(
        id: 'priority',
        valueBuilder: (task) => task.priority,
      );

      const task = Task(id: '1', category: 'Work', priority: 5);
      expect(option.groupKeyFor(task), equals('5'));
    });

    test('should work with double values for GroupByDouble', () {
      final option = GroupByDouble<Task>(
        id: 'price',
        valueBuilder: (task) => task.price,
      );

      const task = Task(id: '1', category: 'Work', price: 99.99);
      expect(option.groupKeyFor(task), equals('99.99'));
    });

    test('should work with bool values for GroupByBool', () {
      final option = GroupByBool<Task>(
        id: 'completed',
        valueBuilder: (task) => task.isCompleted,
      );

      const incomplete = Task(id: '1', category: 'Work');
      const complete = Task(id: '2', category: 'Work', isCompleted: true);

      expect(option.groupKeyFor(incomplete), equals('false'));
      expect(option.groupKeyFor(complete), equals('true'));
    });

    test('should work with DateTime values for GroupByDate', () {
      final option = GroupByDate<Task>(
        id: 'date',
        valueBuilder: (task) => task.createdAt!,
        keyBuilder: (date) => '${date.year}-${date.month}',
      );

      final task = Task(
        id: '1',
        category: 'Work',
        createdAt: DateTime(2024, 3, 15),
      );

      expect(option.groupKeyFor(task), equals('2024-3'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Integration Tests
  // ══════════════════════════════════════════════════════════════════════════

  group('Integration', () {
    test('should support hierarchical grouping workflow', () {
      final categoryOption = GroupOption<Task, String>(
        id: 'category',
        valueBuilder: (task) => task.category,
        order: 0,
      );

      final priorityOption = GroupOption<Task, int>(
        id: 'priority',
        valueBuilder: (task) => task.priority,
        order: 1,
        keyBuilder: (p) => p >= 3 ? 'high' : 'low',
      );

      final manager = GroupManager<Task>(
        options: [priorityOption, categoryOption],
      );

      final tasks = [
        const Task(id: '1', category: 'Work', priority: 5),
        const Task(id: '2', category: 'Work', priority: 1),
        const Task(id: '3', category: 'Home', priority: 4),
      ];

      for (final task in tasks) {
        final categoryKey = categoryOption.groupKeyFor(task);
        final priorityKey = priorityOption.groupKeyFor(task);

        if (task.category == 'Work') {
          expect(categoryKey, equals('Work'));
        }
        if (task.priority >= 3) {
          expect(priorityKey, equals('high'));
        } else {
          expect(priorityKey, equals('low'));
        }
      }

      expect(manager.options.first.id, equals('category'));
      expect(manager.options.last.id, equals('priority'));
    });

    test('should support dynamic hierarchy reordering', () {
      final categoryOption = GroupOption<Task, String>(
        id: 'category',
        valueBuilder: (task) => task.category,
        order: 0,
      );

      final statusOption = GroupOption<Task, bool>(
        id: 'completed',
        valueBuilder: (task) => task.isCompleted,
        order: 1,
      );

      final manager = GroupManager<Task>(
        options: [categoryOption, statusOption],
      );

      var hierarchyOrder = manager.options.map((o) => o.id).toList();
      expect(hierarchyOrder, equals(['category', 'completed']));

      categoryOption.order = 2;
      statusOption.order = 1;

      hierarchyOrder = manager.options.map((o) => o.id).toList();
      expect(hierarchyOrder, equals(['completed', 'category']));
    });

    test('should work with enum-based grouping', () {
      final statusOption = GroupOption<Ticket, Status>(
        id: 'status',
        valueBuilder: (ticket) => ticket.status,
        keyBuilder: (status) => status.name,
      );

      final tickets = [
        const Ticket(id: '1', status: Status.open, category: 'Bug'),
        const Ticket(id: '2', status: Status.closed, category: 'Feature'),
        const Ticket(id: '3', status: Status.inProgress, category: 'Bug'),
      ];

      final groups = <String, List<Ticket>>{};
      for (final ticket in tickets) {
        final key = statusOption.groupKeyFor(ticket)!;
        groups.putIfAbsent(key, () => []).add(ticket);
      }

      expect(groups['open']?.length, equals(1));
      expect(groups['closed']?.length, equals(1));
      expect(groups['inProgress']?.length, equals(1));
    });

    test('should filter disabled options from active grouping', () {
      final category = GroupOption<Task, String>(
        id: 'category',
        valueBuilder: (task) => task.category,
        enabled: true,
        order: 0,
      );

      final priority = GroupOption<Task, int>(
        id: 'priority',
        valueBuilder: (task) => task.priority,
        enabled: false,
        order: 1,
      );

      final completed = GroupOption<Task, bool>(
        id: 'completed',
        valueBuilder: (task) => task.isCompleted,
        enabled: true,
        order: 2,
      );

      final manager = GroupManager<Task>(
        options: [category, priority, completed],
      );

      expect(manager.allOptions.length, equals(3));
      expect(manager.options.length, equals(2));

      final activeIds = manager.options.map((o) => o.id).toList();
      expect(activeIds, equals(['category', 'completed']));
    });
  });

  group('GroupOption.multi', () {
    test('should create multi-value option', () {
      final tagsOption = GroupOption<Task, String>.multi(
        id: 'tags',
        valuesBuilder: (task) => task.tags,
      );

      expect(tagsOption.id, equals('tags'));
      expect(tagsOption.isMultiValue, isTrue);
    });

    test('should return multiple keys from groupKeysFor', () {
      final tagsOption = GroupOption<Task, String>.multi(
        id: 'tags',
        valuesBuilder: (task) => task.tags,
      );

      const task = Task(
        id: '1',
        title: 'Test',
        category: 'Work',
        priority: 1,
        tags: ['urgent', 'backend'],
      );

      final keys = tagsOption.groupKeysFor(task);
      expect(keys, containsAll(['urgent', 'backend']));
      expect(keys.length, equals(2));
    });

    test('should return empty list from groupKeysFor for null values', () {
      final tagsOption = GroupOption<Task, String>.multi(
        id: 'tags',
        valuesBuilder: (task) => task.tags,
      );

      const task = Task(
        id: '1',
        title: 'Test',
        category: 'Work',
        priority: 1,
      );

      expect(tagsOption.groupKeysFor(task), isEmpty);
    });

    test('should use keyBuilder in groupKeysFor when provided', () {
      final tagsOption = GroupOption<Task, String>.multi(
        id: 'tags',
        valuesBuilder: (task) => task.tags,
        keyBuilder: (tag) => tag.toUpperCase(),
      );

      const task = Task(
        id: '1',
        title: 'Test',
        category: 'Work',
        priority: 1,
        tags: ['urgent'],
      );

      expect(tagsOption.groupKeysFor(task), equals(['URGENT']));
    });

    test('should return first value from valueBuilder for multi-value option',
        () {
      final tagsOption = GroupOption<Task, String>.multi(
        id: 'tags',
        valuesBuilder: (task) => task.tags,
      );

      const task = Task(
        id: '1',
        title: 'Test',
        category: 'Work',
        priority: 1,
        tags: ['first', 'second'],
      );

      expect(tagsOption.valueBuilder(task), equals('first'));
    });

    test('should return null from valueBuilder for empty values', () {
      final tagsOption = GroupOption<Task, String>.multi(
        id: 'tags',
        valuesBuilder: (task) => task.tags,
      );

      const task = Task(
        id: '1',
        title: 'Test',
        category: 'Work',
        priority: 1,
        tags: [],
      );

      expect(tagsOption.valueBuilder(task), isNull);
    });

    test('should return null from valueBuilder for null values', () {
      final tagsOption = GroupOption<Task, String>.multi(
        id: 'tags',
        valuesBuilder: (task) => task.tags,
      );

      const task = Task(
        id: '1',
        title: 'Test',
        category: 'Work',
        priority: 1,
      );

      expect(tagsOption.valueBuilder(task), isNull);
    });

    test('should support sortOption in multi option', () {
      final sortOption = ValueSortOption<String, String>(
        id: 'alpha',
        sortIdentifier: (tag) => tag,
      );

      final tagsOption = GroupOption<Task, String>.multi(
        id: 'tags',
        valuesBuilder: (task) => task.tags,
        sortOption: sortOption,
      );

      expect(tagsOption.sortOption, equals(sortOption));
    });
  });

  group('GroupManager.restoreState', () {
    test('should restore enabled options from snapshot', () {
      final category = GroupOption<Task, String>(
        id: 'category',
        valueBuilder: (task) => task.category,
        enabled: false,
      );

      final priority = GroupOption<Task, int>(
        id: 'priority',
        valueBuilder: (task) => task.priority,
        enabled: true,
      );

      final manager = GroupManager<Task>(options: [category, priority]);

      // Restore snapshot that enables category and disables priority
      final snapshot = GroupSnapshot.fromData(activeIds: ['category']);
      manager.restoreState(snapshot);

      expect(category.enabled, isTrue);
      expect(priority.enabled, isFalse);
    });

    test('should restore option orders from snapshot', () {
      final category = GroupOption<Task, String>(
        id: 'category',
        valueBuilder: (task) => task.category,
        order: 0,
      );

      final priority = GroupOption<Task, int>(
        id: 'priority',
        valueBuilder: (task) => task.priority,
        order: 1,
      );

      final manager = GroupManager<Task>(options: [category, priority]);

      // Restore snapshot with custom orders (priority before category)
      final snapshot = GroupSnapshot.fromData(
        activeIds: ['category', 'priority'],
        orders: {'category': 10, 'priority': 5},
      );
      manager.restoreState(snapshot);

      // Orders should be restored from snapshot
      expect(category.order, equals(10));
      expect(priority.order, equals(5));
    });

    test('should notify listeners after restoreState', () {
      final option = GroupOption<Task, String>(
        id: 'category',
        valueBuilder: (task) => task.category,
      );

      final manager = GroupManager<Task>(options: [option]);
      var notified = false;
      manager.addChangeListener(() => notified = true);

      final snapshot = GroupSnapshot.fromData(activeIds: ['category']);
      manager.restoreState(snapshot);

      expect(notified, isTrue);
    });
  });

  group('GroupManager.reorder', () {
    test('should reorder options by new order values', () {
      final category = GroupOption<Task, String>(
        id: 'category',
        valueBuilder: (task) => task.category,
        order: 0,
      );

      final priority = GroupOption<Task, int>(
        id: 'priority',
        valueBuilder: (task) => task.priority,
        order: 1,
      );

      final manager = GroupManager<Task>(options: [category, priority]);

      // Initially category is first (order 0)
      expect(manager.options.first.id, equals('category'));

      // Reorder to make priority first
      manager.reorder({'category': 1, 'priority': 0});

      expect(manager.options.first.id, equals('priority'));
    });

    test('should do nothing on reorder for empty map', () {
      final option = GroupOption<Task, String>(
        id: 'category',
        valueBuilder: (task) => task.category,
      );

      final manager = GroupManager<Task>(options: [option]);
      var notified = false;
      manager.addChangeListener(() => notified = true);

      manager.reorder({});

      expect(notified, isFalse);
    });

    test('should do nothing on reorder for non-existent options', () {
      final option = GroupOption<Task, String>(
        id: 'category',
        valueBuilder: (task) => task.category,
      );

      final manager = GroupManager<Task>(options: [option]);
      var notified = false;
      manager.addChangeListener(() => notified = true);

      manager.reorder({'nonexistent': 1});

      expect(notified, isFalse);
    });

    test('should do nothing on reorder when order unchanged', () {
      final option = GroupOption<Task, String>(
        id: 'category',
        valueBuilder: (task) => task.category,
        order: 0,
      );

      final manager = GroupManager<Task>(options: [option]);
      var notified = false;
      manager.addChangeListener(() => notified = true);

      manager.reorder({'category': 0}); // Same order

      expect(notified, isFalse);
    });

    test('should notify on reorder when order changes', () {
      final category = GroupOption<Task, String>(
        id: 'category',
        valueBuilder: (task) => task.category,
        order: 0,
      );

      final priority = GroupOption<Task, int>(
        id: 'priority',
        valueBuilder: (task) => task.priority,
        order: 1,
      );

      final manager = GroupManager<Task>(options: [category, priority]);
      var notified = false;
      manager.addChangeListener(() => notified = true);

      manager.reorder({'category': 1});

      expect(notified, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // GroupSnapshot Tests
  // ══════════════════════════════════════════════════════════════════════════

  group('GroupSnapshot', () {
    group('constructor', () {
      test('empty() should create empty snapshot', () {
        const snapshot = GroupSnapshot.empty();

        expect(snapshot.isEmpty, isTrue);
        expect(snapshot.isNotEmpty, isFalse);
        expect(snapshot.length, equals(0));
        expect(snapshot.activeIds, isEmpty);
        expect(snapshot.orders, isEmpty);
      });

      test('fromData should create snapshot with activeIds', () {
        final snapshot = GroupSnapshot.fromData(
          activeIds: ['category', 'status'],
        );

        expect(snapshot.activeIds, equals(['category', 'status']));
        expect(snapshot.length, equals(2));
        expect(snapshot.isNotEmpty, isTrue);
        expect(snapshot.isEmpty, isFalse);
      });

      test('fromData should create snapshot with orders', () {
        final snapshot = GroupSnapshot.fromData(
          activeIds: ['category', 'status'],
          orders: {'category': 0, 'status': 1},
        );

        expect(snapshot.orders, equals({'category': 0, 'status': 1}));
      });
    });

    group('toJson', () {
      test('should serialize activeIds and orders', () {
        final snapshot = GroupSnapshot.fromData(
          activeIds: ['category', 'priority'],
          orders: {'category': 0, 'priority': 1},
        );

        final json = snapshot.toJson();

        expect(json['activeIds'], equals(['category', 'priority']));
        expect(json['orders'], equals({'category': 0, 'priority': 1}));
      });
    });

    group('fromJson', () {
      test('should deserialize activeIds and orders', () {
        final json = {
          'activeIds': ['category', 'status'],
          'orders': {'category': 0, 'status': 1},
        };

        final snapshot = GroupSnapshot.fromJson(json);

        expect(snapshot.activeIds, equals(['category', 'status']));
        expect(snapshot.orders, equals({'category': 0, 'status': 1}));
      });

      test('should return empty for null activeIds', () {
        final json = <String, dynamic>{};

        final snapshot = GroupSnapshot.fromJson(json);

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty for empty activeIds', () {
        final json = {'activeIds': <String>[]};

        final snapshot = GroupSnapshot.fromJson(json);

        expect(snapshot.isEmpty, isTrue);
      });

      test('should filter non-string values from activeIds', () {
        final json = {
          'activeIds': ['category', 123, 'status', true],
        };

        final snapshot = GroupSnapshot.fromJson(json);

        expect(snapshot.activeIds, equals(['category', 'status']));
      });

      test('should filter non-int values from orders', () {
        final json = {
          'activeIds': ['category', 'status'],
          'orders': {'category': 0, 'status': 'invalid', 'priority': 2.5},
        };

        final snapshot = GroupSnapshot.fromJson(json);

        expect(snapshot.orders, equals({'category': 0}));
      });
    });

    group('toQueryString', () {
      test('should return empty string for empty snapshot', () {
        const snapshot = GroupSnapshot.empty();

        expect(snapshot.toQueryString(), isEmpty);
      });

      test('should encode activeIds as comma-separated', () {
        final snapshot = GroupSnapshot.fromData(
          activeIds: ['category', 'status'],
        );

        final query = snapshot.toQueryString();

        expect(query, equals('group=category,status'));
      });

      test('should URL-encode special characters', () {
        final snapshot = GroupSnapshot.fromData(
          activeIds: ['cat/egory', 'sta&tus'],
        );

        final query = snapshot.toQueryString();

        expect(query, contains('cat%2Fegory'));
        expect(query, contains('sta%26tus'));
      });
    });

    group('fromQueryString', () {
      test('should return empty for empty query', () {
        final snapshot = GroupSnapshot.fromQueryString('');

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty for missing group param', () {
        final snapshot = GroupSnapshot.fromQueryString('foo=bar');

        expect(snapshot.isEmpty, isTrue);
      });

      test('should return empty for empty group value', () {
        final snapshot = GroupSnapshot.fromQueryString('group=');

        expect(snapshot.isEmpty, isTrue);
      });

      test('should parse comma-separated activeIds', () {
        final snapshot = GroupSnapshot.fromQueryString('group=category,status');

        expect(snapshot.activeIds, equals(['category', 'status']));
      });

      test('should assign orders based on position', () {
        final snapshot =
            GroupSnapshot.fromQueryString('group=category,status,priority');

        expect(snapshot.orders['category'], equals(0));
        expect(snapshot.orders['status'], equals(1));
        expect(snapshot.orders['priority'], equals(2));
      });

      test('should URL-decode special characters', () {
        final snapshot =
            GroupSnapshot.fromQueryString('group=cat%2Fegory,sta%26tus');

        expect(snapshot.activeIds, contains('cat/egory'));
        expect(snapshot.activeIds, contains('sta&tus'));
      });
    });

    group('equality', () {
      test('should be equal for same activeIds', () {
        final snapshot1 = GroupSnapshot.fromData(activeIds: ['a', 'b']);
        final snapshot2 = GroupSnapshot.fromData(activeIds: ['a', 'b']);

        expect(snapshot1, equals(snapshot2));
        expect(snapshot1.hashCode, equals(snapshot2.hashCode));
      });

      test('should not be equal for different activeIds', () {
        final snapshot1 = GroupSnapshot.fromData(activeIds: ['a', 'b']);
        final snapshot2 = GroupSnapshot.fromData(activeIds: ['a', 'c']);

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('should not be equal for different lengths', () {
        final snapshot1 = GroupSnapshot.fromData(activeIds: ['a', 'b']);
        final snapshot2 = GroupSnapshot.fromData(activeIds: ['a']);

        expect(snapshot1, isNot(equals(snapshot2)));
      });

      test('should not be equal to non-GroupSnapshot', () {
        final snapshot = GroupSnapshot.fromData(activeIds: ['a']);

        expect(snapshot, isNot(equals('not a snapshot')));
        expect(snapshot, isNot(equals(42)));
      });

      test('identical snapshots should be equal', () {
        final snapshot = GroupSnapshot.fromData(activeIds: ['a', 'b']);

        expect(snapshot, equals(snapshot));
      });
    });

    group('toString', () {
      test('should include activeIds', () {
        final snapshot = GroupSnapshot.fromData(activeIds: ['a', 'b']);

        expect(snapshot.toString(), equals('GroupSnapshot([a, b])'));
      });
    });

    group('roundtrip', () {
      test('should roundtrip through JSON', () {
        final original = GroupSnapshot.fromData(
          activeIds: ['category', 'status'],
          orders: {'category': 0, 'status': 1},
        );

        final json = original.toJson();
        final restored = GroupSnapshot.fromJson(json);

        expect(restored.activeIds, equals(original.activeIds));
      });

      test('should roundtrip through query string', () {
        final original = GroupSnapshot.fromData(
          activeIds: ['category', 'status'],
        );

        final query = original.toQueryString();
        final restored = GroupSnapshot.fromQueryString(query);

        expect(restored.activeIds, equals(original.activeIds));
      });
    });
  });

  // ===========================================================================
  // GroupCriteria Additional Coverage Tests
  // ===========================================================================

  group('GroupCriteria', () {
    test('fromJson parses valid JSON', () {
      final json = {'id': 'category'};
      final criteria = GroupCriteria.fromJson(json);

      expect(criteria.id, equals('category'));
    });

    test('fromJson throws on invalid JSON', () {
      final json = {'invalid': 'data'};

      expect(
        () => GroupCriteria.fromJson(json),
        throwsFormatException,
      );
    });

    test('fromQueryParams parses group parameter', () {
      final params = {'group': 'status'};
      final criteria = GroupCriteria.fromQueryParams(params);

      expect(criteria, isNotNull);
      expect(criteria!.id, equals('status'));
    });

    test('fromQueryParams returns null for missing param', () {
      final criteria = GroupCriteria.fromQueryParams({});

      expect(criteria, isNull);
    });

    test('fromQueryParams returns null for empty param', () {
      final params = {'group': ''};
      final criteria = GroupCriteria.fromQueryParams(params);

      expect(criteria, isNull);
    });

    test('toJson converts to JSON map', () {
      const criteria = GroupCriteria(id: 'category');
      final json = criteria.toJson();

      expect(json['id'], equals('category'));
    });

    test('toString returns descriptive string', () {
      const criteria = GroupCriteria(id: 'category');
      final str = criteria.toString();

      expect(str, contains('GroupCriteria'));
      expect(str, contains('category'));
    });

    test('equality with same id', () {
      const criteria1 = GroupCriteria(id: 'category');
      const criteria2 = GroupCriteria(id: 'category');

      expect(criteria1, equals(criteria2));
      expect(criteria1.hashCode, equals(criteria2.hashCode));
    });

    test('equality with different id', () {
      const criteria1 = GroupCriteria(id: 'category');
      const criteria2 = GroupCriteria(id: 'status');

      expect(criteria1, isNot(equals(criteria2)));
    });

    test('equality with identical instance', () {
      const criteria = GroupCriteria(id: 'category');

      expect(criteria, equals(criteria));
    });

    test('equality with non-GroupCriteria', () {
      const criteria = GroupCriteria(id: 'category');

      expect(criteria, isNot(equals('category')));
      expect(criteria, isNot(equals(42)));
    });
  });
}
