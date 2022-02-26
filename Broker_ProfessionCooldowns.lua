local ignored_spell_ids = {169080 -- gearspring parts
, 177054 -- secrets of draenor engineering
, 175880 -- secrets of draenor alchemy
, 156587 -- alchemical catalyst
}

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

local function should_track_recipe(recipe_id)
    local recipe_info = C_TradeSkillUI.GetRecipeInfo(recipe_id)
    if recipe_info == nil or not recipe_info["learned"] then
        return false
    end

    local _seconds_remaining, has_cooldown = C_TradeSkillUI.GetRecipeCooldown(recipe_id)
    if not has_cooldown then
        return false
    end

    for _i, ignored_spell_id in ipairs(ignored_spell_ids) do
        if ignored_spell_id == recipe_id then
            return false
        end
    end

    return true
end

local function get_profession_skill_line()
    local line_id, _name, _, _, _, parent_line_id, parent_name = C_TradeSkillUI.GetTradeSkillLine()
    if parent_line_id ~= nil then
        return parent_line_id
    end

    return line_id
end

local function get_qualified_name()
    local name, realm = UnitFullName("player")
    local qualified_name = name .. "-" .. realm
    return qualified_name
end

local function add_recipe_to_cache(recipe_id)
    print("Caching recipe", recipe_id)
    local recipe_info = C_TradeSkillUI.GetRecipeInfo(recipe_id)
    local seconds_left_on_cd = C_TradeSkillUI.GetRecipeCooldown(recipe_id)
    local qualified_name = get_qualified_name()

    if seconds_left_on_cd == nil then
        seconds_left_on_cd = -1
    end

    local recipe_to_store = {
        qualified_char_name = qualified_name,
        recipe_id = recipe_id,
        recipe_name = recipe_info["name"],
        cooldown_finished_date = seconds_left_on_cd + time(),
        profession_id = get_profession_skill_line()
    }

    if icbat_bpc_cross_character_cache[qualified_name] == nil then
        icbat_bpc_cross_character_cache[qualified_name] = {}
    end

    icbat_bpc_cross_character_cache[qualified_name][recipe_id] = recipe_to_store

    local _localized, canonical_class_name = UnitClass("player")
    icbat_bpc_character_class_name[qualified_name] = canonical_class_name
end

local function clear_profession_cache(qualified_name, profession_id)
    if icbat_bpc_cross_character_cache[qualified_name] == nil then
        return
    end

    print("clearing stuff: ", qualified_name, profession_id)
    for recipe_id, recipe_info in pairs(icbat_bpc_cross_character_cache[qualified_name]) do
        if recipe_info["profession_id"] == nil then
            icbat_bpc_cross_character_cache[qualified_name][recipe_id] = nil
        elseif recipe_info["profession_id"] == profession_id then
            icbat_bpc_cross_character_cache[qualified_name][recipe_id] = nil
        end
    end
end

local function scan_for_recipes()
    clear_profession_cache(get_qualified_name(), get_profession_skill_line())
    local recipes_in_open_profession = C_TradeSkillUI.GetAllRecipeIDs()

    for _i, recipeID in pairs(recipes_in_open_profession) do
        local recipe_info = C_TradeSkillUI.GetRecipeInfo(recipeID)

        if should_track_recipe(recipeID) then
            add_recipe_to_cache(recipeID)
        end
    end
end

local function flatten_table(cache_table)
    local output = {}
    local index = 1
    for qualified_char_name, recipe_to_cd in pairs(cache_table) do
        for recipe_id, stored_recipe in pairs(recipe_to_cd) do
            local cooldown_finished_date = stored_recipe["cooldown_finished_date"]
            local recipe_name = stored_recipe["recipe_name"]

            output[index] = {
                qualified_char_name = qualified_char_name,
                recipe_id = recipe_id,
                cooldown_finished_date = cooldown_finished_date,
                recipe_name = recipe_name
            }
            index = index + 1
        end
    end
    table.sort(output, function(a, b)
        if a["qualified_char_name"] ~= b["qualified_char_name"] then
            return a["qualified_char_name"] < b["qualified_char_name"]
        end

        return a["recipe_name"] < b["recipe_name"]
    end)
    return output
end

local function update_cooldown(_, _event, unit, _cast_guid, spell_id)
    if unit ~= "player" then
        return
    end

    if should_track_recipe(spell_id) then
        print("update via other hook")
        add_recipe_to_cache(spell_id)
    end
end

-------------
--- View Code
-------------
local function build_tooltip(self)
    self:AddHeader("") -- filled in later w/ colspan
    self:AddSeparator()

    local table = flatten_table(icbat_bpc_cross_character_cache)

    for i, table_entry in ipairs(table) do
        local qualified_char_name = table_entry["qualified_char_name"]
        local cooldown_finished_date = table_entry["cooldown_finished_date"]
        local recipe_name = table_entry["recipe_name"]
        local recipe_id = table_entry["recipe_id"]

        if cooldown_finished_date > time() then
            self:AddLine(Ambiguate(qualified_char_name, "all"), recipe_name, "Cooling Down")
            self:SetCellTextColor(self:GetLineCount(), 3, 1, 0.5, 0, 1)
        else
            self:AddLine(Ambiguate(qualified_char_name, "all"), recipe_name, "Ready")
            self:SetCellTextColor(self:GetLineCount(), 3, 0, 1, 0, 1)
        end

        local class_name = icbat_bpc_character_class_name[qualified_char_name]
        if class_name ~= nil then
            local rgb = C_ClassColor.GetClassColor(class_name)
            self:SetCellTextColor(self:GetLineCount(), 1, rgb.r, rgb.g, rgb.b, 1)
        end

        local function drop_from_cache()
            print(qualified_char_name, recipe_id)
            icbat_bpc_cross_character_cache[qualified_char_name][recipe_id] = nil
            for char, recipe_table in pairs(icbat_bpc_cross_character_cache) do
                for recipe_id, info in pairs(recipe_table) do
                    print(char, recipe_id, info)
                end
            end
        end

        self:SetLineScript(self:GetLineCount(), "OnMouseUp", drop_from_cache)
    end

    self:AddSeparator()
    self:AddLine("") -- filled in later w/ colspan
    self:AddLine("") -- filled in later w/ colspan

    -- lineNum, colNum, value[, font][, justification][, colSpan]
    self:SetCell(1, 1, "Profession Cooldowns", nil, "CENTER", 3)
    self:SetCell(self:GetLineCount() - 1, 1, "To scan for more cooldowns,", nil, "CENTER", 3)
    self:SetCell(self:GetLineCount(), 1, "open and close the profession skills on your characters", nil, "CENTER", 3)

    self:AddLine("") -- spacer
    self:AddLine("") -- filled in later w/ colspan
    self:SetCell(self:GetLineCount(), 1, "Clicking lines will remove it until re-added", nil, "CENTER", 3)
end

--------------------
--- Wiring/LDB/QTip
--------------------

local ADDON, namespace = ...
local LibQTip = LibStub('LibQTip-1.0')
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobj = ldb:NewDataObject(ADDON, {
    type = "data source",
    text = "Profession Cooldowns"
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

local green = "0000ff00"
local function coloredText(text, color, is_eligible)
    return "\124c" .. color .. text .. "\124r"
end

local function set_label()
    local cooldowns_available = 0
    local name, realm = UnitFullName("player")
    local qualified_name = name .. "-" .. realm

    for qualified_char_name, recipe_to_cd in pairs(icbat_bpc_cross_character_cache) do
        if qualified_char_name == qualified_name then
            for recipeID, stored_recipe in pairs(recipe_to_cd) do
                local cooldown_finished_date = stored_recipe["cooldown_finished_date"]

                if cooldown_finished_date < time() then
                    cooldowns_available = cooldowns_available + 1
                end
            end
        end
    end

    if cooldowns_available > 0 then
        dataobj.text = coloredText(cooldowns_available .. " cooldowns available!", green)
    else
        dataobj.text = "Profession Cooldowns"
    end
end

-- invisible frame for updating/hooking events
local f = CreateFrame("frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD") -- on login
f:SetScript("OnEvent", set_label)

local g = CreateFrame("frame")
g:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
g:RegisterEvent("NEW_RECIPE_LEARNED")
g:SetScript("OnEvent", scan_for_recipes)

local h = CreateFrame("frame")
h:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
h:SetScript("OnEvent", update_cooldown)
