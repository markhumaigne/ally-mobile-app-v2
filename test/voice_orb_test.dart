import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ally_mobile_app/models/voice_state.dart';
import 'package:ally_mobile_app/widgets/voice/voice_orb.dart';

void main() {
  testWidgets(
    'all presentation states render with reduced motion and semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final state in VoiceState.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(body: VoiceOrb(state: state)),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          find.bySemanticsLabel('Voice orb: ${state.label}'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );
}
