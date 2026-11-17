# Pinagem proposta — DE0-CV

Confira a montagem externa antes de programar. Todas as entradas/saidas usam 3,3 V.
A numeracao D do GPIO e o indice de sinal, nao o numero fisico no conector de 40 pinos.

São 12 LEDs de uma única cor, um por tecla, nas saídas `piano_leds_n[11:0]`
(GPIO_0 D12–D23). Nível 0 acende, nível 1 apaga. O GPIO_1 fica livre.

| Porta | Pino FPGA |
| --- | --- |
| `CLOCK_50` | `M9` |
| `KEY[0]` | `U7` |
| `KEY[1]` | `W9` |
| `SW0` | `U13` |
| `LEDR[0]` | `AA2` |
| `LEDR[1]` | `AA1` |
| `LEDR[2]` | `W2` |
| `LEDR[3]` | `Y3` |
| `LEDR[4]` | `N2` |
| `LEDR[5]` | `N1` |
| `LEDR[6]` | `U2` |
| `LEDR[7]` | `U1` |
| `LEDR[8]` | `L2` |
| `LEDR[9]` | `L1` |
| `piano_keys[0]` | `N16` |
| `piano_leds_n[0]` | `R21` |
| `piano_keys[1]` | `B16` |
| `piano_leds_n[1]` | `T22` |
| `piano_keys[2]` | `M16` |
| `piano_leds_n[2]` | `N20` |
| `piano_keys[3]` | `C16` |
| `piano_leds_n[3]` | `N19` |
| `piano_keys[4]` | `D17` |
| `piano_leds_n[4]` | `M22` |
| `piano_keys[5]` | `K20` |
| `piano_leds_n[5]` | `P19` |
| `piano_keys[6]` | `K21` |
| `piano_leds_n[6]` | `L22` |
| `piano_keys[7]` | `K22` |
| `piano_leds_n[7]` | `P17` |
| `piano_keys[8]` | `M20` |
| `piano_leds_n[8]` | `P16` |
| `piano_keys[9]` | `M21` |
| `piano_leds_n[9]` | `M18` |
| `piano_keys[10]` | `N21` |
| `piano_leds_n[10]` | `L18` |
| `piano_keys[11]` | `R22` |
| `piano_leds_n[11]` | `L17` |
| `esp_txd` | `L19` |
| `pc_txd` | `K17` |
| `audio_pwm` | `K19` |
| `SW1` (debug C4) | `V13` |
