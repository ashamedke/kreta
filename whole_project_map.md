# ChessCreator Project Map

This document outlines the architecture of the ChessCreator application, divided into its three primary stages: Home, Editor, and Video Rendering. It includes the relevant files for each stage and a brief description of their responsibilities.

## 1. Home Stage
The Home stage is responsible for project management, application startup, and importing chess games from various sources.

### Screens
* **`lib/screens/home_screen.dart`**: The initial landing page of the application. Displays recent projects and provides options to create a new project or open an existing one.
* **`lib/screens/import_screen.dart`**: Provides the UI for importing chess games. Allows users to paste PGN data or fetch games from external platforms.
* **`lib/screens/setup_screen.dart`**: Handles the initial configuration and setup steps when creating a new project.

### Services & API Clients
* **`lib/services/project_service.dart`**: Manages the persistence of projects, handling loading from and saving to the local disk.
* **`lib/services/chesscom_client.dart`**: Interfaces with the Chess.com API to fetch user games.
* **`lib/services/lichess_client.dart`**: Interfaces with the Lichess API to fetch user games.

### Models
* **`lib/models/project.dart`**: The core data structure representing a user's project, containing metadata, references to the game, and timeline settings.
* **`lib/models/game.dart`**: The data structure representing a parsed chess game (moves, players, metadata).

---

## 2. Editor Stage
The Editor stage is where users configure how their chess game will be presented, preview the animation, and tweak timings.

### Screens & UI Panels
* **`lib/screens/editor_screen.dart`**: The main workspace where the user interacts with the project, previewing the board and accessing editing tools.
* **`lib/widgets/timeline_editor.dart`**: A visual timeline widget that allows users to see and modify the sequence and pacing of chess moves.
* **`lib/widgets/timing_panel.dart`**: A configuration panel for adjusting specific timing parameters (e.g., delay between moves, piece slide duration).

### Previews
* **`lib/widgets/chess_board_2d.dart`**: Renders a 2D top-down view of the chess board for live previewing.
* **`lib/widgets/chess_board_3d.dart`**: Renders a 3D view of the chess board for live previewing.

### Logic & Services
* **`lib/services/chess_service.dart`**: Handles the core rules of chess, validating moves, and maintaining the current board state.
* **`lib/services/timing_resolver.dart`**: Calculates the exact absolute timestamps for every move and event based on the user's relative timing preferences.
* **`lib/services/preview_sound_service.dart`**: Plays audio cues (like piece placements and captures) in real-time while the user previews the animation.
* **`lib/utils/virtual_clock.dart`**: Manages the playback time state (play, pause, scrub) during the editor preview.

### Models
* **`lib/models/timeline.dart`**: Represents the sequence of events (moves, pauses, text overlays) that will occur in the video.
* **`lib/models/timing.dart`**: Data model storing the user's granular timing preferences.

---

## 3. Video Rendering Stage
The Video Rendering stage handles the conversion of the configured timeline and board state into a final MP4 video file.

### Screens & UI
* **`lib/screens/export_screen.dart`**: The UI where users select their final export settings (resolution, framerate, format) and initiate the render.
* **`lib/widgets/render_progress.dart`**: Displays the progress bar and status information while the video is being encoded. It often drives the frame-by-frame rendering loop.

### Engine & Encoding
* **`lib/widgets/render_engine.dart`**: The core component responsible for drawing each individual frame (either offscreen or onscreen) and capturing it as a pixel buffer.
* **`lib/services/render_service.dart`**: Orchestrates the entire rendering job, coordinating the render engine and the FFmpeg service.
* **`lib/services/ffmpeg_service.dart`**: A wrapper around the `ffmpeg` executable. It takes the raw frame buffers provided by the render engine and encodes them into a compressed MP4 video, multiplexing in the audio cues.
* **`lib/services/asset_cache_service.dart`**: Pre-loads and caches heavy assets (like 3D models or high-res images) to ensure the render engine doesn't waste time reloading them for every single frame.
* **`lib/services/youtube_service.dart`**: An optional integration that can automatically upload the final rendered MP4 to YouTube.

### Models
* **`lib/models/render_job.dart`**: Data structure tracking the configuration, status, and progress of an active rendering task.

---

## Global App Files
These files are foundational and span across all stages:
* **`lib/main.dart`**: The main entry point of the Flutter application.
* **`lib/app.dart`**: Sets up the root application widget, routing, and global themes.
* **`lib/utils/constants.dart`**: Contains global constants, visual theme properties, and configuration values shared throughout the app.
