import 'dart:io';

import 'package:flutter/material.dart';

import '../data/growth_photo_files.dart';
import '../domain/garden_store.dart';
import '../domain/models.dart';
import 'light_placement_section.dart';
import 'widgets.dart';
import 'discard_changes_guard.dart';

/// Plants shown before the user types. Curated, not usage-based.
const _popularIds = [
  'pothos',
  'snake_plant',
  'monstera',
  'spider_plant',
  'rubber_plant',
];

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.store});

  final GardenStore store;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  static String _norm(String v) => v.toLowerCase().trim();

  /// Name matches first (prefix, then contains), then scientific and aliases.
  List<PlantSpecies> _search(String raw) {
    final q = _norm(raw);
    final scored = <(int, PlantSpecies)>[];
    for (final species in PlantSpecies.catalog) {
      final name = _norm(species.name);
      final int? score = name.startsWith(q)
          ? 0
          : name.split(' ').any((w) => w.startsWith(q))
          ? 1
          : name.contains(q)
          ? 2
          : _norm(species.scientific).contains(q)
          ? 3
          : species.aliases.any((a) => _norm(a).contains(q))
          ? 4
          : null;
      if (score != null) scored.add((score, species));
    }
    scored.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.name.compareTo(b.$2.name);
    });
    return [for (final (_, s) in scored) s];
  }

  void _open(PlantSpecies species) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PlantSetupScreen(store: widget.store, species: species),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.text.trim();
    final popular = [
      for (final id in _popularIds)
        for (final s in PlantSpecies.catalog)
          if (s.id == id) s,
    ];
    final results = query.isEmpty ? popular : _search(query);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a plant'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SearchBar(
            controller: _query,
            hintText: 'Search plants, e.g. fern',
            leading: const Icon(Icons.search),
            trailing: [
              if (query.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(_query.clear),
                ),
            ],
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 20),
          Text(
            query.isEmpty
                ? 'Popular plants'
                : results.isEmpty
                ? 'No matches'
                : results.length == 1
                ? '1 result'
                : '${results.length} results',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (query.isNotEmpty && results.isEmpty)
            Text(
              "Bloom doesn't have \"$query\" yet. Try another name, or "
              'identify it from a photo.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          for (final species in results)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  species.asset,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(species.name),
              subtitle: Text(
                species.scientific,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(species),
            ),
        ],
      ),
    );
  }
}

class PlantSetupScreen extends StatefulWidget {
  const PlantSetupScreen({
    super.key,
    required this.store,
    required this.species,
    this.photoPath,
  });

  final GardenStore store;
  final PlantSpecies species;

  /// The user's own photo (from identification), used as the plant image.
  final String? photoPath;

  @override
  State<PlantSetupScreen> createState() => _PlantSetupScreenState();
}

class _PlantSetupScreenState extends State<PlantSetupScreen> {
  bool _knowsLastWatered = false;
  bool _lightPlaced = false;
  bool _saving = false;
  bool _saved = false;
  DateTime _lastWatered = DateTime.now();

  Future<void> _add() async {
    if (_saving) return;
    setState(() => _saving = true);
    final plant = Plant(
      id: newId(),
      name: widget.species.name,
      species: widget.species.scientific,
      asset: widget.species.asset,
      lightPlacement: _lightPlaced
          ? LightPlacementAcknowledgment(
              acknowledgedAt: DateTime.now(),
              guidanceVersion: widget.species.light.version,
            )
          : null,
    );
    final saved = await widget.store.addPlant(
      plant,
      lastWatered: _knowsLastWatered ? _lastWatered : null,
    );
    if (!mounted) return;
    if (!saved) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't add the plant. Try again.")),
      );
      return;
    }
    if (widget.photoPath case final path?) {
      try {
        await GrowthPhotoFiles.adopt(
          widget.store,
          plant.id,
          path,
          asCover: true,
        );
      } catch (_) {
        // The plant is saved; it falls back to the catalog image.
      }
      if (!mounted) return;
    }
    setState(() {
      _saved = true;
      _saving = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    // Close setup and the catalog so the user lands back on Home.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DiscardChangesGuard(
      hasChanges: !_saved && (_knowsLastWatered || _lightPlaced),
      saving: _saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add a plant'),
          leading: const BackButton(),
        ),
        bottomNavigationBar: BottomAction(
          child: FilledButton(
            onPressed: _saving ? null : _add,
            child: Text(_saving ? 'Adding…' : 'Add plant'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: widget.photoPath == null
                  ? Image.asset(
                      widget.species.asset,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(widget.photoPath!),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(height: 16),
            Text(widget.species.name, style: theme.textTheme.headlineSmall),
            Text(
              widget.species.scientific,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader('Last watered · optional'),
            const SizedBox(height: 4),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('I know when I last watered it'),
                    value: _knowsLastWatered,
                    onChanged: (value) =>
                        setState(() => _knowsLastWatered = value),
                  ),
                  if (_knowsLastWatered)
                    ListTile(
                      title: const Text('Date'),
                      trailing: Text(formatDate(_lastWatered)),
                      onTap: _pickLastWatered,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            LightPlacementSection(
              guidance: widget.species.light,
              acknowledged: _lightPlaced,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _lightPlaced = value),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLastWatered() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastWatered,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _lastWatered = picked);
  }
}
