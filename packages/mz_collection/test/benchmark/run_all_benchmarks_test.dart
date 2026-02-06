// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

// Benchmarks use print statements for results output.
// ignore_for_file: avoid_print

import 'package:test/test.dart';

import 'collection_controller_benchmark.dart' as controller;
import 'manager_benchmark.dart' as manager;
import 'memory_benchmark.dart' as memory;
import 'node_benchmark.dart' as node;

/// Runs all MZ Collection benchmarks as tests.
///
/// Usage:
///   flutter test test/benchmark/run_all_benchmarks_test.dart
///
/// Run specific benchmark:
///   flutter test test/benchmark/node_benchmark.dart
///   flutter test test/benchmark/manager_benchmark.dart
///   flutter test test/benchmark/collection_controller_benchmark.dart
///   flutter test test/benchmark/memory_benchmark.dart
void main() {
  const boxTop = '╔═══════════════════════════════════════════════════════╗';
  const boxBot = '╚═══════════════════════════════════════════════════════╝';

  group('Benchmarks', () {
    test(
      'Node benchmarks',
      () {
        print('\n');
        print(boxTop);
        print('║                     NODE BENCHMARKS                   ║');
        print(boxBot);
        node.main();
      },
      skip: 'Run manually: flutter test test/benchmark/node_benchmark.dart',
    );

    test(
      'Manager benchmarks',
      () {
        print('\n');
        print(boxTop);
        print('║                   MANAGER BENCHMARKS                  ║');
        print(boxBot);
        manager.main();
      },
      skip: 'Run manually: flutter test test/benchmark/manager_benchmark.dart',
    );

    test(
      'CollectionController benchmarks',
      () {
        print('\n');
        print(boxTop);
        print('║             COLLECTION CONTROLLER BENCHMARKS          ║');
        print(boxBot);
        controller.main();
      },
      skip: 'Run manually: '
          'flutter test test/benchmark/collection_controller_benchmark.dart',
    );

    test(
      'Memory benchmarks',
      () {
        print('\n');
        print(boxTop);
        print('║                   MEMORY BENCHMARKS                   ║');
        print(boxBot);
        memory.main();
      },
      skip: 'Run manually: flutter test test/benchmark/memory_benchmark.dart',
    );
  });
}
