# Snake TUI in Bend

A classic Snake game built for the terminal using [Bend](https://github.com/HigherOrderCO/Bend), featuring parallel rendering, formal invariant verification, and interactive TUI gameplay.

---

## Quick Start: Download & Play (Linux)

You do **not** need Bend or any compiler installed on other PCs to play! Simply download the precompiled binary from [GitHub Releases](https://github.com/kidusm001/snake-tui/releases):

```bash
# Download the standalone binary
curl -LO https://github.com/kidusm001/snake-tui/releases/latest/download/snake-tui
chmod +x snake-tui

# Run the game
./snake-tui
```

---

## Zero-Config LAN Multiplayer (Room Auto-Discovery)

Playing with friends on your local Wi-Fi or LAN is completely automated:
1. **Host PC**: Run `./snake-tui` and select:
   - `[2] LAN Co-op (HOST)` or `[4] LAN Versus (HOST)`.
   - The game immediately begins broadcasting a room beacon on the local network.
2. **Joining PC**: Run `./snake-tui` and select:
   - `[3] LAN Co-op (JOIN)` or `[5] LAN Versus (JOIN)`.
   - The joining PC automatically detects the room beacon, discovers the host's IP address, and connects in seconds — **zero manual IP entry needed!**
   - *(Optional fallback)*: If your router or local firewall blocks UDP broadcasts, it gracefully switches to direct IP input so you can still connect manually.

---

## Playing with VPNs & Over the Internet (Tailscale)

### 1. Consumer VPNs on Local Wi-Fi (NordVPN, Mullvad, Proton, ExpressVPN)
By default, commercial VPNs enable **LAN isolation / kill switch** (blocking traffic to private subnets like `192.168.x.x` to prevent leaks). To play on local Wi-Fi while keeping your VPN connected, enable local network sharing:
- **NordVPN**: Run `nordvpn set lan-discovery enable` (or toggle "LAN Discovery" in settings).
- **Mullvad**: Run `mullvad lan set allow` (or Settings ➔ VPN settings ➔ Local network sharing ON).
- **ProtonVPN**: Settings ➔ Advanced ➔ Enable "Allow LAN connections".
- **ExpressVPN**: Options ➔ General ➔ Check "Allow access to devices on local network".
- **Surfshark**: Settings ➔ VPN Settings ➔ Toggle "Invisible on LAN" OFF.
- **Private Internet Access (PIA)**: Settings ➔ Network ➔ Check "Allow LAN Traffic".
- **WireGuard**: In your `.conf`, make sure `AllowedIPs` does not capture your physical subnet.

### 2. Playing from Anywhere in the World (Tailscale / ZeroTier)
You don't need port forwarding, router configuration, or even to be on the same Wi-Fi! You can play across different cities or networks using [Tailscale](https://tailscale.com):
1. Both players install Tailscale.
2. The host runs `./snake-tui` and selects Host (the room screen will automatically detect and show your **Tailscale IP**, e.g. `100.x.y.z`).
3. The joining player selects Join, and enters the host's Tailscale IP at the prompt.
4. Enjoy encrypted, low-latency multiplayer from anywhere in the world!

---

## Features

- **Pure Functional Logic**: The core game mechanics in [`snake.bend`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/snake.bend) are 100% pure, deterministic, and formally verified.
- **Multiple Game Modes**:
  - **Solo Classic**: Traditional 1-player high score chase with persistent binary records.
  - **Co-op Mode (2 Players, 1 Snake)**: Two players steer the same snake cooperatively! Playable over LAN or on the same keyboard.
  - **Versus Mode (2 Snakes Duel)**: Green Snake (P1) vs Purple Snake (P2) battling for apples in the same arena. Crashing into the opponent or walls results in death! Playable over LAN or on the same keyboard.
- **LAN Multiplayer Networking**: Built-in peer-to-peer TCP networking with automatic local IP discovery, zero-desync deterministic lockstep input exchange, and manual host IP prompts.
- **Parallel Grid Rendering**: Utilizes Bend's parallel call primitives (`a b = f(...) g(...)`) in [`snake.bend`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/snake.bend) to render quadrants and rows in parallel across CPU/GPU cores.
- **Formal Verification (Laws & Proofs)**:
  - [`LAWS.bend`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/LAWS.bend): Mathematical definitions of game invariants (direction reversal prevention, movement coordinates, out-of-bounds safety, growth mechanics, safe food generation, co-op turn steering, versus collision resolution).
  - [`PROOF.bend`](file:///home/Kidus.Mesfin/workspace/github.com/kidusm001/snake-tui/PROOF.bend): Formal proofs checked by Bend's theorem prover (`bend PROOF.bend` passes with `ALL PROOFS CHECK`).
- **Persistent High Score Tracking**: Real-time high score updates during gameplay, saved automatically to disk (`highscore.bin`), preserved across sessions, and highlighted with celebratory game-over banners (`🎉 NEW HIGH SCORE! 🏆`).
- **Textured Scale Snake Graphics**: Reptile-scale shaded body (`▓▓` / `▒▒`), bright solid lime & magenta heads (`██`), red apple (`🍎`), crash indicator (`✖✖`), and neon blue double-line arcade cabinet (`╔═══╗`, `║   ║`, `╚═══╝`).
- **Low-Latency TUI**: Raw mode terminal driver with ANSI colors, non-blocking keyboard polling, and arrow key escape sequence parsing.

---

## Game Modes & Controls

### Main Menu
Select your mode at launch:
- `[1]` Solo Classic
- `[2]` LAN Co-op (HOST)
- `[3]` LAN Co-op (JOIN)
- `[4]` LAN Versus (HOST)
- `[5]` LAN Versus (JOIN)
- `[6]` Local Co-op (1 Keyboard)
- `[7]` Local Versus (1 Keyboard)
- `[Q]` Quit

### In-Game Controls
- **Solo & LAN Play**: Use `W/A/S/D` or Arrow Keys `↑/←/↓/→` (each player controls their own screen).
- **Local 2-Player (Same Keyboard)**:
  - **Player 1**: `W` (Up), `A` (Left), `S` (Down), `D` (Right)
  - **Player 2**: `↑` (Up), `←` (Left), `↓` (Down), `→` (Right) or `I/J/K/L`
- **Global**:
  - `R`: Restart game
  - `Q` / `Esc`: Quit / Cancel

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
