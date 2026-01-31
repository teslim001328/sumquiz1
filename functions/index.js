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
// Flutterwave Payment Integration
// ============================================================================

/**
 * Creates a Flutterwave payment link
 * Returns checkout URL to frontend
 */
exports.createPayment = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User not authenticated');
  }

  const { amount, currency, email, name, productId } = data;
  if (!amount || !currency || !productId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing payment details');
  }

  const tx_ref = `sumquiz_${uid}_${Date.now()}`;
  const secretKey = functions.config().payment?.flutterwave_secret_key;

  if (!secretKey) {
    console.error('FLUTTERWAVE_SECRET_KEY not configured');
    throw new functions.https.HttpsError('internal', 'Payment system not configured');
  }

  try {
    const response = await fetch('https://api.flutterwave.com/v3/payments', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${secretKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        tx_ref: tx_ref,
        amount: amount,
        currency: currency,
        redirect_url: 'https://sumquiz.web.app/payment-callback',
        customer: {
          email: email || 'customer@sumquiz.app',
          name: name || 'Valued Customer',
        },
        meta: {
          uid: uid,
          product_id: productId,
        },
        customizations: {
          title: 'SumQuiz Pro',
          description: 'Unlock Premium Features',
          logo: 'https://sumquiz.web.app/assets/icon.png',
        },
      }),
    });

    const result = await response.json();

    if (result.status === 'success') {
      // Log the pending payment
      await db.collection('payments').doc(tx_ref).set({
        uid: uid,
        amount: amount,
        currency: currency,
        productId: productId,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { checkoutUrl: result.data.link };
    } else {
      console.error('Flutterwave API error:', result);
      throw new functions.https.HttpsError('internal', 'Failed to create payment link');
    }
  } catch (error) {
    console.error('Error creating payment:', error);
    throw new functions.https.HttpsError('internal', 'Error creating payment');
  }
});

/**
 * Flutterwave Webhook Listener
 * Verifies signature and updates user status
 */
exports.flutterwaveWebhook = functions.https.onRequest(async (req, res) => {
  // 1. Verify Signature
  const secretHash = functions.config().payment?.flutterwave_secret_hash;
  const signature = req.headers['verif-hash'];

  if (!secretHash || signature !== secretHash) {
    console.warn('Unauthorized webhook signature');
    return res.status(401).send('Unauthorized');
  }

  const event = req.body;
  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  // 2. Accept only charge.completed with status=successful
  if (event.event !== 'charge.completed' || event.data.status !== 'successful') {
    console.log(`Ignoring webhook event: ${event.event} - ${event.data.status}`);
    return res.status(200).send('Event ignored');
  }

  const { tx_ref, amount, currency, id: transactionId } = event.data;
  const uid = event.data.meta?.uid;
  const productId = event.data.meta?.product_id;

  if (!tx_ref || !uid) {
    console.error('Webhook missing critical data:', { tx_ref, uid });
    return res.status(400).send('Missing data');
  }

  try {
    // 3. Idempotency Check: if payments/{tx_ref} exists and status is successful → do nothing
    const paymentRef = db.collection('payments').doc(tx_ref);
    const paymentDoc = await paymentRef.get();

    if (paymentDoc.exists && paymentDoc.data().status === 'successful') {
      console.log(`Payment ${tx_ref} already processed`);
      return res.status(200).send('Already processed');
    }

    // 4. Update Firestore
    const batch = db.batch();

    // Update payment record
    batch.set(paymentRef, {
      status: 'successful',
      transactionId: transactionId,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      amount: amount,
      currency: currency,
      productId: productId,
      raw_data: event.data,
    }, { merge: true });

    // Update user record
    const userRef = db.collection('users').doc(uid);
    batch.update(userRef, {
      isPro: true,
      isPremium: true, // Supporting both legacy and new field
      subscriptionExpiry: null, // As specified: one-time payment for premium unlock
      lastVerified: admin.firestore.FieldValue.serverTimestamp(),
      currentProduct: productId,
    });

    await batch.commit();

    console.log(`Premium unlocked for user ${uid} via transaction ${tx_ref}`);
    return res.status(200).send('OK');
  } catch (error) {
    console.error('Error processing webhook:', error);
    return res.status(500).send('Internal Error');
  }
});

