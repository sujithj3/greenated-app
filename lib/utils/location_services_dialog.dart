import 'package:flutter/material.dart';

import 'app_colors.dart';

const String locationServicesDisabledTitle = 'Location Services Disabled';
const String locationServicesDisabledMessage =
    'Location services are disabled on this device. Please enable them to access location services.';
const String locationPermissionSettingsTitle = 'Location Access';
const String locationPermissionSettingsMessage =
    'Location access is off. You can enable it in Settings for location features.';

Future<void> showLocationServicesDisabledDialog(BuildContext context) {
  if (!context.mounted) return Future<void>.value();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(locationServicesDisabledTitle),
      content: const Text(locationServicesDisabledMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<void> showLocationPermissionSettingsPrompt(
  BuildContext context, {
  required Future<void> Function() onOpenSettings,
}) {
  if (!context.mounted) return Future<void>.value();

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              color: Colors.white70,
              size: 56,
            ),
            const SizedBox(height: 18),
            const Text(
              locationPermissionSettingsTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              locationPermissionSettingsMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await onOpenSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Open Settings'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
