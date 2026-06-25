# Firebase Cloud Functions Deployment

1. Make sure you have the Firebase CLI installed: `npm install -g firebase-tools`
2. Run `firebase init functions` in the root of your project.
3. Select TypeScript.
4. Replace the generated `functions/src/index.ts` with the `index.ts` in this folder.
5. In the `functions` directory, install necessary packages: 
   `npm install firebase-admin firebase-functions`
6. Deploy your functions: `firebase deploy --only functions`
