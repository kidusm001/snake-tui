import Base

def init() -> IO(Unit):
  import "./terminal.c"
  import "./terminal.js"

def restore() -> IO(Unit):
  import "./terminal.c"
  import "./terminal.js"

def poll_key() -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"

def load_high_score(diff: U32) -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"

def save_high_score(score: U32, diff: U32) -> IO(Unit):
  import "./terminal.c"
  import "./terminal.js"

def net_set_lan_diff(diff: U32) -> IO(Unit):
  import "./terminal.c"
  import "./terminal.js"

def net_get_lan_diff() -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"

def net_set_lan_mode(mode: U32) -> IO(Unit):
  import "./terminal.c"
  import "./terminal.js"

def net_browse_join() -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"

def net_listen(port: U32) -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"

def net_accept() -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"

def net_beacon_tick(mode: U32) -> IO(Unit):
  import "./terminal.c"
  import "./terminal.js"

def net_send_key(k: U32) -> IO(Unit):
  import "./terminal.c"
  import "./terminal.js"

def net_recv_key() -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"

def get_random_seed() -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"

def check_update() -> IO(Unit):
  import "./terminal.c"
  import "./terminal.js"

def net_close() -> IO(Unit):
  import "./terminal.c"
  import "./terminal.js"

def get_term_cols() -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"

def get_term_rows() -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"
