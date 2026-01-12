# SumQuiz Blueprint

## Overview

SumQuiz is a mobile application that leverages AI to transform various forms of content into study materials. It allows users to import text, links, PDFs, and images, and then generates summaries, quizzes, and flashcards from the extracted content. The application is designed to be a comprehensive study companion, with features for spaced repetition, progress tracking, and offline access.

## Style, Design, and Features

### Theming

*   **Theme Provider:** The application uses a `ThemeProvider` to manage light and dark themes.
*   **Material Design 3:** The UI is built with Material Design 3 components, providing a modern and consistent look and feel.
*   **Color Scheme:** The color scheme is based on a primary seed color, which is used to generate a harmonious and accessible color palette.
*   **Typography:** The application uses the `google_fonts` package to provide a variety of a custom text styles.

### Architecture

*   **Provider State Management:** The application uses the `provider` package for state management, with a combination of `ChangeNotifierProvider`, `ProxyProvider`, and `StreamProvider` to manage the application's state.
*   **Layered Architecture:** The codebase is organized into a layered architecture, with a clear separation of concerns between the UI, business logic, and data layers.
*   **Services:** The application uses a variety of services to handle tasks such as authentication, data storage, AI processing, and content extraction.

### Features

*   **Authentication:** Users can sign in with Firebase Authentication.
*   **Content Extraction:** The application can extract text from a variety of sources, including:
    *   Plain text
    *   Web links
    *   PDF files
    *   Images (using OCR)
    *   **YouTube videos (via direct Gemini API analysis)**
*   **AI-Powered Content Generation:** The application uses the Gemini AI model to generate the following study materials:
    *   **Summaries:** Comprehensive study guides with titles, content, and tags.
    *   **Quizzes:** Challenging multiple-choice exams with plausible distractors.
    *   **Flashcards:** High-quality flashcards for active recall study.
*   **Local Storage:** The application uses a local database to store all generated content, ensuring offline access.
*   **Spaced Repetition:** The application includes a spaced repetition system to help users learn and retain information more effectively.
*   **Syncing:** The application can sync data with a backend service to provide a seamless experience across multiple devices.
*   **In-App Purchases:** The application includes in-app purchases to unlock premium features.
*   **Referrals:** The application includes a referral system to reward users for inviting their friends.
*   **Notifications:** The application can send notifications to remind users to study.
*   **Error Reporting:** The application includes an error reporting service to help developers identify and fix bugs.
*   **Progress Tracking:** The application now provides real-time progress updates for long-running operations, such as content generation.
*   **User-Friendly Error Messages:** The application now displays user-friendly error messages that are easy to understand.
*   **Input Validation:** The application now validates user input to prevent crashes and other issues.

## Current Plan: Refactoring YouTube Video Analysis with Native Gemini API

This refactoring focused on replacing the inefficient and fragile transcript-scraping method with direct video analysis using the Gemini API's native capabilities.

*   **Implemented Direct YouTube Video Analysis:** The `EnhancedAIService` now has an `analyzeYouTubeVideo` method that passes the public YouTube URL directly to the Gemini `visionModel` using `FileData`. This provides much richer, more accurate context from both video and audio.
*   **Simplified Content Extraction:** The `ContentExtractionService` was significantly simplified. It now calls the new `analyzeYouTubeVideo` method directly, removing the complex and error-prone `_extractYoutubeTranscript` logic.
*   **Removed Redundant Dependencies:** The `youtube_explode_dart` package, which was only used for the old transcript-scraping method, has been completely removed from `pubspec.yaml`, reducing the project's dependency footprint.
*   **Streamlined AI Processing:** The call to `filterInstructionalContent` was removed from the YouTube processing flow in `ContentExtractionService`, as the new prompt in `analyzeYouTubeVideo` handles content filtering more effectively at the source.
