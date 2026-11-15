import 'package:flutter/material.dart';

import '../domain/garden_store.dart';
import '../domain/models.dart';
import 'light_placement_section.dart';
import 'widgets.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.store});

  final GardenStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a plant'),
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        leadingWidth: 96,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: PlantSpecies.catalog.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final species = PlantSpecies.catalog[index];
          return Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  species.asset,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(species.name),
              subtitle: Text(
                species.scientific,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PlantSetupScreen(store: store, species: species),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PlantSetupScreen extends StatefulWidget {
  const PlantSetupScreen({
    super.key,
    required this.store,
    required this.species,
  });

  final GardenStore store;
  final PlantSpecies species;

  @override
  State<PlantSetupScreen> createState() => _PlantSetupScreenState();
}

class _PlantSetupScreenState extends State<PlantSetupScreen> {
  bool _knowsLastWatered = false;
  bool _lightPlaced = false;
  bool _saving = false;
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
    // Close setup and the catalog so the user lands back on Home.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Add ${widget.species.name}'),
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        leadingWidth: 96,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _saving ? null : _add,
              child: Text(_saving ? 'Adding…' : 'Add'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.species.name, style: theme.textTheme.headlineSmall),
          Text(
            widget.species.scientific,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bloom will suggest when to check the soil. You decide whether the plant needs water.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Last watered', style: theme.textTheme.titleSmall),
              Text(
                'Optional',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('I know the last watered date'),
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
