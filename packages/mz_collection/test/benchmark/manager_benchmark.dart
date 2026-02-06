// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

// Benchmarks use print statements for results output.
// ignore_for_file: avoid_print

// Benchmark loops are intentional for timing measurements.
// ignore_for_file: prefer_foreach

import 'package:mz_collection/src/filter_manager.dart';
import 'package:mz_collection/src/group_manager.dart';
import 'package:mz_collection/src/selection_manager.dart';
import 'package:mz_collection/src/sort_manager.dart';

import 'benchmark_harness.dart';

/// Benchmarks for Managers (Filter, Sort, Group, Selection).
void main() {
  print('MZ Collection - Manager Benchmarks');
  print('===================================\n');

  _runFilterManagerBenchmarks();
  _runSortManagerBenchmarks();
  _runGroupManagerBenchmarks();
  _runSelectionManagerBenchmarks();
}

void _runFilterManagerBenchmarks() {
  final suite = BenchmarkSuite(
    'FilterManager Operations',
    config: const BenchmarkConfig(
      warmupIterations: 5,
      measureIterations: 50,
      itemCounts: [100, 1000, 10000, 100000],
    ),
  );

  for (final count in suite.config.itemCounts) {
    final items = BenchmarkItem.generate(count);

    // Benchmark: Single filter apply
    suite.run(
      name: 'Filter.apply (single)',
      itemCount: count,
      setup: () {},
      action: () {
        final filter = Filter<BenchmarkItem, String>(
          id: 'category',
          test: (item, value) => item.category == value,
        );
        filter.add('A');

        for (final item in items) {
          filter.apply(item);
        }
      },
    );

    // Benchmark: Multi-value filter
    suite.run(
      name: 'Filter.apply (multi-value)',
      itemCount: count,
      setup: () {},
      action: () {
        final filter = Filter<BenchmarkItem, String>(
          id: 'category',
          test: (item, value) => item.category == value,
        );
        filter.add('A');
        filter.add('B');
        filter.add('C');

        for (final item in items) {
          filter.apply(item);
        }
      },
    );

    // Benchmark: FilterManager with multiple filters
    suite.run(
      name: 'FilterManager.apply (3 filters)',
      itemCount: count,
      setup: () {},
      action: () {
        final manager = FilterManager<BenchmarkItem>();

        final categoryFilter = Filter<BenchmarkItem, String>(
          id: 'category',
          test: (item, value) => item.category == value,
        );
        categoryFilter.add('A');

        final valueFilter = Filter<BenchmarkItem, int>(
          id: 'value',
          test: (item, value) => item.value >= value,
        );
        valueFilter.add(100);

        final nameFilter = Filter<BenchmarkItem, String>(
          id: 'name',
          test: (item, value) => item.name.contains(value),
        );
        nameFilter.add('Item');

        manager.addAll([categoryFilter, valueFilter, nameFilter]);

        for (final item in items) {
          manager.apply(item);
        }
      },
    );

    // Benchmark: Complex filter expression (AND/OR)
    suite.run(
      name: 'FilterExpression (AND + OR)',
      itemCount: count,
      setup: () {},
      action: () {
        final categoryFilter = Filter<BenchmarkItem, String>(
          id: 'category',
          test: (item, value) => item.category == value,
        );
        categoryFilter.add('A');

        final valueFilter = Filter<BenchmarkItem, int>(
          id: 'value',
          test: (item, value) => item.value >= value,
        );
        valueFilter.add(500);

        final expression = FilterAnd<BenchmarkItem>([
          FilterRef(categoryFilter),
          FilterOr<BenchmarkItem>([
            FilterRef(valueFilter),
            FilterNot(FilterRef(categoryFilter)),
          ]),
        ]);

        for (final item in items) {
          expression.apply(item);
        }
      },
    );

    // Benchmark: items.where with filter
    suite.runOnce(
      name: 'Iterable.where + Filter',
      itemCount: count,
      setup: () {},
      action: () {
        final filter = Filter<BenchmarkItem, String>(
          id: 'category',
          test: (item, value) => item.category == value,
        );
        filter.add('A');

        final filtered = items.where(filter.apply).toList();
        if (filtered.isEmpty) print('empty');
      },
    );
  }

  suite.printResults();
  suite.printScalingResults();
}

void _runSortManagerBenchmarks() {
  final suite = BenchmarkSuite(
    'SortManager Operations',
    config: const BenchmarkConfig(
      warmupIterations: 5,
      measureIterations: 50,
      itemCounts: [100, 1000, 10000, 100000],
    ),
  );

  for (final count in suite.config.itemCounts) {
    final items = BenchmarkItem.generate(count);

    // Benchmark: Single sort option
    suite.runOnce(
      name: 'SortManager (single sort)',
      itemCount: count,
      setup: () {},
      action: () {
        final manager = SortManager<BenchmarkItem>();
        final valueSort = ValueSortOption<BenchmarkItem, int>(
          id: 'value',
          sortIdentifier: (item) => item.value,
        );
        manager.addAll([valueSort]);
        manager.setCurrent(valueSort);

        final sorted = items.toList()..sort(manager.compare);
        if (sorted.isEmpty) print('empty');
      },
    );

    // Benchmark: Multi-level sort
    suite.runOnce(
      name: 'SortManager (3-level sort)',
      itemCount: count,
      setup: () {},
      action: () {
        final manager = SortManager<BenchmarkItem>();

        final categorySort = ValueSortOption<BenchmarkItem, String>(
          id: 'category',
          sortIdentifier: (item) => item.category,
        );
        final valueSort = ValueSortOption<BenchmarkItem, int>(
          id: 'value',
          sortIdentifier: (item) => item.value,
        );
        final nameSort = ValueSortOption<BenchmarkItem, String>(
          id: 'name',
          sortIdentifier: (item) => item.name,
        );

        manager.addAll([categorySort, valueSort, nameSort]);
        manager.setCurrent(categorySort);
        manager.add(valueSort);
        manager.add(nameSort);

        final sorted = items.toList()..sort(manager.compare);
        if (sorted.isEmpty) print('empty');
      },
    );

    // Benchmark: Sort comparator only (no list sort)
    suite.run(
      name: 'SortManager.compare (per call)',
      itemCount: count,
      setup: () {},
      action: () {
        final manager = SortManager<BenchmarkItem>();
        final valueSort = ValueSortOption<BenchmarkItem, int>(
          id: 'value',
          sortIdentifier: (item) => item.value,
        );
        manager.addAll([valueSort]);
        manager.setCurrent(valueSort);

        // Compare pairs
        for (var i = 0; i < count - 1; i++) {
          manager.compare(items[i], items[i + 1]);
        }
      },
    );

    // Benchmark: Descending sort
    suite.runOnce(
      name: 'SortManager (descending)',
      itemCount: count,
      setup: () {},
      action: () {
        final manager = SortManager<BenchmarkItem>();
        final valueSort = ValueSortOption<BenchmarkItem, int>(
          id: 'value',
          sortIdentifier: (item) => item.value,
        );
        manager.addAll([valueSort]);
        manager.setCurrent(valueSort);
        manager.setSortOrder(SortOrder.descending);

        final sorted = items.toList()..sort(manager.compare);
        if (sorted.isEmpty) print('empty');
      },
    );
  }

  suite.printResults();
  suite.printScalingResults();
}

void _runGroupManagerBenchmarks() {
  final suite = BenchmarkSuite(
    'GroupManager Operations',
    config: const BenchmarkConfig(
      warmupIterations: 5,
      measureIterations: 50,
    ),
  );

  for (final count in suite.config.itemCounts) {
    final items = BenchmarkItem.generate(count);

    // Benchmark: Single-level grouping
    suite.runOnce(
      name: 'GroupManager (1-level)',
      itemCount: count,
      setup: () {},
      action: () {
        final manager = GroupManager<BenchmarkItem>(
          options: [
            GroupOption<BenchmarkItem, String>(
              id: 'category',
              valueBuilder: (item) => item.category,
            ),
          ],
        );

        // Simulate grouping
        final groups = <String, List<BenchmarkItem>>{};
        for (final item in items) {
          final key = manager.options.first.groupKeyFor(item) ?? '';
          groups.putIfAbsent(key, () => []).add(item);
        }
        if (groups.isEmpty) print('empty');
      },
    );

    // Benchmark: Multi-level grouping
    suite.runOnce(
      name: 'GroupManager (2-level)',
      itemCount: count,
      setup: () {},
      action: () {
        final manager = GroupManager<BenchmarkItem>(
          options: [
            GroupOption<BenchmarkItem, String>(
              id: 'category',
              order: 1,
              valueBuilder: (item) => item.category,
            ),
            GroupOption<BenchmarkItem, int>(
              id: 'value_range',
              order: 2,
              valueBuilder: (item) => item.value ~/ 100,
            ),
          ],
        );

        // Simulate 2-level grouping
        final groups = <String, Map<String, List<BenchmarkItem>>>{};
        for (final item in items) {
          final key1 = manager.options.first.groupKeyFor(item) ?? '';
          final key2 = manager.options.toList()[1].groupKeyFor(item) ?? '';
          groups
              .putIfAbsent(key1, () => {})
              .putIfAbsent(key2, () => [])
              .add(item);
        }
        if (groups.isEmpty) print('empty');
      },
    );

    // Benchmark: GroupOption key extraction
    suite.run(
      name: 'GroupOption.groupKeyFor',
      itemCount: count,
      setup: () {},
      action: () {
        final option = GroupOption<BenchmarkItem, String>(
          id: 'category',
          valueBuilder: (item) => item.category,
        );

        for (final item in items) {
          option.groupKeyFor(item);
        }
      },
    );
  }

  suite.printResults();
  suite.printScalingResults();
}

void _runSelectionManagerBenchmarks() {
  final suite = BenchmarkSuite(
    'SelectionManager Operations',
    config: const BenchmarkConfig(
      warmupIterations: 5,
      itemCounts: [100, 1000, 10000, 100000],
    ),
  );

  for (final count in suite.config.itemCounts) {
    final keys = List.generate(count, (i) => 'item_$i');
    late SelectionManager manager;

    // Benchmark: select
    suite.run(
      name: 'SelectionManager.select',
      itemCount: count,
      setup: () {
        manager = SelectionManager();
      },
      action: () {
        manager.select(keys[0], state: Tristate.yes);
        manager.select(keys[0], state: Tristate.no);
      },
      teardown: () {
        manager.dispose();
      },
    );

    // Benchmark: selectAll
    suite.runOnce(
      name: 'SelectionManager.selectAll',
      itemCount: count,
      setup: () {
        manager = SelectionManager();
      },
      action: () {
        manager.selectAll(keys);
      },
      teardown: () {
        manager.dispose();
      },
    );

    // Benchmark: isSelected lookup
    suite.run(
      name: 'SelectionManager.isSelected',
      itemCount: count,
      setup: () {
        manager = SelectionManager();
        manager.selectAll(keys.take(count ~/ 2));
      },
      action: () {
        for (var i = 0; i < 100; i++) {
          manager.isSelected(keys[i * (count ~/ 100)]);
        }
      },
      teardown: () {
        manager.dispose();
      },
    );

    // Benchmark: stateOf (aggregation)
    suite.run(
      name: 'SelectionManager.stateOf',
      itemCount: count,
      setup: () {
        manager = SelectionManager();
        manager.selectAll(keys.take(count ~/ 2));
      },
      action: () {
        manager.stateOf(keys);
      },
      teardown: () {
        manager.dispose();
      },
    );

    // Benchmark: count selected (via stateOf)
    suite.run(
      name: 'SelectionManager.count (via stateOf)',
      itemCount: count,
      setup: () {
        manager = SelectionManager();
        manager.selectAll(keys.take(count ~/ 2));
      },
      action: () {
        // Use stateOf to determine selection count
        final state = manager.stateOf(keys);
        if (state == SelectionState.none) {
          // no-op to use the result
        }
      },
      teardown: () {
        manager.dispose();
      },
    );

    // Benchmark: scoped selection
    suite.run(
      name: 'SelectionManager (scoped)',
      itemCount: count,
      setup: () {
        manager = SelectionManager();
      },
      action: () {
        manager.select(keys[0], scope: 'scope1', state: Tristate.yes);
        manager.select(keys[1], scope: 'scope2', state: Tristate.yes);
        manager.isSelected(keys[0], scope: 'scope1');
        manager.isSelected(keys[1], scope: 'scope2');
        manager.select(keys[0], scope: 'scope1', state: Tristate.no);
        manager.select(keys[1], scope: 'scope2', state: Tristate.no);
      },
      teardown: () {
        manager.dispose();
      },
    );

    // Benchmark: clearAll
    suite.runOnce(
      name: 'SelectionManager.clearAll',
      itemCount: count,
      setup: () {
        manager = SelectionManager();
        manager.selectAll(keys);
      },
      action: () {
        manager.clearAll();
      },
      teardown: () {
        manager.dispose();
      },
    );
  }

  suite.printResults();
  suite.printScalingResults();
}
