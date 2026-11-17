import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../domain/garden_store.dart';
import '../domain/models.dart';
import '../domain/soil_care.dart';
import 'discard_changes_guard.dart';
import 'widgets.dart';

class SoilCareScreen extends StatefulWidget {
  const SoilCareScreen({
    super.key,
    required this.store,
    required this.plantId,
    this.event,
  });
  final GardenStore store;
  final String plantId;
  final SoilCareEvent? event;
  @override
  State<SoilCareScreen> createState() => _SoilCareScreenState();
}

class _SoilCareScreenState extends State<SoilCareScreen> {
  late final Set<SoilCareAction> _initialActions = {...?widget.event?.actions};
  late final Set<SoilCareAction> _actions = {..._initialActions};
  late final DateTime _initialDate =
      widget.event?.occurredOn ?? DateUtils.dateOnly(DateTime.now());
  late DateTime _date = _initialDate;
  late final _product = TextEditingController(
    text: widget.event?.product ?? '',
  );
  late final _notes = TextEditingController(text: widget.event?.notes ?? '');
  late bool? _mixFeed = widget.event?.mixContainsFeed;
  bool _saving = false;
  bool _saved = false;
  String? _error;
  bool get _dirty =>
      !setEquals(_actions, _initialActions) ||
      _date != _initialDate ||
      _product.text != (widget.event?.product ?? '') ||
      _notes.text != (widget.event?.notes ?? '') ||
      _mixFeed != widget.event?.mixContainsFeed;
  @override
  void dispose() {
    _product.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    setState(() {
      _saved = true;
      _saving = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _save() async {
    if (_actions.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final now = DateTime.now();
    final saved = await widget.store.saveSoilCare(
      SoilCareEvent(
        id: widget.event?.id ?? newId(),
        plantId: widget.plantId,
        occurredOn: _date,
        recordedAt: widget.event?.recordedAt ?? now,
        actions: _actions,
        product: text(_product),
        notes: text(_notes),
        mixContainsFeed: _mixFeed,
      ),
      updating: widget.event != null,
    );
    if (!mounted) return;
    if (saved) {
      await _leave();
    } else {
      setState(() {
        _saving = false;
        _error = "Your soil care couldn't be saved. Try again.";
      });
    }
  }

  Future<void> _remove() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this care record?'),
        content: const Text(
          'This removes the recorded soil care, without changing watering.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove record'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _saving = true);
    final removed = await widget.store.removeSoilCare(
      widget.plantId,
      widget.event!.id,
    );
    if (!mounted) return;
    if (removed) {
      await _leave();
    } else {
      setState(() {
        _saving = false;
        _error = "The record couldn't be removed. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      if (widget.store.plant(widget.plantId) == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Plant unavailable')),
          body: const Center(
            child: Text('This plant is no longer in your garden.'),
          ),
        );
      }
      return DiscardChangesGuard(
        hasChanges: !_saved && _dirty,
        saving: _saving,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.event == null ? 'Record soil care' : 'Edit soil care',
            ),
          ),
          bottomNavigationBar: BottomAction(
            child: FilledButton(
              onPressed: _actions.isEmpty || _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SectionHeader('What did you do?'),
              Text(
                'Select everything you did.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final action in SoilCareAction.values)
                      CheckboxListTile(
                        title: Text(action.label),
                        value: _actions.contains(action),
                        onChanged: _saving
                            ? null
                            : (value) => setState(() {
                                if (value == true) {
                                  _actions.add(action);
                                } else {
                                  _actions.remove(action);
                                }
                              }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader('When'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Care date'),
                  subtitle: Text(formatDate(_date)),
                  onTap: _saving
                      ? null
                      : () async {
                          final chosen = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (chosen != null && mounted) {
                            setState(() => _date = chosen);
                          }
                        },
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader('Details'),
              const SizedBox(height: 4),
              if (_actions.contains(SoilCareAction.nutrientsAdded)) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _product,
                  enabled: !_saving,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Fertilizer or amendment (optional)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (_actions.contains(SoilCareAction.mixRefreshed)) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<bool?>(
                  hint: const Text('Not sure'),
                  initialValue: _mixFeed,
                  decoration: const InputDecoration(
                    labelText: 'Fresh mix contains fertilizer?',
                  ),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('Yes')),
                    DropdownMenuItem(value: false, child: Text('No')),
                    DropdownMenuItem(value: null, child: Text('Not sure')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _mixFeed = value),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _notes,
                enabled: !_saving,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                MessageBanner(_error!),
              ],
              if (widget.event != null) ...[
                const SizedBox(height: 20),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _saving ? null : _remove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove record'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
