#!/bin/sh

set -e

URL="https://raw.githubusercontent.com/TTG-Phyros/Zsh-functions-for-THM/refs/heads/main/custom_functions.zsh"
DIR="$HOME/.bash_related"
DEST="$DIR/custom_functions.zsh"
TMP="$DEST.tmp"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
SOURCE_LINE='[ -f "$HOME/.bash_related/custom_functions.zsh" ] && source "$HOME/.bash_related/custom_functions.zsh"'

# 1. Dossier
mkdir -p "$DIR"
echo "[+] Dossier : $DIR"

if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$URL" -o "$TMP" || { rm -f "$TMP"; echo "[!] Échec du téléchargement." >&2; exit 1; }
elif command -v wget >/dev/null 2>&1; then
    wget -qO "$TMP" "$URL" || { rm -f "$TMP"; echo "[!] Échec du téléchargement." >&2; exit 1; }
else
    echo "[!] Ni curl ni wget n'est installé." >&2
    exit 1
fi

if [ ! -s "$TMP" ]; then
    rm -f "$TMP"
    echo "[!] Fichier téléchargé vide." >&2
    exit 1
fi

mv "$TMP" "$DEST"
echo "[+] Téléchargé : $DEST"

# 3. Source dans .zshrc (une seule fois)
touch "$ZSHRC"
if grep -qF ".bash_related/custom_functions.zsh" "$ZSHRC"; then
    echo "[=] Déjà sourcé dans $ZSHRC"
else
    printf '\n# Custom functions\n%s\n' "$SOURCE_LINE" >> "$ZSHRC"
    echo "[+] Ligne ajoutée dans $ZSHRC"
fi

echo "[✓] Terminé. Lance 'source $ZSHRC' ou ouvre un nouveau terminal."