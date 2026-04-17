This is a top-down vampire survivors like co-op 2D game with the theme "Losing Control", where the gameplay might behave in unexpected ways to make the game harder. Example is, players can throw a pillow item to each other, which might have the effect of either increased health, or they are forced to sleep and require a teammate to defend them. It will have 3 levels with the final being a boss. There is only one weapon (gun) with infinite bullets. The co-op aspect can be done on one keyboard (WASD and arrows).

Player - Veron
- Movement
- Finite States
- Stamina/HP

Gamestate - Veron
-Start
-Win/Lose
-Level change
-Boss trigger event

Items - Veron
-effects
- rng (50/50)

Weapon - Veron
-Gun
-shoot

Spawner - Rahman
-enemies
-items
-hazards (optional)

Sound design - Rahman
-player sound (hurt, steps, attack, damage, etc)
-Ost
-enemies
-items

Sprite - Jordan
- Use open source itch.io sprites
- Send to Justin
- Credit in Readme file

Levels(Tilemap) - Jordan
- Design with tile set
- 2-3 Levels (variation)

UI - Jordan
-options
-pause
-design
-custom fonts
-main menu

Enemies - Justin
-AI movement
-Attack variety (Collision, projectiles)
-Knockback
-flocking/cluster
-other unique gimmicks

Import AnimatedSprite & Animation - Justin
-Player/enemy(idling, walk, attack)
-Attack/Hurt(turn red, death)
-Items idling

new addition log:

- separation of ranged and enemy
- ranged enemy lower hp
- ranged enemy dont move away if player approaches closer to them
- ranged enemy shoot less freq
- ranged enemy have shoot range, not infinite
- player shoot while standing, their last moving toward direction is saved
- enemy_test have longer atk buffer
- projectile slower
