# Architecture Design: Profile Page Widget

## Overview
The profile page widget will display user information (name, email, and avatar) fetched from a remote API. To ensure offline availability, data is cached locally using a caching repository pattern (e.g., using Hive or path_provider + file storage).

## Components & File Structure
- [profile_view.dart](file:///d:/projects/med_scheme/lib/profile/profile_view.dart): UI widget containing user info and update forms.
- [profile_controller.dart](file:///d:/projects/med_scheme/lib/profile/profile_controller.dart): Manages profile state (loading, loaded, error) and triggers updates.
- [profile_repository.dart](file:///d:/projects/med_scheme/lib/profile/profile_repository.dart): Orchestrates remote API fetching and local caching.
- [profile_api_client.dart](file:///d:/projects/med_scheme/lib/profile/profile_api_client.dart): Low-level HTTP client for profile endpoints.
- [profile_cache.dart](file:///d:/projects/med_scheme/lib/profile/profile_cache.dart): Handles local SQLite/Hive/File caching of profile details.

## Data Models / Schemas
### ProfileModel
- `id`: String
- `name`: String
- `email`: String
- `avatarUrl`: String

## APIs & External Integrations
- `GET /user/profile`: Fetches user profile data.
- `POST /user/profile/update`: Updates user profile (name only in this spec).
