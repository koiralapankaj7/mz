import 'package:flutter/material.dart';
import 'package:mz_collection/mz_collection.dart';

/// Demonstrates bi-directional pagination with a document viewer.
/// Simulates loading pages of a document on scroll.
class DocumentViewerDemo extends StatefulWidget {
  const DocumentViewerDemo({super.key});

  @override
  State<DocumentViewerDemo> createState() => _DocumentViewerDemoState();
}

class _DocumentViewerDemoState extends State<DocumentViewerDemo> {
  final ScrollController _scrollController = ScrollController();
  late final PaginationState _paginationState;

  // Document pages - each page has content
  final List<DocumentPage> _pages = [];

  // Current page range (1-indexed for display)
  int _firstPage = 1;
  int _lastPage = 0;

  // Total pages in the "document"
  static const _totalPages = 50;
  static const _initialPages = 5;
  static const _pageSize = 3;
  static const _loadDelay = Duration(milliseconds: 400);
  static const _scrollThreshold = 300.0;

  bool _hasScrolledUp = false;

  @override
  void initState() {
    super.initState();
    _paginationState = PaginationState();
    // Register edges using their string IDs
    _paginationState.addEdge(PaginationEdge.top);
    _paginationState.addEdge(PaginationEdge.bottom);
    _paginationState.addChangeListener(_onPaginationChanged);
    _scrollController.addListener(_onScroll);
    _loadInitialPages();
  }

  void _loadInitialPages() {
    for (var i = 1; i <= _initialPages; i++) {
      _pages.add(_generatePage(i));
    }
    _firstPage = 1;
    _lastPage = _initialPages;
  }

  void _onPaginationChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;

    // Track if user has scrolled away from top
    if (position.pixels > _scrollThreshold) {
      _hasScrolledUp = true;
    }

    // Check for loading previous pages (scroll to top)
    if (_hasScrolledUp && position.pixels <= _scrollThreshold) {
      _loadPreviousPages();
    }

    // Check for loading next pages (scroll to bottom)
    if (position.pixels >= position.maxScrollExtent - _scrollThreshold) {
      _loadNextPages();
    }
  }

  Future<void> _loadPreviousPages() async {
    if (!_paginationState.canLoad(PaginationEdge.top.id)) return;
    if (_firstPage <= 1) return;
    if (!_paginationState.startLoading(PaginationEdge.top.id)) return;

    try {
      await Future<void>.delayed(_loadDelay);
      if (!mounted) return;

      final newFirstPage = (_firstPage - _pageSize).clamp(1, _firstPage);
      final pagesToAdd = _firstPage - newFirstPage;

      if (pagesToAdd > 0) {
        final currentOffset = _scrollController.offset;

        final newPages = <DocumentPage>[];
        for (var i = newFirstPage; i < _firstPage; i++) {
          newPages.add(_generatePage(i));
        }

        setState(() {
          _pages.insertAll(0, newPages);
          _firstPage = newFirstPage;
        });

        // Maintain scroll position after prepending
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            final addedHeight = pagesToAdd * _estimatedPageHeight;
            _scrollController.jumpTo(currentOffset + addedHeight);
          }
        });
      }

      _paginationState.complete(
        PaginationEdge.top.id,
        nextToken:
            newFirstPage > 1 ? PageToken.offset(newFirstPage) : PageToken.end,
      );
    } catch (e) {
      _paginationState.fail(PaginationEdge.top.id, e);
    }
  }

  Future<void> _loadNextPages() async {
    if (!_paginationState.canLoad(PaginationEdge.bottom.id)) return;
    if (_lastPage >= _totalPages) return;
    if (!_paginationState.startLoading(PaginationEdge.bottom.id)) return;

    try {
      await Future<void>.delayed(_loadDelay);
      if (!mounted) return;

      final newLastPage = (_lastPage + _pageSize).clamp(_lastPage, _totalPages);
      final pagesToAdd = newLastPage - _lastPage;

      if (pagesToAdd > 0) {
        final newPages = <DocumentPage>[];
        for (var i = _lastPage + 1; i <= newLastPage; i++) {
          newPages.add(_generatePage(i));
        }

        setState(() {
          _pages.addAll(newPages);
          _lastPage = newLastPage;
        });
      }

      _paginationState.complete(
        PaginationEdge.bottom.id,
        nextToken: newLastPage < _totalPages
            ? PageToken.offset(newLastPage)
            : PageToken.end,
      );
    } catch (e) {
      _paginationState.fail(PaginationEdge.bottom.id, e);
    }
  }

  // Estimated height for scroll position adjustment
  double get _estimatedPageHeight => 400.0;

  DocumentPage _generatePage(int pageNumber) {
    return DocumentPage(
      number: pageNumber,
      title: _getPageTitle(pageNumber),
      paragraphs: _generateParagraphs(pageNumber),
    );
  }

  String _getPageTitle(int pageNumber) {
    final titles = [
      'Introduction',
      'Getting Started',
      'Core Concepts',
      'Architecture Overview',
      'Data Structures',
      'Algorithms',
      'Best Practices',
      'Performance Tips',
      'Testing Strategies',
      'Deployment Guide',
      'Troubleshooting',
      'API Reference',
      'Configuration',
      'Security Guidelines',
      'Appendix',
    ];
    return '${titles[(pageNumber - 1) % titles.length]} (Part ${(pageNumber - 1) ~/ titles.length + 1})';
  }

  List<String> _generateParagraphs(int pageNumber) {
    final paragraphs = <String>[];
    final seed = pageNumber * 17;

    final loremParts = [
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
      'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
      'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.',
      'Duis aute irure dolor in reprehenderit in voluptate velit esse.',
      'Excepteur sint occaecat cupidatat non proident, sunt in culpa.',
      'Nulla facilisi morbi tempus iaculis urna id volutpat lacus.',
      'Amet consectetur adipiscing elit pellentesque habitant morbi.',
      'Viverra accumsan in nisl nisi scelerisque eu ultrices vitae.',
    ];

    final numParagraphs = 3 + (seed % 3);
    for (var i = 0; i < numParagraphs; i++) {
      final startIdx = (seed + i * 3) % loremParts.length;
      final para = StringBuffer();
      for (var j = 0; j < 3; j++) {
        para.write(loremParts[(startIdx + j) % loremParts.length]);
        para.write(' ');
      }
      paragraphs.add(para.toString().trim());
    }

    return paragraphs;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _paginationState.removeChangeListener(_onPaginationChanged);
    super.dispose();
  }

  void _reset() {
    setState(() {
      _pages.clear();
      _hasScrolledUp = false;
      _paginationState.resetAll();
    });
    _loadInitialPages();
    _scrollController.jumpTo(0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final topState = _paginationState.getState(PaginationEdge.top.id);
    final bottomState = _paginationState.getState(PaginationEdge.bottom.id);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Document Viewer', style: TextStyle(fontSize: 16)),
            Text(
              'Pages $_firstPage-$_lastPage of $_totalPages',
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
          Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _pages.length,
              itemBuilder: (context, index) => _buildPageCard(_pages[index]),
            ),
          ),
          // Top loading indicator
          if (topState != null && topState.isLoading)
            Positioned(
              left: 0,
              right: 0,
              top: 16,
              child: _buildLoadingIndicator('Loading previous pages...'),
            ),
          // Bottom loading indicator
          if (bottomState != null && bottomState.isLoading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: _buildLoadingIndicator('Loading more pages...'),
            ),
        ],
      ),
    );
  }

  Widget _buildPageCard(DocumentPage page) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Page header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Page ${page.number}',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    page.title,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Page content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < page.paragraphs.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Text(
                    page.paragraphs[i],
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Page footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Text(
              '— Page ${page.number} of $_totalPages —',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(String text) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
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
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(text, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// A page in the document.
class DocumentPage {
  const DocumentPage({
    required this.number,
    required this.title,
    required this.paragraphs,
  });

  final int number;
  final String title;
  final List<String> paragraphs;
}
