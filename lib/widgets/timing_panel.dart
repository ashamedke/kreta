import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../models/timing.dart';

class TimingPanel extends StatefulWidget {
  final TimingRules timingRules;
  final ValueChanged<TimingRules> onChanged;
  final int totalDurationMs;

  const TimingPanel({
    super.key,
    required this.timingRules,
    required this.onChanged,
    required this.totalDurationMs,
  });

  @override
  State<TimingPanel> createState() => _TimingPanelState();
}

class _TimingPanelState extends State<TimingPanel> {
  late TimingRules _currentRules;

  // One controller per rule id, created lazily and reused across rebuilds so
  // typing in the hold-duration field doesn't get a fresh (and therefore
  // unfocused / cursor-reset) controller on every setState.
  final Map<String, TextEditingController> _holdControllers = {};

  @override
  void initState() {
    super.initState();
    _currentRules = widget.timingRules;
  }

  @override
  void dispose() {
    for (final controller in _holdControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _holdControllerFor(TimingRule rule) {
    return _holdControllers.putIfAbsent(
      rule.id,
      () => TextEditingController(text: rule.holdDurationMs.toString()),
    );
  }

  void _updateRules(TimingRules newRules) {
    setState(() {
      _currentRules = newRules;
    });
    widget.onChanged(newRules);
  }

  /// Generates a unique id for a new rule. Uses a microsecond timestamp plus
  /// the current rule count as a tiebreaker so two rules added in the same
  /// microsecond (unlikely, but possible on fast hardware/hot reload) still
  /// don't collide.
  String _generateRuleId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${_currentRules.rules.length}';
  }

  @override
  Widget build(BuildContext context) {
    final minutes = widget.totalDurationMs ~/ 60000;
    final seconds = (widget.totalDurationMs % 60000) ~/ 1000;
    final isOptimalLength = minutes >= 3 && minutes <= 10;
    final durationColor = isOptimalLength ? AppColors.accentGreen : AppColors.accentOrange;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Timing Configuration', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: TextStyle(color: durationColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGlobalDefaults(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Custom Rules', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
              ElevatedButton.icon(
                onPressed: () {
                  final newRules = _currentRules.copyWith(
                    rules: [
                      ..._currentRules.rules,
                      TimingRule(
                        id: _generateRuleId(),
                        predicate: TimingRulePredicate.isCapture,
                        effect: TimingRuleEffect.add,
                        holdDurationMs: 1000,
                      ),
                    ],
                  );
                  _updateRules(newRules);
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Rule'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue, foregroundColor: Colors.white),
              )
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _currentRules.rules.length,
              itemBuilder: (context, index) {
                final rule = _currentRules.rules[index];
                return _buildRuleCard(rule, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalDefaults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Global Defaults', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hold: ${_currentRules.globalDefaultHoldMs}ms', style: const TextStyle(color: AppColors.textPrimary)),
                  Slider(
                    value: _currentRules.globalDefaultHoldMs.toDouble(),
                    min: 500,
                    max: 5000,
                    activeColor: AppColors.accentBlue,
                    onChanged: (val) {
                      _updateRules(_currentRules.copyWith(globalDefaultHoldMs: val.toInt()));
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Transition: ${_currentRules.globalDefaultTransitionMs}ms', style: const TextStyle(color: AppColors.textPrimary)),
                  Slider(
                    value: _currentRules.globalDefaultTransitionMs.toDouble(),
                    min: 100,
                    max: 2000,
                    activeColor: AppColors.accentBlue,
                    onChanged: (val) {
                      _updateRules(_currentRules.copyWith(globalDefaultTransitionMs: val.toInt()));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRuleCard(TimingRule rule, int index) {
    return Card(
      color: AppColors.surfaceLight,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Switch(
              value: rule.enabled,
              activeThumbColor: AppColors.accentBlue,
              onChanged: (val) {
                final newRules = List<TimingRule>.from(_currentRules.rules);
                newRules[index] = TimingRule(id: rule.id, predicate: rule.predicate, predicateParams: rule.predicateParams, effect: rule.effect, enabled: val, holdDurationMs: rule.holdDurationMs, transitionDurationMs: rule.transitionDurationMs,);
                _updateRules(_currentRules.copyWith(rules: newRules));
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<TimingRulePredicate>(
                value: rule.predicate,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary),
                underline: const SizedBox(),
                isExpanded: true,
                onChanged: (val) {
                  if (val != null) {
                    final newRules = List<TimingRule>.from(_currentRules.rules);
                    newRules[index] = TimingRule(id: rule.id, predicate: val, predicateParams: rule.predicateParams, effect: rule.effect, enabled: rule.enabled, holdDurationMs: rule.holdDurationMs, transitionDurationMs: rule.transitionDurationMs,);
                    _updateRules(_currentRules.copyWith(rules: newRules));
                  }
                },
                items: TimingRulePredicate.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<TimingRuleEffect>(
                value: rule.effect,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary),
                underline: const SizedBox(),
                isExpanded: true,
                onChanged: (val) {
                  if (val != null) {
                    final newRules = List<TimingRule>.from(_currentRules.rules);
                    newRules[index] = TimingRule(id: rule.id, predicate: rule.predicate, predicateParams: rule.predicateParams, effect: val, enabled: rule.enabled, holdDurationMs: rule.holdDurationMs, transitionDurationMs: rule.transitionDurationMs,);
                    _updateRules(_currentRules.copyWith(rules: newRules));
                  }
                },
                items: TimingRuleEffect.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextField(
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  isDense: true,
                  suffixText: 'ms',
                  suffixStyle: TextStyle(color: AppColors.textSecondary),
                  border: OutlineInputBorder(),
                ),
                controller: _holdControllerFor(rule),
                keyboardType: TextInputType.number,
                onSubmitted: (val) {
                  final ms = int.tryParse(val) ?? rule.holdDurationMs;
                  final newRules = List<TimingRule>.from(_currentRules.rules);
                  newRules[index] = TimingRule(id: rule.id, predicate: rule.predicate, predicateParams: rule.predicateParams, effect: rule.effect, enabled: rule.enabled, holdDurationMs: ms, transitionDurationMs: rule.transitionDurationMs,);
                  _updateRules(_currentRules.copyWith(rules: newRules));
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.accentRed),
              onPressed: () {
                final newRules = List<TimingRule>.from(_currentRules.rules)..removeAt(index);
                _holdControllers.remove(rule.id)?.dispose();
                _updateRules(_currentRules.copyWith(rules: newRules));
              },
            ),
          ],
        ),
      ),
    );
  }
}
