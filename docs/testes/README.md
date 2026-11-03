# Testbenches do SensoPianoV2

A suite valida os dez modulos Verilog do repositorio, individualmente e em
integracao. Sao **12 testbenches com verificacao automatica**: resultados
inesperados encerram a simulacao com `$fatal(1, ...)`; cada teste tem um
limite de tempo simulado e so anuncia `PASS` ao concluir as verificacoes.
O runner tambem exige esse marcador, alem do codigo de saida zero.

## Como executar

Requisitos: Bash e Icarus Verilog (`iverilog` e `vvp`). Nao sao necessarios
Quartus, placa FPGA, adaptador serial nem visualizador de formas de onda.

Na raiz do repositorio:

```sh
bash Verilog/run_tests.sh
```

O script pode ser chamado de qualquer diretorio e compila os fontes atuais
em um diretorio temporario, removido ao sair. Ele nao utiliza os arquivos
antigos `Verilog/tb_top.vvp` e `Verilog/output.txt` como evidencia.

Para listar testes, selecionar alguns ou preservar os logs:

```sh
bash Verilog/run_tests.sh --list
bash Verilog/run_tests.sh tb_debouncer tb_uc tb_mode_controller
TEST_LOG_DIR=/tmp/sensopiano-resultados bash Verilog/run_tests.sh
```

`TEST_LOG_DIR` e relativo ao diretorio de chamada; cada teste produz
`<nome>.compile.log` e `<nome>.log`, alem de `summary.log` da execucao.
Sem essa variavel, os logs temporarios sao removidos junto dos executaveis.
O runner continua os demais testes apos uma falha e retorna **0** quando
todos passam, **1** se algum falha, **2** para nome desconhecido e **127** se
um executavel nao for encontrado. Uma selecao parcial resume apenas os testes
selecionados.

Para uma instalacao portatil, configure os caminhos:

```sh
IVERILOG=/caminho/bin/iverilog \
VVP=/caminho/bin/vvp \
IVL_BASE=/caminho/lib/ivl \
bash Verilog/run_tests.sh
```

Em pacotes Debian/Ubuntu, `IVL_BASE` pode ser `usr/lib/x86_64-linux-gnu/ivl`
dentro da arvore extraida. O script passa esse diretorio ao compilador e ao
runtime. A compilacao usa `-g2012 -Wall -Wno-timescale`: os testbenches definem
`1ns/1ps`, e o RTL nao tem atrasos de simulacao. Apenas os avisos de unidade
de tempo herdada sao desabilitados.

## Matriz de testes

| Testbench / arquivo em `Verilog/` | Objeto | Verificacoes |
| --- | --- | --- |
| `tb_debouncer` — `modules/utils/tb/tb_debounce.v` | `debouncer` | Bounce ao pressionar e soltar; pulsos curtos nao acumulam contagem; limiar; entrada mantida; sincronizacao com debounce zero; reset assincrono ativo baixo. |
| `tb_key_register` — `modules/utils/tb/tb_key_register.v` | `key_register` | Todos os 4.096 valores de 12 bits; carga na borda; retencao com carga desabilitada; reset sincrono com prioridade sobre carga. |
| `tb_music_rom` — `modules/utils/tb/tb_music_rom.v` | `music_rom` | Todas as 64 combinacoes de musica e indice, incluindo notas, comprimentos e retorno zero para indices fora da musica. |
| `tb_fd` — `tb_fd.v` | `fluxo_dados` | Todos os 4.096 vetores: nenhuma tecla, 12 teclas individuais e 4.083 acordes; saidas `key_any`, `key_valid`, `key_error`; sincronizacao, carga, retencao e reset integrados. |
| `tb_uc` — `tb_uc.v` | `UC` | Estados SCAN/REGISTER/WAIT_RELEASE; carga e pulso de um ciclo; tecla mantida; bloqueio de acorde e liberacao parcial; rearme; prioridade de erro; reset em REGISTER e WAIT_RELEASE. |
| `tb_mode_controller` — `tb_mode_controller.v` | `mode_controller` | Modo Livre nas 12 teclas; notas, oitava, LEDs e RGB; silencio e acorde; inicio com tecla mantida; erro sem avancar; seis acertos; sequencia C3/D4/E5/C#6/E5/F6; conclusao; nova sessao; cancelamento e reset. |
| `tb_uart_key_sender` — `modules/uart/tb/tb_uart_key_sender.v` | `uart_key_sender` | As 96 combinacoes de 12 notas e oito oitavas; byte `{0,oitava,nota}`; estabilidade com `ready=0`; descarte de pulso com byte pendente; um handshake por byte; reset e recuperacao. |
| `tb_uart_tx` — `modules/uart/tb/tb_uart_tx.v` | `uart_tx` | 518 quadros completos: todos os 256 bytes nos divisores 1 e 2; `00/FF/55/AA` no divisor 54; `A5` em 65535; `81` apos reset. Verifica cada ciclo de start/dados LSB-first/stop, duracao dos bits, `busy`, `ready` e repouso. Reset interrompe outro quadro parcial. |
| `tb_uart_metrics_sender` — `tb_metrics_uart.v` | `uart_metrics_sender` | Comparacao dos 23 bytes ASCII; snapshots imutaveis; backpressure entre bytes; agregacao de eventos; acertos, erros e conclusao; 65.535 tentativas reais; saturacao; conclusao apos saturar; prioridades inicio/acerto/erro; nova sessao com linha pendente; reset. |
| `tb_metrics_uart` — `tb_metrics_uart.v` | `top` → `pc_txd` | Recepcao 8N1 pelo fio em periodo nominal de 115200 baud; formato, CR/LF e soma dos contadores; ausencia de metricas no modo Livre; tecla anterior ao inicio; transicoes curtas; tecla mantida; acordes e liberacao parcial; musica completa; ausencia de duplicatas; nova sessao; reset durante byte e recuperacao. |
| `tb_top` — `tb_top.v` | Integracao de audio e `esp_txd` | Regressao existente: audio nas teclas 3/7, silencio com acorde, audio no modo Aprender, primeira resposta e bloqueio de acorde; bytes de nota `43`, `47`, `30`, `42` e quantidade total de transmissoes. |
| `tb_audio_output` — `tb_audio_output.v` | `top` → `audio_pwm` e LEDs | Medicao externa dos semiperiodos alto e baixo nas 12 notas da oitava 4 e nas seis notas da atividade, cobrindo oitavas 3/4/5/6; polaridade ativa baixa dos LEDs/RGB no modo Livre; silencio sem tecla, com acorde, antes de start e apos conclusao; reset durante tom. |

## Criterios e escolhas de simulacao

- Os novos estimulos sincronos mudam na borda de descida. As leituras de
  registradores ocorrem depois da atualizacao da borda de subida ou na
  descida seguinte, evitando disputas entre testbench e DUT.
- Os testes usam portas publicas, sem `force`, alteracao de contadores
  internos ou atalhos para atingir a saturacao.
- O debounce isolado usa `CLK_FREQ=1000` e `DEBOUNCE_TIME_MS=5` para reduzir
  o limiar a cinco ciclos. O clock da simulacao e de 20 ns: esse teste mede
  ciclos, nao cinco milissegundos fisicos. Na implementacao atual, a saida
  muda na oitava borda apos a mudanca da entrada: duas de sincronizacao e
  seis avaliacoes do contador (`COUNTER_MAX + 1`). Com debounce zero, sao
  tres bordas. Os testes de integracao preservam o debounce zero do projeto.
- O audio e medido com clock real de simulacao de 50 MHz. Por exemplo, C4
  deve ter semiperiodo de 47.778 ciclos (955.560 ns). Tambem sao verificados
  o nivel alto e o baixo, cobrindo o duty cycle de 50%. As oitavas usam a
  divisao inteira da implementacao.
- `tb_metrics_uart` amostra `pc_txd` com 8.681 ns por bit, independentemente
  do divisor interno de 54 (8.640 ns por bit). Assim, a integracao verifica
  a recepcao com a diferenca entre baud nominal e baud gerado.
- `music_rom` e validada separadamente: o controlador de modos utiliza sua
  propria sequencia interna de seis notas, e nao instancia essa ROM.
- O emissor de notas tem capacidade para um byte pendente. Os testes
  verificam o descarte de novos pulsos enquanto ocupado; nao assumem uma
  fila que o hardware nao implementa. O emissor de metricas, por sua vez,
  agrega atualizacoes nos totais e preserva a consistencia de cada linha.

## Resultado registrado

A execucao e o ambiente estao documentados em [resultados.md](resultados.md),
com o [log da suite completa](execucao-2026-11-03.log). Os testes modificam
somente a infraestrutura de verificacao; o RTL funcional foi preservado.

## Limites

Esta e verificacao funcional por simulacao, sem medicao formal de cobertura
de linhas ou de ramos. Nao substitui sintese, analise de timing, pinagem,
metastabilidade, ensaio de botoes mecanicos ou recepcao em placa. O debounce
padrao continua zerado. Audio nas oitavas 0/1/2/7 e configuracoes diferentes
de `DATA_WIDTH=8` da UART nao foram exercitados. A validacao de divisores
nao cobre zero, que esta fora do intervalo suportado documentado no README.
