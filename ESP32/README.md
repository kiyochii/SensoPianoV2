# ESP32: UART da FPGA e webapp local

O firmware em `fw/` serve `web/index.html` diretamente da flash. Não precisa de
internet, CDN, servidor externo ou upload separado de filesystem. A página
consulta `/api/events` a cada 150 ms e reconecta automaticamente.

## Placa e ligação

O alvo padrão é **ESP32-WROOM-32 / DevKit** (`esp32dev`), com duas
UARTs de hardware além da serial USB. Não use essa configuração sem adaptar
em ESP32-C3/S2/S3, placas com PSRAM usando GPIO16/17 ou outra pinagem.

| FPGA | ESP32 |
| --- | --- |
| `esp_txd` (notas binárias) | GPIO16 — RX UART1 |
| `pc_txd` (métricas + eventos ASCII) | GPIO17 — RX UART2 |
| GND | GND |

Use sinais TTL de **3,3 V**, nunca RS-232 ou 5 V. O [projeto DE0-CV](../Quartus/README.md) atribui `esp_txd` ao GPIO_0 D24
e `pc_txd` ao GPIO_0 D25; confira a montagem com essa pinagem.
Os dois fios de TX da FPGA são sinais independentes: **não os una** no mesmo RX.
É possível conectar apenas notas ou apenas métricas; o campo ausente permanece
indisponível. `pc_txd` pode também alimentar o RX de um adaptador USB-UART.

Ambas as UARTs: **115200 baud, 8N1**, sem controle de fluxo. O USB do ESP32
permanece dedicado à gravação e ao monitor de diagnóstico. O firmware não envia
comandos à FPGA, pois o RTL atual não possui UART RX para recebê-los.

## Compilar e gravar

Instale [PlatformIO Core](https://docs.platformio.org/en/latest/core/installation/index.html)
ou use a extensão PlatformIO no VS Code. No terminal:

```sh
cd ESP32/fw
pio run
pio run --target upload
pio device monitor
```

Se houver mais de uma porta, acrescente `--upload-port /dev/PORTA` ao upload
e `--port /dev/PORTA` ao monitor. A configuração fixa a plataforma Espressif32
6.10.0 para tornar a compilação reproduzível. O script `scripts/embed_web.py`
embute o HTML a cada compilação; após editar o webapp, recompile e regrave.

1. Ligue a FPGA e o ESP32 com o GND comum e os RXs conectados.
2. Conecte o celular/computador à rede **SensoPiano**, senha **sensopiano**.
3. Abra **http://192.168.4.1**. Mantenha a conexão Wi-Fi mesmo sem internet.
4. Toque notas para verificar o RX de notas. Para métricas, selecione Aprender
   e acione `start` na FPGA; o primeiro snapshot contém contadores zerados.

Ajuste pinos, baud rate, nome e senha do AP em `fw/include/config.h`.
Opcionalmente preencha `WIFI_SSID` e `WIFI_PASSWORD` para conectar também a um
roteador. O endereço dessa conexão aparece no monitor serial, enquanto o AP
continua disponível. Não versione credenciais pessoais.

## Dados e API

- Notas: um byte `{0, oitava[2:0], nota[3:0]}`; notas 0–11 = C–B e oitavas
  0–7. O evento contém o byte original, nota e oitava. Bytes inválidos continuam
  disponíveis em hexadecimal e incrementam o diagnóstico. No modo Aprender,
  a UART de notas transmite a nota guia, não o toque da criança. O estado físico e os tempos vêm dos eventos `T` na outra UART.
- Métricas: linhas `M,00006,00001,00007,1\r\n`. O parser aceita frames
  fragmentados e sincroniza novamente em `M`. Verifica separadores, CRLF,
  limites de 16 bits e `tentativas = acertos + erros`. Substitui os totais em
  cada snapshot, inclusive quando uma nova sessão zera os contadores.
- Eventos físicos `T`: timestamps da FPGA, máscara das 12 teclas, modo,
  estado da atividade, nota esperada, sessão e resultado da tentativa. O
  teclado visual agora acompanha pressão e soltura reais.
- Todos os bytes de RX de métricas também são publicados como eventos `raw`,
  em blocos de até 32 bytes, inclusive mensagens parciais ou inválidas.
  Um evento `metrics` válido é uma interpretação adicional dos mesmos bytes.
- Acurácia é calculada no navegador, indisponível com zero tentativas.
  O progresso considera as seis notas da ROM atual da FPGA.

`GET /api/events?after=0&boot=` retorna:

```json
{
  "boot": "identificador-da-inicializacao",
  "reset": true,
  "next": 2,
  "latest": 2,
  "dropped": 0,
  "uptimeMs": 1200,
  "note": null,
  "metrics": {"correct": 0, "wrong": 0, "attempts": 0, "done": false},
  "rx": {"notes": 0, "metrics": 23, "invalidNotes": 0, "invalidLines": 0, "uartErrors": 0},
  "events": [
    {"id": 1, "ms": 1200, "source": "metrics", "type": "raw", "hex": "4D2C30303030302C30303030302C30303030302C300D0A"},
    {"id": 2, "ms": 1200, "source": "metrics", "type": "metrics", "metrics": {"correct": 0, "wrong": 0, "attempts": 0, "done": false}}
  ]
}
```

Use `next` e `boot` na próxima consulta. Cada resposta traz até 32 eventos,
mais os snapshots mais recentes. Os novos campos `activity` e `performance`
trazem estado físico e estatísticas; os eventos `activity` trazem cada observação.
`rx.activityMissing` conta observações faltantes pela sequência da FPGA. Consulte imediatamente enquanto `next < latest`.
`reset` indica cursor incompatível ou outra inicialização do ESP32. `dropped`
indica quantos eventos anteriores ao cursor já saíram do buffer; o webapp
mostra esse aviso. O campo `ms` continua sendo o horário de recepção no ESP32. O campo
`activity.fpgaMs` é o horário capturado na FPGA; os cálculos de tempos usam
exclusivamente esse relógio. Os dois fios UART não têm uma ordem comum de chegada.

## Tempos e outras métricas sem novos componentes

Atualize **FPGA e ESP32**. A ligação permanece igual: GPIO16, GPIO17 e GND.
O protocolo de notas e as linhas `M` continuam disponíveis. Leitores antigos
que só interpretam `M` devem ignorar as novas linhas `T` no mesmo fio.

| Métrica implementada | Como é obtida |
| --- | --- |
| Pressões e solturas das 12 teclas | Mudanças na máscara física, incluindo várias teclas |
| Total de toques e distribuição por tecla | Uma contagem por borda de pressão de cada tecla |
| Duração do toque | Soltura menos pressão da mesma tecla; média, mínimo, máximo e desvio padrão |
| Intervalo e variação entre toques | Diferença entre instantes de pressão; teclas simultâneas formam um único instante |
| Primeira resposta | Primeira tentativa aceita menos instante da indicação da nota guia |
| Tempo até acertar | Acerto menos instante da indicação; inclui tentativas erradas anteriores |
| Duração da atividade | Desde início de sessão ou troca de modo, congelada na conclusão |
| Tempo ativo | Tempo com pelo menos uma tecla pressionada, sem contar sobreposições duas vezes |
| Sequência atual e maior sequência de acertos | Resultados das tentativas aceitas |
| Episódios com várias teclas | Transição de zero/uma para duas ou mais teclas; não implica acorde musical correto |
| Integridade | Sequência, checksum XOR, perdas de FIFO e lacunas na recepção |

As estatísticas são calculadas no ESP32 mesmo sem navegador conectado.
Reiniciam ao mudar de modo, iniciar nova sessão ou detectar reset da FPGA.
A duração encerra na conclusão; a soltura da última tecla ainda pode completar
sua amostra de duração. Os timestamps têm resolução de **1 ms**, a partir das
teclas filtradas (10 ms de debounce no wrapper DE0-CV). Isso não mede o contato
elétrico anterior ao filtro nem a latência acústica.

Cada pressão física conta, inclusive uma tecla errada ou pressionada em conjunto.
As tentativas do modo Aprender seguem as regras originais: uma tecla individual
válida após liberar todas. Portanto, toques físicos e tentativas podem diferir.
O monitor mostra as estatísticas da atividade FPGA completa. As sessões do
navegador contam apenas os eventos físicos recebidos durante a gravação e
salvam, para consulta/exportação, os resumos das atividades FPGA observadas,
identificados separadamente. Um resumo pode incluir tempo anterior à gravação.
Registros antigos permanecem com seus valores originais e são identificados
como eventos legados; não entram nos novos gráficos de toques físicos.

Se faltar uma observação, as métricas ficam marcadas como incompletas e os
intervalos/durações/respostas que atravessariam a lacuna são descartados.
A sequência de acertos também é interrompida. Uma tecla já mantida quando
a recepção começa não ganha uma duração inventada. O horário de 32 bits volta
a zero em aproximadamente 49,7 dias; diferenças curtas atravessam essa volta.
Reset é reconhecido pela flag inicial e por regressão de sequência/relógio;
se o início for perdido durante uma desconexão, não há identificador de boot
persistente da FPGA que garanta distinguir todos os casos de reinicialização.

Também podem ser derivados em software, sem nova montagem: cadência de toques,
tempo inativo (duração menos tempo ativo), percentual de teclas exploradas e
tendências entre sessões. Força/intensidade,
velocidade mecânica da tecla e pressão contínua exigem sensores adicionais.
A ROM atual não especifica durações ou andamento: a variação dos intervalos
não deve ser apresentada como precisão rítmica em relação à música.

## Protocolo adicional no fio de métricas

Cada frame tem **58 bytes ASCII**, versão `1`, CRLF, campos hexadecimais de
largura fixa, letras maiúsculas:

```text
T,1,ssssssss,tttttttt,iiiiiiii,kkk,m,e,nn,ff,dddddddd,cc\r\n
```

- `s`: sequência de observações, inclusive as descartadas por falta de espaço.
- `t`: milissegundos desde o reset da FPGA, capturados antes do envio UART.
- `i`: sessão, incrementada a cada início no modo Aprender.
- `k`: máscara física, bit 0 = C, ..., bit 11 = B; zero indica todas soltas.
- `m`: 0 Livre, 1 Aprender. `e`: 0 Livre, 1 aguardando início, 2 indicando
  nota, 3 aguardando resposta, 4 avaliando tentativa, 5 concluída.
- `nn`: byte `{0,oitava,nota}` da nota esperada; só tem sentido no modo Aprender.
- `ff`: bits 0 início, 1 acerto, 2 erro, 3 primeiro evento após reset,
  4 heartbeat. Flags podem se combinar.
- `d`: total saturado de observações descartadas pela FIFO desde reset.
- `cc`: XOR dos primeiros 54 bytes (de `T` até a vírgula antes do checksum).

Há eventos nas mudanças de teclas, modo, estado, início e tentativas, além de
um heartbeat a cada segundo. A FIFO guarda 16 observações, mais o frame ativo.
Linhas `M` e `T` alternam por frame quando ambas estão pendentes; seus bytes
nunca são intercalados. Um frame `T` leva aproximadamente 5 ms a 115200 baud.
Rajadas acima da capacidade podem perder eventos, com diagnóstico explícito.
O heartbeat atualiza o estado após períodos sem teclas. O campo `activityAgeMs`
mede há quanto tempo o ESP32 recebeu uma observação válida. Após 3 segundos
sem atualização, a página informa estado desconhecido e bloqueia o início de
nova gravação; não inventa uma soltura da tecla.

A API expõe, por exemplo:

```json
{
  "activity": {"sequence": 10, "fpgaMs": 1250, "session": 1, "epoch": 1,
    "keys": 1, "pressed": 1, "released": 0, "mode": 1, "state": 3,
    "expected": 48, "flags": 0, "dropped": 0, "continuous": true},
  "performance": {"startedMs": 1000, "elapsedMs": 250, "activeMs": 0,
    "presses": 1, "chords": 0, "streak": 0, "bestStreak": 0,
    "hold": null, "interval": null, "response": null, "solve": null,
    "perKey": [1,0,0,0,0,0,0,0,0,0,0,0], "incomplete": false, "finished": false}
}
```

Cada grupo de tempo não nulo contém `count`, `meanMs`, `minMs`, `maxMs` e
`stddevMs` (desvio padrão populacional). `null` significa nenhuma amostra completa.
`epoch` identifica os resets da FPGA observados pelo ESP32; não é o `boot` do ESP32.

## Limites e validação

O histórico em RAM conserva **128 eventos**, compartilhados entre os dois RXs;
a página conserva os últimos **150** que conseguiu ler. Os eventos e estatísticas são voláteis:
ao reiniciar o ESP32 são apagados. Perfil fica na NVS; sessões e resumos já
gravados ficam no armazenamento local do navegador e podem ser exportados. Uma tarefa FreeRTOS recebe UART
independentemente das requisições HTTP, com buffers de RX de 4096 bytes por
porta. Erros de UART são contabilizados; nenhum buffer finito garante ausência
de perdas em tráfego contínuo ou durante desconexões prolongadas. O caso de
uso é o fluxo de notas e snapshots emitido pelo RTL atual.

Teste independente do hardware:

```sh
c++ -std=c++11 -Wall -Wextra -Werror -fsanitize=address,undefined \
  -I ESP32/fw/include ESP32/fw/test/telemetry_test.cpp \
  -o /tmp/sensopiano-telemetry-test
/tmp/sensopiano-telemetry-test
node ESP32/fw/test/web_test.js
```

Os testes não substituem o ensaio físico: confira ambos os RXs, notas nos dois
modos, início/conclusão de sessão, reset da FPGA, reconexão Wi-Fi, múltiplos
navegadores e contadores de erros na montagem real.

Referências: [UART Arduino-ESP32](https://docs.espressif.com/projects/arduino-esp32/en/latest/api/serial.html)
e [Wi-Fi Arduino-ESP32](https://docs.espressif.com/projects/arduino-esp32/en/latest/api/wifi.html).
