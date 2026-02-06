// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

// Benchmarks use print statements for results output.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:mz_collection/mz_collection.dart';

import 'benchmark_harness.dart';

/// Memory profiling benchmarks for MZ Collection.
///
/// These benchmarks focus on:
/// - Memory overhead per data structure
/// - Memory scaling with item count
/// - Memory efficiency of different storage strategies
/// - Peak memory during operations
void main() {
  print('MZ Collection - Memory Benchmarks');
  print('==================================\n');

  _runStorageOverheadBenchmarks();
  _runNodeMemoryBenchmarks();
  _runWindowedStoreMemoryBenchmarks();
  _runCollectionControllerMemoryBenchmarks();
}

/// Formats bytes to human-readable string.
String _formatBytes(int bytes) {
  if (bytes.abs() < 1024) return '$bytes B';
  if (bytes.abs() < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

/// Gets current memory usage.
int _getMemory() {
  try {
    return ProcessInfo.currentRss;
  } on Object {
    return 0;
  }
}

/// Forces garbage collection (best effort).
void _forceGC() {
  final list = List.generate(100000, (i) => i);
  list.clear();
}

void _runStorageOverheadBenchmarks() {
  print('\n--- Storage Overhead Analysis ---\n');

  final counts = [100, 1000, 10000, 100000];

  for (final count in counts) {
    final items = BenchmarkItem.generate(count);

    // Baseline: Raw List storage
    _forceGC();
    final baselineStart = _getMemory();
    final rawList = List<BenchmarkItem>.from(items);
    final baselineEnd = _getMemory();
    final rawListMemory = baselineEnd - baselineStart;

    // Controller with items
    _forceGC();
    final controllerStart = _getMemory();
    final controller = CollectionController<BenchmarkItem>(
      keyOf: (item) => item.id,
    );
    controller.addAll(items);
    final controllerEnd = _getMemory();
    final controllerMemory = controllerEnd - controllerStart;

    // Node storage
    _forceGC();
    final nodeStart = _getMemory();
    final node = Node<BenchmarkItem>(
      id: 'root',
      keyOf: (item) => item.id,
    );
    node.addAll(items);
    final nodeEnd = _getMemory();
    final nodeMemory = nodeEnd - nodeStart;

    // Calculate overhead
    final controllerOverhead =
        rawListMemory > 0 ? (controllerMemory / rawListMemory - 1) * 100 : 0;
    final nodeOverhead =
        rawListMemory > 0 ? (nodeMemory / rawListMemory - 1) * 100 : 0;

    print('Item count: $count');
    print('  Raw List:     ${_formatBytes(rawListMemory)}');
    print('  Controller:   ${_formatBytes(controllerMemory)} '
        '(${controllerOverhead.toStringAsFixed(0)}% overhead)');
    print('  Node:         ${_formatBytes(nodeMemory)} '
        '(${nodeOverhead.toStringAsFixed(0)}% overhead)');
    print('  Per-item overhead:');
    print(
      '    Controller: ${((controllerMemory - rawListMemory) / count).toStringAsFixed(1)} bytes/item',
    );
    print(
      '    Node:        ${((nodeMemory - rawListMemory) / count).toStringAsFixed(1)} bytes/item',
    );
    print('');

    // Cleanup
    rawList.clear();
    controller.dispose();
    node.dispose();
  }
}

void _runNodeMemoryBenchmarks() {
  print('\n--- Node Tree Memory Analysis ---\n');

  // Compare flat vs tree structures
  final counts = [100, 1000, 10000];

  for (final count in counts) {
    print('Node count: $count');

    // Flat node (all items in root)
    _forceGC();
    final flatStart = _getMemory();
    final flatNode = Node<BenchmarkItem>(
      id: 'root',
      keyOf: (item) => item.id,
    );
    for (var i = 0; i < count; i++) {
      flatNode.add(
        BenchmarkItem(
          id: 'item_$i',
          name: 'Item $i',
          value: i,
          category: 'A',
        ),
      );
    }
    final flatEnd = _getMemory();
    final flatMemory = flatEnd - flatStart;
    print('  Flat (items in root):   ${_formatBytes(flatMemory)}');

    // Wide tree (all children of root)
    _forceGC();
    final wideStart = _getMemory();
    final wideNode = Node<BenchmarkItem>(
      id: 'root',
      keyOf: (item) => item.id,
    );
    for (var i = 0; i < count; i++) {
      final child = Node<BenchmarkItem>(
        id: 'child_$i',
        keyOf: (item) => item.id,
      );
      child.add(
        BenchmarkItem(
          id: 'item_$i',
          name: 'Item $i',
          value: i,
          category: 'A',
        ),
      );
      wideNode.addChild(child);
    }
    final wideEnd = _getMemory();
    final wideMemory = wideEnd - wideStart;
    print('  Wide (1 item per child): ${_formatBytes(wideMemory)}');

    // Deep tree (linear chain)
    _forceGC();
    final deepStart = _getMemory();
    final deepRoot = Node<BenchmarkItem>(
      id: 'root',
      keyOf: (item) => item.id,
    );
    var current = deepRoot;
    for (var i = 0; i < count; i++) {
      final child = Node<BenchmarkItem>(
        id: 'child_$i',
        keyOf: (item) => item.id,
      );
      child.add(
        BenchmarkItem(
          id: 'item_$i',
          name: 'Item $i',
          value: i,
          category: 'A',
        ),
      );
      current.addChild(child);
      current = child;
    }
    final deepEnd = _getMemory();
    final deepMemory = deepEnd - deepStart;
    print('  Deep (linear chain):    ${_formatBytes(deepMemory)}');

    // Balanced tree (binary-ish)
    _forceGC();
    final balancedStart = _getMemory();
    final balancedRoot = Node<BenchmarkItem>(
      id: 'root',
      keyOf: (item) => item.id,
    );
    void buildBalanced(Node<BenchmarkItem> parent, int start, int end) {
      if (start > end) return;
      final mid = (start + end) ~/ 2;
      final child = Node<BenchmarkItem>(
        id: 'child_$mid',
        keyOf: (item) => item.id,
      );
      child.add(
        BenchmarkItem(
          id: 'item_$mid',
          name: 'Item $mid',
          value: mid,
          category: 'A',
        ),
      );
      parent.addChild(child);
      buildBalanced(child, start, mid - 1);
      buildBalanced(child, mid + 1, end);
    }

    buildBalanced(balancedRoot, 0, count - 1);
    final balancedEnd = _getMemory();
    final balancedMemory = balancedEnd - balancedStart;
    print('  Balanced (binary):      ${_formatBytes(balancedMemory)}');

    print('  Memory per node:');
    print('    Wide:     ${(wideMemory / count).toStringAsFixed(0)} bytes');
    print('    Deep:     ${(deepMemory / count).toStringAsFixed(0)} bytes');
    print('    Balanced: ${(balancedMemory / count).toStringAsFixed(0)} bytes');
    print('');

    // Cleanup
    flatNode.dispose();
    wideNode.dispose();
    deepRoot.dispose();
    balancedRoot.dispose();
  }
}

void _runWindowedStoreMemoryBenchmarks() {
  // WindowedStore has been removed - skipping this benchmark
  print('\n--- WindowedStore Memory Analysis ---\n');
  print('(Skipped - WindowedStore has been removed)\n');
}

void _runCollectionControllerMemoryBenchmarks() {
  print('\n--- CollectionController Memory Analysis ---\n');

  final counts = [1000, 10000, 50000];

  for (final count in counts) {
    final items = BenchmarkItem.generate(count);
    print('Item count: $count\n');

    // Baseline: Raw list
    _forceGC();
    final baselineStart = _getMemory();
    final rawList = List<BenchmarkItem>.from(items);
    final baselineEnd = _getMemory();
    final baselineMemory = baselineEnd - baselineStart;
    print('  Raw list:            ${_formatBytes(baselineMemory)}');

    // CollectionController (no managers)
    _forceGC();
    final basicStart = _getMemory();
    final controller1 = CollectionController<BenchmarkItem>(
      keyOf: (item) => item.id,
    );
    controller1.addAll(items);
    final basicEnd = _getMemory();
    final basicMemory = basicEnd - basicStart;
    print('  Controller (basic):  ${_formatBytes(basicMemory)} '
        '(+${_formatBytes(basicMemory - baselineMemory)})');

    // CollectionController with filter
    _forceGC();
    final filterStart = _getMemory();
    final filter = Filter<BenchmarkItem, String>(
      id: 'category',
      test: (item, value) => item.category == value,
    );
    filter.add('A');
    final filterManager = FilterManager<BenchmarkItem>()..add(filter);
    final controller2 = CollectionController<BenchmarkItem>(
      keyOf: (item) => item.id,
      filter: filterManager,
    );
    controller2.addAll(items);
    final filterEnd = _getMemory();
    final filterMemory = filterEnd - filterStart;
    print('  Controller + Filter: ${_formatBytes(filterMemory)} '
        '(+${_formatBytes(filterMemory - baselineMemory)})');

    // CollectionController with sort
    _forceGC();
    final sortStart = _getMemory();
    final valueSort = ValueSortOption<BenchmarkItem, int>(
      id: 'value',
      sortIdentifier: (item) => item.value,
    );
    final sortManager = SortManager<BenchmarkItem>()..addAll([valueSort]);
    sortManager.setCurrent(valueSort);
    final controller3 = CollectionController<BenchmarkItem>(
      keyOf: (item) => item.id,
      sort: sortManager,
    );
    controller3.addAll(items);
    final sortEnd = _getMemory();
    final sortMemory = sortEnd - sortStart;
    print('  Controller + Sort:   ${_formatBytes(sortMemory)} '
        '(+${_formatBytes(sortMemory - baselineMemory)})');

    // CollectionController with grouping
    _forceGC();
    final groupStart = _getMemory();
    final groupManager = GroupManager<BenchmarkItem>(
      options: [
        GroupOption<BenchmarkItem, String>(
          id: 'category',
          valueBuilder: (item) => item.category,
        ),
      ],
    );
    final controller4 = CollectionController<BenchmarkItem>(
      keyOf: (item) => item.id,
      group: groupManager,
    );
    controller4.addAll(items);
    final groupEnd = _getMemory();
    final groupMemory = groupEnd - groupStart;
    print('  Controller + Group:  ${_formatBytes(groupMemory)} '
        '(+${_formatBytes(groupMemory - baselineMemory)})');

    // Full pipeline
    _forceGC();
    final fullStart = _getMemory();
    final filter2 = Filter<BenchmarkItem, String>(
      id: 'category',
      test: (item, value) => item.category == value,
    );
    filter2.add('A');
    final filterManager2 = FilterManager<BenchmarkItem>()..add(filter2);
    final valueSort2 = ValueSortOption<BenchmarkItem, int>(
      id: 'value',
      sortIdentifier: (item) => item.value,
    );
    final sortManager2 = SortManager<BenchmarkItem>()..addAll([valueSort2]);
    sortManager2.setCurrent(valueSort2);
    final groupManager2 = GroupManager<BenchmarkItem>(
      options: [
        GroupOption<BenchmarkItem, String>(
          id: 'category',
          valueBuilder: (item) => item.category,
        ),
      ],
    );
    final selection = SelectionManager();
    final controller5 = CollectionController<BenchmarkItem>(
      keyOf: (item) => item.id,
      filter: filterManager2,
      sort: sortManager2,
      group: groupManager2,
      selection: selection,
    );
    controller5.addAll(items);
    final fullEnd = _getMemory();
    final fullMemory = fullEnd - fullStart;
    print('  Full pipeline:       ${_formatBytes(fullMemory)} '
        '(+${_formatBytes(fullMemory - baselineMemory)})');

    print('');

    // Cleanup
    rawList.clear();
    controller1.dispose();
    controller2.dispose();
    controller3.dispose();
    controller4.dispose();
    controller5.dispose();
    selection.dispose();
  }
}
