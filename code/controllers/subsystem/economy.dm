SUBSYSTEM_DEF(economy)
	name = "Economy"
	wait = 5 MINUTES
	init_order = INIT_ORDER_ECONOMY
	runlevels = RUNLEVEL_GAME
	var/roundstart_paychecks = 5
	var/budget_pool = 1250
	var/list/department_accounts = list(ACCOUNT_STA = ACCOUNT_STA_NAME,
										ACCOUNT_CIV = ACCOUNT_CIV_NAME,
										ACCOUNT_ENG = ACCOUNT_ENG_NAME,
										ACCOUNT_SCI = ACCOUNT_SCI_NAME,
										ACCOUNT_MED = ACCOUNT_MED_NAME,
										ACCOUNT_SRV = ACCOUNT_SRV_NAME,
										ACCOUNT_CAR = ACCOUNT_CAR_NAME,
										ACCOUNT_SEC = ACCOUNT_SEC_NAME,
										ACCOUNT_TRA = ACCOUNT_TRA_NAME)
	var/list/generated_accounts = list()
	var/full_ancap = FALSE // Enables extra money charges for things that normally would be free, such as sleepers/cryo/cloning.
							//Take care when enabling, as players will NOT respond well if the economy is set up for low cash flows.
	/// Departmental cash provided to science when a node is researched in specific configs.
	var/techweb_bounty = 250
	/**
	  * List of normal (no department ones) accounts' identifiers with associated datum accounts, for big O performance.
	  * A list of sole account datums can be obtained with flatten_list(), another variable would be redundant rn.
	  */
	var/list/bank_accounts_by_id = list()
	var/list/dep_cards = list()
	/// A var that collects the total amount of credits owned in player accounts on station, reset and recounted on fire()
	var/station_total = 0
	/// A var that tracks how much money is expected to be on station at a given time. If less than station_total prices go up in vendors.
	var/station_target = 1
	/// A passively increasing buffer to help alliviate inflation later into the shift, but to a lesser degree.
	var/station_target_buffer = 0
	/// A var that displays the result of inflation_value for easier debugging and tracking.
	var/inflation_value = 1
	/// How many civilain bounties have been completed so far this shift? Affects civilian budget payout values.
	var/civ_bounty_tracker = 0
	/// Contains the message to send to newscasters about price inflation and earnings, updated on price_update()
	var/earning_report
	///The modifier multiplied to the value of bounties paid out.
	var/bounty_modifier = 1
	///The modifier multiplied to the value of cargo pack prices.
	var/pack_price_modifier = 1
	var/market_crashing = FALSE

	var/bonus_money = 0

	var/obj/machinery/computer/price_controller/PC = null
	/// Total value of exported materials.
	var/export_total = 0
	/// Total value of imported goods.
	var/import_total = 0
	/// Number of mail items generated.
	var/mail_waiting = 0

/datum/controller/subsystem/economy/Initialize()
	//removes cargo from the split
	var/budget_to_hand_out = round(budget_pool / department_accounts.len -1)
	for(var/dep_id in department_accounts)
		if(dep_id == ACCOUNT_CAR) //cargo starts with NOTHING
			new /datum/bank_account/department(dep_id, 0)
			continue
		new /datum/bank_account/department(dep_id, budget_to_hand_out)
	return SS_INIT_SUCCESS

/datum/controller/subsystem/economy/Recover()
	generated_accounts = SSeconomy.generated_accounts
	bank_accounts_by_id = SSeconomy.bank_accounts_by_id
	dep_cards = SSeconomy.dep_cards

/datum/controller/subsystem/economy/fire(resumed = 0)
	var/temporary_total = 0
	var/delta_time = wait / (5 MINUTES)
	departmental_payouts()
	station_total = 0
	station_target_buffer += STATION_TARGET_BUFFER
	for(var/account in bank_accounts_by_id)
		var/datum/bank_account/bank_account = bank_accounts_by_id[account]
		if(bank_account?.account_job && !ispath(bank_account.account_job))
			temporary_total += (bank_account.account_job.paycheck * STARTING_PAYCHECKS)
		station_total += bank_account.account_balance
	station_target = max(round(temporary_total / max(bank_accounts_by_id.len * 2, 1)) + station_target_buffer, 1)
	if(!market_crashing)
		price_update()
	var/effective_mailcount = round(living_player_count()/(inflation_value - 0.5)) //More mail at low inflation, and vis versa.
	mail_waiting += clamp(effective_mailcount, 1, MAX_MAIL_PER_MINUTE * delta_time)

/**
 * Handy proc for obtaining a department's bank account, given the department ID, AKA the define assigned for what department they're under.
 */
/datum/controller/subsystem/economy/proc/get_dep_account(dep_id)
	for(var/datum/bank_account/department/D in generated_accounts)
		if(D.department_id == dep_id)
			return D

/**
 * Departmental income payments are kept static and linear for every department, and paid out once every 5 minutes, as determined by MAX_GRANT_DPT.
 * Iterates over every department account for the same payment.
 */
/datum/controller/subsystem/economy/proc/departmental_payouts()
	for(var/iteration in department_accounts)
		var/datum/bank_account/dept_account = get_dep_account(iteration)
		if(!dept_account)
			continue
		dept_account.adjust_money(MAX_GRANT_DPT)

/**
 * Updates the prices of all station vendors with the inflation_value, increasing/decreasing costs across the station, and alerts the crew.
 *
 * Iterates over the machines list for vending machines, resets their regular and premium product prices (Not contraband), and sends a message to the newscaster network.
 **/
/datum/controller/subsystem/economy/proc/price_update()
	for(var/obj/machinery/vending/V in GLOB.machines)
		if(istype(V, /obj/machinery/vending/custom))
			continue
		if(!is_station_level(V.z))
			continue
		V.reset_prices(V.product_records, V.coin_records)
	earning_report = "<b>Экономический отчет сектора</b><br><br> В настоящее время цены поставщиков в секторе <b>[SSeconomy.inflation_value()*100]%</b>.<br><br> Расходная мощность станции в настоящее время <b>[station_total] кредит[get_num_string(station_total)]</b>, а целевое довольствие экипажа составляет <b>[station_target] кредит[get_num_string(station_target)]</b>.<br><br> Это всё от <i>Отдел экономистов NanoTrasen</i>."
	GLOB.news_network.submit_article(earning_report, "Экономический отчет сектора", "Станционные Объявления", null, update_alert = FALSE)

/**
 * Proc that returns a value meant to shift inflation values in vendors, based on how much money exists on the station.
 *
 * If crew are somehow aquiring far too much money, this value will dynamically cause vendables across the station to skyrocket in price until some money is spent.
 * Additionally, civilain bounties will cost less, and cargo goodies will increase in price as well.
 * The goal here is that if you want to spend money, you'll have to get it, and the most efficient method is typically from other players.
 **/
/datum/controller/subsystem/economy/proc/inflation_value()
	if(!bank_accounts_by_id.len)
		return 1
	inflation_value = max(round(((station_total / bank_accounts_by_id.len) / station_target), 0.1), 1.0)
	return inflation_value

/**
 * Прок для получения выплат за покуику товаров
 **/
/datum/controller/subsystem/economy/proc/adjust_station_money(amount, source, slave, product)
	var/datum/bank_account/D = get_dep_account(ACCOUNT_STA)
	if(D && amount)
		D.adjust_money(amount/2)
		if(PC && source && slave && product)
			PC.log_self("+[amount] кр. Источник: [source]. Покупатель: [slave]. Товар: [product].")
