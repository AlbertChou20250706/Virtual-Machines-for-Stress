#!/bin/bash

################################################################################
#                                                                              #
#  Project    : Stress Workload Generator (Stable English Version)            #
#  Version    : 4.0                                                            #
#  Filename   : stress_workload_ENGLISH.sh                                    #
#  Author     : Albert Zhou                                                    #
#  Date       : 2026-05-05                                                     #
#  Platform   : Red Hat Enterprise Linux 9.6 on VMware ESXi 9.0               #
#                                                                              #
#  目的(モクテキ): インタラクティブストレステストツール                         #
#  Purpose: Interactive stress testing tool with time configuration            #
#                                                                              #
#  修正履歴(シュウセイリレキ) - Fix History:                                   #
#  ----------------------------------------------------------------------------#
#  v4.0 - 重大バグ修正(ジュウダイ バグ シュウセイ)                              #
#         CRITICAL FIX: Command substitution issue                            #
#                                                                              #
#         旧バージョン問題(キュウバージョン モンダイ):                          #
#           local duration=$(input_test_time ...)                             #
#           → $()がprintfメニューを全部飲み込む(ノミコム)                      #
#           → User cannot see prompts, appears frozen                         #
#                                                                              #
#         新バージョン解決(シンバージョン カイケツ):                            #
#           input_test_time ...                                               #
#           local duration=$RESULT_DURATION                                   #
#           → グローバル変数で値を返す(アタイヲ カエス)                         #
#           → All menus visible, no freeze                                    #
#                                                                              #
################################################################################

# 環境設定(カンキョウ セッテイ) - Environment setup
set -u

# スクリプト情報(スクリプト ジョウホウ) - Script info
SCRIPT_VERSION="4.0"
SCRIPT_NAME=$(basename "$0")

# ディレクトリ設定(ディレクトリ セッテイ) - Directory configuration
LOG_DIR="/var/log/stress-test"
DATA_DIR="${LOG_DIR}/data"
REPORT_DIR="${LOG_DIR}/reports"
RUN_DIR="/tmp/stress-test-run"

# ============================================================================
# PART 1: 色定義(イロ テイギ) - Color definitions
# ============================================================================

C_INFO="\033[1;36m"
C_PASS="\033[1;32m"
C_WARN="\033[1;33m"
C_ERROR="\033[1;31m"
C_TITLE="\033[1;35m"
C_MENU="\033[1;34m"
C_INPUT="\033[1;33m"
C_RESET="\033[0m"

# ============================================================================
# PART 2: グローバル変数(グローバル ヘンスウ) - Global return variables
#         重要(ジュウヨウ): $()問題回避用(モンダイ カイヒ ヨウ)
#         IMPORTANT: Used to avoid command substitution pitfall
# ============================================================================

RESULT_DURATION=0
RESULT_WORKERS=0
RESULT_PERCENT=0
RESULT_CONFIRM="no"

# ============================================================================
# PART 3: ログ関数(ログ カンスウ) - Logging functions
# ============================================================================

log_info() {
    mkdir -p "$LOG_DIR" 2>/dev/null
    printf "${C_INFO}[INFO]${C_RESET} %s\n" "$*" | tee -a "${LOG_DIR}/stress.log"
}

log_pass() {
    mkdir -p "$LOG_DIR" 2>/dev/null
    printf "${C_PASS}[PASS]${C_RESET} %s\n" "$*" | tee -a "${LOG_DIR}/stress.log"
}

log_warn() {
    mkdir -p "$LOG_DIR" 2>/dev/null
    printf "${C_WARN}[WARN]${C_RESET} %s\n" "$*" | tee -a "${LOG_DIR}/stress.log"
}

log_error() {
    mkdir -p "$LOG_DIR" 2>/dev/null
    printf "${C_ERROR}[ERROR]${C_RESET} %s\n" "$*" | tee -a "${LOG_DIR}/stress.log"
}

log_title() {
    printf "\n${C_TITLE}========== %s ==========${C_RESET}\n" "$*"
}

# ============================================================================
# PART 4: 環境初期化(カンキョウ ショキカ) - Initialize environment
# ============================================================================

init_environment() {
    log_title "Initialize Stress Workload Environment"

    # ルート権限チェック(ルート ケンゲン チェック) - Root privilege check
    if [[ $EUID -ne 0 ]]; then
        log_error "ERROR: Root privileges required"
        printf "Please run: sudo bash %s\n" "$SCRIPT_NAME"
        exit 1
    fi

    # ディレクトリ作成(ディレクトリ サクセイ) - Create directories
    mkdir -p "$LOG_DIR" "$DATA_DIR" "$REPORT_DIR" "$RUN_DIR"

    check_dependencies
    log_pass "OK: Environment initialized"
}

# 依存関係チェック(イゾン カンケイ チェック) - Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    local missing=0

    for cmd in stress-ng top free; do
        if ! command -v "$cmd" &>/dev/null; then
            log_warn "MISSING: $cmd"
            missing=$((missing + 1))
        else
            log_pass "OK: $cmd available"
        fi
    done

    # 不足ツールインストール(フソク ツール インストール) - Install missing tools
    if [[ $missing -gt 0 ]]; then
        log_warn "Attempting to install missing tools..."
        sudo dnf install -y stress-ng sysstat >/dev/null 2>&1 || \
            log_error "ERROR: Installation failed - please install manually"
    fi
}

# ============================================================================
# PART 5: ユーティリティ関数(ユーティリティ カンスウ) - Utility functions
# ============================================================================

# 秒数フォーマット(ビョウスウ フォーマット) - Format seconds to readable string
seconds_to_format() {
    local secs=$1
    local h=$((secs / 3600))
    local m=$(((secs % 3600) / 60))
    local s=$((secs % 60))

    if [[ $h -gt 0 ]]; then
        printf "%dh %dm %ds" $h $m $s
    elif [[ $m -gt 0 ]]; then
        printf "%dm %ds" $m $s
    else
        printf "%ds" $s
    fi
}

# システム状態表示(システム ジョウタイ ヒョウジ) - Display system stats
show_system_stats() {
    printf "\n${C_INFO}===== System Status =====${C_RESET}\n"
    printf "  CPU Load: %s\n" "$(uptime | awk -F'load average:' '{print $2}')"

    local mem_info used total
    mem_info=$(free -h | grep Mem)
    used=$(echo "$mem_info" | awk '{print $3}')
    total=$(echo "$mem_info" | awk '{print $2}')
    printf "  Memory:   %s / %s\n" "$used" "$total"

    local cpu
    cpu=$(top -bn1 2>/dev/null | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{printf "%.1f", 100 - $1}')
    printf "  CPU Use:  %s%%\n\n" "$cpu"
}

# ============================================================================
# PART 6: インタラクティブ入力関数(インタラクティブ ニュウリョク カンスウ)
#         Interactive Input Functions
#
#         注意(チュウイ): 値を返すのにグローバル変数使用!!
#         WARNING: Use GLOBAL VARIABLES to return values!!
#         理由(リユウ): $()がprintfメニューを飲み込む(ノミコム)問題回避
#         REASON: $() swallows printf output, making menus invisible
# ============================================================================

# 時間入力(ジカン ニュウリョク) - Time input → sets RESULT_DURATION
input_test_time() {
    local test_name="$1"

    log_title "Step 1: Time Configuration - $test_name"

    printf "${C_INFO}Default:${C_RESET} 1 hour (3600 seconds)\n\n"

    printf "${C_MENU}Quick Select:${C_RESET}\n"
    printf "  1) 1 minute    (60 sec)\n"
    printf "  2) 5 minutes   (300 sec)\n"
    printf "  3) 10 minutes  (600 sec)\n"
    printf "  4) 30 minutes  (1800 sec)\n"
    printf "  5) 1 hour      (3600 sec)  [default]\n"
    printf "  6) 2 hours     (7200 sec)\n"
    printf "  7) 4 hours     (14400 sec)\n"
    printf "\n"

    printf "${C_MENU}Custom Time:${C_RESET}\n"
    printf "  8) Enter hours/minutes/seconds\n"
    printf "  9) Enter minutes only\n"
    printf "  0) Enter seconds only\n"
    printf "\n"

    printf "${C_INPUT}Select option [0-9, default 5]: ${C_RESET}"
    local time_choice=""
    read -r time_choice
    time_choice="${time_choice:-5}"

    case "$time_choice" in
        1) RESULT_DURATION=60 ;;
        2) RESULT_DURATION=300 ;;
        3) RESULT_DURATION=600 ;;
        4) RESULT_DURATION=1800 ;;
        5) RESULT_DURATION=3600 ;;
        6) RESULT_DURATION=7200 ;;
        7) RESULT_DURATION=14400 ;;
        8)
            local hours minutes seconds
            printf "${C_INPUT}Enter hours [default 1]: ${C_RESET}"
            read -r hours
            hours="${hours:-1}"
            [[ ! "$hours" =~ ^[0-9]+$ ]] && hours=1

            printf "${C_INPUT}Enter minutes [default 0]: ${C_RESET}"
            read -r minutes
            minutes="${minutes:-0}"
            [[ ! "$minutes" =~ ^[0-9]+$ ]] && minutes=0
            [[ $minutes -gt 59 ]] && minutes=59

            printf "${C_INPUT}Enter seconds [default 0]: ${C_RESET}"
            read -r seconds
            seconds="${seconds:-0}"
            [[ ! "$seconds" =~ ^[0-9]+$ ]] && seconds=0
            [[ $seconds -gt 59 ]] && seconds=59

            RESULT_DURATION=$((hours * 3600 + minutes * 60 + seconds))
            [[ $RESULT_DURATION -lt 10 ]] && RESULT_DURATION=10
            ;;
        9)
            local minutes
            printf "${C_INPUT}Enter minutes [default 30]: ${C_RESET}"
            read -r minutes
            minutes="${minutes:-30}"
            [[ ! "$minutes" =~ ^[0-9]+$ ]] && minutes=30
            RESULT_DURATION=$((minutes * 60))
            ;;
        0)
            local seconds
            printf "${C_INPUT}Enter seconds [default 3600]: ${C_RESET}"
            read -r seconds
            seconds="${seconds:-3600}"
            [[ ! "$seconds" =~ ^[0-9]+$ ]] && seconds=3600
            [[ $seconds -lt 10 ]] && seconds=10
            RESULT_DURATION=$seconds
            ;;
        *)
            log_warn "Invalid selection '$time_choice', using default 1 hour"
            RESULT_DURATION=3600
            ;;
    esac

    printf "${C_PASS}>>> Selected duration: %s${C_RESET}\n" "$(seconds_to_format $RESULT_DURATION)"
}

# Worker数入力(ワーカー スウ ニュウリョク) - Worker count → sets RESULT_WORKERS
input_workers() {
    local name="$1"
    local default="$2"
    local min="${3:-1}"
    local max="${4:-16}"

    printf "\n${C_MENU}Configure ${name}:${C_RESET}\n"
    printf "  Range: %d - %d (default: %d)\n" "$min" "$max" "$default"
    printf "${C_INPUT}Enter ${name} count [default %d]: ${C_RESET}" "$default"

    local workers=""
    read -r workers
    workers="${workers:-$default}"

    if ! [[ "$workers" =~ ^[0-9]+$ ]] || [[ $workers -lt $min ]] || [[ $workers -gt $max ]]; then
        log_warn "Invalid input '$workers', using default $default"
        workers=$default
    fi

    RESULT_WORKERS=$workers
    printf "${C_PASS}>>> Selected: %d workers${C_RESET}\n" "$workers"
}

# メモリ%入力(メモリ パーセント ニュウリョク) - Memory % → sets RESULT_PERCENT
input_memory_percent() {
    printf "\n${C_MENU}Configure Memory Percentage:${C_RESET}\n"
    printf "  Range: 10%% - 90%% (default: 80)\n"
    printf "${C_INPUT}Enter memory percentage [default 80]: ${C_RESET}"

    local percent=""
    read -r percent
    percent="${percent:-80}"

    if ! [[ "$percent" =~ ^[0-9]+$ ]] || [[ $percent -lt 10 ]] || [[ $percent -gt 90 ]]; then
        log_warn "Invalid input '$percent', using default 80"
        percent=80
    fi

    RESULT_PERCENT=$percent
    printf "${C_PASS}>>> Selected: %d%% memory${C_RESET}\n" "$percent"
}

# 確認入力(カクニン ニュウリョク) - Confirm → sets RESULT_CONFIRM
input_confirm() {
    local prompt="$1"

    printf "\n${C_INPUT}%s (yes/no, default yes): ${C_RESET}" "$prompt"
    local confirm=""
    read -r confirm
    confirm="${confirm:-yes}"

    case "$confirm" in
        yes|YES|y|Y) RESULT_CONFIRM="yes" ;;
        *) RESULT_CONFIRM="no" ;;
    esac
}

# ============================================================================
# PART 7: テスト概要表示(テスト ガイヨウ ヒョウジ) - Show test summary
# ============================================================================

show_test_summary() {
    local test_name="$1"
    local duration="$2"
    shift 2

    log_title "Step 3: Test Configuration Summary"

    printf "${C_INFO}Test Name:${C_RESET} %s\n" "$test_name"
    printf "${C_INFO}Duration:${C_RESET}  %s (%d seconds)\n" "$(seconds_to_format $duration)" "$duration"
    printf "\n"

    printf "${C_INFO}Parameters:${C_RESET}\n"
    while [[ $# -gt 0 ]]; do
        printf "  - %s\n" "$1"
        shift
    done

    show_system_stats

    printf "${C_WARN}WARNING: Test will use significant system resources for %s${C_RESET}\n" \
        "$(seconds_to_format $duration)"
}

# ============================================================================
# PART 8: 進捗バー(シンチョク バー) - Progress bar
# ============================================================================

show_progress_bar() {
    local current=$1
    local total=$2
    local width=40

    [[ $total -le 0 ]] && total=1
    [[ $current -gt $total ]] && current=$total

    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))

    [[ $filled -lt 0 ]] && filled=0
    [[ $empty -lt 0 ]] && empty=0

    # バー文字列構築(バー モジレツ コウチク) - Build bar string
    local bar=""
    local i
    for ((i=0; i<filled; i++)); do bar="${bar}#"; done
    for ((i=0; i<empty; i++)); do bar="${bar}-"; done

    printf "\r${C_PASS}[%s]${C_RESET} %3d%%  %s / %s  " \
        "$bar" "$percent" \
        "$(seconds_to_format $current)" \
        "$(seconds_to_format $total)"
}

# ============================================================================
# PART 9: 監視関数(カンシ カンスウ) - Monitoring function
# ============================================================================

run_monitoring() {
    local duration=$1
    local stress_pid=$2
    local monitor_file="${RUN_DIR}/monitor-$$.log"
    local start_time
    start_time=$(date +%s)
    local elapsed=0

    log_info "Starting real-time monitoring..."
    printf "\n"

    # 監視ループ(カンシ ループ) - Monitoring loop
    while [[ $elapsed -lt $duration ]]; do
        # プロセスチェック(プロセス チェック) - Check if process still alive
        if ! kill -0 "$stress_pid" 2>/dev/null; then
            printf "\n${C_WARN}stress-ng process ended early${C_RESET}\n"
            break
        fi

        show_progress_bar "$elapsed" "$duration"

        # 30秒ごと詳細ログ(30ビョウ ゴト ショウサイ ログ) - Detailed log every 30s
        if [[ $((elapsed % 30)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
            local cpu mem
            cpu=$(top -bn1 2>/dev/null | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{printf "%.1f", 100 - $1}')
            mem=$(free | grep Mem | awk '{printf "%.1f", 100 * $3 / $2}')
            printf "\n${C_INFO}[%s]${C_RESET} CPU: %s%% | Memory: %s%%\n" \
                "$(date '+%H:%M:%S')" "$cpu" "$mem" | tee -a "$monitor_file"
        fi

        sleep 5
        elapsed=$(($(date +%s) - start_time))
    done

    show_progress_bar "$duration" "$duration"
    printf "\n${C_PASS}Monitoring complete${C_RESET}\n"
}

# ============================================================================
# PART 10: ストレステスト実行(ストレステスト ジッコウ) - Execute stress test
# ============================================================================

run_stress_test() {
    local test_name="$1"
    local duration="$2"
    local stress_cmd="$3"

    local start_time session_id
    start_time=$(date '+%Y-%m-%d %H:%M:%S')
    session_id="stress-$(date +%Y%m%d_%H%M%S)"

    log_title "Step 4: Running Stress Test"

    printf "${C_PASS}Test Name:${C_RESET}  %s\n" "$test_name"
    printf "${C_PASS}Duration:${C_RESET}   %s\n" "$(seconds_to_format $duration)"
    printf "${C_PASS}Start Time:${C_RESET} %s\n\n" "$start_time"

    log_info "Command: $stress_cmd --timeout ${duration}s"
    printf "\n"

    # バックグラウンド実行(バックグラウンド ジッコウ) - Run in background
    eval "$stress_cmd --timeout ${duration}s --verbose" > "${RUN_DIR}/stress-$$.log" 2>&1 &
    local stress_pid=$!

    log_pass "OK: stress-ng started (PID: $stress_pid)"
    printf "\n"

    # 監視開始(カンシ カイシ) - Start monitoring
    run_monitoring "$duration" "$stress_pid"

    # プロセス終了待ち(プロセス シュウリョウ マチ) - Wait for process
    wait $stress_pid 2>/dev/null || true

    log_pass "OK: Stress test completed"

    # レポート生成(レポート セイセイ) - Generate report
    generate_test_report "$session_id" "$test_name" "$duration" "$start_time"
}

# レポート生成(レポート セイセイ) - Generate test report
generate_test_report() {
    local session_id="$1"
    local test_name="$2"
    local duration="$3"
    local start_time="$4"
    local end_time
    end_time=$(date '+%Y-%m-%d %H:%M:%S')

    log_info "Generating report..."

    local report_file="${REPORT_DIR}/stress-report-${session_id}.txt"

    cat > "$report_file" << EOF
========== Stress Test Report ==========
Session ID:   $session_id
Test Name:    $test_name
Start Time:   $start_time
End Time:     $end_time
Duration:     $(seconds_to_format $duration) ($duration sec)

System Info:
  Hostname:   $(hostname)
  OS:         $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
  Kernel:     $(uname -r)
  CPU Cores:  $(nproc)
  Memory:     $(free -h | grep Mem | awk '{print $2}')

Report Time:  $(date '+%Y-%m-%d %H:%M:%S')
========================================
EOF

    log_pass "OK: Report saved to $report_file"
}

# ============================================================================
# PART 11: テスト関数(テスト カンスウ) - Test functions
#          重要(ジュウヨウ): $()を使わない!グローバル変数を使う!
#          IMPORTANT: Do NOT use $() ! Use global variables!
# ============================================================================

# CPUストレステスト(CPU ストレステスト) - CPU stress test
test_cpu_stress() {
    log_info "Starting CPU stress test configuration"

    # ステップ1: 時間設定(ステップ 1: ジカン セッテイ) - Step 1: Time
    input_test_time "CPU Stress Test"
    local duration=$RESULT_DURATION

    # ステップ2: パラメータ設定(ステップ 2: パラメータ セッテイ) - Step 2: Params
    log_title "Step 2: Parameter Configuration"
    input_workers "CPU Workers" 2 1 16
    local cpu_w=$RESULT_WORKERS

    # ステップ3: 確認(ステップ 3: カクニン) - Step 3: Confirm
    show_test_summary "CPU Stress Test" "$duration" \
        "CPU Workers: $cpu_w" \
        "CPU Method:  all"

    input_confirm "Confirm execution?"
    if [[ "$RESULT_CONFIRM" != "yes" ]]; then
        log_info "Test cancelled by user"
        return
    fi

    # ステップ4: 実行(ステップ 4: ジッコウ) - Step 4: Execute
    run_stress_test "CPU Stress Test" "$duration" \
        "stress-ng --cpu $cpu_w --cpu-method all"
}

# メモリストレステスト(メモリ ストレステスト) - Memory stress test
test_memory_stress() {
    log_info "Starting Memory stress test configuration"

    input_test_time "Memory Stress Test"
    local duration=$RESULT_DURATION

    log_title "Step 2: Parameter Configuration"
    input_workers "Memory Workers" 2 1 16
    local mem_w=$RESULT_WORKERS

    input_memory_percent
    local mem_p=$RESULT_PERCENT

    show_test_summary "Memory Stress Test" "$duration" \
        "Memory Workers: $mem_w" \
        "Memory Percent: ${mem_p}%"

    input_confirm "Confirm execution?"
    if [[ "$RESULT_CONFIRM" != "yes" ]]; then
        log_info "Test cancelled by user"
        return
    fi

    run_stress_test "Memory Stress Test" "$duration" \
        "stress-ng --vm $mem_w --vm-bytes ${mem_p}%"
}

# I/Oストレステスト(I/O ストレステスト) - I/O stress test
test_io_stress() {
    log_info "Starting I/O stress test configuration"

    input_test_time "I/O Stress Test"
    local duration=$RESULT_DURATION

    log_title "Step 2: Parameter Configuration"
    input_workers "I/O Workers" 4 1 16
    local io_w=$RESULT_WORKERS

    show_test_summary "I/O Stress Test" "$duration" \
        "I/O Workers: $io_w"

    input_confirm "Confirm execution?"
    if [[ "$RESULT_CONFIRM" != "yes" ]]; then
        log_info "Test cancelled by user"
        return
    fi

    run_stress_test "I/O Stress Test" "$duration" \
        "stress-ng --io $io_w"
}

# ネットワークストレステスト(ネットワーク ストレステスト) - Network stress test
test_network_stress() {
    log_info "Starting Network stress test configuration"

    input_test_time "Network Stress Test"
    local duration=$RESULT_DURATION

    log_title "Step 2: Parameter Configuration"
    input_workers "Network Workers" 1 1 16
    local net_w=$RESULT_WORKERS

    show_test_summary "Network Stress Test" "$duration" \
        "Network Workers: $net_w"

    input_confirm "Confirm execution?"
    if [[ "$RESULT_CONFIRM" != "yes" ]]; then
        log_info "Test cancelled by user"
        return
    fi

    run_stress_test "Network Stress Test" "$duration" \
        "stress-ng --udp $net_w"
}

# 組み合わせストレステスト(クミアワセ ストレステスト) - Combined stress test
test_combined_stress() {
    log_info "Starting Combined stress test configuration"

    input_test_time "Combined Stress Test"
    local duration=$RESULT_DURATION

    log_title "Step 2: Parameter Configuration"
    input_workers "CPU Workers" 2 1 16
    local cpu_w=$RESULT_WORKERS

    input_workers "Memory Workers" 2 1 16
    local mem_w=$RESULT_WORKERS

    input_workers "I/O Workers" 4 1 16
    local io_w=$RESULT_WORKERS

    input_workers "Network Workers" 1 1 16
    local net_w=$RESULT_WORKERS

    input_memory_percent
    local mem_p=$RESULT_PERCENT

    show_test_summary "Combined Stress Test" "$duration" \
        "CPU Workers:     $cpu_w" \
        "Memory Workers:  $mem_w" \
        "Memory Percent:  ${mem_p}%" \
        "I/O Workers:     $io_w" \
        "Network Workers: $net_w"

    input_confirm "Confirm execution?"
    if [[ "$RESULT_CONFIRM" != "yes" ]]; then
        log_info "Test cancelled by user"
        return
    fi

    # コマンド構築(コマンド コウチク) - Build stress command
    local stress_cmd="stress-ng"
    stress_cmd="$stress_cmd --cpu $cpu_w --cpu-method all"
    stress_cmd="$stress_cmd --vm $mem_w --vm-bytes ${mem_p}%"
    stress_cmd="$stress_cmd --io $io_w"
    stress_cmd="$stress_cmd --udp $net_w"

    run_stress_test "Combined Stress Test" "$duration" "$stress_cmd"
}

# ============================================================================
# PART 12: メインメニュー(メイン メニュー) - Main menu
# ============================================================================

show_main_menu() {
    clear
    printf "${C_TITLE}========== Stress Workload Generator v${SCRIPT_VERSION} ==========${C_RESET}\n"
    printf "${C_TITLE}     Red Hat 9.6 - VMware ESXi 9.0 Compatible${C_RESET}\n"
    printf "\n"

    show_system_stats

    printf "${C_MENU}Stress Test Modes (interactive time config):${C_RESET}\n"
    printf "  1) CPU Stress Test\n"
    printf "  2) Memory Stress Test\n"
    printf "  3) I/O Stress Test\n"
    printf "  4) Network Stress Test\n"
    printf "  5) Combined Stress Test (all-in-one)\n"
    printf "\n"

    printf "${C_MENU}Management Tools:${C_RESET}\n"
    printf "  6) Show system resources\n"
    printf "  7) Show test history\n"
    printf "  8) Clean log files\n"
    printf "  9) Stop all running tests\n"
    printf "\n"

    printf "${C_MENU}System:${C_RESET}\n"
    printf "  0) Exit\n"
    printf "\n"

    printf "${C_INPUT}Select option [0-9]: ${C_RESET}"
}

# ============================================================================
# PART 13: 管理ツール(カンリ ツール) - Management tools
# ============================================================================

show_system_resources() {
    log_title "System Resources"

    printf "\nCPU Info:\n"
    printf "  Cores: %d\n" "$(nproc)"
    lscpu 2>/dev/null | grep "Model name" | head -1 || printf "  Model: N/A\n"

    printf "\nMemory Info:\n"
    free -h

    printf "\nDisk Info:\n"
    df -h /

    printf "\nLoad Average:\n"
    uptime

    printf "\n${C_INPUT}Press Enter to return to menu...${C_RESET}"
    local dummy=""
    read -r dummy
}

show_test_history() {
    log_title "Test History"

    if [[ -d "$REPORT_DIR" ]] && [[ -n "$(ls -A "$REPORT_DIR" 2>/dev/null)" ]]; then
        printf "\nRecent reports:\n"
        ls -lht "$REPORT_DIR"/* 2>/dev/null | head -10
    else
        printf "\nNo test records found\n"
    fi

    printf "\n${C_INPUT}Press Enter to return to menu...${C_RESET}"
    local dummy=""
    read -r dummy
}

cleanup_logs() {
    log_title "Clean Log Files"

    printf "${C_WARN}WARNING: Delete all log files? (yes/no, default no): ${C_RESET}"
    local confirm=""
    read -r confirm
    confirm="${confirm:-no}"

    if [[ "$confirm" == "yes" ]]; then
        rm -rf "$RUN_DIR"/* 2>/dev/null
        rm -f "$LOG_DIR"/stress.log 2>/dev/null
        log_pass "OK: Logs cleaned"
    else
        log_info "Cancelled"
    fi

    printf "\n${C_INPUT}Press Enter to return to menu...${C_RESET}"
    local dummy=""
    read -r dummy
}

stop_all_tests() {
    log_title "Stop All Tests"

    if pkill -f "stress-ng" 2>/dev/null; then
        log_pass "OK: Stopped all stress-ng processes"
    else
        log_info "No running stress-ng processes"
    fi

    printf "\n${C_INPUT}Press Enter to return to menu...${C_RESET}"
    local dummy=""
    read -r dummy
}

# ============================================================================
# PART 14: メインループ(メイン ループ) - Main loop
# ============================================================================

main() {
    init_environment

    while true; do
        show_main_menu

        local choice=""
        read -r choice
        choice="${choice:-0}"

        case "$choice" in
            1) test_cpu_stress ;;
            2) test_memory_stress ;;
            3) test_io_stress ;;
            4) test_network_stress ;;
            5) test_combined_stress ;;
            6) show_system_resources ;;
            7) show_test_history ;;
            8) cleanup_logs ;;
            9) stop_all_tests ;;
            0)
                log_title "Exit"
                log_info "Thank you for using Stress Workload Generator v${SCRIPT_VERSION}"
                exit 0
                ;;
            *)
                log_error "Invalid selection: '$choice'"
                sleep 1
                ;;
        esac

        # メニュー戻る前少し待機(メニュー モドル マエ スコシ タイキ)
        # Brief pause before returning to menu
        sleep 1
    done
}

# ============================================================================
# 実行(ジッコウ) - Execute
# ============================================================================

main "$@"