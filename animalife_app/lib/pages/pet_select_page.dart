import 'package:flutter/material.dart';
import '../models/pet.dart';
import '../services/animalife_api.dart';
import 'listen_page.dart';

class PetSelectPage extends StatefulWidget {
  const PetSelectPage({super.key});

  @override
  State<PetSelectPage> createState() => _PetSelectPageState();
}

class _PetSelectPageState extends State<PetSelectPage> {
  List<Pet>? _pets;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pets = await AnimalifeApi.fetchPets();
      setState(() { _pets = pets; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  void _select(Pet pet) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ListenPage(pet: pet)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Выберите питомца', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A2E),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: () { setState(() { _pets = null; _error = null; }); _load(); },
          ),
        ],
      ),
      body: _build(),
    );
  }

  Widget _build() {
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () { setState(() { _pets = null; _error = null; }); _load(); }, child: const Text('Повторить')),
        ]),
      );
    }
    if (_pets == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_pets!.isEmpty) {
      return const Center(
        child: Text(
          'Нет питомцев.\nДобавьте питомца в приложении AnimalLife.',
          style: TextStyle(color: Colors.white54, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pets!.length,
      itemBuilder: (_, i) {
        final pet = _pets![i];
        return _PetCard(pet: pet, onTap: () => _select(pet));
      },
    );
  }
}

class _PetCard extends StatelessWidget {
  final Pet pet;
  final VoidCallback onTap;

  const _PetCard({required this.pet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(28)),
            child: pet.photoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.network(pet.photoUrl!, fit: BoxFit.cover),
                  )
                : Center(child: Text(pet.emoji, style: const TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pet.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                pet.breedName ?? pet.species,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Colors.white38),
        ]),
      ),
    );
  }
}
