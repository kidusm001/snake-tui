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
          if (code === 65) keyQueue.push(200);      // Up -> 200
          else if (code === 66) keyQueue.push(201); // Down -> 201
          else if (code === 67) keyQueue.push(203); // Right -> 203
          else if (code === 68) keyQueue.push(202); // Left -> 202
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

const BSNK_MAGIC = 0x4B4E5342;
const BSNK_MASK = 0x534E414B;
const BSNK_SALT = 0x1337BEEF;

function bsnk_checksum(score) {
  return ((score ^ 0xA5A5A5A5) + BSNK_SALT) >>> 0;
}

function high_score_file(diff) {
  if (diff === 0) return "highscore_easy.bin";
  if (diff === 2) return "highscore_hard.bin";
  if (diff === 3) return "highscore_turbo.bin";
  return "highscore.bin";
}

function load_high_score(diff) {
  try {
    const fs = require("fs");
    const fname = high_score_file(diff);
    if (fs.existsSync(fname)) {
      const buf = fs.readFileSync(fname);
      if (buf.length === 16) {
        const magic = buf.readUInt32LE(0);
        const version = buf.readUInt16LE(4);
        if (magic === BSNK_MAGIC && version === 1) {
          const maskedScore = buf.readUInt32LE(8);
          const checksum = buf.readUInt32LE(12);
          const score = (maskedScore ^ BSNK_MASK) >>> 0;
          if (checksum === bsnk_checksum(score)) {
            return score;
          }
        }
      }
    } else if (diff === 1 && fs.existsSync("highscore.txt")) {
      const txt = fs.readFileSync("highscore.txt", "utf8").trim();
      const n = parseInt(txt, 10);
      if (!isNaN(n) && n >= 0) {
        save_high_score(n >>> 0, diff);
        try { fs.unlinkSync("highscore.txt"); } catch (_) {}
        return n >>> 0;
      }
    }
  } catch (e) {}
  return 0;
}

function save_high_score(score, diff) {
  try {
    const fs = require("fs");
    const buf = Buffer.alloc(16);
    buf.writeUInt32LE(BSNK_MAGIC, 0);
    buf.writeUInt16LE(1, 4);
    buf.writeUInt16LE((diff || 0) & 0xFFFF, 6);
    buf.writeUInt32LE((score ^ BSNK_MASK) >>> 0, 8);
    buf.writeUInt32LE(bsnk_checksum(score), 12);
    fs.writeFileSync(high_score_file(diff), buf);
  } catch (e) {}
  return {$: CID(Unit)};
}

io_eff(CID(init), term_init);
io_eff(CID(restore), term_restore);
io_eff(CID(poll_key), term_poll_key);
io_eff(CID(load_high_score), load_high_score);
io_eff(CID(save_high_score), save_high_score);

let netServer = null;
let netClient = null;
let netKeyQueue = [];

function net_listen(port) {
  try {
    const net = require("net");
    net_close();
    netServer = net.createServer((socket) => {
      netClient = socket;
      socket.on("data", (chunk) => {
        let offset = 0;
        while (offset + 4 <= chunk.length) {
          netKeyQueue.push(chunk.readUInt32LE(offset));
          offset += 4;
        }
      });
      socket.on("close", () => {
        netKeyQueue.push(113);
      });
    });
    netServer.listen(port, "0.0.0.0");
    return 1;
  } catch (e) {
    return 0;
  }
}

function net_accept() {
  return netClient ? 1 : 0;
}

function net_prompt_join(port) {
  try {
    const net = require("net");
    const fs = require("fs");
    let ip = process.env.BEND_SNAKE_HOST || "127.0.0.1";
    if (!process.env.BEND_SNAKE_HOST && fs.existsSync("host.txt")) {
      ip = fs.readFileSync("host.txt", "utf8").trim() || "127.0.0.1";
    }
    if (ip.includes(":")) {
      const parts = ip.split(":");
      ip = parts[0];
      const p = parseInt(parts[1], 10);
      if (p > 0) port = p;
    }
    net_close();
    netClient = new net.Socket();
    netClient.connect(port, ip);
    netClient.on("data", (chunk) => {
      let offset = 0;
      while (offset + 4 <= chunk.length) {
        netKeyQueue.push(chunk.readUInt32LE(offset));
        offset += 4;
      }
    });
    netClient.on("close", () => {
      netKeyQueue.push(113);
    });
    return 1;
  } catch (e) {
    return 0;
  }
}

function net_send_key(k) {
  try {
    if (netClient && !netClient.destroyed) {
      const buf = Buffer.alloc(4);
      buf.writeUInt32LE(k >>> 0, 0);
      netClient.write(buf);
    }
  } catch (e) {}
  return {$: CID(Unit)};
}

function net_recv_key() {
  if (netKeyQueue.length > 0) {
    return netKeyQueue.shift() >>> 0;
  }
  return 0;
}

let beaconSocket = null;

function net_beacon_tick(mode) {
  try {
    const dgram = require("dgram");
    if (!beaconSocket) {
      beaconSocket = dgram.createSocket({ type: "udp4", reuseAddr: true });
      beaconSocket.bind(() => {
        try { beaconSocket.setBroadcast(true); } catch (_) {}
      });
    }
    const msg = Buffer.from(`BSNK_ROOM:${mode}`);
    beaconSocket.send(msg, 0, msg.length, 4243, "255.255.255.255");
    beaconSocket.send(msg, 0, msg.length, 4243, "127.0.0.1");
  } catch (e) {}
  return {$: CID(Unit)};
}

function net_auto_join(mode) {
  return net_prompt_join(4242);
}

function get_random_seed() {
  const s = Math.floor(Math.random() * 0x7FFFFFFF) >>> 0;
  return s === 0 ? 1337 : s;
}

let lanDiff = 1;

function net_set_lan_diff(diff) {
  lanDiff = diff >>> 0;
  return {$: CID(Unit)};
}

function net_get_lan_diff() {
  return lanDiff >>> 0;
}

function check_update() {
  return {$: CID(Unit)};
}

function net_close() {
  try {
    if (netClient) { netClient.destroy(); netClient = null; }
    if (netServer) { netServer.close(); netServer = null; }
    if (beaconSocket) { beaconSocket.close(); beaconSocket = null; }
  } catch (e) {}
  return {$: CID(Unit)};
}

io_eff(CID(net_listen), net_listen);
io_eff(CID(net_accept), net_accept);
io_eff(CID(net_prompt_join), net_prompt_join);
io_eff(CID(net_auto_join), net_auto_join);
io_eff(CID(net_beacon_tick), net_beacon_tick);
io_eff(CID(net_send_key), net_send_key);
io_eff(CID(net_recv_key), net_recv_key);
io_eff(CID(net_close), net_close);
io_eff(CID(get_random_seed), get_random_seed);
io_eff(CID(check_update), check_update);
io_eff(CID(net_set_lan_diff), net_set_lan_diff);
io_eff(CID(net_get_lan_diff), net_get_lan_diff);
