# Advanced Damage System (AD) for Roblox

**Created by Samtyy** *(Aka Armahan, Prymitif, Durkheim)*

The **Advanced Damage System (AD)** is a highly detailed, localized damage engine for Roblox characters. It introduces limb-based health points, an advanced armor penetration mathematical model, dynamic bleeding states, and procedural visual degradation (heating metal effect) that eventually leads to physical dismemberment.

![AD Preview](https://image.noelshack.com/fichiers/2026/13/3/1774425981-capture-d-cran-2026-03-25-090550.png)

## Key Features

* **Localized Limb Damage:** Damage is calculated based on proximity to a 3D impact point, seamlessly affecting specific limb folders rather than a global health pool.
* **Armor Mathematics:** Features a strict calculation model (`Difference = ArmorLevel - ArmorPenetration`) that dynamically determines if an attack is fully blocked, halved, or deals full damage.
* **Visual Degradation:** Parts dynamically heat up, smoothly interpolating their color toward a glowing orange and transitioning to Neon materials as their health depletes.
* **Dismemberment & Physics:** Broken limbs shatter their joints, trigger purely visual zero-pressure explosions, and apply calculated directional forces and spins to the separated parts.
* **Bleeding System:** Destruction of non-vital limbs initiates a dynamic damage-over-time (bleeding) effect on the core Humanoid, scaleable via attributes.
* **Event Registry:** Exposes public `BindableEvents` (OnDamageTaken, OnPartBroken, OnBleedingStarted, OnFatalDamage) allowing seamless integration with other server scripts.

## Full Documentation

For the complete API reference, Event Registry details, and Folder Attributes (like `Health`, `ArmorLevel`, and `Vital`), please visit the official documentation website:

**[Read the AD Documentation Here](https://armahan.github.io/AD/)**

## Quick Setup

1. Place the **AD ModuleScript** inside `ReplicatedStorage` or `ServerScriptService`.
2. Structure your custom rig so that limbs are grouped within `Folders` (e.g., `Character.Body.LeftArm`).
3. Assign a `Health` attribute (Number) to the specific limb Folders you want to be destructible.
4. Initialize the system and apply damage from a Server Script:

```lua
local AdvancedDamageSystem = require(game.ReplicatedStorage.AD)

-- 1. Initialize the character
AdvancedDamageSystem.InitCharacter(workspace.Rig)

-- 2. Bind the cleanup function to prevent memory leaks
workspace.Rig.Humanoid.Died:Connect(function()
    AdvancedDamageSystem.CleanUp(workspace.Rig)
end)

-- 3. Define impact parameters
local impactPosition = workspace.Rig.Body.LeftArm.LeftLowerArm.Position
local baseDamage = 1500
local armorPenetration = 1
local radius = 3
local force = 50

-- 4. Apply the area damage
task.wait(2)
AdvancedDamageSystem.ApplyAreaDamage(workspace.Rig, impactPosition, baseDamage, armorPenetration, radius, force)
