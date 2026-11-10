create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_clock_uncertainty
# Entradas humanas assincronas, sincronizadas no wrapper/debouncers.
set_false_path -from [get_ports {KEY[*] SW0 SW1 piano_keys[*]}]
# Interfaces sem clock externo: LEDs, audio 1-bit e UART assincrona.
set_false_path -to [get_ports {LEDR[*] piano_leds_n[*] rgb_r_n[*] rgb_g_n[*] rgb_b_n[*] esp_txd pc_txd audio_pwm}]
