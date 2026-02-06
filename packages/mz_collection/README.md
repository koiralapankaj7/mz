# mz_collection

Pure Dart collection state management for lists, tables, trees, and more. Includes filtering, sorting, grouping, selection, pagination, aggregation, and fuzzy search.

[![pub package](https://img.shields.io/pub/v/mz_collection.svg)](https://pub.dev/packages/mz_collection)
[![License: BSD](https://img.shields.io/badge/License-BSD-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![codecov](https://codecov.io/gh/koiralapankaj7/mz/branch/main/graph/badge.svg?flag=mz_collection)](https://codecov.io/gh/koiralapankaj7/mz)
[![CI](https://github.com/koiralapankaj7/mz/workflows/CI/badge.svg)](https://github.com/koiralapankaj7/mz/actions)

## Features

| Feature | Description |
| ------- | ----------- |
| **Filtering** | Multi-filter support with AND/OR/NOT expressions, local and remote processing |
| **Sorting** | Multi-level sorting with ascending/descending order and custom comparators |
| **Grouping** | Single and multi-value grouping with nested hierarchies and aggregations |
| **Selection** | Multi-scope selection with single/multi modes and tri-state support |
| **Pagination** | Cursor and offset pagination with infinite scroll and bidirectional loading |
| **Aggregation** | Built-in count, sum, avg, min, max, first, last, and custom aggregators |
| **Fuzzy Search** | Levenshtein-based fuzzy matching with configurable scoring thresholds |
| **Tree Structure** | Hierarchical data representation with expand/collapse and lazy loading |
| **Virtualization** | SlotManager for efficient large list rendering with expand/collapse |
| **State Serialization** | Save/restore state for deep linking, URL query params, and persistence |

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  mz_collection: ^0.0.1
```

Then run:

```bash
dart pub get
```

## Quick Start

### Basic Collection

```dart
import 'package:mz_collection/mz_collection.dart';

// Create a controller with your data type
final controller = CollectionController<Task>(
  keyOf: (task) => task.id,
);

// Add data
controller.addAll(tasks);

// Access items
print('Total: ${controller.length}');
for (final task in controller.items) {
  print(task.title);
}

// CRUD operations
controller.add(newTask);
controller.update('task-1', (t) => t.copyWith(done: true));
controller.remove('task-1');
```

### Filtering

```dart
// Define filters
final filter = FilterManager<Task>(
  filters: [
    Filter<Task, String>(
      id: 'status',
      test: (task, value) => task.status == value,
    ),
    Filter<Task, String>(
      id: 'priority',
      test: (task, value) => task.priority == value,
    ),
  ],
);

// Create controller with filter
final controller = CollectionController<Task>(
  keyOf: (task) => task.id,
  filter: filter,
);

controller.addAll(tasks);

// Apply filters
filter['status']!.add('active');      // Show only active tasks
filter['priority']!.add('high');      // AND high priority

// Clear a filter
filter['status']!.clear();
```

### Sorting

```dart
// Define sort options
final sort = SortManager<Task>(
  options: [
    SortOption<Task, DateTime>(
      id: 'createdAt',
      sortIdentifier: (task) => task.createdAt,
    ),
    SortOption<Task, String>(
      id: 'title',
      sortIdentifier: (task) => task.title,
    ),
    SortOption<Task, int>(
      id: 'priority',
      sortIdentifier: (task) => task.priorityLevel,
    ),
  ],
);

// Create controller with sort
final controller = CollectionController<Task>(
  keyOf: (task) => task.id,
  sort: sort,
);

// Apply sorting
sort.setCurrent(sort['createdAt']!);
sort.setOrder(SortOrder.descending);  // Newest first
```

### Grouping

```dart
// Define grouping options
final group = GroupManager<Task>(
  options: [
    GroupOption<Task, String>(
      id: 'status',
      valueBuilder: (task) => task.status,
      labelBuilder: (status) => status.toUpperCase(),
    ),
  ],
);

// Create controller with grouping
final controller = CollectionController<Task>(
  keyOf: (task) => task.id,
  group: group,
);

controller.addAll(tasks);

// Access grouped data via tree structure
for (final groupNode in controller.root.children.values) {
  print('${groupNode.id}: ${groupNode.length} tasks');
  for (final task in groupNode.items) {
    print('  - ${task.title}');
  }
}
```

### Selection

```dart
final controller = CollectionController<Task>(
  keyOf: (task) => task.id,
  selection: SelectionManager(mode: SelectionMode.multi),
);

controller.addAll(tasks);

// Select items
controller.selection.select('task-1');
controller.selection.select('task-2');

// Check selection
if (controller.selection.isSelected('task-1')) {
  print('Task 1 is selected');
}

// Get selected items
final selectedKeys = controller.selection.selectedKeys;
final selectedTasks = controller.getAll(selectedKeys.toList());

// Toggle selection
controller.selection.toggle('task-3');

// Clear selection
controller.selection.clear();
```

### Pagination with Data Loader

```dart
final controller = CollectionController<Task>(
  keyOf: (task) => task.id,
  dataLoader: (request) async {
    // Fetch from your API
    final response = await api.fetchTasks(
      offset: request.token is OffsetToken
          ? (request.token as OffsetToken).offset
          : 0,
      limit: request.limit,
      filters: request.filters,
      sort: request.sort,
    );
    
    return PageResponse(
      items: response.tasks,
      nextToken: response.hasMore 
          ? PageToken.offset(response.nextOffset)
          : PageToken.end,
    );
  },
);

// Initial load
await controller.load();

// Load more (infinite scroll)
await controller.load();  // Automatically uses next token

// Force refresh
await controller.refresh();

// Check pagination state
if (controller.pagination.canLoad(PaginationEdge.trailing.id)) {
  await controller.load();
}
```

### State Serialization

```dart
// Capture current state
final snapshot = controller.captureState();

// Convert to JSON for persistence
final json = snapshot.toJson();
await storage.save('collection_state', json);

// Or convert to URL query string
final queryString = snapshot.toQueryString();
// e.g., "filter.status=active&sort=createdAt&order=desc"

// Restore from JSON
final savedJson = await storage.load('collection_state');
controller.restoreState(CollectionSnapshot.fromJson(savedJson));

// Or restore from URL query string
controller.restoreState(CollectionSnapshot.fromQueryString(queryString));
```

## Architecture

```
CollectionController<T>
    |
    +-- FilterManager<T>      (optional) - Multi-filter with AND/OR/NOT
    +-- SortManager<T>        (optional) - Multi-level sorting
    +-- GroupManager<T>       (optional) - Hierarchical grouping
    +-- SelectionManager      (built-in)  - Selection tracking
    +-- PaginationState       (built-in)  - Pagination tracking
    |
    +-- root: Node<T>         (output)    - Tree structure for display
            |
            +-- SlotManager<T>  (optional) - Virtualized list rendering
```

### Key Design Principles

1. **Controller owns data** - CRUD operations go directly to controller
2. **Managers are optional** - Use only what you need
3. **Key-based operations** - `update(key, fn)`, `remove(key)` for O(1) lookup
4. **Local/Remote transforms** - Each filter/sort declares where it runs
5. **Tree output** - All data exposed as `Node<T>` tree for flexible rendering

## Documentation

| Resource | Description |
| -------- | ----------- |
| [Architecture](architecture.md) | Detailed architecture and design patterns |
| [API Reference](https://pub.dev/documentation/mz_collection/latest/) | Complete API documentation |

## Features in Detail

### FilterManager

Multi-filter support with flexible composition:

- Multiple filters with independent values
- AND/OR/NOT filter expressions
- Local, remote, or combined processing via `TransformSource`
- Search filter with fuzzy matching support

**Use case**: Filtering tables, lists, search results

### SortManager

Multi-level sorting with full control:

- Multiple sort options with priority ordering
- Ascending/descending toggle per option
- Custom comparators for complex types
- Local or remote sorting

**Use case**: Sortable tables, ordered lists

### GroupManager

Hierarchical grouping with aggregations:

- Single-value grouping (item in one group)
- Multi-value grouping (item in multiple groups)
- Nested multi-level grouping
- Group-level aggregations (count, sum, etc.)

**Use case**: Grouped lists, category views, pivot tables

### SelectionManager

Flexible selection tracking:

- Single and multi-selection modes
- Tri-state support for hierarchical selection
- Scope-based selection for grouped items
- Selection change notifications

**Use case**: Multi-select lists, bulk actions, tree selection

### Pagination

Cursor and offset pagination:

- Leading and trailing edge pagination
- Automatic "load more" detection
- Bidirectional loading for chat-style UIs
- Integration with remote data sources

**Use case**: Infinite scroll, paginated APIs, large datasets

### Node Tree

Hierarchical data structure:

- Flat or grouped item organization
- Expand/collapse state management
- Lazy loading of children
- Efficient tree traversal

**Use case**: File explorers, org charts, nested menus

### SlotManager

Virtualized rendering support:

- Flattens tree to indexed slots
- Handles expand/collapse efficiently
- O(1) index-to-node lookup
- Minimal memory footprint

**Use case**: Large lists, virtualized scroll views

## Examples

### Example 1: Task Manager with Filtering and Grouping

```dart
import 'package:mz_collection/mz_collection.dart';

class Task {
  final String id;
  final String title;
  final String status;
  final DateTime dueDate;
  
  Task({
    required this.id, 
    required this.title, 
    required this.status,
    required this.dueDate,
  });
}

void main() {
  // Setup managers
  final filter = FilterManager<Task>(
    filters: [
      Filter<Task, String>(
        id: 'status',
        test: (task, value) => task.status == value,
      ),
    ],
  );

  final sort = SortManager<Task>(
    options: [
      SortOption<Task, DateTime>(
        id: 'dueDate',
        sortIdentifier: (task) => task.dueDate,
      ),
    ],
  );

  final group = GroupManager<Task>(
    options: [
      GroupOption<Task, String>(
        id: 'status',
        valueBuilder: (task) => task.status,
      ),
    ],
  );

  // Create controller
  final controller = CollectionController<Task>(
    keyOf: (task) => task.id,
    filter: filter,
    sort: sort,
    group: group,
  );

  // Add tasks
  controller.addAll([
    Task(id: '1', title: 'Review PR', status: 'todo', dueDate: DateTime.now()),
    Task(id: '2', title: 'Fix bug', status: 'in_progress', dueDate: DateTime.now().add(Duration(days: 1))),
    Task(id: '3', title: 'Write tests', status: 'todo', dueDate: DateTime.now().add(Duration(days: 2))),
  ]);

  // Apply transformations
  sort.setCurrent(sort['dueDate']!);
  sort.setOrder(SortOrder.ascending);

  // Print grouped results
  for (final groupNode in controller.root.children.values) {
    print('\n${groupNode.id.toUpperCase()}:');
    for (final task in groupNode.items) {
      print('  - ${task.title} (due: ${task.dueDate})');
    }
  }

  // Cleanup
  controller.dispose();
}
```

### Example 2: Paginated API Integration

```dart
import 'package:mz_collection/mz_collection.dart';

class User {
  final String id;
  final String name;
  final String email;
  
  User({required this.id, required this.name, required this.email});
}

class UserApi {
  Future<({List<User> users, int nextOffset, bool hasMore})> fetchUsers({
    required int offset,
    required int limit,
  }) async {
    // Simulated API call
    await Future.delayed(Duration(milliseconds: 500));
    
    final users = List.generate(
      limit,
      (i) => User(
        id: 'user-${offset + i}',
        name: 'User ${offset + i}',
        email: 'user${offset + i}@example.com',
      ),
    );
    
    return (
      users: users,
      nextOffset: offset + limit,
      hasMore: offset + limit < 100,
    );
  }
}

void main() async {
  final api = UserApi();

  final controller = CollectionController<User>(
    keyOf: (user) => user.id,
    dataLoader: (request) async {
      final offset = request.token is OffsetToken
          ? (request.token as OffsetToken).offset
          : 0;
      
      final result = await api.fetchUsers(
        offset: offset,
        limit: request.limit,
      );
      
      return PageResponse(
        items: result.users,
        nextToken: result.hasMore 
            ? PageToken.offset(result.nextOffset)
            : PageToken.end,
      );
    },
  );

  // Initial load
  await controller.load();
  print('Loaded ${controller.length} users');

  // Load more
  await controller.load();
  print('Total: ${controller.length} users');

  // Refresh (reload from beginning)
  await controller.refresh();
  print('After refresh: ${controller.length} users');

  controller.dispose();
}
```

## Testing

mz_collection is fully tested with comprehensive test coverage:

- Unit tests for all managers and controllers
- Integration tests for complex scenarios
- Edge case coverage for pagination and state

Run tests:

```bash
dart test
```

## Requirements

- **Dart SDK**: ^3.5.0

## Contributing

Contributions are welcome! Please:

1. Read the [contribution guidelines](../../CONTRIBUTING.md)
2. Fork the repository
3. Create a feature branch
4. Write tests for new features
5. Ensure all tests pass
6. Submit a pull request

## License

This package is released under the [BSD-3-Clause License](LICENSE).

## Credits

Developed and maintained by [Pankaj Koirala](https://github.com/koiralapankaj7).

## Support

- **Issues**: [GitHub Issues](https://github.com/koiralapankaj7/mz/issues)
- **Discussions**: [GitHub Discussions](https://github.com/koiralapankaj7/mz/discussions)
- **Repository**: [GitHub](https://github.com/koiralapankaj7/mz/tree/main/packages/mz_collection)

## Related Packages

- [mz_core](https://pub.dev/packages/mz_core) - Flutter utilities for state management, logging, and more
- [collection](https://pub.dev/packages/collection) - Dart collections utilities
- [fast_immutable_collections](https://pub.dev/packages/fast_immutable_collections) - Immutable collections

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
