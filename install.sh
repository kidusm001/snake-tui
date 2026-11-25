#!/bin/sh
set -eu

REPO="kidusm001/snake-tui"
BIN_NAME="snake-tui"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
DEST="$INSTALL_DIR/$BIN_NAME"
RELEASE_URL="https://github.com/$REPO/releases/latest/download/$BIN_NAME"

printf "🐍 Installing %s to %s...\n" "$BIN_NAME" "$DEST"
mkdir -p "$INSTALL_DIR"

TMP_FILE="$(mktemp "$INSTALL_DIR/.${BIN_NAME}.XXXXXX")"
cleanup() {
  rm -f "$TMP_FILE"
}
trap cleanup EXIT INT TERM

if [ "${1:-}" = "--local" ] && [ -f "./$BIN_NAME" ]; then
  cp "./$BIN_NAME" "$TMP_FILE"
else
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$RELEASE_URL" -o "$TMP_FILE"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$TMP_FILE" "$RELEASE_URL"
  else
    printf "Error: neither curl nor wget is installed.\n" >&2
    exit 1
  fi
fi

chmod +x "$TMP_FILE"
mv -f "$TMP_FILE" "$DEST"

PATH_LINE="export PATH=\"$INSTALL_DIR:\$PATH\""
UPDATED_RC=""

add_to_rc() {
  rc_file="$1"
  if [ -f "$rc_file" ]; then
    if ! grep -F "$INSTALL_DIR" "$rc_file" >/dev/null 2>&1 && ! grep -F "snake-tui installer" "$rc_file" >/dev/null 2>&1; then
      printf "\n# Added by snake-tui installer\n%s\n" "$PATH_LINE" >> "$rc_file"
      UPDATED_RC="$UPDATED_RC $rc_file"
    fi
  fi
}

case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    add_to_rc "$HOME/.zshrc"
    add_to_rc "$HOME/.bashrc"
    add_to_rc "$HOME/.profile"
    if [ -z "$UPDATED_RC" ]; then
      printf "\n# Added by snake-tui installer\n%s\n" "$PATH_LINE" >> "$HOME/.profile"
      UPDATED_RC=" $HOME/.profile"
    fi
    ;;
esac

printf "✅ Installed %s to %s\n" "$BIN_NAME" "$DEST"

if [ -n "$UPDATED_RC" ]; then
  printf "🔧 Added %s to PATH in:%s\n" "$INSTALL_DIR" "$UPDATED_RC"
  printf "   Run 'export PATH=\"%s:\$PATH\"' or open a new terminal, then run: %s\n" "$INSTALL_DIR" "$BIN_NAME"
else
  printf "🎮 Run '%s' anywhere to play!\n" "$BIN_NAME"
fi
