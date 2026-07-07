# Personal Strong Clone (iOS) - Software Requirements Specification

## Platform

-   iPhone only
-   Native Swift + SwiftUI
-   iOS 18+
-   Offline-first
-   Local-only storage (SwiftData/Core Data)
-   No accounts, cloud sync, Apple Watch, subscriptions, or privacy
    features.

## Goal

Build a fast, offline workout tracker for personal use with unlimited
workout templates and full analytics.

## Navigation

-   Home
-   Workouts
-   Templates
-   Progress
-   Settings

## Home

-   Continue Current Workout
-   Start Empty Workout
-   Start From Template
-   Recent Workouts
-   Weekly Goal Progress
-   Current Body Weight
-   Personal Records Summary
-   Last Workout Summary

## Workout Logging

-   Empty/template/duplicate workout start
-   Workout header: name, date, start time, elapsed time, notes
-   Exercise list
-   Exercise types: weight+reps, weight only, reps only, duration,
    distance, bodyweight, assisted, machine, cable, custom
-   Set types: normal, warm-up, failure, drop set
-   Set fields: weight, reps, duration, distance, RPE, completed, notes
-   Exercise actions: add/delete/reorder/duplicate/replace, notes,
    history, records
-   Set actions: add/delete/duplicate/reorder, autocomplete previous
    values, edit
-   Workout actions:
    pause/resume/cancel/finish/edit/duplicate/delete/change date

## Exercise Library

-   Built-in database
-   Instructions
-   Primary/secondary muscles
-   Equipment
-   History
-   Progress charts
-   Personal records
-   Custom exercises (create/edit/delete/hide/restore)

## Templates

-   Unlimited templates
-   Folders
-   Favorites
-   Search
-   CRUD operations

## Rest Timer

-   Manual/automatic
-   Custom durations
-   Sound/vibration
-   Restart/skip

## History

-   Chronological list
-   Search/filter
-   Edit/delete/duplicate

## Exercise Detail

-   Lifetime volume
-   Estimated 1RM
-   Best weight
-   Best reps
-   Best volume
-   Workout frequency
-   History
-   Charts
-   Notes

## Progress Dashboard

-   Weekly workouts
-   Monthly workouts
-   Total workouts
-   Current streak
-   Longest streak
-   Total volume
-   Average workout duration
-   Average weekly volume
-   Current body weight
-   Personal records

## Analytics & Charts

-   Workout frequency (daily/weekly/monthly/yearly)
-   Total volume (daily/weekly/monthly/yearly)
-   Estimated 1RM per exercise
-   Max weight per exercise
-   Max reps per exercise
-   Total sets per exercise
-   Total reps per exercise
-   Workout duration trend
-   Body weight trend

## Personal Records

-   Highest weight
-   Highest volume
-   Most reps
-   Best estimated 1RM
-   Longest workout
-   Largest volume workout
-   Longest training streak

## Notes

-   Workout notes
-   Exercise notes
-   Set notes
-   Searchable

## CSV Export

-   Export workouts, exercises, sets, templates, measurements, dates,
    records

## Settings

-   lbs/kg
-   miles/km
-   12/24-hour
-   Light/Dark/System theme
-   Rest timer defaults
-   Export
-   Reset app data

## Data Model

### Workout

-   id, date, duration, notes, exercises, totalVolume

### Exercise

-   id, name, category, equipment, muscleGroups, notes

### WorkoutExercise

-   exerciseID, order, sets

### Set

-   id, weight, reps, duration, distance, RPE, completed, setType, notes

### Template

-   id, name, folder, exercises

### Measurement

-   id, date, type, value

### PersonalRecord

-   exercise, type, value, date

## Future

-   Apple Health
-   Nutrition tracking
-   Exercise media
-   Widgets
-   Import from Strong CSV
-   AI suggestions

## MVP

1.  Exercise database
2.  Workout logging
3.  Unlimited templates
4.  Rest timer
5.  History
6.  Exercise detail
7.  Progress dashboard and charts
8.  CSV export
9.  Settings
