let keyQueue = [];
let listenerAttached = false;

function attachListener() {
  if (!listenerAttached && process.stdin) {
    listenerAttached = true;
    process.stdin.on("data", (chunk) => {
      let i = 0;
      while (i < chunk.length) {
        if (chunk[i] === 27 && i + 2 < chunk.length && chunk[i+1] === 91) {
          const code = chunk[i+2];
          if (code === 65) keyQueue.push(119);      // Up -> 'w'
          else if (code === 66) keyQueue.push(115); // Down -> 's'
          else if (code === 67) keyQueue.push(100); // Right -> 'd'
          else if (code === 68) keyQueue.push(97);  // Left -> 'a'
          i += 3;
        } else if (chunk[i] === 27) {
          keyQueue.push(113); // Escape -> 'q'
          i += 1;
        } else {
          let b = chunk[i];
          if (b >= 65 && b <= 90) b += 32;
          keyQueue.push(b);
          i += 1;
        }
      }
    });
  }
}

function term_init() {
  try {
    if (process.stdin.setRawMode) {
      process.stdin.setRawMode(true);
      process.stdin.resume();
    }
  } catch (e) {}
  attachListener();
  process.stdout.write("\x1b[2J\x1b[H\x1b[?25l");
  return {$: CID(Unit)};
}

function term_restore() {
  try {
    if (process.stdin.setRawMode) {
      process.stdin.setRawMode(false);
    }
  } catch (e) {}
  process.stdout.write("\x1b[?25h\n");
  return {$: CID(Unit)};
}

function term_poll_key() {
  attachListener();
  if (keyQueue.length > 0) {
    return keyQueue.shift() >>> 0;
  }
  return 0;
}

function load_high_score() {
  try {
    const fs = require("fs");
    if (fs.existsSync("highscore.txt")) {
      const txt = fs.readFileSync("highscore.txt", "utf8").trim();
      const n = parseInt(txt, 10);
      if (!isNaN(n) && n >= 0) return n >>> 0;
    }
  } catch (e) {}
  return 0;
}

function save_high_score(score) {
  try {
    require("fs").writeFileSync("highscore.txt", `${score}\n`);
  } catch (e) {}
  return {$: CID(Unit)};
}

io_eff(CID(init), term_init);
io_eff(CID(restore), term_restore);
io_eff(CID(poll_key), term_poll_key);
io_eff(CID(load_high_score), load_high_score);
io_eff(CID(save_high_score), save_high_score);
