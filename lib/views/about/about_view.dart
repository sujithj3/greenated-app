// About Us view — a static informational screen reached from the side menu.
//
// Displays the Greenated brand mark and tagline near the top, with the app
// version and update date pinned toward the bottom. Both come from
// VersionInfoService: the version is read from the bundle at runtime, and the
// "updated" date is the day that version first ran on this device — it only
// changes on an actual version bump, not on every rebuild.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/version_info_service.dart';
import '../../utils/app_colors.dart';

class AboutView extends StatefulWidget {
  const AboutView({super.key});

  @override
  State<AboutView> createState() => _AboutViewState();
}

class _AboutViewState extends State<AboutView> {
  AppVersionInfo? _versionInfo;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final info = await VersionInfoService.load();
    if (mounted) {
      setState(() => _versionInfo = info);
    }
  }

  String get _versionLine {
    final info = _versionInfo;
    if (info == null) return 'Version: —';
    final updated = DateFormat('d MMMM yyyy').format(info.updatedAt);
    return 'Version: ${info.version}  |  Updated: $updated';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                  minWidth: constraints.maxWidth,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Reasonable top padding so content doesn't hug the app bar.
                        const SizedBox(height: 48),

                        // 1. App logo.
                        Image.asset(
                          'assets/images/greenated-trasnparent-logo.png',
                          width: screenWidth * 0.5,
                          fit: BoxFit.contain,
                        ),

                        // Comfortable gap between the logo and the tagline.
                        const SizedBox(height: 32),

                        // 2. Tagline — emphasised for good visibility.
                        Text.rich(
                          TextSpan(
                            children: const [
                              TextSpan(text: 'Powering '),
                              TextSpan(
                                text: 'NET-ZERO',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(text: ' Through\nNature and Innovation'),
                            ],
                            style: const TextStyle(
                              color: AppColors.dark,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // Spacer between the tagline (2) and the version block (3).
                        const Spacer(),

                        // 3. Version and update date.
                        Text(
                          _versionLine,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMedium,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 4. Copyright.
                        const Text(
                          '© Greenated',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
