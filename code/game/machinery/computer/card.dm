

//Keeps track of the time for the ID console. Having it as a global variable prevents people from dismantling/reassembling it to
//increase the slots of many jobs.
GLOBAL_VAR_INIT(time_last_changed_position, 0)

#define JOB_ALLOWED 1
#define JOB_COOLDOWN -2
#define JOB_MAX_POSITIONS -1 // Trying to reduce the number of slots below that of current holders of that job, or trying to open more slots than allowed
#define JOB_DENIED 0

#define UNAUTHENTICATED 0
#define AUTHENTICATED_DEPARTMENT 1
#define AUTHENTICATED_ALL 2

/obj/machinery/computer/card
	name = "identification console"
	desc = "You can use this to manage jobs and ID access."
	icon_screen = "id"
	icon_keyboard = "id_key"
	req_one_access = list(ACCESS_HEADS, ACCESS_CHANGE_IDS)
	circuit = /obj/item/circuitboard/computer/card
	light_color = LIGHT_COLOR_BLUE
	var/mode = 0
	var/printing = null
	var/target_dept = 0 //Which department this computer has access to. 0=all departments

	//Cooldown for closing positions in seconds
	//if set to -1: No cooldown... probably a bad idea
	//if set to 0: Not able to close "original" positions. You can only close positions that you have opened before
	var/change_position_cooldown = 30
	//Jobs you cannot open new positions for
	var/list/blacklisted = list(
		"AI",
		"Assistant",
		"Cyborg",
		"Captain",
		"Head of Personnel",
		"Head of Security",
		"Chief Engineer",
		"Research Director",
		"Chief Medical Officer",
		"Brig Physician",
		"SolGov Representative",		//WS Edit - SolGov Rep
		"Prisoner")

	//The scaling factor of max total positions in relation to the total amount of people on board the station in %
	var/max_relative_positions = 30 //30%: Seems reasonable, limit of 6 @ 20 players

	//This is used to keep track of opened positions for jobs to allow instant closing
	//Assoc array: "JobName" = (int)<Opened Positions>
	var/list/opened_positions = list()
	var/obj/item/card/id/inserted_scan_id
	var/obj/item/card/id/inserted_modify_id
	var/list/region_access = null

	COOLDOWN_DECLARE(silicon_access_print_cooldown)

/obj/machinery/computer/card/retro
	icon = 'icons/obj/machines/retro_computer.dmi'
	icon_state = "computer-retro"
	deconpath = /obj/structure/frame/computer/retro

/obj/machinery/computer/card/solgov
	icon = 'icons/obj/machines/retro_computer.dmi'
	icon_state = "computer-solgov"
	deconpath = /obj/structure/frame/computer/solgov

/obj/machinery/computer/card/proc/get_jobs()
	return get_all_jobs()

/obj/machinery/computer/card/centcom/get_jobs()
	return get_all_centcom_jobs()

/obj/machinery/computer/card/Initialize()
	. = ..()
	change_position_cooldown = CONFIG_GET(number/id_console_jobslot_delay)

/obj/machinery/computer/card/examine(mob/user)
	. = ..()
	if(inserted_scan_id || inserted_modify_id)
		. += span_notice("Alt-click to eject the ID card.")

/obj/machinery/computer/card/attackby(obj/I, mob/user, params)
	if(isidcard(I))
		if(check_access(I) && !inserted_scan_id)
			if(id_insert(user, I, inserted_scan_id))
				inserted_scan_id = I
				updateUsrDialog()
		else if(id_insert(user, I, inserted_modify_id))
			inserted_modify_id = I
			updateUsrDialog()
	else
		return ..()

/obj/machinery/computer/card/Destroy()
	if(inserted_scan_id)
		qdel(inserted_scan_id)
		inserted_scan_id = null
	if(inserted_modify_id)
		qdel(inserted_modify_id)
		inserted_modify_id = null
	return ..()

/obj/machinery/computer/card/handle_atom_del(atom/A)
	..()
	if(A == inserted_scan_id)
		inserted_scan_id = null
		updateUsrDialog()
	if(A == inserted_modify_id)
		inserted_modify_id = null
		updateUsrDialog()

/obj/machinery/computer/card/on_deconstruction()
	if(inserted_scan_id)
		inserted_scan_id.forceMove(drop_location())
		inserted_scan_id = null
	if(inserted_modify_id)
		inserted_modify_id.forceMove(drop_location())
		inserted_modify_id = null

//Check if you can't open a new position for a certain job
/obj/machinery/computer/card/proc/job_blacklisted(jobtitle)
	return (jobtitle in blacklisted)

/obj/machinery/computer/card/proc/id_insert(mob/user, obj/item/inserting_item, obj/item/target)
	var/obj/item/card/id/card_to_insert = inserting_item
	var/holder_item = FALSE

	if(!isidcard(card_to_insert))
		card_to_insert = inserting_item.RemoveID()
		holder_item = TRUE

	if(!card_to_insert || !user.transferItemToLoc(card_to_insert, src))
		return FALSE

	if(target)
		if(holder_item && inserting_item.InsertID(target))
			playsound(src, 'sound/machines/terminal_insert_disc.ogg', 50, FALSE)
		else
			id_eject(user, target)

	user.visible_message(span_notice("[user] inserts \the [card_to_insert] into \the [src]."),
						span_notice("You insert \the [card_to_insert] into \the [src]."))
	playsound(src, 'sound/machines/terminal_insert_disc.ogg', 50, FALSE)
	updateUsrDialog()
	return TRUE

/obj/machinery/computer/card/proc/id_eject(mob/user, obj/target)
	if(!target)
		to_chat(user, span_warning("That slot is empty!"))
		return FALSE
	else
		target.forceMove(drop_location())
		if(!issilicon(user) && Adjacent(user))
			user.put_in_hands(target)
		user.visible_message(span_notice("[user] gets \the [target] from \the [src]."), \
							span_notice("You get \the [target] from \the [src]."))
		playsound(src, 'sound/machines/terminal_insert_disc.ogg', 50, FALSE)
		updateUsrDialog()
		return TRUE

/obj/machinery/computer/card/AltClick(mob/user)
	..()
	if(!user.canUseTopic(src, !issilicon(user)) || !is_operational)
		return
	if(inserted_modify_id)
		if(id_eject(user, inserted_modify_id))
			inserted_modify_id = null
			updateUsrDialog()
			return
	if(inserted_scan_id)
		if(id_eject(user, inserted_scan_id))
			inserted_scan_id = null
			updateUsrDialog()
			return

/obj/machinery/computer/card/ui_interact(mob/user)
	. = ..()
	var/list/dat = list()
	if (mode == 1) // accessing crew manifest
		dat += "<tt><b>Crew Manifest:</b><br>Please use security record computer to modify entries.<br><br>"
		for(var/datum/data/record/t in sortRecord(GLOB.data_core.general))
			dat += {"[t.fields["name"]] - [t.fields["rank"]]<br>"}
		dat += "<a href='byond://?src=[REF(src)];choice=print'>Print</a><br><br><a href='byond://?src=[REF(src)];choice=mode;mode_target=0'>Access ID modification console.</a><br></tt>"

	else
		var/list/header = list()

		var/scan_name = inserted_scan_id ? html_encode(inserted_scan_id.name) : "--------"
		var/target_name = inserted_modify_id ? html_encode(inserted_modify_id.name) : "--------"
		var/target_owner = (inserted_modify_id && inserted_modify_id.registered_name) ? html_encode(inserted_modify_id.registered_name) : "--------"
		var/target_rank = (inserted_modify_id && inserted_modify_id.assignment) ? html_encode(inserted_modify_id.assignment) : "Unassigned"
		var/target_age = (inserted_modify_id && inserted_modify_id.registered_age) ? html_encode(inserted_modify_id.registered_age) : "--------"
		var/datum/overmap/ship/controlled/ship = SSshuttle.get_ship(src)
		var/target_ship_access = (inserted_modify_id && inserted_modify_id.has_ship_access(ship))

		if(!authenticated)
			header += {"<br><i>Please insert the cards into the slots</i><br>
				Target: <a href='byond://?src=[REF(src)];choice=inserted_modify_id'>[target_name]</a><br>
				Confirm Identity: <a href='byond://?src=[REF(src)];choice=inserted_scan_id'>[scan_name]</a><br>"}
		else
			header += {"<div align='center'><br>
				Target: <a href='byond://?src=[REF(src)];choice=inserted_modify_id'>Remove [target_name]</a> ||
				Confirm Identity: <a href='byond://?src=[REF(src)];choice=inserted_scan_id'>Remove [scan_name]</a><br>
				<a href='byond://?src=[REF(src)];choice=mode;mode_target=1'>Access Crew Manifest</a><br>
				Unique Ship Access: [ship.unique_ship_access?"Enabled":"Disabled"] <a href='byond://?src=[REF(src)];choice=toggle_unique_ship_access'>[ship.unique_ship_access?"Disable":"Enable"]</a><br>
				Print Silicon Access Chip <a href='byond://?src=[REF(src)];choice=print_silicon_access_chip'>Print</a></div>
				<a href='byond://?src=[REF(src)];choice=logout'>Log Out</a></div>"}

		header += "<hr>"

		var/body

		if (authenticated && inserted_modify_id)
			var/list/carddesc = list()
			var/list/jobs = list()
			if (authenticated == AUTHENTICATED_ALL)
				var/list/jobs_all = list()
				for(var/job in (list("Unassigned") + get_jobs() + "Custom"))
					jobs_all += "<a href='byond://?src=[REF(src)];choice=assign;assign_target=[job]'>[replacetext(job, " ", "&nbsp;")]</a> " //make sure there isn't a line break in the middle of a job
				carddesc += {"<script type="text/javascript">
									function markRed(){
										var nameField = document.getElementById('namefield');
										nameField.style.backgroundColor = "#FFDDDD";
									}
									function markGreen(){
										var nameField = document.getElementById('namefield');
										nameField.style.backgroundColor = "#DDFFDD";
									}
									function showAll(){
										var allJobsSlot = document.getElementById('alljobsslot');
										allJobsSlot.innerHTML = "<a href='#' onclick='hideAll()'>hide</a><br>"+ "[jobs_all.Join()]";
									}
									function hideAll(){
										var allJobsSlot = document.getElementById('alljobsslot');
										allJobsSlot.innerHTML = "<a href='#' onclick='showAll()'>show</a>";
									}
								</script>"}
				carddesc += {"<form name='cardcomp' action='?src=[REF(src)]' method='get'>
					<input type='hidden' name='src' value='[REF(src)]'>
					<input type='hidden' name='choice' value='reg'>
					<b>registered name:</b> <input type='text' id='namefield' name='reg' value='[target_owner]' style='width:250px; background-color:white;' onchange='markRed()'>
					<b>registered age:</b> <input type='number' id='namefield' name='setage' value='[target_age]' style='width:50px; background-color:white;' onchange='markRed()'>
					<input type='submit' value='Submit' onclick='markGreen()'>
					</form>
					<b>has ship access: [target_ship_access?"granted":"denied"]</b> <a href='byond://?src=[REF(src)];choice=toggle_id_ship_access'>[target_ship_access?"Deny":"Grant"]</a>
					<b>Assignment:</b> "}

				jobs += "<span id='alljobsslot'><a href='#' onclick='showAll()'>[target_rank]</a></span>" //CHECK THIS

			else
				carddesc += "<b>registered_name:</b> [target_owner]</span>"
				jobs += "<b>Assignment:</b> [target_rank] (<a href='byond://?src=[REF(src)];choice=demote'>Demote</a>)</span>"

			var/list/accesses = list()
			if(istype(src, /obj/machinery/computer/card/centcom)) // REE
				accesses += "<h5>Central Command:</h5>"
				for(var/A in get_all_centcom_access())
					if(A in inserted_modify_id.access)
						accesses += "<a href='byond://?src=[REF(src)];choice=access;access_target=[A];allowed=0'><font color=\"6bc473\">[replacetext(get_centcom_access_desc(A), " ", "&nbsp")]</font></a> "
					else
						accesses += "<a href='byond://?src=[REF(src)];choice=access;access_target=[A];allowed=1'>[replacetext(get_centcom_access_desc(A), " ", "&nbsp")]</a> "
			else
				accesses += {"<div align='center'><b>Access</b></div>
					<table style='width:100%'>
					<tr>"}
				for(var/i = 1; i <= 7; i++)
					if(authenticated == AUTHENTICATED_DEPARTMENT && !(i in region_access))
						continue
					accesses += "<td style='width:14%'><b>[get_region_accesses_name(i)]:</b></td>"
				accesses += "</tr><tr>"
				for(var/i = 1; i <= 7; i++)
					if(authenticated == AUTHENTICATED_DEPARTMENT && !(i in region_access))
						continue
					accesses += "<td style='width:14%' valign='top'>"
					for(var/A in get_region_accesses(i))
						if(A in inserted_modify_id.access)
							accesses += "<a href='byond://?src=[REF(src)];choice=access;access_target=[A];allowed=0'><font color=\"6bc473\">[replacetext(get_access_desc(A), " ", "&nbsp")]</font></a> "
						else
							accesses += "<a href='byond://?src=[REF(src)];choice=access;access_target=[A];allowed=1'>[replacetext(get_access_desc(A), " ", "&nbsp")]</a> "
						accesses += "<br>"
					accesses += "</td>"
				accesses += "</tr></table>"
			body = "[carddesc.Join()]<br>[jobs.Join()]<br><br>[accesses.Join()]<hr>" //CHECK THIS

		else if (!authenticated)
			body = {"<a href='byond://?src=[REF(src)];choice=auth'>Log In</a><br><hr>
				<a href='byond://?src=[REF(src)];choice=mode;mode_target=1'>Access Crew Manifest</a><br><hr>"}

		dat = list("<tt>", header.Join(), body, "<br></tt>")
	var/datum/browser/popup = new(user, "id_com", src.name, 900, 620)
	popup.set_content(dat.Join())
	popup.open()

/obj/machinery/computer/card/Topic(href, href_list)
	if(..())
		return

	if(!usr.canUseTopic(src, !issilicon(usr)) || !is_operational)
		usr.unset_machine()
		usr << browse(null, "window=id_com")
		return

	usr.set_machine(src)
	switch(href_list["choice"])
		if ("inserted_modify_id")
			if(inserted_modify_id && !usr.get_active_held_item())
				if(id_eject(usr, inserted_modify_id))
					inserted_modify_id = null
					updateUsrDialog()
					return
			if(usr.get_id_in_hand())
				var/obj/item/held_item = usr.get_active_held_item()
				var/obj/item/card/id/id_to_insert = held_item.GetID()
				if(id_insert(usr, held_item, inserted_modify_id))
					inserted_modify_id = id_to_insert
					updateUsrDialog()
		if ("inserted_scan_id")
			if(inserted_scan_id && !usr.get_active_held_item())
				if(id_eject(usr, inserted_scan_id))
					inserted_scan_id = null
					updateUsrDialog()
					return
			if(usr.get_id_in_hand())
				var/obj/item/held_item = usr.get_active_held_item()
				var/obj/item/card/id/id_to_insert = held_item.GetID()
				if(id_insert(usr, held_item, inserted_scan_id))
					inserted_scan_id = id_to_insert
					updateUsrDialog()
		if ("auth")
			if ((!(authenticated) && (inserted_scan_id || issilicon(usr)) || mode))
				if (check_access(inserted_scan_id))
					region_access = list()
					if(ACCESS_CHANGE_IDS in inserted_scan_id.access)
						if(target_dept)
							region_access |= target_dept
							authenticated = AUTHENTICATED_DEPARTMENT
						else
							authenticated = AUTHENTICATED_ALL
						playsound(src, 'sound/machines/terminal_on.ogg', 50, FALSE)

					else
						if((ACCESS_HOP in inserted_scan_id.access) && ((target_dept==1) || !target_dept))
							region_access |= 1
							region_access |= 6
						if((ACCESS_HOS in inserted_scan_id.access) && ((target_dept==2) || !target_dept))
							region_access |= 2
						if((ACCESS_CMO in inserted_scan_id.access) && ((target_dept==3) || !target_dept))
							region_access |= 3
						if((ACCESS_RD in inserted_scan_id.access) && ((target_dept==4) || !target_dept))
							region_access |= 4
						if((ACCESS_CE in inserted_scan_id.access) && ((target_dept==5) || !target_dept))
							region_access |= 5
						if(region_access)
							authenticated = AUTHENTICATED_DEPARTMENT
			else if ((!(authenticated) && issilicon(usr)) && (!inserted_modify_id))
				to_chat(usr, span_warning("You can't modify an ID without an ID inserted to modify! Once one is in the modify slot on the computer, you can log in."))
		if ("logout")
			region_access = null
			authenticated = 0
			playsound(src, 'sound/machines/terminal_off.ogg', 50, FALSE)

		if("access")
			if(href_list["allowed"])
				if(authenticated)
					var/access_type = text2num(href_list["access_target"])
					var/access_allowed = text2num(href_list["allowed"])
					if(access_type in (istype(src, /obj/machinery/computer/card/centcom)?get_all_centcom_access() : get_all_accesses()))
						inserted_modify_id.access -= access_type
						if(access_allowed == 1)
							inserted_modify_id.access += access_type
						playsound(src, "terminal_type", 50, FALSE)
		if ( "toggle_id_ship_access" )
			if (authenticated == AUTHENTICATED_ALL)
				var/datum/overmap/ship/controlled/ship = SSshuttle.get_ship(src)
				if (inserted_modify_id.has_ship_access(ship))
					inserted_modify_id.remove_ship_access(ship)
				else
					inserted_modify_id.add_ship_access(ship)
				playsound(src, "terminal_type", 50, FALSE)

		if ( "toggle_unique_ship_access" )
			if (authenticated == AUTHENTICATED_ALL)
				var/datum/overmap/ship/controlled/ship = SSshuttle.get_ship(src)
				ship.unique_ship_access = !ship.unique_ship_access
				playsound(src, "terminal_type", 50, FALSE)

		if ( "print_silicon_access_chip" )
			if (authenticated == AUTHENTICATED_ALL)
				if(!COOLDOWN_FINISHED(src, silicon_access_print_cooldown))
					say("Printer unavailable. Please allow a short time before attempting to print.")
					return
				var/obj/item/borg/upgrade/ship_access_chip/chip = new(get_turf(src))
				chip.ship = SSshuttle.get_ship(src)
				playsound(src, "terminal_type", 50, FALSE)
				COOLDOWN_START(src, silicon_access_print_cooldown, 10 SECONDS)

		if ("assign")
			if (authenticated == AUTHENTICATED_ALL)
				var/t1 = href_list["assign_target"]
				if(t1 == "Custom")
					var/newJob = reject_bad_text(input("Enter a custom job assignment.", "Assignment", inserted_modify_id ? inserted_modify_id.assignment : "Unassigned"), MAX_NAME_LEN)
					if(newJob)
						t1 = newJob

				else if(t1 == "Unassigned")
					inserted_modify_id.access -= get_all_accesses()

				else
					var/datum/job/jobdatum
					for(var/jobtype in typesof(/datum/job))
						var/datum/job/J = new jobtype
						if(ckey(J.name) == ckey(t1))
							jobdatum = J
							updateUsrDialog()
							break
					if(!jobdatum)
						to_chat(usr, span_alert("No log exists for this job."))
						updateUsrDialog()
						return

					inserted_modify_id.access = (istype(src, /obj/machinery/computer/card/centcom) ? get_centcom_access(t1) : jobdatum.get_access())
				if (inserted_modify_id)
					inserted_modify_id.assignment = t1
					playsound(src, 'sound/machines/terminal_prompt_confirm.ogg', 50, FALSE)
		if ("demote")
			if(ACCESS_CHANGE_IDS in inserted_scan_id.access)
				inserted_modify_id.assignment = "Unassigned"
				playsound(src, 'sound/machines/terminal_prompt_confirm.ogg', 50, FALSE)
			else
				to_chat(usr, span_alert("You are not authorized to demote this position."))
		if ("reg")
			if (authenticated)
				var/t2 = inserted_modify_id
				if ((authenticated && inserted_modify_id == t2 && (in_range(src, usr) || issilicon(usr)) && isturf(loc)))
					var/newAge = text2num(href_list["setage"])|null
					if(newAge && isnum(newAge))
						inserted_modify_id.registered_age = newAge
						playsound(src, 'sound/machines/terminal_prompt_confirm.ogg', 50, FALSE)
					else if(!isnull(newAge))
						to_chat(usr, span_alert("Invalid age entered- age not updated."))
						updateUsrDialog()

					var/newName = reject_bad_name(href_list["reg"])
					if(newName)
						inserted_modify_id.registered_name = newName
						playsound(src, 'sound/machines/terminal_prompt_confirm.ogg', 50, FALSE)
					else
						to_chat(usr, span_alert("Invalid name entered."))
						updateUsrDialog()
						return
		if ("mode")
			mode = text2num(href_list["mode_target"])

		if("return")
			//DISPLAY MAIN MENU
			mode = 3;
			playsound(src, "terminal_type", 25, FALSE)

		if ("print")
			if (!(printing))
				printing = 1
				sleep(50)
				var/obj/item/paper/printed_paper = new /obj/item/paper(loc)
				var/t1 = "<B>Crew Manifest:</B><BR>"
				for(var/datum/data/record/t in sortRecord(GLOB.data_core.general))
					t1 += t.fields["name"] + " - " + t.fields["rank"] + "<br>"
				printed_paper.add_raw_text(t1)
				printed_paper.name = "paper- 'Crew Manifest'"
				printing = null
				playsound(src, 'sound/machines/terminal_insert_disc.ogg', 50, FALSE)
	if (inserted_modify_id)
		inserted_modify_id.update_label()
	updateUsrDialog()

/obj/machinery/computer/card/centcom
	name = "\improper CentCom identification console"
	icon_screen = "idcentcom"
	circuit = /obj/item/circuitboard/computer/card/centcom
	req_access = list(ACCESS_CENT_CAPTAIN)

/obj/machinery/computer/card/minor
	name = "department management console"
	desc = "You can use this to change ID's for specific departments."
	icon_screen = "idminor"
	circuit = /obj/item/circuitboard/computer/card/minor

/obj/machinery/computer/card/minor/Initialize()
	. = ..()
	var/obj/item/circuitboard/computer/card/minor/typed_circuit = circuit
	if(target_dept)
		typed_circuit.target_dept = target_dept
	else
		target_dept = typed_circuit.target_dept
	var/list/dept_list = list("general","security","medical","science","engineering")
	name = "[dept_list[target_dept]] department console"

/obj/machinery/computer/card/minor/hos
	target_dept = 2
	icon_screen = "idhos"

	light_color = COLOR_SOFT_RED

/obj/machinery/computer/card/minor/cmo
	target_dept = 3
	icon_screen = "idcmo"

/obj/machinery/computer/card/minor/rd
	target_dept = 4
	icon_screen = "idrd"

	light_color = LIGHT_COLOR_PINK

/obj/machinery/computer/card/minor/ce
	target_dept = 5
	icon_screen = "idce"

	light_color = LIGHT_COLOR_YELLOW

#undef JOB_ALLOWED
#undef JOB_COOLDOWN
#undef JOB_MAX_POSITIONS
#undef JOB_DENIED


#undef UNAUTHENTICATED
#undef AUTHENTICATED_DEPARTMENT
#undef AUTHENTICATED_ALL
