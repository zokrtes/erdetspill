# generatequests.gd - COMPLETELY FIXED with proper array handling
extends Node

const BESTEFAR_VO := "res://assets/sfx/erdetlyd/vox/bestefar"

# tag: quest generation — offer_dialogue etc. (sync changes into data/quests/*.tres when editing baked quests).


func _bestefar_line(line_text: String, clip_file: String = "") -> DialogueLine:
	var dl := DialogueLine.new()
	dl.text = line_text
	if clip_file.is_empty():
		dl.sound = null
	else:
		dl.sound = load("%s/%s" % [BESTEFAR_VO, clip_file]) as AudioStream
	return dl

func _ready():
	if not OS.has_feature("editor"):
		queue_free()
		return
	print("=== Generating Quest Chain: Bestefars Is ===")
	
	var quests_dir = "res://data/quests/"
	_ensure_directory_exists(quests_dir)
	_clear_old_quests(quests_dir)
	
	# Quest 1: En Enkel Forespørsel
	var q1 = _create_quest_1()
	_save_quest(q1, quests_dir + "quest_01_grandpa_request.tres")
	
	# Quest 2: Den Brå Arven
	var q2 = _create_quest_2()
	_save_quest(q2, quests_dir + "quest_02_bank_inheritance.tres")
	
	# Quest 3: Økonomisk Realitet
	var q3 = _create_quest_3()
	_save_quest(q3, quests_dir + "quest_03_economic_reality.tres")
	
	# Quest 4: Skuffelsen
	var q4 = _create_quest_4()
	_save_quest(q4, quests_dir + "quest_04_disappointment.tres")
	
	# Quest 5: Lånekassens Vokter
	var q5 = _create_quest_5()
	_save_quest(q5, quests_dir + "quest_05_scholarship_application.tres")
	
	# Quest 6: Finansielt Gjennombrudd
	var q6 = _create_quest_6()
	_save_quest(q6, quests_dir + "quest_06_bank_deposit.tres")
	
	# Quest 7: Den Andre Isen
	var q7 = _create_quest_7()
	_save_quest(q7, quests_dir + "quest_07_second_icecream.tres")
	
	# Final Quest: Oppdrag Fullført
	var q8 = _create_quest_8()
	_save_quest(q8, quests_dir + "quest_08_final_delivery.tres")

	# Sidequest: Kris og caps
	var q9 = _create_quest_kris_lua()
	_save_quest(q9, quests_dir + "quest_kris_lua.tres")

	# Sidequest chain: Iver -> Steinar
	var q10 = _create_quest_iver()
	_save_quest(q10, quests_dir + "quest_09_iver_bevis.tres")
	var q11 = _create_quest_steinar()
	_save_quest(q11, quests_dir + "quest_10_steinar_grus.tres")
	
	print("\n✅ Main + side quests created successfully!")
	_verify_quests(quests_dir)

func _create_quest_1() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "GRANDPA_REQUEST"
	quest.name = "Bestefars ønske"
	quest.description = "Bestefar vil ha noe."
	quest.brief_description = "Bestefar vil ha noe. Finn ut hva du kan gjøre."
	
	var obj = QuestObjective.new()
	obj.objective_id = "listen_to_grandpa"
	obj.description = "Snakk med bestefar"
	obj.type = QuestObjective.ObjectiveType.TALK_TO_NPC
	obj.target_id = "grandpa"
	obj.target_amount = 1
	quest.objectives.append(obj)
	
	# Gi inheritance_document som reward
	quest.reward_items.append("inheritance_document")
	
	# Unlock BANK_INHERITANCE quest
	quest.unlock_quests.append("BANK_INHERITANCE")
	
	quest.offer_dialogue.append("Mormor er død.")
	quest.offer_dialogue.append("Jeg vil ha to is.")
	quest.offer_dialogue.append("Her er arvedokumentet hennes, løs det inn i banken og kjøp is for pengene.")

	quest.offer_lines.append(_bestefar_line("Mormor er død.", "q01_01.ogg"))
	quest.offer_lines.append(_bestefar_line("Jeg vil ha to is.", "q01_02.ogg"))
	quest.offer_lines.append(_bestefar_line(
		"Her er arvedokumentet hennes, løs det inn i banken og kjøp is for pengene.",
		"q01_03.ogg"
	))

	# Ingen completion-dialogue her; questen fullfores i samme samtale

	return quest

func _create_quest_2() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "BANK_INHERITANCE"
	quest.name = "Arvedokumentet"
	quest.description = "Løs inn dokumentet i banken."
	quest.brief_description = "Snakk med bankansatt"  # ENDRET
	quest.required_quest_ids.append("GRANDPA_REQUEST")
	
	var obj = QuestObjective.new()
	obj.objective_id = "talk_to_bank_teller"  # ENDRET
	obj.description = "Snakk med bankansatt"  # ENDRET
	obj.type = QuestObjective.ObjectiveType.TALK_TO_NPC  # ENDRET fra VISIT_LOCATION
	obj.target_id = "bank_teller"  # ENDRET fra "bank"
	obj.target_amount = 1
	quest.objectives.append(obj)
	
	quest.reward_money = 0
	quest.unlock_quests.append("ECONOMIC_REALITY")
	quest.offer_dialogue.append("Hei.")
	quest.offer_dialogue.append("Mormors arv. 100 kroner.")
	quest.offer_dialogue.append("Ha en fin dag.")
	
	return quest

func _create_quest_3() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "ECONOMIC_REALITY"
	quest.name = "Kjøp is"
	quest.description = "Gå til butikken."
	quest.brief_description = "Gå til butikken."
	quest.required_quest_ids.append("BANK_INHERITANCE")
	
	var obj = QuestObjective.new()
	obj.objective_id = "buy_icecream"
	obj.description = "Kjøp iskrem"
	obj.type = QuestObjective.ObjectiveType.PURCHASE_ITEM
	obj.target_id = "icecream"
	obj.target_amount = 1
	quest.objectives.append(obj)
	
	# Silent quest
	
	quest.unlock_quests.append("GRANDPA_DISAPPOINTMENT")
	
	return quest

func _create_quest_4() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "GRANDPA_DISAPPOINTMENT"
	quest.name = "Tilbake til bestefar"
	quest.description = "Lever det du har til bestefar."
	quest.brief_description = "Lever det du har til bestefar."
	quest.required_quest_ids.append("ECONOMIC_REALITY")
	
	var obj = QuestObjective.new()
	obj.objective_id = "talk_to_grandpa_again"
	obj.description = "Snakk med bestefar"
	obj.type = QuestObjective.ObjectiveType.TALK_TO_NPC
	obj.target_id = "grandpa"
	obj.target_amount = 1
	quest.objectives.append(obj)
	
	quest.unlock_quests.append("SCHOLARSHIP_APPLICATION")
	quest.offer_dialogue.append("Én is.")
	quest.offer_dialogue.append("§Jeg hadde bare nok til én is.")
	quest.offer_dialogue.append("Du er ung. Søk stipend hos Lånekassa.")
	quest.offer_dialogue.append("Ikke kom tilbake uten to is.")
	quest.completion_dialogue.append("Ikke kom tilbake uten to is.")

	quest.offer_lines.append(_bestefar_line("Én is.", "q04_01.ogg"))
	quest.offer_lines.append(_bestefar_line("§Jeg hadde bare nok til én is.", ""))
	quest.offer_lines.append(_bestefar_line("Du er ung. Søk stipend hos Lånekassa.", "q04_02.ogg"))
	quest.offer_lines.append(_bestefar_line("Ikke kom tilbake uten to is.", "q04_03.ogg"))
	quest.completion_lines.append(_bestefar_line("Ikke kom tilbake uten to is.", "q04_03.ogg"))

	return quest

func _create_quest_5() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "SCHOLARSHIP_APPLICATION"
	quest.name = "Stipend"
	quest.description = "Gå til Lånekassa"
	quest.brief_description = "Det finnes kanskje måter å skaffe mer penger på."
	quest.required_quest_ids.append("GRANDPA_DISAPPOINTMENT")
	
	var talk_obj = QuestObjective.new()
	talk_obj.objective_id = "talk_to_chief_keef"
	talk_obj.description = "Snakk med Chief Keef i Lånekassa"
	talk_obj.type = QuestObjective.ObjectiveType.TALK_TO_NPC
	talk_obj.target_id = "chief_keef"
	talk_obj.target_amount = 1
	quest.objectives.append(talk_obj)

	var minigame_obj = QuestObjective.new()
	minigame_obj.objective_id = "complete_scholarship_form"
	minigame_obj.description = "Fullfør stipendskjema-minigame"
	minigame_obj.type = QuestObjective.ObjectiveType.MINIGAME
	minigame_obj.target_id = "scholarship_form"
	minigame_obj.target_amount = 1
	quest.objectives.append(minigame_obj)
	
	quest.reward_money = 0
	quest.reward_items.append("approved_application")
	quest.unlock_quests.append("BANK_DEPOSIT")
	quest.offer_dialogue.append("Eg er lei av folk som sit og snakkar om at Lånekassen bryr seg ikkje og fikser ingenting.")
	quest.offer_dialogue.append("Du veit ikkje kva du snakkar om.")
	quest.offer_dialogue.append("Me sit her kvar dag, behandlar søknadar og held systemet i gang.")
	quest.offer_dialogue.append("Du trur det er lett? Prøv å handtere tusen studentar som masar om stipend samtidig.")
	quest.offer_dialogue.append("Stasjonen er til høyre for deg. Fyll ut og send inn.")
	quest.completion_dialogue.append("Godkjent.")
	quest.completion_dialogue.append("Her er søknaden din.")
	
	return quest

func _create_quest_6() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "BANK_DEPOSIT"
	quest.name = "Tilbake til banken"
	quest.description = "Gå til banken."
	quest.brief_description = "Gå til banken."
	quest.required_quest_ids.append("SCHOLARSHIP_APPLICATION")
	
	var obj = QuestObjective.new()
	obj.objective_id = "talk_to_bank_teller_again"  # ENDRET
	obj.description = "Snakk med bankansatt"  # ENDRET
	obj.type = QuestObjective.ObjectiveType.TALK_TO_NPC  # ENDRET fra VISIT_LOCATION
	obj.target_id = "bank_teller"  # ENDRET fra "bank"
	obj.target_amount = 1
	quest.objectives.append(obj)
	
	quest.unlock_quests.append("SECOND_ICECREAM")
	quest.offer_dialogue.append("Tilbake igjen.")
	quest.offer_dialogue.append("Stipend. Greit.")
	quest.offer_dialogue.append("Ha en fin dag.")
	
	return quest

func _create_quest_7() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "SECOND_ICECREAM"
	quest.name = "Én is til"
	quest.description = "Kjøp enda en is. Du trenger mer penger."
	quest.brief_description = "Du vet hva du må gjøre."
	quest.required_quest_ids.append("BANK_DEPOSIT")
	
	var obj = QuestObjective.new()
	obj.objective_id = "buy_second_icecream"
	obj.description = "Kjøp enda en is. Du trenger mer penger."
	obj.type = QuestObjective.ObjectiveType.PURCHASE_ITEM
	obj.target_id = "icecream"
	obj.target_amount = 1
	quest.objectives.append(obj)
	
	# Silent quest
	
	quest.unlock_quests.append("FINAL_DELIVERY")
	
	return quest

func _create_quest_8() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "FINAL_DELIVERY"
	quest.name = "Lever isen"
	quest.description = "Bestefar venter."
	quest.brief_description = "Du vet hva du må gjøre."
	quest.required_quest_ids.append("SECOND_ICECREAM")
	
	var obj = QuestObjective.new()
	obj.objective_id = "deliver_icecreams"
	obj.description = "Snakk med bestefar etter at fryseren har 2 is"
	obj.type = QuestObjective.ObjectiveType.TALK_TO_NPC
	obj.target_id = "grandpa"
	obj.target_amount = 1
	obj.progress_flavor = "Snakk med bestefar når fryseren er klar"
	quest.objectives.append(obj)
	
	quest.reward_title = "Isens Utvalgte"
	quest.offer_dialogue.append("Er det is?")
	quest.completion_dialogue.append("To is. Endelig.")
	quest.completion_dialogue.append("Bra gjort. Jeg er stolt av deg.")

	quest.offer_lines.append(_bestefar_line("Er det is?", "q08_01.ogg"))
	quest.completion_lines.append(_bestefar_line("To is. Endelig.", "q08_02.ogg"))
	quest.completion_lines.append(_bestefar_line("Bra gjort. Jeg er stolt av deg.", "q08_03.ogg"))

	return quest


func _create_quest_kris_lua() -> Quest:
	var quest := Quest.new()
	quest.quest_id = "KRIS_LUA"
	quest.name = "Capsen til Kris"
	quest.description = "Kris savner capsene sine."
	quest.brief_description = "Finn Kris sine caps."
	quest.quest_type = Quest.QuestType.GATHER
	quest.required_quest_ids = []

	var obj := QuestObjective.new()
	obj.objective_id = "find_hat"
	obj.description = "Finn Peak Performance-caps"
	obj.type = QuestObjective.ObjectiveType.GATHER_ITEM
	obj.target_id = "peak_performance_lua"
	obj.target_amount = 1
	quest.objectives.append(obj)

	var talk_kris := QuestObjective.new()
	talk_kris.objective_id = "return_lua_to_kris"
	talk_kris.description = "Lever capsen til Kris"
	talk_kris.type = QuestObjective.ObjectiveType.TALK_TO_NPC
	talk_kris.target_id = "kris"
	talk_kris.target_amount = 1
	quest.objectives.append(talk_kris)

	quest.reward_money = 150
	quest.offer_dialogue.append("Har du sett capsene mine?")
	quest.offer_dialogue.append("Peak Performance-caps.")
	quest.offer_dialogue.append("Grusbrødrene tok den.")
	quest.offer_dialogue.append("De sitter i garasjen sin der nede.")
	quest.completion_dialogue.append("Liker du rimming?")
	quest.completion_dialogue.append("Takk.")
	return quest

func _create_quest_iver() -> Quest:
	var quest := Quest.new()
	quest.quest_id = "IVER_BEVIS"
	quest.name = "Ivers ære"
	quest.description = "Bevis noe for Iver."
	quest.brief_description = "Skaff 3 kråkefjær og 1 elgskinn, og lever til Iver."
	quest.required_quest_ids = []
	quest.unlock_quests.append("STEINAR_GRUS")

	var fugl_obj := QuestObjective.new()
	fugl_obj.objective_id = "collect_fugleskinn"
	fugl_obj.description = "Samle 3 kråkefjær på Elgveien"
	fugl_obj.type = QuestObjective.ObjectiveType.GATHER_ITEM
	fugl_obj.target_id = "fugleskinn"
	fugl_obj.target_amount = 3
	quest.objectives.append(fugl_obj)

	var elg_obj := QuestObjective.new()
	elg_obj.objective_id = "collect_elgskinn"
	elg_obj.description = "Skyt en elg på Elgveien"
	elg_obj.type = QuestObjective.ObjectiveType.GATHER_ITEM
	elg_obj.target_id = "elgskinn"
	elg_obj.target_amount = 1
	quest.objectives.append(elg_obj)

	var deliver_iver := QuestObjective.new()
	deliver_iver.objective_id = "deliver_skins_to_iver"
	deliver_iver.description = "Lever skinnene til Iver"
	deliver_iver.type = QuestObjective.ObjectiveType.TALK_TO_NPC
	deliver_iver.target_id = "iver"
	deliver_iver.target_amount = 1
	quest.objectives.append(deliver_iver)

	quest.offer_dialogue.append("Du vil ha grus?")
	quest.offer_dialogue.append("Jeg selger ikke til hvem som helst.")
	quest.offer_dialogue.append("Steinar og Stein sa at jeg ikke kunne benke 120 kg.")
	quest.offer_dialogue.append("Det er løgn, men det er ikke poenget.")
	quest.offer_dialogue.append("Poenget er at du må bevise at du er seriøs.")
	quest.offer_dialogue.append("Kjøp deg en hagle.")
	quest.offer_dialogue.append("Gå til Elgveien og skyt fugler og elg.")
	quest.offer_dialogue.append("Kom tilbake med 3 kråkefjær og 1 elgskinn.")
	quest.offer_dialogue.append("Da selger jeg grus.")
	quest.offer_dialogue.append("Ta pistolen min. Du trenger den.")

	quest.completion_dialogue.append("Ikke verst.")
	quest.completion_dialogue.append("Her er gruset.")
	quest.reward_money = 0
	quest.reward_items.append("grus")
	return quest

func _create_quest_steinar() -> Quest:
	var quest := Quest.new()
	quest.quest_id = "STEINAR_GRUS"
	quest.name = "gRUSA"
	quest.description = "Steinar og Stein vil ha grus."
	quest.brief_description = "Lever en pose grus til Steinar."
	quest.required_quest_ids.append("IVER_BEVIS")
	quest.quest_type = Quest.QuestType.DELIVER

	var obj := QuestObjective.new()
	obj.objective_id = "deliver_grus_to_steinar"
	obj.description = "Lever grus til Steinar"
	obj.type = QuestObjective.ObjectiveType.DELIVER
	obj.target_id = "steinar:grus"
	obj.target_amount = 1
	quest.objectives.append(obj)

	quest.offer_dialogue.append("Vi vil ha grus i bytte mot capsen.")
	quest.offer_dialogue.append("Gå til Iver på Kratergata.")
	quest.offer_dialogue.append("Få han til å selge grus til deg.")
	quest.offer_dialogue.append("Kom tilbake med grus, så får du capsen.")
	quest.completion_dialogue.append("Der.")
	return quest

func _save_quest(quest: Quest, path: String):
	var result = ResourceSaver.save(quest, path)
	if result == OK:
		print("  ✓ Created: ", path.get_file())
	else:
		print("  ✗ FAILED: ", path.get_file(), " Error: ", result)

func _ensure_directory_exists(path: String):
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_absolute(path)
		print("Created quests directory")

func _clear_old_quests(quests_dir: String):
	var generated_files = [
		"quest_01_grandpa_request.tres",
		"quest_02_bank_inheritance.tres",
		"quest_03_economic_reality.tres",
		"quest_04_disappointment.tres",
		"quest_05_scholarship_application.tres",
		"quest_06_bank_deposit.tres",
		"quest_07_second_icecream.tres",
		"quest_08_final_delivery.tres",
		"quest_kris_lua.tres",
		"quest_09_iver_bevis.tres",
		"quest_10_steinar_grus.tres"
	]
	for file in generated_files:
		var path = quests_dir + file
		if ResourceLoader.exists(path):
			DirAccess.remove_absolute(path)
			print("Deleted old generated quest: ", file)

func _verify_quests(quests_dir: String):
	var expected = [
		"quest_01_grandpa_request.tres",
		"quest_02_bank_inheritance.tres",
		"quest_03_economic_reality.tres",
		"quest_04_disappointment.tres",
		"quest_05_scholarship_application.tres",
		"quest_06_bank_deposit.tres",
		"quest_07_second_icecream.tres",
		"quest_08_final_delivery.tres",
		"quest_kris_lua.tres",
		"quest_09_iver_bevis.tres",
		"quest_10_steinar_grus.tres"
	]
	
	print("\n=== Verification ===")
	var all_good = true
	for file in expected:
		var path = quests_dir + file
		var loaded = ResourceLoader.load(path)
		if loaded != null:
			print("  ✓ ", file, " - ", loaded.name)
		else:
			print("  ✗ MISSING: ", file)
			all_good = false
	
	if all_good:
		print("\n🎉 All quests verified and ready to use!")
	else:
		print("\n⚠️ Some quests are missing. Check errors above.")
