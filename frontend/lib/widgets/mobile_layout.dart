import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/project.dart';
import '../models/app_bar_config.dart';
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
  AppBarConfig? _appBarConfig;

  void _onAppBarConfigChanged(AppBarConfig? config) {
    setState(() {
      _appBarConfig = config;
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(viewProvider);

    return Scaffold(
      key: scaffoldKey,
      appBar: _buildMobileAppBar(context, viewState),
      drawer: Drawer(child: SafeArea(child: widget.leftBarContent)),
      body: SafeArea(
        child: MainContent(
          projects: widget.projects,
          onAppBarConfigChanged: _onAppBarConfigChanged,
        ),
      ),
    );
  }

  AppBar _buildMobileAppBar(BuildContext context, ViewState viewState) {
    // Use app bar config from child if available, otherwise use default
    if (_appBarConfig != null) {
      return AppBar(
        title: _appBarConfig!.title,
        actions: _appBarConfig!.actions,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIcons.list()),
          onPressed: () {
            scaffoldKey.currentState?.openDrawer();
          },
        ),
        centerTitle: _appBarConfig!.centerTitle,
        elevation: _appBarConfig!.elevation,
        backgroundColor: _appBarConfig!.backgroundColor,
        bottom: _appBarConfig!.bottom,
      );
    }

    // Default app bar when no config is provided
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
        icon: PhosphorIcon(PhosphorIcons.list()),
        onPressed: () {
          scaffoldKey.currentState?.openDrawer();
        },
      ),
    );
  }
}
