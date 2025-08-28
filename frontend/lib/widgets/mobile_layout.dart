import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../providers/view_provider.dart';
import '../config/app_constants.dart';
import 'main_content.dart';

class MobileLayout extends ConsumerStatefulWidget {
  final List<Project> projects;
  final Widget leftBarContent;

  const MobileLayout({
    super.key,
    required this.projects,
    required this.leftBarContent,
  });

  @override
  ConsumerState<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends ConsumerState<MobileLayout> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(viewProvider);

    return Scaffold(
      key: scaffoldKey,
      resizeToAvoidBottomInset: false,
      appBar: _buildMobileAppBar(context, viewState, scaffoldKey),
      drawer: Drawer(child: SafeArea(child: widget.leftBarContent)),
      body: MainContent(projects: widget.projects),
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
