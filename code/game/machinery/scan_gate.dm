#define SCANGATE_NONE "Off"
#define SCANGATE_MINDSHIELD "Mindshield"
#define SCANGATE_NANITES "Nanites"
#define SCANGATE_DISEASE "Disease"
#define SCANGATE_GUNS "Guns"
#define SCANGATE_WANTED "Wanted"
#define SCANGATE_SPECIES "Species"

//god why cant this use the normal species defines
#define SCANGATE_HUMAN "human"
#define SCANGATE_LIZARD "lizard"
#define SCANGATE_FLY "fly"
#define SCANGATE_PLASMAMAN "plasma"
#define SCANGATE_MOTH "moth"
#define SCANGATE_JELLY "jelly"
#define SCANGATE_POD "pod"
#define SCANGATE_ZOMBIE "zombie"
#define SCANGATE_SPIDER "rachnid"
#define SCANGATE_IPC "ipc"
#define SCANGATE_SQUID "squid"
#define SCANGATE_ELZUOSE "elzuose"
#define SCANGATE_KEPORI "kepori"

/obj/machinery/scanner_gate
	name = "scanner gate"
	desc = "A gate able to perform mid-depth scans on any organisms who pass under it."
	icon = 'icons/obj/machines/scangate.dmi'
	icon_state = "scangate"
	use_power = IDLE_POWER_USE
	idle_power_usage = IDLE_DRAW_LOW
	circuit = /obj/item/circuitboard/machine/scanner_gate

	var/scanline_timer
	var/next_beep = 0 //avoids spam
	var/locked = FALSE
	var/scangate_mode = SCANGATE_NONE
	var/disease_threshold = DISEASE_SEVERITY_MINOR
	var/nanite_cloud = 1
	var/detect_species = SCANGATE_HUMAN
	var/reverse = FALSE //If true, signals if the scan returns false

/obj/machinery/scanner_gate/Initialize()
	. = ..()
	set_scanline("passive")
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/machinery/scanner_gate/examine(mob/user)
	. = ..()
	if(locked)
		. += span_notice("The control panel is ID-locked. Swipe a valid ID to unlock it.")
	else
		. += span_notice("The control panel is unlocked. Swipe an ID to lock it.")

/obj/machinery/scanner_gate/proc/on_entered(datum/source, atom/movable/AM)
	SIGNAL_HANDLER

	INVOKE_ASYNC(src, PROC_REF(auto_scan), AM)

/obj/machinery/scanner_gate/proc/auto_scan(atom/movable/AM)
	if(!(machine_stat & (BROKEN|NOPOWER)) && isliving(AM))
		perform_scan(AM)

/obj/machinery/scanner_gate/proc/set_scanline(type, duration)
	cut_overlays()
	deltimer(scanline_timer)
	add_overlay(type)
	if(duration)
		scanline_timer = addtimer(CALLBACK(src, PROC_REF(set_scanline), "passive"), duration, TIMER_STOPPABLE)

/obj/machinery/scanner_gate/attackby(obj/item/W, mob/user, params)
	var/obj/item/card/id/card = W.GetID()
	if(card)
		if(locked)
			if(allowed(user))
				locked = FALSE
				req_access = list()
				to_chat(user, span_notice("You unlock [src]."))
		else if(!(obj_flags & EMAGGED))
			to_chat(user, span_notice("You lock [src] with [W]."))
			var/list/access = W.GetAccess()
			req_access = access
			locked = TRUE
		else
			to_chat(user, span_warning("You try to lock [src] with [W], but nothing happens."))
	else
		return ..()

/obj/machinery/scanner_gate/emag_act(mob/user)
	if(obj_flags & EMAGGED)
		return
	locked = FALSE
	req_access = list()
	obj_flags |= EMAGGED
	to_chat(user, span_notice("You fry the ID checking system."))

/obj/machinery/scanner_gate/proc/perform_scan(mob/living/M)
	var/beep = FALSE
	switch(scangate_mode)
		if(SCANGATE_NONE)
			return
		if(SCANGATE_WANTED)
			if(ishuman(M))
				var/mob/living/carbon/human/H = M
				var/perpname = H.get_face_name(H.get_id_name())
				var/datum/data/record/R = find_record("name", perpname, GLOB.data_core.security)
				if(!R || (R.fields["criminal"] == "*Arrest*"))
					beep = TRUE
		if(SCANGATE_MINDSHIELD)
			if(HAS_TRAIT(M, TRAIT_MINDSHIELD))
				beep = TRUE
		if(SCANGATE_NANITES)
			if(SEND_SIGNAL(M, COMSIG_HAS_NANITES))
				if(nanite_cloud)
					var/datum/component/nanites/nanites = M.GetComponent(/datum/component/nanites)
					if(nanites && nanites.cloud_id == nanite_cloud)
						beep = TRUE
				else
					beep = TRUE
		if(SCANGATE_DISEASE)
			if(iscarbon(M))
				var/mob/living/carbon/C = M
				if(get_disease_severity_value(C.check_virus()) >= get_disease_severity_value(disease_threshold))
					beep = TRUE
		if(SCANGATE_SPECIES)
			if(ishuman(M))
				var/mob/living/carbon/human/H = M
				var/datum/species/scan_species = /datum/species/human
				switch(detect_species)
					if(SCANGATE_LIZARD)
						scan_species = /datum/species/lizard
					if(SCANGATE_FLY)
						scan_species = /datum/species/fly
					if(SCANGATE_PLASMAMAN)
						scan_species = /datum/species/plasmaman
					if(SCANGATE_MOTH)
						scan_species = /datum/species/moth
					if(SCANGATE_JELLY)
						scan_species = /datum/species/jelly
					if(SCANGATE_POD)
						scan_species = /datum/species/pod
					if(SCANGATE_ZOMBIE)
						scan_species = /datum/species/zombie
					if(SCANGATE_SPIDER)
						scan_species = /datum/species/spider
					if(SCANGATE_IPC)
						scan_species = /datum/species/ipc
					if(SCANGATE_ELZUOSE)
						scan_species = /datum/species/elzuose
					if(SCANGATE_KEPORI)
						scan_species = /datum/species/kepori
				if(is_species(H, scan_species))
					beep = TRUE
				if(detect_species == SCANGATE_ZOMBIE) //Can detect dormant zombies
					if(H.getorganslot(ORGAN_SLOT_ZOMBIE))
						beep = TRUE
		if(SCANGATE_GUNS)
			for(var/I in M.get_contents())
				if(istype(I, /obj/item/gun))
					beep = TRUE
					break

	if(reverse)
		beep = !beep
	if(beep)
		alarm_beep()
	else
		set_scanline("scanning", 10)

/obj/machinery/scanner_gate/proc/alarm_beep()
	if(next_beep <= world.time)
		next_beep = world.time + 20
		playsound(src, 'sound/machines/scanbuzz.ogg', 100, FALSE)
	var/mutable_appearance/alarm_display = mutable_appearance(icon, "alarm_light")
	flick_overlay_view(alarm_display, 2 SECONDS)
	set_scanline("alarm", 2 SECONDS)

/obj/machinery/scanner_gate/can_interact(mob/user)
	if(locked)
		return FALSE
	return ..()

/obj/machinery/scanner_gate/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ScannerGate", name)
		ui.open()

/obj/machinery/scanner_gate/ui_data()
	var/list/data = list()
	data["locked"] = locked
	data["scan_mode"] = scangate_mode
	data["reverse"] = reverse
	data["nanite_cloud"] = nanite_cloud
	data["disease_threshold"] = disease_threshold
	data["target_species"] = detect_species
	return data

/obj/machinery/scanner_gate/ui_act(action, params)
	. = ..()
	if(.)
		return

	switch(action)
		if("set_mode")
			var/new_mode = params["new_mode"]
			scangate_mode = new_mode
			. = TRUE
		if("toggle_reverse")
			reverse = !reverse
			. = TRUE
		if("toggle_lock")
			if(allowed(usr))
				locked = !locked
			. = TRUE
		if("set_disease_threshold")
			var/new_threshold = params["new_threshold"]
			disease_threshold = new_threshold
			. = TRUE
		if("set_nanite_cloud")
			var/new_cloud = text2num(params["new_cloud"])
			nanite_cloud = clamp(round(new_cloud, 1), 1, 100)
			. = TRUE
		//Some species are not scannable, like abductors (too unknown), androids (too artificial) or skeletons (too magic)
		if("set_target_species")
			var/new_species = params["new_species"]
			detect_species = new_species
			. = TRUE

#undef SCANGATE_NONE
#undef SCANGATE_MINDSHIELD
#undef SCANGATE_NANITES
#undef SCANGATE_DISEASE
#undef SCANGATE_GUNS
#undef SCANGATE_WANTED
#undef SCANGATE_SPECIES

#undef SCANGATE_HUMAN
#undef SCANGATE_LIZARD
#undef SCANGATE_FLY
#undef SCANGATE_PLASMAMAN
#undef SCANGATE_MOTH
#undef SCANGATE_JELLY
#undef SCANGATE_POD
#undef SCANGATE_ZOMBIE
#undef SCANGATE_SPIDER
#undef SCANGATE_IPC
#undef SCANGATE_SQUID
#undef SCANGATE_ELZUOSE
#undef SCANGATE_KEPORI
