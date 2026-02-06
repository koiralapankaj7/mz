# mz_collection

Pure Dart collection state management for lists, tables, trees, and more. Includes filtering, sorting, grouping, selection, pagination, aggregation, and fuzzy search.

## Installation

```yaml
dependencies:
  mz_collection: ^0.0.1
```

## Quick Start

```dart
import 'package:mz_collection/mz_collection.dart';

// Create a controller with your data type
final controller = CollectionController<Task>(
  keyOf: (task) => task.id,
);

// Add data
controller.addAll(tasks);

// Access filtered, sorted, grouped data
for (final item in controller.root.items) {
  print(item.name);
}
```

See [architecture.md](architecture.md) for complete documentation.

## Features

| Feature | Description |
|---------|-------------|
| **Filtering** | Multi-filter support, AND/OR/NOT expressions, local/remote |
| **Sorting** | Multi-level sorting, ascending/descending, custom comparators |
| **Grouping** | Single and multi-value grouping with aggregations |
| **Selection** | Multi-scope selection with tri-state support |
| **Pagination** | Cursor and offset pagination with infinite scroll |
| **Aggregation** | Count, sum, avg, min, max, first, last, custom |
| **Fuzzy Search** | Levenshtein-based fuzzy matching with scoring |
| **Tree Structure** | Hierarchical data with expand/collapse |
| **Virtualization** | SlotManager for efficient large list rendering |
| **State Serialization** | Save/restore state for deep linking and persistence |

## Architecture

```
CollectionController<T>
    │
    ├── FilterManager<T>      (optional)
    ├── SortManager<T>        (optional)
    ├── GroupManager<T>       (optional)
    ├── SelectionManager      (built-in)
    ├── PaginationState       (built-in)
    │
    └── root: Node<T>         (tree output)
            │
            └── SlotManager<T>  (virtualized list)
```

## Example Usage

### Basic Collection

```dart
final controller = CollectionController<User>(
  keyOf: (user) => user.id,
);

controller.addAll(users);
print(controller.length); // filtered count
```

### Filtering

```dart
final filter = FilterManager<User>(
  filters: [
    Filter<User, String>(
      id: 'role',
      test: (user, value) => user.role == value,
    ),
  ],
);

final controller = CollectionController<User>(
  keyOf: (user) => user.id,
  filter: filter,
);

// Filter to admins only
filter['role']!.add('admin');
```

### Sorting

```dart
final sort = SortManager<User>(
  options: [
    SortOption<User, String>(
      id: 'name',
      sortIdentifier: (user) => user.name,
    ),
  ],
);

final controller = CollectionController<User>(
  keyOf: (user) => user.id,
  sort: sort,
);

// Sort by name descending
sort.setCurrent(sort['name']!);
sort.setOrder(SortOrder.descending);
```

### Grouping

```dart
final group = GroupManager<User>(
  options: [
    GroupOption<User, String>(
      id: 'department',
      valueBuilder: (user) => user.department,
    ),
  ],
);

final controller = CollectionController<User>(
  keyOf: (user) => user.id,
  group: group,
);

// Access grouped data
for (final groupNode in controller.root.children.values) {
  print('${groupNode.id}: ${groupNode.length} users');
}
```

### With Data Loader

```dart
final controller = CollectionController<User>(
  keyOf: (user) => user.id,
  dataLoader: (request) async {
    final response = await api.fetchUsers(
      offset: request.token?.offset ?? 0,
      limit: request.limit,
      filter: request.filter,
      sort: request.sort,
    );
    return PageResponse(
      items: response.users,
      nextToken: response.hasMore 
          ? PageToken.offset(response.offset + response.limit)
          : null,
    );
  },
);

// Initial load
await controller.load();

// Load more (pagination)
await controller.load();
```

## Requirements

- Dart SDK: ^3.6.0

## License

BSD-style license. See LICENSE file.
