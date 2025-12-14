class Voice {
  final String id;
  final String name;
  final String gender;
  final String language;

  const Voice({
    required this.id,
    required this.name,
    required this.gender,
    this.language = 'en',
  });

  static const List<Voice> availableVoices = [
    Voice(id: 'M1', name: 'Male 1', gender: 'male'),
    Voice(id: 'M2', name: 'Male 2', gender: 'male'),
    Voice(id: 'M3', name: 'Male 3', gender: 'male'),
    Voice(id: 'M4', name: 'Male 4', gender: 'male'),
    Voice(id: 'M5', name: 'Male 5', gender: 'male'),
    Voice(id: 'F1', name: 'Female 1', gender: 'female'),
    Voice(id: 'F2', name: 'Female 2', gender: 'female'),
    Voice(id: 'F3', name: 'Female 3', gender: 'female'),
    Voice(id: 'F4', name: 'Female 4', gender: 'female'),
    Voice(id: 'F5', name: 'Female 5', gender: 'female'),
  ];
}
