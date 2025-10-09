part of 'workbook_navigator.dart';

class _ScriptEditorOverlayHost extends StatefulWidget {
  const _ScriptEditorOverlayHost({
    required this.isActive,
    required this.overlayBuilder,
  });

  final bool isActive;
  final WidgetBuilder overlayBuilder;

  @override
  State<_ScriptEditorOverlayHost> createState() =>
      _ScriptEditorOverlayHostState();
}

class _ScriptEditorOverlayHostState extends State<_ScriptEditorOverlayHost> {
  OverlayEntry? _entry;
  bool _overlayRebuildScheduled = false;

  void _scheduleOverlayRebuild() {
    if (_overlayRebuildScheduled) {
      return;
    }
    _overlayRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayRebuildScheduled = false;
      if (!mounted) {
        return;
      }
      _entry?.markNeedsBuild();
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _insertEntry();
    }
  }

  @override
  void didUpdateWidget(covariant _ScriptEditorOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _insertEntry();
    } else if (oldWidget.isActive && !widget.isActive) {
      _removeEntry();
    } else if (widget.isActive && _entry != null) {
      _scheduleOverlayRebuild();
    }
  }

  void _insertEntry() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) {
        return;
      }
      if (_entry != null) {
        _scheduleOverlayRebuild();
        return;
      }
      final overlay = Overlay.of(context, rootOverlay: true);
      _entry = OverlayEntry(
        builder: (context) => widget.overlayBuilder(context),
      );
      overlay.insert(_entry!);
    });
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isActive && _entry != null) {
      _scheduleOverlayRebuild();
    }
    return const SizedBox.shrink();
  }
}
