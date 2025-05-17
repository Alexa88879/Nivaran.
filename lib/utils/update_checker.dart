import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:install_plugin_v2/install_plugin_v2.dart';  // Updated import

class UpdateChecker {
  static const String versionUrl = 'https://versionhost-88b2d.web.app/version.json';  // This URL

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
          _showUpdateDialog(context, latestVersion, apkUrl);
        }
      }
    } catch (e) {
      debugPrint('Version check failed: $e');
    }
  }

  static void _showUpdateDialog(BuildContext context, String version, String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Update Available'),
          content: Text('A new version ($version) is available. Would you like to update now?'),
          actions: [
            TextButton(
              child: const Text('Later'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              child: const Text('Update Now'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _startDownload(context, apkUrl);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _startDownload(BuildContext context, String url) async {
    try {
      // Updated permission check for Android 10+
      if (await Permission.manageExternalStorage.isDenied) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage permission is required to download the update')),
            );
          }
          return;
        }
      }

      final dio = Dio();
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;

      final savePath = '${dir.path}/app-update.apk';
      
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: _DownloadProgressDialog(
              dio: dio,
              url: url,
              savePath: savePath,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Download failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start download: $e')),
        );
      }
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
}

class _DownloadProgressDialog extends StatefulWidget {
  final Dio dio;
  final String url;
  final String savePath;

  const _DownloadProgressDialog({
    required this.dio,
    required this.url,
    required this.savePath,
  });

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;
  bool _isDownloading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      await widget.dio.download(
        widget.url,
        widget.savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      setState(() {
        _isDownloading = false;
      });

      if (mounted) {
        Navigator.of(context).pop();
        _installApk(widget.savePath);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isDownloading = false;
      });
    }
  }

  Future<void> _installApk(String filePath) async {
    try {
      final installStatus = await Permission.requestInstallPackages.request();
      if (!installStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission to install packages is required')),
          );
        }
        return;
      }

      // Updated to use InstallPlugin instead of InstallPluginV2
      await InstallPlugin.installApk(filePath, 'com.modern_auth_app');
    } catch (e) {
      debugPrint('Installation failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to install update: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Downloading Update'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isDownloading) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 10),
            Text('${(_progress * 100).toStringAsFixed(1)}%'),
          ] else if (_error.isNotEmpty) ...[
            Text('Error: $_error'),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ],
      ),
    );
  }
}
