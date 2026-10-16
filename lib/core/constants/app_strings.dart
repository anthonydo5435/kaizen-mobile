class AppStrings {
  AppStrings._();
  static const String appTitle = 'KaizenTeams';
  static const String noContentAvailable = 'No content available.';
  static const String apiInvalidUrl = 'Invalid URL';
  static const String apiInvalidResponse = 'Invalid response';
  static const String apiRequestFailedPrefix = 'Request failed with status code:';
  static const String apiErrorPrefix = 'ApiError:';
  static const String apiUnableToConnectServer = 'Unable to connect to server.';
  static const String apiRequestTimedOut =
      'Server is taking too long to respond. Please try again.';

  static const String loginTitle = 'Sign In';
  static const String loginToYourAccount = 'Login to your account';
  static const String enterProvidedCredentialsToContinue = 'Enter provided credentials to continue';
  static const String loginTo = 'Sign In';
  static const String kaizen = 'Kaizen';
  static const String teams = 'Teams';
  static const String welcomeToKaizenTeams = 'Welcome to Kaizen Teams';
  static const String singInToManage =
      'Sign in to manage your team, training, and clinic operations';
  static const String loginSubtitle = 'Please enter the login credentials';
  static const String loginEmailLabel = 'Enter you email';
  static const String loginPasswordLabel = 'Enter your password';
  static const String loginButton = 'Login';
  static const String loginContinueWithGoogle = 'Continue with Google';
  static const String loginAlternativeSeparator = 'OR';
  static const String loginFailedTitle = 'Login Failed';
  static const String loginGoogleUnavailable =
      'Google sign-in is unavailable right now. Please use your email and password.';
  static const String loginGoogleBrowserUnavailable =
      'Google sign-in requires an up-to-date browser. Please update Chrome and try again, or use your email and password.';
  static const String loginGoogleAppNotVerified =
      'Google sign-in could not verify this app. Please try again later or use your email and password.';
  static const String loginGoogleFailed = 'Unable to sign in with Google. Please try again.';
  static const String loginGoogleTimedOut = 'Google sign-in timed out. Please try again.';
  static const String loginGoogleCodeRejected =
      'Google sign-in could not be completed. Please try again or use your email and password.';
  static const String loginCancelGoogle = 'Cancel Google sign-in';
  static const String loginForgotPassword = 'Forgot Password?';
  static const String loginEnterEmail = 'Please enter your email.';
  static const String loginEnterValidEmail = 'Please enter a valid email address.';
  static const String loginEnterPassword = 'Please enter your password.';
  static const String loginNoAccount = 'No account found for this email.';
  static const String loginIncorrectPassword = 'Incorrect password.';
  static const String loginUnableToConnect = 'Unable to connect to the user database.';
  static const String loginServiceUnavailable = 'Login service is unavailable right now.';
  static const String loginInvalidUserData = 'Invalid user data received from database.';
  static const String loginSomethingWentWrong = 'Something went wrong. Please try again.';
  static const String userRecordIncomplete = 'User record is incomplete.';
  static const String authEmailLabel = 'Enter your email';
  static const String authForgotPasswordTitle = 'Forgot Password?';
  static const String authForgotPasswordSubtitle =
      'Enter the email attached to your account and we will send password reset instructions.';
  static const String authForgotPasswordHelper =
      'Use the work email connected to your Kaizen Teams account.';
  static const String authSendResetLink = 'Send Reset Link';
  static const String authResendResetLink = 'Resend Reset Link';
  static const String authResetLinkFailedTitle = 'Unable to Send Reset Link';
  static const String authResetLinkUnableToSend =
      'Unable to send reset instructions right now. Please try again.';
  static const String authResetLinkServiceUnavailable =
      'Password reset service is unavailable right now.';
  static const String authResetLinkSentTitle = 'Check your inbox';
  static String authResetLinkSentDescription(String email) =>
      'We sent reset instructions to $email. Check your inbox and spam folder for the next step.';
  static const String authAlreadyHaveResetLink = 'Already have a reset link?';
  static const String authSetPasswordAction = 'Set Password';
  static const String authSetPasswordTitle = 'Set New Password';
  static const String authSetPasswordSubtitle =
      'Create a fresh password for your account so you can sign back in securely.';
  static const String authNewPasswordLabel = 'Enter your new password';
  static const String authConfirmPasswordLabel = 'Confirm your new password';
  static const String authPasswordRequirementMinLength = 'Use 8 or more characters';
  static const String authPasswordRequirementLetter = 'Use minimum of one letter';
  static const String authPasswordRequirementNumber = 'Use minimum of one number';
  static const String authUpdatePassword = 'Update Password';
  static const String authSetPasswordFailedTitle = 'Unable to Update Password';
  static const String authSetPasswordMissingToken =
      'Reset link is missing or expired. Please request a new password reset link.';
  static const String authSetPasswordUnableToUpdate =
      'Unable to update your password right now. Please try again.';
  static const String authSetPasswordServiceUnavailable =
      'Password update service is unavailable right now.';
  static const String authPasswordUpdatedTitle = 'Password Updated';
  static const String authPasswordUpdatedDescription =
      'Your password has been updated. You can now sign in with your new password.';
  static const String authEnterConfirmPassword = 'Please confirm your password.';
  static const String authPasswordMinLength = 'Password must be at least 8 characters.';
  static const String authPasswordLetterRequired = 'Password must include at least one letter.';
  static const String authPasswordNumberRequired = 'Password must include at least one number.';
  static const String authPasswordsDoNotMatch = 'Passwords do not match.';
  static const String authRememberedPassword = 'Remembered your password?';
  static const String authBackToLogin = 'Back to Login';
  static const String authLogout = 'Logout';
  static const String authLogoutConfirmationDescription = 'Are you sure you want to logout?';
  static const String onboardingTitle = 'Finish your setup';
  static const String onboardingSubtitle =
      'Complete your profile image and password before entering the app.';
  static const String onboardingSetPasswordTitle = 'Set Password';
  static const String onboardingSetPasswordSubtitle = 'Please create a secure password to continue';
  static const String onboardingSetPasswordEmailHint = 'Email';
  static const String onboardingSetPasswordPasswordHint = 'Enter password';
  static const String onboardingSetPasswordConfirmPasswordHint = 'Confirm password';
  static const String onboardingSetPasswordHelper = 'Use at least 8 characters.';

  static const String splashBrand = 'Chatting\nWorkspace';
  static const String splashTitle = 'Welcome to your\nOnboarding Envelope';
  static const String splashSubtitle =
      'Press next to take a look at your envelope and\nfill in all the required details';
  static const String splashStartupFailed = 'Unable to finish startup right now. Please try again.';
  static const String homePlaceholder = 'Home screen is not available yet.';
  static const String homeTitle = 'Home';
  static const String homeSubtitle = 'Use the drawer to navigate through compliance and audits.';
  static const String homeKaizengram = 'Kaizengram';
  static const String homeAi = 'AI';
  static const String homeLearningTracks = 'Learning Tracks';
  static const String bottomNavPerformance = 'Performance';
  static const String bottomNavLtc = 'LTC';
  static const String homeCompliance = 'Compliance';
  static const String homeLibrary = 'Library';
  static const String weeklyCheckIns = 'Weekly Check-Ins';
  static const String performanceSnapshot = 'Performance Snapshot';
  static const String homeSeatProfiles = 'Seat Profiles';
  static const String homePaygrades = 'Paygrades';
  static const String homeDepartments = 'Departments';
  static const String homeKaizenGpt = 'KaizenGPT';
  static const String homeSetting = 'Setting';
  static const String seatProfileTitle = 'Seat Profile';
  static const String shareAction = 'Share';
  static const String sharePublicLinkTitle = 'Public Link';
  static const String shareCreateLinkAction = 'Create Link';
  static const String shareRevokeLinkAction = 'Revoke Link';
  static const String shareCopyLinkAction = 'Copy link';
  static const String shareLinkCopied = 'Link copied';
  static const String shareLoadingLink = 'Checking public link…';
  static const String shareLoadLinkFailed = 'Unable to load the public link. Please try again.';
  static const String shareCreateLinkFailed = 'Unable to create the public link. Please try again.';
  static const String shareRevokeLinkFailed = 'Unable to revoke the public link. Please try again.';
  static const String shareCopyLinkFailed = 'Unable to copy the link. Please try again.';
  static const String shareSeatProfileContent = 'this seat profile';
  static const String sharePaygradesContent = 'these paygrades';
  static const String shareLessonsContent = 'these lessons';
  static const String shareLessonsTitle = 'Share Lessons';
  static const String shareLessonsDescription =
      'Choose which modules anyone with the public link can view.';
  static const String shareLessonsSelectAll = 'Select all';
  static const String shareLessonsSelectAtLeastOne = 'Select at least one lesson to create a link.';
  static String shareLessonsSelectedCount(int selected, int total) =>
      '$selected of $total selected';
  static String sharePublicLinkDescription(String contentLabel) =>
      'Anyone with this link can view $contentLabel. '
      'Editing controls and internal organization data are never shared.';
  static String shareCreateLinkDescription(String contentLabel) =>
      'Create a public link so anyone can view $contentLabel. '
      'Editing controls and internal organization data are never shared.';
  static const String seatProfileCreateTitle = 'Create Seat Profile';
  static const String seatProfileEditTitle = 'Edit Seat Profile';
  static const String seatProfileCreateAction = 'Create';
  static const String seatProfileEditAction = 'Edit';
  static const String seatProfileSaveAction = 'Save';
  static const String seatProfileUpdateAction = 'Update';
  static const String seatProfileCreatedAction = 'Done';
  static const String seatProfileCreateAccessDenied =
      'You are not allowed to create or edit seat profiles here.';
  static const String seatProfileAddDescriptionAction = 'Add Description';
  static const String seatProfileAddSeatDescriptionAction = 'Add Seat Description';
  static const String seatProfileGenerateDescriptionWithAiAction = 'Generate Description with AI';
  static const String seatProfileUpdateCategoryAction = 'Update Category';
  static const String seatProfileAddOrUpdateSeatCategoryAction = 'Add Or Update Seat Category';
  static const String seatProfileGenerateWithAiAction = 'Generate with AI';
  static const String seatProfileGenerateAction = 'Generate';
  static const String seatProfileRegenerateAction = 'Re-Generate';
  static const String seatProfileGenerateSeatContentDialogTitle = 'Generate Seat Content';
  static const String seatProfileGenerateSeatContentDialogDescription =
      'Choose specificity and tone for the generated categories and descriptions.';
  static const String seatProfileGenerateSeatContentWarningTitle = 'Warning';
  static const String seatProfileGenerateSeatContentWarningSubtitle =
      'Regenerating can replace existing AI generated details.';
  static const String seatProfileGenerateSeatContentWarningDetails =
      'This action affects Check-ins, LTC, and Training Modules.\n\nExisting categories and descriptions will be permanently replaced with newly generated content.';
  static const String seatProfileGenerateSeatContentWarningInstruction =
      'Type REGENERATE to confirm and enable Re-Generate.';
  static const String seatProfileGenerateSeatContentWarningHint = 'REGENERATE';
  static const String seatProfileGenerateSeatContentWarningKeyword = 'REGENERATE';
  static const String seatProfileSpecificityLabel = 'Specificity';
  static const String seatProfileToneLabel = 'Tone';
  static const String seatProfileAiLow = 'Low';
  static const String seatProfileAiMedium = 'Medium';
  static const String seatProfileAiHigh = 'High';
  static const String seatProfileAiLayman = 'Layman';
  static const String seatProfileAiProfessional = 'Professional';
  static const String seatProfileAiTechnical = 'Technical';
  static const String seatProfileManageCategoriesDialogTitle = 'Manage Seat Categories';
  static const String seatProfileManageCategoriesSectionTitle = 'Category Name & Importance';
  static const String seatProfileManageCategoriesDescription =
      'To start enter the category name and weight of that category. Categories reaching 100% means maximum limit';
  static const String seatProfileLoadedDescriptionsSubtitle =
      'Selected category descriptions are shown below.';
  static const String seatProfileCategoryImportanceRemaining = 'Category Importance Remaining';
  static const String seatProfileCategoryImportanceReached = 'Category Importance Reached';
  static const String seatProfileCategoryImportanceExceeded = 'Category Importance Exceeded';
  static const String seatProfileCategoryNameColumn = 'Category Name';
  static const String seatProfileDescriptionNameColumn = 'Description Name';
  static const String seatProfileImportancePercentColumn = 'Importance %';
  static const String seatProfileAddSeatCategoryAction = 'Add Seat Category';
  static const String seatProfileCategoriesTotalLabel = 'Total';
  static const String seatProfileCategoryValidationNote =
      'Category name: max 3 words and 25 characters. Total importance is validated on save.';
  static const String seatProfileSeatAdditionDialogTitle = 'Add Seat Description';
  static const String seatProfileSeatAdditionDialogDescription =
      'Enter a seat description name for this category.';
  static const String seatProfileSeatDescriptionNameLabel = 'Seat Description Name';
  static const String seatProfileSeatDescriptionNameHint = 'Enter seat description name';
  static const String seatProfileSeatDescriptionValidationNote =
      'Seat description name can be up to 7 words.';
  static const String seatProfileEditDescriptionDialogTitle = 'Update Seat Description';
  static const String seatProfileEditDescriptionDialogDescription =
      'Review and update the selected description details.';
  static const String seatProfileCreateDescriptionSheetDescription =
      'Enter and save the details for this seat description.';
  static const String seatProfileSeatDescriptionNameRequired =
      'Please enter the seat description name.';
  static const String seatProfileSeatDescriptionNameWordLimit =
      'Seat description name must be 7 words or fewer.';
  static const String seatProfileAuditSpecificsHint = 'Enter audit specifics';
  static const String seatProfileCheckInType = 'Check-in Type';
  static const String seatProfileCheckInObservation = 'Observation';
  static const String seatProfileCheckInExamination = 'Examination';
  static const String seatProfileCheckInAdministrative = 'Administrative';
  static const String seatProfileCheckInInterview = 'Interview';
  static const String seatProfileCheckInSurvey = 'Survey';
  static const String seatProfileCheckInNoCheckIn = 'No Check-In Found';
  static const String noCheckIn = 'No Check-In';
  static const String noCheckInDetailFound = 'No Check-In Details Found';
  static const String seatProfileNoneOption = 'None';
  static const String seatProfileCategoriesSaveConfirmationTitle = 'Save Categories?';
  static const String seatProfileCategoriesSaveConfirmationDescription =
      'Total importance is not 100%. Do you still want to save these categories?';
  static const String seatProfileCategoryNameRequired = 'Please enter the category name.';
  static const String seatProfileCategoryNameWordLimit = 'Category name must be 3 words or fewer.';
  static const String seatProfileCategoryNameCharacterLimit =
      'Category name must be 25 characters or fewer.';
  static const String seatProfileDeleteDescriptionTitle = 'Delete Seat Description';
  static const String seatProfileDeleteDescriptionAction = 'Delete';
  static String seatProfileDeleteDescriptionDescription(String descriptionName) =>
      'Delete "$descriptionName"? This action cannot be undone.';
  static const String seatProfileCategoryImportanceRequired =
      'Please enter the category importance.';
  static const String seatProfileCategoryImportanceInvalid =
      'Please enter a valid importance percentage.';
  static const String seatProfileCategoryImportanceTotalExceeded =
      'Total category importance cannot be more than 100%.';
  static const String seatProfileCategoriesLoadFailed = 'Unable to load seat categories right now.';
  static const String paygradesTitle = 'Paygrades';
  static const String paygradesDetailsTitle = 'Paygrade Details';
  static const String paygradesAvailableYes = 'Yes';
  static const String paygradesAvailableNo = 'No';
  static const String sharedPaygradesUnableToLoad = 'Unable to load these shared paygrades.';
  static String paygradesRateForUnit(String unit) =>
      unit.trim().isEmpty ? 'Pay Rate' : 'Pay Rate (${unit.trim().toUpperCase()})';
  static const String paygradesSearchHint = 'Search Paygrades';
  static const String paygradesNoItemsFound = 'No paygrades found.';
  static const String paygradesNoDetailItemsFound = 'No paygrades found for this tab.';
  static const String paygradesDepartment = 'Department';
  static const String paygradesUnit = 'Unit';
  static const String paygradesRate = 'Pay Rate (HR)';
  static String paygradesHourlyRate(String value) =>
      '${value.trim().isEmpty ? paygradesUnavailableDisplay : value.trim()}/hr';
  static const String paygradesPayRateInputLabel = 'Enter Payrate / hr';
  static const String paygradesPayRateInvalid = 'Enter a valid, non-negative pay rate.';
  static const String paygradesPayRateSaveFailed = 'Unable to save the pay rate. Please try again.';
  static const String paygradesUnavailableDisplay = '..';
  static const String paygradesLevel = 'Level';
  static const String paygradesDescription = 'Paygrade Specifics';
  static const String paygradesPromotionRequirement = 'Promotion Requirements';
  static const String paygradesEmptyDescription = 'No paygrade specifics available.';
  static const String paygradesEmptyPromotionRequirement = 'No promotion requirements available.';
  static const String paygradesPrimaryTab = 'Primary';
  static const String paygradesAncillaryTab = 'Ancillary';
  static const String paygradesPrimaryPaygrade = 'Primary Paygrade';
  static const String paygradesAncillaryPaygrade = 'Ancillary Paygrade';
  static const String paygradesGenerateWithAiAction = 'Re-Generate With AI';
  static const String paygradesGenerateWithAiSubtitle =
      'Choose how many paygrades AI should generate.';
  static const String paygradesGenerateSheetTitle = 'Re-Generate Paygrades With AI';
  static const String paygradesGenerateSheetDescription =
      'Choose how many paygrades should be generated for this seat.';
  static const String paygradesGenerateCountLabel = 'Number of Paygrades';
  static const String paygradesGenerateCountNote =
      'Maximum 7 paygrades can be generated at a time.';
  static const String paygradesGenerateDisclaimerTitle = 'Disclaimer';
  static const String paygradesGenerateDisclaimerSubtitle =
      'Regenerating can replace the current paygrade list.';
  static const String paygradesGenerateDisclaimerDetails =
      'AI will generate a new paygrade list for this seat. Existing paygrade details may be replaced.';
  static const String paygradesGenerateDisclaimerInstruction =
      'Type REGENERATE to confirm and enable Re-Generate.';
  static const String paygradesGenerateDisclaimerHint = 'REGENERATE';
  static const String paygradesGenerateDisclaimerKeyword = 'REGENERATE';
  static const String paygradesRegenerateAction = 'Re-Generate';
  static const String paygradesCreateSheetTitle = 'Add Paygrade Level';
  static const String paygradesCreateSheetDescription =
      'Enter the details for the new paygrade level.';
  static const String paygradesEditSheetTitle = 'Update Paygrade';
  static const String paygradesEditSheetDescription =
      'Review and update the selected paygrade details.';
  static const String paygradesEditAction = 'Edit';
  static const String paygradesShowMoreAction = 'Show More';
  static const String paygradesShowLessAction = 'Show Less';
  static const String paygradesNameLabel = 'Name';
  static const String paygradesNameHint = 'Enter paygrade name';
  static const String paygradesDescriptionHint = 'Enter paygrade specifics';
  static const String paygradesPromotionRequirementHint = 'Enter promotion requirements';
  static const String paygradesNameRequired = 'Please enter the paygrade name.';
  static const String paygradesCreateSuccess = 'Paygrade level created successfully.';
  static const String paygradesUpdateSuccess = 'Paygrade updated successfully.';
  static const String paygradesDeleteTitle = 'Delete Paygrade';
  static const String paygradesDeleteAction = 'Delete';
  static const String paygradesDeleteSuccess = 'Paygrade deleted successfully.';
  static const String paygradesAddLevelAction = 'Add Paygrade Level';
  static const String paygradesAddLevelUnavailable =
      'Add Paygrade Level needs a create API before it can be completed.';
  static String paygradesDeleteDescription(String paygradeTitle) =>
      'Delete "$paygradeTitle"? This action cannot be undone.';
  static const String departmentsTitle = 'Departments';
  static const String departmentsSearchHint = 'Search Departments';
  static const String departmentsNoItemsFound = 'No departments found.';
  static const String departmentsNoSearchResults = 'No departments match this search.';
  static const String departmentsEditTitle = 'Edit Department';
  static const String departmentsEditDescription = 'Update the department name and color.';
  static const String departmentsNameLabel = 'Department Name';
  static const String departmentsNameHint = 'Enter department name';
  static const String departmentsColorLabel = 'Department Color';
  static const String departmentsColorHexLabel = 'Color Hex';
  static const String departmentsSelectedColor = 'Selected Color';
  static const String departmentsNameRequired = 'Please enter the department name.';
  static const String departmentsColorInvalid = 'Please enter a valid hex color like #A67DFF.';
  static const String departmentsUpdateSuccess = 'Department updated successfully.';
  static const String departmentsRetryAction = 'Retry';
  static const String organizationsTitle = 'Organisations';
  static const String organizationsNoItemsFound = 'No organizations found.';
  static const String organizationsCurrentLabel = 'Current Organisation';
  static const String organizationsFetching = 'Fetching...';
  static const String organizationsChangeAction = 'Change';
  static const String organizationsNoActiveOrganization = 'No active organisation';
  static const String organizationsSandboxNote =
      'Available organisations are being listed here. Please set active organisation from the given list';
  static const String organizationsBannerText =
      'Click Here to set active organisation on the system';
  static const String organizationConflictChangedMessage =
      'Someone has changed Active Organisation';

  static const String billingBannerText = 'Payment is required to keep using paid features';
  static const String paidFeaturesUnavailable = 'Paid Features Unavailable';
  static const String yourSubscriptionEnded =
      'Your organization\'s trial or subscription has ended. Upgrade your plan to create, edit, or delete content.';
  static const String upgradePlanButton = 'OK';
  static const String seatProfileDetailsTitle = 'Seat Profile Details';
  static const String seatProfileDescriptionsTitle = 'Descriptions List';
  static const String seatProfileExpandDescriptionAction = 'Expand Description';
  static const String seatProfileCollapseDescriptionAction = 'Collapse Description';
  static const String seatProfileShowMoreAction = 'Show More';
  static const String seatProfileShowLessAction = 'Show Less';
  static const String seatProfileSearchHint = 'Search Seat Profile';
  static const String seatProfileNameLabel = 'Seat Profile Name';
  static const String seatProfileNameHint = 'Enter seat profile name';
  static const String seatProfileSelectDepartmentHint = 'Select Department';
  static const String seatProfileSelectPaygradeHint = 'Select Paygrade';
  static const String seatProfilePaygradeLabel = 'Paygrade';
  static const String seatProfilePaygradeHourly = 'Hourly';
  static const String seatProfilePaygradeMonthly = 'Monthly';
  static const String seatProfilePaygradeComission = 'Comission';
  static const String seatProfileCreatedSectionTitle = 'Seat Profile Created';
  static const String seatProfileCreatedSuccess = 'Seat profile created successfully.';
  static const String seatProfileDescriptionsCountLong =
      'Number of seat descriptions in the seat profile';
  static const String seatProfileNoDepartmentsAvailable = 'No departments available right now.';
  static const String seatProfileAddDescriptionUnavailable =
      'Add Description flow is not available yet.';
  static const String seatProfileGenerateDescriptionUnavailable =
      'Generate Description with AI is not available yet.';
  static const String seatProfileAddOrUpdateSeatCategoryUnavailable =
      'Seat category flow is not available yet.';
  static const String seatProfileNameRequired = 'Please enter the seat profile name.';
  static const String seatProfileDepartmentRequired = 'Please select a department.';
  static const String seatProfilePrivilegedDepartmentRestricted =
      'Seat profiles cannot be created in the Privileged department.';
  static const String seatProfileDepartmentAccessDenied =
      'You are not allowed to manage seat profiles for this department.';
  static const String seatProfilePaygradeRequired = 'Please select a paygrade.';
  static const String seatProfileNoItemsFound = 'No seat profiles found.';
  static const String seatProfileNoCategoriesFound = 'No categories found.';
  static const String seatProfileNoDescriptionsFound = 'No descriptions found.';
  static const String sharedSeatProfileUnableToLoad = 'Unable to load this shared seat profile.';
  static String seatProfileLoadedDescriptionsForCategory(String categoryTitle) =>
      'Descriptions from $categoryTitle';
  static const String seatProfileFilterTitle = 'Filter';
  static const String seatProfileFilterAll = 'All';
  static const String seatProfileDepartmentsTitle = 'Departments';
  static const String seatProfileFilterPrimaryPaygrade = 'Primary Paygrade';
  static const String seatProfileFilterAncillaryPaygrade = 'Ancillary Paygrade';
  static const String seatProfileCategoriesCount = 'Categories';
  static const String seatProfileDescriptionsCount = 'Descriptions';
  static const String seatProfilePrimaryPaygrade = 'Primary Paygrade';
  static const String seatProfileAncillaryPaygrade = 'Ancillary Paygrade';
  static const String seatProfilePercentageHold = 'Percentage Hold';
  static const String seatProfileMilestoneDays = 'Milestone Days';
  static const String seatProfileAuditSpecifics = 'Audit Specifics';
  static const String seatProfileDescriptionEllipsis = '... ';
  static const String training = 'Training';
  static const String seatProfileViewTrainings = 'View Training';
  static const String seatProfileSetupTrainingTitle = 'Create Training';
  static const String seatProfileNoMatchFound = 'No Match Found';
  static const String seatProfileSelectSeatProfile = 'Select Seat Profile';
  static const String seatProfileSelectCategory = 'Select Category';
  static const String seatProfileSelectDescription = 'Select Description';
  static const String trainingSetupSelectionPrompt = 'Select Seat, Category\nand Description';
  static const String trainingSetupSelectSeat = 'Select Seat';
  static const String trainingSetupSelectCategory = 'Select a category';
  static const String trainingSetupSelectDescription = 'Select a description';
  static const String trainingSetupSelectCategoryTitle = 'Select Category';
  static const String trainingSetupSelectDescriptionTitle = 'Select Description';
  static const String trainingSetupSearchSeat = 'Search Seat';
  static const String trainingSetupSearchCategory = 'Search Category';
  static const String trainingSetupSearchDescription = 'Search Description';
  static const String trainingSetupNoMatches = 'No matches found.';
  static const String seatProfileTrainingNoOptionsAvailable =
      'No training setup options available.';
  static const String kaizenGptTitle = 'KaizenGPT';
  static const String kaizenGptGreeting =
      'Your AI teammate for faster coaching and clearer answers.';
  static const String kaizenGptPromptHint = 'Ask KaizenGPT';
  static const String kaizenGptReady = 'READY';
  static const String howMayIHelpToday = 'How may I help you today?';
  static const String kaizenGptListening = 'Listening...';
  static const String kaizenGptSpeechPermissionTitle = 'Microphone Access';
  static const String kaizenGptSpeechPermissionMessage =
      'Please allow microphone and speech recognition access to use voice input.';
  static const String auditActive = 'Active';
  static const String auditDeactivated = 'Deactivated';
  static const String auditTeamMembersTab = 'Team Members';
  static const String auditAllTeamMembersTab = 'All Team Members';
  static const String auditMyFavoritesTab = 'My Favorites';
  static const String auditSeeMore = 'See More';
  static const String auditNoTeamMembersFound = 'No team members found.';
  static const String auditSearchTeamMembersHint = 'Search team members';
  static const String auditMyCheckInTitle = 'My Check-In';
  static const String auditMyCheckInsTab = 'My Check-Ins';
  static const String auditSearchHint = 'Search Team Member';
  static const String auditOverallScore = 'Overall\nScore';
  static const String auditConfidenceLevel = 'Confidence\nLevel';
  static const String checkInTitle = 'Check-In';
  static const String checkInReadOnlyOrganization =
      'Check-ins are view-only in child organisations.';
  static const String reportsTitle = 'Reports';
  static const String reportsScreenTitle = 'Reports';
  static const String myReportsTitle = 'My Reports';
  static const String certify = 'Certify';
  static const String performanceReportUnavailable =
      'Performance report is not available right now.';
  static const String performanceReportSelectedCategoryTitle = 'Selected Category';
  static const String performanceReportCategoriesTitle = 'Categories';
  static const String performanceReportSelectCategory = 'Select Category';
  static const String performanceReportSelectCategoryDescription =
      'Choose a category to load its descriptions.';
  static const String performanceReportPercentageLabel = 'Percentage:';
  static const String performanceReportNoCategoryDescriptions =
      'No descriptions available for this category.';
  static const String performanceReportCoreValuesTitle = 'Core Values';
  static const String performanceReportCoreValueDetailsFallback = 'No details available yet.';
  static const String performanceReportPaygradePipelineTitle = 'View Paygrade Pipeline';
  static const String sheetPaygradePipelineTitle = 'Paygrade Pipeline';
  static const String performanceReportPaygradePipelineSubtitle =
      'Follow the current grade and the next pay levels in one mobile-friendly timeline.';
  static const String performanceReportPaygradePipelineEmpty = 'Paygrades not created yet.';
  static const String performanceReportPaygradeCurrentGradeLabel = 'Current Position';
  static const String performanceReportPaygradeCurrentPositionValueLabel = 'Current Position:';
  static const String performanceReportPaygradeCurrentPayLabel = 'Current Pay:';
  static const String performanceReportPaygradeTotalLevelsLabel = 'Total Levels:';
  static const String performanceReportPaygradeLevelsLabel = 'Levels';
  static const String performanceReportPaygradeTapHint =
      'Tap a stage to review pay rate and advancement requirements.';
  static const String performanceReportPaygradeStatusCurrent = 'Current';
  static const String performanceReportPaygradeStatusAchieved = 'Achieved';
  static const String performanceReportPaygradeStatusNext = 'Next';
  static const String performanceReportPaygradeStatusUpcoming = 'Upcoming';
  static const String performanceReportPaygradeAdvancementRequirementsTitle =
      'Advancement Requirements';
  static const String performanceSnapshotNoReports = 'No profiles available.';
  static const String performanceSnapshotNoMyReports = 'Report not available.';
  static const String performanceSnapshotDataUnavailable = 'Data not available.';
  static const String performanceSnapshotFilterLoading = 'Loading jobs...';
  static const String performanceSnapshotAction = 'Report';
  static const String performanceSnapshotJob = 'Job';
  static const String performanceSnapshotAllJobs = 'All Jobs';
  static const String performanceSnapshotSearchJob = 'Search Job';
  static const String nothingFound = 'Nothing Found!';
  static String auditNoStatusAvailable(String label) => 'No $label available.';
  static const String auditFiltersTitle = 'Filters';
  static const String auditSelectYearQuarter = 'Select Year & Quarter';
  static const String auditYear = 'Year';
  static const String auditQuarter = 'Quarter';
  static const String auditSeatProfile = 'Seat Profile';
  static const String auditApplyFilters = 'Apply Filters';
  static const String auditSearchSeatProfile = 'Search Seat Profile';
  static const List<String> auditMilestoneOptions = <String>['30 Days', '60 Days', '90 Days'];
  static String auditMilestoneCardLabel(String milestone) => '${milestone.split(' ').first} Day';
  static const List<String> auditTimingOptions = <String>[
    'Available',
    'Wait',
    'Overdue',
    'Inprogress',
  ];
  static const List<String> auditTypeOptions = <String>[
    'Examination',
    'Observation',
    'Administrative',
  ];
  static const String complianceLearningTrack = 'Learning Tracks';
  static const String complianceDocument = 'Document';
  static const String complianceSearchHint = 'Search Module';
  static const String complianceDetailTitle = 'Detail';
  static const String complianceTracksTitle = 'Tracks';
  static const String complianceTrainingTitle = 'Training';
  static const String complianceSeatProfileTitle = 'Seat Profile';
  static const String done = 'Done';
  static const String complianceMasteredBasics = "--- You've Mastered The Basics ---";
  static const String complianceNoTracksFound = 'No Learning Tracks Found';
  static const String complianceTrackSearchFailed =
      'Unable to search learning tracks. Please try again.';
  static const String complianceNoDocumentsFound = 'No Documents Found';
  static const String complianceDocumentSearchFailed =
      'Unable to search documents. Please try again.';
  static const String trainingVideoTab = 'Video';
  static const String trainingDocumentTab = 'Document';
  static const String trainingSopTab = 'SOP';
  static const String trainingQuizTab = 'Quiz';
  static const String trainingAssignmentTab = 'Assignment';
  static const String trainingNoAssignmentAvailable = 'No assignment available.';
  static const String trainingCreateAssignment = 'Create Assignment';
  static const String trainingGenerateAssignment = 'Generate Assignment';
  static const String trainingGenerateAssignmentDialogTitle = 'Generate Assignment with AI';
  static const String trainingGenerateAssignmentDialogDescription =
      'AI will create assignment instructions for this training module.';
  static const String trainingGenerateAssignmentAlertDescription =
      'This will replace the existing assignment instructions with AI-generated content.';
  static const String trainingEditAssignment = 'Edit';
  static const String trainingGenerateQuiz = 'Generate Quiz';
  static const String trainingCreateQuiz = 'Create Quiz';
  static const String trainingAddQuestion = 'Add Question';
  static const String trainingAddNewQuestion = 'Add New Question';
  static const String trainingAddQuestionDialogTitle = 'Add Quiz Question';
  static const String trainingAddQuestionDialogDescription =
      'Create a custom quiz question, add answer options, and choose the correct answer.';
  static const String trainingGenerateQuizDialogTitle = 'Generate Quiz with AI';
  static const String trainingGenerateQuizDialogDescription =
      'Use your document and video contents to generate an AI-powered quiz';
  static const String trainingQuizGenerateWithAi = 'Generate with AI';
  static const String trainingQuizNumberOfQuestions = 'Number of questions';
  static const String trainingQuizOptionsPerQuestion = 'Options per question';
  static const String trainingQuizDifficultyLevel = 'Difficulty level';
  static String trainingQuizIncreaseSetting(String label) => 'Increase ${label.toLowerCase()}';
  static String trainingQuizDecreaseSetting(String label) => 'Decrease ${label.toLowerCase()}';
  static const String trainingQuizReplaceExistingQuestions = 'Replace Existing Questions';
  static const String trainingQuizDifficultyEasy = 'Easy';
  static const String trainingQuizDifficultyMedium = 'Medium';
  static const String trainingQuizDifficultyHard = 'Hard';
  static const String trainingQuizEnabled = 'On';
  static const String trainingQuizDisabled = 'Off';
  static const String trainingQuizGeneratedSuccess = 'Quiz generated successfully.';
  static String trainingVideoPositionLabel(int current, int total) => 'Video $current of $total';
  static const String trainingSopGeneratedSuccess = 'SOP generated successfully.';
  static const String trainingCancel = 'Cancel';
  static const String trainingGenerateSop = 'Generate SOP';
  static const String trainingGenerateSopsWithAi = 'Generate SOPs with AI';
  static const String trainingGenerateWithAi = 'Generate With AI';
  static const String trainingCreateSop = 'Create SOP';
  static const String trainingCreateWithAi = 'Generate with AI';
  static const String trainingGenerateSopSubtitle =
      'AI will generate SOP content for this training module.';
  static const String trainingGenerateSopAlertTitle = 'Alert';
  static const String trainingGenerateSopAlertDescription =
      'This action will replace the existing document with the AI generated content.';
  static const String trainingGenerateSopAlertInstruction =
      'Type REGENERATE to confirm and enable Re-Generate.';
  static const String trainingGenerateSopConfirmation = 'REGENERATE';
  static const String trainingRegenerate = 'Re-Generate';
  static const String trainingDeleteOption = 'Delete option';
  static const String trainingDeleteOptionTitle = 'Delete Option';
  static const String trainingDeleteOptionDescription =
      'Are you sure you want to delete this option?';
  static const String trainingDeleteQuestionTitle = 'Delete Question';
  static const String trainingDeleteQuestionAction = 'Delete';
  static const String trainingDeleteQuestionDescription =
      'Delete this question and all of its options? This action cannot be undone.';
  static const String trainingQuestionDeletedSuccess = 'Question deleted successfully.';
  static const String trainingRemoveOption = 'Remove option';
  static const String trainingAddNewLesson = 'Add New Lesson';
  static const String trainingNewLesson = 'New Lesson';
  static const String trainingSelectedLesson = 'Selected Lesson';
  static const String trainingAllLessons = 'All Lessons';
  static const String trainingChooseLesson = 'Choose Lesson';
  static const String trainingAddLessonPrompt = 'Tap Add New Lesson to create a training module.';
  static const String trainingReadOnlyAccessMessage =
      'You can view this training module, but create and edit actions are disabled for this seat profile.';
  static const String trainingDeleteModuleTitle = 'Delete Module';
  static const String trainingDeleteModuleAction = 'Delete';
  static const String trainingModuleDeletedSuccess = 'Module deleted successfully.';
  static const String trainingLessonTitle = 'Lesson Title';
  static const String trainingLessonTitleHint = 'Enter lesson title';
  static const String trainingLessonCreatedSuccess = 'Lesson created successfully.';
  static const String trainingUntitledLesson = 'Untitled Lesson';
  static const String trainingUploadVideo = 'Upload Video';
  static const String trainingUploadingVideo = 'Uploading';
  static const String trainingPreparingVideoUpload = 'Preparing training video';
  static const String trainingFinalizingVideoUpload = 'Finalizing video upload';
  static const String trainingVideoUploadCompletedTitle = 'Training video uploaded';
  static const String trainingVideoUploadFailedTitle = 'Training video upload failed';
  static const String trainingBackgroundUploadContinues = 'You can keep using the app.';
  static const String trainingFinalizingUploadDetail = 'Finalizing Upload...';
  static const String backgroundUploadContinues = 'You can keep using the app.';
  static const String trainingReturnToLessonToAddThumbnail =
      'Return to the lesson to add a thumbnail.';
  static const String trainingVideoUploadAlreadyInProgress =
      'A training video upload is already in progress.';
  static const String trainingModuleVideoUploadAlreadyInProgress =
      'This lesson already has a video upload in progress.';
  static const String trainingFinishingVideoSetup = 'Finishing video setup';
  static const String trainingSelectVideoSource = 'Select Video Source';
  static const String trainingSelectVideoSourceHint =
      'Record a new video or upload one from your library.';
  static const String trainingRecordVideo = 'Shoot Video';
  static const String trainingRecordVideoHint = 'Capture a video to attach to this lesson.';
  static const String trainingOpenGallery = 'Open Gallery';
  static const String trainingRecentVideos = 'Recent Videos';
  static const String trainingNoGalleryVideos =
      'No gallery videos found yet. Use the camera tile to record one.';
  static const String trainingGalleryAccessHint =
      'Allow photo library access to show recent videos here.';
  static const String trainingLimitedGalleryAccessHint =
      'Only the videos you selected are visible. Choose more videos from your device to expand this list.';
  static const String trainingSelectMoreVideos = 'Select More Videos';
  static const String trainingManageGalleryAccess = 'Manage Access';
  static const String trainingUploadVideoHint = 'Choose a video to attach to this lesson.';
  static const String trainingVideoUploadPrompt = 'Click to upload or drag and\ndrop';
  static const String trainingVideoFileFormat = 'File Format: MP4, MOV, H264';
  static const String trainingVideoMaxFileSize = 'Max file size is 80 MB';
  static const String trainingDeleteVideoTitle = 'Delete Video';
  static const String trainingDeleteVideoAction = 'Delete';
  static const String trainingReUploadVideoAction = 'Re-Upload';
  static const String trainingDeleteAndContinueAction = 'Delete & Continue';
  static const String trainingVideoMoreActions = 'Video actions';
  static const String trainingExpandVideoAction = 'Expand video';
  static const String trainingThumbnailAction = 'Thumbnail';
  static const String trainingAddThumbnailTitle = 'Add Video Thumbnail';
  static const String trainingAddThumbnailDescription =
      'Video uploaded successfully. Choose an image from your gallery to use as the thumbnail for this lesson.';
  static const String trainingSelectThumbnailAction = 'Choose Thumbnail';
  static const String trainingSelectThumbnailHint = 'Select an image from gallery';
  static const String trainingSkipThumbnailAction = 'Skip for now';
  static const String trainingVideoUploadedSuccess = 'Video uploaded successfully.';
  static const String trainingVideoDeletedSuccess = 'Video deleted successfully.';
  static const String trainingThumbnailUpdatedSuccess = 'Thumbnail updated successfully.';
  static const String trainingVideoUploadFailed = 'Failed to upload, Try Again!';
  static const String trainingVideoDeleteFailed = 'Unable to delete video right now.';
  static const String trainingThumbnailUploadFailed = 'Unable to update thumbnail right now.';
  static const String trainingVideoUploadsTapToExpand = 'Tap to view all uploads.';
  static const String trainingVideoUploadsTapToCollapse = 'Tap to hide upload details.';
  static String backgroundUploadProgressLabel(int percent) {
    return '$percent% uploaded';
  }

  static String trainingPreparingVideoUploadFor(String lessonName) {
    return 'Preparing $lessonName';
  }

  static String trainingUploadingVideoFor(String lessonName) {
    return 'Uploading On $lessonName';
  }

  static String trainingFinalizingVideoUploadFor(String lessonName) {
    return 'Finalizing $lessonName';
  }

  static String trainingVideoUploadCompletedTitleFor(String lessonName) {
    return 'Uploaded $lessonName';
  }

  static String trainingVideoUploadFailedTitleFor(String lessonName) {
    return 'Upload failed for $lessonName';
  }

  static String trainingVideosUploadingCount(int count) {
    return count == 1 ? '1 video uploading' : '$count videos uploading';
  }

  static String trainingVideoUploadsCount(int count) {
    return count == 1 ? '1 video upload' : '$count video uploads';
  }

  static String backgroundUploadsUploadingCount(int count) {
    return count == 1 ? '1 upload in progress' : '$count uploads in progress';
  }

  static String backgroundUploadsCount(int count) {
    return count == 1 ? '1 upload' : '$count uploads';
  }

  static String backgroundUploadsFailedCount(int count) {
    return '$count Failed';
  }

  static const String trainingProgressLabel = 'Progress';
  static const String trainingTrackModules = 'Track Modules';
  static const String trainingTakeQuiz = 'Take Quiz';
  static const String trainingEditAction = 'Edit Assignment';
  static const String trainingSubmitQuiz = 'Submit Quiz';
  static const String trainingNoModulesAvailable = 'No training modules available.';
  static const String trainingSharedLessonUnavailable = 'Unable to load this shared lesson.';
  static const String sharedLmsUnableToLoad = 'Unable to load this shared LMS.';
  static const String sharedLmsNoLessons = 'No shared lessons available.';
  static const String sharedLmsUntitledLesson = 'Untitled Lesson';
  static const String sharedLmsSeatLabel = 'SEAT';
  static const String sharedLmsCategoryLabel = 'CATEGORY';
  static const String sharedLmsDescriptionLabel = 'DESCRIPTION';
  static const String trainingLibraryTitle = 'LMS';
  static const String trainingLibrarySearchLesson = 'Search Lesson';
  static const String trainingLibrarySelectLesson = 'Select Lesson';
  static const String trainingLibraryNoMatchingLessons = 'No lessons match this search.';
  static const String trainingLibraryLessonActionsHint =
      'Long press for lesson details and available actions';
  static const String trainingLibraryLessonActions = 'Actions';
  static const String trainingLibraryVisibilityPrefix = 'Set to ';
  static const String trainingLibraryEditLessonDescription = 'Edit this Lesson';
  static const String trainingLibraryDeleteLessonDescription = 'Delete this Lesson';
  static const String trainingLibraryDeleteLessonTitle = 'Delete Lesson';
  static const String trainingLibraryAllFilter = 'All';
  static const String trainingLibraryUnableToApplyFilter =
      'Unable to apply this filter. Please try again.';
  static const String trainingLibraryUnableToUpdateVisibility =
      'Unable to update visibility. Please try again.';
  static const String trainingLibraryAllSeats = 'All Seats';
  static const String trainingLibraryFilterTitle = 'Filter Training';
  static const String trainingLibraryAllCategories = 'All Categories';
  static const String trainingLibraryAllDescriptions = 'All Descriptions';
  static String trainingLibraryRemoveFilter(String name) => 'Remove $name filter';
  static const String trainingLibrarySeatFilterPrefix = 'Seat:';
  static const String trainingLibraryCategoryFilterPrefix = 'Category:';
  static const String trainingLibraryDescriptionFilterPrefix = 'Description:';
  static String trainingLibraryFilterTagLabel(String prefix, String name) => '$prefix $name';
  static const String trainingLibraryUnableToLoadSeats = 'Unable to load seats. Please try again.';
  static const String trainingLibraryAllVideoLesson = 'All Video Lesson';
  static const String trainingLibraryAllVisibility = 'All Visibility';
  static const String trainingLibraryRestrictedVisibility = 'Upline Visibility';
  static const String trainingLibraryLessonsSection = 'Training Modules';
  static const String trainingLibraryDepartment = 'Department';
  static const String trainingLibrarySeat = 'Seat';
  static const String trainingLibraryCategory = 'Category';
  static const String trainingLibraryCreate = 'Create';
  static const String trainingCreateAccessDenied =
      'You do not have access to create training modules from this account.';
  static const String trainingLibrarySearchFieldTooltip = 'Choose search field';
  static const String trainingLibrarySearchFieldLabel = 'Search by';
  static const String trainingLibraryNoModulesFound = 'No library modules found.';
  static const String trainingLibraryNoLessonsFound =
      'No training modules found in this library item.';
  static const String trainingLibraryRetry = 'Retry';
  static const String trainingLibraryUnableToLoadMore =
      'Unable to load more lessons. Please retry.';
  static const String trainingLibraryNotAvailable = 'Not available';
  static const String trainingLibraryUntitledModule = 'Untitled Module';
  static const String trainingLibraryShowGrid = 'Show grid';
  static const String trainingLibraryShowList = 'Show list';
  static const String trainingLibraryShowAction = 'Show';
  static const String trainingLibraryVisibilitySheetDescription =
      'Choose who can access this training module.';
  static const String trainingNoVideoAvailable = 'No video available.';
  static const String trainingNoDocumentAvailable = 'No document available.';
  static const String trainingNoSopAvailable = 'No SOP available.';
  static const String trainingNoQuizQuestionsAvailable = 'No quiz questions available.';
  static const String trainingQuestionLabel = 'Question';
  static String trainingQuestionBadge(int number) =>
      '${trainingQuestionLabel.toUpperCase()} ${number.toString().padLeft(2, '0')}';
  static const String trainingQuestionActions = 'Question actions';
  static const String trainingQuestionEditAction = 'Edit';
  static const String trainingEditQuestionTitle = 'Edit Question';
  static const String trainingQuestionEditDescription = 'Edit this question';
  static const String trainingQuestionDeleteDescription = 'Delete this question';
  static const String trainingQuestionEditAnswers = 'Edit Answers';
  static const String trainingQuestionHint = 'Enter the quiz question';
  static const String trainingNewQuestionHint = 'Enter a Question';
  static const String trainingQuestionUploadPicture = 'Upload a Picture';
  static const String trainingQuestionPictureHint = 'PNG, JPG up to 10MB';
  static const String trainingQuestionImageFormatError = 'Choose a PNG or JPG image.';
  static const String trainingQuestionImageSizeError = 'Choose an image up to 10MB.';
  static const String trainingQuestionRemovePicture = 'Remove picture';
  static const String trainingQuestionReplacePicture = 'Replace picture';
  static const String trainingQuestionOptionsPrompt = 'Provide at least two options for the quiz';
  static const String trainingQuestionNoCorrectAnswer = '—';
  static const String trainingQuestionPreviousAnswer = 'Previous correct answer';
  static const String trainingQuestionNextAnswer = 'Next correct answer';
  static const String trainingQuestionOptionsLabel = 'Options';
  static const String trainingQuestionCorrectAnswerLabel = 'Correct Answer';
  static const String trainingQuestionSelectCorrectAnswerHint =
      'Tap the radio circle beside an option to mark it as correct.';
  static const String trainingQuestionAddedSuccess = 'Question added successfully.';
  static const String trainingQuestionSaveAction = 'Save Question';
  static const String trainingQuestionAddOption = 'Add Option';
  static const String trainingQuestionRequired = 'Please enter a question before saving.';
  static const String trainingQuestionMinOptionsRequired = 'Add at least 2 options.';
  static const String trainingQuestionOptionsRequired =
      'Please fill in every option before saving.';
  static const String trainingQuestionCorrectOptionRequired = 'Please select the correct option.';
  static const String trainingViewTranscript = 'View Transcript';
  static const String trainingCc = 'CC';
  static const String trainingExitFullscreen = 'Exit fullscreen';
  static const String trainingHideActiveTranscript = 'Hide active transcript';
  static const String trainingShowActiveTranscript = 'Show active transcript';
  static const String trainingTranscriptTitle = 'Transcript';
  static const String trainingTranscriptSeekFailed =
      'Unable to jump to this part of the video. Please try again.';
  static const String trainingNoTranscriptAvailable = 'No transcript available.';
  static const String trainingNoSummaryAvailable = 'No summary available.';
  static const String trainingNoSummaryAvailableSnackBar = 'No Summary Available';
  static const String trainingModuleDetailsSavedSuccess = 'Training module updated successfully.';
  static const String trainingEditTextSheetDescription =
      'Update the text below and save your changes.';
  static const String trainingSummaryLabel = 'Summary';
  static const String trainingGenerateSummaryAction = 'Generate';
  static const String trainingSummaryHint = noContentAvailable;
  static const String trainingSummarySavedSuccess = 'Summary updated successfully.';
  static const String trainingSaveAction = 'Save';
  static const String trainingSaveChangesAction = 'Save Changes';
  static const String trainingFieldValueRequired = 'Please enter a value before saving.';
  static const String trainingVisibilityLabel = 'Edit Visibility';
  static const String visibilityLabel = 'Visibility';
  static const String trainingVisibilityAllDescription =
      'Learning module access to everyone company-wide (good for full company transparency)';
  static const String trainingVisibilityUplineDescription =
      'Learning module access to only seat functions with this seat profile and their upline leaders (good for protecting sensitive company protocols)';
  static const String trainingSopLabel = 'SOP';
  static const String trainingSopHint = 'Write SOP content for this lesson.';
  static const String trainingSopEditorError = 'Unable to open the SOP editor. Please try again.';
  static const String trainingSopSavedSuccess = 'SOP updated successfully.';
  static const String trainingAssignmentDescriptionLabel = 'Description';
  static const String trainingAssignmentTitleHint = 'Enter assignment title';
  static const String trainingAssignmentDescriptionHint =
      'Write assignment instructions for this lesson.';
  static const String trainingAssignmentTitleRequired =
      'Please enter an assignment title before saving.';
  static const String trainingAssignmentSavedSuccess = 'Assignment updated successfully.';
  static const String trainingFormattingLabel = 'Basic Editing';
  static const String trainingBoldAction = 'Bold';
  static const String trainingItalicAction = 'Italic';
  static const String trainingUnderlineAction = 'Underline';
  static const String trainingBulletListAction = 'Bullet list';
  static const String trainingNumberedListAction = 'Numbered list';
  static const String trainingQuoteAction = 'Quote';
  static const String trainingHeadingAction = 'Heading';
  static const String trainingListItemPlaceholder = 'List item';
  static const String trainingTextPlaceholder = 'Text';
  static String trainingEditFieldTitle(String fieldLabel) => fieldLabel;
  static String trainingLibraryLessonsCount(int count) =>
      '$count ${count == 1 ? 'Lesson' : 'Lessons'}';
  static String trainingLibraryVideosCount(int count) =>
      '$count ${count == 1 ? 'Video' : 'Videos'}';
  static String trainingLibraryMinutesDuration(String duration) => '$duration min';
  static const String trainingLibrarySeatPrefix = 'Seat - ';
  static String trainingLibraryFilterHint(String filterLabel) => 'Filter by $filterLabel';
  static String trainingLessonPosition(int current, int total) => 'Lesson $current of $total';
  static String trainingLessonCounter(int current, int total) =>
      '${current == 1 ? 'Lesson' : 'Lessons'} $current/$total';
  static String trainingLibrarySearchHint(String filterLabel) => 'Search by $filterLabel';
  static String trainingQuestionOptionLabel(int number) => 'Option $number';
  static String trainingQuestionOptionLetter(int index) => String.fromCharCode(65 + index);
  static String trainingQuestionOptionHint(int number) => 'Enter option $number';
  static String trainingQuestionChoiceLabel(int number) => 'Choice $number';
  static String trainingDeleteModuleDescription(String moduleTitle) =>
      'Delete "$moduleTitle"? This action cannot be undone.';
  static String trainingDeleteVideoDescription(String moduleTitle) =>
      'Delete the video from "$moduleTitle"?';
  static String trainingReUploadVideoDescription(String moduleTitle) =>
      'Delete the existing video from "$moduleTitle" and choose a new video to upload?';
  static const String trainingWelcomeQuizTitle = 'Welcome To Quiz';
  static const String trainingPassingScore = 'Passing: above: ';
  static const String start = 'Start';
  static const String resume = 'Resume';
  static const String trainingPauseQuizTitle = 'Pause Quiz?';
  static const String trainingPauseQuizDescription =
      'You are about to close the quiz without submitting. Your progress will be saved and the quiz will be paused. You can resume it later from where you left off.';
  static const String trainingPauseQuizConfirm = 'Pause Quiz';
  static const String trainingPauseQuizCancel = 'Continue Quiz';
  static const String uploadDoc = 'Upload Document';
  static const String uploadDocumentTitle = 'Upload Document';
  static const String complianceCamera = 'Camera';
  static const String complianceCameraDescription = 'Take a photo of your document';
  static const String complianceMediaSelectionFailedTitle = 'Unable to select document';
  static const String complianceSelectImage = 'Select Image';
  static const String complianceSelectImageDescription = 'Choose a PNG, JPG, or JPEG from gallery';
  static const String complianceSelectPdf = 'Select PDF';
  static const String complianceSelectPdfDescription = 'Choose a PDF document from files';
  static const String complianceCameraPermissionRequired =
      'Camera permission is required to photograph your document.';
  static const String complianceCameraOpenError =
      'Unable to open the camera right now. Please try again.';
  static const String compliancePickImageError =
      'Unable to select an image right now. Please try again.';
  static const String compliancePickPdfError =
      'Unable to select a PDF right now. Please try again.';
  static const String rejectionReasonTitle = 'Rejection Reason';
  static const String complianceShowMore = 'Show More';
  static const String complianceRejectionPreviewEllipsis = '… ';
  static const String complianceRejectionReasonOk = 'OK';
  static const String rejectionReasonBody = 'Lorem Ipsum Lorem ipsum Lorem Ipsum Lorem ipsum';
  static const String clickToUploadDocument = 'Click to upload\nDocument';
  static const String uploadFileFormat = 'File Format: JPEG, PNG, JPG, PDF';
  static const String uploadMaxFileSize = 'Max file size is 20 MB';
  static const String enterExpiryDate = 'MMMM DD, YYYY';
  static const String enterExpirationDate = 'Expiration Date';
  static const String expirationDateWithFormat = '$enterExpirationDate ($enterExpiryDate)';
  static const String expiryDateMonthPlaceholder = 'MMMM';
  static const String expiryDateDayPlaceholder = 'DD';
  static const String expiryDateYearPlaceholder = 'YYYY';
  static const String selectExpiryDate = 'Select expiration date';
  static const String expiryDateRequired = 'Please enter an expiration date.';
  static const String expiryDateInvalid = 'Enter a valid date, for example Apr 05, 2027.';
  static const String expiryDateInPast = 'Expiration date must be today or later.';
  static const List<String> expiryDateMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const List<String> expiryDateFullMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const String cancelUpload = 'Cancel Upload';
  static const String submit = 'Submit';
  static const String reUpload = 'Re-Upload';
  static const String next = 'Next';
  static const String backToModules = 'Back To Modules';
  static const String trainingBackToTrackModules = 'Back to Track Modules';
  static const String trainingBackToLearningTrack = 'Back to Learning Track';

  static String welcomeBackUser(String displayName) => 'Welcome back, $displayName!';

  static String welcomeUser(String displayName) => 'Welcome, $displayName!';

  static String commentAsUser(String displayName) {
    final normalizedName = displayName.trim();
    final firstName = normalizedName.isEmpty ? 'You' : normalizedName.split(RegExp(r'\s+')).first;
    return 'Comment as $firstName';
  }

  static String apiRequestFailed(int statusCode) => '$apiRequestFailedPrefix $statusCode';

  static const String cosmeticDentist = "Cosmetic Dentist";
  static const String claraBell = "Clara Bell";
  static const String noProfile = "No Profile";
  static const String lastAudit = "Last Audit";
  static const String checkInLastCheckIn = "Last Check-in";
  static const String like = "Like";
  static const String comments = "Comments";
  static const String addTextComment = "Add Text Comment";
  static const String comment = "Comment";
  static const String writeCommentHint = 'Write a comment...';
  static const String enterComment = "Enter Comment";
  static const String saveComment = "Save Comment";
  static const String unableToLoadComments = "Unable to load comments.";
  static const String noCommentsAvailable = "No comments available.";
  static const String noComment = "No Comment";

  // Statistics Section
  static const String runningOverallPerformance = "Running Overall Performance Score";
  static const String confidenceLevel = "Confidence Level";

  // Audit List Section
  static const String auditEvaluationChart = "Audit Evaluation Chart";
  static const String checkInEvaluationChart = "Check-in Evaluation Chart";
  static const String score = "Score";
  static const String view = "View";
  static const String continueAction = "Continue";

  // Actions
  static const String continueCheckIn = "Continue Check-in";
  static const String newCheckIn = "New Check-in";

  // Date placeholders (if needed for static display)
  static const String defaultDate = "October 1, 25";
  static const String imagePath = "lib/assets/images/";

  static const String selectTeamMember = "Select Team Member";
  static const String profile = "Profile";

  static const String auditDescriptionDetails = 'Description Details';
  static const String auditDescriptionsTitle = 'Descriptions';
  static const String auditDescriptionFilterOptions = 'Filter Options';
  static const String auditDescriptionCategories = 'Categories';
  static const String auditDescriptionMilestones = 'Milestons';
  static const String auditDescriptionTiming = 'Audit Timing';
  static const String auditDescriptionType = 'Audit Type';
  static const String auditDescriptionClearFilters = 'Clear All';
  static const String auditDescriptionShowAuditedOnly = 'Show Audited Only';
  static String auditDescriptionPagePosition(int current, int total) => 'Page $current of $total';
  static const String auditPreviousDescription = 'Previous description';
  static const String auditNextDescription = 'Next description';
  static const String auditNoDescriptionAvailable = 'No description available.';
  static const String auditNoMatchingDescriptions = 'No descriptions match the selected filters.';
  static const String auditSearchDescriptionsHint = 'Search descriptions';
  static const String auditNoMatchingDescriptionSearch = 'No descriptions match your search.';
  static const String auditSeatDescription = 'Seat Description';
  static const String auditSeatSpecifics = 'Seat Specifics';
  static const String auditNoSeatSpecificsAvailable = 'No seat specifics available.';
  static const String auditSelectPassNoPass = 'Select Pass/No Pass';
  static const String auditPass = 'Pass';
  static const String auditNoPass = 'No Pass';
  static const String auditDefault = 'Default';
  static const String auditHideComments = 'Hide comments';
  static const String auditExpandComments = 'Tap here to expand comments';
  static const String auditAddComment = 'Add Comment';
  static const String auditCommentOnly = 'Comment Only';
  static const String auditShowLess = 'Show Less';
  static const String auditSelectMediaType = 'Select Media Type';
  static const String auditPhoto = 'Photo';
  static const String auditVideo = 'Video';
  static const String auditUpload = 'Upload';
  static const String auditScreenRecording = 'Screen Recording';
  static const String auditUnableToLoadDescriptionDetails =
      'Unable to load description details right now.';
  static const String auditUnableToUpdateRating = 'Unable to update rating right now.';
  static const String auditTakePhoto = 'Take a photo';
  static const String auditCapturePhotoComment = 'Capture a photo for this audit comment';
  static const String auditOpenCamera = 'Open Camera';
  static const String auditRecordVideo = 'Record a video';
  static const String auditCaptureVideoComment = 'Capture a video using your camera';
  static const String auditOpenVideoCamera = 'Open Video Camera';
  static const String auditUploadMedia = 'Upload media';
  static const String auditUploadMediaChoice =
      'Choose whether you want to upload a photo or a video';
  static const String auditUploadPhoto = 'Upload Photo';
  static const String auditUploadVideo = 'Upload Video';
  static const String auditMarkupImage = 'Markup';
  static const String auditMarkupImageTitle = 'Markup image';
  static const String auditMarkupImageHint =
      'Mark the image to highlight what matters before saving.';
  static const String auditMarkupDraw = 'Draw';
  static const String auditMarkupCrop = 'Crop';
  static const String auditMarkupUndo = 'Undo';
  static const String auditMarkupClear = 'Clear';
  static const String auditMarkupResetCrop = 'Reset crop';
  static const String auditMarkupCropHint =
      'Drag a corner to resize the crop area, or drag inside the box to move it.';
  static const String auditMarkupImageLoadError = 'Unable to open this image for markup right now.';
  static const String auditMarkupImageSaveError = 'Unable to save the marked image right now.';
  static const String auditScreenRecordingPreview = 'Screen recording preview';
  static const String auditScreenRecordingPreviewHint =
      'Record a screen first, then it will appear here for playback before saving.';
  static const String auditCameraPermissionPhoto = 'Camera permission is required to take a photo.';
  static const String auditPhotoLibraryPermissionImage =
      'Photo library permission is required to upload an image.';
  static const String auditCameraOpenError =
      'Unable to open the camera right now. Please try again.';
  static const String auditPickImageError = 'Unable to pick an image right now. Please try again.';
  static const String auditCameraPermissionVideo =
      'Camera permission is required to record a video.';
  static const String auditPhotoLibraryPermissionVideo =
      'Photo library permission is required to upload a video.';
  static const String auditRecordVideoError =
      'Unable to record a video right now. Please try again.';
  static const String auditPickVideoError = 'Unable to pick a video right now. Please try again.';
  static const String auditMediaUploadFailed = 'Unable to upload audit media right now.';
  static const String auditMediaUploadAlreadyInProgress =
      'This audit item already has a media upload in progress.';
  static const String auditCommentMediaPreparing = 'Preparing comment media';
  static const String auditCommentMediaUploading = 'Uploading comment media';
  static const String auditCommentMediaFinalizing = 'Finalizing comment media';
  static const String auditCommentMediaCompleted = 'Comment media uploaded';
  static const String auditCommentMediaFailed = 'Comment media upload failed';
  static const String auditAttachmentPreparing = 'Preparing audit media';
  static const String auditAttachmentUploading = 'Uploading audit media';
  static const String auditAttachmentFinalizing = 'Finalizing audit media';
  static const String auditAttachmentCompleted = 'Audit media uploaded';
  static const String auditAttachmentFailed = 'Audit media upload failed';
  static const String auditRestoreMediaError =
      'Unable to restore the interrupted media capture. Please try again.';
  static const String auditSaveRecordedVideoPermission =
      'Photo library permission is required to save the recorded video to your gallery.';
  static const String auditSaveRecordedVideoError =
      'The video was captured, but we could not save it to your gallery.';

  static const String auditDelete = 'Delete';
  static const String auditSave = 'Save';
  static const String auditStartRecording = 'Start Recording';
  static const String auditStopRecording = 'Stop Recording';
  static const String auditRecordingNotificationTitle = 'Screen recording';
  static const String auditRecordingNotificationMessage = 'Recording in progress';
  static const String auditStartRecordingError = 'Unable to start screen recording right now.';
  static const String auditNoRecordingReturned = 'Recording finished but no video was returned.';
  static const String auditRecordedVideoMissing = 'Recorded video could not be found.';
  static const String auditStopRecordingError = 'Unable to stop screen recording right now.';
  static const String auditStartScreenRecordingTitle = 'Start screen recording';
  static const String auditRecordingInProgress = 'Recording in progress';
  static const String auditRecordingPrompt =
      'Capture your screen, then save it as a media comment.';
  static const String auditStopPrompt =
      'Tap stop below when you want to finish and review the recording.';

  // Kaizengram Feed & Navigation
  static const String kaizengramTabWeeklyCheckIn = 'Weekly Check-In';
  static const String kaizengramTabLearning = 'Learning';
  static const String kaizengramTabDocument = 'Document';

  // Kaizengram Power List
  static const String kaizengramPowerListTitle = 'Power List';
  static const String kaizengramPowerListSubtitle = 'Insights across compliances and audits';
  static const String kaizengramPowerListContinuedTitle = 'Power List Continued';
  static const String kaizengramPowerListContinuedSubtitle = 'More highlights inside the feed';

  // Kaizengram Power List Entries
  static const String kaizengramLearningCompliancesTitle = 'Learning Compliances';
  static const String kaizengramLearningCompliancesDue = '12 Due This Week';
  static const String kaizengramDocumentCompliancesTitle = 'Document Compliances';
  static const String kaizengramDocumentCompliancesPending = '8 Pending Uploads';
  static const String kaizengramCheckInsTitle = 'Check-ins';
  static const String kaizengramCheckInsActive = '5 Active Check-ins';
  static const String kaizengramCheckInReportsTitle = 'Check-in Reports';
  static const String kaizengramCheckInReportsReady = '3 Ready For Review';
  static const String kaizengramWeeklySocialPostTitle = 'Kaizengram';
  static const String kaizengramWeeklySocialPostSubtitle = 'Weekly Check-In Note';
  static const String kaizengramWeeklySocialAuthorOne = 'Jordan Miles';
  static const String kaizengramWeeklySocialAuthorTwo = 'Alyssa Grant';
  static const String kaizengramWeeklySocialChannelOne = '#weekly-check-in';
  static const String kaizengramWeeklySocialChannelTwo = '#ops-floor';
  static const String kaizengramWeeklySocialTimeOne = '2h';
  static const String kaizengramWeeklySocialTimeTwo = '1 Day';
  static const String kaizengramWeeklySocialPostOne =
      'Weekly check-ins are building strong momentum across teams. Keep turning each observation into one clear next action before the next review window opens.';
  static const String kaizengramWeeklySocialPostTwo =
      'The fastest wins this week came from teams who closed the loop in comments. Capture what changed, who owns it, and what will be rechecked next time.';
  static const String kaizengramComposePrompt = 'What\'s on your mind?';
  static const String kaizengramComposeSubtitle =
      'Share a quick win, follow-up, or proof with your team.';
  static const String kaizengramComposeSheetTitle = 'Write Post';
  static const String kaizengramComposeSheetHint = 'Share a quick update with your team';
  static const String kaizengramComposeButtonPost = 'Post';
  static const String kaizengramComposeButtonCancel = 'Cancel';
  static const String kaizengramComposeTimeLabel = '1m';
  static const String kaizengramComposeSourceTitle = 'Add to Post';
  static const String kaizengramComposeActionImage = 'Image';
  static const String kaizengramComposeActionAttachment = 'Attachment';
  static const String kaizengramComposeActionImageHint = 'Choose an image from your device.';
  static const String kaizengramComposeActionAttachmentHint = 'Choose a PDF file from your device.';

  // Kaizengram Post Actions
  static const String kaizengramButtonComments = 'Comments';
  static const String kaizengramLabelAuditedAt = 'Audited At';
  static const String kaizengramLabelAuditedBy = 'Audited By';
  static const String kaizengramLabelAssignedBy = 'Assigned By';
  static const String kaizengramLabelDueBy = 'Due By';
  static const String kaizengramLabelRatings = 'Ratings';
  static const String kaizengramLabelSeat = 'Seat';
  static const String kaizengramLabelStatus = 'Status';
  static const String kaizengramNotificationsTitle = 'Notifications';
  static const String kaizengramNotificationsToday = 'Today';
  static const String kaizengramNotificationsThisWeek = 'This Week';
  static const String kaizengramNotificationsEarlier = 'Earlier';
  static const String kaizengramNotificationsEmpty = 'No notifications are available yet.';
  static const String kaizengramNotificationsUnableToLoad =
      'Unable to load notifications right now.';
  static const String kaizengramNotificationsActorComplianceDesk = 'Compliance Desk';
  static const String kaizengramNotificationsActorTrainingDesk = 'Training Desk';
  static const String kaizengramNotificationsActorReviewBoard = 'Review Board';
  static const String kaizengramNotificationsActorKaizenQa = 'Kaizen QA';

  // Kaizengram Media & Upload
  static const String kaizengramLabelUploadDoc = 'Upload Doc';
  static const String kaizengramButtonUploadImage = 'Upload Image';
  static const String kaizengramButtonChangeImage = 'Change Image';
  static const String kaizengramMediaFallbackMore = 'more...';
  static const String kaizengramLabelCheckInComments = 'Check-In Comments';
  static const String kaizengramNoImageThreadTitle = 'No Image Follow-Up';
  static const String kaizengramNoImageThreadPlaceholder = 'No image attached to this thread.';

  // Kaizengram Empty & Error States
  static const String kaizengramMessageUnableLoadFeed = 'Unable to load Kaizen feed right now.';
  static const String kaizengramMessageNoFeedItems = 'No feed items are available yet.';

  // Kaizengram Error Messages
  static const String kaizengramErrorCannotAccessCompliance = 'You cannot access this compliance';
  static const String kaizengramErrorRestrictedTitle = 'Restricted';
  static const String kaizengramErrorPickImageFailed = 'Unable to pick image right now';
  static const String kaizengramErrorPickAttachmentFailed = 'Unable to pick file right now';

  // Kaizengram Comments Thread
  static const String kaizengramMessageShowReplies = 'Show replies';
  static const String kaizengramMessageHideReplies = 'Hide replies';

  /// Get the show/hide replies text with count.
  /// Example: "Show replies (5)" or "Hide replies"
  static String kaizengramRepliesToggleText(int count, bool isShowing) {
    return isShowing ? kaizengramMessageHideReplies : '$kaizengramMessageShowReplies ($count)';
  }

  static String kaizengramNotificationAssigned(String title) {
    return 'assigned $title for review.';
  }

  static String kaizengramNotificationCommented(String title) {
    return 'commented on $title.';
  }

  static String kaizengramNotificationDueIn(String title, String dueLabel) {
    return 'flagged $title as due in $dueLabel.';
  }

  static String kaizengramNotificationDueBy(String title, String dueLabel) {
    return 'flagged $title as due $dueLabel.';
  }

  static String kaizengramNotificationMarkedOverdue(String title) {
    return 'marked $title as overdue.';
  }

  static String kaizengramNotificationReviewed(String title, String status) {
    return 'updated $title to $status.';
  }

  static String kaizengramNotificationReadyForFollowUp(String title) {
    return 'marked $title ready for follow-up.';
  }

  static String kaizengramNotificationRequestedUpload(String title) {
    return 'requested an upload for $title.';
  }

  // Groups Strings
  static const String screenTitle = 'Group Posts';
  static const String searchHint = 'Search groups';
  static const String heroTitle = 'Build focused spaces for wins, proof, and follow-up.';
  static const String heroSubtitle =
      'Move recurring conversations out of the feed and into dedicated communities that feel easy to manage.';
  static const String createGroup = 'Create Group';
  static const String discoverGroups = 'Discover';
  static const String manageGroups = 'Manage';
  static const String forYouTab = 'For You';
  static const String yourGroupsTab = 'Your Groups';
  static const String yourActivityTab = 'Your Activity';
  static const String invitesTab = 'Invites';
  static const String summaryInvites = 'Invites';
  static const String summaryManaged = 'Managed';
  static const String summaryJoined = 'Joined';
  static const String sectionYourGroups = 'Your Groups';
  static const String sectionGroupsFeed = 'Group Posts';
  static const String sectionInvites = 'Invites waiting for you';
  static const String sectionRecent = 'Recent from your groups';
  static const String sectionSuggested = 'Suggested for you';
  static const String sectionManaged = 'Groups you manage';
  static const String sectionJoined = 'Groups you joined';
  static const String sectionTopics = 'Browse by topic';
  static const String sectionTrending = 'Trending with Kaizen teams';
  static const String sectionExplore = 'More groups to explore';
  static const String sectionHighlights = 'Highlights this week';
  static const String reviewAction = 'Review';
  static const String joinAction = 'Join';
  static const String joinedAction = 'Joined';
  static const String inviteAction = 'Invite';
  static const String writePostAction = 'Write Post';
  static const String likeAction = 'Like';
  static const String viewGroupAction = 'View Group';
  static const String commentAction = 'Comment';
  static const String seeAllAction = 'See All';
  static const String pinnedLabel = 'Pinned';
  static const String invitedLabel = 'Invite';
  static const String managedLabel = 'You manage this';
  static const String discoverTrendingBadge = 'Trending';
  static const String myGroupsScreenTitle = 'My Groups';
  static const String yourGroupsSubtitle = 'Jump back into the communities you already joined.';
  static const String groupsFeedSubtitle = 'Latest posts from the groups you joined.';
  static const String yourActivitySubtitle = 'Recent updates from the groups you joined.';
  static const String createGroupTileSubtitle = 'Start a new space for your team.';
  static const String yourGroupsEmptySubtitle =
      'Create a group first, then your joined communities will show here.';
  static const String detailAboutHeader = 'Group Info';
  static const String detailPostsHeader = 'Posts';
  static const String detailRulesHeader = 'Keep the group useful';
  static const String detailActivityHeader = 'Recent Activity';
  static const String detailHighlightHeader = 'This week';
  static const String detailPinnedUpdate = 'Pinned update';
  static const String detailMemberShare = 'What members are sharing';
  static const String detailAbout = 'About';
  static const String detailRules = 'Rules';
  static const String detailInvite = 'Invite';
  static const String detailWritePost = 'Write Post';
  static const String detailManage = 'Manage';
  static const String groupManageSheetTitle = 'Manage Group';
  static const String groupManageEditAction = 'Edit Details';
  static const String groupManageInviteAction = 'Invite People';
  static const String groupManagePinAction = 'Pin to My Groups';
  static const String groupManageUnpinAction = 'Remove Pin';
  static const String groupEditSheetTitle = 'Edit Group';
  static const String groupEditSheetSubtitle =
      'Adjust the details members see before they join or post.';
  static const String groupSaveAction = 'Save';
  static const String leaveGroupAction = 'Leave Group';
  static const String leaveGroupConfirmTitle = 'Leave Group?';
  static const String leaveGroupConfirmButton = 'Leave';
  static const String stayGroupAction = 'Stay';
  static const String createSheetTitle = 'Create Group';
  static const String createSheetSubtitle =
      'Start a space for proof, playbooks, coaching, and weekly momentum.';
  static const String groupImageLabel = 'Group Image';
  static const String groupImageHint = 'Choose a picture for this group.';
  static const String groupImageSelectedHint = 'Tap to change the current group image.';
  static const String groupBackgroundImageLabel = 'Background Image';
  static const String groupBackgroundImageHint = 'Choose a background image for group details.';
  static const String groupBackgroundImageSelectedHint =
      'Tap to change the current background image.';
  static const String nameLabel = 'Group Name';
  static const String nameHint = 'Name your group';
  static const String aboutLabel = 'About';
  static const String aboutHint = 'What is this group for?';
  static const String privacyLabel = 'Privacy';
  static const String topicLabel = 'Topic';
  static const String createSubmit = 'Create';
  static const String createCancel = 'Cancel';
  static const String emptySearchTitle = 'No groups matched your search.';
  static const String emptySearchSubtitle = 'Try another topic or clear the current search.';
  static const String clearSearch = 'Clear Search';
  static const String createPromptMessage =
      'Create your first group and keep recurring conversations in one place.';
  static const String createSuccessPrefix = 'Group created:';
  static const String commentsSheetTitle = 'Comments';
  static const String commentInputHint = 'Write a comment';
  static const String postCommentAction = 'Post';
  static const String commentsEmptyTitle = 'No comments yet.';
  static const String commentsEmptySubtitle = 'Start the conversation for this group post.';
  static const String currentUserCommentName = 'You';
  static const String justNowTimeLabel = 'Just now';
  static const String invitePeopleSheetTitle = 'Add People';
  static const String invitePeopleSearchLabel = 'Email';
  static const String invitePeopleSearchHint = 'Type a name or email';
  static const String invitePeopleSuggestedHeader = 'Suggested People';
  static const String invitePeopleSelectedHeader = 'Selected';
  static const String invitePeopleConfirmAction = 'Invite';
  static const String invitePeopleAddAction = 'Add';
  static const String invitePeopleSelectedLabel = 'Selected';
  static const String invitePeopleAlreadyMemberLabel = 'Already in group';
  static const String invitePeopleExternalRole = 'Email Invite';
  static const String invitePeopleNoResultsTitle = 'No people found.';
  static const String invitePeopleNoResultsSubtitle =
      'Try another teammate name or use a valid email address.';
  static const String invitePeopleEmailInvalid = 'Enter a valid email address.';
  static const String invitePeopleEmptySelection =
      'Select at least one person or enter a valid email.';
  static const String writePostSnackBar = 'Post composer will land here next in the flow.';
  static const String inviteSnackBar = 'Invite flow is ready for the next implementation step.';
  static const String manageSnackBar = 'Group controls can expand from here.';
  static const String commentSnackBar = 'Group post comments can connect here in the next step.';
  static const String likeSnackBar = 'Post likes can connect here next.';
  static const String profileScreenTitle = 'Profile';
  static const String profileGroupHeader = 'Current Group';
  static const String profileRecentPostHeader = 'Latest Group Activity';
  static const String profileContactHeader = 'Contact Details';
  static const String profilePersonalHeader = 'Personal Details';
  static const String profileAboutHeader = 'About';
  static const String profileEmailLabel = 'Email';
  static const String profilePhoneLabel = 'Phone';
  static const String profileDateOfBirthLabel = 'Date of Birth';
  static const String profileGenderLabel = 'Gender';
  static const String profilePrimaryRoleLabel = 'Role';
  static const String profileValueUnavailable = 'Not available';
  static const String profileGenderFemale = 'Female';
  static const String profileGenderMale = 'Male';
  static const String sharedFromKaizengramLabel = 'Shared from Kaizengram';
  static const String secondaryFeedTimeLabel = '1d';
  static const String tertiaryFeedTimeLabel = '2d';
  static const String commentTimeLabelOne = '14m';
  static const String commentTimeLabelTwo = '1h';
  static const String currentGroupMemberName = 'Avery Chen';
  static const String currentGroupMemberRole = 'Community Owner';
  static const String groupMemberRole = 'Community Member';
  static const String frontDeskLeadRole = 'Front Desk Lead';
  static const String auditReviewerRole = 'Audit Reviewer';
  static const String hrBusinessPartnerRole = 'HR Business Partner';

  static const String categoryAll = 'All';
  static const String categoryClinicOps = 'Clinic Ops';
  static const String categoryTraining = 'Training';
  static const String categoryAudit = 'Audit';
  static const String categoryLeadership = 'Leadership';
  static const String categoryPeopleOps = 'People Ops';
  static const String categoryTechnology = 'Technology';

  static const List<String> browseTopics = <String>[
    categoryAll,
    categoryClinicOps,
    categoryTraining,
    categoryAudit,
    categoryLeadership,
    categoryPeopleOps,
    categoryTechnology,
  ];

  static const String privacyPrivate = 'Private';
  static const String privacyPublic = 'Public';

  static const String groupFrontDeskName = 'Front Desk Momentum';
  static const String groupFrontDeskDescription =
      'A shared operating room for callback proof, handoff notes, and service recovery wins across front desk teams.';
  static const String groupTrainingLabName = 'Training Lab Collective';
  static const String groupTrainingLabDescription =
      'A place for trainers to swap lesson upgrades, quiz coaching, and moments that helped a learner close the loop faster.';
  static const String groupAuditWinsName = 'Audit Wins Room';
  static const String groupAuditWinsDescription =
      'A living highlight board for check-in wins, proof photos, and action items that turned into cleaner follow-through.';
  static const String groupPeopleOpsName = 'People Ops Connect';
  static const String groupPeopleOpsDescription =
      'A support group for onboarding touchpoints, policy rollout questions, and people-process improvements.';
  static const String groupDentalAssistName = 'Dental Assist Playbook';
  static const String groupDentalAssistDescription =
      'An everyday playbook for setup standards, room turnover proof, and coaching threads that make shift handoffs easier.';
  static const String groupTechRoundtableName = 'Tech Workflow Roundtable';
  static const String groupTechRoundtableDescription =
      'A space for systems owners to surface blockers, share fixes, and keep workflow changes documented in one thread.';
  static const String groupLeadershipCircleName = 'Leadership Alignment Circle';
  static const String groupLeadershipCircleDescription =
      'A focused room for managers to align follow-up expectations, document leadership asks, and keep priorities visible.';

  static const List<String> sharedRules = <String>[
    'Lead with proof, not assumptions.',
    'Keep every thread tied to one clear action or takeaway.',
    'Close the loop when an owner or due date changes.',
  ];

  static String memberCountLabel(int count) {
    return count == 1 ? '1 member' : '$count members';
  }

  static String reactionCountLabel(int count) {
    return count == 1 ? '1 reaction' : '$count reactions';
  }

  static String commentCountLabel(int count) {
    return count == 1 ? '1 comment' : '$count comments';
  }

  static String weeklyPostsLabel(int count) {
    return count == 1 ? '1 post this week' : '$count posts this week';
  }

  static String newPostsLabel(int count) {
    return count == 1 ? '1 new post' : '$count new posts';
  }

  static String inviteCountLabel(int count) {
    return count == 1 ? '1 invite' : '$count invites';
  }

  static String managedCountLabel(int count) {
    return count == 1 ? '1 managed' : '$count managed';
  }

  static String joinedCountLabel(int count) {
    return count == 1 ? '1 joined' : '$count joined';
  }

  static String privacyMeta(String privacy, String category) {
    return '$privacy • $category';
  }

  static String activityMeta(String location, int weeklyPosts) {
    return '$location • ${weeklyPostsLabel(weeklyPosts)}';
  }

  static String compactGroupMeta(int count, int newPosts) {
    return '$count • ${newPostsLabel(newPosts)}';
  }

  static String authorMeta(String primaryText, String secondaryText) {
    return '$primaryText • $secondaryText';
  }

  static String focusHeadline(String focusArea) {
    return '$focusArea priorities for the week';
  }

  static String focusSummary(String groupName, String focusArea) {
    return '$groupName is keeping ${focusArea.toLowerCase()} updates visible so owners can close the loop without losing context.';
  }

  static String memberShareSummary(String focusArea) {
    return 'Members are sharing proof, quick coaching notes, and follow-up screenshots tied to $focusArea.';
  }

  static String feedAuthor(String category) {
    switch (category) {
      case categoryClinicOps:
        return 'Ava from Operations';
      case categoryTraining:
        return 'Mason from Training';
      case categoryAudit:
        return 'Sana from Audit';
      case categoryLeadership:
        return 'Elena from Leadership';
      case categoryPeopleOps:
        return 'Nora from People Ops';
      case categoryTechnology:
        return 'Kai from Systems';
      default:
        return 'Team Update';
    }
  }

  static String feedAuthorRole(String category) {
    switch (category) {
      case categoryClinicOps:
        return 'Operations Lead';
      case categoryTraining:
        return 'Training Coach';
      case categoryAudit:
        return 'Audit Partner';
      case categoryLeadership:
        return 'Leadership Manager';
      case categoryPeopleOps:
        return 'People Ops Partner';
      case categoryTechnology:
        return 'Systems Owner';
      default:
        return 'Team Member';
    }
  }

  static String secondaryFeedAuthor(String category) {
    switch (category) {
      case categoryClinicOps:
        return 'Noah from Operations';
      case categoryTraining:
        return 'Lina from Training';
      case categoryAudit:
        return 'Omar from Audit';
      case categoryLeadership:
        return 'Mira from Leadership';
      case categoryPeopleOps:
        return 'Priya from People Ops';
      case categoryTechnology:
        return 'Eli from Systems';
      default:
        return 'Team Member';
    }
  }

  static String secondaryFeedAuthorRole(String category) {
    return authorMeta(category, 'Group Member');
  }

  static String tertiaryFeedAuthor(String category) {
    return 'Jordan from $category';
  }

  static String tertiaryFeedAuthorRole(String category) {
    return authorMeta(category, 'Contributor');
  }

  static String feedTimeLabel(int newPostsCount) {
    if (newPostsCount >= 5) {
      return '10m';
    }
    if (newPostsCount >= 3) {
      return '1h';
    }
    if (newPostsCount >= 2) {
      return '5h';
    }
    return '1d';
  }

  static String feedPostBody(String groupName, String category) {
    switch (category) {
      case categoryClinicOps:
        return '$groupName shared a handoff proof update with owners assigned so the next shift can continue without rework.';
      case categoryTraining:
        return 'A coaching recap in $groupName highlighted the drill that improved completion speed and confidence for the team.';
      case categoryAudit:
        return '$groupName posted a quick audit win with photo proof and one clear follow-up item for the next round.';
      case categoryLeadership:
        return 'Managers in $groupName aligned on priorities for the week and documented the owner for each follow-up item.';
      case categoryPeopleOps:
        return '$groupName is tracking onboarding questions in one thread so policy updates and responses stay visible.';
      case categoryTechnology:
        return '$groupName surfaced a workflow blocker, added the fix, and captured the steps so the team can repeat it.';
      default:
        return '$groupName shared a focused update so the team can keep the next action visible.';
    }
  }

  static String secondaryFeedPostBody(String groupName) {
    return 'Members in $groupName shared follow-up proof, quick coaching notes, and the next owner so nothing gets lost.';
  }

  static String tertiaryFeedPostBody(String groupName) {
    return 'This week in $groupName, the team documented one win, one blocker, and the next action to keep momentum visible.';
  }

  static String commentAuthorOne(String category) {
    switch (category) {
      case categoryClinicOps:
        return 'Taylor from Operations';
      case categoryTraining:
        return 'Rhea from Training';
      case categoryAudit:
        return 'Imran from Audit';
      case categoryLeadership:
        return 'Selena from Leadership';
      case categoryPeopleOps:
        return 'Amina from People Ops';
      case categoryTechnology:
        return 'Reid from Systems';
      default:
        return 'Group Member';
    }
  }

  static String commentAuthorTwo(String category) {
    switch (category) {
      case categoryClinicOps:
        return 'Mila from Operations';
      case categoryTraining:
        return 'Zane from Training';
      case categoryAudit:
        return 'Ariel from Audit';
      case categoryLeadership:
        return 'Cam from Leadership';
      case categoryPeopleOps:
        return 'Luca from People Ops';
      case categoryTechnology:
        return 'Jules from Systems';
      default:
        return 'Team Member';
    }
  }

  static String commentMessageOne(String groupName) {
    return 'Love this update from $groupName. The owner callout makes the next step really clear.';
  }

  static String commentMessageTwo(String category) {
    return 'This is a solid $category thread. Let us keep the proof screenshots coming.';
  }

  static String commentsSheetSubtitle(String groupName) {
    return 'Talk through the latest update from $groupName.';
  }

  static String invitePeopleSheetSubtitle(String groupName) {
    return 'Add people to $groupName and keep the conversation moving.';
  }

  static String invitePeopleEmailLabel(String email) {
    return 'Invite $email';
  }

  static String invitePeopleEmailSubtitle(String email) {
    return 'Send an invite to $email.';
  }

  static String invitePeopleSelectedCountLabel(int count) {
    return count == 1 ? '1 person selected' : '$count people selected';
  }

  static String invitePeopleAddedMessage(String groupName, int count) {
    final peopleLabel = count == 1 ? '1 person' : '$count people';
    return 'Invited $peopleLabel to $groupName.';
  }

  static String groupManageSheetSubtitle(String groupName) {
    return 'Update $groupName, invite people, and keep the space organized.';
  }

  static String groupPinnedMessage(String groupName) {
    return 'Pinned $groupName to the top of your groups.';
  }

  static String groupUnpinnedMessage(String groupName) {
    return 'Removed $groupName from your pinned groups.';
  }

  static String groupUpdatedMessage(String groupName) {
    return 'Updated $groupName.';
  }

  static String groupPostSheetSubtitle(String groupName) {
    return 'Share a quick update with $groupName.';
  }

  static String groupPostedMessage(String groupName) {
    return 'Posted to $groupName.';
  }

  static String joinGroupToPostMessage(String groupName) {
    return 'Join $groupName before writing a post.';
  }

  static String leaveGroupDescription(String groupName) {
    return 'Are you sure you want to leave $groupName? You can always join again later.';
  }

  static String leftGroupMessage(String groupName) {
    return 'You left $groupName.';
  }

  static String profileGroupValue(String groupName) {
    return groupName;
  }

  static String profileAboutSummary(String authorName, String groupName, String category) {
    return '$authorName keeps the team aligned by sharing proof, follow-up notes, and quick updates across $category work in $groupName.';
  }

  static String profileRecentPostMeta(String groupName, String timeLabel) {
    return '$groupName • $timeLabel';
  }

  static String profileLatestActivityLabel(String timeLabel) {
    return 'Latest activity $timeLabel';
  }

  static String sharePostToGroupMessage(String groupName) {
    return 'Post shared to $groupName.';
  }

  static String groupCreatedMessage(String name) {
    return '$createSuccessPrefix $name';
  }

  // Chat Strings
  // Chat Labels & Titles
  static const String conversationLabel = 'Conversation';
  static const String channelLabel = 'Channel';
  static const String directMessageLabel = 'Direct Message';
  static const String channelGeneral = 'general';
  static const String channelAnnouncements = 'announcements';
  static const String channelWins = 'wins';
  static const String channelCoaching = 'coaching';
  static const String channelTrainingHub = 'training-hub';
  static const String channelQaReview = 'qa-review';

  static const String menuCreateChannel = 'Create Channel';
  static const String menuOpenChannel = 'Open Channel';
  static const String menuUsers = 'Users';
  static const String menuDeleteChannel = 'Delete Channel';
  static const String chatHomeTitle = 'Talk Zone';
  static const String channelsTitle = 'Channels';
  static const String directMessagesTitle = 'One to One Chat';
  static const String groupsTitle = 'Groups';
  static const String sharePostTitle = 'Send Post';
  static const String sharePostSubtitle =
      'Choose a group, channel, or one-to-one chat for this post.';
  static const String sharePostOriginLabel = 'Shared from Kaizengram';
  static const String sharePostLinkLabel = 'Link';
  static const String sharePostEmptyState = 'Create a channel or one-to-one chat first.';

  // Chat Creation & Discovery
  static const String createChannelTitle = 'Create Channel';
  static const String createChannelSubtitle = 'Set a name for the new Kaizengram channel.';
  static const String createChannelImageLabel = 'Channel Image';
  static const String createChannelImageHint = 'Upload image for channel';
  static const String createChannelImageSelectedHint = 'Tap to change the current channel image';
  static const String startDirectMessageTitle = 'Users';
  static const String startDirectMessageSubtitle =
      'Search and choose a user to begin a one-to-one chat.';
  static const String startDirectMessageSearchLabel = 'People';
  static const String startDirectMessageSearchHint = 'Type name or email';
  static const String startDirectMessageSuggestedHeader = 'Suggested People';
  static const String startDirectMessageEmptyTitle = 'No people found';
  static const String startDirectMessageEmptySubtitle =
      'Try another name or email to start a one-to-one chat.';
  static const String channelNameLabel = 'Channel Name';
  static const String channelNameHint = 'Enter channel name';
  static const String usersTitle = 'Users';
  static const String deleteChannelTitle = 'Delete Channel';
  static const String emptyMessages = 'No messages yet. Start the conversation.';
  static const String noConversationSelected = 'Choose a channel or direct message from the list.';
  static const String noDirectMessages = 'Start a one-to-one chat.';

  // Chat Actions & Attachments
  static const String actionCreate = 'Create';
  static const String actionCancel = 'Cancel';
  static const String actionClose = 'Done';
  static const String actionOpenSettings = 'Open Settings';
  static const String actionRetry = 'Retry';
  static const String actionDelete = 'Delete';
  static const String actionStartChat = 'Start Chat';
  static const String actionReply = 'Reply';
  static const String actionAddImage = 'Add Image';
  static const String actionChangeImage = 'Change Image';
  static const String actionAddVideo = 'Add Video';
  static const String actionRemoveImage = 'Remove Image';
  static const String actionRemoveVideo = 'Remove Video';
  static const String messageHint = 'Send a message';
  static const String addPeopleLabel = 'Add People';
  static const String addPeopleSearchLabel = 'People';
  static const String addPeopleSearchHint = 'Type name or email';
  static const String addPeopleSuggestedHeader = 'Suggested People';
  static const String addPeopleConfirm = 'Add People';
  static const String addPeopleSelectedLabel = 'Selected';
  static const String addPeopleAlreadyInChannelLabel = 'Already Added';
  static const String addPeopleInviteByEmailLabel = 'Invite by Email';
  static const String addPeopleSearchEmptyTitle = 'No people found';
  static const String addPeopleSearchEmptySubtitle =
      'Try another name or email to add someone to this channel.';
  static const String actionRemove = 'Remove';
  static const String selectedImageLabel = 'Selected image';
  static const String selectedVideoLabel = 'Selected video';
  static const String selectedDocumentLabel = 'Selected PDF';
  static const String photoMessageLabel = 'Photo';
  static const String videoMessageLabel = 'Video';
  static const String documentMessageLabel = 'Document';
  static const String mediaMessageLabel = 'Attachments';
  static const String attachmentPickerTitle = 'Choose Attachment';
  static const String attachmentPickerMediaTitle = 'Photos & Videos';
  static const String attachmentPickerMediaSubtitle = 'Pick images or videos from your device.';
  static const String attachmentPickerPdfTitle = 'PDF Document';
  static const String attachmentPickerPdfSubtitle = 'Pick a PDF file from your documents.';

  // Chat Errors & Validation
  static const String emptyChannelNameError = 'Please enter a channel name.';
  static const String duplicateChannelNameError = 'A channel with this name already exists.';
  static const String lastChannelError = 'At least one channel must remain.';
  static const String invalidEmailError = 'Please enter a valid email address.';
  static const String pickImageError = 'Unable to pick image right now.';
  static const String pickChannelImageError = 'Unable to pick channel image right now.';
  static const String pickVideoError = 'Unable to pick video right now.';
  static const String pickMediaError = 'Unable to open the attachment picker right now.';
  static const String mediaLimitError =
      'You can attach up to 3 images, videos, or PDF files in one message.';
  static const String duplicateUserError = 'This user is already in the list.';
  static const String duplicateChannelUserError = 'This user is already in this channel.';
  static const String noActiveChannelError = 'Choose a channel first.';
  static const String cannotRemoveCurrentUserError = 'You cannot remove yourself.';
  static const String addPeopleEmptySelectionError = 'Choose at least one person to add.';
  static const String replyingToLabel = 'Replying to';

  // Chat Seed Users
  static const String userOliviaName = 'Olivia Stone';
  static const String userOliviaEmail = 'olivia.stone@kaizen.app';
  static const String userMarcusName = 'Marcus Lee';
  static const String userMarcusEmail = 'marcus.lee@kaizen.app';
  static const String userNinaName = 'Nina Patel';
  static const String userNinaEmail = 'nina.patel@kaizen.app';
  static const String userChrisName = 'Chris Moore';
  static const String userChrisEmail = 'chris.moore@kaizen.app';
  static const String userAishaName = 'Aisha Khan';
  static const String userAishaEmail = 'aisha.khan@kaizen.app';
  static const String userDanielName = 'Daniel Brooks';
  static const String userDanielEmail = 'daniel.brooks@kaizen.app';
  static const String userFatimaName = 'Fatima Noor';
  static const String userFatimaEmail = 'fatima.noor@kaizen.app';
  static const String userLiamName = 'Liam Carter';
  static const String userLiamEmail = 'liam.carter@kaizen.app';
  static const String userEmmaName = 'Emma Reyes';
  static const String userEmmaEmail = 'emma.reyes@kaizen.app';
  static const String userBotName = 'Kaizen Bot';
  static const String userBotEmail = 'bot@kaizen.app';
  static const String userYouName = 'You';
  static const String userYouEmail = 'you@kaizen.app';

  // Chat Seed Messages
  static const String generalMessageOne =
      'Morning team. Please keep the learning compliance updates in this channel.';
  static const String generalMessageTwo =
      'Seat profile review is done on my side. I have already uploaded the notes.';
  static const String generalMessageThree =
      'Thanks. I will share the document follow-up summary before lunch.';
  static const String generalMessageFour =
      'Perfect. I will pin the final checklist here once the upload is complete.';
  static const String generalMessageFive =
      'Please tag me once the final checklist is posted so I can review it quickly.';
  static const String generalMessageSix =
      'The checklist is ready. I just added the upload notes and due items for this week.';
  static const String generalMessageSeven =
      'Reviewed. The follow-up section looks good, but let us also mention the training deadline.';
  static const String generalMessageEight =
      'Added the training deadline and tagged everyone who still needs to confirm.';
  static const String announcementsMessage =
      'Reminder: tomorrow\'s coaching recap will be posted here for everyone.';
  static const String winsMessage =
      'Big win today. The weekly check-in completion rate crossed 90 percent.';
  static const String coachingMessage =
      'Coaching notes live here. Drop one follow-up action after each session.';
  static const String trainingHubMessage =
      'Training Hub is open for reminders, deadlines, and learning support.';
  static const String qaReviewMessage =
      'QA review updates go here so the next check-in can close the loop faster.';
  static const String directMessageOlivia =
      'Can you review the handoff note when you have a minute?';
  static const String directMessageMarcus =
      'I just sent the checklist update. Let me know if anything still needs to change.';
  static const String directMessageNina =
      'Thanks for closing the loop on the follow-up items today.';

  // Chat Dynamic Strings
  static String deleteChannelDescription(String channelName) {
    return 'Are you sure you want to delete #$channelName?';
  }

  static String createdChannelMessage(String channelName) {
    return '#$channelName is ready. Start the conversation here.';
  }

  static String channelCreatedSnackBar(String channelName) {
    return '#$channelName created.';
  }

  static String channelDeletedSnackBar(String channelName) {
    return '#$channelName deleted.';
  }

  static String directMessageCreatedSnackBar(String name) {
    return 'Direct message with $name ready.';
  }

  static String removeUserTitle(String name) {
    return 'Remove $name';
  }

  static String addPersonTitle(String channelName) {
    return 'Add People to #$channelName';
  }

  static String usersSheetSubtitle(String channelName) {
    return 'Add or remove people in #$channelName.';
  }

  static String addPeopleSheetSubtitle(String channelName) {
    return 'Search by name or email to add people to #$channelName.';
  }

  static String addPeopleSelectedCountLabel(int count) {
    return 'Selected ($count)';
  }

  static String addPeopleEmailInviteSubtitle(String email) {
    return 'Send an invite to $email';
  }

  static String removeUserDescription(String email) {
    return 'Are you sure you want to remove $email from this channel?';
  }

  static String userAddedSnackBar(String email) {
    return '$email added.';
  }

  static String userRemovedSnackBar(String email) {
    return '$email removed.';
  }

  static String usersAddedSnackBar(int count) {
    return count == 1 ? '1 person added.' : '$count people added.';
  }

  static String channelMembersLabel(int count) {
    return count == 1 ? '1 member' : '$count members';
  }

  static String selectedMediaLabel(int count, int maxCount) {
    return 'Selected attachments ($count/$maxCount)';
  }
}
