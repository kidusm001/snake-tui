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

static void __attribute__((constructor)) term_eff_register(void) {
  io_eff(CID(init), term_init_run);
  io_eff(CID(restore), term_restore_run);
  io_eff(CID(poll_key), term_poll_key_run);
}
