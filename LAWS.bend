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
