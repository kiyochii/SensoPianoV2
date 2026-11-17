# SensoPiano — DE0-CV

Abra `SensoPiano_DE0_CV.qpf` no Quartus Prime Lite/Standard com suporte
instalado a Cyclone V. Mantenha as pastas `Quartus/` e `Verilog/` lado a lado.
O QSF inclui os onze fontes RTL, o wrapper da placa e a restricao de 50 MHz.
O dispositivo selecionado e **5CEBA4F23C7**, correspondente a DE0-CV.

## Controles e montagem proposta

- KEY0: reset (pressione e solte depois de programar).
- KEY1: iniciar modo Aprender.
- SW0: 0 = Livre; 1 = Aprender.
- GPIO_0 D0–D11: teclas C, C#, D, D#, E, F, F#, G, G#, A, A#, B.
  Entradas ativas altas: use pull-down externo e contato para 3,3 V.
- GPIO_0 D12–D23: 12 LEDs de uma única cor, um por tecla, ativos baixos.
  No modo Livre indicam as teclas pressionadas; em Aprender indicam a nota guia.
- GPIO_0 D24: `esp_txd` -> ESP32 GPIO16 (notas).
- GPIO_0 D25: `pc_txd` -> ESP32 GPIO17 ou RX USB-UART (metricas).
- GPIO_0 D26: audio 1-bit, para entrada de circuito de audio apropriado.
- GPIO_1: livre; não é necessário para os LEDs de uma cor.
- LEDR0–LEDR9: primeiras dez indicacoes de tecla, com polaridade
  corrigida para os LEDs ativos altos da placa.

Esta pinagem externa e uma proposta; nao foi inferida da fiacao existente.
Os pinos FPGA individuais estao em [PINAGEM.md](PINAGEM.md).
As ligações de contatos, resistores, LEDs e UARTs estão na
[tabela de montagem física](MONTAGEM.md). A versão para impressão está em
[PDF](../Entregas/SensoPiano_pinagem_e_montagem.pdf), e a planilha em
[CSV](../Entregas/SensoPiano_pinagem.csv).
Use GND comum, resistores/drivers adequados aos LEDs e nao conecte
alto-falante diretamente a um GPIO. Os pinos de alimentacao do conector
nao sao sinais GPIO. Confira sua orientacao no manual antes de ligar.

O wrapper acrescenta sincronizacao e debounce de 10 ms para as teclas e
start. O núcleo transmite também os eventos físicos e tempos pelo `pc_txd`.
Portas de depuracao do nucleo
ficam internas, sem atribuicoes automaticas a pinos da placa.

## Compilar e criar o QAR

O arquivo pronto está em [Entregas/SensoPiano_DE0_CV.qar](../Entregas/SensoPiano_DE0_CV.qar).
Foi gerado pelo **Quartus Prime Lite 20.1.1 Build 720**, para a versão com
LEDs de uma única cor e telemetria temporal.

Para restaurar, use **Project > Restore Archived Project** e selecione uma
pasta vazia. Abra `Quartus/SensoPiano_DE0_CV.qpf` dentro da pasta restaurada.
O arquivo inclui fontes Verilog, QPF/QSF/SDC, tabelas e o `.sof` validado.
O firmware do ESP32 permanece no projeto `ESP32/fw` deste repositório.

Para recompilar e criar outro arquivo, na pasta `Quartus`, com Quartus no PATH:

```sh
quartus_sh --flow compile SensoPiano_DE0_CV
quartus_sh --archive -self_test SensoPiano_DE0_CV
```

A segunda linha gera `SensoPiano_DE0_CV.qar`. Pela interface, use
**Project > Archive Project**. Para programar a placa, use o `.sof`
gerado em `output_files/`, pelo Programmer/USB-Blaster.

A compilação completa foi concluída com **0 erros**; o timing interno atende
**50 MHz**, com pior folga de setup de **+5,436 ns**. As 42 atribuições de
pinos foram conferidas no relatório do Fitter. O `.sof` está em
[Entregas/SensoPiano_DE0_CV.sof](../Entregas/SensoPiano_DE0_CV.sof).
Os [resultados e avisos de compilação](../docs/testes/compilacao-quartus-2026-11-17.md)
detalham a validação. Não houve gravação nem ensaio físico nesta execução.
As exceções SDC cobrem as interfaces assíncronas externas; a análise de tempo
citada é do circuito interno sob o clock de 20 ns.

Referencia de dispositivo, polaridades e pinos:
[Manual Terasic DE0-CV, tabelas 3-2 a 3-7](https://pages.hmc.edu/harris/class/e85/old/fall24/de0_manual.pdf).

## Debug de bancada — SW1

Ligue **SW1** para fixar **C4 (Do central, aproximadamente 261,63 Hz)**:

- Audio continuo no GPIO_0 D26.
- LED externo 0 e LEDR0 acesos juntos.
- Um byte `0x40` na UART de notas (`esp_txd`, GPIO_0 D24) a cada entrada
  no debug, em 115200 baud/8N1. Para reenviar, desligue e ligue SW1.
- SW0, KEY1 e teclas do piano sao ignorados enquanto SW1 estiver ligada.
- A UART de métricas envia eventos físicos `T` e heartbeat. Não são geradas
  tentativas `M` no debug; a tecla fixa C aparece como entrada física simulada.

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
