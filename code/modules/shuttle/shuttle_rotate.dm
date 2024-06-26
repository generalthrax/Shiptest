/*
All shuttleRotate procs go here

If ever any of these procs are useful for non-shuttles, rename it to proc/rotate and move it to be a generic atom proc
*/

/************************************Base proc************************************/

/atom/proc/shuttleRotate(rotation, params=ROTATE_DIR|ROTATE_SMOOTH|ROTATE_OFFSET)
	if(params & ROTATE_DIR)
		//rotate our direction
		setDir(angle2dir(rotation+dir2angle(dir)))

	//resmooth if need be.
	if(params & ROTATE_SMOOTH && smoothing_flags & (SMOOTH_CORNERS|SMOOTH_BITMASK))
		QUEUE_SMOOTH(src)

	//rotate the pixel offsets too.
	if((pixel_x || pixel_y) && (params & ROTATE_OFFSET))
		if(rotation < 0)
			rotation += 360
		for(var/turntimes=rotation/90;turntimes>0;turntimes--)
			var/oldPX = pixel_x
			var/oldPY = pixel_y
			pixel_x = oldPY
			pixel_y = (oldPX*(-1))

/************************************Turf rotate procs************************************/

/turf/closed/mineral/shuttleRotate(rotation, params)
	params &= ~ROTATE_OFFSET
	return ..()

/************************************Mob rotate procs************************************/

//override to avoid rotating pixel_xy on mobs
/mob/shuttleRotate(rotation, params)
	params = NONE
	. = ..()
	if(!buckled)
		setDir(angle2dir(rotation+dir2angle(dir)))

/mob/dead/observer/shuttleRotate(rotation, params)
	. = ..()
	update_appearance()

/************************************Structure rotate procs************************************/

/obj/structure/cable/shuttleRotate(rotation, params)
	params &= ~ROTATE_DIR
	. = ..()
	if(d1)
		d1 = angle2dir(rotation+dir2angle(d1))
	if(d2)
		d2 = angle2dir(rotation+dir2angle(d2))

	//d1 should be less than d2 for cable icons to work
	if(d1 > d2)
		var/temp = d1
		d1 = d2
		d2 = temp
	update_appearance()

//Fixes dpdir on shuttle rotation
/obj/structure/disposalpipe/shuttleRotate(rotation, params)
	. = ..()
	var/new_dpdir = 0
	for(var/D in GLOB.cardinals)
		if(dpdir & D)
			new_dpdir = new_dpdir | angle2dir(rotation+dir2angle(D))
	dpdir = new_dpdir

/obj/structure/alien/weeds/shuttleRotate(rotation, params)
	params &= ~ROTATE_OFFSET
	return ..()

/obj/structure/reflector/shuttleRotate(rotation, params)
	. = ..()
	setAngle(SIMPLIFY_DEGREES(rotation_angle + rotation))

/************************************Machine rotate procs************************************/

/obj/machinery/atmospherics/shuttleRotate(rotation, params)
	var/list/real_node_connect = getNodeConnects()
	for(var/i in 1 to device_type)
		real_node_connect[i] = angle2dir(rotation+dir2angle(real_node_connect[i]))

	. = ..()
	SetInitDirections()
	var/list/supposed_node_connect = getNodeConnects()
	var/list/nodes_copy = nodes.Copy()

	for(var/i in 1 to device_type)
		var/new_pos = supposed_node_connect.Find(real_node_connect[i])
		nodes[new_pos] = nodes_copy[i]

/obj/machinery/mineral/shuttleRotate(rotation, params)
	. = ..()
	input_dir = angle2dir(rotation + dir2angle(input_dir))
	output_dir = angle2dir(rotation + dir2angle(output_dir))

//prevents shuttles attempting to rotate this since it messes up sprites
/obj/machinery/gateway/shuttleRotate(rotation, params)
	params = NONE
	return ..()

//prevents shuttles attempting to rotate this since it messes up sprites
/obj/machinery/gravity_generator/shuttleRotate(rotation, params)
	params = NONE
	return ..()

/obj/machinery/door/airlock/shuttleRotate(rotation, params)
	. = ..()
	if(cyclelinkeddir && (params & ROTATE_DIR))
		cyclelinkeddir = angle2dir(rotation+dir2angle(cyclelinkeddir))
		// If we update the linked airlock here, the partner airlock might
		// not be present yet, so don't do that. Just assume we're still
		// partnered with the same airlock as before.

/obj/machinery/porta_turret/shuttleRotate(rotation, params)
	. = ..()
	if(wall_turret_direction && (params & ROTATE_DIR))
		wall_turret_direction = turn(wall_turret_direction,rotation)
