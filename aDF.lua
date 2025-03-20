--########### armor and Debuff Frame
--########### By Atreyyo @ Vanillagaming.org

local has_superwow = SetAutoloot and true or false

aDF = CreateFrame('Button', "aDF", UIParent); -- Event Frame
aDF.Options = CreateFrame("Frame",nil,UIParent) -- Options frame

--register events 
aDF:RegisterEvent("ADDON_LOADED")
aDF:RegisterEvent("UNIT_AURA")
aDF:RegisterEvent("PLAYER_TARGET_CHANGED")

-- tables 
aDF_frames = {} -- we will put all debuff frames in here
aDF_guiframes = {} -- we wil put all gui frames here
gui_Options = gui_Options or {} -- checklist options
gui_Optionsxy = gui_Optionsxy or 1
gui_DebuffsPerRow = gui_DebuffsPerRow or 7 -- Default to 7 debuffs per row
gui_Order = gui_Order or {} -- Table to store the order of enabled debuffs

local last_target_change_time = GetTime()
local scorched_at = GetTime() -- Timer for Scorch
local exposed_at = GetTime() -- Timer for Expose Armor
local chilled_at = GetTime() -- Timer for Winter's Chill
local ignited_at = GetTime() -- Timer for Ignite

-- translation table for debuff check on target

aDFSpells = {
    ["Sunder Armor"] = "Sunder Armor",
    ["Armor Shatter"] = "Armor Shatter",
    ["Faerie Fire"] = "Faerie Fire",
    ["Nightfall"] = "Spell Vulnerability",
    ["Flame Buffet"] = "Flame Buffet",
    ["Scorch"] = "Fire Vulnerability",
    ["Ignite"] = "Ignite",
    ["Curse of Recklessness"] = "Curse of Recklessness",
    ["Curse of the Elements"] = "Curse of the Elements",
    ["Curse of Shadows"] = "Curse of Shadow",
    ["Shadow Bolt"] = "Shadow Vulnerability",
    ["Shadow Weaving"] = "Shadow Weaving",
    ["Expose Armor"] = "Expose Armor",
    ["Judgement of Wisdom"] = "Judgement of Wisdom",
    ["Judgement of Light"] = "Judgement of Light",
    ["Judgement of the Crusader"] = "Judgement of the Crusader",
    ["Winter's Chill"] = "Winter's Chill",  -- Added Winter's Chill
}

-- table with names and textures 

aDFDebuffs = {
    ["Sunder Armor"] = "Interface\\Icons\\Ability_Warrior_Sunder",
    ["Armor Shatter"] = "Interface\\Icons\\INV_Axe_12",
    ["Faerie Fire"] = "Interface\\Icons\\Spell_Nature_FaerieFire",
    ["Nightfall"] = "Interface\\Icons\\Spell_Holy_ElunesGrace",
    ["Flame Buffet"] = "Interface\\Icons\\Spell_Fire_Fireball",
    ["Scorch"] = "Interface\\Icons\\Spell_Fire_SoulBurn",
    ["Ignite"] = "Interface\\Icons\\Spell_Fire_Incinerate",
    ["Curse of Recklessness"] = "Interface\\Icons\\Spell_Shadow_UnholyStrength",
    ["Curse of the Elements"] = "Interface\\Icons\\Spell_Shadow_ChillTouch",
    ["Curse of Shadows"] = "Interface\\Icons\\Spell_Shadow_CurseOfAchimonde",
    ["Shadow Bolt"] = "Interface\\Icons\\Spell_Shadow_ShadowBolt",
    ["Shadow Weaving"] = "Interface\\Icons\\Spell_Shadow_BlackPlague",
    ["Expose Armor"] = "Interface\\Icons\\Ability_Warrior_Riposte",
    ["Judgement of Wisdom"] = "Interface\\Icons\\Spell_Holy_RighteousnessAura",
    ["Judgement of Light"] = "Interface\\Icons\\Spell_Holy_HealingAura",
    ["Judgement of the Crusader"] = "Interface\\Icons\\Spell_Holy_HolySmite",
    ["Winter's Chill"] = "Interface\\Icons\\Spell_Frost_ChillingBlast",  -- Added Winter's Chill
}

-- Helper function to check if a table contains a value
function tContains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- Initialize default values
function aDF_Default()
    if guiOptions == nil then
        guiOptions = {}
        for k, v in pairs(aDFDebuffs) do
            if guiOptions[k] == nil then
                guiOptions[k] = 1
                -- Only add to gui_Order if it doesn't already exist
                if not tContains(gui_Order, k) then
                    table.insert(gui_Order, k)
                end
            end
        end
    end
end

-- the main frame

function aDF:Init()
    aDF.Drag = { }
    function aDF.Drag:StartMoving()
        if IsShiftKeyDown() then
            this:StartMoving()
        end
    end
    
    function aDF.Drag:StopMovingOrSizing()
        if IsShiftKeyDown() then
            this:StopMovingOrSizing()
            local x, y = this:GetCenter()
            local ux, uy = UIParent:GetCenter()
            aDF_x, aDF_y = floor(x - ux + 0.5), floor(y - uy + 0.5)
        end
    end
    
    self:SetFrameStrata("BACKGROUND")
    self:SetWidth((24+gui_Optionsxy)*gui_DebuffsPerRow) -- Set these to whatever height/width is needed 
    self:SetHeight(24+gui_Optionsxy) -- for your Texture
    self:SetPoint("CENTER",aDF_x,aDF_y)
    self:SetMovable(1)
    self:EnableMouse(1)
    self:RegisterForDrag("LeftButton")
    self:SetScript("OnDragStart", aDF.Drag.StartMoving)
    self:SetScript("OnDragStop", aDF.Drag.StopMovingOrSizing)
    
    f_ =  0
    for name, texture in pairs(aDFDebuffs) do
        aDFsize = 24+gui_Optionsxy
        aDF_frames[name] = aDF_frames[name] or aDF.Create_frame(name)
        local frame = aDF_frames[name]
        frame:SetWidth(aDFsize)
        frame:SetHeight(aDFsize)
        frame:SetPoint("BOTTOMLEFT",aDFsize*f_,-aDFsize)
        frame.icon:SetTexture(texture)
        frame:SetFrameLevel(2)
        frame:Show()
        frame:SetScript("OnMouseDown", function()
            if (arg1 == "RightButton") then
                tdb=this:GetName()
                if aDF_target ~= nil then
                    if UnitAffectingCombat(aDF_target) and UnitCanAttack("player", aDF_target) and guiOptions[tdb] ~= nil then
                        if not aDF:GetDebuff(aDF_target,aDFSpells[tdb]) then
                            -- No chat reporting
                        else
                            if aDF:GetDebuff(aDF_target,aDFSpells[tdb],1) == 1 then
                                s_ = "stack"
                            elseif aDF:GetDebuff(aDF_target,aDFSpells[tdb],1) > 1 then
                                s_ = "stacks"
                            end
                            if aDF:GetDebuff(aDF_target,aDFSpells[tdb],1) >= 1 and aDF:GetDebuff(aDF_target,aDFSpells[tdb],1) < 5 and tdb ~= "Armor Shatter" then
                                -- No chat reporting
                            end
                            if tdb == "Armor Shatter" and aDF:GetDebuff(aDF_target,aDFSpells[tdb],1) >= 1 and aDF:GetDebuff(aDF_target,aDFSpells[tdb],1) < 3 then
                                -- No chat reporting
                            end
                        end
                    end
                end
            end
        end)
        f_ = f_+1
    end
end

-- creates the debuff frames on load

function aDF.Create_frame(name)
    local frame = CreateFrame('Button', name, aDF)
    frame:SetBackdrop({ bgFile=[[Interface/Tooltips/UI-Tooltip-Background]] })
    frame:SetBackdropColor(0,0,0,1)
    frame.icon = frame:CreateTexture(nil, 'ARTWORK')
    frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.icon:SetPoint('TOPLEFT', 1, -1)
    frame.icon:SetPoint('BOTTOMRIGHT', -1, 1)
    frame.dur = frame:CreateFontString(nil, "OVERLAY")
    frame.dur:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, -5)  -- Moved down by 5 pixels
    frame.dur:SetFont("Interface\\AddOns\\aDF\\BalooBhaina.ttf", 10+gui_Optionsxy) -- Updated font path
    frame.dur:SetTextColor(1, 1, 1, 1) -- White text
    frame.dur:SetShadowOffset(2,-2)
    frame.dur:SetText("0")
    frame.nr = frame:CreateFontString(nil, "OVERLAY")
    frame.nr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.nr:SetFont("Interface\\AddOns\\aDF\\BalooBhaina.ttf", 10+gui_Optionsxy) -- Updated font path
    frame.nr:SetTextColor(1, 1, 1, 1) -- White text
    frame.nr:SetShadowOffset(2,-2)
    frame.nr:SetText("1")
    return frame
end

-- creates gui checkboxes

function aDF.Create_guiframe(name)
    local frame = CreateFrame("CheckButton", name, aDF.Options, "UICheckButtonTemplate")
    frame:SetFrameStrata("LOW")
    frame:SetScript("OnClick", function () 
        if frame:GetChecked() == nil then 
            guiOptions[name] = nil
            -- Remove the debuff from the order table
            for i, v in ipairs(gui_Order) do
                if v == name then
                    table.remove(gui_Order, i)
                    break
                end
            end
        elseif frame:GetChecked() == 1 then 
            guiOptions[name] = 1 
            -- Add the debuff to the order table if it's not already there
            if not tContains(gui_Order, name) then
                table.insert(gui_Order, name)
            end
        end
        aDF:Sort()
        aDF:Update()
    end)
    frame:SetScript("OnEnter", function() 
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT");
        GameTooltip:SetText(name, 255, 255, 0, 1, 1);
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame:SetChecked(guiOptions[name])
    frame.Icon = frame:CreateTexture(nil, 'ARTWORK')
    frame.Icon:SetTexture(aDFDebuffs[name])
    frame.Icon:SetWidth(25)
    frame.Icon:SetHeight(25)
    frame.Icon:SetPoint("CENTER",-30,0)
    return frame
end

-- update function for the text/debuff frames

local sunderers = {}
local shattered_at = GetTime()
local sundered_at = GetTime()
local anni_stacks_maxed = false

function aDF:Update()
    if aDF_target ~= nil and UnitExists(aDF_target) and not UnitIsDead(aDF_target) then
        if UnitIsUnit(aDF_target,'targettarget') and GetTime() < (last_target_change_time + 1.3) then
            return
        end
        for i, v in pairs(guiOptions) do
            if aDF:GetDebuff(aDF_target,aDFSpells[i]) then
                aDF_frames[i]["icon"]:SetAlpha(1)
                if aDF:GetDebuff(aDF_target,aDFSpells[i],1) > 1 then
                    aDF_frames[i]["nr"]:SetText(aDF:GetDebuff(aDF_target,aDFSpells[i],1))
                end
                if i == "Sunder Armor" then
                    local elapsed = 30 - (GetTime() - sundered_at)
                    aDF_frames[i]["nr"]:SetText(aDF:GetDebuff(aDF_target,aDFSpells[i],1))
                    aDF_frames[i]["dur"]:SetText(format("%0.f",elapsed >= 0 and elapsed or 0))
                end
                if i == "Armor Shatter" then
                    local elapsed = 45 - (GetTime() - shattered_at)
                    if elapsed < 0 then
                        shattered_at = shattered_at + 20
                    end
                    aDF_frames[i]["nr"]:SetText(aDF:GetDebuff(aDF_target,aDFSpells[i],1))
                    aDF_frames[i]["dur"]:SetText(format("%0.f",elapsed >= 0 and elapsed or 0))
                end
                if i == "Scorch" then
                    local elapsed = 30 - (GetTime() - scorched_at)  -- Scorch lasts 30 seconds
                    aDF_frames[i]["nr"]:SetText(aDF:GetDebuff(aDF_target,aDFSpells[i],1))
                    aDF_frames[i]["dur"]:SetText(format("%0.f",elapsed >= 0 and elapsed or 0))
                end
                if i == "Expose Armor" then
                    local elapsed = 30 - (GetTime() - exposed_at)  -- Expose Armor lasts 30 seconds
                    aDF_frames[i]["nr"]:SetText(aDF:GetDebuff(aDF_target,aDFSpells[i],1))
                    aDF_frames[i]["dur"]:SetText(format("%0.f",elapsed >= 0 and elapsed or 0))
                end
                if i == "Winter's Chill" then
                    local elapsed = 15 - (GetTime() - chilled_at)  -- Winter's Chill lasts 15 seconds
                    aDF_frames[i]["nr"]:SetText(aDF:GetDebuff(aDF_target,aDFSpells[i],1))
                    aDF_frames[i]["dur"]:SetText(format("%0.f",elapsed >= 0 and elapsed or 0))
                end
                if i == "Ignite" then
                    local elapsed = 6 - (GetTime() - ignited_at)  -- Ignite lasts 6 seconds
                    aDF_frames[i]["nr"]:SetText(aDF:GetDebuff(aDF_target,aDFSpells[i],1))
                    aDF_frames[i]["dur"]:SetText(format("%0.f",elapsed >= 0 and elapsed or 0))
                end
            else
                aDF_frames[i]["icon"]:SetAlpha(0.3)
                aDF_frames[i]["nr"]:SetText("")
                aDF_frames[i]["dur"]:SetText("")
            end        
        end
    else
        for i, v in pairs(guiOptions) do
            aDF_frames[i]["icon"]:SetAlpha(0.3)
            aDF_frames[i]["nr"]:SetText("")
            aDF_frames[i]["dur"]:SetText("")
        end
    end
end

function aDF:UpdateCheck()
    if utimer == nil or (GetTime() - utimer > 0.3) then
        utimer = GetTime()
        aDF:Update()
    end
end

-- Sort function to show/hide frames aswell as positioning them correctly

function aDF:Sort()
    for name, _ in pairs(aDFDebuffs) do
        if guiOptions[name] == nil then
            aDF_frames[name]:Hide()
        else
            aDF_frames[name]:Show()
        end
    end

    -- Use the saved order to position the debuff frames
    for n, v in ipairs(gui_Order) do
        if v and aDF_frames[v] then
            local row = math.floor((n-1)/gui_DebuffsPerRow)
            local col = (n-1) - (row * gui_DebuffsPerRow) -- Use subtraction instead of modulo
            aDF_frames[v]:SetPoint('BOTTOMLEFT', (24+gui_Optionsxy)*col, -(24+gui_Optionsxy)*(row+1))
        end
    end
end

-- Options frame

-- Options frame

function aDF.Options:Gui()
    aDF.Options.Drag = { }
    function aDF.Options.Drag:StartMoving()
        if IsShiftKeyDown() then
            this:StartMoving()
        end
    end
    
    function aDF.Options.Drag:StopMovingOrSizing()
        if IsShiftKeyDown() then
            this:StopMovingOrSizing()
        end
    end

    local backdrop = {
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            tile="false",
            tileSize="4",
            edgeSize="8",
            insets={
                left="2",
                right="2",
                top="2",
                bottom="2"
            }
    }
    
    self:SetFrameStrata("BACKGROUND")
    self:SetWidth(500) -- Increased width
    self:SetHeight(550) -- Increased height
    self:SetPoint("CENTER",0,0)
    self:SetMovable(1)
    self:EnableMouse(1)
    self:RegisterForDrag("LeftButton")
    self:SetScript("OnDragStart", aDF.Options.Drag.StartMoving)
    self:SetScript("OnDragStop", aDF.Options.Drag.StopMovingOrSizing)
    self:SetBackdrop(backdrop) --border around the frame
    self:SetBackdropColor(0,0,0,1);
    
    -- Options text
    
    self.text = self:CreateFontString(nil, "OVERLAY")
    self.text:SetPoint("CENTER", self, "CENTER", 0, 230)
    self.text:SetFont("Interface\\AddOns\\aDF\\BalooBhaina.ttf", 25) -- Updated font path
    self.text:SetTextColor(255, 255, 0, 1)
    self.text:SetShadowOffset(2,-2)
    self.text:SetText("Options")
    
    -- mid line
    
    self.left = self:CreateTexture(nil, "BORDER")
    self.left:SetWidth(125)
    self.left:SetHeight(2)
    self.left:SetPoint("CENTER", -62, 210)
    self.left:SetTexture(1, 1, 0, 1)
    self.left:SetGradientAlpha("Horizontal", 0, 0, 0, 0, 102, 102, 102, 0.6)

    self.right = self:CreateTexture(nil, "BORDER")
    self.right:SetWidth(125)
    self.right:SetHeight(2)
    self.right:SetPoint("CENTER", 63, 210)
    self.right:SetTexture(1, 1, 0, 1)
    self.right:SetGradientAlpha("Horizontal", 255, 255, 0, 0.6, 0, 0, 0, 0)
    
    -- slider for debuff size

    self.Slider = CreateFrame("Slider", "aDF Slider", self, 'OptionsSliderTemplate')
    self.Slider:SetWidth(200)
    self.Slider:SetHeight(20)
    self.Slider:SetPoint("CENTER", self, "CENTER", -110, 180) -- Moved to the left
    self.Slider:SetMinMaxValues(1, 10)
    self.Slider:SetValue(gui_Optionsxy)
    self.Slider:SetValueStep(1)
    getglobal(self.Slider:GetName() .. 'Low'):SetText('1')
    getglobal(self.Slider:GetName() .. 'High'):SetText('10')
    self.Slider:SetScript("OnValueChanged", function() 
        gui_Optionsxy = this:GetValue()
        for _, frame in pairs(aDF_frames) do
            frame:SetWidth(24+gui_Optionsxy)
            frame:SetHeight(24+gui_Optionsxy)
            frame.nr:SetFont("Interface\\AddOns\\aDF\\BalooBhaina.ttf", 16+gui_Optionsxy) -- Updated font path
        end
        aDF:SetWidth((24+gui_Optionsxy)*gui_DebuffsPerRow)
        aDF:SetHeight(24+gui_Optionsxy)
        aDF:Sort()
    end)
    self.Slider:Show()

    -- Title for the debuff size slider
    self.SliderTitle = self:CreateFontString(nil, "OVERLAY")
    self.SliderTitle:SetPoint("CENTER", self.Slider, "CENTER", 0, 20)
    self.SliderTitle:SetFont("Interface\\AddOns\\aDF\\BalooBhaina.ttf", 14) -- Updated font path
    self.SliderTitle:SetTextColor(255, 255, 0, 1)
    self.SliderTitle:SetText("Debuff Size")
    
    -- slider for debuffs per row

    self.Slider2 = CreateFrame("Slider", "aDF Slider2", self, 'OptionsSliderTemplate')
    self.Slider2:SetWidth(200)
    self.Slider2:SetHeight(20)
    self.Slider2:SetPoint("CENTER", self, "CENTER", 110, 180) -- Moved to the right
    self.Slider2:SetMinMaxValues(1, 10)
    self.Slider2:SetValue(gui_DebuffsPerRow)
    self.Slider2:SetValueStep(1)
    getglobal(self.Slider2:GetName() .. 'Low'):SetText('1')
    getglobal(self.Slider2:GetName() .. 'High'):SetText('10')
    self.Slider2:SetScript("OnValueChanged", function() 
        gui_DebuffsPerRow = this:GetValue()
        aDF:SetWidth((24+gui_Optionsxy)*gui_DebuffsPerRow)
        aDF:Sort()
    end)
    self.Slider2:Show()

    -- Title for the debuffs per row slider
    self.Slider2Title = self:CreateFontString(nil, "OVERLAY")
    self.Slider2Title:SetPoint("CENTER", self.Slider2, "CENTER", 0, 20)
    self.Slider2Title:SetFont("Interface\\AddOns\\aDF\\BalooBhaina.ttf", 14) -- Updated font path
    self.Slider2Title:SetTextColor(255, 255, 0, 1)
    self.Slider2Title:SetText("Debuffs Per Row")
    
    -- checkboxes

    local temptable = {}
    for tempn, _ in pairs(aDFDebuffs) do
        table.insert(temptable,tempn)
    end
    table.sort(temptable, function(a,b) return a<b end)
    
    local x, y = 130, -80
    for _, name in pairs(temptable) do
        y = y - 40
        if y < -360 then y = -120; x = x + 140 end
        aDF_guiframes[name] = aDF_guiframes[name] or aDF.Create_guiframe(name)
        local frame = aDF_guiframes[name]
        frame:SetPoint("TOPLEFT",x,y)
    end    

    -- done button
    
    self.dbutton = CreateFrame("Button",nil,self,"UIPanelButtonTemplate")
    self.dbutton:SetPoint("BOTTOM",0,10)
    self.dbutton:SetFrameStrata("LOW")
    self.dbutton:SetWidth(79)
    self.dbutton:SetHeight(18)
    self.dbutton:SetText("Done")
    self.dbutton:SetScript("OnClick", function() PlaySound("igMainMenuOptionCheckBoxOn"); aDF:Sort(); aDF:Update(); aDF.Options:Hide() end)
    self:Hide()
end

-- function to check a unit for a certain debuff and/or number of stacks
function aDF:GetDebuff(name,buff,stacks)
    local a = 1
    while UnitDebuff(name,a) do
        local _, s, _, id = UnitDebuff(name,a)
        local n = SpellInfo(id)
        if buff == n then 
            if stacks == 1 then
                return s
            else
                return true 
            end
        end
        a = a + 1
    end

    -- if not found, check buffs in case over the debuff limit
    a = 1
    while UnitBuff(name,a) do
        local _, s, id = UnitBuff(name,a)
        local n = SpellInfo(id)
        if buff == n then 
            if stacks == 1 then
                return s
            else
                return true 
            end
        end
        a = a + 1
    end
    return false
end

-- event function, will load the frames we need
function aDF:OnEvent()
    if event == "ADDON_LOADED" and arg1 == "aDF" then
        -- Initialize defaults only if necessary
        aDF_Default()
        aDF_target = nil
        if gui_chan == nil then gui_chan = Say end
        aDF:Init() -- loads frame, see the function
        aDF.Options:Gui() -- loads options frame
        aDF:Sort() -- sorts the debuff frames and places them to eachother
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r Loaded",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf show|r to show frame",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf hide|r to hide frame",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf options|r for options frame",1,1,1)
    elseif event == "UNIT_AURA" and arg1 == aDF_target then
        -- Handle aura updates
        local anni_prev = tonumber(aDF_frames["Armor Shatter"]["nr"]:GetText()) or 0
        local scorch_prev = tonumber(aDF_frames["Scorch"]["nr"]:GetText()) or 0
        local expose_prev = tonumber(aDF_frames["Expose Armor"]["nr"]:GetText()) or 0
        local chill_prev = tonumber(aDF_frames["Winter's Chill"]["nr"]:GetText()) or 0
        local ignite_prev = tonumber(aDF_frames["Ignite"]["nr"]:GetText()) or 0
        aDF:Update()
        local anni = tonumber(aDF_frames["Armor Shatter"]["nr"]:GetText()) or 0
        local scorch = tonumber(aDF_frames["Scorch"]["nr"]:GetText()) or 0
        local expose = tonumber(aDF_frames["Expose Armor"]["nr"]:GetText()) or 0
        local chill = tonumber(aDF_frames["Winter's Chill"]["nr"]:GetText()) or 0
        local ignite = tonumber(aDF_frames["Ignite"]["nr"]:GetText()) or 0

        -- Reset timers if debuffs are reapplied
        if anni_prev ~= anni then shattered_at = GetTime() end
        if scorch_prev ~= scorch or (scorch == 5 and aDF:GetDebuff(aDF_target, aDFSpells["Scorch"])) then
            scorched_at = GetTime() -- Reset Scorch timer even at 5 stacks
        end
        if expose_prev ~= expose or (expose == 5 and aDF:GetDebuff(aDF_target, aDFSpells["Expose Armor"])) then
            exposed_at = GetTime() -- Reset Expose Armor timer even at 5 stacks
        end
        if chill_prev ~= chill or (chill == 5 and aDF:GetDebuff(aDF_target, aDFSpells["Winter's Chill"])) then
            chilled_at = GetTime() -- Reset Winter's Chill timer even at 5 stacks
        end
        if ignite_prev ~= ignite or (ignite == 5 and aDF:GetDebuff(aDF_target, aDFSpells["Ignite"])) then
            ignited_at = GetTime() -- Reset Ignite timer even at 5 stacks
        end

        if anni_stacks_maxed and anni < 3 then anni_stacks_maxed = false end
        if not anni_stacks_maxed and anni >= 3 then
            UIErrorsFrame:AddMessage("Annihilator Stacks Maxxed",1,0.1,0.1,1)
            PlaySoundFile("Sound\\Spells\\YarrrrImpact.wav")
            anni_stacks_maxed = true
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Handle target changes
        local aDF_target_old = aDF_target
        aDF_target = nil
        last_target_change_time = GetTime()
        if UnitIsPlayer("target") then
            aDF_target = "targettarget"
        end
        if UnitCanAttack("player", "target") then
            aDF_target = "target"
        end
        if has_superwow then
            _, aDF_target = UnitExists(aDF_target)
        end
        if aDF_target ~= aDF_target_old then
            anni_stacks_maxed = false
        end
        aDF:Update()
    end
end

-- update and onevent who will trigger the update and event functions

aDF:SetScript("OnEvent", aDF.OnEvent)
aDF:SetScript("OnUpdate", aDF.UpdateCheck)

-- slash commands

function aDF.slash(arg1,arg2,arg3)
    if arg1 == nil or arg1 == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf show|r to show frame",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf hide|r to hide frame",1,1,1)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r type |cFFFFFF00 /adf options|r for options frame",1,1,1)
    else
        if arg1 == "show" then
            aDF:Show()
        elseif arg1 == "hide" then
            aDF:Hide()
        elseif arg1 == "options" then
            aDF.Options:Show()
        else
            DEFAULT_CHAT_FRAME:AddMessage(arg1)
            DEFAULT_CHAT_FRAME:AddMessage("|cFFF5F54A aDF:|r unknown command",1,0.3,0.3);
        end
    end
end

SlashCmdList['ADF_SLASH'] = aDF.slash
SLASH_ADF_SLASH1 = '/adf'