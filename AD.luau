--// Services
local Debris = game:GetService("Debris")

--// Module Definition
local Module = {}

--// Public Variables
Module.DebugMode = true
Module.UseDeathExplosion = true
Module.UseLimbExplosion = false

--// Public Events Registry
Module.Events = {
	OnDamageTaken = Instance.new("BindableEvent"),
	OnPartBroken = Instance.new("BindableEvent"),
	OnBleedingStarted = Instance.new("BindableEvent"),
	OnFatalDamage = Instance.new("BindableEvent")
}

--// Private Variables
local originalStates = {}
local activeBleedings = {}

--// Private Debug Functions
local function DebugLog(msg, isWarning)
	if not Module.DebugMode then return end
	if isWarning then
		warn("[DBG-DMG] " .. msg)
	else
		print("[DBG-DMG] " .. msg)
	end
end

local function DebugVisualSphere(pos, radius)
	if not Module.DebugMode then return end
	local sphere = Instance.new("Part")
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	sphere.Position = pos
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.CastShadow = false
	sphere.Transparency = 0.7
	sphere.Color = Color3.fromRGB(255, 0, 0)
	sphere.Material = Enum.Material.ForceField
	sphere.Parent = workspace
	Debris:AddItem(sphere, 2)
end

local function DebugVisualLine(p1, p2, color)
	if not Module.DebugMode then return end
	local distance = (p2 - p1).Magnitude
	local line = Instance.new("Part")
	line.Size = Vector3.new(0.05, 0.05, distance)
	line.CFrame = CFrame.lookAt(p1, p2) * CFrame.new(0, 0, -distance / 2)
	line.Anchored = true
	line.CanCollide = false
	line.CanQuery = false
	line.Color = color or Color3.fromRGB(255, 255, 0)
	line.Material = Enum.Material.Neon
	line.Parent = workspace
	Debris:AddItem(line, 2)
end

--// Private FX Functions
local function CreateVisualExplosion(position, radius)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = radius or 5
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Visible = true
	explosion.Parent = workspace
end

local function ShatterFolder(folder, originPos, explodeForce)
	for _, part in pairs(folder:GetChildren()) do
		if part:IsA("BasePart") then
			for _, joint in pairs(part:GetJoints()) do
				joint:Destroy()
			end

			local forceDir = (part.Position - originPos).Unit
			local randomSpin = Vector3.new(math.random(-50,50), math.random(-50,50), math.random(-50,50))

			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.Velocity = forceDir * explodeForce + randomSpin
			bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
			bodyVelocity.Parent = part
			Debris:AddItem(bodyVelocity, 0.1)

			local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
			bodyAngularVelocity.AngularVelocity = randomSpin
			bodyAngularVelocity.MaxTorque = Vector3.new(100000, 100000, 100000)
			bodyAngularVelocity.Parent = part
			Debris:AddItem(bodyAngularVelocity, 0.2)
		end
	end
end

--// Private Functions
local function StartBleeding(humanoid, healthFolder, character)
	local maxHealth = healthFolder:GetAttribute("MaxHealth") or 100
	local bleedingLevel = healthFolder:GetAttribute("BleedingLevel") or 1
	local bleedDamagePerSecond = (maxHealth / 10) * bleedingLevel

	DebugLog("Bleeding Start | " .. healthFolder.Name .. " | " .. string.format("%.1f", bleedDamagePerSecond) .. "/s", true)
	Module.Events.OnBleedingStarted:Fire(character, healthFolder.Name, bleedDamagePerSecond)

	if bleedDamagePerSecond > 0 then
		activeBleedings[character] = activeBleedings[character] or {}
		table.insert(activeBleedings[character], task.spawn(function()
			while humanoid and humanoid.Health > 0 do
				humanoid:TakeDamage(bleedDamagePerSecond)
				task.wait(1)
			end
		end))
	end
end

--// Public Functions
function Module.InitCharacter(character)
	originalStates[character] = {}

	for _, folder in pairs(character:GetDescendants()) do
		if folder:IsA("Folder") and folder:GetAttribute("Health") then
			if not folder:GetAttribute("MaxHealth") then
				folder:SetAttribute("MaxHealth", folder:GetAttribute("Health"))
			end

			for _, part in pairs(folder:GetChildren()) do
				if part:IsA("BasePart") then
					originalStates[character][part] = {
						Color = part.Color,
						Material = part.Material
					}
				end
			end
		end
	end

	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		Module.Events.OnFatalDamage:Fire(character)

		if Module.UseDeathExplosion then
			local originPosition = character.PrimaryPart and character.PrimaryPart.Position or character:GetPivot().Position

			-- Optional: Global visual explosion
			CreateVisualExplosion(originPosition, 10)

			-- Shatter EVERY remaining valid folder
			for _, folder in pairs(character:GetDescendants()) do
				if folder:IsA("Folder") and folder:GetAttribute("Health") then
					-- Check if it hasn't already been destroyed by a 0 HP call
					if folder:GetAttribute("Health") > 0 then
						ShatterFolder(folder, originPosition, 50) -- Apply standard force for full body shatter
					end
				end
			end
		end

		Module.CleanUp(character)
	end)

	DebugLog("Init | " .. character.Name)
end

function Module.ApplyAreaDamage(character, impactPosition, baseDamage, armorPenetration, radius, force)
	baseDamage = baseDamage or 10
	armorPenetration = armorPenetration or 1
	radius = radius or 1
	force = force or 0

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	DebugLog(string.format("Hit @ %s | R:%.1f | Dmg:%.1f | Pen:%d", tostring(impactPosition), radius, baseDamage, armorPenetration))
	DebugVisualSphere(impactPosition, radius)

	for _, folder in pairs(character:GetDescendants()) do
		if folder:IsA("Folder") and folder:GetAttribute("Health") then
			local currentHealth = folder:GetAttribute("Health")
			if currentHealth <= 0 then continue end

			local closestDistance = math.huge
			local closestPart = nil

			for _, part in pairs(folder:GetChildren()) do
				if part:IsA("BasePart") then
					local dist = (part.Position - impactPosition).Magnitude
					if dist < closestDistance then
						closestDistance = dist
						closestPart = part
					end
				end
			end

			if closestPart and closestDistance <= radius then
				local distanceMultiplier = 1 - (closestDistance / radius)
				local localizedDamage = baseDamage * distanceMultiplier

				local armorLevel = folder:GetAttribute("ArmorLevel") or 1
				local diff = armorLevel - armorPenetration
				local finalDamage = 0

				if diff >= 2 then
					finalDamage = 0
				elseif diff == 1 then
					finalDamage = localizedDamage / 2
				else
					finalDamage = localizedDamage
				end

				if finalDamage > 0 then
					local newHealth = math.max(0, currentHealth - finalDamage)
					folder:SetAttribute("Health", newHealth)

					local maxHealth = folder:GetAttribute("MaxHealth")
					local healthRatio = newHealth / maxHealth

					DebugLog(string.format("%s | Dist:%.1f | Dmg:%.1f | HP:%.1f/%.1f", folder.Name, closestDistance, finalDamage, newHealth, maxHealth))
					DebugVisualLine(impactPosition, closestPart.Position, Color3.fromRGB(255, 170, 0))

					Module.Events.OnDamageTaken:Fire(character, folder.Name, finalDamage, newHealth)

					local targetColor = Color3.fromRGB(165, 113, 22)

					for _, part in pairs(folder:GetChildren()) do
						if part:IsA("BasePart") then
							local origState = originalStates[character] and originalStates[character][part]
							if origState then
								if newHealth <= 0 then
									part.Color = targetColor
									part.Material = Enum.Material.Neon
								else
									part.Color = origState.Color:Lerp(targetColor, 1 - healthRatio)
									if healthRatio <= 0.3 then
										part.Material = Enum.Material.Neon
									end
								end
							end
						end
					end

					if newHealth <= 0 then
						DebugLog(folder.Name .. " BROKEN", true)
						DebugVisualLine(impactPosition, closestPart.Position, Color3.fromRGB(255, 0, 0))

						Module.Events.OnPartBroken:Fire(character, folder.Name)

						if Module.UseLimbExplosion then
							CreateVisualExplosion(closestPart.Position, 5)
						end

						ShatterFolder(folder, impactPosition, force)

						local isVital = folder:GetAttribute("Vital") or false
						if isVital then
							DebugLog("FATAL | " .. folder.Name, true)
							humanoid.Health = 0
						else
							StartBleeding(humanoid, folder, character)
						end
					end
				else
					DebugLog(string.format("%s | BLOCKED (Armor:%d vs Pen:%d)", folder.Name, armorLevel, armorPenetration))
					DebugVisualLine(impactPosition, closestPart.Position, Color3.fromRGB(150, 150, 150))
				end
			end
		end
	end
end

function Module.CleanUp(character)
	if originalStates[character] then
		originalStates[character] = nil
	end
	if activeBleedings[character] then
		for _, thread in ipairs(activeBleedings[character]) do
			task.cancel(thread)
		end
		activeBleedings[character] = nil
	end
	DebugLog("CleanUp | " .. character.Name)
end

--// Return
return Module