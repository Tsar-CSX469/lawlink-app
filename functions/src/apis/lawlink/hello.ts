import * as functions from "firebase-functions";
import { generateWelcomeMessage } from "../../../services/messageService";

export const helloLawLink = functions.https.onRequest((req, res) => {
  const name = req.body.name || "Anonymous";
  console.log('test' + req.body["name"]);
  const message = generateWelcomeMessage(name);
  
  res.json({
    message: message,
  });
});