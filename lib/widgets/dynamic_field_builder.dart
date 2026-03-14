import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/api/api_models.dart';
import '../utils/app_colors.dart';

/// Renders a single [ApiField] as the appropriate UI widget based on its
/// [FieldStyle]. Handles validation, value tracking, and user interaction.
class DynamicFieldBuilder extends StatelessWidget {
  const DynamicFieldBuilder({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.textController,
    this.accentColor,
    this.onPickAttachment,
    this.onPopupPressed,
    this.popupFilledCount,
    this.popupTotalCount,
  });

  final ApiField field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final TextEditingController? textController;
  final Color? accentColor;
  final Future<dynamic> Function(ApiField field)? onPickAttachment;
  final VoidCallback? onPopupPressed;
  final int? popupFilledCount;
  final int? popupTotalCount;

  Color get _accent => accentColor ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    switch (field.fieldStyle) {
      case FieldStyle.text:
        return _buildTextField();
      case FieldStyle.dropdown:
        return _buildDropdownField();
      case FieldStyle.checkbox:
        return _buildCheckboxField(context);
      case FieldStyle.radio:
        return _buildRadioField(context);
      case FieldStyle.date:
        return _buildDateField(context);
      case FieldStyle.camera:
      case FieldStyle.file:
      case FieldStyle.cameraFile:
        return _buildAttachmentField(context);
      case FieldStyle.button:
        return _buildButtonField();
      case FieldStyle.unknown:
        return const SizedBox.shrink();
    }
  }

  // ── Text / Number ──────────────────────────────────────────────────────────

  Widget _buildTextField() {
    final controller = textController ?? TextEditingController();
    final isNumber = field.fieldType == FieldType.number;
    final isPhone = field.key.contains('phone') ||
        field.key.contains('mobile') ||
        field.label.toLowerCase().contains('phone') ||
        field.label.toLowerCase().contains('mobile');

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: field.required ? '${field.label} *' : field.label,
        prefixIcon: Icon(
          isNumber
              ? Icons.numbers_outlined
              : isPhone
                  ? Icons.phone_outlined
                  : Icons.edit_note_outlined,
          color: _accent,
        ),
      ),
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : isPhone
              ? TextInputType.phone
              : TextInputType.text,
      textCapitalization:
          isNumber || isPhone ? TextCapitalization.none : TextCapitalization.sentences,
      inputFormatters: [
        if (isNumber)
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        if (isPhone) FilteringTextInputFormatter.digitsOnly,
      ],
      maxLength: isPhone ? 15 : null,
      onChanged: (raw) {
        if (isNumber) {
          onChanged(double.tryParse(raw.trim()));
        } else {
          onChanged(raw.trim().isEmpty ? null : raw.trim());
        }
      },
      validator: (v) {
        final sanitized = (v ?? '').trim();
        if (field.required && sanitized.isEmpty) {
          return '${field.label} is required';
        }
        if (sanitized.isNotEmpty && isNumber && double.tryParse(sanitized) == null) {
          return 'Enter a valid number';
        }
        if (isPhone && sanitized.isNotEmpty && sanitized.length < 7) {
          return 'Invalid number';
        }
        return null;
      },
    );
  }

  // ── Dropdown ───────────────────────────────────────────────────────────────

  Widget _buildDropdownField() {
    final items = field.fieldData;
    final selected = value is String && items.contains(value) ? value as String : null;

    return DropdownButtonFormField<String>(
      key: ValueKey('dropdown_${field.key}'),
      initialValue: selected,
      decoration: InputDecoration(
        labelText: field.required ? '${field.label} *' : field.label,
        prefixIcon: Icon(Icons.arrow_drop_down_circle_outlined, color: _accent),
      ),
      hint: Text('Select ${field.label}'),
      items: items
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (v) => onChanged(v),
      validator: (v) {
        if (field.required && (v == null || v.isEmpty)) {
          return '${field.label} is required';
        }
        return null;
      },
    );
  }

  // ── Checkbox ───────────────────────────────────────────────────────────────

  Widget _buildCheckboxField(BuildContext context) {
    final checked = value is bool ? value as bool : false;

    return FormField<bool>(
      key: ValueKey('checkbox_${field.key}'),
      initialValue: checked,
      validator: (v) {
        if (field.required && v != true) {
          return '${field.label} is required';
        }
        return null;
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.veryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.hasError ? AppColors.error : AppColors.light,
                ),
              ),
              child: CheckboxListTile(
                value: state.value ?? false,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: _accent,
                title: Text(field.label),
                onChanged: (v) {
                  final next = v ?? false;
                  state.didChange(next);
                  onChanged(next);
                },
              ),
            ),
            if (state.hasError) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  state.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // ── Radio (ChoiceChips) ────────────────────────────────────────────────────

  Widget _buildRadioField(BuildContext context) {
    final items = field.fieldData;
    final selected =
        value is String && items.contains(value) ? value as String : null;

    return FormField<String>(
      key: ValueKey('radio_${field.key}'),
      initialValue: selected,
      validator: (v) {
        if (field.required && (v == null || v.isEmpty)) {
          return '${field.label} is required';
        }
        return null;
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.veryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.hasError ? AppColors.error : AppColors.light,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.required ? '${field.label} *' : field.label,
                    style: const TextStyle(
                      color: AppColors.textMedium,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: items
                        .map((option) => ChoiceChip(
                              label: Text(option),
                              selected: state.value == option,
                              selectedColor: _accent.withValues(alpha: 0.2),
                              onSelected: (sel) {
                                final next = sel ? option : null;
                                state.didChange(next);
                                onChanged(next);
                              },
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            if (state.hasError) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  state.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // ── Date Picker ────────────────────────────────────────────────────────────

  Widget _buildDateField(BuildContext context) {
    final controller = textController ?? TextEditingController();

    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: field.required ? '${field.label} *' : field.label,
        prefixIcon: Icon(Icons.calendar_today_outlined, color: _accent),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged(null);
                },
              )
            : null,
      ),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: DateTime(1900),
          lastDate: DateTime(now.year + 10),
        );
        if (picked != null) {
          final formatted =
              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
          controller.text = formatted;
          onChanged(formatted);
        }
      },
      validator: (v) {
        if (field.required && (v == null || v.trim().isEmpty)) {
          return '${field.label} is required';
        }
        return null;
      },
    );
  }

  // ── Attachment (Camera / File) ─────────────────────────────────────────────

  Widget _buildAttachmentField(BuildContext context) {
    return FormField<dynamic>(
      key: ValueKey('attachment_${field.key}'),
      initialValue: value,
      validator: (v) {
        if (field.required && v == null) {
          return '${field.label} is required';
        }
        return null;
      },
      builder: (state) {
        final hasAttachment = state.value != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                if (onPickAttachment == null) return;
                final result = await onPickAttachment!(field);
                if (result == null) return;
                state.didChange(result);
                onChanged(result);
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.veryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        state.hasError ? AppColors.error : AppColors.light,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_attachmentIcon(), color: _accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hasAttachment
                            ? _attachmentLabel(state.value)
                            : field.required
                                ? '${field.label} *'
                                : field.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasAttachment
                              ? AppColors.textDark
                              : AppColors.textMedium,
                        ),
                      ),
                    ),
                    if (hasAttachment)
                      InkWell(
                        onTap: () {
                          state.didChange(null);
                          onChanged(null);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 18,
                              color: AppColors.textMedium),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (state.hasError) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  state.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  IconData _attachmentIcon() {
    return switch (field.fieldStyle) {
      FieldStyle.camera || FieldStyle.cameraFile => Icons.photo_camera_outlined,
      FieldStyle.file => Icons.upload_file_outlined,
      _ => Icons.attach_file_outlined,
    };
  }

  String _attachmentLabel(dynamic attachment) {
    if (attachment is Map && attachment['name'] is String) {
      return attachment['name'] as String;
    }
    if (attachment is String && attachment.trim().isNotEmpty) {
      final segments = attachment.split('/');
      return segments.isNotEmpty ? segments.last : attachment;
    }
    return 'Selected file';
  }

  // ── Button (opens popup) ───────────────────────────────────────────────────

  Widget _buildButtonField() {
    if (field.popup == null && onPopupPressed == null) {
      return const SizedBox.shrink();
    }
    final filled = popupFilledCount ?? 0;
    final total = popupTotalCount ?? field.popup?.fields.length ?? 0;

    return OutlinedButton.icon(
      onPressed: onPopupPressed,
      icon: Icon(
        filled > 0 ? Icons.check_circle_outline : Icons.add_circle_outline,
        color: filled > 0 ? _accent : AppColors.textMedium,
      ),
      label: Text(
        filled > 0 ? '${field.label}  ($filled / $total filled)' : field.label,
        style: TextStyle(
          color: filled > 0 ? _accent : AppColors.textMedium,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        side: BorderSide(
          color: filled > 0 ? _accent : AppColors.light,
          width: filled > 0 ? 1.5 : 1,
        ),
      ),
    );
  }
}
