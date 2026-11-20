import Base
import ./snake.bend as Snake
import ./LAWS.bend as Laws

def Laws.opp_involutive(d):
  match d:
    case Snake.Up{}:
      {==}
    case Snake.Down{}:
      {==}
    case Snake.Left{}:
      {==}
    case Snake.Right{}:
      {==}

def Laws.turn_prevent_reverse_up():
  {==}

def Laws.turn_prevent_reverse_down():
  {==}

def Laws.turn_prevent_reverse_left():
  {==}

def Laws.turn_prevent_reverse_right():
  {==}

def Laws.turn_allow_up_right():
  {==}

def Laws.turn_allow_up_left():
  {==}

def Laws.turn_allow_down_right():
  {==}

def Laws.turn_allow_down_left():
  {==}

def Laws.key_w_maps_up():
  {==}

def Laws.key_s_maps_down():
  {==}

def Laws.key_a_maps_left():
  {==}

def Laws.key_d_maps_right():
  {==}

def Laws.key_idle_preserves():
  {==}

def Laws.move_up_decrements_y():
  {==}

def Laws.move_down_increments_y():
  {==}

def Laws.move_left_decrements_x():
  {==}

def Laws.move_right_increments_x():
  {==}

def Laws.origin_in_bounds():
  {==}

def Laws.max_corner_in_bounds():
  {==}

def Laws.width_overflow_out_of_bounds():
  {==}

def Laws.height_overflow_out_of_bounds():
  {==}

def Laws.grow_adds_head(p, body):
  {==}

def Laws.contains_empty_false(p):
  {==}

def Laws.max_score_higher():
  {==}

def Laws.max_score_lower():
  {==}

def Laws.max_score_equal():
  {==}

def Laws.new_game_sets_highscore(seed, h):
  {==}

def Laws.pick_food_rejects_collision(cand, alt):
  {==}

def Laws.pick_food_accepts_free(cand, alt):
  {==}

def Laws.is_snake_cell_free():
  {==}

def Laws.is_snake_cell_head(body):
  {==}

def Laws.is_snake_cell_body():
  {==}

def Laws.step_inactive_game_stays_dead():
  {==}
