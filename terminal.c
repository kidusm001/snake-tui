#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <poll.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <time.h>
#include <ctype.h>
#include <string.h>
#include <errno.h>

static struct termios orig_termios;
static int raw_mode_set = 0;

Term term_init_run(Env e, Term* f, IoWork* w) {
  if (!raw_mode_set) {
    if (tcgetattr(STDIN_FILENO, &orig_termios) == 0) {
      struct termios raw = orig_termios;
      raw.c_lflag &= ~(ECHO | ICANON | ISIG);
      raw.c_iflag &= ~(IXON | ICRNL);
      raw.c_cc[VMIN] = 0;
      raw.c_cc[VTIME] = 0;
      tcsetattr(STDIN_FILENO, TCSANOW, &raw);
      raw_mode_set = 1;
    }
  }
  write(STDOUT_FILENO, "\x1b[2J\x1b[H\x1b[?25l", 13);
  return term_pak(CID(Unit), 0);
}

Term term_restore_run(Env e, Term* f, IoWork* w) {
  if (raw_mode_set) {
    tcsetattr(STDIN_FILENO, TCSANOW, &orig_termios);
    raw_mode_set = 0;
  }
  write(STDOUT_FILENO, "\x1b[?25h\n", 7);
  return term_pak(CID(Unit), 0);
}

Term term_poll_key_run(Env e, Term* f, IoWork* w) {
  unsigned char ch = 0;
  ssize_t n = read(STDIN_FILENO, &ch, 1);
  if (n <= 0) {
    return (Term)0;
  }
  if (ch == 27) {
    unsigned char seq[2] = {0, 0};
    if (read(STDIN_FILENO, &seq[0], 1) > 0 && read(STDIN_FILENO, &seq[1], 1) > 0) {
      if (seq[0] == '[') {
        if (seq[1] == 'A') return (Term)(uint32_t)200; // Arrow Up
        if (seq[1] == 'B') return (Term)(uint32_t)201; // Arrow Down
        if (seq[1] == 'C') return (Term)(uint32_t)203; // Arrow Right
        if (seq[1] == 'D') return (Term)(uint32_t)202; // Arrow Left
      }
    }
    return (Term)(uint32_t)'q';
  }
  if (ch >= 'A' && ch <= 'Z') {
    ch += ('a' - 'A');
  }
  return (Term)(uint32_t)ch;
}

#define BSNK_MAGIC 0x4B4E5342u
#define BSNK_MASK  0x534E414Bu
#define BSNK_SALT  0x1337BEEFu

struct __attribute__((packed)) HighScoreRecord {
  uint32_t magic;
  uint16_t version;
  uint16_t flags;
  uint32_t masked_score;
  uint32_t checksum;
};

static uint32_t bsnk_checksum(uint32_t score) {
  return (score ^ 0xA5A5A5A5u) + BSNK_SALT;
}

static void get_data_file(const char* name, char* out, size_t outlen) {
  const char* xdg = getenv("XDG_DATA_HOME");
  const char* home = getenv("HOME");
  char dir[512];
  if (xdg && strlen(xdg) > 0) {
    mkdir(xdg, 0755);
    snprintf(dir, sizeof(dir), "%s/snake-tui", xdg);
  } else if (home && strlen(home) > 0) {
    char p1[512];
    snprintf(p1, sizeof(p1), "%s/.local", home);
    mkdir(p1, 0755);
    snprintf(p1, sizeof(p1), "%s/.local/share", home);
    mkdir(p1, 0755);
    snprintf(dir, sizeof(dir), "%s/.local/share/snake-tui", home);
  } else {
    snprintf(out, outlen, "%s", name);
    return;
  }
  mkdir(dir, 0755);
  snprintf(out, outlen, "%s/%s", dir, name);
}

static const char* high_score_filename(uint32_t diff) {
  switch (diff) {
    case 0: return "highscore_easy.bin";
    case 2: return "highscore_hard.bin";
    case 3: return "highscore_turbo.bin";
    default: return "highscore.bin";
  }
}

Term save_high_score_run(Env e, Term* f, IoWork* w) {
  uint32_t s = (uint32_t)f[0];
  uint32_t diff = (uint32_t)f[1];
  char path[600];
  get_data_file(high_score_filename(diff), path, sizeof(path));
  FILE* fp = fopen(path, "wb");
  if (fp) {
    struct HighScoreRecord rec;
    rec.magic = BSNK_MAGIC;
    rec.version = 1;
    rec.flags = (uint16_t)diff;
    rec.masked_score = s ^ BSNK_MASK;
    rec.checksum = bsnk_checksum(s);
    fwrite(&rec, sizeof(rec), 1, fp);
    fclose(fp);
  }
  return term_pak(CID(Unit), 0);
}

Term load_high_score_run(Env e, Term* f, IoWork* w) {
  uint32_t diff = (uint32_t)f[0];
  char path[600];
  get_data_file(high_score_filename(diff), path, sizeof(path));
  FILE* fp = fopen(path, "rb");
  if (!fp) {
    if (diff == 1) {
      // Migrate legacy Normal highscore.bin or highscore.txt from current working directory
      FILE* cwd_fp = fopen("highscore.bin", "rb");
      if (cwd_fp) {
        struct HighScoreRecord old_rec;
        if (fread(&old_rec, sizeof(old_rec), 1, cwd_fp) == 1 &&
            old_rec.magic == BSNK_MAGIC && old_rec.version == 1) {
          uint32_t old_s = old_rec.masked_score ^ BSNK_MASK;
          if (old_rec.checksum == bsnk_checksum(old_s)) {
            fclose(cwd_fp);
            Term args[2] = { (Term)old_s, (Term)diff };
            save_high_score_run(e, args, w);
            return (Term)old_s;
          }
        }
        fclose(cwd_fp);
      }
      FILE* old_fp = fopen("highscore.txt", "r");
      if (old_fp) {
        uint32_t old_s = 0;
        if (fscanf(old_fp, "%u", &old_s) == 1) {
          fclose(old_fp);
          unlink("highscore.txt");
          Term args[2] = { (Term)old_s, (Term)diff };
          save_high_score_run(e, args, w);
          return (Term)old_s;
        }
        fclose(old_fp);
      }
    }
    return (Term)0;
  }
  struct HighScoreRecord rec;
  if (fread(&rec, sizeof(rec), 1, fp) != 1) {
    fclose(fp);
    return (Term)0;
  }
  fclose(fp);

  if (rec.magic != BSNK_MAGIC || rec.version != 1) {
    return (Term)0;
  }
  uint32_t score = rec.masked_score ^ BSNK_MASK;
  if (rec.checksum != bsnk_checksum(score)) {
    return (Term)0;
  }
  return (Term)score;
}

static int server_sock = -1;
static int client_sock = -1;
static int beacon_sock = -1;
static uint32_t active_lan_seed = 424242;
static uint32_t active_lan_diff = 1;

static void get_network_ips(char* lan_ip, size_t lan_len, char* mesh_ip, size_t mesh_len) {
  strncpy(lan_ip, "127.0.0.1", lan_len);
  mesh_ip[0] = '\0';

  struct ifaddrs* ifaddr = NULL;
  if (getifaddrs(&ifaddr) == 0) {
    for (struct ifaddrs* ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
      if (!ifa->ifa_addr || ifa->ifa_addr->sa_family != AF_INET) continue;
      if (ifa->ifa_flags & IFF_LOOPBACK) continue;

      char ip_str[64];
      struct sockaddr_in* sin = (struct sockaddr_in*)ifa->ifa_addr;
      inet_ntop(AF_INET, &sin->sin_addr, ip_str, sizeof(ip_str));

      // Check for Tailscale / ZeroTier mesh interfaces
      if (strncmp(ifa->ifa_name, "tailscale", 9) == 0 ||
          strncmp(ifa->ifa_name, "ts", 2) == 0 ||
          strncmp(ifa->ifa_name, "zt", 2) == 0) {
        strncpy(mesh_ip, ip_str, mesh_len - 1);
      } else if ((ifa->ifa_flags & IFF_BROADCAST) && (strcmp(lan_ip, "127.0.0.1") == 0)) {
        // Prefer physical ethernet / wifi over virtual bridges/containers
        if (strncmp(ifa->ifa_name, "docker", 6) != 0 &&
            strncmp(ifa->ifa_name, "br-", 3) != 0 &&
            strncmp(ifa->ifa_name, "veth", 4) != 0) {
          strncpy(lan_ip, ip_str, lan_len - 1);
        }
      }
    }
    freeifaddrs(ifaddr);
  }
}

static void set_tcp_nodelay(int s) {
  int opt = 1;
  setsockopt(s, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));
}

static int recv_exact(int s, void* buf, size_t len, int timeout_ms) {
  uint8_t* p = (uint8_t*)buf;
  size_t got = 0;
  while (got < len) {
    struct pollfd pfd = { .fd = s, .events = POLLIN, .revents = 0 };
    int ret = poll(&pfd, 1, timeout_ms);
    if (ret <= 0) return -1;
    ssize_t n = recv(s, p + got, len - got, 0);
    if (n == 0) return 0;
    if (n < 0) {
      if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) continue;
      return -1;
    }
    got += (size_t)n;
  }
  return 1;
}

static void recv_lan_handshake(int s) {
  uint32_t hs[2] = { 0, 1 };
  if (recv_exact(s, hs, sizeof(hs), 1500) == 1) {
    if (hs[0] != 0) active_lan_seed = hs[0];
    active_lan_diff = hs[1];
  }
}

Term net_set_lan_diff_run(Env e, Term* f, IoWork* w) {
  active_lan_diff = (uint32_t)f[0];
  return term_pak(CID(Unit), 0);
}

Term net_get_lan_diff_run(Env e, Term* f, IoWork* w) {
  return (Term)active_lan_diff;
}

Term net_beacon_tick_run(Env e, Term* f, IoWork* w) {
  uint32_t mode = (uint32_t)f[0];
  if (beacon_sock >= 0) {
    char msg[64];
    snprintf(msg, sizeof(msg), "BSNK_ROOM:%u:%u:%u", mode, active_lan_seed, active_lan_diff);

    struct sockaddr_in baddr;
    memset(&baddr, 0, sizeof(baddr));
    baddr.sin_family = AF_INET;
    baddr.sin_port = htons(4243);

    // 1. Universal broadcast
    baddr.sin_addr.s_addr = inet_addr("255.255.255.255");
    sendto(beacon_sock, msg, strlen(msg), 0, (struct sockaddr*)&baddr, sizeof(baddr));

    // 2. Localhost for loopback tests
    baddr.sin_addr.s_addr = inet_addr("127.0.0.1");
    sendto(beacon_sock, msg, strlen(msg), 0, (struct sockaddr*)&baddr, sizeof(baddr));

    // 3. Every active subnet broadcast interface
    struct ifaddrs* ifaddr = NULL;
    if (getifaddrs(&ifaddr) == 0) {
      for (struct ifaddrs* ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
        if (!ifa->ifa_addr || ifa->ifa_addr->sa_family != AF_INET) continue;
        if (!(ifa->ifa_flags & IFF_BROADCAST) || !ifa->ifa_broadaddr) continue;
        struct sockaddr_in* broad = (struct sockaddr_in*)ifa->ifa_broadaddr;
        baddr.sin_addr = broad->sin_addr;
        sendto(beacon_sock, msg, strlen(msg), 0, (struct sockaddr*)&baddr, sizeof(baddr));
      }
      freeifaddrs(ifaddr);
    }
  }
  return term_pak(CID(Unit), 0);
}

Term net_auto_join_run(Env e, Term* f, IoWork* w) {
  uint32_t target_mode = (uint32_t)f[0];
  uint32_t port = 4242;

  int lsock = socket(AF_INET, SOCK_DGRAM, 0);
  if (lsock < 0) return (Term)0;

  int opt = 1;
  setsockopt(lsock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
#ifdef SO_REUSEPORT
  setsockopt(lsock, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));
#endif
  setsockopt(lsock, SOL_SOCKET, SO_BROADCAST, &opt, sizeof(opt));

  struct sockaddr_in laddr;
  memset(&laddr, 0, sizeof(laddr));
  laddr.sin_family = AF_INET;
  laddr.sin_port = htons(4243);
  laddr.sin_addr.s_addr = INADDR_ANY;

  if (bind(lsock, (struct sockaddr*)&laddr, sizeof(laddr)) < 0) {
    close(lsock);
    return (Term)0;
  }

  write(STDOUT_FILENO, "\x1b[2J\x1b[H\x1b[1;36m🔍 SCANNING FOR LAN ROOMS...\x1b[0m\n\n\x1b[1;37mListening for active game rooms on local network...\x1b[0m\n\x1b[90m(Make sure the host selected 'Host' on their PC)\x1b[0m\n\n", 175);

  struct sockaddr_in sender_addr;
  char host_ip[64] = {0};
  int found = 0;

  for (int iter = 0; iter < 14; iter++) {
    struct pollfd pfd = { .fd = lsock, .events = POLLIN, .revents = 0 };
    int ret = poll(&pfd, 1, 250);
    if (ret > 0 && (pfd.revents & POLLIN)) {
      char buf[128] = {0};
      socklen_t slen = sizeof(sender_addr);
      ssize_t n = recvfrom(lsock, buf, sizeof(buf) - 1, 0, (struct sockaddr*)&sender_addr, &slen);
      if (n > 0) {
        buf[n] = 0;
        if (strncmp(buf, "BSNK_ROOM:", 10) == 0) {
          uint32_t r_mode = (uint32_t)atoi(buf + 10);
          if (r_mode == target_mode || target_mode == 0) {
            active_lan_diff = 1;
            char* s_seed = strchr(buf + 10, ':');
            if (s_seed) {
              active_lan_seed = (uint32_t)strtoul(s_seed + 1, NULL, 10);
              char* s_diff = strchr(s_seed + 1, ':');
              if (s_diff) {
                active_lan_diff = (uint32_t)strtoul(s_diff + 1, NULL, 10);
              }
            }
            inet_ntop(AF_INET, &sender_addr.sin_addr, host_ip, sizeof(host_ip));
            found = 1;
            break;
          }
        }
      }
    }
  }

  close(lsock);

  if (!found) {
    write(STDOUT_FILENO, "\x1b[33m⚡ No automatic broadcast room detected yet.\x1b[0m\n\x1b[90mSwitching to direct IP join...\x1b[0m\n\n", 95);
    usleep(500000);
    return (Term)0;
  }

  char found_msg[128];
  snprintf(found_msg, sizeof(found_msg), "\x1b[1;32m🎯 FOUND ROOM on %s!\x1b[0m Connecting...\n", host_ip);
  write(STDOUT_FILENO, found_msg, strlen(found_msg));

  if (client_sock >= 0) { close(client_sock); client_sock = -1; }
  int s = socket(AF_INET, SOCK_STREAM, 0);
  if (s < 0) return (Term)0;

  struct sockaddr_in tcp_addr;
  memset(&tcp_addr, 0, sizeof(tcp_addr));
  tcp_addr.sin_family = AF_INET;
  tcp_addr.sin_port = htons((uint16_t)port);
  tcp_addr.sin_addr = sender_addr.sin_addr;

  if (connect(s, (struct sockaddr*)&tcp_addr, sizeof(tcp_addr)) < 0) {
    char err_msg[128];
    snprintf(err_msg, sizeof(err_msg), "\x1b[1;31mCould not connect to room at %s:%u (%s)\x1b[0m\n", host_ip, port, strerror(errno));
    write(STDOUT_FILENO, err_msg, strlen(err_msg));
    close(s);
    usleep(1200000);
    return (Term)0;
  }

  set_tcp_nodelay(s);
  recv_lan_handshake(s);

  int flags = fcntl(s, F_GETFL, 0);
  fcntl(s, F_SETFL, flags | O_NONBLOCK);
  client_sock = s;
  return (Term)1;
}

Term net_listen_run(Env e, Term* f, IoWork* w) {
  uint32_t port = (uint32_t)f[0];
  if (server_sock >= 0) { close(server_sock); server_sock = -1; }
  if (client_sock >= 0) { close(client_sock); client_sock = -1; }
  if (beacon_sock >= 0) { close(beacon_sock); beacon_sock = -1; }

  beacon_sock = socket(AF_INET, SOCK_DGRAM, 0);
  if (beacon_sock >= 0) {
    int opt = 1;
    setsockopt(beacon_sock, SOL_SOCKET, SO_BROADCAST, &opt, sizeof(opt));
    setsockopt(beacon_sock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
#ifdef SO_REUSEPORT
    setsockopt(beacon_sock, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));
#endif
  }

  server_sock = socket(AF_INET, SOCK_STREAM, 0);
  if (server_sock < 0) return (Term)0;

  int opt = 1;
  setsockopt(server_sock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = INADDR_ANY;
  addr.sin_port = htons((uint16_t)port);

  if (bind(server_sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
    close(server_sock);
    server_sock = -1;
    return (Term)0;
  }

  if (listen(server_sock, 1) < 0) {
    close(server_sock);
    server_sock = -1;
    return (Term)0;
  }

  int flags = fcntl(server_sock, F_GETFL, 0);
  fcntl(server_sock, F_SETFL, flags | O_NONBLOCK);

  active_lan_seed = ((uint32_t)time(NULL) ^ ((uint32_t)getpid() << 16) ^ (uint32_t)rand()) & 0x7FFFFFFFu;
  if (active_lan_seed == 0) active_lan_seed = 1337;

  char lan_ip[64] = "127.0.0.1";
  char mesh_ip[64] = "";
  get_network_ips(lan_ip, sizeof(lan_ip), mesh_ip, sizeof(mesh_ip));

  const char* diff_name = "🐍 Normal (120ms)";
  if (active_lan_diff == 0) diff_name = "🐢 Easy (165ms)";
  else if (active_lan_diff == 2) diff_name = "🔥 Hard (85ms)";
  else if (active_lan_diff == 3) diff_name = "⚡ Turbo (60ms)";

  printf("\x1b[2J\x1b[H\x1b[1;36m📡 ROOM OPEN\x1b[0m  \x1b[90m│\x1b[0m  \x1b[1;37m%s\x1b[0m\n\n", diff_name);
  printf("\x1b[1;32mBroadcasting room beacon to local network...\x1b[0m\n\n");
  printf("  • \x1b[1;37mLocal LAN IP:\x1b[0m   \x1b[1;33m%s\x1b[0m (Port: %u)\n", lan_ip, port);
  if (strlen(mesh_ip) > 0) {
    printf("  • \x1b[1;37mTailscale IP:\x1b[0m   \x1b[1;35m%s\x1b[0m (Port: %u) \x1b[90m(Play from anywhere!)\x1b[0m\n", mesh_ip, port);
  }
  printf("\n\x1b[90mOther PCs on same Wi-Fi can join automatically with zero setup!\x1b[0m\n");
  printf("\x1b[90mTip: If using a VPN (Nord/Mullvad/Proton), enable 'Allow LAN Traffic' or use Tailscale.\x1b[0m\n");
  printf("\x1b[90m(Press [Q] to cancel)\x1b[0m\n");
  fflush(stdout);

  return (Term)1;
}

Term net_accept_run(Env e, Term* f, IoWork* w) {
  if (server_sock < 0) return (Term)0;
  if (client_sock >= 0) return (Term)1;

  struct sockaddr_in caddr;
  socklen_t clen = sizeof(caddr);
  int s = accept(server_sock, (struct sockaddr*)&caddr, &clen);
  if (s < 0) return (Term)0;

  set_tcp_nodelay(s);
  int flags = fcntl(s, F_GETFL, 0);
  fcntl(s, F_SETFL, flags | O_NONBLOCK);
  client_sock = s;
  uint32_t hs[2] = { active_lan_seed, active_lan_diff };
  send(client_sock, hs, sizeof(hs), MSG_NOSIGNAL);
  return (Term)1;
}

Term net_prompt_join_run(Env e, Term* f, IoWork* w) {
  uint32_t port = (uint32_t)f[0];
  if (client_sock >= 0) { close(client_sock); client_sock = -1; }

  char ip[128] = "127.0.0.1";
  char last_ip[128] = "127.0.0.1";
  char host_path[600];
  get_data_file("host.txt", host_path, sizeof(host_path));

  // Check if previous valid host was saved
  FILE* hfp = fopen(host_path, "r");
  if (!hfp) hfp = fopen("host.txt", "r");
  if (hfp) {
    if (fscanf(hfp, "%127s", last_ip) == 1) {
      char* colon = strchr(last_ip, ':');
      if (colon) *colon = '\0';
    }
    fclose(hfp);
  }

  const char* env_host = getenv("BEND_SNAKE_HOST");
  if (env_host && strlen(env_host) > 0) {
    strncpy(ip, env_host, sizeof(ip) - 1);
  } else {
    printf("\x1b[2J\x1b[H\x1b[1;36m🔗 JOIN LAN / MESH GAME\x1b[0m\n\n");
    printf("\x1b[1;37mEnter Host IP address \x1b[33m[default: %s]\x1b[1;37m (or press Enter to use default):\x1b[0m\n", last_ip);
    printf("\x1b[90m(Supports LAN IPs like 192.168.x.x, or Tailscale/VPN IPs like 100.x.x.x)\x1b[0m\n");
    printf("\x1b[90m(If using Nord/Mullvad/Proton VPN, enable 'Allow LAN Traffic' in VPN settings)\x1b[0m\n> ");
    fflush(stdout);

    if (raw_mode_set) {
      tcsetattr(STDIN_FILENO, TCSANOW, &orig_termios);
    }

    char input_buf[128] = {0};
    if (fgets(input_buf, sizeof(input_buf), stdin)) {
      char* nl = strchr(input_buf, '\n');
      if (nl) *nl = 0;
      char* cr = strchr(input_buf, '\r');
      if (cr) *cr = 0;

      char* p = input_buf;
      while (*p == ' ' || *p == '\t') p++;

      if (strlen(p) > 0) {
        char* colon = strchr(p, ':');
        if (colon) {
          *colon = '\0';
          uint32_t user_port = (uint32_t)atoi(colon + 1);
          if (user_port > 0) port = user_port;
        }
        strncpy(ip, p, sizeof(ip) - 1);
      } else {
        strncpy(ip, last_ip, sizeof(ip) - 1);
      }
    } else {
      strncpy(ip, last_ip, sizeof(ip) - 1);
    }

    if (raw_mode_set) {
      struct termios raw = orig_termios;
      raw.c_lflag &= ~(ECHO | ICANON | ISIG);
      raw.c_iflag &= ~(IXON | ICRNL);
      raw.c_cc[VMIN] = 0;
      raw.c_cc[VTIME] = 0;
      tcsetattr(STDIN_FILENO, TCSANOW, &raw);
    }
  }

  char* extra_colon = strchr(ip, ':');
  if (extra_colon) {
    *extra_colon = '\0';
    uint32_t user_port = (uint32_t)atoi(extra_colon + 1);
    if (user_port > 0) port = user_port;
  }

  printf("\x1b[KConnecting to %s:%u...\n", ip, port);
  fflush(stdout);

  int s = socket(AF_INET, SOCK_STREAM, 0);
  if (s < 0) return (Term)0;

  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons((uint16_t)port);
  if (inet_pton(AF_INET, ip, &addr.sin_addr) <= 0) {
    printf("\x1b[1;31mInvalid IP address format: '%s'\x1b[0m\n", ip);
    fflush(stdout);
    close(s);
    usleep(1500000);
    return (Term)0;
  }

  if (connect(s, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
    printf("\x1b[1;31mCould not connect to %s:%u (%s)\x1b[0m\n\x1b[90mMake sure the host is currently on the 'Host' screen.\x1b[0m\n", ip, port, strerror(errno));
    fflush(stdout);
    close(s);
    usleep(2000000);
    return (Term)0;
  }

  set_tcp_nodelay(s);
  recv_lan_handshake(s);

  FILE* save_fp = fopen(host_path, "w");
  if (save_fp) {
    fprintf(save_fp, "%s\n", ip);
    fclose(save_fp);
  }

  int flags = fcntl(s, F_GETFL, 0);
  fcntl(s, F_SETFL, flags | O_NONBLOCK);
  client_sock = s;
  return (Term)1;
}

Term net_send_key_run(Env e, Term* f, IoWork* w) {
  uint32_t k = (uint32_t)f[0];
  if (client_sock >= 0) {
    send(client_sock, &k, sizeof(k), MSG_NOSIGNAL);
  }
  return term_pak(CID(Unit), 0);
}

Term net_recv_key_run(Env e, Term* f, IoWork* w) {
  if (client_sock < 0) return (Term)0;
  uint32_t k = 0;
  int rc = recv_exact(client_sock, &k, sizeof(k), 3000);
  if (rc == 1) {
    return (Term)k;
  }
  return (Term)(uint32_t)'q';
}

Term get_random_seed_run(Env e, Term* f, IoWork* w) {
  if (server_sock >= 0 || client_sock >= 0) {
    return (Term)active_lan_seed;
  }
  uint32_t s = ((uint32_t)time(NULL) ^ ((uint32_t)getpid() << 16) ^ (uint32_t)rand()) & 0x7FFFFFFFu;
  if (s == 0) s = 1337;
  return (Term)s;
}

typedef struct {
  uint32_t state[8];
  uint64_t bitlen;
  uint8_t data[64];
  size_t datalen;
} BsnkSha256;

static const uint32_t BSNK_K256[64] = {
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
};

#define BSNK_ROTR(a,b) (((a) >> (b)) | ((a) << (32-(b))))

static void bsnk_sha_transform(BsnkSha256* ctx, const uint8_t data[]) {
  uint32_t a,b,c,d,e,f,g,h,i,j,t1,t2,m[64];
  for (i=0,j=0; i<16; ++i,j+=4)
    m[i] = ((uint32_t)data[j]<<24) | ((uint32_t)data[j+1]<<16) | ((uint32_t)data[j+2]<<8) | ((uint32_t)data[j+3]);
  for (; i<64; ++i)
    m[i] = (BSNK_ROTR(m[i-2],17)^BSNK_ROTR(m[i-2],19)^(m[i-2]>>10)) + m[i-7] + (BSNK_ROTR(m[i-15],7)^BSNK_ROTR(m[i-15],18)^(m[i-15]>>3)) + m[i-16];
  a=ctx->state[0]; b=ctx->state[1]; c=ctx->state[2]; d=ctx->state[3];
  e=ctx->state[4]; f=ctx->state[5]; g=ctx->state[6]; h=ctx->state[7];
  for (i=0; i<64; ++i) {
    t1 = h + (BSNK_ROTR(e,6)^BSNK_ROTR(e,11)^BSNK_ROTR(e,25)) + ((e&f)^((~e)&g)) + BSNK_K256[i] + m[i];
    t2 = (BSNK_ROTR(a,2)^BSNK_ROTR(a,13)^BSNK_ROTR(a,22)) + ((a&b)^(a&c)^(b&c));
    h=g; g=f; f=e; e=d+t1; d=c; c=b; b=a; a=t1+t2;
  }
  ctx->state[0]+=a; ctx->state[1]+=b; ctx->state[2]+=c; ctx->state[3]+=d;
  ctx->state[4]+=e; ctx->state[5]+=f; ctx->state[6]+=g; ctx->state[7]+=h;
}

static int file_sha256_hex(const char* path, char out[65]) {
  FILE* fp = fopen(path, "rb");
  if (!fp) return 0;
  BsnkSha256 ctx;
  ctx.datalen = 0; ctx.bitlen = 0;
  ctx.state[0]=0x6a09e667; ctx.state[1]=0xbb67ae85; ctx.state[2]=0x3c6ef372; ctx.state[3]=0xa54ff53a;
  ctx.state[4]=0x510e527f; ctx.state[5]=0x9b05688c; ctx.state[6]=0x1f83d9ab; ctx.state[7]=0x5be0cd19;
  uint8_t buf[4096];
  size_t n;
  while ((n = fread(buf, 1, sizeof(buf), fp)) > 0) {
    for (size_t i=0; i<n; ++i) {
      ctx.data[ctx.datalen++] = buf[i];
      if (ctx.datalen == 64) { bsnk_sha_transform(&ctx, ctx.data); ctx.bitlen += 512; ctx.datalen = 0; }
    }
  }
  fclose(fp);
  uint32_t i = (uint32_t)ctx.datalen;
  if (ctx.datalen < 56) { ctx.data[i++] = 0x80; while (i < 56) ctx.data[i++] = 0x00; }
  else { ctx.data[i++] = 0x80; while (i < 64) ctx.data[i++] = 0x00; bsnk_sha_transform(&ctx, ctx.data); memset(ctx.data, 0, 56); }
  ctx.bitlen += ctx.datalen * 8;
  for (int j=0; j<8; ++j) ctx.data[63-j] = (uint8_t)((ctx.bitlen >> (j*8)) & 0xff);
  bsnk_sha_transform(&ctx, ctx.data);
  uint8_t hash[32];
  for (i=0; i<8; ++i) {
    hash[i*4+0]=(ctx.state[i]>>24)&0xff; hash[i*4+1]=(ctx.state[i]>>16)&0xff;
    hash[i*4+2]=(ctx.state[i]>>8)&0xff;  hash[i*4+3]=ctx.state[i]&0xff;
  }
  for (int k=0; k<32; ++k) snprintf(out + k*2, 3, "%02x", hash[k]);
  out[64] = 0;
  return 1;
}

static int is_valid_elf(const char* path) {
  FILE* fp = fopen(path, "rb");
  if (!fp) return 0;
  unsigned char hdr[4] = {0};
  size_t n = fread(hdr, 1, 4, fp);
  fclose(fp);
  return n == 4 && hdr[0] == 0x7f && hdr[1] == 'E' && hdr[2] == 'L' && hdr[3] == 'F';
}

static int fetch_release_json(char* out, size_t max_len) {
  int pfd[2];
  if (pipe(pfd) < 0) return 0;
  pid_t pid = fork();
  if (pid == 0) {
    close(pfd[0]);
    dup2(pfd[1], STDOUT_FILENO);
    close(pfd[1]);
    int devnull = open("/dev/null", O_WRONLY);
    if (devnull >= 0) { dup2(devnull, STDERR_FILENO); close(devnull); }
    execlp("curl", "curl", "-fsSL", "--connect-timeout", "2", "--max-time", "3",
           "-H", "Accept: application/vnd.github+json",
           "https://api.github.com/repos/kidusm001/snake-tui/releases/latest", (char*)NULL);
    _exit(127);
  }
  close(pfd[1]);
  if (pid < 0) { close(pfd[0]); return 0; }
  size_t total = 0;
  ssize_t n;
  while (total + 1 < max_len && (n = read(pfd[0], out + total, max_len - 1 - total)) > 0) {
    total += (size_t)n;
  }
  close(pfd[0]);
  int status = 0;
  waitpid(pid, &status, 0);
  out[total] = '\0';
  return WIFEXITED(status) && WEXITSTATUS(status) == 0 && total > 0;
}

static int download_file_curl(const char* url, const char* dst) {
  pid_t pid = fork();
  if (pid == 0) {
    int devnull = open("/dev/null", O_WRONLY);
    if (devnull >= 0) { dup2(devnull, STDOUT_FILENO); dup2(devnull, STDERR_FILENO); close(devnull); }
    execlp("curl", "curl", "-fSL", "--connect-timeout", "5", "--max-time", "30",
           "-o", dst, url, (char*)NULL);
    _exit(127);
  }
  if (pid < 0) return 0;
  int status = 0;
  waitpid(pid, &status, 0);
  return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

Term check_update_run(Env e, Term* f, IoWork* w) {
  if (!isatty(STDIN_FILENO) || getenv("SNAKE_NO_UPDATE")) {
    return term_pak(CID(Unit), 0);
  }

  char exe_path[512] = {0};
  ssize_t exe_len = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
  if (exe_len <= 0) return term_pak(CID(Unit), 0);
  exe_path[exe_len] = '\0';

  char local_sha[65] = {0};
  if (!file_sha256_hex(exe_path, local_sha)) return term_pak(CID(Unit), 0);

  const char chk_msg[] = "\x1b[90mChecking for updates...\x1b[0m";
  write(STDOUT_FILENO, chk_msg, sizeof(chk_msg) - 1);

  char* json = (char*)malloc(65536);
  if (!json) {
    write(STDOUT_FILENO, "\r\x1b[K", 4);
    return term_pak(CID(Unit), 0);
  }

  if (!fetch_release_json(json, 65536)) {
    free(json);
    write(STDOUT_FILENO, "\r\x1b[K", 4);
    return term_pak(CID(Unit), 0);
  }

  const char* scope = strstr(json, "\"snake-tui\"");
  if (!scope) scope = json;
  const char* dig = strstr(scope, "\"sha256:");
  if (!dig) dig = strstr(json, "\"sha256:");

  char remote_sha[65] = {0};
  if (dig) {
    dig += 8; // skip "sha256:
    int valid = 1;
    for (int i = 0; i < 64; i++) {
      if (!isxdigit((unsigned char)dig[i])) { valid = 0; break; }
      remote_sha[i] = (char)tolower((unsigned char)dig[i]);
    }
    remote_sha[64] = '\0';
    if (!valid) remote_sha[0] = '\0';
  }

  char dl_url[512] = "https://github.com/kidusm001/snake-tui/releases/latest/download/snake-tui";
  const char* uptr = strstr(scope, "\"browser_download_url\"");
  if (uptr) {
    const char* q1 = strchr(uptr + 22, '"');
    if (q1) {
      q1++;
      const char* q2 = strchr(q1, '"');
      if (q2 && (size_t)(q2 - q1) < sizeof(dl_url)) {
        memcpy(dl_url, q1, (size_t)(q2 - q1));
        dl_url[q2 - q1] = '\0';
      }
    }
  }
  free(json);

  write(STDOUT_FILENO, "\r\x1b[K", 4);

  if (remote_sha[0] == '\0' || strcmp(local_sha, remote_sha) == 0) {
    return term_pak(CID(Unit), 0);
  }

  // Update available!
  char dir_path[512];
  strncpy(dir_path, exe_path, sizeof(dir_path) - 1);
  dir_path[sizeof(dir_path) - 1] = '\0';
  char* slash = strrchr(dir_path, '/');
  if (slash) *slash = '\0';
  int can_write = (access(dir_path, W_OK) == 0);

  printf("\x1b[2J\x1b[H\x1b[1;36m🚀 UPDATE AVAILABLE FOR SNAKE-TUI!\x1b[0m\n\n");
  printf("  \x1b[90mInstalled:\x1b[0m %.12s\n", local_sha);
  printf("  \x1b[1;32mLatest:\x1b[0m    %.12s\n\n", remote_sha);
  if (can_write) {
    printf("  \x1b[1;33m[U]\x1b[0m Update & Restart now\n");
  } else {
    printf("  \x1b[33mInstall path %s requires sudo. Run install.sh to update.\x1b[0m\n", exe_path);
  }
  printf("  \x1b[1;37m[Enter / S]\x1b[0m Skip & Play\n");
  fflush(stdout);

  struct pollfd pfd = { .fd = STDIN_FILENO, .events = POLLIN, .revents = 0 };
  unsigned char ch = 0;
  if (poll(&pfd, 1, -1) > 0) {
    read(STDIN_FILENO, &ch, 1);
  }

  if (can_write && (ch == 'u' || ch == 'U' || ch == 'y' || ch == 'Y')) {
    printf("\n\x1b[1;36mDownloading latest snake-tui...\x1b[0m\n");
    fflush(stdout);

    char tmp_path[528];
    snprintf(tmp_path, sizeof(tmp_path), "%s.tmp", exe_path);

    char new_sha[65] = {0};
    if (download_file_curl(dl_url, tmp_path) &&
        is_valid_elf(tmp_path) &&
        file_sha256_hex(tmp_path, new_sha) &&
        strcmp(new_sha, remote_sha) == 0 &&
        chmod(tmp_path, 0755) == 0 &&
        rename(tmp_path, exe_path) == 0) {
      printf("\x1b[1;32m✅ Updated successfully! Relaunching...\x1b[0m\n");
      fflush(stdout);
      term_restore_run(e, f, w);
      usleep(400000);
      execl(exe_path, exe_path, (char*)NULL);
    } else {
      unlink(tmp_path);
      printf("\x1b[1;31m⚠️  Update download or verification failed. Playing current version...\x1b[0m\n");
      fflush(stdout);
      usleep(1200000);
    }
  }

  write(STDOUT_FILENO, "\x1b[2J\x1b[H", 7);
  return term_pak(CID(Unit), 0);
}

Term net_close_run(Env e, Term* f, IoWork* w) {
  if (client_sock >= 0) { close(client_sock); client_sock = -1; }
  if (server_sock >= 0) { close(server_sock); server_sock = -1; }
  if (beacon_sock >= 0) { close(beacon_sock); beacon_sock = -1; }
  return term_pak(CID(Unit), 0);
}

static void __attribute__((constructor)) term_eff_register(void) {
  io_eff(CID(init), term_init_run);
  io_eff(CID(restore), term_restore_run);
  io_eff(CID(poll_key), term_poll_key_run);
  io_eff(CID(load_high_score), load_high_score_run);
  io_eff(CID(save_high_score), save_high_score_run);
  io_eff(CID(net_listen), net_listen_run);
  io_eff(CID(net_accept), net_accept_run);
  io_eff(CID(net_prompt_join), net_prompt_join_run);
  io_eff(CID(net_auto_join), net_auto_join_run);
  io_eff(CID(net_beacon_tick), net_beacon_tick_run);
  io_eff(CID(net_send_key), net_send_key_run);
  io_eff(CID(net_recv_key), net_recv_key_run);
  io_eff(CID(net_close), net_close_run);
  io_eff(CID(get_random_seed), get_random_seed_run);
  io_eff(CID(check_update), check_update_run);
  io_eff(CID(net_set_lan_diff), net_set_lan_diff_run);
  io_eff(CID(net_get_lan_diff), net_get_lan_diff_run);
}
