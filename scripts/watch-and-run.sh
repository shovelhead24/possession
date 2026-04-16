#!/usr/bin/env bash
# watch-and-run.sh
# macOS equivalent of watch-and-run.ps1
# Polls GitHub for new commits every 15 seconds.
# When new code is detected, pulls and relaunches Godot automatically.
#
# Usage: ./scripts/watch-and-run.sh

# ---- CONFIGURE THESE ----
PROJECT_PATH="/Users/declan_mcgibney/possession"
GODOT_EXE="/Users/declan_mcgibney/Downloads/Godot.app/Contents/MacOS/Godot"
POLL_SECONDS=15
# --------------------------

GAME_PATH="$PROJECT_PATH/game"
LOG_DIR="$PROJECT_PATH/logs"
LOG_FILE="$LOG_DIR/godot_latest.log"
GODOT_PID=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

# ------------------------------------------------------------------ #
#  DIAGNOSTICS                                                        #
# ------------------------------------------------------------------ #
run_diagnostics() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  POSSESSION - startup diagnostics${NC}"
    echo -e "${CYAN}========================================${NC}"

    local ok=true

    # 1. Godot executable
    if [[ -x "$GODOT_EXE" ]]; then
        local version
        version=$("$GODOT_EXE" --version 2>&1 | head -1)
        echo -e "${GREEN}[OK]  Godot found: $version${NC}"
        if [[ ! "$version" =~ ^4\.5 ]]; then
            echo -e "${YELLOW}[WARN] Project requires Godot 4.5 - you have: $version${NC}"
        fi
    else
        echo -e "${RED}[FAIL] Godot not found at: $GODOT_EXE${NC}"
        echo -e "${RED}       Edit GODOT_EXE at the top of this script.${NC}"
        ok=false
    fi

    # 2. project.godot
    if [[ -f "$GAME_PATH/project.godot" ]]; then
        echo -e "${GREEN}[OK]  project.godot found${NC}"
    else
        echo -e "${RED}[FAIL] project.godot not found under: $PROJECT_PATH${NC}"
        echo -e "${RED}       Expected: $GAME_PATH/project.godot${NC}"
        ok=false
    fi

    # 3. Git repo
    local git_hash
    git_hash=$(git -C "$PROJECT_PATH" rev-parse HEAD 2>/dev/null)
    if [[ -n "$git_hash" ]]; then
        echo -e "${GREEN}[OK]  Git repo at commit: ${git_hash:0:8}${NC}"
    else
        echo -e "${RED}[FAIL] Not a git repo: $PROJECT_PATH${NC}"
        ok=false
    fi

    # 4. Asset packs
    local asset_packs=(
        "custom_halo_classic_ring"
        "enemy"
        "fp_arms"
        "fps_arms"
        "halo_-_carbine"
        "halo_railgun_redesigned"
        "halo_warthog"
        "realistic_fir_trees_pack_lods_gameready"
        "realistic_trees_collection"
        "skybox"
        "grass_pack_of_9_vars_lowpoly_game_ready"
        "tall_coniferous_fir_variant_low_poly"
        "low_poly_red_spruce_tree_custom_textures"
    )
    local missing=0
    local missing_names=()
    for pack in "${asset_packs[@]}"; do
        if [[ ! -d "$GAME_PATH/$pack" ]]; then
            ((missing++))
            missing_names+=("$pack")
        fi
    done
    if [[ $missing -eq 0 ]]; then
        echo -e "${GREEN}[OK]  All asset packs present${NC}"
    else
        echo -e "${YELLOW}[WARN] Missing asset packs ($missing/${#asset_packs[@]}) - game may have missing meshes:${NC}"
        for p in "${missing_names[@]}"; do
            echo -e "${YELLOW}       - $p${NC}"
        done
    fi

    # 5. Log directory
    mkdir -p "$LOG_DIR"
    echo -e "${GREEN}[OK]  Logs will be written to: $LOG_FILE${NC}"

    echo -e "${CYAN}========================================${NC}"
    echo ""

    $ok
}

# ------------------------------------------------------------------ #
#  LAUNCH GODOT                                                       #
# ------------------------------------------------------------------ #
start_godot() {
    # Kill existing Godot if running
    if [[ -n "$GODOT_PID" ]] && kill -0 "$GODOT_PID" 2>/dev/null; then
        echo "$(date +%H:%M:%S) Stopping Godot (PID $GODOT_PID)..."
        kill "$GODOT_PID" 2>/dev/null
        sleep 2
    fi

    local godot_log="$HOME/Library/Application Support/Godot/app_userdata/HaloTest/logs/godot.log"
    echo "$(date +%H:%M:%S) Launching Godot..."
    echo "  Path: $GAME_PATH"
    echo "  Log : $godot_log"
    echo "  Tip : tail -f \"$godot_log\""

    "$GODOT_EXE" --path "$GAME_PATH" --verbose &
    GODOT_PID=$!
}

# ------------------------------------------------------------------ #
#  PUSH LOG TO REPO                                                   #
# ------------------------------------------------------------------ #
push_log() {
    local godot_log="$HOME/Library/Application Support/Godot/app_userdata/HaloTest/logs/godot.log"
    if [[ ! -f "$godot_log" ]]; then
        echo -e "$(date +%H:%M:%S) ${YELLOW}No Godot log found yet.${NC}"
        return
    fi
    echo -e "$(date +%H:%M:%S) ${CYAN}Pushing log to repo...${NC}"
    cp "$godot_log" "$LOG_FILE"
    git -C "$PROJECT_PATH" add "logs/godot_latest.log" 2>/dev/null
    local msg="log: mac push $(date '+%Y-%m-%d %H:%M:%S')"
    git -C "$PROJECT_PATH" commit -m "$msg" 2>/dev/null
    git -C "$PROJECT_PATH" pull --rebase origin main 2>/dev/null
    git -C "$PROJECT_PATH" push --quiet origin main 2>/dev/null
    echo -e "$(date +%H:%M:%S) ${GREEN}Log pushed - Claude can now read logs/godot_latest.log${NC}"
}

# ------------------------------------------------------------------ #
#  CLEANUP on exit                                                    #
# ------------------------------------------------------------------ #
cleanup() {
    echo ""
    echo "Shutting down..."
    if [[ -n "$GODOT_PID" ]] && kill -0 "$GODOT_PID" 2>/dev/null; then
        kill "$GODOT_PID" 2>/dev/null
    fi
    exit 0
}
trap cleanup SIGINT SIGTERM

# ------------------------------------------------------------------ #
#  MAIN                                                               #
# ------------------------------------------------------------------ #

if ! run_diagnostics; then
    echo -e "${RED}Fix the errors above then re-run this script.${NC}"
    exit 1
fi

# Asset import
echo ""
echo -e "${CYAN}=== ASSET IMPORT ===${NC}"
echo -e "${YELLOW}Importing resources (this takes ~30-60s on first run, fast after)...${NC}"
timeout 120 "$GODOT_EXE" --headless --editor --quit --path "$GAME_PATH" 2>/dev/null
import_exit=$?
if [[ $import_exit -eq 124 ]]; then
    echo -e "${YELLOW}Import timed out after 120s - continuing anyway${NC}"
else
    echo -e "${GREEN}Import complete (exit: $import_exit)${NC}"
fi
echo -e "${CYAN}====================${NC}"
echo ""

# Initial pull if behind
echo "$(date +%H:%M:%S) Checking for commits missed while watcher was offline..."
git -C "$PROJECT_PATH" fetch origin main 2>/dev/null
start_remote=$(git -C "$PROJECT_PATH" rev-parse origin/main 2>/dev/null)
start_local=$(git -C "$PROJECT_PATH" rev-parse HEAD 2>/dev/null)
if [[ -n "$start_remote" && "$start_remote" != "$start_local" ]]; then
    echo -e "$(date +%H:%M:%S) ${CYAN}Behind origin - pulling now...${NC}"
    git -C "$PROJECT_PATH" pull --rebase origin main 2>/dev/null
    echo -e "$(date +%H:%M:%S) ${GREEN}Pulled.${NC}"
else
    echo -e "$(date +%H:%M:%S) ${GREEN}Already up to date (${start_local:0:8}).${NC}"
fi

echo "Watching for new commits every $POLL_SECONDS seconds. Press Ctrl+C to stop."
echo "Press L + Enter to push the current log so Claude can read it."
echo ""

start_godot
last_hash=$(git -C "$PROJECT_PATH" rev-parse HEAD 2>/dev/null)
poll_count=0

while true; do
    # Wait, but check for 'L' keypress
    read -t "$POLL_SECONDS" -n 1 key 2>/dev/null
    if [[ "$key" == "l" || "$key" == "L" ]]; then
        push_log
        last_hash=$(git -C "$PROJECT_PATH" rev-parse HEAD 2>/dev/null)
    fi

    ((poll_count++))
    git -C "$PROJECT_PATH" fetch origin main 2>/dev/null
    remote_hash=$(git -C "$PROJECT_PATH" rev-parse origin/main 2>/dev/null)

    if [[ -n "$remote_hash" && "$remote_hash" != "$last_hash" ]]; then
        echo -e "$(date +%H:%M:%S) ${CYAN}New commits detected - pulling...${NC}"
        prev_hash="$last_hash"
        git -C "$PROJECT_PATH" pull --rebase origin main 2>/dev/null
        last_hash=$(git -C "$PROJECT_PATH" rev-parse HEAD 2>/dev/null)
        # Show what arrived
        new_commits=$(git -C "$PROJECT_PATH" log --oneline "$prev_hash..HEAD" 2>/dev/null | head -5)
        if [[ -n "$new_commits" ]]; then
            echo -e "  ${CYAN}Pulled commits:${NC}"
            echo "$new_commits" | while read -r c; do
                echo "    $c"
            done
        fi
        echo "$(date +%H:%M:%S) Relaunching Godot..."
        start_godot
    fi

    # Heartbeat every 4 polls
    if (( poll_count % 4 == 0 )); then
        local_hash=$(git -C "$PROJECT_PATH" rev-parse HEAD 2>/dev/null)
        echo -e "$(date +%H:%M:%S) ${GRAY}[watching] commit ${local_hash:0:8} | poll #$poll_count${NC}"
    fi

    # Auto-push log every 20 polls (~5 minutes)
    if (( poll_count % 20 == 0 )); then
        push_log
        last_hash=$(git -C "$PROJECT_PATH" rev-parse HEAD 2>/dev/null)
    fi

    # Check if Godot crashed/exited
    if [[ -n "$GODOT_PID" ]] && ! kill -0 "$GODOT_PID" 2>/dev/null; then
        wait "$GODOT_PID" 2>/dev/null
        exit_code=$?
        echo -e "$(date +%H:%M:%S) ${CYAN}Godot exited (code $exit_code) - pushing log...${NC}"
        push_log
        last_hash=$(git -C "$PROJECT_PATH" rev-parse HEAD 2>/dev/null)

        if [[ -f "$PROJECT_PATH/logs/quit_requested" ]]; then
            rm -f "$PROJECT_PATH/logs/quit_requested"
            echo -e "$(date +%H:%M:%S) ${YELLOW}Clean quit - log pushed. Press any key to close watcher.${NC}"
            read -n 1
            break
        fi

        echo "$(date +%H:%M:%S) Relaunching Godot..."
        start_godot
    fi
done
