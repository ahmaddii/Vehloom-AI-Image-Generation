import re
import os

def fix_screen(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, 'r') as f:
        content = f.read()

    # Find the main build method of the screen state
    # We look for:
    #   @override
    #   Widget build(BuildContext context) {
    #     return ...
    # And we wrap it in ListenableBuilder
    
    # We only want to wrap the first build method (the screen's build method)
    # not the ones in local widgets.
    
    pattern = r'(@override\s+Widget build\(BuildContext context\) \{\s+return )([a-zA-Z_])'
    
    if "ListenableBuilder(listenable: PreferencesService()" not in content:
        # Check if PreferencesService is imported
        if "import 'package:artsharing/core/services/preferences_service.dart';" not in content and "import '../../core/services/preferences_service.dart';" not in content and "import '../../../core/services/preferences_service.dart';" not in content:
            # add import at top
            content = "import '../../core/services/preferences_service.dart';\n" + content
            
        replacement = r'\1ListenableBuilder(\n      listenable: PreferencesService(),\n      builder: (context, _) => \2'
        
        # We only replace the first occurrence
        content = re.sub(pattern, replacement, content, count=1)
        
        # We need to add a closing parenthesis at the end of the return statement.
        # But wait, it's safer to just do a string replacement for the exact return of Scaffold/AnnotatedRegion
        
    with open(filepath, 'w') as f:
        f.write(content)

fix_screen('lib/features/profile/screens/profile_screen.dart')
fix_screen('lib/features/home/screens/home_feed_screen.dart')
