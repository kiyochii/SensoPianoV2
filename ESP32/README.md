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
| `pc_txd` (métricas ASCII) | GPIO17 — RX UART2 |
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
  disponíveis em hexadecimal e incrementam o diagnóstico. Não há mensagem de
  soltura, duração, modo ou estado de teclas no protocolo atual; o teclado
  visual mostra a última nota recebida, sem inventar essas informações.
- Métricas: linhas `M,00006,00001,00007,1\r\n`. O parser aceita frames
  fragmentados e sincroniza novamente em `M`. Verifica separadores, CRLF,
  limites de 16 bits e `tentativas = acertos + erros`. Substitui os totais em
  cada snapshot, inclusive quando uma nova sessão zera os contadores.
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
mais o snapshot mais recente. Consulte imediatamente enquanto `next < latest`.
`reset` indica cursor incompatível ou outra inicialização do ESP32. `dropped`
indica quantos eventos anteriores ao cursor já saíram do buffer; o webapp
mostra esse aviso. Os timestamps são locais ao ESP32, não à FPGA, e não
estabelecem ordem física entre os dois fios UART.

## Limites e validação

O histórico em RAM conserva **128 eventos**, compartilhados entre os dois RXs;
a página conserva os últimos **150** que conseguiu ler. Não há persistência:
ao reiniciar o ESP32 os dados são apagados. Uma tarefa FreeRTOS recebe UART
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
