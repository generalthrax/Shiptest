/datum/component/empprotection
	var/flags = NONE

/datum/component/empprotection/Initialize(_flags)
	if(!istype(parent, /atom))
		return COMPONENT_INCOMPATIBLE
	flags = _flags
	RegisterSignal(parent, COMSIG_ATOM_EMP_ACT, PROC_REF(getEmpFlags))

/datum/component/empprotection/proc/getEmpFlags(datum/source, severity)
	SIGNAL_HANDLER

	return flags
