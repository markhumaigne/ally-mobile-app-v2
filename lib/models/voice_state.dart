enum VoiceState {
  idle('Ready to start'),
  connecting('Connecting'),
  listening('Listening'),
  thinking('Thinking'),
  speaking('Speaking'),
  error('Connection error'),
  disconnected('Disconnected');

  const VoiceState(this.label);
  final String label;
}
