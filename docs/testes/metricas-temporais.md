# Métricas temporais — 17/11/2026

Implementação sem alteração de pinagem: eventos físicos `T` compartilham
`pc_txd` com os snapshots `M`. O timestamp é capturado na FPGA, antes da
fila e da transmissão UART. A UART de notas anterior continua disponível.

## Validação automatizada

- Suíte RTL: **13 aprovados, 0 reprovados**, Icarus Verilog 12.0.
- Teste novo do emissor: timestamps com divisor de clock, pressão/soltura,
  nota guia, flags de acerto/erro, sessão, checksum, heartbeat, FIFO cheia,
  backpressure e reset. Reexecutado após reforço das verificações.
- Integração pelo fio UART: mensagens M/T completas, checksum T, snapshots
  M, tentativas, acordes, conclusão, reset durante transmissão e recuperação.
- Telemetria C++ com AddressSanitizer e UndefinedBehaviorSanitizer: aprovada.
  Inclui todos os pontos de fragmentação do frame T, checksum inválido,
  ressincronização, tempos conhecidos, teclas simultâneas, primeira resposta,
  erros antes do acerto, congelamento na conclusão, lacunas, reset da FPGA e
  volta a zero dos contadores de tempo/sequência de 32 bits.
- Página completa em Node: aprovada. Executa os dois scripts; verifica
  pressão/soltura, exibição de tempos, gravação de sessões, exclusão de notas
  guia da contagem de toques, duplicatas, perdas, persistência dos resumos,
  reset da FPGA e estado desatualizado.
- Firmware ESP32: compilação PlatformIO aprovada para `esp32dev`, plataforma
  Espressif32 6.10.0. RAM estática: 59.836 bytes (18,3%); flash: aproximadamente
  826 kB (63%). Esses valores não medem o pico de heap durante requisições.
- Wrapper da DE0-CV: `tb_debug` aprovado, incluindo áudio C4, LEDs, UART,
  prioridade do debug, saída, reentrada e reset.

Comandos reproduzíveis na raiz:

```sh
bash Verilog/run_tests.sh
c++ -std=c++11 -Wall -Wextra -Werror -fsanitize=address,undefined \
  -I ESP32/fw/include ESP32/fw/test/telemetry_test.cpp \
  -o /tmp/sensopiano-telemetry-test
/tmp/sensopiano-telemetry-test
node ESP32/fw/test/web_test.js
pio run -d ESP32/fw
git diff --check
```

Nesta execução, o Icarus foi extraído em `/tmp/sensopiano-tools/iverilog`,
e o PlatformIO instalado num ambiente Python em `/tmp/sensopiano-tools/pio-env`.
Esses caminhos são locais à execução e não são dependências do projeto.

## Ensaio na montagem

1. Compile e grave a FPGA pelo projeto Quartus atualizado; compile e grave o
   ESP32. Preserve GPIO16 para notas, GPIO17 para métricas e o GND comum.
2. Abra o monitor do piano. Após um segundo, confirme modo, teclas e tempos.
3. No modo Livre, mantenha uma tecla por aproximadamente um segundo e solte:
   deve surgir um toque físico e uma amostra de duração próxima de 1000 ms.
   O desenho da tecla deve apagar na soltura. Repita em outra tecla.
4. Pressione duas teclas simultaneamente: ambas devem aparecer e o contador
   de episódios com várias teclas deve aumentar, sem tentativa de aprendizado.
5. No modo Aprender, acione start. Aguarde a guia, erre, solte e acerte:
   primeira resposta deve medir a primeira tentativa, e tempo até acertar
   deve incluir o período gasto no erro e na correção.
6. Complete a música. A duração deve parar na conclusão e o acerto final deve
   aparecer na sequência de acertos. A nota guia sozinha não pode contar como
   toque físico nos registros do navegador.
7. Reinicie só a FPGA: os resumos correntes devem reiniciar e uma gravação
   ativa no navegador deve encerrar, marcada como incompleta.
8. Interrompa apenas o fio de métricas por mais de 3 segundos. A página deve
   indicar estado desconhecido. Ao reconectar, confira a sinalização de perdas
   e a retomada de medições completas, sem inventar durações que cruzem a perda.

A simulação e os testes de software não substituem fitting/timing no Quartus
nem ensaio elétrico com as placas. Não houve gravação ou recepção física
durante esta execução.
