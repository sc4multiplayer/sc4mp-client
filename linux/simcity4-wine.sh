#!/usr/bin/env bash
#
# SimCity 4 Wine wrapper for the SC4MP Launcher on Linux.
#
# The launcher runs natively (`python sc4mpclient.py`) and starts the game by
# executing this script with SC4's command-line arguments. This script turns
# the Linux `-UserDir:` path into a Windows path and runs SC4 through Wine.
#
# Setup: in the launcher, open Launcher > Settings > SC4... and set
# "Custom installation path" to the full path of this script.
#
# Configure it with environment variables, or put the same `KEY=value` lines in
# ~/.config/sc4mp/simcity4-wine.conf or a simcity4-wine.conf next to this script
# (both are sourced if they exist; the one next to the script wins):
#
#   LAUNCH_MODE     "wine" (default) runs SC4_EXE with plain Wine. Use this for
#                   DRM-free copies (GOG, disc).
#                   "steam" launches through Steam (`steam -applaunch 24780`), so
#                   the Steam copy runs under Proton. Use this if you get
#                   "Application load error 5:0000065434". Steam must be running.
#                   Set gamescope etc. in the game's Steam launch options instead.
#   SC4_EXE         Windows path to "SimCity 4.exe" inside the prefix (wine mode),
#                   e.g. "C:/GOG Games/SimCity 4 Deluxe Edition/Apps/SimCity 4.exe"
#                   or   "Z:/mnt/games/steamapps/common/SimCity 4 Deluxe/Apps/SimCity 4.exe"
#   WINEPREFIX      Wine prefix to use (default: ~/.wine)
#   WINE            Wine binary (default: wine)
#   USE_GAMESCOPE   1 to run inside gamescope (default: 0)
#   GAMESCOPE_W/H   Game (inner) resolution. Default: taken from the launcher's
#                   -r<width>x<height>x32 argument (SC4 settings > Resolution)
#   GAMESCOPE_OUT_W/H  Output resolution, e.g. your monitor's (optional)
#   GAMESCOPE_ARGS  Extra gamescope arguments (default: -f)
#   SC4_PLUGINS_DIR Linux path to the game installation's Plugins folder. Only
#                   needed if it can't be worked out from SC4_EXE (e.g. steam
#                   mode without SC4_EXE set).
#
# `simcity4-wine.sh --plugins-dir` prints the installation's Plugins folder.
# The launcher uses it to skip loading DLLs that are already installed there
# (e.g. SC4Fix), since loading the same DLL twice can crash the game.

set -euo pipefail

# Settings come from ~/.config/sc4mp/simcity4-wine.conf, then from a
# simcity4-wine.conf next to this script (which wins if both set something)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sc4mp/simcity4-wine.conf"
for conf in "$CONFIG_FILE" "$SCRIPT_DIR/simcity4-wine.conf"; do
	if [[ -f "$conf" ]]; then
		echo "simcity4-wine: using $conf" >&2
		# shellcheck disable=SC1090
		source "$conf"
	fi
done

export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
WINE="${WINE:-wine}"
LAUNCH_MODE="${LAUNCH_MODE:-wine}"
USE_GAMESCOPE="${USE_GAMESCOPE:-0}"
GAMESCOPE_ARGS="${GAMESCOPE_ARGS:--f}"

if [[ "${1:-}" == "--plugins-dir" ]]; then
	dir="${SC4_PLUGINS_DIR:-}"
	if [[ -z "$dir" && -n "${SC4_EXE:-}" ]]; then
		exe="${SC4_EXE//\\//}"
		if [[ "$exe" =~ ^[Zz]:(/.*)$ ]]; then
			linux_exe="${BASH_REMATCH[1]}"		# Z: is the Linux root in Wine and Proton
		else
			linux_exe="$(winepath -u "$SC4_EXE" 2>/dev/null || true)"
		fi
		# "<install>/Apps/SimCity 4.exe" -> "<install>/Plugins"
		[[ -n "$linux_exe" ]] && dir="$(dirname "$(dirname "$linux_exe")")/Plugins"
	fi
	[[ -n "$dir" ]] && echo "$dir"
	exit 0
fi

if [[ "$LAUNCH_MODE" == "wine" && -z "${SC4_EXE:-}" ]]; then
	echo "simcity4-wine: SC4_EXE is not set. Set it in the environment or in $CONFIG_FILE." >&2
	exit 1
fi

args=()
res_w=""
res_h=""

for arg in "$@"; do
	if [[ "$arg" == -UserDir:* ]]; then
		# The launcher passes -UserDir:"/linux/path/" (with literal quotes)
		linux_path="${arg#-UserDir:}"
		linux_path="${linux_path//\"/}"
		if [[ "$LAUNCH_MODE" == "steam" ]]; then
			# Don't run winepath against the Proton prefix; Z: maps to / there too
			windows_path="Z:${linux_path//\//\\}"
		else
			windows_path="$(winepath -w "$linux_path")"
		fi
		# SC4 expects a trailing backslash on the user directory
		[[ "$windows_path" == *\\ ]] || windows_path="$windows_path\\"
		args+=("-UserDir:$windows_path")
	else
		if [[ "$arg" =~ ^-r([0-9]+)x([0-9]+) ]]; then
			res_w="${BASH_REMATCH[1]}"
			res_h="${BASH_REMATCH[2]}"
		fi
		args+=("$arg")
	fi
done

if [[ "$LAUNCH_MODE" == "steam" ]]; then
	echo "simcity4-wine: steam -applaunch 24780 ${args[*]}"
	steam -applaunch 24780 "${args[@]}" >/dev/null 2>&1 &
	# Steam hands the launch to its running instance and returns, so wait for
	# the game ourselves; the launcher treats this script exiting as the game closing
	for _ in $(seq 120); do
		pgrep -f "SimCity 4.exe" >/dev/null && break
		sleep 1
	done
	if ! pgrep -f "SimCity 4.exe" >/dev/null; then
		echo "simcity4-wine: SimCity 4 did not start within 2 minutes." >&2
		exit 1
	fi
	while pgrep -f "SimCity 4.exe" >/dev/null; do
		sleep 2
	done
	exit 0
fi

echo "simcity4-wine: WINEPREFIX=$WINEPREFIX"
echo "simcity4-wine: $SC4_EXE ${args[*]}"

if [[ "$USE_GAMESCOPE" == "1" ]]; then
	gs=(gamescope)
	inner_w="${GAMESCOPE_W:-$res_w}"
	inner_h="${GAMESCOPE_H:-$res_h}"
	[[ -n "$inner_w" ]] && gs+=(-w "$inner_w")
	[[ -n "$inner_h" ]] && gs+=(-h "$inner_h")
	[[ -n "${GAMESCOPE_OUT_W:-}" ]] && gs+=(-W "$GAMESCOPE_OUT_W")
	[[ -n "${GAMESCOPE_OUT_H:-}" ]] && gs+=(-H "$GAMESCOPE_OUT_H")
	# shellcheck disable=SC2206
	gs+=($GAMESCOPE_ARGS)
	exec "${gs[@]}" -- "$WINE" "$SC4_EXE" "${args[@]}"
else
	exec "$WINE" "$SC4_EXE" "${args[@]}"
fi
