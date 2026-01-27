# Flappy Bird ACM Activity

A Flappy Bird minigame for the ACM booth following the same code-based registration workflow as the Tech Trivia quiz app.

## Features

- **Code-based Registration**: Users enter a registration code to play
- **Attempts System**: Configurable number of attempts (default: 3)
- **Score Tracking**: Raw pipe count as score with attempt history
- **Admin Authentication**: Persistent Firebase login for booth operators
- **Firestore Integration**: Scores automatically sync with ACM Minigames Admin

## Setup Instructions

### 1. Admin System Setup

In the `coders_cup_minigame_admin` app:

1. Create a new game named exactly **"Flappy Bird"**
2. Set it as "code-based" game
3. Create response documents for each registration code:
   - Path: `games/{gameId}/responses/{CODE}`
   - Initially empty (will be populated when users play)

### 2. Configure Game Settings (Optional)

Create a settings document at `games/{gameId}/settings/flappybird`:

```javascript
{
  maxAttempts: 3,           // Number of attempts per code
  gravity: 0.5,             // Bird fall speed
  pipeSpeed: 3.0,           // Pipe movement speed
  pipeSpawnInterval: 2.0    // Seconds between pipes
}
```

**Defaults** (if no settings document exists):
- `maxAttempts`: 3
- `gravity`: 0.5
- `pipeSpeed`: 3.0
- `pipeSpawnInterval`: 2.0

### 3. Admin Login

Use Firebase email/password authentication:
- Login persists across app restarts
- Same credentials as quiz app admin

## How to Play

1. Admin logs in on booth device
2. User enters their registration code
3. Game validates code and checks attempts remaining
4. User taps to start and taps to flap
5. Score (pipes passed) submitted automatically on game over
6. User can play again if attempts remaining

## Data Structure

### Response Document
Path: `games/{gameId}/responses/{CODE}`

```javascript
{
  // Pre-populated by admin
  userName: "John Doe",
  userEmail: "john@example.com",
  
  // Added by game
  attempts: [
    {
      score: 15,
      timeTakenSeconds: 45,
      timestamp: Timestamp
    },
    // ... up to maxAttempts
  ],
  bestScore: 15,
  lastPlayedAt: Timestamp
}
```

### Settings Document
Path: `games/{gameId}/settings/flappybird`

See configuration section above.

## Game Mechanics

- **Controls**: Tap anywhere to flap/jump
- **Scoring**: +1 point per pipe passed
- **Collision**: Hitting pipes, ground, or ceiling ends game
- **Physics**: Simple gravity + jump velocity
- **Difficulty**: Pipes spawn at random heights with fixed gap

## Development

### Run the app
```bash
cd flappy_bird_acm_activity
flutter run -d chrome  # For web
flutter run            # For mobile/desktop
```

### Project Structure
```
lib/
├── main.dart                      # App entry + routing
├── firebase_options.dart          # Firebase config
└── src/
    ├── models/
    │   ├── game_object.dart       # Bird & Pipe classes
    │   └── game_settings.dart     # Settings model
    └── pages/
        ├── auth_gate.dart         # Admin login
        ├── user_home.dart         # Code entry wrapper
        ├── code_entry_page.dart   # Registration code validation
        └── flappy_game_page.dart  # Game logic & rendering
```

## Integration with Admin Dashboard

Scores automatically appear in the admin dashboard at `coders_cup_minigame_frontend`:
- View all responses with best scores
- Export to CSV
- Display on live scoreboard
- Filter and search by code/name

## Future Enhancements

- Custom sprites/graphics (currently using simple shapes)
- Admin settings UI within game app
- Sound effects
- Difficulty progression
- Leaderboard display in-game

