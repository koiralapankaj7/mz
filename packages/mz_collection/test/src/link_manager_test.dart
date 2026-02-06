// Copyright (c) 2025, the MZ Collection project authors.
// Use of this source code is governed by a BSD-style license.

import 'package:mz_collection/src/link_manager.dart';
import 'package:test/test.dart';

void main() {
  group('LinkDirection', () {
    test('should have all enum values', () {
      expect(LinkDirection.values, hasLength(3));
      expect(LinkDirection.values, contains(LinkDirection.outgoing));
      expect(LinkDirection.values, contains(LinkDirection.incoming));
      expect(LinkDirection.values, contains(LinkDirection.bidirectional));
    });
  });

  group('NodeLink', () {
    group('constructor', () {
      test('should create link with required parameters', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        expect(link.id, equals('link1'));
        expect(link.sourceId, equals('node1'));
        expect(link.targetId, equals('node2'));
        expect(link.type, equals('parent'));
        expect(link.direction, equals(LinkDirection.outgoing));
        expect(link.metadata, isNull);
      });

      test('should create link with all parameters', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'spouse',
          direction: LinkDirection.bidirectional,
          metadata: {'since': '2020'},
        );

        expect(link.id, equals('link1'));
        expect(link.sourceId, equals('node1'));
        expect(link.targetId, equals('node2'));
        expect(link.type, equals('spouse'));
        expect(link.direction, equals(LinkDirection.bidirectional));
        expect(link.metadata, equals({'since': '2020'}));
      });
    });

    group('involves', () {
      test('should return true when node is source', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        expect(link.involves('node1'), isTrue);
      });

      test('should return true when node is target', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        expect(link.involves('node2'), isTrue);
      });

      test('should return false when node is neither source nor target', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        expect(link.involves('node3'), isFalse);
      });
    });

    group('otherNode', () {
      test('should return target when given source', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        expect(link.otherNode('node1'), equals('node2'));
      });

      test('should return source when given target', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        expect(link.otherNode('node2'), equals('node1'));
      });

      test('should return null when given unrelated node', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        expect(link.otherNode('node3'), isNull);
      });
    });

    group('canTraverseFrom', () {
      test('should allow traversal from source for outgoing link', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        expect(link.canTraverseFrom('node1'), isTrue);
      });

      test('should not allow traversal from target for outgoing link', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        expect(link.canTraverseFrom('node2'), isFalse);
      });

      test('should allow traversal from both ends for bidirectional', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'spouse',
          direction: LinkDirection.bidirectional,
        );

        expect(link.canTraverseFrom('node1'), isTrue);
        expect(link.canTraverseFrom('node2'), isTrue);
      });

      test('should not allow traversal from unrelated node', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
          direction: LinkDirection.bidirectional,
        );

        expect(link.canTraverseFrom('node3'), isFalse);
      });
    });

    group('copyWith', () {
      test('should create copy with same values when no params', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
          direction: LinkDirection.bidirectional,
          metadata: {'key': 'value'},
        );

        final copy = link.copyWith();

        expect(copy.id, equals(link.id));
        expect(copy.sourceId, equals(link.sourceId));
        expect(copy.targetId, equals(link.targetId));
        expect(copy.type, equals(link.type));
        expect(copy.direction, equals(link.direction));
        expect(copy.metadata, equals(link.metadata));
      });

      test('should override id', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        final copy = link.copyWith(id: 'link2');

        expect(copy.id, equals('link2'));
        expect(copy.sourceId, equals('node1'));
      });

      test('should override sourceId', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        final copy = link.copyWith(sourceId: 'node3');

        expect(copy.sourceId, equals('node3'));
        expect(copy.id, equals('link1'));
      });

      test('should override targetId', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        final copy = link.copyWith(targetId: 'node3');

        expect(copy.targetId, equals('node3'));
      });

      test('should override type', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        final copy = link.copyWith(type: 'spouse');

        expect(copy.type, equals('spouse'));
      });

      test('should override direction', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        final copy = link.copyWith(direction: LinkDirection.bidirectional);

        expect(copy.direction, equals(LinkDirection.bidirectional));
      });

      test('should override metadata', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        final copy = link.copyWith(metadata: {'new': 'data'});

        expect(copy.metadata, equals({'new': 'data'}));
      });
    });

    group('equality', () {
      test('should equal link with same id', () {
        const link1 = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );
        const link2 = NodeLink(
          id: 'link1',
          sourceId: 'node3',
          targetId: 'node4',
          type: 'spouse',
        );

        expect(link1, equals(link2));
        expect(link1.hashCode, equals(link2.hashCode));
      });

      test('should not equal link with different id', () {
        const link1 = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );
        const link2 = NodeLink(
          id: 'link2',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        expect(link1, isNot(equals(link2)));
      });

      test('should equal itself', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        expect(link, equals(link));
      });

      test('should not equal non-NodeLink object', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );

        expect(link, isNot(equals('link1')));
        expect(link, isNot(equals(42)));
      });
    });

    group('toString', () {
      test('should format outgoing link correctly', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'alice',
          targetId: 'bob',
          type: 'reports_to',
        );

        expect(
          link.toString(),
          equals('NodeLink(alice → bob, type: reports_to)'),
        );
      });

      test('should format bidirectional link correctly', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'alice',
          targetId: 'bob',
          type: 'spouse',
          direction: LinkDirection.bidirectional,
        );

        expect(
          link.toString(),
          equals('NodeLink(alice ↔ bob, type: spouse)'),
        );
      });
    });
  });

  group('LinkManager', () {
    late LinkManager manager;

    setUp(() {
      manager = LinkManager();
    });

    tearDown(() {
      manager.dispose();
    });

    group('constructor', () {
      test('should create empty manager', () {
        expect(manager.isEmpty, isTrue);
        expect(manager.length, equals(0));
        expect(manager.links, isEmpty);
      });
    });

    group('properties', () {
      test('should return correct length', () {
        expect(manager.length, equals(0));

        manager.add(
          const NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'parent',
          ),
        );

        expect(manager.length, equals(1));
      });

      test('should return isEmpty correctly', () {
        expect(manager.isEmpty, isTrue);
        expect(manager.isNotEmpty, isFalse);

        manager.add(
          const NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'parent',
          ),
        );

        expect(manager.isEmpty, isFalse);
        expect(manager.isNotEmpty, isTrue);
      });

      test('should return all link types', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'spouse',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node3',
              targetId: 'node4',
              type: 'parent',
            ),
          );

        expect(manager.types, hasLength(2));
        expect(manager.types, containsAll(['parent', 'spouse']));
      });

      test('should return all source nodes', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'parent',
            ),
          );

        expect(manager.sourceNodes, containsAll(['node1', 'node2']));
      });

      test('should return all target nodes', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'parent',
            ),
          );

        expect(manager.targetNodes, containsAll(['node2', 'node3']));
      });

      test('should return all linked nodes', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node3',
              targetId: 'node4',
              type: 'parent',
            ),
          );

        expect(
          manager.linkedNodes,
          containsAll(['node1', 'node2', 'node3', 'node4']),
        );
      });
    });

    group('operator []', () {
      test('should return link by id', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );
        manager.add(link);

        expect(manager['link1'], equals(link));
      });

      test('should return null for non-existent id', () {
        expect(manager['nonexistent'], isNull);
      });
    });

    group('add', () {
      test('should add link and notify listeners', () {
        var notified = false;
        manager.addChangeListener(() => notified = true);

        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );
        manager.add(link);

        expect(manager.length, equals(1));
        expect(manager['link1'], equals(link));
        expect(notified, isTrue);
      });

      test('should replace existing link with same id', () {
        const link1 = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );
        const link2 = NodeLink(
          id: 'link1',
          sourceId: 'node3',
          targetId: 'node4',
          type: 'spouse',
        );

        manager
          ..add(link1)
          ..add(link2);

        expect(manager.length, equals(1));
        expect(manager['link1']?.sourceId, equals('node3'));
      });

      test('should index bidirectional link in both directions', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'spouse',
          direction: LinkDirection.bidirectional,
        );

        manager.add(link);

        expect(manager.getOutgoingLinks('node1'), hasLength(1));
        expect(manager.getOutgoingLinks('node2'), hasLength(1));
        expect(manager.getIncomingLinks('node1'), hasLength(1));
        expect(manager.getIncomingLinks('node2'), hasLength(1));
      });
    });

    group('addAll', () {
      test('should add multiple links and notify once', () {
        var notificationCount = 0;
        manager.addChangeListener(() => notificationCount++);

        const links = [
          NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'parent',
          ),
          NodeLink(
            id: 'link2',
            sourceId: 'node2',
            targetId: 'node3',
            type: 'parent',
          ),
        ];

        manager.addAll(links);

        expect(manager.length, equals(2));
        expect(notificationCount, equals(1));
      });

      test('should handle empty iterable', () {
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.addAll([]);

        expect(manager.isEmpty, isTrue);
        expect(notified, isTrue);
      });

      test('should replace existing link when adding with same ID', () {
        const originalLink = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );
        manager.add(originalLink);

        // Add via addAll with the same ID but different type
        const replacementLink = NodeLink(
          id: 'link1',
          sourceId: 'node3',
          targetId: 'node4',
          type: 'child',
        );
        manager.addAll([replacementLink]);

        expect(manager.length, equals(1));
        expect(manager['link1']?.sourceId, equals('node3'));
        expect(manager['link1']?.targetId, equals('node4'));
        expect(manager['link1']?.type, equals('child'));
      });

      test('should index bidirectional links in both directions', () {
        const link = NodeLink(
          id: 'bilink',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'sibling',
          direction: LinkDirection.bidirectional,
        );
        manager.addAll([link]);

        // Should be in outgoing for both nodes
        expect(
          manager.getOutgoingLinks('node1').map((l) => l.id),
          contains('bilink'),
        );
        expect(
          manager.getOutgoingLinks('node2').map((l) => l.id),
          contains('bilink'),
        );
        // Should be in incoming for both nodes
        expect(
          manager.getIncomingLinks('node1').map((l) => l.id),
          contains('bilink'),
        );
        expect(
          manager.getIncomingLinks('node2').map((l) => l.id),
          contains('bilink'),
        );
      });
    });

    group('remove', () {
      test('should remove link and notify listeners', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );
        manager.add(link);

        var notified = false;
        manager.addChangeListener(() => notified = true);

        final removed = manager.remove('link1');

        expect(removed, equals(link));
        expect(manager.isEmpty, isTrue);
        expect(notified, isTrue);
      });

      test('should return null when removing non-existent link', () {
        final removed = manager.remove('nonexistent');

        expect(removed, isNull);
      });

      test('should clean up indices when removing link', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );
        manager.add(link);

        manager.remove('link1');

        expect(manager.getOutgoingLinks('node1'), isEmpty);
        expect(manager.getIncomingLinks('node2'), isEmpty);
      });

      test('should clean up bidirectional link indices', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'spouse',
          direction: LinkDirection.bidirectional,
        );
        manager.add(link);

        manager.remove('link1');

        expect(manager.getOutgoingLinks('node1'), isEmpty);
        expect(manager.getOutgoingLinks('node2'), isEmpty);
        expect(manager.getIncomingLinks('node1'), isEmpty);
        expect(manager.getIncomingLinks('node2'), isEmpty);
      });
    });

    group('removeAllForNode', () {
      test('should remove all links involving node', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node3',
              targetId: 'node4',
              type: 'parent',
            ),
          );

        manager.removeAllForNode('node2');

        expect(manager.length, equals(1));
        expect(manager['link1'], isNull);
        expect(manager['link2'], isNull);
        expect(manager['link3'], isNotNull);
      });

      test('should notify listeners when links removed', () {
        manager.add(
          const NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'parent',
          ),
        );

        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.removeAllForNode('node1');

        expect(notified, isTrue);
      });

      test('should not notify when no links to remove', () {
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.removeAllForNode('nonexistent');

        expect(notified, isFalse);
      });
    });

    group('removeAllOfType', () {
      test('should remove all links of specific type', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'spouse',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node3',
              targetId: 'node4',
              type: 'parent',
            ),
          );

        manager.removeAllOfType('parent');

        expect(manager.length, equals(1));
        expect(manager['link2'], isNotNull);
      });

      test('should notify listeners when links removed', () {
        manager.add(
          const NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'parent',
          ),
        );

        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.removeAllOfType('parent');

        expect(notified, isTrue);
      });

      test('should not notify when no links of type', () {
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.removeAllOfType('nonexistent');

        expect(notified, isFalse);
      });
    });

    group('clear', () {
      test('should remove all links and notify listeners', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'parent',
            ),
          );

        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.clear();

        expect(manager.isEmpty, isTrue);
        expect(manager.types, isEmpty);
        expect(notified, isTrue);
      });

      test('should not notify when already empty', () {
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.clear();

        expect(notified, isFalse);
      });
    });

    group('getOutgoingLinks', () {
      test('should return outgoing links for node', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node1',
              targetId: 'node3',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node2',
              targetId: 'node4',
              type: 'parent',
            ),
          );

        final outgoing = manager.getOutgoingLinks('node1');

        expect(outgoing, hasLength(2));
        expect(outgoing.map((l) => l.id), containsAll(['link1', 'link2']));
      });

      test('should filter by type', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node1',
              targetId: 'node3',
              type: 'spouse',
            ),
          );

        final parents = manager.getOutgoingLinks('node1', type: 'parent');

        expect(parents, hasLength(1));
        expect(parents.first.id, equals('link1'));
      });

      test('should return empty list for node with no outgoing links', () {
        final outgoing = manager.getOutgoingLinks('nonexistent');

        expect(outgoing, isEmpty);
      });
    });

    group('getIncomingLinks', () {
      test('should return incoming links for node', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node3',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'parent',
            ),
          );

        final incoming = manager.getIncomingLinks('node3');

        expect(incoming, hasLength(2));
        expect(incoming.map((l) => l.id), containsAll(['link1', 'link2']));
      });

      test('should filter by type', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'spouse',
            ),
          );

        final parents = manager.getIncomingLinks('node2', type: 'parent');

        expect(parents, hasLength(1));
        expect(parents.first.id, equals('link1'));
      });

      test('should return empty list for node with no incoming links', () {
        final incoming = manager.getIncomingLinks('nonexistent');

        expect(incoming, isEmpty);
      });
    });

    group('getAllLinks', () {
      test('should return all links involving node', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node4',
              targetId: 'node2',
              type: 'parent',
            ),
          );

        final all = manager.getAllLinks('node2');

        expect(all, hasLength(3));
      });

      test('should deduplicate bidirectional links', () {
        manager.add(
          const NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'spouse',
            direction: LinkDirection.bidirectional,
          ),
        );

        final all = manager.getAllLinks('node1');

        expect(all, hasLength(1));
      });

      test('should filter by type', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'spouse',
            ),
          );

        final parents = manager.getAllLinks('node2', type: 'parent');

        expect(parents, hasLength(1));
        expect(parents.first.type, equals('parent'));
      });
    });

    group('getLinkedNodeIds', () {
      test('should return ids of linked nodes', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node1',
              targetId: 'node3',
              type: 'parent',
            ),
          );

        final linkedIds = manager.getLinkedNodeIds('node1');

        expect(linkedIds, containsAll(['node2', 'node3']));
      });

      test('should respect link direction', () {
        manager.add(
          const NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'parent',
          ),
        );

        final fromSource = manager.getLinkedNodeIds('node1');
        final fromTarget = manager.getLinkedNodeIds('node2');

        expect(fromSource, equals(['node2']));
        expect(fromTarget, isEmpty);
      });

      test('should work bidirectionally for bidirectional links', () {
        manager.add(
          const NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'spouse',
            direction: LinkDirection.bidirectional,
          ),
        );

        final from1 = manager.getLinkedNodeIds('node1');
        final from2 = manager.getLinkedNodeIds('node2');

        expect(from1, equals(['node2']));
        expect(from2, equals(['node1']));
      });

      test('should filter by type', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node1',
              targetId: 'node3',
              type: 'spouse',
            ),
          );

        final parents = manager.getLinkedNodeIds('node1', type: 'parent');

        expect(parents, equals(['node2']));
      });
    });

    group('getLinksByType', () {
      test('should return all links of specific type', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'spouse',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node3',
              targetId: 'node4',
              type: 'parent',
            ),
          );

        final parents = manager.getLinksByType('parent');

        expect(parents, hasLength(2));
        expect(parents.map((l) => l.type), everyElement(equals('parent')));
      });

      test('should return empty list for non-existent type', () {
        final links = manager.getLinksByType('nonexistent');

        expect(links, isEmpty);
      });
    });

    group('areLinked', () {
      test('should return true when nodes are directly linked', () {
        manager.add(
          const NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'parent',
          ),
        );

        expect(manager.areLinked('node1', 'node2'), isTrue);
      });

      test('should return false when nodes are not linked', () {
        expect(manager.areLinked('node1', 'node2'), isFalse);
      });

      test('should filter by type', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'spouse',
            ),
          );

        expect(manager.areLinked('node1', 'node2', type: 'parent'), isTrue);
        expect(manager.areLinked('node1', 'node2', type: 'sibling'), isFalse);
      });
    });

    group('getLinkBetween', () {
      test('should return link between two nodes', () {
        const link = NodeLink(
          id: 'link1',
          sourceId: 'node1',
          targetId: 'node2',
          type: 'parent',
        );
        manager.add(link);

        final found = manager.getLinkBetween('node1', 'node2');

        expect(found, equals(link));
      });

      test('should return null when no link exists', () {
        final found = manager.getLinkBetween('node1', 'node2');

        expect(found, isNull);
      });

      test('should filter by type', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'spouse',
            ),
          );

        final parent = manager.getLinkBetween('node1', 'node2', type: 'parent');
        final spouse = manager.getLinkBetween('node1', 'node2', type: 'spouse');

        expect(parent?.id, equals('link1'));
        expect(spouse?.id, equals('link2'));
      });
    });

    group('linkCount', () {
      test('should return total count of links for node', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node1',
              targetId: 'node3',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node4',
              targetId: 'node1',
              type: 'parent',
            ),
          );

        expect(manager.linkCount('node1'), equals(3));
      });

      test('should filter by type', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node1',
              targetId: 'node3',
              type: 'spouse',
            ),
          );

        expect(manager.linkCount('node1', type: 'parent'), equals(1));
      });
    });

    group('getReachableNodes', () {
      test('should find all transitively reachable nodes', () {
        // node1 -> node2 -> node3 -> node4
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node3',
              targetId: 'node4',
              type: 'parent',
            ),
          );

        final reachable = manager.getReachableNodes('node1');

        expect(reachable, containsAll(['node2', 'node3', 'node4']));
        expect(reachable, isNot(contains('node1')));
      });

      test('should include start node when includeStart is true', () {
        manager.add(
          const NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'parent',
          ),
        );

        final reachable = manager.getReachableNodes(
          'node1',
          includeStart: true,
        );

        expect(reachable, contains('node1'));
      });

      test('should respect maxDepth', () {
        // node1 -> node2 -> node3 -> node4
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node3',
              targetId: 'node4',
              type: 'parent',
            ),
          );

        final reachable = manager.getReachableNodes('node1', maxDepth: 1);

        expect(reachable, equals({'node2'}));
      });

      test('should filter by type', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'spouse',
            ),
          );

        final parents = manager.getReachableNodes('node1', type: 'parent');

        expect(parents, equals({'node2'}));
      });

      test('should handle cycles without infinite loop', () {
        // Create a cycle: node1 -> node2 -> node3 -> node1
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node3',
              targetId: 'node1',
              type: 'link',
            ),
          );

        final reachable = manager.getReachableNodes('node1');

        expect(reachable, containsAll(['node2', 'node3']));
      });
    });

    group('findPath', () {
      test('should find shortest path between nodes', () {
        // node1 -> node2 -> node3
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'parent',
            ),
          );

        final path = manager.findPath('node1', 'node3');

        expect(path, equals(['node1', 'node2', 'node3']));
      });

      test('should return path with just start when start equals end', () {
        final path = manager.findPath('node1', 'node1');

        expect(path, equals(['node1']));
      });

      test('should return null when no path exists', () {
        manager.add(
          const NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'parent',
          ),
        );

        final path = manager.findPath('node1', 'node3');

        expect(path, isNull);
      });

      test('should filter by type', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node1',
              targetId: 'node3',
              type: 'spouse',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'parent',
            ),
          );

        final parentPath = manager.findPath('node1', 'node3', type: 'parent');

        expect(parentPath, equals(['node1', 'node2', 'node3']));
      });

      test('should handle cycles without infinite loop', () {
        // Create a cycle with an exit
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node1',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'link',
            ),
          );

        final path = manager.findPath('node1', 'node3');

        expect(path, equals(['node1', 'node2', 'node3']));
      });
    });

    group('findAllPaths', () {
      test('should find all paths between nodes', () {
        // Create multiple paths: node1 -> node2 -> node4
        //                        node1 -> node3 -> node4
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node1',
              targetId: 'node3',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node2',
              targetId: 'node4',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link4',
              sourceId: 'node3',
              targetId: 'node4',
              type: 'link',
            ),
          );

        final paths = manager.findAllPaths('node1', 'node4');

        expect(paths, hasLength(2));
        expect(
          paths,
          containsAll([
            ['node1', 'node2', 'node4'],
            ['node1', 'node3', 'node4'],
          ]),
        );
      });

      test('should respect maxPaths limit', () {
        // Create 3 paths but limit to 2
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node1',
              targetId: 'node3',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node1',
              targetId: 'node4',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link4',
              sourceId: 'node2',
              targetId: 'node5',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link5',
              sourceId: 'node3',
              targetId: 'node5',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link6',
              sourceId: 'node4',
              targetId: 'node5',
              type: 'link',
            ),
          );

        final paths = manager.findAllPaths('node1', 'node5', maxPaths: 2);

        expect(paths.length, lessThanOrEqualTo(2));
      });

      test('should respect maxDepth limit', () {
        // Create deep path but limit depth
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node3',
              targetId: 'node4',
              type: 'link',
            ),
          );

        final paths = manager.findAllPaths('node1', 'node4', maxDepth: 2);

        expect(paths, isEmpty);
      });

      test('should filter by type', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node1',
              targetId: 'node3',
              type: 'spouse',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node2',
              targetId: 'node4',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link4',
              sourceId: 'node3',
              targetId: 'node4',
              type: 'parent',
            ),
          );

        final paths = manager.findAllPaths('node1', 'node4', type: 'parent');

        expect(paths, hasLength(1));
        expect(paths.first, equals(['node1', 'node2', 'node4']));
      });

      test('should handle cycles without infinite loop', () {
        // Create a cycle
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link3',
              sourceId: 'node3',
              targetId: 'node1',
              type: 'link',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link4',
              sourceId: 'node3',
              targetId: 'node4',
              type: 'link',
            ),
          );

        final paths = manager.findAllPaths('node1', 'node4');

        expect(paths.isNotEmpty, isTrue);
      });
    });

    group('dispose', () {
      test('should clear all data on dispose', () {
        manager.add(
          const NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'parent',
          ),
        );

        manager.dispose();

        expect(manager.isEmpty, isTrue);
      });

      test('should not notify listeners after dispose', () {
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.dispose();

        // Try to trigger notification after dispose
        // Listeners should have been cleared
        notified = false;
        manager.clear();

        expect(notified, isFalse);
      });
    });

    group('toString', () {
      test('should return descriptive string', () {
        manager
          ..add(
            const NodeLink(
              id: 'link1',
              sourceId: 'node1',
              targetId: 'node2',
              type: 'parent',
            ),
          )
          ..add(
            const NodeLink(
              id: 'link2',
              sourceId: 'node2',
              targetId: 'node3',
              type: 'spouse',
            ),
          );

        expect(manager.toString(), equals('LinkManager(links: 2, types: 2)'));
      });
    });

    group('listener notifications', () {
      test('should notify on add', () {
        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.add(
          const NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'parent',
          ),
        );

        expect(notified, isTrue);
      });

      test('should notify once on addAll', () {
        var count = 0;
        manager.addChangeListener(() => count++);

        manager.addAll([
          const NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'parent',
          ),
          const NodeLink(
            id: 'link2',
            sourceId: 'node2',
            targetId: 'node3',
            type: 'parent',
          ),
        ]);

        expect(count, equals(1));
      });

      test('should notify on remove', () {
        manager.add(
          const NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'parent',
          ),
        );

        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.remove('link1');

        expect(notified, isTrue);
      });

      test('should notify on clear', () {
        manager.add(
          const NodeLink(
            id: 'link1',
            sourceId: 'node1',
            targetId: 'node2',
            type: 'parent',
          ),
        );

        var notified = false;
        manager.addChangeListener(() => notified = true);

        manager.clear();

        expect(notified, isTrue);
      });
    });
  });
}
