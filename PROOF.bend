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

def Laws.turn_coop_idle_preserves(d):
  {==}

def Laws.turn_coop_p1_steers():
  {==}

def Laws.turn_coop_p2_steers():
  {==}

def Laws.versus_outcome_active():
  {==}

def Laws.versus_outcome_p1win():
  {==}

def Laws.versus_outcome_p2win():
  {==}

def Laws.versus_outcome_draw():
  {==}

def Laws.versus_new_game_active(seed):
  {==}

def Laws.diff_cycle_4(d):
  match d:
    case Snake.Easy{}:
      {==}
    case Snake.Normal{}:
      {==}
    case Snake.Hard{}:
      {==}
    case Snake.Turbo{}:
      {==}

def Laws.diff_next_prev(d):
  match d:
    case Snake.Easy{}:
      {==}
    case Snake.Normal{}:
      {==}
    case Snake.Hard{}:
      {==}
    case Snake.Turbo{}:
      {==}

def Laws.diff_roundtrip(d):
  match d:
    case Snake.Easy{}:
      {==}
    case Snake.Normal{}:
      {==}
    case Snake.Hard{}:
      {==}
    case Snake.Turbo{}:
      {==}

def Laws.diff_easy_steady(score):
  {==}

def Laws.diff_normal_base():
  {==}

def Laws.diff_hard_base():
  {==}

def Laws.diff_turbo_base():
  {==}

def Laws.diff_normal_floor():
  {==}

def Laws.restart_requires_both_p1_only():
  {==}

def Laws.restart_requires_both_p2_only():
  {==}

def Laws.restart_works_when_both():
  {==}

def Laws.versus_new_starts_zero_wins1(seed):
  {==}

def Laws.versus_new_starts_zero_wins2(seed):
  {==}

def Laws.versus_restart_preserves_wins1(seed, w1, w2):
  {==}

def Laws.versus_restart_preserves_wins2(seed, w1, w2):
  {==}
