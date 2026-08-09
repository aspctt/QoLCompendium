# QoL Compendium tests

Runs the mod's real Lua against Project Zomboid's own VM, without launching the game.

```
pwsh tests/run-tests.ps1
```

A full run takes under a second.

## How it works

`projectzomboid.jar` contains Kahlua, the Lua 5.1 VM the game runs mods on. The runner
boots that same VM outside the game, installs a stubbed game API, loads the real mod
source, and drives it frame by frame.

Because it is the shipped VM and the shipped `PZAPI/ModOptions.lua`, the tests break
when a game update changes the API, rather than silently passing against a hand-written
imitation.

Load order, assembled by `run-tests.ps1`:

| Layer | Source |
| --- | --- |
| Game API stubs | `harness/pz_stubs.lua` |
| Translations | the mod's own `UI_EN.txt`, which is valid Lua |
| Mod options API | the real one from the game install |
| Assertions | `harness/test_lib.lua` |
| Code under test | every `.lua` in the mod's `client` folder |
| Specs | `specs/*_spec.lua` |

Each test runs in a completely fresh environment. A mod's file-level locals, such as
the overlay blend accumulators, cannot leak from one test into the next.

## What it checks

Beyond the specs themselves, every run performs two static checks first:

- **Syntax**, by compiling each file with the game's own compiler.
- **Enum validity.** Every `MoodleType.X` in shipped mod source is verified against the
  constants actually present in the installed build, read straight out of the jar. This
  catches build-41 names in branches the tests never execute, reported with file and
  line.

The `MoodleType` table exposed to tests is built from that same jar reflection, so a
retired constant is nil in tests exactly as it is in game, and the stub raises a clear
error instead of a Java NullPointerException.

## Writing a spec

```lua
Test("description of the behaviour", function()
    Harness.Fire("OnGameBoot")
    Harness.SetMoodle(MoodleType.PAIN, 4)
    Harness.FireFrames(20)

    local Draw = Harness.FindDraw("qolc_pain")
    AssertNotNil(Draw, "pain overlay was not drawn")
    AssertNear(Draw.Alpha, 0.28, 0.0001, "pain alpha")
end)
```

Harness surface: `Fire`, `FireFrames`, `SetMoodle`, `SetScreenSize`, `ClearDraws`,
`FindDraw`, `DrawOrder`, `HandlerCount`, and the flags `HasPlayer`, `Draws`, `Moodles`.

Assertions: `AssertTrue`, `AssertFalse`, `AssertNil`, `AssertNotNil`, `AssertEquals`,
`AssertNear`, `AssertContains`.

## Adding a mod

Drop `specs/<mod>_spec.lua` in place. The runner picks up new specs and new mod source
automatically, no configuration.

If a mod calls a game function the stubs do not cover yet, add it to `pz_stubs.lua`.
Events need no work: any `Events.Anything.Add` is captured on first use.

## Requirements

A JDK. The JRE bundled with the game has no compiler, so the runner looks for one in
`Program Files`, Adoptium and the JetBrains runtime included with IntelliJ both work.
Tests execute from the game directory, because Kahlua resolves `stdlib.lua` relative to
the working directory.
