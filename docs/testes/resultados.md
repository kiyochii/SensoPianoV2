# Registro de execucao — 03/11/2026

Projeto: **SensoPianoV2**. A suite contem sete testbenches novos, dois
convertidos de demonstracoes textuais em verificacoes automaticas (debounce
e ROM) e tres existentes ampliados ou reforcados (metricas e integracao).
Os dez modulos RTL funcionais foram preservados.

## Ambiente e reproducao

- Linux x86_64, WSL2, kernel `6.6.87.2-microsoft-standard-WSL2`.
- Icarus Verilog **12.0 stable**, pacote Ubuntu `12.0-2build2`.
- Compilacao SystemVerilog: `-g2012 -Wall -Wno-timescale`.
- Clock dos testes sincronos: 50 MHz, periodo de 20 ns.
- Simulacao funcional, sem Quartus ou FPGA fisica.

O ambiente nao tinha Icarus instalado e nao permitia `sudo` sem senha.
O pacote foi baixado com `apt-get download iverilog` e extraido com
`dpkg-deb -x` em `/tmp/sensopiano-iverilog/root`, sem instalacao no sistema.

Comando usado na raiz do repositorio para a execucao registrada:

```sh
set -o pipefail
IVERILOG=/tmp/sensopiano-iverilog/root/usr/bin/iverilog \
VVP=/tmp/sensopiano-iverilog/root/usr/bin/vvp \
IVL_BASE=/tmp/sensopiano-iverilog/root/usr/lib/x86_64-linux-gnu/ivl \
TEST_LOG_DIR=/tmp/sensopiano-final \
bash Verilog/run_tests.sh | tee docs/testes/execucao-2026-11-03.log
```

Esses caminhos em `/tmp` sao especificos desta execucao. Com Icarus
instalado no `PATH`, basta `bash Verilog/run_tests.sh`. Para outro local de
instalacao portatil, ajuste `IVERILOG`, `VVP` e `IVL_BASE`. O runner compila
todos os executaveis novamente antes de simular.

## Resultado da suite

**12 aprovados, 0 reprovados; codigo de saida 0.** Os 12 logs de compilacao
ficaram sem diagnosticos com as opcoes acima. A execucao integral esta no
[log versionavel](execucao-2026-11-03.log).

| Testbench | Resultado |
| --- | --- |
| `tb_debouncer` | PASS |
| `tb_key_register` | PASS |
| `tb_music_rom` | PASS |
| `tb_fd` | PASS |
| `tb_uc` | PASS |
| `tb_mode_controller` | PASS |
| `tb_uart_key_sender` | PASS |
| `tb_uart_tx` | PASS |
| `tb_uart_metrics_sender` | PASS |
| `tb_metrics_uart` | PASS |
| `tb_top` | PASS |
| `tb_audio_output` | PASS |

Destacam-se os 4.096 vetores de entrada, 64 enderecos da ROM, 96
combinacoes de nota/oitava, 518 quadros UART, 65.535 tentativas sem atalhos
nos contadores e a medicao de audio nas 12 notas e nas seis notas da
atividade. Nenhuma falha funcional foi observada nos cenarios exercitados.
Os limites de simulacao estao descritos na [documentacao](README.md#limites).

## Investigacao da pausa em `tb_uart_tx`

A execucao isolada da versao anterior terminou com PASS em **29,33 s**
(tempo real), com codigo zero. O longo silencio correspondia ao quadro
com divisor 65535: 5.242.800 ciclos verificados, sem mensagens intermediarias.
O pipe para `tee` tambem permitia o armazenamento da saida em buffer.

Foram adicionadas mensagens de progresso por divisor e por bit no caso
mais longo. O runner agora usa `vvp -i`, com saida sem buffer. A verificacao
dos 518 quadros, o timeout e o RTL foram preservados.

A verificacao apos a mudanca executou `tb_uart_key_sender` e `tb_uart_tx`:
**2 aprovados, 0 reprovados**, codigo zero, em **32,58 s** no total. As
mensagens foram observadas enquanto o processo ainda estava rodando.
Veja o [log dessa verificacao](execucao-uart-tx-2026-11-03.log).
O resultado de 12 testes acima pertence a execucao integral anterior.

## Verificacao do executor

Tambem foram executados `bash -n Verilog/run_tests.sh` e `git diff --check`,
sem erros. O runner foi chamado de `/tmp`, com injecao controlada dos
executaveis `true`/`false` e de um caminho inexistente, obtendo:

| Cenario | Codigo observado | Resultado |
| --- | --- | --- |
| Testbench desconhecida | 2 | Aprovado |
| Compilador inexistente | 127 | Aprovado |
| Compilador retorna falha | 1 | Aprovado |
| Processo termina com zero, sem marcador `PASS` | 1 | Aprovado |
| Simulador retorna falha | 1 | Aprovado |

Essas verificacoes do executor sao separadas das 12 simulacoes de hardware.
Os cenarios e criterios de cada testbench estao na
[matriz de testes](README.md#matriz-de-testes).
