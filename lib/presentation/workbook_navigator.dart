import 'package:flutter/material.dart';

import 'widgets/sheet_tab_bar.dart';

class WorkbookNavigator extends StatefulWidget {
  const WorkbookNavigator({
    super.key,
    required this.sheets,
    required this.selectedSheetIndex,
    required this.onSheetSelected,
    required this.onAddSheet,
    required this.onRemoveSheet,
  });

  final List<String> sheets;
  final int selectedSheetIndex;
  final ValueChanged<int> onSheetSelected;
  final VoidCallback onAddSheet;
  final ValueChanged<int> onRemoveSheet;

  @override
  State<WorkbookNavigator> createState() => _WorkbookNavigatorState();
}

class _WorkbookNavigatorState extends State<WorkbookNavigator> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.selectedSheetIndex);
  }

  @override
  void didUpdateWidget(covariant WorkbookNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSheetIndex != oldWidget.selectedSheetIndex) {
      _jumpToSheet(widget.selectedSheetIndex);
    }
  }

  void _jumpToSheet(int index) {
    if (!_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pageController.jumpToPage(index);
        }
      });
      return;
    }
    if (_pageController.page?.round() == index) {
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheets = widget.sheets;
    return Column(
      children: [
        SheetTabBar(
          sheets: sheets,
          selectedIndex: widget.selectedSheetIndex,
          onSelectSheet: widget.onSheetSelected,
          onAddSheet: widget.onAddSheet,
          onRemoveSheet: widget.onRemoveSheet,
        ),
        Expanded(
          child: sheets.isEmpty
              ? const Center(child: Text('Aucune feuille disponible'))
              : PageView.builder(
                  controller: _pageController,
                  itemCount: sheets.length,
                  onPageChanged: widget.onSheetSelected,
                  itemBuilder: (context, index) {
                    return Center(
                      child: Text(
                        'Contenu de ${sheets[index]}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
