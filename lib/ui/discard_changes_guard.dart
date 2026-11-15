import 'package:flutter/material.dart';

/// One exit policy for toolbar, Android system Back, and predictive Back.
class DiscardChangesGuard extends StatefulWidget {
  const DiscardChangesGuard({
    super.key,
    required this.hasChanges,
    this.saving = false,
    required this.child,
  });
  final bool hasChanges;
  final bool saving;
  final Widget child;
  @override
  State<DiscardChangesGuard> createState() => _DiscardChangesGuardState();
}

class _DiscardChangesGuardState extends State<DiscardChangesGuard> {
  bool _approved = false;
  bool _asking = false;

  Future<void> _requestExit() async {
    if (_asking || _approved) return;
    if (widget.saving) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saving… Please wait.')));
      return;
    }
    if (!widget.hasChanges) return;
    _asking = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. Leaving will discard them.',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard changes'),
          ),
        ],
      ),
    );
    _asking = false;
    if (discard != true || !mounted) return;
    setState(() => _approved = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: _approved || (!widget.hasChanges && !widget.saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _requestExit();
    },
    child: widget.child,
  );
}
