# Privacy Policy — {{APP_NAME}}

<!--
  FILL-IN DRAFT. Replace every {{PLACEHOLDER}} and resolve every [decision] note.
  This is a starting point, NOT legal advice — have it reviewed before publishing.
  Every "we collect X" line MUST match a declared data type in the Play Data Safety
  form and the iOS privacy manifest. The three artifacts must agree.

  Host the finished policy at a public, stable URL and enter that URL in Play Console
  (App content → Privacy policy) and App Store Connect.
-->

**Last updated:** {{DATE}}
**App:** {{APP_NAME}} ({{PACKAGE_ID}})
**Developer / Data controller:** {{LEGAL_ENTITY}}
**Contact:** {{PRIVACY_EMAIL}}

## 1. Introduction

This Privacy Policy explains what data {{APP_NAME}} ("the app", "we") collects, why we collect it,
how it is used and shared, and the choices and rights you have. By using the app you agree to the
practices described here.

## 2. Data we collect

We collect only the data needed to provide and improve the app. The table below lists each category;
it mirrors our Google Play Data Safety declaration and iOS privacy labels.

| Data category | Examples | Why we collect it | Required or optional |
|---|---|---|---|
| Account info | {{e.g. email, name, user ID}} | Create and manage your account | {{Required / Optional}} |
| App activity | {{usage events, screens viewed}} | Understand usage and improve features | {{Optional, consent-based}} |
| Device & diagnostics | {{device model, OS, crash logs}} | Diagnose crashes and performance | {{Required for stability}} |
| Identifiers | {{device ID, advertising ID}} | {{Analytics / advertising}} | {{Optional}} |
| Location | {{approximate / precise}} | {{Feature that needs it}} | {{Optional}} |
| Photos / files | {{images you upload}} | {{Feature that needs it}} | {{Optional}} |
| Purchase info | {{purchase history}} | Process and restore purchases | {{Required for purchases}} |

<!-- Delete rows that don't apply. Add any category your code collects that no SDK reveals. -->

We do **not** collect: {{list categories you do NOT collect, e.g. contacts, precise location, health}}.

## 3. How we use your data

- Provide core app functionality and your account.
- Diagnose crashes and improve performance and reliability.
- {{Analytics to understand and improve usage — only with your consent where required}}.
- {{Advertising / personalization — describe if applicable, or delete}}.
- Communicate with you about the service (e.g. important notices).

We do not use your data for purposes incompatible with those listed without telling you first.

## 4. Sharing & third-party services

We share data only as described here. The app uses the following third-party services, each governed
by its own privacy policy:

| Service | Purpose | Data shared | Their policy |
|---|---|---|---|
| {{Firebase Analytics}} | Analytics | {{usage, device, app instance ID}} | {{url}} |
| {{Crashlytics / Sentry}} | Crash & diagnostics | {{crash logs, device info}} | {{url}} |
| {{Ad network}} | Advertising | {{advertising ID, usage}} | {{url}} |
| {{Auth provider}} | Sign-in | {{email, name}} | {{url}} |

We do **not** sell your personal data. {{State CCPA/GDPR "sale/share" stance explicitly.}}

## 5. Data retention

We keep personal data only as long as needed for the purposes above or as required by law. {{Specify
retention periods or the deletion triggers, e.g. "account data is deleted within 30 days of account
deletion".}}

## 6. Security

Data is encrypted in transit using TLS/HTTPS. Credentials and tokens are stored in the platform's
secure storage (Android Keystore / iOS Keychain). {{Describe other safeguards.}} No method of
transmission or storage is 100% secure; we work to protect your data but cannot guarantee absolute
security.

## 7. Your rights & choices

- **Access / correction:** request a copy or correction of your data at {{PRIVACY_EMAIL}}.
- **Deletion:** delete your account and associated data in-app via {{path}}, or request deletion at
  {{PRIVACY_EMAIL}} / {{ACCOUNT_DELETION_URL}}.
- **Opt out of analytics/ads:** {{describe the in-app toggle that stops non-essential collection}}.
- **Permissions:** you can revoke camera, location, and other permissions in your device settings.
- **Regional rights:** {{GDPR (EU/UK): legal basis, DPO contact, right to object, complaint to a
  supervisory authority}} · {{CCPA/CPRA (California): right to know/delete/opt-out}}.

## 8. Children's privacy

{{Choose one:}}
- The app is **not directed to children under {{13/16}}** and we do not knowingly collect their data.
  If we learn we have, we delete it. Contact {{PRIVACY_EMAIL}}.
- The app **is** intended for children and complies with {{COPPA / Play Families policy}}: {{describe}}.

## 9. International transfers

{{If data is processed outside the user's country, state where and the safeguard used (e.g. SCCs).}}

## 10. Changes to this policy

We may update this policy; we will post the new version here and update the "Last updated" date.
Material changes will be notified {{in-app / by email}}.

## 11. Contact

Questions or requests: **{{PRIVACY_EMAIL}}** · {{LEGAL_ENTITY}}, {{MAILING_ADDRESS}}.

---

> Consistency check before publishing: every collected category above appears in the Play Data Safety
> form and the iOS privacy manifest, every named third-party SDK is in your `pubspec.yaml`, and the
> deletion path actually exists in the app.
