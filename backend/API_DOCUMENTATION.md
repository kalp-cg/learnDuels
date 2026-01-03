# LearnDuels API - Complete Postman Testing Guide

## 🚀 Quick Start

**Base URL:** `http://localhost:4000`

**Demo Accounts:**
- Email: `demo1@learnduels.com` | Password: `demo123`
- Email: `demo2@learnduels.com` | Password: `demo123`
- Email: `admin@learnduels.com` | Password: `demo123` (Admin)

---

## 📋 Table of Contents
1. [Health & Info Endpoints](#1-health--info-endpoints)
2. [Authentication APIs](#2-authentication-apis)
3. [User Management APIs](#3-user-management-apis)
4. [Category & Difficulty APIs](#4-category--difficulty-apis)
5. [Question Management APIs](#5-question-management-apis)
6. [Duel System APIs](#6-duel-system-apis)
7. [Leaderboard APIs](#7-leaderboard-apis)
8. [Notification APIs](#8-notification-apis)

---

## 1. Health & Info Endpoints

### 1.1 Health Check
**GET** `http://localhost:4000/health`

**Response:**
```json
{
  "success": true,
  "message": "LearnDuels API is healthy",
  "timestamp": "2025-11-23T10:30:00.000Z",
  "environment": "development",
  "version": "2.0.0"
}
```

### 1.2 API Information
**GET** `http://localhost:4000/api`

**Response:**
```json
{
  "success": true,
  "message": "Welcome to LearnDuels API",
  "version": "2.0.0",
  "endpoints": {
    "auth": "/api/auth",
    "users": "/api/users",
    "duels": "/api/duels",
    "categories": "/api/categories",
    "questions": "/api/questions",
    "leaderboards": "/api/leaderboards",
    "notifications": "/api/notifications"
  }
}
```

---

## 2. Authentication APIs

### 2.1 User Registration
**POST** `http://localhost:4000/api/auth/signup`

**Headers:**
```
Content-Type: application/json
```

**Body (raw JSON):**
```json
{
  "fullName": "John Doe",
  "email": "john.doe@example.com",
  "password": "SecurePass123"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Account created successfully",
  "data": {
    "user": {
      "id": 4,
      "fullName": "John Doe",
      "email": "john.doe@example.com",
      "role": "user",
      "rating": 1000
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

### 2.2 User Login
**POST** `http://localhost:4000/api/auth/login`

**Headers:**
```
Content-Type: application/json
```

**Body (raw JSON):**
```json
{
  "email": "demo1@learnduels.com",
  "password": "demo123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": 1,
      "fullName": "Demo User 1",
      "email": "demo1@learnduels.com",
      "role": "user",
      "rating": 1500
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

### 2.3 Refresh Access Token
**POST** `http://localhost:4000/api/auth/refresh`

**Headers:**
```
Content-Type: application/json
```

**Body (raw JSON):**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Tokens refreshed successfully",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

### 2.4 Logout
**POST** `http://localhost:4000/api/auth/logout`

**Headers:**
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

### 2.5 Change Password
**POST** `http://localhost:4000/api/auth/change-password`

**Headers:**
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Body (raw JSON):**
```json
{
  "currentPassword": "demo123",
  "newPassword": "NewSecurePass123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Password changed successfully"
}
```

---

## 3. User Management APIs

### 3.1 Get Current User Profile
**GET** `http://localhost:4000/api/users/me`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Profile retrieved successfully",
  "data": {
    "id": 1,
    "fullName": "Demo User 1",
    "email": "demo1@learnduels.com",
    "role": "user",
    "rating": 1500,
    "createdAt": "2025-11-23T10:00:00.000Z",
    "stats": {
      "totalDuels": 0,
      "wins": 0,
      "losses": 0,
      "winRate": 0
    }
  }
}
```

### 3.2 Update User Profile
**PUT** `http://localhost:4000/api/users/update`

**Headers:**
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Body (raw JSON):**
```json
{
  "fullName": "Demo User Updated"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Profile updated successfully",
  "data": {
    "id": 1,
    "fullName": "Demo User Updated",
    "email": "demo1@learnduels.com",
    "role": "user",
    "rating": 1500
  }
}
```

### 3.3 Get User By ID
**GET** `http://localhost:4000/api/users/1`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "User profile retrieved successfully",
  "data": {
    "id": 1,
    "fullName": "Demo User 1",
    "email": "demo1@learnduels.com",
    "role": "user",
    "rating": 1500,
    "createdAt": "2025-11-23T10:00:00.000Z"
  }
}
```

### 3.4 Follow a User
**POST** `http://localhost:4000/api/users/2/follow`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "User followed successfully"
}
```

### 3.5 Unfollow a User
**POST** `http://localhost:4000/api/users/2/unfollow`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "User unfollowed successfully"
}
```

### 3.6 Get User's Followers
**GET** `http://localhost:4000/api/users/1/followers?page=1&limit=20`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Followers retrieved successfully",
  "data": [
    {
      "id": 2,
      "fullName": "Demo User 2",
      "email": "demo2@learnduels.com",
      "rating": 1200
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 1,
    "pages": 1
  }
}
```

### 3.7 Get User's Following List
**GET** `http://localhost:4000/api/users/1/following?page=1&limit=20`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Following list retrieved successfully",
  "data": [
    {
      "id": 2,
      "fullName": "Demo User 2",
      "email": "demo2@learnduels.com",
      "rating": 1200
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 1,
    "pages": 1
  }
}
```

### 3.8 Search Users
**GET** `http://localhost:4000/api/users/search?q=demo&page=1&limit=20`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "User search completed successfully",
  "data": [
    {
      "id": 1,
      "fullName": "Demo User 1",
      "email": "demo1@learnduels.com",
      "rating": 1500
    },
    {
      "id": 2,
      "fullName": "Demo User 2",
      "email": "demo2@learnduels.com",
      "rating": 1200
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 2,
    "pages": 1
  }
}
```

---

## 4. Category & Difficulty APIs

### 4.1 Get All Categories
**GET** `http://localhost:4000/api/categories`

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Categories retrieved successfully",
  "data": [
    {
      "id": 1,
      "name": "Mathematics"
    },
    {
      "id": 2,
      "name": "Science"
    },
    {
      "id": 3,
      "name": "History"
    },
    {
      "id": 4,
      "name": "Geography"
    },
    {
      "id": 5,
      "name": "Literature"
    }
  ]
}
```

### 4.2 Create Category (Admin Only)
**POST** `http://localhost:4000/api/categories`

**Headers:**
```
Content-Type: application/json
Authorization: Bearer ADMIN_ACCESS_TOKEN
```

**Body (raw JSON):**
```json
{
  "name": "Philosophy"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Category created successfully",
  "data": {
    "id": 11,
    "name": "Philosophy"
  }
}
```

### 4.3 Get All Difficulty Levels
**GET** `http://localhost:4000/api/categories/difficulties`

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Difficulties retrieved successfully",
  "data": [
    {
      "id": 1,
      "level": "Easy"
    },
    {
      "id": 2,
      "level": "Medium"
    },
    {
      "id": 3,
      "level": "Hard"
    }
  ]
}
```

### 4.4 Create Difficulty (Admin Only)
**POST** `http://localhost:4000/api/categories/difficulties`

**Headers:**
```
Content-Type: application/json
Authorization: Bearer ADMIN_ACCESS_TOKEN
```

**Body (raw JSON):**
```json
{
  "level": "Expert"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Difficulty level created successfully",
  "data": {
    "id": 4,
    "level": "Expert"
  }
}
```

---

## 5. Question Management APIs

### 5.1 Create Question
**POST** `http://localhost:4000/api/questions`

**Headers:**
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Body (raw JSON):**
```json
{
  "categoryId": 1,
  "difficultyId": 1,
  "questionText": "What is 5 + 5?",
  "optionA": "8",
  "optionB": "9",
  "optionC": "10",
  "optionD": "11",
  "correctOption": "C"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Question created successfully",
  "data": {
    "id": 4,
    "categoryId": 1,
    "difficultyId": 1,
    "authorId": 1,
    "questionText": "What is 5 + 5?",
    "optionA": "8",
    "optionB": "9",
    "optionC": "10",
    "optionD": "11",
    "correctOption": "C",
    "createdAt": "2025-11-23T10:30:00.000Z"
  }
}
```

### 5.2 Get All Questions
**GET** `http://localhost:4000/api/questions?page=1&limit=20`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Questions retrieved successfully",
  "data": [
    {
      "id": 1,
      "questionText": "What is 2 + 2?",
      "optionA": "3",
      "optionB": "4",
      "optionC": "5",
      "optionD": "6",
      "category": {
        "id": 1,
        "name": "Mathematics"
      },
      "difficulty": {
        "id": 1,
        "level": "Easy"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 3,
    "pages": 1
  }
}
```

### 5.3 Get Questions with Filters
**GET** `http://localhost:4000/api/questions?categoryId=1&difficultyId=1&page=1&limit=10`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Questions retrieved successfully",
  "data": [
    {
      "id": 1,
      "questionText": "What is 2 + 2?",
      "optionA": "3",
      "optionB": "4",
      "optionC": "5",
      "optionD": "6",
      "category": {
        "id": 1,
        "name": "Mathematics"
      },
      "difficulty": {
        "id": 1,
        "level": "Easy"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 2,
    "pages": 1
  }
}
```

### 5.4 Get Question by ID
**GET** `http://localhost:4000/api/questions/1`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Question retrieved successfully",
  "data": {
    "id": 1,
    "questionText": "What is 2 + 2?",
    "optionA": "3",
    "optionB": "4",
    "optionC": "5",
    "optionD": "6",
    "category": {
      "id": 1,
      "name": "Mathematics"
    },
    "difficulty": {
      "id": 1,
      "level": "Easy"
    },
    "author": {
      "id": 1,
      "fullName": "Demo User 1"
    }
  }
}
```

### 5.5 Search Questions
**GET** `http://localhost:4000/api/questions/search?q=what&page=1&limit=20`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Question search completed successfully",
  "data": [
    {
      "id": 1,
      "questionText": "What is 2 + 2?",
      "category": {
        "id": 1,
        "name": "Mathematics"
      },
      "difficulty": {
        "id": 1,
        "level": "Easy"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 3,
    "pages": 1
  }
}
```

### 5.6 Update Question
**PUT** `http://localhost:4000/api/questions/1`

**Headers:**
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Body (raw JSON):**
```json
{
  "categoryId": 1,
  "difficultyId": 2,
  "questionText": "What is 2 + 2? (Updated)",
  "optionA": "3",
  "optionB": "4",
  "optionC": "5",
  "optionD": "6",
  "correctOption": "B"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Question updated successfully",
  "data": {
    "id": 1,
    "questionText": "What is 2 + 2? (Updated)",
    "difficultyId": 2
  }
}
```

### 5.7 Delete Question
**DELETE** `http://localhost:4000/api/questions/1`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Question deleted successfully"
}
```

---

## 6. Duel System APIs

### 6.1 Create a Duel
**POST** `http://localhost:4000/api/duels`

**Headers:**
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Body (raw JSON):**
```json
{
  "opponentId": 2,
  "categoryId": 1,
  "difficultyId": 1,
  "questionCount": 5,
  "timeLimit": 60
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Duel created successfully",
  "data": {
    "id": 1,
    "challengerId": 1,
    "opponentId": 2,
    "categoryId": 1,
    "difficultyId": 1,
    "status": "pending",
    "questionCount": 5,
    "timeLimit": 60,
    "createdAt": "2025-11-23T10:30:00.000Z",
    "questions": [
      {
        "id": 1,
        "questionText": "What is 2 + 2?"
      },
      {
        "id": 2,
        "questionText": "What is 10 - 5?"
      }
    ]
  }
}
```

### 6.2 Get User's Duels
**GET** `http://localhost:4000/api/duels/my?status=active&page=1&limit=20`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Query Parameters:**
- `status` (optional): `pending`, `active`, `completed`
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 20)

**Response (200 OK):**
```json
{
  "success": true,
  "message": "User duels retrieved successfully",
  "data": [
    {
      "id": 1,
      "challenger": {
        "id": 1,
        "fullName": "Demo User 1"
      },
      "opponent": {
        "id": 2,
        "fullName": "Demo User 2"
      },
      "category": {
        "id": 1,
        "name": "Mathematics"
      },
      "difficulty": {
        "id": 1,
        "level": "Easy"
      },
      "status": "active",
      "questionCount": 5,
      "timeLimit": 60,
      "createdAt": "2025-11-23T10:30:00.000Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 1,
    "pages": 1
  }
}
```

### 6.3 Get Duel by ID
**GET** `http://localhost:4000/api/duels/1`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Duel retrieved successfully",
  "data": {
    "id": 1,
    "challenger": {
      "id": 1,
      "fullName": "Demo User 1",
      "rating": 1500
    },
    "opponent": {
      "id": 2,
      "fullName": "Demo User 2",
      "rating": 1200
    },
    "category": {
      "id": 1,
      "name": "Mathematics"
    },
    "difficulty": {
      "id": 1,
      "level": "Easy"
    },
    "status": "active",
    "questionCount": 5,
    "timeLimit": 60,
    "challengerScore": 0,
    "opponentScore": 0,
    "winnerId": null,
    "createdAt": "2025-11-23T10:30:00.000Z",
    "questions": [
      {
        "id": 1,
        "questionText": "What is 2 + 2?",
        "optionA": "3",
        "optionB": "4",
        "optionC": "5",
        "optionD": "6"
      }
    ]
  }
}
```

### 6.4 Submit Answer to Duel Question
**POST** `http://localhost:4000/api/duels/1/questions/1/answer`

**Headers:**
```
Content-Type: application/json
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Body (raw JSON):**
```json
{
  "selectedOption": "B"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Answer submitted successfully",
  "data": {
    "isCorrect": true,
    "correctOption": "B",
    "duelStatus": "active",
    "currentScore": 1
  }
}
```

---

## 7. Leaderboard APIs

### 7.1 Get Global Leaderboard
**GET** `http://localhost:4000/api/leaderboards?page=1&limit=20`

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Leaderboard retrieved successfully",
  "data": [
    {
      "rank": 1,
      "userId": 3,
      "fullName": "Admin User",
      "rating": 2000,
      "totalDuels": 10,
      "wins": 8,
      "losses": 2,
      "winRate": 80
    },
    {
      "rank": 2,
      "userId": 1,
      "fullName": "Demo User 1",
      "rating": 1500,
      "totalDuels": 5,
      "wins": 3,
      "losses": 2,
      "winRate": 60
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 3,
    "pages": 1
  }
}
```

### 7.2 Get User Rank
**GET** `http://localhost:4000/api/leaderboards/user/1`

**Response (200 OK):**
```json
{
  "success": true,
  "message": "User rank retrieved successfully",
  "data": {
    "rank": 2,
    "userId": 1,
    "fullName": "Demo User 1",
    "rating": 1500,
    "totalDuels": 5,
    "wins": 3,
    "losses": 2,
    "winRate": 60
  }
}
```

---

## 8. Notification APIs

### 8.1 Get User Notifications
**GET** `http://localhost:4000/api/notifications?page=1&limit=20`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Notifications retrieved successfully",
  "data": [
    {
      "id": 1,
      "userId": 1,
      "message": "Demo User 2 challenged you to a duel!",
      "isRead": false,
      "createdAt": "2025-11-23T10:30:00.000Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 1,
    "pages": 1
  }
}
```

### 8.2 Mark Notification as Read
**PUT** `http://localhost:4000/api/notifications/1/read`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Notification marked as read"
}
```

### 8.3 Mark All Notifications as Read
**PUT** `http://localhost:4000/api/notifications/read-all`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "All notifications marked as read"
}
```

### 8.4 Register Device for Push Notifications
**POST** `http://localhost:4000/api/notifications/register-device`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Body:**
```json
{
  "token": "fcm_device_token_here",
  "platform": "android"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Device registered for push notifications",
  "data": {}
}
```

### 8.5 Remove Device Token
**DELETE** `http://localhost:4000/api/notifications/remove-device`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Body:**
```json
{
  "token": "fcm_device_token_here"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Device token removed",
  "data": {}
}
```

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "All notifications marked as read",
  "data": {
    "count": 5
  }
}
```

### 8.4 Delete Notification
**DELETE** `http://localhost:4000/api/notifications/1`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Notification deleted successfully"
}
```

---

## 🔐 Authentication Flow

### Step 1: Login and Get Token
```
POST http://localhost:4000/api/auth/login
Body: {"email": "demo1@learnduels.com", "password": "demo123"}
```

### Step 2: Copy Access Token from Response
```json
{
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

### Step 3: Use Token in Headers
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## 📝 Complete Duel Workflow Example

### 1. Login as User 1
```
POST http://localhost:4000/api/auth/login
Body: {"email": "demo1@learnduels.com", "password": "demo123"}
```

### 2. Get Categories
```
GET http://localhost:4000/api/categories
```

### 3. Get Difficulties
```
GET http://localhost:4000/api/categories/difficulties
```

### 4. Create a Duel (User 1 challenges User 2)
```
POST http://localhost:4000/api/duels
Headers: Authorization: Bearer USER1_TOKEN
Body: {
  "opponentId": 2,
  "categoryId": 1,
  "difficultyId": 1,
  "questionCount": 5,
  "timeLimit": 60
}
```

### 5. Get Duel Details
```
GET http://localhost:4000/api/duels/1
Headers: Authorization: Bearer USER1_TOKEN
```

### 6. Submit Answers
```
POST http://localhost:4000/api/duels/1/questions/1/answer
Headers: Authorization: Bearer USER1_TOKEN
Body: {"selectedOption": "B"}
```

### 7. Check Leaderboard
```
GET http://localhost:4000/api/leaderboards
```

---

## 🎯 Testing Checklist

- [ ] Health check endpoint works
- [ ] User can register new account
- [ ] User can login with demo account
- [ ] User can view their profile
- [ ] User can update their profile
- [ ] Categories are loaded correctly
- [ ] Difficulties are loaded correctly
- [ ] User can create a question
- [ ] User can view questions
- [ ] User can create a duel
- [ ] User can view their duels
- [ ] User can submit answers
- [ ] Leaderboard displays correctly
- [ ] User can follow/unfollow others
- [ ] Notifications are created and retrieved

---

## 🐛 Common Issues & Solutions

### Issue: "Access token required"
**Solution:** Make sure you're including the Authorization header:
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```

### Issue: "Cannot find module"
**Solution:** Run from correct directory:
```powershell
cd C:\Users\kalp1\OneDrive\Desktop\learnDules\backend\src
node server.js
```

### Issue: "Database connection failed"
**Solution:** Ensure PostgreSQL is running and credentials in `.env` are correct

### Issue: "Port 4000 already in use"
**Solution:** Stop the existing server or change PORT in `.env`

---

## 💡 Tips for Postman

1. **Create Environment Variables:**
   - `baseUrl`: `http://localhost:4000`
   - `accessToken`: (Set after login)
   - `userId`: (Set after login)

2. **Use Collections:**
   - Organize requests by feature (Auth, Users, Duels, etc.)
   - Add tests to validate responses

3. **Use Pre-request Scripts:**
   - Auto-refresh tokens before requests
   - Set dynamic variables

4. **Save Example Responses:**
   - Document expected responses
   - Compare with actual results

---

## 📊 Database Info

**Connection:**
- Host: `localhost`
- Port: `5432`
- Database: `learnduels`
- Username: `postgres`
- Password: `1234`

**Demo Users:**
| ID | Email | Password | Role | Rating |
|----|-------|----------|------|--------|
| 1 | demo1@learnduels.com | demo123 | user | 1500 |
| 2 | demo2@learnduels.com | demo123 | user | 1200 |
| 3 | admin@learnduels.com | demo123 | admin | 2000 |

**Seeded Data:**
- 10 Categories (Mathematics, Science, History, etc.)
- 3 Difficulty Levels (Easy, Medium, Hard)
- 3 Sample Questions
- 3 Subscription Plans

---

## 🚀 Start Server

```powershell
cd C:\Users\kalp1\OneDrive\Desktop\learnDules\backend\src
node server.js
```

**Expected Output:**
```
🚀 LearnDuels server listening on port 4000
```

Now you're ready to test all APIs in Postman! 🎉
