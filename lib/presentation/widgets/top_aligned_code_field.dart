import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';

/// Wraps the upstream [CodeField] to keep the rest of the codebase API stable
/// while exposing a `textAlignVertical` toggle for expanded layouts.
class TopAlignedCodeField extends StatelessWidget {
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
    TextAlignVertical? textAlignVertical,
  }) : textAlignVertical = textAlignVertical ?? TextAlignVertical.top;

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
  Widget build(BuildContext context) {
    final editor = CodeField(
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

    if (!expands || textAlignVertical == TextAlignVertical.top) {
      return editor;
    }

    return _ExpandingAlignmentWrapper(
      textAlignVertical: textAlignVertical,
      child: editor,
    );
  }
}

class _ExpandingAlignmentWrapper extends StatelessWidget {
  const _ExpandingAlignmentWrapper({
    required this.textAlignVertical,
    required this.child,
  });

  final TextAlignVertical textAlignVertical;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasHeight = constraints.hasBoundedHeight &&
            constraints.maxHeight != double.infinity;
        final align = Alignment(0, textAlignVertical.y.clamp(-1.0, 1.0));

        if (!hasHeight) {
          return Align(alignment: align, child: child);
        }

        return SizedBox(
          height: constraints.maxHeight,
          child: Align(alignment: align, child: child),
        );
      },
    );
  }
}
