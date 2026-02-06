import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mz_collection/mz_collection.dart';

/// Demonstrates node-based pagination with a file explorer tree view.
/// Simulates browsing a large codebase like GitHub or an IDE.
class FileExplorerDemo extends StatefulWidget {
  const FileExplorerDemo({super.key});

  @override
  State<FileExplorerDemo> createState() => _FileExplorerDemoState();
}

class _FileExplorerDemoState extends State<FileExplorerDemo> {
  late final PaginationState _paginationState;
  final ScrollController _scrollController = ScrollController();

  // Loaded children by parent path (folders first, then files)
  final Map<String, List<FileNode>> _loadedFolders = {};
  final Map<String, List<FileNode>> _loadedFiles = {};

  // Track pagination phase: true = still loading folders, false = loading files
  final Map<String, bool> _inFolderPhase = {};

  // Track pages loaded per phase
  final Map<String, int> _folderPagesLoaded = {};
  final Map<String, int> _filePagesLoaded = {};

  // Expanded folders
  final Set<String> _expandedNodes = {};

  // Root nodes
  final List<FileNode> _rootNodes = [];

  // Keys for pagination tiles (to detect visibility)
  final Map<String, GlobalKey> _paginationKeys = {};

  // Settings
  bool _autoLoadEnabled = true;

  static const _scrollThreshold = 100.0;
  static const _loadDelay = Duration(milliseconds: 400);
  static const _itemsPerPage = 5;
  static const _maxFolderPages = 2; // 2 pages of folders (~6-10 folders)
  static const _maxFilePages = 3; // 3 pages of files (~15 files)

  @override
  void initState() {
    super.initState();
    _paginationState = PaginationState();
    _paginationState.addChangeListener(_onPaginationChanged);
    _scrollController.addListener(_onScroll);
    _initializeRoot();
  }

  void _initializeRoot() {
    // Simulate a typical project structure
    _rootNodes.addAll([
      FileNode(
        path: '.github',
        name: '.github',
        type: FileType.folder,
        depth: 0,
      ),
      FileNode(path: 'docs', name: 'docs', type: FileType.folder, depth: 0),
      FileNode(path: 'lib', name: 'lib', type: FileType.folder, depth: 0),
      FileNode(path: 'test', name: 'test', type: FileType.folder, depth: 0),
      FileNode(
        path: 'example',
        name: 'example',
        type: FileType.folder,
        depth: 0,
      ),
      FileNode(
        path: '.gitignore',
        name: '.gitignore',
        type: FileType.file,
        depth: 0,
      ),
      FileNode(
        path: 'README.md',
        name: 'README.md',
        type: FileType.file,
        depth: 0,
      ),
      FileNode(
        path: 'pubspec.yaml',
        name: 'pubspec.yaml',
        type: FileType.file,
        depth: 0,
      ),
    ]);

    // Mark folders as having children
    for (final node in _rootNodes) {
      if (node.type == FileType.folder) {
        _paginationState.setHint(node.path, hasMore: true);
      }
    }
  }

  void _onPaginationChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_autoLoadEnabled) return;
    if (!_scrollController.hasClients) return;
    _checkVisiblePaginationTiles();
  }

  void _checkVisiblePaginationTiles() {
    final viewportHeight = _scrollController.position.viewportDimension;

    // Check each pagination key for visibility
    for (final entry in _paginationKeys.entries) {
      final path = entry.key;
      final key = entry.value;

      // Skip if already loading or can't load
      if (_paginationState.isLoading(path)) continue;
      if (!_paginationState.canLoad(path)) continue;
      if (!_paginationState.isRegistered(path)) continue;

      final keyContext = key.currentContext;
      if (keyContext == null) continue;

      final box = keyContext.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;

      // Get widget position on screen
      final position = box.localToGlobal(Offset.zero);
      final tileTop = position.dy;

      // Check if tile is visible (within viewport + threshold)
      final isVisible = tileTop < viewportHeight + _scrollThreshold &&
          tileTop > -box.size.height;

      if (isVisible) {
        _loadMoreChildren(path);
        break; // Load one at a time
      }
    }
  }

  Future<void> _toggleNode(FileNode node) async {
    if (node.type != FileType.folder) return;

    if (_expandedNodes.contains(node.path)) {
      setState(() {
        _expandedNodes.remove(node.path);
        _paginationKeys.remove(node.path);
      });
    } else {
      setState(() => _expandedNodes.add(node.path));

      if (!_paginationState.isRegistered(node.path)) {
        await _loadChildren(node);
      }
    }
  }

  Future<void> _loadChildren(FileNode parent) async {
    if (!_paginationState.canLoad(parent.path)) return;
    if (!_paginationState.startLoading(parent.path)) return;

    try {
      await Future<void>.delayed(_loadDelay);
      if (!mounted) return;

      final path = parent.path;

      // Initialize phase tracking if needed
      _inFolderPhase[path] ??= true;
      final inFolderPhase = _inFolderPhase[path]!;

      if (inFolderPhase) {
        // Loading folders phase
        final pageNumber = (_folderPagesLoaded[path] ?? 0) + 1;
        final folders = _generateFolders(parent, pageNumber);

        final currentFolders = _loadedFolders[path] ?? [];
        final allFolders = [...currentFolders, ...folders]
          ..sort((a, b) => a.name.compareTo(b.name));

        setState(() {
          _loadedFolders[path] = allFolders;
          _folderPagesLoaded[path] = pageNumber;
        });

        // Mark new folders as having children
        for (final folder in folders) {
          _paginationState.setHint(folder.path, hasMore: true);
        }

        final hasMoreFolders = pageNumber < _maxFolderPages;

        if (hasMoreFolders) {
          // More folders to load
          _paginationState.complete(
            path,
            nextToken: PageToken.cursor('folders:$pageNumber'),
          );
        } else {
          // Switch to files phase
          _inFolderPhase[path] = false;
          _paginationState.complete(
            path,
            nextToken: PageToken.cursor('files:0'),
          );
        }
      } else {
        // Loading files phase
        final pageNumber = (_filePagesLoaded[path] ?? 0) + 1;
        final files = _generateFiles(parent, pageNumber);

        final currentFiles = _loadedFiles[path] ?? [];
        final allFiles = [...currentFiles, ...files]
          ..sort((a, b) => a.name.compareTo(b.name));

        setState(() {
          _loadedFiles[path] = allFiles;
          _filePagesLoaded[path] = pageNumber;
        });

        final hasMoreFiles = pageNumber < _maxFilePages;

        _paginationState.complete(
          path,
          nextToken: hasMoreFiles
              ? PageToken.cursor('files:$pageNumber')
              : PageToken.end,
        );
      }
    } catch (e) {
      _paginationState.fail(parent.path, e);
    }
  }

  Future<void> _loadMoreChildren(String parentPath) async {
    final parent = _findNode(parentPath);
    if (parent == null) return;
    await _loadChildren(parent);
  }

  FileNode? _findNode(String path) {
    for (final node in _rootNodes) {
      if (node.path == path) return node;
    }
    for (final folders in _loadedFolders.values) {
      for (final node in folders) {
        if (node.path == path) return node;
      }
    }
    for (final files in _loadedFiles.values) {
      for (final node in files) {
        if (node.path == path) return node;
      }
    }
    return null;
  }

  List<FileNode> _generateFolders(FileNode parent, int pageNumber) {
    final depth = parent.depth + 1;
    final basePath = parent.path;
    final seed = basePath.hashCode + pageNumber * 100;
    final rand = Random(seed);

    final folders = <FileNode>[];
    final count = pageNumber == 1 ? 3 : 2; // More folders on first page

    for (var i = 0; i < count; i++) {
      final name = _getFolderName(rand, pageNumber, i);
      folders.add(FileNode(
        path: '$basePath/$name',
        name: name,
        type: FileType.folder,
        depth: depth,
      ));
    }

    return folders;
  }

  List<FileNode> _generateFiles(FileNode parent, int pageNumber) {
    final depth = parent.depth + 1;
    final basePath = parent.path;
    final seed =
        basePath.hashCode + pageNumber * 200; // Different seed for files
    final rand = Random(seed);

    final files = <FileNode>[];

    for (var i = 0; i < _itemsPerPage; i++) {
      final name = _getFileName(rand, basePath, pageNumber, i);
      files.add(FileNode(
        path: '$basePath/$name',
        name: name,
        type: FileType.file,
        depth: depth,
      ));
    }

    return files;
  }

  String _getFolderName(Random rand, int page, int index) {
    const names = [
      ['src', 'core', 'features', 'widgets', 'models'],
      ['services', 'repositories', 'providers', 'controllers', 'utils'],
      ['components', 'screens', 'pages', 'views', 'layouts'],
      ['helpers', 'extensions', 'mixins', 'painters', 'themes'],
    ];
    final pageNames = names[(page - 1) % names.length];
    return pageNames[(index + rand.nextInt(3)) % pageNames.length];
  }

  String _getFileName(Random rand, String path, int page, int index) {
    final baseName = path.split('/').last;
    const prefixes = ['base', 'app', 'custom', 'default', 'main', 'abstract'];
    const suffixes = [
      '_widget.dart',
      '_controller.dart',
      '_service.dart',
      '_model.dart',
      '_state.dart',
      '_provider.dart',
    ];
    final prefix = prefixes[(page + index) % prefixes.length];
    final suffix = suffixes[(page + index + rand.nextInt(2)) % suffixes.length];
    return '${prefix}_$baseName$suffix';
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
      _rootNodes.clear();
      _loadedFolders.clear();
      _loadedFiles.clear();
      _inFolderPhase.clear();
      _folderPagesLoaded.clear();
      _filePagesLoaded.clear();
      _expandedNodes.clear();
      _paginationKeys.clear();
      _paginationState.resetAll();
    });
    _initializeRoot();
    _scrollController.jumpTo(0);
    setState(() {});
  }

  void _collapseAll() {
    setState(() {
      _expandedNodes.clear();
      _paginationKeys.clear();
    });
  }

  int get _totalNodes {
    var count = _rootNodes.length;
    for (final folders in _loadedFolders.values) {
      count += folders.length;
    }
    for (final files in _loadedFiles.values) {
      count += files.length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File Explorer', style: TextStyle(fontSize: 16)),
            Text(
              '$_totalNodes items loaded',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.unfold_less),
            onPressed: _collapseAll,
            tooltip: 'Collapse All',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildInfoBar(),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: _buildNodeList(_rootNodes),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder_open,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text(
            'my_flutter_project',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          const Text('Auto-load', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          SizedBox(
            height: 24,
            child: Switch(
              value: _autoLoadEnabled,
              onChanged: (v) => setState(() => _autoLoadEnabled = v),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNodeList(List<FileNode> nodes, {Set<String>? visited}) {
    visited ??= <String>{};
    final widgets = <Widget>[];

    for (final node in nodes) {
      if (visited.contains(node.path)) continue;
      visited.add(node.path);

      widgets.add(_buildNodeTile(node));

      if (_expandedNodes.contains(node.path)) {
        final path = node.path;
        final folders = _loadedFolders[path] ?? [];
        final files = _loadedFiles[path] ?? [];
        final inFolderPhase = _inFolderPhase[path] ?? true;

        // Render folders
        if (folders.isNotEmpty) {
          widgets.addAll(_buildNodeList(folders, visited: visited));
        }

        // Show folder pagination (if still in folder phase or has folders)
        if (inFolderPhase && _paginationState.isRegistered(path)) {
          widgets.add(_buildSectionPaginationTile(
            node,
            isFolder: true,
            itemCount: folders.length,
          ));
        }

        // Render files
        if (files.isNotEmpty) {
          widgets.addAll(_buildNodeList(files, visited: visited));
        }

        // Show file pagination (if in file phase or exhausted)
        if (!inFolderPhase || _paginationState.isExhausted(path)) {
          widgets.add(_buildSectionPaginationTile(
            node,
            isFolder: false,
            itemCount: files.length,
          ));
        }
      }
    }

    return widgets;
  }

  Widget _buildSectionPaginationTile(
    FileNode parent, {
    required bool isFolder,
    required int itemCount,
  }) {
    final path = parent.path;
    final isLoading = _paginationState.isLoading(path);
    final canLoadMore =
        _paginationState.canLoad(path) && _paginationState.isRegistered(path);
    final isExhausted = _paginationState.isExhausted(path);
    final inFolderPhase = _inFolderPhase[path] ?? true;

    final indent = (parent.depth + 1) * 24.0;
    final colorScheme = Theme.of(context).colorScheme;

    // Determine if this section is active
    final isActiveSection = isFolder ? inFolderPhase : !inFolderPhase;
    final sectionName = isFolder ? 'folders' : 'files';
    final sectionIcon =
        isFolder ? Icons.folder_outlined : Icons.description_outlined;

    // Loading state for this section
    if (isLoading && isActiveSection) {
      return _buildSectionRow(
        indent: indent,
        icon: sectionIcon,
        iconColor: colorScheme.primary,
        child: Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading $sectionName...',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // Can load more in this section
    if (canLoadMore && isActiveSection) {
      // Register key for visibility detection
      final key = _paginationKeys.putIfAbsent(path, GlobalKey.new);

      return InkWell(
        key: key,
        onTap: () => _loadMoreChildren(path),
        child: _buildSectionRow(
          indent: indent,
          icon: sectionIcon,
          iconColor: colorScheme.primary,
          child: Row(
            children: [
              Text(
                '$itemCount $sectionName',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Load more',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Section complete
    if (isFolder && !inFolderPhase && itemCount > 0) {
      // Folders section done, show completion
      return _buildSectionRow(
        indent: indent,
        icon: Icons.check_circle_outline,
        iconColor: colorScheme.outline,
        child: Text(
          '$itemCount folders',
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.outline,
          ),
        ),
      );
    }

    if (!isFolder && isExhausted && itemCount > 0) {
      // Files section done
      return _buildSectionRow(
        indent: indent,
        icon: Icons.check_circle_outline,
        iconColor: colorScheme.outline,
        child: Text(
          '$itemCount files',
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.outline,
          ),
        ),
      );
    }

    // Files section not started yet (still loading folders)
    if (!isFolder && inFolderPhase) {
      return _buildSectionRow(
        indent: indent,
        icon: sectionIcon,
        iconColor: colorScheme.outlineVariant,
        child: Text(
          'Files will load after folders',
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.outlineVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSectionRow({
    required double indent,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: 16 + indent + 24, right: 16),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildNodeTile(FileNode node) {
    final isExpanded = _expandedNodes.contains(node.path);
    final isLoading = _paginationState.isLoading(node.path) &&
        !_paginationState.isRegistered(node.path);
    final isFolder = node.type == FileType.folder;
    final indent = node.depth * 24.0;

    return InkWell(
      onTap: isFolder ? () => _toggleNode(node) : null,
      child: Padding(
        padding: EdgeInsets.only(left: 16 + indent, right: 16),
        child: SizedBox(
          height: 36,
          child: Row(
            children: [
              // Expand/collapse icon for folders
              if (isFolder)
                SizedBox(
                  width: 24,
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                )
              else
                const SizedBox(width: 24),
              // File/folder icon
              Icon(
                _getIcon(node),
                size: 18,
                color: _getIconColor(node),
              ),
              const SizedBox(width: 8),
              // Name
              Expanded(
                child: Text(
                  node.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(FileNode node) {
    if (node.type == FileType.folder) {
      return _expandedNodes.contains(node.path)
          ? Icons.folder_open
          : Icons.folder;
    }

    final name = node.name.toLowerCase();
    if (name.endsWith('.dart')) return Icons.code;
    if (name.endsWith('.yaml') || name.endsWith('.yml')) return Icons.settings;
    if (name.endsWith('.md')) return Icons.description;
    if (name.endsWith('.json')) return Icons.data_object;
    if (name.startsWith('.')) return Icons.settings;
    return Icons.insert_drive_file;
  }

  Color _getIconColor(FileNode node) {
    final colorScheme = Theme.of(context).colorScheme;

    if (node.type == FileType.folder) {
      return Colors.amber.shade700;
    }

    final name = node.name.toLowerCase();
    if (name.endsWith('.dart')) return Colors.blue;
    if (name.endsWith('.yaml') || name.endsWith('.yml')) return Colors.pink;
    if (name.endsWith('.md')) return colorScheme.onSurfaceVariant;
    if (name.endsWith('.json')) return Colors.orange;
    return colorScheme.onSurfaceVariant;
  }
}

/// Type of file system node.
enum FileType { file, folder }

/// A node in the file tree.
class FileNode {
  const FileNode({
    required this.path,
    required this.name,
    required this.type,
    required this.depth,
  });

  final String path;
  final String name;
  final FileType type;
  final int depth;
}
