import re
from pathlib import Path

base = Path(r"C:\Users\drnew\Desktop\chesscreator")

def write(p, content):
    (base / p).write_text(content, encoding='utf-8')

def read(p):
    return (base / p).read_text(encoding='utf-8')

# Fix editor_screen.dart
ed = read('lib/screens/editor_screen.dart')
ed = ed.replace("ProjectService().updateProject", "ProjectService().saveProject")
ed = re.sub(r'ChessBoard2D\(\s*game:\s*[^,]+,\s*currentPly:\s*[^)]+\)', 'ChessBoard2D(fen: project.game.startingFen, size: 400)', ed)
ed = ed.replace("ply.san", "ply.moveSan")
ed = ed.replace("ply.isImportant", "ply.isFlagged")
ed = re.sub(r'TimingPanel\(\s*project:\s*[^)]+\)', 'TimingPanel(timingRules: project.timingRules, totalDurationMs: 0, onChanged: (rules) {})', ed)
ed = re.sub(r'TimelineEditor\(\s*currentPly:\s*[^)]+\)', 'TimelineEditor(project: project, resolvedTimings: _resolvedTimings, currentPlyIndex: _currentPlyIndex, onPlySelected: (i) {}, onTimingChanged: (i, t) {})', ed)
ed = ed.replace("ply.annotation = text", "final newPlies = List<Ply>.from(project.game.plies); newPlies[_currentPlyIndex] = ply.copyWith(annotation: text);")
ed = ed.replace("Timeline(", "TimingRules(") # In case Timeline was used instead of TimingRules
write('lib/screens/editor_screen.dart', ed)

# Fix export_screen.dart
ex = read('lib/screens/export_screen.dart')
ex = re.sub(r'RenderPreset\(\s*id:\s*[^,]+,\s*', 'RenderPreset(', ex)
ex = re.sub(r'RenderJob\(\s*id:\s*[^,]+,\s*projectId:\s*[^,]+,\s*preset:\s*[^,]+,\s*outputPath:\s*[^)]+\)', 'RenderJob(id: "1", projectId: project.id, preset: preset, outputPath: outputPath, status: RenderStatus.idle, currentFrame: 0, totalFrames: 100)', ex)
ex = re.sub(r'RenderProgressDialog\(\s*job:\s*([^,]+)(,\s*onCancel:\s*[^)]+)?\)', r'RenderProgressDialog(renderJob: \1, onCancel: () {})', ex)
ex = re.sub(r'RenderService\(\)\.startRender\([^)]+\)', 'RenderService().startRender(project, preset, outputPath)', ex)
write('lib/screens/export_screen.dart', ex)
