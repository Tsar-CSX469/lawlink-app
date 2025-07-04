# LawLink Functions

## 📁 Structure
```
functions/
├── src/
│   ├── functions/           # All Firebase Functions
│   ├── services/            # Business logic & utilities  
│   ├── express.ts           # Express app setup
│   └── index.ts             # Export functions
├── utils/
│   └── globalUtil.ts        # Global utilities
└── package.json
```

## 🚀 Add New Function
1. Create `src/functions/yourFunction.ts`
2. Export it in `src/index.ts`
3. Build & deploy

## 📝 Function Template
```typescript
import * as functions from "firebase-functions";
import { Request, Response } from 'express';
import { createExpressApp } from "../express";
import { asyncHandler, sendSuccess } from "../../utils/globalUtil";

const app = createExpressApp();

app.post('/your-endpoint', asyncHandler(async (req, res) => {
  // Your logic here
  sendSuccess(res, { message: "success" });
}));

export const yourFunction = functions.https.onRequest(app);
```

## 🔧 Commands
```bash
npm run build          # Build TypeScript
firebase emulators:start --only functions  # Test locally  
firebase deploy --only functions           # Deploy
```

## 📱 Test URLs
- **Local**: `http://localhost:5001/project-id/us-central1/functionName/endpoint`
- **Production**: `https://us-central1-project-id.cloudfunctions.net/functionName/endpoint`

## 📋 Response Format
```json
{
  "success": true,
  "data": { ... }
}
```
