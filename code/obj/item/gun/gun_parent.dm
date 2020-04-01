var/list/forensic_IDs = new/list() //Global list of all guns, based on bioholder uID stuff

/obj/item/gun
	name = "gun"
	icon = 'icons/obj/gun.dmi'
	inhand_image_icon = 'icons/mob/inhand/hand_weapons.dmi'
	flags =  FPRINT | TABLEPASS | CONDUCT | ONBELT | USEDELAY | EXTRADELAY
	event_handler_flags = USE_GRAB_CHOKE | USE_FLUID_ENTER
	special_grab = /obj/item/grab/gunpoint

	item_state = "gun"
	m_amt = 2000
	force = 10.0
	throwforce = 5
	w_class = 3.0
	throw_speed = 4
	throw_range = 6
	contraband = 4
	hide_attack = 2 //Point blanking... gross
	pickup_sfx = "sound/items/pickup_gun.ogg"

	var/continuous = 0 //If 1, fire pixel based while button is held.
	var/c_interval = 3 //Interval between shots while button is held.
	var/c_windup = 0 //Time before we start firing while button is held - think minigun.
	var/c_windup_sound = null //Sound to play during windup. TBI

	var/c_firing = 0
	var/c_mouse_down = 0
	var/datum/gunTarget/c_target = null

	var/suppress_fire_msg = 0

	var/spread_angle = 0
	var/datum/projectile/current_projectile = null
	var/list/projectiles = null
	var/current_projectile_num = 1
	var/silenced = 0
	var/can_dual_wield = 1

	var/slowdown = 0 //Movement delay attack after attack
	var/slowdown_time = 10 //For this long

	var/forensic_ID = null
	var/add_residue = 0 // Does this gun add gunshot residue when fired (Convair880)?

	var/charge_up = 0 //Does this gun have a charge up time and how long is it? 0 = normal instant shots.

	buildTooltipContent()
		var/Tcontent = ..()
		if(current_projectile)
			Tcontent += "<br><img style=\"display:inline;margin:0\" src=\"[resource("images/tooltips/ranged.png")]\" width=\"10\" height=\"10\" /> Bullet Power: [current_projectile.power] - [current_projectile.ks_ratio * 100]% lethal"

		return Tcontent

	New()
		SPAWN_DBG(2 SECONDS)
			src.forensic_ID = src.CreateID()
			forensic_IDs.Add(src.forensic_ID)
		return ..()

/datum/gunTarget
	var/params = null
	var/target = null
	var/user = 0

/obj/item/gun/onMouseDrag(src_object,over_object,src_location,over_location,src_control,over_control,params)
	if(!continuous) return
	if(c_target == null) c_target = new()
	c_target.params = params2list(params)
	c_target.target = over_object
	c_target.user = usr

/obj/item/gun/onMouseDown(atom/object,location,control,params) //This doesnt work with reach, will pistolwhip once. FIX.
	if(!continuous) return
	if(object == src || (!isturf(object.loc) && !isturf(object))) return
	if(ishuman(usr))
		var/mob/living/carbon/human/H = usr
		if(H.in_throw_mode) return
	c_mouse_down = 1
	SPAWN_DBG(c_windup)
		if(!c_firing && c_mouse_down)
			continuousFire(object, params, usr)

/obj/item/gun/onMouseUp(object,location,control,params)
	c_mouse_down = 0

/obj/item/gun/proc/continuousFire(atom/target, params, mob/user)
	if(!continuous) return
	if(c_target == null) c_target = new()
	c_target.params = params2list(params)
	c_target.target = target
	c_target.user = user

	if(!c_firing)
		c_firing = 1
		SPAWN_DBG(0)
			while(src && src.c_mouse_down)
				pixelaction(src.c_target.target, src.c_target.params, src.c_target.user, 0, 1)
				suppress_fire_msg = 1
				sleep(src.c_interval)
			src.c_firing = 0
			suppress_fire_msg = 0

/obj/item/gun/proc/CreateID() //Creates a new tracking id for the gun and returns it.
	var/newID = ""

	do
		for(var/i = 1 to 10) // 20 characters are way too fuckin' long for anyone to care about
			newID += "[pick(numbersAndLetters)]"
	while(forensic_IDs.Find(newID))

	return newID

///CHECK_LOCK
///Call to run a weaponlock check vs the users implant
///Return 0 for fail
/obj/item/gun/proc/check_lock(var/user as mob)
	return 1

///CHECK_VALID_SHOT
///Call to check and make sure the shot is ok
///Not called much atm might remove, is now inside shoot
/obj/item/gun/proc/check_valid_shot(atom/target as mob|obj|turf|area, mob/user as mob)
	var/turf/T = get_turf(user)
	var/turf/U = get_turf(target)
	if(!istype(T) || !istype(U))
		return 0
	if (U == T)
		//user.bullet_act(current_projectile)
		return 0
	return 1
/*
/obj/item/gun/proc/emag(obj/item/A as obj, mob/user as mob)
	if(istype(A, /obj/item/card/emag))
		boutput(user, "<span style=\"color:red\">No lock to break!</span>")
		return 1
	return 0
*/
/obj/item/gun/emag_act(var/mob/user, var/obj/item/card/emag/E)
	if (user)
		boutput(user, "<span style=\"color:red\">No lock to break!</span>")
	return 0

/obj/item/gun/attack_self(mob/user as mob)
	if(src.projectiles && src.projectiles.len > 1)
		src.current_projectile_num = ((src.current_projectile_num) % src.projectiles.len) + 1
		src.current_projectile = src.projectiles[src.current_projectile_num]
		boutput(user, "<span style=\"color:blue\">you set the output to [src.current_projectile.sname].</span>")
	return

/datum/action/bar/icon/guncharge
	duration = 150
	interrupt_flags = INTERRUPT_MOVE | INTERRUPT_ACT | INTERRUPT_STUNNED | INTERRUPT_ACTION
	id = "guncharge"
	icon = 'icons/obj/items.dmi'
	icon_state = "screwdriver"
	var/obj/item/gun/ownerGun
	var/pox
	var/poy
	var/user_turf
	var/target_turf

	New(_gun, _pox, _poy, _uturf, _tturf, _time, _icon, _icon_state)
		ownerGun = _gun
		pox = _pox
		poy = _poy
		user_turf = _uturf
		target_turf = _tturf
		icon = _icon
		icon_state = _icon_state
		duration = _time
		..()

	onEnd()
		..()
		ownerGun.shoot(target_turf, user_turf, owner, pox, poy)

/obj/item/gun/pixelaction(atom/target, params, mob/user, reach, continuousFire = 0)
	if (reach)
		return 0
	if (!isturf(user.loc))
		return 0
	if(continuous && !continuousFire)
		return 0

	var/pox = text2num(params["icon-x"]) - 16
	var/poy = text2num(params["icon-y"]) - 16
	var/turf/user_turf = get_turf(user)
	var/turf/target_turf = get_turf(target)

	if(charge_up && !can_dual_wield && canshoot())
		actions.start(new/datum/action/bar/icon/guncharge(src, pox, poy, user_turf, target_turf, charge_up, icon, icon_state), user)
	else
		shoot(target_turf, user_turf, user, pox, poy)

	//if they're holding a gun in each hand... why not shoot both!
	if (can_dual_wield && (!charge_up) && ishuman(user))
		if(user.hand && istype(user.r_hand, /obj/item/gun) && user.r_hand:can_dual_wield)
			SPAWN_DBG(0.2 SECONDS)
				user.r_hand:shoot(target_turf,user_turf,user, pox+rand(-2,2), poy+rand(-2,2))
		else if(!user.hand && istype(user.l_hand, /obj/item/gun)&& user.l_hand:can_dual_wield)
			SPAWN_DBG(0.2 SECONDS)
				user.l_hand:shoot(target_turf,user_turf,user, pox+rand(-2,2), poy+rand(-2,2))

	return 1

/obj/item/gun/attack(mob/M as mob, mob/user as mob)
	if (!M || !ismob(M)) //Wire note: Fix for Cannot modify null.lastattacker
		return ..()

	user.lastattacked = M
	M.lastattacker = user
	M.lastattackertime = world.time

	if(user.a_intent != INTENT_HELP && isliving(M))
		if (user.a_intent == INTENT_GRAB)
			attack_particle(user,M)
			return ..()
		else
			src.shoot_point_blank(M, user)
	else
		..()
		attack_particle(user,M)

#ifdef DATALOGGER
		game_stats.Increment("violence")
#endif
		return

/obj/item/gun/proc/shoot_point_blank(var/mob/M as mob, var/mob/user as mob, var/second_shot = 0)
	if (!M || !user)
		return

	if (isghostdrone(user))
		user.show_text("<span class='combat bold'>Your internal law subroutines kick in and prevent you from using [src]!</span>")
		return

	//Ok. i know it's kind of dumb to add this param 'second_shot' to the shoot_point_blank proc just to make sure pointblanks don't repeat forever when we could just move these checks somewhere else.
	//but if we do the double-gun checks here, it makes stuff like double-hold-at-gunpoint-pointblanks easier!
	if (can_dual_wield && !second_shot)
		//brutal double-pointblank shots
		if (ishuman(user))
			if(user.hand && istype(user.r_hand, /obj/item/gun) && user.r_hand:can_dual_wield)
				var/target_turf = get_turf(M)
				SPAWN_DBG(0.2 SECONDS)
					if (get_dist(user,M)<=1)
						user.r_hand:shoot_point_blank(M,user,second_shot = 1)
					else
						user.r_hand:shoot(target_turf,get_turf(user), user, rand(-5,5), rand(-5,5))
			else if(!user.hand && istype(user.l_hand, /obj/item/gun) && user.l_hand:can_dual_wield)
				var/target_turf = get_turf(M)
				SPAWN_DBG(0.2 SECONDS)
					if (get_dist(user,M)<=1)
						user.l_hand:shoot_point_blank(M,user,second_shot = 11)
					else
						user.l_hand:shoot(target_turf,get_turf(user), user, rand(-5,5), rand(-5,5))


	if (!canshoot())
		if (!silenced)
			M.visible_message("<span style=\"color:red\"><B>[user] tries to shoot [user == M ? "[him_or_her(user)]self" : M] with [src] point-blank, but it was empty!</B></span>")
			playsound(user, "sound/weapons/Gunclick.ogg", 60, 1)
		else
			user.show_text("*click* *click*", "red")
		return

	if (ishuman(user) && src.add_residue) // Additional forensic evidence for kinetic firearms (Convair880).
		var/mob/living/carbon/human/H = user
		H.gunshot_residue = 1

	if (!src.silenced)
		for (var/mob/O in AIviewers(M, null))
			if (O.client)
				O.show_message("<span style=\"color:red\"><B>[user] shoots [user == M ? "[him_or_her(user)]self" : M] point-blank with [src]!</B></span>")
	else
		user.show_text("<span style=\"color:red\">You silently shoot [user == M ? "yourself" : M] point-blank with [src]!</span>") // Was non-functional (Convair880).

	if (!process_ammo(user))
		return
	var/obj/projectile/P = initialize_projectile_ST(user, current_projectile, M)
	if (!P)
		return

	if (user == M)
		P.shooter = null
		P.mob_shooter = user

	alter_projectile(P)
	P.forensic_ID = src.forensic_ID // Was missing (Convair880).
	P.was_pointblank = 1
	hit_with_existing_projectile(P, M) // Includes log entry.

	var/mob/living/L = M
	if (M && isalive(M))
		L.lastgasp()
	M.set_clothing_icon_dirty()
	src.update_icon()

/obj/item/gun/afterattack(atom/target as mob|obj|turf|area, mob/user as mob, flag)
	src.add_fingerprint(user)
	if(continuous) return
	if (flag)
		return

/obj/item/gun/proc/alter_projectile(var/obj/projectile/P)
	return

/obj/item/gun/proc/shoot(var/target,var/start,var/mob/user,var/POX,var/POY)
	if (isghostdrone(user))
		user.show_text("<span class='combat bold'>Your internal law subroutines kick in and prevent you from using [src]!</span>")
		return
	if (!canshoot())
		if (ismob(user))
			user.show_text("*click* *click*", "red") // No more attack messages for empty guns (Convair880).
			if (!silenced)
				playsound(user, "sound/weapons/Gunclick.ogg", 60, 1)
		return
	if (!process_ammo(user))
		return
	if (!istype(target, /turf) || !istype(start, /turf))
		return
	if (!istype(src.current_projectile,/datum/projectile/))
		return

	if (ismob(user))
		var/mob/M = user
		if (M.mob_flags & AT_GUNPOINT)
			for(var/obj/item/grab/gunpoint/G in M.grabbed_by)
				G.shoot()
		if(slowdown)
			SPAWN_DBG(-1)
				M.movement_delay_modifier += slowdown
				sleep(slowdown_time)
				M.movement_delay_modifier -= slowdown

	var/obj/projectile/P = shoot_projectile_ST_pixel_spread(user, current_projectile, target, POX, POY, spread_angle)
	if (P)
		alter_projectile(P)
		P.forensic_ID = src.forensic_ID

	if(user && !suppress_fire_msg)
		if(!src.silenced)
			for(var/mob/O in AIviewers(user, null))
				O.show_message("<span style=\"color:red\"><B>[user] fires [src] at [target]!</B></span>", 1, "<span style=\"color:red\">You hear a gunshot</span>", 2)
		else
			if (ismob(user)) // Fix for: undefined proc or verb /obj/item/mechanics/gunholder/show text().
				user.show_text("<span style=\"color:red\">You silently fire the [src] at [target]!</span>") // Some user feedback for silenced guns would be nice (Convair880).

		var/turf/T = target
		logTheThing("combat", user, null, "fires \a [src] from [log_loc(user)], vector: ([T.x - user.x], [T.y - user.y]), dir: <I>[dir2text(get_dir(user, target))]</I>, projectile: <I>[P.name]</I>[P.proj_data && P.proj_data.type ? ", [P.proj_data.type]" : null]")

	if (ismob(user))
		var/mob/M = user
		if (ishuman(M) && src.add_residue) // Additional forensic evidence for kinetic firearms (Convair880).
			var/mob/living/carbon/human/H = user
			H.gunshot_residue = 1
		M.next_click = world.time + 4

	src.update_icon()

/obj/item/gun/proc/canshoot()
	return 0

/obj/item/gun/examine()
	set src in usr
	set category = "Local"

	if (src.artifact)
		boutput(usr, "You have no idea what the hell this thing is!")
		return

	..()
	return

/obj/item/gun/proc/update_icon()
	return 0

/obj/item/gun/proc/process_ammo(var/mob/user)
	boutput(user, "<span style=\"color:red\">*click* *click*</span>")
	if (!src.silenced)
		playsound(user, "sound/weapons/Gunclick.ogg", 60, 1)
	return 0

// Could be useful in certain situations (Convair880).
/obj/item/gun/proc/logme_temp(mob/user as mob, obj/item/gun/G as obj, obj/item/ammo/A as obj)
	if (!user || !G || !A)
		return

	else if (istype(G, /obj/item/gun/kinetic) && istype(A, /obj/item/ammo/bullets))
		logTheThing("combat", user, null, "reloads [G] (<b>Ammo type:</b> <i>[G.current_projectile.type]</i>) at [log_loc(user)].")
		return

	else if (istype(G, /obj/item/gun/energy) && istype(A, /obj/item/ammo/power_cell))
		logTheThing("combat", user, null, "reloads [G] (<b>Cell type:</b> <i>[A.type]</i>) at [log_loc(user)].")
		return

	else return

/obj/item/gun/custom_suicide = 1
/obj/item/gun/suicide(var/mob/living/carbon/human/user as mob)
	if (!src.user_can_suicide(user))
		return 0
	if (!src.canshoot())
		return 0

	src.process_ammo(user)
	user.visible_message("<span style='color:red'><b>[user] places [src] against [his_or_her(user)] head!</b></span>")
	var/dmg = user.get_brute_damage() + user.get_burn_damage()
	src.shoot_point_blank(user, user)
	var/new_dmg = user.get_brute_damage() + user.get_burn_damage()
	if (new_dmg >= (dmg + 20)) // it did some appreciable amount of damage
		user.TakeDamage("head", 500, 0)
		user.updatehealth()
	else if (new_dmg < (dmg + 20))
		user.visible_message("<span style='color:red'>[user] hangs their head in shame because they chose such a weak gun.</span>")
	return 1

/obj/item/gun/on_spin_emote(var/mob/living/carbon/human/user as mob)
	if ((user.bioHolder && user.bioHolder.HasEffect("clumsy") && prob(50)) || (user.reagents && prob(user.reagents.get_reagent_amount("ethanol") / 2)) || prob(5))
		user.visible_message("<span style=\"color:red\"><b>[user] accidentally shoots [him_or_her(user)]self with [src]!</b></span>")
		src.shoot_point_blank(user, user)