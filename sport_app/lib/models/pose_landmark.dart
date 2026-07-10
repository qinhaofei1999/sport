class PoseLandmark {
  final int id;
  final String name;
  final double x;
  final double y;
  final double z;
  final double visibility;

  const PoseLandmark({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'x': x,
        'y': y,
        'z': z,
        'visibility': visibility,
      };

  factory PoseLandmark.fromJson(Map<String, dynamic> json) => PoseLandmark(
        id: json['id'] as int,
        name: json['name'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        z: (json['z'] as num).toDouble(),
        visibility: (json['visibility'] as num).toDouble(),
      );
}
