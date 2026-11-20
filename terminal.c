#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <poll.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>
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

Term save_high_score_run(Env e, Term* f, IoWork* w) {
  uint32_t s = (uint32_t)f[0];
  FILE* fp = fopen("highscore.bin", "wb");
  if (fp) {
    struct HighScoreRecord rec;
    rec.magic = BSNK_MAGIC;
    rec.version = 1;
    rec.flags = 0;
    rec.masked_score = s ^ BSNK_MASK;
    rec.checksum = bsnk_checksum(s);
    fwrite(&rec, sizeof(rec), 1, fp);
    fclose(fp);
  }
  return term_pak(CID(Unit), 0);
}

Term load_high_score_run(Env e, Term* f, IoWork* w) {
  FILE* fp = fopen("highscore.bin", "rb");
  if (!fp) {
    FILE* old_fp = fopen("highscore.txt", "r");
    if (old_fp) {
      uint32_t old_s = 0;
      if (fscanf(old_fp, "%u", &old_s) == 1) {
        fclose(old_fp);
        unlink("highscore.txt");
        Term args[1] = { (Term)old_s };
        save_high_score_run(e, args, w);
        return (Term)old_s;
      }
      fclose(old_fp);
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

Term net_beacon_tick_run(Env e, Term* f, IoWork* w) {
  uint32_t mode = (uint32_t)f[0];
  if (beacon_sock >= 0) {
    char msg[64];
    snprintf(msg, sizeof(msg), "BSNK_ROOM:%u", mode);

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

  char lan_ip[64] = "127.0.0.1";
  char mesh_ip[64] = "";
  get_network_ips(lan_ip, sizeof(lan_ip), mesh_ip, sizeof(mesh_ip));

  printf("\x1b[2J\x1b[H\x1b[1;36m📡 ROOM OPEN\x1b[0m\n\n");
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

  int flags = fcntl(s, F_GETFL, 0);
  fcntl(s, F_SETFL, flags | O_NONBLOCK);
  client_sock = s;
  return (Term)1;
}

Term net_prompt_join_run(Env e, Term* f, IoWork* w) {
  uint32_t port = (uint32_t)f[0];
  if (client_sock >= 0) { close(client_sock); client_sock = -1; }

  char ip[128] = "127.0.0.1";
  char last_ip[128] = "127.0.0.1";

  // Check if previous valid host was saved
  FILE* hfp = fopen("host.txt", "r");
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

  FILE* save_fp = fopen("host.txt", "w");
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
  ssize_t n = recv(client_sock, &k, sizeof(k), 0);
  if (n == sizeof(k)) {
    return (Term)k;
  } else if (n == 0) {
    return (Term)(uint32_t)'q';
  }
  return (Term)0;
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
}
