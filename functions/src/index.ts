// File: functions/src/index.ts
// This file contains the main entry point for Firebase Cloud Functions.
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();

// Create a callable function with v1 API that should work with any firebase-tools version
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const helloLawLink = functions.https.onCall((data: any, context) => {
  return {
    message: `Hello ${data.name || "Anonymous"}! Welcome to LawLink.`,
  };
});
