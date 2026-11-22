# UniCode

**Block-based software puzzles that teach core programming concepts and abstractions.**

UniCode is a pixel-art puzzle game where you learn programming logic by
snapping together Python-inspired code blocks. It has 93 levels in 10 modules,
from printing to the terminal to reading files, and an AI assistant that gives
hints, not answers. It runs in the browser and on Windows.

It is the thesis project of five Computer Science students at the University
of the East, Manila.

**[Play in your browser](https://unicode-ue.itch.io/unicode)** · **[Website](https://unicode-ue.vercel.app/)**

![The program running: the step forward block is lit, small bubbles show input() giving '4' and int() turning it into 4, and the robot in Room 1 has started walking to the flag.](https://unicode-ue.vercel.app/assets/shots/how-3-run.webp)

## How to play

Every level has four steps.

1. **Read the mission.** Each level gives you a mission, like taking the robot
   to the green flag or showing a line on the terminal, and says how many blocks
   earn three stars.
2. **Build with blocks.** Drag blocks from the Toolbox and attach them under the
   Begin block. Blocks snap into place, so there's no syntax to get wrong.
3. **Press play.** Your program runs one block at a time, in every room of the
   level. The block that's running lights up.
4. **Fix it or win.** If something goes wrong, the game tells you which block
   and why. Solve every room to earn up to three stars.

New blocks come with a short guided tutorial, so you're never thrown in cold.

![The Level complete card with three stars and You used 2 blocks, plus a short comment on the program. Both terminals now show their messages.](https://unicode-ue.vercel.app/assets/shots/how-4-win.webp)

## Features

- **Python-inspired blocks.** Blocks use Python's own words: `print`, `input`,
  `if`, `elif`, `else`, `while`, `for`, `break` and `continue`. What you learn
  carries over to typed code.
- **Watch your program run.** The running block lights up, the robot moves or
  text appears on the terminal, and the Variables tab shows every value as it
  changes.
- **One program, many rooms.** Many levels have two or three rooms with
  different layouts or inputs. One program has to solve them all, so you write
  general rules instead of one-off moves.
- **Python on the side.** Many levels show the matching Python next to the
  mission, like `prices["pen"]`, so the jump to typed code stays small.
- **Learn from mistakes.** When a block can't run, the game marks it and says
  why, like "Variable 'Hello' doesn't exist."
- **Up to three stars.** Solve a level with fewer blocks for more stars. With
  internet, every win ends with a short AI comment on your own program.

## What you'll learn

The modules follow the order of CCP-1101, the first programming course at the
University of the East, which is taught in Python.

| Module | Levels | What it covers |
|---|---|---|
| Tutorial | 3 | How the game works |
| Input and Output | 10 | Showing text with `print` and reading what the user types with `input` |
| Values and Variables | 10 | Keeping values in variables, and putting them into text with f-strings |
| Operators and Expressions | 10 | Working out answers with `+ - * / // % **` and `+=` |
| Selection | 10 | Choosing what to do with `if`, `elif` and `else`, `and` and `or` |
| Loops (Iteration) | 10 | `while` and `for` loops, loops inside loops, `break` and `continue` |
| Functions | 10 | Writing and calling functions, with parameters and return values |
| Lists (Arrays) | 10 | Indexes and length, going through a list, and changing and building lists |
| Dictionaries | 10 | Looking up, adding, changing and removing values by key |
| Text Files | 10 | Reading a file line by line and writing new lines |

## The AI assistant

Stuck? Ask the assistant in the game. It knows the level you're on and what
your program just did, and it guides you with hints and questions. It never
writes out the whole program.

- You can hold up to 10 questions. One comes back every 3 minutes, and solving
  a level for the first time gives you 3 more.
- Your question goes with your current blocks, the result of your last run and
  pictures of the level, through our server to Google's Gemini model, which
  writes the reply. Our server doesn't keep your messages or pictures. It only
  records numbers, like how long a reply took.
- You don't need an account. Your stars and your question count stay on your
  own computer or browser.

## System requirements

| | In the browser | Windows version |
|---|---|---|
| Computer | A desktop or laptop with a mouse | Windows 10 or 11, 64-bit, with a mouse and keyboard |
| Software | An up-to-date Chrome, Edge or Firefox (it needs WebGL 2) | Up-to-date graphics drivers |
| Size | About 45 MB the first time you open it | About 40 MB to download and 105 MB once unzipped |
| Internet | Needed to load the game and for the AI assistant | Only for the AI assistant. Everything else works offline |

Phones and tablets aren't supported yet. On a Mac, play in the browser; the
game can look small on high-resolution Mac screens.


## The research

**UniCode: Block-based Software Puzzles to Teach Core Programming Concepts and
Abstractions**

A research project presented to the Faculty of the College of Computer Studies
and Systems, University of the East, Manila, in partial fulfillment of the
requirements for the degree of Bachelor of Science in Computer Science, 2026.

**The team**

- Barcelon, John Hendrix
- Daniel, Alex Jr.
- Cabeza, Edgar Jr.
- Ebrahim, Musaiden
- Salivio, Johnas Earl

## Credits

- Made with the [Godot Engine](https://godotengine.org/).
- AI replies by Google Gemini.
- Fonts: Kenney Pixel and Kenney Mini by Kenney (CC0), Atkinson Hyperlegible
  by the Braille Institute (SIL Open Font License 1.1), and Noto Sans Symbols 2
  by Google (SIL Open Font License 1.1).

© 2026 UniCode team. All rights reserved.
