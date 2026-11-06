import 'dart:math' as math;
import 'package:flutter/material.dart' as m;
import 'package:provider/provider.dart';
import '../core/billing_strings.dart';
import '../providers/language_provider.dart';

class BillingText extends m.StatelessWidget {
  const BillingText(this.data,
      {super.key,
      this.style,
      this.strutStyle,
      this.textAlign,
      this.textDirection,
      this.locale,
      this.softWrap,
      this.overflow,
      this.textScaler,
      this.maxLines,
      this.semanticsLabel,
      this.textWidthBasis,
      this.textHeightBehavior,
      this.selectionColor})
      : textSpan = null;
  const BillingText.rich(this.textSpan,
      {super.key,
      this.style,
      this.strutStyle,
      this.textAlign,
      this.textDirection,
      this.locale,
      this.softWrap,
      this.overflow,
      this.textScaler,
      this.maxLines,
      this.semanticsLabel,
      this.textWidthBasis,
      this.textHeightBehavior,
      this.selectionColor})
      : data = null;
  final String? data;
  final m.InlineSpan? textSpan;
  final m.TextStyle? style;
  final m.StrutStyle? strutStyle;
  final m.TextAlign? textAlign;
  final m.TextDirection? textDirection;
  final m.Locale? locale;
  final bool? softWrap;
  final m.TextOverflow? overflow;
  final m.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final m.TextWidthBasis? textWidthBasis;
  final m.TextHeightBehavior? textHeightBehavior;
  final m.Color? selectionColor;
  @override
  m.Widget build(m.BuildContext context) {
    context.watch<AppLanguageProvider?>();
    final effective = style ?? m.DefaultTextStyle.of(context).style;
    final readable = effective.copyWith(
        fontFamily: 'FastStoreDevanagari',
        fontSize: math.max(
            effective.fontSize ?? 18, BillingStrings.isNepali ? 21 : 18),
        height: BillingStrings.isNepali ? 1.55 : 1.3);
    if (data != null) {
      return m.Text(BillingStrings.tr(data!),
          style: readable,
          strutStyle: strutStyle,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaler: textScaler,
          maxLines: maxLines,
          semanticsLabel: BillingStrings.optional(semanticsLabel),
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
          selectionColor: selectionColor);
    }
    return m.Text.rich(
        data != null
            ? m.TextSpan(text: BillingStrings.tr(data!))
            : _span(textSpan!),
        style: readable,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: BillingStrings.optional(semanticsLabel),
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor);
  }

  static m.InlineSpan _span(m.InlineSpan span) => span is m.TextSpan
      ? m.TextSpan(
          text: BillingStrings.optional(span.text),
          style: span.style,
          recognizer: span.recognizer,
          children: span.children?.map(_span).toList())
      : span;
}

class BillingInputDecoration extends m.InputDecoration {
  const BillingInputDecoration(
      {super.icon,
      super.iconColor,
      super.label,
      super.labelText,
      super.labelStyle,
      super.floatingLabelStyle,
      super.helper,
      super.helperText,
      super.helperStyle,
      super.helperMaxLines,
      super.hintText,
      super.hintStyle,
      super.hintTextDirection,
      super.hintMaxLines,
      super.error,
      super.errorText,
      super.errorStyle,
      super.errorMaxLines,
      super.floatingLabelBehavior,
      super.floatingLabelAlignment,
      super.isCollapsed,
      super.isDense,
      super.contentPadding,
      super.prefixIcon,
      super.prefixIconConstraints,
      super.prefix,
      super.prefixText,
      super.prefixStyle,
      super.prefixIconColor,
      super.suffixIcon,
      super.suffix,
      super.suffixText,
      super.suffixStyle,
      super.suffixIconColor,
      super.suffixIconConstraints,
      super.counter,
      super.counterText,
      super.counterStyle,
      super.filled,
      super.fillColor,
      super.focusColor,
      super.hoverColor,
      super.errorBorder,
      super.focusedBorder,
      super.focusedErrorBorder,
      super.disabledBorder,
      super.enabledBorder,
      super.border,
      super.enabled,
      super.semanticCounterText,
      super.alignLabelWithHint,
      super.constraints});
  @override
  String? get labelText => BillingStrings.optional(super.labelText);
  @override
  String? get hintText => BillingStrings.optional(super.hintText);
  @override
  String? get helperText => BillingStrings.optional(super.helperText);
  @override
  String? get errorText => BillingStrings.optional(super.errorText);
  @override
  String? get prefixText => BillingStrings.optional(super.prefixText);
  @override
  String? get suffixText => BillingStrings.optional(super.suffixText);
  @override
  int? get helperMaxLines => super.helperMaxLines ?? 3;
  @override
  int? get hintMaxLines => super.hintMaxLines ?? 1;
}

class BillingTextFormField extends m.TextFormField {
  BillingTextFormField(
      {super.key,
      super.controller,
      super.initialValue,
      super.focusNode,
      super.decoration,
      super.keyboardType,
      super.textCapitalization,
      super.textInputAction,
      m.TextStyle? style,
      super.textDirection,
      super.textAlign,
      super.autofocus,
      super.readOnly,
      super.showCursor,
      super.obscuringCharacter,
      super.obscureText,
      super.autocorrect,
      super.enableSuggestions,
      super.maxLines,
      super.minLines,
      super.expands,
      super.maxLength,
      super.onChanged,
      super.onTap,
      super.onEditingComplete,
      super.onFieldSubmitted,
      super.onSaved,
      super.validator,
      super.inputFormatters,
      super.enabled,
      super.autovalidateMode,
      super.cursorWidth,
      super.cursorHeight,
      super.cursorRadius,
      super.cursorColor,
      super.scrollPadding,
      super.enableInteractiveSelection,
      super.autofillHints})
      : super(
            style: (style ?? const m.TextStyle()).copyWith(
                fontFamily: 'FastStoreDevanagari',
                fontSize: math.max(
                    style?.fontSize ?? 18, BillingStrings.isNepali ? 21 : 18),
                height: 1.5));
  @override
  m.FormFieldValidator<String>? get validator => super.validator == null
      ? null
      : (value) => BillingStrings.optional(super.validator!(value));
}

class BillingIconButton extends m.IconButton {
  const BillingIconButton(
      {super.key,
      required super.onPressed,
      required super.icon,
      super.iconSize,
      super.visualDensity,
      super.padding,
      super.alignment,
      super.splashRadius,
      super.color,
      super.focusColor,
      super.hoverColor,
      super.highlightColor,
      super.splashColor,
      super.disabledColor,
      super.mouseCursor,
      super.focusNode,
      super.autofocus,
      super.tooltip,
      super.enableFeedback,
      super.constraints,
      super.style,
      super.isSelected,
      super.selectedIcon});
  @override
  String? get tooltip => BillingStrings.optional(super.tooltip);
  const BillingIconButton.filledTonal(
      {super.key,
      required super.onPressed,
      required super.icon,
      super.iconSize,
      super.visualDensity,
      super.padding,
      super.alignment,
      super.color,
      super.tooltip,
      super.style,
      super.isSelected,
      super.selectedIcon})
      : super.filledTonal();
  const BillingIconButton.filled(
      {super.key,
      required super.onPressed,
      required super.icon,
      super.iconSize,
      super.visualDensity,
      super.padding,
      super.alignment,
      super.color,
      super.tooltip,
      super.style,
      super.isSelected,
      super.selectedIcon})
      : super.filled();
  const BillingIconButton.outlined(
      {super.key,
      required super.onPressed,
      required super.icon,
      super.iconSize,
      super.visualDensity,
      super.padding,
      super.alignment,
      super.color,
      super.tooltip,
      super.style,
      super.isSelected,
      super.selectedIcon})
      : super.outlined();
}

class BillingTooltip extends m.Tooltip {
  const BillingTooltip(
      {super.key,
      required super.message,
      super.child,
      super.preferBelow,
      super.verticalOffset,
      super.waitDuration,
      super.showDuration});
  @override
  String? get message => BillingStrings.optional(super.message);
}

class BillingPopupMenuButton<T> extends m.PopupMenuButton<T> {
  const BillingPopupMenuButton(
      {super.key,
      required super.itemBuilder,
      super.initialValue,
      super.onSelected,
      super.onCanceled,
      super.tooltip,
      super.child,
      super.icon,
      super.enabled,
      super.position,
      super.offset,
      super.color,
      super.shape,
      super.padding,
      super.constraints});
  @override
  String? get tooltip => BillingStrings.optional(super.tooltip);
}
