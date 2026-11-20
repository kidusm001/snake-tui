import Base
import ./snake.bend as Snake
import ./terminal.bend as Term

def is_quit(+k: U32) -> Bool:
  U32.is_eq(k, 113)

def is_restart(+k: U32) -> Bool:
  U32.is_eq(k, 114)

@unsafe def step_io_run(p: Nat, k: U32, restart: Bool, g: Snake.GameState) -> IO(Unit):
  match restart:
    case True{}:
      Snake.Game{+head, +body, +dir, +food, +score, +high_score, +alive, +seed} = g
      +cur_best = Snake.max_score(high_score, score)
      +new_g : Snake.GameState = Snake.new_game(Snake.next_seed(seed), cur_best)
      frame : String = Snake.render_frame(new_g, 24n)
      do IO<Unit>:
        Term.save_high_score(cur_best)
        IO.write(frame)
        IO.sleep(120)
        game_loop(p, new_g)
    case False{}:
      +next_g : Snake.GameState = Snake.step_game(g, k, 24, 16)
      frame : String = Snake.render_frame(next_g, 24n)
      do IO<Unit>:
        Term.save_high_score(Snake.get_high_score(next_g))
        IO.write(frame)
        IO.sleep(120)
        game_loop(p, next_g)

@unsafe def step_io(p: Nat, +k: U32, quit: Bool, +g: Snake.GameState) -> IO(Unit):
  match quit:
    case True{}:
      do IO<Unit>:
        Term.save_high_score(Snake.get_high_score(g))
        Term.restore()
    case False{}:
      step_io_run(p, k, is_restart(k), g)

@unsafe def game_loop(fuel: Nat, g: Snake.GameState) -> IO(Unit):
  match fuel:
    case 0n:
      Term.restore()
    case 1n+p:
      do IO<Unit>:
        +k : U32 <- Term.poll_key()
        step_io(p, k, is_quit(k), g)

def main() -> IO(Unit):
  do IO<Unit>:
    Term.init()
    saved_high : U32 <- Term.load_high_score()
    +g : Snake.GameState = Snake.new_game(12345, saved_high)
    frame : String = Snake.render_frame(g, 24n)
    IO.write(frame)
    game_loop(1000000n, g)
