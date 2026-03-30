## 📱 VISUAL TEST GUIDE - Follow Request System

### ✅ STEP-BY-STEP TESTING

---

## 🧑 TEST 1: User A Sends Follow Request

### What You'll See:

**BEFORE clicking Follow:**
```
┌────────────────────────────────────┐
│  User B's Profile                  │
│  ──────────────────────────────    │
│                                    │
│      [  Profile Picture  ]         │
│      User B Name                   │
│      @username                     │
│                                    │
│  ┌────────────────────────────┐   │
│  │         FOLLOW             │   │  ← Green/Primary Color
│  └────────────────────────────┘   │
│                                    │
└────────────────────────────────────┘
```

**AFTER clicking Follow:**
```
┌────────────────────────────────────┐
│  User B's Profile                  │
│  ──────────────────────────────    │
│                                    │
│      [  Profile Picture  ]         │
│      User B Name                   │
│      @username                     │
│                                    │
│  ┌────────────────────────────┐   │
│  │     CANCEL REQUEST         │   │  ← Orange Color
│  └────────────────────────────┘   │
│                                    │
│  ✓ Follow request sent            │  ← Toast Message
└────────────────────────────────────┘
```

---

## 👤 TEST 2: User B Views Follow Requests

### Navigation:
1. Go to **Profile** tab (bottom navigation)
2. Look for **person icon** (👤) in top right corner
3. Tap it

### What You'll See:

```
┌────────────────────────────────────┐
│  ←  Follow Requests                │
│  ──────────────────────────────    │
│                                    │
│  ┌────────────────────────────┐   │
│  │ 👤  User A Name            │   │
│  │     usera@email.com        │   │
│  │                     ✅  ❌  │   │
│  └────────────────────────────┘   │
│                                    │
│  ┌────────────────────────────┐   │
│  │ 👤  User C Name            │   │
│  │     userc@email.com        │   │
│  │                     ✅  ❌  │   │
│  └────────────────────────────┘   │
│                                    │
└────────────────────────────────────┘
```

**If no requests:**
```
┌────────────────────────────────────┐
│  ←  Follow Requests                │
│  ──────────────────────────────    │
│                                    │
│            📥                      │
│                                    │
│     No pending requests            │
│                                    │
└────────────────────────────────────┘
```

---

## ✅ TEST 3: User B Accepts Request

### Before Accepting:
```
┌────────────────────────────────┐
│ 👤  User A Name                │
│     usera@email.com            │
│                       ✅  ❌    │ ← Click green checkmark
└────────────────────────────────┘
```

### After Accepting:
```
┌────────────────────────────────────┐
│  Follow Requests                   │
│  ──────────────────────────────    │
│                                    │
│  (User A removed from list)        │
│                                    │
│  ✓ Follow request accepted         │ ← Toast Message
└────────────────────────────────────┘
```

### User A's View Changes:
```
┌────────────────────────────────────┐
│  User B's Profile                  │
│  ──────────────────────────────    │
│                                    │
│      [  Profile Picture  ]         │
│      User B Name                   │
│      @username                     │
│                                    │
│  ┌────────────────────────────┐   │
│  │        UNFOLLOW            │   │  ← Gray Color
│  └────────────────────────────┘   │
│                                    │
└────────────────────────────────────┘
```

---

## ❌ TEST 4: User B Declines Request

### Before Declining:
```
┌────────────────────────────────┐
│ 👤  User C Name                │
│     userc@email.com            │
│                       ✅  ❌    │ ← Click red X
└────────────────────────────────┘
```

### After Declining:
```
┌────────────────────────────────────┐
│  Follow Requests                   │
│  ──────────────────────────────    │
│                                    │
│  (User C removed from list)        │
│                                    │
│  ✓ Follow request declined         │ ← Toast Message
└────────────────────────────────────┘
```

### User C's View (unchanged):
```
┌────────────────────────────────────┐
│  User B's Profile                  │
│                                    │
│  ┌────────────────────────────┐   │
│  │         FOLLOW             │   │  ← Back to Follow (can retry)
│  └────────────────────────────┘   │
└────────────────────────────────────┘
```

---

## 🔄 TEST 5: User A Cancels Pending Request

### Before Canceling:
```
┌────────────────────────────────────┐
│  User D's Profile                  │
│                                    │
│  ┌────────────────────────────┐   │
│  │     CANCEL REQUEST         │   │  ← Orange, click it
│  └────────────────────────────┘   │
└────────────────────────────────────┘
```

### After Canceling:
```
┌────────────────────────────────────┐
│  User D's Profile                  │
│                                    │
│  ┌────────────────────────────┐   │
│  │         FOLLOW             │   │  ← Back to green
│  └────────────────────────────┘   │
│                                    │
│  ✓ Request cancelled               │  ← Toast Message
└────────────────────────────────────┘
```

---

## 🎯 BUTTON COLOR REFERENCE

| Button Text | Background Color | Meaning |
|-------------|------------------|---------|
| **FOLLOW** | 🟢 Green/Primary | Not following, can send request |
| **CANCEL REQUEST** | 🟠 Orange | Request is pending, can cancel |
| **UNFOLLOW** | ⚪ Gray | Currently following, can unfollow |

---

## 📝 QUICK CHECKLIST

### For Sender (User A):
- [ ] "Follow" button is green initially
- [ ] Button changes to "Cancel Request" (orange) after clicking
- [ ] Toast shows "Follow request sent"
- [ ] Can click "Cancel Request" to undo
- [ ] After accept: Button shows "Unfollow" (gray)

### For Receiver (User B):
- [ ] Can access Follow Requests screen from profile
- [ ] Sees list of pending requests
- [ ] Can accept request (green checkmark)
- [ ] Can decline request (red X)
- [ ] Request disappears after action
- [ ] Toast confirms action

---

## 🚀 START TESTING NOW

1. **Terminal 1:** Start backend
   ```bash
   cd backend
   npm start
   ```

2. **Terminal 2:** Run Flutter app
   ```bash
   cd frontend
   flutter run
   ```

3. **Login as User A** and send a follow request

4. **Login as User B** and check Follow Requests screen

5. **Verify all button states** match the diagrams above

---

## ✅ SUCCESS CRITERIA

Your system is working if:

✓ Button shows **3 different states** (Follow, Cancel Request, Unfollow)
✓ Button **colors change** appropriately  
✓ Toast messages appear after each action
✓ Follow Requests screen shows **pending requests**
✓ Accept/Decline **removes** request from list
✓ Accepted requests change button to **"Unfollow"**
✓ Status **persists** after app restart

**If all checked ✅ → System is WORKING! 🎉**
