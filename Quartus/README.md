# SensoPiano — DE0-CV

Abra `SensoPiano_DE0_CV.qpf` no Quartus Prime Lite/Standard com suporte
instalado a Cyclone V. Mantenha as pastas `Quartus/` e `Verilog/` lado a lado.
O QSF inclui os dez fontes RTL, o wrapper da placa e a restricao de 50 MHz.
O dispositivo selecionado e **5CEBA4F23C7**, correspondente a DE0-CV.

## Controles e montagem proposta

- KEY0: reset (pressione e solte depois de programar).
- KEY1: iniciar modo Aprender.
- SW0: 0 = Livre; 1 = Aprender.
- GPIO_0 D0–D11: teclas C, C#, D, D#, E, F, F#, G, G#, A, A#, B.
  Entradas ativas altas: use pull-down externo e contato para 3,3 V.
- GPIO_0 D12–D23: 12 LEDs externos, ativos baixos.
- GPIO_0 D24: `esp_txd` -> ESP32 GPIO16 (notas).
- GPIO_0 D25: `pc_txd` -> ESP32 GPIO17 ou RX USB-UART (metricas).
- GPIO_0 D26: audio 1-bit, para entrada de circuito de audio apropriado.
- GPIO_1 D0–D11, D12–D23, D24–D35: R, G, B dos 12 LEDs RGB,
  respectivamente; saidas ativas baixas.
- LEDR0–LEDR9: primeiras dez indicacoes de tecla, com polaridade
  corrigida para os LEDs ativos altos da placa.

Esta pinagem externa e uma proposta; nao foi inferida da fiacao existente.
Os pinos FPGA individuais estao em [PINAGEM.md](PINAGEM.md).
Use GND comum, resistores/drivers adequados aos LEDs e nao conecte
alto-falante diretamente a um GPIO. Os pinos de alimentacao do conector
nao sao sinais GPIO. Confira sua orientacao no manual antes de ligar.

O wrapper acrescenta sincronizacao e debounce de 10 ms para as teclas e
start. O nucleo original permanece intacto. Portas de depuracao do nucleo
ficam internas, sem atribuicoes automaticas a pinos da placa.

## Compilar e criar o QAR

Na pasta `Quartus`, com Quartus no PATH:

```sh
quartus_sh --flow compile SensoPiano_DE0_CV
quartus_sh --archive SensoPiano_DE0_CV
```

A segunda linha gera `SensoPiano_DE0_CV.qar`. Pela interface, use
**Project > Archive Project**. Para programar a placa, use o `.sof`
gerado em `output_files/`, pelo Programmer/USB-Blaster.

Os arquivos QPF/QSF/SDC foram preparados sem Quartus instalado.
Nao ha `.qar` ou `.sof` gerado, nem validacao de fitting/timing ou ensaio
fisico. As excecoes SDC cobrem apenas portas externas assincronas; o
caminho interno continua restrito pelo clock de 20 ns.

Referencia de dispositivo, polaridades e pinos:
[Manual Terasic DE0-CV, tabelas 3-2 a 3-7](https://pages.hmc.edu/harris/class/e85/old/fall24/de0_manual.pdf).

## Debug de bancada — SW1

Ligue **SW1** para fixar **C4 (Do central, aproximadamente 261,63 Hz)**:

- Audio continuo no GPIO_0 D26.
- LED externo 0, LEDR0 e os tres canais RGB da nota 0 acesos juntos.
- Um byte `0x40` na UART de notas (`esp_txd`, GPIO_0 D24) a cada entrada
  no debug, em 115200 baud/8N1. Para reenviar, desligue e ligue SW1.
- SW0, KEY1 e teclas do piano sao ignorados enquanto SW1 estiver ligada.
- A UART de metricas fica em repouso; nao sao inventadas tentativas.

KEY0 continua sendo reset. Desligar SW1 reinicia o nucleo no modo selecionado
por SW0; no modo Aprender, pressione KEY1 para iniciar uma nova sessao.
A troca de modo reinicia os transmissores e pode interromper um frame em curso.
O debug utiliza divisor proprio para C4; o audio dos modos anteriores nao
foi alterado. SW1 possui debounce de 10 ms.

Teste do wrapper (a partir da raiz, com Icarus Verilog):

```sh
iverilog -g2012 -s tb_debug -o /tmp/sensopiano-debug.vvp \
  Quartus/tb_debug.v Quartus/sensopiano_de0_cv.v \
  Verilog/top.v Verilog/fd.v Verilog/uc.v Verilog/mode_controller.v \
  Verilog/modules/utils/*.v Verilog/modules/uart/*.v
vvp /tmp/sensopiano-debug.vvp
```
