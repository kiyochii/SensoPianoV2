#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
iverilog_bin=${IVERILOG:-iverilog}
vvp_bin=${VVP:-vvp}
compile_options=(-g2012 -Wall)
runtime_options=()
if [[ -n ${IVL_BASE:-} ]]; then
    compile_options+=(-B "$IVL_BASE")
    runtime_options+=(-M "$IVL_BASE")
fi
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/sensopiano-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

sources=(top.v fd.v uc.v mode_controller.v
         modules/uart/uart_tx.v modules/uart/uart_key_sender.v
         modules/uart/uart_metrics_sender.v
         modules/utils/debounce.v modules/utils/key_register.v)

for test_name in tb_uart_metrics_sender tb_metrics_uart tb_top; do
    test_source=tb_metrics_uart.v
    if [[ $test_name == tb_top ]]; then test_source=tb_top.v; fi
    "$iverilog_bin" "${compile_options[@]}" -s "$test_name" \
        -o "$test_dir/$test_name.vvp" "${sources[@]}" "$test_source"
    "$vvp_bin" "${runtime_options[@]}" "$test_dir/$test_name.vvp"
done
