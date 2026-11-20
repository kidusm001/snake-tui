# Snake TUI in Bend

A classic Snake game built for the terminal using [Bend](https://github.com/HigherOrderCO/Bend), featuring parallel rendering, formal invariant verification, and interactive TUI gameplay.

---

## Features

- **Pure Functional Logic**: The core game mechanics in [`snake.bend`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/snake.bend) are 100% pure, deterministic, and formally verified.
- **Parallel Grid Rendering**: Utilizes Bend's parallel call primitives (`a b = f(...) g(...)`) in [`snake.bend`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/snake.bend) to render quadrants and rows in parallel across CPU/GPU cores.
- **Formal Verification (Laws & Proofs)**:
  - [`LAWS.bend`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/LAWS.bend): Mathematical definitions of game invariants (direction reversal prevention, movement coordinates, out-of-bounds safety, growth mechanics, collision correctness).
  - [`PROOF.bend`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/PROOF.bend): Formal proofs checked by Bend's theorem prover (`bend PROOF.bend` passes with `ALL PROOFS CHECK`).
- **Vibrant Arcade Graphics**: Double-line neon cabinet borders (`╔═══╗`, `║   ║`, `╚═══╝`), solid green snake body blocks (`🟩`), green head (`🟢`), juicy red apple (`🍎`), and crash skull (`💀`).
- **Low-Latency TUI**: Raw mode terminal driver with ANSI colors, non-blocking keyboard polling, and arrow key escape sequence parsing.

---

## Controls

| Key | Action |
|---|---|
| `W` / `↑` / `K` | Move Up |
| `S` / `↓` / `J` | Move Down |
| `A` / `←` / `H` | Move Left |
| `D` / `→` / `L` | Move Right |
| `R` | Restart (after game over or during play) |
| `Q` / `Esc` | Quit game |

---

## How to Run

### 1. Run directly with Bend
```bash
bend main.bend
```

### 2. Compile to a high-performance native binary
```bash
bend main.bend -o snake-tui
./snake-tui
```

---

## Verifying Proofs

To run the formal theorem verification:
```bash
bend PROOF.bend
```
Output:
```
ALL PROOFS CHECK
Use --verdict for mathematical validity.
```

---

## Project Structure

- [`snake.bend`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/snake.bend): Pure Snake state transitions, collision detection, food generation, and parallel rendering.
- [`LAWS.bend`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/LAWS.bend): Formal laws defining game invariants.
- [`PROOF.bend`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/PROOF.bend): Proof implementations verifying all rules in `LAWS.bend`.
- [`terminal.bend`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/terminal.bend): Effect declarations for raw terminal manipulation.
- [`terminal.c`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/terminal.c): C effect implementation for native builds.
- [`terminal.js`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/terminal.js): JS effect implementation for direct `bend` execution.
- [`main.bend`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/main.bend): Interactive TUI event loop and entrypoint.
- [`AGENTS.md`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/AGENTS.md): Development instructions for Bend agents.
