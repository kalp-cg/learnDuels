# Application Features Overview

This document provides a comprehensive overview of the features implemented in the LearnDules application. The application is a competitive learning platform focused on computer science topics (like DSA, Web Development, etc.) with social and gamification elements.

## 1. Authentication & User Management
*   **Multi-Method Sign In:**
    *   **Email/Password:** Classic registration and login.
    *   **OAuth Integration:** Sign in with **Google** (and potentially GitHub) for one-click access.
    *   **Password Recovery:** Reset password functionality via email tokens.
*   **User Profiles:**
    *   **Personalization:** Users can set a bio, upload avatars (hosted on Cloudinary), and manage personal details.
    *   **Stats Dashboard:** Displays level, reputation, current/longest streaks, questions solved, and quizzes completed.
    *   **Activity Tracking:** Logs last login and daily streaks to encourage retention.

## 2. Social Ecosystem
*   **Follow System:**
    *   **Request-Based Logic:** A complete "Follow Request" workflow where users can set their profile privacy.
    *   **Workflow:** Send Request -> Pending State (Cancelable) -> Accept/Decline by Receiver.
    *   **Followers/Following:** Social graph tracking with counters on profiles.
*   **Activity Feed:** Users can likely see updates or achievements from people they follow (implied by `feed.routes.js`).

## 3. Learning Engine (Content)
*   **Topic Hierarchy:**
    *   Structured learning paths with parent and child topics (e.g., Programming -> JavaScript -> Arrays).
    *   Slugs for SEO-friendly or clean URLs.
*   **Question Bank:**
    *   **Formats:** Multiple Choice Questions (MCQs) with support for options and correct answers.
    *   **Rich Content:** Questions include explanations for the correct answer to facilitate learning.
    *   **Difficulty Levels:** Categorized by difficulty (Easy, Medium, Hard).
    *   **Saved Questions:** Users can bookmark specific questions and add personal notes for later review.
*   **Question Sets:**
    *   Curated collections of questions (Quizzes).
    *   **Visibility:** Can be Private (personal use) or Public.
    *   **Ordering:** Custom ordering of questions within a set.

## 4. Competitive Mode
*   **Challenges & Duels:**
    *   **1v1 Battles:** Users can issue challenges to others.
    *   **Real-time Interaction:** Powered by WebSockets for live gameplay functionality.
    *   **Battle States:** Pending (invited), Accepted, Completed.
    *   **Scoring:** Tracks scores, time taken, and declares a winner.
*   **Spectator Mode:** (Implied by `spectator.routes.js`) Ability for users to watch live duels.

## 5. Gamification
*   **XP & Leveling System:**
    *   Users earn Experience Points (XP) for solving questions and winning challenges.
    *   Level progression based on accumulated XP.
*   **Leaderboards:**
    *   Rankings based on XP, rating, or specific topics.
    *   Global and possibly friend/network-based views.
*   **Reputation & Rating:**
    *   Elo-style rating system (defaulting to 1200) to match users of similar skill in duels.
*   **Streaks:**
    *   Daily login/activity streaks to gamify consistency.

## 6. Communication
*   **Chat System:**
    *   In-app messaging between users.
    *   Conversation handling.
*   **Notifications:**
    *   **In-App:** Alerts for follow requests, challenge invites, etc.
    *   **Push Notifications:** Mobile alerts to bring users back to the app.

## 7. Administration & Safety
*   **Reporting System:** Users can flag inappropriate questions or report other users.
*   **Moderation:** Admin routes to manage content and users.
*   **Analytics:** Backend tracking of system usage and engagement metrics.
*   **GDPR Compliance:** Tools to manage user data privacy and deletion protocols.

## 8. Technical Stack Highlights
*   **Backend:** Node.js, Express, Prisma ORM, PostgreSQL.
*   **Frontend:** Flutter (Mobile/Web).
*   **Real-time:** Socket.io (or similar WebSocket implementation).
*   **Storage:** Cloudinary for media assets.
