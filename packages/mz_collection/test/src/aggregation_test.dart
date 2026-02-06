// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

import 'package:mz_collection/mz_collection.dart';
import 'package:test/test.dart';

void main() {
  group('Aggregation', () {
    group('count', () {
      test('should count items', () {
        final agg = Aggregation.count<int>(id: 'count', label: 'Count');

        expect(agg.compute([1, 2, 3, 4, 5]), 5);
        expect(agg.compute([]), 0);
        expect(agg.compute([1]), 1);
      });

      test('should have correct id and label', () {
        final agg = Aggregation.count<int>(id: 'count', label: 'Total Items');

        expect(agg.id, 'count');
        expect(agg.label, 'Total Items');
      });

      test('should return initialValue for empty list', () {
        final agg = Aggregation.count<int>(id: 'count');

        expect(agg.initialValue, 0);
        expect(agg.compute([]), 0);
      });
    });

    group('sum', () {
      test('should sum numeric values', () {
        final agg = Aggregation.sum<_Task>(
          id: 'total_hours',
          valueGetter: (t) => t.hours,
        );

        final tasks = [
          _Task(hours: 2.5),
          _Task(hours: 3),
          _Task(hours: 1.5),
        ];

        expect(agg.compute(tasks), 7.0);
      });

      test('should handle null values as zero', () {
        final agg = Aggregation.sum<_Task>(
          id: 'total_hours',
          valueGetter: (t) => t.hours,
        );

        final tasks = [
          _Task(hours: 2.5),
          _Task(),
          _Task(hours: 1.5),
        ];

        expect(agg.compute(tasks), 4.0);
      });

      test('should return 0 for empty list', () {
        final agg = Aggregation.sum<_Task>(
          id: 'total_hours',
          valueGetter: (t) => t.hours,
        );

        expect(agg.compute([]), 0.0);
      });
    });

    group('average', () {
      test('should compute average', () {
        final agg = Aggregation.average<_Task>(
          id: 'avg_score',
          valueGetter: (t) => t.score,
        );

        final tasks = [
          _Task(score: 80),
          _Task(score: 90),
          _Task(score: 100),
        ];

        expect(agg.compute(tasks), 90.0);
      });

      test('should exclude null values from average', () {
        final agg = Aggregation.average<_Task>(
          id: 'avg_score',
          valueGetter: (t) => t.score,
        );

        final tasks = [
          _Task(score: 80),
          _Task(),
          _Task(score: 100),
        ];

        expect(agg.compute(tasks), 90.0);
      });

      test('should return null for empty list', () {
        final agg = Aggregation.average<_Task>(
          id: 'avg_score',
          valueGetter: (t) => t.score,
        );

        expect(agg.compute([]), null);
      });

      test('should return null when all values are null', () {
        final agg = Aggregation.average<_Task>(
          id: 'avg_score',
          valueGetter: (t) => t.score,
        );

        final tasks = [
          _Task(),
          _Task(),
        ];

        expect(agg.compute(tasks), null);
      });
    });

    group('min', () {
      test('should find minimum value', () {
        final agg = Aggregation.min<_Task, num>(
          id: 'min_priority',
          valueGetter: (t) => t.priority,
        );

        final tasks = [
          _Task(priority: 3),
          _Task(priority: 1),
          _Task(priority: 2),
        ];

        expect(agg.compute(tasks), 1);
      });

      test('should exclude null values', () {
        final agg = Aggregation.min<_Task, num>(
          id: 'min_priority',
          valueGetter: (t) => t.priority,
        );

        final tasks = [
          _Task(priority: 3),
          _Task(),
          _Task(priority: 2),
        ];

        expect(agg.compute(tasks), 2);
      });

      test('should return null for empty list', () {
        final agg = Aggregation.min<_Task, num>(
          id: 'min_priority',
          valueGetter: (t) => t.priority,
        );

        expect(agg.compute([]), null);
      });

      test('should work with DateTime', () {
        final agg = Aggregation.min<_Task, DateTime>(
          id: 'earliest',
          valueGetter: (t) => t.createdAt,
        );

        final tasks = [
          _Task(createdAt: DateTime(2024, 3, 15)),
          _Task(createdAt: DateTime(2024)),
          _Task(createdAt: DateTime(2024, 6, 30)),
        ];

        expect(agg.compute(tasks), DateTime(2024));
      });
    });

    group('max', () {
      test('should find maximum value', () {
        final agg = Aggregation.max<_Task, num>(
          id: 'max_priority',
          valueGetter: (t) => t.priority,
        );

        final tasks = [
          _Task(priority: 3),
          _Task(priority: 1),
          _Task(priority: 5),
        ];

        expect(agg.compute(tasks), 5);
      });

      test('should exclude null values', () {
        final agg = Aggregation.max<_Task, num>(
          id: 'max_priority',
          valueGetter: (t) => t.priority,
        );

        final tasks = [
          _Task(priority: 3),
          _Task(),
          _Task(priority: 2),
        ];

        expect(agg.compute(tasks), 3);
      });

      test('should return null for empty list', () {
        final agg = Aggregation.max<_Task, num>(
          id: 'max_priority',
          valueGetter: (t) => t.priority,
        );

        expect(agg.compute([]), null);
      });
    });

    group('first', () {
      test('should return first item value', () {
        final agg = Aggregation.first<_Task, String>(
          id: 'first_status',
          valueGetter: (t) => t.status,
        );

        final tasks = [
          _Task(status: 'open'),
          _Task(status: 'closed'),
          _Task(status: 'pending'),
        ];

        expect(agg.compute(tasks), 'open');
      });

      test('should return null for empty list', () {
        final agg = Aggregation.first<_Task, String>(
          id: 'first_status',
          valueGetter: (t) => t.status,
        );

        expect(agg.compute([]), null);
      });
    });

    group('last', () {
      test('should return last item value', () {
        final agg = Aggregation.last<_Task, String>(
          id: 'last_status',
          valueGetter: (t) => t.status,
        );

        final tasks = [
          _Task(status: 'open'),
          _Task(status: 'closed'),
          _Task(status: 'pending'),
        ];

        expect(agg.compute(tasks), 'pending');
      });

      test('should return null for empty list', () {
        final agg = Aggregation.last<_Task, String>(
          id: 'last_status',
          valueGetter: (t) => t.status,
        );

        expect(agg.compute([]), null);
      });
    });

    group('distinct', () {
      test('should count distinct values', () {
        final agg = Aggregation.distinct<_Task, String>(
          id: 'unique_assignees',
          valueGetter: (t) => t.assignee,
        );

        final tasks = [
          _Task(assignee: 'Alice'),
          _Task(assignee: 'Bob'),
          _Task(assignee: 'Alice'),
          _Task(assignee: 'Charlie'),
          _Task(assignee: 'Bob'),
        ];

        expect(agg.compute(tasks), 3);
      });

      test('should exclude null values', () {
        final agg = Aggregation.distinct<_Task, String>(
          id: 'unique_assignees',
          valueGetter: (t) => t.assignee,
        );

        final tasks = [
          _Task(assignee: 'Alice'),
          _Task(),
          _Task(assignee: 'Bob'),
          _Task(),
        ];

        expect(agg.compute(tasks), 2);
      });

      test('should return 0 for empty list', () {
        final agg = Aggregation.distinct<_Task, String>(
          id: 'unique_assignees',
          valueGetter: (t) => t.assignee,
        );

        expect(agg.compute([]), 0);
      });
    });

    group('percentage', () {
      test('should compute percentage of matching items', () {
        final agg = Aggregation.percentage<_Task>(
          id: 'completion_rate',
          predicate: (t) => t.isComplete,
        );

        final tasks = [
          _Task(isComplete: true),
          _Task(isComplete: true),
          _Task(),
          _Task(isComplete: true),
        ];

        expect(agg.compute(tasks), 75.0);
      });

      test('should return 0 for empty list', () {
        final agg = Aggregation.percentage<_Task>(
          id: 'completion_rate',
          predicate: (t) => t.isComplete,
        );

        expect(agg.compute([]), 0.0);
      });

      test('should return 100 when all match', () {
        final agg = Aggregation.percentage<_Task>(
          id: 'completion_rate',
          predicate: (t) => t.isComplete,
        );

        final tasks = [
          _Task(isComplete: true),
          _Task(isComplete: true),
        ];

        expect(agg.compute(tasks), 100.0);
      });

      test('should return 0 when none match', () {
        final agg = Aggregation.percentage<_Task>(
          id: 'completion_rate',
          predicate: (t) => t.isComplete,
        );

        final tasks = [
          _Task(),
          _Task(),
        ];

        expect(agg.compute(tasks), 0.0);
      });
    });

    group('custom', () {
      test('should support custom aggregation function', () {
        final agg = Aggregation<_Task, String>(
          id: 'status_summary',
          aggregate: (items) {
            final open = items.where((t) => t.status == 'open').length;
            final closed = items.where((t) => t.status == 'closed').length;
            return '$open open, $closed closed';
          },
        );

        final tasks = [
          _Task(status: 'open'),
          _Task(status: 'closed'),
          _Task(status: 'open'),
        ];

        expect(agg.compute(tasks), '2 open, 1 closed');
      });
    });

    group('equality', () {
      test('should be equal by id', () {
        final agg1 = Aggregation.count<int>(id: 'count');
        final agg2 = Aggregation.count<int>(id: 'count');
        final agg3 = Aggregation.count<int>(id: 'other');

        expect(agg1, equals(agg2));
        expect(agg1, isNot(equals(agg3)));
      });

      test('hashCode should be consistent with equality', () {
        final agg1 = Aggregation.count<int>(id: 'count');
        final agg2 = Aggregation.count<int>(id: 'count');
        final agg3 = Aggregation.count<int>(id: 'other');

        expect(agg1.hashCode, equals(agg2.hashCode));
        expect(agg1.hashCode, isNot(equals(agg3.hashCode)));
      });
    });

    test('toString returns descriptive string', () {
      final agg = Aggregation.count<int>(id: 'my_count');
      expect(agg.toString(), contains('Aggregation'));
      expect(agg.toString(), contains('my_count'));
    });
  });

  group('AggregateResult', () {
    test('should provide access by id', () {
      const result = AggregateResult({
        'count': 42,
        'total': 1500.0,
        'avg': 35.7,
      });

      expect(result['count'], 42);
      expect(result['total'], 1500.0);
      expect(result['avg'], 35.7);
      expect(result['nonexistent'], null);
    });

    test('should provide typed access', () {
      const result = AggregateResult({
        'count': 42,
        'total': 1500.0,
      });

      expect(result.get<int>('count'), 42);
      expect(result.get<double>('total'), 1500.0);
      expect(result.get<String>('count'), null); // Wrong type
    });

    test('should check containsKey', () {
      const result = AggregateResult({'count': 42});

      expect(result.containsKey('count'), true);
      expect(result.containsKey('other'), false);
    });

    test('should provide keys and values', () {
      const result = AggregateResult({
        'count': 42,
        'total': 1500.0,
      });

      expect(result.keys, containsAll(['count', 'total']));
      expect(result.values, containsAll([42, 1500.0]));
    });

    test('should check isEmpty and isNotEmpty', () {
      const empty = AggregateResult.empty();
      const nonEmpty = AggregateResult({'count': 42});

      expect(empty.isEmpty, true);
      expect(empty.isNotEmpty, false);
      expect(nonEmpty.isEmpty, false);
      expect(nonEmpty.isNotEmpty, true);
    });

    test('should provide length', () {
      const result = AggregateResult({
        'count': 42,
        'total': 1500.0,
      });

      expect(result.length, 2);
    });

    test('should convert to map', () {
      const result = AggregateResult({
        'count': 42,
        'total': 1500.0,
      });

      final map = result.toMap();
      expect(map, {'count': 42, 'total': 1500.0});
    });

    test('should provide entries', () {
      const result = AggregateResult({
        'count': 42,
        'total': 1500.0,
      });

      final entries = result.entries.toList();
      expect(entries.length, 2);
      expect(entries.any((e) => e.key == 'count' && e.value == 42), isTrue);
      expect(
        entries.any((e) => e.key == 'total' && e.value == 1500.0),
        isTrue,
      );
    });

    test('toString returns descriptive string', () {
      const result = AggregateResult({'count': 42});
      expect(result.toString(), contains('AggregateResult'));
      expect(result.toString(), contains('count'));
      expect(result.toString(), contains('42'));
    });
  });

  group('AggregationManager', () {
    late AggregationManager<_Task> manager;

    setUp(() {
      manager = AggregationManager<_Task>(
        aggregations: [
          Aggregation.count<_Task>(id: 'count', label: 'Tasks'),
          Aggregation.sum<_Task>(
            id: 'total_hours',
            label: 'Total Hours',
            valueGetter: (t) => t.hours,
          ),
          Aggregation.average<_Task>(
            id: 'avg_score',
            label: 'Avg Score',
            valueGetter: (t) => t.score,
          ),
        ],
      );
    });

    test('should aggregate all values', () {
      final tasks = [
        _Task(hours: 2, score: 80),
        _Task(hours: 3, score: 90),
        _Task(hours: 5, score: 100),
      ];

      final result = manager.aggregate(tasks);

      expect(result['count'], 3);
      expect(result['total_hours'], 10.0);
      expect(result['avg_score'], 90.0);
    });

    test('should return empty result when no aggregations', () {
      final emptyManager = AggregationManager<_Task>();
      final result = emptyManager.aggregate([_Task()]);

      expect(result.isEmpty, true);
    });

    test('should get aggregation by id', () {
      expect(manager['count'], isNotNull);
      expect(manager['count']!.id, 'count');
      expect(manager['nonexistent'], null);
    });

    test('should add and remove aggregations', () {
      final newAgg = Aggregation.max<_Task, num>(
        id: 'max_priority',
        valueGetter: (t) => t.priority,
      );

      manager.add(newAgg);
      expect(manager['max_priority'], isNotNull);

      manager.remove('max_priority');
      expect(manager['max_priority'], null);
    });

    test('should clear all aggregations', () {
      expect(manager.isEmpty, false);
      manager.clear();
      expect(manager.isEmpty, true);
    });

    test('should compute single aggregation', () {
      final tasks = [
        _Task(hours: 2),
        _Task(hours: 3),
      ];

      final count = manager.computeOne<int>('count', tasks);
      expect(count, 2);

      final nonexistent = manager.computeOne<int>('nonexistent', tasks);
      expect(nonexistent, null);
    });

    test('should aggregate multiple groups', () {
      final group1 = [_Task(hours: 2), _Task(hours: 3)];
      final group2 = [_Task(hours: 5)];

      final results = manager.aggregateGroups({
        'group1': group1,
        'group2': group2,
      });

      expect(results['group1']!['count'], 2);
      expect(results['group1']!['total_hours'], 5.0);
      expect(results['group2']!['count'], 1);
      expect(results['group2']!['total_hours'], 5.0);
    });

    test('should notify listeners on changes', () {
      var notified = false;
      manager
        ..addChangeListener(() => notified = true)
        ..add(Aggregation.count<_Task>(id: 'new'));
      expect(notified, true);

      notified = false;
      manager.remove('new');
      expect(notified, true);

      notified = false;
      manager.clear();
      // clear() notifies only if not empty, but we just removed the only
      // extra aggregation
    });

    test('should provide aggregations list', () {
      expect(manager.aggregations.length, 3);
      expect(manager.length, 3);
    });

    test('should check isNotEmpty', () {
      expect(manager.isNotEmpty, isTrue);
      manager.clear();
      expect(manager.isNotEmpty, isFalse);
    });

    test('should get typed aggregation', () {
      final countAgg = manager.getAggregation<int>('count');
      expect(countAgg, isNotNull);
      expect(countAgg!.id, 'count');

      // Wrong type returns null
      final wrongType = manager.getAggregation<String>('count');
      expect(wrongType, isNull);

      // Non-existent returns null
      final nonExistent = manager.getAggregation<int>('nonexistent');
      expect(nonExistent, isNull);
    });

    test('should add multiple aggregations with addAll', () {
      final newManager = AggregationManager<_Task>();
      expect(newManager.isEmpty, isTrue);

      newManager.addAll([
        Aggregation.count<_Task>(id: 'count1'),
        Aggregation.count<_Task>(id: 'count2'),
      ]);

      expect(newManager.length, 2);
      expect(newManager['count1'], isNotNull);
      expect(newManager['count2'], isNotNull);
    });

    test('should dispose properly', () {
      final disposableManager = AggregationManager<_Task>(
        aggregations: [Aggregation.count<_Task>(id: 'count')],
      );
      expect(disposableManager.isEmpty, isFalse);

      disposableManager.dispose();
      expect(disposableManager.isEmpty, isTrue);
    });

    test('toString returns descriptive string', () {
      expect(manager.toString(), contains('AggregationManager'));
      expect(manager.toString(), contains('3'));
    });
  });
}

/// Test helper class
class _Task {
  _Task({
    this.hours,
    this.score,
    this.priority,
    this.status,
    this.assignee,
    this.isComplete = false,
    this.createdAt,
  });

  final double? hours;
  final int? score;
  final int? priority;
  final String? status;
  final String? assignee;
  final bool isComplete;
  final DateTime? createdAt;
}
