import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../providers/view_provider.dart';
import '../config/app_constants.dart';
import 'main_content.dart';

class MobileLayout extends ConsumerWidget {
  final List<Project> projects;
  final Widget leftBarContent;

  const MobileLayout({
    super.key,
    required this.projects,
    required this.leftBarContent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(viewProvider);
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      appBar: _buildMobileAppBar(context, viewState, scaffoldKey),
      drawer: Drawer(
        child: SafeArea(child: leftBarContent),
      ),
      body: SafeArea(
        child: MainContent(projects: projects),
      ),
    );
  }

  AppBar _buildMobileAppBar(
    BuildContext context,
    ViewState viewState,
    GlobalKey<ScaffoldState> scaffoldKey,
  ) {
    String title = AppConstants.appName;
    final customView = viewState.currentCustomView;
    final project = viewState.currentProject;

    if (customView != null) {
      title = customView.name;
    } else if (project != null) {
      title = project.name;
    }

    return AppBar(
      title: Text(title),
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () {
          scaffoldKey.currentState?.openDrawer();
        },
      ),
    );
  }
}