# Professional Architecture Blueprint: Chess NLE Editor

To elevate `chesscreator` from a simple chess visualizer to a professional Non-Linear Editor (NLE) on par with tools like Premiere Pro or After Effects, we must fundamentally restructure the editing phase. The current architecture tightly couples playback logic to the UI, relies on rigid data models, and lacks the foundational systems required for multi-track composition. 

Here is the deep, architectural roadmap detailing the specific files and systems that must be overhauled or created.

---

## 1. Unified Multi-Track Timeline Model
**The Current Flaw:**
The timeline state is horribly fragmented. `lib/models/timeline.dart` handles media `Layer`s, but chess annotations (arrows, floating text, notes) are stubbornly attached to `Ply` objects in `lib/models/game.dart`. `lib/services/timing_resolver.dart` dynamically generates absolute times on the fly. This fragmentation makes it impossible to build a unified multi-track timeline UI or easily sync audio to specific events.

**The Professional Architecture:**
We must refactor the data model so that *everything* is a temporal item on a track.
* **Target Files:** Rewrite `lib/models/timeline.dart`; create `lib/models/track.dart` and `lib/models/timeline_item.dart`.
* **The New System:**
  * `Timeline` contains a `List<Track>`.
  * `Track` has a type (`Video`, `Audio`, `Annotation`, `Overlay`) and contains a `List<TimelineItem>`.
  * `TimelineItem` is an abstract base class with `startTimeMs`, `endTimeMs`, and `z-index`.
  * Chess moves become `ChessMoveItem extends TimelineItem`. Arrows become `AnnotationItem extends TimelineItem`. 
* **Why?** This decoupling allows the UI to render a true multi-track view. You can drag an `AudioItem` on Track 4 to align exactly with the start of a `ChessMoveItem` on Track 1, because they share the same temporal base class.

---

## 2. Decoupled Playback Sequencer
**The Current Flaw:**
In `lib/screens/editor_screen.dart`, the `_onTick` function manually calculates the playhead position using a bunch of `if/else` logic against `_resolvedTimings`, and triggers audio (`PreviewSoundService`) directly from the UI layer. If you pause, the UI stops the timer. This is unscalable and causes UI stutters to drop audio frames.

**The Professional Architecture:**
A standalone `PlaybackEngine` that acts as the single source of truth for time.
* **Target Files:** Create `lib/services/playback_engine.dart`, modify `lib/utils/virtual_clock.dart`, remove playback logic from `editor_screen.dart`.
* **The New System:**
  * `PlaybackEngine` runs an internal high-fidelity timer (or ties into Flutter's `Ticker` cleanly but separated from the UI).
  * It broadcasts a `Stream<double> currentAbsoluteTimeMs`.
  * The `RenderEngineWidget` and `TimelineEditor` listen to this stream. They do not calculate time; they simply render the state at `currentAbsoluteTimeMs`.
  * Audio tracks subscribe to this engine. If the playhead hits 10450ms, the engine automatically tells the audio system to start playing the clip located at 10450ms.

---

## 3. Interactive, Zoomable Multi-Track UI
**The Current Flaw:**
`lib/widgets/timeline_editor.dart` is a basic horizontal `ListView.builder`. It can only display one row (the plies). You cannot zoom in on time (scale pixels-per-second), nor can you see overlays or audio below the moves.

**The Professional Architecture:**
A completely custom-painted timeline view capable of handling immense detail.
* **Target Files:** Total rewrite of `lib/widgets/timeline_editor.dart`; create `lib/widgets/timeline_track_view.dart`.
* **The New System:**
  * Build the timeline using a `CustomPaint` canvas or a highly optimized `Stack` of rows. 
  * Implement a `TimelineController` that holds `zoomLevel` (pixels per millisecond) and `scrollOffset`.
  * Support `Ctrl + Scroll` to zoom horizontally, revealing exact millisecond gaps between moves.
  * Dragging the edge of a `TimelineItem` updates its `duration`, automatically pushing all subsequent items forward (Ripple Edit) or just extending the clip (Roll Edit).

---

## 4. Keyframing & Property Animation Engine
**The Current Flaw:**
In `lib/models/timeline.dart`, `Layer` has static `x`, `y`, `width`, `height`. If a creator wants an image to slide across the screen, it is currently impossible because the properties are static scalar values.

**The Professional Architecture:**
A generic keyframe engine for any visual property.
* **Target Files:** Create `lib/models/keyframe.dart` and `lib/models/animatable_property.dart`. Update `lib/models/timeline.dart`.
* **The New System:**
  * Replace `double x` with `AnimatableProperty<double> x`.
  * An `AnimatableProperty` contains a list of `Keyframe` objects (e.g., `Time: 0ms, Value: 0.1, Curve: EaseIn`).
  * `RenderEngineWidget` interpolates the exact value of `x` at `currentAbsoluteTimeMs` by evaluating the curve between the two nearest keyframes.
  * This instantly unlocks panning cameras, zooming overlays, fading text, and animating arrows without writing custom animation code for each one.

---

## 5. Waveform Generation & Audio Syncing
**The Current Flaw:**
`lib/services/preview_sound_service.dart` blindly fires `playMoveSound()` based on editor screen logic. There is no concept of persistent audio tracks, and users cannot see audio visually. Syncing a voiceover is impossible.

**The Professional Architecture:**
Visual audio representation.
* **Target Files:** Update `lib/services/preview_sound_service.dart`; create `lib/widgets/audio_waveform_painter.dart`.
* **The New System:**
  * Integrate an audio manipulation package (like `fftea` or `audio_waveforms`) to decode audio files into PCM float data.
  * In the new multi-track timeline (`timeline_editor.dart`), audio tracks use `AudioWaveformPainter` to draw the peaks and valleys of the audio file.
  * Creators can now visually align the spike of the waveform (their voice saying "Checkmate!") with the exact millisecond the king is captured on the video track above it.

---

## 6. On-Canvas Gizmo System (Transform & Draw)
**The Current Flaw:**
We previously identified that `chess_board_2d.dart` and `RenderEngineWidget` lack interaction. But hardcoding gesture detectors into every widget is messy. 

**The Professional Architecture:**
A unified "Gizmo" layer that sits above the rendering engine.
* **Target Files:** Create `lib/widgets/editor_gizmo_layer.dart` and `lib/models/selection_model.dart`.
* **The New System:**
  * The `EditorGizmoLayer` sits on top of the `RenderEngineWidget` in `editor_screen.dart`.
  * It listens to a `SelectionModel`. If an `OverlayItem` is selected, it draws 8 transform handles.
  * If the "Arrow Tool" is active, it intercepts drags, projects the screen coordinates down onto the board's internal `_BoardGeometry`, and draws the temporary arrow.
  * This keeps the `RenderEngineWidget` pure (it only draws what exists) while the `GizmoLayer` handles all the complex interaction math and updates the timeline models.
