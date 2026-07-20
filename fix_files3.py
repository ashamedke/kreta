import os
from pathlib import Path

base = Path(r"C:\Users\drnew\Desktop\chesscreator")

def write(p, content):
    (base / p).write_text(content, encoding='utf-8')

def read(p):
    return (base / p).read_text(encoding='utf-8')

# Fix import_screen.dart
import_screen = read('lib/screens/import_screen.dart')
import_screen = import_screen.replace("ChessBoard2D(game: project.game, currentPly: 0)", "ChessBoard2D(fen: project.game.startingFen, size: 200)")
write('lib/screens/import_screen.dart', import_screen)

# Fix chess_service.dart
chess_service = read('lib/services/chess_service.dart')
chess_service = chess_service.replace("pgnTags: {}", "pgnTags: <String, String>{}")
write('lib/services/chess_service.dart', chess_service)

# Fix project_service.dart
project_service = read('lib/services/project_service.dart')
project_service = project_service.replace("Project(id: id, name: name, game: game,", "Project(id: id, name: name, game: game, gameId: game.id, timingRules: TimingRules(globalDefaultHoldMs: 2000, globalDefaultTransitionMs: 500, rules: []),")
write('lib/services/project_service.dart', project_service)

# Fix render_service.dart
render_service = read('lib/services/render_service.dart')
render_service = render_service.replace("job.RenderJob(", "RenderJob(")
write('lib/services/render_service.dart', render_service)

# Fix timing_resolver.dart
timing_resolver = read('lib/services/timing_resolver.dart')
import re
timing_resolver = re.sub(r'final override\s*=\s*rules\.plyOverrides\[ply\.index\];.*?if\s*\(override\s*!=\s*null\)\s*\{.*?\}\s*else\s*\{.*?\}', 
    r'''int hold = rules.globalDefaultHoldMs;
      int trans = rules.globalDefaultTransitionMs;
      for (final rule in rules.rules) {
        if (!rule.enabled) continue;
        bool applies = false;
        switch (rule.predicate) {
          case TimingRulePredicate.isCapture: applies = ply.moveSan.contains('x'); break;
          case TimingRulePredicate.isCheck: applies = ply.moveSan.contains('+'); break;
          case TimingRulePredicate.isCheckmate: applies = ply.moveSan.contains('#'); break;
          case TimingRulePredicate.isCastle: applies = ply.moveSan.contains('O-O'); break;
          case TimingRulePredicate.isPromotion: applies = ply.moveSan.contains('='); break;
          case TimingRulePredicate.plyIndexRange: applies = false; break;
          case TimingRulePredicate.everyNthPly: applies = false; break;
          case TimingRulePredicate.isFlagged: applies = ply.isFlagged; break;
          case TimingRulePredicate.isOpeningMoves: applies = ply.index < 20; break;
          case TimingRulePredicate.always: applies = true; break;
        }
        if (applies) {
           hold = rule.holdDurationMs;
           trans = rule.transitionDurationMs;
        }
      }''', timing_resolver, flags=re.DOTALL)
write('lib/services/timing_resolver.dart', timing_resolver)

# Fix render_progress.dart
rp = read('lib/widgets/render_progress.dart')
rp = re.sub(r'RenderProgressDialog\(\{.*?\)\s*:', 'RenderProgressDialog({required this.renderJob, required this.onCancel, Key? key}) :', rp)
write('lib/widgets/render_progress.dart', rp)

# Fix timeline_editor.dart
te = read('lib/widgets/timeline_editor.dart')
te = te.replace("t.totalDurationMs", "(t.holdDurationMs + t.transitionDurationMs)")
write('lib/widgets/timeline_editor.dart', te)

# Fix timing_panel.dart
tp = read('lib/widgets/timing_panel.dart')
tp = tp.replace("TimingRule(predicate:", "TimingRule(id: '1', predicate:")
write('lib/widgets/timing_panel.dart', tp)
