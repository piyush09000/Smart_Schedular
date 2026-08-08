const admin = require("firebase-admin");
const cron = require("node-cron");

// 🔥 Load Firebase Service Key
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

console.log("🚀 Server started...");

// ⏰ Run every 5 minutes
cron.schedule("*/5 * * * *", async () => {
  console.log("⏰ Checking lectures...");

  const now = new Date();

  // 📅 Get current day (Monday, Tuesday...)
  const currentDay = now.toLocaleString("en-US", { weekday: "long" });

  try {
    const snapshot = await db.collection("timetable").get();

    for (const doc of snapshot.docs) {
      const data = doc.data();

      // ✅ Match day
      if (data.day !== currentDay) continue;

      try {
        // ⏰ Convert "10:30" → Date
        const [hour, minute] = data.startTime.split(":").map(Number);

        const lectureTime = new Date();
        lectureTime.setHours(hour, minute, 0);

        // ⏱ Calculate difference
        const diffMinutes = Math.floor(
          (lectureTime - now) / (1000 * 60)
        );

        // 🎯 Trigger 15 min before
        // 🔥 For testing use: diffMinutes <= 15 && diffMinutes >= 14
        if (diffMinutes <= 15 && diffMinutes >= 14) {

          console.log(`📢 Sending notification for ${data.subject}`);

          // 👨‍🏫 Get faculty user
          const userDoc = await db
            .collection("users")
            .doc(data.facultyCode)
            .get();

          if (!userDoc.exists) {
            console.log("❌ Faculty not found:", data.facultyCode);
            continue;
          }

          const token = userDoc.data().fcmToken;

          if (!token) {
            console.log("❌ No FCM token for:", data.facultyCode);
            continue;
          }

          // 🚀 Send notification
          await admin.messaging().send({
            token: token,
            notification: {
              title: "Lecture in 15 minutes",
              body: `${data.subject} in Room ${data.room} (${data.department}-${data.year}-${data.division})`,
            },
          });

          console.log("✅ Notification sent");
        }

      } catch (err) {
        console.log("❌ Time error:", err);
      }
    }

  } catch (error) {
    console.log("❌ Firestore error:", error);
  }
});