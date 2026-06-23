import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'form_builder.freezed.dart';
part 'form_builder.g.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

enum FormFieldType { text, email, number, url, phone, dropdown, date, toggle, multiselect }

@freezed
class FormFieldSchema with _$FormFieldSchema {
  const factory FormFieldSchema({
    required String name,
    required FormFieldType type,
    required String label,
    @Default(false) bool required,
    @Default([]) List<String> validators,
    List<String>? options,
    String? placeholder,
    String? hint,
  }) = _FormFieldSchema;

  factory FormFieldSchema.fromJson(Map<String, dynamic> json) => _$FormFieldSchemaFromJson(json);
}

@freezed
class FormSchema with _$FormSchema {
  const factory FormSchema({required List<FormFieldSchema> fields}) = _FormSchema;
  factory FormSchema.fromJson(Map<String, dynamic> json) => _$FormSchemaFromJson(json);
}

// ---------------------------------------------------------------------------
// Validation (pure function — testable in isolation)
// ---------------------------------------------------------------------------

String? validateField(FormFieldSchema field, String? value, Map<String, String?> allValues) {
  final v = value ?? '';
  for (final rule in field.validators) {
    final parts = rule.split(':');
    final name = parts.first;
    final arg = parts.length > 1 ? parts.sublist(1).join(':') : null;

    switch (name) {
      case 'required':
        final empty = field.type == FormFieldType.toggle ? v != 'true' : v.trim().isEmpty;
        if (empty) return '${field.label} is required';
      case 'email':
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Enter a valid email';
      case 'url':
        if (!RegExp(r'^https?://[^\s/$.?#].[^\s]*$').hasMatch(v)) return 'Enter a valid URL';
      case 'phone':
        if (!RegExp(r'^\+?[\d\s\-().]{7,15}$').hasMatch(v)) return 'Enter a valid phone number';
      case 'numeric':
        if (num.tryParse(v) == null) return 'Enter a valid number';
      case 'min':
        if (num.tryParse(arg ?? '') case final min? when num.tryParse(v) case final val? when val < min)
          return 'Must be at least $min';
      case 'max':
        if (num.tryParse(arg ?? '') case final max? when num.tryParse(v) case final val? when val > max)
          return 'Must be at most $max';
      case 'min_length':
        if (arg != null && v.length < int.parse(arg)) return 'Must be at least $arg characters';
      case 'max_length':
        if (arg != null && v.length > int.parse(arg)) return 'Must be at most $arg characters';
      case 'regex':
        if (arg != null && !RegExp(arg).hasMatch(v)) return 'Invalid format';
      case 'matches':
        if (arg != null && v != (allValues[arg] ?? '')) return 'Does not match ${arg.replaceAll('_', ' ')}';
      case 'date_after':
        if (v.isNotEmpty && arg == 'today' && DateTime.tryParse(v) case final d? when !d.isAfter(DateTime.now()))
          return 'Date must be after today';
      case 'date_before':
        if (v.isNotEmpty && arg == 'today' && DateTime.tryParse(v) case final d? when !d.isBefore(DateTime.now()))
          return 'Date must be before today';
      case 'must_be_true':
        if (v != 'true') return 'You must accept ${field.label}';
      case 'min_selection':
        final s = v.split(',').where((x) => x.trim().isNotEmpty).toList();
        if (arg != null && s.length < int.parse(arg)) return 'Select at least $arg';
      case 'max_selection':
        final s = v.split(',').where((x) => x.trim().isNotEmpty).toList();
        if (arg != null && s.length > int.parse(arg)) return 'Select at most $arg';
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum FormSubmissionStatus { idle, validating, submitting, success, failure }

@freezed
class FormBuilderState with _$FormBuilderState {
  const factory FormBuilderState({
    required FormSchema schema,
    required Map<String, TextEditingController> controllers,
    @Default({}) Map<String, String?> fieldErrors,
    @Default(FormSubmissionStatus.idle) FormSubmissionStatus status,
    String? formError,
  }) = _FormBuilderState;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

typedef FormSubmitter = Future<Result<Map<String, dynamic>>> Function(Map<String, dynamic> values);

@riverpod
class FormBuilderNotifier extends _$FormBuilderNotifier {
  FormSubmitter? _submitter;

  void configure(FormSubmitter submitter) => _submitter = submitter;

  @override
  FormBuilderState build(FormSchema schema) {
    return FormBuilderState(
      schema: schema,
      controllers: {for (final f in schema.fields) f.name: TextEditingController()},
    );
  }

  String? fieldValue(String name) => state.controllers[name]?.text;

  Future<void> submit() async {
    assert(_submitter != null, 'Call configure(submitter) before submit()');
    state = state.copyWith(status: FormSubmissionStatus.validating, fieldErrors: {}, formError: null);

    final errors = <String, String?>{};
    final values = <String, dynamic>{};
    final allValues = state.controllers.map((k, c) => MapEntry(k, c.text));

    for (final f in state.schema.fields) {
      final raw = state.controllers[f.name]?.text;
      final err = validateField(f, raw, allValues);
      if (err != null) errors[f.name] = err;
      values[f.name] = _coerceValue(f, raw ?? '');
    }

    if (errors.isNotEmpty) {
      state = state.copyWith(status: FormSubmissionStatus.idle, fieldErrors: errors);
      return;
    }

    state = state.copyWith(status: FormSubmissionStatus.submitting);
    final result = await _submitter!(values);
    result.when(
      success: (_) => state = state.copyWith(status: FormSubmissionStatus.success),
      failure: (f) => state = state.copyWith(status: FormSubmissionStatus.failure, formError: f.message),
    );
  }

  void clearErrors() => state = state.copyWith(fieldErrors: {}, formError: null);

  void reset() {
    for (final c in state.controllers.values) { c.clear(); }
    state = state.copyWith(status: FormSubmissionStatus.idle, fieldErrors: {}, formError: null);
  }

  dynamic _coerceValue(FormFieldSchema f, String raw) => switch (f.type) {
    FormFieldType.number => num.tryParse(raw) ?? 0,
    FormFieldType.toggle => raw == 'true',
    FormFieldType.multiselect => raw.split(',').where((s) => s.trim().isNotEmpty).toList(),
    FormFieldType.date => DateTime.tryParse(raw),
    _ => raw.trim(),
  };
}

// ---------------------------------------------------------------------------
// Widget builder — concise per-type helpers
// ---------------------------------------------------------------------------

TextInputType? _keyboardFor(FormFieldType t) => switch (t) {
  FormFieldType.email => TextInputType.emailAddress,
  FormFieldType.number => TextInputType.number,
  FormFieldType.url => TextInputType.url,
  FormFieldType.phone => TextInputType.phone,
  _ => null,
};

Widget buildFormField(BuildContext context, FormFieldSchema f, TextEditingController c,
    String? error, ValueChanged<String> onChanged) {
  final theme = Theme.of(context);
  final kb = _keyboardFor(f.type);

  if (f.type == FormFieldType.dropdown) {
    final opts = f.options ?? [];
    final val = c.text.isNotEmpty && opts.contains(c.text) ? c.text : null;
    return DropdownButtonFormField<String>(
      value: val,
      decoration: _dec(f, error, theme),
      items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: (v) { c.text = v ?? ''; onChanged(v ?? ''); },
    );
  }

  if (f.type == FormFieldType.date) {
    return TextFormField(
      controller: c,
      decoration: _dec(f, error, theme).copyWith(suffixIcon: const Icon(Icons.calendar_today)),
      readOnly: true,
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: DateTime.now(),
            firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (d != null) {
          final v = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          c.text = v; onChanged(v);
        }
      },
    );
  }

  if (f.type == FormFieldType.toggle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SwitchListTile(title: Text(f.label), value: c.text == 'true',
          onChanged: (v) { c.text = v.toString(); onChanged(v.toString()); }),
      if (error != null)
        Padding(padding: const EdgeInsets.only(left: 16),
            child: Text(error, style: TextStyle(color: theme.colorScheme.error, fontSize: 12))),
    ]);
  }

  if (f.type == FormFieldType.multiselect) {
    final opts = f.options ?? [];
    final sel = c.text.split(',').where((x) => x.trim().isNotEmpty).toSet();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(f.label, style: theme.textTheme.titleSmall), const SizedBox(height: 4),
      Wrap(spacing: 8, children: opts.map((o) => FilterChip(label: Text(o), selected: sel.contains(o),
          onSelected: (v) { v ? sel.add(o) : sel.remove(o); c.text = sel.join(','); onChanged(c.text); },
      )).toList()),
      if (error != null)
        Text(error, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
    ]);
  }

  // text / email / number / url / phone — all share TextFormField
  return TextFormField(
    controller: c, decoration: _dec(f, error, theme), keyboardType: kb,
    maxLines: (f.hint != null && f.hint!.length > 60) ? 3 : 1, onChanged: onChanged,
  );
}

InputDecoration _dec(FormFieldSchema f, String? error, ThemeData theme) => InputDecoration(
  labelText: f.label, hintText: f.placeholder,
  helperText: error ?? f.hint,
  helperStyle: TextStyle(color: error != null ? theme.colorScheme.error : null),
  errorBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.error)),
  border: const OutlineInputBorder(),
);
