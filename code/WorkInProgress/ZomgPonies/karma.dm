

proc/sql_report_karma(var/mob/spender, var/mob/receiver)
	var/sqlspendername = spender.name
	var/sqlspenderkey = spender.key
	var/sqlreceivername = receiver.name
	var/sqlreceiverkey = receiver.key
	var/sqlreceiverrole = "None"
	var/sqlreceiverspecial = "None"


	var/sqlspenderip = spender.client.address

	if(receiver.mind)
		if(receiver.mind.special_role)
			sqlreceiverspecial = receiver.mind.special_role
		if(receiver.mind.assigned_role)
			sqlreceiverrole = receiver.mind.assigned_role

	if(!dbcon.IsConnected())
		log_game("SQL ERROR during karma logging. Failed to connect.")
	else
		var/sqltime = time2text(world.realtime, "YYYY-MM-DD hh:mm:ss")
		var/DBQuery/query = dbcon.NewQuery("INSERT INTO karma (spendername, spenderkey, receivername, receiverkey, receiverrole, receiverspecial, spenderip, time) VALUES ('[sqlspendername]', '[sqlspenderkey]', '[sqlreceivername]', '[sqlreceiverkey]', '[sqlreceiverrole]', '[sqlreceiverspecial]', '[sqlspenderip]', '[sqltime]')")
		if(!query.Execute())
			var/err = query.ErrorMsg()
			log_game("SQL ERROR during karma logging. Error : \[[err]\]\n")


		query = dbcon.NewQuery("SELECT * FROM karmatotals WHERE byondkey='[receiver.key]'")
		query.Execute()

		var/karma
		var/id
		while(query.NextRow())
			id = query.item[1]
			karma = text2num(query.item[3])
		if(karma == null)
			karma = 1
			query = dbcon.NewQuery("INSERT INTO karmatotals (byondkey, karma) VALUES ('[receiver.key]', [karma])")
			if(!query.Execute())
				var/err = query.ErrorMsg()
				log_game("SQL ERROR during karmatotal logging (adding new key). Error : \[[err]\]\n")
		else
			karma += 1
			query = dbcon.NewQuery("UPDATE karmatotals SET karma=[karma] WHERE id=[id]")
			if(!query.Execute())
				var/err = query.ErrorMsg()
				log_game("SQL ERROR during karmatotal logging (updating existing entry). Error : \[[err]\]\n")


var/list/karma_spenders = list()

/mob/verb/spend_karma(var/mob/M in player_list) // Karma system -- TLE
	set name = "Award Karma"
	set desc = "Let the gods know whether someone's been naughty or nice. <One use only>"
	set category = "Special Verbs"
	if(!istype(M, /mob))
		usr << "\red That's not a mob. You shouldn't have even been able to specify that. Please inform TLE post haste."
		return

	if(!M.client)
		usr << "\red That mob has no client connected at the moment."
		return
	if(src.client.karma_spent)
		usr << "\red You've already spent your karma for the round."
		return
	for(var/a in karma_spenders)
		if(a == src.key)
			usr << "\red You've already spent your karma for the round."
			return
	if(M.key == src.key)
		usr << "\red You can't spend karma on yourself!"
		return
	if(M.client.address == src.client.address)
		message_admins("\red Illegal karma spending detected from [src.key] to [M.key]. Using the same IP!")
		log_game("\red Illegal karma spending detected from [src.key] to [M.key]. Using the same IP!")
		usr << "\red The karma system is not available to multi-accounters."
	var/choice = input("Give [M.name] good karma?", "Karma") in list("Good", "Cancel")
	if(!choice || choice == "Cancel")
		return
	if(choice == "Good")
		M.client.karma += 1
	usr << "[choice] karma spent on [M.name]."
	src.client.karma_spent = 1
	karma_spenders.Add(src.key)
	if(M.client.karma <= -2 || M.client.karma >= 2)
		var/special_role = "None"
		var/assigned_role = "None"
		var/karma_diary = file("data/logs/karma_[time2text(world.realtime, "YYYY/MM-Month/DD-Day")].log")
		if(M.mind)
			if(M.mind.special_role)
				special_role = M.mind.special_role
			if(M.mind.assigned_role)
				assigned_role = M.mind.assigned_role
		karma_diary << "[M.name] ([M.key]) [assigned_role]/[special_role]: [M.client.karma] - [time2text(world.timeofday, "hh:mm:ss")] given by [src.key]"

	sql_report_karma(src, M)




mob/verb/check_karma()
	set name = "Check Karma"
	set category = "Special Verbs"
	set desc = "Reports how much karma you have accrued"

	if(!dbcon.IsConnected())
		usr << "\red Unable to connect to karma database. Please try again later.<br>"
		return
	else
		var/DBQuery/query = dbcon.NewQuery("SELECT karma FROM karmatotals WHERE byondkey='[src.key]'")
		query.Execute()

		var/currentkarma
		while(query.NextRow())
			currentkarma = query.item[1]
		if(currentkarma)
			usr << "<b>Your current karma is:</b> [currentkarma]<br>"
		else
			usr << "<b>Your current karma is:</b> 0<br>"
