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

def load_high_score() -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"

def save_high_score(score: U32) -> IO(Unit):
  import "./terminal.c"
  import "./terminal.js"

def net_listen(port: U32) -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"

def net_accept() -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"

def net_prompt_join(port: U32) -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"

def net_beacon_tick(mode: U32) -> IO(Unit):
  import "./terminal.c"
  import "./terminal.js"

def net_auto_join(mode: U32) -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"

def net_send_key(k: U32) -> IO(Unit):
  import "./terminal.c"
  import "./terminal.js"

def net_recv_key() -> IO(U32):
  import "./terminal.c"
  import "./terminal.js"

def net_close() -> IO(Unit):
  import "./terminal.c"
  import "./terminal.js"
