# Security Notes

## Firebase Web API Keys (`AIza...`)

Firebase Web API keys are **not secrets**. They identify the Firebase project and are expected to be present in client-side code for web/mobile apps.

Security does **not** depend on hiding these keys. Security depends on:

- Firebase Authentication correctly configured.
- Firestore/Storage Security Rules enforcing least privilege.
- Backend/API authorization checks where applicable.
- Proper quota and monitoring controls.

## Commercial Checklist (recommended)

- Restrict each Firebase API key in Google Cloud Console:
  - Application restrictions: HTTP referrers (your domains).
  - API restrictions: allow only required APIs.
- Review and harden Firestore/Storage Rules before production.
- Enable App Check where possible.
- Monitor usage, errors, and quota anomalies.
- Rotate keys if abuse is suspected.
