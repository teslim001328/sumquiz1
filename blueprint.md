# SumQuiz Blueprint

## Overview

This document outlines the architecture, features, and design of the SumQuiz application. It serves as a single source of truth for the project, documenting all style, design, and features implemented from the initial version to the current version.

## Project Structure

The project is organized into the following directories:

- `lib`: Contains the main application code, organized by feature.
- `lib/models`: Contains the data models for the application.
- `lib/services`: Contains the services that interact with external APIs and databases.
- `lib/views`: Contains the UI widgets and screens.
- `lib/view_models`: Contains the view models that manage the state of the UI.

## Features

- **User Authentication**: Users can sign in with Google or email and password.
- **Summarization**: Users can generate summaries from text or PDF files.
- **Quizzes**: Users can generate quizzes from summaries or text.
- **Flashcards**: Users can generate flashcards from summaries or text.
- **Library**: Users can save their summaries, quizzes, and flashcards to a local database for offline access.
- **Spaced Repetition**: The application uses a spaced repetition algorithm to schedule flashcard reviews.
- **Synchronization**: The application synchronizes the local database with Firestore when the user logs in.

## Design

The application uses a modern, clean design with a consistent color scheme and typography. The UI is designed to be intuitive and easy to use.

## Current Plan

### Bug Fixes

- **Fixed**: The library screen was not displaying the content from the Firestore database. This was fixed by adding a synchronization service that is triggered when the user logs in.

### Refactoring

- **Refactored**: The `SummaryScreen`, `QuizScreen`, and `FlashcardsScreen` were refactored to use a state enum and improve the overall code structure.

### Next Steps

- Continue to improve the UI and add new features.
- Add more tests to improve the code coverage.
- Monitor the application for bugs and performance issues.