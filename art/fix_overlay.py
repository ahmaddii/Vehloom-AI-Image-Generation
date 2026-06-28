with open('lib/features/onboarding/screens/onboarding_screen_3.dart', 'r') as f:
    c = f.read()

if "import '../../../core/services/preferences_service.dart';" not in c:
    c = c.replace("import '../../../core/constants/app_colors.dart';", "import '../../../core/constants/app_colors.dart';\nimport '../../../core/services/preferences_service.dart';")

c = c.replace(
    "value: SystemUiOverlayStyle.light,",
    "value: PreferencesService().darkModeEnabled ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,"
)

with open('lib/features/onboarding/screens/onboarding_screen_3.dart', 'w') as f:
    f.write(c)

