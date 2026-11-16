## AI Quest Coach and Testing

The project includes an AI Quest Coach backend implemented using Genkit and Google Gemini.

The `askQuestCoach` Firebase callable function requires authentication. It uses a read-only tool named `readMyQuestState` to retrieve the current user's challenge and progress. The tool obtains the user's UID from verified Firebase Authentication and does not contain reward-writing operations.

### Verified Tests

- Flutter signup, signin, and signout worked during initial testing.
- The Flutter app successfully displayed a challenge from Firestore.
- Firebase Functions passed ESLint and JavaScript syntax checks.
- Genkit successfully generated a response using Gemini.
- An unauthenticated AI Coach request returned HTTP 401.
- Firebase Authentication Emulator successfully created and authenticated a test user.
- An unauthenticated Firestore document request returned HTTP 403.

### Known Limitations

- Android authentication later encountered network errors.
- The authenticated AI Coach request timed out after 60 seconds.
- The AI Coach interface has not been integrated into Flutter.
- Reward completion and duplicate-reward protection have not been verified.
- The 999-point prompt-injection test remains incomplete.
- Full Firestore security denial testing remains incomplete.

The Gemini API key is stored in a local `.secret.local` file excluded from version control. The AI Coach is configured for local emulator testing, not production deployment.