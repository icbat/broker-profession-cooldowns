-- TODO Need an easy way to manage the cache/reset a character
------------------------------
--- Initialize Saved Variables
------------------------------
if icbat_bpc_cross_character_cache == nil then
    -- char name -> recipe w/cooldown ID -> recipe_name, cooldown_finished_date
    icbat_bpc_cross_character_cache = {}
end
if icbat_bpc_character_class_name == nil then
    -- char name -> class name
    icbat_bpc_character_class_name = {}
end

-----------------------
--- Tim Allen Grunt.wav
-----------------------

local function add_recipe_to_cache(recipeID)
    local seconds_left_on_cd, has_cooldown = C_TradeSkillUI.GetRecipeCooldown(recipeID)
    local name, realm = UnitFullName("player")
    local qualified_name = name .. "-" .. realm

    if has_cooldown then
        local recipe_info = C_TradeSkillUI.GetRecipeInfo(recipeID)

        if seconds_left_on_cd == nil then
            seconds_left_on_cd = -1
        end

        local recipe_to_store = {
            recipe_name = recipe_info["name"],
            cooldown_finished_date = seconds_left_on_cd + time()
        }

        if icbat_bpc_cross_character_cache[qualified_name] == nil then
            icbat_bpc_cross_character_cache[qualified_name] = {}
        end

        -- if seconds_left_on_cd ~= nil then
        --     icbat_bpc_cross_character_cache[qualified_name][recipeID] = seconds_left_on_cd + time()
        -- else
        -- end
        icbat_bpc_cross_character_cache[qualified_name][recipeID] = recipe_to_store
    end

    local _localized, canonical_class_name = UnitClass("player")
    icbat_bpc_character_class_name[qualified_name] = canonical_class_name
end

local function scan_for_recipes()
    local recipes_in_open_profession = C_TradeSkillUI.GetAllRecipeIDs()

    local known_recipes = {}
    for _i, recipeID in pairs(recipes_in_open_profession) do
        local recipe_info = C_TradeSkillUI.GetRecipeInfo(recipeID)

        if recipe_info["learned"] then
            add_recipe_to_cache(recipeID)
        end
    end
end

-------------
--- View Code
-------------
local function build_tooltip(self)
    self:AddHeader("") -- filled in later w/ colspan
    self:AddSeparator()

    for qualified_char_name, recipe_to_cd in pairs(icbat_bpc_cross_character_cache) do
        for recipeID, stored_recipe in pairs(recipe_to_cd) do
            local cooldown_finished_date = stored_recipe["cooldown_finished_date"]
            local recipe_name = stored_recipe["recipe_name"]

            local ready = "Ready"
            if cooldown_finished_date > time() then
                local hours = (cooldown_finished_date - time()) / 3600
                if hours >= 1 then
                    ready = math.ceil(hours) .. " hours"
                else
                    local minutes = (cooldown_finished_date - time()) / 60
                    ready = math.ceil(minutes) .. " minutes"
                end

            end
            local line = self:AddLine(Ambiguate(qualified_char_name, "all"), recipe_name, ready)

            if cooldown_finished_date > time() then
                self:SetCellTextColor(self:GetLineCount(), 3, 1, 0.5, 0, 1)
            else
                self:SetCellTextColor(self:GetLineCount(), 3, 0, 1, 0, 1)
            end

            local class_name = icbat_bpc_character_class_name[qualified_char_name]
            print(class_name)
            if class_name ~= nil then
                local rgb = C_ClassColor.GetClassColor(class_name)
                self:SetCellTextColor(self:GetLineCount(), 1, rgb.r, rgb.g, rgb.b, 1)
            end
        end
    end

    self:AddSeparator()
    self:AddLine("") -- filled in later w/ colspan
    self:AddLine("") -- filled in later w/ colspan

    -- lineNum, colNum, value[, font][, justification][, colSpan]
    self:SetCell(1, 1, "Profession Cooldowns", nil, "CENTER", 3)
    self:SetCell(self:GetLineCount() - 1, 1, "To scan for more cooldowns,", nil, "CENTER", 3)
    self:SetCell(self:GetLineCount(), 1, "open and close the profession skills on your characters", nil, "CENTER", 3)

    -- self:SetLineTextColor(self:GetLineCount(), 1, 1, 1, 0.5)

end

--------------------
--- Wiring/LDB/QTip
--------------------

local ADDON, namespace = ...
local LibQTip = LibStub('LibQTip-1.0')
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobj = ldb:NewDataObject(ADDON, {
    type = "data source",
    text = "-"
})

local function OnRelease(self)
    LibQTip:Release(self.tooltip)
    self.tooltip = nil
end

local function anchor_OnEnter(self)
    if self.tooltip then
        LibQTip:Release(self.tooltip)
        self.tooltip = nil
    end

    local tooltip = LibQTip:Acquire(ADDON, 3, "LEFT", "LEFT")
    self.tooltip = tooltip
    tooltip.OnRelease = OnRelease
    tooltip.OnLeave = OnLeave
    tooltip:SetAutoHideDelay(.1, self)

    build_tooltip(tooltip)

    tooltip:SmartAnchorTo(self)

    tooltip:Show()
end

function dataobj:OnEnter()
    anchor_OnEnter(self)
end

--- Nothing to do. Needs to be defined for some display addons apparently
function dataobj:OnLeave()
end

local function set_label(self)
    dataobj.text = "Profession Cooldowns"
    local prof1, prof2 = GetProfessions()

    -- local prof_name, prof_icon, _, _, numAbilities, offset = GetProfessionInfo(prof1)

    -- -- print(prof_name, numAbilities, offset)
    -- print(GetProfessionInfo(prof1))
    -- print(GetProfessionInfo(prof2))

    -- local t = C_TradeSkillUI.GetAllRecipeIDs()
    -- for _i, recipeID in pairs(t) do
    --     local recipe_info = C_TradeSkillUI.GetRecipeInfo(recipeID)
    --     if recipe_info["learned"] then
    --         print(recipe_info["name"])
    --     end

    --     -- for k, v in pairs(C_TradeSkillUI.GetRecipeInfo(recipeID)) do
    --     --     print(k, v)
    --     -- end
    -- end

end

-- invisible frame for updating/hooking events
local f = CreateFrame("frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD") -- on login
f:SetScript("OnEvent", set_label)

local g = CreateFrame("frame")
g:RegisterEvent("TRADE_SKILL_CLOSE")
g:RegisterEvent("NEW_RECIPE_LEARNED")
g:SetScript("OnEvent", scan_for_recipes)
