import Base

type Dir is Data:
  Up{}
  Down{}
  Left{}
  Right{}

type Diff is Data:
  Easy{}
  Normal{}
  Hard{}
  Turbo{}

def next_diff(d: Diff) -> Diff:
  match d:
    case Easy{}:
      Normal{}
    case Normal{}:
      Hard{}
    case Hard{}:
      Turbo{}
    case Turbo{}:
      Easy{}

def prev_diff(d: Diff) -> Diff:
  match d:
    case Easy{}:
      Turbo{}
    case Normal{}:
      Easy{}
    case Hard{}:
      Normal{}
    case Turbo{}:
      Hard{}

def diff_to_u32(d: Diff) -> U32:
  match d:
    case Easy{}:
      0
    case Normal{}:
      1
    case Hard{}:
      2
    case Turbo{}:
      3

def u32_to_diff(+n: U32) -> Diff:
  match n:
    case 0:
      Easy{}
    case 1:
      Normal{}
    case 2:
      Hard{}
    case 3:
      Turbo{}
    case _:
      Normal{}

def min_u32_select(+a: U32, +b: U32, a_le_b: Bool) -> U32:
  match a_le_b:
    case True{}:
      a
    case False{}:
      b

def min_u32(+a: U32, +b: U32) -> U32:
  min_u32_select(a, b, (a <= b : U32))

def tick_clamp(+base: U32, +drop: U32, +floor_ms: U32) -> U32:
  max_drop = (base - floor_ms : U32)
  use_drop = min_u32(drop, max_drop)
  (base - use_drop : U32)

def calc_tick_ms(d: Diff, +score: U32) -> U32:
  match d:
    case Easy{}:
      165
    case Normal{}:
      tick_clamp(120, (score / 10 : U32), 75)
    case Hard{}:
      tick_clamp(85, (score / 8 : U32), 55)
    case Turbo{}:
      tick_clamp(60, (score / 8 : U32), 40)

def diff_badge(d: Diff) -> String:
  match d:
    case Easy{}:
      "\u{1b}[1;32m[🐢 Easy]\u{1b}[0m"
    case Normal{}:
      "\u{1b}[1;36m[🐍 Normal]\u{1b}[0m"
    case Hard{}:
      "\u{1b}[1;33m[🔥 Hard]\u{1b}[0m"
    case Turbo{}:
      "\u{1b}[1;31m[⚡ Turbo]\u{1b}[0m"

type Pos is Data:
  Pos{x: U32, y: U32}

def max_score_select(+a: U32, +b: U32, a_ge_b: Bool) -> U32:
  match a_ge_b:
    case True{}:
      a
    case False{}:
      b

def max_score(+a: U32, +b: U32) -> U32:
  max_score_select(a, b, (a >= b : U32))

type GameState is Data:
  Game{head: Pos, body: +List<Pos>, dir: Dir, food: Pos, score: U32, high_score: U32, alive: Bool, seed: U32}

def get_high_score(g: GameState) -> U32:
  Game{head, body, dir, food, score, high_score, alive, seed} = g
  high_score

def get_score(g: GameState) -> U32:
  Game{head, body, dir, food, score, high_score, alive, seed} = g
  score

def is_alive(g: GameState) -> Bool:
  Game{head, body, dir, food, score, high_score, alive, seed} = g
  alive

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
    case 200:
      turn(cur, Up{})
    case 105:
      turn(cur, Up{})
    case 115:
      turn(cur, Down{})
    case 201:
      turn(cur, Down{})
    case 107:
      turn(cur, Down{})
    case 97:
      turn(cur, Left{})
    case 202:
      turn(cur, Left{})
    case 106:
      turn(cur, Left{})
    case 100:
      turn(cur, Right{})
    case 203:
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

type FoodSeed is Data:
  FoodSeed{pos: Pos, seed: U32}

def is_snake_cell(+p: Pos, +head: Pos, +body: +List<Pos>) -> Bool:
  pos_eq(p, head) || contains_pos(body, p)

def gen_food_candidate(+seed: U32, +w: U32, +h: U32) -> FoodSeed:
  +s1 = next_seed(seed)
  x = (s1 % w : U32)
  +s2 = next_seed(s1)
  y = (s2 % h : U32)
  FoodSeed{Pos{x, y}, s2}

def pick_food(hit: Bool, cand: FoodSeed, next_food: FoodSeed) -> FoodSeed:
  match hit:
    case False{}:
      cand
    case True{}:
      next_food

def pick_cand(+cand: FoodSeed, next_food: FoodSeed, +head: Pos, +body: +List<Pos>) -> FoodSeed:
  FoodSeed{+pos, +seed} = cand
  hit = is_snake_cell(pos, head, body)
  pick_food(hit, cand, next_food)

def gen_food_safe(fuel: Nat, +seed: U32, +head: Pos, +body: +List<Pos>, +w: U32, +h: U32) -> FoodSeed:
  match fuel:
    case 0n:
      FoodSeed{Pos{1, 1}, seed}
    case 1n+p:
      +cand = gen_food_candidate(seed, w, h)
      +s_next = next_seed(next_seed(seed))
      next_food = gen_food_safe(p, s_next, head, body, w, h)
      pick_cand(cand, next_food, head, body)

def make_ate_game(food_seed: FoodSeed, new_head: Pos, new_body: +List<Pos>, new_dir: Dir, new_score: U32, new_high: U32) -> GameState:
  FoodSeed{new_food, new_seed} = food_seed
  Game{new_head, new_body, new_dir, new_food, new_score, new_high, True{}, new_seed}

def step_food(ate: Bool, +new_head: Pos, head: Pos, body: +List<Pos>, +new_dir: Dir, food: Pos, +score: U32, +high_score: U32, +seed: U32, +w: U32, +h: U32) -> GameState:
  match ate:
    case True{}:
      +new_body = grow(head, body)
      +new_score = (score + 10 : U32)
      new_high = max_score(high_score, new_score)
      safe_food = gen_food_safe(32n, seed, new_head, new_body, w, h)
      make_ate_game(safe_food, new_head, new_body, new_dir, new_score, new_high)
    case False{}:
      new_body = grow(head, drop_last(body))
      Game{new_head, new_body, new_dir, food, score, high_score, True{}, seed}

def step_alive(dead: Bool, +new_head: Pos, head: Pos, body: +List<Pos>, +new_dir: Dir, +food: Pos, +score: U32, +high_score: U32, +seed: U32, +w: U32, +h: U32) -> GameState:
  match dead:
    case True{}:
      Game{head, body, new_dir, food, score, high_score, False{}, seed}
    case False{}:
      ate = pos_eq(new_head, food)
      step_food(ate, new_head, head, body, new_dir, food, score, high_score, seed, w, h)

def step_active(g: GameState, +key: U32, +w: U32, +h: U32) -> GameState:
  Game{+head, +body, +dir, +food, +score, +high_score, alive, +seed} = g
  match alive:
    case False{}:
      Game{head, body, dir, food, score, high_score, False{}, seed}
    case True{}:
      +new_dir = key_to_dir(key, dir)
      +new_head = move_pos(head, new_dir)
      hit_wall = is_out_of_bounds(new_head, w, h)
      hit_self = contains_pos(body, new_head)
      dead = hit_wall || hit_self
      step_alive(dead, new_head, head, body, new_dir, food, score, high_score, seed, w, h)

def step_game(g: GameState, key: U32, w: U32, h: U32) -> GameState:
  step_active(g, key, w, h)

def new_game(+seed: U32, +high_score: U32) -> GameState:
  Game{Pos{8, 6}, {[Pos{7, 6}, Pos{6, 6}] : +List<Pos>}, Right{}, Pos{14, 6}, 0, high_score, True{}, seed}

# Rendering
def head_glyph(alive: Bool) -> String:
  match alive:
    case True{}:
      "\u{1b}[38;5;82m██\u{1b}[0m"
    case False{}:
      "\u{1b}[1;31m✖✖\u{1b}[0m"

def cell_char_body(is_body: Bool) -> String:
  match is_body:
    case True{}:
      "\u{1b}[38;5;40m▓▓\u{1b}[0m"
    case False{}:
      "  "

def cell_char_food(is_food: Bool, is_body: Bool) -> String:
  match is_food:
    case True{}:
      "🍎"
    case False{}:
      cell_char_body(is_body)

def cell_char_head(is_head: Bool, is_food: Bool, is_body: Bool, alive: Bool) -> String:
  match is_head:
    case True{}:
      head_glyph(alive)
    case False{}:
      cell_char_food(is_food, is_body)

def cell_char(+target: Pos, +head: Pos, +food: Pos, +body: +List<Pos>, +alive: Bool) -> String:
  is_head = pos_eq(target, head)
  is_food = pos_eq(target, food)
  is_body = contains_pos(body, target)
  cell_char_head(is_head, is_food, is_body, alive)

def render_cells(fuel: Nat, +x: U32, +y: U32, +head: Pos, +food: Pos, +body: +List<Pos>, +alive: Bool) -> String:
  match fuel:
    case 0n:
      ""
    case 1n+p:
      c = cell_char(Pos{x, y}, head, food, body, alive)
      c ++ render_cells(p, (x + 1 : U32), y, head, food, body, alive)

def render_row(+y: U32, +w_nat: Nat, +head: Pos, +food: Pos, +body: +List<Pos>, +alive: Bool) -> String:
  "\u{1b}[38;5;39m║\u{1b}[0m" ++ render_cells(w_nat, 0, y, head, food, body, alive) ++ "\u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n"

def render_quad(+y: U32, +w_nat: Nat, +head: Pos, +food: Pos, +body: +List<Pos>, +alive: Bool) -> String:
  r0 r1 = render_row(y, w_nat, head, food, body, alive) render_row((y + 1 : U32), w_nat, head, food, body, alive)
  r2 r3 = render_row((y + 2 : U32), w_nat, head, food, body, alive) render_row((y + 3 : U32), w_nat, head, food, body, alive)
  (r0 ++ r1) ++ (r2 ++ r3)

def render_grid_par(+w_nat: Nat, +head: Pos, +food: Pos, +body: +List<Pos>, +alive: Bool) -> String:
  q0 q1 = render_quad(0, w_nat, head, food, body, alive) render_quad(4, w_nat, head, food, body, alive)
  q2 q3 = render_quad(8, w_nat, head, food, body, alive) render_quad(12, w_nat, head, food, body, alive)
  (q0 ++ q1) ++ (q2 ++ q3)

def render_game_over(is_new_high: Bool, score: U32, high_score: U32) -> String:
  match is_new_high:
    case True{}:
      "\u{1b}[1;32m🎉 NEW HIGH SCORE! 🏆 " ++ U32.show(score) ++ " 🎉\u{1b}[0m   \u{1b}[90m│\u{1b}[0m   \u{1b}[1;33m[R]\u{1b}[0m Play Again   \u{1b}[90m│\u{1b}[0m   \u{1b}[1;33m[Q]\u{1b}[0m Quit\u{1b}[K\n"
    case False{}:
      "\u{1b}[1;31m💀 GAME OVER!\u{1b}[0m   \u{1b}[1;37mScore: \u{1b}[1;32m" ++ U32.show(score) ++ "\u{1b}[0m   \u{1b}[1;37m🏆 Best: \u{1b}[1;33m" ++ U32.show(high_score) ++ "\u{1b}[0m   \u{1b}[90m│\u{1b}[0m   \u{1b}[1;33m[R]\u{1b}[0m Play Again   \u{1b}[90m│\u{1b}[0m   \u{1b}[1;33m[Q]\u{1b}[0m Quit\u{1b}[K\n"

def render_status(alive: Bool, +score: U32, +high_score: U32) -> String:
  match alive:
    case True{}:
      "\u{1b}[1;37m🍎 Score: \u{1b}[1;32m" ++ U32.show(score) ++ "\u{1b}[0m   \u{1b}[1;37m🏆 Best: \u{1b}[1;33m" ++ U32.show(high_score) ++ "\u{1b}[0m   \u{1b}[90m│\u{1b}[0m   \u{1b}[37mControls: [W/A/S/D] or [↑/←/↓/→]\u{1b}[0m   \u{1b}[90m│\u{1b}[0m   \u{1b}[33m[R]\u{1b}[0m Restart  \u{1b}[33m[Q]\u{1b}[0m Quit\u{1b}[K\n"
    case False{}:
      is_new = (score >= high_score : U32) && (score > 0 : U32)
      render_game_over(is_new, score, high_score)

def render_frame(g: GameState, +w_nat: Nat, d: Diff) -> String:
  Game{+head, +body, +dir, +food, +score, +high_score, +alive, +seed} = g
  badge = diff_badge(d)
  header = {"\u{1b}[H\u{1b}[1;33m🐍  BEND SNAKE ARCADE  🐍\u{1b}[0m   " ++ badge ++ "\u{1b}[K\n" : String}
  border_top = {"\u{1b}[38;5;39m╔════════════════════════════════════════════════╗\u{1b}[0m\u{1b}[K\n" : String}
  border_bot = {"\u{1b}[38;5;39m╚════════════════════════════════════════════════╝\u{1b}[0m\u{1b}[K\u{1b}[J\n" : String}
  grid = render_grid_par(w_nat, head, food, body, alive)
  status = render_status(alive, score, high_score)
  (header ++ status) ++ (border_top ++ grid ++ border_bot)

# Co-op Mode: 2 Players Steering 1 Snake
def turn_coop(+cur: Dir, +k1: U32, +k2: U32) -> Dir:
  +d1 = key_to_dir(k1, cur)
  key_to_dir(k2, d1)

def step_coop(g: GameState, +k1: U32, +k2: U32, +w: U32, +h: U32) -> GameState:
  Game{+head, +body, +dir, +food, +score, +high_score, alive, +seed} = g
  match alive:
    case False{}:
      Game{head, body, dir, food, score, high_score, False{}, seed}
    case True{}:
      +new_dir = turn_coop(dir, k1, k2)
      +new_head = move_pos(head, new_dir)
      hit_wall = is_out_of_bounds(new_head, w, h)
      hit_self = contains_pos(body, new_head)
      dead = hit_wall || hit_self
      step_alive(dead, new_head, head, body, new_dir, food, score, high_score, seed, w, h)

def render_coop_status(alive: Bool, +score: U32, +high_score: U32) -> String:
  match alive:
    case True{}:
      "\u{1b}[1;37m🍎 Co-op Score: \u{1b}[1;32m" ++ U32.show(score) ++ "\u{1b}[0m   \u{1b}[1;37m🏆 Best: \u{1b}[1;33m" ++ U32.show(high_score) ++ "\u{1b}[0m   \u{1b}[90m│\u{1b}[0m   \u{1b}[36m[P1: Host] [P2: Client]\u{1b}[0m   \u{1b}[90m│\u{1b}[0m   \u{1b}[33m[R]\u{1b}[0m Restart  \u{1b}[33m[Q]\u{1b}[0m Quit\u{1b}[K\n"
    case False{}:
      is_new = (score >= high_score : U32) && (score > 0 : U32)
      render_game_over(is_new, score, high_score)

def render_coop_frame(g: GameState, +w_nat: Nat, d: Diff) -> String:
  Game{+head, +body, +dir, +food, +score, +high_score, +alive, +seed} = g
  badge = diff_badge(d)
  header = {"\u{1b}[H\u{1b}[1;33m🐍  BEND SNAKE CO-OP (2 PLAYERS, 1 SNAKE)  🐍\u{1b}[0m   " ++ badge ++ "\u{1b}[K\n" : String}
  border_top = {"\u{1b}[38;5;39m╔════════════════════════════════════════════════╗\u{1b}[0m\u{1b}[K\n" : String}
  border_bot = {"\u{1b}[38;5;39m╚════════════════════════════════════════════════╝\u{1b}[0m\u{1b}[K\u{1b}[J\n" : String}
  grid = render_grid_par(w_nat, head, food, body, alive)
  status = render_coop_status(alive, score, high_score)
  (header ++ status) ++ (border_top ++ grid ++ border_bot)

# Versus Mode: 2 Snakes Duel
type VersusWinner is Data:
  Active{}
  P1Win{}
  P2Win{}
  Draw{}

type VersusState is Data:
  VersusGame{
    head1: Pos,
    body1: +List<Pos>,
    dir1: Dir,
    alive1: Bool,
    score1: U32,
    head2: Pos,
    body2: +List<Pos>,
    dir2: Dir,
    alive2: Bool,
    score2: U32,
    food: Pos,
    winner: VersusWinner,
    seed: U32
  }

def new_versus_game(+seed: U32) -> VersusState:
  +s1 = next_seed(seed)
  +s2 = next_seed(s1)
  +s3 = next_seed(s2)
  +s4 = next_seed(s3)
  +s5 = next_seed(s4)
  +s6 = next_seed(s5)
  +x1 = (((s1 % 6) + 3) : U32)
  +y1 = (((s2 % 10) + 3) : U32)
  +h1 = {Pos{x1, y1} : Pos}
  +b1 = {[Pos{((x1 - 1) : U32), y1}, Pos{((x1 - 2) : U32), y1}] : +List<Pos>}
  +x2 = (((s3 % 6) + 15) : U32)
  +y2 = (((s4 % 10) + 3) : U32)
  +h2 = {Pos{x2, y2} : Pos}
  +b2 = {[Pos{((x2 + 1) : U32), y2}, Pos{((x2 + 2) : U32), y2}] : +List<Pos>}
  +fx = (((s5 % 5) + 10) : U32)
  +fy = (((s6 % 10) + 3) : U32)
  VersusGame{h1, b1, Right{}, True{}, 0, h2, b2, Left{}, True{}, 0, Pos{fx, fy}, Active{}, s6}

def get_versus_seed(vg: VersusState) -> U32:
  VersusGame{+h1, +b1, +d1, +a1, +s1, +h2, +b2, +d2, +a2, +s2, +food, +winner, seed} = vg
  seed

def is_versus_over(vg: VersusState) -> Bool:
  VersusGame{+h1, +b1, +d1, +a1, +s1, +h2, +b2, +d2, +a2, +s2, +food, winner, +seed} = vg
  match winner:
    case Active{}:
      False{}
    case _:
      True{}

def versus_outcome(c1: Bool, c2: Bool) -> VersusWinner:
  match c1 c2:
    case True{} True{}:
      Draw{}
    case True{} False{}:
      P2Win{}
    case False{} True{}:
      P1Win{}
    case False{} False{}:
      Active{}

def is_in_snakes(+p: Pos, +h1: Pos, +b1: +List<Pos>, +h2: Pos, +b2: +List<Pos>) -> Bool:
  is_snake_cell(p, h1, b1) || is_snake_cell(p, h2, b2)

def pick_versus_cand(+cand: FoodSeed, next_food: FoodSeed, +h1: Pos, +b1: +List<Pos>, +h2: Pos, +b2: +List<Pos>) -> FoodSeed:
  FoodSeed{+pos, +seed} = cand
  hit = is_in_snakes(pos, h1, b1, h2, b2)
  pick_food(hit, cand, next_food)

def gen_versus_food_safe(fuel: Nat, +seed: U32, +h1: Pos, +b1: +List<Pos>, +h2: Pos, +b2: +List<Pos>, +w: U32, +h: U32) -> FoodSeed:
  match fuel:
    case 0n:
      FoodSeed{Pos{12, 8}, seed}
    case 1n+p:
      +cand = gen_food_candidate(seed, w, h)
      +s_next = next_seed(next_seed(seed))
      next_food = gen_versus_food_safe(p, s_next, h1, b1, h2, b2, w, h)
      pick_versus_cand(cand, next_food, h1, b1, h2, b2)

def make_versus_ate1_game(fs: FoodSeed, +nh1: Pos, new_b1: +List<Pos>, +nd1: Dir, +new_s1: U32, +nh2: Pos, new_b2: +List<Pos>, +nd2: Dir, +s2: U32) -> VersusState:
  FoodSeed{new_food, new_seed} = fs
  VersusGame{nh1, new_b1, nd1, True{}, new_s1, nh2, new_b2, nd2, True{}, s2, new_food, Active{}, new_seed}

def make_versus_ate2_game(fs: FoodSeed, +nh1: Pos, new_b1: +List<Pos>, +nd1: Dir, +s1: U32, +nh2: Pos, new_b2: +List<Pos>, +nd2: Dir, +new_s2: U32) -> VersusState:
  FoodSeed{new_food, new_seed} = fs
  VersusGame{nh1, new_b1, nd1, True{}, s1, nh2, new_b2, nd2, True{}, new_s2, new_food, Active{}, new_seed}

def versus_ate_step(ate1: Bool, ate2: Bool, +nh1: Pos, head1: Pos, body1: +List<Pos>, +nd1: Dir, +s1: U32, +nh2: Pos, head2: Pos, body2: +List<Pos>, +nd2: Dir, +s2: U32, +food: Pos, +seed: U32, +w: U32, +h: U32) -> VersusState:
  match ate1:
    case True{}:
      +new_b1 = grow(head1, body1)
      +new_s1 = (s1 + 10 : U32)
      +new_b2 = grow(head2, drop_last(body2))
      safe_food = gen_versus_food_safe(32n, seed, nh1, new_b1, nh2, new_b2, w, h)
      make_versus_ate1_game(safe_food, nh1, new_b1, nd1, new_s1, nh2, new_b2, nd2, s2)
    case False{}:
      match ate2:
        case True{}:
          +new_b1 = grow(head1, drop_last(body1))
          +new_b2 = grow(head2, body2)
          +new_s2 = (s2 + 10 : U32)
          safe_food = gen_versus_food_safe(32n, seed, nh1, new_b1, nh2, new_b2, w, h)
          make_versus_ate2_game(safe_food, nh1, new_b1, nd1, s1, nh2, new_b2, nd2, new_s2)
        case False{}:
          new_b1 = grow(head1, drop_last(body1))
          new_b2 = grow(head2, drop_last(body2))
          VersusGame{nh1, new_b1, nd1, True{}, s1, nh2, new_b2, nd2, True{}, s2, food, Active{}, seed}

def versus_resolve_step(outcome: VersusWinner, +nh1: Pos, head1: Pos, body1: +List<Pos>, +nd1: Dir, +s1: U32, +nh2: Pos, head2: Pos, body2: +List<Pos>, +nd2: Dir, +s2: U32, +food: Pos, +seed: U32, +w: U32, +h: U32) -> VersusState:
  match outcome:
    case Active{}:
      ate1 = pos_eq(nh1, food)
      ate2 = pos_eq(nh2, food)
      versus_ate_step(ate1, ate2, nh1, head1, body1, nd1, s1, nh2, head2, body2, nd2, s2, food, seed, w, h)
    case P1Win{}:
      new_b1 = grow(head1, drop_last(body1))
      VersusGame{nh1, new_b1, nd1, True{}, s1, head2, body2, nd2, False{}, s2, food, P1Win{}, seed}
    case P2Win{}:
      new_b2 = grow(head2, drop_last(body2))
      VersusGame{head1, body1, nd1, False{}, s1, nh2, new_b2, nd2, True{}, s2, food, P2Win{}, seed}
    case Draw{}:
      VersusGame{head1, body1, nd1, False{}, s1, head2, body2, nd2, False{}, s2, food, Draw{}, seed}

def step_versus(vg: VersusState, +k1: U32, +k2: U32, +w: U32, +h: U32) -> VersusState:
  VersusGame{+head1, +body1, +dir1, alive1, +score1, +head2, +body2, +dir2, alive2, +score2, +food, winner, +seed} = vg
  match winner:
    case Active{}:
      +nd1 = key_to_dir(k1, dir1)
      +nd2 = key_to_dir(k2, dir2)
      +nh1 = move_pos(head1, nd1)
      +nh2 = move_pos(head2, nd2)
      w1 = is_out_of_bounds(nh1, w, h)
      s_self1 = contains_pos(body1, nh1)
      hit_b2 = contains_pos(body2, nh1)
      +head_on = pos_eq(nh1, nh2)
      hit_h2 = pos_eq(nh1, head2)
      crash1 = w1 || s_self1 || hit_b2 || head_on || hit_h2
      w2 = is_out_of_bounds(nh2, w, h)
      s_self2 = contains_pos(body2, nh2)
      hit_b1 = contains_pos(body1, nh2)
      hit_h1 = pos_eq(nh2, head1)
      crash2 = w2 || s_self2 || hit_b1 || head_on || hit_h1
      outcome = versus_outcome(crash1, crash2)
      versus_resolve_step(outcome, nh1, head1, body1, nd1, score1, nh2, head2, body2, nd2, score2, food, seed, w, h)
    case _:
      vg

def p2_head_glyph(alive: Bool) -> String:
  match alive:
    case True{}:
      "\u{1b}[38;5;201m██\u{1b}[0m"
    case False{}:
      "\u{1b}[1;31m✖✖\u{1b}[0m"

def versus_char_empty() -> String:
  "  "

def versus_char_food(is_f: Bool) -> String:
  match is_f:
    case True{}:
      "🍎"
    case False{}:
      versus_char_empty()

def versus_char_b2(is_b2: Bool, is_f: Bool) -> String:
  match is_b2:
    case True{}:
      "\u{1b}[38;5;171m▒▒\u{1b}[0m"
    case False{}:
      versus_char_food(is_f)

def versus_char_b1(is_b1: Bool, is_b2: Bool, is_f: Bool) -> String:
  match is_b1:
    case True{}:
      "\u{1b}[38;5;40m▓▓\u{1b}[0m"
    case False{}:
      versus_char_b2(is_b2, is_f)

def versus_char_h2(is_h2: Bool, is_b1: Bool, is_b2: Bool, is_f: Bool, a2: Bool) -> String:
  match is_h2:
    case True{}:
      p2_head_glyph(a2)
    case False{}:
      versus_char_b1(is_b1, is_b2, is_f)

def versus_char_h1(is_h1: Bool, is_h2: Bool, is_b1: Bool, is_b2: Bool, is_f: Bool, a1: Bool, a2: Bool) -> String:
  match is_h1:
    case True{}:
      head_glyph(a1)
    case False{}:
      versus_char_h2(is_h2, is_b1, is_b2, is_f, a2)

def versus_cell_char(+p: Pos, +h1: Pos, +b1: +List<Pos>, alive1: Bool, +h2: Pos, +b2: +List<Pos>, alive2: Bool, +food: Pos) -> String:
  is_h1 = pos_eq(p, h1)
  is_h2 = pos_eq(p, h2)
  is_b1 = contains_pos(b1, p)
  is_b2 = contains_pos(b2, p)
  is_f = pos_eq(p, food)
  versus_char_h1(is_h1, is_h2, is_b1, is_b2, is_f, alive1, alive2)

def render_versus_cells(fuel: Nat, +x: U32, +y: U32, +h1: Pos, +b1: +List<Pos>, +a1: Bool, +h2: Pos, +b2: +List<Pos>, +a2: Bool, +food: Pos) -> String:
  match fuel:
    case 0n:
      ""
    case 1n+p:
      c = versus_cell_char(Pos{x, y}, h1, b1, a1, h2, b2, a2, food)
      c ++ render_versus_cells(p, (x + 1 : U32), y, h1, b1, a1, h2, b2, a2, food)

def render_versus_row(+y: U32, +w_nat: Nat, +h1: Pos, +b1: +List<Pos>, +a1: Bool, +h2: Pos, +b2: +List<Pos>, +a2: Bool, +food: Pos) -> String:
  "\u{1b}[38;5;39m║\u{1b}[0m" ++ render_versus_cells(w_nat, 0, y, h1, b1, a1, h2, b2, a2, food) ++ "\u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n"

def render_versus_quad(+y: U32, +w_nat: Nat, +h1: Pos, +b1: +List<Pos>, +a1: Bool, +h2: Pos, +b2: +List<Pos>, +a2: Bool, +food: Pos) -> String:
  r0 r1 = render_versus_row(y, w_nat, h1, b1, a1, h2, b2, a2, food) render_versus_row((y + 1 : U32), w_nat, h1, b1, a1, h2, b2, a2, food)
  r2 r3 = render_versus_row((y + 2 : U32), w_nat, h1, b1, a1, h2, b2, a2, food) render_versus_row((y + 3 : U32), w_nat, h1, b1, a1, h2, b2, a2, food)
  (r0 ++ r1) ++ (r2 ++ r3)

def render_versus_grid_par(+w_nat: Nat, +h1: Pos, +b1: +List<Pos>, +a1: Bool, +h2: Pos, +b2: +List<Pos>, +a2: Bool, +food: Pos) -> String:
  q0 q1 = render_versus_quad(0, w_nat, h1, b1, a1, h2, b2, a2, food) render_versus_quad(4, w_nat, h1, b1, a1, h2, b2, a2, food)
  q2 q3 = render_versus_quad(8, w_nat, h1, b1, a1, h2, b2, a2, food) render_versus_quad(12, w_nat, h1, b1, a1, h2, b2, a2, food)
  (q0 ++ q1) ++ (q2 ++ q3)

def render_versus_status(winner: VersusWinner, +s1: U32, +s2: U32) -> String:
  match winner:
    case Active{}:
      "\u{1b}[1;32m🍏 P1: \u{1b}[1;37m" ++ U32.show(s1) ++ "\u{1b}[0m   \u{1b}[90m│\u{1b}[0m   \u{1b}[1;35m🍇 P2: \u{1b}[1;37m" ++ U32.show(s2) ++ "\u{1b}[0m   \u{1b}[90m│\u{1b}[0m   \u{1b}[37mDuel for Apples!\u{1b}[0m   \u{1b}[90m│\u{1b}[0m   \u{1b}[33m[R]\u{1b}[0m Restart  \u{1b}[33m[Q]\u{1b}[0m Quit\u{1b}[K\n"
    case P1Win{}:
      "\u{1b}[1;32m🎉 PLAYER 1 (GREEN) WINS! 🏆\u{1b}[0m  P1: " ++ U32.show(s1) ++ " vs P2: " ++ U32.show(s2) ++ "   \u{1b}[90m│\u{1b}[0m   \u{1b}[33m[R]\u{1b}[0m Play Again  \u{1b}[33m[Q]\u{1b}[0m Quit\u{1b}[K\n"
    case P2Win{}:
      "\u{1b}[1;35m🎉 PLAYER 2 (PURPLE) WINS! 🏆\u{1b}[0m  P2: " ++ U32.show(s2) ++ " vs P1: " ++ U32.show(s1) ++ "   \u{1b}[90m│\u{1b}[0m   \u{1b}[33m[R]\u{1b}[0m Play Again  \u{1b}[33m[Q]\u{1b}[0m Quit\u{1b}[K\n"
    case Draw{}:
      "\u{1b}[1;31m⚔️ MUTUAL CRASH - DRAW! ⚔️\u{1b}[0m  Final: " ++ U32.show(s1) ++ " - " ++ U32.show(s2) ++ "   \u{1b}[90m│\u{1b}[0m   \u{1b}[33m[R]\u{1b}[0m Play Again  \u{1b}[33m[Q]\u{1b}[0m Quit\u{1b}[K\n"

def get_versus_max_score(vg: VersusState) -> U32:
  VersusGame{+h1, +b1, +d1, +a1, +s1, +h2, +b2, +d2, +a2, +s2, +food, +winner, +seed} = vg
  max_score(s1, s2)

def render_versus_frame(vg: VersusState, +w_nat: Nat, d: Diff) -> String:
  VersusGame{+h1, +b1, +d1, +a1, +s1, +h2, +b2, +d2, +a2, +s2, +food, +winner, +seed} = vg
  badge = diff_badge(d)
  header = {"\u{1b}[H\u{1b}[1;33m🐍  BEND SNAKE VERSUS (2 SNAKES DUEL)  🐍\u{1b}[0m   " ++ badge ++ "\u{1b}[K\n" : String}
  border_top = {"\u{1b}[38;5;39m╔════════════════════════════════════════════════╗\u{1b}[0m\u{1b}[K\n" : String}
  border_bot = {"\u{1b}[38;5;39m╚════════════════════════════════════════════════╝\u{1b}[0m\u{1b}[K\u{1b}[J\n" : String}
  grid = render_versus_grid_par(w_nat, h1, b1, a1, h2, b2, a2, food)
  status = render_versus_status(winner, s1, s2)
  (header ++ status) ++ (border_top ++ grid ++ border_bot)

def diff_menu_line(d: Diff) -> String:
  match d:
    case Easy{}:
      "\u{1b}[38;5;39m║\u{1b}[0m  \u{1b}[1;33m[D]\u{1b}[0m \u{1b}[1;37mSpeed:\u{1b}[0m \u{1b}[1;32m🐢 Easy\u{1b}[0m   \u{1b}[90m(165ms, Steady)\u{1b}[0m          \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n"
    case Normal{}:
      "\u{1b}[38;5;39m║\u{1b}[0m  \u{1b}[1;33m[D]\u{1b}[0m \u{1b}[1;37mSpeed:\u{1b}[0m \u{1b}[1;36m🐍 Normal\u{1b}[0m \u{1b}[90m(120ms -> 75ms)\u{1b}[0m          \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n"
    case Hard{}:
      "\u{1b}[38;5;39m║\u{1b}[0m  \u{1b}[1;33m[D]\u{1b}[0m \u{1b}[1;37mSpeed:\u{1b}[0m \u{1b}[1;33m🔥 Hard\u{1b}[0m   \u{1b}[90m(85ms  -> 55ms)\u{1b}[0m          \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n"
    case Turbo{}:
      "\u{1b}[38;5;39m║\u{1b}[0m  \u{1b}[1;33m[D]\u{1b}[0m \u{1b}[1;37mSpeed:\u{1b}[0m \u{1b}[1;31m⚡ Turbo\u{1b}[0m  \u{1b}[90m(60ms  -> 40ms)\u{1b}[0m          \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n"

def render_menu(d: Diff) -> String:
  dline = diff_menu_line(d)
  "\u{1b}[H\u{1b}[2J\u{1b}[1;33m🐍  BEND SNAKE ARCADE  🐍\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m╔════════════════════════════════════════════════╗\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m║\u{1b}[0m          \u{1b}[1;37mCHOOSE GAME MODE & MULTIPLAYER\u{1b}[0m        \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m╠════════════════════════════════════════════════╣\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m║\u{1b}[0m                                                \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m║\u{1b}[0m  \u{1b}[1;32m[1]\u{1b}[0m \u{1b}[1;37mSolo Classic\u{1b}[0m     - High score chase       \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m║\u{1b}[0m                                                \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m║\u{1b}[0m  \u{1b}[1;36m[2]\u{1b}[0m \u{1b}[1;37mLAN Co-op (Host)\u{1b}[0m - 2 players, 1 snake     \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m║\u{1b}[0m  \u{1b}[1;36m[3]\u{1b}[0m \u{1b}[1;37mLAN Co-op (Join)\u{1b}[0m - 2 players, 1 snake     \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m║\u{1b}[0m                                                \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m║\u{1b}[0m  \u{1b}[1;35m[4]\u{1b}[0m \u{1b}[1;37mLAN Versus (Host)\u{1b}[0m- 2 snakes battle duel   \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m║\u{1b}[0m  \u{1b}[1;35m[5]\u{1b}[0m \u{1b}[1;37mLAN Versus (Join)\u{1b}[0m- 2 snakes battle duel   \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m║\u{1b}[0m                                                \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m║\u{1b}[0m  \u{1b}[1;33m[6]\u{1b}[0m \u{1b}[1;37mLocal Co-op\u{1b}[0m     - 1 keyboard (WASD/Arrows)\u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m║\u{1b}[0m  \u{1b}[1;33m[7]\u{1b}[0m \u{1b}[1;37mLocal Versus\u{1b}[0m    - 1 keyboard (WASD/Arrows)\u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m╠════════════════════════════════════════════════╣\u{1b}[0m\u{1b}[K\n" ++
  dline ++
  "\u{1b}[38;5;39m║\u{1b}[0m  \u{1b}[1;31m[Q]\u{1b}[0m \u{1b}[1;37mQuit Game\u{1b}[0m                                 \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m╠════════════════════════════════════════════════╣\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m║\u{1b}[0m  \u{1b}[90mDefault Port: 4242  │  [1-7, D, ←/→, Q]\u{1b}[0m       \u{1b}[38;5;39m║\u{1b}[0m\u{1b}[K\n" ++
  "\u{1b}[38;5;39m╚════════════════════════════════════════════════╝\u{1b}[0m\u{1b}[K\n\n\u{1b}[1;37mSelect an option [1-7, D, Q]: \u{1b}[0m\u{1b}[K"
