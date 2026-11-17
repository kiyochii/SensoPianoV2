# Montagem física — SensoPiano / DE0-CV + ESP32

Esta montagem usa **12 contatos normalmente abertos e 12 LEDs de uma única
cor**. A referência de posições é o **JP1 / GPIO_0** da DE0-CV. O conector
JP2 / GPIO_1 fica livre. A [tabela de pinagem](PINAGEM.md) contém os números
físicos e os pinos da FPGA, inclusive o mapa completo do conector.

## Componentes e conexões

| Componente | Quantidade | Especificação / função |
| --- | --- | --- |
| DE0-CV | 1 | FPGA 5CEBA4F23C7; usar a alimentação própria da placa |
| ESP32 DevKit / WROOM-32 | 1 | GPIO16 e GPIO17 disponíveis; alimentação por USB próprio |
| Contato de tecla / botão | 12 | Normalmente aberto; fechamento ao pressionar |
| LED de uma cor | 12 | Indicador discreto, um por tecla |
| Resistor de pull-down | 12 | 10 kΩ, um entre cada entrada e GND |
| Resistor em série do LED | 12 | 1 kΩ como ponto de partida para LED indicador de baixa corrente |
| Protoboard / placa de montagem | Conforme a montagem | Distribuir 3,3 V e GND |
| Jumpers | Conforme a montagem | 12 sinais de tecla, 12 de LED, 2 UARTs e referências comuns |
| Circuito de áudio | Opcional | Entrada compatível com sinal lógico 3,3 V, para o áudio 1 bit |

O código do ESP32 está configurado para o WROOM-32 clássico. Outras variantes
podem usar GPIO16/17 para outra função e precisam de adaptação de pinagem.

## Alimentação e interfaces

| Origem | Pino físico | Destino | Como ligar |
| --- | --- | --- | --- |
| DE0-CV JP1 / 3,3 V | 29 | Barramento positivo das teclas e LEDs | Alimenta somente os componentes discretos desta montagem |
| DE0-CV JP1 / GND | 12 ou 30 | Barramento GND e GND do ESP32 | Referência comum obrigatória |
| DE0-CV `esp_txd` / D24 | 27 | ESP32 GPIO16 | RX das notas legadas |
| DE0-CV `pc_txd` / D25 | 28 | ESP32 GPIO17 | RX das métricas e eventos físicos com tempo |
| DE0-CV `audio_pwm` / D26 | 31 | Entrada do circuito de áudio | Opcional; manter desconectado se não houver circuito adequado |
| USB da DE0-CV | USB-Blaster | Computador | Programação da FPGA; não é a UART dos GPIOs |
| USB do ESP32 | USB do DevKit | Computador / fonte USB | Alimentação, gravação e diagnóstico do ESP32 |
| DE0-CV JP1 / 5 V | 11 | Sem conexão nesta montagem | Não usar para os sinais ou contatos das teclas |

As UARTs usam **115200 baud, 8N1, TTL 3,3 V**. Não junte os dois TX da FPGA;
cada um vai ao seu RX. Não conecte TX do ESP32 de volta à FPGA: o protocolo
atual é somente FPGA → ESP32. As placas usam suas alimentações próprias;
não interligue 5 V/VIN/3V3 entre elas quando estiverem alimentadas por USB.

## Uma tecla — repetir 12 vezes

```text
3,3 V (JP1-29) ─── contato normalmente aberto ───┬── entrada piano_keys[i]
                                               │
                                             10 kΩ
                                               │
GND (JP1-12 ou JP1-30) ──────────────────────────┘
```

Solta: o resistor mantém a entrada em 0. Pressionada: o contato aplica
3,3 V e a entrada vale 1. O firmware da FPGA filtra as teclas com debounce
de 10 ms. Se usar botão de quatro terminais, identifique os dois lados do
contato: dois terminais do mesmo lado podem já estar ligados internamente.

| Tecla | Entrada | GPIO_0 | Pino físico JP1 | Contato e resistor |
| --- | --- | --- | --- | --- |
| C / Dó | `piano_keys[0]` | D0 | 1 | Contato para 3,3 V; pull-down 10 kΩ para GND |
| C# / Dó♯ | `piano_keys[1]` | D1 | 2 | Igual |
| D / Ré | `piano_keys[2]` | D2 | 3 | Igual |
| D# / Ré♯ | `piano_keys[3]` | D3 | 4 | Igual |
| E / Mi | `piano_keys[4]` | D4 | 5 | Igual |
| F / Fá | `piano_keys[5]` | D5 | 6 | Igual |
| F# / Fá♯ | `piano_keys[6]` | D6 | 7 | Igual |
| G / Sol | `piano_keys[7]` | D7 | 8 | Igual |
| G# / Sol♯ | `piano_keys[8]` | D8 | 9 | Igual |
| A / Lá | `piano_keys[9]` | D9 | 10 | Igual |
| A# / Lá♯ | `piano_keys[10]` | D10 | 13 | Igual |
| B / Si | `piano_keys[11]` | D11 | 14 | Igual |

## Um LED — repetir 12 vezes

```text
3,3 V (JP1-29) ─── resistor 1 kΩ ─── ânodo LED ──>|── cátodo ─── piano_leds_n[i]
```

O LED é comandado pela saída em nível baixo: **0 acende, 1 apaga**.
O resistor é individual para cada LED. A cor é definida pelo componente,
sem canais RGB. Para o resistor de 1 kΩ, um LED com queda de 2,0 V conduz
aproximadamente `(3,3 - 2,0) / 1000 = 1,3 mA`; confira a queda e o brilho
no datasheet do LED escolhido antes de reduzir o resistor. LEDs de potência,
fitas e cargas maiores precisam de driver apropriado, não desta ligação direta.

| LED da tecla | Saída | GPIO_0 | Pino físico JP1 | Ligação |
| --- | --- | --- | --- | --- |
| C / Dó | `piano_leds_n[0]` | D12 | 15 | Cátodo no GPIO; ânodo ao resistor para 3,3 V |
| C# / Dó♯ | `piano_leds_n[1]` | D13 | 16 | Igual |
| D / Ré | `piano_leds_n[2]` | D14 | 17 | Igual |
| D# / Ré♯ | `piano_leds_n[3]` | D15 | 18 | Igual |
| E / Mi | `piano_leds_n[4]` | D16 | 19 | Igual |
| F / Fá | `piano_leds_n[5]` | D17 | 20 | Igual |
| F# / Fá♯ | `piano_leds_n[6]` | D18 | 21 | Igual |
| G / Sol | `piano_leds_n[7]` | D19 | 22 | Igual |
| G# / Sol♯ | `piano_leds_n[8]` | D20 | 23 | Igual |
| A / Lá | `piano_leds_n[9]` | D21 | 24 | Igual |
| A# / Lá♯ | `piano_leds_n[10]` | D22 | 25 | Igual |
| B / Si | `piano_leds_n[11]` | D23 | 26 | Igual |

No modo Livre, cada LED acompanha sua tecla. No modo Aprender, acende o LED
da nota guia; o erro mantém a nota esperada e o acerto avança a sequência.
A indicação se apaga ao concluir a música. A oitava continua sendo enviada
na UART e usada no áudio, mas não é diferenciada pela cor do LED.

## Áudio opcional

`audio_pwm` é um sinal digital de 1 bit, não uma saída analógica de linha.
Conecte JP1-31 somente à entrada compatível de um circuito projetado para
esse sinal, com GND comum. O filtro, acoplamento, ganho e alimentação dependem
do amplificador escolhido; não estão definidos pelo projeto atual.
Não ligue alto-falante, fone ou entrada de microfone diretamente ao GPIO.
A aquisição de notas e métricas funciona sem conectar o áudio.

## Ordem de montagem e conferência

1. Com as placas desligadas, localize o **JP1** e a marca do **pino 1**.
   Confira o [mapa de 40 pinos](PINAGEM.md#mapa-físico-completo-do-jp1).
2. Monte os barramentos 3,3 V e GND. Confira se o barramento da protoboard
   tem interrupção no meio. Use JP1-29 para 3,3 V e JP1-12/30 para GND.
3. Monte primeiro apenas a tecla e o LED C: entrada JP1-1 e saída JP1-15,
   com seus resistores individuais. Depois replique as outras 11 linhas.
4. Ligue GND da DE0-CV ao GND do ESP32; JP1-27 ao GPIO16; JP1-28 ao GPIO17.
5. Alimente as placas pelos caminhos próprios e grave os firmwares atuais.
   O `.qar` restaura o projeto; a programação JTAG usa o `.sof` compilado.
6. Pressione e solte KEY0. Mantenha SW1 = 0 e SW0 = 0; teste pressão e
   soltura de cada tecla, verificando seu LED e os eventos na página.
7. Coloque SW0 = 1 e pressione KEY1 com as teclas soltas. Confira a sequência
   C, D, E, C#, E, F e as métricas de acertos, erros e tempos.
8. Para debug de C4, ligue SW1: LED C e LEDR0 acendem, com nota `0x40` na
   UART de notas. Desligue SW1 para voltar ao funcionamento normal.

A tabela descreve a montagem correspondente ao QSF entregue. A fiação real
ainda deve ser conferida na bancada. Referência de conectores:
[Terasic DE0-CV User Manual, figura 3-12 e tabela 3-7](https://www.engr.colostate.edu/ECE102/Spring22/LABS/Lab01/de0-cv-user-manual.pdf#page=29).
