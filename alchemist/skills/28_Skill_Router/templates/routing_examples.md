# Routing Examples

Concrete request-to-plan examples from `scripts/route.py`. Re-run the script to reproduce.

## Example 1: Add a login form

```
Request: "add a login form"
Mode: ad-hoc  |  confidence: high  |  loaded 5 of 74 skills
Preconditions (assumed present -- verify before loading deps):
  [A] 02_Product_Planning
  [A] 03_UI_UX_Planning
  [A] 04_Premium_Design_System
  [B] 06_Flutter_Architecture
Ordered plan (upstream contracts first):
   1. [dependency] 07_Navigation  (phase B)
   2. [dependency] 08_Riverpod  (phase B)
   3. [dependency] 15_Error_Handling  (phase C)
   4. [dependency] 16_Loading_States  (phase C)
   5. [match     ] 55_Form_Engine  (phase X) <- form, login form
```

**Why this set:** Form Engine (#55) owns the input/validation/DTO pipeline. Its dependsOn closure pulls Navigation (07, to route to/from the login screen), Riverpod (08, for form state and submission), Error Handling (15, for validation failures), and Loading States (16, for submit-in-progress UI). Phase-A design + scaffold are preconditions the existing app must already satisfy.

## Example 2: Why is my build red

```
Request: "why is my build red"
Mode: ad-hoc  |  confidence: medium  |  loaded 1 of 74 skills
Ordered plan (upstream contracts first):
   1. [match     ] 37_Build_Doctor  (phase X) <- build red
```

**Why this set:** Build Doctor (#37) is purpose-built for triaging red Gradle/AGP/Kotlin/JDK version failures. It has zero pipeline dependencies — it reads logs and references known-version conflicts. One skill, straight to the answer.

## Example 3: "Build me a Flutter app" (defer to orchestrator)

```
Request: "build me a flutter app for tracking habits"
Mode: ORCHESTRATOR (full pipeline)
  -> 01_Master_Orchestrator
  Request spans multiple phases / a full build -- defer to the orchestrator (#01)
  to run the 24-stage pipeline rather than loading skills ad-hoc.
  Strong matches: 01_Master_Orchestrator
```

**Why defer:** The request matches the orchestrator's own trigger phrases. The router detects this and recommends the full-pipeline orchestrator instead of picking an incomplete ad-hoc skill set.

## Example 4: Make the app responsive on tablets

```
Request: "make the app responsive on tablets"
Mode: ad-hoc  |  confidence: medium  |  loaded 3 of 74 skills
Preconditions:
  [A] 04_Premium_Design_System
  [B] 06_Flutter_Architecture
Ordered plan:
   1. [dependency] 07_Navigation  (phase B)
   2. [match     ] 17_Responsive_UI  (phase C) <- responsive, tablet
```

**Why 07 as a dependency:** Responsive UI (#17) owns adaptive layouts, but it hosts the nav shell and expects go_router routes to already exist (#07). The router pulls it in as a dependency despite #17 being the match.

## Example 5: "Add retries when the network is flaky"

```
Request: "add retries when the network is flaky"
Mode: ad-hoc  |  confidence: low  |  loaded 6 of 74 skills
Ordered plan:
   1. [dependency] 11_Backend_Integration  (phase C)
   2. [match     ] 14_Network_Resilience  (phase C) <- retries
   3. [dependency] 15_Error_Handling  (phase C)
   4. [dependency] 16_Loading_States  (phase C)
```

**Why low confidence:** Only "retries" matched; "flaky" and "network" alone did not hit the exact trigger phrases. The plan is still correct (the resilience layer needs the dio client, Result types, and loading states), but the user could improve precision by phrasing as "handle offline" or "add circuit breaker".

## Example 6: Add push notifications

```
Request: "add push notifications"
Mode: ad-hoc  |  confidence: high  |  loaded 4 of 74 skills
Ordered plan:
   1. [dependency] 07_Navigation  (phase B)
   2. [dependency] 13_Security  (phase C)
   3. [match     ] 52_Push_Notifications  (phase X) <- push notification, push, notifications
```

**Why security and navigation:** Push (#52) needs secure token storage (#13, for the FCM token) and go_router (#07, for deep-link notification taps into specific screens).

## Example 7: Review the UI design

```
Request: "critique this screen, why does it look off"
Mode: ad-hoc  |  confidence: medium  |  loaded 2 of 74 skills
Preconditions:
  [A] 04_Premium_Design_System
Ordered plan:
   1. [match     ] 43_Design_Critic  (phase X) <- critique this screen, why does it look off
```

## Example 8: I need tests for my login notifier

```
Request: "generate tests for my login notifier"
Mode: ad-hoc  |  confidence: medium  |  loaded 4 of 74 skills
Ordered plan:
   1. [dependency] 08_Riverpod  (phase B)
   2. [dependency] 15_Error_Handling  (phase C)
   3. [dependency] 20_Testing  (phase D)
   4. [match     ] 70_Test_Generation  (phase X) <- generate tests, test this notifier
```

**Why closure includes 20:** Test Generation (#70) generates tests using the patterns owned by Testing (#20), Riverpod (#08, notifier override patterns), and API Testing (#12, data-layer tests). The router expands them all.

## Example 9: "We're running out of context" (token economy)

```
Request: "we're running out of context, compress the project docs"
Mode: ad-hoc  |  confidence: high  |  loaded 2 of 74 skills
Ordered plan:
   1. [match     ] 25_Context_Compression_Engine  (phase X) <- running out of context, compress
   2. [dependency] 35_Skill_Telemetry  (phase X)
```

## Example 10: CI is failing repeatedly

```
Request: "ci is red and keeps breaking, fix it automatically"
Mode: ad-hoc  |  confidence: medium  |  loaded 2 of 74 skills
Ordered plan:
   1. [match     ] 33_Self_Healing_CI  (phase X) <- ci is red
   2. [dependency] 37_Build_Doctor  (phase X)
```

**Why the closure stops short:** Self-Healing CI (#33) depends on Build Doctor (#37), but #37 has no deps. The Analyzer Auto-Fix (#41) is also in #33's dependsOn closure but only self-healing tasks need it; the router includes all closure members equally.
