# AGENTS.md

## Purpose

This file defines repository-level rules for Codex in this Flutter project.
Favor small, targeted changes that preserve existing architecture, naming, and UI behavior.

## Repository Expectations

This is a feature-first Flutter application organized under `lib/features`.
Most features follow `data`, `domain`, and `presentation` layers, but Codex should match the local pattern of the touched feature instead of forcing a rewrite.

## Architecture Principles

- Favor feature ownership first. Keep feature-specific models, providers, widgets, and helpers inside the owning feature unless at least two features actively reuse them.
- Preserve dependency direction: `presentation -> domain -> data`. UI code must not reach directly into remote/local data sources when a provider, controller, or repository already owns that interaction.
- Treat repositories as the boundary for data access. API calls, persistence, and external SDK interactions should stay out of widgets and out of simple UI helpbber methods.
- Keep domain logic framework-light when practical. Business rules, validation, filtering, mapping, and status decisions should be easy to test without depending on widget code.
- Prefer view models or provider-owned presentation data when the UI needs formatted labels, grouped sections, or display-ready flags. Do not spread repeated mapping logic across multiple widgets.
- Add to `lib/core/` only when behavior is truly shared, stable, and generic. Do not move code into `core` just to avoid importing from a feature.
- Avoid circular feature dependencies. If two features need the same behavior, extract the smallest shared abstraction into `core` or keep one feature as the clear owner and depend on its public-facing contract only when that pattern already exists.
- Extend existing layers before creating new folders such as `services`, `helpers`, or `managers` inside a feature. New structure is justified only when the feature already has enough complexity to support it clearly.
- Prefer additive refactors and seam creation over architectural rewrites. If a feature is inconsistent, improve the touched path and leave the rest stable unless the task explicitly asks for broader cleanup.
- Keep side effects explicit. Navigation, analytics, network calls, storage writes, and uploads should flow through the owning provider/controller or repository instead of being triggered deep inside reusable widgets.
- When introducing shared abstractions, optimize for clarity over cleverness. Use simple interfaces, focused methods, and names that reflect current app behavior rather than speculative future use cases.
- Document architecture by example through file placement and naming consistency. New files should make it obvious where business logic, state, and UI behavior live without needing extra explanation.

## Repository Layout

- `lib/core/`
  Shared constants, config, managers, navigation, utilities, services, and reusable widgets.
- `lib/features/<feature>/`
  Feature code grouped by domain such as `presentation`, `data`, `domain`, and related models/providers.
- `lib/routes/`
  App-level route registration and navigation wiring.
- `lib/assets/images/`
  Bundled image assets used by the application.
- `third_party/`
  Local vendored packages. Do not edit unless the task explicitly requires it.
- `build/`, `.dart_tool/`
  Generated output. Do not modify manually.

## How To Work In This Repo

- Prefer following the existing feature structure instead of introducing a new architecture.
- Prefer the existing `Provider`, `ChangeNotifier`, and `ProxyProvider` patterns already used in the codebase. Do not introduce a new state-management approach without explicit approval.
- Keep mutable screen state in the owning controller/provider when that screen already follows that pattern.
- For strictly local widget state, `ValueNotifier` is acceptable when it keeps the code simpler and the surrounding file already uses that style.
- Reuse existing shared UI primitives such as `AppTextView`, `AppColors`, `DrawerMainScreen`, and existing utility helpers before creating new abstractions.
- Keep screen-specific helper widgets private in the same file when that is already the pattern for the surrounding code.
- Favor additive refactors over broad rewrites.

## Flutter Conventions

- Use null-safe Dart idioms and keep types explicit when they help readability.
- Respect the existing lint baseline from `analysis_options.yaml` and `package:flutter_lints/flutter.yaml`.
- Use `snake_case` for file names, `PascalCase` for types, and `_privateName` for file-private helpers.
- Prefer immutable widget inputs and `const` constructors where practical.
- Keep widget trees readable by extracting focused private widgets when a build method becomes too dense, but avoid creating unnecessary abstraction for tiny one-off UI fragments.
- For async UI actions, handle loading and failure states in the widget or provider that owns the interaction.
- Buttons must keep the same width and height while loading. Preserve the label/icon layout and overlay a bounded loader, or reserve an identical icon slot in both states; do not let a loading indicator determine the button's size.
- Always use `FastCircularProgressIndicator()` from `lib/core/widgets/fast_circular_progress.dart` whenever a progress bar or loading indicator is needed in the project. Reuse its sizing and color options instead of adding direct `CircularProgressIndicator`, `LinearProgressIndicator`, or custom spinner implementations. This includes placeholder loaders inside SOP and Assignment description cards while content is loading or its initial state is being resolved.
- Dispose owned controllers and notifiers such as `TextEditingController`, `ScrollController`, `PageController`, `TabController`, `AnimationController`, `VideoPlayerController`, and `ValueNotifier`.
- Use existing status/color conventions from `lib/core/constants/app_colors.dart` unless the task requires a new design rule.

## UI Rules

- Main listing search bars must use the shared LMS styling in `AppListingSearchBar`: a 40-pixel minimum field height that grows with text scaling, 12-pixel corners, a 40-by-40 filter button with a 20-pixel icon, and an 8-pixel gap. Keep the Seat Profile filter button visible and the department strip hidden; its filter opens Departments with All first and selected by default, and bottom SafeArea disabled. Paygrades must use its filter sheet instead of department chips or See All.
- Main listing filter sheets must use `AppFilterSheetHeader` directly at the top of the sheet, without extra parent top padding or spacer widgets. Keep its 10-pixel top inset, 16-pixel horizontal inset, and shared handle/title/divider spacing; start the filter content 16 pixels below the divider, including the header's 12-pixel bottom padding.
- On Check-in description list cards, keep the rating row centered, the camera action vertically centered against the full card content in the right-hand column aligned with the chevron, and the type tag at the bottom-right. Do not center the camera against the ratings/decrement row alone. Single-description details must retain previous/next arrows beside `Page X of Y`, with arrows disabled at the first and last pages.
- Every Check-in description card camera menu must retain Comment Only alongside Photo, Video, and Upload. Route Comment Only through `DescriptionTextCommentDialog` and the controller's text-comment method using the resolved audit-description UUID; a media attachment must not be required.
- Render delete/trash icons with `SvgPicture.asset('${AppStrings.imagePath}delete.svg')`, including Training lesson actions, quiz actions, and swipe-to-delete controls. Preserve existing icon sizes and contrast colors when replacing Material icons.
- Populate repeated UI with builder widgets such as `ListView.builder` or `ListView.separated`, or collection mapping for short inline content. Do not use `for` loops to populate widget children.
- In the LMS filter sheet, use the Create Training Seat → Category → Description dropdown styling and hierarchy. Enable each dependent dropdown only after its parent is selected, and clear dependent selections when the parent changes. Picker taps only update the draft; apply filters, including All Seats, only from the bottom Done button. Closing discards the draft.
- Keep the department list/filter strip off the main LMS listing. Training tabs screens must not display the lesson overview/header bar, including New Lesson; wait for an explicitly requested placement before adding that action elsewhere.
- LMS listing lesson taps open `EditTrainingScreen`. Keep the public-link Share action in that screen's top bar and use its loaded description lessons; verify the listing-to-lesson navigation when changing sharing, rather than testing only the separate `TrainingLessonViewerScreen`.
- Do not show success snackbars for LMS lesson creation, updates, deletion, video or thumbnail uploads, SOP or quiz generation, or assignment saves. Update the content directly and preserve error and validation feedback.
- Use `AppRadioSelectionTile` for seat-profile and department picker rows: a leading unchecked radio or purple selected radio followed by the name, with no card background or selected border. Preserve each picker's existing single/multiple selection and Show/Done behavior.
- Keep quiz `Add Option` actions visible while option fields are being edited. Existing-question editors must preserve all locally added options and the correct-answer UUID until Save or Cancel; opening one draft option must not hide the action or require an intermediate API save.
- Open quiz question editing in a bottom sheet from Actions > Edit, using the shared question-sheet header and Correct Answer selector. Keep question cards in display mode and leave about 10 logical pixels between option rows, without adding a trailing gap after the last display option.
- In the Add Question and Edit Question sheets, reveal option Delete actions with a right-to-left swipe. A swipe must never remove an option. In Add Question, tapping Delete removes the option immediately without confirmation. In Edit Question, tapping Delete must ask for confirmation before removing either an existing or newly added option from the draft. Set all text input cursors in both sheets to 15 logical pixels high.
- Name the lesson selection sheet All Lessons and keep New Lesson creation outside this sheet. Cap its height at 85% of the screen and keep long lists scrollable. For users with training management access, reveal each lesson's Delete action with a right-to-left swipe and use the existing module deletion confirmation before deleting it.
- Keep View Lesson visually aligned with Edit Training by sharing its bottom navigation, video layout, title field, and quiz cards. Video and SOP remain available for every selected lesson. Quiz and Assignment require separate tab-viewing permission: existing training managers retain their access, and non-owner accounts with `hasSandboxAccess == true` may open them only for their managed seat profiles. This managed-seat viewing also applies in child organisations, while child-organisation editing remains blocked. Preserve existing `isOwner == true` access. Disable taps and swipes when viewing permission is unavailable. Sandbox access alone must never grant editing rights. Keep read-only titles inside the same non-interactive field without an edit icon, and do not show the training read-only notice card. The viewer must not expose create, edit, delete, upload, generation, formatting, or submission actions, even to managers.
- Keep the viewer's SOP heading and white reading panel mounted in loading, empty, error, and content states. An unresolved SOP must show `FastCircularProgressIndicator` immediately, including during a swipe into the tab; show No SOP Available only after the API has returned empty content, and discard document responses from a previously selected lesson.
- The SOP editor's purple Done button only dismisses an open keyboard. SOP changes are saved by the controller's existing debounce; Done must not trigger or flush a save request.
- In the A4 SOP editor, double-tap must select text without changing zoom; preserve pinch zoom and native selection. Toolbar active states must query the mark/node type associated with each command, including stored marks and mixed selections. Hide the iOS previous/next/Done keyboard accessory only for the SOP WebView, retaining the app's formatting toolbar and purple Done button.
- Preserve explicit HTML line breaks and blank paragraphs when loading SOP content into the editor. Saving and reopening must preserve the same spacing and formatting offsets; block separators must not collapse repeated `<br>` tags or add duplicate breaks on each reload.
- Preserve SOP `data-sop-template` and `data-sop-role` attributes through parsing, editing, and saving. Apply the reference template's styles only to documents marked `reference-v1`; ordinary SOPs retain their own design. Verify template rendering with the API's marker-only HTML, including after a text edit and reload, and install the SOP schema before its first native document initialization.
- Assignment creation and explicit title edits require a nonblank title. Existing Assignment instruction edits must debounce a PATCH to `training_assignment/<assignment-id>/`, including assignments whose API response has no title. Omit unchanged title fields from content-only PATCH payloads; a missing title must not silently block editing existing instructions. Keep Done as keyboard dismissal, and verify autosave by editing the actual Assignment tab in a widget test.
- Keep the AI quiz generation sheet's Replace Existing Questions toggle above the final divider and connected to the existing replacement flag when updating its design.
- Keep training quiz lists compact on mobile: use 16 logical pixels for the section heading, 14 for questions, 12 for answers and action labels, 12 for card padding, and 10–12 for gaps. Preserve system text scaling rather than enlarging the base sizes to match screenshot pixels.
- Preserve the established visual system unless the task explicitly asks for a redesign.
- Use `AppDialogStyle` for dialog outlines: a 0.5-pixel purple stroke at 40% opacity. Apply it to the visible dialog surface, preserve its existing corner radius, and avoid duplicate borders on transparent dialog wrappers.
- On new or changed screens, maintain mobile-first layout behavior and avoid overflow.
- Reuse existing spacing, typography, icon, and bottom-sheet patterns where possible instead of inventing a parallel style.
- If media, uploads, comments, or sheets already exist elsewhere in the app, mirror those interaction patterns before creating a new one.
- Long text, pills, tags, and action rows must be overflow-safe by using `Expanded`, `Flexible`, wrapping, or constrained layouts where appropriate.
- Media cards should use stable constraints. If a list or pager mixes images and videos, keep the video thumbnail container matched to the image container unless the task explicitly asks for a different treatment.
- The fullscreen entry button in both Training and LTC video tabs must use a rounded rectangular container with `AppColors.surfaceDark2` and a 12-logical-pixel corner radius, matching Training's thumbnail action. Keep the SVG background transparent so the widget supplies the only background, and preserve the existing tap area.
- In the shared Training and Learning Compliance video player, keep the title, duration, and purple progress bar synchronized with play/pause and 10-second skip controls: hide on playback, reveal for three seconds after a video tap, and stay visible while paused, completed, or scrubbing. Restart the hide timer after scrubbing ends.
- Apply the same control visibility timing in fullscreen, including the exit-fullscreen button and transcript action. Do not show a back icon in fullscreen; retain system-back support. Single taps on the fullscreen video, black area, or active caption toggle play/pause and reveal controls. Paused controls stay visible; resuming from a surface tap reveals them for three seconds. Dedicated buttons, seeking, and caption scrolling retain their own gestures without also toggling playback. While controls are hidden, move active captions into the bottom seek-bar area. When controls are revealed, restore captions above the title and playback controls in their existing position. Keep the caption mounted with the same viewport height so long-caption scrolling is preserved. Tapping an active caption must reveal controls and restore its normal position without resetting its scroll position.
- LTC and Edit Training must share the transcript panel, with Edit Training reading `trainingVideo.transcript`. Both use the shared video height of half the screen, clamped to 320–520 logical pixels and then reduced by 60 logical pixels, with the same fill behavior and playback controls. LTC must not show re-upload or thumbnail-change actions, and must not add a fractional-height wrapper around the video panel. Both retain rounded corners and a fixed video frame. Active captions wrap fully: while playback controls are hidden, start captions exactly 6 logical pixels below the rendered video image and grow the black surface downward with their text. Measure the visible video bounds instead of anchoring to the hidden title/seek area or the full player frame, which can include black bands; never bottom-anchor captions with empty space above. When controls appear, place the title/duration and seek bar group exactly 10 logical pixels below the rendered video image, followed by active captions exactly 10 logical pixels below the seek bar view. Let the black area grow to fit, and keep controls tappable even when scaled text puts them beyond the fixed video frame. Tapping an overlaid caption must reveal the controls, long captions must remain scrollable, and CC must hide captions in both positions. Do not add extra margin between LTC active captions and the video controls; preserve the existing seek bar, title, and duration positions when adjusting transcript spacing. Put CC at the start and View Transcript at the end of the bottom row, exactly 4 logical pixels below the active caption in both playback states. Do not stack caption bottom padding with this gap; the caption area grows with wrapped text while the video frame stays fixed. When no caption is visible and playback controls are shown, place the action row 6 logical pixels below the seek bar view, using its existing bottom space without moving the video, seek bar, title, or duration. This also applies when CC hides a cue and during transcript timing gaps. CC starts off; enabling it hides captions. While playback controls are also hidden, collapse their reserved space too and place the action row 6 logical pixels below the rendered video image. Let the footer determine the outer black surface height while retaining the video frame and media bounds; restore the original controls positions when revealed. Open the transcript sheet centered on the active cue without extra blank space at the list start. Timed rows seek and resume playback, showing bounded progress after the timestamp while waiting for initialization or a seek retry. Preserve Edit Training's summary and permission-controlled video actions, and reset transcript state when the selected lesson or video changes.
- In Edit Training's Video tab, show active captions on one line and advance long cues through consecutive segments using playback timing and the available text width. Keep the upper black band at half its centered height with a small gap below the video action icons. Apply the same media alignment to preview bounds, decoded thumbnails, and playback so the title and seek bar stay aligned during initialization.
- In LTC and Edit Training, open the video panel at its compact preview height on the first frame, using 16:9 preview bounds with the panel's media alignment until media measurements are available. Loading callbacks must keep those compact bounds instead of briefly expanding to the full video frame. Anchor the title and seek bar 10 logical pixels below the visible thumbnail before playback starts, including while the native player initializes and when there is no active transcript. Measure the thumbnail again after image decoding; do not leave the footer at the bottom of the taller video frame. Switch measurement to the video when playback starts.
- Keep the app locked to portrait outside fullscreen video and EditTrainingScreen's Video and SOP tabs. In EditTrainingScreen, rotating the Video tab to landscape expands the existing tab in place to fill the screen; do not push another video route. Hide the screen header, lesson title, summary, and bottom navigation while expanded. Disable horizontal tab swipes in fullscreen, including drags started before rotation, while retaining video seek controls; restore tab swiping in the normal view. Keep the same mounted player, video texture, playback controller, position, and play/pause state across rotation, without an extra seek. Rotating back to portrait restores the normal Video tab. SOP rotates in place, preserving its editor and pending changes. Quiz, Assignment, embedded training, and the separate lesson viewer retain the portrait rule. Keep the fullscreen rotation icon hidden. Provide a white exit-fullscreen icon at the end of the fullscreen playback controls. Tapping it restores the normal portrait Video tab and system bars without changing playback. After an explicit reset, keep portrait locked until the phone physically returns to upright portrait, using the native orientation bridge rather than the forced viewport rotation; then allow the next portrait-to-landscape movement to expand the same Video tab again. Cancel pending sensor waits when leaving the tab or screen. Use the display's full viewport with safe-area padding only around controls, retain the video's aspect ratio and playback controller, and use Android's WindowInsets fullscreen bridge for system bars on API 36 rather than relying solely on Flutter's legacy immersive mode.
- Training tabs must use Flutter's page snapping in a stable, bounded viewport, with horizontal padding and a separate clip around each page's content so adjacent tabs have a visible gap during swipes. Keep the pager mounted during tab changes, and let each tab own its vertical scrolling. Completed or cancelled swipes and interrupted tab taps must settle on one complete page that matches the bottom navigation; do not implement separate translated preview stacks.
- Keep the main and Training lesson bottom navigation surfaces at 12 logical pixels from the left and right screen edges, respecting side safe-area insets. Apply this spacing in the navigation's containing SafeArea. Verify the rendered EditTrainingScreen and lesson viewer when changing these margins.
- Match detail screens and their child screens to the parent home screen's 8-logical-pixel horizontal content inset, including headers and non-video Training tab pages. In Edit Training, the lesson viewer, and LTC, keep the video and its black background full width; apply the 8-pixel inset separately to titles, summaries, and other surrounding content. Keep the bottom navigation's separate 12-logical-pixel side margins.

## UI File Structure And Widget Organization

- **Main Screen File**: Keep the main screen widget lightweight; extract UI logic into focused private helper widgets when the build method exceeds 30-40 lines.
- **Reusable Widget Pattern**: Create private `_CustomWidgetName()` methods or separate private widget classes for UI components that are used more than once in the same feature or across the app.
- **Widget Granularity**: Break down complex layouts into smaller widgets with clear responsibilities (e.g., `_HeaderSection()`, `_ContentCard()`, `_ActionButtons()`, `_EmptyStateView()`).
- **Widget Naming**: Use descriptive names that reflect the widget's purpose. Prefix private widgets with underscore (e.g., `_UserProfileCard`, `_FilterChip`).
- **Immutability**: Ensure private widget methods accept all necessary data as parameters and remain pure functions. Avoid capturing mutable state directly.
- **Documentation**: For complex private widgets, add brief inline comments explaining the widget's purpose and expected parameters.

## String And Localization Rules

- **String Declaration**: All user-facing strings must be declared in `lib/core/constants/app_strings.dart` or the feature-specific strings file (e.g., `lib/features/<feature>/presentation/strings.dart`).
- **No Hardcoded Strings**: Do not hardcode strings directly in widget files or UI builders. Always reference strings from the AppStrings file.
- **String Organization**: Group related strings logically with clear naming conventions (e.g., `buttonSubmit`, `labelEmail`, `errorInvalidInput`, `messageWelcome`).
- **Reuse Pattern**: Import strings at the top of the UI file and reference them as `AppStrings.stringName`.
- **Pluralization and Parameters**: For strings with dynamic content, use `String.format()` or string interpolation patterns defined in AppStrings.

## State And Variable Declaration Rules

- **Controller/Provider Declaration**: All mutable state, input values, and business logic variables must be declared in the feature's controller or provider (e.g., `UserProfileController`, `SettingsNotifier`).
- **Variable Exposure**: Use getter methods or exposed stream properties to make variables available to the UI widget.
- **Local-Only State**: Only use `ValueNotifier` or `State` local variables for strictly UI-local state (e.g., collapsed/expanded sections, tab indices) when the feature controller does not already manage it.
- **Avoid Direct Mutation**: UI widgets should never directly mutate controller state. All state changes must go through controller methods.
- **Type Safety**: Always use typed providers and controllers; avoid raw `dynamic` types when accessing state from the UI.
- **Cleanup**: Ensure all streams, listeners, and notifiers subscribed to in the UI are properly unsubscribed or disposed when the widget is disposed.

## Permission Rules

- **Public-Link Sharing**: Seat Profile, Paygrades, and LMS Share actions require `User.isOwner == true`. Role names (including `owner` and `csuite`) and module management access must not substitute for this flag. Apply the same shared permission helper to Share visibility and public-link GET, POST, DELETE, and copy actions; preserve the child-organisation restriction.
- **Child Organisation Read-Only**: Except for the Check-in module, when the active organisation has `type == child`, no account may Create, Edit, Delete, or Update organisation content, including owners. Hide main Create entry points too. Apply this restriction before owner, sandbox access, role, department, hierarchy, or explicitly passed management access checks.
- **Sandbox Training Access**: For accounts without `User.isOwner == true`, sandbox-based viewing of Quiz and Assignment requires both `User.hasSandboxAccess == true` and the opened lesson's seat profile matching the user's hierarchy `manageableSeatProfileIds`. Apply this scope in every organisation, including child organisations and when Sandbox is inactive; sandbox access must not unlock unrelated lessons or lessons with an unresolved seat profile. Preserve existing `isOwner == true` access and ordinary training-management permissions. Resolve tab-viewing access separately from training management in the shared permission helpers. Keep create, edit, delete, upload, generation, formatting, and save actions behind the existing training editing permissions, including the child-organisation restriction; sandbox access alone must not enable them. The separate lesson viewer remains read-only. Preserve main Create entry rules, public-link sharing rules, and permissions for other features.
- **Child Organisation Training Viewer**: Keep Video and SOP available in child organisations. Non-owner accounts with `hasSandboxAccess == true` may open Quiz and Assignment by tapping or swiping in read-only mode only for their managed-seat training. Otherwise, these tabs remain disabled and reject taps and swipes. Preserve existing `isOwner == true` viewing rules. No account may edit training content in a child organisation.
- **Check-In Organisation Exception**: Do not apply child-organisation restrictions to Check-in screens or controller writes, including Create/Continue, ratings, comments, media, and performance-report certification. Preserve existing role, self-check-in, date-window, billing, and certified-report rules. Embedded Training actions still follow Training permissions.
- **Owner Override**: For Check-in in every organisation, and for other modules outside child organisations, treat `User.isOwner == true` as a master-access override for app permissions. Owner users must not lose Create, Edit, manage, or team-access actions because of seat-scoped, hierarchy-scoped, or role-list checks.
- **Permission Helper Source**: Put organisation restrictions and owner permission rules in shared user/app permission helpers before feature screens consume them. Do not re-encode owner exceptions ad hoc inside individual widgets when a shared helper can own the rule.
- **Hierarchy Matching**: When resolving managed-profile permissions from organisation hierarchy JSON, match the logged-in user against the hierarchy node `profile.uuid`, `profile.user_uuid`, or `profile.email`, and treat only that matched node's direct `children` as managed profiles for seat-scoped training permissions.
- **Department Scope**: Seat profile create/edit permissions must be checked against the matched hierarchy membership `department_uuid`; do not broaden seat-profile edit access from department names, unrelated descendants, or generic lead-role checks alone.
- **Role Aliases**: Treat API role aliases such as `c_suite` and `csuite` as the same role before permission checks.
- **Create Entry Vs Scope Enforcement**: For Seat Profile and LMS outside child organisations, keep the outer create entry points available to any account with at least one non-`team_member` role, then enforce the stricter department and managed-seat permission checks only after the create flow opens. Child organisations must never expose these entry points for any role.

## Feature-Specific Best Practices

- **Separation of Concerns**: Keep UI presentation logic in the screen file, business logic in the controller, and data access in the repository.
- **Error Handling**: Display error messages from AppStrings and always show user-friendly error states using controllers' error properties.
- **Loading States**: Implement loading indicators and disable user interactions during async operations by tracking a loading state in the controller.
- **Naming Convention for Screens**: Name screen files as `<feature>_screen.dart` and controller files as `<feature>_controller.dart`.
- **File Organization**: For complex features, organize presentation layer as: `screens/`, `widgets/`, `controllers/`.

## Data And Media Rules

- Reuse the website's existing dialog for mobile deep-link visits; fallback scripts must not inject a second dialog. Installed apps open through the existing verified deep links. Browser visits, including pasted links and visits without the app, stay on the website; only the existing dialog button navigates to the device's official store. Do not auto-launch the app, redirect on page load, or use a timer to infer installation. Supply a TypeScript Window declaration for any global helper used by the frontend.
- For Android HTTPS links that stay in the browser, inspect `adb shell pm get-app-links --user cur com.kaizenteam` and compare the installed signing SHA-256 and application ID with the live host's `/.well-known/assetlinks.json` before changing Flutter routing. Keep debug, local release, and Play App Signing certificates distinct; a package-targeted launch bypasses verification and is not proof that normal link taps work.
- Keep production `app.kaizenteams.ai` verification and organization deep links registered in both Android's manifest and the shared Flutter resolver, alongside the dev domain. A production-host shortcut must not skip these routes; Google callbacks remain owned by the active sign-in attempt.
- Google browser sign-in must select the Web/backend OAuth client and exact registered callback together through `GoogleOAuthConfiguration` using the backend environment. Do not add independent client/redirect fallback strings in the authorization datasource, substitute Android/iOS native client IDs, or construct a callback by appending a path to the REST API host. Keep Android/iOS callback links aligned with both environments, forward the same redirect URI during code exchange, and generate a fresh state instead of copying Google's account-chooser session URL.
- For iOS Google callback changes, inspect Runner's `CODE_SIGN_ENTITLEMENTS` in every build configuration. Debug/Profile use `RunnerTesting.entitlements`, while Release uses `Runner.entitlements`; both must include the production callback domain. Verify the domains embedded in a signed app, not only the source plist.
- For Check-In ratings, publish successfully saved counts through the shared controller to the matching description UUID. Keep saves for the same description ordered, and preserve pending detail edits when navigating back; do not wait for an older list-card count before accepting detail updates.
- Prefer local feature data shaping inside providers/controllers instead of scattering UI-specific transforms across widgets.
- Keep business logic, status mapping, and display label mapping out of widget trees when the logic is reused or non-trivial.
- For Kaizengram Learning tab posts, `description` will not be present. UI, models, and mappers must not expect description content, must not reserve empty layout space for it, and must keep those posts visually correct without a description field.
- For Kaizengram Groups home feed, do not show a suggested groups section below the main joined-groups list.
- When adding media selection or upload flows, use existing dependencies already present in the repo such as `image_picker` or `file_picker`.
- If a feature already distinguishes image/video/document states, preserve that distinction through the UI and comments/detail sheets.
- When a detail sheet opens from a tapped media item, keep the selected item in sync so the sheet shows the same image or video the user opened.
- Do not introduce another picker, player, or caching package if the repo already has a suitable dependency.

## Commands

Run the minimum relevant checks for the touched area.

- Install dependencies:
  `flutter pub get`
- Format touched files:
  `dart format <files>`
- Analyze relevant files:
  `flutter analyze <paths>`
- Run full analyzer when changes are broad:
  `flutter analyze`
- Run tests when logic changes or tests are touched:
  `flutter test`

## Constraints And Do-Not Rules

- Do not edit `third_party/` packages unless explicitly requested.
- Do not manually edit generated folders or build artifacts.
- Do not add new dependencies, state-management approaches, or major architectural patterns without approval.
- Do not rename or move large parts of the repo unless the task specifically asks for that.
- Do not silently change status semantics, route behavior, or upload behavior across features unless the task requires it.
- Do not do broad formatting-only churn in unrelated files.

## Done When

A change is complete only when all of the following are true:

- The requested behavior is implemented in the relevant feature.
- The touched Dart files are formatted.
- `flutter analyze` passes for the touched scope at minimum.
- Any important limitations, skipped checks, or follow-up risks are clearly reported.
- The final response names the main files changed and what was verified.

## Good Defaults For Codex

- Read the relevant feature folder before editing.
- Prefer the canonical `.codex` routing skill at `.codex/skills/repo-navigation/SKILL.md`, then open only the relevant feature reference under `.codex/skills/repo-navigation/references/features/`.
- If a workflow or older instruction points to `lib/features/SKILLS.md` or `lib/features/<feature>/SKILL.md`, treat those files as compatibility shims that redirect to the canonical `.codex` references.
- Prefer the smallest change that satisfies the request.
- Verify UI changes with analyzer-friendly, overflow-safe widget code.
- When a bug repeats, update this file with a concrete rule rather than adding vague guidance.
