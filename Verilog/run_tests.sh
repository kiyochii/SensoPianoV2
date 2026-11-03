#!/usr/bin/env bash
set -euo pipefail

# Os caminhos de logs sao relativos ao diretorio de onde o script foi chamado.
if [[ -n ${TEST_LOG_DIR:-} ]]; then
    mkdir -p "$TEST_LOG_DIR"
    TEST_LOG_DIR=$(cd "$TEST_LOG_DIR" && pwd)
fi
cd "$(dirname "$0")"
iverilog_bin=${IVERILOG:-iverilog}
vvp_bin=${VVP:-vvp}
# O RTL nao usa atrasos; a unidade de tempo vem de cada testbench.
compile_options=(-g2012 -Wall -Wno-timescale)
# Exibe $display imediatamente mesmo quando a saida passa pelo tee.
runtime_options=(-i)
if [[ -n ${IVL_BASE:-} ]]; then
    compile_options+=(-B "$IVL_BASE")
    runtime_options+=(-M "$IVL_BASE")
fi

tests=(tb_debouncer tb_key_register tb_music_rom tb_fd tb_uc
       tb_mode_controller tb_uart_key_sender tb_uart_tx
       tb_uart_metrics_sender tb_metrics_uart tb_top tb_audio_output)
if [[ ${1:-} == --list ]]; then
    printf '%s\n' "${tests[@]}"
    exit 0
fi
if [[ ${1:-} == --help ]]; then
    printf 'Uso: bash run_tests.sh [nome_do_testbench ...]\n'
    printf 'Sem argumentos, executa toda a suite; --list lista os testes.\n'
    printf 'Variaveis: IVERILOG, VVP, IVL_BASE e TEST_LOG_DIR.\n'
    exit 0
fi
selected=("${tests[@]}")
if (( $# )); then
    selected=("$@")
fi
for name in "${selected[@]}"; do
    found=0
    for known in "${tests[@]}"; do
        if [[ $name == "$known" ]]; then found=1; break; fi
    done
    if (( ! found )); then
        printf 'Testbench desconhecida: %s (use --list)\n' "$name" >&2
        exit 2
    fi
done
for bin in "$iverilog_bin" "$vvp_bin"; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        printf 'Executavel nao encontrado: %s. Instale Icarus Verilog ou configure IVERILOG/VVP.\n' "$bin" >&2
        exit 127
    fi
done

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/sensopiano-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
log_dir=${TEST_LOG_DIR:-$test_dir}
sources=(top.v fd.v uc.v mode_controller.v
         modules/uart/uart_tx.v modules/uart/uart_key_sender.v
         modules/uart/uart_metrics_sender.v
         modules/utils/debounce.v modules/utils/key_register.v modules/utils/music_rom.v)
passed=0
failed=0
for test_name in "${selected[@]}"; do
    case "$test_name" in
        tb_debouncer) test_source=modules/utils/tb/tb_debounce.v ;;
        tb_key_register|tb_music_rom) test_source=modules/utils/tb/$test_name.v ;;
        tb_uart_key_sender|tb_uart_tx) test_source=modules/uart/tb/$test_name.v ;;
        tb_uart_metrics_sender|tb_metrics_uart) test_source=tb_metrics_uart.v ;;
        *) test_source=$test_name.v ;;
    esac
    printf '\nRUN: %s\n' "$test_name"
    if "$iverilog_bin" "${compile_options[@]}" -s "$test_name" \
        -o "$test_dir/$test_name.vvp" "$test_source" "${sources[@]}" \
        >"$log_dir/$test_name.compile.log" 2>&1; then
        cat "$log_dir/$test_name.compile.log"
        if "$vvp_bin" "${runtime_options[@]}" "$test_dir/$test_name.vvp" \
            2>&1 | tee "$log_dir/$test_name.log"; then
            if grep -q '^PASS:' "$log_dir/$test_name.log"; then
                passed=$((passed + 1))
                continue
            fi
            printf 'FAIL: %s terminou sem marcador PASS\n' "$test_name"
        fi
    else
        cat "$log_dir/$test_name.compile.log"
    fi
    printf 'FAIL: %s\n' "$test_name"
    failed=$((failed + 1))
done
printf '\nRESULTADO: %d aprovados, %d reprovados, %d total\n' \
    "$passed" "$failed" "${#selected[@]}" | tee "$log_dir/summary.log"
(( failed == 0 ))
