import Base

type Dir is Data:
  Up{}
  Down{}
  Left{}
  Right{}

type Pos is Data:
  Pos{x: U32, y: U32}

type GameState is Data:
  Game{head: Pos, body: +List<Pos>, dir: Dir, food: Pos, score: U32, alive: Bool, seed: U32}

def opp(d: Dir) -> Dir:
  match d:
    case Up{}:
      Down{}
    case Down{}:
      Up{}
    case Left{}:
      Right{}
    case Right{}:
      Left{}

def is_opposite(+cur: Dir, +next: Dir) -> Bool:
  match cur next:
    case Up{} Down{}:
      True{}
    case Down{} Up{}:
      True{}
    case Left{} Right{}:
      True{}
    case Right{} Left{}:
      True{}
    case _ _:
      False{}

def turn_select(cur: Dir, next: Dir, is_opp: Bool) -> Dir:
  match is_opp:
    case True{}:
      cur
    case False{}:
      next

def turn(+cur: Dir, +next: Dir) -> Dir:
  turn_select(cur, next, is_opposite(cur, next))

def key_to_dir(+k: U32, +cur: Dir) -> Dir:
  match k:
    case 119:
      turn(cur, Up{})
    case 107:
      turn(cur, Up{})
    case 115:
      turn(cur, Down{})
    case 106:
      turn(cur, Down{})
    case 97:
      turn(cur, Left{})
    case 104:
      turn(cur, Left{})
    case 100:
      turn(cur, Right{})
    case 108:
      turn(cur, Right{})
    case _:
      cur

def pos_eq(+a: Pos, +b: Pos) -> Bool:
  Pos{+ax, +ay} = a
  Pos{+bx, +by} = b
  eq_x = U32.is_eq(ax, bx)
  eq_y = U32.is_eq(ay, by)
  eq_x && eq_y

def move_pos(p: Pos, d: Dir) -> Pos:
  match p d:
    case Pos{+x, +y} Up{}:
      Pos{x, (y - 1 : U32)}
    case Pos{+x, +y} Down{}:
      Pos{x, (y + 1 : U32)}
    case Pos{+x, +y} Left{}:
      Pos{(x - 1 : U32), y}
    case Pos{+x, +y} Right{}:
      Pos{(x + 1 : U32), y}

def is_out_of_bounds(+p: Pos, +w: U32, +h: U32) -> Bool:
  Pos{+x, +y} = p
  bad_x = (x >= w : U32)
  bad_y = (y >= h : U32)
  bad_x || bad_y

def contains_pos(+body: +List<Pos>, +target: Pos) -> Bool:
  match body:
    case Nil{}:
      False{}
    case Con{h, t}:
      pos_eq(target, h) || contains_pos(t, target)

def drop_last(xs: +List<Pos>) -> +List<Pos>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      match t:
        case Nil{}:
          Nil{}
        case Con{th, tt}:
          Con{h, drop_last(Con{th, tt})}

def grow(head: Pos, body: +List<Pos>) -> +List<Pos>:
  {Con{head, body} : +List<Pos>}

def next_seed(+seed: U32) -> U32:
  (seed * 1664525 + 1013904223 : U32)

def gen_food(+seed: U32, +w: U32, +h: U32) -> Pos & U32:
  +s1 = next_seed(seed)
  x = (s1 % w : U32)
  +s2 = next_seed(s1)
  y = (s2 % h : U32)
  (Pos{x, y}, s2)

def make_ate_game(food_seed: Pos & U32, new_head: Pos, new_body: +List<Pos>, new_dir: Dir, new_score: U32) -> GameState:
  (new_food, new_seed) = food_seed
  Game{new_head, new_body, new_dir, new_food, new_score, True{}, new_seed}

def step_food(ate: Bool, +new_head: Pos, head: Pos, body: +List<Pos>, +new_dir: Dir, food: Pos, +score: U32, +seed: U32, +w: U32, +h: U32) -> GameState:
  match ate:
    case True{}:
      new_body = grow(head, body)
      new_score = (score + 10 : U32)
      make_ate_game(gen_food(seed, w, h), new_head, new_body, new_dir, new_score)
    case False{}:
      new_body = grow(head, drop_last(body))
      Game{new_head, new_body, new_dir, food, score, True{}, seed}

def step_alive(dead: Bool, +new_head: Pos, head: Pos, body: +List<Pos>, +new_dir: Dir, +food: Pos, +score: U32, +seed: U32, +w: U32, +h: U32) -> GameState:
  match dead:
    case True{}:
      Game{head, body, new_dir, food, score, False{}, seed}
    case False{}:
      ate = pos_eq(new_head, food)
      step_food(ate, new_head, head, body, new_dir, food, score, seed, w, h)

def step_active(g: GameState, +key: U32, +w: U32, +h: U32) -> GameState:
  Game{+head, +body, +dir, +food, +score, alive, +seed} = g
  match alive:
    case False{}:
      Game{head, body, dir, food, score, False{}, seed}
    case True{}:
      +new_dir = key_to_dir(key, dir)
      +new_head = move_pos(head, new_dir)
      hit_wall = is_out_of_bounds(new_head, w, h)
      hit_self = contains_pos(body, new_head)
      dead = hit_wall || hit_self
      step_alive(dead, new_head, head, body, new_dir, food, score, seed, w, h)

def step_game(g: GameState, key: U32, w: U32, h: U32) -> GameState:
  step_active(g, key, w, h)

def new_game(+seed: U32) -> GameState:
  Game{Pos{8, 6}, {[Pos{7, 6}, Pos{6, 6}] : +List<Pos>}, Right{}, Pos{14, 6}, 0, True{}, seed}

# Rendering
def head_alive_glyph(d: Dir) -> String:
  match d:
    case Up{}:
      "\u{1b}[1;32m▲ \u{1b}[0m"
    case Down{}:
      "\u{1b}[1;32m▼ \u{1b}[0m"
    case Left{}:
      "\u{1b}[1;32m◄ \u{1b}[0m"
    case Right{}:
      "\u{1b}[1;32m► \u{1b}[0m"

def head_glyph(alive: Bool, d: Dir) -> String:
  match alive:
    case True{}:
      head_alive_glyph(d)
    case False{}:
      "\u{1b}[1;31m✖ \u{1b}[0m"

def cell_char_body(is_body: Bool) -> String:
  match is_body:
    case True{}:
      "\u{1b}[32m● \u{1b}[0m"
    case False{}:
      "\u{1b}[90m· \u{1b}[0m"

def cell_char_food(is_food: Bool, is_body: Bool) -> String:
  match is_food:
    case True{}:
      "\u{1b}[1;31m★ \u{1b}[0m"
    case False{}:
      cell_char_body(is_body)

def cell_char_head(is_head: Bool, is_food: Bool, is_body: Bool, alive: Bool, d: Dir) -> String:
  match is_head:
    case True{}:
      head_glyph(alive, d)
    case False{}:
      cell_char_food(is_food, is_body)

def cell_char(+target: Pos, +head: Pos, +food: Pos, +body: +List<Pos>, +alive: Bool, +d: Dir) -> String:
  is_head = pos_eq(target, head)
  is_food = pos_eq(target, food)
  is_body = contains_pos(body, target)
  cell_char_head(is_head, is_food, is_body, alive, d)

def render_cells(fuel: Nat, +x: U32, +y: U32, +head: Pos, +food: Pos, +body: +List<Pos>, +alive: Bool, +d: Dir) -> String:
  match fuel:
    case 0n:
      ""
    case 1n+p:
      c = cell_char(Pos{x, y}, head, food, body, alive, d)
      c ++ render_cells(p, (x + 1 : U32), y, head, food, body, alive, d)

def render_row(+y: U32, +w_nat: Nat, +head: Pos, +food: Pos, +body: +List<Pos>, +alive: Bool, +d: Dir) -> String:
  "\u{1b}[1;36m│\u{1b}[0m" ++ render_cells(w_nat, 0, y, head, food, body, alive, d) ++ "\u{1b}[1;36m│\u{1b}[0m\n"

def render_quad(+y: U32, +w_nat: Nat, +head: Pos, +food: Pos, +body: +List<Pos>, +alive: Bool, +d: Dir) -> String:
  r0 r1 = render_row(y, w_nat, head, food, body, alive, d) render_row((y + 1 : U32), w_nat, head, food, body, alive, d)
  r2 r3 = render_row((y + 2 : U32), w_nat, head, food, body, alive, d) render_row((y + 3 : U32), w_nat, head, food, body, alive, d)
  (r0 ++ r1) ++ (r2 ++ r3)

def render_grid_par(+w_nat: Nat, +head: Pos, +food: Pos, +body: +List<Pos>, +alive: Bool, +d: Dir) -> String:
  q0 q1 = render_quad(0, w_nat, head, food, body, alive, d) render_quad(4, w_nat, head, food, body, alive, d)
  q2 q3 = render_quad(8, w_nat, head, food, body, alive, d) render_quad(12, w_nat, head, food, body, alive, d)
  (q0 ++ q1) ++ (q2 ++ q3)

def render_status(alive: Bool, score: U32) -> String:
  match alive:
    case True{}:
      "\u{1b}[1;37mScore: \u{1b}[1;32m" ++ U32.show(score) ++ "\u{1b}[0m   \u{1b}[90m│\u{1b}[0m   \u{1b}[37mControls: [W/A/S/D] or [↑/←/↓/→], [R] Restart, [Q] Quit\u{1b}[0m\n"
    case False{}:
      "\u{1b}[1;31m💀  GAME OVER!  💀\u{1b}[0m   \u{1b}[1;37mFinal Score: \u{1b}[1;32m" ++ U32.show(score) ++ "\u{1b}[0m   \u{1b}[90m│\u{1b}[0m   \u{1b}[1;33m[R]\u{1b}[0m Restart  \u{1b}[1;33m[Q]\u{1b}[0m Quit\n"

def render_frame(g: GameState, +w_nat: Nat) -> String:
  Game{+head, +body, +dir, +food, +score, +alive, +seed} = g
  header = {"\u{1b}[H\u{1b}[1;33m🐍  BEND SNAKE TUI  🐍\u{1b}[0m\n" : String}
  border_top = {"\u{1b}[1;36m╭────────────────────────────────────────────────╮\u{1b}[0m\n" : String}
  border_bot = {"\u{1b}[1;36m╰────────────────────────────────────────────────╯\u{1b}[0m\n" : String}
  grid = render_grid_par(w_nat, head, food, body, alive, dir)
  status = render_status(alive, score)
  (header ++ status) ++ (border_top ++ grid ++ border_bot)
