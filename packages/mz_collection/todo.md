# mz_collection - Future Features

This document tracks features planned for future implementation.

## High Priority

### 1. CSV Export

Export collection data to CSV string format.

**Estimated Effort**: Low

**API Design**:

```dart
class CsvExporter<T> {
  CsvExporter({required this.columns});
  
  final List<CsvColumn<T>> columns;
  
  String export(Iterable<T> items, {bool includeHeader = true});
  List<List<String>> exportAsRows(Iterable<T> items);
}

class CsvColumn<T> {
  const CsvColumn({required this.header, required this.getValue});
  
  final String header;
  final String Function(T item) getValue;
}
```

---

### 2. JSON Export

Export collection data to JSON string with optional transforms.

**Estimated Effort**: Low

**API Design**:

```dart
class JsonExporter<T> {
  String export(
    Iterable<T> items, {
    Object? Function(T)? toJson,
    bool pretty = false,
  });
}
```

---

### 3. CSV Import

Parse CSV string into items with validation support.

**Estimated Effort**: Medium

**API Design**:

```dart
class CsvImporter<T> {
  CsvImporter({required this.fromRow});
  
  final T Function(Map<String, String> row) fromRow;
  
  List<T> import(String csv, {bool hasHeader = true});
  ImportResult<T> importWithValidation(
    String csv, {
    bool hasHeader = true,
    Validator<T>? validator,
  });
}

class ImportResult<T> {
  final List<T> valid;
  final List<ImportError> errors;
}

class ImportError {
  final int row;
  final List<String> messages;
}
```

---

### 4. JSON Import

Parse JSON string/array into items with validation support.

**Estimated Effort**: Low

**API Design**:

```dart
class JsonImporter<T> {
  JsonImporter({required this.fromJson});
  
  final T Function(Map<String, dynamic> json) fromJson;
  
  List<T> import(String jsonString);
  ImportResult<T> importWithValidation(
    String jsonString, {
    Validator<T>? validator,
  });
}
```

---

### 5. Data Validation

Validate items against rules, return field-level errors.

**Estimated Effort**: Medium

**API Design**:

```dart
typedef Validator<T> = ValidationResult Function(T item);

class ValidationResult {
  final bool isValid;
  final Map<String, List<String>> errors; // field -> messages
  
  factory ValidationResult.valid();
  factory ValidationResult.invalid(Map<String, List<String>> errors);
}

// Extension on CollectionController
extension CollectionValidation<K, T> on CollectionController<K, T> {
  void setValidator(Validator<T>? validator);
  ValidationResult validate(T item);
  List<(K key, ValidationResult result)> validateAll();
}
```

---

## Medium Priority

### 6. Snapshots

Capture current state for "has changed?" comparisons (dirty checking).

**Estimated Effort**: Low

**API Design**:

```dart
class DataSnapshot<K, T> {
  final List<T> items;
  final int itemCount;
  final int version;
  final DateTime timestamp;
}

// On CollectionController
DataSnapshot<K, T> dataSnapshot();
bool hasDataChangesFrom(DataSnapshot<K, T> snapshot);
```

---

### 7. Computed Fields

Register derived/calculated fields that can be accessed like regular fields.

**Estimated Effort**: Medium

**API Design**:

```dart
class ComputedField<T, R> {
  const ComputedField({
    required this.id,
    required this.compute,
    this.cache = false,
  });
  
  final String id;
  final R Function(T item) compute;
  final bool cache;
}

// On CollectionController
void registerComputed<R>(ComputedField<T, R> field);
void unregisterComputed(String id);
R? computed<R>(String id, T item);
```

---

### 8. Data Diffing

Compare two collections, return added/removed/modified items.

**Estimated Effort**: Medium

**API Design**:

```dart
class CollectionDiff<K, T> {
  final List<T> added;
  final List<T> removed;
  final List<ItemChange<T>> modified;
  final List<MoveChange<K>> moved; // For trees
  
  bool get isEmpty;
  bool get hasChanges;
}

class ItemChange<T> {
  final T oldItem;
  final T newItem;
}

class MoveChange<K> {
  final K key;
  final K? oldParentKey;
  final K? newParentKey;
}

// Usage
CollectionDiff<K, T> diff(
  Iterable<T> oldItems,
  Iterable<T> newItems, {
  bool Function(T a, T b)? equals,
});
```

---

## Lower Priority

### 9. Query Builder

Programmatic query construction for power users.

**Estimated Effort**: High

**API Design**:

```dart
class QueryBuilder<T> {
  QueryBuilder<T> where(String field, {
    Object? equals,
    Object? notEquals,
    Object? greaterThan,
    Object? lessThan,
    Iterable<Object>? isIn,
    bool? isNull,
  });
  
  QueryBuilder<T> orderBy(String field, {bool descending = false});
  QueryBuilder<T> groupBy(String field);
  QueryBuilder<T> limit(int count);
  QueryBuilder<T> offset(int count);
  
  Query<T> build();
}

class Query<T> {
  final List<QueryCondition> conditions;
  final List<QuerySort> sorts;
  final List<String> groups;
  final int? limit;
  final int? offset;
}

// Usage
final query = QueryBuilder<Task>()
  .where('status', equals: 'active')
  .where('priority', greaterThan: 2)
  .orderBy('createdAt', descending: true)
  .groupBy('assignee')
  .limit(50)
  .build();
```

---

### 10. Conflict Resolution

Strategies for handling concurrent edits in collaborative apps.

**Estimated Effort**: High

**API Design**:

```dart
enum ConflictStrategy { 
  keepLocal, 
  keepRemote, 
  merge, 
  manual,
}

typedef ConflictResolver<T> = T Function(T local, T remote);

class ConflictPolicy<T> {
  final ConflictStrategy strategy;
  final ConflictResolver<T>? resolver;
}

// On Store
void setConflictPolicy(ConflictPolicy<T> policy);
```

---

### 11. Relationship Cascades

Define cascade behavior when linked nodes are deleted.

**Estimated Effort**: Medium

**API Design**:

```dart
enum CascadeAction { 
  none,      // Do nothing
  nullify,   // Set reference to null
  delete,    // Delete related items
  restrict,  // Prevent deletion if has relations
}

class CascadePolicy {
  final String linkType;
  final CascadeAction onDelete;
  final CascadeAction onUpdate;
}

// On LinkManager
void setCascadePolicy(CascadePolicy policy);
List<CascadePolicy> get cascadePolicies;
```

---

## Notes

- Features should be implemented following the existing code style and patterns
- Each feature should include comprehensive documentation
- Tests should be added using the `/dart-test-generator` skill
- Consider backward compatibility when adding new APIs
