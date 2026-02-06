# UI Package Features Roadmap

This document lists features to be implemented in the Flutter UI package that consumes `mz_collection`.

> **Note:** `mz_collection` provides the data layer (pure Dart). The UI package will handle rendering, interactions, and visual components.

---

## Data Visualization

### Pivot Tables
Multi-dimensional data aggregation with row/column grouping.

```
              | Product A | Product B | Total |
|-------------|-----------|-----------|-------|
| Region North|    1000   |    500    | 1500  |
| Region South|    800    |    600    | 1400  |
| Total       |   1800    |   1100    | 2900  |
```

**Requirements:**
- [ ] Row grouping (use GroupManager)
- [ ] Column grouping (transpose dimension)
- [ ] Aggregation functions (SUM, COUNT, AVG, MIN, MAX)
- [ ] Grand totals (row/column)
- [ ] Sub-totals per group
- [ ] Drill-down on cells

---

### Tree View
Hierarchical data display with expand/collapse.

**Requirements:**
- [ ] Expand/collapse animations
- [ ] Lazy loading children on expand (use `controller.loadChildren()`)
- [ ] Expand indicator (arrow/chevron) based on `mayHaveChildren()`
- [ ] Loading spinner per node (use `controller.pagination.isLoading(nodeId)`)
- [ ] Indent guides/lines
- [ ] Multi-select with checkbox
- [ ] Drag to reorder within tree
- [ ] Keyboard navigation (arrow keys, Enter to expand)

---

### DAG Visualization (Multi-Parent)
For genealogy, org charts with matrix reporting, etc.

**Requirements:**
- [ ] Visual connectors for links (use LinkManager data)
- [ ] Different line styles per link type (solid, dashed, colored)
- [ ] Highlight linked nodes on hover/selection
- [ ] Path highlighting between nodes
- [ ] Layout algorithms (hierarchical, force-directed)
- [ ] Mini-map for large graphs

---

## Table Features

### Column Management
- [ ] Column reordering (drag header)
- [ ] Column resizing (drag edge)
- [ ] Column visibility toggle (show/hide)
- [ ] Column pinning (freeze left/right)
- [ ] Column grouping (nested headers)

### Cell Features
- [ ] Inline cell editing
- [ ] Cell selection (single, range, multi)
- [ ] Cell copy/paste
- [ ] Cell formatting (conditional styles)
- [ ] Cell tooltips
- [ ] Cell validation on edit

### Row Features
- [ ] Row selection (single, multi, range)
- [ ] Row reordering (drag & drop)
- [ ] Row expansion (master-detail)
- [ ] Row grouping header (sticky)
- [ ] Alternating row colors

---

## Interactions

### Drag & Drop
- [ ] Drag rows to reorder
- [ ] Drag to move between groups
- [ ] Drag to tree (reparent nodes)
- [ ] Drag to external targets
- [ ] Drop indicators/placeholders
- [ ] Auto-scroll while dragging

### Keyboard Navigation
- [ ] Arrow keys (cell/row navigation)
- [ ] Tab/Shift+Tab (cell navigation)
- [ ] Enter (edit/confirm)
- [ ] Escape (cancel edit)
- [ ] Space (toggle selection)
- [ ] Ctrl+A (select all)
- [ ] Ctrl+C/V (copy/paste)
- [ ] Home/End (jump to first/last)
- [ ] Page Up/Down (scroll page)

### Clipboard
- [ ] Copy selected cells/rows
- [ ] Paste into cells
- [ ] Copy as CSV/TSV
- [ ] Copy as formatted text

---

## Virtualization

### Performance
- [ ] Virtual scrolling (only render visible rows)
- [ ] Windowed rendering for columns
- [ ] Estimated row heights (use HeightEstimator)
- [ ] Smooth scrolling with momentum
- [ ] Scroll position persistence

### Slot Management
- [ ] Use SlotManager for slot allocation
- [ ] Dynamic slot sizing
- [ ] Group header slots
- [ ] Sticky headers during scroll

---

## Search & Filter UI

### Search Bar
- [ ] Global search input
- [ ] Search highlighting in cells
- [ ] Search result count
- [ ] Navigate between matches (prev/next)
- [ ] Search history/suggestions

### Filter UI
- [ ] Filter dropdowns per column
- [ ] Quick filters (chips)
- [ ] Advanced filter builder
- [ ] Filter presets (save/load)
- [ ] Clear all filters button

### Sort UI
- [ ] Click header to sort
- [ ] Sort indicator (arrow)
- [ ] Multi-column sort (Shift+click)
- [ ] Sort menu (ascending/descending/clear)

---

## Selection UI

### Visual Feedback
- [ ] Selection highlight color
- [ ] Selection checkbox column
- [ ] "Select All" header checkbox
- [ ] Selection count badge
- [ ] Bulk action toolbar (appears on selection)

### Selection Modes
- [ ] Single select
- [ ] Multi-select (Ctrl+click)
- [ ] Range select (Shift+click)
- [ ] Checkbox select
- [ ] Select all in group

---

## Responsive Design

### Layout
- [ ] Mobile-friendly table (card view)
- [ ] Responsive column hiding
- [ ] Horizontal scroll on small screens
- [ ] Touch-friendly interactions
- [ ] Swipe actions on rows

### Accessibility
- [ ] Screen reader support
- [ ] ARIA labels
- [ ] Focus management
- [ ] High contrast mode
- [ ] Keyboard-only navigation

---

## Theming

### Customization
- [ ] Light/dark theme support
- [ ] Custom color schemes
- [ ] Custom cell renderers
- [ ] Custom header renderers
- [ ] Custom row renderers
- [ ] Icon customization

---

## Export

### Formats
- [ ] Export to CSV
- [ ] Export to Excel (.xlsx)
- [ ] Export to PDF
- [ ] Export to JSON
- [ ] Print view

---

## Integration with mz_collection

| UI Feature | mz_collection API |
|------------|-------------------|
| Lazy load children | `controller.loadChildren(nodeId)` |
| Show expand arrow | `controller.mayHaveChildren(nodeId)` |
| Loading spinner | `controller.pagination.isLoading(nodeId)` |
| Get linked nodes | `controller.getLinkedNodes(nodeId)` |
| Check if linked | `controller.areLinked(nodeA, nodeB)` |
| Find path | `controller.findLinkPath(start, end)` |
| Pagination | `controller.loadMore()` |
| Filter | `controller.filter` |
| Sort | `controller.sort` |
| Group | `controller.group` |
| Selection | `controller.selection` |
| Node collapse | `node.collapse()` / `node.isCollapsed` |

---

## Priority Order

### Phase 1 - Core
1. Tree View with lazy loading
2. Basic table with virtualization
3. Selection (single/multi)
4. Sort/Filter UI

### Phase 2 - Enhanced
1. DAG visualization (for genealogy)
2. Drag & drop
3. Keyboard navigation
4. Cell editing

### Phase 3 - Advanced
1. Pivot tables
2. Export features
3. Column management
4. Clipboard support

### Phase 4 - Polish
1. Theming
2. Accessibility
3. Responsive design
4. Performance optimization

---

*Last updated: January 2025*
