# UniCode

UniCode is a block-based puzzle game that teaches introductory programming to
first-year college students. The student programs a robot that cleans
classrooms. They drag blocks such as **Step Forward**, **While**, **If** and
**Index Of** into a program, press Play, and watch the robot carry it out in one
or more rooms. The blocks behave like Python, and the game says so: tips and
end-of-level comments show the matching Python, and lists count from 0.

An AI assistant, backed by Google Gemini through a small relay server, gives
hints when a student is stuck. It never gives the answer. It runs on Windows and
in the browser.

- **Engine:** Godot 4.5.1 (standard build, GDScript).
- **AI relay:** Python 3.12 + Flask, on Vercel with a Render fallback. See [`ai/README.md`](ai/README.md).
- **Audience:** first-year students who read English as a second language. Every
  sentence a student reads is written to be skimmed: plain words, whole short
  sentences, the same terms every time.

---

## Contents

1. [Running it](#running-it)
2. [What a student sees](#what-a-student-sees)
3. [The curriculum](#the-curriculum)
4. [Architecture](#architecture)
   - [Project layout](#project-layout)
   - [Autoloads](#autoloads)
   - [Scenes and flow](#scenes-and-flow)
   - [Blocks](#blocks)
   - [The interpreter](#the-interpreter)
   - [Levels and rooms](#levels-and-rooms)
   - [Goals and stars](#goals-and-stars)
   - [Lists](#lists)
   - [The puzzle screen](#the-puzzle-screen)
   - [Guides (tutorials)](#guides-tutorials)
   - [The AI assistant](#the-ai-assistant)
   - [Progress and release](#progress-and-release)
5. [Tools and checks](#tools-and-checks)
6. [Making a level](#making-a-level)
7. [Building and deploying](#building-and-deploying)
8. [Conventions](#conventions)
9. [Known pitfalls](#known-pitfalls)

---

## Running it

1. Install **Godot 4.5.1** (standard).
2. Open `project.godot`. The first open imports every asset, which takes a minute.
3. Press **F5**. The game starts on the main menu (`menus/main/main_menu.tscn`).

The AI assistant needs a relay. The shipped `unicode_ai.cfg` points at the
deployed one. To run a relay locally, see [`ai/README.md`](ai/README.md).

Two config files sit next to `project.godot` (or next to the `.exe` in a desktop
export).

| File | Section | What it controls |
|---|---|---|
| `unicode_ai.cfg` | `[ai]` | `url`, `fallback_url`, `summary_url` and `token` for the relay. |
| `unicode.cfg` | `[levels]` | `released="tutorial,io,values,operators,selection,functions,arrays,dicts,files"`: which modules are open in level select. While the key is there it alone decides, and each module's own `released` flag is ignored (level select warns where they disagree). Leave the key out and the flags decide. |

---

## What a student sees

**Main menu → Level select → a level.**

- **Level select** shows one module at a time, in the course's order (Tutorial,
  Input and Output, Values and Variables, Operators and Expressions, Selection,
  Iteration, Functions, Arrays, Dictionaries, Text Files) as a
  grid of numbered buttons. A solved level shows the stars it earned; an
  unsolved one shows none. Levels unlock in order. It reopens on the module of
  the level just played.
- **The puzzle screen** has three columns:
  - **Left panel**, with four tabs behind icon buttons:
    - **Instructions**: the level's brief, titled `Level n: Title`.
    - **Toolbox**: the blocks for this level, with the new ones first. A small
      eye on each block shows what the block does, in a sentence.
    - **AI Assistant**: the hint chat.
    - **Variables**: every variable while a program runs.
  - **The canvas** in the middle: the student's program, built under the
    **Begin** block, on a grid like graph paper. It can be panned and zoomed,
    and the grid moves with it.
  - **The room** on the right: the level itself, in its own view. It can be
    dragged, zoomed, reset, and hidden for more space.
  - Buttons along the edges: menu, show/hide room, reset view, speed (its
    icon turns blue while the program runs fast), Play, Stop, and trash.
  - The Information tab ends with a **Go to Toolbox** button.
- **Running.** Play runs the program in every room of the level, one after
  another. The block that is running lights up. Values that blocks work out
  appear in small tags on them; when the next room starts, the last room's tags
  fade. Lists animate as they are read and written, and Ahead Is lights up the
  tile it checks. The Variables tab follows along.
- **Winning** shows a card with one to three stars (fewer blocks, more stars),
  the block count, and a short comment from the assistant about the program.
- **Guides** (dimmed tutorials) appear when a level brings in something new:
  - The screen dims except for the part being explained.
  - Arrows run from the card to it.
  - A page that waits for the student to do something starts with that, in
    bold. A page that is there to be read has no bold.
  - The guide waits for the student to do what it asks.
  - The pause menu shows the guide again.
- **Sounds** mark what happens: a ding when a level opens, a click on the main
  buttons, a pop when a block is picked up and a click when it attaches, a short
  note as each block runs, a "teleport" between rooms, and a win or fail sound.
- **Leaving.** The main menu's Exit asks first, and shows the progress code,
  flashing, with a Copy button.

---

## The curriculum

Defined in `global/utils/level_catalog.tres`: modules in order, levels in order.

| Module | Level | Title | Concept |
|---|---|---|---|
| Tutorial | 1 | First steps | How the screen works. |
| | 2 | Read it first | Read a program, predict what it does, run it (a worked example that runs itself). |
| | 3 | Rebuild it | A sensor and an if, from a blank canvas. |
| Iteration | 1 | Until the wall | `while`, driven by what the robot senses. |
| | 2 | Until you see it | A loop that watches for the target. |
| | 3 | Around the corners | A decision inside a loop. |
| | 4 | Count the desks | A counter built by hand. |
| | 5 | One block instead of three | `for`: the counter, packaged. |
| | 6 | A pattern, not a step | A loop body worth more than one move. |
| | 7 | Aisle by aisle | A loop inside a loop. |
| | 8 | Every row is longer | The inner bound is the outer counter. |
| | 9 | Two ways out | Leaving a loop early: `break`. |
| | 10 | Back to the question | Skipping to the next pass: `continue`. |
| Arrays | 1 | Read a list | A list, its indexes, and Index Of, with Step Forward N Times. |
| | 2 | How long is a list? | Length Of, then the first value. |
| | 3 | Last index, last value | Math with Length Of: the last index is length - 1, and the last value sits there. |
| | 4 | Every stop | Going through a list by index. |
| | 5 | Every stop, again | Going through a list value by value: For Each. |
| | 6 | There and back | Going through a list backwards. |
| | 7 | Number the lockers | Changing a list's values in place (Set Index). |
| | 8 | Passing marks | Building a new list with Append. |
| | 9 | In both | Checking whether a value is in a list (In). |
| | 10 | Here either day | Joining two lists without repeats, using Not and In. |

Arrays 1 to 3 add one idea each: a value by its index, the number of values,
then the last value. Each has two rooms with different lists, so a number typed
in doesn't pass. Arrays 2 and 3 share one shape, move, turn, move, and Arrays 3
changes only what is read: its first move builds the last index, length - 1, and
its second puts that same block inside Index Of, so the nesting deepens one step
at a time. Arrays 1 also brings Step Forward N Times, which is
Iteration's step forward with a number. An earlier opener asked for Step
Forward N Times, Index Of and a list's name block twice each, around a turn,
which was too much to take in; Arrays 1 uses each once, in a one-block program.

**The modules around Iteration and Arrays** follow the course syllabus
(CCP 1101) in its order, with CodeChum's exercises as the model for many
levels (Starry Ascension, Two String Input, Addition and Subtraction, Calculate
Distance, Is the Triangle Equilateral?, Book Recommendation). They are written
as data in `tools/modules/module_specs.py` and generated (see Tools and checks).
Each is ten levels, and none uses a block from a module after it.

| Module | Level | Title | Concept |
|---|---|---|---|
| Input and Output | 1 | Hello, World! | Showing text on the terminal with Print. |
|  | 2 | Line by line | One Print block for each line, from the top down. |
|  | 3 | Starry steps | A pattern, line by line. |
|  | 4 | One block, many lines | The control code \n starts a new line inside text. |
|  | 5 | Echo | Input reads what the user typed. |
|  | 6 | Two answers | Each Input reads the next line the user typed. |
|  | 7 | Steps from the keyboard | Input gives text; int( ) makes it a number the robot can use. |
|  | 8 | Around the corner | Two numbers from the user, read in order. |
|  | 9 | Here I am | Input and Print in the same program, in the order the user typed. |
|  | 10 | The delivery | Everything from this module in one program. |
| Values and Variables | 1 | Remember it | A variable keeps a value until you need it. |
|  | 2 | Say it three times | A variable can be used again and again. |
|  | 3 | Make a sentence | An f-string puts a variable's value into text. |
|  | 4 | There and back | One f-string can use the same variable twice. |
|  | 5 | Swap | Set gives a variable a new value; a third variable helps two of them swap. |
|  | 6 | Count your steps | A number kept in a variable can move the robot and go into text. |
|  | 7 | A decimal point | float( ) makes a number with a decimal point. |
|  | 8 | Good names | A variable's name follows Python's rules. |
|  | 9 | Name and age | \n and an f-string together: two lines from one block. |
|  | 10 | Here you go | Variables, types and f-strings in one program. |
| Operators and Expressions | 1 | Twice as far | The Math block, inside another block. |
|  | 2 | Add and subtract | + and - on two numbers the user typed. |
|  | 3 | Show your work | Work an answer out into a variable, then put it in an f-string. |
|  | 4 | Halfway there | // divides and drops the part after the decimal point. |
|  | 5 | Share the snacks | // for how many each, % for what is left over. |
|  | 6 | Around the garden | A Math block inside another one works first, like ( ) in Python. |
|  | 7 | Squares and cubes | ** raises a number to a power. |
|  | 8 | Keep a total | += adds to a variable: total += 5 is total = total + 5. |
|  | 9 | Kilometers to miles | Decimal numbers, and an f-string that shows three decimal places. |
|  | 10 | Minutes and seconds | // and % together. |
| Selection | 1 | Only sometimes | If runs its blocks only when its condition is True. |
|  | 2 | Left or right | Else runs when If did not. |
|  | 3 | Even or odd | % 2 tells even numbers from odd ones. |
|  | 4 | Three bins | Elif checks another condition when the one above it was False. |
|  | 5 | Letter grades | In a chain of If and Elif, the first True condition wins. |
|  | 6 | Both at once | And is True only when both conditions are True. |
|  | 7 | No school today | Or is True when at least one condition is True. |
|  | 8 | An if inside an if | A decision inside another decision. |
|  | 9 | Triangle types | And, or and elif together. |
|  | 10 | Book finder | Decisions inside decisions, to choose one of many answers. |
| Functions | 1 | Call it | A function is a set of steps with a name; calling it runs them. |
|  | 2 | Write it | Writing a function's steps once, and using them many times. |
|  | 3 | Hand it a number | A parameter: a name in the function that each call gives a value. |
|  | 4 | Stripes | A function with two parameters. |
|  | 5 | Give it back | Return gives a value back to the block that called the function. |
|  | 6 | How far apart | A function that decides what to give back. |
|  | 7 | The biggest | A call inside a call: the answer of one call goes into the next. |
|  | 8 | Even or not | A function that gives back True or False, used as a condition. |
|  | 9 | A receipt | Top-down design: a big job made of small functions. |
|  | 10 | Spiral | A function, a loop and a parameter together. |
| Dictionaries | 1 | Look it up | A dictionary finds a value by its key. |
|  | 2 | Where to? | A dictionary's values can be numbers the robot uses. |
|  | 3 | New price | Set Key gives a key a new value. |
|  | 4 | A new name | Set Key adds a key that isn't there yet. |
|  | 5 | Do we sell it? | In checks whether a key is in a dictionary. |
|  | 6 | Count the votes | A dictionary as a tally: one count for each key. |
|  | 7 | New words | A tally that starts empty: a new key starts at 1. |
|  | 8 | The price list | For Each goes through a dictionary's keys, in order. |
|  | 9 | The bill | Two dictionaries with the same keys, used together. |
|  | 10 | Sold out | Remove Key takes a key out; a dictionary changes as things happen. |
| Text Files | 1 | Read every line | Reading a text file, one line at a time. |
|  | 2 | How long is it? | Length Of counts a file's lines. |
|  | 3 | Write it down | Write adds a line to a file. |
|  | 4 | Copy a file | Reading one file and writing another. |
|  | 5 | Find a word | Searching through a file: In finds a piece of text inside a line. |
|  | 6 | Add up the scores | Reading numbers from a file: each line is text. |
|  | 7 | Write the squares | Writing numbers to a file: they have to become text first. |
|  | 8 | Passing scores | Reading, choosing, and writing: a filter from one file to another. |
|  | 9 | Number the lines | A counter while reading, and f-strings while writing. |
|  | 10 | The guest book | Search a file, then write to it: everything from this module. |

**How they teach.** Each module builds its idea from parts first, the way
Iteration builds `for` from a counted `while`: Functions calls a function that
is written before writing one, writes `abs()` and `max()` before naming the
built-ins, and the Arrays-style "one program, every room" rule is what makes
the terminal levels work. **A room is one run of the program with one user**,
as a CodeChum exercise has Sample Output 1, 2 and 3: the user types different
lines in each room, so typing a room's answer in fails the next room, and the
first wrong room is named.

**What they add.** At most one new feature per module, each because the
module's idea has nothing to be seen with otherwise:

- **Input and Output: the terminal** (`TerminalEntity`). Python's console as
  an object in the room: what the program prints, line by line, and under it
  what the user types, as coral chips (the colour of text, because `input()`
  always gives text). A `TerminalGoal` shows the lines it should end with,
  faded, and colours each printed line green or red. Values and Variables,
  Operators and Selection use it too, with no feature of their own:
  - **strings** need nothing new. A typed slot already took "text"; it now
    reads Python's escape codes (`\n`, `\t`, `\"`) and **f-strings**
    (`f"Hello, {name}!"`, with `{x:.2f}` and `{n:d}`), filled in when the block
    runs (`FString`). An f-string holds names only, not math: `{x + y}` says to
    work the answer out into a variable first.
  - **Convert** is `int()`, `float()` and `str()`, with Python's rules and
    messages that say why ("int() can't turn '7.5' into a whole number. It
    has a decimal point, so use float().").
  - **Math** gained `**`, and text `*` a whole number (`"*" * 3`). **Update**
    is `+=`, `-=`, `*=`, `/=`, `//=` and `%=`.
  - **Selection** gets no feature: decisions are made interesting by the
    rooms. The same program meets a different user (or a different bin, in
    Three bins) in each room, so the student has to find the rule that tells
    the rooms apart, which is the constructivist part, and the robot's path
    shows a wrong branch at once.
- **Functions: define and call** (`FunctionDefinitions`). A level names its
  functions and their parameters; each gets a `define name ( a, b )` block on
  the canvas beside Begin and a call block in the Toolbox (round when it gives
  back a value, six-sided when it gives back True or False, so it fits an If).
  The student writes what it does. Naming is the level's, as a list's name is:
  a name typed by the student would have to rename call blocks already on the
  canvas. A call gets its own variables and sees the program's top-level ones,
  as Python's local and global names; `return` ends it from inside any loop
  (`ControlSignal.RETURN`).
- **Dictionaries: the dictionary board** (`DictEntity`). One row per key,
  `key : value`, in insertion order. The list board's boxes are a tile wide,
  which a key like "library" isn't, so it is drawn like the terminal. Its blocks
  are written as Python writes them: `prices [ "pen" ]`, `set prices [ "pen" ]
  to 20`, `remove "pen" from prices`; In, Length Of and For Each take a
  dictionary as Python's `in`, `len()` and `for` do. A `DictGoal` compares as
  `==` does, in any order.
- **Text Files: the file** (`FileEntity`). A sheet with a name tab
  (notes.txt) and numbered lines; its name block is the opened file. For Each
  reads its lines, Length Of counts them, Write adds one at the end, and In
  finds a word in a line (In now takes text, as Python's does, and its right
  side can be typed into). Write takes text only, as `f.write()` does, so
  writing numbers teaches `str()`.

Tuples and sets, from the same weeks as dictionaries, have no levels.

Every level scores except the Tutorial module's (`counts_for_progress =
false`). Those take no slot in the progress code, but still unlock in order and
earn stars, which are kept on this computer only (see
[Progress and release](#progress-and-release)).

Level ids never change, since the progress code and the thesis data are keyed
by them. So Arrays 1 and 2 keep `ar-t2` and `ar-t3` from when they were
tutorials, and there is no `ar-9`: Tidy up was cut to keep Arrays at ten
levels.

**The rooms.** Each level has one to three rooms; Arrays 1 to 6 have two,
since a third board and route on screen was more to look at than it taught. **One program runs in every room**, so it has to handle all of them. In
each room the robot must:

- stop on the **green flag** (the destination);
- collect every **battery** on its way (some levels);
- avoid **puddles** (shown with a wet-floor sign);
- leave each list holding what it should (list levels).

Desks and walls block the robot.

---

## Architecture

### Project layout

```
project.godot          Autoloads, input map, main scene
unicode.cfg            Release gate: which modules are open
unicode_ai.cfg         Relay URLs and token

global/                Autoloads and shared helpers
  core.gd              Scene paths, tree helpers, type checking, Python keywords
  game.gd              The current level, its id, the session id, sleep()
  interpreter.gd       Run state, speed, scopes (variables), errors, output log
  progress.gd          Stars, saved to user://progress.cfg
  tutorial.gd          Signals the guides listen for
  ui_motion.gd         Pop-ins, fades, button juice for every button and popup
  star_text.gd         Stars drawn in the one font that has them (Noto Symbols 2)
  code_spans.gd        Python in prose shown as code (backticks, bare Python)
  sfx player/          Sound effects, and the click on the main buttons
  transition/          The fade between scenes
  utils/               Level catalog, level entries, progress codes, hint pool

menus/                 Main menu (with its demos), level select, pause menu, progress dialog

puzzle/                The puzzle screen
  puzzle.tscn/.gd      Wires everything for one level
  button_manager.gd    Play / pause / stop / speed / reframe
  blocks/              BlockData resources (.tres): one file per block
  functions/           What blocks do: control_flow.gd, generic.gd, list_functions.gd, array.gd
  ui/block/            Block scenes, components, BlockData scripts
  ui/canvas/           The canvas, drag and drop, serializer, value bubbles
  ui/side panel/       Side panels, Toolbox, AI Assistant, Variables
  ui/tutorial/         Guide overlay, card, arrow, pictures
  ui/level_complete/   The win card
  ui/notification/     Toasts at the top of the canvas
  ui/themes/           main_theme.tres, fonts

level/                 Level framework
  level.tscn/.gd       Base scene every level inherits
  level_description.gd The brief in the Instructions tab
  level_briefs.gd      Backup copy of every brief (see Known pitfalls)
  guides.gd            Every guide page, as data
  block_preset.gd      The Begin block and any preset program
  goal_manager.gd      One room's goals
  goals/               Destination, checkpoint (batteries), hazard (puddles), list goals
  components/          LevelCamera, BlockProvider, Resettable
  objects/             Sprites, the robot, the list board
  levels/              The level scenes: tutorial_1, it_0a/b, it_1..10, ar_t2, ar_t3, ar_3..8, ar_10, ar_11

world/                 Tilesets (floor, walls, furniture) and their art
audio/                 Sound effects
tools/                 Test and authoring scenes (see Tools and checks)
  arrays/              The generator for the Arrays levels (Python)
  menu/                The generator for the main menu's demo rooms (Python)
  audio/               The sound measuring and retuning tool (Python)
ai/                    The relay server and the web build it hosts
```

### Autoloads

Registered in `project.godot`, available everywhere by name:

| Autoload | Role |
|---|---|
| `Core` | Paths to the main scenes, `get_block()`, recursive child walks, `validate_type()` (the "must be an integer" messages), Python's keyword list. |
| `Debug` | Debug logging. |
| `Game` | The running `Level`, its scene and `level_id`, a random `session_id` per launch, and `sleep()`, which pauses with the program. |
| `Interpreter` | Whether a program is running, paused or interrupted. Also the step delay (slow or fast), the variable scopes, errors, the output log, and the signals the UI follows. |
| `SfxPlayer` | Plays sound effects from a pool of players, so they can overlap. Clicks the buttons in the `sfx_click` group, and gives the run's pulse notes their own three players. |
| `Transition` | `change_scene()` with a fade. |
| `Tutorial` | Signals for guide steps: block placed, block trashed, message sent, menu toggled, panel toggled, tab shown, view reset. |
| `Progress` | Stars per level, the catalog, saving and loading. |
| `UiMotion` | `pop_in`, `fade_in`, `stagger_in`. Also gives every button a hover and press scale, and pops in every popup, without each scene wiring it. |

### Scenes and flow

```
main_menu.tscn ──Start──> level_select.tscn ──a level──> puzzle.tscn
      ▲                         │  ▲                        │
      └───────── Home ──────────┘  └──── Level select ──────┘
```

**The main menu** (`menus/main/`) is a pixel-art campus (`final_bg.jpg`) that
covers the window and drifts a little with the pointer (`background.gd`,
which keeps the courtyard in the middle when a window's shape crops it). The
logo and the buttons are in the left column. In the courtyard, `MenuDemo`
plays short programs in turn, each beside a little classroom where it runs:
a robot going round a desk, a robot following the values in a list, a robot
checking ahead and turning back at the walls, and a list swapping two of its
values. Each demo is worked out step by step the way the program runs (a block
lights up for a step, then acts) and replayed by a Tween, not by the
Interpreter, which is a level's. Lists animate through
`ListEntity.show_read()` and `show_write()`, which run a read's and a write's
animation with no block and no step. The rooms are `demo_*.tscn`, made by
`tools/menu/gen_demo_room.py` with the Arrays generator's painter; the room is
drawn at the biggest whole-number scale that fits.

`Transition.change_scene()` moves between them. Choosing a level sets
`Game.level_scene` and `Game.level_id` before the change. `Puzzle._ready()` then
instantiates the level into the room's `SubViewport` and calls
`configure_level()`. That fills the Instructions tab and the Toolbox, places the
Begin block, starts the level's guide, and runs worked examples by themselves.

### Blocks

A block is **data plus a scene**.

**`BlockData`** (`puzzle/ui/block/data/block_data.gd`) is a Resource, one
`.tres` per block in `puzzle/blocks/` and `level/objects/entities/robot/blocks/`.
It holds:

- `name` (an internal id, e.g. `ItemOfBlock`) and `title` (what students call it,
  e.g. "Index Of").
- `type`: `STATEMENT` (does something), `NESTED` (has a mouth for blocks), or
  `SOCKET`/`VALUE` (gives a value and plugs into a slot).
- `text`, with `{}` for each slot (`"index {} of {}"`), plus `text_blocks`: the
  slot blocks themselves.
- `text_hints`: the grey word shown in an empty slot (`index`, `var`, `value`).
- `note`: the block's short tutorial text for students ("This block adds 1 to a
  variable."). The Toolbox's eye shows it, and a guide page uses it when the
  level gives no note of its own.
- `category` (the Toolbox section), `color`, `description` (the precise
  version, sent to the assistant), `syntax`, and flags: `draggable`,
  `placeable`, `trashable`, `copyable`, `top_notch`, `toolbox`.
- What it does, as one of:
  - a method on a script in `puzzle/functions/` (`STANDARD`);
  - a method on an entity in the level, found by `entity_name`: the robot's
    `move`, `turn` and `ahead_is`, a list's `read` (`ENTITY`);
  - nothing, as for a plain value slot (`LAMBDA`).

`deep_copy()` is used everywhere a block is built. `duplicate(true)` shares
file-backed sub-resources, which once let one block's edit leak into every copy.

**Block scenes** (`puzzle/ui/block/templates/`):

| Scene | Class | Used for |
|---|---|---|
| `statement_block.tscn` | `StatementBlock` | Step Forward, Turn, Set, Append, ... |
| `nested_block.tscn` | `NestedBlock` | While, For, For Each, If, Else |
| `cap_block.tscn` | `CapBlock` | Begin (flashes when Play is pressed) |
| `expression_block.tscn` | `ExpressionBlock` | Hexagonal true/false blocks: Ahead Is, Compare, Not, And/Or, In |
| `value_block.tscn` | `ValueBlock` | Round value blocks: typed slots, dropdowns, Index Of, Length Of, Math, a list's name |

`Block.construct(data)` builds one. Each block has four components:

- **Text** builds the label and slots from `text`.
- **Function** evaluates the parameters and calls the bound method.
- **Visual** handles colour, highlighting, error flashing, and the shimmer on
  empty slots.
- **Drag** handles copying and dragging.

**Drag and drop** uses Godot's built-in drag and drop:

- `canvas/drop_manager.gd` shows where a statement block will attach.
- `canvas/socket_drop_manager.gd` does the same for value blocks going into slots.
- The canvas takes free drops; the trash button takes deletions. A block from
  the canvas let go over the open toolbox is thrown away too
  (`Puzzle.returns_to_toolbox()`, handled in `trash_button.gd`), and the drag
  cursor shows an arrow there.
- The canvas is one big `ColorRect` that pans and zooms with its blocks. Its
  grid (`ui/themes/shaders/canvas_bg.gdshader`) is worked out in the canvas's
  own coordinates, so it moves with the blocks: dragging the canvas reads as
  moving the workspace. It is kept dim, so the blocks stand out. Level select
  uses the same shader, set fainter.
- Loose blocks that overlap drift apart (`PuzzleCanvas._separate()`): a block
  dropped where it can't attach used to sit on top of another and look
  attached. Each frame, overlapping loose stacks are pushed apart along the
  shorter way, a little at a time, until there is a 16 px gap; Begin and blocks
  that can't be dragged hold still. Only overlaps push, so blocks come to rest.
  It pauses while a block is dragged and while a program runs.
- Blocks that can't be thrown away say so by name.
- The cursor turns to "not allowed" wherever letting go would do nothing.

**The serializer** (`canvas/serializer.gd`) writes the program as YAML. That YAML
goes to the assistant, is stored as a level's `intended_solution`, and is how
blocks are counted for stars.

### The interpreter

A tree-walking, `await`-based interpreter. Pressing Play calls
`Puzzle.run_program()`, which calls `Level.run_rooms(begin)`. For each room it:

1. resets that room's goals, then puts every entity back where it starts
   (`Resettable` snapshots);
2. runs `begin.function.run()`;
3. checks the room's goals.

The first room that fails ends the run with a message that names the room.

Each block's function (for example `ControlFlow._while`) awaits
`Interpreter.step(block)`. That lights the block up and waits `current_delay`:
0.7 s at normal speed, and in fast mode a delay that shrinks as the run goes on.
Then the function evaluates its parameters with `function.eval_args()`. After
a nested block (an If, a loop) is done, and at the end of the program, there is
a beat with nothing lit (`Interpreter.settle()`, one step long) before the next
block, unless an Else or Elif carries the chain on. Without it, what an If had
just checked was still showing while the block under it moved the robot.
Everything is a coroutine, so a run can pause (the pause menu), stop (Stop, an
error, a failed goal), and show every step.

**Semantics follow Python:**

- **For** counts like `range()`: `from 0 until 3` runs 0, 1, 2.
- **For Each** gives its variable a copy of each value, and re-reads the list's
  length every pass.
- `//` and `%` work as in Python.
- `-1` is the last index.
- Comparing values of different types is an error that says why.
- A list's name typed into a slot means that list, unless a variable has that
  name.

**Safety limits:** 10 000 passes per loop (`MAX_LOOPS`), a nesting depth of
1 000, and 20 values per list.

**Scopes.** Each block that opens a body pushes a frame
(`Interpreter.push_scope`), and the Variables tab draws the frames as a tree.
After an error or a Stop, the frames are frozen, so the tab shows the values at
that moment.

**Signals the UI follows:**

- `running_changed`, `paused_changed`, `scope_changed`;
- `block_highlighted`;
- `value_shown`, `value_skipped` and `values_cleared`, for the value tags;
- `error_raised`, `output_logged`.

### Levels and rooms

Every level scene inherits `level/level.tscn`:

```
Level (level.gd)
├── LevelDescription     the brief: title, mission, rooms, twist, tip, new blocks
├── LevelBlockPreset     the Begin block, and any program already under it
├── GenericBlockProvider blocks this level gives the Toolbox
├── RoomGoals
│   └── GoalManager[, GoalManagerRoom2, ...]   one per room, holding its goals
├── Camera2D (LevelCamera)
└── Visuals
    ├── Floor (TileMapLayer)
    ├── Destination1.. / Pen1_1.. / Hazard1..   Area2Ds the goals watch
    ├── Lists/Room1/<name>  list boards, one set per room
    ├── YSorted
    │   ├── Furniture (TileMapLayer)   desks block the robot
    │   ├── RobotCharacter             robot.gd, with its own BlockProvider
    │   ├── Walls (TileMapLayer)
    │   └── PhantomSprite...           faded robots marking the other rooms' starts
    └── Room1Label..
```

**Settings on `Level`:**

| Setting | What it does |
|---|---|
| `intended_solution` | The reference program, as YAML. Sets par, and goes to the assistant as a hidden reference. |
| `star_slack` | How many blocks over par still earn two stars. |
| `star_par_override` | Sets par directly, instead of counting the reference program. |
| `room_goals` | The GoalManagers, in room order. |
| `auto_run` | Worked examples run once by themselves after the guide. |
| `minimal_ui` | Hides the assistant, the Variables tab and the speed button. |

**One robot, several rooms.** The robot moves between rooms by snapshot:
`ResettableComponent.room_snapshots` holds its position and facing for each
room. Blocks that talk to a list find the board in the room that is running
(`ListEntity.find`, by `room_index`).

**The robot** (`level/objects/entities/robot/robot.gd`):

- **Move:** `move()` and `move_n()` move it by physics; a wall or desk stops it
  with an error.
- **Turn:** turns left, right or around.
- **Ahead Is:** `ahead_is()` checks the tile in front with a ShapeCast probe. It
  answers `blocked` (any solid body) or matches a `SensedArea` tag
  (`destination`, `puddle`). The tile it checks lights up (`TileScan`): a yellow
  frame and a sweep away from the robot, then green for True or pink for False,
  all inside one step, so it's over before the robot can move.
- **Animation:** only the sprite moves. It hops on turns, bobs on steps, bumps
  into walls, celebrates a win and shakes its head on a fail. The body stays
  exact for the goal checks.

**The brief.** `LevelDescription` builds the Instructions tab from its fields:

- a mission card;
- numbered room rows;
- a "twist" card;
- a tip, with its Python shown as code;
- the star target.

`get_raw()` gives the same text to the assistant. New blocks don't appear in the
brief. They go to the top of the Toolbox with their notes, and each gets a guide
page.

### Goals and stars

A `GoalManager` holds one room's goals (`level/goals/`). After a room runs,
`find_failing_goal()` returns the first goal that isn't met, and its
`fail_message` is what the student reads.

| Goal | Met when | Shown as |
|---|---|---|
| `DestinationGoal` | The robot ends on its area. | The green flag (`level/objects/green_flag.png`, 32 x 32, drawn at 1x) |
| `CheckpointGoal` | The robot passed over it. Once collected, it stays collected. | A battery (`world/assets/objects/battery.png`), which fades when picked up |
| `HazardGoal` | The robot never entered it. | A puddle with a wet-floor sign (`danger.png`) |
| `ListGoal` | A list holds the expected values at the end. | Green targets on the board's boxes |

**Stars.** Par is the number of solid blocks in `intended_solution`, counted by
`Serializer.count_solid_blocks()`; a preset program doesn't count.

| Blocks used | Stars |
|---|---|
| par or fewer | 3 |
| up to `par + star_slack` | 2 |
| more | 1 |

The win card shows the next tier only. Earned stars are yellow and the rest
black, with no outline: an outlined empty star read as a filled one.

### Lists

A list is a whiteboard in the room (`level/objects/entities/list/`):

- **The board:** `ListEntity` is a Node2D that draws the board.
  - Its name sits on an orange chip drawn like the list's name block in the
    Toolbox.
  - Values sit in boxes, with an index row under them.
  - A board can hang on the wall or stand on legs.
  - A room with a board on its wall has a wall three tiles tall, so the board
    hangs with plain wall under it, and its boxes start half a tile into a
    floor column. Its index row once sat right on the floor's edge, one box
    over each tile, and the indexes read as numbers for the floor's columns.
    The middle wall tiles are row 2 of `world/assets/tilesets/school_walls.png`.
  - Each list has one board per room, all with the same name.
- **The name block:** the board's `ListBlockProvider` gives the Toolbox the
  list's name block, a round orange reporter.
- **Blocks that use lists:** `puzzle/functions/list_functions.gd` implements
  Index Of, Set Index, Length Of, Append and In. Each block calls
  `ListFunctions.resolve()` to find its list, and names itself in any error.
- **Animation:**
  - A value that is read rises and glows.
  - A written value flies in from the box it was read from, or drops in.
  - An index past the end shows a red "ghost" box.
  - For Each outlines the box it is on, in yellow.
- **Goals:** `show_example()` and the list's `ListGoal` mark targets. A small
  green badge on a box shows what the box should hold, whether it is empty or
  holds something else (a faded value used to mark empty boxes, and read as
  one that couldn't be changed). The badge reaches over the next box, so it
  draws above the boxes. A card turns green or red when a write is right or
  wrong.

### The puzzle screen

| Part | Where | Notes |
|---|---|---|
| Side panels | `ui/side panel/panel.gd` (`SidePanel`) | Slide open and closed; `focus_content()` switches tabs; emit `toggled`. |
| Toolbox | `tabs/toolbox/` | One scroll, holding the new blocks first and then each category. Tabs and scroll follow each other; other categories dim. Each block sits on a tile (`ToolboxTile`) with an eye that shows its `note`; in the new blocks section the note shows from the start. |
| Variables | `tabs/watcher/variable_watcher.gd` | A tree of frames and variables. It only takes the panel over once a run has a variable to show. |
| AI Assistant | `tabs/ai assistant/` | See [The AI assistant](#the-ai-assistant). |
| Value tags | `ui/canvas/value_bubbles.gd` | What each expression came to, on its block: results of math, Index Of, comparisons, and a typed variable's value. When a room is solved and the next starts, its tags fade after 0.6 s, unless the new room has put a value on the same block. |
| Notifications | `ui/notification/` | Errors, logs, and successes such as "You solved Room 1 of 2". |
| Win card | `ui/level_complete/` | Stars, block count, next tier, and the assistant's comment. It holds the buttons for a second so a stray click can't skip it. |
| Pause menu | `menus/pause/` | Resume, the level's guide (show again or skip), Level select, Main menu. Esc toggles it. |

### Sounds

The files are in `audio/`; `SfxPlayer` (`global/sfx player/`) plays them, each
at the gain in its `GAIN_DB` table.

| Sound | When | Where it's called |
|---|---|---|
| `level_start.mp3` | A level opens. | `Puzzle.configure_level()` |
| `button_click.mp3` | A button in the `sfx_click` group is pressed: the room, view, speed, Play, Stop, menu and trash buttons, the pause and main menus, the progress dialog, level select's Home and arrows, the win card's Try again and Level select. Not the guide's buttons, the side panel tabs, or anything that opens a level (the level's own sound follows). | `SfxPlayer`, by group |
| `block_picked_up.mp3` | A block is picked up, from the Toolbox or the canvas. | `Block._get_drag_data()`, `DragComponent` (copying) |
| `block_drop.mp3` | A block attaches, to a block or into a slot. | `drop_manager.gd`, `socket_drop_manager.gd` |
| `block_trash.mp3` | A block goes in the trash. | `trash_button.gd` |
| `block_pulse_f#5`, `_a5`, `_b5`, `_d6.mp3` | A block runs and lights up. One note at random, never the same twice in a row, for every block: three players take turns, so none is dropped. Closer together than 160 ms, each is a little quieter. | `Interpreter.step()` |
| `next_room.mp3` | A room is solved and the next one starts. | `Puzzle._on_room_completed()` |
| `success.mp3`, `fail.mp3` | The level is solved; a block raised an error. | `Puzzle` |

**Balancing.** `tools/audio/balance.py` (needs numpy, scipy and ffmpeg)
measures every file: its loudest 100 ms, K-weighted the way LUFS is, and its
pitch. Each sound has a role with a target loudness (the win and fail loudest,
then a level opening and the next room, then clicks and block sounds, and the
pulses under everything), and the tool prints the gains as `GAIN_DB`. With
`--retune` it also tunes each pulse to the note in its name, by resampling,
after copying the original to `audio/source/` (which has a `.gdignore`, so
Godot skips it). The pulses are four notes of the D major pentatonic, so any
two that overlap in a fast run still sound good together, around the G5 of
`level_start.mp3`.

```bash
python tools/audio/balance.py . --retune
```

### Guides (tutorials)

- **The data:** guides are data in `level/guides.gd`.
  - `SETS` holds named runs of pages.
  - `LEVELS` says which sets each level gets.
  - `"blocks"` stands for one page per new block, built from the level's
    description.
  - Kept in code because the editor twice dropped exported step properties.
- **What a page can set:**
  - its title, text and button text. In the text, `**this**` is bold
    (`GuideCard` turns the text into BBCode). Only a page that waits for the
    student to do something starts with bold;
  - a picture: a `GuideGraphics` picture, a video, an image or scene, a small
    program, or a block;
  - what stays lit (`targets`), which tab to open (`focus`), and what the
    arrows point at (`arrow`: one target, or a list for one arrow each);
  - what moves it on (`advance`): a block placed or trashed, Play, a menu
    toggle, a panel toggle, a tab opened with its button, and so on.
- **Block pages** show the block's note; the arrow already shows where the
  block is. A block with a slot that is typed into gets `SlotExamples`: sample
  values (a variable `x` and a number `2`) floating under it, each with an arrow
  into the slot, so the slot reads as a place for many kinds of value.
- **`TutorialOverlay`** (`puzzle/ui/tutorial/`):
  - dims the screen except the targets (`TutorialMask`);
  - places the card beside the first arrow's target, glides it as panels move,
    and draws the arrows (`GuidePointer`);
  - lets the student go Back over earlier pages, which then wait for nothing.
- **Pictures** are built from the game's own sprites, so they match it:
  - `TileStrip` draws rows of room tiles with the robot.
  - `ListPicture` wraps a real board.
  - `BlockPicture` draws a block, or a whole small program.
  - `GuideGraphics` builds the picture for each robot and list block. Ahead
    Is gets one framed panel for each thing it can look for (a wall, the green
    flag, a puddle), each with its dropdown word and True.
- **Videos:** the two `.ogv` clips in `ui/tutorial/graphics/` show attaching a
  block and filling a slot.
- After a guide that opened the Toolbox, the panel goes back to the
  Instructions tab.

### The AI assistant

The game side is `puzzle/ui/side panel/tabs/ai assistant/ai_assistant.gd`:

- **Endpoints:** read from `unicode_ai.cfg`. If the main URL can't be reached,
  the game tries `fallback_url` once.
- **What a question sends:**
  - two pictures once something has run: the level as it started (taken when
    it opened) and the level now. After a run the robot and lists stay where
    the program left them, and with one picture the model took that result for
    the start of the level. The robot line says the same in words;
  - the brief, and a description of every available block;
  - the student's program as YAML, plus the program at the last Play;
  - the hidden reference solution;
  - the last run's result and output log;
  - the robot's position and facing, and every room's lists;
  - the chat history.
- **Question budget:** a pool of 10 questions that refills one a minute,
  shared by all levels (`HintPool`). A request that never reached the model
  gives its question back.
- **Win-card comment:** one request per win. The card never waits for it; it
  fills in when it arrives, or its line disappears.
- **New chat** clears the history. Each message scrolls the chat to the bottom.

The relay (`ai/main.py`) holds the prompts, the model lists (Gemini Flash with
thinking at medium for hints, Flash-Lite with thinking at low for the win
card), safety settings and rate limits. Its hint prompt is a
tutor's: answer what the student said, give one fact about their run, and end
with one question that makes them predict, count or explain, never "press
Play". Everything about it is in [`ai/README.md`](ai/README.md).

### Progress and release

- **Saving:** `Progress` keeps the best stars per level in memory and in
  `user://progress.cfg`. Levels without a progress slot (the Tutorial module)
  keep theirs in the same file, under `[practice]`, and nowhere else: not in
  the code, and not in the study's data. A practice level that has since
  become a scored one brings its stars into its slot when the file loads.
- **Progress codes:** `ProgressCode` packs all stars into a 10-character code
  (`XXXXX-XXXXX`) with a format version and a checksum. The main menu's
  Progress dialog shows it and takes one in; a typed code keeps the better
  result per level. Exit shows it too, flashing, before the game closes. No
  progress is ever sent anywhere. Version 2 came with the Arrays rework; a
  version 1 code is still read, against the slots it was written with
  (`Progress.V1_SLOTS`).
- **The catalog:** `LevelCatalog` (`global/utils/level_catalog.tres`) holds
  every module (`LevelModule`) and level (`LevelEntry`). An entry has an id,
  label, title, concept, scene, `counts_for_progress` and `retired`.
- **Unlocking:** with `sequential_unlock`, a level opens once the one before it
  in its module is solved, plus `unlock_lookahead` more. Each module is its own
  sequence, and its first level is always open. A solved level opens every
  level before it, so a progress code typed in on a new computer opens each
  module up to its furthest solved level. The Tutorial module has no slots in
  the code, so it starts over there.
- **Release gate:** a module shows only when it is released: by
  `unicode.cfg`'s `[levels] released` when that key is there, otherwise by the
  module's own flag. A closed module shows its `locked_notice` in place of its
  levels. Iteration is closed for now, in both.

---

## Tools and checks

All in `tools/`, run with the Godot executable (`$GODOT` below). Run the first
three after any change to levels, blocks or the interpreter.

| Scene | What it does | Command |
|---|---|---|
| `level_checks.tscn` | The harness: builds each level's intended program and its known wrong programs from a compact spec, runs them through the real puzzle, interpreter and goals, and prints OK or BAD per case. An argument filters by case title; `yaml` prints each program's YAML. | `$GODOT --headless --fixed-fps 60 --path . res://tools/level_checks.tscn [-- AR-4]` |
| `level_lint.tscn` | Checks every level's wiring: catalog entries, goals and their nodes, room counts against brief rows, blocks, briefs against `level_briefs.gd`. | `$GODOT --headless --path . res://tools/level_lint.tscn` |
| `tour_check.tscn` | Plays the first level's guide by doing what each page asks, through the real buttons. | `$GODOT --headless --path . res://tools/tour_check.tscn` |
| `guide_snaps.tscn` | Screenshots of every guide page of the levels given. Not headless. | `$GODOT --path . --resolution 1920x1080 res://tools/guide_snaps.tscn -- res://level/levels/ar_t2.tscn` |
| `ui_snaps.tscn` | Screenshots of the Toolbox, the assistant, the win card, a room mid-scan (Ahead Is), a list's goal badges, level select and the quit popup. Not headless. | `$GODOT --path . --resolution 1920x1080 res://tools/ui_snaps.tscn` |
| `bake_level.tscn` | Measures a level's camera bounds and each room's bounds, as JSON. | `$GODOT --headless --path . res://tools/bake_level.tscn -- res://level/levels/ar_4.tscn` |

Screenshots go to `user://` (on Windows,
`%APPDATA%/Godot/app_userdata/unicode/`); each path is printed.

**The module generator** (`tools/modules/`, Python 3, no packages) writes
the levels of the seven modules around Iteration and Arrays:

- `module_specs.py` is every level as data: its rooms (`module_rooms.py`
  helpers: `screen()`, `hall()`, `route()`, `walk()`, `junction()`, with a
  terminal, dictionaries and files in a band of their own), its brief, its
  blocks, its intended program and the wrong programs it is built to catch.
- `gen_modules.py` writes the scenes with the Arrays generator's painter and
  clutter, `level/module_briefs.gd` (LevelBriefs reads it), and
  `tools/modules/cases.json` (level_checks reads it).
- `finish_modules.py` runs every intended program for its YAML and bakes
  every level's bounds, then regenerates with both and runs `add_catalog.py`,
  which puts the modules into the catalog (rerunnable).

```bash
python tools/modules/finish_modules.py . "$GODOT"
```

**The Arrays generator** (`tools/arrays/`, Python 3, no packages):

- `gen_arrays.py` writes the Arrays scenes from the specs in its `LEVELS`:
  `ar_t2`, `ar_t3` and `ar_4`..`ar_11`, without `ar_9`. `ar_3` is hand-made
  (`HAND_MADE`) and never overwritten. Rooms, boards, the robot's route,
  batteries, the flag, goals and clutter all come from the spec; clutter is
  seeded, so a level comes out the same each time.
- `finish_levels.py` runs each level's "intended" harness case for its YAML and
  `bake_level` for its bounds, then reruns the generator with both.

**Audio** (`tools/audio/balance.py`): see [Sounds](#sounds).
- After generating, paste the generator's `ar_briefs.txt` (written to `%TEMP%`)
  over the Arrays part of `level/level_briefs.gd`.

```bash
python tools/arrays/finish_levels.py . "$GODOT"
```

---

## Making a level

1. **Make the scene.** New scene → inherit `level/level.tscn`, or duplicate
   `level/levels/template.tscn`. Save it in `level/levels/`.
2. **Build the room.** Paint the floor, walls and furniture layers, and place
   the robot under `Visuals/YSorted`. Add the destination, battery and puddle
   areas (`SensedArea` with a tag, plus a sprite). For lists, instance
   `level/objects/entities/list/list_entity.tscn` under `Visuals/Lists/Room1/`.
3. **Add the goals** under `RoomGoals/GoalManager`. For more rooms, add a
   `GoalManagerRoomN` per room, give the robot's `ResettableComponent` one
   snapshot per room, and set the boards' `room_index`.
4. **Set up the blocks.** Put the level's blocks in `GenericBlockProvider` (the
   robot's own provider gives its blocks). Add any preset program under the
   Begin block in `LevelBlockPreset`, or as JSON in its `program`.
5. **Write the brief** in `LevelDescription`: title, mission, rooms, twist, tip,
   and the new blocks with one note each. **Add the same text to
   `level/level_briefs.gd`** (see [Known pitfalls](#known-pitfalls)).
6. **Set the solution.** Write the intended solution, and get its YAML from the
   harness's `yaml` mode. Set `star_slack`.
7. **Add guide pages** in `level/guides.gd` if the level brings in something
   that needs more than a block page.
8. **Add a catalog entry**: a `LevelEntry` in `level_catalog.tres`, in its
   module.

---

## Building and deploying

| Target | Preset | Notes |
|---|---|---|
| Windows | `Windows Desktop` → `unicode.exe` | Ship `unicode_ai.cfg` and `unicode.cfg` next to the `.exe`. |
| Web | `Web` → `unicode.html` | No threads, so no special server headers. Put the files in `ai/public/game/`. The relay serves them, and the bare domain redirects there. |

Deploying the relay (Vercel, plus Render as a fallback) is covered in
[`ai/README.md`](ai/README.md#deploying).

---

## Conventions

**Writing for students.**

- Plain international English for readers of English as a second language. Use
  short whole sentences that keep the small words ("the", "that", "of"), and one
  idea per sentence.
- Use the same words every time:
  - **block names** as titles (Step Forward, Index Of, Begin);
  - **the green flag**, **battery**, **puddle**;
  - **list**, **value**, **index**;
  - **click** for buttons.
- A guide page that waits for the student to do something starts with it, in
  bold: "**Click this button** to hide the room." The sentences after it say
  why. A page that is there to be read has no bold and no "Look at...": its
  arrow already points.
- Never give the answer. A brief says what the room needs, not how. The
  assistant says what happened and where, never what to change.
- Never assume the student remembers the last level. Say it again or show it:
  levels that rebuild a worked example open with a picture of its program.
- No slang, no mixed languages.

**Code style.** Follow the GDScript already there:

- Comments say *why*, especially for anything learned the hard way.
- Use typed GDScript.
- Exported node references, not `$` paths, for anything a scene wires.

**Colours.**

- Yellow `#FFD14D` is the guide accent: highlights, arrows, the loop cursor,
  earned stars. Stars not earned are black.
- Green means right, red means wrong or error.
- Value types have their own colours: variable names pink, strings coral,
  numbers blue, true/false green and red.

---

## Known pitfalls

- **The editor can drop brief fields.** `LevelDescription` isn't a `@tool`
  script, and saving a scene while its script failed to load has dropped its
  exported values. `level/level_briefs.gd` keeps a copy of every brief, and
  fills any field a scene lost (with a warning). Keep the two the same.
- **New `class_name` scripts** aren't visible to `--script` or tool runs until
  the project is imported once: `$GODOT --headless --path . --import`.
- **Fonts have no fallback.** A fallback font's taller line height spread to
  every label in the game. So ★ is drawn with `StarText` (Noto Sans Symbols 2),
  and other symbols should be checked against Atkinson Hyperlegible and Kenney
  Mini before use.
- **The progress code holds 20 levels**, and all 20 are used: ten in
  Iteration, ten in Arrays. So the generated modules' levels are practice
  levels (`counts_for_progress = false`): their stars stay on this computer,
  and they aren't in a code or the study's data. Another scored level needs a new code format; a
  level with `counts_for_progress = false` doesn't take a slot. Adding,
  reordering or cutting a scored level moves other levels' slots, so it needs
  `ProgressCode.VERSION` bumped and the old layout kept in `Progress`, as the
  Arrays rework did. To pull a level without that, retire it.
- **Pixel art scales by whole numbers only.** Sprites are drawn at 1x or 2x so
  their pixels line up with the room's.
- **Tile maps** are stored as base64 `PackedByteArray`s: a 2-byte header, then
  12 bytes per cell (x, y, source, atlas x, atlas y, alternative). They can be
  read and edited outside the editor.
- **Godot's `get_meta(name, null)`** prints an error when the key is missing.
  Check `has_meta()` first.
