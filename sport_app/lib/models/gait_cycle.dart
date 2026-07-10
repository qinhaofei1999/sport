class GaitCycle {
  final int cycleId;
  final int startFrame;
  final int endFrame;
  final double durationSec;
  final double? cadenceSpm;

  const GaitCycle({
    required this.cycleId,
    required this.startFrame,
    required this.endFrame,
    required this.durationSec,
    this.cadenceSpm,
  });

  Map<String, dynamic> toJson() => {
        'cycle_id': cycleId,
        'start_frame': startFrame,
        'end_frame': endFrame,
        'duration_sec': durationSec,
        'cadence_spm': cadenceSpm,
      };

  factory GaitCycle.fromJson(Map<String, dynamic> json) => GaitCycle(
        cycleId: json['cycle_id'] as int,
        startFrame: json['start_frame'] as int,
        endFrame: json['end_frame'] as int,
        durationSec: (json['duration_sec'] as num).toDouble(),
        cadenceSpm: (json['cadence_spm'] as num?)?.toDouble(),
      );
}
