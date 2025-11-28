import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/design_tokens.dart';
import '../models/search_result.dart';
import '../providers/search_provider.dart';
import '../providers/view_provider.dart';
import '../providers/project_provider.dart';
import '../services/api_service.dart';
import '../services/logging_service.dart';

class SearchResultsScreen extends ConsumerWidget {
  const SearchResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchProvider);
    final theme = Theme.of(context);

    if (searchState.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(
              PhosphorIcons.warning(),
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              'Search failed',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              searchState.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (searchState.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(
              PhosphorIcons.magnifyingGlass(),
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              searchState.query.isEmpty
                  ? 'Start typing to search...'
                  : 'No results found',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (searchState.query.isNotEmpty) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                'for "${searchState.query}"',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Text(
            '${searchState.results.length} result${searchState.results.length == 1 ? '' : 's'} for "${searchState.query}"',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: searchState.results.length,
            itemBuilder: (context, index) {
              final result = searchState.results[index];
              return _SearchResultTile(result: result);
            },
          ),
        ),
      ],
    );
  }
}

class _SearchResultTile extends ConsumerWidget {
  final SearchResult result;

  const _SearchResultTile({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListTile(
      leading: PhosphorIcon(
        result.isTask ? PhosphorIcons.square() : PhosphorIcons.folder(),
        color: theme.colorScheme.primary,
      ),
      title: Text(result.title),
      subtitle: result.subtitle != null && result.subtitle!.isNotEmpty
          ? Text(result.subtitle!)
          : null,
      trailing: PhosphorIcon(
        PhosphorIcons.caretRight(),
        size: Sizes.iconXs,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: () => _navigateToResult(context, ref),
    );
  }

  Future<void> _navigateToResult(BuildContext context, WidgetRef ref) async {
    final logger = LoggingService.logger;
    final searchNotifier = ref.read(searchProvider.notifier);
    final viewNotifier = ref.read(viewProvider.notifier);
    final projectsAsync = ref.read(projectProvider);
    final projects = projectsAsync.valueOrNull ?? [];

    try {
      if (result.isProject) {
        final project = projects.where((p) => p.id == result.id).firstOrNull;

        if (project != null) {
          viewNotifier.selectProject(project);
          searchNotifier.clearSearch();
        } else {
          logger.warning('Project not found: ${result.id}');
        }
      } else if (result.isTask) {
        final apiService = ApiService();
        final task = await apiService.getTask(result.id);

        final project = projects.where((p) => p.id == task.projectId).firstOrNull;

        if (project != null) {
          viewNotifier.selectProject(project);
          searchNotifier.clearSearch();
        } else {
          // Project not found in local list, just clear search
          searchNotifier.clearSearch();
        }
      }
    } catch (e) {
      logger.severe('Error navigating to result: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening result: $e')),
        );
      }
    }
  }
}
