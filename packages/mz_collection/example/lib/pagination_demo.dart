import 'package:flutter/material.dart';
import 'package:mz_collection/mz_collection.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

/// Demonstrates bi-directional pagination with TableView.
/// Supports all 4 edges: top, bottom, left, right.
class PaginationDemo extends StatefulWidget {
  const PaginationDemo({super.key});

  @override
  State<PaginationDemo> createState() => _PaginationDemoState();
}

class _PaginationDemoState extends State<PaginationDemo> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  // Data range tracking - logical coordinates
  // Rows: [_rowStart, _rowEnd) - e.g., -20 to 30 means rows -20 through 29
  int _rowStart = 0;
  int _rowEnd = 30;

  // Columns: [_colStart, _colEnd)
  int _colStart = 0;
  int _colEnd = 30;

  // Derived counts
  int get _rowCount => _rowEnd - _rowStart;
  int get _colCount => _colEnd - _colStart;

  static const _cellWidth = 100.0;
  static const _cellHeight = 50.0;

  // Pagination config
  static const _pageSize = 20;
  static const _maxExtent = 100; // Max distance from origin in any direction
  static const _loadDelay = Duration(milliseconds: 500);
  static const _threshold = 200.0;

  // Track if user has scrolled away from initial position
  // This prevents auto-triggering top/left on initial load
  bool _hasScrolledVertically = false;
  bool _hasScrolledHorizontally = false;

  late final PaginationState _paginationState;

  @override
  void initState() {
    super.initState();

    _paginationState = PaginationState();
    // Register edges using their string IDs
    _paginationState.addEdge(PaginationEdge.top);
    _paginationState.addEdge(PaginationEdge.bottom);
    _paginationState.addEdge(PaginationEdge.left);
    _paginationState.addEdge(PaginationEdge.right);

    _paginationState.addChangeListener(_onPaginationChanged);
    _verticalController.addListener(_checkVerticalEdges);
    _horizontalController.addListener(_checkHorizontalEdges);
  }

  void _onPaginationChanged() {
    if (mounted) setState(() {});
  }

  void _checkVerticalEdges() {
    if (!_verticalController.hasClients) return;

    final position = _verticalController.position;
    if (!position.hasContentDimensions) return;

    // Track if user has scrolled away from top
    // Once they've scrolled down, we can trigger top loading when they scroll back
    if (position.pixels > _threshold) {
      _hasScrolledVertically = true;
    }

    // Check top edge - only if user has scrolled away first
    if (_hasScrolledVertically && position.pixels <= _threshold) {
      _loadTop();
    }

    // Check bottom edge - always active
    if (position.pixels >= position.maxScrollExtent - _threshold) {
      _loadBottom();
    }
  }

  void _checkHorizontalEdges() {
    if (!_horizontalController.hasClients) return;

    final position = _horizontalController.position;
    if (!position.hasContentDimensions) return;

    // Track if user has scrolled away from left
    if (position.pixels > _threshold) {
      _hasScrolledHorizontally = true;
    }

    // Check left edge - only if user has scrolled away first
    if (_hasScrolledHorizontally && position.pixels <= _threshold) {
      _loadLeft();
    }

    // Check right edge - always active
    if (position.pixels >= position.maxScrollExtent - _threshold) {
      _loadRight();
    }
  }

  Future<void> _loadTop() async {
    if (!_paginationState.canLoad(PaginationEdge.top.id)) return;
    if (!_paginationState.startLoading(PaginationEdge.top.id)) return;

    try {
      await Future<void>.delayed(_loadDelay);
      if (!mounted) return;

      final newRowStart = (_rowStart - _pageSize).clamp(-_maxExtent, _rowEnd);
      final hasMore = newRowStart > -_maxExtent;
      final addedRows = _rowStart - newRowStart;

      if (addedRows > 0) {
        // Save scroll position and adjust after adding rows at top
        final currentOffset = _verticalController.offset;
        final addedHeight = addedRows * _cellHeight;

        setState(() {
          _rowStart = newRowStart;
        });

        // Jump to maintain visual position
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _verticalController.hasClients) {
            _verticalController.jumpTo(currentOffset + addedHeight);
          }
        });
      }

      _paginationState.complete(
        PaginationEdge.top.id,
        nextToken: hasMore ? PageToken.offset(newRowStart) : PageToken.end,
      );
    } catch (e) {
      _paginationState.fail(PaginationEdge.top.id, e);
    }
  }

  Future<void> _loadBottom() async {
    if (!_paginationState.canLoad(PaginationEdge.bottom.id)) return;
    if (!_paginationState.startLoading(PaginationEdge.bottom.id)) return;

    try {
      await Future<void>.delayed(_loadDelay);
      if (!mounted) return;

      final newRowEnd = (_rowEnd + _pageSize).clamp(_rowStart, _maxExtent);
      final hasMore = newRowEnd < _maxExtent;

      setState(() {
        _rowEnd = newRowEnd;
      });

      _paginationState.complete(
        PaginationEdge.bottom.id,
        nextToken: hasMore ? PageToken.offset(newRowEnd) : PageToken.end,
      );
    } catch (e) {
      _paginationState.fail(PaginationEdge.bottom.id, e);
    }
  }

  Future<void> _loadLeft() async {
    if (!_paginationState.canLoad(PaginationEdge.left.id)) return;
    if (!_paginationState.startLoading(PaginationEdge.left.id)) return;

    try {
      await Future<void>.delayed(_loadDelay);
      if (!mounted) return;

      final newColStart = (_colStart - _pageSize).clamp(-_maxExtent, _colEnd);
      final hasMore = newColStart > -_maxExtent;
      final addedCols = _colStart - newColStart;

      if (addedCols > 0) {
        // Save scroll position and adjust after adding columns at left
        final currentOffset = _horizontalController.offset;
        final addedWidth = addedCols * _cellWidth;

        setState(() {
          _colStart = newColStart;
        });

        // Jump to maintain visual position
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _horizontalController.hasClients) {
            _horizontalController.jumpTo(currentOffset + addedWidth);
          }
        });
      }

      _paginationState.complete(
        PaginationEdge.left.id,
        nextToken: hasMore ? PageToken.offset(newColStart) : PageToken.end,
      );
    } catch (e) {
      _paginationState.fail(PaginationEdge.left.id, e);
    }
  }

  Future<void> _loadRight() async {
    if (!_paginationState.canLoad(PaginationEdge.right.id)) return;
    if (!_paginationState.startLoading(PaginationEdge.right.id)) return;

    try {
      await Future<void>.delayed(_loadDelay);
      if (!mounted) return;

      final newColEnd = (_colEnd + _pageSize).clamp(_colStart, _maxExtent);
      final hasMore = newColEnd < _maxExtent;

      setState(() {
        _colEnd = newColEnd;
      });

      _paginationState.complete(
        PaginationEdge.right.id,
        nextToken: hasMore ? PageToken.offset(newColEnd) : PageToken.end,
      );
    } catch (e) {
      _paginationState.fail(PaginationEdge.right.id, e);
    }
  }

  @override
  void dispose() {
    _paginationState.removeChangeListener(_onPaginationChanged);
    _verticalController.removeListener(_checkVerticalEdges);
    _horizontalController.removeListener(_checkHorizontalEdges);
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topState = _paginationState.getState(PaginationEdge.top.id);
    final bottomState = _paginationState.getState(PaginationEdge.bottom.id);
    final leftState = _paginationState.getState(PaginationEdge.left.id);
    final rightState = _paginationState.getState(PaginationEdge.right.id);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pagination Demo', style: TextStyle(fontSize: 16)),
            Text(
              'Rows: $_rowStart to ${_rowEnd - 1} | '
              'Cols: $_colStart to ${_colEnd - 1}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Use separate scrollbars with proper orientation
          _buildScrollableGrid(),
          // Top loading indicator
          if (topState != null && topState.isLoading)
            Positioned(
              left: 0,
              right: 0,
              top: 16,
              child: _buildLoadingIndicator('Loading rows...'),
            ),
          // Bottom loading indicator
          if (bottomState != null && bottomState.isLoading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: _buildLoadingIndicator('Loading rows...'),
            ),
          // Left loading indicator
          if (leftState != null && leftState.isLoading)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(child: _buildLoadingIndicator('Loading cols...')),
            ),
          // Right loading indicator
          if (rightState != null && rightState.isLoading)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(child: _buildLoadingIndicator('Loading cols...')),
            ),
        ],
      ),
    );
  }

  Widget _buildScrollableGrid() {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(true),
      ),
      child: Scrollbar(
        controller: _verticalController,
        thumbVisibility: true,
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          // notificationPredicate: (n) => n.depth == 1,
          child: TableView.builder(
            verticalDetails: ScrollableDetails.vertical(
              controller: _verticalController,
            ),
            horizontalDetails: ScrollableDetails.horizontal(
              controller: _horizontalController,
            ),
            diagonalDragBehavior: DiagonalDragBehavior.free,
            cellBuilder: _buildCell,
            columnCount: _colCount,
            columnBuilder: _buildColumnSpan,
            rowCount: _rowCount,
            rowBuilder: _buildRowSpan,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _reset() {
    setState(() {
      _rowStart = 0;
      _rowEnd = 30;
      _colStart = 0;
      _colEnd = 30;
      _hasScrolledVertically = false;
      _hasScrolledHorizontally = false;
      _paginationState.resetAll();
    });
    _verticalController.jumpTo(0);
    _horizontalController.jumpTo(0);
  }

  TableSpan _buildColumnSpan(int index) {
    return const TableSpan(extent: FixedTableSpanExtent(_cellWidth));
  }

  TableSpan _buildRowSpan(int index) {
    return const TableSpan(extent: FixedTableSpanExtent(_cellHeight));
  }

  TableViewCell _buildCell(BuildContext context, TableVicinity vicinity) {
    // Convert table index to logical coordinates
    final logicalRow = vicinity.row + _rowStart;
    final logicalCol = vicinity.column + _colStart;

    // Alternating surface container colors for readability
    final colorScheme = Theme.of(context).colorScheme;
    final isEven = (vicinity.row + vicinity.column) % 2 == 0;
    final cellColor = isEven
        ? colorScheme.surfaceContainerLowest
        : colorScheme.surfaceContainerLow;

    return TableViewCell(
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            '$logicalRow,$logicalCol',
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }
}

// // =============================================================================
// // Export SimpleGridView for tests - wrapper around TableView
// // =============================================================================

// typedef CellBuilder = Widget Function(BuildContext context, int row, int col);

// class SimpleGridView extends StatelessWidget {
//   const SimpleGridView({
//     super.key,
//     required this.rowCount,
//     required this.columnCount,
//     required this.cellWidth,
//     required this.cellHeight,
//     required this.cellBuilder,
//     this.verticalController,
//     this.horizontalController,
//   });

//   final int rowCount;
//   final int columnCount;
//   final double cellWidth;
//   final double cellHeight;
//   final CellBuilder cellBuilder;
//   final ScrollController? verticalController;
//   final ScrollController? horizontalController;

//   @override
//   Widget build(BuildContext context) {
//     return Scrollbar(
//       controller: horizontalController,
//       thumbVisibility: true,
//       child: TableView.builder(
//         verticalDetails: ScrollableDetails.vertical(
//           controller: verticalController,
//         ),
//         horizontalDetails: ScrollableDetails.horizontal(
//           controller: horizontalController,
//         ),
//         diagonalDragBehavior: DiagonalDragBehavior.free,
//         cellBuilder: (context, vicinity) {
//           return TableViewCell(
//             child: cellBuilder(context, vicinity.row, vicinity.column),
//           );
//         },
//         columnCount: columnCount,
//         columnBuilder: (index) {
//           return TableSpan(extent: FixedTableSpanExtent(cellWidth));
//         },
//         rowCount: rowCount,
//         rowBuilder: (index) {
//           return TableSpan(extent: FixedTableSpanExtent(cellHeight));
//         },
//       ),
//     );
//   }
// }
