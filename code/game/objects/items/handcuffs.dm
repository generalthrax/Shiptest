/obj/item/restraints
	breakouttime = 600

/obj/item/restraints/Destroy()
	if(iscarbon(loc))
		var/mob/living/carbon/M = loc
		if(M.handcuffed == src)
			M.set_handcuffed(null)
			M.update_handcuffed()
			if(M.buckled && M.buckled.buckle_requires_restraints)
				M.buckled.unbuckle_mob(M)
		if(M.legcuffed == src)
			M.legcuffed = null
			M.update_inv_legcuffed()
	return ..()

//Handcuffs

/obj/item/restraints/handcuffs
	name = "handcuffs"
	desc = "Use this to keep prisoners in line."
	gender = PLURAL
	icon = 'icons/obj/items.dmi'
	icon_state = "handcuff"
	lefthand_file = 'icons/mob/inhands/equipment/security_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/security_righthand.dmi'
	flags_1 = CONDUCT_1
	slot_flags = ITEM_SLOT_BELT
	throwforce = 0
	w_class = WEIGHT_CLASS_SMALL
	throw_speed = 3
	throw_range = 5
	custom_materials = list(/datum/material/iron=500)
	breakouttime = 1 MINUTES
	armor = list("melee" = 0, "bullet" = 0, "laser" = 0, "energy" = 0, "bomb" = 0, "bio" = 0, "rad" = 0, "fire" = 50, "acid" = 50)
	var/cuffsound = 'sound/weapons/handcuffs.ogg'
	var/trashtype = null //for disposable cuffs

/obj/item/restraints/handcuffs/attack(mob/living/carbon/C, mob/living/user)
	if(!istype(C))
		return

	SEND_SIGNAL(C, COMSIG_CARBON_CUFF_ATTEMPTED, user)

	if(iscarbon(user) && (HAS_TRAIT(user, TRAIT_CLUMSY) && prob(50)))
		to_chat(user, span_warning("Uh... how do those things work?!"))
		apply_cuffs(user,user)
		return

	if(!C.handcuffed)
		if(C.canBeHandcuffed())
			C.visible_message(span_danger("[user] is trying to put [src.name] on [C]!"), \
								span_userdanger("[user] is trying to put [src.name] on you!"))

			playsound(loc, cuffsound, 30, TRUE, -2)
			log_combat(user, C, "attempted to handcuff")
			if(do_after(user, 3 SECONDS, C) && C.canBeHandcuffed())
				if(iscyborg(user))
					apply_cuffs(C, user, TRUE)
				else
					apply_cuffs(C, user)
				C.visible_message(span_notice("[user] handcuffs [C]."), \
									span_userdanger("[user] handcuffs you."))
				SSblackbox.record_feedback("tally", "handcuffs", 1, type)

				log_combat(user, C, "handcuffed")
			else
				to_chat(user, span_warning("You fail to handcuff [C]!"))
		else
			to_chat(user, span_warning("[C] doesn't have two hands..."))

/obj/item/restraints/handcuffs/proc/apply_cuffs(mob/living/carbon/target, mob/user, dispense = 0)
	if(target.handcuffed)
		return

	if(!user.temporarilyRemoveItemFromInventory(src) && !dispense)
		return

	var/obj/item/restraints/handcuffs/cuffs = src
	if(trashtype)
		cuffs = new trashtype()
	else if(dispense)
		cuffs = new type()

	cuffs.forceMove(target)
	target.set_handcuffed(cuffs)

	target.update_handcuffed()
	if(trashtype && !dispense)
		qdel(src)
	return

/obj/item/restraints/handcuffs/cable/sinew
	name = "sinew restraints"
	desc = "A pair of restraints fashioned from long strands of flesh."
	icon = 'icons/obj/mining.dmi'
	icon_state = "sinewcuff"
	item_state = "sinewcuff"
	custom_materials = null
	color = null

/obj/item/restraints/handcuffs/cable
	name = "cable restraints"
	desc = "Looks like some cables tied together. Could be used to tie something up."
	icon_state = "cuff"
	item_state = "coil"
	color = "#ff0000"
	lefthand_file = 'icons/mob/inhands/equipment/tools_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tools_righthand.dmi'
	custom_materials = list(/datum/material/iron=150, /datum/material/glass=75)
	breakouttime = 30 SECONDS
	cuffsound = 'sound/weapons/cablecuff.ogg'

/*WS - Smartwire Revert
/obj/item/restraints/handcuffs/cable/Initialize(mapload, param_color)
	. = ..()

	var/list/cable_colors = GLOB.cable_colors
	cable_color = param_color || cable_color || pick(cable_colors)
	if(cable_colors[cable_color])
		cable_color = cable_colors[cable_color]
	update_appearance()

/obj/item/restraints/handcuffs/cable/update_appearance()
	color = null
	add_atom_colour(cable_color, FIXED_COLOUR_PRIORITY)
*/

/obj/item/restraints/handcuffs/cable/red
	color = "#ff0000"

/obj/item/restraints/handcuffs/cable/yellow
	color = "#ffff00"

/obj/item/restraints/handcuffs/cable/blue
	color = "#1919c8"

/obj/item/restraints/handcuffs/cable/green
	color = "#00aa00"

/obj/item/restraints/handcuffs/cable/pink
	color = "#ff3ccd"

/obj/item/restraints/handcuffs/cable/orange
	color = "#ff8000"

/obj/item/restraints/handcuffs/cable/cyan
	color = "#00ffff"

/obj/item/restraints/handcuffs/cable/white
	color = null

/obj/item/restraints/handcuffs/alien
	icon_state = "handcuffAlien"

/obj/item/restraints/handcuffs/fake
	name = "fake handcuffs"
	desc = "Fake handcuffs meant for gag purposes."
	breakouttime = 1 SECONDS

/obj/item/restraints/handcuffs/cable/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/stack/rods))
		var/obj/item/stack/rods/R = I
		if (R.use(1))
			var/obj/item/wirerod/W = new /obj/item/wirerod
			remove_item_from_storage(user)
			user.put_in_hands(W)
			to_chat(user, span_notice("You wrap [src] around the top of [I]."))
			qdel(src)
		else
			to_chat(user, span_warning("You need one rod to make a wired rod!"))
			return
	else if(istype(I, /obj/item/stack/sheet/metal))
		var/obj/item/stack/sheet/metal/M = I
		if(M.get_amount() < 6)
			to_chat(user, span_warning("You need at least six metal sheets to make good enough weights!"))
			return
		to_chat(user, span_notice("You begin to apply [I] to [src]..."))
		if(do_after(user, 35, target = src))
			if(M.get_amount() < 6 || !M)
				return
			var/obj/item/restraints/legcuffs/bola/S = new /obj/item/restraints/legcuffs/bola
			M.use(6)
			user.put_in_hands(S)
			to_chat(user, span_notice("You make some weights out of [I] and tie them to [src]."))
			remove_item_from_storage(user)
			qdel(src)
	else
		return ..()

/obj/item/restraints/handcuffs/cable/zipties
	name = "zipties"
	desc = "Plastic, disposable zipties that can be used to restrain temporarily but are destroyed after use."
	icon_state = "cuff"
	lefthand_file = 'icons/mob/inhands/equipment/security_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/security_righthand.dmi'
	custom_materials = null
	breakouttime = 45 SECONDS
	trashtype = /obj/item/restraints/handcuffs/cable/zipties/used
	color = null

/obj/item/restraints/handcuffs/cable/zipties/used
	desc = "A pair of broken zipties."
	icon_state = "cuff_used"
	item_state = "cuff"

/obj/item/restraints/handcuffs/cable/zipties/used/attack()
	return

//Legcuffs

/obj/item/restraints/legcuffs
	name = "leg cuffs"
	desc = "Use this to keep prisoners in line."
	gender = PLURAL
	icon = 'icons/obj/items.dmi'
	icon_state = "handcuff"
	lefthand_file = 'icons/mob/inhands/equipment/security_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/security_righthand.dmi'
	flags_1 = CONDUCT_1
	throwforce = 0
	w_class = WEIGHT_CLASS_NORMAL
	slowdown = 7
	breakouttime = 30 SECONDS

/obj/item/restraints/legcuffs/beartrap
	name = "bear trap"
	throw_speed = 1
	throw_range = 1
	icon_state = "beartrap"
	desc = "A trap used to catch bears and other legged creatures."
	var/armed = 0
	var/trap_damage = 20

/obj/item/restraints/legcuffs/beartrap/goliath
	name = "tentacle mass"
	desc = "Ew."
	icon_state = "goliathtrap"
	flags_1 = NONE
	slowdown = 10
	breakouttime = 5 SECONDS
	item_flags = DROPDEL
	armed = 1
	trap_damage = 0

/obj/item/restraints/legcuffs/beartrap/Initialize()
	. = ..()
	update_appearance()

	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/item/restraints/legcuffs/beartrap/update_icon_state()
	icon_state = "[initial(icon_state)][armed]"
	return ..()

/obj/item/restraints/legcuffs/beartrap/attack_self(mob/user)
	. = ..()
	if(!ishuman(user) || user.stat != CONSCIOUS || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED))
		return
	armed = !armed
	update_appearance()
	to_chat(user, span_notice("[src] is now [armed ? "armed" : "disarmed"]"))

/obj/item/restraints/legcuffs/beartrap/proc/close_trap()
	armed = FALSE
	update_appearance()
	playsound(src, 'sound/effects/snap.ogg', 50, TRUE)

/obj/item/restraints/legcuffs/beartrap/hitby(atom/movable/AM, skipcatch, hitpush, blocked, datum/thrownthing/throwingdatum)
	if(armed)
		close_trap()
	..()

/obj/item/restraints/legcuffs/beartrap/proc/on_entered(datum/source, AM as mob|obj)
	SIGNAL_HANDLER
	if(armed && isturf(loc))
		if(isliving(AM))
			var/mob/living/L = AM
			var/snap = TRUE
			if(istype(L.buckled, /obj/vehicle))
				var/obj/vehicle/ridden_vehicle = L.buckled
				if(!ridden_vehicle.are_legs_exposed) //close the trap without injuring/trapping the rider if their legs are inside the vehicle at all times.
					close_trap()
					ridden_vehicle.visible_message(span_danger("[ridden_vehicle] triggers \the [src]."))
					return

			if(L.movement_type & (FLYING|FLOATING)) //don't close the trap if they're flying/floating over it.
				snap = FALSE

			var/def_zone = BODY_ZONE_CHEST
			if(snap && iscarbon(L))
				var/mob/living/carbon/C = L
				if(C.body_position == STANDING_UP)
					def_zone = pick(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
					if(!C.legcuffed && C.num_legs >= 2) //beartrap can't cuff your leg if there's already a beartrap or legcuffs, or you don't have two legs.
						C.legcuffed = src
						forceMove(C)
						C.update_equipment_speed_mods()
						C.update_inv_legcuffed()
						SSblackbox.record_feedback("tally", "handcuffs", 1, type)
			else if(snap && isanimal(L))
				var/mob/living/simple_animal/SA = L
				if(SA.mob_size <= MOB_SIZE_TINY) //don't close the trap if they're as small as a mouse.
					snap = FALSE
			if(snap)
				close_trap()
				L.visible_message(span_danger("[L] gets caught by \the [src]!"), \
						span_userdanger("You get caught by \the [src]!"))
				L.apply_damage(trap_damage, BRUTE, def_zone)

/obj/item/restraints/legcuffs/beartrap/energy
	name = "energy snare"
	armed = 1
	icon_state = "e_snare"
	trap_damage = 0
	breakouttime = 30
	item_flags = DROPDEL
	flags_1 = NONE

/obj/item/restraints/legcuffs/beartrap/energy/Initialize()
	. = ..()
	addtimer(CALLBACK(src, PROC_REF(dissipate)), 100)

/obj/item/restraints/legcuffs/beartrap/energy/proc/dissipate()
	if(!ismob(loc))
		do_sparks(1, TRUE, src)
		qdel(src)

/obj/item/restraints/legcuffs/beartrap/energy/attack_hand(mob/user)
	on_entered(src, user) //honk
	return ..()

/obj/item/restraints/legcuffs/beartrap/energy/cyborg
	breakouttime = 20 // Cyborgs shouldn't have a strong restraint

/obj/item/restraints/legcuffs/bola
	name = "bola"
	desc = "A restraining device designed to be thrown at the target. Upon connecting with said target, it will wrap around their legs, making it difficult for them to move quickly."
	icon_state = "bola"
	item_state = "bola"
	lefthand_file = 'icons/mob/inhands/weapons/thrown_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/weapons/thrown_righthand.dmi'
	breakouttime = 35//easy to apply, easy to break out of
	gender = NEUTER
	var/knockdown = 0

/obj/item/restraints/legcuffs/bola/throw_at(atom/target, range, speed, mob/thrower, spin=1, diagonals_first = 0, datum/callback/callback, gentle = FALSE, quickstart = TRUE)
	if(!..())
		return
	playsound(src.loc,'sound/weapons/bolathrow.ogg', 75, TRUE)

/obj/item/restraints/legcuffs/bola/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	if(..() || !iscarbon(hit_atom))//if it gets caught or the target can't be cuffed,
		return//abort
	ensnare(hit_atom)

/**
 * Attempts to legcuff someone with the bola
 *
 * Arguments:
 * * C - the carbon that we will try to ensnare
 */
/obj/item/restraints/legcuffs/bola/proc/ensnare(mob/living/carbon/C)
	if(!C.legcuffed && C.num_legs >= 2)
		visible_message(span_danger("\The [src] ensnares [C]!"))
		C.legcuffed = src
		forceMove(C)
		C.update_equipment_speed_mods()
		C.update_inv_legcuffed()
		SSblackbox.record_feedback("tally", "handcuffs", 1, type)
		to_chat(C, span_userdanger("\The [src] ensnares you!"))
		C.Knockdown(knockdown)
		playsound(src, 'sound/effects/snap.ogg', 50, TRUE)

/obj/item/restraints/legcuffs/bola/tactical//traitor variant
	name = "reinforced bola"
	desc = "A strong bola, made with a long steel chain. It looks heavy, enough so that it could trip somebody."
	icon_state = "bola_r"
	item_state = "bola_r"
	breakouttime = 70
	knockdown = 35

/obj/item/restraints/legcuffs/bola/energy //For Security
	name = "energy bola"
	desc = "A specialized hard-light bola designed to ensnare fleeing criminals and aid in arrests."
	icon_state = "ebola"
	item_state = "ebola"
	hitsound = 'sound/weapons/taserhit.ogg'
	w_class = WEIGHT_CLASS_SMALL
	breakouttime = 60

/obj/item/restraints/legcuffs/bola/energy/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	if(iscarbon(hit_atom))
		var/obj/item/restraints/legcuffs/beartrap/B = new /obj/item/restraints/legcuffs/beartrap/energy/cyborg(get_turf(hit_atom))
		B.on_entered(src, hit_atom)
		qdel(src)
	. = ..()

/obj/item/restraints/legcuffs/bola/gonbola
	name = "gonbola"
	desc = "Hey, if you have to be hugged in the legs by anything, it might as well be this little guy."
	icon_state = "gonbola"
	item_state = "bola_r"
	breakouttime = 300
	slowdown = 0
	var/datum/status_effect/gonbolaPacify/effectReference

/obj/item/restraints/legcuffs/bola/gonbola/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	. = ..()
	if(iscarbon(hit_atom))
		var/mob/living/carbon/C = hit_atom
		effectReference = C.apply_status_effect(STATUS_EFFECT_GONBOLAPACIFY)

/obj/item/restraints/legcuffs/bola/gonbola/dropped(mob/user)
	. = ..()
	if(effectReference)
		QDEL_NULL(effectReference)

/obj/item/restraints/legcuffs/bola/watcher //tribal bola for tribal lizards
	name = "watcher Bola"
	desc = "A Bola made from the stretchy sinew of fallen watchers."
	icon = 'icons/obj/items.dmi'
	icon_state = "bola_watcher"
	breakouttime = 45
