/**********************Mining drone**********************/
#define MINEDRONE_COLLECT 1
#define MINEDRONE_ATTACK 2

/mob/living/simple_animal/hostile/mining_drone
	name = "\improper Nanotrasen minebot"
	desc = "The instructions printed on the side read: This is a small robot used to support miners, can be set to search and collect loose ore, or to help fend off wildlife."
	gender = NEUTER
	icon = 'icons/mob/aibots.dmi'
	icon_state = "mining_drone"
	icon_living = "mining_drone"
	status_flags = CANSTUN|CANKNOCKDOWN|CANPUSH
	mouse_opacity = MOUSE_OPACITY_ICON
	faction = list("neutral")
	a_intent = INTENT_HARM
	atmos_requirements = IMMUNE_ATMOS_REQS
	minbodytemp = 0
	move_to_delay = 10
	health = 125
	maxHealth = 125
	melee_damage_lower = 15
	melee_damage_upper = 15
	obj_damage = 10
	environment_smash = ENVIRONMENT_SMASH_NONE
	check_friendly_fire = TRUE
	stop_automated_movement_when_pulled = TRUE
	attack_verb_continuous = "drills"
	attack_verb_simple = "drill"
	attack_sound = 'sound/weapons/circsawhit.ogg'
	sentience_type = SENTIENCE_MINEBOT
	custom_price = 800
	speak_emote = list("states")
	wanted_objects = list(
		/obj/item/stack/ore/diamond, /obj/item/stack/ore/gold,
		/obj/item/stack/ore/plasma, /obj/item/stack/ore/uranium, /obj/item/stack/ore/iron,
		/obj/item/stack/ore/hellstone, /obj/item/stack/ore/titanium)
	healable = 0
	loot = list(/obj/effect/decal/cleanable/robot_debris)
	del_on_death = TRUE
	light_system = MOVABLE_LIGHT
	light_range = 6
	light_on = FALSE
	var/mode = MINEDRONE_COLLECT
	var/obj/item/gun/energy/kinetic_accelerator/minebot/stored_gun

/mob/living/simple_animal/hostile/mining_drone/rockplanet


/mob/living/simple_animal/hostile/mining_drone/Initialize()
	. = ..()

	stored_gun = new(src)
	var/datum/action/innate/minedrone/toggle_light/toggle_light_action = new()
	toggle_light_action.Grant(src)
	var/datum/action/innate/minedrone/toggle_meson_vision/toggle_meson_vision_action = new()
	toggle_meson_vision_action.Grant(src)
	var/datum/action/innate/minedrone/toggle_mode/toggle_mode_action = new()
	toggle_mode_action.Grant(src)
	var/datum/action/innate/minedrone/dump_ore/dump_ore_action = new()
	dump_ore_action.Grant(src)
	var/obj/item/implant/radio/mining/imp = new(src)
	imp.implant(src)

	access_card = new /obj/item/card/id(src)
	var/datum/job/mining/M = new
	access_card.access = M.get_access()

	SetCollectBehavior()


/mob/living/simple_animal/hostile/mining_drone/Destroy()
	QDEL_NULL(stored_gun)
	for (var/datum/action/innate/minedrone/action in actions)
		qdel(action)
	return ..()

/mob/living/simple_animal/hostile/mining_drone/sentience_act()
	..()
	check_friendly_fire = 0

/mob/living/simple_animal/hostile/mining_drone/examine(mob/user)
	. = ..()
	var/t_He = p_they(TRUE)
	var/t_him = p_them()
	var/t_s = p_s()
	if(health < maxHealth)
		if(health >= maxHealth * 0.5)
			. += span_warning("[t_He] look[t_s] slightly dented.")
		else
			. += span_boldwarning("[t_He] look[t_s] severely dented!")
	. += {"<span class='notice'>Using a mining scanner on [t_him] will instruct [t_him] to drop stored ore. <b>[max(0, LAZYLEN(contents) - 1)] Stored Ore</b>\n
	Field repairs can be done with a welder."}
	if(stored_gun && stored_gun.max_mod_capacity)
		. += "<b>[stored_gun.get_remaining_mod_capacity()]%</b> mod capacity remaining."
		for(var/A in stored_gun.get_modkits())
			var/obj/item/borg/upgrade/modkit/M = A
			. += span_notice("There is \a [M] installed, using <b>[M.cost]%</b> capacity.")

/mob/living/simple_animal/hostile/mining_drone/welder_act(mob/living/user, obj/item/I)
	..()
	. = TRUE
	if(mode == MINEDRONE_ATTACK)
		to_chat(user, span_warning("[src] can't be repaired while in attack mode!"))
		return

	if(maxHealth == health)
		to_chat(user, span_info("[src] is at full integrity."))
		return

	if(I.use_tool(src, user, 0, volume=40))
		adjustBruteLoss(-15)
		to_chat(user, span_info("You repair some of the armor on [src]."))

/mob/living/simple_animal/hostile/mining_drone/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/mining_scanner) || istype(I, /obj/item/t_scanner/adv_mining_scanner))
		to_chat(user, span_info("You instruct [src] to drop any collected ore."))
		DropOre()
		return
	if(I.tool_behaviour == TOOL_CROWBAR || istype(I, /obj/item/borg/upgrade/modkit))
		I.melee_attack_chain(user, stored_gun, params)
		return
	..()

/mob/living/simple_animal/hostile/mining_drone/death()
	DropOre(0)
	if(stored_gun)
		for(var/obj/item/borg/upgrade/modkit/M in stored_gun.modkits)
			M.uninstall(stored_gun)
	deathmessage = "blows apart!"
	..()

/mob/living/simple_animal/hostile/mining_drone/attack_hand(mob/living/carbon/human/M)
	. = ..()
	if(.)
		return
	if(M.a_intent == INTENT_HELP)
		toggle_mode()
		switch(mode)
			if(MINEDRONE_COLLECT)
				to_chat(M, span_info("[src] has been set to search and store loose ore."))
			if(MINEDRONE_ATTACK)
				to_chat(M, span_info("[src] has been set to attack hostile wildlife."))
		return

/mob/living/simple_animal/hostile/mining_drone/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..()
	if(istype(mover, /obj/projectile/kinetic))
		var/obj/projectile/kinetic/projectile = mover
		if(projectile.kinetic_gun)
			if (locate(/obj/item/borg/upgrade/modkit/minebot_passthrough) in projectile.kinetic_gun.modkits)
				return TRUE
	else if(istype(mover, /obj/projectile/destabilizer))
		return TRUE

/mob/living/simple_animal/hostile/mining_drone/proc/SetCollectBehavior()
	mode = MINEDRONE_COLLECT
	vision_range = 9
	search_objects = 2
	wander = TRUE
	ranged = FALSE
	minimum_distance = 1
	retreat_distance = null
	icon_state = "mining_drone"
	to_chat(src, span_info("You are set to collect mode. You can now collect loose ore."))

/mob/living/simple_animal/hostile/mining_drone/proc/SetOffenseBehavior()
	mode = MINEDRONE_ATTACK
	vision_range = 7
	search_objects = 0
	wander = FALSE
	ranged = TRUE
	retreat_distance = 2
	minimum_distance = 1
	icon_state = "mining_drone_offense"
	to_chat(src, span_info("You are set to attack mode. You can now attack from range."))

/mob/living/simple_animal/hostile/mining_drone/AttackingTarget()
	if(istype(target, /obj/item/stack/ore) && mode == MINEDRONE_COLLECT)
		CollectOre()
		return
	if(isliving(target))
		SetOffenseBehavior()
	return ..()

/mob/living/simple_animal/hostile/mining_drone/OpenFire(atom/A)
	if(CheckFriendlyFire(A))
		return
	stored_gun.afterattack(A, src) //of the possible options to allow minebots to have KA mods, would you believe this is the best?

/mob/living/simple_animal/hostile/mining_drone/proc/CollectOre()
	for(var/obj/item/stack/ore/O in range(1, src))
		O.forceMove(src)

/mob/living/simple_animal/hostile/mining_drone/proc/DropOre(message = 1)
	if(!contents.len)
		if(message)
			to_chat(src, span_warning("You attempt to dump your stored ore, but you have none!"))
		return
	if(message)
		to_chat(src, span_notice("You dump your stored ore."))
	for(var/obj/item/stack/ore/O in contents)
		O.forceMove(drop_location())

/mob/living/simple_animal/hostile/mining_drone/adjustHealth(amount, updating_health = TRUE, forced = FALSE)
	if(mode != MINEDRONE_ATTACK && amount > 0)
		SetOffenseBehavior()
	. = ..()

/datum/action/innate/minedrone/toggle_meson_vision
	name = "Toggle Meson Vision"
	button_icon_state = "meson"

/datum/action/innate/minedrone/toggle_meson_vision/Activate()
	var/mob/living/simple_animal/hostile/mining_drone/user = owner
	if(user.sight & SEE_TURFS)
		user.sight &= ~SEE_TURFS
		user.lighting_alpha = initial(user.lighting_alpha)
	else
		user.sight |= SEE_TURFS
		user.lighting_alpha = LIGHTING_PLANE_ALPHA_MOSTLY_VISIBLE

	user.sync_lighting_plane_alpha()

	to_chat(user, span_notice("You toggle your meson vision [(user.sight & SEE_TURFS) ? "on" : "off"]."))


/mob/living/simple_animal/hostile/mining_drone/proc/toggle_mode()
	switch(mode)
		if(MINEDRONE_ATTACK)
			SetCollectBehavior()
		else
			SetOffenseBehavior()

//Actions for sentient minebots

/datum/action/innate/minedrone
	check_flags = AB_CHECK_CONSCIOUS
	icon_icon = 'icons/mob/actions/actions_mecha.dmi'
	background_icon_state = "bg_default"

/datum/action/innate/minedrone/toggle_light
	name = "Toggle Light"
	button_icon_state = "mech_lights_off"


/datum/action/innate/minedrone/toggle_light/Activate()
	var/mob/living/simple_animal/hostile/mining_drone/user = owner
	user.set_light_on(!user.light_on)
	to_chat(user, span_notice("You toggle your light [user.light_on ? "on" : "off"]."))


/datum/action/innate/minedrone/toggle_mode
	name = "Toggle Mode"
	button_icon_state = "mech_cycle_equip_off"

/datum/action/innate/minedrone/toggle_mode/Activate()
	var/mob/living/simple_animal/hostile/mining_drone/user = owner
	user.toggle_mode()

/datum/action/innate/minedrone/dump_ore
	name = "Dump Ore"
	button_icon_state = "mech_eject"

/datum/action/innate/minedrone/dump_ore/Activate()
	var/mob/living/simple_animal/hostile/mining_drone/user = owner
	user.DropOre()


/**********************Minebot Upgrades**********************/

//Melee

/obj/item/mine_bot_upgrade
	name = "minebot melee upgrade"
	desc = "A minebot upgrade."
	icon_state = "door_electronics"
	icon = 'icons/obj/module.dmi'

/obj/item/mine_bot_upgrade/afterattack(mob/living/simple_animal/hostile/mining_drone/M, mob/user, proximity)
	. = ..()
	if(!istype(M) || !proximity)
		return
	upgrade_bot(M, user)

/obj/item/mine_bot_upgrade/proc/upgrade_bot(mob/living/simple_animal/hostile/mining_drone/M, mob/user)
	if(M.melee_damage_upper != initial(M.melee_damage_upper))
		to_chat(user, span_warning("[src] already has a combat upgrade installed!"))
		return
	M.melee_damage_lower += 7
	M.melee_damage_upper += 7
	qdel(src)

//Health

/obj/item/mine_bot_upgrade/health
	name = "minebot armor upgrade"

/obj/item/mine_bot_upgrade/health/upgrade_bot(mob/living/simple_animal/hostile/mining_drone/M, mob/user)
	if(M.maxHealth != initial(M.maxHealth))
		to_chat(user, span_warning("[src] already has reinforced armor!"))
		return
	M.maxHealth += 45
	M.updatehealth()
	qdel(src)

#undef MINEDRONE_COLLECT
#undef MINEDRONE_ATTACK
