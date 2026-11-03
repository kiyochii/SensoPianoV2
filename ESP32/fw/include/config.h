#pragma once

// ESP32 classico / ESP32-WROOM DevKit. Ajuste para sua placa.
constexpr int NOTES_RX_PIN = 16;
constexpr int METRICS_RX_PIN = 17;
constexpr unsigned long FPGA_BAUD = 115200;
constexpr char AP_SSID[] = "SensoPiano";
constexpr char AP_PASSWORD[] = "sensopiano";  // Minimo de 8 caracteres.
// O AP permanece disponivel mesmo sem roteador.
constexpr char WIFI_SSID[] = "";
constexpr char WIFI_PASSWORD[] = "";
