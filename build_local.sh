#!/usr/bin/env bash
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────
R='\033[1;31m'  G='\033[1;32m'  Y='\033[1;33m'  B='\033[1;34m'
C='\033[1;36m'  M='\033[1;35m'  W='\033[1;37m'  D='\033[0m'
BG='\033[48;5;235m'  UL='\033[4m'  BL='\033[1m'
GREEN='\033[38;5;114m' RED='\033[38;5;203m' CYAN='\033[38;5;75m'
YELLOW='\033[38;5;220m' PINK='\033[38;5;213m' LGRAY='\033[38;5;250m'

# ── Helpers ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

border() {
    local len=${#1} pad=2 total=$((len + pad * 2))
    local line=""
    for ((i=0; i<total; i++)); do line+="─"; done
    echo -e "${CYAN}┌${line}┐${D}"
    printf "${CYAN}│${D}%*s%s%*s${CYAN}│${D}\n" "$pad" "" "$1" "$pad" ""
    echo -e "${CYAN}└${line}┘${D}"
}

section() {
    echo ""
    echo -e "  ${PINK}▸${D} ${BL}${W}$1${D}"
    echo -e "  ${LGRAY}├──────────────────────────────────────${D}"
}

bullet() {
    echo -e "  ${PINK}│${D}  $1"
}

done_msg() {
    echo -e "  ${PINK}│${D}"
    echo -e "  ${PINK}╰─${D} ${GREEN}✓${D} $1"
}

warn_msg() {
    echo -e "  ${PINK}│${D}"
    echo -e "  ${PINK}╰─${D} ${YELLOW}⚠${D} $1"
}

fail_msg() {
    echo -e "  ${PINK}╰─${D} ${RED}✗${D} $1"
}

menu_header() {
    local title="$1" index="$2"
    echo ""
    echo -e "  ${PINK}╭──────────────────────────────────────╮${D}"
    printf "  ${PINK}│${D}  ${BL}${W}%-20s${D} ${LGRAY}[${index}]${D}     ${PINK}│${D}\n" "$title"
    echo -e "  ${PINK}╰──────────────────────────────────────╯${D}"
}

# ── Defaults ────────────────────────────────────────────────────────
WORKSPACE="${WORKSPACE:-$HOME/twrp_workspace}"
INSTALL_DEPS="${INSTALL_DEPS:-1}"
SWAP_GB="${SWAP_GB:-12}"

MANIFEST_URL="${MANIFEST_URL:-}"
MANIFEST_BRANCH="${MANIFEST_BRANCH:-}"
DEVICE_NAME="${DEVICE_NAME:-}"
BUILD_TARGET="${BUILD_TARGET:-}"
LUNCH_TARGET="${LUNCH_TARGET:-}"

usage() {
    cat <<EOF
Usage: $0 [-u MANIFEST_URL] [-b MANIFEST_BRANCH] [-d DEVICE_NAME] [-t BUILD_TARGET] [-w WORKSPACE]
EOF
    exit 1
}

while getopts "u:b:d:t:w:h" opt; do
    case "$opt" in
        u) MANIFEST_URL="$OPTARG" ;;
        b) MANIFEST_BRANCH="$OPTARG" ;;
        d) DEVICE_NAME="$OPTARG" ;;
        t) BUILD_TARGET="$OPTARG" ;;
        w) WORKSPACE="$OPTARG" ;;
        h|*) usage ;;
    esac
done

# ── Interactive Mode ────────────────────────────────────────────────
if [ -z "$MANIFEST_URL" ] || [ -z "$MANIFEST_BRANCH" ] || [ -z "$DEVICE_NAME" ] || [ -z "$BUILD_TARGET" ] || [ -z "$LUNCH_TARGET" ]; then
    echo ""
    echo -e "${BG}"
    echo -e "${CYAN}    ╔═══════════════════════════════════════╗${D}"
    echo -e "${CYAN}    ║${D}  ${BL}${M}  ╦═╗╔═╗╔╦╗╔╦╗╔═╗╦═╗${D}                ${CYAN}║${D}"
    echo -e "${CYAN}    ║${D}  ${BL}${M}  ╠╦╝║╣  ║║║║║║╣ ╠╦╝${D}                ${CYAN}║${D}"
    echo -e "${CYAN}    ║${D}  ${BL}${M}  ╩╚═╚═╝═╩╝╩╝╚═╝╩╚═${D}  ${LGRAY}v2.0 Local${D}   ${CYAN}║${D}"
    echo -e "${CYAN}    ╚═══════════════════════════════════════╝${D}"
    echo ""
fi

if [ -z "$MANIFEST_URL" ]; then
    menu_header "MANIFEST" "1/4"
    echo ""
    echo -e "    ${LGRAY}1)${D} ${G}TWRP${D}          ${LGRAY}minimal-manifest-twrp/aosp${D}"
    echo -e "    ${LGRAY}2)${D} ${C}SHRP${D}          ${LGRAY}rjfahad/manifest${D}"
    echo -e "    ${LGRAY}3)${D} ${M}PBRP${D}          ${LGRAY}PitchBlackRecoveryProject${D}"
    echo -e "    ${LGRAY}4)${D} ${Y}LineageOS${D}     ${LGRAY}minimal-manifest-twrp/lineageos${D}"
    echo -e "    ${LGRAY}5)${D} ${R}Custom URL${D}"
    echo ""
    read -rp $'    \e[1m► Select [1-5]: \e[0m' choice
    case "$choice" in
        1) MANIFEST_URL="https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp" ;;
        2) MANIFEST_URL="https://github.com/rjfahad/manifest" ;;
        3) MANIFEST_URL="https://github.com/PitchBlackRecoveryProject/manifest_pb" ;;
        4) MANIFEST_URL="https://github.com/minimal-manifest-twrp/platform_manifest_twrp_lineageos" ;;
        5) read -rp $'    \e[1m► Enter URL: \e[0m' MANIFEST_URL ;;
        *) echo -e "    ${RED}Invalid choice${D}"; exit 1 ;;
    esac
fi

if [ -z "$MANIFEST_BRANCH" ]; then
    menu_header "BRANCH" "2/4"
    echo ""
    echo -e "    ${LGRAY}1)${D} ${G}twrp-11${D}       ${LGRAY}2)${D} ${C}twrp-12.1${D}     ${LGRAY}3)${D} ${M}twrp-14.1${D}"
    echo -e "    ${LGRAY}4)${D} ${Y}shrp-12.1${D}     ${LGRAY}5)${D} ${G}v3_11.0${D}       ${LGRAY}6)${D} ${C}v3_10.0${D}"
    echo -e "    ${LGRAY}7)${D} ${M}android-12.1${D}  ${LGRAY}8)${D} ${Y}android-11.0${D}  ${LGRAY}9)${D} ${R}Custom${D}"
    echo ""
    read -rp $'    \e[1m► Select [1-9]: \e[0m' choice
    case "$choice" in
        1) MANIFEST_BRANCH="twrp-11" ;;
        2) MANIFEST_BRANCH="twrp-12.1" ;;
        3) MANIFEST_BRANCH="twrp-14.1" ;;
        4) MANIFEST_BRANCH="shrp-12.1" ;;
        5) MANIFEST_BRANCH="v3_11.0" ;;
        6) MANIFEST_BRANCH="v3_10.0" ;;
        7) MANIFEST_BRANCH="android-12.1" ;;
        8) MANIFEST_BRANCH="android-11.0" ;;
        9) read -rp $'    \e[1m► Enter branch: \e[0m' MANIFEST_BRANCH ;;
        *) echo -e "    ${RED}Invalid choice${D}"; exit 1 ;;
    esac
fi

if [ -z "$DEVICE_NAME" ]; then
    menu_header "DEVICE" "3/4"
    echo ""
    read -rp $'    \e[1m► Device name \e[0m\e[38;5;250m[even]\e[0m: \e[0m' DEVICE_NAME
    DEVICE_NAME="${DEVICE_NAME:-even}"
fi

if [ -z "$LUNCH_TARGET" ]; then
    menu_header "LUNCH TARGET" "4/4"
    echo ""
    echo -e "    ${LGRAY}1)${D} ${G}twrp_${DEVICE_NAME}-eng${D}"
    echo -e "    ${LGRAY}2)${D} ${C}omni_${DEVICE_NAME}-eng${D}"
    echo -e "    ${LGRAY}3)${D} ${R}Custom target${D}"
    echo ""
    read -rp $'    \e[1m► Select [1-3]: \e[0m' choice
    case "$choice" in
        1) LUNCH_TARGET="twrp_${DEVICE_NAME}-eng" ;;
        2) LUNCH_TARGET="omni_${DEVICE_NAME}-eng" ;;
        3) read -rp $'    \e[1m► Enter target: \e[0m' LUNCH_TARGET ;;
        *) echo -e "    ${RED}Invalid choice${D}"; exit 1 ;;
    esac
fi

if [ -z "$BUILD_TARGET" ]; then
    echo ""
    echo -e "    ${LGRAY}1)${D} ${G}recovery${D}"
    echo -e "    ${LGRAY}2)${D} ${C}boot${D}"
    echo ""
    read -rp $'    \e[1m► Build target [1-2]: \e[0m' choice
    case "$choice" in
        1) BUILD_TARGET="recovery" ;;
        2) BUILD_TARGET="boot" ;;
        *) echo -e "    ${RED}Invalid choice${D}"; exit 1 ;;
    esac
fi

# ── Summary ─────────────────────────────────────────────────────────
echo ""
echo -e "  ${CYAN}╔═══════════════════════════════════════════╗${D}"
echo -e "  ${CYAN}║${D}           ${BL}${W}BUILD CONFIGURATION${D}              ${CYAN}║${D}"
echo -e "  ${CYAN}╠═══════════════════════════════════════════╣${D}"
printf "  ${CYAN}║${D}  ${LGRAY}Manifest:${D}   ${G}%-28s${D}  ${CYAN}║${D}\n" "$MANIFEST_URL"
printf "  ${CYAN}║${D}  ${LGRAY}Branch:${D}     ${C}%-28s${D}  ${CYAN}║${D}\n" "$MANIFEST_BRANCH"
printf "  ${CYAN}║${D}  ${LGRAY}Device:${D}     ${M}%-28s${D}  ${CYAN}║${D}\n" "$DEVICE_NAME"
printf "  ${CYAN}║${D}  ${LGRAY}Target:${D}     ${Y}%-28s${D}  ${CYAN}║${D}\n" "${BUILD_TARGET}.img"
printf "  ${CYAN}║${D}  ${LGRAY}Lunch:${D}      ${PINK}%-28s${D}  ${CYAN}║${D}\n" "$LUNCH_TARGET"
printf "  ${CYAN}║${D}  ${LGRAY}Workspace:${D}  ${LGRAY}%-28s${D}  ${CYAN}║${D}\n" "$WORKSPACE"
echo -e "  ${CYAN}╚═══════════════════════════════════════════╝${D}"
echo ""

read -rp $'  \e[1mProceed with build? \e[0m\e[38;5;250m[Y/n]\e[0m: \e[0m' CONFIRM
if [[ "${CONFIRM,,}" == "n" || "${CONFIRM,,}" == "no" ]]; then
    echo -e "  ${RED}Aborted.${D}"
    exit 0
fi

# ── Sudo Detection ─────────────────────────────────────────────────
SUDO=""
apt_ok=0
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        SUDO="sudo"
    fi
fi
[ -n "$SUDO" ] || [ "$(id -u)" -eq 0 ] && apt_ok=1

tg_notify() {
    if [ -n "${TG_BOT_TOKEN:-}" ] && [ -n "${TG_CHAT_ID:-}" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
            -d chat_id="${TG_CHAT_ID}" \
            -d text="$1" \
            -d parse_mode=html \
            -d disable_web_page_preview=true || true
    fi
}

# ── Dependencies ────────────────────────────────────────────────────
section "Installing dependencies"
if [ "$INSTALL_DEPS" = "1" ] && [ "$apt_ok" = "1" ]; then
    APT_CMD="apt-get install -y"
    [ -n "$SUDO" ] && APT_CMD="$SUDO $APT_CMD"
    $SUDO apt update -qq 2>/dev/null
    $APT_CMD -qq zip unzip tar gzip bzip2 openjdk-8-jdk ccache rsync python3 2>/dev/null
    done_msg "Dependencies installed"
elif [ "$INSTALL_DEPS" = "1" ]; then
    warn_msg "No root access — skipping apt"
    bullet "${LGRAY}Ensure installed: zip unzip openjdk-8-jdk ccache rsync python3${D}"
fi

if ! command -v java >/dev/null 2>&1; then
    fail_msg "Java 8 not found — install OpenJDK 8 before building"
fi

# ── Repo ────────────────────────────────────────────────────────────
section "Setting up repo"
if ! command -v repo >/dev/null 2>&1; then
    mkdir -p "$HOME/bin"
    curl -s https://storage.googleapis.com/git-repo-downloads/repo > "$HOME/bin/repo"
    chmod a+x "$HOME/bin/repo"
    export PATH="$HOME/bin:$PATH"
    done_msg "repo installed"
else
    done_msg "repo already present"
fi

git config --global user.name "rjfahad"
git config --global user.email "actions@github.com"

# ── Workspace ───────────────────────────────────────────────────────
section "Preparing workspace"
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"
done_msg "Workspace ready at ${WORKSPACE}"

# ── Swap ────────────────────────────────────────────────────────────
if [ "$SWAP_GB" != "0" ] && [ "$(id -u)" -eq 0 ]; then
    CURRENT_SWAP_KB="$(awk '/^SwapTotal/ {print $2}' /proc/meminfo)"
    if [ "${CURRENT_SWAP_KB:-0}" -lt $((SWAP_GB * 1024 * 1024)) ] && [ ! -f /swapfile ]; then
        fallocate -l "${SWAP_GB}G" /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo "/swapfile none swap defaults 0 0" >> /etc/fstab
        done_msg "${SWAP_GB}G swap enabled"
    fi
fi

# ── Telegram Start ──────────────────────────────────────────────────
tg_notify "🚀 <b>Build Started</b>%0AManifest: ${MANIFEST_URL}%0ABranch: ${MANIFEST_BRANCH}%0ADevice: ${DEVICE_NAME}%0ATarget: ${BUILD_TARGET}"

# ── Repo Sync ───────────────────────────────────────────────────────
section "Syncing sources"
if [ ! -f .repo/manifest.xml ]; then
    bullet "Initializing repo..."
    repo init --depth=1 -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" 2>&1 | tail -1
    bullet "Syncing..."
    repo sync -j"$(nproc --all)" --force-sync --no-tags 2>&1 | tail -1
    done_msg "Repo synced"
else
    bullet "Existing repo found, syncing..."
    repo sync -j"$(nproc --all)" --force-sync --no-tags 2>&1 | tail -1
    done_msg "Repo synced"
fi

# ── Device Tree ─────────────────────────────────────────────────────
section "Installing device tree"
rm -rf "./device/realme/${DEVICE_NAME}"
mkdir -p "./device/realme/${DEVICE_NAME}"
rsync -a --exclude='.git' --exclude='.github' "$SCRIPT_DIR"/ "./device/realme/${DEVICE_NAME}/"
done_msg "Device tree → device/realme/${DEVICE_NAME}"

# ── Dependencies ────────────────────────────────────────────────────
case "$MANIFEST_BRANCH" in
    twrp-11|twrp-12.1) BUILD_TREE="twrp" ;;
    *) BUILD_TREE="omni" ;;
esac

section "Syncing device dependencies"
DEP_FILE="./device/realme/${DEVICE_NAME}/${BUILD_TREE}.dependencies"
CONVERTER="./device/realme/${DEVICE_NAME}/scripts/convert.sh"
if [ -f "$CONVERTER" ] && [ -f "$DEP_FILE" ]; then
    bullet "Running convert.sh on ${BUILD_TREE}.dependencies..."
    bash "$CONVERTER" "$DEP_FILE" 2>/dev/null || true
fi
repo sync -j"$(nproc --all)" 2>&1 | tail -1
done_msg "Dependencies synced"

# ── Build ───────────────────────────────────────────────────────────
echo ""
echo -e "  ${CYAN}╔═══════════════════════════════════════════╗${D}"
echo -e "  ${CYAN}║${D}           ${BL}${M}🔨 BUILDING RECOVERY${D}              ${CYAN}║${D}"
echo -e "  ${CYAN}╚═══════════════════════════════════════════╝${D}"
echo ""

set +eu
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
export USE_CCACHE=1
export CCACHE_COMPRESS=1
export CCACHE_MAXSIZE=50G
export CCACHE_DIR="$HOME/.ccache"
export TZ=Asia/Jakarta
export TW_THEME=portrait_hdpi
export TARGET_SCREEN_WIDTH=720
export TARGET_SCREEN_HEIGHT=1600
lunch "${LUNCH_TARGET}"
if ! make "${BUILD_TARGET}image" -j"$(nproc --all)"; then
    set -eu
    fail_msg "Build FAILED"
    tg_notify "❌ <b>Build Failed</b>%0ADevice: ${DEVICE_NAME}%0ATarget: ${BUILD_TARGET}"
    exit 1
fi
set -eu

# ── Package ─────────────────────────────────────────────────────────
OUT_DIR="$WORKSPACE/out/target/product/${DEVICE_NAME}"
cd "$OUT_DIR"
zip -j recovery.zip "${BUILD_TARGET}.img" >/dev/null 2>&1

echo ""
echo -e "  ${CYAN}╔═══════════════════════════════════════════╗${D}"
echo -e "  ${CYAN}║${D}           ${BL}${G}✅ BUILD COMPLETE${D}                ${CYAN}║${D}"
echo -e "  ${CYAN}╠═══════════════════════════════════════════╣${D}"
printf "  ${CYAN}║${D}  ${LGRAY}Image:${D}   ${G}%-30s${D}  ${CYAN}║${D}\n" "$OUT_DIR/${BUILD_TARGET}.img"
printf "  ${CYAN}║${D}  ${LGRAY}Zip:${D}     ${G}%-30s${D}  ${CYAN}║${D}\n" "$OUT_DIR/recovery.zip"
echo -e "  ${CYAN}╚═══════════════════════════════════════════╝${D}"

tg_notify "✅ <b>Build Complete</b>%0ADevice: ${DEVICE_NAME}%0ATarget: ${BUILD_TARGET}"

if [ -n "${TG_BOT_TOKEN:-}" ] && [ -n "${TG_CHAT_ID:-}" ]; then
    bullet "Sending to Telegram..."
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendDocument" \
        -F chat_id="${TG_CHAT_ID}" \
        -F document="@recovery.zip" \
        -F caption="${DEVICE_NAME}_${BUILD_TARGET}_$(date +%s).zip" || true
    done_msg "Sent to Telegram"
fi

echo ""
echo -e "  ${G}Done!${D}"
echo ""
