import 'dart:async';

import 'package:flutter/widgets.dart';

import '../providers/plan_provider.dart';

/// One clock observer for the existing provider; no new plan or API state.
class PlanLifecycle extends StatefulWidget {
  const PlanLifecycle({super.key, required this.plans, required this.child});
  final PlanProvider plans;
  final Widget child;
  @override
  State<PlanLifecycle> createState() => _PlanLifecycleState();
}

class _PlanLifecycleState extends State<PlanLifecycle>
    with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(widget.plans.untilNextDay, () {
      if (mounted) {
        widget.plans.refreshDay();
        _arm();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PlanLifecycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plans != widget.plans) _arm();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.plans.refreshDay();
      _arm();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
