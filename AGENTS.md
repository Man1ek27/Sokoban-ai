
# Sokoban AI — Agent Instructions

## Project Overview

University project for "Artificial Intelligence in Games and Augmented Reality".

Goal: Build a 2D Sokoban game with an A* solver and a custom physics model that directly influences AI planning.

We aim for the highest grade (5.0).

The project must demonstrate:
- A* search with multiple heuristics.
- Geometric and physics-related deadlock detection.
- Physics-aware planning and movement costs.
- Meaningful integration with the Godot game engine.
- Experiments comparing AI strategies and physics settings.

## Technology

- Godot Engine 4.7.2
- GDScript
- 2D grid-based gameplay
- JSON level definitions
- Git and GitHub
- Godot AI plugin for Codex MCP integration

Do not introduce another game engine or programming language without approval.

## Team Responsibilities

### Alicja — Gameplay, UI and Integration
- Godot scenes and visual presentation
- Manual gameplay and controls
- HUD and interactive menus
- Player and box animations
- AI action playback
- Visualization of solver decisions and statistics
- Integration of AI and physics with gameplay

### Radoslaw — AI
- A* search algorithm
- Heuristic functions h1, h2 and h3
- Geometric and physics-based deadlock detection
- Solver performance experiments

### Mariusz — Physics and Levels
- Box masses and robot pushing force
- Static and kinetic friction
- Sliding mechanics and movement energy
- Physics transition model
- JSON level parser and test environments

## Current Implementation

The existing project contains:

- main.tscn — main scene with a Node2D root
- scripts/game.gd — gameplay and procedural drawing
- scripts/level_data.gd — JSON level parsing
- scripts/physical_model.gd — physics calculations
- levels/demo_level.json — demonstration level

Already implemented:
- Manual movement using WASD and arrow keys
- Box pushing and collision checks
- Level reset using R
- Basic movement and energy statistics
- Physics-dependent pushing and sliding

Not yet implemented:
- A* solver integration
- Win condition detection
- Animated movement
- Full UI and level selection
- AI playback and planning visualization

The current demo level has two boxes and one goal.
Do not assume it is a valid complete Sokoban puzzle.

## Architecture Rules

1. Keep gameplay presentation separate from AI and physics.
2. Maintain one consistent logical board state.
3. Reuse the existing physics model for move validation.
4. Never implement conflicting physics rules in UI code.
5. Animations must reflect the actual logical transitions.
6. Keep AI independent of the visual scene tree.
7. Agree on a solver interface before implementing AI playback.
8. Preserve compatibility with existing JSON levels.

The board is currently drawn procedurally.
Do not replace it with TileMapLayer without discussing
the architectural change first.

## Development Rules

- Always inspect existing code before editing.
- Prefer incremental, testable changes.
- Use clear GDScript naming and type annotations.
- Avoid unnecessary dependencies.
- Do not rewrite teammates' modules without approval.
- Do not modify the Godot AI plugin.
- Do not perform unrelated refactoring.
- Do not commit, push, merge, or switch Git branches
  unless explicitly requested.
- Report changed files after each implementation task.
- Explain how to test each change in Godot.
- Never claim a test passed unless it was actually run.

## Current Development Priority

Prepare the Godot gameplay and visualization layer:

1. HUD using Godot Control nodes
2. Level completion feedback
3. Player and box movement animations
4. Future AI integration points

Do not implement the A* algorithm or redesign
the physics model as part of these tasks.

## Verification

After changes, where possible:
- Check GDScript parsing and editor errors.
- Run the project in Godot.
- Verify WASD and arrow movement.
- Verify reset with R.
- Test pushing and blocked movement.
- Confirm that energy accounting still works.
- Check `git diff` and `git status`.

Keep the project reproducible and document significant decisions.
