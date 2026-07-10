class GaitEvent {
  final int eventId;
  final int frame;
  final double timestamp;
  final String side;
  final String eventType;

  const GaitEvent({
    required this.eventId,
    required this.frame,
    required this.timestamp,
    required this.side,
    required this.eventType,
  });

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'frame': frame,
        'timestamp': timestamp,
        'side': side,
        'event_type': eventType,
      };

  factory GaitEvent.fromJson(Map<String, dynamic> json) => GaitEvent(
        eventId: json['event_id'] as int,
        frame: json['frame'] as int,
        timestamp: (json['timestamp'] as num).toDouble(),
        side: json['side'] as String,
        eventType: json['event_type'] as String,
      );
}
