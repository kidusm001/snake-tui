import Base
import ./snake.bend as Snake
import ./terminal.bend as Term

def is_quit(+k: U32) -> Bool:
  U32.is_eq(k, 113)

def is_restart(+k: U32) -> Bool:
  U32.is_eq(k, 114)

def is_menu(+k: U32) -> Bool:
  U32.is_eq(k, 109)

@unsafe def return_to_menu(+d: Snake.Diff) -> IO(Unit):
  do IO<Unit>:
    IO.write(Snake.render_menu(d))
    menu_loop(100000n, d)

@unsafe def net_return_to_menu(+d: Snake.Diff) -> IO(Unit):
  do IO<Unit>:
    Term.net_close()
    return_to_menu(d)

def is_p2_local_restart(+k: U32) -> Bool:
  U32.is_eq(k, 111) || U32.is_eq(k, 13) || U32.is_eq(k, 10)

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
@unsafe def solo_step_run(p: Nat, k: U32, restart: Bool, g: Snake.GameState, +d: Snake.Diff) -> IO(Unit):
  match restart:
    case True{}:
      Snake.Game{+head, +body, +dir, +food, +score, +high_score, +alive, +seed} = g
      +cur_best = Snake.max_score(high_score, score)
      +new_g : Snake.GameState = Snake.new_game(Snake.next_seed(seed), cur_best)
      frame : String = Snake.render_frame(new_g, 24n, d)
      do IO<Unit>:
        Term.save_high_score(cur_best, Snake.diff_to_u32(d))
        IO.write(frame)
        IO.sleep(Snake.calc_tick_ms(d, 0))
        solo_loop(p, new_g, d)
    case False{}:
      +next_g : Snake.GameState = Snake.step_game(g, k, 24, 16)
      frame : String = Snake.render_frame(next_g, 24n, d)
      do IO<Unit>:
        Term.save_high_score(Snake.get_high_score(next_g), Snake.diff_to_u32(d))
        IO.write(frame)
        IO.sleep(Snake.calc_tick_ms(d, Snake.get_score(next_g)))
        solo_loop(p, next_g, d)

@unsafe def solo_step_menu(go_menu: Bool, p: Nat, +k: U32, +g: Snake.GameState, +d: Snake.Diff) -> IO(Unit):
  match go_menu:
    case True{}:
      do IO<Unit>:
        Term.save_high_score(Snake.get_high_score(g), Snake.diff_to_u32(d))
        return_to_menu(d)
    case False{}:
      solo_step_run(p, k, is_restart(k), g, d)

@unsafe def solo_step(p: Nat, +k: U32, quit: Bool, +g: Snake.GameState, +d: Snake.Diff) -> IO(Unit):
  match quit:
    case True{}:
      do IO<Unit>:
        Term.save_high_score(Snake.get_high_score(g), Snake.diff_to_u32(d))
        Term.restore()
    case False{}:
      solo_step_menu(is_menu(k), p, k, g, d)

@unsafe def solo_loop(fuel: Nat, g: Snake.GameState, +d: Snake.Diff) -> IO(Unit):
  match fuel:
    case 0n:
      Term.restore()
    case 1n+p:
      do IO<Unit>:
        +k : U32 <- Term.poll_key()
        solo_step(p, k, is_quit(k), g, d)

# Local Co-op Loop (1 snake, 2 players on same keyboard)
@unsafe def coop_local_step_run(restart: Bool, p: Nat, +k: U32, g: Snake.GameState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match restart:
    case True{}:
      Snake.Game{+head, +body, +dir, +food, +score, +high_score, +alive, +seed} = g
      +new_g : Snake.GameState = Snake.new_game(Snake.next_seed(seed), high_score)
      +nr : Snake.RestartVote = Snake.restart_none()
      frame : String = Snake.render_coop_frame(new_g, 24n, d, nr, True{})
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(Snake.calc_tick_ms(d, 0))
        coop_local_loop(p, new_g, d, nr)
    case False{}:
      +k1 = filter_p1_key(k)
      +k2 = filter_p2_key(k)
      +next_g : Snake.GameState = Snake.step_coop(g, k1, k2, 24, 16)
      frame : String = Snake.render_coop_frame(next_g, 24n, d, rv, True{})
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(Snake.calc_tick_ms(d, Snake.get_score(next_g)))
        coop_local_loop(p, next_g, d, rv)

@unsafe def coop_local_step_menu(go_menu: Bool, p: Nat, +k: U32, g: Snake.GameState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match go_menu:
    case True{}:
      return_to_menu(d)
    case False{}:
      +next_rv : Snake.RestartVote = Snake.vote_restart(rv, is_restart(k), is_p2_local_restart(k))
      coop_local_step_run(Snake.both_restart(next_rv), p, k, g, d, next_rv)

@unsafe def coop_local_step(quit: Bool, p: Nat, +k: U32, g: Snake.GameState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match quit:
    case True{}:
      Term.restore()
    case False{}:
      coop_local_step_menu(is_menu(k), p, k, g, d, rv)

@unsafe def coop_local_loop(fuel: Nat, g: Snake.GameState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match fuel:
    case 0n:
      Term.restore()
    case 1n+p:
      do IO<Unit>:
        +k : U32 <- Term.poll_key()
        coop_local_step(is_quit(k), p, k, g, d, rv)

# Local Versus Loop (2 snakes duel, 2 players on same keyboard)
@unsafe def versus_local_step_run(restart: Bool, p: Nat, +k: U32, vg: Snake.VersusState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match restart:
    case True{}:
      +new_vg : Snake.VersusState = Snake.restart_versus_game(vg)
      +nr : Snake.RestartVote = Snake.restart_none()
      frame : String = Snake.render_versus_frame(new_vg, 24n, d, nr, True{})
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(Snake.calc_tick_ms(d, 0))
        versus_local_loop(p, new_vg, d, nr)
    case False{}:
      +k1 = filter_p1_key(k)
      +k2 = filter_p2_key(k)
      +next_vg : Snake.VersusState = Snake.step_versus(vg, k1, k2, 24, 16)
      frame : String = Snake.render_versus_frame(next_vg, 24n, d, rv, True{})
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(Snake.calc_tick_ms(d, Snake.get_versus_max_score(next_vg)))
        versus_local_loop(p, next_vg, d, rv)

@unsafe def versus_local_step_menu(go_menu: Bool, p: Nat, +k: U32, vg: Snake.VersusState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match go_menu:
    case True{}:
      return_to_menu(d)
    case False{}:
      +next_rv : Snake.RestartVote = Snake.vote_restart(rv, is_restart(k), is_p2_local_restart(k))
      versus_local_step_run(Snake.both_restart(next_rv), p, k, vg, d, next_rv)

@unsafe def versus_local_step(quit: Bool, p: Nat, +k: U32, vg: Snake.VersusState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match quit:
    case True{}:
      Term.restore()
    case False{}:
      versus_local_step_menu(is_menu(k), p, k, vg, d, rv)

@unsafe def versus_local_loop(fuel: Nat, vg: Snake.VersusState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match fuel:
    case 0n:
      Term.restore()
    case 1n+p:
      do IO<Unit>:
        +k : U32 <- Term.poll_key()
        versus_local_step(is_quit(k), p, k, vg, d, rv)

# LAN Co-op Host Loop
@unsafe def coop_host_step_run(restart: Bool, p: Nat, +k1: U32, +k2: U32, g: Snake.GameState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match restart:
    case True{}:
      Snake.Game{+head, +body, +dir, +food, +score, +high_score, +alive, +seed} = g
      +new_g : Snake.GameState = Snake.new_game(Snake.next_seed(seed), high_score)
      +nr : Snake.RestartVote = Snake.restart_none()
      frame : String = Snake.render_coop_frame(new_g, 24n, d, nr, False{})
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(Snake.calc_tick_ms(d, 0))
        coop_host_loop(p, new_g, d, nr)
    case False{}:
      +next_g : Snake.GameState = Snake.step_coop(g, k1, k2, 24, 16)
      frame : String = Snake.render_coop_frame(next_g, 24n, d, rv, False{})
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(Snake.calc_tick_ms(d, Snake.get_score(next_g)))
        coop_host_loop(p, next_g, d, rv)

@unsafe def coop_host_step_menu(go_menu: Bool, p: Nat, +k1: U32, +k2: U32, g: Snake.GameState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match go_menu:
    case True{}:
      net_return_to_menu(d)
    case False{}:
      +next_rv : Snake.RestartVote = Snake.vote_restart(rv, is_restart(k1), is_restart(k2))
      coop_host_step_run(Snake.both_restart(next_rv), p, k1, k2, g, d, next_rv)

@unsafe def coop_host_step(quit: Bool, p: Nat, +k1: U32, +k2: U32, g: Snake.GameState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match quit:
    case True{}:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case False{}:
      coop_host_step_menu(is_menu(k1) || is_menu(k2) || is_quit(k2), p, k1, k2, g, d, rv)

@unsafe def coop_host_loop(fuel: Nat, g: Snake.GameState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
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
        coop_host_step(is_quit(k1), p, k1, k2, g, d, rv)

# LAN Co-op Join Loop
@unsafe def coop_join_step_run(restart: Bool, p: Nat, +k1: U32, +k2: U32, g: Snake.GameState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match restart:
    case True{}:
      Snake.Game{+head, +body, +dir, +food, +score, +high_score, +alive, +seed} = g
      +new_g : Snake.GameState = Snake.new_game(Snake.next_seed(seed), high_score)
      +nr : Snake.RestartVote = Snake.restart_none()
      frame : String = Snake.render_coop_frame(new_g, 24n, d, nr, False{})
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(Snake.calc_tick_ms(d, 0))
        coop_join_loop(p, new_g, d, nr)
    case False{}:
      +next_g : Snake.GameState = Snake.step_coop(g, k1, k2, 24, 16)
      frame : String = Snake.render_coop_frame(next_g, 24n, d, rv, False{})
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(Snake.calc_tick_ms(d, Snake.get_score(next_g)))
        coop_join_loop(p, next_g, d, rv)

@unsafe def coop_join_step_menu(go_menu: Bool, p: Nat, +k1: U32, +k2: U32, g: Snake.GameState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match go_menu:
    case True{}:
      net_return_to_menu(d)
    case False{}:
      +next_rv : Snake.RestartVote = Snake.vote_restart(rv, is_restart(k1), is_restart(k2))
      coop_join_step_run(Snake.both_restart(next_rv), p, k1, k2, g, d, next_rv)

@unsafe def coop_join_step(quit: Bool, p: Nat, +k1: U32, +k2: U32, g: Snake.GameState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match quit:
    case True{}:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case False{}:
      coop_join_step_menu(is_menu(k1) || is_menu(k2) || is_quit(k1), p, k1, k2, g, d, rv)

@unsafe def coop_join_loop(fuel: Nat, g: Snake.GameState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
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
        coop_join_step(is_quit(k2), p, k1, k2, g, d, rv)

# LAN Versus Host Loop
@unsafe def versus_host_step_run(restart: Bool, p: Nat, +k1: U32, +k2: U32, vg: Snake.VersusState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match restart:
    case True{}:
      +new_vg : Snake.VersusState = Snake.restart_versus_game(vg)
      +nr : Snake.RestartVote = Snake.restart_none()
      frame : String = Snake.render_versus_frame(new_vg, 24n, d, nr, False{})
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(Snake.calc_tick_ms(d, 0))
        versus_host_loop(p, new_vg, d, nr)
    case False{}:
      +next_vg : Snake.VersusState = Snake.step_versus(vg, k1, k2, 24, 16)
      frame : String = Snake.render_versus_frame(next_vg, 24n, d, rv, False{})
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(Snake.calc_tick_ms(d, Snake.get_versus_max_score(next_vg)))
        versus_host_loop(p, next_vg, d, rv)

@unsafe def versus_host_step_menu(go_menu: Bool, p: Nat, +k1: U32, +k2: U32, vg: Snake.VersusState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match go_menu:
    case True{}:
      net_return_to_menu(d)
    case False{}:
      +next_rv : Snake.RestartVote = Snake.vote_restart(rv, is_restart(k1), is_restart(k2))
      versus_host_step_run(Snake.both_restart(next_rv), p, k1, k2, vg, d, next_rv)

@unsafe def versus_host_step(quit: Bool, p: Nat, +k1: U32, +k2: U32, vg: Snake.VersusState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match quit:
    case True{}:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case False{}:
      versus_host_step_menu(is_menu(k1) || is_menu(k2) || is_quit(k2), p, k1, k2, vg, d, rv)

@unsafe def versus_host_loop(fuel: Nat, vg: Snake.VersusState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
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
        versus_host_step(is_quit(k1), p, k1, k2, vg, d, rv)

# LAN Versus Join Loop
@unsafe def versus_join_step_run(restart: Bool, p: Nat, +k1: U32, +k2: U32, vg: Snake.VersusState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match restart:
    case True{}:
      +new_vg : Snake.VersusState = Snake.restart_versus_game(vg)
      +nr : Snake.RestartVote = Snake.restart_none()
      frame : String = Snake.render_versus_frame(new_vg, 24n, d, nr, False{})
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(Snake.calc_tick_ms(d, 0))
        versus_join_loop(p, new_vg, d, nr)
    case False{}:
      +next_vg : Snake.VersusState = Snake.step_versus(vg, k1, k2, 24, 16)
      frame : String = Snake.render_versus_frame(next_vg, 24n, d, rv, False{})
      do IO<Unit>:
        IO.write(frame)
        IO.sleep(Snake.calc_tick_ms(d, Snake.get_versus_max_score(next_vg)))
        versus_join_loop(p, next_vg, d, rv)

@unsafe def versus_join_step_menu(go_menu: Bool, p: Nat, +k1: U32, +k2: U32, vg: Snake.VersusState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match go_menu:
    case True{}:
      net_return_to_menu(d)
    case False{}:
      +next_rv : Snake.RestartVote = Snake.vote_restart(rv, is_restart(k1), is_restart(k2))
      versus_join_step_run(Snake.both_restart(next_rv), p, k1, k2, vg, d, next_rv)

@unsafe def versus_join_step(quit: Bool, p: Nat, +k1: U32, +k2: U32, vg: Snake.VersusState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
  match quit:
    case True{}:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case False{}:
      versus_join_step_menu(is_menu(k1) || is_menu(k2) || is_quit(k1), p, k1, k2, vg, d, rv)

@unsafe def versus_join_loop(fuel: Nat, vg: Snake.VersusState, +d: Snake.Diff, +rv: Snake.RestartVote) -> IO(Unit):
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
        versus_join_step(is_quit(k2), p, k1, k2, vg, d, rv)

# Waiting for LAN Client
@unsafe def wait_host_dispatch(+mode: U32, +d: Snake.Diff) -> IO(Unit):
  match mode:
    case 2:
      do IO<Unit>:
        +seed : U32 <- Term.get_random_seed()
        +g : Snake.GameState = Snake.new_game(seed, 0)
        +nr : Snake.RestartVote = Snake.restart_none()
        frame : String = Snake.render_coop_frame(g, 24n, d, nr, False{})
        IO.write(frame)
        coop_host_loop(1000000n, g, d, nr)
    case 4:
      do IO<Unit>:
        +seed : U32 <- Term.get_random_seed()
        +vg : Snake.VersusState = Snake.new_versus_game(seed)
        +nr : Snake.RestartVote = Snake.restart_none()
        frame : String = Snake.render_versus_frame(vg, 24n, d, nr, False{})
        IO.write(frame)
        versus_host_loop(1000000n, vg, d, nr)
    case _:
      Term.restore()

@unsafe def wait_host_check(is_ok: Bool, p: Nat, +mode: U32, +d: Snake.Diff) -> IO(Unit):
  match is_ok:
    case True{}:
      wait_host_dispatch(mode, d)
    case False{}:
      do IO<Unit>:
        IO.sleep(100)
        wait_host(p, mode, d)

@unsafe def wait_host_step_menu(go_menu: Bool, p: Nat, +mode: U32, +d: Snake.Diff) -> IO(Unit):
  match go_menu:
    case True{}:
      net_return_to_menu(d)
    case False{}:
      do IO<Unit>:
        Term.net_beacon_tick(mode)
        +ok : U32 <- Term.net_accept()
        wait_host_check(U32.is_eq(ok, 1), p, mode, d)

@unsafe def wait_host_step(quit: Bool, go_menu: Bool, p: Nat, +mode: U32, +d: Snake.Diff) -> IO(Unit):
  match quit:
    case True{}:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case False{}:
      wait_host_step_menu(go_menu, p, mode, d)

@unsafe def wait_host(fuel: Nat, +mode: U32, +d: Snake.Diff) -> IO(Unit):
  match fuel:
    case 0n:
      do IO<Unit>:
        Term.net_close()
        Term.restore()
    case 1n+p:
      do IO<Unit>:
        +k : U32 <- Term.poll_key()
        wait_host_step(is_quit(k), is_menu(k), p, mode, d)

@unsafe def join_coop_step(is_ok: Bool, +fallback_d: Snake.Diff) -> IO(Unit):
  match is_ok:
    case True{}:
      do IO<Unit>:
        +seed : U32 <- Term.get_random_seed()
        diff_u : U32 <- Term.net_get_lan_diff()
        +d : Snake.Diff = Snake.u32_to_diff(diff_u)
        +g : Snake.GameState = Snake.new_game(seed, 0)
        +nr : Snake.RestartVote = Snake.restart_none()
        frame : String = Snake.render_coop_frame(g, 24n, d, nr, False{})
        IO.write(frame)
        coop_join_loop(1000000n, g, d, nr)
    case False{}:
      do IO<Unit>:
        IO.print("\nFailed to connect to host. Returning to menu...\n")
        IO.sleep(1500)
        return_to_menu(fallback_d)

@unsafe def join_versus_step(is_ok: Bool, +fallback_d: Snake.Diff) -> IO(Unit):
  match is_ok:
    case True{}:
      do IO<Unit>:
        +seed : U32 <- Term.get_random_seed()
        diff_u : U32 <- Term.net_get_lan_diff()
        +d : Snake.Diff = Snake.u32_to_diff(diff_u)
        +vg : Snake.VersusState = Snake.new_versus_game(seed)
        +nr : Snake.RestartVote = Snake.restart_none()
        frame : String = Snake.render_versus_frame(vg, 24n, d, nr, False{})
        IO.write(frame)
        versus_join_loop(1000000n, vg, d, nr)
    case False{}:
      do IO<Unit>:
        IO.print("\nFailed to connect to host. Returning to menu...\n")
        IO.sleep(1500)
        return_to_menu(fallback_d)

@unsafe def join_browse_dispatch(+joined_mode: U32, +d: Snake.Diff) -> IO(Unit):
  match joined_mode:
    case 2:
      join_coop_step(True{}, d)
    case 4:
      join_versus_step(True{}, d)
    case _:
      return_to_menu(d)

# Main Menu Dispatcher
@unsafe def menu_select(+choice: U32, +d: Snake.Diff) -> IO(Unit):
  match choice:
    case 49:
      # [1] Solo Classic
      do IO<Unit>:
        saved_high : U32 <- Term.load_high_score(Snake.diff_to_u32(d))
        +seed : U32 <- Term.get_random_seed()
        +g : Snake.GameState = Snake.new_game(seed, saved_high)
        frame : String = Snake.render_frame(g, 24n, d)
        IO.write(frame)
        solo_loop(1000000n, g, d)
    case 50:
      # [2] Host LAN Co-op
      do IO<Unit>:
        Term.net_set_lan_mode(2)
        Term.net_set_lan_diff(Snake.diff_to_u32(d))
        _ : U32 <- Term.net_listen(4242)
        wait_host(100000n, 2, d)
    case 51:
      # [3] Host LAN Versus
      do IO<Unit>:
        Term.net_set_lan_mode(4)
        Term.net_set_lan_diff(Snake.diff_to_u32(d))
        _ : U32 <- Term.net_listen(4242)
        wait_host(100000n, 4, d)
    case 52:
      # [4] Join LAN Room (Interactive Browser)
      do IO<Unit>:
        joined_mode : U32 <- Term.net_browse_join()
        join_browse_dispatch(joined_mode, d)
    case 53:
      # [5] Local Co-op
      do IO<Unit>:
        +seed : U32 <- Term.get_random_seed()
        +g : Snake.GameState = Snake.new_game(seed, 0)
        +nr : Snake.RestartVote = Snake.restart_none()
        frame : String = Snake.render_coop_frame(g, 24n, d, nr, True{})
        IO.write(frame)
        coop_local_loop(1000000n, g, d, nr)
    case 54:
      # [6] Local Versus
      do IO<Unit>:
        +seed : U32 <- Term.get_random_seed()
        +vg : Snake.VersusState = Snake.new_versus_game(seed)
        +nr : Snake.RestartVote = Snake.restart_none()
        frame : String = Snake.render_versus_frame(vg, 24n, d, nr, True{})
        IO.write(frame)
        versus_local_loop(1000000n, vg, d, nr)
    case 100:
      # [D] Cycle Difficulty Forward
      +nd = Snake.next_diff(d)
      do IO<Unit>:
        IO.write(Snake.render_menu(nd))
        menu_loop(100000n, nd)
    case 203:
      # [Right] Cycle Difficulty Forward
      +nd = Snake.next_diff(d)
      do IO<Unit>:
        IO.write(Snake.render_menu(nd))
        menu_loop(100000n, nd)
    case 202:
      # [Left] Cycle Difficulty Backward
      +pd = Snake.prev_diff(d)
      do IO<Unit>:
        IO.write(Snake.render_menu(pd))
        menu_loop(100000n, pd)
    case 113:
      # [Q] Quit
      Term.restore()
    case _:
      menu_loop(100000n, d)

@unsafe def menu_step(is_zero: Bool, p: Nat, +k: U32, +d: Snake.Diff) -> IO(Unit):
  match is_zero:
    case True{}:
      do IO<Unit>:
        IO.sleep(80)
        menu_loop(p, d)
    case False{}:
      menu_select(k, d)

@unsafe def menu_loop(fuel: Nat, +d: Snake.Diff) -> IO(Unit):
  match fuel:
    case 0n:
      Term.restore()
    case 1n+p:
      do IO<Unit>:
        +k : U32 <- Term.poll_key()
        menu_step(U32.is_eq(k, 0), p, k, d)

@unsafe def main() -> IO(Unit):
  +d : Snake.Diff = Snake.Normal{}
  do IO<Unit>:
    Term.init()
    Term.check_update()
    IO.write(Snake.render_menu(d))
    menu_loop(100000n, d)
