import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/project_service.dart';
import '../services/ffmpeg_service.dart';
import '../models/project.dart';
import '../widgets/chess_board_2d.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectService>().loadProjects();
      context.read<FfmpegService>().checkAvailability();
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectService = context.watch<ProjectService>();
    final ffmpegService = context.watch<FfmpegService>();

    return Scaffold(
      body: Column(
        children: [
          // Hero Area
          Container(
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF58A6FF), Color(0xFF7C3AED)],
                  ).createShader(bounds),
                  child: const Text(
                    'ChessCreator',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Create premium chess videos with ease.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF8B949E), // TextSecondary
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/import'),
                  icon: const Icon(Icons.add),
                  label: const Text('New Project'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Project Grid
          Expanded(
            child: projectService.projects.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dashboard_customize_outlined, size: 64, color: Color(0xFF30363D)),
                        SizedBox(height: 16),
                        Text(
                          'No projects yet. Create one to get started.',
                          style: TextStyle(color: Color(0xFF8B949E)),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(32),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                    ),
                    itemCount: projectService.projects.length,
                    itemBuilder: (context, index) {
                      final project = projectService.projects[index];
                      return _ProjectCard(project: project);
                    },
                  ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(top: BorderSide(color: Color(0xFF30363D))),
            ),
            child: Row(
              children: [
                Icon(
                  ffmpegService.isAvailable ? Icons.check_circle : Icons.error,
                  color: ffmpegService.isAvailable ? const Color(0xFF06D6A0) : const Color(0xFFF85149),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  ffmpegService.isAvailable ? 'FFmpeg ready' : 'FFmpeg not found',
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;

  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onHover: (hovering) {
          // Hover logic placeholder
        },
        onTap: () {
          Navigator.pushNamed(context, '/editor', arguments: project);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ChessBoard2D(fen: project.game.startingFen, size: 200),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFF30363D)),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      project.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${project.game.plies.length ~/ 2} moves',
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: const Color(0xFFF85149),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF161B22),
                                title: const Text('Delete Project?'),
                                content: Text('Are you sure you want to delete ${project.name}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel', style: TextStyle(color: Color(0xFFE6EDF3))),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF85149)),
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true && context.mounted) {
                              context.read<ProjectService>().deleteProject(project.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
