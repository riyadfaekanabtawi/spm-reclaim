# EduQuestRPG

A 2D side-scrolling educational RPG foundation for Unity. Pick a character, run a
short platformer segment, and at each level goal answer a math or language
question. Correct answers award coins (scaled by tier and character multiplier)
and advance the level; wrong answers cost a life. Difficulty climbs from
single-digit arithmetic up to "resolve this integral" at the top tier.

Tone target: somewhere between MU-style character progression and Mario-style
platforming, with a quiz gate as the level-clear mechanic.

This is a working foundation, not a finished game. The logic layer is complete
and tested; scene wiring is a documented manual step (see "Scene setup").

## What is verified vs. what you wire

- Verified by compilation and a runtime smoke test (Mono 6.8, C# latest):
  the question system, answer validation across all tiers/subjects, reward
  scaling, DTOs, the backend contract, and game state. Output confirmed:
  rewards 10/25/40/55 per tier, correct answers validate, wrong answers reject.
- Not machine-verified (no Unity in the build environment): the MonoBehaviour
  and ScriptableObject scripts. They target Unity 6 LTS / C# 9 and are written
  to compile there, but treat the first Editor compile as the real check.

## Prerequisites

Run the checker first:

```
chmod +x check_prerequisites.sh
./check_prerequisites.sh
```

It verifies macOS + Apple Silicon, Xcode (iOS target), the Android toolchain,
Unity Hub, installed Editors and their iOS/Android modules, disk space, and git.
It is read-only and exits non-zero if a hard requirement (FAIL) is missing.

Baseline: Unity 6 LTS (6000.x), Apple silicon build, with iOS Build Support and
Android Build Support (SDK/NDK/JDK) modules added in Unity Hub.

## Project setup

1. Create a new Unity project using the 2D (URP or Built-in) template.
2. Copy the contents of this `Assets/` folder into your project's `Assets/`.
3. In the Editor menu run: `EduQuestRPG > Create Default Assets`.
   This imports the four placeholder skins as sprites, builds a `CharacterData`
   asset per skin, and assembles `Assets/Data/CharacterDatabase.asset`.

## Scene setup (manual, one time)

A single scene drives everything via panels toggled by the `GameManager`.

1. Tags and layers: confirm the `Player` tag exists; add a `Ground` layer.
2. World:
   - Ground: `GameObject > 2D Object > Sprites > Square`, scale wide, add
     `BoxCollider2D`, set its layer to `Ground`.
   - Player: a Square sprite with `SpriteRenderer`, `Rigidbody2D`
     (freeze rotation Z, gravity scale ~3), a collider, tag `Player`. Add
     `PlayerController`. Add a child empty `GroundCheck` at the feet; assign it
     to `groundCheck` and set `groundLayer = Ground`.
   - LevelStart: an empty GameObject at the spawn point.
   - Goal: a Square sprite at the right end with a trigger `Collider2D`
     (Is Trigger on). Add `LevelGoal`.
3. UI: `GameObject > UI > Canvas` (adds an EventSystem).
   - HUD: four `Text` elements (coins, level, lives, character). Add
     `HUDController` and wire them.
   - Selection panel: a panel with a child content object using a
     `Grid Layout Group`. Add `CharacterSelectionController`; wire `panel` and
     `grid`. Build a `CharacterButton` prefab: a `Button` with a child `Image`
     (skin) and child `Text` (label); add the `CharacterButton` component and
     wire `skinImage`, `label`, `button`. Assign the prefab to `buttonPrefab`.
   - Quiz panel: a `prompt` Text, a `feedback` Text, a choices container
     (`Vertical Layout Group`), a choice `Button` prefab (Button + child Text),
     and a free-text group (an `InputField` + a submit `Button`). Add
     `QuizGateController` and wire all references.
4. GameManager: an empty GameObject with `GameManager` and `LevelManager`. Wire
   `database`, `levelManager`, `player`, `levelStart`, `goal`, `selectionUI`,
   `quizUI`, `hud`.
5. Press Play. Selection appears, pick a character, walk right into the goal, the
   quiz gate opens.

If you would rather not wire this by hand, a full scene-building editor script
can be added in a later iteration. It was deliberately left out here because it
cannot be verified without running the Editor, and shipping unverified scene
codegen tends to cost more time than it saves.

## How the loop works

`GameManager` is the composition root (no DI container) and the state machine:
load/create profile, show selection, start level, on goal reached fetch a
question for the level's subject and tier, present the quiz, then award + advance
on correct or decrement lives + retry on wrong. State persists through
`IGameBackend` after each level.

Subject and tier per level (`LevelManager`, overridable per level via a
`LevelDefinition` asset):
- Subject alternates by parity: odd levels Math, even Language.
- Tier steps every 3 levels: 1-3 Basic, 4-6 Intermediate, 7-9 Advanced,
  10+ Expert (calculus / advanced vocabulary).

## Architecture

```
Core/        GameManager (loop + composition root), GameState
Questions/   Question, QuestionType, DifficultyTier, IQuestionProvider,
             LocalQuestionProvider (generated arithmetic + curated MCQ banks)
Characters/  CharacterData (SO), CharacterDatabase (SO)
Player/      PlayerController (Rigidbody2D platformer)
Levels/      LevelManager, LevelDefinition (SO), LevelGoal (trigger)
UI/          CharacterSelectionController, CharacterButton, QuizGateController,
             HUDController
Backend/     IGameBackend, LocalGameBackend (JSON), DTOs/
Editor/      AssetBootstrapper (menu: create skins + database assets)
```

Two seams are built for the backend you will add later:
- `IQuestionProvider`: swap `LocalQuestionProvider` for a `RemoteQuestionProvider`
  that fetches from your API. Signature is already async.
- `IGameBackend`: swap `LocalGameBackend` for a `RemoteGameBackend` (HTTP).
  DTOs are engine-free and ready to be a shared contract. The leaderboard method
  is stubbed to local profiles today.

## Extending

- Add a character: drop a sprite in `Art/Characters`, add a row in
  `AssetBootstrapper.Defs`, rerun the menu (or author the asset by hand).
- Add questions: extend the curated banks or the generators in
  `LocalQuestionProvider`. Expert tiers stay multiple choice so answers validate
  without a local CAS.
- Tune a level: create a `LevelDefinition` asset, set `levelIndex` and any
  overrides, add it to `LevelManager.definitions`.

## Notes / known items

- `PlayerController` uses `Rigidbody2D.velocity`, which works on Unity 2022 and
  Unity 6. On Unity 6 it emits a deprecation warning; rename to `linearVelocity`
  to silence it once you commit to Unity 6 only.
- Input uses the legacy Input Manager (`Horizontal` axis, `Jump` button) so the
  project runs with no extra packages. Migrate to the Input System package when
  input grows.
- Async lifecycle handlers in `GameManager` are `async void` at the Unity
  boundary and wrapped in try/catch. Consider UniTask if you want cleaner async.
- Local saves live in `Application.persistentDataPath`
  (`profile_<id>.json`, `progress_<id>.json`).
