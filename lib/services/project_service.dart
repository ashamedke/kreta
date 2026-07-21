import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chesscreator/models/project.dart';
import 'package:chesscreator/models/game.dart';

/// Service to manage persistence and state of Projects.
class ProjectService extends ChangeNotifier {
  List<Project> _projects = [];
  
  List<Project> get projects => _projects;

  /// Gets the directory where projects are stored.
  Future<String> get _projectsDir async {
    final directory = await getApplicationSupportDirectory();
    final path = '${directory.path}/chesscreator_projects';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  /// Loads all projects from disk.
  Future<void> loadProjects() async {
    final dirPath = await _projectsDir;
    final dir = Directory(dirPath);
    final List<Project> loadedProjects = [];

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final jsonMap = jsonDecode(content) as Map<String, dynamic>;
          
          // MIGRATION: Convert old 'layers' to 'tracks' and 'Ply' annotations to 'AnnotationTrack'
          final gameJson = jsonMap['game'] as Map<String, dynamic>?;
          List<Map<String, dynamic>> migratingArrows = [];
          List<Map<String, dynamic>> migratingTexts = [];
          
          if (gameJson != null) {
            final plies = gameJson['plies'] as List<dynamic>?;
            if (plies != null) {
               for (var plyJson in plies) {
                  final arrows = plyJson['arrows'] as List<dynamic>?;
                  if (arrows != null && arrows.isNotEmpty) {
                    for (var arrow in arrows) {
                      arrow['sourcePlyIndex'] = plyJson['index'];
                      migratingArrows.add(arrow);
                    }
                  }
                  final texts = plyJson['floatingTexts'] as List<dynamic>?;
                  if (texts != null && texts.isNotEmpty) {
                    for (var text in texts) {
                      text['sourcePlyIndex'] = plyJson['index'];
                      migratingTexts.add(text);
                    }
                  }
                  plyJson.remove('arrows');
                  plyJson.remove('floatingTexts');
               }
            }
          }
          
          final timelineJson = jsonMap['timeline'] as Map<String, dynamic>?;
          if (timelineJson != null) {
            List<dynamic> tracks = timelineJson['tracks'] ?? [];
            final layers = timelineJson['layers'] as List<dynamic>?;
            if (layers != null) {
               final overlayTrack = {
                 'id': 'migrated-overlay-track',
                 'name': 'Overlays',
                 'type': 'overlay',
                 'items': layers.map((l) {
                   l['type'] = 'overlay';
                   return l;
                 }).toList(),
               };
               tracks.add(overlayTrack);
               timelineJson.remove('layers');
            }
            
            if (migratingArrows.isNotEmpty || migratingTexts.isNotEmpty) {
               Map<String, dynamic>? annotationTrack;
               try {
                 annotationTrack = tracks.firstWhere((t) => t['type'] == 'annotation');
               } catch (_) {
                 annotationTrack = {
                   'id': 'migrated-annotation-track',
                   'name': 'Annotations',
                   'type': 'annotation',
                   'items': []
                 };
                 tracks.add(annotationTrack);
               }
               
               List<dynamic> items = annotationTrack!['items'];
               for (var a in migratingArrows) {
                 items.add({
                   'type': 'arrow',
                   'id': 'migrated-arrow-${a['sourcePlyIndex']}',
                   'startTimeMs': 0, // Sync will fix this
                   'sourcePlyIndex': a['sourcePlyIndex'],
                   'fromSquare': a['fromSquare'],
                   'toSquare': a['toSquare'],
                   'color': a['color'],
                   'text': a['text'],
                 });
               }
               for (var t in migratingTexts) {
                 items.add({
                   'type': 'floatingText',
                   'id': 'migrated-text-${t['sourcePlyIndex']}',
                   'startTimeMs': 0,
                   'sourcePlyIndex': t['sourcePlyIndex'],
                   'text': t['text'],
                   'x': t['x'],
                   'y': t['y'],
                   'color': t['color'],
                   'fontSize': t['fontSize'],
                 });
               }
            }
            timelineJson['tracks'] = tracks;
          }

          loadedProjects.add(Project.fromJson(jsonMap));
        } catch (e) {
          debugPrint('Error parsing project file ${entity.path}: $e');
        }
      }
    }

    _projects = loadedProjects;
    notifyListeners();
  }

  /// Saves a project to disk.
  Future<void> saveProject(Project project) async {
    final dirPath = await _projectsDir;
    final file = File('$dirPath/${project.id}.json');
    final jsonStr = jsonEncode(project.toJson());
    await file.writeAsString(jsonStr);
    
    // Update memory representation
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index >= 0) {
      _projects[index] = project;
    } else {
      _projects.add(project);
    }
    notifyListeners();
  }

  /// Creates a new project with default settings, saves it, and adds it to the list.
  Future<Project> createProject(String name, Game game) async {
    final project = Project.create(name, game);

    await saveProject(project);
    return project;
  }

  /// Deletes a project by ID.
  Future<void> deleteProject(String projectId) async {
    final dirPath = await _projectsDir;
    final file = File('$dirPath/$projectId.json');
    
    if (await file.exists()) {
      await file.delete();
    }

    _projects.removeWhere((p) => p.id == projectId);
    notifyListeners();
  }
}
