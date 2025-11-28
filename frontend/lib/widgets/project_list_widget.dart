import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/design_tokens.dart';
import '../models/project.dart';
import '../utils/color_utils.dart';

class ProjectList extends StatelessWidget {
  final List<Project> projects;
  final int selectedIndex;
  final Function(int) onProjectSelected;
  final Function(Project) onEdit;
  final Function(int) onDelete;

  const ProjectList({
    super.key,
    required this.projects,
    required this.selectedIndex,
    required this.onProjectSelected,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView.builder(
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        final isSelected = selectedIndex == index;

        return Container(
          key: Key(project.id.toString()),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: InkWell(
            onTap: () => onProjectSelected(index),
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.md,
              ),
              child: Row(
                children: [
                  // Color dot
                  Container(
                    width: Sizes.avatarSm * 2,
                    height: Sizes.avatarSm * 2,
                    decoration: BoxDecoration(
                      color: getColor(project.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Spacing.md),

                  // Project name
                  Expanded(
                    child: Text(
                      project.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),

                  // Menu (only on selected)
                  if (isSelected)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: PhosphorIcon(
                        PhosphorIcons.dotsThreeVertical(),
                        size: Sizes.iconSm,
                        color: colors.onSurfaceVariant,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit(project);
                        } else if (value == 'delete') {
                          onDelete(project.id!);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
