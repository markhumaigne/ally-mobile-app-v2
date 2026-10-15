import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';
import '../core/validation/uuid_validator.dart';
import '../models/agent_model.dart';
import '../repositories/agent_repository.dart';

enum ActivationState { initial, loading, success, failure }

class AgentProvider extends ChangeNotifier {
  AgentProvider(
    this._repository, {
    this.config = const AppConfig(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final AgentRepository _repository;
  final AppConfig config;
  ActivationState _state = ActivationState.initial;
  AgentSession? _session;
  AppException? _error;
  bool _initialized = false;
  bool _disposed = false;
  int _generation = 0;
  Timer? _expiryTimer;

  ActivationState get state => _state;
  AgentSession? get session => _session;
  AppException? get error => _error;
  bool get initialized => _initialized;
  bool get isLoading => _state == ActivationState.loading;
  bool get hasSession => _session?.isValidAt(_now()) ?? false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    notifyListeners();
  }

  Future<void> activate(String id, {String? userReference}) async {
    if (isLoading || _disposed) return;
    final generation = ++_generation;
    _expiryTimer?.cancel();
    _session = null;
    _error = null;
    if (!UuidValidator.isValid(id)) {
      _state = ActivationState.failure;
      _error = const AppException(
        ErrorKind.invalidRequest,
        'Enter a valid Agent UUID.',
      );
      notifyListeners();
      return;
    }
    _state = ActivationState.loading;
    notifyListeners();
    try {
      final session = await _repository.activate(
        id,
        userReference: userReference,
      );
      if (_disposed || generation != _generation) return;
      if (!session.isValidAt(_now())) {
        throw AppException.fromStatus(401);
      }
      _session = session;
      _state = ActivationState.success;
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        _expiryTimer = Timer(expiresAt.difference(_now()), checkExpiry);
      }
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _state = ActivationState.failure;
      _error = error is AppException ? error : AppException.unknown;
    }
    if (!_disposed && generation == _generation) notifyListeners();
  }

  void checkExpiry() {
    if (_session != null && !hasSession) {
      invalidate(AppException.fromStatus(401));
    }
  }

  void invalidate(AppException error) {
    reset(notify: false);
    _error = error;
    _state = ActivationState.failure;
    if (!_disposed) notifyListeners();
  }

  void reset({bool notify = true}) {
    ++_generation;
    _expiryTimer?.cancel();
    _session = null;
    _error = null;
    _state = ActivationState.initial;
    if (notify && !_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _expiryTimer?.cancel();
    super.dispose();
  }
}
