import 'dart:async';

import 'package:flutter/material.dart';

import '../core/store.dart';

class DraftLifecycle extends StatefulWidget {
  final StudioStore store;
  final Widget child;
  const DraftLifecycle({super.key, required this.store, required this.child});
  @override
  State<DraftLifecycle> createState() => _DraftLifecycleState();
}

class _DraftLifecycleState extends State<DraftLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(widget.store.flushDraft());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
