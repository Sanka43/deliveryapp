import 'package:flutter/material.dart';

/// Shared white page AppBar for non-home customer screens.
AppBar mndPageAppBar({
  required String title,
  List<Widget>? actions,
  bool implyLeading = true,
  Widget? leading,
}) {
  return AppBar(
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    automaticallyImplyLeading: implyLeading,
    leading: leading,
    actions: actions,
  );
}
