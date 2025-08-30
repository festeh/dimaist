import 'package:flutter/material.dart';

class AppBarConfig {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double? elevation;
  final Color? backgroundColor;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;

  const AppBarConfig({
    this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.elevation,
    this.backgroundColor,
    this.automaticallyImplyLeading = true,
    this.bottom,
  });

  AppBarConfig copyWith({
    Widget? title,
    List<Widget>? actions,
    Widget? leading,
    bool? centerTitle,
    double? elevation,
    Color? backgroundColor,
    bool? automaticallyImplyLeading,
    PreferredSizeWidget? bottom,
  }) {
    return AppBarConfig(
      title: title ?? this.title,
      actions: actions ?? this.actions,
      leading: leading ?? this.leading,
      centerTitle: centerTitle ?? this.centerTitle,
      elevation: elevation ?? this.elevation,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      automaticallyImplyLeading:
          automaticallyImplyLeading ?? this.automaticallyImplyLeading,
      bottom: bottom ?? this.bottom,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppBarConfig &&
        other.title == title &&
        other.centerTitle == centerTitle &&
        other.elevation == elevation &&
        other.backgroundColor == backgroundColor &&
        other.automaticallyImplyLeading == automaticallyImplyLeading &&
        other.bottom == bottom;
  }

  @override
  int get hashCode {
    return Object.hash(
      title,
      centerTitle,
      elevation,
      backgroundColor,
      automaticallyImplyLeading,
      bottom,
    );
  }
}
