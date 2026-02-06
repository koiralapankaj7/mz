// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

// Benchmarks use print statements for results output.
// ignore_for_file: avoid_print

// Benchmarks use side-effect statements for timing measurements.
// ignore_for_file: unnecessary_statements

import 'package:mz_collection/mz_collection.dart';

import 'benchmark_harness.dart';

/// Benchmarks for Node tree operations.
void main() {
  print('MZ Collection - Node Benchmarks');
  print('================================\n');

  _runItemOperationBenchmarks();
  _runTreeNavigationBenchmarks();
  _runTreeManipulationBenchmarks();
  _runCollapseExpandBenchmarks();
}

void _runItemOperationBenchmarks() {
  final suite = BenchmarkSuite(
    'Node Item Operations',
    config: const BenchmarkConfig(
      warmupIterations: 5,
      measureIterations: 50,
      itemCounts: [100, 1000, 10000, 100000],
    ),
  );

  for (final count in suite.config.itemCounts) {
    final items = BenchmarkItem.generate(count);
    late Node<BenchmarkItem> node;

    // Benchmark: addAll (bulk insert)
    suite.runOnce(
      name: 'Node.addAll',
      itemCount: count,
      setup: () {
        node = Node<BenchmarkItem>(
          id: 'root',
          keyOf: (item) => item.id,
        );
      },
      action: () {
        node.addAll(items);
      },
      teardown: () {
        node.dispose();
      },
    );

    // Benchmark: add (single insert)
    suite.run(
      name: 'Node.add',
      itemCount: count,
      setup: () {
        node = Node<BenchmarkItem>(
          id: 'root',
          keyOf: (item) => item.id,
        );
      },
      action: () {
        node.add(items[0]);
      },
      teardown: () {
        node.dispose();
      },
    );

    // Benchmark: lookup by key
    suite.run(
      name: 'Node.operator[]',
      itemCount: count,
      setup: () {
        node = Node<BenchmarkItem>(
          id: 'root',
          keyOf: (item) => item.id,
        );
        node.addAll(items);
      },
      action: () {
        for (var i = 0; i < 100; i++) {
          final key = 'item_${i * (count ~/ 100)}';
          node[key];
        }
      },
      teardown: () {
        node.dispose();
      },
    );

    // Benchmark: atOrNull (index access)
    suite.run(
      name: 'Node.atOrNull',
      itemCount: count,
      setup: () {
        node = Node<BenchmarkItem>(
          id: 'root',
          keyOf: (item) => item.id,
        );
        node.addAll(items);
      },
      action: () {
        for (var i = 0; i < 100; i++) {
          final index = i * (count ~/ 100);
          node.atOrNull(index);
        }
      },
      teardown: () {
        node.dispose();
      },
    );

    // Benchmark: indexOf
    suite.run(
      name: 'Node.indexOf',
      itemCount: count,
      setup: () {
        node = Node<BenchmarkItem>(
          id: 'root',
          keyOf: (item) => item.id,
        );
        node.addAll(items);
      },
      action: () {
        for (var i = 0; i < 100; i++) {
          final index = i * (count ~/ 100);
          final item = items[index];
          node.indexOf(item);
        }
      },
      teardown: () {
        node.dispose();
      },
    );

    // Benchmark: iteration
    suite.run(
      name: 'Node iteration',
      itemCount: count,
      setup: () {
        node = Node<BenchmarkItem>(
          id: 'root',
          keyOf: (item) => item.id,
        );
        node.addAll(items);
      },
      action: () {
        var sum = 0;
        for (final item in node) {
          sum += item.value;
        }
        if (sum < 0) print(sum);
      },
      teardown: () {
        node.dispose();
      },
    );

    // Benchmark: removeByKey
    suite.run(
      name: 'Node.removeByKey',
      itemCount: count,
      setup: () {
        node = Node<BenchmarkItem>(
          id: 'root',
          keyOf: (item) => item.id,
        );
        node.addAll(items);
      },
      action: () {
        node.removeByKey('item_0');
        node.add(items[0]); // Re-add for next iteration
      },
      teardown: () {
        node.dispose();
      },
    );

    // Benchmark: remove (by reference)
    suite.run(
      name: 'Node.remove',
      itemCount: count,
      setup: () {
        node = Node<BenchmarkItem>(
          id: 'root',
          keyOf: (item) => item.id,
        );
        node.addAll(items);
      },
      action: () {
        node.remove(items[0]);
        node.add(items[0]); // Re-add for next iteration
      },
      teardown: () {
        node.dispose();
      },
    );

    // Benchmark: replaceByKey
    suite.run(
      name: 'Node.replaceByKey',
      itemCount: count,
      setup: () {
        node = Node<BenchmarkItem>(
          id: 'root',
          keyOf: (item) => item.id,
        );
        node.addAll(items);
      },
      action: () {
        node.replaceByKey('item_0', items[0]);
      },
      teardown: () {
        node.dispose();
      },
    );

    // Benchmark: sort
    suite.runOnce(
      name: 'Node.sort',
      itemCount: count,
      setup: () {
        node = Node<BenchmarkItem>(
          id: 'root',
          keyOf: (item) => item.id,
        );
        // Add in random order
        final shuffled = List<BenchmarkItem>.from(items)..shuffle();
        node.addAll(shuffled);
      },
      action: () {
        node.sort((a, b) => a.value.compareTo(b.value));
      },
      teardown: () {
        node.dispose();
      },
    );
  }

  suite.printResults();
  suite.printScalingResults();
}

void _runTreeNavigationBenchmarks() {
  final suite = BenchmarkSuite(
    'Node Tree Navigation',
    config: const BenchmarkConfig(
      warmupIterations: 5,
      measureIterations: 50,
      itemCounts: [10, 100, 1000],
    ),
  );

  for (final count in suite.config.itemCounts) {
    late Node<BenchmarkItem> root;

    // Create a tree with depth based on count
    Node<BenchmarkItem> createTree(int nodeCount) {
      final treeRoot = Node<BenchmarkItem>(
        id: 'root',
        keyOf: (item) => item.id,
      );

      // Create a balanced tree structure
      const nodesPerLevel = 5;
      final depth = (nodeCount / nodesPerLevel).ceil().clamp(1, 10);
      var nodeId = 0;

      void addLevel(Node<BenchmarkItem> parent, int currentDepth) {
        if (currentDepth >= depth || nodeId >= nodeCount) return;

        for (var i = 0; i < nodesPerLevel && nodeId < nodeCount; i++) {
          final child = Node<BenchmarkItem>(
            id: 'node_$nodeId',
            keyOf: (item) => item.id,
          );
          child.add(
            BenchmarkItem(
              id: 'item_$nodeId',
              name: 'Item $nodeId',
              value: nodeId,
              category: 'A',
            ),
          );
          parent.addChild(child);
          nodeId++;
          addLevel(child, currentDepth + 1);
        }
      }

      addLevel(treeRoot, 0);
      return treeRoot;
    }

    // Benchmark: findNode
    suite.run(
      name: 'Node.findNode',
      itemCount: count,
      setup: () {
        root = createTree(count);
      },
      action: () {
        for (var i = 0; i < 10; i++) {
          root.findNode('node_${i * (count ~/ 10)}');
        }
      },
      teardown: () {
        root.dispose();
      },
    );

    // Benchmark: descendants (BFS)
    suite.run(
      name: 'Node.descendants (BFS)',
      itemCount: count,
      setup: () {
        root = createTree(count);
      },
      action: () {
        var nodeCount = 0;
        for (final _ in root.descendants()) {
          nodeCount++;
        }
        if (nodeCount < 0) print(nodeCount);
      },
      teardown: () {
        root.dispose();
      },
    );

    // Benchmark: descendants (DFS)
    suite.run(
      name: 'Node.descendants (DFS)',
      itemCount: count,
      setup: () {
        root = createTree(count);
      },
      action: () {
        var nodeCount = 0;
        for (final _ in root.descendants(depthFirst: true)) {
          nodeCount++;
        }
        if (nodeCount < 0) print(nodeCount);
      },
      teardown: () {
        root.dispose();
      },
    );

    // Benchmark: visibleDescendants
    suite.run(
      name: 'Node.visibleDescendants',
      itemCount: count,
      setup: () {
        root = createTree(count);
        // Collapse some nodes
        for (var i = 0; i < count ~/ 2; i++) {
          root.findNode('node_$i')?.collapse(state: Tristate.yes);
        }
      },
      action: () {
        var nodeCount = 0;
        for (final _ in root.visibleDescendants()) {
          nodeCount++;
        }
        if (nodeCount < 0) print(nodeCount);
      },
      teardown: () {
        root.dispose();
      },
    );

    // Benchmark: flattenedItems
    suite.run(
      name: 'Node.flattenedItems',
      itemCount: count,
      setup: () {
        root = createTree(count);
      },
      action: () {
        var itemCount = 0;
        for (final _ in root.flattenedItems) {
          itemCount++;
        }
        if (itemCount < 0) print(itemCount);
      },
      teardown: () {
        root.dispose();
      },
    );

    // Benchmark: flattenedLength
    suite.run(
      name: 'Node.flattenedLength',
      itemCount: count,
      setup: () {
        root = createTree(count);
      },
      action: () {
        final length = root.flattenedLength;
        if (length < 0) print(length);
      },
      teardown: () {
        root.dispose();
      },
    );

    // Benchmark: height
    suite.run(
      name: 'Node.height',
      itemCount: count,
      setup: () {
        root = createTree(count);
      },
      action: () {
        final h = root.height;
        if (h < 0) print(h);
      },
      teardown: () {
        root.dispose();
      },
    );

    // Benchmark: isAncestorOf
    suite.run(
      name: 'Node.isAncestorOf',
      itemCount: count,
      setup: () {
        root = createTree(count);
      },
      action: () {
        for (var i = 0; i < 10; i++) {
          final target = root.findNode('node_${count - 1 - i}');
          if (target != null) {
            root.isAncestorOf(target);
          }
        }
      },
      teardown: () {
        root.dispose();
      },
    );
  }

  suite.printResults();
  suite.printScalingResults();
}

void _runTreeManipulationBenchmarks() {
  final suite = BenchmarkSuite(
    'Node Tree Manipulation',
    config: const BenchmarkConfig(
      warmupIterations: 5,
      measureIterations: 50,
      itemCounts: [10, 100, 500],
    ),
  );

  for (final count in suite.config.itemCounts) {
    late Node<BenchmarkItem> root;

    Node<BenchmarkItem> createFlatTree() {
      final treeRoot = Node<BenchmarkItem>(
        id: 'root',
        keyOf: (item) => item.id,
      );
      for (var i = 0; i < count; i++) {
        final child = Node<BenchmarkItem>(
          id: 'node_$i',
          keyOf: (item) => item.id,
        );
        treeRoot.addChild(child);
      }
      return treeRoot;
    }

    // Benchmark: addChild
    suite.run(
      name: 'Node.addChild',
      itemCount: count,
      setup: () {
        root = Node<BenchmarkItem>(
          id: 'root',
          keyOf: (item) => item.id,
        );
      },
      action: () {
        final child = Node<BenchmarkItem>(
          id: 'child',
          keyOf: (item) => item.id,
        );
        root.addChild(child);
        root.removeChild('child');
      },
      teardown: () {
        root.dispose();
      },
    );

    // Benchmark: removeChild
    suite.run(
      name: 'Node.removeChild',
      itemCount: count,
      setup: () {
        root = createFlatTree();
      },
      action: () {
        root.removeChild('node_0');
        final child = Node<BenchmarkItem>(
          id: 'node_0',
          keyOf: (item) => item.id,
        );
        root.addChild(child);
      },
      teardown: () {
        root.dispose();
      },
    );

    // Benchmark: moveTo
    suite.run(
      name: 'Node.moveTo',
      itemCount: count,
      setup: () {
        root = createFlatTree();
      },
      action: () {
        final source = root.child('node_0');
        final target = root.child('node_1');
        if (source != null && target != null) {
          source.moveTo(target);
          source.moveTo(root);
        }
      },
      teardown: () {
        root.dispose();
      },
    );

    // Benchmark: clone (deep)
    suite.runOnce(
      name: 'Node.clone (deep)',
      itemCount: count,
      setup: () {
        root = createFlatTree();
        for (var i = 0; i < count; i++) {
          root.child('node_$i')?.add(
                BenchmarkItem(
                  id: 'item_$i',
                  name: 'Item $i',
                  value: i,
                  category: 'A',
                ),
              );
        }
      },
      action: () {
        root.clone();
      },
      teardown: () {
        root.dispose();
      },
    );

    // Benchmark: clone (shallow)
    suite.runOnce(
      name: 'Node.clone (shallow)',
      itemCount: count,
      setup: () {
        root = createFlatTree();
        for (var i = 0; i < count; i++) {
          root.child('node_$i')?.add(
                BenchmarkItem(
                  id: 'item_$i',
                  name: 'Item $i',
                  value: i,
                  category: 'A',
                ),
              );
        }
      },
      action: () {
        root.clone(deep: false);
      },
      teardown: () {
        root.dispose();
      },
    );
  }

  suite.printResults();
  suite.printScalingResults();
}

void _runCollapseExpandBenchmarks() {
  final suite = BenchmarkSuite(
    'Node Collapse/Expand',
    config: const BenchmarkConfig(
      warmupIterations: 5,
      itemCounts: [10, 100, 1000],
    ),
  );

  for (final count in suite.config.itemCounts) {
    late Node<BenchmarkItem> root;

    Node<BenchmarkItem> createDeepTree() {
      final treeRoot = Node<BenchmarkItem>(
        id: 'root',
        keyOf: (item) => item.id,
      );
      var current = treeRoot;
      for (var i = 0; i < count; i++) {
        final child = Node<BenchmarkItem>(
          id: 'node_$i',
          keyOf: (item) => item.id,
        );
        current.addChild(child);
        current = child;
      }
      return treeRoot;
    }

    // Benchmark: toggle
    suite.run(
      name: 'Node.toggle',
      itemCount: count,
      setup: () {
        root = createDeepTree();
      },
      action: () {
        root.toggle();
      },
      teardown: () {
        root.dispose();
      },
    );

    // Benchmark: expandAll
    suite.run(
      name: 'Node.expandAll',
      itemCount: count,
      setup: () {
        root = createDeepTree();
        root.collapseAll();
      },
      action: () {
        root.expandAll();
      },
      teardown: () {
        root.dispose();
      },
    );

    // Benchmark: collapseAll
    suite.run(
      name: 'Node.collapseAll',
      itemCount: count,
      setup: () {
        root = createDeepTree();
        root.expandAll();
      },
      action: () {
        root.collapseAll();
      },
      teardown: () {
        root.dispose();
      },
    );

    // Benchmark: collapseToLevel
    suite.run(
      name: 'Node.collapseToLevel',
      itemCount: count,
      setup: () {
        root = createDeepTree();
        root.expandAll();
      },
      action: () {
        root.collapseToLevel(2);
      },
      teardown: () {
        root.dispose();
      },
    );
  }

  suite.printResults();
  suite.printScalingResults();
}
