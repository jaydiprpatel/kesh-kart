import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

// Haversine formula to calculate distance between two lat/lng coordinates in meters
function getDistanceFromLatLonInM(lat1: number, lon1: number, lat2: number, lon2: number) {
  const R = 6371e3; // Radius of the earth in m
  const dLat = deg2rad(lat2 - lat1);
  const dLon = deg2rad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const d = R * c; // Distance in m
  return d;
}

function deg2rad(deg: number) {
  return deg * (Math.PI / 180);
}

export const checkInUser = functions.https.onCall(async (data, context) => {
  // Validation 1: Authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be logged in to check-in."
    );
  }

  const { shopId, appointmentId, lat, lng } = data;

  if (!shopId || !appointmentId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing shopId or appointmentId."
    );
  }

  const uid = context.auth.uid;
  const appointmentRef = db.collection("appointments").doc(appointmentId);
  const shopRef = db.collection("shops").doc(shopId);

  // Run in a transaction to ensure atomicity
  return await db.runTransaction(async (transaction) => {
    const appointmentSnap = await transaction.get(appointmentRef);
    const shopSnap = await transaction.get(shopRef);

    if (!appointmentSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Appointment not found.");
    }
    if (!shopSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Shop not found.");
    }

    const appointment = appointmentSnap.data()!;
    const shop = shopSnap.data()!;

    // Validation 2: Re-check / Ownership / State Validation
    if (appointment.customerId !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Not your appointment.");
    }

    if (appointment.shopId !== shopId) {
      throw new functions.https.HttpsError("invalid-argument", "Appointment does not belong to this shop.");
    }

    // Idempotency: if already arrived, return success gracefully
    if (appointment.status === "arrived" || appointment.status === "in_progress") {
      // Return a pseudo-success so the client can just jump to the live queue card
      return {
        success: true,
        alreadyCheckedIn: true,
        position: appointment.priority, // We will just return priority as placeholder, client relies on stream anyway
        estimatedWaitTime: 0,
        locationUnverified: appointment.location_unverified || false
      };
    }

    if (appointment.status !== "booked") {
      throw new functions.https.HttpsError("failed-precondition", "Invalid appointment state.");
    }

    // Validation 3: Session Validation
    const now = admin.firestore.Timestamp.now();
    const sessionsQuery = await transaction.get(
      db.collection("shop_sessions")
        .where("shopId", "==", shopId)
        .where("expiresAt", ">", now)
        .limit(1)
    );

    if (sessionsQuery.empty) {
      throw new functions.https.HttpsError("permission-denied", "Shop session expired. Please ask barber to refresh QR.");
    }

    // Validation 4: Time Validation
    // Assume slotStart and slotEnd are Firestore Timestamps
    const slotStart = appointment.slotStart.toDate().getTime();
    const slotEnd = appointment.slotEnd.toDate().getTime();
    const currentTime = now.toDate().getTime();

    const tenMinutes = 10 * 60 * 1000;

    if (currentTime < slotStart - tenMinutes) {
      throw new functions.https.HttpsError("failed-precondition", "Too early to check-in.");
    }

    if (currentTime > slotEnd + tenMinutes) {
      throw new functions.https.HttpsError("failed-precondition", "Too late. Slot has expired.");
    }

    // Validation 5: GPS Validation
    let locationUnverified = false;
    if (lat === null || lng === null) {
      // GPS Failed
      locationUnverified = true;
    } else {
      const shopLat = shop.lat;
      const shopLng = shop.lng;
      
      if (shopLat !== undefined && shopLng !== undefined) {
        const distance = getDistanceFromLatLonInM(lat, lng, shopLat, shopLng);
        if (distance > 100) {
          throw new functions.https.HttpsError("failed-precondition", "You are too far from the shop to check-in.");
        }
      } else {
        // Shop missing coordinates
        locationUnverified = true; 
      }
    }

    const isLate = currentTime > slotStart;

    // Mutation
    transaction.update(appointmentRef, {
      status: "arrived",
      arrivedAt: now,
      location_unverified: locationUnverified,
      priority: 2,
      late: isLate,
    });

    // Calculate Queue Info
    // Firestore transaction doesn't allow querying across the collection with complex filters easily
    // So we will fetch them directly. Note: strictly speaking, reads in transactions must happen before writes,
    // so we fetch the queue list now.
    
    // We only care about appointments for this shop, happening today.
    // For simplicity, we can fetch all in_progress and arrived appointments for this shop.
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);

    const queueQuery = await transaction.get(
      db.collection("appointments")
        .where("shopId", "==", shopId)
        .where("status", "in", ["arrived", "in_progress"])
        .where("slotStart", ">=", admin.firestore.Timestamp.fromDate(startOfDay))
    );

    let arrivedBeforeCount = 0;
    let inProgressCount = 0;

    queueQuery.docs.forEach((doc) => {
      const data = doc.data();
      if (data.status === "in_progress") {
        inProgressCount++;
      } else if (data.status === "arrived") {
        // Only count if they arrived before this user
        if (data.arrivedAt.toDate().getTime() <= now.toDate().getTime()) {
          arrivedBeforeCount++;
        }
      }
    });

    const position = arrivedBeforeCount + inProgressCount + 1; // +1 for the current user
    const avgServiceTime = shop.avgServiceTime || 15; // default 15 mins
    const estimatedWaitTime = (position - 1) * avgServiceTime; // minutes

    // Send FCM to barber asynchronously (after transaction)
    // We'll schedule this without awaiting to not block the response
    sendNotificationToBarber(appointment.barberId, appointment.customerName || "A customer", appointment.slotStart.toDate());

    return {
      success: true,
      position: position,
      estimatedWaitTime: estimatedWaitTime,
      locationUnverified: locationUnverified
    };
  });
});

async function sendNotificationToBarber(barberId: string, customerName: string, slotStart: Date) {
  try {
    const barberDoc = await db.collection("users").doc(barberId).get();
    const fcmToken = barberDoc.data()?.fcmToken;
    if (fcmToken) {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "Customer Arrived",
          body: `Customer ${customerName} has arrived for their slot at ${slotStart.toLocaleTimeString()}.`
        }
      });
    }
  } catch (error) {
    console.error("Error sending notification to barber:", error);
  }
}

// Scheduled Function for No-Shows
// Runs every 15 minutes
export const handleNoShows = functions.pubsub.schedule("every 15 minutes").onRun(async (context) => {
  const now = new Date();
  const tenMinutesAgo = new Date(now.getTime() - 10 * 60 * 1000);

  const snapshot = await db.collection("appointments")
    .where("status", "==", "booked")
    .where("slotEnd", "<", admin.firestore.Timestamp.fromDate(tenMinutesAgo))
    .get();

  if (snapshot.empty) {
    console.log("No no-shows to process.");
    return null;
  }

  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.update(doc.ref, { status: "no_show" });
  });

  await batch.commit();
  console.log(`Marked ${snapshot.docs.length} appointments as no_show.`);
  return null;
});
