# SensoPianoV2

## Primeira etapa: metricas da FPGA para o computador

O `top` agora tem a saida `pc_txd` para transmitir as metricas do modo
Aprender por UART. A saida `esp_txd` continua enviando os bytes de nota no
formato binario original. A transmissao e unidirecional: FPGA -> PC.

Configuracao padrao: clock de **50 MHz**, serial **115200 baud, 8 bits,
sem paridade, 1 stop bit (8N1)**, sem controle de fluxo. Os parametros
`CLK_FREQ_HZ` e `BAUD_RATE` do `top` configuram os dois transmissores.
O divisor inteiro arredondado e 54, resultando em aproximadamente 115741 baud
com 50 MHz (erro de +0,47%). O divisor deve ficar entre 1 e 65535.
O parametro de clock configura a UART; os tempos de audio e debounce do
projeto continuam dimensionados para 50 MHz.

### Ligacao para o teste de bancada

Use um adaptador **USB-UART com sinais TTL de 3,3 V**:

| FPGA / placa | Adaptador USB-UART |
| --- | --- |
| GPIO atribuido a `pc_txd` | RX / RXD |
| GND | GND |

Alimente a placa pelo seu circuito habitual. Nao conecte o VCC do adaptador
nem use uma interface RS-232 diretamente. O TX do adaptador nao e utilizado
nesta etapa. Os GPIOs da DE0-CV operam em 3,3 V, conforme a
[especificacao da Terasic](https://www.terasic.com.cn/cgi-bin/page/archive.pl?CategoryNo=183&Language=China&No=921&PartNo=2).
Um conversor como o [TTL-232R-3V3](https://ftdichip.com/products/ttl-232r-3v3/)
exemplifica o tipo de interface eletrica necessario.

Este repositorio ainda nao inclui projeto/pinagem do Quartus. Adicione
`Verilog/modules/uart/uart_metrics_sender.v` aos fontes, selecione `top` e
atribua `pc_txd` ao GPIO fisicamente escolhido no Pin Planner, usando o
padrao de I/O de 3,3 V apropriado. Confira tambem clock, reset, teclas e
demais portas na montagem. O cabo USB-Blaster de programacao nao recebe
automaticamente a UART implementada neste GPIO.

Abra a porta serial do adaptador no computador com a configuracao acima.
Coloque `mode_sel=1` e acione `start`, com as teclas soltas. O terminal deve
receber uma linha inicial com os contadores zerados.

### Formato das mensagens

Cada linha tem 23 bytes ASCII e termina com CR + LF (`\r\n`):

```text
M,acertos,erros,tentativas,concluida
M,00000,00000,00000,0
M,00000,00001,00001,0
M,00001,00001,00002,0
M,00006,00001,00007,1
```

- Os tres contadores possuem cinco digitos decimais; `concluida` vale 0 ou 1.
- Cada tentativa e uma unica tecla valida, apos liberar todas as teclas.
  Uma tecla errada incrementa `erros` e mantem a nota esperada. Uma correta
  incrementa `acertos` e avanca a musica. `tentativas = acertos + erros`.
- Teclas mantidas, teclas pressionadas antes do inicio e acordes nao geram
  novas tentativas. Depois de um acorde, solte todas antes de tentar novamente.
- A musica atual possui seis notas: C3, D4, E5, C#6, E5 e F6. O progresso
  no PC e `acertos / 6`; a acuracia e `100 * acertos / tentativas`.
  Com zero tentativas, mostre a acuracia como indisponivel.
- A FPGA envia os contadores e o indicador de conclusao; o percentual e
  calculado no PC, evitando uma divisao adicional em hardware.

Uma linha e solicitada no inicio, apos tentativas e na conclusao. O emissor
congela os valores ate terminar a linha. Se houver varias atualizacoes durante
o envio, a proxima linha contem os totais mais recentes: os snapshots
intermediarios podem ser agrupados, mas as tentativas continuam contabilizadas.
O PC deve **substituir** os totais exibidos, nunca somar as linhas recebidas.
A linha leva aproximadamente 2 ms na configuracao padrao.

Os contadores saturam juntos em 65535 tentativas, sem retornar a zero; novas
tentativas deixam de incrementar os totais ate a proxima sessao. O sinal de
conclusao ainda pode ser atualizado. Para iniciar outra sessao, volte ao modo
Livre, selecione Aprender e acione `start`; os contadores sao zerados.
Uma linha em andamento termina antes do snapshot da nova sessao. O reset
global interrompe a transmissao; apos um reset, o leitor deve descartar linhas
incompletas ou fora do formato esperado e sincronizar na proxima linha `M,...`.
Ainda nao ha timestamp, identificador de sessao ou comandos recebidos do PC.

### Simulacao e limites da validacao

Com Icarus Verilog (`iverilog` e `vvp`) instalado:

```sh
cd Verilog
bash run_tests.sh
```

O script verifica a regressao de audio/notas e a telemetria UART, incluindo
conteudo serial, contagem de tentativas, conclusao, reset e transmissor ocupado.
Os executaveis de teste sao criados em diretorio temporario.
Para uma instalacao portatil do Icarus, o script tambem aceita `IVERILOG` e
`VVP` com os caminhos dos executaveis e `IVL_BASE` com o diretorio `lib/ivl`.

Os testes sao simulacoes; ainda e necessario compilar no Quartus, conferir
timing/pinagem e validar a recepcao com a placa e o adaptador reais.
O debounce original esta configurado com `DEBOUNCE_TIME_MS=0`; ajuste-o
para os botoes fisicos antes do ensaio, pois contatos mecanicos podem gerar
tentativas repetidas. Esta etapa nao implementa ESP32, MQTT ou aplicativo.
