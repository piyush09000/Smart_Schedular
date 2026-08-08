const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function initializeHierarchicalMetadata() {
  console.log("🔍 Scanning existing timetable to build hierarchy...");

  try {
    const timetableSnapshot = await db.collection("timetable").get();
    
    if (timetableSnapshot.empty) {
      console.log("No timetable entries found. Make sure you have uploaded a timetable.");
      process.exit(0);
    }

    // Maps: departmentName -> { yearName -> Set(divisions) }
    const deptHierarchy = {};

    timetableSnapshot.forEach((doc) => {
      const data = doc.data();
      const dept = data.department ? data.department.trim() : "";
      const year = data.year ? data.year.trim() : "";
      const div = data.division ? data.division.trim() : "";

      if (dept && year && div) {
        if (!deptHierarchy[dept]) {
          deptHierarchy[dept] = {};
        }
        if (!deptHierarchy[dept][year]) {
          deptHierarchy[dept][year] = new Set();
        }
        deptHierarchy[dept][year].add(div);
      }
    });

    console.log("🏠 Creating/Updating department structures...");
    
    let updatedCount = 0;
    
    for (const [dept, yearsObj] of Object.entries(deptHierarchy)) {
      // Convert Sets to Arrays for Firestore
      const structure = {};
      for (const [year, divSet] of Object.entries(yearsObj)) {
        structure[year] = Array.from(divSet).sort();
      }

      console.log(`- Department [${dept}] Structure:`, structure);

      // Save structure into the department document
      await db.collection("departments").doc(dept).set({
        structure: structure
      }, { merge: true });
      
      updatedCount++;
    }

    console.log(`✅ Successfully updated ${updatedCount} departments with hierarchical structure!`);
    
    // We can also clean up the old standalone 'years' and 'divisions' collections if desired, 
    // but leaving them is harmless.

    process.exit(0);

  } catch (error) {
    console.error("❌ Error initializing hierarchy:", error);
    process.exit(1);
  }
}

// Run the script
initializeHierarchicalMetadata();
