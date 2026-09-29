import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';
import 'api_client.dart';

class RealtimeSyncService {
  static final RealtimeSyncService _instance = RealtimeSyncService._internal();
  factory RealtimeSyncService() => _instance;
  RealtimeSyncService._internal();

  io.Socket? _socket;

  final _scansController = StreamController<Map<String, dynamic>?>.broadcast();
  final _rewardsController = StreamController<Map<String, dynamic>?>.broadcast();
  final _loyaltyCardsController = StreamController<Map<String, dynamic>?>.broadcast();
  final _rewardTransfersController = StreamController<Map<String, dynamic>?>.broadcast();
  final _qrCodesController = StreamController<Map<String, dynamic>?>.broadcast();

  Stream<Map<String, dynamic>?> get onScansChanged => _scansController.stream;
  Stream<Map<String, dynamic>?> get onRewardsChanged => _rewardsController.stream;
  Stream<Map<String, dynamic>?> get onLoyaltyCardsChanged => _loyaltyCardsController.stream;
  Stream<Map<String, dynamic>?> get onRewardTransfersChanged => _rewardTransfersController.stream;
  Stream<Map<String, dynamic>?> get onQrCodesChanged => _qrCodesController.stream;

  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized && _socket != null && _socket!.connected) return;

    try {
      final token = ApiClient().token;
      final websocketUrl = ApiConfig.websocketUrl;

      _socket = io.io(
        websocketUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .setExtraHeaders(token != null ? {'Authorization': 'Bearer $token'} : {})
            .setAuth(token != null ? {'token': token} : {})
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('RealtimeSyncService conectado a $websocketUrl');
      });

      _socket!.onDisconnect((_) {
        debugPrint('RealtimeSyncService desconectado');
      });

      _socket!.onConnectError((error) {
        debugPrint('Error de conexion RealtimeSyncService: $error');
      });

      _socket!.on('scan:new', (data) {
        debugPrint('Realtime Sync: nuevo escaneo recibido');
        if (data is Map) {
          _scansController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('card:updated', (data) {
        debugPrint('Realtime Sync: tarjeta actualizada');
        if (data is Map) {
          _loyaltyCardsController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('scan:status', (data) {
        debugPrint('Realtime Sync: estado de escaneo actualizado');
        if (data is Map) {
          _scansController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('reward:status', (data) {
        debugPrint('Realtime Sync: estado de premio actualizado');
        if (data is Map) {
          _rewardsController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('reward:transferred', (data) {
        debugPrint('Realtime Sync: transferencia de premio recibida');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          _rewardTransfersController.add(map);
          _rewardsController.add(map);
        }
      });

      _socket!.on('qr:updated', (data) {
        debugPrint('Realtime Sync: codigo QR actualizado');
        if (data is Map) {
          _qrCodesController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.connect();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Fallo al inicializar RealtimeSyncService: $e');
    }
  }

  void joinBusiness(String businessId) {
    if (_socket != null && _socket!.connected && businessId.isNotEmpty) {
      _socket!.emit('join_business', businessId);
    }
  }

  void leaveBusiness(String businessId) {
    if (_socket != null && _socket!.connected && businessId.isNotEmpty) {
      _socket!.emit('leave_business', businessId);
    }
  }

  void reset() {
    try {
      if (_socket != null) {
        _socket!.disconnect();
        _socket!.dispose();
      }
    } catch (e) {
      debugPrint('Error al resetear RealtimeSyncService: $e');
    }
    _socket = null;
    _isInitialized = false;
    debugPrint('RealtimeSyncService reseteado');
  }

  void dispose() {
    reset();
    _scansController.close();
    _rewardsController.close();
    _loyaltyCardsController.close();
    _rewardTransfersController.close();
    _qrCodesController.close();
  }
}
