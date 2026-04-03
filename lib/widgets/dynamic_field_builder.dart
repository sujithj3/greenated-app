import 'package:cached_network_image/cached_network_image.dart';
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
    this.onPopupFormPressed,
    this.popupFormFilledCount,
    this.popupFormTotalCount,
    this.isUploading = false,
    this.onCapturePhoto,
    this.onClearPhoto,
    this.onMapPolygonPressed,
    this.onGenerateKml,
    this.resolvedOptions,
    this.isLoadingOptions = false,
    this.optionsError,
    this.onRetryOptions,
    this.isViewMode = false,
    this.previewUrl,
  });

  final ApiField field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final TextEditingController? textController;
  final Color? accentColor;
  final Future<dynamic> Function(ApiField field)? onPickAttachment;
  final VoidCallback? onPopupFormPressed;
  final int? popupFormFilledCount;
  final int? popupFormTotalCount;

  /// Whether the camera field is currently uploading an image.
  final bool isUploading;

  /// Callback to open the camera and capture a photo for a camera field.
  final VoidCallback? onCapturePhoto;

  /// Callback to clear/remove a captured image for a camera field.
  final VoidCallback? onClearPhoto;

  /// Callback to open the map for a map polygon field.
  final VoidCallback? onMapPolygonPressed;

  /// Callback to generate and share a KML file for a map polygon field.
  /// When non-null, a "Generate KML" button is shown next to the "View Map" button.
  final VoidCallback? onGenerateKml;

  /// Runtime-resolved options for dependent dropdowns (null = use field.options).
  final List<ApiOption>? resolvedOptions;

  /// Whether dependent options are currently being fetched.
  final bool isLoadingOptions;

  /// Error message from a failed dependent options fetch.
  final String? optionsError;

  /// Callback to retry a failed dependent options fetch.
  final VoidCallback? onRetryOptions;

  /// When true, all fields render in read-only display mode.
  final bool isViewMode;

  /// Presigned S3 URL for displaying a camera-field image.
  /// Takes priority over [value] when resolving the image URL for display.
  final String? previewUrl;

  Color get _accent => accentColor ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    switch (field.fieldStyle) {
      case FieldStyle.text:
        return _buildTextField();
      case FieldStyle.number:
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
      case FieldStyle.cameraFile:
        return _buildCameraField(context);
      case FieldStyle.file:
        return _buildAttachmentField(context);
      case FieldStyle.popupForm:
        return _buildPopupFormField();
      case FieldStyle.mapPolygon:
        return _buildMapPolygonField(context);
      case FieldStyle.unknown:
        return const SizedBox.shrink();
    }
  }

  // ── Text / Number ──────────────────────────────────────────────────────────

  Widget _buildTextField() {
    final controller = textController ?? TextEditingController();
    final isNumber = field.fieldType == FieldType.integer ||
        field.fieldType == FieldType.decimal;
    final isPhone = field.key.contains('phone') ||
        field.key.contains('mobile') ||
        field.label.toLowerCase().contains('phone') ||
        field.label.toLowerCase().contains('mobile');

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: isViewMode
            ? field.label
            : (field.required ? '${field.label} *' : field.label),
        hintText: isViewMode ? null : field.effectiveplaceHolder,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(
          isNumber
              ? Icons.numbers_outlined
              : isPhone
                  ? Icons.phone_outlined
                  : Icons.edit_note_outlined,
          color: _accent,
        ),
      ),
      readOnly: isViewMode,
      enabled: !isViewMode,
      keyboardType: isViewMode
          ? null
          : isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : isPhone
                  ? TextInputType.phone
                  : TextInputType.text,
      textCapitalization: isNumber || isPhone
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      inputFormatters: isViewMode
          ? const []
          : [
              if (field.fieldType == FieldType.integer)
                FilteringTextInputFormatter.digitsOnly,
              if (field.fieldType == FieldType.decimal)
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              if (isPhone) FilteringTextInputFormatter.digitsOnly,
            ],
      maxLength: isViewMode ? null : (isPhone ? 15 : null),
      onChanged: isViewMode
          ? null
          : (raw) {
              if (field.fieldType == FieldType.integer) {
                onChanged(int.tryParse(raw.trim()));
              } else if (field.fieldType == FieldType.decimal) {
                onChanged(double.tryParse(raw.trim()));
              } else {
                onChanged(raw.trim().isEmpty ? null : raw.trim());
              }
            },
      validator: isViewMode
          ? null
          : (v) {
              final sanitized = (v ?? '').trim();
              if (field.required && sanitized.isEmpty) {
                return '${field.label} is required';
              }
              if (sanitized.isNotEmpty &&
                  isNumber &&
                  double.tryParse(sanitized) == null) {
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
    if (isViewMode) {
      final options = resolvedOptions ?? field.options;
      final selectedStr = value?.toString();
      final matched = options.firstWhere(
        (o) => o.id.toString() == selectedStr,
        orElse: () => ApiOption(id: -1, name: selectedStr ?? '-'),
      );
      final displayText =
          matched.name.isNotEmpty ? matched.name : (selectedStr ?? '-');
      return InputDecorator(
        decoration: InputDecoration(
          labelText: field.label,
          prefixIcon:
              Icon(Icons.arrow_drop_down_circle_outlined, color: _accent),
        ),
        child: Text(
          displayText,
          style: const TextStyle(color: AppColors.textDark),
        ),
      );
    }

    if (isLoadingOptions) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: field.required ? '${field.label} *' : field.label,
          prefixIcon:
              Icon(Icons.arrow_drop_down_circle_outlined, color: _accent),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
            ),
            const SizedBox(width: 8),
            const Text('Loading...',
                style: TextStyle(color: AppColors.textMedium)),
          ],
        ),
      );
    }

    if (optionsError != null) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: field.required ? '${field.label} *' : field.label,
          prefixIcon:
              Icon(Icons.arrow_drop_down_circle_outlined, color: _accent),
          errorText: optionsError,
          suffixIcon: onRetryOptions != null
              ? IconButton(
                  icon: const Icon(Icons.refresh), onPressed: onRetryOptions)
              : null,
        ),
        child: const Text('Tap retry',
            style: TextStyle(color: AppColors.textMedium)),
      );
    }

    final options = resolvedOptions ?? field.options;
    final bool isDependentWithNoOptions = field.dataSource != null &&
        field.dependsOn != null &&
        field.dependsOn!.isNotEmpty &&
        options.isEmpty;
    final selectedStr = value?.toString();
    final selected =
        options.any((o) => o.id.toString() == selectedStr) ? selectedStr : null;

    final String hintText;
    if (isDependentWithNoOptions) {
      final parentKey = field.dependsOn!;
      hintText =
          'Select ${parentKey[0].toUpperCase()}${parentKey.substring(1)} first';
    } else {
      hintText = 'Select ${field.label.isNotEmpty ? field.label : 'an option'}';
    }

    return DropdownButtonFormField<String>(
      key: ValueKey('dropdown_${field.key}'),
      value: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: field.required ? '${field.label} *' : field.label,
        prefixIcon: Icon(Icons.arrow_drop_down_circle_outlined, color: _accent),
      ),
      hint: Text(hintText, overflow: TextOverflow.ellipsis),
      disabledHint: Text(
        hintText,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textMedium),
      ),
      items: options.isEmpty
          ? [
              const DropdownMenuItem<String>(
                value: 'no_data',
                enabled: false,
                child: Text(
                  'No data found',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textMedium),
                ),
              )
            ]
          : options
              .map((o) => DropdownMenuItem(
                    value: o.id.toString(),
                    child: Text(o.name, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
      onChanged: isDependentWithNoOptions ? null : (v) => onChanged(v),
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
      validator: isViewMode
          ? null
          : (v) {
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
                onChanged: isViewMode
                    ? null
                    : (v) {
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
    final options = field.options;
    final selectedStr = value?.toString();
    final selected =
        options.any((o) => o.id.toString() == selectedStr) ? selectedStr : null;

    return FormField<String>(
      key: ValueKey('radio_${field.key}'),
      initialValue: selected,
      validator: isViewMode
          ? null
          : (v) {
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
                    isViewMode
                        ? field.label
                        : (field.required ? '${field.label} *' : field.label),
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
                    children: options
                        .map((option) => ChoiceChip(
                              label: Text(option.name),
                              selected: state.value == option.id.toString(),
                              selectedColor: _accent.withValues(alpha: 0.2),
                              onSelected: isViewMode
                                  ? null
                                  : (sel) {
                                      final next =
                                          sel ? option.id.toString() : null;
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
      enabled: !isViewMode,
      decoration: InputDecoration(
        labelText: isViewMode
            ? field.label
            : (field.required ? '${field.label} *' : field.label),
        hintText: isViewMode ? null : field.effectiveplaceHolder,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(Icons.calendar_today_outlined, color: _accent),
        suffixIcon: (!isViewMode && controller.text.isNotEmpty)
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged(null);
                },
              )
            : null,
      ),
      onTap: isViewMode
          ? null
          : () async {
              final now = DateTime.now();
              // Try to parse existing value as initial date
              DateTime initialDate = now;
              if (controller.text.isNotEmpty) {
                final parsed = _parseDateDMY(controller.text);
                if (parsed != null) initialDate = parsed;
              }
              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(1900),
                lastDate: DateTime(now.year + 10),
                locale: const Locale('en', 'GB'),
              );
              if (picked != null) {
                final formatted =
                    '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
                controller.text = formatted;
                onChanged(formatted);
              }
            },
      validator: isViewMode
          ? null
          : (v) {
              if (field.required && (v == null || v.trim().isEmpty)) {
                return '${field.label} is required';
              }
              return null;
            },
    );
  }

  /// Parses a date string in DD-MM-YYYY format. Returns null if parsing fails.
  static DateTime? _parseDateDMY(String text) {
    final parts = text.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  // ── Camera Field (dynamic, with network image preview) ─────────────────────

  Widget _buildCameraField(BuildContext context) {
    final imageUrl = (previewUrl != null && previewUrl!.isNotEmpty)
        ? previewUrl
        : (value is String && (value as String).isNotEmpty
            ? value as String
            : null);

    return FormField<dynamic>(
      key: ValueKey('camera_${field.key}'),
      initialValue: value,
      validator: (v) {
        if (field.required && (v == null || (v is String && v.isEmpty))) {
          return '${field.label} is required';
        }
        return null;
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null) ...[
              // ── Image preview from URL ──
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        backgroundColor: Colors.black,
                        appBar: AppBar(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        body: Center(
                          child: InteractiveViewer(
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white),
                              ),
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_outlined,
                                    color: Colors.grey, size: 50),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.veryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.veryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                size: 36, color: AppColors.textMedium),
                            SizedBox(height: 8),
                            Text('Failed to load image',
                                style: TextStyle(
                                    color: AppColors.textMedium, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!isViewMode) ...[
                const SizedBox(height: 12),
                // ── Retake / Delete buttons ──
                if (isUploading)
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    label: const Text('Uploading...'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCapturePhoto,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            state.didChange(null);
                            onClearPhoto?.call();
                          },
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: AppColors.error),
                          label: const Text('Remove',
                              style: TextStyle(color: AppColors.error)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ] else if (isViewMode) ...[
              // ── View mode: no image placeholder ──
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.veryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.light),
                ),
                child: Row(
                  children: [
                    Icon(Icons.photo_camera_outlined, color: _accent),
                    const SizedBox(width: 10),
                    Text(field.label,
                        style: const TextStyle(color: AppColors.textMedium)),
                    const Spacer(),
                    const Text('No image',
                        style: TextStyle(
                            color: AppColors.textMedium, fontSize: 12)),
                  ],
                ),
              ),
            ] else ...[
              // ── Capture button ──
              OutlinedButton.icon(
                onPressed: isUploading ? null : onCapturePhoto,
                icon: isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.photo_camera_outlined, color: _accent),
                label: Text(
                  isUploading
                      ? 'Uploading...'
                      : field.required
                          ? '${field.label} *'
                          : field.label,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: BorderSide(
                    color: state.hasError ? AppColors.error : AppColors.light,
                  ),
                ),
              ),
            ],
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

  // ── Attachment (Camera / File) ─────────────────────────────────────────────

  Widget _buildAttachmentField(BuildContext context) {
    return FormField<dynamic>(
      key: ValueKey('attachment_${field.key}'),
      initialValue: value,
      validator: (isViewMode || !field.required)
          ? null
          : (v) {
              if (v == null) return '${field.label} is required';
              return null;
            },
      builder: (state) {
        final hasAttachment = state.value != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: isViewMode
                  ? null
                  : () async {
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
                    color: state.hasError ? AppColors.error : AppColors.light,
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
                            : isViewMode
                                ? 'No file'
                                : (field.required
                                    ? '${field.label} *'
                                    : field.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasAttachment
                              ? AppColors.textDark
                              : AppColors.textMedium,
                        ),
                      ),
                    ),
                    if (hasAttachment && !isViewMode)
                      InkWell(
                        onTap: () {
                          state.didChange(null);
                          onChanged(null);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close,
                              size: 18, color: AppColors.textMedium),
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

  // ── Popup Form (opens sub-form in bottom sheet) ───────────────────────────

  Widget _buildPopupFormField() {
    final filled = popupFormFilledCount ?? 0;
    final total = popupFormTotalCount ?? field.subFields.length;

    if (isViewMode) {
      return OutlinedButton.icon(
        onPressed: onPopupFormPressed,
        icon: Icon(Icons.visibility_outlined, color: _accent),
        label: Text(
          filled > 0
              ? 'View ${field.label}  ($filled / $total filled)'
              : 'View ${field.label}',
          style: TextStyle(color: _accent),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          side: BorderSide(color: _accent, width: 1.5),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPopupFormPressed,
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

  // ── Map Polygon Field ──────────────────────────────────────────────────────

  Widget _buildMapPolygonField(BuildContext context) {
    final asList = value is List ? value as List : null;
    final hasData = asList != null && asList.isNotEmpty;
    final int ptsCount = hasData ? asList.length : 0;

    return FormField<dynamic>(
      key: ValueKey('mappolygon_${field.key}'),
      initialValue: value,
      validator: (isViewMode || !field.required)
          ? null
          : (v) {
              if (v == null || (v as List).isEmpty) {
                return '${field.label} is required';
              }
              return null;
            },
      builder: (state) {
        final pairLabel = hasData ? 'View Land Map' : 'No polygon data';
        final soloLabel = isViewMode
            ? (hasData
                ? 'View ${field.label} ($ptsCount pts)'
                : 'No polygon data')
            : (hasData ? '${field.label} ($ptsCount pts)' : field.label);

        final viewMapButton = OutlinedButton.icon(
          onPressed: (isViewMode && !hasData) ? null : onMapPolygonPressed,
          icon: Icon(isViewMode ? Icons.map_outlined : Icons.map,
              color: hasData ? _accent : AppColors.textMedium),
          label: Text(
            (onGenerateKml != null && hasData) ? pairLabel : soloLabel,
            style: TextStyle(color: hasData ? _accent : AppColors.textMedium),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: BorderSide(
              color: state.hasError
                  ? AppColors.error
                  : hasData
                      ? _accent
                      : AppColors.light,
              width: hasData ? 1.5 : 1,
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onGenerateKml != null && hasData)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        onPressed: onMapPolygonPressed,
                        icon: Icon(
                          isViewMode ? Icons.map_outlined : Icons.map,
                          color: _accent,
                          size: 18,
                        ),
                        label: Text(
                          pairLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _accent),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          side: BorderSide(color: _accent, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: onGenerateKml,
                        icon: Icon(
                          Icons.file_download_outlined,
                          color: _accent,
                          size: 18,
                        ),
                        label: Text(
                          'Export KML',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _accent),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          side: BorderSide(color: _accent, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              viewMapButton,
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
}
