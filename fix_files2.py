import os
import re
from pathlib import Path

base_dir = Path(r"C:\Users\drnew\Desktop\chesscreator")

def process(filepath, func):
    p = base_dir / filepath
    if not p.exists():
        return
    text = p.read_text(encoding='utf-8')
    new_text = func(text)
    if text != new_text:
        p.write_text(new_text, encoding='utf-8')

# lib/services/project_service.dart
def fix_project_service(t):
    t = re.sub(r'plyOverrides:\s*\{.*?\},?\s*', '', t, flags=re.DOTALL)
    t = re.sub(r'lastModifiedAt:\s*[^,]+,?\s*', '', t)
    return t
process('lib/services/project_service.dart', fix_project_service)

# lib/services/render_service.dart
def fix_render_service(t):
    t = t.replace('job.RenderJob(', 'RenderJob(')
    return t
process('lib/services/render_service.dart', fix_render_service)

# lib/services/timing_resolver.dart
def fix_timing_resolver(t):
    # Fix the dead null-aware / null check issue
    t = re.sub(r'final override\s*=\s*null;', '', t)
    t = re.sub(r'if\s*\(override\s*!=\s*null\)\s*\{.*?\}', '', t, flags=re.DOTALL)
    t = re.sub(r'int hold\s*=\s*.*?rules\.globalDefaultHoldMs;', 'int hold = rules.globalDefaultHoldMs;', t)
    t = re.sub(r'int trans\s*=\s*.*?rules\.globalDefaultTransitionMs;', 'int trans = rules.globalDefaultTransitionMs;', t)
    t = t.replace('rule.effect.transitionDurationMs', 'rule.transitionDurationMs')
    # Let's just cleanly replace the resolving loop
    return t
process('lib/services/timing_resolver.dart', fix_timing_resolver)

# lib/widgets/render_progress.dart
def fix_render_progress(t):
    t = t.replace("import '../models/render_renderJob.dart';", "import '../models/render_job.dart';")
    # multiple initializers in constructor:
    t = re.sub(r'RenderProgressDialog\(\{\s*required this\.renderJob,\s*required this\.onCancel,\s*Key\? key,\s*required this\.renderJob,\s*required this\.onCancel\s*\}\)', 
               r'RenderProgressDialog({required this.renderJob, required this.onCancel, Key? key})', t)
    return t
process('lib/widgets/render_progress.dart', fix_render_progress)

# lib/widgets/timing_panel.dart
def fix_timing_panel(t):
    def repl(m):
        # We find duplicate params like `enabled: val` at the end
        full = m.group(0)
        # We just want to use the parameter passed as replacement
        var_name = m.group(1)
        var_val = m.group(2)
        # return new string without the duplicated part in the middle, just set it
        return f'TimingRule(id: rule.id, predicate: rule.predicate, predicateParams: rule.predicateParams, effect: rule.effect, enabled: rule.enabled, holdDurationMs: rule.holdDurationMs, transitionDurationMs: rule.transitionDurationMs,'.replace(
            f'{var_name}: rule.{var_name}', f'{var_name}: {var_val}'
        ) + ')'

    t = re.sub(r'TimingRule\(id: rule\.id, predicate: rule\.predicate, predicateParams: rule\.predicateParams, effect: rule\.effect, enabled: rule\.enabled, holdDurationMs: rule\.holdDurationMs, transitionDurationMs: rule\.transitionDurationMs,\s*([a-zA-Z0-9_]+):\s*([^)]+)\)', repl, t)
    return t
process('lib/widgets/timing_panel.dart', fix_timing_panel)

# lib/widgets/timeline_editor.dart
def fix_timeline_editor(t):
    t = t.replace("import '../models/game.dart';", "")
    t = t.replace('t.totalDurationMs', '(t.holdDurationMs + t.transitionDurationMs)')
    return t
process('lib/widgets/timeline_editor.dart', fix_timeline_editor)

# test/widget_test.dart
def fix_widget_test(t):
    t = t.replace("import 'package:chesscreator/main.dart';", "import 'package:chesscreator/app.dart';")
    return t
process('test/widget_test.dart', fix_widget_test)

