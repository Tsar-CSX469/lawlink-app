import * as functions from "firebase-functions";
import { generateWelcomeMessage } from "../../../services/messageService";

export const helloLawLink = functions.https.onRequest((req, res) => {
  const name = JSON.parse(req.body).name || "Anonymous";
  const message = generateWelcomeMessage(name);
  
  res.json({
    message: message,
  });
});