import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateChecker {
  static const String versionUrl = 'https://versionhost-88b2d.web.app/version.json';

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'];
        final apkUrl = data['apk_url'];

        if (_isNewerVersion(latestVersion, currentVersion)) {
          if (!context.mounted) return;

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Update Available'),
              content: Text('A new version ($latestVersion) is available.'),
              actions: [
                TextButton(
                  child: const Text('Later'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                ElevatedButton(
                  child: const Text('Update Now'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _launchApkUrl(apkUrl);
                  },
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Version check failed: $e');
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length || latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

    static void _launchApkUrl(String url) async {
      final uri = Uri.parse(url);

      try {
        // Try to launch in external browser
        bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

        // Fallback to platform default (e.g., in-app browser or system default handler)
        if (!launched) {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        }

        if (!launched) {
          debugPrint('No handler could open URL: $url');
        }
      } catch (e) {
        debugPrint('Failed to launch update URL: $e');
      }
    }

}
