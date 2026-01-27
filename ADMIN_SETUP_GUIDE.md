# Quick Setup Guide - Character Customization

## Initial Setup (5 minutes)

### 1. Firebase Storage Rules
Add to Firebase Console → Storage → Rules:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /flappy_bird/{allPaths=**} {
      allow read: if true;  // Public read for game assets
      allow write: if request.auth != null;  // Authenticated admin only
    }
  }
}
```

### 2. Access Admin Panel

1. Open app and login with admin credentials
2. Click the **Settings icon** (⚙️) in top-right corner
3. Enter password: `reallygoodpassword`
4. You're now in the Admin Panel!

## Adding Your First Character

### Step 1: Prepare Character Sprite
- Image should be square (recommended: 256x256 or 512x512)
- PNG format with transparency recommended
- Keep file size under 1MB for fast loading

### Step 2: Upload in Admin Panel
1. Scroll to "Add New Character" section
2. Enter character name (e.g., "Speedy Duck")
3. Set **Pipe Speed** (3.0 = normal, 5.0 = faster, 1.5 = slower)
4. Set **Jump Force** (8.0 = normal, 12.0 = higher, 5.0 = lower)
5. Click "Choose Sprite" and select your image
6. Click "Add Character"

### Step 3: Test
1. Go back (press back arrow in app bar)
2. Enter a registration code
3. You should now see your character in the selection grid!

## Setting a Background Image

### Step 1: Prepare Background
- Landscape orientation (recommended: 1920x1080 or 2560x1440)
- JPG or PNG format
- Keep file size under 2MB

### Step 2: Upload in Admin Panel
1. Scroll to "Game Background" section at top
2. Click "Choose File" and select your background image
3. Click "Upload Background"
4. You'll see a preview of the current background

### Step 3: Test
1. Go back and start a game
2. Background should be visible behind game elements!

## Character Stat Guide

### Pipe Speed (Difficulty)
- **1.0 - 2.0:** Easy (slow pipes, good for beginners)
- **2.5 - 3.5:** Medium (balanced gameplay)
- **4.0 - 6.0:** Hard (fast pipes, challenging)
- **6.0+:** Expert (extremely difficult)

### Jump Force (Jump Height)
- **5.0 - 6.0:** Low jump (requires precise timing)
- **7.0 - 9.0:** Normal jump (balanced)
- **10.0 - 12.0:** High jump (easier pipe clearing)
- **12.0+:** Super jump (may feel floaty)

## Recommended Starting Characters

### 1. Easy Character (For Newcomers)
- Name: "Beginner Bird"
- Pipe Speed: 2.0
- Jump Force: 10.0
- Good for first-time players

### 2. Normal Character (Balanced)
- Name: "Classic Flappy"
- Pipe Speed: 3.0
- Jump Force: 8.0
- Standard gameplay experience

### 3. Hard Character (Challenge)
- Name: "Speed Demon"
- Pipe Speed: 5.0
- Jump Force: 7.0
- For experienced players

## Troubleshooting

**Character sprite not showing:**
- Check image file size (should be under 1MB)
- Verify Firebase Storage rules allow authenticated write
- Try PNG format with transparency

**Background not displaying:**
- Check image file size (should be under 2MB)
- Verify image uploaded successfully (check Firebase Console → Storage)
- Try landscape-oriented image

**"No characters added yet" message:**
- Create at least one character in admin panel
- App will show "Classic Bird" default if no characters exist

**Admin panel not accessible:**
- Ensure you're logged in with Firebase admin account
- Settings icon is in top-right of UserHome screen
- Password is case-sensitive: `reallygoodpassword`

## Tips for Best Results

1. **Create 3-5 characters** with varying difficulties
2. **Use descriptive names** that indicate difficulty (e.g., "Easy Eagle", "Hard Hawk")
3. **Test each character** after adding to verify physics feel right
4. **Choose contrasting background** that doesn't hide pipes/bird
5. **Use consistent art style** across all character sprites for cohesive look

## Deleting Characters

1. Open admin panel
2. Scroll to "Existing Characters" section
3. Click red trash icon next to character
4. Confirm deletion in dialog
5. Character is permanently removed

## Changing Admin Password

Edit file: `lib/src/pages/admin_password_gate.dart`

Line 24: Change `_correctPassword` value

```dart
static const String _correctPassword = 'yournewpassword';
```

Then rebuild the app.

## Support

If you encounter issues:
1. Check Firebase Console logs
2. Verify Storage rules are correctly set
3. Ensure admin account has proper permissions
4. Check app logs for error messages
