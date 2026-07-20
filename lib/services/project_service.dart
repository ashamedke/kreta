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
