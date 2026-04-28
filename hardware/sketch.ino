#include <Arduino.h>
#include <BluetoothSerial.h>
#include "DHT.h"

// ===== CONFIG =====
#define DHTPIN 4
#define DHTTYPE DHT11
#define MQ135_PIN 34

#define RL 10.0
#define CLEAN_AIR_FACTOR 3.6

#define SAMPLES 10

DHT dht(DHTPIN, DHTTYPE);
BluetoothSerial SerialBT;

// ===== VARIABLES =====
float R0 = 10.0;
float baselineRatio = 0;

// ===== FUNCTIONS =====

// Average ADC for stability
int readMQ135() {
  long sum = 0;
  for (int i = 0; i < SAMPLES; i++) {
    sum += analogRead(MQ135_PIN);
    delay(10);
  }
  return sum / SAMPLES;
}

// Convert ADC to resistance
float getRs(int adc) {
  if (adc == 0) return 0;
  return ((4095.0 / adc) - 1.0) * RL;
}

// Calibration
float calibrate() {
  float rs = 0;
  for (int i = 0; i < 50; i++) {
    rs += getRs(readMQ135());
    delay(100);
  }
  rs /= 50;
  return rs / CLEAN_AIR_FACTOR;
}

// Relative gas estimation (normalized)
float estimateGas(float ratio, float slope) {
  return pow(ratio, slope);
}

// ===== SETUP =====
void setup() {
  Serial.begin(115200);
  SerialBT.begin("ESP32_AirMonitor");

  dht.begin();

  Serial.println("Calibrating...");
  R0 = calibrate();

  // Initial baseline
  baselineRatio = getRs(readMQ135()) / R0;

  Serial.println("Ready.");
}

// ===== LOOP =====
void loop() {

  // --- Read DHT ---
  float temp = dht.readTemperature();
  float hum  = dht.readHumidity();

  if (isnan(temp) || isnan(hum)) return;

  // --- Read MQ135 ---
  int adc = readMQ135();
  float rs = getRs(adc);
  float ratio = rs / R0;

  // --- Normalize change ---
  float change = (baselineRatio - ratio) / baselineRatio;

  // --- Estimate gases (relative) ---
  float co2      = estimateGas(ratio, -2.7);
  float nh3      = estimateGas(ratio, -2.2);
  float benzene  = estimateGas(ratio, -2.5);

  // --- Intelligent detection ---
  String status = "CLEAN";

  if (change > 0.05) status = "LOW POLLUTION";
  if (change > 0.15) status = "MODERATE";
  if (change > 0.30) status = "HIGH";

  // --- Bluetooth Output ---
  SerialBT.println("---- AIR DATA ----");
  SerialBT.printf("Temp: %.1f C | Hum: %.1f %%\n", temp, hum);

  SerialBT.printf("CO2 idx: %.2f | NH3 idx: %.2f | Benzene idx: %.2f\n",
                  co2, nh3, benzene);

  SerialBT.printf("Air Change: %.2f %% | Status: %s\n",
                  change * 100, status.c_str());

  SerialBT.println("------------------\n");

  // Slowly adapt baseline (prevents drift issues)
  baselineRatio = baselineRatio * 0.98 + ratio * 0.02;

  delay(2000);
}
