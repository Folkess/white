//////lavaland surface papers

/obj/item/paper/fluff/stations/lavaland/surface/henderson_report
	name = "Important Notice - Mrs. Henderson"
	info = "Nothing of interest to report."

//ratvar

/obj/structure/dead_ratvar
	name = "огромная развалина"
	desc = "Останки монструозной военной машины."
	icon = 'icons/obj/lavaland/dead_ratvar.dmi'
	icon_state = "dead_ratvar"
	flags_1 = ON_BORDER_1
	appearance_flags = LONG_GLIDE
	layer = FLY_LAYER
	plane = ABOVE_GAME_PLANE
	anchored = TRUE
	density = TRUE
	bound_width = 416
	bound_height = 64
	pixel_y = -10
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
