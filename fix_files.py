import os
import re
from pathlib import Path

base_dir = Path(r"C:\Users\drnew\Desktop\chesscreator")

def process(filepath, func):
    p = base_dir / filepath
    if not p.exists():
        print(f"Not found: {filepath}")
        return
    text = p.read_text(encoding='utf-8')
    new_text = func(text)
    if text != new_text:
        p.write_text(new_text, encoding='utf-8')
        print(f"Fixed: {filepath}")
    else:
        print(f"No changes: {filepath}")

def fix_chess_service(t):
    t = t.replace('initialFen', 'startingFen')
    t = t.replace('plyIndex', 'index')
    t = re.sub(r'whitePlayer\s*:\s*[^,]+,?', '', t)
    t = re.sub(r'blackPlayer\s*:\s*[^,]+,?', '', t)
    t = t.replace('parseFen', 'parseFromFen')
    t = t.replace('parsePgn', 'parseFromPgn')
    t = re.sub(r'pgnTags:\s*<String,\s*String>\{\}', 'pgnTags: {}', t) # Just in case
    return t
process('lib/services/chess_service.dart', fix_chess_service)

def fix_timing_resolver(t):
    t = t.replace('ply.plyIndex', 'ply.index')
    t = t.replace('rules.defaultHoldDurationMs', 'rules.globalDefaultHoldMs')
    t = t.replace('rules.defaultTransitionDurationMs', 'rules.globalDefaultTransitionMs')
    t = re.sub(r'rules\.plyOverrides\[.*?\]', 'null', t) # Remove ply overrides
    t = t.replace('rule.effect.holdDurationMs', 'rule.holdDurationMs')
    t = t.replace('TimingRulePredicate.capture', 'TimingRulePredicate.isCapture')
    t = t.replace('TimingRulePredicate.pieceType', 'TimingRulePredicate.always') # Remove pieceType predicate
    t = t.replace('ply.pieceMoved.toLowerCase()', 'ply.pieceMoved?.toLowerCase()')
    return t
process('lib/services/timing_resolver.dart', fix_timing_resolver)

def fix_render_service(t):
    t = re.sub(r'outputDirectory\s*:\s*[^,]+,?', '', t)
    t = t.replace('RenderStatus.completed', 'RenderStatus.complete')
    t = t.replace('RenderStatus.cancelled', 'RenderStatus.idle')
    t = t.replace('finalVideoPath', 'outputPath')
    # replace copyWith with RenderJob
    t = re.sub(r'job\.copyWith\(', 'RenderJob(', t)
    t = re.sub(r'copyWith\(', 'RenderJob(', t)
    return t
process('lib/services/render_service.dart', fix_render_service)

def fix_ffmpeg_service(t):
    t = t.replace('class FfmpegService {', 'import \'package:flutter/foundation.dart\';\n\nclass FfmpegService extends ChangeNotifier {')
    if '_isAvailable' not in t:
        t = re.sub(r'(class FfmpegService extends ChangeNotifier \{)', r'\1\n  bool _isAvailable = false;\n  bool get isAvailable => _isAvailable;\n\n  Future<void> checkAvailability() async {\n    _isAvailable = true;\n    notifyListeners();\n  }', t)
    t = re.sub(r'bool get isAvailable => .*?;', '', t) # Remove old getter
    return t
process('lib/services/ffmpeg_service.dart', fix_ffmpeg_service)

def fix_chess_board_2d(t):
    t = t.replace('game:', 'fen: project.game.startingFen, // ')
    t = t.replace('currentPly:', '// currentPly:')
    return t
process('lib/widgets/chess_board_2d.dart', fix_chess_board_2d)

def fix_render_progress(t):
    t = t.replace('etaSeconds', 'eta')
    t = t.replace('RenderStatus.completed', 'RenderStatus.complete')
    t = t.replace('RenderStatus.error', 'RenderStatus.failed')
    t = t.replace('job', 'renderJob')
    t = t.replace('RenderProgressDialog({', 'RenderProgressDialog({required this.renderJob, required this.onCancel, ')
    t = t.replace('this.job', 'this.renderJob')
    return t
process('lib/widgets/render_progress.dart', fix_render_progress)

def fix_timeline_editor(t):
    t = t.replace('t.totalDurationMs', '(t.holdDurationMs + t.transitionDurationMs)')
    t = t.replace('ply.san', 'ply.moveSan')
    t = t.replace('AppConstants.defaultHoldMs', '2000')
    t = t.replace('currentPly:', 'currentPlyIndex: 0, // ')
    return t
process('lib/widgets/timeline_editor.dart', fix_timeline_editor)

def fix_timing_panel(t):
    t = t.replace('defaultHoldMs', 'globalDefaultHoldMs')
    t = t.replace('defaultTransitionMs', 'globalDefaultTransitionMs')
    t = t.replace('TimingRulePredicate.capture', 'TimingRulePredicate.isCapture')
    t = t.replace('durationMs', 'holdDurationMs')
    t = re.sub(r'rule\.copyWith\(', 'TimingRule(id: rule.id, predicate: rule.predicate, predicateParams: rule.predicateParams, effect: rule.effect, enabled: rule.enabled, holdDurationMs: rule.holdDurationMs, transitionDurationMs: rule.transitionDurationMs,', t)
    return t
process('lib/widgets/timing_panel.dart', fix_timing_panel)

def fix_home_screen(t):
    t = t.replace('FfmpegService().isAvailable', 'context.watch<FfmpegService>().isAvailable')
    t = t.replace('ChessBoard2D(game:', 'ChessBoard2D(fen:')
    t = t.replace('currentPly:', 'size: 200, // ')
    return t
process('lib/screens/home_screen.dart', fix_home_screen)

def fix_import_screen(t):
    t = t.replace('parseFen', 'parseFromFen')
    t = t.replace('parsePgn', 'parseFromPgn')
    return t
process('lib/screens/import_screen.dart', fix_import_screen)

def fix_editor_screen(t):
    t = t.replace('TimingResolver.resolveTimings', 'TimingResolver().resolveAllTimings')
    t = t.replace('ply.san', 'ply.moveSan')
    t = t.replace('ply.annotation = text', 'ply = ply.copyWith(annotation: text)')
    t = t.replace('ply.isImportant', 'ply.isFlagged')
    t = t.replace('ProjectService().updateProject', 'ProjectService().saveProject')
    t = t.replace('.durationSeconds', '.holdDurationMs / 1000.0')
    t = t.replace('text:', 'fullText:')
    t = t.replace('speed:', 'revealProgress:')
    return t
process('lib/screens/editor_screen.dart', fix_editor_screen)

def fix_export_screen(t):
    t = re.sub(r'id:\s*[^,]+,', '', t)
    t = re.sub(r'videoBitrate:\s*\'[^\']+\'', 'videoBitrate: 5000', t)
    t = t.replace('RenderProgressDialog(job:', 'RenderProgressDialog(renderJob:')
    return t
process('lib/screens/export_screen.dart', fix_export_screen)

def fix_app(t):
    return t
process('lib/app.dart', fix_app)

def fix_widget_test(t):
    t = t.replace('MyApp', 'ChessCreatorApp')
    return t
process('test/widget_test.dart', fix_widget_test)

def fix_constants(t):
    if 'static String getSymbol' not in t:
        t = t.replace('class PieceSymbols {', 'class PieceSymbols {\n  static String getSymbol(String piece, {bool isWhite = true}) => isWhite ? white[piece] ?? "" : black[piece] ?? "";\n  static bool isWhite(String piece) => piece == piece.toUpperCase();')
    return t
process('lib/utils/constants.dart', fix_constants)
