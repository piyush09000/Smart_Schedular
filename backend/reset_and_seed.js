const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Helper to delete all documents in a collection
async function deleteCollection(collectionPath, batchSize = 50) {
  const collectionRef = db.collection(collectionPath);
  const query = collectionRef.orderBy('__name__').limit(batchSize);

  return new Promise((resolve, reject) => {
    deleteQueryBatch(db, query, resolve).catch(reject);
  });
}

async function deleteQueryBatch(db, query, resolve) {
  const snapshot = await query.get();

  const batchSize = snapshot.size;
  if (batchSize === 0) {
    // When there are no documents left, we are done
    resolve();
    return;
  }

  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });
  await batch.commit();

  // Recurse on the next process tick, to avoid
  // exploding the stack.
  process.nextTick(() => {
    deleteQueryBatch(db, query, resolve);
  });
}

const initialData = {
  schools: [
    { id: "engineering", name: "School of Engineering" },
    { id: "science", name: "School of Science" }
  ],
  departments: [
    {
      id: "CSE",
      name: "Computer Science Engineering",
      school: "engineering",
      structure: {
        "SY": ["A", "B", "C"],
        "TY": ["A", "B"]
      }
    },
    {
      id: "ECE",
      name: "Electronics & Communication",
      school: "engineering",
      structure: {
        "SY": ["A"],
        "TY": ["A"]
      }
    }
  ],
  users: [
    {
      id: "admin",
      name: "Super Admin",
      role: "admin",
      password: "admin",
      school: "engineering",
      department: "CSE"
    }
  ],
  rooms: [
    "101", "102", "103", "303", "IoT Lab", "PrL"
  ]
};

async function resetAndSeed() {
  try {
    console.log("⚠️ WARNING: Deleting all existing collections...");
    const collectionsToWipe = ["users", "schools", "departments", "rooms", "room_status", "timetable", "years", "divisions"];
    
    for (const coll of collectionsToWipe) {
      console.log(`- Deleting collection: ${coll}`);
      await deleteCollection(coll);
    }
    console.log("✅ All collections wiped successfully!");

    console.log("🌱 Seeding fresh database structure...");

    // Seed Schools
    console.log("- Seeding Schools...");
    for (const school of initialData.schools) {
      await db.collection("schools").doc(school.id).set({ name: school.name });
    }

    // Seed Departments
    console.log("- Seeding Departments...");
    for (const dept of initialData.departments) {
      await db.collection("departments").doc(dept.id).set({
        name: dept.name,
        school: dept.school,
        structure: dept.structure
      });
    }

    // Seed Users
    console.log("- Seeding Admin User...");
    for (const user of initialData.users) {
      await db.collection("users").doc(user.id).set({
        name: user.name,
        role: user.role,
        password: user.password,
        school: user.school,
        department: user.department
      });
    }

    // Seed Rooms
    console.log("- Seeding Rooms & Room Statuses...");
    for (const room of initialData.rooms) {
      // Base metadata
      await db.collection("rooms").doc(room).set({
        name: room
      });
      // Real-time status
      await db.collection("room_status").doc(room).set({
        status: "Available",
        currentFacultyName: "",
        currentFacultyCode: "",
        currentSubject: "",
        currentDivision: "",
        currentTimeSlot: "",
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    console.log("✅ Database reset and seed completed successfully!");
    process.exit(0);

  } catch (error) {
    console.error("❌ Error resetting database:", error);
    process.exit(1);
  }
}

resetAndSeed();
