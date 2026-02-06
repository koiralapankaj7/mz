import 'package:flutter/material.dart';

import 'collection_demo.dart';
import 'file_explorer_demo.dart';
import 'fuzzy_search_demo.dart';
import 'genealogy_demo.dart';
import 'graph_view_demo.dart';
import 'pagination_demo.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MZ Collection Examples',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ExampleLauncher(),
    );
  }
}

class ExampleLauncher extends StatelessWidget {
  const ExampleLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MZ Collection Examples'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ExampleCard(
            title: 'Collection Demo',
            description:
                'Full-featured demo showcasing filtering, sorting, grouping, '
                'selection, and multiple store types.',
            icon: Icons.view_list,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const CollectionDemo(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ExampleCard(
            title: 'Fuzzy Search Demo',
            description: 'Typo-tolerant search using Levenshtein distance. '
                'Try different strategies, distances, and see algorithms live.',
            icon: Icons.manage_search,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const FuzzySearchDemo(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ExampleCard(
            title: 'Grid Pagination Demo',
            description:
                'Demonstrates bi-directional pagination with TableView. '
                'Supports all 4 edges: top, bottom, left, right.',
            icon: Icons.grid_view,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const PaginationDemo(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ExampleCard(
            title: 'File Explorer Demo',
            description:
                'Tree view with lazy loading like GitHub/IDE file explorer. '
                'Expands folders on tap, auto-loads more on scroll.',
            icon: Icons.folder_open,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const FileExplorerDemo(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ExampleCard(
            title: 'Graph View Demo',
            description: 'Visual knowledge graph using Node + LinkManager. '
                'Drag nodes, create links, find paths between concepts.',
            icon: Icons.hub,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const GraphViewDemo(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ExampleCard(
            title: 'Genealogy Demo',
            description: 'Family tree graph with real WikiTree data. '
                'Shows parents, children, spouses with hierarchical layout.',
            icon: Icons.family_restroom,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => const GenealogyDemo(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
