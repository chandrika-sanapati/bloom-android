import 'package:flutter/material.dart';
import '../domain/garden_store.dart';
import '../domain/soil_assessment.dart';
import '../domain/soil_care.dart';
import 'discard_changes_guard.dart';
import 'soil_care_screen.dart';
import 'widgets.dart';

class SoilHealthSection extends StatelessWidget {
  const SoilHealthSection({
    super.key,
    required this.store,
    required this.plantId,
  });
  final GardenStore store;
  final String plantId;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      title: const Text('Soil health'),
      subtitle: const Text('Nutrients, potting mix, and root space'),
      shape: const Border(),
      collapsedShape: const Border(),
      children: [
        for (final check in SoilCheck.values)
          ListTile(
            title: Text(SoilAssessment.label(check)),
            subtitle: const Text('Check whether action may help'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SoilAssessmentScreen(
                  store: store,
                  plantId: plantId,
                  check: check,
                ),
              ),
            ),
          ),
        const Divider(indent: 16, endIndent: 16),
        for (final action in SoilCareAction.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${action.label}: ${_last(action)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ListTile(
          leading: const Icon(Icons.add_task),
          title: const Text('Record soil care'),
          subtitle: const Text('Record work you have already done'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SoilCareScreen(store: store, plantId: plantId),
            ),
          ),
        ),
      ],
    ),
  );
  String _last(SoilCareAction action) {
    final events = store
        .soilCareFor(plantId)
        .where((e) => e.actions.contains(action));
    return events.isEmpty
        ? 'Not recorded'
        : formatDate(events.first.occurredOn);
  }
}

class SoilAssessmentScreen extends StatefulWidget {
  const SoilAssessmentScreen({
    super.key,
    required this.store,
    required this.plantId,
    required this.check,
  });
  final GardenStore store;
  final String plantId;
  final SoilCheck check;
  @override
  State<SoilAssessmentScreen> createState() => _SoilAssessmentScreenState();
}

class _SoilAssessmentScreenState extends State<SoilAssessmentScreen> {
  final Map<int, SoilAnswer> _answers = {};
  int _step = 0;
  bool _finished = false;
  String _nutrientHistory() {
    final events = widget.store.soilCareFor(widget.plantId);
    final nutrients = events.where(
      (e) => e.actions.contains(SoilCareAction.nutrientsAdded),
    );
    final mixes = events.where(
      (e) => e.actions.contains(SoilCareAction.mixRefreshed),
    );
    return [
      if (nutrients.isNotEmpty)
        'Last nutrients: ${formatDate(nutrients.first.occurredOn)}${nutrients.first.product == null ? '' : ' · ${nutrients.first.product}'}',
      if (mixes.isNotEmpty)
        'Last fresh mix: ${formatDate(mixes.first.occurredOn)} · Fertilizer in mix: ${mixes.first.mixContainsFeed == null
            ? 'Not sure'
            : mixes.first.mixContainsFeed!
            ? 'Yes'
            : 'No'}',
      'A date alone cannot tell us how long a product supplies nutrients. Follow the product label.',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final questions = SoilAssessment.questions(widget.check);
    final advice = _finished
        ? SoilAssessment.advise(widget.check, [
            for (var i = 0; i < questions.length; i++)
              if (_answers[i] != null) _answers[i]!,
          ])
        : null;
    return DiscardChangesGuard(
      hasChanges: _answers.isNotEmpty && !_finished,
      child: Scaffold(
        appBar: AppBar(title: Text(SoilAssessment.label(widget.check))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.store.plant(widget.plantId)?.name ?? 'Plant',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            if (advice == null) ...[
              Text(
                'Quick check · Step ${_step + 1}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Text(
                questions[_step].text,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(questions[_step].help),
              if (widget.check == SoilCheck.nutrients &&
                  _step == 1 &&
                  widget.store.soilCareFor(widget.plantId).isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_nutrientHistory()),
              ],
              const SizedBox(height: 20),
              Card(
                margin: EdgeInsets.zero,
                child: RadioGroup<SoilAnswer>(
                  groupValue: _answers[_step],
                  onChanged: (value) {
                    if (value != null) setState(() => _answers[_step] = value);
                  },
                  child: Column(
                    children: [
                      for (final answer in SoilAnswer.values)
                        RadioListTile(
                          value: answer,
                          title: Text(switch (answer) {
                            SoilAnswer.yes => 'Yes',
                            SoilAnswer.no => 'No',
                            SoilAnswer.unsure => 'Not sure',
                          }),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _answers[_step] == null
                    ? null
                    : () => setState(() {
                        if (!SoilAssessment.needsMoreAnswers(widget.check, [
                          for (var i = 0; i <= _step; i++)
                            if (_answers[i] != null) _answers[i]!,
                        ])) {
                          _finished = true;
                        } else {
                          _step++;
                        }
                      }),
                child: Text(
                  !SoilAssessment.needsMoreAnswers(widget.check, [
                        for (var i = 0; i <= _step; i++)
                          if (_answers[i] != null) _answers[i]!,
                      ])
                      ? 'See guidance'
                      : 'Next',
                ),
              ),
              if (_step > 0)
                TextButton(
                  onPressed: () => setState(() => _step--),
                  child: const Text('Previous question'),
                ),
            ] else ...[
              Icon(
                advice.actions.isEmpty
                    ? Icons.info_outline
                    : Icons.eco_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                advice.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(advice.reason),
              const SizedBox(height: 24),
              const Text(
                'Record only actions you have actually performed. Reading this guidance does not record care.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SoilCareScreen(
                      store: widget.store,
                      plantId: widget.plantId,
                    ),
                  ),
                ),
                icon: const Icon(Icons.add_task),
                label: const Text('Record soil care'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _step = 0;
                  _finished = false;
                  _answers.clear();
                }),
                child: const Text('Start again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
