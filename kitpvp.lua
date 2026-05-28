-- ==========================================
-- 1. CHAT COMMAND TO OPEN KIT SELECTION
-- ==========================================
minetest.register_chatcommand("kitpvp", {
	params = "",
	description = "Open the Kit Selection menu and clear your inventory.",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if player then
			local inv = player:get_inventory()
			if inv then
				-- Safely empty all inventory and armor lists
				local function clear_inventory(inv)
					if not inv then return end
					local function fill_empty(listname, size)
						if inv:get_list(listname) then
							local t = {}
							for i = 1, size do t[i] = ItemStack("") end
							inv:set_list(listname, t)
						end
					end
					fill_empty("craft", 9)
					fill_empty("craftpreview", 1)
					fill_empty("main", 32)
					fill_empty("hotbar", 8)
					fill_empty("armor", 4)
				end
				clear_inventory(inv)
			end
		end

		-- Display selection formspec UI
		minetest.show_formspec(name, "kitpvp:form",
			"size[8,9]" ..
			"label[0,0;Kit Selection]" ..
			"button[1,1;6,1;kit1;Pawn Kit]" ..
			"button[1,2;6,1;kit2;Crusher Kit]" ..
			"button[1,3;6,1;kit3;Spearman Kit]" ..
			"button[1,4;6,1;kit4;Archer Kit]" ..
			"button[1,5;6,1;kit_warrior;Heavy Kit]" ..
			"button[1,6;6,1;kit6;Barbarian]" ..
			"button[1,7;6,1;kit_crossbow_man;Crossbow Man]" ..
			"button_exit[1,8;6,1;exit;Exit]"
		)
	end
})

-- ==========================================
-- 2. HELPER FUNCTIONS (ENCHANTING & INVENTORY)
-- ==========================================

-- Safely applies enchants using Mineclonia's API layers
local function safe_enchant(stack, enchant_name, level)
	if not stack or stack:is_empty() then return stack end

	local name = stack.get_name and stack:get_name() or nil
	if not name or name == "" then return stack end

	if mcl_enchanting and mcl_enchanting.enchant then
		local ok, err = pcall(function() mcl_enchanting.enchant(stack, enchant_name, level) end)
		if ok then return stack end
		minetest.log("error", "mcl_enchanting.enchant failed: " .. tostring(err))
	end

	if mcl_enchanting and mcl_enchanting.set_enchanted_itemstring then
		local ench_table = { { name = enchant_name, level = level } }
		local ok, itemstr = pcall(function() return mcl_enchanting.set_enchanted_itemstring(name, ench_table) end)
		if ok and itemstr and type(itemstr) == "string" then
			local new_stack = ItemStack(itemstr)
			if not new_stack:is_empty() then return new_stack end
		else
			minetest.log("error", "mcl_enchanting.set_enchanted_itemstring failed or returned nil")
		end
	end

	return stack
end

-- Modified to accept direct items as separate parameters to completely eliminate indexing/bracket bugs
local function give_armor(inv, helmet_name, chest_name, leggings_name, boots_name, protection_level, curse_level)
	local curse = "curse_of_vanishing"
	local prot = "protection"
	
	if inv:get_list("armor") == nil then
		inv:set_list("armor", { ItemStack(""), ItemStack(""), ItemStack(""), ItemStack("") })
	end

	-- 1. HELMET -> Slot 1 (Top Left)
	if helmet_name and helmet_name ~= "" then
		local helmet_stack = ItemStack(helmet_name)
		if helmet_stack and not helmet_stack:is_empty() then
			if protection_level and protection_level > 0 then helmet_stack = safe_enchant(helmet_stack, prot, protection_level) end
			helmet_stack = safe_enchant(helmet_stack, curse, curse_level)
			inv:set_stack("armor", 1, helmet_stack)
		end
	end

	-- 2. CHESTPLATE -> Slot 2 (Bottom Left)
	if chest_name and chest_name ~= "" then
		local chest_stack = ItemStack(chest_name)
		if chest_stack and not chest_stack:is_empty() then
			if protection_level and protection_level > 0 then chest_stack = safe_enchant(chest_stack, prot, protection_level) end
			chest_stack = safe_enchant(chest_stack, curse, curse_level)
			inv:set_stack("armor", 2, chest_stack)
		end
	end

	-- 3. LEGGINGS -> Slot 3 (Top Right)
	if leggings_name and leggings_name ~= "" then
		local leggings_stack = ItemStack(leggings_name)
		if leggings_stack and not leggings_stack:is_empty() then
			if protection_level and protection_level > 0 then leggings_stack = safe_enchant(leggings_stack, prot, protection_level) end
			leggings_stack = safe_enchant(leggings_stack, curse, curse_level)
			inv:set_stack("armor", 3, leggings_stack)
		end
	end

	-- 4. BOOTS -> Slot 4 (Bottom Right)
	if boots_name and boots_name ~= "" then
		local boots_stack = ItemStack(boots_name)
		if boots_stack and not boots_stack:is_empty() then
			if protection_level and protection_level > 0 then boots_stack = safe_enchant(boots_stack, prot, protection_level) end
			boots_stack = safe_enchant(boots_stack, curse, curse_level)
			inv:set_stack("armor", 4, boots_stack)
		end
	end
end

-- ==========================================
-- 3. FORMSPEC SELECTION & TELEPORT PROCESSING
-- ==========================================
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "kitpvp:form" then return end
	local player_name = player:get_player_name()
	local inv = player:get_inventory()
	if not inv then return end

	-- close the formspec immediately
	minetest.close_formspec(player_name, "kitpvp:form")

	-- Cascade safety fallbacks down to engine config if spawn module fails
	local tp = nil
	if mcl_spawn and mcl_spawn.get_player_spawn_pos then
		tp = mcl_spawn.get_player_spawn_pos(player)
	end
	if not tp then
		tp = minetest.setting_get_pos("static_spawnpoint") or {x = 0, y = 20, z = 0}
	end

	-- Kit 1: Pawn Kit
	if fields.kit1 then
		give_armor(inv, 
			"mcl_armor:helmet_diamond", 
			"mcl_armor:chestplate_diamond", 
			"mcl_armor:leggings_diamond", 
			"mcl_armor:boots_diamond", 
			0, 1
		)

		local sword = ItemStack("mcl_tools:sword_diamond")
		sword = safe_enchant(sword, "sharpness", 4)
		sword = safe_enchant(sword, "curse_of_vanishing", 1)
		inv:add_item("main", sword)

		player:set_pos(tp)
		minetest.chat_send_player(player_name, "You have selected the Pawn Kit!")

	-- Kit 2: Crusher Kit
	elseif fields.kit2 then
		give_armor(inv, 
			"mcl_armor:helmet_netherite", 
			"mcl_armor:chestplate_netherite", 
			"mcl_armor:leggings_iron", 
			"mcl_armor:boots_netherite", 
			0, 1
		)

		local sword = ItemStack("mcl_tools:sword_iron")
		local mace = ItemStack("mcl_tools:mace")
		sword = safe_enchant(sword, "curse_of_vanishing", 1)
		sword = safe_enchant(sword, "sharpness", 3)
		mace = safe_enchant(mace, "curse_of_vanishing", 1)
		inv:add_item("main", sword)
		inv:add_item("main", mace)

		player:set_pos(tp)
		minetest.chat_send_player(player_name, "You have selected the Crusher Kit!")

	-- Kit 3: Spearman Kit
	elseif fields.kit3 then
		give_armor(inv, 
			"mcl_armor:helmet_iron", 
			"mcl_armor:chestplate_iron", 
			"mcl_armor:leggings_diamond", 
			"mcl_armor:boots_diamond", 
			2, 1
		)

		local sword = ItemStack("mcl_tools:sword_diamond")
		local trident = ItemStack("mcl_tridents:trident")
		if sword and not sword:is_empty() then
			sword = safe_enchant(sword, "curse_of_vanishing", 1)
			sword = safe_enchant(sword, "sharpness", 1)
			inv:add_item("main", sword)
		end
		if trident and not trident:is_empty() then
			trident = safe_enchant(trident, "curse_of_vanishing", 1)
			trident = safe_enchant(trident, "loyalty", 3)
			trident = safe_enchant(trident, "impaling", 2)
			inv:add_item("main", trident)
		end

		player:set_pos(tp)
		minetest.chat_send_player(player_name, "You have selected the Spearman Kit!")

	-- Kit 4: Archer Kit
	elseif fields.kit4 then
		give_armor(inv, 
			"mcl_armor:helmet_chainmail", 
			"mcl_armor:chestplate_chainmail", 
			"mcl_armor:leggings_chainmail", 
			"mcl_armor:boots_chainmail", 
			1, 1
		)

		local bow = ItemStack("mcl_bows:bow")
		bow = safe_enchant(bow, "power", 3)
		bow = safe_enchant(bow, "infinity", 1)
		bow = safe_enchant(bow, "curse_of_vanishing", 1)
		inv:add_item("main", bow)
		inv:add_item("main", ItemStack("mcl_bows:arrow 1"))

		player:set_pos(tp)
		minetest.chat_send_player(player_name, "You have selected the Archer Kit!")

	-- Kit 5: Heavy Kit
	elseif fields.kit_warrior then
		give_armor(inv, 
			"mcl_armor:helmet_netherite", 
			"mcl_armor:chestplate_netherite", 
			"mcl_armor:leggings_netherite", 
			"mcl_armor:boots_netherite", 
			2, 1
		)

		local axe = ItemStack("mcl_tools:axe_diamond")
		axe = safe_enchant(axe, "sharpness", 2)
		axe = safe_enchant(axe, "curse_of_vanishing", 1)
		inv:add_item("main", axe)

		player:set_pos(tp)
		minetest.chat_send_player(player_name, "You have selected the Heavy Kit!")

	-- Kit 6: Barbarian Kit
	elseif fields.kit6 then
		give_armor(inv, 
			"", 
			"mcl_armor:chestplate_iron", 
			"mcl_armor:leggings_leather", 
			"", 
			0, 1
		)

		local sword = ItemStack("mcl_tools:sword_stone")
		sword = safe_enchant(sword, "sharpness", 5)
		sword = safe_enchant(sword, "knockback", 2)
		sword = safe_enchant(sword, "curse_of_vanishing", 1)
		inv:add_item("main", sword)

		player:set_pos(tp)
		minetest.chat_send_player(player_name, "You have selected the Barbarian Kit!")

	-- Kit 7: Crossbow Man Kit
	elseif fields.kit_crossbow_man then
		give_armor(inv, 
			"mcl_armor:helmet_iron", 
			"mcl_armor:chestplate_iron", 
			"mcl_armor:leggings_chainmail", 
			"mcl_armor:boots_iron", 
			0, 1
		)

		local xbow = ItemStack("mcl_crossbows:crossbow")
		xbow = safe_enchant(xbow, "quick_charge", 2)
		xbow = safe_enchant(xbow, "multishot", 1)
		xbow = safe_enchant(xbow, "curse_of_vanishing", 1)
		inv:add_item("main", xbow)
		inv:add_item("main", ItemStack("mcl_bows:arrow 64"))

		player:set_pos(tp)
		minetest.chat_send_player(player_name, "You have selected the Crossbow Man Kit!")
	end
end)
