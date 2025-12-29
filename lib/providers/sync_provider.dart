import 'package:flutter/material.dart';
import 'package:sumquiz/services/sync_service.dart';

class SyncProvider with ChangeNotifier {
  final SyncService _syncService;
  bool _isSyncing = false;

  SyncProvider(this._syncService);

  bool get isSyncing => _isSyncing;

  Future<void> syncData() async {
    if (_isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    try {
      await _syncService.syncOnLogin();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
