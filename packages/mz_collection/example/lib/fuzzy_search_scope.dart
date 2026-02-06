import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:mz_collection/mz_collection.dart';

// =============================================================================
// Data Models
// =============================================================================

/// Information about a single fuzzy search match.
class FuzzySearchMatch {
  FuzzySearchMatch({
    required this.id,
    required this.matchedText,
    required this.fullText,
    required this.query,
    required this.distance,
    required this.isExact,
    required this.paragraphRef,
    required this.startOffset,
    required this.endOffset,
    this.queryIndex = 0,
    this.scrollY = 0.0,
  });

  /// Unique identifier for this match (based on text content).
  final String id;

  /// The text that was matched (highlighted portion).
  final String matchedText;

  /// The full text of the paragraph containing the match.
  final String fullText;

  /// The search query that produced this match.
  final String query;

  /// Edit distance (0 = exact match).
  final int distance;

  /// Whether this is an exact match.
  final bool isExact;

  /// Weak reference to the RenderParagraph (may become null if disposed).
  final WeakReference<RenderParagraph> paragraphRef;

  /// Start offset in the text.
  final int startOffset;

  /// End offset in the text.
  final int endOffset;

  /// Index of the query term (for multi-term search).
  final int queryIndex;

  /// Y position relative to scroll content (for sorting).
  double scrollY;

  /// Current screen rect (updated during paint if visible).
  Rect? currentRect;

  /// Whether this match is currently visible in the viewport.
  bool isVisible = false;

  @override
  String toString() => 'FuzzySearchMatch("$matchedText", distance: $distance)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FuzzySearchMatch && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Statistics about search matches.
class FuzzySearchStatistics {
  const FuzzySearchStatistics({
    this.totalMatches = 0,
    this.exactMatches = 0,
    this.fuzzyMatches = 0,
    this.visibleMatches = 0,
    this.matchesByQuery = const {},
  });

  final int totalMatches;
  final int exactMatches;
  final int fuzzyMatches;
  final int visibleMatches;
  final Map<String, int> matchesByQuery;
}

/// A single search term with its own color.
class SearchTerm {
  const SearchTerm({
    required this.query,
    this.color,
    this.isRegex = false,
  });

  final String query;
  final Color? color;
  final bool isRegex;
}

// =============================================================================
// Controller
// =============================================================================

/// Controller for managing fuzzy search state and navigation.
class FuzzySearchController extends ChangeNotifier {
  FuzzySearchController({
    String query = '',
    int maxDistance = 2,
    bool caseSensitive = false,
    int maxHistoryLength = 10,
  })  : _query = query,
        _maxDistance = maxDistance,
        _caseSensitive = caseSensitive,
        _maxHistoryLength = maxHistoryLength;

  // Search configuration
  String _query;
  String get query => _query;
  set query(String value) {
    if (_query == value) return;
    _query = value;
    _clearMatches();
    _addToHistory(value);
    notifyListeners();
  }

  int _maxDistance;
  int get maxDistance => _maxDistance;
  set maxDistance(int value) {
    if (_maxDistance == value) return;
    _maxDistance = value;
    _clearMatches();
    notifyListeners();
  }

  bool _caseSensitive;
  bool get caseSensitive => _caseSensitive;
  set caseSensitive(bool value) {
    if (_caseSensitive == value) return;
    _caseSensitive = value;
    _clearMatches();
    notifyListeners();
  }

  bool _useRegex = false;
  bool get useRegex => _useRegex;
  set useRegex(bool value) {
    if (_useRegex == value) return;
    _useRegex = value;
    _clearMatches();
    notifyListeners();
  }

  // Multi-term search
  final List<SearchTerm> _searchTerms = [];
  List<SearchTerm> get searchTerms => List.unmodifiable(_searchTerms);

  void addSearchTerm(SearchTerm term) {
    _searchTerms.add(term);
    _clearMatches();
    notifyListeners();
  }

  void removeSearchTerm(int index) {
    if (index >= 0 && index < _searchTerms.length) {
      _searchTerms.removeAt(index);
      _clearMatches();
      notifyListeners();
    }
  }

  void clearSearchTerms() {
    _searchTerms.clear();
    _clearMatches();
    notifyListeners();
  }

  // Match tracking - ALL discovered matches (persistent)
  final Map<String, FuzzySearchMatch> _matchesById = {};
  final List<FuzzySearchMatch> _orderedMatches = [];

  List<FuzzySearchMatch> get matches => List.unmodifiable(_orderedMatches);
  int get matchCount => _orderedMatches.length;

  int _currentMatchIndex = -1;
  int get currentMatchIndex => _currentMatchIndex;
  FuzzySearchMatch? get currentMatch =>
      _currentMatchIndex >= 0 && _currentMatchIndex < _orderedMatches.length
          ? _orderedMatches[_currentMatchIndex]
          : null;

  // Statistics
  FuzzySearchStatistics get statistics {
    final exactCount = _orderedMatches.where((m) => m.isExact).length;
    final visibleCount = _orderedMatches.where((m) => m.isVisible).length;
    final matchesByQuery = <String, int>{};
    for (final match in _orderedMatches) {
      matchesByQuery[match.query] = (matchesByQuery[match.query] ?? 0) + 1;
    }
    return FuzzySearchStatistics(
      totalMatches: _orderedMatches.length,
      exactMatches: exactCount,
      fuzzyMatches: _orderedMatches.length - exactCount,
      visibleMatches: visibleCount,
      matchesByQuery: matchesByQuery,
    );
  }

  // Search history
  final int _maxHistoryLength;
  final List<String> _history = [];
  List<String> get history => List.unmodifiable(_history);

  void _addToHistory(String query) {
    if (query.isEmpty) return;
    _history.remove(query);
    _history.insert(0, query);
    if (_history.length > _maxHistoryLength) {
      _history.removeLast();
    }
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  // Scroll callback for navigation
  void Function(FuzzySearchMatch match)? onScrollToMatch;

  // Render object reference for scrolling
  _RenderFuzzyHighlight? _renderObject;

  // Navigation
  void nextMatch() {
    if (_orderedMatches.isEmpty) return;

    // Stop any ongoing scroll-to-find
    _stopScrollToFind();

    final nextIndex = _currentMatchIndex + 1;

    if (nextIndex >= _orderedMatches.length) {
      // At the end of known matches - start scrolling to find more
      if (!_startScrollToFind(forward: true)) {
        // Can't scroll further - wrap to beginning
        _currentMatchIndex = 0;
        _scrollToCurrentMatch();
        notifyListeners();
      }
    } else {
      _currentMatchIndex = nextIndex;
      _scrollToCurrentMatch();
      notifyListeners();
    }
  }

  void previousMatch() {
    if (_orderedMatches.isEmpty) return;

    // Stop any ongoing scroll-to-find
    _stopScrollToFind();

    if (_currentMatchIndex <= 0) {
      // At the beginning of known matches - start scrolling to find more
      if (!_startScrollToFind(forward: false)) {
        // Can't scroll further - wrap to end
        _currentMatchIndex = _orderedMatches.length - 1;
        _scrollToCurrentMatch();
        notifyListeners();
      }
    } else {
      _currentMatchIndex = _currentMatchIndex - 1;
      _scrollToCurrentMatch();
      notifyListeners();
    }
  }

  /// Start continuous scroll to find the next/previous match.
  /// Returns true if scrolling started, false if already at boundary.
  bool _startScrollToFind({required bool forward}) {
    final renderObject = _renderObject;
    if (renderObject == null) return false;

    final scrollController = renderObject._scrollController;
    if (scrollController == null || !scrollController.hasClients) return false;

    final currentOffset = scrollController.offset;
    final maxExtent = scrollController.position.maxScrollExtent;

    // Check if we can scroll in the desired direction
    if (forward && currentOffset >= maxExtent - 1) return false;
    if (!forward && currentOffset <= 1) return false;

    // Remember current match position to compare against new discoveries
    _scrollingFromY =
        _currentMatchIndex >= 0 && _currentMatchIndex < _orderedMatches.length
            ? _orderedMatches[_currentMatchIndex].scrollY
            : (forward ? 0.0 : double.infinity);

    _scrollingToFind = true;
    _scrollingForward = forward;

    // Start scrolling toward the boundary at moderate speed
    final targetOffset = forward ? maxExtent : 0.0;
    final distance = (targetOffset - currentOffset).abs();
    // Speed: ~400 pixels per second
    final durationMs = (distance / 400 * 1000).clamp(100, 3000).toInt();

    scrollController.animateTo(
      targetOffset,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.linear,
    );

    return true;
  }

  /// Stop the scroll-to-find animation.
  void _stopScrollToFind() {
    if (!_scrollingToFind) return;
    _scrollingToFind = false;

    final scrollController = _renderObject?._scrollController;
    if (scrollController != null && scrollController.hasClients) {
      // Stop animation by jumping to current position
      scrollController.jumpTo(scrollController.offset);
    }
  }

  /// Called when a new match is discovered during scroll-to-find.
  /// Returns true if this match should be selected (stops the scroll).
  bool _checkScrollToFindMatch(FuzzySearchMatch match, int matchIndex) {
    if (!_scrollingToFind) return false;

    final isAfterCurrent = _scrollingForward
        ? match.scrollY > _scrollingFromY
        : match.scrollY < _scrollingFromY;

    if (isAfterCurrent && match.isVisible) {
      _stopScrollToFind();
      _currentMatchIndex = matchIndex;
      _needsNotification = true;
      return true;
    }

    return false;
  }

  void goToMatch(int index) {
    if (index < 0 || index >= _orderedMatches.length) return;
    _currentMatchIndex = index;
    _scrollToCurrentMatch();
    notifyListeners();
  }

  void _scrollToCurrentMatch() {
    final match = currentMatch;
    if (match == null) return;

    // Try to scroll using the render object
    if (_renderObject != null) {
      _renderObject!.scrollToMatch(match);
    }

    // Also call the callback if set
    onScrollToMatch?.call(match);
  }

  // Track if we need to notify after paint
  bool _needsNotification = false;
  bool _notificationScheduled = false;

  // Track if we need to select first visible match
  bool _needsInitialSelection = true;

  // Track if we're scrolling to find the next/previous match
  bool _scrollingToFind = false;
  bool _scrollingForward = true;
  double _scrollingFromY = 0.0;

  /// Called by render object to register a discovered match.
  /// Returns the match index. Inserts in sorted order by scrollY.
  int registerMatch(FuzzySearchMatch match) {
    if (_matchesById.containsKey(match.id)) {
      // Update existing match's visibility and position
      final existing = _matchesById[match.id]!;
      final existingIndex = _orderedMatches.indexOf(existing);
      existing.isVisible = match.isVisible;
      existing.currentRect = match.currentRect;
      // Only update scrollY if the new value is valid and different
      // Keep the original scrollY for stable ordering
      if (existing.scrollY == 0.0 && match.scrollY > 0.0) {
        existing.scrollY = match.scrollY;
      }
      // Check if this existing match should stop scroll-to-find
      if (existing.isVisible) {
        _checkScrollToFindMatch(existing, existingIndex);
      }
      return existingIndex;
    }

    // Add new match - insert in sorted order by scrollY
    _matchesById[match.id] = match;

    // Find insertion point to maintain sorted order
    var insertIndex = _orderedMatches.length;
    for (var i = 0; i < _orderedMatches.length; i++) {
      if (_orderedMatches[i].scrollY > match.scrollY) {
        insertIndex = i;
        break;
      }
    }

    _orderedMatches.insert(insertIndex, match);

    // Adjust current index if insertion was before it
    if (_currentMatchIndex >= 0 && insertIndex <= _currentMatchIndex) {
      _currentMatchIndex++;
    }

    // Check if this new match should stop scroll-to-find
    _checkScrollToFindMatch(match, insertIndex);

    // Mark that we need to notify listeners (will be done post-frame)
    _needsNotification = true;

    return insertIndex;
  }

  /// Update visibility of matches based on current viewport.
  void updateMatchVisibility(Set<String> visibleIds) {
    for (final match in _orderedMatches) {
      match.isVisible = visibleIds.contains(match.id);
      if (!match.isVisible) {
        match.currentRect = null;
      }
    }
  }

  /// Find the first visible match and select it.
  void selectFirstVisibleMatch() {
    for (var i = 0; i < _orderedMatches.length; i++) {
      if (_orderedMatches[i].isVisible) {
        _currentMatchIndex = i;
        _needsInitialSelection = false;
        return;
      }
    }
  }

  /// Called after paint to do initial match selection.
  void doInitialSelectionIfNeeded() {
    if (_needsInitialSelection && _orderedMatches.isNotEmpty) {
      selectFirstVisibleMatch();
      _needsNotification = true;
    }
  }

  /// Called by render object after paint to trigger deferred notification.
  void scheduleNotificationIfNeeded() {
    if (_needsNotification && !_notificationScheduled) {
      _notificationScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notificationScheduled = false;
        if (_needsNotification) {
          _needsNotification = false;
          notifyListeners();
        }
      });
    }
  }

  void _clearMatches() {
    _stopScrollToFind();
    _matchesById.clear();
    _orderedMatches.clear();
    _currentMatchIndex = -1;
    _needsInitialSelection = true;
  }

  void clear() {
    _query = '';
    _clearMatches();
    _searchTerms.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _clearMatches();
    _searchTerms.clear();
    _history.clear();
    super.dispose();
  }
}

// =============================================================================
// Search Bar Widget
// =============================================================================

/// Pre-built search bar with all controls.
class FuzzySearchBar extends StatefulWidget {
  const FuzzySearchBar({
    super.key,
    required this.controller,
    this.autofocus = false,
    this.hintText = 'Search...',
    this.showStatistics = true,
    this.showHistory = true,
    this.showRegexToggle = true,
    this.showCaseSensitiveToggle = true,
    this.showNavigationButtons = true,
    this.compact = false,
    this.decoration,
    this.onSubmitted,
  });

  final FuzzySearchController controller;
  final bool autofocus;
  final String hintText;
  final bool showStatistics;
  final bool showHistory;
  final bool showRegexToggle;
  final bool showCaseSensitiveToggle;
  final bool showNavigationButtons;
  final bool compact;
  final InputDecoration? decoration;
  final void Function(String)? onSubmitted;

  @override
  State<FuzzySearchBar> createState() => _FuzzySearchBarState();
}

class _FuzzySearchBarState extends State<FuzzySearchBar> {
  late TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.controller.query);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(FuzzySearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _textController.text = widget.controller.query;
    }
  }

  void _onControllerChanged() {
    if (_textController.text != widget.controller.query) {
      _textController.text = widget.controller.query;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (HardwareKeyboard.instance.isShiftPressed) {
          widget.controller.previousMatch();
        } else {
          widget.controller.nextMatch();
        }
        widget.onSubmitted?.call(_textController.text);
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.controller.clear();
        _textController.clear();
        _focusNode.unfocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stats = widget.controller.statistics;
    final hasMatches = stats.totalMatches > 0;
    final currentIndex = widget.controller.currentMatchIndex;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main search row
          Row(
            children: [
              // Search field
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  decoration: widget.decoration ??
                      InputDecoration(
                        hintText: widget.hintText,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _textController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _textController.clear();
                                  widget.controller.clear();
                                },
                                tooltip: 'Clear (Esc)',
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: widget.compact,
                        contentPadding: widget.compact
                            ? const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              )
                            : null,
                      ),
                  onChanged: (value) {
                    widget.controller.query = value;
                  },
                  onSubmitted: (value) {
                    widget.controller.nextMatch();
                    widget.onSubmitted?.call(value);
                  },
                ),
              ),

              if (widget.showNavigationButtons && !widget.compact) ...[
                const SizedBox(width: 8),
                // Match counter
                if (hasMatches)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${currentIndex + 1} / ${stats.totalMatches}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                // Navigation buttons
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up),
                  onPressed:
                      hasMatches ? widget.controller.previousMatch : null,
                  tooltip: 'Previous (Shift+Enter)',
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: hasMatches ? widget.controller.nextMatch : null,
                  tooltip: 'Next (Enter)',
                ),
              ],
            ],
          ),

          // Compact navigation row
          if (widget.showNavigationButtons && widget.compact && hasMatches)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                    onPressed: widget.controller.previousMatch,
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    '${currentIndex + 1} / ${stats.totalMatches}',
                    style: theme.textTheme.bodySmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                    onPressed: widget.controller.nextMatch,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Main Widget
// =============================================================================

/// A widget that provides fuzzy search highlighting for all Text widgets
/// in its subtree.
class FuzzySearchScope extends StatefulWidget {
  const FuzzySearchScope({
    super.key,
    this.controller,
    this.query = '',
    this.maxDistance = 2,
    this.caseSensitive = false,
    this.highlightColor,
    this.currentMatchColor,
    this.scrollController,
    this.onMatchCountChanged,
    this.onHighlightTap,
    required this.child,
  });

  /// Controller for advanced features (navigation, history, etc.)
  final FuzzySearchController? controller;

  /// Simple query string (used if controller is null).
  final String query;

  /// Maximum edit distance for fuzzy matching.
  final int maxDistance;

  /// Whether matching should be case-sensitive.
  final bool caseSensitive;

  /// Color for highlighting matches.
  final Color? highlightColor;

  /// Color for the current/selected match.
  final Color? currentMatchColor;

  /// Optional scroll controller for auto-scroll to matches.
  final ScrollController? scrollController;

  /// Callback when visible match count changes.
  final void Function(int count)? onMatchCountChanged;

  /// Callback when a highlight is tapped.
  final void Function(FuzzySearchMatch match)? onHighlightTap;

  /// The widget subtree to search within.
  final Widget child;

  @override
  State<FuzzySearchScope> createState() => _FuzzySearchScopeState();
}

class _FuzzySearchScopeState extends State<FuzzySearchScope> {
  late FuzzySearchController _controller;
  bool _ownsController = false;
  bool _isHoveringHighlight = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = FuzzySearchController(
        query: widget.query,
        maxDistance: widget.maxDistance,
        caseSensitive: widget.caseSensitive,
      );
      _ownsController = true;
    }
    // Listen to controller to rebuild when query changes
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(FuzzySearchScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onControllerChanged);
      if (_ownsController) {
        _controller.dispose();
      }
      _initController();
    } else if (_ownsController) {
      // Update internal controller from widget properties
      if (widget.query != _controller.query) {
        _controller.query = widget.query;
      }
      if (widget.maxDistance != _controller.maxDistance) {
        _controller.maxDistance = widget.maxDistance;
      }
      if (widget.caseSensitive != _controller.caseSensitive) {
        _controller.caseSensitive = widget.caseSensitive;
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onHoverChanged(bool isHovering) {
    if (_isHoveringHighlight != isHovering) {
      setState(() => _isHoveringHighlight = isHovering);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget result = _ScrollRepaintTrigger(
      child: _FuzzyHighlightWidget(
        controller: _controller,
        highlightColor:
            widget.highlightColor ?? theme.colorScheme.primaryContainer,
        currentMatchColor:
            widget.currentMatchColor ?? theme.colorScheme.primary,
        enabled: _controller.query.isNotEmpty,
        scrollController: widget.scrollController,
        onMatchCountChanged: widget.onMatchCountChanged,
        onHighlightTap: widget.onHighlightTap,
        onHoverChanged: widget.onHighlightTap != null ? _onHoverChanged : null,
        child: widget.child,
      ),
    );

    // Add cursor change when hovering highlights
    if (widget.onHighlightTap != null) {
      result = MouseRegion(
        cursor:
            _isHoveringHighlight ? SystemMouseCursors.click : MouseCursor.defer,
        child: result,
      );
    }

    return result;
  }
}

/// Triggers repaint when scrolling occurs.
class _ScrollRepaintTrigger extends StatefulWidget {
  const _ScrollRepaintTrigger({required this.child});

  final Widget child;

  @override
  State<_ScrollRepaintTrigger> createState() => _ScrollRepaintTriggerState();
}

class _ScrollRepaintTriggerState extends State<_ScrollRepaintTrigger> {
  _RenderFuzzyHighlight? _cachedRenderObject;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _cachedRenderObject ??= _findFuzzyHighlight();
          _cachedRenderObject?.markNeedsPaint();
        }
        return false;
      },
      child: widget.child,
    );
  }

  _RenderFuzzyHighlight? _findFuzzyHighlight() {
    RenderObject? current = context.findRenderObject();
    while (current != null) {
      if (current is _RenderFuzzyHighlight) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }
}

// =============================================================================
// Render Objects
// =============================================================================

class _FuzzyHighlightWidget extends SingleChildRenderObjectWidget {
  const _FuzzyHighlightWidget({
    required this.controller,
    required this.highlightColor,
    required this.currentMatchColor,
    required this.enabled,
    required super.child,
    this.scrollController,
    this.onMatchCountChanged,
    this.onHighlightTap,
    this.onHoverChanged,
  });

  final FuzzySearchController controller;
  final Color highlightColor;
  final Color currentMatchColor;
  final bool enabled;
  final ScrollController? scrollController;
  final void Function(int)? onMatchCountChanged;
  final void Function(FuzzySearchMatch)? onHighlightTap;
  final void Function(bool)? onHoverChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderFuzzyHighlight(
      controller: controller,
      highlightColor: highlightColor,
      currentMatchColor: currentMatchColor,
      enabled: enabled,
      scrollController: scrollController,
      onMatchCountChanged: onMatchCountChanged,
      onHighlightTap: onHighlightTap,
      onHoverChanged: onHoverChanged,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFuzzyHighlight renderObject,
  ) {
    renderObject
      ..controller = controller
      ..highlightColor = highlightColor
      ..currentMatchColor = currentMatchColor
      ..enabled = enabled
      ..scrollController = scrollController
      ..onMatchCountChanged = onMatchCountChanged
      ..onHighlightTap = onHighlightTap
      ..onHoverChanged = onHoverChanged;
  }
}

/// Cache entry wrapper.
final _matchCache = Expando<_CacheEntry>('fuzzyMatch');

class _CacheEntry {
  const _CacheEntry(this.match, this.version);
  final _ParagraphMatchInfo? match;
  final int version;
}

/// Internal match data.
class _ParagraphMatchInfo {
  const _ParagraphMatchInfo({
    required this.start,
    required this.end,
    required this.distance,
    required this.query,
    this.queryIndex = 0,
  });

  final int start;
  final int end;
  final int distance;
  final String query;
  final int queryIndex;
}

/// Highlight region for hit testing.
class _HighlightRegion {
  const _HighlightRegion({
    required this.rect,
    required this.match,
  });

  final Rect rect;
  final FuzzySearchMatch match;
}

class _RenderFuzzyHighlight extends RenderProxyBox {
  _RenderFuzzyHighlight({
    required FuzzySearchController controller,
    required Color highlightColor,
    required Color currentMatchColor,
    required bool enabled,
    ScrollController? scrollController,
    void Function(int)? onMatchCountChanged,
    void Function(FuzzySearchMatch)? onHighlightTap,
    void Function(bool)? onHoverChanged,
  })  : _controller = controller,
        _highlightColor = highlightColor,
        _currentMatchColor = currentMatchColor,
        _enabled = enabled,
        _scrollController = scrollController,
        _onMatchCountChanged = onMatchCountChanged,
        _onHighlightTap = onHighlightTap,
        _onHoverChanged = onHoverChanged {
    _controller.addListener(_onControllerChanged);
    _controller._renderObject = this;
  }

  FuzzySearchController _controller;
  set controller(FuzzySearchController value) {
    if (_controller == value) return;
    _controller.removeListener(_onControllerChanged);
    _controller._renderObject = null;
    _controller = value;
    _controller.addListener(_onControllerChanged);
    _controller._renderObject = this;
    _cacheVersion++;
    markNeedsPaint();
  }

  void _onControllerChanged() {
    _cacheVersion++;
    markNeedsPaint();
  }

  Color _highlightColor;
  set highlightColor(Color value) {
    if (_highlightColor == value) return;
    _highlightColor = value;
    markNeedsPaint();
  }

  Color _currentMatchColor;
  set currentMatchColor(Color value) {
    if (_currentMatchColor == value) return;
    _currentMatchColor = value;
    markNeedsPaint();
  }

  bool _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    markNeedsPaint();
  }

  ScrollController? _scrollController;
  set scrollController(ScrollController? value) {
    _scrollController = value;
  }

  void Function(int)? _onMatchCountChanged;
  set onMatchCountChanged(void Function(int)? value) {
    _onMatchCountChanged = value;
  }

  void Function(FuzzySearchMatch)? _onHighlightTap;
  set onHighlightTap(void Function(FuzzySearchMatch)? value) {
    _onHighlightTap = value;
  }

  void Function(bool)? _onHoverChanged;
  set onHoverChanged(void Function(bool)? value) {
    _onHoverChanged = value;
  }

  int _cacheVersion = 0;
  int _lastReportedCount = -1;
  final List<_HighlightRegion> _visibleHighlights = [];
  Offset _paintOffset = Offset.zero;
  _HighlightRegion? _hoveredRegion;

  @override
  bool get isRepaintBoundary => true;

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller._renderObject = null;
    super.dispose();
  }

  /// Scroll to make a match visible using minimal scroll (ensureVisible style).
  void scrollToMatch(FuzzySearchMatch match) {
    final scrollController = _scrollController;
    if (scrollController == null || !scrollController.hasClients) return;

    final viewportHeight = size.height;
    final currentOffset = scrollController.offset;
    final maxScroll = scrollController.position.maxScrollExtent;

    // Padding from edges
    const edgePadding = 20.0;

    // Use stored scrollY for navigation
    final targetScrollY = match.scrollY;

    if (targetScrollY > 0) {
      // Calculate current viewport bounds in content coordinates
      final viewportTop = currentOffset;
      final viewportBottom = currentOffset + viewportHeight;

      // Check if match is already fully visible
      if (targetScrollY >= viewportTop + edgePadding &&
          targetScrollY <= viewportBottom - edgePadding) {
        // Already visible, no scroll needed
        return;
      }

      double targetScroll;
      if (targetScrollY < viewportTop + edgePadding) {
        // Match is above viewport - scroll up to show it at top edge
        targetScroll = targetScrollY - edgePadding;
      } else {
        // Match is below viewport - scroll down to show it at bottom edge
        targetScroll = targetScrollY - viewportHeight + edgePadding + 40;
      }

      scrollController.animateTo(
        targetScroll.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
      return;
    }

    // Fallback: try using paragraph reference for matches without scrollY
    final paragraph = match.paragraphRef.target;
    if (paragraph == null || !paragraph.attached) return;

    try {
      final transform = paragraph.getTransformTo(this);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: match.startOffset,
          extentOffset: match.endOffset,
        ),
      );

      if (boxes.isEmpty) return;

      final box = boxes.first;
      final topLeft =
          MatrixUtils.transformPoint(transform, box.toRect().topLeft);

      final matchY = topLeft.dy;

      // Minimal scroll - just bring into view at edge
      if (matchY < edgePadding) {
        // Above viewport - scroll up
        scrollController.animateTo(
          (currentOffset + matchY - edgePadding).clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      } else if (matchY > viewportHeight - edgePadding - 40) {
        // Below viewport - scroll down
        scrollController.animateTo(
          (currentOffset + matchY - viewportHeight + edgePadding + 40)
              .clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      // Ignore errors from detached paragraphs
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);

    _visibleHighlights.clear();
    _paintOffset = offset;

    final visibleMatchIds = <String>{};

    if (_enabled && _controller.query.isNotEmpty) {
      context.canvas.save();
      context.canvas.clipRect(offset & size);
      _paintHighlights(context.canvas, offset, visibleMatchIds);
      context.canvas.restore();
    }

    // Update visibility of all matches
    _controller.updateMatchVisibility(visibleMatchIds);

    // Do initial selection of first visible match
    _controller.doInitialSelectionIfNeeded();

    // Schedule notification if new matches were added
    _controller.scheduleNotificationIfNeeded();

    // Report match count change via callback
    final totalCount = _controller.matchCount;
    if (_onMatchCountChanged != null && totalCount != _lastReportedCount) {
      _lastReportedCount = totalCount;
      final callback = _onMatchCountChanged!;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        callback(totalCount);
      });
    }
  }

  void _paintHighlights(
    Canvas canvas,
    Offset offset,
    Set<String> visibleMatchIds,
  ) {
    final viewportRect = offset & size;

    // Get search terms
    final terms = _controller.searchTerms.isNotEmpty
        ? _controller.searchTerms
        : [SearchTerm(query: _controller.query)];

    _visitVisibleParagraphs(child, viewportRect, (paragraph) {
      for (var termIndex = 0; termIndex < terms.length; termIndex++) {
        final term = terms[termIndex];
        if (term.query.isEmpty) continue;

        final matchInfo = _findMatch(paragraph, term, termIndex);
        if (matchInfo == null) continue;

        final boxes = paragraph.getBoxesForSelection(
          TextSelection(
            baseOffset: matchInfo.start,
            extentOffset: matchInfo.end,
          ),
        );

        if (boxes.isEmpty) continue;

        final transform = paragraph.getTransformTo(this);
        final fullText = paragraph.text.toPlainText();
        final matchedText = fullText.substring(matchInfo.start, matchInfo.end);

        // Calculate scroll position using first box (for unique ID and sorting)
        final firstBox = boxes.first;
        final firstTopLeft = MatrixUtils.transformPoint(
          transform,
          firstBox.toRect().topLeft,
        );
        final scrollOffset = _scrollController?.hasClients == true
            ? _scrollController!.offset
            : 0.0;
        final scrollY = scrollOffset + firstTopLeft.dy;

        // Generate unique ID including scroll position - this makes each
        // visually distinct match unique, even if text content is identical
        final matchId =
            '${matchInfo.query}_${scrollY.round()}_${matchInfo.start}';

        // Track if we've registered this match (only register once per paragraph)
        var matchRegistered = false;
        int? matchIndex;

        for (final box in boxes) {
          final topLeft = MatrixUtils.transformPoint(
            transform,
            box.toRect().topLeft,
          );
          final bottomRight = MatrixUtils.transformPoint(
            transform,
            box.toRect().bottomRight,
          );

          final rect = Rect.fromPoints(topLeft, bottomRight).shift(offset);

          if (!rect.overlaps(viewportRect)) continue;

          visibleMatchIds.add(matchId);

          // Create match object for this box
          final searchMatch = FuzzySearchMatch(
            id: matchId,
            matchedText: matchedText,
            fullText: fullText,
            query: matchInfo.query,
            distance: matchInfo.distance,
            isExact: matchInfo.distance == 0,
            paragraphRef: WeakReference(paragraph),
            startOffset: matchInfo.start,
            endOffset: matchInfo.end,
            queryIndex: termIndex,
            scrollY: scrollY,
          )
            ..currentRect = rect
            ..isVisible = true;

          // Register match only once per paragraph (not per box)
          if (!matchRegistered) {
            matchIndex = _controller.registerMatch(searchMatch);
            matchRegistered = true;
          }

          final isCurrentMatch = matchIndex == _controller.currentMatchIndex;
          final isHovered = _hoveredRegion?.rect == rect;

          // Determine color
          Color fillColor;
          if (isCurrentMatch) {
            fillColor = _currentMatchColor.withAlpha(180);
          } else if (isHovered) {
            fillColor = _highlightColor.withAlpha(200);
          } else {
            fillColor =
                term.color?.withAlpha(100) ?? _highlightColor.withAlpha(100);
          }

          // Paint the highlight
          final paint = Paint()
            ..color = fillColor
            ..style = PaintingStyle.fill;

          final rrect = RRect.fromRectAndRadius(
            rect,
            const Radius.circular(2),
          );
          canvas.drawRRect(rrect, paint);

          // Add border for current match or hovered
          if (isCurrentMatch || isHovered) {
            final borderPaint = Paint()
              ..color = isCurrentMatch
                  ? _currentMatchColor
                  : _highlightColor.withAlpha(255)
              ..style = PaintingStyle.stroke
              ..strokeWidth = isCurrentMatch ? 2 : 1;
            canvas.drawRRect(rrect, borderPaint);
          }

          // Store for hit testing
          _visibleHighlights.add(_HighlightRegion(
            rect: rect,
            match: searchMatch,
          ));
        }
      }
    });
  }

  void _visitVisibleParagraphs(
    RenderObject? node,
    Rect viewportRect,
    void Function(RenderParagraph) visitor,
  ) {
    if (node == null || !node.attached) return;

    if (node is RenderParagraph) {
      // Check if paragraph is potentially visible
      try {
        final transform = node.getTransformTo(this);
        final topLeft = MatrixUtils.transformPoint(transform, Offset.zero);
        final bottomRight = MatrixUtils.transformPoint(
          transform,
          Offset(node.size.width, node.size.height),
        );
        final bounds = Rect.fromPoints(topLeft, bottomRight);

        if (bounds.overlaps(viewportRect.translate(
          -_paintOffset.dx,
          -_paintOffset.dy,
        ))) {
          visitor(node);
        }
      } catch (e) {
        // Ignore errors from detached nodes
      }
      return;
    }

    node.visitChildren(
      (child) => _visitVisibleParagraphs(child, viewportRect, visitor),
    );
  }

  _ParagraphMatchInfo? _findMatch(
    RenderParagraph paragraph,
    SearchTerm term,
    int termIndex,
  ) {
    final cacheEntry = _matchCache[paragraph];
    if (cacheEntry != null && cacheEntry.version == _cacheVersion) {
      return cacheEntry.match;
    }

    final plainText = paragraph.text.toPlainText();
    if (plainText.isEmpty) {
      _matchCache[paragraph] = _CacheEntry(null, _cacheVersion);
      return null;
    }

    _ParagraphMatchInfo? match;

    if (term.isRegex || _controller.useRegex) {
      match = _findRegexMatch(plainText, term.query, termIndex);
    } else {
      match = _findFuzzyMatch(
        plainText,
        term.query,
        termIndex,
        _controller.maxDistance,
        _controller.caseSensitive,
      );
    }

    _matchCache[paragraph] = _CacheEntry(match, _cacheVersion);
    return match;
  }

  _ParagraphMatchInfo? _findRegexMatch(
    String text,
    String pattern,
    int termIndex,
  ) {
    try {
      final regex = RegExp(
        pattern,
        caseSensitive: _controller.caseSensitive,
      );
      final match = regex.firstMatch(text);
      if (match != null) {
        return _ParagraphMatchInfo(
          start: match.start,
          end: match.end,
          distance: 0,
          query: pattern,
          queryIndex: termIndex,
        );
      }
    } catch (e) {
      // Invalid regex - ignore
    }
    return null;
  }

  _ParagraphMatchInfo? _findFuzzyMatch(
    String text,
    String query,
    int termIndex,
    int maxDistance,
    bool caseSensitive,
  ) {
    if (query.isEmpty) return null;

    final textNorm = caseSensitive ? text : text.toLowerCase();
    final queryNorm = caseSensitive ? query : query.toLowerCase();

    // First, try exact substring match
    final exactIndex = textNorm.indexOf(queryNorm);
    if (exactIndex != -1) {
      return _ParagraphMatchInfo(
        start: exactIndex,
        end: exactIndex + query.length,
        distance: 0,
        query: query,
        queryIndex: termIndex,
      );
    }

    // Try fuzzy matching with sliding window
    _ParagraphMatchInfo? bestMatch;
    var bestDistance = maxDistance + 1;

    // Check word boundaries first for better matches
    final words = text.split(RegExp(r'\s+'));
    var wordStart = 0;
    for (final word in words) {
      if (word.isEmpty) {
        wordStart += 1;
        continue;
      }

      final wordNorm = caseSensitive ? word : word.toLowerCase();
      final distance = levenshteinDistance(wordNorm, queryNorm);

      if (distance <= maxDistance && distance < bestDistance) {
        bestDistance = distance;
        final start = text.indexOf(word, wordStart);
        bestMatch = _ParagraphMatchInfo(
          start: start,
          end: start + word.length,
          distance: distance,
          query: query,
          queryIndex: termIndex,
        );

        if (distance == 0) return bestMatch;
      }
      wordStart += word.length + 1;
    }

    // Sliding window for partial matches
    final minLen = (query.length * 0.7).floor().clamp(1, query.length);
    final maxLen = (query.length * 1.3).ceil();

    for (var windowSize = minLen;
        windowSize <= maxLen && windowSize <= text.length;
        windowSize++) {
      for (var i = 0; i <= text.length - windowSize; i++) {
        final substring = textNorm.substring(i, i + windowSize);
        final distance = levenshteinDistance(substring, queryNorm);

        if (distance <= maxDistance && distance < bestDistance) {
          bestDistance = distance;
          bestMatch = _ParagraphMatchInfo(
            start: i,
            end: i + windowSize,
            distance: distance,
            query: query,
            queryIndex: termIndex,
          );

          if (distance == 0) return bestMatch;
        }
      }
    }

    return bestMatch;
  }

  // Hit testing for tap and hover
  @override
  bool hitTestSelf(Offset position) => _onHighlightTap != null;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    super.handleEvent(event, entry);

    if (event is PointerDownEvent && _onHighlightTap != null) {
      final localPos = event.localPosition + _paintOffset;
      for (final region in _visibleHighlights) {
        if (region.rect.contains(localPos)) {
          _onHighlightTap!(region.match);
          return;
        }
      }
    }

    if (event is PointerHoverEvent && _onHoverChanged != null) {
      final localPos = event.localPosition + _paintOffset;
      _HighlightRegion? found;
      for (final region in _visibleHighlights) {
        if (region.rect.contains(localPos)) {
          found = region;
          break;
        }
      }

      if (found != _hoveredRegion) {
        _hoveredRegion = found;
        _onHoverChanged!(found != null);
        markNeedsPaint();
      }
    }

    if (event is PointerExitEvent && _onHoverChanged != null) {
      if (_hoveredRegion != null) {
        _hoveredRegion = null;
        _onHoverChanged!(false);
        markNeedsPaint();
      }
    }
  }
}

// =============================================================================
// Legacy API Support
// =============================================================================

/// Information about a highlight tap (legacy API).
class FuzzyHighlightHit {
  const FuzzyHighlightHit({
    required this.matchedText,
    required this.fullText,
    required this.query,
    required this.distance,
  });

  final String matchedText;
  final String fullText;
  final String query;
  final int distance;
}
