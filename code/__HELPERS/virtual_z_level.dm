/**
 * Used to get the virtual z-level.
 * Will give unique values to each shuttle while it is in a transit level.
 * Note: If the user teleports to another virtual z on the same z-level they will need to have reset_virtual_z called. (Teleportations etc.)
 */

/// Virtual Z is optimized lookup of the virtual level for comparisons, but it doesn't pass the reference
/atom/proc/virtual_z()
	return

/atom/movable/virtual_z()
	var/turf/my_turf = get_turf(src)
	if(!my_turf)
		return 0
	return my_turf.virtual_z

/turf/virtual_z() //Just read the variable if you access a turf already, please
	return virtual_z // Some day put a stack trace and figure out all use cases of this and change them to .virtual_level instead

/area/virtual_z()
	var/turf/my_turf = locate(x,y,z)
	if(!my_turf)
		return 0
	return my_turf.virtual_z

/atom/proc/get_virtual_level()
	RETURN_TYPE(/datum/virtual_level)
	return

/atom/movable/get_virtual_level()
	var/turf/my_turf = get_turf(src)
	if(!my_turf)
		return
	return my_turf.get_virtual_level()

/area/get_virtual_level()
	var/turf/my_turf = locate(x,y,z)
	if(!my_turf)
		return
	return my_turf.get_virtual_level()

/turf/get_virtual_level()
	return SSmapping.virtual_z_translation["[virtual_z]"]

/atom/proc/get_map_zone()
	var/datum/virtual_level/vlevel = get_virtual_level()
	if(vlevel)
		return vlevel.parent_map_zone

/atom/proc/get_relative_location()
	var/datum/virtual_level/vlevel = get_virtual_level()
	return vlevel?.get_relative_coords(src)

/atom/proc/get_overmap_location()
	var/datum/map_zone/our_zone = get_map_zone()
	for(var/datum/overmap/dynamic/dynamic_object in SSovermap.overmap_objects)
		if(!istype(dynamic_object))
			continue
		if(!dynamic_object.mapzone)
			continue
		if(dynamic_object.mapzone == our_zone)
			return dynamic_object
	// Outposts need to be special and have a mapzone but not be dynamic, fun! Searches those here
	for(var/datum/overmap/outpost/outpost in SSovermap.outposts)
		if(!istype(outpost))
			continue
		if(!outpost.mapzone)
			continue
		if(outpost.mapzone == our_zone)
			return outpost
