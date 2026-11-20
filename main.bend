import Base
import ./snake.bend as Snake
import ./terminal.bend as Term

def is_quit(+k: U32) -> Bool:
  U32.is_eq(k, 113)

def is_restart(+k: U32) -> Bool:
  U32.is_eq(k, 114)

def filter_p1_key(+k: U32) -> U32:
  match k:
    case 119:
      119
    case 115:
      115
    case 97:
      97
    case 100:
      100
    case _:
      0

def filter_p2_key(+k: U32) -> U32:
  match k:
    case 200:
      119
    case 201:
      115
    case 202:
      97
    case 203:
      100
    case 105:
      119
    case 107:
      115
    case 106:
      97
    case 108:
      100
    case _:
      0

# Solo Game Loop
@unsafe def solo_step_run(p: Nat, k: U32, restart: Bool, g: Snake.GameState) -> IO(Unit):
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
        solo_loop(p, new_g)
    case False{}:
      +next_g : Snake.GameState = Snake.step_game(g, k, 24, 16)
      frame : String = Snake.render_frame(next_g, 24n)
      do IO<Unit>:
        Term.save_high_score(Snake.get_high_score(next_g))
        IO.write(frame)
        IO.sleep(120)
        solo_loop(p, next_g)

@unsafe def solo_step(p: Nat, +k: U32, quit: Bool, +g: Snake.GameState) -> IO(Unit):
  match quit:
    case True{}:
      do IO<Unit>:
        Term.save_high_score(Snake.get_high_score(g))
        Term.restore()
    case False{}:
      solo_step_run(p, k, is_restart(k), g)

@unsafe def solo_loop(fuel: Nat, g: Snake.GameState) -> IO(Unit):
  match fuel:
    case 0n:
      Term.restore()
    case 1n+p:
      do IO<Unit>:
        +k : U32 <- Term.poll_key()
        solo_step(p, k, is_quit(k), g)

# Local Co-op Loop (1 snake, 2 players on same keyboard)
@unsafe def coop_local_step_run(restart: Bool, p: Nat, +k: U32, g: Snake.GameState) -> IO(Unit):
  match restart:
    case True{}:
      Snake.Game{+head, +body, +dir, +food, +score, +high_score, +alive, +seed} = g
      +new_g : Snake.GameState = Snake.new_game(Snake.next_seed(seed), high_score)
      frame : String = Snake.render_coop_frame(new_g, 24n)
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(120)
        coop_local_loop(p, new_g)
    case False{}:
      +k1 = filter_p1_key(k)
      +k2 = filter_p2_key(k)
      +next_g : Snake.GameState = Snake.step_coop(g, k1, k2, 24, 16)
      frame : String = Snake.render_coop_frame(next_g, 24n)
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(120)
        coop_local_loop(p, next_g)

@unsafe def coop_local_step(quit: Bool, p: Nat, +k: U32, g: Snake.GameState) -> IO(Unit):
  match quit:
    case True{}:
      Term.restore()
    case False{}:
      coop_local_step_run(is_restart(k), p, k, g)

@unsafe def coop_local_loop(fuel: Nat, g: Snake.GameState) -> IO(Unit):
  match fuel:
    case 0n:
      Term.restore()
    case 1n+p:
      do IO<Unit>:
        +k : U32 <- Term.poll_key()
        coop_local_step(is_quit(k), p, k, g)

# Local Versus Loop (2 snakes duel, 2 players on same keyboard)
@unsafe def versus_local_step_run(restart: Bool, p: Nat, +k: U32, vg: Snake.VersusState) -> IO(Unit):
  match restart:
    case True{}:
      +seed = Snake.get_versus_seed(vg)
      +new_vg : Snake.VersusState = Snake.new_versus_game(Snake.next_seed(seed))
      frame : String = Snake.render_versus_frame(new_vg, 24n)
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(120)
        versus_local_loop(p, new_vg)
    case False{}:
      +k1 = filter_p1_key(k)
      +k2 = filter_p2_key(k)
      +next_vg : Snake.VersusState = Snake.step_versus(vg, k1, k2, 24, 16)
      frame : String = Snake.render_versus_frame(next_vg, 24n)
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(120)
        versus_local_loop(p, next_vg)

@unsafe def versus_local_step(quit: Bool, p: Nat, +k: U32, vg: Snake.VersusState) -> IO(Unit):
  match quit:
    case True{}:
      Term.restore()
    case False{}:
      versus_local_step_run(is_restart(k), p, k, vg)

@unsafe def versus_local_loop(fuel: Nat, vg: Snake.VersusState) -> IO(Unit):
  match fuel:
    case 0n:
      Term.restore()
    case 1n+p:
      do IO<Unit>:
        +k : U32 <- Term.poll_key()
        versus_local_step(is_quit(k), p, k, vg)

# LAN Co-op Host Loop
@unsafe def coop_host_step_run(restart: Bool, p: Nat, +k1: U32, +k2: U32, g: Snake.GameState) -> IO(Unit):
  match restart:
    case True{}:
      Snake.Game{+head, +body, +dir, +food, +score, +high_score, +alive, +seed} = g
      +new_g : Snake.GameState = Snake.new_game(Snake.next_seed(seed), high_score)
      frame : String = Snake.render_coop_frame(new_g, 24n)
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(120)
        coop_host_loop(p, new_g)
    case False{}:
      +next_g : Snake.GameState = Snake.step_coop(g, k1, k2, 24, 16)
      frame : String = Snake.render_coop_frame(next_g, 24n)
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(120)
        coop_host_loop(p, next_g)

@unsafe def coop_host_step(quit: Bool, p: Nat, +k1: U32, +k2: U32, g: Snake.GameState) -> IO(Unit):
  match quit:
    case True{}:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case False{}:
      restart = is_restart(k1) || is_restart(k2)
      coop_host_step_run(restart, p, k1, k2, g)

@unsafe def coop_host_loop(fuel: Nat, g: Snake.GameState) -> IO(Unit):
  match fuel:
    case 0n:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case 1n+p:
      do IO<Unit>:
        +k1 : U32 <- Term.poll_key()
        Term.net_send_key(k1)
        +k2 : U32 <- Term.net_recv_key()
        coop_host_step(is_quit(k1) || is_quit(k2), p, k1, k2, g)

# LAN Co-op Join Loop
@unsafe def coop_join_step_run(restart: Bool, p: Nat, +k1: U32, +k2: U32, g: Snake.GameState) -> IO(Unit):
  match restart:
    case True{}:
      Snake.Game{+head, +body, +dir, +food, +score, +high_score, +alive, +seed} = g
      +new_g : Snake.GameState = Snake.new_game(Snake.next_seed(seed), high_score)
      frame : String = Snake.render_coop_frame(new_g, 24n)
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(120)
        coop_join_loop(p, new_g)
    case False{}:
      +next_g : Snake.GameState = Snake.step_coop(g, k1, k2, 24, 16)
      frame : String = Snake.render_coop_frame(next_g, 24n)
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(120)
        coop_join_loop(p, next_g)

@unsafe def coop_join_step(quit: Bool, p: Nat, +k1: U32, +k2: U32, g: Snake.GameState) -> IO(Unit):
  match quit:
    case True{}:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case False{}:
      restart = is_restart(k1) || is_restart(k2)
      coop_join_step_run(restart, p, k1, k2, g)

@unsafe def coop_join_loop(fuel: Nat, g: Snake.GameState) -> IO(Unit):
  match fuel:
    case 0n:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case 1n+p:
      do IO<Unit>:
        +k2 : U32 <- Term.poll_key()
        Term.net_send_key(k2)
        +k1 : U32 <- Term.net_recv_key()
        coop_join_step(is_quit(k1) || is_quit(k2), p, k1, k2, g)

# LAN Versus Host Loop
@unsafe def versus_host_step_run(restart: Bool, p: Nat, +k1: U32, +k2: U32, vg: Snake.VersusState) -> IO(Unit):
  match restart:
    case True{}:
      +seed = Snake.get_versus_seed(vg)
      +new_vg : Snake.VersusState = Snake.new_versus_game(Snake.next_seed(seed))
      frame : String = Snake.render_versus_frame(new_vg, 24n)
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(120)
        versus_host_loop(p, new_vg)
    case False{}:
      +next_vg : Snake.VersusState = Snake.step_versus(vg, k1, k2, 24, 16)
      frame : String = Snake.render_versus_frame(next_vg, 24n)
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(120)
        versus_host_loop(p, next_vg)

@unsafe def versus_host_step(quit: Bool, p: Nat, +k1: U32, +k2: U32, vg: Snake.VersusState) -> IO(Unit):
  match quit:
    case True{}:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case False{}:
      restart = is_restart(k1) || is_restart(k2)
      versus_host_step_run(restart, p, k1, k2, vg)

@unsafe def versus_host_loop(fuel: Nat, vg: Snake.VersusState) -> IO(Unit):
  match fuel:
    case 0n:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case 1n+p:
      do IO<Unit>:
        +k1 : U32 <- Term.poll_key()
        Term.net_send_key(k1)
        +k2 : U32 <- Term.net_recv_key()
        versus_host_step(is_quit(k1) || is_quit(k2), p, k1, k2, vg)

# LAN Versus Join Loop
@unsafe def versus_join_step_run(restart: Bool, p: Nat, +k1: U32, +k2: U32, vg: Snake.VersusState) -> IO(Unit):
  match restart:
    case True{}:
      +seed = Snake.get_versus_seed(vg)
      +new_vg : Snake.VersusState = Snake.new_versus_game(Snake.next_seed(seed))
      frame : String = Snake.render_versus_frame(new_vg, 24n)
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(120)
        versus_join_loop(p, new_vg)
    case False{}:
      +next_vg : Snake.VersusState = Snake.step_versus(vg, k1, k2, 24, 16)
      frame : String = Snake.render_versus_frame(next_vg, 24n)
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(120)
        versus_join_loop(p, next_vg)

@unsafe def versus_join_step(quit: Bool, p: Nat, +k1: U32, +k2: U32, vg: Snake.VersusState) -> IO(Unit):
  match quit:
    case True{}:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case False{}:
      restart = is_restart(k1) || is_restart(k2)
      versus_join_step_run(restart, p, k1, k2, vg)

@unsafe def versus_join_loop(fuel: Nat, vg: Snake.VersusState) -> IO(Unit):
  match fuel:
    case 0n:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case 1n+p:
      do IO<Unit>:
        +k2 : U32 <- Term.poll_key()
        Term.net_send_key(k2)
        +k1 : U32 <- Term.net_recv_key()
        versus_join_step(is_quit(k1) || is_quit(k2), p, k1, k2, vg)

# Waiting for LAN Client
@unsafe def wait_host_dispatch(+mode: U32) -> IO(Unit):
  match mode:
    case 2:
      +g : Snake.GameState = Snake.new_game(424242, 0)
      frame : String = Snake.render_coop_frame(g, 24n)
      do IO<Unit>:
        IO.write(frame)
        coop_host_loop(1000000n, g)
    case 4:
      +vg : Snake.VersusState = Snake.new_versus_game(424242)
      frame : String = Snake.render_versus_frame(vg, 24n)
      do IO<Unit>:
        IO.write(frame)
        versus_host_loop(1000000n, vg)
    case _:
      Term.restore()

@unsafe def wait_host_check(is_ok: Bool, p: Nat, +mode: U32) -> IO(Unit):
  match is_ok:
    case True{}:
      wait_host_dispatch(mode)
    case False{}:
      do IO<Unit>:
        IO.sleep(100)
        wait_host(p, mode)

@unsafe def wait_host_step(quit: Bool, p: Nat, +mode: U32) -> IO(Unit):
  match quit:
    case True{}:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case False{}:
      do IO<Unit>:
        +ok : U32 <- Term.net_accept()
        wait_host_check(U32.is_eq(ok, 1), p, mode)

@unsafe def wait_host(fuel: Nat, +mode: U32) -> IO(Unit):
  match fuel:
    case 0n:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case 1n+p:
      do IO<Unit>:
        +k : U32 <- Term.poll_key()
        wait_host_step(is_quit(k), p, mode)

@unsafe def join_coop_step(is_ok: Bool) -> IO(Unit):
  match is_ok:
    case True{}:
      +g : Snake.GameState = Snake.new_game(424242, 0)
      frame : String = Snake.render_coop_frame(g, 24n)
      do IO<Unit>:
        IO.write(frame)
        coop_join_loop(1000000n, g)
    case False{}:
      do IO<Unit>:
        IO.print("\nFailed to connect to host. Returning to menu...\n")
        IO.sleep(1500)
        Term.restore()

@unsafe def join_versus_step(is_ok: Bool) -> IO(Unit):
  match is_ok:
    case True{}:
      +vg : Snake.VersusState = Snake.new_versus_game(424242)
      frame : String = Snake.render_versus_frame(vg, 24n)
      do IO<Unit>:
        IO.write(frame)
        versus_join_loop(1000000n, vg)
    case False{}:
      do IO<Unit>:
        IO.print("\nFailed to connect to host. Returning to menu...\n")
        IO.sleep(1500)
        Term.restore()

# Main Menu Dispatcher
@unsafe def menu_select(+choice: U32) -> IO(Unit):
  match choice:
    case 49:
      # [1] Solo Classic
      do IO<Unit>:
        saved_high : U32 <- Term.load_high_score()
        +g : Snake.GameState = Snake.new_game(12345, saved_high)
        frame : String = Snake.render_frame(g, 24n)
        IO.write(frame)
        solo_loop(1000000n, g)
    case 50:
      # [2] LAN Co-op Host
      do IO<Unit>:
        _ : U32 <- Term.net_listen(4242)
        wait_host(100000n, 2)
    case 51:
      # [3] LAN Co-op Join
      do IO<Unit>:
        ok : U32 <- Term.net_prompt_join(4242)
        join_coop_step(U32.is_eq(ok, 1))
    case 52:
      # [4] LAN Versus Host
      do IO<Unit>:
        _ : U32 <- Term.net_listen(4242)
        wait_host(100000n, 4)
    case 53:
      # [5] LAN Versus Join
      do IO<Unit>:
        ok : U32 <- Term.net_prompt_join(4242)
        join_versus_step(U32.is_eq(ok, 1))
    case 54:
      # [6] Local Co-op
      do IO<Unit>:
        +g : Snake.GameState = Snake.new_game(54321, 0)
        frame : String = Snake.render_coop_frame(g, 24n)
        IO.write(frame)
        coop_local_loop(1000000n, g)
    case 55:
      # [7] Local Versus
      do IO<Unit>:
        +vg : Snake.VersusState = Snake.new_versus_game(54321)
        frame : String = Snake.render_versus_frame(vg, 24n)
        IO.write(frame)
        versus_local_loop(1000000n, vg)
    case 113:
      # [Q] Quit
      Term.restore()
    case _:
      Term.restore()

@unsafe def menu_step(is_zero: Bool, p: Nat, +k: U32) -> IO(Unit):
  match is_zero:
    case True{}:
      do IO<Unit>:
        IO.sleep(80)
        menu_loop(p)
    case False{}:
      menu_select(k)

@unsafe def menu_loop(fuel: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      Term.restore()
    case 1n+p:
      do IO<Unit>:
        +k : U32 <- Term.poll_key()
        menu_step(U32.is_eq(k, 0), p, k)

@unsafe def main() -> IO(Unit):
  do IO<Unit>:
    Term.init()
    IO.write(Snake.render_menu())
    menu_loop(100000n)
