#define CHEMICAL_QUANTISATION_LEVEL 0.0001 //stops floating point errors causing issues with checking reagent amounts


/proc/build_chemical_reagent_list()
	//Chemical Reagents - Initialises all /datum/reagent into a list indexed by reagent id

	if(GLOB.chemical_reagents_list)
		return

	var/paths = subtypesof(/datum/reagent)
	GLOB.chemical_reagents_list = list()

	for(var/path in paths)
		var/datum/reagent/D = new path()
		GLOB.chemical_reagents_list[path] = D

/proc/build_chemical_reactions_list()
	//Chemical Reactions - Initialises all /datum/chemical_reaction into a list
	// It is filtered into multiple lists within a list.
	// For example:
	// chemical_reaction_list[/datum/reagent/toxin/plasma] is a list of all reactions relating to plasma

	if(GLOB.chemical_reactions_list)
		return

	//Randomized need to go last since they need to check against conflicts with normal recipes
	var/paths = subtypesof(/datum/chemical_reaction) - typesof(/datum/chemical_reaction/randomized) + subtypesof(/datum/chemical_reaction/randomized)
	GLOB.chemical_reactions_list = list()

	for(var/path in paths)
		var/datum/chemical_reaction/D = new path()
		var/list/reaction_ids = list()

		if(!D.required_reagents || !D.required_reagents.len) //Skip impossible reactions
			continue

		for(var/reaction in D.required_reagents)
			reaction_ids += reaction

		// Create filters based on each reagent id in the required reagents list
		for(var/id in reaction_ids)
			if(!GLOB.chemical_reactions_list[id])
				GLOB.chemical_reactions_list[id] = list()
			GLOB.chemical_reactions_list[id] += D
			break // Don't bother adding ourselves to other reagent ids, it is redundant

///////////////////////////////////////////////////////////////////////////////////

/// Holder for a bunch of [/datum/reagent]
/datum/reagents
	/// The reagents being held
	var/list/datum/reagent/reagent_list = new/list()
	/// Current volume of all the reagents
	var/total_volume = 0
	/// Max volume of this holder
	var/maximum_volume = 100
	/// The atom this holder is attached to
	var/atom/my_atom = null
	/// Current temp of the holder volume
	var/chem_temp = 150
	/// unused
	var/last_tick = 1
	/// see [/datum/reagents/proc/metabolize] for usage
	var/addiction_tick = 1
	/// currently addicted reagents
	var/list/datum/reagent/addiction_list = new/list()
	/// various flags, see code\__DEFINES\reagents.dm
	var/flags

/datum/reagents/New(maximum=100, new_flags=0)
	maximum_volume = maximum

	//I dislike having these here but map-objects are initialised before world/New() is called. >_>
	if(!GLOB.chemical_reagents_list)
		build_chemical_reagent_list()
	if(!GLOB.chemical_reactions_list)
		build_chemical_reactions_list()

	flags = new_flags

/datum/reagents/Destroy()
	. = ..()
	//We're about to delete all reagents, so lets cleanup
	addiction_list.Cut()
	var/list/cached_reagents = reagent_list
	for(var/reagent in cached_reagents)
		var/datum/reagent/R = reagent
		qdel(R)
	cached_reagents.Cut()
	cached_reagents = null
	if(my_atom && my_atom.reagents == src)
		my_atom.reagents = null
	my_atom = null

/datum/reagents/proc/get_total_accelerant_quality()
	var/quality = 0
	for(var/datum/reagent/reagent as anything in reagent_list)
		quality += reagent.volume * reagent.accelerant_quality
	return quality

/**
 * Used in attack logs for reagents in pills and such
 *
 * Arguments:
 * * external_list - list of reagent types = amounts
 */
/datum/reagents/proc/log_list(external_list)
	if((external_list && !length(external_list)) || !length(reagent_list))
		return "no reagents"

	var/list/data = list()
	if(external_list)
		for(var/r in external_list)
			data += "[r] ([round(external_list[r], 0.1)]u)"
	else
		for(var/r in reagent_list) //no reagents will be left behind
			var/datum/reagent/R = r
			data += "[R.type] ([round(R.volume, 0.1)]u)"
			//Using types because SOME chemicals (I'm looking at you, chlorhydrate-beer) have the same names as other chemicals.
	return english_list(data)

/// Remove an amount of reagents without caring about what they are
/datum/reagents/proc/remove_any(amount = 1)
	var/list/cached_reagents = reagent_list
	var/total_transfered = 0
	var/current_list_element = 1
	var/initial_list_length = cached_reagents.len //stored here because removing can cause some reagents to be deleted, ergo length change.

	current_list_element = rand(1, cached_reagents.len)

	while(total_transfered != amount)
		if(total_transfered >= amount)
			break
		if(total_volume <= 0 || !cached_reagents.len)
			break

		if(current_list_element > cached_reagents.len)
			current_list_element = 1

		var/datum/reagent/R = cached_reagents[current_list_element]
		var/remove_amt = min(amount-total_transfered,round(amount/rand(2,initial_list_length),round(amount/10,0.01))) //double round to keep it at a somewhat even spread relative to amount without getting funky numbers.
		//min ensures we don't go over amount.
		remove_reagent(R.type, remove_amt)

		current_list_element++
		total_transfered += remove_amt
		update_total()

	handle_reactions()
	return total_transfered //this should be amount unless the loop is prematurely broken, in which case it'll be lower. It shouldn't ever go OVER amount.

/// Removes all reagents from this holder
/datum/reagents/proc/remove_all(amount = 1)
	var/list/cached_reagents = reagent_list
	if(total_volume > 0)
		var/part = amount / total_volume
		for(var/reagent in cached_reagents)
			var/datum/reagent/R = reagent
			remove_reagent(R.type, R.volume * part)

		update_total()
		handle_reactions()
		return amount

/// DEPRICATED use get_master_regent. Get the name of the reagent there is the most of in this holder
/datum/reagents/proc/get_master_reagent_name()
	var/list/cached_reagents = reagent_list
	var/name
	var/max_volume = 0
	for(var/reagent in cached_reagents)
		var/datum/reagent/R = reagent
		if(R.volume > max_volume)
			max_volume = R.volume
			name = R.name

	return name

/// DEPRICATED use get_master_regent. Get the id of the reagent there is the most of in this holder
/datum/reagents/proc/get_master_reagent_id()
	var/list/cached_reagents = reagent_list
	var/max_type
	var/max_volume = 0
	for(var/reagent in cached_reagents)
		var/datum/reagent/R = reagent
		if(R.volume > max_volume)
			max_volume = R.volume
			max_type = R.type

	return max_type

/// Get a reference to the reagent there is the most of in this holder
/datum/reagents/proc/get_master_reagent()
	var/list/cached_reagents = reagent_list
	var/datum/reagent/master
	var/max_volume = 0
	for(var/reagent in cached_reagents)
		var/datum/reagent/R = reagent
		if(R.volume > max_volume)
			max_volume = R.volume
			master = R

	return master

/**
 * Transfer some stuff from this holder to a target object
 *
 * Arguments:
 * * obj/target - Target to attempt transfer to
 * * amount - amount of reagent volume to transfer
 * * multiplier - multiplies amount of each reagent by this number
 * * preserve_data - if preserve_data=0, the reagents data will be lost. Usefull if you use data for some strange stuff and don't want it to be transferred.
 * * no_react - passed through to [/datum/reagents/proc/add_reagent]
 * * mob/transfered_by - used for logging
 * * remove_blacklisted - skips transferring of reagents with can_synth = FALSE
 * * method - passed through to [/datum/reagents/proc/react_single] and [/datum/reagent/proc/on_transfer]
 * * show_message - passed through to [/datum/reagents/proc/react_single]
 * * round_robin - if round_robin=TRUE, so transfer 5 from 15 water, 15 sugar and 15 plasma becomes 10, 15, 15 instead of 13.3333, 13.3333 13.3333. Good if you hate floating point errors
 * * ignore_stomach - when using methods INGEST will not use the stomach as the target
 */
/datum/reagents/proc/trans_to(obj/target, amount = 1, multiplier = 1, preserve_data = TRUE, no_react = FALSE, mob/transfered_by, remove_blacklisted = FALSE, method = null, show_message = TRUE, round_robin = FALSE, ignore_stomach = FALSE)
	var/list/cached_reagents = reagent_list
	if(!target || !total_volume)
		return
	if(amount < 0)
		return

	var/atom/target_atom
	var/datum/reagents/R
	if(istype(target, /datum/reagents))
		R = target
		target_atom = R.my_atom
	else
		if(!ignore_stomach && (method & INGEST) && istype(target, /mob/living/carbon))
			var/mob/living/carbon/eater = target
			var/obj/item/organ/stomach/belly = eater.getorganslot(ORGAN_SLOT_STOMACH)
			if(!belly)
				eater.expel_ingested(my_atom, amount)
				return
			R = belly.reagents
			target_atom = belly
		else if(!target.reagents)
			return
		else
			R = target.reagents
			target_atom = target

	amount = min(min(amount, src.total_volume), R.maximum_volume-R.total_volume)
	var/trans_data = null
	var/transfer_log = list()
	if(!round_robin)
		var/part = amount / src.total_volume
		for(var/reagent in cached_reagents)
			var/datum/reagent/T = reagent
			if(remove_blacklisted && !T.can_synth)
				continue
			var/transfer_amount = T.volume * part
			if(preserve_data)
				trans_data = copy_data(T)
			R.add_reagent(T.type, transfer_amount * multiplier, trans_data, chem_temp, no_react = 1) //we only handle reaction after every reagent has been transfered.
			if(method)
				if(istype(target_atom, /obj/item/organ/stomach))
					R.expose_single(T, target, method, part, show_message)
				else
					R.expose_single(T, target_atom, method, part, show_message)
				T.on_transfer(target_atom, method, transfer_amount * multiplier)
			remove_reagent(T.type, transfer_amount)
			transfer_log[T.type] = transfer_amount
	else
		var/to_transfer = amount
		for(var/reagent in cached_reagents)
			if(!to_transfer)
				break
			var/datum/reagent/T = reagent
			if(remove_blacklisted && !T.can_synth)
				continue
			if(preserve_data)
				trans_data = copy_data(T)
			var/transfer_amount = amount
			if(amount > T.volume)
				transfer_amount = T.volume
			R.add_reagent(T.type, transfer_amount * multiplier, trans_data, chem_temp, no_react = 1)
			to_transfer = max(to_transfer - transfer_amount , 0)
			if(method)
				if(istype(target_atom, /obj/item/organ/stomach))
					R.expose_single(T, target, method, transfer_amount, show_message)
				else
					R.expose_single(T, target_atom, method, transfer_amount, show_message)
				T.on_transfer(target_atom, method, transfer_amount * multiplier)
			remove_reagent(T.type, transfer_amount)
			transfer_log[T.type] = transfer_amount

	if(transfered_by && target_atom)
		target_atom.add_hiddenprint(transfered_by) //log prints so admins can figure out who touched it last.
		log_combat(transfered_by, target_atom, "transferred reagents ([log_list(transfer_log)]) from [my_atom] to")

	update_total()
	R.update_total()
	if(!no_react)
		R.handle_reactions()
		src.handle_reactions()
	return amount

/// Copies the reagents to the target object
/datum/reagents/proc/copy_to(obj/target, amount=1, multiplier=1, preserve_data=1)
	var/list/cached_reagents = reagent_list
	if(!target || !total_volume)
		return

	var/datum/reagents/R
	if(istype(target, /datum/reagents))
		R = target
	else
		if(!target.reagents)
			return
		R = target.reagents

	if(amount < 0)
		return
	amount = min(min(amount, total_volume), R.maximum_volume-R.total_volume)
	var/part = amount / total_volume
	var/trans_data = null
	for(var/reagent in cached_reagents)
		var/datum/reagent/T = reagent
		var/copy_amount = T.volume * part
		if(preserve_data)
			trans_data = T.data
		R.add_reagent(T.type, copy_amount * multiplier, trans_data)

	src.update_total()
	R.update_total()
	R.handle_reactions()
	src.handle_reactions()
	return amount

/// Transfer a specific reagent id to the target object
/datum/reagents/proc/trans_id_to(obj/target, reagent, amount=1, preserve_data=1)//Not sure why this proc didn't exist before. It does now! /N
	var/list/cached_reagents = reagent_list
	if (!target)
		return
	if (!target.reagents || src.total_volume<=0 || !src.get_reagent_amount(reagent))
		return
	if(amount < 0)
		return

	var/datum/reagents/R = target.reagents
	if(src.get_reagent_amount(reagent)<amount)
		amount = src.get_reagent_amount(reagent)
	amount = min(amount, R.maximum_volume-R.total_volume)
	var/trans_data = null
	for (var/CR in cached_reagents)
		var/datum/reagent/current_reagent = CR
		if(current_reagent.type == reagent)
			if(preserve_data)
				trans_data = current_reagent.data
			R.add_reagent(current_reagent.type, amount, trans_data, src.chem_temp)
			remove_reagent(current_reagent.type, amount, 1)
			break

	src.update_total()
	R.update_total()
	R.handle_reactions()
	return amount

/**
 * Triggers metabolizing the reagents in this holder
 *
 * Arguments:
 * * mob/living/carbon/C - The mob to metabolize in, if null it uses [/datum/reagents/var/my_atom]
 * * can_overdose - Allows overdosing
 * * liverless - Stops reagents that aren't set as [/datum/reagent/var/self_consuming] from metabolizing
 */
/datum/reagents/proc/metabolize(mob/living/carbon/C, can_overdose = FALSE, liverless = FALSE)
	var/list/cached_reagents = reagent_list
	var/list/cached_addictions = addiction_list
	if(C)
		expose_temperature(C.bodytemperature, 0.25)
	var/need_mob_update = 0
	for(var/datum/reagent/R as anything in cached_reagents)
		if(QDELETED(R.holder))
			continue

		if(!C)
			C = R.holder.my_atom
		if(C && R)
			if(!C.handled_by_species(R))
				if(liverless && !R.self_consuming) //need to be metabolized
					continue
				if(!R.metabolizing)
					R.metabolizing = TRUE
					R.on_mob_metabolize(C)
				if(can_overdose)
					if(R.overdose_threshold)
						if(R.volume >= R.overdose_threshold && !R.overdosed)
							R.overdosed = 1
							need_mob_update += R.overdose_start(C)
							log_game("[key_name(C)] has started overdosing on [R.name] at [R.volume] units.")
					if(R.addiction_threshold)
						if(R.volume >= R.addiction_threshold && !is_type_in_list(R, cached_addictions))
							var/datum/reagent/new_reagent = new R.type()
							cached_addictions.Add(new_reagent)
							log_game("[key_name(C)] has become addicted to [R.name] at [R.volume] units.")
					if(R.overdosed)
						need_mob_update += R.overdose_process(C)
					if(is_type_in_list(R,cached_addictions))
						for(var/addiction in cached_addictions)
							var/datum/reagent/A = addiction
							if(istype(R, A))
								A.addiction_stage = -30 // you're satisfied for a good while.
				need_mob_update += R.on_mob_life(C)

	if(can_overdose)
		if(addiction_tick == 6)
			addiction_tick = 1
			for(var/datum/reagent/R as anything in cached_addictions)
				if(C && R)
					R.addiction_stage++
					switch(R.addiction_stage)
						if(1 to 10)
							need_mob_update += R.addiction_act_stage1(C)
						if(10 to 20)
							need_mob_update += R.addiction_act_stage2(C)
						if(20 to 30)
							need_mob_update += R.addiction_act_stage3(C)
						if(30 to 40)
							need_mob_update += R.addiction_act_stage4(C)
						if(40 to INFINITY)
							remove_addiction(R)
						else
							SEND_SIGNAL(C, COMSIG_CLEAR_MOOD_EVENT, "[R.type]_overdose")
		addiction_tick++
	if(C && need_mob_update) //some of the metabolized reagents had effects on the mob that requires some updates.
		C.updatehealth()
		C.update_stamina()
	update_total()

/// Removes addiction to a specific reagent on [/datum/reagents/var/my_atom]
/datum/reagents/proc/remove_addiction(datum/reagent/R)
	R.on_addiction_removal(my_atom)
	to_chat(my_atom, span_notice("You feel like you've gotten over your need for [R.name]."))
	SEND_SIGNAL(my_atom, COMSIG_CLEAR_MOOD_EVENT, "[R.type]_overdose")
	addiction_list.Remove(R)
	qdel(R)

/// Signals that metabolization has stopped, triggering the end of trait-based effects
/datum/reagents/proc/end_metabolization(mob/living/carbon/C, keep_liverless = TRUE)
	var/list/cached_reagents = reagent_list
	for(var/reagent in cached_reagents)
		var/datum/reagent/R = reagent
		if(QDELETED(R.holder))
			continue
		if(keep_liverless && R.self_consuming) //Will keep working without a liver
			continue
		if(!C)
			C = R.holder.my_atom
		if(R.metabolizing)
			R.metabolizing = FALSE
			R.on_mob_end_metabolize(C)

/**
 * Calls [/datum/reagent/proc/on_move] on every reagent in this holder
 *
 * Arguments:
 * * atom/A - passed to on_move
 * * Running - passed to on_move
 */
/datum/reagents/proc/conditional_update_move(atom/A, Running = 0)
	var/list/cached_reagents = reagent_list
	for(var/reagent in cached_reagents)
		var/datum/reagent/R = reagent
		R.on_move (A, Running)
	update_total()

/**
 * Calls [/datum/reagent/proc/on_update] on every reagent in this holder
 *
 * Arguments:
 * * atom/A - passed to on_update
 */
/datum/reagents/proc/conditional_update(atom/A)
	var/list/cached_reagents = reagent_list
	for(var/reagent in cached_reagents)
		var/datum/reagent/R = reagent
		R.on_update (A)
	update_total()

/// Handle any reactions possible in this holder
/datum/reagents/proc/handle_reactions()
	if(flags & NO_REACT)
		return //Yup, no reactions here. No siree.

	var/list/cached_reagents = reagent_list
	var/list/cached_reactions = GLOB.chemical_reactions_list
	var/datum/cached_my_atom = my_atom

	var/reaction_occurred = 0
	do
		var/list/possible_reactions = list()
		reaction_occurred = 0
		for(var/reagent in cached_reagents)
			var/datum/reagent/R = reagent
			for(var/reaction in cached_reactions[R.type]) // Was a big list but now it should be smaller since we filtered it with our reagent id
				if(!reaction)
					continue

				var/datum/chemical_reaction/C = reaction
				var/list/cached_required_reagents = C.required_reagents
				var/total_required_reagents = cached_required_reagents.len
				var/total_matching_reagents = 0
				var/list/cached_required_catalysts = C.required_catalysts
				var/total_required_catalysts = cached_required_catalysts.len
				var/total_matching_catalysts= 0
				var/matching_container = 0
				var/matching_other = 0
				var/required_temp = C.required_temp
				var/is_cold_recipe = C.is_cold_recipe
				var/meets_temp_requirement = 0

				for(var/B in cached_required_reagents)
					if(!has_reagent(B, cached_required_reagents[B]))
						break
					total_matching_reagents++
				for(var/B in cached_required_catalysts)
					if(!has_reagent(B, cached_required_catalysts[B]))
						break
					total_matching_catalysts++
				if(cached_my_atom)
					if(!C.required_container)
						matching_container = 1

					else
						if(cached_my_atom.type in typesof(C.required_container))
							matching_container = 1
					if (isliving(cached_my_atom) && !C.mob_react) //Makes it so certain chemical reactions don't occur in mobs
						return
					if(!C.required_other)
						matching_other = 1

				else
					if(!C.required_container)
						matching_container = 1
					if(!C.required_other)
						matching_other = 1

				if(required_temp == 0 || (is_cold_recipe && chem_temp <= required_temp) || (!is_cold_recipe && chem_temp >= required_temp))
					meets_temp_requirement = 1

				if(total_matching_reagents == total_required_reagents && total_matching_catalysts == total_required_catalysts && matching_container && matching_other && meets_temp_requirement)
					possible_reactions  += C

		if(possible_reactions.len)
			var/datum/chemical_reaction/selected_reaction = possible_reactions[1]
			//select the reaction with the most extreme temperature requirements
			for(var/V in possible_reactions)
				var/datum/chemical_reaction/competitor = V
				if(selected_reaction.is_cold_recipe) //if there are no recipe conflicts, everything in possible_reactions will have this same value for is_cold_reaction. warranty void if assumption not met.
					if(competitor.required_temp <= selected_reaction.required_temp)
						selected_reaction = competitor
				else
					if(competitor.required_temp >= selected_reaction.required_temp)
						selected_reaction = competitor
			var/list/cached_required_reagents = selected_reaction.required_reagents
			var/list/cached_results = selected_reaction.results
			var/list/multiplier = INFINITY
			for(var/B in cached_required_reagents)
				multiplier = min(multiplier, round(get_reagent_amount(B) / cached_required_reagents[B]))

			for(var/B in cached_required_reagents)
				remove_reagent(B, (multiplier * cached_required_reagents[B]), safety = 1)

			for(var/P in selected_reaction.results)
				multiplier = max(multiplier, 1) //this shouldnt happen ...
				SSblackbox.record_feedback("tally", "chemical_reaction", cached_results[P]*multiplier, P)
				add_reagent(P, cached_results[P]*multiplier, null, chem_temp)

			var/list/seen = viewers(4, get_turf(my_atom))
			var/iconhtml = icon2html(cached_my_atom, seen)
			if(cached_my_atom)
				if(!ismob(cached_my_atom)) // No bubbling mobs
					if(selected_reaction.mix_sound)
						playsound(get_turf(cached_my_atom), selected_reaction.mix_sound, 80, TRUE)

					for(var/mob/M in seen)
						to_chat(M, span_notice("[iconhtml] [selected_reaction.mix_message]"))

			selected_reaction.on_reaction(src, multiplier)
			reaction_occurred = 1

	while(reaction_occurred)
	update_total()
	return 0

/// Remove every reagent except this one
/datum/reagents/proc/isolate_reagent(reagent)
	var/list/cached_reagents = reagent_list
	for(var/_reagent in cached_reagents)
		var/datum/reagent/R = _reagent
		if(R.type != reagent)
			del_reagent(R.type)
			update_total()

/// Fuck this one reagent
/datum/reagents/proc/del_reagent(reagent)
	var/list/cached_reagents = reagent_list
	for(var/_reagent in cached_reagents)
		var/datum/reagent/R = _reagent
		if(R.type == reagent)
			var/mob/living/mob_consumer
			if (isliving(my_atom))
				mob_consumer = my_atom
			else if (istype(my_atom, /obj/item/organ))
				var/obj/item/organ/organ = my_atom
				mob_consumer = organ.owner

			if (mob_consumer)
				if(R.metabolizing)
					R.metabolizing = FALSE
					R.on_mob_end_metabolize(mob_consumer)
				R.on_mob_delete(mob_consumer)
			//Clear from relevant lists
			addiction_list -= R
			reagent_list -= R
			SEND_SIGNAL(src, COMSIG_REAGENTS_DEL_REAGENT, R)
			qdel(R)
			update_total()
			if(my_atom)
				my_atom.on_reagent_change(DEL_REAGENT)
	return 1

/// Updates [/datum/reagents/var/total_volume]
/datum/reagents/proc/update_total()
	var/list/cached_reagents = reagent_list
	total_volume = 0
	for(var/reagent in cached_reagents)
		var/datum/reagent/R = reagent
		if(R.volume < 0.1)
			del_reagent(R.type)
		else
			total_volume += R.volume

	return 0

/// Removes all reagents
/datum/reagents/proc/clear_reagents()
	var/list/cached_reagents = reagent_list
	for(var/reagent in cached_reagents)
		var/datum/reagent/R = reagent
		del_reagent(R.type)
	if(my_atom)
		my_atom.on_reagent_change(CLEAR_REAGENTS)

	SEND_SIGNAL(src, COMSIG_REAGENTS_CLEAR_REAGENTS)
	return 0

/**
 * Applies the relevant expose_ proc for every reagent in this holder
 * * [/datum/reagent/proc/expose_mob]
 * * [/datum/reagent/proc/expose_turf]
 * * [/datum/reagent/proc/expose_obj]
 */
/datum/reagents/proc/expose(atom/A, method = TOUCH, volume_modifier = 1, show_message = 1)
	if(isnull(A))
		return null

	var/list/cached_reagents = reagent_list
	if(!cached_reagents.len)
		return null

	var/list/reagents = list()
	for(var/reagent in cached_reagents)
		var/datum/reagent/R = reagent
		reagents[R] = R.volume * volume_modifier

	return A.expose_reagents(reagents, src, method, volume_modifier, show_message)


/// Same as [/datum/reagents/proc/expose] but only for one reagent
/datum/reagents/proc/expose_single(datum/reagent/R, atom/A, method = TOUCH, volume_modifier = 1, show_message = TRUE)
	if(isnull(A))
		return null

	if(ispath(R))
		R = get_reagent(R)
	if(isnull(R))
		return null

	// Yes, we need the parentheses.
	return A.expose_reagents(list((R) = R.volume * volume_modifier), src, method, volume_modifier, show_message)

/// Is this holder full or not
/datum/reagents/proc/holder_full()
	if(total_volume >= maximum_volume)
		return TRUE
	return FALSE

/// Returns the average specific heat for all reagents currently in this holder.
/datum/reagents/proc/specific_heat()
	. = 0
	var/cached_amount = total_volume		//cache amount
	var/list/cached_reagents = reagent_list		//cache reagents
	for(var/I in cached_reagents)
		var/datum/reagent/R = I
		. += R.specific_heat * (R.volume / cached_amount)

/datum/reagents/proc/adjust_thermal_energy(J, min_temp = 2.7, max_temp = 1000)
	var/S = specific_heat()
	chem_temp = clamp(chem_temp + (J / (S * total_volume)), 2.7, 1000)

/**
 * Adds a reagent to this holder
 *
 * Arguments:
 * * reagent - The reagent id to add
 * * amount - Amount to add
 * * list/data - Any reagent data for this reagent, used for transferring data with reagents
 * * reagtemp - Temperature of this reagent, will be equalized
 * * no_react - prevents reactions being triggered by this addition
 */
/datum/reagents/proc/add_reagent(reagent, amount, list/data=null, reagtemp = 300, no_react = 0)
	if(!isnum(amount) || !amount)
		return FALSE

	if(amount <= 0)
		return FALSE

	var/datum/reagent/D = GLOB.chemical_reagents_list[reagent]
	if(!D)
		WARNING("[my_atom] attempted to add a reagent called '[reagent]' which doesn't exist. ([usr])")
		return FALSE

	update_total()
	var/cached_total = total_volume
	if(cached_total + amount > maximum_volume)
		amount = (maximum_volume - cached_total) //Doesnt fit in. Make it disappear. Shouldnt happen. Will happen.
		if(amount <= 0)
			return FALSE
	var/new_total = cached_total + amount
	var/cached_temp = chem_temp
	var/list/cached_reagents = reagent_list

	//Equalize temperature - Not using specific_heat() because the new chemical isn't in yet.
	var/specific_heat = 0
	var/thermal_energy = 0
	for(var/i in cached_reagents)
		var/datum/reagent/R = i
		specific_heat += R.specific_heat * (R.volume / new_total)
		thermal_energy += R.specific_heat * R.volume * cached_temp
	specific_heat += D.specific_heat * (amount / new_total)
	thermal_energy += D.specific_heat * amount * reagtemp
	chem_temp = thermal_energy / (specific_heat * new_total)
	////

	//add the reagent to the existing if it exists
	for(var/A in cached_reagents)
		var/datum/reagent/R = A
		if (R.type == reagent)
			R.volume += amount
			update_total()
			if(my_atom)
				my_atom.on_reagent_change(ADD_REAGENT)
			R.on_merge(data, amount)

			SEND_SIGNAL(src, COMSIG_REAGENTS_ADD_REAGENT, cached_reagents, amount, reagtemp, data, no_react)
			if(!no_react)
				handle_reactions()
			return TRUE

	//otherwise make a new one
	var/datum/reagent/R = new D.type(data)
	cached_reagents += R
	R.holder = src
	R.volume = amount
	if(data)
		R.data = data
		R.on_new(data)

	if(isliving(my_atom))
		R.on_mob_add(my_atom) //Must occur befor it could posibly run on_mob_delete
	else if(istype(my_atom, /obj/item/organ/stomach))
		var/obj/item/organ/stomach/belly = my_atom
		var/mob/living/carbon/body = belly.owner
		R.on_mob_add(body)
	update_total()
	if(my_atom)
		my_atom.on_reagent_change(ADD_REAGENT)

	SEND_SIGNAL(src, COMSIG_REAGENTS_NEW_REAGENT, reagent, amount, reagtemp, data, no_react)
	if(!no_react)
		handle_reactions()
	return TRUE

/// Like add_reagent but you can enter a list. Format it like this: list(/datum/reagent/toxin = 10, "beer" = 15)
/datum/reagents/proc/add_reagent_list(list/list_reagents, list/data=null)
	for(var/r_id in list_reagents)
		var/amt = list_reagents[r_id]
		add_reagent(r_id, amt, data)

/// Remove a specific reagent
/datum/reagents/proc/remove_reagent(reagent, amount, safety)//Added a safety check for the trans_id_to

	if(isnull(amount))
		amount = 0
		CRASH("null amount passed to reagent code")

	if(!isnum(amount))
		return FALSE

	if(amount < 0)
		return FALSE

	var/list/cached_reagents = reagent_list

	for(var/A in cached_reagents)
		var/datum/reagent/R = A
		if (R.type == reagent)
			//clamp the removal amount to be between current reagent amount
			//and zero, to prevent removing more than the holder has stored
			amount = clamp(amount, 0, R.volume)
			R.volume -= amount
			SEND_SIGNAL(src, COMSIG_REAGENTS_REM_REAGENT, A, amount)
			update_total()
			if(!safety)//So it does not handle reactions when it need not to
				handle_reactions()
			if(my_atom)
				my_atom.on_reagent_change(REM_REAGENT)
			return amount

	return FALSE


/*
Check if this holder contains this reagent.
Reagent takes a PATH to a reagent.
Amount checks for having a specific amount of that chemical.
Needs matabolizing takes into consideration if the chemical is matabolizing when it's checked.
*/
/datum/reagents/proc/has_reagent(reagent, amount = -1, needs_metabolizing = FALSE)
	var/list/cached_reagents = reagent_list
	for(var/_reagent in cached_reagents)
		var/datum/reagent/R = _reagent
		if (R.type == reagent)
			if(!amount)
				if(needs_metabolizing && !R.metabolizing)
					return 0
				return R
			else
				if(round(R.volume, CHEMICAL_QUANTISATION_LEVEL) >= amount)
					if(needs_metabolizing && !R.metabolizing)
						return 0
					return R
				else
					return 0

	return 0

/// Get the amount of this reagent
/datum/reagents/proc/get_reagent_amount(reagent)
	var/list/cached_reagents = reagent_list
	for(var/_reagent in cached_reagents)
		var/datum/reagent/R = _reagent
		if (R.type == reagent)
			return round(R.volume, CHEMICAL_QUANTISATION_LEVEL)

	return 0

/// Get a comma separated string of every reagent name in this holder
/datum/reagents/proc/get_reagents()
	var/list/names = list()
	var/list/cached_reagents = reagent_list
	for(var/reagent in cached_reagents)
		var/datum/reagent/R = reagent
		names += R.name

	return jointext(names, ",")

/// Removes all reagent of X type. @strict set to 1 determines whether the childs of the type are included.
/datum/reagents/proc/remove_all_type(reagent_type, amount, strict = 0, safety = 1)
	if(!isnum(amount))
		return 1
	var/list/cached_reagents = reagent_list
	var/has_removed_reagent = 0

	for(var/reagent in cached_reagents)
		var/datum/reagent/R = reagent
		var/matches = 0
		// Switch between how we check the reagent type
		if(strict)
			if(R.type == reagent_type)
				matches = 1
		else
			if(istype(R, reagent_type))
				matches = 1
		// We found a match, proceed to remove the reagent.	Keep looping, we might find other reagents of the same type.
		if(matches)
			// Have our other proc handle removement
			has_removed_reagent = remove_reagent(R.type, amount, safety)

	return has_removed_reagent

/// helper function to preserve data across reactions (needed for xenoarch)
/datum/reagents/proc/get_data(reagent_id)
	var/list/cached_reagents = reagent_list
	for(var/reagent in cached_reagents)
		var/datum/reagent/R = reagent
		if(R.type == reagent_id)
			return R.data

/// helper function to preserve data across reactions (needed for xenoarch)
/datum/reagents/proc/set_data(reagent_id, new_data)
	var/list/cached_reagents = reagent_list
	for(var/reagent in cached_reagents)
		var/datum/reagent/R = reagent
		if(R.type == reagent_id)
			R.data = new_data

/// Shallow copies (deep copy of viruses) data from the provided reagent into our copy of that reagent
/datum/reagents/proc/copy_data(datum/reagent/current_reagent)
	if(!current_reagent || !current_reagent.data)
		return null
	if(!istype(current_reagent.data, /list))
		return current_reagent.data

	var/list/trans_data = current_reagent.data.Copy()

	// We do this so that introducing a virus to a blood sample
	// doesn't automagically infect all other blood samples from
	// the same donor.
	//
	// Technically we should probably copy all data lists, but
	// that could possibly eat up a lot of memory needlessly
	// if most data lists are read-only.
	if(trans_data["viruses"])
		var/list/v = trans_data["viruses"]
		trans_data["viruses"] = v.Copy()

	return trans_data

/// Get a reference to the reagent if it exists
/datum/reagents/proc/get_reagent(type)
	var/list/cached_reagents = reagent_list
	. = locate(type) in cached_reagents

/**
 * Returns what this holder's reagents taste like
 *
 * Arguments:
 * * minimum_percent - the lower the minimum percent, the more sensitive the message is.
 */
/datum/reagents/proc/generate_taste_message(minimum_percent=15)
	var/list/out = list()
	var/list/tastes = list() //descriptor = strength
	if(minimum_percent <= 100)
		for(var/datum/reagent/R in reagent_list)
			if(!R.taste_mult)
				continue

			if(istype(R, /datum/reagent/consumable/nutriment))
				var/list/taste_data = R.data
				for(var/taste in taste_data)
					var/ratio = taste_data[taste]
					var/amount = ratio * R.taste_mult * R.volume
					if(taste in tastes)
						tastes[taste] += amount
					else
						tastes[taste] = amount
			else
				var/taste_desc = R.taste_description
				var/taste_amount = R.volume * R.taste_mult
				if(taste_desc in tastes)
					tastes[taste_desc] += taste_amount
				else
					tastes[taste_desc] = taste_amount
		//deal with percentages
		// TODO it would be great if we could sort these from strong to weak
		var/total_taste = counterlist_sum(tastes)
		if(total_taste > 0)
			for(var/taste_desc in tastes)
				var/percent = tastes[taste_desc]/total_taste * 100
				if(percent < minimum_percent)
					continue
				var/intensity_desc = "a hint of"
				if(percent > minimum_percent * 2 || percent == 100)
					intensity_desc = ""
				else if(percent > minimum_percent * 3)
					intensity_desc = "the strong flavor of"
				if(intensity_desc != "")
					out += "[intensity_desc] [taste_desc]"
				else
					out += "[taste_desc]"

	return english_list(out, "something indescribable")

/// Applies heat to this holder
/datum/reagents/proc/expose_temperature(temperature, coeff=0.02)
	if(istype(my_atom,/obj/item/reagent_containers))
		var/obj/item/reagent_containers/RCs = my_atom
		if(RCs.reagent_flags & NO_REACT) //stasis holders IE cryobeaker
			return
	var/temp_delta = (temperature - chem_temp) * coeff
	if(temp_delta > 0)
		chem_temp = min(chem_temp + max(temp_delta, 1), temperature)
	else
		chem_temp = max(chem_temp + min(temp_delta, -1), temperature)
	chem_temp = round(chem_temp)
	for(var/i in reagent_list)
		var/datum/reagent/R = i
		R.on_temp_change()
	handle_reactions()

///////////////////////////////////////////////////////////////////////////////////


/**
 * Convenience proc to create a reagents holder for an atom
 *
 * Arguments:
 * * max_vol - maximum volume of holder
 * * flags - flags to pass to the holder
 */
/atom/proc/create_reagents(max_vol, flags)
	if(reagents)
		qdel(reagents)
	reagents = new /datum/reagents(max_vol, flags)
	reagents.my_atom = src

/proc/find_reagent_object_from_type(input)
	if(GLOB.chemical_reagents_list[input]) //prefer IDs!
		return GLOB.chemical_reagents_list[input]
	else
		return null

/proc/get_random_reagent_id()	// Returns a random reagent ID minus blacklisted reagents
	var/static/list/random_reagents = list()
	if(!random_reagents.len)
		for(var/thing  in subtypesof(/datum/reagent))
			var/datum/reagent/R = thing
			if(initial(R.can_synth))
				random_reagents += R
	var/picked_reagent = pick(random_reagents)
	return picked_reagent

/proc/get_chem_id(chem_name)
	for(var/X in GLOB.chemical_reagents_list)
		var/datum/reagent/R = GLOB.chemical_reagents_list[X]
		if(ckey(chem_name) == ckey(lowertext(R.name)))
			return X
