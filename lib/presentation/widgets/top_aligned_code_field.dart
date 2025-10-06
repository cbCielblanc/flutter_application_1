import 'dart:math';

import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';

/// A local extension of the upstream [CodeField] widget that exposes
/// [textAlignVertical] and keeps the editable content anchored to the top of
/// the viewport when `expands: true`.
class TopAlignedCodeField extends StatefulWidget {
  const TopAlignedCodeField({
    super.key,
    required this.controller,
    this.minLines,
    this.maxLines,
    this.expands = false,
    this.wrap = false,
    this.background,
    this.decoration,
    this.textStyle,
    this.padding = EdgeInsets.zero,
    this.lineNumberStyle = const LineNumberStyle(),
    this.enabled,
    this.onTap,
    this.readOnly = false,
    this.cursorColor,
    this.textSelectionTheme,
    this.lineNumberBuilder,
    this.focusNode,
    this.onChanged,
    this.isDense = false,
    this.smartQuotesType,
    this.keyboardType,
    this.lineNumbers = true,
    this.horizontalScroll = true,
    this.selectionControls,
  });

  final SmartQuotesType? smartQuotesType;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final bool expands;
  final bool wrap;
  final CodeController controller;
  final LineNumberStyle lineNumberStyle;
  final Color? cursorColor;
  final TextStyle? textStyle;
  final TextSpan Function(int, TextStyle?)? lineNumberBuilder;
  final bool? enabled;
  final void Function(String)? onChanged;
  final bool readOnly;
  final bool isDense;
  final TextSelectionControls? selectionControls;
  final Color? background;
  final EdgeInsets padding;
  final Decoration? decoration;
  final TextSelectionThemeData? textSelectionTheme;
  final FocusNode? focusNode;
  final void Function()? onTap;
  final bool lineNumbers;
  final bool horizontalScroll;
  final TextAlignVertical textAlignVertical;

  @override
  State<TopAlignedCodeField> createState() => _TopAlignedCodeFieldState();
}

class _TopAlignedCodeFieldState extends State<TopAlignedCodeField> {
  LinkedScrollControllerGroup? _controllers;
  ScrollController? _numberScroll;
  ScrollController? _codeScroll;
  LineNumberController? _numberController;

  FocusNode? _focusNode;
  String longestLine = '';
  int _lineNumberDigits = 1;
  int _lineCount = 1;

  @override
  void initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
    _numberScroll = _controllers?.addAndGet();
    _codeScroll = _controllers?.addAndGet();
    _numberController = LineNumberController(widget.lineNumberBuilder);
    widget.controller.addListener(_onTextChanged);
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode!.onKey = _onKey;
    _focusNode!.attach(context, onKey: _onKey);

    _onTextChanged();
  }

  KeyEventResult _onKey(FocusNode node, RawKeyEvent event) {
    if (widget.readOnly) {
      return KeyEventResult.ignored;
    }

    return widget.controller.onKey(event);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _numberScroll?.dispose();
    _codeScroll?.dispose();
    _numberController?.dispose();
    _numberController = null;
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted || _numberController == null) {
      return;
    }

    final lines = widget.controller.text.split('\n');
    final newLineCount = max(1, lines.length);
    final newDigitWidth = max(1, newLineCount.toString().length);
    final buf = <String>[];

    for (var k = 0; k < lines.length; k++) {
      buf.add((k + 1).toString().padLeft(newDigitWidth));
    }

    _numberController?.text = buf.join('\n');
    _lineCount = newLineCount;
    _lineNumberDigits = newDigitWidth;

    longestLine = '';
    for (final line in widget.controller.text.split('\n')) {
      if (line.length > longestLine.length) {
        longestLine = line;
      }
    }

    setState(() {});
  }

  Widget _wrapInScrollView(
    Widget codeField,
    TextStyle textStyle,
    double minWidth,
  ) {
    final leftPad = widget.lineNumberStyle.margin / 2;
    final intrinsic = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 0,
              minWidth: max(minWidth - leftPad, 0),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(longestLine, style: textStyle),
            ),
          ),
          widget.expands ? Expanded(child: codeField) : codeField,
        ],
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: leftPad,
        right: widget.padding.right,
      ),
      scrollDirection: Axis.horizontal,
      physics:
          widget.horizontalScroll ? null : const NeverScrollableScrollPhysics(),
      child: intrinsic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CodeField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      expands: expands,
      wrap: wrap,
      background: background,
      decoration: decoration,
      textStyle: textStyle,
      padding: padding,
      lineNumberStyle: lineNumberStyle,
      enabled: enabled,
      onTap: onTap,
      readOnly: readOnly,
      cursorColor: cursorColor,
      textSelectionTheme: textSelectionTheme,
      lineNumberBuilder: lineNumberBuilder,
      focusNode: focusNode,
      onChanged: onChanged,
      isDense: isDense,
      smartQuotesType: smartQuotesType,
      keyboardType: keyboardType,
      lineNumbers: lineNumbers,
      horizontalScroll: horizontalScroll,
      selectionControls: selectionControls,
    );
  }
}
