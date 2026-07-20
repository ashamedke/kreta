import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/project_service.dart';
import '../services/chess_service.dart';
import '../models/game.dart';
import '../widgets/chess_board_2d.dart';
import '../services/lichess_client.dart';
import '../services/chesscom_client.dart';
import '../utils/constants.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _projectNameController = TextEditingController();
  final _fenController = TextEditingController();
  final _pgnController = TextEditingController();
  final _lichessIdController = TextEditingController();
  final _chesscomUsernameController = TextEditingController();
  
  Game? _parsedGame;
  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _projectNameController.dispose();
    _fenController.dispose();
    _pgnController.dispose();
    _lichessIdController.dispose();
    _chesscomUsernameController.dispose();
    super.dispose();
  }

  void _parseFEN(String fen) {
    setState(() {
      _errorMessage = null;
      _parsedGame = null;
    });
    try {
      if (fen.trim().isEmpty) return;
      _parsedGame = ChessService().parseFromFen(fen);
    } catch (e) {
      setState(() => _errorMessage = 'Invalid FEN');
    }
  }

  void _parsePGN(String pgn) {
    setState(() {
      _errorMessage = null;
      _parsedGame = null;
    });
    try {
      if (pgn.trim().isEmpty) return;
      _parsedGame = ChessService().parseFromPgn(pgn);
    } catch (e) {
      setState(() => _errorMessage = 'Invalid PGN');
    }
  }

  Future<void> _fetchLichess(String id) async {
    if (id.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _parsedGame = null;
    });
    try {
      final client = LichessClient(ChessService());
      Game game;
      final query = id.trim();
      if (query.length == 8) {
        try {
          game = await client.fetchGameById(query);
        } catch (e) {
          game = await client.fetchLatestGameForUser(query);
        }
      } else {
        game = await client.fetchLatestGameForUser(query);
      }
      if (mounted) setState(() => _parsedGame = game);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchChesscom(String username) async {
    if (username.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _parsedGame = null;
    });
    try {
      final client = ChesscomClient(ChessService());
      final game = await client.fetchLatestGameForUser(username.trim());
      if (mounted) setState(() => _parsedGame = game);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _createProject() async {
    if (_parsedGame == null) return;
    
    setState(() => _isCreating = true);

    final name = _projectNameController.text.trim().isEmpty 
        ? 'Untitled Project' 
        : _projectNameController.text.trim();
        
    final project = await context.read<ProjectService>().createProject(name, _parsedGame!);
    if (mounted) {
      setState(() => _isCreating = false);
      Navigator.pushReplacementNamed(context, '/editor', arguments: project);
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1, void Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(fontFamily: 'monospace'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accentBlue),
        ),
      ),
    );
  }

  Widget _buildFetchButton({required String label, required VoidCallback? onPressed}) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Import Game'),
          backgroundColor: AppColors.surface,
          bottom: const TabBar(
            indicatorColor: AppColors.accentBlue,
            labelColor: AppColors.accentBlue,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(text: 'FEN'),
              Tab(text: 'PGN'),
              Tab(text: 'Lichess'),
              Tab(text: 'Chess.com'),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Inputs
              Expanded(
                flex: 3,
                child: TabBarView(
                  children: [
                    // FEN
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(_fenController, 'FEN String', onChanged: _parseFEN),
                      ],
                    ),
                    // PGN
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(_pgnController, 'PGN Data', maxLines: 15, onChanged: _parsePGN),
                      ],
                    ),
                    // Lichess
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          _lichessIdController,
                          'Lichess Game ID or Username',
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Paste an 8-character game ID for an exact game, or a username for their latest game.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        _buildFetchButton(
                          label: 'Fetch Game',
                          onPressed: () => _fetchLichess(_lichessIdController.text),
                        ),
                      ],
                    ),
                    // Chess.com
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(_chesscomUsernameController, 'Chess.com Username'),
                        const SizedBox(height: 16),
                        _buildFetchButton(
                          label: 'Fetch Latest Game',
                          onPressed: () => _fetchChesscom(_chesscomUsernameController.text),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right: Preview & Create
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        if (_errorMessage != null)
                          Text(_errorMessage!, style: const TextStyle(color: AppColors.accentRed))
                        else if (_parsedGame != null) ...[
                          Expanded(
                            child: ChessBoard2D(fen: _parsedGame!.startingFen, size: 200),
                          ),
                          const SizedBox(height: 16),
                          Text('${_parsedGame!.plies.length ~/ 2} moves parsed', style: const TextStyle(color: AppColors.textSecondary)),
                        ] else
                          const Expanded(
                            child: Center(
                              child: Text('Enter a valid game to preview', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                          ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _projectNameController,
                          decoration: const InputDecoration(
                            labelText: 'Project Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _parsedGame == null || _isCreating ? null : _createProject,
                            child: _isCreating
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : const Text('Create Project', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
