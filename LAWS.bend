import Base
import ./snake.bend as Snake

law opp_involutive:
  for d: Snake.Dir
  {Snake.opp(Snake.opp(d)) == d : Snake.Dir}

law turn_prevent_reverse_up:
  {Snake.turn(Snake.Up{}, Snake.Down{}) == Snake.Up{} : Snake.Dir}

law turn_prevent_reverse_down:
  {Snake.turn(Snake.Down{}, Snake.Up{}) == Snake.Down{} : Snake.Dir}

law turn_prevent_reverse_left:
  {Snake.turn(Snake.Left{}, Snake.Right{}) == Snake.Left{} : Snake.Dir}

law turn_prevent_reverse_right:
  {Snake.turn(Snake.Right{}, Snake.Left{}) == Snake.Right{} : Snake.Dir}

law turn_allow_up_right:
  {Snake.turn(Snake.Up{}, Snake.Right{}) == Snake.Right{} : Snake.Dir}

law turn_allow_up_left:
  {Snake.turn(Snake.Up{}, Snake.Left{}) == Snake.Left{} : Snake.Dir}

law turn_allow_down_right:
  {Snake.turn(Snake.Down{}, Snake.Right{}) == Snake.Right{} : Snake.Dir}

law turn_allow_down_left:
  {Snake.turn(Snake.Down{}, Snake.Left{}) == Snake.Left{} : Snake.Dir}

law key_w_maps_up:
  {Snake.key_to_dir(119, Snake.Right{}) == Snake.Up{} : Snake.Dir}

law key_s_maps_down:
  {Snake.key_to_dir(115, Snake.Right{}) == Snake.Down{} : Snake.Dir}

law key_a_maps_left:
  {Snake.key_to_dir(97, Snake.Up{}) == Snake.Left{} : Snake.Dir}

law key_d_maps_right:
  {Snake.key_to_dir(100, Snake.Up{}) == Snake.Right{} : Snake.Dir}

law key_idle_preserves:
  {Snake.key_to_dir(0, Snake.Up{}) == Snake.Up{} : Snake.Dir}

law move_up_decrements_y:
  {Snake.move_pos(Snake.Pos{10, 10}, Snake.Up{}) == Snake.Pos{10, 9} : Snake.Pos}

law move_down_increments_y:
  {Snake.move_pos(Snake.Pos{10, 10}, Snake.Down{}) == Snake.Pos{10, 11} : Snake.Pos}

law move_left_decrements_x:
  {Snake.move_pos(Snake.Pos{10, 10}, Snake.Left{}) == Snake.Pos{9, 10} : Snake.Pos}

law move_right_increments_x:
  {Snake.move_pos(Snake.Pos{10, 10}, Snake.Right{}) == Snake.Pos{11, 10} : Snake.Pos}

law origin_in_bounds:
  {Snake.is_out_of_bounds(Snake.Pos{0, 0}, 24, 16) == False{} : Bool}

law max_corner_in_bounds:
  {Snake.is_out_of_bounds(Snake.Pos{23, 15}, 24, 16) == False{} : Bool}

law width_overflow_out_of_bounds:
  {Snake.is_out_of_bounds(Snake.Pos{24, 5}, 24, 16) == True{} : Bool}

law height_overflow_out_of_bounds:
  {Snake.is_out_of_bounds(Snake.Pos{5, 16}, 24, 16) == True{} : Bool}

law grow_adds_head:
  for p: Snake.Pos
  for body: +List<Snake.Pos>
  {Snake.grow(p, body) == Con{p, body} : +List<Snake.Pos>}

law contains_empty_false:
  for p: Snake.Pos
  {Snake.contains_pos(Nil{}, p) == False{} : Bool}

law max_score_higher:
  {Snake.max_score(50, 20) == 50 : U32}

law max_score_lower:
  {Snake.max_score(20, 50) == 50 : U32}

law max_score_equal:
  {Snake.max_score(30, 30) == 30 : U32}

law new_game_sets_highscore:
  for seed: U32
  for h: U32
  {Snake.get_high_score(Snake.new_game(seed, h)) == h : U32}

law pick_food_rejects_collision:
  for cand: Snake.FoodSeed
  for alt: Snake.FoodSeed
  {Snake.pick_food(True{}, cand, alt) == alt : Snake.FoodSeed}

law pick_food_accepts_free:
  for cand: Snake.FoodSeed
  for alt: Snake.FoodSeed
  {Snake.pick_food(False{}, cand, alt) == cand : Snake.FoodSeed}

law is_snake_cell_free:
  {Snake.is_snake_cell(Snake.Pos{1, 1}, Snake.Pos{5, 5}, Nil{}) == False{} : Bool}

law is_snake_cell_head:
  for body: +List<Snake.Pos>
  {Snake.is_snake_cell(Snake.Pos{5, 5}, Snake.Pos{5, 5}, body) == True{} : Bool}

law is_snake_cell_body:
  {Snake.is_snake_cell(Snake.Pos{5, 5}, Snake.Pos{0, 0}, Con{Snake.Pos{5, 5}, Nil{}}) == True{} : Bool}

law step_inactive_game_stays_dead:
  {Snake.step_game(Snake.Game{Snake.Pos{0, 0}, Nil{}, Snake.Right{}, Snake.Pos{5, 5}, 10, 20, False{}, 123}, 0, 24, 16) == Snake.Game{Snake.Pos{0, 0}, Nil{}, Snake.Right{}, Snake.Pos{5, 5}, 10, 20, False{}, 123} : Snake.GameState}

law turn_coop_idle_preserves:
  for d: Snake.Dir
  {Snake.turn_coop(d, 0, 0) == d : Snake.Dir}

law turn_coop_p1_steers:
  {Snake.turn_coop(Snake.Right{}, 119, 0) == Snake.Up{} : Snake.Dir}

law turn_coop_p2_steers:
  {Snake.turn_coop(Snake.Right{}, 0, 119) == Snake.Up{} : Snake.Dir}

law versus_outcome_active:
  {Snake.versus_outcome(False{}, False{}) == Snake.Active{} : Snake.VersusWinner}

law versus_outcome_p1win:
  {Snake.versus_outcome(False{}, True{}) == Snake.P1Win{} : Snake.VersusWinner}

law versus_outcome_p2win:
  {Snake.versus_outcome(True{}, False{}) == Snake.P2Win{} : Snake.VersusWinner}

law versus_outcome_draw:
  {Snake.versus_outcome(True{}, True{}) == Snake.Draw{} : Snake.VersusWinner}

law versus_new_game_active:
  for seed: U32
  {Snake.is_versus_over(Snake.new_versus_game(seed)) == False{} : Bool}

law diff_cycle_4:
  for d: Snake.Diff
  {Snake.next_diff(Snake.next_diff(Snake.next_diff(Snake.next_diff(d)))) == d : Snake.Diff}

law diff_next_prev:
  for d: Snake.Diff
  {Snake.prev_diff(Snake.next_diff(d)) == d : Snake.Diff}

law diff_roundtrip:
  for d: Snake.Diff
  {Snake.u32_to_diff(Snake.diff_to_u32(d)) == d : Snake.Diff}

law diff_easy_steady:
  for score: U32
  {Snake.calc_tick_ms(Snake.Easy{}, score) == 165 : U32}

law diff_normal_base:
  {Snake.calc_tick_ms(Snake.Normal{}, 0) == 120 : U32}

law diff_hard_base:
  {Snake.calc_tick_ms(Snake.Hard{}, 0) == 85 : U32}

law diff_turbo_base:
  {Snake.calc_tick_ms(Snake.Turbo{}, 0) == 60 : U32}

law diff_normal_floor:
  {Snake.calc_tick_ms(Snake.Normal{}, 1000) == 75 : U32}

law restart_requires_both_p1_only:
  {Snake.both_restart(Snake.vote_restart(Snake.restart_none(), True{}, False{})) == False{} : Bool}

law restart_requires_both_p2_only:
  {Snake.both_restart(Snake.vote_restart(Snake.restart_none(), False{}, True{})) == False{} : Bool}

law restart_works_when_both:
  {Snake.both_restart(Snake.vote_restart(Snake.vote_restart(Snake.restart_none(), True{}, False{}), False{}, True{})) == True{} : Bool}

law versus_new_starts_zero_wins1:
  for seed: U32
  {Snake.get_versus_wins1(Snake.new_versus_game(seed)) == 0 : U32}

law versus_new_starts_zero_wins2:
  for seed: U32
  {Snake.get_versus_wins2(Snake.new_versus_game(seed)) == 0 : U32}

law versus_restart_preserves_wins1:
  for seed: U32
  for w1: U32
  for w2: U32
  {Snake.get_versus_wins1(Snake.restart_versus_game(Snake.new_versus_game_match(seed, w1, w2))) == w1 : U32}

law versus_restart_preserves_wins2:
  for seed: U32
  for w1: U32
  for w2: U32
  {Snake.get_versus_wins2(Snake.restart_versus_game(Snake.new_versus_game_match(seed, w1, w2))) == w2 : U32}
