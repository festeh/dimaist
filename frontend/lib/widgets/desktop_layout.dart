import 'package:flutter/material.dart';
import '../models/project.dart';
import 'main_content.dart';

class DesktopLayout extends StatelessWidget {
  final List<Project> projects;
  final Widget leftBarContent;

  const DesktopLayout({
    super.key,
    required this.projects,
    required this.leftBarContent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            leftBarContent,
            Expanded(
              child: MainContent(projects: projects),
            ),
          ],
        ),
      ),
    );
  }
}
