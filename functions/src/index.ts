// This file contains the main entry point for Firebase Cloud Functions.
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();

// Create a callable function with v1 API that should work with any firebase-tools version
export const helloLawLink = functions.https.onRequest((req, res) => {
  const name = req.body.name || "Annonymous";
  res.json({
    message: `Hello, ${name}! Welcome to LawLink!`,
  });  
});
