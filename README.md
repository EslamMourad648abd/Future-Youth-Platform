# BBC Operations Platform

> An internal operations platform built with Flutter and Firebase for managing client onboarding, operational workflows, support activities, training, API tooling, and platform administration.

The **BBC Operations Platform** brings multiple internal workflows into a unified application with role-based access, modular feature areas, Firebase-backed services, and integrations with operational systems.

It has evolved from the original BBC API Tool into a broader internal platform supporting **operations, onboarding, support, training, administration, and API tooling**.

---

## Overview

The platform provides a centralized workspace for teams that operate and support Bevatel Business Chat services.

Rather than maintaining separate tools for individual operational processes, the platform combines them under a shared authentication, authorization, navigation, backend, and data architecture.

### Platform surfaces

| Platform                    | Purpose                                                                            |
| --------------------------- | ---------------------------------------------------------------------------------- |
| **BBC Operations Platform** | Master workspace providing access to the platform's operational modules            |
| **BBC Onboarding Platform** | Client onboarding, activation, verification, channel, chatbot, and group workflows |
| **BBC Support Platform**    | Support-oriented operational workspace                                             |
| **BEVATEL Training Portal** | Courses, lessons, quizzes, progress tracking, and certificates                     |
| **BBC API Tool**            | Internal API testing and operational API tooling                                   |

---

## Core Capabilities

### Client & Onboarding Management

The onboarding workspace provides a structured client lifecycle for operational teams.

Capabilities include:

* Client records and ownership
* Client workspaces
* Activation management
* Channel management
* Verification workflows
* Chatbot management
* Group management
* CRM-related information
* Client activity history
* Operational task management
* Reporting

The client workspace is organized into dedicated operational areas so that different parts of the onboarding process can be managed independently.

### Operational Workflows

The platform supports day-to-day operational activities through:

* Role-aware dashboards
* Client assignments
* Operational tasks
* Activity tracking
* Status management
* Client lifecycle workflows
* Operational reporting
* Administrative controls

The goal is to keep operational state centralized and make workflow ownership explicit.

### Training & Certification

The Training Portal provides an integrated learning environment for internal users.

It supports:

* Training dashboards
* Course catalogs
* Course details
* Lessons
* Video-based learning
* Quizzes
* Quiz review
* Progress tracking
* Course completion
* Certificate generation

Training progress is associated with authenticated users and tracked independently from the operational modules.

### API & Integration Tooling

The BBC API Tool provides internal tooling for working with platform APIs and integrations.

It is designed to support operational and technical workflows such as:

* API testing
* Request/response inspection
* Integration troubleshooting
* API documentation
* Internal operational utilities

Sensitive API operations are handled through backend services where appropriate rather than exposing privileged credentials directly in the client application.

### Administration & Analytics

Administrative functionality provides centralized management of platform resources.

Administrative areas include:

* User management
* Role management
* Training management
* Analytics
* Meta/WhatsApp administration
* Platform logging
* Administrative operations

Access to these areas is controlled through role-based authorization.

---

## Platform Architecture

The platform follows a modular Flutter architecture backed by Firebase services and server-side integrations.

### High-Level Architecture

```text
                         ┌─────────────────────┐
                         │       Users         │
                         └──────────┬──────────┘
                                    │
                                    ▼
                    ┌─────────────────────────────┐
                    │      Flutter Application    │
                    │                             │
                    │  Operations │ Support      │
                    │  Onboarding │ Training     │
                    │  API Tool   │ Admin        │
                    └─────────────┬───────────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
                    ▼             ▼             ▼
             ┌────────────┐ ┌────────────┐ ┌────────────┐
             │   Firebase │ │  Firestore │ │  Storage   │
             │    Auth    │ │            │ │            │
             └────────────┘ └────────────┘ └────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ Cloud Functions │
                         │   Backend Layer │
                         └────────┬────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              ▼                   ▼                   ▼
       ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
       │   Bevatel   │     │ Meta/WhatsApp│     │  Zoho CRM  │
       │     API     │     │  Integrations │     │             │
       └─────────────┘     └─────────────┘     └─────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ Google Services │
                         │ & Other APIs    │
                         └─────────────────┘
```

### Application Layer

The frontend is built with:

* Flutter
* Dart
* Material UI
* GoRouter
* Feature-based module organization

The application is structured around platform modules rather than treating the entire application as one large feature.

### Backend Layer

Firebase provides the primary backend infrastructure:

* Firebase Authentication
* Cloud Firestore
* Firebase Cloud Functions
* Firebase Storage
* Firebase Admin SDK

Cloud Functions are used for backend-controlled operations, privileged workflows, integrations, and operations that should not be executed directly from the client.

### Integration Layer

The platform integrates with external systems where required by operational workflows, including:

* Bevatel APIs
* Meta / WhatsApp services
* Zoho CRM
* Google APIs
* PDF generation services
* Other backend-connected services

Integration logic is kept behind the appropriate application/backend boundaries rather than exposing external credentials to the Flutter client.

---

## Platform Model

The application supports multiple platform surfaces while sharing the same underlying infrastructure.

### Master Platform

**BBC Operations Platform**

The primary application surface.

It provides access to the platform's available modules based on the authenticated user's role and permissions.

### Onboarding Platform

**BBC Onboarding Platform**

Focused on client onboarding and operational activation workflows.

Typical areas include:

* Dashboard
* Clients
* Client workspace
* Activation
* Channels
* Verification
* Chatbot
* Group
* Activity
* Tasks
* Reports

### Support Platform

**BBC Support Platform**

Provides a dedicated workspace for support-oriented workflows while using the same authentication and backend infrastructure.

### Training Portal

**BEVATEL Training Portal**

Provides the internal training experience for courses, lessons, quizzes, progress tracking, and certificates.

### API Tool

**BBC API Tool**

Provides internal API testing, documentation, and technical operational tooling.

---

## Access & Roles

Access is controlled through authenticated user roles and platform-aware navigation.

### Super Admin

Provides the highest level of administrative access across the platform.

Typical capabilities include:

* User administration
* Platform administration
* Operational administration
* Analytics and reporting
* Training administration
* Privileged configuration
* Administrative integrations

### Onboarding Agent

Provides access to onboarding-related operational workflows according to the user's assigned permissions.

Typical capabilities include:

* Client management
* Client onboarding
* Activation workflows
* Verification
* Channel management
* Chatbot and group workflows
* Operational tasks
* Client activity

### Support Agent

Provides access to support-oriented platform functionality and the API tooling available to the role.

### Trainee

Provides access to the training environment and its associated learning workflows.

> Authorization is enforced through the application's authentication and role model. UI visibility should not be treated as the only security boundary; privileged operations are handled through backend authorization where required.

---

## Client Workspace

The client workspace is the primary operational area of the onboarding platform.

A client record can be managed through dedicated sections rather than a single large edit form.

### Overview

Provides a consolidated view of the client's current operational state.

Includes areas such as:

* Client information
* Ownership
* Status
* Integration information
* Group information
* Channels
* CRM information
* Record metadata

### Activation

Manages activation-related information and workflow state.

### Channels

Provides channel-level operational information for the client.

### Verification

Supports verification workflows and their associated checklist/state.

### Chatbot

Provides operational management of chatbot-related configuration and status.

### Group

Tracks operational group information and lifecycle state.

### Activity

Provides visibility into relevant client activity and operational history.

---

## Authentication & Authorization

Authentication is handled through **Firebase Authentication**.

Authorization is implemented through application roles and backend-aware access control.

The platform uses role-aware routing and platform configuration to determine which application areas are available to an authenticated user.

The authorization model is designed around the principle that:

```text
Authentication
      ↓
Identify User
      ↓
Resolve Role
      ↓
Resolve Platform Access
      ↓
Resolve Route Access
      ↓
Perform Authorized Operation
```

Privileged operations should be executed through trusted backend services rather than relying exclusively on client-side restrictions.

---

## Technology Stack

| Layer               | Technology                                    |
| ------------------- | --------------------------------------------- |
| Frontend            | Flutter / Dart                                |
| UI                  | Flutter Material                              |
| Navigation          | GoRouter                                      |
| Authentication      | Firebase Authentication                       |
| Database            | Cloud Firestore                               |
| Backend             | Firebase Cloud Functions                      |
| Storage             | Firebase Storage                              |
| Server SDK          | Firebase Admin SDK                            |
| External APIs       | Bevatel, Meta/WhatsApp, Zoho CRM, Google APIs |
| Document Generation | PDF generation                                |
| Web Hosting         | Firebase Hosting                              |

---

## Project Structure

The main application is organized into feature-oriented modules.

```text
lib/
├── admin_console/
│   ├── analytics/
│   ├── meta_admin/
│   ├── training_management/
│   └── users/
│
├── login/
│
├── modules/
│   ├── bbc_api_tool/
│   ├── operations/
│   │   └── onboarding/
│   └── ...
│
├── platform/
│   ├── configuration/
│   └── ...
│
├── router/
│
├── services/
│
├── training/
│
└── functions/
```

Backend functionality is maintained separately under:

```text
functions/
```

Additional project-level directories contain platform targets, deployment configuration, scripts, Firebase configuration, assets, and supporting application resources.

---

## Application Navigation

Navigation is handled through **GoRouter** with platform- and role-aware routing.

The application separates:

* Authentication routes
* Platform entry points
* Operational routes
* Client workspace routes
* Training routes
* Administration routes
* API tooling routes

Detailed route documentation should be maintained separately from this README as the application continues to evolve.

This keeps the README focused on the platform architecture rather than turning it into a route reference.

---

## Development Setup

### Prerequisites

The development environment requires:

* Flutter SDK
* Dart SDK
* Node.js
* npm
* Firebase CLI
* A configured Firebase project
* Appropriate access to required external services

Flutter and Node.js versions should follow the versions configured by the project and its deployment environment.

### Flutter

Install Flutter dependencies:

```bash
flutter pub get
```

Run the application locally:

```bash
flutter run
```

For web development:

```bash
flutter run -d chrome
```

### Firebase Functions

Install backend dependencies:

```bash
cd functions
npm install
```

Return to the project root when finished:

```bash
cd ..
```

### Local Development

Before running the full platform locally, ensure that:

1. Firebase configuration is available.
2. Required authentication configuration is valid.
3. Backend dependencies are installed.
4. Required external integrations are configured.
5. Local development credentials are not committed to source control.

---

## Configuration

The platform depends on Firebase configuration and external service configuration.

### Firebase

Firebase is used for:

* Authentication
* Firestore
* Cloud Functions
* Storage
* Hosting

Project-specific Firebase configuration is maintained through the repository's Firebase configuration files.

### Environment & Secrets

Secrets and privileged credentials must remain outside the source-controlled application code.

Examples include:

* API credentials
* Service account credentials
* External integration secrets
* Backend authentication tokens
* Private configuration values

Sensitive configuration should be supplied through the appropriate deployment/runtime configuration mechanism.

### External Integrations

External services should be configured independently from the Flutter application's public configuration whenever credentials or privileged access are involved.

The Flutter client should not contain secrets that provide unrestricted access to external systems.

---

## Deployment

The project is configured for Firebase-based deployment and platform-specific web builds.

Deployment may involve:

1. Building the required Flutter platform surface.
2. Applying the appropriate platform configuration.
3. Deploying Firebase Hosting resources.
4. Deploying Cloud Functions when backend changes are included.
5. Verifying authentication, routing, integrations, and cache behavior after deployment.

The repository contains deployment configuration and scripts used to support the platform's deployment workflow.

### Deployment Considerations

Before deploying changes, verify:

* Flutter build succeeds
* Static analysis passes
* Firebase configuration is correct
* Cloud Functions compile successfully
* Required backend configuration exists
* Firestore/Storage rules are appropriate
* Authentication and role-based access still behave correctly
* Platform-specific routing works
* External integrations remain functional

---

## Security

Security is treated as an architectural concern rather than only a UI concern.

### Authentication

Firebase Authentication provides the identity layer for platform users.

### Authorization

Application access is controlled through user roles and platform permissions.

Sensitive backend operations should additionally validate authorization on the server.

### Secrets & Credentials

Credentials and privileged secrets must not be committed to the repository.

Do not store:

* API keys with privileged access
* Service account files
* Access tokens
* Private certificates
* External integration secrets

in source-controlled files.

### Backend Operations

Operations involving privileged credentials or trusted external services should be routed through backend services where appropriate.

This prevents the Flutter application from becoming the security boundary for operations that require trusted credentials.

---

## Engineering Practices

The project follows several engineering principles intended to keep the platform maintainable as its scope grows.

### Modular Architecture

Major business areas are separated into feature modules rather than being implemented as one monolithic application layer.

### Separation of Responsibilities

UI, routing, platform configuration, services, backend functionality, and feature-specific workflows are maintained as separate concerns where practical.

### Role-Aware Navigation

Navigation and platform availability are derived from authenticated user context and role configuration.

### Backend-First Sensitive Operations

Privileged operations and external integrations should be handled through trusted backend services when client-side execution would expose credentials or bypass server-side authorization.

### Reusable Platform Infrastructure

Multiple platform surfaces share common infrastructure instead of maintaining completely independent applications.

This allows authentication, backend services, data models, and shared services to evolve centrally.

---

## Current Platform Status

The project is actively developed as an internal operations platform.

It has evolved from the original **BBC API Tool** into a broader system covering:

* Operations
* Client onboarding
* Support workflows
* Training
* API tooling
* Administration
* Analytics
* External integrations

The architecture continues to evolve as additional operational workflows are migrated into the platform.

---

## Documentation

The README provides the high-level platform overview and development entry point.

More detailed documentation can be maintained separately for areas such as:

* Architecture decisions
* Route reference
* Data models
* Firebase collections
* Cloud Functions
* External integrations
* Deployment procedures
* Operational workflows
* Development standards

This keeps the main README readable while allowing technical documentation to grow independently with the platform.

---

## Repository Structure

At the repository level, the project contains the Flutter application, Firebase backend, deployment configuration, platform assets, scripts, and supporting project resources.

The main areas include:

```text
.
├── android/
├── assets/
├── functions/
├── ios/
├── lib/
├── linux/
├── macos/
├── public/
├── scripts/
├── test/
├── web/
├── windows/
│
├── .firebaserc
├── firebase.json
├── pubspec.yaml
├── package.json
├── README.md
└── ...
```

---

## Internal Use

This platform is intended for internal operational use.

Access, deployment, credentials, integrations, and platform data should be managed according to the organization's internal security and operational policies.
