import 'package:flutter/material.dart';

const String locationServicesDisabledTitle = 'Location Services Disabled';
const String locationServicesDisabledMessage =
    'Location services are disabled on this device. Please enable them to access location services.';

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
