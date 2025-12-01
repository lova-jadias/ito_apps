// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de synchronisation offline-first
/// Gère la queue de modifications locales et sync avec Supabase
class SyncService {
  static const String _syncQueueBox = 'sync_queue';
  static const String _lastSyncBox = 'last_sync';

  final SupabaseClient _supabase;
  late Box<Map> _queueBox;
  late Box<String> _syncMetaBox;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  SyncService(this._supabase);

  /// Initialiser Hive et les boxes
  Future<void> initialize() async {
    await Hive.initFlutter();
    _queueBox = await Hive.openBox<Map>(_syncQueueBox);
    _syncMetaBox = await Hive.openBox<String>(_lastSyncBox);

    // Écouter les changements de connectivité
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
  }

  /// Ajouter une opération à la queue de sync
  Future<void> addToQueue(SyncOperation operation) async {
    final operationMap = operation.toMap();
    await _queueBox.add(operationMap);
    print('✅ Opération ajoutée à la queue: ${operation.type} sur ${operation.table}');

    // Tenter une sync immédiate si connecté
    unawaited(trySyncNow());
  }

  /// Tenter une synchronisation maintenant (si connecté)
  Future<void> trySyncNow() async {
    if (_isSyncing) return; // Éviter les sync concurrentes

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      print('⚠️ Pas de connexion, sync annulée');
      return;
    }

    await _performSync();
  }

  /// Effectuer la synchronisation
  Future<void> _performSync() async {
    if (_queueBox.isEmpty) return;

    _isSyncing = true;
    print('🔄 Début de synchronisation (${_queueBox.length} opérations)');

    try {
      // Traiter chaque opération dans l'ordre
      final operations = _queueBox.values.toList();
      for (int i = 0; i < operations.length; i++) {
        final opMap = operations[i];
        final operation = SyncOperation.fromMap(opMap);

        try {
          await _executeSyncOperation(operation);
          await _queueBox.deleteAt(i); // Supprimer si succès
          print('✅ Opération ${i + 1}/${operations.length} synchronisée');
        } catch (e) {
          print('❌ Erreur sync opération ${i + 1}: $e');
          // On garde l'opération dans la queue pour réessayer plus tard
        }
      }

      // Mettre à jour la dernière sync
      await _syncMetaBox.put('last_sync', DateTime.now().toIso8601String());
      print('✅ Synchronisation terminée avec succès');

    } catch (e) {
      print('❌ Erreur globale de synchronisation: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Exécuter une opération de sync sur Supabase
  Future<void> _executeSyncOperation(SyncOperation operation) async {
    switch (operation.type) {
      case SyncOperationType.insert:
        await _supabase.from(operation.table).insert(operation.data);
        break;
      case SyncOperationType.update:
        await _supabase
            .from(operation.table)
            .update(operation.data)
            .eq('id', operation.recordId!);
        break;
      case SyncOperationType.delete:
        await _supabase
            .from(operation.table)
            .delete()
            .eq('id', operation.recordId!);
        break;
      case SyncOperationType.rpcCall:
        await _supabase.rpc(
          operation.rpcName!,
          params: operation.data,
        );
        break;
    }
  }

  /// Callback quand la connectivité change
  void _onConnectivityChanged(List<ConnectivityResult> result) {
    if (!result.contains(ConnectivityResult.none)) {
      print('🌐 Connexion rétablie, tentative de sync...');
      unawaited(trySyncNow());
    }
  }

  /// Obtenir le nombre d'opérations en attente
  int get pendingOperationsCount => _queueBox.length;

  /// Nettoyer les ressources
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _queueBox.close();
    await _syncMetaBox.close();
  }
}

/// Types d'opérations de synchronisation
enum SyncOperationType { insert, update, delete, rpcCall }

/// Représente une opération à synchroniser
class SyncOperation {
  final SyncOperationType type;
  final String table;
  final Map<String, dynamic> data;
  final dynamic recordId; // Pour update/delete
  final String? rpcName; // Pour les appels RPC
  final DateTime timestamp;

  SyncOperation({
    required this.type,
    required this.table,
    required this.data,
    this.recordId,
    this.rpcName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'table': table,
      'data': data,
      'recordId': recordId,
      'rpcName': rpcName,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SyncOperation.fromMap(Map<dynamic, dynamic> map) {
    return SyncOperation(
      type: SyncOperationType.values.firstWhere((e) => e.name == map['type']),
      table: map['table'],
      data: Map<String, dynamic>.from(map['data']),
      recordId: map['recordId'],
      rpcName: map['rpcName'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}