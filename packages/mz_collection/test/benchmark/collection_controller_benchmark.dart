// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

// Benchmarks use print statements for results output.
// ignore_for_file: avoid_print

// Benchmarks may have intentional side-effect-only statements.
// ignore_for_file: unnecessary_statements

import 'package:mz_collection/mz_collection.dart';

import 'benchmark_harness.dart';

/// Benchmarks for CollectionController operations.
void main() {
  print('MZ Collection - CollectionController Benchmarks');
  print('================================================\n');

  _runRebuildBenchmarks();
  _runFilteringBenchmarks();
  _runSortingBenchmarks();
  _runGroupingBenchmarks();
  _runCombinedBenchmarks();
}

void _runRebuildBenchmarks() {
  final suite = BenchmarkSuite(
    'CollectionController Rebuild',
    config: const BenchmarkConfig(
      warmupIterations: 3,
      measureIterations: 20,
      itemCounts: [100, 1000, 10000, 50000],
    ),
  );

  for (final count in suite.config.itemCounts) {
    final items = BenchmarkItem.generate(count);

    late CollectionController<BenchmarkItem> controller;

    // Benchmark: Initial construction and addAll
    suite.runOnce(
      name: 'CollectionController construction + addAll',
      itemCount: count,
      setup: () {
        // Nothing to setup - we measure construction
      },
      action: () {
        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
        );
        controller.addAll(items);
      },
      teardown: () {
        controller.dispose();
      },
    );

    // Benchmark: Adding items triggers rebuild
    suite.run(
      name: 'Add item (triggers rebuild)',
      itemCount: count,
      setup: () {
        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
        );
        controller.addAll(items);
      },
      action: () {
        const newItem = BenchmarkItem(
          id: 'new_item',
          name: 'New',
          value: 0,
          category: 'X',
        );
        controller.add(newItem);
        controller.remove(newItem.id);
      },
      teardown: () {
        controller.dispose();
      },
    );

    // Benchmark: Iterate root items
    suite.run(
      name: 'Iterate root.items',
      itemCount: count,
      setup: () {
        controller.addAll(items);
        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
        );
      },
      action: () {
        var sum = 0;
        for (final item in controller.root) {
          sum += item.value;
        }
        if (sum < 0) print(sum);
      },
      teardown: () {
        controller.dispose();
      },
    );

    // Benchmark: Access by key
    suite.run(
      name: 'Lookup by key',
      itemCount: count,
      setup: () {
        controller.addAll(items);
        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
        );
      },
      action: () {
        for (var i = 0; i < 100; i++) {
          final key = 'item_${i * (count ~/ 100)}';
          controller[key];
        }
      },
      teardown: () {
        controller.dispose();
      },
    );
  }

  suite.printResults();
  suite.printScalingResults();
}

void _runFilteringBenchmarks() {
  final suite = BenchmarkSuite(
    'CollectionController Filtering',
    config: const BenchmarkConfig(
      warmupIterations: 3,
      measureIterations: 20,
      itemCounts: [100, 1000, 10000, 50000],
    ),
  );

  for (final count in suite.config.itemCounts) {
    final items = BenchmarkItem.generate(count);

    late FilterManager<BenchmarkItem> filterManager;
    late Filter<BenchmarkItem, String> categoryFilter;
    late CollectionController<BenchmarkItem> controller;

    // Benchmark: With local filtering (store doesn't handle)
    suite.runOnce(
      name: 'Local filtering (1 filter)',
      itemCount: count,
      setup: () {
        categoryFilter = Filter<BenchmarkItem, String>(
          id: 'category',
          test: (item, value) => item.category == value,
        );
        filterManager = FilterManager<BenchmarkItem>()..add(categoryFilter);
      },
      action: () {
        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
          filter: filterManager,
        );
        controller.addAll(items);
        categoryFilter.add('A');
      },
      teardown: () {
        controller.dispose();
      },
    );

    // Benchmark: Filter change rebuild
    suite.run(
      name: 'Filter change (rebuild)',
      itemCount: count,
      setup: () {
        categoryFilter = Filter<BenchmarkItem, String>(
          id: 'category',
          test: (item, value) => item.category == value,
        );
        filterManager = FilterManager<BenchmarkItem>()..add(categoryFilter);

        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
          filter: filterManager,
        );
        controller.addAll(items);
        categoryFilter.add('A');
      },
      action: () {
        // Toggle filter
        categoryFilter.clear();
        categoryFilter.add('B');
      },
      teardown: () {
        controller.dispose();
      },
    );

    // Benchmark: Multiple filters
    suite.runOnce(
      name: 'Local filtering (3 filters)',
      itemCount: count,
      setup: () {
        final f1 = Filter<BenchmarkItem, String>(
          id: 'category',
          test: (item, value) => item.category == value,
        );
        final f2 = Filter<BenchmarkItem, int>(
          id: 'value',
          test: (item, value) => item.value >= value,
        );
        final f3 = Filter<BenchmarkItem, String>(
          id: 'name',
          test: (item, value) => item.name.startsWith(value),
        );

        filterManager = FilterManager<BenchmarkItem>()..addAll([f1, f2, f3]);
        f1.add('A');
        f2.add(100);
        f3.add('Item');
      },
      action: () {
        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
          filter: filterManager,
        );
        controller.addAll(items);
      },
      teardown: () {
        controller.dispose();
      },
    );
  }

  suite.printResults();
  suite.printScalingResults();
}

void _runSortingBenchmarks() {
  final suite = BenchmarkSuite(
    'CollectionController Sorting',
    config: const BenchmarkConfig(
      warmupIterations: 3,
      measureIterations: 20,
      itemCounts: [100, 1000, 10000, 50000],
    ),
  );

  for (final count in suite.config.itemCounts) {
    final items = BenchmarkItem.generate(count);

    late SortManager<BenchmarkItem> sortManager;
    late ValueSortOption<BenchmarkItem, int> valueSort;
    late CollectionController<BenchmarkItem> controller;

    // Benchmark: With local sorting
    suite.runOnce(
      name: 'Local sorting (1 sort)',
      itemCount: count,
      setup: () {
        valueSort = ValueSortOption<BenchmarkItem, int>(
          id: 'value',
          sortIdentifier: (item) => item.value,
        );
        sortManager = SortManager<BenchmarkItem>()..addAll([valueSort]);
        sortManager.setCurrent(valueSort);
      },
      action: () {
        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
          sort: sortManager,
        );
        controller.addAll(items);
      },
      teardown: () {
        controller.dispose();
      },
    );

    // Benchmark: Sort change
    suite.run(
      name: 'Sort change (rebuild)',
      itemCount: count,
      setup: () {
        valueSort = ValueSortOption<BenchmarkItem, int>(
          id: 'value',
          sortIdentifier: (item) => item.value,
        );
        sortManager = SortManager<BenchmarkItem>()..addAll([valueSort]);
        sortManager.setCurrent(valueSort);

        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
          sort: sortManager,
        );
        controller.addAll(items);
      },
      action: () {
        // Toggle sort order
        sortManager.setSortOrder(SortOrder.descending);
        sortManager.setSortOrder(SortOrder.ascending);
      },
      teardown: () {
        controller.dispose();
      },
    );

    // Benchmark: Multi-level sort
    suite.runOnce(
      name: 'Local sorting (3-level)',
      itemCount: count,
      setup: () {
        final s1 = ValueSortOption<BenchmarkItem, String>(
          id: 'category',
          sortIdentifier: (item) => item.category,
        );
        final s2 = ValueSortOption<BenchmarkItem, int>(
          id: 'value',
          sortIdentifier: (item) => item.value,
        );
        final s3 = ValueSortOption<BenchmarkItem, String>(
          id: 'name',
          sortIdentifier: (item) => item.name,
        );

        sortManager = SortManager<BenchmarkItem>()..addAll([s1, s2, s3]);
        sortManager.setCurrent(s1);
        sortManager.add(s2);
        sortManager.add(s3);
      },
      action: () {
        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
          sort: sortManager,
        );
        controller.addAll(items);
      },
      teardown: () {
        controller.dispose();
      },
    );
  }

  suite.printResults();
  suite.printScalingResults();
}

void _runGroupingBenchmarks() {
  final suite = BenchmarkSuite(
    'CollectionController Grouping',
    config: const BenchmarkConfig(
      warmupIterations: 3,
      measureIterations: 20,
    ),
  );

  for (final count in suite.config.itemCounts) {
    final items = BenchmarkItem.generate(count);

    late GroupManager<BenchmarkItem> groupManager;
    late CollectionController<BenchmarkItem> controller;

    // Benchmark: Single-level grouping
    suite.runOnce(
      name: 'Grouping (1-level, 5 groups)',
      itemCount: count,
      setup: () {
        groupManager = GroupManager<BenchmarkItem>(
          options: [
            GroupOption<BenchmarkItem, String>(
              id: 'category',
              valueBuilder: (item) => item.category,
            ),
          ],
        );
      },
      action: () {
        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
          group: groupManager,
        );
        controller.addAll(items);
      },
      teardown: () {
        controller.dispose();
      },
    );

    // Benchmark: Two-level grouping
    suite.runOnce(
      name: 'Grouping (2-level)',
      itemCount: count,
      setup: () {
        groupManager = GroupManager<BenchmarkItem>(
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
      },
      action: () {
        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
          group: groupManager,
        );
        controller.addAll(items);
      },
      teardown: () {
        controller.dispose();
      },
    );

    // Benchmark: Grouped iteration
    suite.run(
      name: 'Iterate grouped items',
      itemCount: count,
      setup: () {
        groupManager = GroupManager<BenchmarkItem>(
          options: [
            GroupOption<BenchmarkItem, String>(
              id: 'category',
              valueBuilder: (item) => item.category,
            ),
          ],
        );

        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
          group: groupManager,
        );
        controller.addAll(items);
      },
      action: () {
        var sum = 0;
        for (final item in controller.items) {
          sum += item.value;
        }
        if (sum < 0) print(sum);
      },
      teardown: () {
        controller.dispose();
      },
    );

    // Benchmark: flattenedLength with grouping
    suite.run(
      name: 'Grouped flattenedLength',
      itemCount: count,
      setup: () {
        groupManager = GroupManager<BenchmarkItem>(
          options: [
            GroupOption<BenchmarkItem, String>(
              id: 'category',
              valueBuilder: (item) => item.category,
            ),
          ],
        );

        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
          group: groupManager,
        );
        controller.addAll(items);
      },
      action: () {
        final length = controller.length;
        if (length < 0) print(length);
      },
      teardown: () {
        controller.dispose();
      },
    );
  }

  suite.printResults();
  suite.printScalingResults();
}

void _runCombinedBenchmarks() {
  final suite = BenchmarkSuite(
    'CollectionController Combined Operations',
    config: const BenchmarkConfig(
      warmupIterations: 3,
      measureIterations: 20,
    ),
  );

  for (final count in suite.config.itemCounts) {
    final items = BenchmarkItem.generate(count);

    late FilterManager<BenchmarkItem> filterManager;
    late SortManager<BenchmarkItem> sortManager;
    late GroupManager<BenchmarkItem> groupManager;
    late CollectionController<BenchmarkItem> controller;

    // Benchmark: Filter + Sort
    suite.runOnce(
      name: 'Filter + Sort',
      itemCount: count,
      setup: () {
        final categoryFilter = Filter<BenchmarkItem, String>(
          id: 'category',
          test: (item, value) => item.category == value,
        );
        categoryFilter.add('A');
        filterManager = FilterManager<BenchmarkItem>()..add(categoryFilter);

        final valueSort = ValueSortOption<BenchmarkItem, int>(
          id: 'value',
          sortIdentifier: (item) => item.value,
        );
        sortManager = SortManager<BenchmarkItem>()..addAll([valueSort]);
        sortManager.setCurrent(valueSort);
      },
      action: () {
        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
          filter: filterManager,
          sort: sortManager,
        );
        controller.addAll(items);
      },
      teardown: () {
        controller.dispose();
      },
    );

    // Benchmark: Filter + Sort + Group
    suite.runOnce(
      name: 'Filter + Sort + Group',
      itemCount: count,
      setup: () {
        final categoryFilter = Filter<BenchmarkItem, String>(
          id: 'category',
          test: (item, value) => item.category == value,
        );
        categoryFilter.add('A');
        categoryFilter.add('B');
        filterManager = FilterManager<BenchmarkItem>()..add(categoryFilter);

        final valueSort = ValueSortOption<BenchmarkItem, int>(
          id: 'value',
          sortIdentifier: (item) => item.value,
        );
        sortManager = SortManager<BenchmarkItem>()..addAll([valueSort]);
        sortManager.setCurrent(valueSort);

        groupManager = GroupManager<BenchmarkItem>(
          options: [
            GroupOption<BenchmarkItem, String>(
              id: 'category',
              valueBuilder: (item) => item.category,
            ),
          ],
        );
      },
      action: () {
        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
          filter: filterManager,
          sort: sortManager,
          group: groupManager,
        );
        controller.addAll(items);
      },
      teardown: () {
        controller.dispose();
      },
    );

    // Benchmark: Full pipeline rebuild
    suite.run(
      name: 'Full rebuild (filter+sort+group)',
      itemCount: count,
      setup: () {
        final categoryFilter = Filter<BenchmarkItem, String>(
          id: 'category',
          test: (item, value) => item.category == value,
        );
        categoryFilter.add('A');
        filterManager = FilterManager<BenchmarkItem>()..add(categoryFilter);

        final valueSort = ValueSortOption<BenchmarkItem, int>(
          id: 'value',
          sortIdentifier: (item) => item.value,
        );
        sortManager = SortManager<BenchmarkItem>()..addAll([valueSort]);
        sortManager.setCurrent(valueSort);

        groupManager = GroupManager<BenchmarkItem>(
          options: [
            GroupOption<BenchmarkItem, String>(
              id: 'category',
              valueBuilder: (item) => item.category,
            ),
          ],
        );

        controller = CollectionController<BenchmarkItem>(
          keyOf: (item) => item.id,
          filter: filterManager,
          sort: sortManager,
          group: groupManager,
        );
        controller.addAll(items);
      },
      action: () {
        // Trigger rebuild by changing filter
        filterManager.filters.first.clear();
        filterManager.filters.first.add('B');
      },
      teardown: () {
        controller.dispose();
      },
    );
  }

  suite.printResults();
  suite.printScalingResults();
}
