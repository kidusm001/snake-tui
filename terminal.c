#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>

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
        if (seq[1] == 'A') return (Term)(uint32_t)'w';
        if (seq[1] == 'B') return (Term)(uint32_t)'s';
        if (seq[1] == 'C') return (Term)(uint32_t)'d';
        if (seq[1] == 'D') return (Term)(uint32_t)'a';
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

static void __attribute__((constructor)) term_eff_register(void) {
  io_eff(CID(init), term_init_run);
  io_eff(CID(restore), term_restore_run);
  io_eff(CID(poll_key), term_poll_key_run);
  io_eff(CID(load_high_score), load_high_score_run);
  io_eff(CID(save_high_score), save_high_score_run);
}
