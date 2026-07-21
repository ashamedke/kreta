import re

with open('lib/screens/editor_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# First we add scaleController initialization
content = content.replace("final textController = TextEditingController(text: _project!.localModelsPath ?? '');", "final textController = TextEditingController(text: _project!.localModelsPath ?? '');\n      final scaleController = TextEditingController(text: _project!.localModelsScale.toString());")

target_ui = '''              const SizedBox(height: 4),
              const Text('Absolute path to a folder containing board.obj and piece .obj files.', style: TextStyle(color: _textSec, fontSize: 11)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _textSec)),
            ),
            ElevatedButton(
              onPressed: () {
                final newPath = textController.text.trim().isEmpty ? null : textController.text.trim();
                setState(() {
                  _project = _project!.copyWith(localModelsPath: newPath);
                  if (newPath == null) {
                    _project = _project!.clearLocalModelsPath();
                  }
                });
                context.read<ProjectService>().saveProject(_project!);
                Navigator.pop(ctx);
              },'''

replacement_ui = '''              const SizedBox(height: 4),
              const Text('Absolute path to a folder containing board.obj and piece .obj files.', style: TextStyle(color: _textSec, fontSize: 11)),
              const SizedBox(height: 16),
              const Text('Model Scale', style: TextStyle(color: _textSec, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: scaleController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: _textPri),
                decoration: const InputDecoration(
                  hintText: 'e.g. 0.01 or 1.0',
                  hintStyle: TextStyle(color: _textSec),
                  filled: true,
                  fillColor: _surface2,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 4),
              const Text('Scale factor to apply to local models. Useful if they appear giant or tiny.', style: TextStyle(color: _textSec, fontSize: 11)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _textSec)),
            ),
            ElevatedButton(
              onPressed: () {
                final newPath = textController.text.trim().isEmpty ? null : textController.text.trim();
                final newScale = double.tryParse(scaleController.text.trim()) ?? 1.0;
                setState(() {
                  _project = _project!.copyWith(localModelsPath: newPath, localModelsScale: newScale);
                  if (newPath == null) {
                    _project = _project!.clearLocalModelsPath();
                  }
                });
                context.read<ProjectService>().saveProject(_project!);
                Navigator.pop(ctx);
              },'''

if target_ui in content:
    content = content.replace(target_ui, replacement_ui)
    with open('lib/screens/editor_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Patched editor_screen.dart successfully!")
else:
    print("Could not find target block!")

