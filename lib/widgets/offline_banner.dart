// lib/widgets/offline_banner.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_sync_service.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final offlineService = Provider.of<OfflineSyncService>(context);
    
    // Only show the banner when offline
    if (offlineService.isOnline) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: Colors.orange,
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              offlineService.isSyncing 
                  ? 'Offline mode - Syncing data when online...'
                  : 'Offline mode - Changes will sync when connection is restored',
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
