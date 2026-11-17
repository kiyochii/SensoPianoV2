# SensoPianoV2

## LEDs do piano

São **12 LEDs de uma única cor**, um por tecla. No modo Livre acendem
conforme as teclas pressionadas; no modo Aprender indicam a próxima nota.
As saídas `piano_leds_n` usam GPIO_0 D12–D23 e são ativas em nível baixo.
A cor depende do LED instalado. Consulte a [pinagem](Quartus/PINAGEM.md) e a
[montagem física](Quartus/MONTAGEM.md). O projeto pronto para restaurar está
no [arquivo QAR](Entregas/SensoPiano_DE0_CV.qar), com as tabelas também em
[PDF](Entregas/SensoPiano_pinagem_e_montagem.pdf).

## ESP32 e webapp

O firmware agora recebe notas e métricas da FPGA por duas UARTs e serve um
webapp local pelo Wi-Fi do ESP32. Consulte [ligação, compilação e uso](ESP32/README.md).

## Tempos e eventos físicos

A FPGA agora envia timestamps de 1 ms, pressão/soltura das 12 teclas, modo,
sessão e resultado das tentativas no fio `pc_txd` existente, junto às linhas
`M` anteriores. O ESP32 calcula duração dos toques, intervalos e variação,
tempo da primeira resposta, tempo até acertar, tempo ativo, uso por tecla,
episódios com várias teclas e sequências de acertos. Não há novos componentes
ou fios. É necessário atualizar o firmware das **duas placas**.

No modo Aprender, a UART legada `esp_txd` envia notas guia; os toques físicos
são identificados pelos novos frames `T`. Consulte o
[protocolo e as definições das métricas](ESP32/README.md#tempos-e-outras-métricas-sem-novos-componentes).

## Métricas da FPGA para o computador

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

O projeto para **DE0-CV** esta em [Quartus/SensoPiano_DE0_CV.qpf](Quartus/SensoPiano_DE0_CV.qpf),
com fontes, dispositivo, clock e pinagem definidos no QSF. Consulte as
[instrucoes de abertura e montagem](Quartus/README.md). A pinagem externa
proposta precisa corresponder a sua fiacao. O cabo USB-Blaster de programacao
nao recebe automaticamente a UART implementada neste GPIO.

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
As linhas `M` não incluem timestamp ou sessão. Essas informações agora vêm
nos frames `T` adicionais; não há comandos recebidos do PC. Leitores antigos
devem ignorar as linhas `T` para continuar interpretando apenas `M`.

### Simulacao e limites da validacao

Com Icarus Verilog (`iverilog` e `vvp`) instalado:

```sh
cd Verilog
bash run_tests.sh
```

O script executa 13 testbenches com verificacao automatica, cobrindo todos
os modulos: debounce, registrador, ROM, fluxo de dados, unidade de controle,
modos, audio, emissores de notas/metricas e UART. Inclui todos os 4096
vetores de teclas, os 256 bytes UART, periodos de audio, saturacao, reset e
transmissor ocupado. Consulte a [matriz de testes e instrucoes](docs/testes/README.md)
e os [resultados registrados](docs/testes/resultados.md).
Os executaveis de teste sao criados em diretorio temporario.
Para uma instalacao portatil do Icarus, o script tambem aceita `IVERILOG` e
`VVP` com os caminhos dos executaveis e `IVL_BASE` com o diretorio `lib/ivl`.

Além das simulações, a versão atual foi compilada no Quartus Lite 20.1.1:
timing interno de 50 MHz atendido e 42 atribuições de pinos conferidas.
Consulte o [registro de compilação](docs/testes/compilacao-quartus-2026-11-17.md).
A recepção com as placas e o adaptador reais ainda precisa de ensaio físico.
O debounce original esta configurado com `DEBOUNCE_TIME_MS=0`; ajuste-o
para os botoes fisicos antes do ensaio, pois contatos mecanicos podem gerar
tentativas repetidas. O firmware ESP32 e o webapp local estao descritos em [ESP32/README.md](ESP32/README.md). MQTT nao e utilizado.
