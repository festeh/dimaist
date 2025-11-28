import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/design_tokens.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import '../utils/color_utils.dart';

class ArrangeProjectsDialog extends ConsumerStatefulWidget {
  final List<Project> projects;

  const ArrangeProjectsDialog({
    super.key,
    required this.projects,
  });

  @override
  ConsumerState<ArrangeProjectsDialog> createState() => _ArrangeProjectsDialogState();
}

class _ArrangeProjectsDialogState extends ConsumerState<ArrangeProjectsDialog> {
  late List<Project> _projects;

  @override
  void initState() {
    super.initState();
    _projects = List.from(widget.projects);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final project = _projects.removeAt(oldIndex);
      _projects.insert(newIndex, project);
    });

    // Apply immediately
    ref.read(projectProvider.notifier).reorderProjects(oldIndex, newIndex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 500,
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Arrange Projects',
                    style: theme.textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              Flexible(
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  itemCount: _projects.length,
                  onReorder: _onReorder,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    return ListTile(
                      key: Key(project.id.toString()),
                      leading: Container(
                        width: Sizes.avatarSm * 2,
                        height: Sizes.avatarSm * 2,
                        decoration: BoxDecoration(
                          color: getColor(project.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(project.name),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
