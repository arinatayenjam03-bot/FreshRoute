#include <Arduino.h>
#include <BluetoothSerial.h>
#include "DHT.h"

// ===== CONFIGURATION =====
#define DHTPIN 4
#define DHTTYPE DHT11
#define MQ135_PIN 34

#define RL 10.0              // Load resistor value in KOhms
#define CLEAN_AIR_FACTOR 3.6 // RS/R0 ratio in clean air (from datasheet)
#define SAMPLES 10           // Number of readings for ADC averaging

DHT dht(DHTPIN, DHTTYPE);
BluetoothSerial SerialBT;

// ===== GLOBAL VARIABLES =====
float R0 = 10.0;             // Sensor resistance in clean air
float baselineRatio = 0;     // Moving reference point for "normal" air

// ===== HELPER FUNCTIONS =====

/**
 * Reads the analog pin multiple times and returns the average.
 * This helps smooth out the ESP32's electrical noise.
 */
int readMQ135() {
  long sum = 0;
  for (int i = 0; i < SAMPLES; i++) {
    sum += analogRead(MQ135_PIN);
    delay(10);
  }
  return sum / SAMPLES;
}

/**
 * Converts ADC value to Sensor Resistance (Rs).
 * Formula based on voltage divider: Rs = ((Vcc/Vout) - 1) * RL
 */
float getRs(int adc) {
  if (adc == 0) return 0;
  // 4095.0 is the max resolution for ESP32 12-bit ADC
  return ((4095.0 / (float)adc) - 1.0) * RL;
}

/**
 * Calibrates the sensor by finding R0 in clean air.
 * Should ideally be run in a known fresh-air environment.
 */
float calibrate() {
  float rs = 0;
  for (int i = 0; i < 50; i++) {
    rs += getRs(readMQ135());
    delay(100);
  }
  rs /= 50;
  return rs / CLEAN_AIR_FACTOR;
}

/**
 * Power function to estimate gas concentration trends.
 * Note: These slopes are approximations based on datasheet log-log curves.
 */
float estimateGas(float ratio, float slope) {
  return pow(ratio, slope);
}

// ===== SETUP =====
void setup() {
  Serial.begin(115200);
  SerialBT.begin("ESP32_AirMonitor");
  dht.begin();

  // MQ sensors require a heater warm-up. 
  // For a real-world app, consider a 60-second countdown here.
  Serial.println("Warming up sensor...");
  delay(5000); 

  Serial.println("Calibrating R0...");
  R0 = calibrate();

  // Set the initial baseline for change detection
  baselineRatio = getRs(readMQ135()) / R0;

  Serial.println("System Ready.");
}

// ===== MAIN LOOP =====
void loop() {
  // 1. Environmental Data
  float temp = dht.readTemperature();
  float hum  = dht.readHumidity();

  // Skip loop if DHT fails to prevent bad math
  if (isnan(temp) || isnan(hum)) {
    Serial.println("DHT Sensor Error!");
    return;
  }

  // 2. Gas Sensor Readings
  int adc = readMQ135();
  float rs = getRs(adc);
  float ratio = rs / R0;

  // 3. Logic: Calculate % change from the moving baseline
  // A drop in Rs (resistance) usually indicates an increase in gas.
  float change = (baselineRatio - ratio) / baselineRatio;

  // 4. Gas Index Calculations (Relative values)
  float co2      = estimateGas(ratio, -2.7);
  float nh3      = estimateGas(ratio, -2.2);
  float benzene  = estimateGas(ratio, -2.5);

  // 5. Determine Air Quality Status
  String status = "CLEAN";
  if (change > 0.05) status = "LOW POLLUTION";
  if (change > 0.15) status = "MODERATE";
  if (change > 0.30) status = "HIGH";

  // 6. Output to Bluetooth
  SerialBT.println("---- AIR DATA ----");
  SerialBT.printf("Temp: %.1f C | Hum: %.1f %%\n", temp, hum);
  SerialBT.printf("CO2 idx: %.2f | NH3 idx: %.2f | Benzene idx: %.2f\n", 
                  co2, nh3, benzene);
  SerialBT.printf("Air Change: %.2f %% | Status: %s\n", 
                  change * 100, status.c_str());
  SerialBT.println("------------------\n");

  // 7. Baseline Adaptation (Low-pass filter)
  // This allows the "normal" level to drift slowly over time (e.g., weather changes)
  // while still reacting quickly to sudden spikes in pollution.
  baselineRatio = (baselineRatio * 0.98) + (ratio * 0.02);

  delay(2000); // 2-second update interval
}
