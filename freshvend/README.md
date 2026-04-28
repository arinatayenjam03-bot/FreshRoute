# FreshRoute Flutter App [freshvend]

> **Mobile & Web Interface for AI-Powered Farmer Produce Routing**

The FreshRoute Flutter application provides farmers with a user-friendly interface to monitor produce freshness, receive AI-powered routing recommendations, and track deliveries in real-time. Built with Flutter for cross-platform support (iOS, Android, Web, Desktop).

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Screenshots & Demo](#screenshots--demo)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation & Setup](#installation--setup)
- [Configuration](#configuration)
- [Running the App](#running-the-app)
- [App Screens & Usage](#app-screens--usage)
- [State Management](#state-management)
- [API Integration](#api-integration)
- [Firebase Integration](#firebase-integration)
- [Geolocation & Permissions](#geolocation--permissions)
- [Troubleshooting](#troubleshooting)
- [Development Guidelines](#development-guidelines)
- [Building for Production](#building-for-production)

---

## Overview

The **FreshRoute Flutter App** is the frontend interface connecting farmers directly to the backend AI system. It enables:

✓ Real-time sensor data visualization (temperature, humidity, gas levels)  
✓ AI-powered route optimization powered by CrewAI and Ollama  
✓ Location-aware vendor recommendations  
✓ Weather-integrated route planning  
✓ On-the-go order management and tracking  
✓ Profit analytics and business insights  
✓ Regional market intelligence and news  

Built using **Provider** for state management and **HTTP** for backend communication.

---

## Features

### Core Features

| Feature | Description |
|---------|-------------|
| **Freshness Dashboard** | Real-time sensor readings with visual urgency indicators |
| **Vendor Marketplace** | Browse nearby buyers with demand and pricing info |
| **Route Analyzer** | AI generates optimal delivery sequences based on freshness & weather |
| **Navigation Integration** | One-tap integration with Google Maps & Apple Maps |
| **Order Management** | Track pending, active, and completed deliveries |
| **Market Intelligence** | Regional price trends, weather alerts, and road updates |
| **Profit Insights** | Cost-benefit analysis with fuel calculations |
| **Multi-Platform** | Native experience on iOS, Android, Web, and Desktop |
| **Offline Support** | Cached data available when network unavailable |
| **Real-time Sync** | Firebase Firestore live data synchronization |

---

## Screenshots & Demo

### Video Demo

Watch the full app walkthrough:

[![FreshRoute App Demo](https://img.youtube.com/vi/eqnd0IeCWjM/maxresdefault.jpg)](https://youtu.be/eqnd0IeCWjM)

**[Watch Full Demo on YouTube](https://youtu.be/eqnd0IeCWjM)** — 5-minute walkthrough showing all key features

### App Screens

#### Farmer Dashboard

| Screen | Purpose |
|--------|---------|
| **Dashboard** | Home screen with freshness score, urgency status, and quick actions |
| **Vendor Selection** | Browse all available buyers with demand and location |
| **Route Analysis** | AI-generated optimal delivery sequence with maps |
| **Delivery Tracking** | Real-time tracking of active delivery orders |
| **Market News** | Regional updates on prices, weather, and logistics |
| **Profit Insights** | Financial analysis of completed deliveries |

---

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **UI Framework** | Flutter 3.8+ | Cross-platform mobile/web app |
| **Language** | Dart | Flutter's programming language |
| **State Management** | Provider 6.1.2 | Simple, scalable state management |
| **HTTP Client** | http 1.2.1 | Backend API communication |
| **Geolocation** | geolocator 11.0.0 | GPS and location services |
| **Maps** | google_maps_flutter | Route visualization |
| **Bluetooth** | flutter_blue_plus 1.31.0 | IoT sensor connectivity |
| **Storage** | shared_preferences 2.2.3 | Local data persistence |
| **Date/Time** | intl 0.19.0 | Localization and formatting |
| **Web View** | webview_flutter 4.7.0 | Embedded browser content |
| **URL Launcher** | url_launcher 6.3.0 | Deep linking to apps/URLs |

---

## Project Structure
