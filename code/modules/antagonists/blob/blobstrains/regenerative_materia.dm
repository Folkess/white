//does toxin damage, hallucination, targets think they're not hurt at all
/datum/blobstrain/reagent/regenerative_materia
	name = "Регенеративная материя"
	description = "нанесет токсиновый урон и заставит цели поверить, что они полностью исцелены."
	analyzerdescdamage = "Наносит токсиновый урон и вводит токсин, который заставляет цель поверить в то, что она полностью исцелена. Core восстанавливается намного быстрее."
	color = "#A88FB7"
	complementary_color = "#AF7B8D"
	message_living = " и я чувствую себя <i>живее</i>"
	reagent = /datum/reagent/blob/regenerative_materia
	core_regen_bonus = 20
	point_rate_bonus = 1

/datum/reagent/blob/regenerative_materia
	name = "Регенеративная материя"
	enname = "Regenerative Materia"
	taste_description = "небеса"
	color = "#A88FB7"

/datum/reagent/blob/regenerative_materia/expose_mob(mob/living/exposed_mob, methods=TOUCH, reac_volume, show_message, touch_protection, mob/camera/blob/overmind)
	. = ..()
	reac_volume = return_mob_expose_reac_volume(exposed_mob, methods, reac_volume, show_message, touch_protection, overmind)
	exposed_mob.adjust_drugginess(reac_volume)
	if(exposed_mob.reagents)
		exposed_mob.reagents.add_reagent(/datum/reagent/blob/regenerative_materia, 0.2*reac_volume)
		exposed_mob.reagents.add_reagent(/datum/reagent/toxin/spore, 0.2*reac_volume)
	exposed_mob.apply_damage(0.7*reac_volume, TOX)

/datum/reagent/blob/regenerative_materia/on_mob_life(mob/living/carbon/C, delta_time, times_fired)
	C.adjustToxLoss(1 * REAGENTS_EFFECT_MULTIPLIER * delta_time)
	C.hal_screwyhud = SCREWYHUD_HEALTHY //fully healed, honest
	..()

/datum/reagent/blob/regenerative_materia/on_mob_end_metabolize(mob/living/M)
	if(iscarbon(M))
		var/mob/living/carbon/N = M
		N.hal_screwyhud = 0
	..()
