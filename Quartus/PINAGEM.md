# Pinagem e posições físicas — SensoPiano / DE0-CV

Versão com **12 LEDs de uma única cor**, um por tecla. Projeto Quartus:
`SensoPiano_DE0_CV`, dispositivo `5CEBA4F23C7`, topo `sensopiano_de0_cv`.

A coluna **Pino FPGA** é a esfera do encapsulamento usada no QSF; a coluna
**Pino físico JP1** é o contato do conector de 40 pinos onde o fio é ligado.
`D12` é o índice do sinal GPIO, e não o contato físico 12.
Os números físicos foram conferidos visualmente na figura 3-12 do manual
Terasic; os sinais foram cruzados com as atribuições do QSF do projeto.

## Teclas e LEDs externos

Todos os sinais abaixo estão no **JP1 / GPIO_0**, com lógica de 3,3 V.
Tecla pressionada = nível 1; LED aceso = nível 0.

| Nota | Entrada da tecla | GPIO_0 | Pino físico JP1 | Pino FPGA | Saída do LED | GPIO_0 | Pino físico JP1 | Pino FPGA |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C / Dó | `piano_keys[0]` | D0 | 1 | N16 | `piano_leds_n[0]` | D12 | 15 | R21 |
| C# / Dó♯ | `piano_keys[1]` | D1 | 2 | B16 | `piano_leds_n[1]` | D13 | 16 | T22 |
| D / Ré | `piano_keys[2]` | D2 | 3 | M16 | `piano_leds_n[2]` | D14 | 17 | N20 |
| D# / Ré♯ | `piano_keys[3]` | D3 | 4 | C16 | `piano_leds_n[3]` | D15 | 18 | N19 |
| E / Mi | `piano_keys[4]` | D4 | 5 | D17 | `piano_leds_n[4]` | D16 | 19 | M22 |
| F / Fá | `piano_keys[5]` | D5 | 6 | K20 | `piano_leds_n[5]` | D17 | 20 | P19 |
| F# / Fá♯ | `piano_keys[6]` | D6 | 7 | K21 | `piano_leds_n[6]` | D18 | 21 | L22 |
| G / Sol | `piano_keys[7]` | D7 | 8 | K22 | `piano_leds_n[7]` | D19 | 22 | P17 |
| G# / Sol♯ | `piano_keys[8]` | D8 | 9 | M20 | `piano_leds_n[8]` | D20 | 23 | P16 |
| A / Lá | `piano_keys[9]` | D9 | 10 | M21 | `piano_leds_n[9]` | D21 | 24 | M18 |
| A# / Lá♯ | `piano_keys[10]` | D10 | 13 | N21 | `piano_leds_n[10]` | D22 | 25 | L18 |
| B / Si | `piano_keys[11]` | D11 | 14 | R22 | `piano_leds_n[11]` | D23 | 26 | L17 |

No modo Livre, os LEDs acompanham as teclas pressionadas. No modo Aprender,
indicam a nota guia. Os índices de tecla representam as 12 classes de nota;
a oitava do áudio é definida pelo modo/ROM, não por sensores adicionais.

## ESP32, áudio e alimentação

| Função | Porta | GPIO_0 | Pino físico JP1 | Pino FPGA | Destino |
| --- | --- | --- | --- | --- | --- |
| Notas | `esp_txd` | D24 | 27 | L19 | ESP32 GPIO16 / RX UART1 |
| Métricas e tempos | `pc_txd` | D25 | 28 | K17 | ESP32 GPIO17 / RX UART2 |
| Áudio 1 bit | `audio_pwm` | D26 | 31 | K19 | Entrada de circuito de áudio apropriado |
| Referência comum | GND | — | 12 ou 30 | — | GND do ESP32 e da montagem |
| Alimentação das teclas/LEDs | 3,3 V | — | 29 | — | Barramento 3,3 V da protoboard |

UARTs: **115200 baud, 8N1, TTL 3,3 V**. Mantenha os dois TX separados.
O ESP32 deve ser alimentado por seu USB; ligue o GND comum e os dois sinais
UART. Não faça uma segunda ligação de alimentação entre as duas placas.

## Controles já existentes na DE0-CV

| Função | Porta | Componente | Pino FPGA | Uso |
| --- | --- | --- | --- | --- |
| Clock | `CLOCK_50` | Oscilador da placa | M9 | 50 MHz; sem fio externo |
| Reset | `KEY[0]` | KEY0 | U7 | Pressionar = nível 0; reinicia |
| Iniciar atividade | `KEY[1]` | KEY1 | W9 | Pressionar = nível 0; inicia Aprender |
| Modo | `SW0` | SW0 | U13 | 0 Livre; 1 Aprender |
| Debug | `SW1` | SW1 | V13 | 0 normal; 1 C4 fixo |

## LEDs da própria placa

| Porta | Pino FPGA | Indicação | Ligação |
| --- | --- | --- | --- |
| `LEDR[0]` | AA2 | C / Dó | Nível 1 acende; já instalado na placa |
| `LEDR[1]` | AA1 | C# / Dó♯ | Nível 1 acende; já instalado na placa |
| `LEDR[2]` | W2 | D / Ré | Nível 1 acende; já instalado na placa |
| `LEDR[3]` | Y3 | D# / Ré♯ | Nível 1 acende; já instalado na placa |
| `LEDR[4]` | N2 | E / Mi | Nível 1 acende; já instalado na placa |
| `LEDR[5]` | N1 | F / Fá | Nível 1 acende; já instalado na placa |
| `LEDR[6]` | U2 | F# / Fá♯ | Nível 1 acende; já instalado na placa |
| `LEDR[7]` | U1 | G / Sol | Nível 1 acende; já instalado na placa |
| `LEDR[8]` | L2 | G# / Sol♯ | Nível 1 acende; já instalado na placa |
| `LEDR[9]` | L1 | A / Lá | Nível 1 acende; já instalado na placa |

## Mapa físico completo do JP1

Vista de referência do manual: contato **1 no canto superior esquerdo**,
ímpares à esquerda e pares à direita. Localize primeiro a marca de pino 1
na placa/conector; girar a placa ou olhar o verso espelha a disposição.
Os contatos 11/12 e 29/30 são alimentação/GND e interrompem a sequência GPIO.

| JP1 ímpar | Sinal | FPGA / função | JP1 par | Sinal | FPGA / função |
| --- | --- | --- | --- | --- | --- |
| 1 | D0 | N16 | 2 | D1 | B16 |
| 3 | D2 | M16 | 4 | D3 | C16 |
| 5 | D4 | D17 | 6 | D5 | K20 |
| 7 | D6 | K21 | 8 | D7 | K22 |
| 9 | D8 | M20 | 10 | D9 | M21 |
| 11 | 5 V | NÃO USAR neste circuito | 12 | GND | Terra comum |
| 13 | D10 | N21 | 14 | D11 | R22 |
| 15 | D12 | R21 | 16 | D13 | T22 |
| 17 | D14 | N20 | 18 | D15 | N19 |
| 19 | D16 | M22 | 20 | D17 | P19 |
| 21 | D18 | L22 | 22 | D19 | P17 |
| 23 | D20 | P16 | 24 | D21 | M18 |
| 25 | D22 | L18 | 26 | D23 | L17 |
| 27 | D24 | L19 | 28 | D25 | K17 |
| 29 | 3,3 V | Teclas/LEDs | 30 | GND | Terra comum |
| 31 | D26 | K19 | 32 | D27 | P18 |
| 33 | D28 | R15 | 34 | D29 | R17 |
| 35 | D30 | R16 | 36 | D31 | T20 |
| 37 | D32 | T19 | 38 | D33 | T18 |
| 39 | D34 | T17 | 40 | D35 | T15 |

GPIO_0 D27–D35 e todo o GPIO_1 / JP2 ficam disponíveis. Não há saídas RGB.
A montagem detalhada, componentes e sequência de ligação estão em
[MONTAGEM.md](MONTAGEM.md).

Fonte: [Terasic DE0-CV User Manual, figura 3-12 e tabela 3-7, páginas 28–29](https://www.engr.colostate.edu/ECE102/Spring22/LABS/Lab01/de0-cv-user-manual.pdf#page=29).
