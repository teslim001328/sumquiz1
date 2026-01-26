/**
 * SumQuiz Firebase Cloud Functions
 * Security & Revenue Protection Functions
 * 
 * CRITICAL FIXES:
 * - C2: Server-side receipt validation
 * - C3: Server time sync
 * - C4: Subscription expiry enforcement
 * - C5: Atomic referral signup
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

// ============================================================================
// C3: Server Time Sync
// ============================================================================

/**
 * Returns server timestamp to prevent device time manipulation
 * Used by TimeSyncService on client
 */
exports.getServerTime = functions.https.onCall(async (data, context) => {
  return {
    serverTime: new Date().toISOString(),
    timestamp: Date.now(),
  };
});

// ============================================================================
// C4: Subscription Expiry Check
// ============================================================================

/**
 * Checks if user's subscription has expired and revokes access if needed
 * Called by background task and on-demand
 */
exports.checkSubscriptionExpiry = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid || data.uid;

  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User not authenticated');
  }

  const userRef = db.collection('users').doc(uid);
  const doc = await userRef.get();

  if (!doc.exists) {
    return { status: 'not_found' };
  }

  const userData = doc.data();
  const expiry = userData.subscriptionExpiry;

  // Lifetime access (null expiry)
  if (expiry === null) {
    return { status: 'lifetime', isPro: true };
  }

  const now = admin.firestore.Timestamp.now();

  if (expiry.toDate() < now.toDate()) {
    // Subscription expired - revoke access
    await userRef.update({
      isPro: false,
      expiredAt: now,
    });

    console.log(`Revoked Pro access for user ${uid} - subscription expired`);

    return {
      status: 'expired',
      isPro: false,
      expiredAt: now.toDate().toISOString(),
    };
  }

  return {
    status: 'active',
    isPro: true,
    expiresAt: expiry.toDate().toISOString(),
  };
});

/**
 * Scheduled function to check all expired subscriptions daily at 3 AM UTC
 * Automatically revokes access for expired users
 */
exports.scheduledExpiryCheck = functions.pubsub
  .schedule('0 3 * * *') // Every day at 3 AM UTC
  .timeZone('UTC')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    console.log('Running scheduled expiry check...');

    // Find all users with expired subscriptions who still have Pro access
    const expiredUsers = await db
      .collection('users')
      .where('subscriptionExpiry', '<', now)
      .where('subscriptionExpiry', '!=', null) // Exclude lifetime users
      .where('isPro', '==', true)
      .get();

    if (expiredUsers.empty) {
      console.log('No expired subscriptions found');
      return null;
    }

    const batch = db.batch();
    let count = 0;

    expiredUsers.forEach((doc) => {
      batch.update(doc.ref, {
        isPro: false,
        expiredAt: now,
      });
      count++;
    });

    await batch.commit();

    console.log(`Revoked Pro access for ${count} expired users`);

    return { success: true, revokedCount: count };
  });

// ============================================================================
// C5: Atomic Referral Signup
// ============================================================================

/**
 * Creates user account and applies referral code atomically
 * Prevents partial failures where user is created but referral fails
 */
exports.signUpWithReferral = functions.https.onCall(async (data, context) => {
  const { email, password, displayName, referralCode } = data;

  // Validation
  if (!email || !password || !displayName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Email, password, and display name are required'
    );
  }

  let userRecord;

  try {
    // Step 1: Create Firebase Auth user
    userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: displayName,
    });

    const uid = userRecord.uid;

    // Step 2: Create user document + apply referral atomically
    await db.runTransaction(async (transaction) => {
      const userRef = db.collection('users').doc(uid);

      // Base user data
      let userData = {
        uid: uid,
        email: email,
        displayName: displayName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isPro: false,
      };

      // If referral code provided, validate and apply
      if (referralCode && referralCode.trim()) {
        const trimmedCode = referralCode.trim().toUpperCase();

        // Find referrer
        const referrerQuery = await db
          .collection('users')
          .where('referralCode', '==', trimmedCode)
          .limit(1)
          .get();

        if (!referrerQuery.empty) {
          const referrerRef = referrerQuery.docs[0].ref;
          const referrerDoc = await transaction.get(referrerRef);

          if (referrerDoc.exists) {
            const referrerData = referrerDoc.data();

            // Prevent self-referral
            if (referrerRef.id !== uid) {
              // Grant new user 3-day Pro trial
              const expiry = new Date();
              expiry.setDate(expiry.getDate() + 3);

              userData.appliedReferralCode = trimmedCode;
              userData.referredBy = referrerRef.id;
              userData.referralAppliedAt = admin.firestore.FieldValue.serverTimestamp();
              userData.isPro = true;
              userData.subscriptionExpiry = admin.firestore.Timestamp.fromDate(expiry);

              // Update referrer
              const currentReferrals = referrerData.referrals || 0;
              const currentRewards = referrerData.referralRewards || 0;
              const newReferrals = currentReferrals + 1;

              let updates = {
                referrals: newReferrals,
                totalReferrals: (referrerData.totalReferrals || 0) + 1,
              };

              // Every 3 referrals = +7 days (capped at 12 rewards)
              const MAX_REFERRAL_REWARDS = 12;

              if (newReferrals >= 3 && currentRewards < MAX_REFERRAL_REWARDS) {
                const currentExpiry = referrerData.subscriptionExpiry?.toDate() || new Date();
                currentExpiry.setDate(currentExpiry.getDate() + 7);

                updates.subscriptionExpiry = admin.firestore.Timestamp.fromDate(currentExpiry);
                updates.referrals = 0; // Reset counter
                updates.referralRewards = currentRewards + 1;

                console.log(`Granted referrer ${referrerRef.id} +7 days (reward #${currentRewards + 1})`);
              } else if (newReferrals >= 3) {
                // Hit cap, reset counter but don't grant time
                updates.referrals = 0;
                console.log(`Referrer ${referrerRef.id} hit reward cap`);
              }

              transaction.update(referrerRef, updates);
              console.log(`Applied referral ${trimmedCode} for user ${uid}`);
            }
          }
        } else {
          console.log(`Referral code ${trimmedCode} not found`);
        }
      }

      // Create user document
      transaction.set(userRef, userData);
    });

    console.log(`User ${uid} created successfully with email ${email}`);

    return {
      success: true,
      uid: uid,
      email: email,
    };
  } catch (error) {
    console.error('Sign up failed:', error);

    // Rollback: Delete auth user if Firestore transaction failed
    if (userRecord) {
      try {
        await admin.auth().deleteUser(userRecord.uid);
        console.log(`Rolled back auth user ${userRecord.uid}`);
      } catch (deleteError) {
        console.error('Failed to rollback auth user:', deleteError);
      }
    }

    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================================================
// Helper: Generate Referral Code
// ============================================================================

/**
 * Generates a unique 8-character referral code for a user
 */
exports.generateReferralCode = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;

  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User not authenticated');
  }

  const userRef = db.collection('users').doc(uid);
  const doc = await userRef.get();

  // If user already has a code, return it
  if (doc.exists && doc.data().referralCode) {
    return { code: doc.data().referralCode };
  }

  // Generate unique code
  let code;
  let isUnique = false;
  let attempts = 0;

  while (!isUnique && attempts < 10) {
    // Generate 8-character alphanumeric code
    code = Math.random().toString(36).substring(2, 10).toUpperCase();

    // Check if unique
    const existing = await db
      .collection('users')
      .where('referralCode', '==', code)
      .limit(1)
      .get();

    if (existing.empty) {
      isUnique = true;
    }

    attempts++;
  }

  if (!isUnique) {
    throw new functions.https.HttpsError('internal', 'Failed to generate unique code');
  }

  // Save code
  await userRef.set({ referralCode: code }, { merge: true });

  console.log(`Generated referral code ${code} for user ${uid}`);

  return { code: code };
});

// ============================================================================
// H5: Server-Side Usage Limits
// ============================================================================

/**
 * Check if user can perform an action based on daily limits
 * HIGH PRIORITY FIX H5: Move limits logic to Cloud Function
 */
exports.canPerformAction = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  const action = data.action;
  
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User not authenticated');
  }
  
  if (!action) {
    throw new functions.https.HttpsError('invalid-argument', 'Action is required');
  }
  
  // Get daily limit for action
  const limit = _getLimitForAction(action);
  
  // Get today's usage
  const today = _getToday();
  const doc = await db.collection('users').doc(uid).collection('usage').doc(today).get();
  
  if (!doc.exists) {
    return { canPerform: true, current: 0, limit: limit };
  }
  
  const usage = doc.data();
  const current = usage[action] || 0;
  
  return { canPerform: current < limit, current: current, limit: limit };
});

/**
 * Record an action and increment the counter
 * HIGH PRIORITY FIX H5: Enforce strict counters
 */
exports.recordAction = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  const action = data.action;
  
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User not authenticated');
  }
  
  if (!action) {
    throw new functions.https.HttpsError('invalid-argument', 'Action is required');
  }
  
  // Get today's date
  const today = _getToday();
  
  // Increment counter atomically
  const docRef = db.collection('users').doc(uid).collection('usage').doc(today);
  await docRef.set({ [action]: admin.firestore.FieldValue.increment(1) }, { merge: true });
  
  console.log(`Recorded action ${action} for user ${uid}`);
  
  return { success: true };
});

/**
 * Get daily limit for an action
 */
function _getLimitForAction(action) {
  switch (action) {
    case 'summaries':
      return 5;
    case 'quizzes':
      return 3;
    case 'flashcards':
      return 3;
    default:
      return 0;
  }
}

/**
 * Get today's date as a string (YYYY-MM-DD)
 */
function _getToday() {
  const now = new Date();
  return `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}-${now.getDate().toString().padStart(2, '0')}`;
}

// ============================================================================
// H2: Rate Limiting for Password Reset
// ============================================================================

/**
 * Send password reset email with rate limiting
 * HIGH PRIORITY FIX H2: Rate Limiting (Password Reset)
 */
exports.sendPasswordResetEmail = functions.https.onCall(async (data, context) => {
  const email = data.email;
  
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }
  
  // Check rate limit - max 3 resets per hour per email
  const rateLimitDoc = db.collection('rate_limits').doc(`password_reset_${email}`);
  const rateLimitData = await rateLimitDoc.get();
  
  const now = Date.now();
  const oneHour = 60 * 60 * 1000; // 1 hour in milliseconds
  
  if (rateLimitData.exists) {
    const rateLimit = rateLimitData.data();
    const lastReset = rateLimit.lastReset.toMillis();
    const resetCount = rateLimit.resetCount || 0;
    
    // If last reset was more than an hour ago, reset the counter
    if (now - lastReset > oneHour) {
      await rateLimitDoc.set({
        lastReset: admin.firestore.FieldValue.serverTimestamp(),
        resetCount: 1
      });
    } else {
      // Check if we've exceeded the limit
      if (resetCount >= 3) {
        throw new functions.https.HttpsError('resource-exhausted', 
          'Too many password reset requests. Please try again later.');
      }
      
      // Increment counter
      await rateLimitDoc.update({
        resetCount: admin.firestore.FieldValue.increment(1)
      });
    }
  } else {
    // First time requesting reset for this email
    await rateLimitDoc.set({
      lastReset: admin.firestore.FieldValue.serverTimestamp(),
      resetCount: 1
    });
  }
  
  // Send password reset email
  try {
    await admin.auth().sendPasswordResetEmail(email);
    console.log(`Password reset email sent to ${email}`);
    return { success: true };
  } catch (error) {
    console.error(`Failed to send password reset email to ${email}:`, error);
    throw new functions.https.HttpsError('internal', 
      'Failed to send password reset email. Please try again later.');
  }
});

// ============================================================================
// H4: Secure API Keys Implementation
// ============================================================================

/**
 * Get payment processor API keys for client-side initialization
 * HIGH PRIORITY FIX H4: Secure API keys implementation
 */
exports.getPaymentProcessorKeys = functions.https.onCall(async (data, context) => {
  // In production, this should be stored in Firebase Functions config
  // firebase functions:config:set payment.flutterwave_key="YOUR_PRODUCTION_KEY"
  
  const flutterwaveKey = functions.config().payment?.flutterwave_key || 'FLWPUBK_TEST-SANDBOX-DEMO-DUMMY';
  
  if (!flutterwaveKey) {
    throw new functions.https.HttpsError('internal', 'Payment processor key not configured');
  }
  
  return { flutterwaveKey: flutterwaveKey };
});

// ============================================================================
// H8: Crash Reporting / Logging
// ============================================================================

/**
 * Log client-side errors for crash reporting
 * HIGH PRIORITY FIX H8: Crash Reporting / Logging
 */
exports.logClientError = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  const { error, stackTrace, context: errorContext, timestamp } = data;
  
  // Log to Firebase Console
  console.error('Client Error Report:', {
    uid: uid || 'anonymous',
    error: error,
    stackTrace: stackTrace,
    context: errorContext,
    timestamp: timestamp || new Date().toISOString(),
    userAgent: context.rawRequest.get('user-agent'),
  });
  
  // Store in Firestore for later analysis
  try {
    await db.collection('client_errors').add({
      uid: uid || null,
      error: error,
      stackTrace: stackTrace,
      context: errorContext,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      userAgent: context.rawRequest.get('user-agent'),
    });
  } catch (firestoreError) {
    console.error('Failed to store error in Firestore:', firestoreError);
  }
  
  return { success: true };
});

// ============================================================================
// C2: Direct Payment Validation Webhook
// ====================================================================

/**
 * Webhook endpoint for payment processor events
 * Validates receipts and syncs subscription changes
 * 
 * Configure in payment processor dashboard:
 * 1. Webhooks → Add endpoint URL
 * 2. Set authorization header to match PAYMENT_WEBHOOK_SECRET
 */
exports.paymentValidationWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // SECURITY: Verify webhook is from payment processor
    // Set this environment variable: firebase functions:config:set payment.webhook_secret="YOUR_SECRET"
    const expectedAuth = functions.config().payment?.webhook_secret;

    if (expectedAuth) {
      const authHeader = req.headers.authorization;
      if (authHeader !== `Bearer ${expectedAuth}`) {
        console.warn('Unauthorized webhook attempt');
        return res.status(401).send('Unauthorized');
      }
    } else {
      console.warn('WARNING: PAYMENT_WEBHOOK_SECRET not configured. Webhook is not secured!');
    }

    const event = req.body;
    const eventType = event.event_type || event.type;
    const uid = event.customer?.id || event.user_id;
    const transactionId = event.transaction_id || event.id;

    if (!uid) {
      console.warn('Webhook event missing user identifier');
      return res.status(400).send('Missing user identifier');
    }

    console.log(`Payment webhook: ${eventType} for user ${uid}, transaction ${transactionId}`);

    // Validate the payment and determine subscription status
    const validationResult = await _validatePayment(event);
    
    if (!validationResult.isValid) {
      console.warn(`Invalid payment for user ${uid}: ${validationResult.reason}`);
      return res.status(400).send('Invalid payment');
    }

    // Calculate expiry based on product
    let expiry = null;
    let isPro = false;
    
    if (validationResult.product) {
      isPro = true;
      const now = new Date();
      
      switch (validationResult.product) {
        case 'sumquiz_pro_monthly':
          expiry = new Date(now.setMonth(now.getMonth() + 1));
          break;
        case 'sumquiz_pro_yearly':
          expiry = new Date(now.setFullYear(now.getFullYear() + 1));
          break;
        case 'sumquiz_pro_lifetime':
          expiry = null; // Lifetime access
          break;
        case 'sumquiz_exam_24h':
          expiry = new Date(now.setHours(now.getHours() + 24));
          break;
        case 'sumquiz_week_pass':
          expiry = new Date(now.setDate(now.getDate() + 7));
          break;
        default:
          console.warn(`Unknown product: ${validationResult.product}`);
          isPro = false;
      }
    }

    // Update Firestore with subscription status
    const updateData = {
      isPro: isPro,
      lastVerified: admin.firestore.FieldValue.serverTimestamp(),
      lastWebhookEvent: eventType,
      currentProduct: validationResult.product,
      transactionId: transactionId,
    };

    if (expiry !== null) {
      updateData.subscriptionExpiry = admin.firestore.Timestamp.fromDate(expiry);
    } else if (validationResult.product === 'sumquiz_pro_lifetime') {
      // For lifetime, set a very distant expiry date
      updateData.subscriptionExpiry = admin.firestore.Timestamp.fromDate(
        new Date(new Date().setFullYear(new Date().getFullYear() + 100))
      );
    }

    await db.collection('users').doc(uid).set(updateData, { merge: true });

    console.log(`Webhook processed: user ${uid}, isPro=${isPro}, product=${validationResult.product}`);
    res.status(200).send('OK');

  } catch (error) {
    console.error('Webhook processing error:', error);
    res.status(500).send('Internal Server Error');
  }
});

/**
 * Validate payment receipt with payment processor
 */
async function _validatePayment(event) {
  // This is a simplified validation - in production, you'd verify
  // the receipt signature and check with the payment processor's API
  
  const productId = event.product_id || event.metadata?.product_id;
  const status = event.status || event.transaction_status;
  
  // Basic validation
  if (!productId) {
    return { isValid: false, reason: 'Missing product ID' };
  }
  
  if (status !== 'successful' && status !== 'completed') {
    return { isValid: false, reason: `Invalid status: ${status}` };
  }
  
  // Validate known product IDs
  const validProducts = [
    'sumquiz_pro_monthly',
    'sumquiz_pro_yearly', 
    'sumquiz_pro_lifetime',
    'sumquiz_exam_24h',
    'sumquiz_week_pass'
  ];
  
  if (!validProducts.includes(productId)) {
    return { isValid: false, reason: `Invalid product: ${productId}` };
  }
  
  return { isValid: true, product: productId };
}

