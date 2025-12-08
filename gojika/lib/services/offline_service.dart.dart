import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class OfflineService {
  static const String _notesBox = 'notes_cache';
  static const String _absencesBox = 'absences_cache';
  static const String _publicationsBox = 'publications_cache';
  static const String _emploiBox = 'emploi_cache';
  static const String _syncQueueBox = 'sync_queue';

  late Box<Map> _notesCache;
  late Box<Map> _absencesCache;
  late Box<Map> _publicationsCache;
  late Box<Map> _emploiCache;
  late Box<Map> _syncQueue;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  Future<void> initialize() async {
    await Hive.initFlutter();

    _notesCache = await Hive.openBox<Map>(_notesBox);
    _absencesCache = await Hive.openBox<Map>(_absencesBox);
    _publicationsCache = await Hive.openBox<Map>(_publicationsBox);
    _emploiCache = await Hive.openBox<Map>(_emploiBox);
    _syncQueue = await Hive.openBox<Map>(_syncQueueBox);

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
  }

  // ==================== NOTES ====================
  Future<void> cacheNotes(List<Map<String, dynamic>> notes) async {
    await _notesCache.clear();
    for (var note in notes) {
      await _notesCache.put(note['id'], note);
    }
  }

  List<Map<String, dynamic>> getCachedNotes() {
    return _notesCache.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ==================== ABSENCES ====================
  Future<void> cacheAbsences(List<Map<String, dynamic>> absences) async {
    await _absencesCache.clear();
    for (var absence in absences) {
      await _absencesCache.put(absence['id'], absence);
    }
  }

  List<Map<String, dynamic>> getCachedAbsences() {
    return _absencesCache.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ==================== PUBLICATIONS ====================
  Future<void> cachePublications(List<Map<String, dynamic>> publications) async {
    await _publicationsCache.clear();
    for (var pub in publications) {
      await _publicationsCache.put(pub['id'], pub);
    }
  }

  List<Map<String, dynamic>> getCachedPublications() {
    return _publicationsCache.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ==================== EMPLOI DU TEMPS ====================
  Future<void> cacheEmploi(List<Map<String, dynamic>> emploi) async {
    await _emploiCache.clear();
    for (var cours in emploi) {
      await _emploiCache.put(cours['id'], cours);
    }
  }

  List<Map<String, dynamic>> getCachedEmploi() {
    return _emploiCache.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ==================== FILE DE SYNCHRONISATION ====================
  Future<void> addToSyncQueue(SyncOperation operation) async {
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    await _syncQueue.put(key, operation.toMap());
    print('✅ Opération ajoutée à la queue: ${operation.type} sur ${operation.table}');
  }

  int get pendingSyncCount => _syncQueue.length;

  List<SyncOperation> get pendingOperations {
    return _syncQueue.values
        .map((e) => SyncOperation.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> removeSyncOperation(String key) async {
    await _syncQueue.delete(key);
  }

  // ==================== SYNCHRONISATION ====================
  void _onConnectivityChanged(List<ConnectivityResult> result) {
    if (!result.contains(ConnectivityResult.none) && !_isSyncing) {
      print('🌐 Connexion rétablie, tentative de synchronisation...');
      trySyncNow();
    }
  }

  Future<void> trySyncNow() async {
    if (_isSyncing || _syncQueue.isEmpty) return;

    _isSyncing = true;
    print('🔄 Début de synchronisation (${_syncQueue.length} opérations)');

    try {
      final operations = _syncQueue.toMap();
      for (var entry in operations.entries) {
        final operation = SyncOperation.fromMap(
          Map<String, dynamic>.from(entry.value),
        );

        try {
          await _executeSyncOperation(operation);
          await _syncQueue.delete(entry.key);
          print('✅ Opération synchronisée: ${operation.type}');
        } catch (e) {
          print('❌ Erreur sync opération: $e');
        }
      }

      print('✅ Synchronisation terminée avec succès');
    } catch (e) {
      print('❌ Erreur globale de synchronisation: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _executeSyncOperation(SyncOperation operation) async {
    // Cette fonction sera implémentée avec les appels Supabase
    // Pour l'instant, on simule juste une attente
    await Future.delayed(Duration(milliseconds: 100));
  }

  // ==================== NETTOYAGE ====================
  Future<void> clearAllCaches() async {
    await _notesCache.clear();
    await _absencesCache.clear();
    await _publicationsCache.clear();
    await _emploiCache.clear();
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _notesCache.close();
    await _absencesCache.close();
    await _publicationsCache.close();
    await _emploiCache.close();
    await _syncQueue.close();
  }
}

// Modèle pour les opérations de synchronisation
enum SyncOperationType { insert, update, delete }

class SyncOperation {
  final SyncOperationType type;
  final String table;
  final Map<String, dynamic> data;
  final dynamic recordId;
  final DateTime timestamp;

  SyncOperation({
    required this.type,
    required this.table,
    required this.data,
    this.recordId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'table': table,
      'data': data,
      'recordId': recordId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SyncOperation.fromMap(Map<String, dynamic> map) {
    return SyncOperation(
      type: SyncOperationType.values.firstWhere((e) => e.name == map['type']),
      table: map['table'],
      data: Map<String, dynamic>.from(map['data']),
      recordId: map['recordId'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}