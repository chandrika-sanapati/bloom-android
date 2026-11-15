import 'package:flutter/material.dart';

import '../data/garden_repository.dart';
import '../data/watering_notifications.dart';
import '../domain/garden_store.dart';
import '../domain/models.dart';
import 'catalog_screen.dart';
import 'check_screen.dart';
import 'plant_detail_screen.dart';
import 'preferences_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.flags,
    required this.notifications,
  });

  final GardenStore store;
  final FirstRunFlags flags;
  final WateringNotifications notifications;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _Tab { upcoming, past }

class _HomeScreenState extends State<HomeScreen> {
  _Tab _tab = _Tab.upcoming;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onChanged);
    _loadHint();
  }

  @override
  void dispose() {
    widget.store.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _selectTab(_Tab tab) => setState(() => _tab = tab);

  Future<void> _loadHint() async {
    final seen = await widget.flags.hasSeenAddPlantHint();
    if (!mounted) return;
    setState(() => _showHint = !seen && widget.store.garden.plants.isEmpty);
  }

  Future<void> _openCatalog() async {
    await widget.flags.markAddPlantHintSeen();
    if (!mounted) return;
    setState(() => _showHint = false);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CatalogScreen(store: widget.store)),
    );
  }

  void _openPreferences() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreferencesScreen(
          store: widget.store,
          notifications: widget.notifications,
        ),
      ),
    );
  }

  void _openPlant(Plant plant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlantDetailScreen(store: widget.store, plantId: plant.id),
      ),
    );
  }

  void _openCheck(Plant plant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CheckScreen(store: widget.store, plantId: plant.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final garden = widget.store.garden;
    final isEmpty = garden.plants.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const BloomTitle(),
        actions: [
          IconButton(
            tooltip: 'Preferences',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openPreferences,
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isEmpty && _showHint)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Chip(label: Text('Tap to add a plant')),
            ),
          FloatingActionButton(
            tooltip: 'Add plant',
            onPressed: _openCatalog,
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: isEmpty ? const _EmptyHome() : _PopulatedHome(this),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/images/area-whole.png',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add your first plant', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Tap + to choose a supported plant and start its watering check-ins.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PopulatedHome extends StatelessWidget {
  const _PopulatedHome(this.state);

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    final store = state.widget.store;
    final theme = Theme.of(context);
    final plants = store.garden.plants;

    final scheduled = <(Plant, WateringSchedule)>[];
    for (final plant in plants) {
      final schedule = store.scheduleFor(plant.id);
      if (schedule != null) scheduled.add((plant, schedule));
    }
    scheduled.sort((a, b) => a.$2.nextCheckAt.compareTo(b.$2.nextCheckAt));

    final past = [...store.garden.records]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        Text('My plants', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 224,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: plants.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final plant = plants[index];
              return PlantCard(
                plant: plant,
                schedule: store.scheduleFor(plant.id),
                onTap: () => state._openPlant(plant),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text('Activity', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SegmentedButton<_Tab>(
          segments: const [
            ButtonSegment(value: _Tab.upcoming, label: Text('Upcoming')),
            ButtonSegment(value: _Tab.past, label: Text('Past')),
          ],
          selected: {state._tab},
          onSelectionChanged: (selection) => state._selectTab(selection.first),
        ),
        const SizedBox(height: 16),
        if (state._tab == _Tab.upcoming)
          ..._upcoming(context, scheduled)
        else
          ..._pastRows(context, past.take(5).toList()),
      ],
    );
  }

  List<Widget> _upcoming(BuildContext context, List<(Plant, WateringSchedule)> scheduled) {
    if (scheduled.isEmpty) {
      return const [
        EmptyActivityCard(
          title: 'Nothing scheduled',
          detail: 'Add a supported plant to start watering check-ins.',
        ),
      ];
    }
    final widgets = <Widget>[];
    for (final timing in CareTaskTiming.values) {
      final items = scheduled
          .where((item) => CareTaskTiming.classify(item.$2.nextCheckAt) == timing)
          .toList();
      if (items.isEmpty) continue;
      if (timing != CareTaskTiming.upcoming) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(timing.label, style: Theme.of(context).textTheme.titleSmall),
        ));
      }
      for (final item in items) {
        widgets.add(TaskRow(
          plant: item.$1,
          schedule: item.$2,
          timing: timing,
          onTap: () => state._openCheck(item.$1),
        ));
        widgets.add(const SizedBox(height: 8));
      }
    }
    return widgets;
  }

  List<Widget> _pastRows(BuildContext context, List<WateringRecord> records) {
    if (records.isEmpty) {
      return const [
        EmptyActivityCard(
          title: 'No watering history yet',
          detail: 'Your completed checks will appear here.',
        ),
      ];
    }
    final store = state.widget.store;
    final rows = <Widget>[];
    for (final record in records) {
      final plant = store.plant(record.plantId);
      if (plant == null) continue;
      rows.add(HistoryRow(plant: plant, record: record));
      rows.add(const Divider(height: 1));
    }
    return rows;
  }
}
