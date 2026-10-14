import 'package:flutter/material.dart';
import 'app.dart';
import 'core/config/app_config.dart';
import 'repositories/agent_repository.dart';
import 'repositories/chat_repository.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig();
  final api = ApiService(config: config);
  runApp(
    AllyApp(
      config: config,
      firstFrameReady: WidgetsBinding.instance.waitUntilFirstFrameRasterized,
      agentRepository: ApiAgentRepository(api),
      chatRepository: ApiChatRepository(api),
    ),
  );
}
