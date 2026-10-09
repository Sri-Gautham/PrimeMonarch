# PrimeMonarch

PrimeMonarch is a SwiftUI iOS (iPadOS/Mac) fitness and nutrition app that generates adaptive, algorithm-driven daily calorie, macro, water, and step targets, builds personalized meal and workout plans, and layers in gamification (XP, streaks, achievements) to drive habit formation.

## Features

### Onboarding & Planning
- Multi-step onboarding collecting personal profile (DOB, sex, height/weight), goals, activity level, dietary preferences, and schedule.
- Initial plan reveal showing a computed BMR, TDEE, and calorie target before the user finishes setup.

### Daily Experience
- **Today** — at-a-glance dashboard for calories/water consumed vs. target, current streak, and today's workout status.
- **Log** — manual logging hub for food (recipes + quick-log predefined meals), water, weight, and body measurements, with macro breakdowns.
- **Plan** — daily nutrition plan from the meal-plan engine, plus a workout plan generated on-device via Apple's FoundationModels (with a static fallback catalog).
- **Progress** — charts and history for weight, measurements, progress photos, and weekly meal/workout summaries.
- **Live Workout** — timed session tracking with per-set rep/weight entry, rest timer, and exercise substitution.

### Gamification
- XP ledger, logging streaks, and an achievement catalog that awards progress milestones.

### Account & Privacy
- Sign in with Apple, email/password, and anonymous guest mode with later upgrade to a full account — backed by Supabase Auth.
- Optional biometric (Face ID/Touch ID) app lock, independent of the device passcode.
- HealthKit integration for steps, active energy, body mass, heart rate, and sleep.
- GDPR-style data export and account/data deletion.
- Progress photos stored privately on-device (not synced via Photos/iCloud).

## Architecture

### Domain / Engine Layer
- **MetabolicCalculationEngine** — Mifflin-St Jeor BMR, TDEE (BMR × activity multiplier), and goal-based macro splits.
- **AdaptiveGoalEngine** — orchestrates daily calorie, water (~35 ml/kg, clamped 1800–4000 ml), step, and workout-burn targets, with a data-confidence score that falls back to safe defaults when biometric data is missing.
- **NutritionSafetyConfiguration** — hard safety floors/caps (min 1200 kcal women / 1500 kcal men, max daily deficit/surplus, max weekly weight-change rate). Flagged in-code as requiring professional nutrition review before shipping.
- **MealPlanEngine** — deterministic daily meal plan builder with hard allergy/avoid-term filtering, dietary-style filtering, macro-fit scoring, and day-based variety rotation.
- **GroceryAggregationEngine** — aggregates ingredients across a meal plan into a categorized shopping list.
- **Domain/Models** — SwiftData models for user/goal profiles, daily targets/summaries, logging entries (meals, water, weight), workout sessions, progress (measurements, photos), and progression (streaks, achievements, XP); plus shared domain enums (goal type, activity level, equipment, dietary style, etc.).

### Services
| Service | Responsibility |
|---|---|
| `AchievementService` | Awards achievements and XP from a fixed catalog |
| `AdaptationEngine` | Adjusts today's workout intensity based on logged caloric balance |
| `BiometricService` | Face ID/Touch ID wrapper for the in-app lock |
| `DailySummaryService` | Rolls up the previous day's activity into a summary |
| `DailyTargetService` | Ensures one daily target exists per calendar day |
| `DataDeletionService` / `DataExportService` | Privacy-focused account data deletion/export |
| `HealthKitService` | Reads steps, energy, weight, heart rate, and sleep from HealthKit |
| `NotificationService` | Local reminder notifications |
| `PhotoStorageService` | Private, file-protected progress photo storage |
| `PredefinedMealService` / `RecipeCatalogService` | Bundled quick-log meals and recipe catalog |
| `StreakService` | Logging-streak lifecycle (credit/reset rules) |
| `WorkoutVarietyService` | On-device generative workout plans via Apple FoundationModels, with static fallback |
| `XPLedgerService` | Tracks and credits XP |

### Backend
- **Supabase** provides authentication (Sign in with Apple, email/password, anonymous guest) and sync for user profiles and activity data (meals, water, weight, workouts), with a "remote wins, onboarding step takes max" merge strategy.
- `supabase/schema.sql` defines the backing tables and must be applied manually in the Supabase Dashboard before first run.

## Tech Stack

- **UI**: SwiftUI
- **Persistence**: SwiftData
- **Platform**: iOS 27+ (iPhone/iPad), also builds for Mac
- **On-device AI**: Apple FoundationModels (generative workout plans)
- **Backend**: Supabase (auth + sync)
- **Dependencies**: `supabase-swift`, `swift-clocks`, `swift-concurrency-extras`, `swift-crypto`, `swift-http-types`, `swift-asn1`, `xctest-dynamic-overlay`

## Content

- `Resources/recipes.json` — 60 curated recipes with ingredients, macros, and dietary tags, powering the meal-plan and grocery engines.
- `Resources/predefined_meals.json` — 50 quick-log meals for fast food entry without full recipes.

## Setup

1. Clone the repository and open `PrimeMonarch.xcodeproj` in Xcode.
2. Create a Supabase project and run `supabase/schema.sql` against it via the Supabase Dashboard SQL editor.
3. Set your Supabase project URL and anon key in `PrimeMonarch/Services/Supabase/SupabaseConfig.swift`.
4. Build and run on an iOS 27+ simulator or device.

## Project Status

- Core goal/nutrition/workout engines, SwiftData models, gamification, HealthKit read integration, Supabase auth/sync, data export/deletion, biometric lock, and local notifications are implemented.
- No automated test coverage beyond Xcode-generated boilerplate yet.
- `StreakService` has a planned "grace day" prompt (retroactively mark yesterday as a rest day) not yet built.
