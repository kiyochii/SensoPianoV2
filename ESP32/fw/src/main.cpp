#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <esp_system.h>
#include "config.h"
#include "telemetry.h"
#include "webapp.generated.h"

HardwareSerial notesUart(1), metricsUart(2);
WebServer server(80);
senso::Telemetry telemetry;
SemaphoreHandle_t telemetryMutex;
String bootId;

void uartError(hardwareSerial_error_t) {
    xSemaphoreTake(telemetryMutex, portMAX_DELAY);
    ++telemetry.uartErrors;
    xSemaphoreGive(telemetryMutex);
}

void receiveTask(void*) {
    uint8_t bytes[32];
    for (;;) {
        HardwareSerial* ports[] = {&notesUart, &metricsUart};
        for (int port = 0; port < 2; ++port) {
            size_t length = 0;
            while (length < sizeof(bytes) && ports[port]->available()) {
                bytes[length++] = static_cast<uint8_t>(ports[port]->read());
            }
            if (!length) continue;
            xSemaphoreTake(telemetryMutex, portMAX_DELAY);
            if (port == 0) telemetry.receiveNotes(bytes, length, millis());
            else telemetry.receiveMetrics(bytes, length, millis());
            xSemaphoreGive(telemetryMutex);
        }
        vTaskDelay(1);
    }
}

String metricsJson(const senso::Metrics& m) {
    if (!m.available) return "null";
    return String("{\"correct\":") + m.correct + ",\"wrong\":" + m.wrong +
        ",\"attempts\":" + m.attempts + ",\"done\":" + (m.done ? "true}" : "false}");
}
String noteJson(const senso::Note& n) {
    if (!n.available) return "null";
    return String("{\"raw\":") + n.raw + ",\"pitch\":" + n.pitch + ",\"octave\":" + n.octave + "}";
}
String eventJson(const senso::Event& e) {
    String result = String("{\"id\":") + e.id + ",\"ms\":" + e.ms +
        ",\"source\":\"" + (e.source ? "metrics" : "notes") + "\",\"type\":\"";
    if (e.kind == senso::Kind::Note) result += "note\",\"note\":" + noteJson(e.note);
    else if (e.kind == senso::Kind::Metrics) result += "metrics\",\"metrics\":" + metricsJson(e.metrics);
    else result += "raw\"";
    if (e.length) {
        static const char hex[] = "0123456789ABCDEF";
        result += ",\"hex\":\"";
        for (uint8_t i = 0; i < e.length; ++i) {
            result += hex[e.raw[i] >> 4];
            result += hex[e.raw[i] & 15];
        }
        result += '"';
    }
    return result + '}';
}
void eventsHandler() {
    String query = server.arg("after");
    if (query.isEmpty()) query = "0";
    uint64_t parsed = 0;
    for (size_t i = 0; i < query.length(); ++i) {
        if (query[i] < '0' || query[i] > '9' || (parsed = parsed * 10 + query[i] - '0') > UINT32_MAX) {
            server.send(400, "application/json", "{\"error\":\"invalid cursor\"}");
            return;
        }
    }
    // Copy under the mutex; JSON and network writes never block UART reception.
    static senso::Event batch[32];
    size_t count = 0;
    uint32_t cursor = static_cast<uint32_t>(parsed);
    xSemaphoreTake(telemetryMutex, portMAX_DELAY);
    uint32_t oldest = telemetry.oldest(), latest = telemetry.sequence;
    bool reset = server.arg("boot") != bootId || cursor > latest;
    if (reset) cursor = 0;
    uint32_t dropped = oldest > cursor + 1 ? oldest - cursor - 1 : 0;
    uint32_t first = cursor < oldest ? oldest : cursor + 1;
    for (uint32_t id = first; id <= latest && count < 32; ++id) batch[count++] = telemetry.get(id);
    auto metrics = telemetry.metrics;
    auto note = telemetry.note;
    uint32_t noteBytes = telemetry.noteBytes, metricsBytes = telemetry.metricsBytes;
    uint32_t invalidNotes = telemetry.invalidNotes, invalidLines = telemetry.invalidLines;
    uint32_t uartErrors = telemetry.uartErrors;
    xSemaphoreGive(telemetryMutex);
    uint32_t next = count ? batch[count - 1].id : cursor;
    String json;
    json.reserve(8000);
    json = "{\"boot\":\"" + bootId + "\",\"reset\":" + (reset ? "true" : "false") +
        ",\"next\":" + next + ",\"latest\":" + latest + ",\"dropped\":" + dropped +
        ",\"uptimeMs\":" + millis() + ",\"note\":" + noteJson(note) +
        ",\"metrics\":" + metricsJson(metrics) + ",\"rx\":{\"notes\":" + noteBytes +
        ",\"metrics\":" + metricsBytes + ",\"invalidNotes\":" + invalidNotes +
        ",\"invalidLines\":" + invalidLines + ",\"uartErrors\":" + uartErrors + "},\"events\":[";
    for (size_t i = 0; i < count; ++i) {
        if (i) json += ',';
        json += eventJson(batch[i]);
    }
    json += "]}";
    server.sendHeader("Cache-Control", "no-store");
    server.send(200, "application/json", json);
}
void setup() {
    Serial.begin(115200);
    telemetryMutex = xSemaphoreCreateMutex();
    if (!telemetryMutex) { Serial.println("Falha ao criar mutex"); abort(); }
    pinMode(NOTES_RX_PIN, INPUT_PULLUP);
    pinMode(METRICS_RX_PIN, INPUT_PULLUP);
    notesUart.setRxBufferSize(4096);
    metricsUart.setRxBufferSize(4096);
    // TX permanece sem ligacao com a FPGA; nao existem comandos de retorno no RTL.
    notesUart.begin(FPGA_BAUD, SERIAL_8N1, NOTES_RX_PIN, -1);
    metricsUart.begin(FPGA_BAUD, SERIAL_8N1, METRICS_RX_PIN, -1);
    notesUart.onReceiveError(uartError);
    metricsUart.onReceiveError(uartError);
    if (xTaskCreate(receiveTask, "fpga-rx", 4096, nullptr, 2, nullptr) != pdPASS) {
        Serial.println("Falha ao criar tarefa RX"); abort();
    }
    bootId = String(esp_random(), HEX);
    WiFi.mode(WIFI_AP_STA);
    WiFi.setAutoReconnect(true);
    if (!WiFi.softAP(AP_SSID, AP_PASSWORD)) { Serial.println("Falha ao iniciar AP"); abort(); }
    if (WIFI_SSID[0]) WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    server.on("/", HTTP_GET, []() {
        server.sendHeader("Cache-Control", "no-cache");
        server.send_P(200, "text/html; charset=utf-8", WEBAPP);
    });
    server.on("/api/events", HTTP_GET, eventsHandler);
    server.onNotFound([]() { server.send(404, "text/plain", "Nao encontrado"); });
    server.begin();
    Serial.printf("SensoPiano: Wi-Fi %s / senha %s\n", AP_SSID, AP_PASSWORD);
    Serial.print("Webapp: http://"); Serial.println(WiFi.softAPIP());
}
void loop() {
    server.handleClient();
    static bool connected = false;
    bool nowConnected = WiFi.status() == WL_CONNECTED;
    if (nowConnected && !connected) {
        Serial.print("Endereco na rede local: http://"); Serial.println(WiFi.localIP());
    }
    connected = nowConnected;
    delay(1);
}
