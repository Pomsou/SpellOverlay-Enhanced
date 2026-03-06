local addonName = "SpellOverlay Enhanced"
-- Safe Load
local AceAddon = LibStub("AceAddon-3.0", true)
if not AceAddon then return end

local SOE = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

-- Global state for Maelstrom stack tracking to prevent "0 stack" flicker
SOE.LastMaelstromStack = 0

-----------------------------------------------------------------------
-- 1. DATA & CONSTANTS
-----------------------------------------------------------------------
local DUAL_PROCS = {
    ["Hot Streak"] = true, ["Heating Up"] = true, ["Hyperthermia"] = true, ["Fingers of Frost"] = true, ["Clearcasting"] = true, ["Clearcasting (2nd proc)"] = true, ["Clearcasting (3rd proc)"] = true, ["Overpowered Missiles"] = true,
    ["Essence Burst"] = true, ["Killing Machine"] = true, ["Sudden Doom"] = true, ["Crimson Scourge"] = true,
    ["Lava Surge"] = true, ["High Tide"] = true, ["Nightfall"] = true, 
    ["Demonic Core"] = true, ["Surge of Light"] = true, ["Power of the Dark Side"] = true, ["Dark Thoughts"] = true,
    ["Infusion of Light"] = true,
    ["Grand Crusader"] = true, ["Art of War"] = true,
    ["Voidfall"] = true, ["Light Stagger"] = true, ["Moderate Stagger"] = true, ["Heavy Stagger"] = true,
    ["Howl of the Pack Leader"] = true, ["Precise Shot"] = true, ["Precise Shot (2nd proc)"] = true,
    ["Rampage"] = true, ["Tactician"] = true,
}

local LEFT_PROCS = {
    ["Lunar Eclipse"] = true, ["Galactic Guardian"] = true,
    ["Shield Slam"] = true,
    ["Strength of the Black Ox"] = true,
}

local RIGHT_PROCS = {
    ["Solar Eclipse"] = true,
    ["Riposte"] = true,
    ["Blackout Kick!"] = true,
    ["Zen Pulse"] = true,
}

local SUPPRESSED_BY = {
    [270436] = { 270437 }, -- Precise Shots 1 hides if Precise Shots 2 is active
    [1277420] = { 1277421 },
    [1277421] = { 1277422 },
}

local SPELL_GROUPS = {
    [1467] = { ["Essence Burst"] = { 359618, 369297, 369299 } }, 
    [1468] = { ["Essence Burst"] = { 359618, 369297, 369299 }, ["Lifespark"] = { 370960 } }, 
    [1473] = { ["Essence Burst"] = { 359618, 369297, 369299 } }, 
    [63] = { ["Hot Streak"] = { 48108 }, ["Heating Up"] = { 48107 }, ["Pyroclasm"] = { 269651 }, ["Hyperthermia"] = { 449619 } },
    [64] = { ["Brain Freeze"] = { 190446 }, ["Fingers of Frost"] = { 44544 } },
    [62] = { ["Clearcasting"] = { 1277420 }, ["Clearcasting (2nd proc)"] = { 1277421 }, ["Clearcasting (3rd proc)"] = { 1277422 }, ["Overpowered Missiles"] = { 1277009 }, ["Arcane Soul"] = { 451038 } },
    [102] = { ["Lunar Eclipse"] = { 93431 }, ["Solar Eclipse"] = { 93430 } },
    [103] = { ["Clearcasting"] = { 135700 } },
    [104] = { ["Galactic Guardian"] = { 213708 }, ["Gore"] = { 93622 } },
    [105] = { ["Clearcasting"] = { 16870 } },
    [70] = { ["Divine Purpose"] = { 408458 }, ["Art of War"] = { 406086 } },
    [65] = { ["Infusion of Light"] = { 54149 }, ["Divine Purpose"] = { 223819 } },
    [66] = { ["Grand Crusader"] = { 85416 }, ["Divine Purpose"] = { 223819 } },
    [253] = { ["Howl of the Pack Leader"] = { 472324 } },
    [254] = { ["Lock and Load"] = { 194594 }, ["Precise Shot"] = { 270436 }, ["Precise Shot (2nd proc)"] = { 270437 } },
    [255] = { ["Howl of the Pack Leader"] = { 472325 } },
    [251] = { ["Rime"] = { 59052 }, ["Killing Machine"] = { 51124 } },
    [252] = { ["Sudden Doom"] = { 81340 } },
    [250] = { ["Crimson Scourge"] = { 81141 }, ["Dance of Midnight"] = { 1264568 } },
    [260] = { ["Opportunity"] = { 195627 } },
    [72] = { ["Rampage"] = { 209697 } },
    [71] = { ["Tactician"] = { 199864 } },
    [73] = { ["Shield Slam"] = { 224324 }, ["Riposte"] = { 5302 } },
    [258] = { ["Shadowy Insight"] = { 375981 } },
    [256] = { ["Power of the Dark Side"] = { 198069 }, ["Surge of Light"] = { 114255, 128654 } },
    [257] = { ["Surge of Light"] = { 114255 } },
    [262] = { ["Lava Surge"] = { 77762 } },
    [263] = { ["Maelstrom Weapon"] = { 344179 } },
    [264] = { ["High Tide"] = { 157153 } },
    [266] = { ["Demonic Core"] = { 264173 } },
    [265] = { ["Nightfall"] = { 108558 } },
    [1480] = { ["Moment of Craving"] = { 1238488 },["Voidfall"] = { 1253304 } }, 
    [269] = { ["Blackout Kick!"] = { 116768, 439045 }, ["Strength of the Black Ox"] = { 443112 } },
    [270] = { ["Strength of the Black Ox"] = { 443112 }, ["Zen Pulse"] = { 446334 }, ["Harmonic Surge"] = { 1270990 } },
    [268] = { ["Blackout Kick!"] = { 116768, 439045 }, ["Light Stagger"] = { 124275 }, ["Moderate Stagger"] = { 124274 }, ["Heavy Stagger"] = { 124273 } },
}

local ID_TO_GROUP_MAP = {}

local defaults = {
    global = {
        snapshots = {}, 
        uiPos = { width = 550, height = 500, point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    },
    profile = {
        specs = {
            ['*'] = { 
                global = {
                    scale = 1.0, 
                    x = nil, y = nil, x2 = nil, y2 = nil,
                    rotation = 0, rotation2 = 0,
                    mirror = false, mirror2 = false,
                    width = 0, height = 0, width2 = 0, height2 = 0, -- [NEW]
                    alpha = 1.0, alpha2 = 1.0,
                    desaturate = false,
                    blendMode = "BLEND",
                    gradient = "NONE",
                    color = { r = 1, g = 1, b = 1, a = 1 },
                    color2 = { r = 1, g = 1, b = 1, a = 1 },
                    pulseEnabled = false, pulseSpeed = 1.5, pulseMin = 0.3, 
                    borderEnabled = false, borderScale = 1.05, borderAlpha = 1.0,
                    borderColor = { r = 1, g = 0.9, b = 0, a = 1 },
                    borderBlendMode = "ADD",
                },
                spells = {},
            }
        }
    }
}

local DUMMY_CONFIG = {
    scale = 1.0, x = 0, y = 0, x2 = 0, y2 = 0, 
    rotation = 0, rotation2 = 0, 
    mirror = false, mirror2 = false,
    width = 0, height = 0, width2 = 0, height2 = 0, -- [NEW]
    alpha = 1.0, alpha2 = 1.0,
    desaturate = false, gradient = "NONE", blendMode = "BLEND",
    color = { r = 1, g = 1, b = 1, a = 1 },
    color2 = { r = 1, g = 1, b = 1, a = 1 },
    pulseEnabled = false, pulseSpeed = 1.5, pulseMin = 0.3,
    borderEnabled = false, borderScale = 1.05, borderAlpha = 1.0, 
    borderColor = { r = 1, g = 0.9, b = 0, a = 1 },
    borderBlendMode = "ADD"
}

local selectedClassID = nil
local selectedSpecID = nil
local selectedGroupName = nil 

-----------------------------------------------------------------------
-- 2. HELPER FUNCTIONS
-----------------------------------------------------------------------

local function UnpackColor(t, fallbackA)
    if not t then return 1, 1, 1, (fallbackA or 1) end
    return (t.r or 1), (t.g or 1), (t.b or 1), (t.a or fallbackA or 1)
end

function SOE:BuildLookupMap()
    ID_TO_GROUP_MAP = {}
    for specID, groups in pairs(SPELL_GROUPS) do
        ID_TO_GROUP_MAP[specID] = {}
        for groupName, ids in pairs(groups) do
            for _, spellID in ipairs(ids) do
                ID_TO_GROUP_MAP[specID][spellID] = groupName
            end
        end
    end
end

-- TRACK STACKS PERSISTENTLY
function SOE:GetMaelstromStackCount()
    if not C_UnitAuras then return 0 end
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(344179)
    if aura then 
        SOE.LastMaelstromStack = aura.applications or 0
        return SOE.LastMaelstromStack
    end
    return SOE.LastMaelstromStack or 0
end

-- VISUAL FINGERPRINTING: Detect Stage based on Texture Crop Height
function SOE:DetectMaelstromStage(texture)

    if SOE:GetMaelstromStackCount() >= 10 then 
        return "Maelstrom Weapon (Max 10)" 
    end

    if not texture then 

        local s = SOE:GetMaelstromStackCount()
        if s > 0 and s < 5 then return "Maelstrom Weapon (Stage 1-4)" end
        return "Maelstrom Weapon (Stage 5-9)" 
    end
    
    -- Measure the texture crop
    local _, uly, _, lly = texture:GetTexCoord()
    local height = lly - uly
    
    -- "Full" textures usually span 0.0 to 1.0 (height ~1.0)

    if height < 0.90 then 
        return "Maelstrom Weapon (Stage 1-4)" 
    end

    return "Maelstrom Weapon (Stage 5-9)"
end

function SOE:GetGroupKey(spellID, texture)
    local specID = GetSpecializationInfo(GetSpecialization())
    local baseName = nil

    if texture and texture.GetTexture then
        local texID = texture:GetTexture()
        if texID == 1028136 or texID == 1028137 or texID == 1028138 or texID == 1028139 then
            return "Maelstrom Weapon (Stage 1-4)"
        end
    end

    if ID_TO_GROUP_MAP[specID] and ID_TO_GROUP_MAP[specID][spellID] then
        baseName = ID_TO_GROUP_MAP[specID][spellID] 
    else
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name then baseName = info.name end
    end
    
    if not baseName then return spellID end

    -- SPECIAL HANDLING: Maelstrom Weapon (Fallback for 5-10)
    if spellID == 344179 or baseName == "Maelstrom Weapon" then
        return SOE:DetectMaelstromStage(texture)
    end

    return baseName
end

function SOE:GetSpellIDFromKey(key)
    if not selectedSpecID then return nil end
    local cleanKey = key
    if string.find(key, "Maelstrom Weapon") then cleanKey = "Maelstrom Weapon" end
    
    if SPELL_GROUPS[selectedSpecID] and SPELL_GROUPS[selectedSpecID][cleanKey] then
        return SPELL_GROUPS[selectedSpecID][cleanKey][1]
    end
    return nil
end

function SOE:ResolveDefaultsFor(groupName)
    local d = { 
        x = 0, y = 0, x2 = 0, y2 = 0, 
        rotation = 0, rotation2 = 0, mirror = false, mirror2 = false,
        width = 0, height = 0, width2 = 0, height2 = 0
    }
    if not groupName then return d end
    
    -- [1] Hardcoded Categories take priority
    if DUAL_PROCS[groupName] then 
        d.x = -150; d.y = 0; d.x2 = 150; d.y2 = 0 
    elseif LEFT_PROCS[groupName] then
        d.x = -150; d.y = 0
    elseif RIGHT_PROCS[groupName] then
        d.x = 150; d.y = 0
    end

    -- [2] Snapshot fallback for uncategorized spells
    local snap = self.db.global.snapshots[groupName]
    local function AnalyzeShape(s)
        if not s or not s.width or not s.height then return "SQUARE" end
        local ratio = s.width / s.height
        if ratio > 1.3 then return "WIDE" end 
        if ratio < 0.7 then return "TALL" end 
        return "SQUARE"
    end

    if snap and not (DUAL_PROCS[groupName] or LEFT_PROCS[groupName] or RIGHT_PROCS[groupName]) then
        if snap.left then
            local shape = AnalyzeShape(snap.left)
            if shape == "TALL" then d.x = -150; d.y = 0 elseif shape == "WIDE" then d.x = 0; d.y = 120 end
        end
        if snap.right and not snap.left then
            -- Single right-sided proc: map to primary X offset
            local shape = AnalyzeShape(snap.right)
            if shape == "TALL" then d.x = 150; d.y = 0 elseif shape == "WIDE" then d.x = 0; d.y = 120 end
        end
    end
    
    return d
end

function SOE:GetSettingsForActiveOverlay(spellID, overrideGroup, texture)
    local specID = GetSpecializationInfo(GetSpecialization())
    if not self.db.profile.specs then return nil end
    local specDB = self.db.profile.specs[specID]
    if not specDB then return nil end

    local groupName = overrideGroup or SOE:GetGroupKey(spellID, texture)
    
    local settings = specDB.global
    if groupName and specDB.spells and specDB.spells[groupName] then
        settings = specDB.spells[groupName]
    end
    
    local dynDefaults = SOE:ResolveDefaultsFor(groupName)
    local safeSettings = setmetatable({}, {
        __index = function(t, k)
            if settings[k] ~= nil then return settings[k] end
            if dynDefaults[k] ~= nil then return dynDefaults[k] end
            return nil
        end,
        __newindex = function(t, k, v) settings[k] = v end
    })
    return safeSettings
end

-----------------------------------------------------------------------
-- 3. CORE LOGIC
-----------------------------------------------------------------------

function SOE:EnsureHelperExists(overlay)
    if overlay.SOE_Created then return end
    overlay.SOE_Created = true
    
    if not overlay.SOE_Glow then
        overlay.SOE_Glow = overlay:CreateTexture(nil, "BACKGROUND")
        overlay.SOE_Glow:SetBlendMode("ADD")
        overlay.SOE_Glow:SetParent(overlay)
    end
end

function SOE:ApplyToOverlay(overlay)
    if not overlay:IsShown() then 
        if overlay.SOE_Glow then overlay.SOE_Glow:Hide() end
        return 
    end

    if overlay.animOut and overlay.animOut:IsPlaying() then return end

    local mainTexture = overlay.texture
    if not mainTexture then return end

    -- [1] SUPPRESSION SYSTEM (Fixes overlaps for progressive procs)
    if SUPPRESSED_BY then
        local suppressors = SUPPRESSED_BY[overlay.spellID]
        if suppressors and not overlay.IsDummy then
            local isSuppressed = false
            local frame = SpellActivationOverlayFrame
            if frame and frame.overlayPool then
                for o in frame.overlayPool:EnumerateActive() do
                    for _, sID in ipairs(suppressors) do
                        if o.spellID == sID and o:IsShown() and not o.IsDummy then
                            isSuppressed = true
                            break
                        end
                    end
                    if isSuppressed then break end
                end
            end
            
            if isSuppressed then
                mainTexture:SetAlpha(0)
                if overlay.SOE_Glow then overlay.SOE_Glow:Hide() end
                return
            end
        end
    end

    -- [2] DUMMY LOGIC 
    if overlay.IsDummy then
        if overlay.SOE_UseAtlas then
            overlay.texture:SetAtlas(overlay.SOE_UseAtlas)
        elseif overlay.SOE_UseTexture then
            overlay.texture:SetTexture(overlay.SOE_UseTexture)
        elseif overlay.SOE_UseIcon then
            overlay.texture:SetTexture(overlay.SOE_UseIcon)
        end
        
        if overlay.SOE_TexCoords then
            local c = overlay.SOE_TexCoords
            overlay.texture:SetTexCoord(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8])
        else
            overlay.texture:SetTexCoord(0, 1, 0, 1)
        end
    end

    local forcedGroup = overlay.SOE_GroupName
    local currentGroup = forcedGroup or SOE:GetGroupKey(overlay.spellID, mainTexture)
    
    -- Auto-Snapshot (Live Only)
    if not forcedGroup and not overlay.IsDummy and currentGroup then
        if not self.db.global.snapshots[currentGroup] or 
           (not self.db.global.snapshots[currentGroup]["left"] and not self.db.global.snapshots[currentGroup]["right"]) then
             SOE:SnapshotOverlay(overlay)
        end
    end

    local settings = self:GetSettingsForActiveOverlay(overlay.spellID, currentGroup, mainTexture)
    if not settings then return end

    SOE:EnsureHelperExists(overlay)
    local glow = overlay.SOE_Glow

    -- [3] POSITIONAL LOGIC & BASE SIZE

    -- Added a check for overlay.position so recycled frames don't keep hiding or overlapping
    if not overlay.SOE_BaseCoords or overlay.SOE_LastSpellBase ~= overlay.spellID or overlay.SOE_LastPos ~= overlay.position then
        overlay.SOE_BaseCoords = { mainTexture:GetTexCoord() }
        overlay.SOE_LastSpellBase = overlay.spellID
        overlay.SOE_LastPos = overlay.position
    end
    
    local c = overlay.SOE_BaseCoords
    local ULx = c[1] or 0 
    local isRightSide = (overlay.position and string.find(string.lower(overlay.position), "right")) or (ULx and ULx > 0.5)
    
    local groupName = currentGroup 
    local isDualProc = groupName and DUAL_PROCS[groupName]

    local baseW, baseH = 256, 256
    if overlay.IsDummy then
        baseW = overlay.SOE_OrigW or 256
        baseH = overlay.SOE_OrigH or 256
    elseif overlay.SOE_OrigW then
        baseW = overlay.SOE_OrigW
        baseH = overlay.SOE_OrigH
    end

    local mainW, mainH = baseW, baseH
    local offsetX = settings.x or 0
    local offsetY = settings.y or 0
    local targetRotation = settings.rotation or 0
    local targetMirror = settings.mirror or false
    local targetWidth = settings.width or 0
    local targetHeight = settings.height or 0

    if isDualProc and isRightSide then
        offsetX = settings.x2 or 0
        offsetY = settings.y2 or 0
        targetRotation = settings.rotation2 or 0
        targetMirror = settings.mirror2 or false
        targetWidth = settings.width2 or 0
        targetHeight = settings.height2 or 0
    end

    if targetWidth > 0 then mainW = targetWidth end
    if targetHeight > 0 then mainH = targetHeight end

    -- [4] CALCULATE VISUALS & PULSE
    local pulseFactor = 1.0
    if settings.pulseEnabled then
        local speed = settings.pulseSpeed or 1.5
        local min = settings.pulseMin or 0.3
        pulseFactor = min + (1 - min) * (0.5 * (math.sin(GetTime() * speed) + 1))
    end

    local baseAlpha = (isRightSide and isDualProc) and (settings.alpha2 or 1.0) or (settings.alpha or 1.0)
    local finalAlpha = baseAlpha * pulseFactor

    -- [5] APPLY SCALE & POSITION
    local scale = settings.scale or 1.0
    overlay:SetSize(mainW * scale, mainH * scale)
    
    local currentPoint, _, _, currentX, currentY = overlay:GetPoint()
    if not currentPoint or math.abs(currentX - offsetX) > 0.1 or math.abs(currentY - offsetY) > 0.1 then
        overlay:ClearAllPoints()
        overlay:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
    end

    -- [6] APPLY SYMMETRY, COLORS & TEXTURE STYLING
    mainTexture:SetDesaturated(settings.desaturate)
    mainTexture:SetBlendMode(settings.blendMode or "BLEND")
    
    -- Rotation
    mainTexture:SetRotation(math.rad(targetRotation))
    
    -- Mirroring (Swaps the Left X and Right X texture coordinates)
    if targetMirror then
        mainTexture:SetTexCoord(c[5], c[6], c[7], c[8], c[1], c[2], c[3], c[4])
    else
        mainTexture:SetTexCoord(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8])
    end
    
    local r1, g1, b1, a1 = UnpackColor(settings.color)
    local r2, g2, b2, a2 = UnpackColor(settings.color2)

    local combinedAlpha1 = a1 * finalAlpha
    local combinedAlpha2 = a2 * finalAlpha

    if settings.gradient and settings.gradient ~= "NONE" then
        mainTexture:SetGradient(settings.gradient, CreateColor(r1, g1, b1, combinedAlpha1), CreateColor(r2, g2, b2, combinedAlpha2))
    else
        mainTexture:SetVertexColor(r1, g1, b1, combinedAlpha1) 
    end

    -- [7] BORDER / GLOW APPLICATION
    if settings.borderEnabled and glow then
        glow:Show()
        local atlasName = mainTexture:GetAtlas()
        if atlasName then
            glow:SetAtlas(atlasName)
        else
            if mainTexture:GetTexture() then 
                glow:SetTexture(mainTexture:GetTexture()) 
            end
        end
        glow:SetBlendMode(settings.borderBlendMode or "ADD")
        
        -- Sync Glow Symmetry
        glow:SetRotation(math.rad(targetRotation))
        if targetMirror then
            glow:SetTexCoord(c[5], c[6], c[7], c[8], c[1], c[2], c[3], c[4])
        else
            glow:SetTexCoord(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8])
        end
        
        local bScale = settings.borderScale or 1.05
        glow:SetSize(mainW * scale * bScale, mainH * scale * bScale)
        
        glow:ClearAllPoints()
        glow:SetPoint("CENTER", overlay, "CENTER", 0, 0)
        
        local br, bg, bb, ba = UnpackColor(settings.borderColor)
        glow:SetVertexColor(br, bg, bb, ba)
        glow:SetAlpha(finalAlpha * (settings.borderAlpha or 1.0))
    else
        if glow then glow:Hide() end
    end
end

function SOE:RefreshAllOverlays()
    local frame = SpellActivationOverlayFrame
    if frame and frame.overlayPool then
        for overlay in frame.overlayPool:EnumerateActive() do
            SOE:ApplyToOverlay(overlay)
        end
    end
    if SOE.DummyFrame1 and SOE.DummyFrame1:IsShown() then SOE:ApplyToOverlay(SOE.DummyFrame1) end
    if SOE.DummyFrame2 and SOE.DummyFrame2:IsShown() then SOE:ApplyToOverlay(SOE.DummyFrame2) end
end

function SOE:TriggerUpdate(spellID)
    if not spellID then return end
    self:RefreshAllOverlays()
end

function SOE:OnFrameUpdate(elapsed)
    if SOE.IsPreviewActive then
        local ACD = LibStub("AceConfigDialog-3.0")
        local container = ACD.OpenFrames[addonName]
        if not container or not container.frame or not container.frame:IsShown() then
            SOE:HidePreview()
        end
        if SOE.DummyFrame1 and SOE.DummyFrame1:IsShown() then SOE:ApplyToOverlay(SOE.DummyFrame1) end
        if SOE.DummyFrame2 and SOE.DummyFrame2:IsShown() then SOE:ApplyToOverlay(SOE.DummyFrame2) end
    end

    local frame = SpellActivationOverlayFrame
    if frame and frame.overlayPool then
        for overlay in frame.overlayPool:EnumerateActive() do
            if not overlay.IsDummy and overlay:IsShown() then
                SOE:ApplyToOverlay(overlay)
            end
        end
    end
end

function SOE:SnapshotOverlay(overlay)
    if not overlay.spellID then return end
    
    local texPath = nil
    local isAtlas = false
    local atlasName = overlay.texture and overlay.texture:GetAtlas()
    
    if atlasName then
        texPath = atlasName
        isAtlas = true
    else
        texPath = overlay.texture and overlay.texture:GetTexture()
    end

    if not texPath then return end
    
    local group = SOE:GetGroupKey(overlay.spellID, overlay.texture)
    if not group then return end
    
    if not self.db.global.snapshots[group] then self.db.global.snapshots[group] = {} end
    
    -- [FIX] Prevent corrupted snapshot dimensions
    local w = overlay.SOE_OrigW or 256
    local h = overlay.SOE_OrigH or 256
    if w > 1024 then w = 256 end
    if h > 1024 then h = 256 end

    local s = overlay.SOE_OrigScale or 1.0 
    local ulx, uly, llx, lly, urx, ury, lrx, lry = 0,0,0,1,1,0,1,1
    if overlay.texture then
         ulx, uly, llx, lly, urx, ury, lrx, lry = overlay.texture:GetTexCoord()
    end
    
    -- FIXED: Rely on Blizzard's position tag first, fallback to math if missing
    local posStr = overlay.position and string.lower(overlay.position) or ""
    local isRight = string.find(posStr, "right") or (ulx and ulx > 0.4)
    local slot = isRight and "right" or "left"
    
    local exists = self.db.global.snapshots[group][slot]
    
    self.db.global.snapshots[group][slot] = {
        texture = texPath, width = w, height = h, scale = s,
        isAtlas = isAtlas,
        texCoords = { ulx, uly, llx, lly, urx, ury, lrx, lry }
    }
    
    if not exists then
        LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
    end
end

function SOE:HidePreview()
    if SOE.DummyFrame1 then SOE.DummyFrame1:Hide() end
    if SOE.DummyFrame2 then SOE.DummyFrame2:Hide() end
    SOE.IsPreviewActive = false
end

function SOE:PreviewSelected()
    if not selectedSpecID then print("|cff33ff99SOE:|r Select a Spec first.") return end
    
    local snapshots = self.db.global.snapshots[selectedGroupName or "Unknown"]
    
    if selectedGroupName ~= "Maelstrom Weapon (Stage 1-4)" and (not snapshots or (not snapshots.left and not snapshots.right)) then
        print("|cff33ff99SOE:|r No snapshot data for " .. (selectedGroupName or "Unknown"))
        print("|cff33ff99SOE:|r Please trigger the proc in combat first to capture it.")
        return 
    end

    if SOE.IsPreviewActive and SOE.LastPreviewedGroup == selectedGroupName and not SOE.ForceShow then
        SOE:HidePreview()
        print("|cff33ff99SOE:|r Preview Hidden.")
        return
    end

    SOE:HidePreview()
    SOE.IsPreviewActive = true
    SOE.ForceShow = false
    SOE.LastPreviewedGroup = selectedGroupName

    local function SpawnDummy(index, snapshotData)
        local fName = "SOE_PreviewFrame"..index
        local f = _G[fName]
        if not f then
            f = CreateFrame("Frame", fName, SpellActivationOverlayFrame)
            f:SetFrameStrata("DIALOG")
            f.IsDummy = true
            f.texture = f:CreateTexture(nil, "ARTWORK")
            f.texture:SetAllPoints()
            SOE:EnsureHelperExists(f)
            if index == 1 then SOE.DummyFrame1 = f else SOE.DummyFrame2 = f end
        end
        
        f.spellID = SOE:GetSpellIDFromKey(selectedGroupName)
        f.SOE_GroupName = selectedGroupName

        f.SOE_UseAtlas = nil
        f.SOE_UseTexture = nil
        f.SOE_TexCoords = nil
        f.texture:SetTexture(nil)
        f.texture:SetAtlas(nil)
        f.texture:SetTexCoord(0, 1, 0, 1)

        -- FIXED: Explicitly tell ApplyToOverlay which dummy this is so Right-side config options apply
        f.position = (index == 2) and "Right" or "Left"

        if selectedGroupName == "Maelstrom Weapon (Stage 1-4)" then
             f.SOE_UseTexture = 1028139
             
             if snapshotData then
                 f.SOE_OrigW = snapshotData.width
                 f.SOE_OrigH = snapshotData.height
             else
                 f.SOE_OrigW = 256
                 f.SOE_OrigH = 256
             end
             
             f:Show()
             SOE:ApplyToOverlay(f)
             return
        end

        if snapshotData then
            f.SOE_OrigW = snapshotData.width
            f.SOE_OrigH = snapshotData.height
            
            if snapshotData.isAtlas then
                f.SOE_UseAtlas = snapshotData.texture
            else
                f.SOE_UseTexture = snapshotData.texture
            end
            
            if snapshotData.texCoords then
                f.SOE_TexCoords = snapshotData.texCoords
            end
            
            f:Show()
            SOE:ApplyToOverlay(f)
        end
    end

    if selectedGroupName == "Maelstrom Weapon (Stage 1-4)" then
        SpawnDummy(1, snapshots and snapshots.left)
    else
        if snapshots.left then SpawnDummy(1, snapshots.left) end
        if snapshots.right then SpawnDummy(2, snapshots.right) end
    end
    
    print("|cff33ff99SOE:|r Previewing: " .. (selectedGroupName or "Unknown"))
end

-----------------------------------------------------------------------
-- 4. CONFIGURATION UI
-----------------------------------------------------------------------

function SOE:GetEditingConfig()
    if not selectedSpecID then return DUMMY_CONFIG end
    local profile = self.db.profile
    if not profile.specs then profile.specs = {} end
    local specDB = profile.specs[selectedSpecID]
    if not specDB then
        specDB = { global = CopyTable(defaults.profile.specs['*'].global), spells = {} }
        profile.specs[selectedSpecID] = specDB
    end
    if not specDB.global then specDB.global = CopyTable(defaults.profile.specs['*'].global) end
    if not specDB.spells then specDB.spells = {} end

    local targetDB = specDB.global
    if selectedGroupName and selectedGroupName ~= "Global" then
        if not specDB.spells[selectedGroupName] then
            local source = specDB.global
            -- Only auto-inherit for Max or 5-9. Leave 1-4 clean or copy 5-9 if exists.
            if string.find(selectedGroupName, "Maelstrom Weapon") then
                 if specDB.spells["Maelstrom Weapon (Stage 5-9)"] then
                     source = specDB.spells["Maelstrom Weapon (Stage 5-9)"]
                 elseif specDB.spells["Maelstrom Weapon"] then
                     source = specDB.spells["Maelstrom Weapon"]
                 end
            end
            specDB.spells[selectedGroupName] = CopyTable(source)
        end
        targetDB = specDB.spells[selectedGroupName]
    end
    
    local uiDefaults = SOE:ResolveDefaultsFor(selectedGroupName)
    local safeUI = setmetatable({}, {
        __index = function(t, k)
            if targetDB[k] ~= nil then return targetDB[k] end
            if uiDefaults[k] ~= nil then return uiDefaults[k] end
            return 0 
        end,
        __newindex = function(t, k, v) targetDB[k] = v end
    })
    return safeUI
end

function SOE:GetOptions()
    local function GetProcList()
        local list = { ["Global"] = "Global (All Spells)" }
        if not selectedSpecID then return list end
        
        if SPELL_GROUPS[selectedSpecID] then
            for groupName, ids in pairs(SPELL_GROUPS[selectedSpecID]) do
                local firstID = ids[1]
                local info = C_Spell.GetSpellInfo(firstID)
                local icon = info and info.iconID
                if not icon then info = C_Spell.GetSpellInfo(groupName); icon = info and info.iconID end
                
                if groupName ~= "Maelstrom Weapon" then
                    list[groupName] = icon and ("|T"..icon..":14:14:0:0|t " .. groupName) or groupName
                end
            end
        end
        
        if SPELL_GROUPS[selectedSpecID] and SPELL_GROUPS[selectedSpecID]["Maelstrom Weapon"] then
             local ids = SPELL_GROUPS[selectedSpecID]["Maelstrom Weapon"]
             local info = C_Spell.GetSpellInfo(ids[1])
             local icon = info and info.iconID
             local p = icon and "|T"..icon..":14:14:0:0|t " or ""
             
             list["Maelstrom Weapon (Stage 1-4)"] = p .. "Maelstrom Weapon (Stage 1-4)"
             list["Maelstrom Weapon (Stage 5-9)"] = p .. "Maelstrom Weapon (Stage 5-9)"
             list["Maelstrom Weapon (Max 10)"] = p .. "Maelstrom Weapon (Max 10)"
        end

        local specDB = SOE.db.profile.specs[selectedSpecID]
        if specDB and specDB.spells then
            for name, _ in pairs(specDB.spells) do 
                local isValid = list[name] ~= nil 
                                or (SPELL_GROUPS[selectedSpecID] and SPELL_GROUPS[selectedSpecID][name])
                                or string.find(name, "Maelstrom Weapon") 
                
                if not list[name] and isValid then 
                    list[name] = name .. " (Saved)" 
                end 
            end
        end
        return list
    end
    
    local function GetSortedProcKeys()
        local list = GetProcList()
        local keys = {}
        for k in pairs(list) do if k ~= "Global" then table.insert(keys, k) end end
        table.sort(keys)
        table.insert(keys, 1, "Global") 
        return keys
    end
    local function IsDual() return selectedGroupName and DUAL_PROCS[selectedGroupName] end

    return {
        type = "group", name = "|cff33ff99SpellOverlay Enhanced|r", childGroups = "tab", 
        args = {
            settings = {
                order = 1, type = "group", name = "Settings",
                args = {
                    selection = {
                        order = 1, type = "group", name = "Configuration Target", inline = true,
                        args = {
                            classSelect = { order = 1, type = "select", name = "Class", width = "fill", 
                                values = function()
                                    local classes = {}
                                    for i = 1, GetNumClasses() do
                                        local name, tag, id = GetClassInfo(i)
                                        if name then classes[id] = "|c" .. (RAID_CLASS_COLORS[tag].colorStr or "ffffffff") .. name .. "|r" end
                                    end
                                    return classes
                                end,
                                get = function() return selectedClassID end,
                                set = function(_, val) selectedClassID = val; selectedSpecID = nil; selectedGroupName = nil; SOE:HidePreview() end,
                            },
                            specSelect = { order = 2, type = "select", name = "Specialization", width = "fill", disabled = function() return not selectedClassID end,
                                values = function()
                                    local specs = {}
                                    if not selectedClassID then return specs end
                                    for i = 1, 4 do
                                        local id, name, _, icon = GetSpecializationInfoForClassID(selectedClassID, i)
                                        if id then specs[id] = "|T"..icon..":14:14:0:0|t " .. name end
                                    end
                                    return specs
                                end,
                                get = function() return selectedSpecID end,
                                set = function(_, val) selectedSpecID = val; selectedGroupName = nil; SOE:HidePreview() end,
                            },
                            break_line = { order = 4, type = "description", name = "\n" },
                            procSelect = { order = 5, type = "select", name = "Spell / Proc", width = "double", values = GetProcList, sorting = GetSortedProcKeys, disabled = function() return not selectedSpecID end, get = function() return selectedGroupName or "Global" end, set = function(_, val) selectedGroupName = val; SOE:HidePreview(); SOE.LastPreviewedGroup = nil end },
                            resetBtn = { order = 6, type = "execute", name = "Reset Override", width = 0.8, disabled = function() return not selectedGroupName or selectedGroupName == "Global" end, func = function() if selectedSpecID and selectedGroupName then SOE.db.profile.specs[selectedSpecID].spells[selectedGroupName] = nil; SOE:RefreshAllOverlays() end end },
                            previewBtn = { order = 7, type = "execute", name = "Test / Preview", width = 0.8, disabled = function() return not selectedSpecID end, func = function() SOE.ForceShow = false; SOE:PreviewSelected() end }
                        }
                    },
                    spacer = { order = 9, type = "description", name = " " },
                    positioning = {
                        order = 10, type = "group", name = "Positioning", inline = true, disabled = function() return not selectedSpecID end,
                        args = {
                            scale = { order = 1, type = "range", name = "Scale", min = 0, max = 2.0, step = 0.01, isPercent = true, width = "fill", get = function() return SOE:GetEditingConfig().scale end, set = function(_, val) SOE:GetEditingConfig().scale = val; SOE:RefreshAllOverlays() end },
                            
                            header1 = { order = 10, type = "header", name = function() return IsDual() and "Left Texture" or "Offset" end },
                            posX = { order = 11, type = "range", name = "X Offset", min = -500, max = 500, step = 1, width = "fill", get = function() return SOE:GetEditingConfig().x end, set = function(_, val) SOE:GetEditingConfig().x = val; SOE:RefreshAllOverlays() end },
                            posY = { order = 12, type = "range", name = "Y Offset", min = -500, max = 500, step = 1, width = "fill", get = function() return SOE:GetEditingConfig().y end, set = function(_, val) SOE:GetEditingConfig().y = val; SOE:RefreshAllOverlays() end },
                            
                            header2 = { order = 20, type = "header", name = "Right Texture", hidden = function() return not IsDual() end },
                            posX2 = { order = 21, type = "range", name = "X Offset (Right)", min = -500, max = 500, step = 1, width = "fill", hidden = function() return not IsDual() end, get = function() return SOE:GetEditingConfig().x2 end, set = function(_, val) SOE:GetEditingConfig().x2 = val; SOE:RefreshAllOverlays() end },
                            posY2 = { order = 22, type = "range", name = "Y Offset (Right)", min = -500, max = 500, step = 1, width = "fill", hidden = function() return not IsDual() end, get = function() return SOE:GetEditingConfig().y2 end, set = function(_, val) SOE:GetEditingConfig().y2 = val; SOE:RefreshAllOverlays() end },
                        }
                    },
                    symmetry = {
                        order = 11, type = "group", name = "Symmetry & Size", inline = true, disabled = function() return not selectedSpecID end,
                        args = {
                            header1 = { order = 1, type = "header", name = function() return IsDual() and "Left Texture" or "Rotation, Mirror & Size" end },
                            rotation = { order = 2, type = "range", name = "Rotation (Degrees)", min = 0, max = 360, step = 1, width = "normal", get = function() return SOE:GetEditingConfig().rotation end, set = function(_, val) SOE:GetEditingConfig().rotation = val; SOE:RefreshAllOverlays() end },
                            mirror = { order = 3, type = "toggle", name = "Mirror Horizontally", width = "normal", get = function() return SOE:GetEditingConfig().mirror end, set = function(_, val) SOE:GetEditingConfig().mirror = val; SOE:RefreshAllOverlays() end },
                            
                            -- [SMART SLIDERS] Fetches from the snapshot database if the user hasn't set a custom override
                            width = { order = 4, type = "range", name = "Width", min = 10, max = 1000, step = 1, width = "normal", 
                                get = function() 
                                    local w = SOE:GetEditingConfig().width or 0
                                    if w > 0 then return w end
                                    local snap = SOE.db.global.snapshots[selectedGroupName]
                                    return (snap and snap.left and snap.left.width) and snap.left.width or 256
                                end, 
                                set = function(_, val) SOE:GetEditingConfig().width = val; SOE:RefreshAllOverlays() end 
                            },
                            height = { order = 5, type = "range", name = "Height", min = 10, max = 1000, step = 1, width = "normal", 
                                get = function() 
                                    local h = SOE:GetEditingConfig().height or 0
                                    if h > 0 then return h end
                                    local snap = SOE.db.global.snapshots[selectedGroupName]
                                    return (snap and snap.left and snap.left.height) and snap.left.height or 256
                                end, 
                                set = function(_, val) SOE:GetEditingConfig().height = val; SOE:RefreshAllOverlays() end 
                            },
                            
                            header2 = { order = 10, type = "header", name = "Right Texture", hidden = function() return not IsDual() end },
                            rotation2 = { order = 11, type = "range", name = "Rotation (Right)", min = 0, max = 360, step = 1, width = "normal", hidden = function() return not IsDual() end, get = function() return SOE:GetEditingConfig().rotation2 end, set = function(_, val) SOE:GetEditingConfig().rotation2 = val; SOE:RefreshAllOverlays() end },
                            mirror2 = { order = 12, type = "toggle", name = "Mirror (Right)", width = "normal", hidden = function() return not IsDual() end, get = function() return SOE:GetEditingConfig().mirror2 end, set = function(_, val) SOE:GetEditingConfig().mirror2 = val; SOE:RefreshAllOverlays() end },
                            
                            width2 = { order = 13, type = "range", name = "Width (Right)", min = 10, max = 1000, step = 1, width = "normal", hidden = function() return not IsDual() end, 
                                get = function() 
                                    local w = SOE:GetEditingConfig().width2 or 0
                                    if w > 0 then return w end
                                    local snap = SOE.db.global.snapshots[selectedGroupName]
                                    return (snap and snap.right and snap.right.width) and snap.right.width or 256
                                end, 
                                set = function(_, val) SOE:GetEditingConfig().width2 = val; SOE:RefreshAllOverlays() end 
                            },
                            height2 = { order = 14, type = "range", name = "Height (Right)", min = 10, max = 1000, step = 1, width = "normal", hidden = function() return not IsDual() end, 
                                get = function() 
                                    local h = SOE:GetEditingConfig().height2 or 0
                                    if h > 0 then return h end
                                    local snap = SOE.db.global.snapshots[selectedGroupName]
                                    return (snap and snap.right and snap.right.height) and snap.right.height or 256
                                end, 
                                set = function(_, val) SOE:GetEditingConfig().height2 = val; SOE:RefreshAllOverlays() end 
                            },
                        }
                    },
                    visuals = {
                        order = 20, type = "group", name = "Visual Customization", inline = true, disabled = function() return not selectedSpecID end,
                        args = {
                            alpha = { order = 1, type = "range", name = function() return IsDual() and "Opacity (Left)" or "Opacity" end, min = 0, max = 1.0, step = 0.01, isPercent = true, width = "fill", get = function() return SOE:GetEditingConfig().alpha end, set = function(_, val) SOE:GetEditingConfig().alpha = val; SOE:RefreshAllOverlays() end },
                            alpha2 = { order = 1.5, type = "range", name = "Opacity (Right)", min = 0, max = 1.0, step = 0.01, isPercent = true, width = "fill", hidden = function() return not IsDual() end, get = function() return SOE:GetEditingConfig().alpha2 end, set = function(_, val) SOE:GetEditingConfig().alpha2 = val; SOE:RefreshAllOverlays() end },
                            gradientMode = { order = 2, type = "select", name = "Color Mode", width = "fill", values = { ["NONE"] = "Solid", ["VERTICAL"] = "Gradient (V)", ["HORIZONTAL"] = "Gradient (H)" }, get = function() return SOE:GetEditingConfig().gradient end, set = function(_, val) SOE:GetEditingConfig().gradient = val; SOE:RefreshAllOverlays() end },
                            color = { order = 3, type = "color", name = "Primary Color", hasAlpha = true, width = "half", get = function() local s=SOE:GetEditingConfig().color; return s.r,s.g,s.b,s.a end, set = function(_,r,g,b,a) SOE:GetEditingConfig().color={r=r,g=g,b=b,a=a}; SOE:RefreshAllOverlays() end },
                            color2 = { order = 4, type = "color", name = "Secondary Color", hasAlpha = true, width = "half", hidden = function() return SOE:GetEditingConfig().gradient=="NONE" end, get = function() local s=SOE:GetEditingConfig().color2; return s.r,s.g,s.b,s.a end, set = function(_,r,g,b,a) SOE:GetEditingConfig().color2={r=r,g=g,b=b,a=a}; SOE:RefreshAllOverlays() end },
                            desaturate = { order = 10, type = "toggle", name = "Desaturate", width = "fill", get = function() return SOE:GetEditingConfig().desaturate end, set = function(_, val) SOE:GetEditingConfig().desaturate = val; SOE:RefreshAllOverlays() end },
                            blendMode = { order = 11, type = "select", name = "Texture Style", width = "fill", values = { ["BLEND"]="Opaque", ["ADD"]="Glow" }, get = function() return SOE:GetEditingConfig().blendMode end, set = function(_, val) SOE:GetEditingConfig().blendMode = val; SOE:RefreshAllOverlays() end },
                            
                            -- GLOW
                            break_glow = { order = 12, type = "header", name = "Border Settings" },
                            borderEnabled = { order = 13, type = "toggle", name = "Enable Border", width = "full", get = function() return SOE:GetEditingConfig().borderEnabled end, set = function(_, val) SOE:GetEditingConfig().borderEnabled = val; SOE:RefreshAllOverlays() end },
                            borderBlendMode = { order = 13.5, type = "select", name = "Border Style", width = "fill", values = { ["ADD"]="Glow", ["BLEND"]="Solid" }, disabled = function() return not SOE:GetEditingConfig().borderEnabled end, get = function() return SOE:GetEditingConfig().borderBlendMode end, set = function(_, val) SOE:GetEditingConfig().borderBlendMode = val; SOE:RefreshAllOverlays() end },
                            borderScale = { order = 14, type = "range", name = "Glow Size", min = 1.0, max = 1.5, step = 0.01, isPercent = true, width = "fill", disabled = function() return not SOE:GetEditingConfig().borderEnabled end, get = function() return SOE:GetEditingConfig().borderScale end, set = function(_, val) SOE:GetEditingConfig().borderScale = val; SOE:RefreshAllOverlays() end },
                            borderAlpha = { order = 15, type = "range", name = "Glow Opacity", min = 0, max = 1, step = 0.05, isPercent = true, width = "fill", disabled = function() return not SOE:GetEditingConfig().borderEnabled end, get = function() return SOE:GetEditingConfig().borderAlpha end, set = function(_, val) SOE:GetEditingConfig().borderAlpha = val; SOE:RefreshAllOverlays() end },
                            borderColor = { order = 16, type = "color", name = "Glow Color", hasAlpha = true, width = "full", disabled = function() return not SOE:GetEditingConfig().borderEnabled end, get = function() local c=SOE:GetEditingConfig().borderColor; return c.r,c.g,c.b,c.a end, set = function(_,r,g,b,a) SOE:GetEditingConfig().borderColor={r=r,g=g,b=b,a=a}; SOE:RefreshAllOverlays() end },
                            
                            -- PULSE
                            break_pulse = { order = 17, type = "header", name = "Pulse Effect" },
                            pulseEnabled = { order = 18, type = "toggle", name = "Enable Pulse", width = "full", get = function() return SOE:GetEditingConfig().pulseEnabled end, set = function(_, val) SOE:GetEditingConfig().pulseEnabled = val; SOE:RefreshAllOverlays() end },
                            pulseSpeed = { order = 19, type = "range", name = "Pulse Speed", min = 0.1, max = 10, step = 0.1, width = "fill", disabled = function() return not SOE:GetEditingConfig().pulseEnabled end, get = function() return SOE:GetEditingConfig().pulseSpeed end, set = function(_, val) SOE:GetEditingConfig().pulseSpeed = val; SOE:RefreshAllOverlays() end },
                            pulseMin = { order = 20, type = "range", name = "Min Opacity", min = 0, max = 1, step = 0.05, isPercent = true, width = "fill", disabled = function() return not SOE:GetEditingConfig().pulseEnabled end, get = function() return SOE:GetEditingConfig().pulseMin end, set = function(_, val) SOE:GetEditingConfig().pulseMin = val; SOE:RefreshAllOverlays() end },
                        }
                    }
                }
            },
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(SOE.db),
        }
    }
end

function SOE:OpenConfig()
    if not selectedClassID then self:AutoDetectSpec() end
    local ACD = LibStub("AceConfigDialog-3.0")
    local container = ACD:Open(addonName)
    
    if container and container.frame then
        local frame = container.frame
        frame:SetScale(1.2)
        if self.db.global.uiPos and self.db.global.uiPos.point then
            local p = self.db.global.uiPos
            frame:ClearAllPoints()
            pcall(function() frame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y) end)
        end
        
        -- INVISIBLE WATCHER for 100% Reliable Closing
        if not frame.SOE_Watcher then
            local watcher = CreateFrame("Frame", nil, frame)
            watcher:Hide() 
            watcher:SetScript("OnHide", function()
                local app = LibStub("AceAddon-3.0"):GetAddon("SpellOverlay Enhanced", true)
                if app then
                    local point, relativeTo, relPoint, x, y = frame:GetPoint()
                    app.db.global.uiPos = { point = point, relPoint = relPoint, x = x, y = y }
                    if app.HidePreview then app:HidePreview() end
                end
            end)
            frame.SOE_Watcher = watcher
        end
        frame.SOE_Watcher:Show()
    end
end

function SOE:ChatCommand(input)
    self:OpenConfig()
end

-----------------------------------------------------------------------
-- 5. INITIALIZATION
-----------------------------------------------------------------------

function SOE:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("SpellOverlayEnhancedDB", defaults, true)
    self:BuildLookupMap()

    if not SOE.db.profile.cacheVersion or SOE.db.profile.cacheVersion < 18 then
        SOE.db.profile.cacheVersion = 18
    end

    self:RegisterChatCommand("soe", "ChatCommand")

    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, self:GetOptions())
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "Spell Overlay")
    LibStub("AceConfigDialog-3.0"):SetDefaultSize(addonName, 520, 750)
    
    local ACD = LibStub("AceConfigDialog-3.0", true)
    if ACD then
        hooksecurefunc(ACD, "Close", function(lib, appName)
            if appName == addonName then
                SOE:HidePreview()
            end
        end)
    end
end

function SOE:OnOverlayShow() end

function SOE:AutoDetectSpec()
    local classID = select(3, UnitClass("player"))
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)
    selectedClassID = classID
    selectedSpecID = specID
end

function SOE:OnEnable()
    if SpellActivationOverlayFrame then
        self:HookScript(SpellActivationOverlayFrame, "OnUpdate", function(self, elapsed)
            SOE:OnFrameUpdate(elapsed)
        end)

        local function HookHandler(self, spellID, texturePath, position, scale, r, g, b)
            -- Ignore the parent wrapper call that triggers the two sub-frames
            if position == "Left + Right (Flipped)" then return end 
            
            if self.overlayPool then
                for overlay in self.overlayPool:EnumerateActive() do
                    -- Ensure we ONLY target the frame matching the exact position event
                    if overlay.spellID == spellID and overlay.position == position then
                        
                        if overlay.animIn and overlay.animIn:IsPlaying() then
                            overlay.animIn:Finish()
                        end
                        
                        if not overlay.SOE_Hooked or overlay.SOE_LastSpell ~= spellID then
                            local blizzScale = scale or 1.0
                            local w, h = overlay:GetSize()
                            overlay.SOE_OrigW = w / blizzScale
                            overlay.SOE_OrigH = h / blizzScale
                            overlay.SOE_LastSpell = spellID
                        end
                        
                        if texturePath then 
                            overlay.SOE_RealTexture = texturePath 
                        elseif overlay.texture then
                            local t = overlay.texture:GetTexture()
                            if t and t ~= "" then overlay.SOE_RealTexture = t end
                        end
                        
                        overlay.SOE_OrigScale = 1.0

                        SOE:EnsureHelperExists(overlay)
                        if not overlay.IsDummy then 
                            if not overlay.SOE_Hooked then overlay.SOE_FrameCount = 0 end
                            overlay.SOE_Hooked = true
                            
                            SOE:ApplyToOverlay(overlay)
                            
                            C_Timer.After(0.1, function() 
                                if overlay:IsShown() then SOE:SnapshotOverlay(overlay) end
                            end)
                        end
                    end
                end
            end
            SOE:TriggerUpdate(spellID)
        end

        if SpellActivationOverlayFrame.ShowOverlay then
            hooksecurefunc(SpellActivationOverlayFrame, "ShowOverlay", HookHandler)
        elseif _G.SpellActivationOverlay_ShowOverlay then
            hooksecurefunc("SpellActivationOverlay_ShowOverlay", HookHandler)
        end
    end
    
    self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_SHOW", "OnOverlayShow")
    self:RegisterEvent("PLAYER_LOGIN", "AutoDetectSpec")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "AutoDetectSpec")
end