import 'package:flutter/material.dart';
import '../services/auto_lock_service.dart';

class ActivityTracker extends StatefulWidget {
  final Widget child;

  const ActivityTracker({super.key, required this.child});

  @override
  State<ActivityTracker> createState() => _ActivityTrackerState();
}

class _ActivityTrackerState extends State<ActivityTracker> {
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => AutoLockService.updateActivity(),
      onPointerMove: (_) => AutoLockService.updateActivity(),
      child: GestureDetector(
        onTap: () => AutoLockService.updateActivity(),
        onPanDown: (_) => AutoLockService.updateActivity(),
        onPanUpdate: (_) => AutoLockService.updateActivity(),
        child: widget.child,
      ),
    );
  }
}
