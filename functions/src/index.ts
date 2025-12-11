import {setGlobalOptions} from "firebase-functions";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

// Init
setGlobalOptions({ maxInstances: 10 });
initializeApp();
const db = getFirestore();

/**
 * createUserProfile
 *
 * Callable from the client AFTER the user has signed up with Firebase Auth.
 * It:
 *  - checks auth
 *  - checks username uniqueness
 *  - writes users/{uid} and subcollections
 *  - writes usernames/{handle}
*/

export const createUserProfile = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  const uid = auth.uid;
  const { username, email } = request.data ?? {};

  if (typeof username !== "string" || !username.trim()) {
    throw new HttpsError("invalid-argument", "username is required.");
  }
  if (typeof email !== "string" || !email.trim()) {
    throw new HttpsError("invalid-argument", "email is required.");
  }

  const rawUsername = username.trim();
  const handle = rawUsername.toLowerCase();

  if (rawUsername.length > 15) {
    throw new HttpsError(
      "invalid-argument",
      "Username must be at most 15 characters."
    );
  }

  const now = FieldValue.serverTimestamp();

  try {
    await db.runTransaction(async (tx) => {
      const userRef = db.collection("users").doc(uid);
      const usernamesRef = db.collection("username").doc(handle);
      const privateCoreRef = userRef.collection("private").doc("core");
      const achievementsRef = userRef.collection("achievements").doc("_init");
      const progressRef = userRef.collection("levelProgress").doc("_init");
      const materialsRef = userRef.collection("inGameMaterials").doc("_init");

      // Ensure handle not taken
      const unameSnap = await tx.get(usernamesRef);
      if (unameSnap.exists) {
        throw new HttpsError("already-exists", "That username is already taken.");
      }

      // users/{uid}
      tx.set(userRef, {
        uid,
        username: rawUsername,
        iq: 0,
        profilePicUrl: null,
        createdAt: now,

        // 🔹 NEW FIELDS
        trophies: 0,
        rank: 0,           // starting global rank
        league: "Bronze",  // or "Unranked", etc.
        avatar: "defaultBrain",
        language: "english",
        acceptedPrivacy: false,
        acceptedTerms: false,
        coins: 0,
        intyCards: 0,
        replayCards: 0,
        skipCards: 0,
        easyLevelsPassed: 0,
        mediumLevelsPassed: 0,
        hardLevelsPassed: 0,
        expertLevelsPassed: 0,
        masterLevelsPassed: 0,
        extremeLevelsPassed: 0,
        impossibleLevelsPassed: 0,
      });

      // users/{uid}/private/core
      tx.set(privateCoreRef, {
        email,
        createdAt: now,
      });

      // usernames/{handle}
      tx.set(usernamesRef, {
        uid,
        username: rawUsername,
        reservedAt: now,
      });

      // Init subcollections
      tx.set(achievementsRef, {
        placeholder: true,
        createdAt: now,
      });

      tx.set(progressRef, {
        placeholder: true,
        createdAt: now,
      });

      tx.set(materialsRef, {
        placeholder: true,
        createdAt: now,
      });
    });

    logger.info(`User profile created for uid=${uid}, username=${rawUsername}`);
    return { ok: true };
  } catch (err: any) {
    if (err instanceof HttpsError) {
      throw err;
    }

    logger.error("createUserProfile failed", err);
    throw new HttpsError("internal", "Failed to create user profile.");
  }
});

//-----------RESETPRIVACY AND TERMS-----------

export const resetLegalFlags = onCall(async (request) => {
  const auth = request.auth;

  // 🔒 Admin-only guard
  if (!auth || !auth.token || auth.token.admin !== true) {
    throw new HttpsError(
      "permission-denied",
      "Only admins can run this function."
    );
  }

  try {
    const usersSnap = await db.collection("users").get();
    logger.info(
      `resetLegalFlags: found ${usersSnap.size} user documents to update.`
    );

    let updatedCount = 0;
    let batch = db.batch();
    let batchOps = 0;

    const commitBatch = async () => {
      if (batchOps === 0) return;
      await batch.commit();
      logger.info(`resetLegalFlags: committed batch with ${batchOps} ops.`);
      batch = db.batch();
      batchOps = 0;
    };

    for (const doc of usersSnap.docs) {
      batch.update(doc.ref, {
        acceptedPrivacy: false,
        acceptedTerms: false,
      });
      updatedCount++;
      batchOps++;

      if (batchOps >= 450) {
        await commitBatch();
      }
    }

    await commitBatch();

    logger.info(
      `resetLegalFlags: successfully updated ${updatedCount} user documents.`
    );

    return { ok: true, updatedCount };
  } catch (err: any) {
    logger.error("resetLegalFlags failed", err);
    throw new HttpsError(
      "internal",
      "Failed to reset acceptedTerms/acceptedPrivacy for all users."
    );
  }
});

//-----------CREATEGAME-----------

type DifficultyId =
  | 'easy'
  | 'medium'
  | 'hard'
  | 'expert'
  | 'master'
  | 'extreme'
  | 'impossible';

const difficultyConfig: Record<
  DifficultyId,
  {
    numberOfMoves: number;
    coinsReward: number;
    baseIqPotential: number;   // 👈 maximum IQ you can earn for a perfect run
    targetTimeSeconds: number; // 👈 “ideal” completion time for this difficulty
  }
> = {
  easy:       { numberOfMoves: 7,  coinsReward: 30,  baseIqPotential: 10, targetTimeSeconds: 60  },
  medium:     { numberOfMoves: 12,  coinsReward: 60,  baseIqPotential: 15, targetTimeSeconds: 90  },
  hard:       { numberOfMoves: 17,  coinsReward: 90, baseIqPotential: 20, targetTimeSeconds: 120 },
  expert:     { numberOfMoves: 25, coinsReward: 140, baseIqPotential: 30, targetTimeSeconds: 150 },
  master:     { numberOfMoves: 32, coinsReward: 200, baseIqPotential: 40, targetTimeSeconds: 180 },
  extreme:    { numberOfMoves: 40, coinsReward: 500, baseIqPotential: 50, targetTimeSeconds: 210 },
  impossible: { numberOfMoves: 50, coinsReward: 1000, baseIqPotential: 70, targetTimeSeconds: 240 },
};

export const startNewGame = onCall(
  { region: 'us-central1' },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'You must be signed in.');
    }

    const rawDifficulty = request.data?.difficulty;
    const difficulty = String(rawDifficulty ?? '').toLowerCase() as DifficultyId;

    const allowed: DifficultyId[] = [
      'easy',
      'medium',
      'hard',
      'expert',
      'master',
      'extreme',
      'impossible',
    ];

    if (!allowed.includes(difficulty)) {
      throw new HttpsError(
        'invalid-argument',
        `Invalid difficulty "${rawDifficulty}".`
      );
    }

    const cfg = difficultyConfig[difficulty];

    // 👇 Base map that ALWAYS exists for any difficulty
    const currentGame: Record<string, unknown> = {
      difficulty,                     // "easy" | "medium" | ...
      incorrects: 0,                  // mistakes so far (overall run)
      time: 0,                        // total time spent so far (seconds)
      timestamp: FieldValue.serverTimestamp(),
      currentMove: 0,                 // index in the current script, if you want

      requiredMoves: cfg.numberOfMoves, // moves needed to clear the base level
      ExtraMovesDone: 0,               // EXTRA correct moves after clearing

      coinsReward: cfg.coinsReward,
      iqPotential: cfg.baseIqPotential,
    };

    // Extra fields only for expert+
    if (['expert', 'master', 'extreme', 'impossible'].includes(difficulty)) {
      currentGame['skipsUsed']   = 0;
      currentGame['replaysUsed'] = 0;
      currentGame['intysUsed']   = 0;
    }

    const userRef = db.collection('users').doc(uid);

    await userRef.set(
      {
        currentGame,
      },
      { merge: true }
    );

    return {
      ok: true,
      difficulty,
      currentGame,
    };
  }
);

//-----------IQ CALCULATOR-----------

export function computeIqReward(params: {
  difficulty: DifficultyId;
  incorrects: number;      // total mistakes in the whole run
  timeSeconds: number;     // total time spent
  requiredMoves: number;   // from config (base pattern length)
  ExtraMovesDone: number;  // EXTRA moves after beating the level
  skipsUsed: number;       // 0+ (only matters for expert+)
  replaysUsed: number;
  intysUsed: number;
}): number {
  const cfg = difficultyConfig[params.difficulty];
  const base = cfg.baseIqPotential;

  // 1) Accuracy – 0 mistakes = 1.0, 1 ≈ 0.7, 2+ ≈ 0.35
  const mistakes = Math.max(0, Math.min(2, params.incorrects));
  const accuracyFactor = [1.0, 0.7, 0.35][mistakes];

  // 2) Speed – relative to targetTimeSeconds
  const t = Math.max(1, params.timeSeconds);
  const target = cfg.targetTimeSeconds;
  const speedRatio = t / target;

  const speedFactor =
    speedRatio <= 1
      ? 1.0      // fast or on time
      : speedRatio <= 2
      ? 0.7      // up to 2x slower
      : 0.4;     // very slow

  // 3) Streak bonus – extra moves AFTER beating the level
  //    Every full "pattern length" of extra moves gives +50% bonus,
  //    capped so it doesn't blow up.
  const req = Math.max(1, params.requiredMoves);
  const extra = Math.max(0, params.ExtraMovesDone);

  const streakBase = 1 + 0.5 * (extra / req); // +0.5x per full pattern of extras
  const streakFactor = Math.min(3, streakBase); // cap at 3x total bonus

  // 4) Card penalty – more cards = less IQ (only really relevant for expert+)
  const totalCards =
    Math.max(0, params.skipsUsed) +
    Math.max(0, params.replaysUsed) +
    Math.max(0, params.intysUsed);

  // Each card reduces 10%, but never below 40%
  const cardPenaltyFactor = Math.max(0.4, 1 - 0.1 * totalCards);

  // Final reward
  const raw =
    base *
    accuracyFactor *
    speedFactor *
    streakFactor *
    cardPenaltyFactor;

  return Math.max(0, Math.round(raw));
}

//-----------FINISH GAME AND GIVE IQ+COINS-----------

export const finishGame = onCall({ region: "us-central1" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "You must be signed in.");

  const userRef = db.collection("users").doc(uid);
  const snap = await userRef.get();
  const data = snap.data() ?? {};
  const cg = data.currentGame as any;

  if (!cg || !cg.difficulty) {
    throw new HttpsError("failed-precondition", "No active game.");
  }

  const difficulty = cg.difficulty as DifficultyId;

  // --- Pull base difficulty config ---
  const cfg = difficultyConfig[difficulty];
  if (!cfg) {
    throw new HttpsError("failed-precondition", "Invalid difficulty.");
  }

  const requiredMoves =
    typeof cg.requiredMoves === "number"
      ? cg.requiredMoves
      : cfg.numberOfMoves;

  // Prefer live numbers from the client if sent
  const requestData = (request.data ?? {}) as any;
  const currentMove =
    typeof requestData.currentMove === "number"
      ? requestData.currentMove
      : typeof cg.currentMove === "number"
      ? cg.currentMove
      : requiredMoves;

  const incorrects =
    typeof requestData.incorrects === "number"
      ? requestData.incorrects
      : cg.incorrects ?? 0;

  const timeSeconds =
    typeof requestData.timeSeconds === "number"
      ? requestData.timeSeconds
      : cg.time ?? 0;

  const riskMode =
    typeof requestData.riskMode === "boolean"
      ? requestData.riskMode
      : !!cg.hasRisked;

  const walkedAway =
    typeof requestData.walkedAway === "boolean"
      ? requestData.walkedAway
      : !!cg.walkedAway;

  const lost =
    typeof requestData.lost === "boolean"
      ? requestData.lost
      : !!cg.lost;

  const extraMoves = Math.max(0, currentMove - requiredMoves);

  // --- IQ reward using your calculator ---
  const rawIq = computeIqReward({
    difficulty,
    incorrects,
    timeSeconds,
    requiredMoves,
    ExtraMovesDone: extraMoves,
    skipsUsed: cg.skipsUsed ?? 0,
    replaysUsed: cg.replaysUsed ?? 0,
    intysUsed: cg.intysUsed ?? 0,
  });

  // 🔹 Treat rawIq as the *final IQ rating* for this run.
  const previousIq = typeof data.iq === "number" ? data.iq : 0;
  const finalIq = typeof rawIq === "number" ? rawIq : 0;

  // We never want to LOWER a player’s IQ.
  let iqToWrite: number | undefined;
  let iqGain = 0;

  if (finalIq > previousIq) {
    iqToWrite = finalIq;             // replace IQ
    iqGain = finalIq - previousIq;   // how much they improved vs old record
  } else {
    // IQ is worse or equal → keep stored IQ as-is, no gain.
    iqToWrite = undefined;           // skip updating iq field
    iqGain = 0;
  }

  // --- COINS with risk rules ---

    const baseCoins = cfg.coinsReward ?? 0;

      // Prefer an explicit flag from the client if provided
      const hasCompletedBaseFromClient =
        typeof requestData.hasCompletedBase === "boolean"
          ? requestData.hasCompletedBase
          : undefined;

      const hasCompletedBase =
        hasCompletedBaseFromClient ?? (currentMove >= requiredMoves);

      let coinsReward = 0;
      let theoreticalMultiplier = 0;
      let effectiveMultiplier = 0;

      // 1) Lost before completing the base sequence → 0 coins
      if (!hasCompletedBase && lost) {
        coinsReward = 0;
        theoreticalMultiplier = 0;
        effectiveMultiplier = 0;

      } else if (!hasCompletedBase && !lost) {
        // Edge case: somehow finished game without a "lost" flag but base not done.
        coinsReward = 0;
        theoreticalMultiplier = 0;
        effectiveMultiplier = 0;

      } else if (!riskMode) {
        // 2) Completed base and chose NOT to risk ("Finish & collect")
        coinsReward = baseCoins;
        theoreticalMultiplier = 1;
        effectiveMultiplier = 1;

    } else {
      // 3) Risk mode: player chose to continue at least once

      if (extraMoves < 5) {
        // 3a) Continued, but never finished the first extra block
        //     → 0.5 × baseCoins
        theoreticalMultiplier = 1; // conceptually still at base level
        effectiveMultiplier = 0.5;
        coinsReward = Math.round(baseCoins * 0.5);
      } else {
        // 3b) Completed at least one full extra block (5 moves per block)
        const fullBlocks = Math.floor(extraMoves / 5); // 1,2,...
        const stageMultiplier = Math.pow(2, fullBlocks); // 2,4,8,...
        const stageReward = baseCoins * stageMultiplier;
        const intoNextBlock = extraMoves - fullBlocks * 5; // 0..4

        theoreticalMultiplier = stageMultiplier;

        if (!lost && walkedAway && intoNextBlock === 0) {
          // 4) Walked away cleanly right after full blocks
          //    e.g. after completing first 5 extra moves → 2 × base
          effectiveMultiplier = stageMultiplier;
          coinsReward = stageReward;
        } else {
          // 5) Lost OR walked away mid-next block
          //    → half of the last full stage reward
          effectiveMultiplier = stageMultiplier / 2;
          coinsReward = Math.round(stageReward / 2);
        }
      }
    }

  // --- CARDS based on extraMoves ---
  const cardChunks = Math.floor(extraMoves / 10); // 0,1,2,...

  let addInty = 0;
  let addSkip = 0;
  let addReplay = 0;

  if (cardChunks > 0) {
    if (difficulty === "hard" || difficulty === "expert") {
      addInty = cardChunks;
    } else if (difficulty === "master") {
      addInty = cardChunks;
      addSkip = cardChunks;
    } else if (difficulty === "extreme" || difficulty === "impossible") {
      addReplay = cardChunks;
    }
    // easy / medium: no cards
  }

  // --- Build update payload --

    console.log("finishGame IQ debug", {
      uid,
      difficulty,
      rawIq,
      previousIq,
      finalIq,
      iqToWrite,
      iqGain,
    });

    console.log("finishGame coins debug", {
      uid,
      difficulty,
      baseCoins,
      requiredMoves,
      currentMove,
      extraMoves,
      hasCompletedBase,
      riskMode,
      walkedAway,
      lost,
      coinsReward,
    });



    const currentCoins =
      typeof data.coins === "number" ? data.coins : 0;
    const currentInty =
      typeof data.intyCards === "number" ? data.intyCards : 0;
    const currentSkip =
      typeof data.skipCards === "number" ? data.skipCards : 0;
    const currentReplay =
      typeof data.replayCards === "number" ? data.replayCards : 0;

    const update: any = {
      // IQ handled below
      coins: currentCoins + coinsReward,
      intyCards: currentInty + addInty,
      skipCards: currentSkip + addSkip,
      replayCards: currentReplay + addReplay,

      lastGameIqGain: iqGain,
      lastGameFinalIq: finalIq,
      lastGameCoinsGain: coinsReward,
      lastGameExtraMoves: extraMoves,
      lastGameIntyCardsGain: addInty,
      lastGameSkipCardsGain: addSkip,
      lastGameReplayCardsGain: addReplay,

      lastGameRiskMode: riskMode,
      lastGameWalkedAway: walkedAway,
      lastGameLost: lost,
      lastGameTheoreticalMultiplier: theoreticalMultiplier,
      lastGameEffectiveMultiplier: effectiveMultiplier,

      currentGame: null,
    };

    if (iqToWrite !== undefined) {
      update.iq = iqToWrite;
    }

    await userRef.set(update, { merge: true });

  return {
    ok: true,
    // 🔹 Send "IQ gained" to the client (not the absolute rating)
    iqReward: iqGain,
    finalIq,
    coinsReward,
    extraMoves,
    theoreticalMultiplier,
    effectiveMultiplier,
    intyCardsReward: addInty,
    skipCardsReward: addSkip,
    replayCardsReward: addReplay,
  };
});
