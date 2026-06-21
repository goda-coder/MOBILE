# Payment Biometric System - Backend Node.js Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Technology Stack](#technology-stack)
4. [Project Structure](#project-structure)
5. [Core Components](#core-components)
6. [API Endpoints](#api-endpoints)
7. [Authentication System](#authentication-system)
8. [Wallet & Balance Management](#wallet--balance-management)
9. [Payment Processing](#payment-processing)
10. [KYC (Know Your Customer)](#kyc-know-your-customer)
11. [Fingerprint Authentication](#fingerprint-authentication)
12. [Chat System](#chat-system)
13. [Data Storage](#data-storage)
14. [Error Handling](#error-handling)

---

## Project Overview

**Wallet Backend** is a Node.js Express-based backend service for a Flutter mobile wallet application. It provides a comprehensive payment processing system with biometric authentication, KYC verification, and wallet management capabilities. The system supports multiple user roles (Customer, Merchant, Admin) and integrates with ZK fingerprint readers for secure authentication.

### Key Features
- **User Management**: Registration, login, and profile management
- **Wallet Services**: Balance tracking, transfers, and transactions
- **Payment Processing**: Support for card, wallet, and fingerprint payment methods
- **Biometric Authentication**: Integration with ZK9500 fingerprint readers
- **KYC Verification**: Document verification with liveness detection
- **Chat System**: Communication between customers and support/admins
- **Admin Dashboard**: Management of KYC requests and user transactions
- **Fraud Detection**: Transaction monitoring and security checks

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter Mobile App (Client)                  │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTP/REST
┌────────────────────────────▼────────────────────────────────────┐
│              Express.js Backend API (Port 8081)                 │
├──────────────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Routes Layer (API Endpoints)                               │ │
│ │  - Auth, Wallet, Payments, KYC, Fingerprint, Chat         │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                            │                                     │
│ ┌─────────────────────────▼─────────────────────────────────┐   │
│ │ Middleware Layer                                         │   │
│ │ - Authentication (JWT Token Verification)               │   │
│ │ - Fraud Detection                                        │   │
│ └─────────────────────────────────────────────────────────────┘   │
│                            │                                     │
│ ┌─────────────────────────▼─────────────────────────────────┐   │
│ │ Controllers & Services Layer                             │   │
│ │ - Payment Service (initiate, confirm)                    │   │
│ │ - Fingerprint Controller (enroll, verify)                │   │
│ └─────────────────────────────────────────────────────────────┘   │
│                            │                                     │
│ ┌─────────────────────────▼─────────────────────────────────┐   │
│ │ Data Store (In-Memory Maps)                              │   │
│ │ - Users, Wallets, Transactions, KYC Requests            │   │
│ └─────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
                             │
        ┌────────────────────┴────────────────────┐
        │                                          │
        ▼                                          ▼
┌────────────────────────────┐        ┌────────────────────────────┐
│  ZK9500 Fingerprint        │        │  Python ZK Service        │
│  Reader Device             │        │  (http://localhost:5005)   │
└────────────────────────────┘        └────────────────────────────┘
```

---

## Technology Stack

### Backend Framework
- **Express.js** (v4.18.4): Web framework for Node.js
- **Node.js** with ES Modules (type: "module")

### Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| `express` | ^4.18.4 | Web server framework |
| `axios` | ^1.18.0 | HTTP client for external API calls |
| `jsonwebtoken` | ^9.0.2 | JWT token generation and verification |
| `bcryptjs` | ^2.4.3 | Password hashing and comparison |
| `cors` | ^2.8.5 | Cross-Origin Resource Sharing middleware |
| `multer` | ^1.4.5-lts.1 | File upload handling for KYC documents |
| `uuid` | ^9.0.1 | Unique ID generation |
| `dotenv` | ^17.4.2 | Environment variable management |

### Data Storage
- **In-Memory Maps**: No external database (development/testing)
- Built-in JavaScript Maps for:
  - Users
  - Wallets
  - Transactions
  - KYC Requests
  - Chat Messages
  - Fingerprints
  - Refresh Tokens

---

## Project Structure

```
backend-node/
├── index.js                          # Main server entry point
├── store.js                          # In-memory data store with all data operations
├── package.json                      # Dependencies and scripts
├── .env                              # Environment variables (not tracked)
│
├── middleware/
│   ├── auth.js                       # JWT authentication middleware
│   └── fraudDetection.js             # Fraud detection logic
│
├── routes/                           # API route handlers
│   ├── auth.js                       # Authentication (login, register, refresh)
│   ├── wallet.js                     # Wallet operations (summary, transfers)
│   ├── payments.js                   # Payment checkout and status
│   ├── fingerprint.js                # Fingerprint payment authentication
│   ├── fingerprintRoutes.js          # Fingerprint device management
│   ├── kyc.js                        # KYC document submission & verification
│   ├── admin.js                      # Admin KYC management
│   └── chat.js                       # Chat messaging system
│
├── controllers/
│   ├── paymentController.js          # Payment initiation and confirmation logic
│   └── fingerprintController.js      # Fingerprint device communication
│
├── services/
│   └── paymentService.js             # Payment business logic & transaction handling
│
└── test_integration.mjs              # Integration tests
```

---

## Core Components

### 1. **index.js** - Main Application Server

The entry point that initializes the Express server and configures all routes.

```javascript
// Key Responsibilities:
- Initialize Express app
- Enable CORS for cross-origin requests
- Parse JSON and URL-encoded request bodies
- Mount all route handlers
- Start HTTP server on port 8081
```

**Port Configuration**: `process.env.PORT || 8081`

---

### 2. **store.js** - In-Memory Data Store

Central repository for all data operations using JavaScript Maps. Provides functions for user management, wallet operations, transaction handling, and KYC processing.

#### Data Structures

**Users Map**
```javascript
Map<userId: string, {
  userId: string (UUID),
  fullName: string,
  email: string,
  phoneNumber: string,
  passwordHash: string (bcryptjs hashed),
  role: 'customer' | 'merchant' | 'admin'
}>
```

**Wallets Map**
```javascript
Map<userId: string, {
  walletId: string (UUID),
  balanceMinor: number (amount in minor units, 1 EGP = 100 minor units),
  currency: 'EGP',
  isKycVerified: boolean,
  kycStatus: string
}>
```

**Operations Map** (Transaction History)
```javascript
Map<userId: string, Array<{
  id: string (UUID),
  type: 'transfer_in' | 'transfer_out' | 'topup' | 'refund' | 'payment_intent',
  description: string,
  amountMinor: number,
  currency: string,
  relatedId: string | null,
  createdAt: ISO 8601 timestamp
}>>
```

**KYC Requests Map**
```javascript
Map<kycRequestId: string, {
  id: string (UUID),
  userId: string,
  fullName: string,
  phoneNumber: string,
  documentType: string,
  status: 'Pending' | 'Verified' | 'Rejected',
  matchPercentage: number (0-1),
  warnings: Array<string>,
  submittedAt: ISO 8601 timestamp,
  decidedAt: ISO 8601 timestamp | null,
  decisionReason: string | null
}>
```

**Chat Messages Map**
```javascript
Map<userId: string, Array<{
  id: string (UUID),
  userId: string (conversation owner),
  senderId: string (who sent the message),
  senderRole: string ('customer' | 'merchant' | 'admin'),
  content: string,
  createdAt: ISO 8601 timestamp
}>>
```

**Fingerprints Map**
```javascript
Map<fingerprintId: string, {
  fingerprintId: string (UUID),
  userId: string,
  deviceModel: string (default: 'ZK9500'),
  enrolledAt: ISO 8601 timestamp
}>
```

#### Key Functions

| Function | Purpose |
|----------|---------|
| `createUser()` | Register new user with role validation |
| `findUserByEmail/Phone/Name()` | Search users with normalized comparison |
| `getUserById()` | Retrieve user by ID |
| `getWallet()` | Get user's wallet information |
| `addOperation()` | Record transaction/operation |
| `getWalletTransactions()` | Get filtered transaction history |
| `createTransaction()` | Create payment transaction |
| `atomicTransfer()` | Thread-safe fund transfer with lock |
| `createKycRequest()` | Submit KYC verification request |
| `updateKycRequest()` | Update KYC request status |
| `attachFingerprintToUser()` | Link fingerprint to user |

#### Seed Data
Two users are automatically created on startup:
1. **Admin User**: `admin@wallet.local` / `+201000000001`
2. **Merchant User**: `merchant@wallet.local` / `+201000000002`

Both accounts have initial wallets with 1,000 EGP (100,000 minor units).

---

## API Endpoints

### Base URL
```
http://localhost:8081
```

### Response Format

**Success Response**
```json
{
  "data": "response-specific data",
  "status": 200
}
```

**Error Response**
```json
{
  "code": "ERROR_CODE",
  "message": "Error description"
}
```

---

## Authentication System

### 1. Authentication Routes (`/api/v1/auth`)

#### Register User
**POST** `/api/v1/auth/register`

Create a new user account with email, phone, and password.

**Request Body**
```json
{
  "fullName": "Ahmed Hassan",
  "email": "ahmed@example.com",
  "phoneNumber": "+201123456789",
  "password": "SecurePass123!",
  "role": "customer"  // Optional: 'customer', 'merchant', 'admin' (default: 'customer')
}
```

**Response** (201 Created)
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "role": "Customer",
  "phoneNumber": "+201123456789",
  "userId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error Cases**
- `400`: Missing required fields (fullName, email, phoneNumber, password)
- `400`: Invalid role (must be customer, merchant, or admin)
- `409`: User already exists (by email, phone, or name)

---

#### Login with Credentials
**POST** `/api/v1/auth/login`

Authenticate user with phone number and password.

**Request Body**
```json
{
  "phoneNumber": "+201123456789",
  "password": "SecurePass123!"
}
```

**Response** (200 OK)
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "role": "Customer",
  "email": "ahmed@example.com",
  "userId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error Cases**
- `400`: Missing phone number or password
- `401`: Invalid credentials (phone or password incorrect)

---

#### Fingerprint Login
**POST** `/api/v1/auth/login-fingerprint`

Authenticate user using biometric fingerprint match.

**Request Body**
```json
{
  "fingerprintId": "550e8400-e29b-41d4-a716-446655440000",
  "matched": true
}
```

**Response** (200 OK)
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "role": "Customer",
  "phoneNumber": "+201123456789",
  "userId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error Cases**
- `400`: Missing fingerprintId
- `401`: Fingerprint not matched
- `404`: Fingerprint not registered or user not found

---

#### Refresh Access Token
**POST** `/api/v1/auth/refresh`

Get a new access token using a valid refresh token.

**Request Body**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response** (200 OK)
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Error Cases**
- `400`: Missing refresh token
- `401`: Invalid or expired refresh token

---

#### Logout
**POST** `/api/v1/auth/logout`

Revoke the refresh token to invalidate future refresh requests.

**Request Body**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response** (204 No Content)

---

### 2. Authentication Middleware (`middleware/auth.js`)

All protected routes require a valid JWT token in the Authorization header.

**Header Format**
```
Authorization: Bearer <accessToken>
```

**Token Payload** (JWT)
```json
{
  "sub": "userId",           // Subject (user ID)
  "role": "customer",        // User role
  "email": "user@example.com",
  "iat": 1234567890,         // Issued at
  "exp": 1234571490         // Expiration time
}
```

**Token Configuration** (Environment Variables)
- `JWT_SECRET`: Secret key for signing tokens (default: 'secret')
- `ACCESS_TOKEN_EXPIRES_IN`: Access token expiration (default: '1h')
- `REFRESH_TOKEN_EXPIRES_IN`: Refresh token expiration (default: '7d')

---

## Wallet & Balance Management

### 1. Wallet Routes (`/api/v1/wallet`)

All wallet endpoints require authentication.

#### Get Wallet Summary
**GET** `/api/v1/wallet/summary`

Retrieve wallet balance and KYC status.

**Response** (200 OK)
```json
{
  "walletId": "550e8400-e29b-41d4-a716-446655440000",
  "balanceMinor": 500000,      // 5000 EGP
  "currency": "EGP",
  "isKycVerified": true,
  "kycStatus": "Verified"
}
```

---

#### Get Wallet Transactions
**GET** `/api/v1/wallet/transactions`

Get filtered transaction history (transfer_in, transfer_out, topup, refund).

**Response** (200 OK)
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "kind": "transfer_out",
    "description": "Transfer to John Doe",
    "amountMinor": 10000,
    "currency": "EGP",
    "reference": "ref-123",
    "status": "Completed",
    "createdAt": "2024-06-20T10:30:00Z"
  },
  {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "kind": "transfer_in",
    "description": "Received transfer from Jane Smith",
    "amountMinor": 50000,
    "currency": "EGP",
    "reference": "ref-124",
    "status": "Completed",
    "createdAt": "2024-06-20T11:00:00Z"
  }
]
```

---

#### Get Wallet Report
**GET** `/api/v1/wallet/report` or `/api/v1/wallet/reports`

Get detailed wallet and all operations (includes all transaction types).

**Response** (200 OK)
```json
{
  "wallet": {
    "walletId": "550e8400-e29b-41d4-a716-446655440000",
    "balanceMinor": 500000,
    "currency": "EGP",
    "isKycVerified": true,
    "kycStatus": "Verified"
  },
  "operations": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "kind": "payment_intent",
      "description": "Started fingerprint payment FP-A1B2C3D4",
      "amountMinor": 100000,
      "currency": "EGP",
      "reference": null,
      "status": "Completed",
      "createdAt": "2024-06-20T10:30:00Z"
    }
  ]
}
```

---

#### Transfer Funds
**POST** `/api/v1/wallet/transfer`

Send money to another user using email, phone, or wallet ID.

**Request Body**
```json
{
  "recipientIdentifier": "ahmed@example.com",  // Can be email, phone, or walletId
  "amountMinor": 10000,                        // 100 EGP
  "currency": "EGP",                          // Optional
  "reference": "INV-001",                     // Required for tracking
  "description": "Payment for services"       // Optional
}
```

**Response** (200 OK)
```json
{
  "transactionId": "550e8400-e29b-41d4-a716-446655440000",
  "newBalanceMinor": 490000
}
```

**Error Cases**
- `400`: Missing required fields or insufficient funds
- `403`: KYC verification required before transfer
- `404`: Recipient not found

**Security Requirements**
- Sender must be KYC verified
- Atomic transfer with concurrency lock
- Both parties get operation records

---

## Payment Processing

### 1. Payment Routes (`/api/v1/payments`)

All payment endpoints require authentication and KYC verification.

#### Checkout - Create Payment Intent
**POST** `/api/v1/payments/checkout`

Initiate a payment with one of three methods: card, wallet, or fingerprint.

**Request Body**
```json
{
  "amountMinor": 50000,                    // 500 EGP
  "method": "fingerprint",                 // 'card', 'wallet', 'fingerprint'
  "firstName": "Ahmed",
  "lastName": "Hassan",
  "email": "ahmed@example.com",
  "phoneNumber": "+201123456789",
  "currency": "EGP",                       // Optional
  "walletPhoneNumber": "+201123456789"     // For wallet method
}
```

**Response - Card Method** (200 OK)
```json
{
  "paymentIntentId": "550e8400-e29b-41d4-a716-446655440000",
  "orderReference": "ORD-A1B2C3D4",
  "iframeUrl": "https://checkout.example.com/550e8400...",
  "walletRedirectUrl": null
}
```

**Response - Wallet Method** (200 OK)
```json
{
  "paymentIntentId": "550e8400-e29b-41d4-a716-446655440000",
  "orderReference": "ORD-A1B2C3D4",
  "iframeUrl": null,
  "walletRedirectUrl": "walletapp://pay/550e8400..."
}
```

**Response - Fingerprint Method** (200 OK)
```json
{
  "paymentIntentId": "550e8400-e29b-41d4-a716-446655440000",
  "orderReference": "FP-A1B2C3D4",
  "iframeUrl": null,
  "walletRedirectUrl": null,
  "paymentDevice": "ZK9500",
  "paymentNote": "Authenticate using ZK9500 fingerprint reader to complete this payment.",
  "deviceAuthRequired": true
}
```

**Error Cases**
- `400`: Missing required fields or amount < 10 EGP for fingerprint
- `403`: KYC verification required

---

#### Get Payment Status
**GET** `/api/v1/payments/status/:paymentIntentId`

Check the status of a payment intent.

**Response** (200 OK)
```json
{
  "paymentIntentId": "550e8400-e29b-41d4-a716-446655440000",
  "orderReference": "FP-A1B2C3D4",
  "method": "fingerprint",
  "status": "AWAITING_DEVICE_AUTH",
  "deviceAuthRequired": true,
  "paymentDevice": "ZK9500",
  "paymentNote": "Authenticate using ZK9500 fingerprint reader to complete this payment."
}
```

---

### 2. Payment Service (`services/paymentService.js`)

Handles the business logic for payment initiation and confirmation.

#### Initiate Payment
```javascript
initiatePayment({ merchantId, targetUserId, amount })
```

- Validates merchant and target user exist
- Creates transaction record with PENDING status
- Records operation in merchant's history
- Returns transaction object

#### Confirm Payment
```javascript
confirmPayment({ transactionId, verificationToken })
```

**Process Flow**
1. Verify JWT token contains matching transaction ID
2. Check transaction exists and is in PENDING state
3. Run fraud detection check
4. Perform atomic transfer from user to merchant
5. Update transaction status to SUCCESS
6. Record operation for both parties
7. Return receipt with completion details

**Error Handling**
- Invalid verification token: `403 INVALID_VERIFICATION_TOKEN`
- Transaction not found: `404 TRANSACTION_NOT_FOUND`
- Transaction mismatch: `403 TOKEN_MISMATCH`
- Fraud detected: `403 FRAUD_BLOCKED`
- Transfer failed: `400 TRANSFER_FAILED`

---

### 3. Merchant Payment Routes

#### Initiate Payment (Merchant)
**POST** `/api/payments/initiate`

**Request Body**
```json
{
  "merchant_id": "550e8400-e29b-41d4-a716-446655440000",
  "target_user_id": "550e8400-e29b-41d4-a716-446655440001",
  "amount": 50000
}
```

**Response** (201 Created)
```json
{
  "transaction_id": "550e8400-e29b-41d4-a716-446655440002",
  "status": "PENDING"
}
```

---

#### Confirm Payment (Merchant)
**POST** `/api/payments/confirm`

**Request Body**
```json
{
  "transaction_id": "550e8400-e29b-41d4-a716-446655440002",
  "verification_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response** (200 OK)
```json
{
  "transaction_id": "550e8400-e29b-41d4-a716-446655440002",
  "status": "SUCCESS",
  "receipt": "RCP-550E8400",
  "completed_at": "2024-06-20T10:30:00Z"
}
```

---

## KYC (Know Your Customer)

### 1. KYC Routes (`/api/v1/kyc`)

All KYC endpoints require authentication.

#### Get KYC Status
**GET** `/api/v1/kyc/status`

Check current KYC verification status.

**Response** (200 OK)
```json
{
  "isVerified": true,
  "status": "Verified",
  "matchPercentage": 0.97,
  "warnings": [],
  "submittedAt": "2024-06-20T09:00:00Z",
  "decidedAt": "2024-06-20T10:00:00Z",
  "decisionReason": "Verified by admin"
}
```

**Initial Status** (First Time)
```json
{
  "isVerified": false,
  "status": "None",
  "matchPercentage": 0.0,
  "warnings": [],
  "submittedAt": null,
  "decidedAt": null,
  "decisionReason": null
}
```

---

#### Submit KYC Documents
**POST** `/api/v1/kyc/submit`

Upload identity documents for verification with multipart/form-data.

**Request Body** (multipart/form-data)
```
documentType: "NATIONAL_ID"        (form field)
idFront: <file>                    (file)
idBack: <file>                     (file, optional)
selfie: <file>                     (file)
```

**Response** (201 Created)
```json
{
  "kycRequestId": "550e8400-e29b-41d4-a716-446655440000",
  "status": "Pending",
  "matchPercentage": 0.0,
  "spoofScore": 0.0,
  "ocrConfidence": 0.0,
  "warnings": []
}
```

**Error Cases**
- `400`: Missing documentType, idFront, or selfie

---

#### Liveness Check Challenge
**POST** `/api/v1/kyc/liveness/challenge`

Get a liveness challenge for anti-spoofing detection.

**Response** (200 OK)
```json
{
  "challengeId": "challenge_1718876400000",
  "action": "blink",
  "ttlSeconds": 90
}
```

---

#### Verify Liveness
**POST** `/api/v1/kyc/liveness/verify`

Submit liveness check response with challenge and video frames.

**Request Body**
```json
{
  "challengeId": "challenge_1718876400000",
  "action": "blink",
  "frames": ["base64_frame_1", "base64_frame_2", ...]
}
```

**Response** (200 OK)
```json
{
  "passed": true,
  "confidence": 0.97,
  "reason": null
}
```

**Error Cases**
- `400`: Missing liveness challenge fields

---

### 2. Admin KYC Routes (`/api/v1/admin/kyc`)

Only accessible by users with `admin` role.

#### Get Pending KYC Requests
**GET** `/api/v1/admin/kyc/pending`

List all KYC requests awaiting admin decision.

**Response** (200 OK)
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "userId": "550e8400-e29b-41d4-a716-446655440001",
    "fullName": "Ahmed Hassan",
    "phoneNumber": "+201123456789",
    "matchPercentage": 0.95,
    "submittedAt": "2024-06-20T09:00:00Z",
    "warnings": []
  }
]
```

---

#### Approve KYC Request
**POST** `/api/v1/admin/kyc/:id/approve`

Approve a KYC request and verify the user.

**Request Body**
```json
{
  "reason": "Verified successfully"  // Optional
}
```

**Response** (204 No Content)

---

#### Reject KYC Request
**POST** `/api/v1/admin/kyc/:id/reject`

Reject a KYC request with reason.

**Request Body**
```json
{
  "reason": "Document quality insufficient"  // Optional
}
```

**Response** (204 No Content)

---

## Fingerprint Authentication

### 1. Fingerprint Routes (`/api/v1/fingerprint`)

All fingerprint endpoints require authentication.

#### Enroll Fingerprint
**POST** `/api/v1/fingerprint/enroll`

Start fingerprint enrollment for a user with ZK9500 device.

**Request Body**
```json
{
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "deviceModel": "ZK9500"  // Optional
}
```

**Response** (201 Created)
```json
{
  "fingerprintId": "550e8400-e29b-41d4-a716-446655440000",
  "message": "Fingerprint enrollment started. Complete enrollment with the ZK device service."
}
```

---

#### Authenticate Fingerprint Payment
**POST** `/api/v1/fingerprint/authenticate`

Complete payment authentication using fingerprint.

**Request Body**
```json
{
  "paymentIntentId": "550e8400-e29b-41d4-a716-446655440000",
  "fingerprintId": "550e8400-e29b-41d4-a716-446655440001",
  "matched": true
}
```

**Response - Success** (200 OK)
```json
{
  "success": true,
  "status": "COMPLETED",
  "orderReference": "FP-A1B2C3D4",
  "paymentDevice": "ZK9500"
}
```

**Response - Failure** (401 Unauthorized)
```json
{
  "success": false,
  "status": "FAILED",
  "message": "Fingerprint not matched"
}
```

**Error Cases**
- `400`: Missing paymentIntentId or fingerprintId
- `401`: Fingerprint not matched or doesn't belong to payment user
- `404`: Payment intent not found

**Security Flow**
1. Verify fingerprint belongs to user
2. Verify fingerprint matches user on payment intent
3. Verify user is KYC verified
4. Credit wallet with payment amount
5. Record topup operation
6. Mark payment intent as SETTLED

---

### 2. Device Management Routes (`/api/fingerprint`)

Unprotected routes for device management and communication with ZK9500 fingerprint reader.

#### Device Status
**GET** `/api/fingerprint/device/status`

Check if ZK fingerprint device is connected and ready.

**Response** (200 OK)
```json
{
  "success": true,
  "device_open": true
}
```

**Response** (503 Service Unavailable)
```json
{
  "success": false,
  "error": "Python ZK Service غير متاح. تأكد أنه شغال."
}
```

---

#### Open Device
**POST** `/api/fingerprint/device/open`

Connect to and open the ZK9500 device.

**Response** (200 OK)
```json
{
  "success": true,
  "message": "Device opened successfully"
}
```

---

#### Close Device
**POST** `/api/fingerprint/device/close`

Disconnect and close the ZK9500 device.

**Response** (200 OK)
```json
{
  "success": true,
  "message": "Device closed successfully"
}
```

---

#### Enroll Fingerprint (Device)
**POST** `/api/fingerprint/enroll`

Enroll a user's fingerprint on the physical ZK9500 device.

**Request Body**
```json
{
  "national_id": "29001011234567",
  "full_name": "Ahmed Hassan",
  "phone": "+201123456789",
  "finger_index": 1
}
```

**Response** (200 OK)
```json
{
  "success": true,
  "message": "Fingerprint enrolled successfully"
}
```

---

#### Verify Fingerprint (Device)
**POST** `/api/fingerprint/verify`

Capture fingerprint and verify against enrolled templates.

**Request Body**
```json
{
  "national_id": "29001011234567"
}
```

**Response - Match** (200 OK)
```json
{
  "success": true,
  "matched": true,
  "confidence": 0.98,
  "message": "✅ تم التحقق من الهوية بنجاح"
}
```

**Response - No Match** (200 OK)
```json
{
  "success": true,
  "matched": false,
  "confidence": 0.35,
  "message": "❌ البصمة غير متطابقة"
}
```

---

#### Get User Information
**GET** `/api/fingerprint/user/:national_id`

Retrieve user information and enrolled fingerprints from device.

**Response** (200 OK)
```json
{
  "success": true,
  "national_id": "29001011234567",
  "full_name": "Ahmed Hassan",
  "phone": "+201123456789",
  "enrolled_fingers": [1, 2]
}
```

---

### 3. Fingerprint Controller (`controllers/fingerprintController.js`)

Communicates with Python ZK Service at `http://localhost:5005` to control the fingerprint device.

**Service Endpoints** (Python Backend)
```
GET    /health              - Check device status
POST   /device/open         - Connect to device
POST   /device/close        - Disconnect device
POST   /enroll              - Enroll fingerprint
POST   /verify              - Verify fingerprint
GET    /users/{national_id} - Get user info
```

**Timeout Configuration**
- Enroll: 30 seconds (3 capture attempts)
- Verify: 5 seconds

---

## Chat System

### 1. Chat Routes (`/api/v1/chat`)

All chat endpoints require authentication.

#### Send Message
**POST** `/api/v1/chat/send`

Send a message to support/admin or between users.

**Request Body - Customer to Admin**
```json
{
  "content": "I need help with my payment"
}
```

**Request Body - Admin to Specific User**
```json
{
  "userId": "550e8400-e29b-41d4-a716-446655440001",
  "content": "Hello, we received your request"
}
```

**Response** (201 Created)
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "550e8400-e29b-41d4-a716-446655440001",
  "senderId": "550e8400-e29b-41d4-a716-446655440002",
  "senderRole": "admin",
  "content": "Hello, we received your request",
  "createdAt": "2024-06-20T10:30:00Z"
}
```

**Error Cases**
- `400`: Empty or invalid message content
- `400`: Admin must specify userId for target user
- `404`: Target user not found

---

#### Get Messages
**GET** `/api/v1/chat` or `/api/v1/chat/messages`

Retrieve messages for current user.

**For Regular Users**
```
GET /api/v1/chat
```
Returns all messages in user's conversation.

**Response** (200 OK)
```json
{
  "messages": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "userId": "550e8400-e29b-41d4-a716-446655440001",
      "senderId": "550e8400-e29b-41d4-a716-446655440002",
      "senderRole": "admin",
      "content": "How can we assist you?",
      "createdAt": "2024-06-20T10:30:00Z"
    }
  ]
}
```

**For Admin Users**
```
GET /api/v1/chat                          - List all conversations
GET /api/v1/chat?userId={userId}          - Get specific user's messages
```

**Admin Conversations Response** (200 OK)
```json
{
  "conversations": [
    {
      "userId": "550e8400-e29b-41d4-a716-446655440001",
      "lastMessage": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "content": "Thank you for your help",
        "createdAt": "2024-06-20T11:00:00Z"
      },
      "messageCount": 5
    }
  ]
}
```

---

## Data Storage

### In-Memory Storage Architecture

The backend uses JavaScript Maps for data persistence (suitable for development/testing):

```
┌─────────────────────────────────────────────────────┐
│           In-Memory Data Store (store.js)           │
├─────────────────────────────────────────────────────┤
│ users             │ Map<userId, userObject>        │
│ wallets           │ Map<userId, walletObject>      │
│ operations        │ Map<userId, operations[]>      │
│ kycRequests       │ Map<kycId, kycObject>          │
│ chats             │ Map<userId, messages[]>        │
│ fingerprints      │ Map<fingerprintId, record>     │
│ refreshTokens     │ Map<token, userId>             │
│ transactions      │ Map<txId, txObject>            │
│ paymentIntents    │ Map<intentId, intentObject>    │
└─────────────────────────────────────────────────────┘
```

### Data Persistence Considerations

**Current Limitation**
- Data is stored only in memory
- All data is lost when server restarts
- Not suitable for production

**Production Migration Path**
1. Replace Maps with database queries
2. Options:
   - **MongoDB**: Document-oriented, flexible schema
   - **PostgreSQL**: Relational, strong data integrity
   - **MySQL**: Established, good performance
3. Use ORM/ODM (Sequelize, TypeORM, Prisma, Mongoose)

---

## Error Handling

### Standard Error Response Format

```json
{
  "code": "ERROR_CODE",
  "message": "Human-readable error message"
}
```

### HTTP Status Codes

| Code | Meaning | Usage |
|------|---------|-------|
| 200 | OK | Successful request |
| 201 | Created | Resource successfully created |
| 204 | No Content | Successful request with no response body |
| 400 | Bad Request | Invalid input or missing required fields |
| 401 | Unauthorized | Authentication failed or token invalid |
| 403 | Forbidden | Insufficient permissions or blocked operation |
| 404 | Not Found | Resource does not exist |
| 409 | Conflict | Resource already exists (duplicate) |
| 503 | Service Unavailable | External service unreachable (e.g., ZK device) |
| 500 | Internal Server Error | Unexpected server error |

### Error Codes by Category

**Authentication Errors**
- `UNAUTHORIZED`: Missing or invalid Authorization header
- `INVALID_TOKEN`: JWT token verification failed
- `INVALID_CREDENTIALS`: Wrong password or phone number
- `INVALID_ROLE`: Role not in allowed set

**Input Validation**
- `INVALID_INPUT`: Missing required fields
- `INVALID_AMOUNT`: Amount not positive or too small
- `INVALID_METHOD`: Payment method not supported

**User/Resource Errors**
- `USER_EXISTS`: Email, phone, or name already in use
- `NOT_FOUND`: User, wallet, transaction, or resource not found
- `WALLET_NOT_FOUND`: User's wallet does not exist
- `RECIPIENT_NOT_FOUND`: Transfer recipient not found

**Permission Errors**
- `FORBIDDEN`: Role doesn't have required permissions
- `KYC_REQUIRED`: Operation requires KYC verification

**Transaction Errors**
- `INSUFFICIENT_FUNDS`: Wallet balance too low
- `INVALID_STATE`: Transaction in unexpected state
- `TRANSFER_FAILED`: Transfer execution failed
- `FRAUD_BLOCKED`: Fraud detection rejected transaction
- `TOKEN_MISMATCH`: Verification token doesn't match transaction
- `MERCHANT_NOT_FOUND`: Merchant user not found
- `TRANSACTION_NOT_FOUND`: Transaction not found
- `INVALID_VERIFICATION_TOKEN`: Verification token invalid

**KYC Errors**
- `KYCREQ_NOT_FOUND`: KYC request ID not found

**Device/Service Errors**
- Service unavailable (ZK device connection failed)

---

## Environment Variables

Create a `.env` file in the root directory:

```env
# Server Configuration
PORT=8081

# JWT Configuration
JWT_SECRET=your-secret-key-here
ACCESS_TOKEN_EXPIRES_IN=1h
REFRESH_TOKEN_EXPIRES_IN=7d

# ZK Fingerprint Service
ZK_SERVICE_URL=http://localhost:5005

# CORS Configuration
CORS_ORIGIN=*
```

### Required Variables
- `JWT_SECRET`: Secret key for signing JWT tokens (minimum 32 characters recommended)
- `ZK_SERVICE_URL`: URL of Python ZK Service for fingerprint device communication

### Default Values
- `PORT`: 8081
- `ACCESS_TOKEN_EXPIRES_IN`: 1h
- `REFRESH_TOKEN_EXPIRES_IN`: 7d
- `ZK_SERVICE_URL`: http://localhost:5005

---

## Running the Server

### Prerequisites
- Node.js 16+ installed
- Python ZK Service running (if using fingerprint features)

### Installation

```bash
npm install
```

### Start Server

```bash
npm start
```

Server runs on: `http://localhost:8081`

### Testing

Run integration tests:
```bash
node test_integration.mjs
```

---

## Security Considerations

### Current Recommendations
1. **Passwords**: Hashed with bcryptjs (10 rounds salt)
2. **Tokens**: JWT-based with expiration
3. **Refresh Lock**: Atomic transfers use simple lock (single-threaded Node.js)
4. **CORS**: Currently allows all origins (`*`)
5. **KYC Requirement**: Payment operations require KYC verification

### Production Improvements Needed
1. Replace in-memory storage with database
2. Use HTTPS/SSL certificates
3. Implement rate limiting
4. Add request validation and sanitization
5. Use environment-based CORS configuration
6. Implement audit logging
7. Add transaction encryption
8. Set strong JWT_SECRET
9. Use secure session management
10. Implement IP whitelist for admin endpoints

---

## Fraud Detection

### Middleware (`middleware/fraudDetection.js`)

Currently a placeholder that always passes transactions:

```javascript
export const runFraudCheck = async (transaction) => {
  return { passed: true, riskScore: 0, flags: [] };
};
```

### Future Implementation
Should include:
- Amount-based thresholds
- Time-based pattern detection
- Device fingerprinting
- Geographic anomaly detection
- Multiple transaction frequency checks
- User risk scoring

---

## Seed Data

Two users are automatically created on server startup:

### Admin User
- **Name**: Admin User
- **Email**: admin@wallet.local
- **Phone**: +201000000001
- **Password**: Admin1234!
- **Role**: admin
- **Initial Balance**: 1,000 EGP

### Merchant User
- **Name**: Merchant User
- **Email**: merchant@wallet.local
- **Phone**: +201000000002
- **Password**: Merchant1234!
- **Role**: merchant
- **Initial Balance**: 1,000 EGP

Use these credentials for testing admin and merchant features.

---

## Future Enhancements

1. **Database Integration**: Replace Maps with persistent database
2. **Real Payment Gateway**: Integrate with actual payment processors
3. **Notification System**: Email/SMS notifications for transactions
4. **Advanced Fraud Detection**: ML-based detection system
5. **Transaction Limits**: Daily/monthly limits per user
6. **Role-Based Access Control**: Fine-grained permissions
7. **Audit Logging**: Complete transaction and API audit trail
8. **Two-Factor Authentication**: Additional security layer
9. **Device Management**: Track and manage enrolled devices
10. **Analytics Dashboard**: Transaction analytics and reporting

---

## Conclusion

This backend provides a comprehensive payment and wallet system with biometric authentication, KYC verification, and multi-user support. It's designed as a development platform with in-memory storage suitable for testing and demonstration purposes. For production deployment, consider migrating to a persistent database, implementing security enhancements, and adding monitoring and analytics capabilities.
