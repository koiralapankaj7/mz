// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

// Benchmarks use print statements for results output.
// ignore_for_file: avoid_print

import 'dart:io';

/// Configuration for a benchmark run.
class BenchmarkConfig {
  const BenchmarkConfig({
    this.warmupIterations = 10,
    this.measureIterations = 100,
    this.itemCounts = const [100, 1000, 10000],
  });

  /// Number of warmup iterations before measuring.
  final int warmupIterations;

  /// Number of iterations to measure.
  final int measureIterations;

  /// Item counts to test at different scales.
  final List<int> itemCounts;
}

/// Result of a single benchmark.
class BenchmarkResult {
  BenchmarkResult({
    required this.name,
    required this.itemCount,
    required this.iterations,
    required this.totalMicroseconds,
    this.memoryBefore,
    this.memoryAfter,
  });

  final String name;
  final int itemCount;
  final int iterations;
  final int totalMicroseconds;
  final int? memoryBefore;
  final int? memoryAfter;

  /// Average time per iteration in microseconds.
  double get averageMicroseconds => totalMicroseconds / iterations;

  /// Average time per iteration in milliseconds.
  double get averageMilliseconds => averageMicroseconds / 1000;

  /// Operations per second.
  double get opsPerSecond => 1000000 / averageMicroseconds;

  /// Memory delta in bytes (if available).
  int? get memoryDelta => memoryBefore != null && memoryAfter != null
      ? memoryAfter! - memoryBefore!
      : null;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..write('$name (n=$itemCount): ')
      ..write('${averageMicroseconds.toStringAsFixed(2)} us/op, ')
      ..write('${opsPerSecond.toStringAsFixed(0)} ops/s');

    final delta = memoryDelta;
    if (delta != null) {
      buffer.write(', memory: ${_formatBytes(delta)}');
    }

    return buffer.toString();
  }

  String _formatBytes(int bytes) {
    if (bytes.abs() < 1024) return '$bytes B';
    if (bytes.abs() < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// A benchmark suite that runs multiple benchmarks.
class BenchmarkSuite {
  BenchmarkSuite(this.name, {this.config = const BenchmarkConfig()});

  final String name;
  final BenchmarkConfig config;
  final List<BenchmarkResult> results = [];

  /// Runs a benchmark with the given setup and action.
  ///
  /// - [name]: Name of the benchmark
  /// - [itemCount]: Number of items being tested
  /// - [setup]: Called once before warmup to prepare state
  /// - [action]: The operation to benchmark (called many times)
  /// - [teardown]: Called once after measurement to clean up
  BenchmarkResult run({
    required String name,
    required int itemCount,
    required void Function() setup,
    required void Function() action,
    void Function()? teardown,
  }) {
    // Setup
    setup();

    // Warmup
    for (var i = 0; i < config.warmupIterations; i++) {
      action();
    }

    // Force GC before measuring
    _forceGC();
    final memoryBefore = _getMemoryUsage();

    // Measure
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < config.measureIterations; i++) {
      action();
    }
    stopwatch.stop();

    final memoryAfter = _getMemoryUsage();

    // Teardown
    teardown?.call();

    final result = BenchmarkResult(
      name: name,
      itemCount: itemCount,
      iterations: config.measureIterations,
      totalMicroseconds: stopwatch.elapsedMicroseconds,
      memoryBefore: memoryBefore,
      memoryAfter: memoryAfter,
    );

    results.add(result);
    return result;
  }

  /// Runs a benchmark that measures a single operation (not repeated).
  ///
  /// Useful for measuring bulk operations like "add 10000 items".
  BenchmarkResult runOnce({
    required String name,
    required int itemCount,
    required void Function() setup,
    required void Function() action,
    void Function()? teardown,
  }) {
    final timings = <int>[];

    for (var run = 0; run < config.measureIterations; run++) {
      setup();
      _forceGC();

      final stopwatch = Stopwatch()..start();
      action();
      stopwatch.stop();

      timings.add(stopwatch.elapsedMicroseconds);
      teardown?.call();
    }

    // Use median to avoid outliers
    timings.sort();
    final medianTime = timings[timings.length ~/ 2];

    final result = BenchmarkResult(
      name: name,
      itemCount: itemCount,
      iterations: 1,
      totalMicroseconds: medianTime,
    );

    results.add(result);
    return result;
  }

  /// Runs a memory benchmark that measures allocation.
  BenchmarkResult runMemory({
    required String name,
    required int itemCount,
    required void Function() setup,
    required Object? Function() action,
    void Function(Object?)? teardown,
  }) {
    setup();
    _forceGC();
    final memoryBefore = _getMemoryUsage();

    final stopwatch = Stopwatch()..start();
    final result = action();
    stopwatch.stop();

    _forceGC();
    final memoryAfter = _getMemoryUsage();

    teardown?.call(result);

    final benchResult = BenchmarkResult(
      name: name,
      itemCount: itemCount,
      iterations: 1,
      totalMicroseconds: stopwatch.elapsedMicroseconds,
      memoryBefore: memoryBefore,
      memoryAfter: memoryAfter,
    );

    results.add(benchResult);
    return benchResult;
  }

  /// Prints all results.
  void printResults() {
    print('\n${'=' * 60}');
    print('BENCHMARK SUITE: $name');
    print('=' * 60);
    results.forEach(print);
    print('=' * 60);
  }

  /// Prints results grouped by operation name.
  void printScalingResults() {
    print('\n${'=' * 60}');
    print('SCALING ANALYSIS: $name');
    print('=' * 60);

    // Group by operation name
    final grouped = <String, List<BenchmarkResult>>{};
    for (final result in results) {
      grouped.putIfAbsent(result.name, () => []).add(result);
    }

    for (final entry in grouped.entries) {
      print('\n${entry.key}:');
      final sorted = entry.value
        ..sort((a, b) => a.itemCount.compareTo(b.itemCount));
      for (final result in sorted) {
        final perItem = result.averageMicroseconds / result.itemCount;
        final count = result.itemCount.toString().padLeft(6);
        final total = result.averageMicroseconds.toStringAsFixed(0).padLeft(8);
        final perItemStr = perItem.toStringAsFixed(3).padLeft(8);
        print('  n=$count: $total us total, $perItemStr us/item');
      }
    }
    print('=' * 60);
  }

  void _forceGC() {
    // Attempt to trigger GC by allocating and releasing memory
    // This is not guaranteed but helps reduce noise
    List.generate(10000, (i) => i).clear();
  }

  int? _getMemoryUsage() {
    try {
      return ProcessInfo.currentRss;
    } on Object {
      return null;
    }
  }
}

/// Simple item for benchmarking.
class BenchmarkItem {
  const BenchmarkItem({
    required this.id,
    required this.name,
    required this.value,
    required this.category,
  });

  final String id;
  final String name;
  final int value;
  final String category;

  static List<BenchmarkItem> generate(int count) {
    final categories = ['A', 'B', 'C', 'D', 'E'];
    return List.generate(
      count,
      (i) => BenchmarkItem(
        id: 'item_$i',
        name: 'Item $i',
        value: i % 1000,
        category: categories[i % categories.length],
      ),
    );
  }
}
