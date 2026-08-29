#!/usr/bin/env bash
# ============================================================================
#  Svan M2 Simulation Launcher
#  One-command launcher for the full M2 Metal robot simulation.
# ============================================================================

set -euo pipefail

# ── Resolve paths ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR/custom/install"
LAIR_DIR="$SCRIPT_DIR"
LIB_PATH_1="$INSTALL_DIR/lib"
LIB_PATH_2="$SCRIPT_DIR/custom/lib"
SESSION="m2_sim"

# ── Colors / helpers ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Pre-flight checks ─────────────────────────────────────────────────────
preflight() {
    local fail=0

    # Check tmux
    if ! command -v tmux &>/dev/null; then
        err "tmux is not installed."
        echo ""
        echo -e "  Install it with:  ${CYAN}sudo apt install tmux${NC}"
        echo ""
        fail=1
    fi

    # Check install directory and binaries
    if [[ ! -d "$INSTALL_DIR" ]]; then
        err "Install directory not found: $INSTALL_DIR"
        fail=1
    else
        for bin in simulate_pv joystick_mux keyboard_interface_dds motion_controller; do
            if [[ ! -x "$INSTALL_DIR/$bin" ]]; then
                err "Missing or not executable: $INSTALL_DIR/$bin"
                fail=1
            fi
        done
    fi

    if [[ $fail -ne 0 ]]; then
        echo ""
        err "Pre-flight checks failed. Fix the issues above and try again."
        exit 1
    fi
}

# ── Setup: add library paths to bashrc ─────────────────────────────────────
setup_env() {
    local marker="# >>> m2_sim LD_LIBRARY_PATH <<<"
    local bashrc="$HOME/.bashrc"

    if grep -qF "$marker" "$bashrc" 2>/dev/null; then
        warn "Library paths already in $bashrc (skipping)."
    else
        {
            echo ""
            echo "$marker"
            echo "export LD_LIBRARY_PATH=\"$LIB_PATH_1:$LIB_PATH_2\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}\""
            echo "# <<< m2_sim LD_LIBRARY_PATH <<<"
        } >> "$bashrc"
        info "Added LD_LIBRARY_PATH to $bashrc"
    fi

    # Also export for the current script so tmux inherits it
    export LD_LIBRARY_PATH="$LIB_PATH_1:$LIB_PATH_2${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
}

# ── Kill existing session ──────────────────────────────────────────────────
kill_session() {
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        tmux kill-session -t "$SESSION"
        info "Killed existing '$SESSION' session."
    fi
}

# ── Build the tmux session ─────────────────────────────────────────────────
launch() {
    local delay=3  # seconds between process launches

    echo ""
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}   Svan M2 Simulation Launcher${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo ""

    # ── Step 1: Physics Simulator ──────────────────────────────────────
    info "Starting Physics Simulator (simulate_pv) ..."
    tmux new-session -d -s "$SESSION" -n "sim" -c "$INSTALL_DIR"
    tmux send-keys -t "$SESSION:sim" "./simulate_pv m2_metal" Enter
    sleep "$delay"

    # ── Step 2: Joystick Multiplexer ───────────────────────────────────
    info "Starting Joystick Multiplexer (joystick_mux) ..."
    tmux new-window -t "$SESSION" -n "mux" -c "$INSTALL_DIR"
    tmux send-keys -t "$SESSION:mux" "./joystick_mux" Enter
    sleep "$delay"

    # ── Step 3: Keyboard Interface ─────────────────────────────────────
    info "Starting Keyboard Interface (keyboard_interface_dds) ..."
    tmux new-window -t "$SESSION" -n "kbd" -c "$INSTALL_DIR"
    tmux send-keys -t "$SESSION:kbd" "./keyboard_interface_dds" Enter
    sleep "$delay"

    # ── Step 4: Motion Controller ──────────────────────────────────────
    info "Starting Motion Controller (motion_controller) ..."
    tmux new-window -t "$SESSION" -n "ctrl" -c "$INSTALL_DIR"
    tmux send-keys -t "$SESSION:ctrl" \
        "./motion_controller --lair_dir=$LAIR_DIR --config=config_m2_metal.yaml" Enter
    sleep 1

    # ── Help window ────────────────────────────────────────────────────
    tmux new-window -t "$SESSION" -n "help"
    tmux send-keys -t "$SESSION:help" "cat <<'HELP'

  ╔══════════════════════════════════════════════════════════════╗
  ║              Svan M2 Simulation  -  Quick Reference         ║
  ╠══════════════════════════════════════════════════════════════╣
  ║                                                              ║
  ║  SWITCHING WINDOWS           (Ctrl-b then ...)               ║
  ║  ─────────────────────────────────────────────               ║
  ║   1  Physics Simulator    (simulate_pv)                      ║
  ║   2  Joystick Mux         (joystick_mux)                     ║
  ║   3  Keyboard Interface   (keyboard_interface_dds)           ║
  ║   4  Motion Controller    (motion_controller)                ║
  ║   5  This help screen                                        ║
  ║                                                              ║
  ║  PROCESS MANAGEMENT          (Ctrl-b then ...)               ║
  ║  ─────────────────────────────────────────────               ║
  ║   R  Restart the current window's process                    ║
  ║   X  Kill the current window's process                       ║
  ║   Q  Kill ALL processes and exit simulation                  ║
  ║                                                              ║
  ║  ROBOT CONTROLS  (in Keyboard Interface window)              ║
  ║  ─────────────────────────────────────────────               ║
  ║   Arrow keys       Move forward / back / strafe              ║
  ║   J / K            Turn left / right                         ║
  ║   1 / 2 / 3        Sleep / Stand / Trot mode                 ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝

HELP" Enter

    # ── Tmux keybindings (session-local) ───────────────────────────────

    # Restart process in current pane: Ctrl-b R
    # Double C-c needed for simulate_pv; harmless for other processes
    tmux bind-key -T prefix R \
        run-shell "tmux send-keys -t '$SESSION' C-c && sleep 0.3 && tmux send-keys -t '$SESSION' C-c && sleep 1 && tmux send-keys -t '$SESSION' Up && sleep 0.2 && tmux send-keys -t '$SESSION' Enter && tmux display-message ' Process restarted.'"

    # Kill process in current pane: Ctrl-b X
    # Double C-c needed for simulate_pv; harmless for other processes
    tmux bind-key -T prefix X \
        run-shell "tmux send-keys -t '$SESSION' C-c && sleep 0.3 && tmux send-keys -t '$SESSION' C-c && tmux display-message ' Process stopped.'"

    # Kill entire session: Ctrl-b Q
    tmux bind-key -T prefix Q \
        confirm-before -p "Kill ALL simulation processes? (y/n)" \
        "kill-session -t $SESSION"

    # ── Status bar ─────────────────────────────────────────────────────
    tmux set-option -t "$SESSION" status-style "bg=#1a1a2e,fg=#e0e0e0"
    tmux set-option -t "$SESSION" status-left "#[fg=#00d4ff,bold] M2 SIM "
    tmux set-option -t "$SESSION" status-right \
        "#[fg=#888888] Ctrl-b R:restart  X:stop  Q:quit-all "
    tmux set-option -t "$SESSION" status-justify centre

    # Window list styling
    tmux set-window-option -t "$SESSION" window-status-format \
        "#[fg=#888888]  #I:#W  "
    tmux set-window-option -t "$SESSION" window-status-current-format \
        "#[fg=#00d4ff,bold]  #I:#W  "

    # Number windows from 1 so they match the shortcut labels
    tmux set-option -t "$SESSION" base-index 1
    tmux set-window-option -t "$SESSION" pane-base-index 1
    # Renumber so window 1 = sim, 2 = mux, ... (created as 0-4, move to 1-5)
    tmux move-window -s "$SESSION:0" -t "$SESSION:10" 2>/dev/null || true
    tmux move-window -s "$SESSION:1" -t "$SESSION:11" 2>/dev/null || true
    tmux move-window -s "$SESSION:2" -t "$SESSION:12" 2>/dev/null || true
    tmux move-window -s "$SESSION:3" -t "$SESSION:13" 2>/dev/null || true
    tmux move-window -s "$SESSION:4" -t "$SESSION:14" 2>/dev/null || true
    tmux move-window -s "$SESSION:10" -t "$SESSION:1" 2>/dev/null || true
    tmux move-window -s "$SESSION:11" -t "$SESSION:2" 2>/dev/null || true
    tmux move-window -s "$SESSION:12" -t "$SESSION:3" 2>/dev/null || true
    tmux move-window -s "$SESSION:13" -t "$SESSION:4" 2>/dev/null || true
    tmux move-window -s "$SESSION:14" -t "$SESSION:5" 2>/dev/null || true

    # ── Focus on keyboard interface window, then attach ────────────────
    tmux select-window -t "$SESSION:3"

    echo ""
    info "All processes launched!"
    echo ""
    echo -e "  ${BOLD}Attaching to tmux session ...${NC}"
    echo -e "  You will land on the ${CYAN}Keyboard Interface${NC} window."
    echo -e "  Press ${CYAN}Ctrl-b 5${NC} to see the help screen at any time."
    echo ""

    tmux attach-session -t "$SESSION"
}

# ── Usage ──────────────────────────────────────────────────────────────────
usage() {
    echo ""
    echo -e "${BOLD}Usage:${NC}  ./m2_launch.sh [COMMAND]"
    echo ""
    echo "  (no args)    Launch the full simulation"
    echo "  --setup      Only add library paths to ~/.bashrc (no launch)"
    echo "  --kill       Kill a running simulation session"
    echo "  --status     Check if a simulation session is running"
    echo "  --help       Show this help"
    echo ""
}

# ── Main ───────────────────────────────────────────────────────────────────
case "${1:-}" in
    --setup)
        setup_env
        info "Done. Run ${CYAN}source ~/.bashrc${NC} or open a new terminal."
        ;;
    --kill)
        kill_session
        ;;
    --status)
        if tmux has-session -t "$SESSION" 2>/dev/null; then
            info "Simulation session '$SESSION' is running."
            tmux list-windows -t "$SESSION" -F "       #I: #W  (#{pane_current_command})"
            echo ""
            echo -e "  Re-attach with:  ${CYAN}tmux attach -t $SESSION${NC}"
        else
            warn "No simulation session is running."
        fi
        ;;
    --help|-h)
        usage
        ;;
    "")
        preflight
        setup_env
        kill_session
        launch
        ;;
    *)
        err "Unknown option: $1"
        usage
        exit 1
        ;;
esac
