/obj/item/transfer_valve
	icon = 'icons/obj/assemblies.dmi'
	name = "tank transfer valve"
	icon_state = "valve_1"
	item_state = "ttv"
	base_icon_state = "valve"
	lefthand_file = 'icons/mob/inhands/weapons/bombs_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/weapons/bombs_righthand.dmi'
	desc = "Regulates the transfer of air between two tanks."
	w_class = WEIGHT_CLASS_BULKY

	var/obj/item/tank/tank_one
	var/obj/item/tank/tank_two
	var/obj/item/assembly/attached_device
	var/datum/weakref/attacher_ref = null
	var/valve_open = FALSE
	var/toggle = TRUE

/obj/item/transfer_valve/Destroy()
	QDEL_NULL(tank_one)
	QDEL_NULL(tank_two)
	QDEL_NULL(attached_device)
	return ..()

/obj/item/transfer_valve/IsAssemblyHolder()
	return TRUE

/obj/item/transfer_valve/attackby(obj/item/item, mob/user, params)
	if(istype(item, /obj/item/tank))
		if(tank_one && tank_two)
			to_chat(user, span_warning("There are already two tanks attached, remove one first!"))
			return

		if(!tank_one)
			if(!user.transferItemToLoc(item, src))
				return
			tank_one = item
			to_chat(user, span_notice("You attach the tank to the transfer valve."))
		else if(!tank_two)
			if(!user.transferItemToLoc(item, src))
				return
			tank_two = item
			to_chat(user, span_notice("You attach the tank to the transfer valve."))

		update_appearance()
//TODO: Have this take an assemblyholder
	else if(isassembly(item))
		var/obj/item/assembly/A = item
		if(A.secured)
			to_chat(user, span_notice("The device is secured."))
			return
		if(attached_device)
			to_chat(user, span_warning("There is already a device attached to the valve, remove it first!"))
			return
		if(!user.transferItemToLoc(item, src))
			return
		attached_device = A
		to_chat(user, span_notice("You attach the [item] to the valve controls and secure it."))
		A.on_attach()
		A.holder = src
		A.toggle_secure()	//this calls update_appearance(), which calls update_appearance() on the holder (i.e. the bomb).
		log_bomber(user, "attached a [item.name] to a ttv -", src, null, FALSE)
		attacher_ref = WEAKREF(user)
	return

//These keep attached devices synced up, for example a TTV with a mouse trap being found in a bag so it's triggered, or moving the TTV with an infrared beam sensor to update the beam's direction.
/obj/item/transfer_valve/Move()
	. = ..()
	if(attached_device)
		attached_device.holder_movement()

/obj/item/transfer_valve/dropped()
	. = ..()
	if(attached_device)
		attached_device.dropped()

/obj/item/transfer_valve/on_found(mob/finder)
	if(attached_device)
		attached_device.on_found(finder)

//Triggers mousetraps
/obj/item/transfer_valve/attack_hand()
	. = ..()
	if(.)
		return
	if(attached_device)
		attached_device.attack_hand()

/obj/item/transfer_valve/proc/process_activation(obj/item/D)
	if(toggle)
		toggle = FALSE
		toggle_valve()
		addtimer(CALLBACK(src, PROC_REF(toggle_off)), 5)	//To stop a signal being spammed from a proxy sensor constantly going off or whatever

/obj/item/transfer_valve/proc/toggle_off()
	toggle = TRUE

/obj/item/transfer_valve/update_icon_state()
	icon_state = "[base_icon_state][(!tank_one && !tank_two && !attached_device) ? "_1" : null]"
	return ..()

/obj/item/transfer_valve/update_overlays()
	. = ..()
	if(tank_one)
		. += "[tank_one.icon_state]"

	if(!tank_two)
		underlays = null
	else
		var/mutable_appearance/J = mutable_appearance(icon, icon_state = "[tank_two.icon_state]")
		var/matrix/T = matrix()
		T.Translate(-13, 0)
		J.transform = T
		underlays = list(J)

	if(!attached_device)
		return

	. += "device"
	if(!istype(attached_device, /obj/item/assembly/infra))
		return
	var/obj/item/assembly/infra/sensor = attached_device
	if(sensor.on && sensor.visible)
		. += "proxy_beam"

/obj/item/transfer_valve/proc/merge_gases(datum/gas_mixture/target, change_volume = TRUE)
	var/target_self = FALSE
	if(!target || (target == tank_one.air_contents))
		target = tank_two.air_contents
	if(target == tank_two.air_contents)
		target_self = TRUE
	if(change_volume)
		if(!target_self)
			target.set_volume(target.return_volume() + tank_two.air_contents.return_volume())
		target.set_volume(target.return_volume() + tank_one.air_contents.return_volume())
	tank_one.air_contents.transfer_ratio_to(target, 1)
	if(!target_self)
		tank_two.air_contents.transfer_ratio_to(target, 1)

/obj/item/transfer_valve/proc/split_gases()
	if (!valve_open || !tank_one || !tank_two)
		return
	var/ratio1 = tank_one.air_contents.return_volume()/tank_two.air_contents.return_volume()
	tank_two.air_contents.transfer_ratio_to(tank_one.air_contents, ratio1)
	tank_two.air_contents.set_volume(tank_two.air_contents.return_volume() - tank_one.air_contents.return_volume())

/*
	Exadv1: I know this isn't how it's going to work, but this was just to check
	it explodes properly when it gets a signal (and it does).
*/
/obj/item/transfer_valve/proc/toggle_valve()
	if(!valve_open && tank_one && tank_two)
		valve_open = TRUE
		var/turf/bombturf = get_turf(src)

		var/attachment
		if(attached_device)
			if(istype(attached_device, /obj/item/assembly/signaler))
				attachment = "<A href='byond://?_src_=holder;[HrefToken()];secrets=list_signalers'>[attached_device]</A>"
			else
				attachment = attached_device

		var/admin_attachment_message
		var/attachment_message
		if(attachment)
			var/mob/attacher = attacher_ref.resolve()
			admin_attachment_message = " with [attachment] attached by [attacher ? ADMIN_LOOKUPFLW(attacher) : "Unknown"]"
			attachment_message = " with [attachment] attached by [attacher ? key_name_admin(attacher) : "Unknown"]"

		var/mob/bomber = get_mob_by_key(fingerprintslast)
		var/admin_bomber_message
		var/bomber_message
		if(bomber)
			admin_bomber_message = " - Last touched by: [ADMIN_LOOKUPFLW(bomber)]"
			bomber_message = " - Last touched by: [key_name_admin(bomber)]"

		var/admin_bomb_message = "Bomb valve opened in [ADMIN_VERBOSEJMP(bombturf)][admin_attachment_message][admin_bomber_message]"
		GLOB.bombers += admin_bomb_message
		message_admins(admin_bomb_message)
		log_game("Bomb valve opened in [AREACOORD(bombturf)][attachment_message][bomber_message]")

		merge_gases()
		for(var/i in 1 to 6)
			addtimer(CALLBACK(src, TYPE_PROC_REF(/atom, update_appearance)), 20 + (i - 1) * 10)

	else if(valve_open && tank_one && tank_two)
		split_gases()
		valve_open = FALSE
		update_appearance()
/*
	This doesn't do anything but the timer etc. expects it to be here
	eventually maybe have it update icon to show state (timer, prox etc.) like old bombs
*/
/obj/item/transfer_valve/proc/c_state()
	return

/obj/item/transfer_valve/ui_state(mob/user)
	return GLOB.hands_state

/obj/item/transfer_valve/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TransferValve", name)
		ui.open()

/obj/item/transfer_valve/ui_data(mob/user)
	var/list/data = list()
	data["tank_one"] = tank_one
	data["tank_two"] = tank_two
	data["attached_device"] = attached_device
	data["valve"] = valve_open
	return data

/obj/item/transfer_valve/ui_act(action, params)
	. = ..()
	if(.)
		return

	switch(action)
		if("tankone")
			if(tank_one)
				split_gases()
				valve_open = FALSE
				tank_one.forceMove(drop_location())
				tank_one = null
				. = TRUE
		if("tanktwo")
			if(tank_two)
				split_gases()
				valve_open = FALSE
				tank_two.forceMove(drop_location())
				tank_two = null
				. = TRUE
		if("toggle")
			toggle_valve()
			. = TRUE
		if("device")
			if(attached_device)
				attached_device.attack_self(usr)
				. = TRUE
		if("remove_device")
			if(attached_device)
				attached_device.on_detach()
				attached_device = null
				. = TRUE

	update_appearance()
