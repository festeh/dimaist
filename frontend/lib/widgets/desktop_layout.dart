import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/app_bar_config.dart';
import 'main_content.dart';

class DesktopLayout extends StatefulWidget {
  final List<Project> projects;
  final Widget leftBarContent;

  const DesktopLayout({
    super.key,
    required this.projects,
    required this.leftBarContent,
  });

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  AppBarConfig? _appBarConfig;

  void _onAppBarConfigChanged(AppBarConfig? config) {
    setState(() {
      _appBarConfig = config;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildDesktopAppBar(context),
      body: SafeArea(
        child: Row(
          children: [
            widget.leftBarContent,
            Expanded(
              child: MainContent(
                projects: widget.projects,
                onAppBarConfigChanged: _onAppBarConfigChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildDesktopAppBar(BuildContext context) {
    // Use app bar config from child if available, otherwise use minimal default
    if (_appBarConfig != null) {
      return AppBar(
        title: _appBarConfig!.title,
        actions: _appBarConfig!.actions,
        leading: _appBarConfig!.leading,
        automaticallyImplyLeading: _appBarConfig!.automaticallyImplyLeading,
        centerTitle: _appBarConfig!.centerTitle,
        elevation:
            _appBarConfig!.elevation ??
            1, // Slightly different default for desktop
        backgroundColor: _appBarConfig!.backgroundColor,
        bottom: _appBarConfig!.bottom,
      );
    }

    // Minimal default app bar for desktop when no config is provided
    return AppBar(
      title: const Text('Tasks'),
      elevation: 1,
      automaticallyImplyLeading: false, // No back button on desktop
    );
  }
}
