/obj/item/multitool/circuit
	name = "схемотул"
	desc = "Мультитул для схем. Используется для отметки объектов, которые затем могут быть загружены в компоненты, нажав кнопку загрузки на порту. \
	В остальном действует как обычный мультитул. Используйте в руке, чтобы очистить отмеченный объект, чтобы вы могли отметить другой объект."
	//icon_state = "multitool_circuit"
	icon_state = "multitool"

	/// The marked atom of this multitool
	var/atom/marked_atom

/obj/item/multitool/circuit/Destroy()
	marked_atom = null
	return ..()

/obj/item/multitool/circuit/examine(mob/user)
	. = ..()
	. += span_notice("It has [marked_atom? "a" : "no"] marked entity registered.")

/obj/item/multitool/circuit/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!marked_atom)
		return

	say("Cleared marked targets.")
	clear_marked_atom()
	return TRUE

/obj/item/multitool/circuit/melee_attack_chain(mob/user, atom/target, params)
	var/is_right_clicking = LAZYACCESS(params2list(params), RIGHT_CLICK)

	if(marked_atom || !user.Adjacent(target) || is_right_clicking)
		return ..()

	say("Marked [target].")
	marked_atom = target
	RegisterSignal(marked_atom, COMSIG_PARENT_QDELETING, PROC_REF(cleanup_marked_atom))
	update_icon()
	flick("multitool_circuit_flick", src)
	playsound(src.loc, 'sound/misc/compiler-stage2.ogg', 30, TRUE)
	return TRUE

/obj/item/multitool/circuit/update_overlays()
	. = ..()
	cut_overlays()
	if(marked_atom)
		. += "marked_overlay"

/// Clears the current marked atom
/obj/item/multitool/circuit/proc/clear_marked_atom()
	if(!marked_atom)
		return
	UnregisterSignal(marked_atom, COMSIG_PARENT_QDELETING)
	marked_atom = null
	update_icon()

/obj/item/multitool/circuit/proc/cleanup_marked_atom(datum/source)
	SIGNAL_HANDLER
	if(source == marked_atom)
		clear_marked_atom()
