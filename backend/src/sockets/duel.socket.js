/**
 * Duel Socket Handler
 * Handles real-time duel functionality with spectator support
 * Updated for Redis Clustering
 */

const spectatorService = require('../services/spectator.service');
const duelService = require('../services/duel.service');
const notificationService = require('../services/notification.service');
const userService = require('../services/user.service');
const { getRedisClient } = require('../config/redis');

// Fallback in-memory state (used if Redis is not available)
const activeRooms = new Map(); // roomId -> room data
const userRooms = new Map(); // userId -> roomId

// Helper functions for State Management (Redis or Memory)
// Helper functions for State Management (Redis or Memory)
async function getRoom(roomId) {
  const client = getRedisClient();
  if (!client) return activeRooms.get(roomId);

  // Use HGETALL to get all fields
  const data = await client.hgetall(`room:${roomId}`);
  if (!data || Object.keys(data).length === 0) return null;

  // Reconstruct room object
  const room = data.metadata ? JSON.parse(data.metadata) : {};

  // Reconstruct answers
  room.answers = {};
  Object.keys(data).forEach(key => {
    if (key.startsWith('answers:')) {
      const userId = key.split(':')[1];
      try {
        room.answers[userId] = JSON.parse(data[key]);
      } catch (e) { room.answers[userId] = {}; }
    }
  });

  // Reconstruct scores
  room.scores = {};
  Object.keys(data).forEach(key => {
    if (key.startsWith('score:')) {
      const userId = key.split(':')[1];
      room.scores[userId] = parseInt(data[key]) || 0;
    }
  });

  return room;
}

function generateRoomId() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function setRoom(roomId, data) {
  const client = getRedisClient();
  if (!client) {
    activeRooms.set(roomId, data);
    return;
  }

  // Split data into hash fields
  const { answers, scores, ...metadata } = data;

  const pipeline = client.pipeline();
  pipeline.hset(`room:${roomId}`, 'metadata', JSON.stringify(metadata));

  // Save answers if present (initial setup)
  if (answers) {
    Object.keys(answers).forEach(uid => {
      pipeline.hset(`room:${roomId}`, `answers:${uid}`, JSON.stringify(answers[uid]));
    });
  }

  // Save scores if present (initial setup)
  if (scores) {
    Object.keys(scores).forEach(uid => {
      pipeline.hset(`room:${roomId}`, `score:${uid}`, scores[uid]);
    });
  }

  // Set expiry (24 hours)
  pipeline.expire(`room:${roomId}`, 86400);

  await pipeline.exec();
}

// Atomic helper for answer submission
async function saveUserAnswer(roomId, userId, answerData) {
  const client = getRedisClient();
  if (!client) {
    const room = activeRooms.get(roomId);
    if (!room) return;
    if (!room.answers[userId]) room.answers[userId] = {};
    Object.assign(room.answers[userId], answerData);
    return;
  }

  // Get current answers for user to merge (serialized per user)
  const currentStr = await client.hget(`room:${roomId}`, `answers:${userId}`);
  const current = currentStr ? JSON.parse(currentStr) : {};

  // Merge new answer
  Object.assign(current, answerData);

  // Save back
  await client.hset(`room:${roomId}`, `answers:${userId}`, JSON.stringify(current));
  // Not strictly atomic R-M-W, but safe per-user
}

// Atomic helper for score update
async function incrementUserScore(roomId, userId, points) {
  const client = getRedisClient();
  if (!client) {
    const room = activeRooms.get(roomId);
    if (room) room.scores[userId] = (room.scores[userId] || 0) + points;
    return (room.scores[userId] || 0);
  }
  return await client.hincrby(`room:${roomId}`, `score:${userId}`, points);
}

async function deleteRoom(roomId) {
  const client = getRedisClient();
  if (!client) return activeRooms.delete(roomId);
  await client.del(`room:${roomId}`);
}

async function getUserRoom(userId) {
  const userIdStr = String(userId); // Ensure consistent type
  const client = getRedisClient();
  if (!client) return userRooms.get(userIdStr);
  const roomId = await client.get(`user_room:${userIdStr}`);
  console.log(`DEBUG: getUserRoom(${userIdStr}) = ${roomId}`);
  return roomId;
}

async function setUserRoom(userId, roomId) {
  const userIdStr = String(userId); // Ensure consistent type
  console.log(`DEBUG: setUserRoom(${userIdStr}, ${roomId})`);
  const client = getRedisClient();
  if (!client) return userRooms.set(userIdStr, roomId);
  await client.set(`user_room:${userIdStr}`, roomId, 'EX', 3600);
}

async function deleteUserRoom(userId) {
  const userIdStr = String(userId); // Ensure consistent type
  const client = getRedisClient();
  if (!client) return userRooms.delete(userIdStr);
  await client.del(`user_room:${userIdStr}`);
}

/**
 * Register duel event handlers
 * @param {Object} socket - Socket instance
 * @param {Object} io - Socket.IO server instance
 */
function registerEvents(socket, io) {
  // Simple heartbeat to keep connection alive
  socket.on('ping', () => {
    socket.emit('pong');
  });

  // Load Async Duel
  socket.on('duel:load', async (data) => {
    try {
      const { duelId } = data;
      // Use distinct prefix for DB-based duel rooms to avoid collision with random room codes
      const redisRoomId = `duel_${duelId}`;
      let room = await getRoom(redisRoomId);

      if (!room) {
        console.log(`DEBUG: Hydrating Duel ${duelId} from DB to Redis`);
        // Load from DB if not in Redis
        const duel = await duelService.getDuelById(duelId);

        // Initialize Room Data from DB Duel
        room = {
          id: redisRoomId,
          hostId: duel.player1Id,
          players: {
            [duel.player1Id]: { ready: true },
            [duel.player2Id]: { ready: true }
          },
          settings: {
            // Extract settings from challenge if possible, else defaults.
            // Since duel is created, questions are already fixed.
          },
          status: 'active',
          duelId: duel.id,
          currentQuestion: 0,
          scores: { [duel.player1Id]: 0, [duel.player2Id]: 0 },
          answers: { [duel.player1Id]: {}, [duel.player2Id]: {} },
          playerProgress: { [duel.player1Id]: 0, [duel.player2Id]: 0 },
          questions: duel.questions,
          createdAt: new Date().toISOString()
        };

        await setRoom(redisRoomId, room);
      }

      // Add user to room
      await setUserRoom(socket.userId, redisRoomId);
      socket.join(redisRoomId);

      // Emit Started with first question
      socket.emit('startDuel', {
        duelId: parseInt(duelId),
        roomId: redisRoomId,
        questions: room.questions,
        firstQuestion: {
          questionIndex: 0,
          question: room.questions[0],
          totalQuestions: room.questions.length,
          timeLimit: 30,
        },
        players: {
          [room.hostId]: { id: room.hostId },
          // Ensure opponent is included
          ...room.players
        }
      });

      // If duel is active, send current question to this player
      if (room.status === 'active') {
        const playerProgress = room.playerProgress?.[socket.userId] || 0;
        if (playerProgress < room.questions.length) {
          socket.emit('duel:next_question', {
            questionIndex: playerProgress,
            question: room.questions[playerProgress],
            totalQuestions: room.questions.length,
            timeLimit: 30,
          });
        }
      }

    } catch (error) {
      console.error('Load duel error:', error);
      socket.emit('duel:error', { message: 'Failed to load duel' });
    }
  });

  // Create Custom Room
  socket.on('duel:create_room', async (data) => {
    try {
      const { categoryId, difficultyId, questionCount = 7 } = data;

      let roomId;
      let attempts = 0;
      do {
        roomId = generateRoomId();
        const existing = await getRoom(roomId);
        if (!existing) break;
        attempts++;
      } while (attempts < 5);

      if (attempts >= 5) {
        throw new Error('Failed to generate unique room ID');
      }

      const roomData = {
        id: roomId,
        hostId: socket.userId,
        players: {
          [socket.userId]: { ready: true }
        },
        settings: { categoryId, difficultyId, questionCount },
        status: 'waiting',
        createdAt: new Date().toISOString(),
      };

      await setRoom(roomId, roomData);
      await setUserRoom(socket.userId, roomId);
      socket.join(roomId);

      socket.emit('duel:room_created', { roomId });
    } catch (error) {
      console.error('Create room error:', error);
      socket.emit('duel:error', { message: 'Failed to create room' });
    }
  });

  // Join Custom Room
  socket.on('duel:join_room', async (data) => {
    try {
      const { roomId } = data;
      const room = await getRoom(roomId);

      if (!room) {
        socket.emit('duel:error', { message: 'Room not found' });
        return;
      }

      if (room.status !== 'waiting' && room.status !== 'active' && room.status !== 'starting') {
        socket.emit('duel:error', { message: 'Room is not available' });
        return;
      }

      // Check if user is already in the room (handle both schema formats)
      const isAlreadyInRoom = room.players[socket.userId] || 
                             (room.players.challenger == socket.userId) || 
                             (room.players.opponent == socket.userId);

      if (!isAlreadyInRoom && Object.keys(room.players).length >= 2) {
        socket.emit('duel:error', { message: 'Room is full' });
        return;
      }

      // Add/Update player
      if (room.players[socket.userId]) {
         room.players[socket.userId].ready = true;
      } else {
         room.players[socket.userId] = { ready: true };
      }
      await setRoom(roomId, room); // Update room
      await setUserRoom(socket.userId, roomId);
      socket.join(roomId);

      // Start Duel
      const hostId = room.hostId;
      const opponentId = socket.userId;

      // If host is joining/re-joining, don't start duel yet
      if (hostId === opponentId) {
         return;
      }

      // Ensure host is also mapped to this room (critical for answer submission)
      await setUserRoom(hostId, roomId);

      // Create actual duel in DB
      const duel = await duelService.createDuel(hostId, opponentId, room.settings);

      // Update Duel with Room Code in DB
      await duelService.updateDuelRoomCode(duel.id, roomId);

      // Update room with duel data
      room.status = 'active';
      room.duelId = duel.id;
      room.currentQuestion = 0;
      room.scores = { [hostId]: 0, [opponentId]: 0 };
      room.answers = { [hostId]: {}, [opponentId]: {} };
      room.playerProgress = { [hostId]: 0, [opponentId]: 0 }; // Track individual progress
      room.questions = duel.questions; // Store questions in room

      await setRoom(roomId, room); // Save updated room

      // Ensure both players have their sockets in the room
      io.sockets.forEach((s) => {
        if (s.userId === hostId || s.userId === opponentId) {
          s.join(roomId);
        }
      });

      // Notify both players
      io.to(roomId).emit('duel:started', {
        duelId: duel.id,
        roomId: roomId, // CRITICAL: Frontend needs this for socket answer submission
        questions: duel.questions,
        firstQuestion: {
          questionIndex: 0,
          question: duel.questions[0],
          totalQuestions: duel.questions.length,
          timeLimit: 30,
        },
        players: {
          [hostId]: { id: hostId },
          [opponentId]: { id: opponentId }
        }
      });

      // Send first question to each player immediately
      startDuel(io, roomId);

    } catch (error) {
      console.error('Join room error:', error);
      socket.emit('duel:error', { message: error.message || 'Failed to join room' });
    }
  });

  // Send duel invitation
  socket.on('invite', async (data) => {
    try {
      const { challengeId, opponentId, settings } = data;

      // Send invitation to opponent
      const invitationData = {
        challengeId,
        challengerId: socket.userId,
        challengerEmail: socket.userEmail,
        settings,
        timestamp: new Date().toISOString(),
      };

      // Create persistent notification
      try {
        await notificationService.createNotification(
          opponentId,
          `${socket.userEmail || 'Someone'} challenged you to a duel!`,
          'duel_invite',
          invitationData
        );
      } catch (notifError) {
        console.error('Failed to create notification:', notifError);
      }

      // Send to user's room (works across cluster with Redis Adapter)
      io.to(`user:${opponentId}`).emit('inviteReceived', invitationData);

      socket.emit('inviteSent', {
        challengeId,
        opponentId,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      console.error('Duel invitation error:', error);
      socket.emit('inviteFailed', {
        error: 'Internal server error',
        challengeId: data.challengeId,
      });
    }
  });

  // Accept duel invitation
  socket.on('inviteAccepted', async (data) => {
    try {
      const { challengeId, challengerId } = data;

      // 1. Generate Unique 6-Digit Room ID
      let roomId;
      let attempts = 0;
      do {
        roomId = generateRoomId();
        const existing = await getRoom(roomId);
        if (!existing) break;
        attempts++;
      } while (attempts < 5);

      if (attempts >= 5) {
        socket.emit('duel:error', { error: 'Failed to generate room ID' });
        return;
      }

      // 2. Accept Challenge via Service (creates Duel if needed)
      console.log(`DEBUG: inviteAccepted challengeId: ${challengeId}, challengerId: ${challengerId}, roomId: ${roomId}`);
      const acceptanceResult = await challengeService.acceptChallenge(challengeId, socket.userId);
      
      if (!acceptanceResult || !acceptanceResult.duelId) {
         throw new Error('Failed to obtain duel ID from acceptance');
      }

      const duelId = acceptanceResult.duelId;
      const duel = await duelService.getDuelById(duelId);

      if (!duel) {
        socket.emit('duel:error', { error: 'Duel not found in database' });
        return;
      }

      // Update Duel with Room Code in DB
      await duelService.updateDuelRoomCode(duel.id, roomId);

      // 3. Create Room Data in Redis (if not exists)
      // We use setRoom with NX (not exist) logic implicitly by checking getRoom first
      let roomData = await getRoom(roomId);

      if (!roomData) {
        roomData = {
          id: roomId,
          challengeId,
          duelId: duel.id, // Store DB Duel ID
          players: {
            challenger: challengerId,
            opponent: socket.userId,
          },
          status: 'starting',
          createdAt: new Date().toISOString(),
          currentQuestion: 0,
          scores: {
            [challengerId]: 0,
            [socket.userId]: 0,
          },
          answers: {
            [challengerId]: {},
            [socket.userId]: {},
          },
          playerProgress: {
            [challengerId]: 0,
            [socket.userId]: 0,
          },
          questions: duel.questions || [], // Store questions in Redis for quick access
        };
        await setRoom(roomId, roomData);
      }

      // 4. Update User Mappings
      await setUserRoom(challengerId, roomId);
      await setUserRoom(socket.userId, roomId);

      console.log(`DEBUG: duel:accept challengeId: ${challengeId}, challengerId: ${challengerId}, roomId: ${roomId}`);

      // 5. Join Room
      socket.join(roomId);

      // Request challenger to join (if on another node)
      io.to(`user:${challengerId}`).emit('duel:join_room_request', { roomId });

      // 6. Notify Players
      // We emit 'duel:started' to match the custom room flow and provide questions
      const startPayload = {
        duelId: duel.id,
        challengeId,
        roomId,
        players: roomData.players,
        questions: duel.questions, // CRITICAL: Send questions to frontend
        firstQuestion: {
          questionIndex: 0,
          question: duel.questions[0],
          totalQuestions: duel.questions.length,
          timeLimit: 30,
        },
        timestamp: new Date().toISOString(),
      };

      console.log(`DEBUG: Emitting startDuel to room ${roomId} and user ${challengerId}`);
      io.to(roomId).emit('startDuel', startPayload);

      // Redundant emit to ensure challenger gets it (if not in room yet)
      io.to(`user:${challengerId}`).emit('startDuel', startPayload);

      // 7. Start Game - Send first question to each player
      setTimeout(() => {
        startDuel(io, roomId);
      }, 2000);

    } catch (error) {
      console.error('Duel accept error:', error);
      socket.emit('duel:error', {
        error: 'Failed to accept duel',
        challengeId: data.challengeId,
      });
    }
  });

  // Decline duel invitation
  socket.on('duel:decline', async (data) => {
    try {
      const { challengeId, challengerId } = data;

      // Notify challenger that invitation was declined
      io.to(`user:${challengerId}`).emit('duel:declined', {
        challengeId,
        declinedBy: socket.userId,
        timestamp: new Date().toISOString(),
      });

    } catch (error) {
      console.error('Duel decline error:', error);
    }
  });

  // Submit answer - ASYNC FLOW: Player advances immediately, no waiting for opponent
  socket.on('duel:submit_answer', async (data) => {
    socket.emit('duel:debug', { message: 'Received submit_answer' });
    try {
      const { questionId, answer } = data;
      const timeUsed = Number(data.timeUsed) || 0;
      const roomId = await getUserRoom(socket.userId);

      console.log(`[SUBMIT_ANSWER] User ${socket.userId} roomId: ${roomId}`);

      if (!roomId) {
        console.error(`[SUBMIT_ANSWER] User ${socket.userId} has no room mapping!`);
        socket.emit('duel:error', { error: 'Not in an active duel' });
        return;
      }

      const room = await getRoom(roomId);
      if (!room) {
        socket.emit('duel:error', { error: 'Room not found' });
        return;
      }

      // Get current question index for THIS player (individual progress)
      const playerProgress = room.playerProgress || {};
      const currentQuestionIndex = playerProgress[socket.userId] || 0;
      const question = room.questions[currentQuestionIndex];

      if (!question) {
        socket.emit('duel:error', { error: 'No more questions' });
        return;
      }

      // Handle skipped/null answer
      const isSkipped = !answer || answer === '' || answer === null;

      // 1. Persist to Database
      const result = await duelService.submitAnswer(
        room.duelId,
        socket.userId,
        question.id,
        isSkipped ? null : answer,
        timeUsed
      );

      // 2. Update Redis/Memory State
      const answerData = {
        [currentQuestionIndex]: {
          answer: isSkipped ? null : answer,
          timeUsed,
          isCorrect: isSkipped ? false : result.isCorrect,
          isSkipped,
          timestamp: new Date().toISOString(),
        }
      };
      await saveUserAnswer(roomId, socket.userId, answerData);

      // Update local room object to prevent overwriting with stale data in setRoom
      if (!room.answers) room.answers = {};
      if (!room.answers[socket.userId]) room.answers[socket.userId] = {};
      Object.assign(room.answers[socket.userId], answerData);

      // Update score (no points for skipped)
      if (!isSkipped && result.isCorrect) {
        const points = Math.max(1000 - (timeUsed * 10), 100);
        await incrementUserScore(roomId, socket.userId, points);
        
        // Update local room object
        if (!room.scores) room.scores = {};
        room.scores[socket.userId] = (room.scores[socket.userId] || 0) + points;
      }

      // 3. Update this player's progress to next question
      const nextQuestionIndex = currentQuestionIndex + 1;
      playerProgress[socket.userId] = nextQuestionIndex;
      room.playerProgress = playerProgress;
      
      socket.emit('duel:debug', { message: `Progress updated: ${nextQuestionIndex}/${room.questions.length}` });

      // CRITICAL: Exclude answers/scores from setRoom to avoid overwriting Redis with stale data
      // We already updated them atomically via saveUserAnswer/incrementUserScore
      const { answers: _a, scores: _s, ...roomUpdate } = room;
      await setRoom(roomId, roomUpdate);

      // 4. Get updated scores and progress for BOTH players
      const updatedRoom = await getRoom(roomId);

      // Get opponent ID
      const playersToCheck = room.players ?
        (room.players.challenger ? [room.players.challenger, room.players.opponent] : Object.keys(room.players))
        : Object.keys(room.scores);
      const opponentId = playersToCheck.find(id => parseInt(id) !== socket.userId);

      // 5. Send immediate result to THIS player only
      socket.emit('duel:answer_result', {
        questionIndex: currentQuestionIndex,
        isCorrect: isSkipped ? false : result.isCorrect,
        isSkipped,
        correctAnswer: question.correctOption,
        currentScore: updatedRoom.scores[socket.userId] || 0,
        yourProgress: nextQuestionIndex,
        opponentProgress: updatedRoom.playerProgress?.[opponentId] || 0,
        totalQuestions: room.questions.length,
      });

      // 6. Notify opponent with DETAILED progress update
      socket.to(roomId).emit('duel:opponent_answered', {
        opponentId: socket.userId,
        opponentProgress: nextQuestionIndex,
        yourProgress: updatedRoom.playerProgress?.[opponentId] || 0,
        totalQuestions: room.questions.length,
        opponentScore: updatedRoom.scores[socket.userId] || 0,
        yourScore: updatedRoom.scores[opponentId] || 0,
        message: `Opponent answered question ${currentQuestionIndex + 1}`,
      });

      // Notify Spectators
      io.to(roomId).emit('spectator:update', {
        playerId: socket.userId,
        progress: nextQuestionIndex,
        score: updatedRoom.scores[socket.userId] || 0,
        scores: updatedRoom.scores,
        playerProgress: updatedRoom.playerProgress
      });

      // 7. Send next question to THIS player or finish
      if (nextQuestionIndex < room.questions.length) {
        const nextQuestion = room.questions[nextQuestionIndex];
        socket.emit('duel:next_question', {
          questionIndex: nextQuestionIndex,
          question: nextQuestion,
          totalQuestions: room.questions.length,
          timeLimit: 30,
        });
      } else {
        // This player finished!
        // Calculate stats
        let correct = 0;
        let wrong = 0;
        let skipped = 0;
        let timeTaken = 0;
        
        if (room.answers && room.answers[socket.userId]) {
             Object.values(room.answers[socket.userId]).forEach(a => {
                 timeTaken += (Number(a.timeUsed) || 0);
                 if (a.isSkipped) skipped++;
                 else if (a.isCorrect) correct++;
                 else wrong++;
             });
        }

        socket.emit('duel:player_finished', {
          message: 'You finished! Waiting for opponent...',
          yourScore: updatedRoom.scores[socket.userId] || 0,
          totalQuestions: room.questions.length,
          stats: {
              correctAnswers: correct,
              wrongAnswers: wrong,
              skippedAnswers: skipped,
              timeTaken: timeTaken
          }
        });
      }

      // 8. Check if BOTH players finished (reuse playersToCheck from above)
      const allFinished = playersToCheck.every(id =>
        (updatedRoom.playerProgress?.[id] || 0) >= room.questions.length
      );

      const debugMsg = `[DEBUG] Check Finished: ${allFinished}. Progress: ${JSON.stringify(updatedRoom.playerProgress)}`;
      console.log(debugMsg);
      io.to(roomId).emit('duel:debug', { message: debugMsg });

      if (allFinished) {
        console.log(`[DEBUG] All finished. Ending duel ${roomId}`);
        io.to(roomId).emit('duel:debug', { message: `Ending duel ${roomId}` });
        endDuel(io, roomId);
      }

    } catch (error) {
      console.error('Submit answer error:', error);
      socket.emit('duel:error', {
        error: error.message || 'Failed to submit answer',
      });
    }
  });

  // Early Leave - Player finishes and leaves before opponent
  socket.on('duel:leave_early', async (data) => {
    try {
      const roomId = await getUserRoom(socket.userId);
      if (!roomId) {
        socket.emit('duel:error', { error: 'Not in an active duel' });
        return;
      }

      const room = await getRoom(roomId);
      if (!room) {
        socket.emit('duel:error', { error: 'Room not found' });
        return;
      }

      // Check if this player has finished all questions
      const playerProgress = room.playerProgress?.[socket.userId] || 0;
      const totalQuestions = room.questions?.length || 0;

      if (playerProgress < totalQuestions) {
        socket.emit('duel:error', {
          error: 'You must finish all questions before leaving',
          yourProgress: playerProgress,
          totalQuestions: totalQuestions
        });
        return;
      }

      // Mark player as left early
      if (!room.leftEarly) room.leftEarly = {};
      room.leftEarly[socket.userId] = true;
      await setRoom(roomId, room);

      // Remove user from room mapping (they're leaving)
      await deleteUserRoom(socket.userId);
      socket.leave(roomId);

      // Confirm to player they can leave
      socket.emit('duel:left_early', {
        message: 'You have left the duel. Results will be sent when your opponent finishes.',
        yourScore: room.scores[socket.userId] || 0,
        yourProgress: playerProgress,
        totalQuestions: totalQuestions
      });

      // Notify opponent that player left
      socket.to(roomId).emit('duel:opponent_left_early', {
        message: 'Opponent finished and left. Complete your questions to see results.',
        opponentScore: room.scores[socket.userId] || 0
      });

      console.log(`User ${socket.userId} left duel ${roomId} early after finishing`);

    } catch (error) {
      console.error('Early leave error:', error);
      socket.emit('duel:error', { message: 'Failed to leave duel' });
    }
  });

  // Spectator Join
  socket.on('spectator:join', async (data) => {
    try {
      const { duelId } = data;
      // Find room by duelId (we might need a mapping or search)
      // For now, assume we can find it or client sends roomId. 
      // If client sends duelId, we need to find the room.
      // Since we don't have a direct duelId -> roomId map in Redis easily accessible without scanning,
      // we'll assume the client sends the roomId (which they can get from the API).
      // But wait, the API returns duelId.
      // Let's try to find the room.
      
      let roomId = data.roomId;
      if (!roomId && duelId) {
         // Try to find room by duelId (this is expensive if we scan, but maybe we can use the DB)
         const duel = await duelService.getDuelById(duelId);
         if (duel && duel.roomCode) {
            roomId = duel.roomCode;
         }
      }

      if (!roomId) {
        socket.emit('spectator:error', { message: 'Room not found' });
        return;
      }

      const room = await getRoom(roomId);
      if (!room) {
        socket.emit('spectator:error', { message: 'Duel not active' });
        return;
      }

      socket.join(roomId);
      
      // Send initial state
      socket.emit('spectator:joined', {
        roomId,
        duelId: room.duelId,
        players: room.players,
        scores: room.scores,
        playerProgress: room.playerProgress,
        questions: room.questions,
        status: room.status
      });

    } catch (error) {
      console.error('Spectator join error:', error);
      socket.emit('spectator:error', { message: 'Failed to join as spectator' });
    }
  });

  // Leave duel
  socket.on('duel:leave', async (data) => {
    try {
      const roomId = await getUserRoom(socket.userId);
      if (roomId) {
        handlePlayerLeave(io, socket, roomId);
      }
    } catch (error) {
      console.error('Duel leave error:', error);
    }
  });

  // Handle join room request (for clustering support)
  socket.on('duel:join_room_ack', async (data) => {
    const roomId = data.roomId;
    socket.join(roomId);
    // CRITICAL: Set user-room mapping for this socket user
    await setUserRoom(socket.userId, roomId);
    console.log(`DEBUG: User ${socket.userId} joined room ${roomId} via ack`);
  });

  // Rematch feature removed for simplicity

  // Rematch accept handler removed

  // Matchmaking Queue
  const matchmakingQueue = []; // Simple in-memory queue for now

  socket.on('duel:join_queue', async (data) => {
    try {
      const { categoryId } = data;

      // Remove if already in queue
      const existingIndex = matchmakingQueue.findIndex(p => p.userId === socket.userId);
      if (existingIndex !== -1) {
        matchmakingQueue.splice(existingIndex, 1);
      }

      // Add to queue
      matchmakingQueue.push({
        userId: socket.userId,
        socketId: socket.id,
        categoryId,
        rating: socket.userRating || 1200,
        timestamp: Date.now()
      });

      socket.emit('duel:queue_joined', { message: 'Joined matchmaking queue' });

      // Check for match
      // Find opponent with same category
      const opponentIndex = matchmakingQueue.findIndex(p =>
        p.userId !== socket.userId &&
        (p.categoryId === categoryId || !categoryId || !p.categoryId) // optional category match
      );

      if (opponentIndex !== -1) {
        const opponent = matchmakingQueue[opponentIndex];
        // Remove both from queue
        // We need to remove current user (last added) and opponent
        matchmakingQueue.splice(matchmakingQueue.indexOf(opponent), 1);
        const currentUserIndex = matchmakingQueue.findIndex(p => p.userId === socket.userId);
        if (currentUserIndex !== -1) matchmakingQueue.splice(currentUserIndex, 1);

        // CREATE DUEL
        const roomId = generateRoomId();

        // Ensure unique room
        // ... (skip unique check for speed, assume random is enough for now or use retry loop)

        // Create duel in DB
        const duel = await duelService.createDuel(socket.userId, opponent.userId, {
          categoryId: categoryId || opponent.categoryId, // Use one of them
          difficultyId: 2, // Default Medium
          questionCount: 7
        });

        await duelService.updateDuelRoomCode(duel.id, roomId);

        // Create Redis Room
        const roomData = {
          id: roomId,
          duelId: duel.id,
          players: {
            challenger: socket.userId,
            opponent: opponent.userId,
          },
          status: 'active',
          createdAt: new Date().toISOString(),
          currentQuestion: 0,
          scores: {
            [socket.userId]: 0,
            [opponent.userId]: 0,
          },
          answers: {
            [socket.userId]: {},
            [opponent.userId]: {},
          },
          playerProgress: {
            [socket.userId]: 0,
            [opponent.userId]: 0,
          },
          questions: duel.questions,
        };
        await setRoom(roomId, roomData);

        // Update User Rooms
        await setUserRoom(socket.userId, roomId);
        await setUserRoom(opponent.userId, roomId);

        // Join Sockets
        socket.join(roomId);
        // Note: Opponent socket might be on another node if clustered, 
        // but for now assume same node or rely on client re-join logic?
        // Actually, we can use io.to(socketId).socketsJoin(roomId) if on same node.
        // Or emit 'duel:match_found' -> client joins room.

        // Better: Emit 'duel:started' to both users directly via user channel
        const startPayload = {
          duelId: duel.id,
          roomId,
          questions: duel.questions,
          players: roomData.players,
          timestamp: new Date().toISOString(),
        };

        io.to(socket.id).emit('duel:started', startPayload);
        io.to(`user:${opponent.userId}`).emit('duel:started', startPayload);

        // Also ensure they join the socket room channel for game events
        socket.join(roomId);
        // We can't force remote socket to join via Redis.
        // We send 'duel:join_room_request' to opponent
        io.to(`user:${opponent.userId}`).emit('duel:join_room_request', { roomId });

        // Start game loop
        setTimeout(() => {
          startDuel(io, roomId);
        }, 3000);

      }
    } catch (error) {
      console.error('Matchmaking error:', error);
      socket.emit('duel:error', { message: 'Failed to join queue' });
    }
  });

  socket.on('duel:leave_queue', () => {
    const index = matchmakingQueue.findIndex(p => p.userId === socket.userId);
    if (index !== -1) {
      matchmakingQueue.splice(index, 1);
      socket.emit('duel:queue_left', { message: 'Left matchmaking queue' });
    }
  });

  // Second rematch handler removed
}

/**
 * Start a duel
 * @param {Object} io - Socket.IO server instance
 * @param {string} roomId - Room ID
 */
async function startDuel(io, roomId) {
  const room = await getRoom(roomId);
  if (!room) {
    console.error(`startDuel: Room ${roomId} not found`);
    return;
  }

  if (!room.questions || room.questions.length === 0) {
    console.error(`startDuel: No questions in room ${roomId}`);
    io.to(roomId).emit('duel:error', { message: 'No questions available for this duel' });
    return;
  }

  room.status = 'active';
  room.startedAt = new Date().toISOString();
  await setRoom(roomId, room);

  // Get player IDs
  const players = room.players ?
    (room.players.challenger ? [room.players.challenger, room.players.opponent] : Object.keys(room.players))
    : Object.keys(room.scores);

  // Send first question to EACH player individually (async flow)
  players.forEach(playerId => {
    const playerIdNum = parseInt(playerId);
    io.to(`user:${playerIdNum}`).emit('duel:next_question', {
      questionIndex: 0,
      question: room.questions[0],
      totalQuestions: room.questions.length,
      timeLimit: 30,
      timestamp: new Date().toISOString(),
    });
  });

  console.log(`✅ Duel started in room ${roomId} with ${room.questions.length} questions. First question sent to ${players.length} players.`);
}

// Old sync sendQuestion() removed - replaced with async per-player flow in duel:submit_answer handler

/**
 * End a duel
 * @param {Object} io - Socket.IO server instance
 * @param {string} roomId - Room ID
 */
async function endDuel(io, roomId) {
  const room = await getRoom(roomId);
  if (!room) return;

  if (room.status === 'completed') return;

  room.status = 'completed';
  room.endedAt = new Date().toISOString();
  await setRoom(roomId, room);

  let playerIds = [];
  if (room.players.challenger) {
    playerIds = [room.players.challenger, room.players.opponent];
  } else {
    playerIds = Object.keys(room.players);
  }

  const p1 = String(playerIds[0]);
  const p2 = String(playerIds[1]);
  const s1 = Number(room.scores[p1]) || 0;
  const s2 = Number(room.scores[p2]) || 0;

  // Fetch player info
  let player1Info = {};
  let player2Info = {};
  
  try {
    const [u1, u2] = await Promise.all([
      userService.getUserProfile(p1),
      userService.getUserProfile(p2)
    ]);
    player1Info = { name: u1.username, avatar: u1.avatarUrl, rating: u1.rating };
    player2Info = { name: u2.username, avatar: u2.avatarUrl, rating: u2.rating };
  } catch (e) {
    console.error('Failed to fetch player info for duel end:', e);
    // Fallback if fetch fails
    player1Info = { name: 'Player 1', avatar: null };
    player2Info = { name: 'Player 2', avatar: null };
  }

  // Calculate total time taken per player FIRST (needed for tie-breaker)
  let player1TotalTime = 0;
  let player2TotalTime = 0;
  let player1Correct = 0;
  let player1Wrong = 0;
  let player1Skipped = 0;
  let player2Correct = 0;
  let player2Wrong = 0;
  let player2Skipped = 0;
  
  if (room.answers) {
    Object.values(room.answers[p1] || {}).forEach(a => { 
      player1TotalTime += (Number(a.timeUsed) || 0);
      if (a.isSkipped) player1Skipped++;
      else if (a.isCorrect) player1Correct++;
      else player1Wrong++;
    });
    Object.values(room.answers[p2] || {}).forEach(a => { 
      player2TotalTime += (Number(a.timeUsed) || 0);
      if (a.isSkipped) player2Skipped++;
      else if (a.isCorrect) player2Correct++;
      else player2Wrong++;
    });
  }

  // Determine winner with Tie-Breaker (Score > Time)
  let winnerId = null;
  if (s1 > s2) {
    winnerId = p1;
  } else if (s2 > s1) {
    winnerId = p2;
  } else {
    // Scores are equal, check time (lower is better)
    if (player1TotalTime < player2TotalTime) {
      winnerId = p1;
    } else if (player2TotalTime < player1TotalTime) {
      winnerId = p2;
    } else {
      winnerId = null; // True Tie
    }
  }

  const finalResults = {
    duelId: room.duelId,
    challengeId: room.challengeId,
    roomId,
    winnerId,
    scores: room.scores,
    players: {
      [p1]: { 
        ...player1Info, 
        score: s1, 
        timeTaken: player1TotalTime,
        correctAnswers: player1Correct,
        wrongAnswers: player1Wrong,
        skippedAnswers: player1Skipped
      },
      [p2]: { 
        ...player2Info, 
        score: s2, 
        timeTaken: player2TotalTime,
        correctAnswers: player2Correct,
        wrongAnswers: player2Wrong,
        skippedAnswers: player2Skipped
      }
    },
    totalQuestions: room.questions?.length || 0,
    endedAt: room.endedAt,
  };

  // Send final results to players still in room
  io.to(roomId).emit('duel:completed', finalResults);

  // IMPORTANT: Send notifications to players who left early
  // They won't receive the socket event, so send via notification system
  const notificationService = require('../services/notification.service');

  if (room.leftEarly) {
    for (const playerId of Object.keys(room.leftEarly)) {
      if (room.leftEarly[playerId]) {
        try {
          const playerIdStr = String(playerId);
          const opponentId = playerIdStr === p1 ? p2 : p1;
          const opponentName = playerIdStr === p1 ? player2Info.name : player1Info.name;
          const playerScore = room.scores[playerId] || 0;
          const opponentScore = room.scores[opponentId] || 0;

          let resultMessage;
          if (winnerId === playerIdStr) {
            resultMessage = `🏆 Duel Complete! You WON against ${opponentName}! Score: ${playerScore} - ${opponentScore}`;
          } else if (winnerId === opponentId) {
            resultMessage = `😔 Duel Complete! You lost to ${opponentName}. Score: ${playerScore} - ${opponentScore}`;
          } else {
            resultMessage = `🤝 Duel Complete! It's a TIE with ${opponentName}! Score: ${playerScore} - ${opponentScore}`;
          }

          // Create persistent notification
          await notificationService.createNotification(
            playerIdInt,
            resultMessage,
            'duel_result',
            {
              duelId: room.duelId,
              winnerId,
              yourScore: playerScore,
              opponentScore: opponentScore,
              opponentName: opponentName,
              finalResults: finalResults
            }
          );

          // Also try to send via socket in case they're still connected
          io.to(`user:${playerId}`).emit('duel:completed', finalResults);
          io.to(`user:${playerId}`).emit('notification', {
            type: 'duel_result',
            message: resultMessage,
            data: finalResults
          });

          console.log(`Sent result notification to early leaver: ${playerId}`);
        } catch (notifError) {
          console.error(`Failed to send notification to early leaver ${playerId}:`, notifError);
        }
      }
    }
  }

  // Send winner notification to active players
  try {
    const winnerName = winnerId === p1 ? player1Info.name : player2Info.name;
    const loserName = winnerId === p1 ? player2Info.name : player1Info.name;
    const loserId = winnerId === p1 ? p2 : p1;

    if (winnerId) {
      // Notify winner (if not already notified as early leaver)
      if (!room.leftEarly?.[winnerId]) {
        io.to(`user:${winnerId}`).emit('notification', {
          type: 'duel_result',
          message: `🏆 You won against ${loserName}! Score: ${room.scores[winnerId]} - ${room.scores[loserId]}`,
          duelId: room.duelId,
        });
      }
      // Notify loser (if not already notified as early leaver)
      if (!room.leftEarly?.[loserId]) {
        io.to(`user:${loserId}`).emit('notification', {
          type: 'duel_result',
          message: `😔 You lost to ${winnerName}. Score: ${room.scores[loserId]} - ${room.scores[winnerId]}`,
          duelId: room.duelId,
        });
      }
    } else {
      // It's a tie - notify both if not early leavers
      if (!room.leftEarly?.[p1]) {
        io.to(`user:${p1}`).emit('notification', {
          type: 'duel_result',
          message: `🤝 It's a tie with ${player2Info.name}! Score: ${s1} - ${s2}`,
          duelId: room.duelId,
        });
      }
      if (!room.leftEarly?.[p2]) {
        io.to(`user:${p2}`).emit('notification', {
          type: 'duel_result',
          message: `🤝 It's a tie with ${player1Info.name}! Score: ${s2} - ${s1}`,
          duelId: room.duelId,
        });
      }
    }
  } catch (error) {
    console.error('Failed to send winner notification:', error);
  }

  // Clean up
  setTimeout(() => {
    cleanup(roomId);
  }, 10000);
}

/**
 * Handle player disconnection
 * @param {Object} socket - Socket instance
 * @param {Object} io - Socket.IO server instance
 */
async function handleDisconnection(socket, io) {
  const roomId = await getUserRoom(socket.userId);
  if (roomId) {
    handlePlayerLeave(io, socket, roomId);
  }
}

/**
 * Handle player leaving duel
 * @param {Object} io - Socket.IO server instance
 * @param {Object} socket - Socket instance
 * @param {string} roomId - Room ID
 */
async function handlePlayerLeave(io, socket, roomId) {
  const room = await getRoom(roomId);
  if (!room) return;

  // Notify other players
  socket.to(roomId).emit('duel:player_left', {
    userId: socket.userId,
    timestamp: new Date().toISOString(),
  });

  // If duel is active, end it
  if (room.status === 'active') {
    endDuel(io, roomId);
  } else {
    // Clean up immediately if duel hasn't started
    cleanup(roomId);
  }
}

/**
 * Clean up room and user mappings
 * @param {string} roomId - Room ID
 */
async function cleanup(roomId) {
  const room = await getRoom(roomId);
  if (!room) return;

  // Remove user room mappings
  let playerIds = [];
  if (room.players.challenger) {
    playerIds = [room.players.challenger, room.players.opponent];
  } else {
    playerIds = Object.keys(room.players);
  }

  for (const userId of playerIds) {
    await deleteUserRoom(userId);
  }

  // Remove room
  await deleteRoom(roomId);

  console.log(`Duel room ${roomId} cleaned up`);
}

module.exports = {
  registerEvents,
  handleDisconnection,
};