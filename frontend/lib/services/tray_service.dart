import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayService {
  static Future<void> initialize() async {
    await trayManager.setIcon('assets/tray_icon.png');
    Menu menu = Menu(
      items: [MenuItem(key: 'exit_app', label: 'Exit App')],
    );
    await trayManager.setContextMenu(menu);
    trayManager.addListener(AppTrayListener());
  }
}

class AppTrayListener extends TrayListener {
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'exit_app') {
      SystemNavigator.pop();
    }
  }
}
