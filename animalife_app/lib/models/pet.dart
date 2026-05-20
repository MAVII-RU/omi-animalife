class Pet {
  final int id;
  final String name;
  final String species;
  final String? breedName;
  final String? photoUrl;

  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breedName,
    this.photoUrl,
  });

  factory Pet.fromJson(Map<String, dynamic> j) => Pet(
        id: j['id'] as int,
        name: j['name'] as String? ?? 'Pet',
        species: j['species'] as String? ?? 'cat',
        breedName: j['breed_name'] as String?,
        photoUrl: j['photo_url'] as String?,
      );

  String get emoji => species == 'dog' ? '🐶' : '🐱';
}
