# generatequests.gd - COMPLETELY FIXED with proper array handling
extends Node

# tag: quest generation — offer_dialogue etc. (sync changes into data/quests/*.tres when editing baked quests).

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

	# Sidequest: Kris og lua
	var q9 = _create_quest_kris_lua()
	_save_quest(q9, quests_dir + "quest_kris_lua.tres")
	
	print("\n✅ Main + side quests created successfully!")
	_verify_quests(quests_dir)

func _create_quest_1() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "GRANDPA_REQUEST"
	quest.name = "Bestefars ønske"
	quest.description = "Bestefar har en vikt beskjed om mormors arv."
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
	
	quest.offer_dialogue.append("Sett deg ned.")
	quest.offer_dialogue.append("Jeg vil ha to is.")
	quest.offer_dialogue.append("Gå i butikken og kjøp to is til meg.")
	quest.offer_dialogue.append("...")
	quest.offer_dialogue.append("Mormor døde.")
	quest.offer_dialogue.append("Her er arven hennes.")
	quest.offer_dialogue.append("*Gir deg arvedokumentet*")
	quest.offer_dialogue.append("Løs det inn i banken.")
	quest.offer_dialogue.append("Bruk pengene på is.")
	
	# Melding når questen er ferdig (vises i UI)
	quest.completion_dialogue.append("Du har fått et arvedokument!")
	quest.completion_dialogue.append("Sjekk questloggen for å se bank-oppdraget.")
	
	return quest

func _create_quest_2() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "BANK_INHERITANCE"
	quest.name = "Den Brå Arven"
	quest.description = "Bestefar ga deg et arvedokument. Løs det inn i banken."
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
	quest.offer_dialogue.append("Hei, du ser ut som du har et arvedokument?")
	quest.offer_dialogue.append("La meg se... Mormors arv? 100 kr, gratulerer.")
	
	# LEGG TIL completion_dialogue
	quest.completion_dialogue.append("Her er pengene dine!")
	quest.completion_dialogue.append("Bruk dem klokt.")
	
	return quest

func _create_quest_3() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "ECONOMIC_REALITY"
	quest.name = "Ærend"
	quest.description = "Du oppdager at is koster 100 kr stykket. Du har bare 100 kr."
	quest.brief_description = "Gå til butikken."
	quest.required_quest_ids.append("BANK_INHERITANCE")
	
	var obj = QuestObjective.new()
	obj.objective_id = "buy_icecream"
	obj.description = "Kjøp iskrem"
	obj.type = QuestObjective.ObjectiveType.PURCHASE_ITEM
	obj.target_id = "icecream"
	obj.target_amount = 1
	quest.objectives.append(obj)
	
	quest.offer_dialogue.append("Du har fått et nytt oppdrag: Gå til butikken.")
	quest.completion_dialogue.append("Bra. Du fant butikken.")
	quest.completion_dialogue.append("Nå gjelder det å kjøpe is.")
	
	quest.unlock_quests.append("GRANDPA_DISAPPOINTMENT")
	
	return quest

func _create_quest_4() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "GRANDPA_DISAPPOINTMENT"
	quest.name = "Tilbake til bestefar"
	quest.description = "Bestefar er ikke fornøyd med én is."
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
	quest.offer_dialogue.append("...")
	quest.offer_dialogue.append("Én is.")
	quest.offer_dialogue.append("Jeg ba om TO is.")
	quest.offer_dialogue.append("§Jeg hadde bare råd til én. De kostet 100 kr stykket. Du ga meg bare 100 kr.")
	quest.offer_dialogue.append("Du er ung.")
	quest.offer_dialogue.append("Kan ikke du bare søke stipend?")
	quest.offer_dialogue.append("Gå til Lånekassa.")
	quest.offer_dialogue.append("De vil hjelpe deg.")
	
	return quest

func _create_quest_5() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "SCHOLARSHIP_APPLICATION"
	quest.name = "Skaff stipend"
	quest.description = "Snakk med Chief Keef og fyll ut stipendskjema."
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
	quest.offer_dialogue.append("Yo.")
	quest.offer_dialogue.append("Stipend?")
	quest.offer_dialogue.append("Ja, det fikser vi.")
	# tag: Chief Keef direction — must match devroom: terminal is to the player's RIGHT when facing Keef.
	quest.offer_dialogue.append("Se den stasjonen til høyre for deg?")
	quest.offer_dialogue.append("Gå dit og fyll ut skjemaet.")
	quest.offer_dialogue.append("Send inn når du er ferdig.")
	quest.offer_dialogue.append("Enkelt.")
	quest.completion_dialogue.append("Skjemaet er godkjent.")
	quest.completion_dialogue.append("Her er stipendet ditt. Bruk det klokt.")
	
	return quest

func _create_quest_6() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "BANK_DEPOSIT"
	quest.name = "Sett inn penger"
	quest.description = "Sett inn stipendet i banken."
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
	quest.offer_dialogue.append("Tilbake igjen?")
	quest.offer_dialogue.append("Å, du har fått stipend? Flott.")
	quest.offer_dialogue.append("Kontoen din er oppdatert. Nå har du nok til to is.")
	
	# LEGG TIL completion_dialogue
	quest.completion_dialogue.append("Stipendet er innsatt!")
	quest.completion_dialogue.append("Nå har du nok penger til to is.")
	
	return quest

func _create_quest_7() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "SECOND_ICECREAM"
	quest.name = "Fullfør ærendet"
	quest.description = "Nå har du nok penger til den andre isen."
	quest.brief_description = "Du vet hva du må gjøre."
	quest.required_quest_ids.append("BANK_DEPOSIT")
	
	var obj = QuestObjective.new()
	obj.objective_id = "buy_second_icecream"
	obj.description = "Kjøp enda en iskrem"
	obj.type = QuestObjective.ObjectiveType.PURCHASE_ITEM
	obj.target_id = "icecream"
	obj.target_amount = 1
	quest.objectives.append(obj)
	
	quest.offer_dialogue.append("Du har fått et nytt oppdrag: Kjøp én is til.")
	quest.completion_dialogue.append("Der ja. Nå har du begge isene.")
	
	quest.unlock_quests.append("FINAL_DELIVERY")
	
	return quest

func _create_quest_8() -> Quest:
	var quest = Quest.new()
	quest.quest_id = "FINAL_DELIVERY"
	quest.name = "Fullfør ærendet"
	quest.description = "Lever to is til bestefar."
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
	
	quest.reward_xp = 500
	quest.reward_title = "Isens Utvalgte"
	quest.offer_dialogue.append("...")
	quest.offer_dialogue.append("Har du isen?")
	quest.completion_dialogue.append("...")
	quest.completion_dialogue.append("To is.")
	quest.completion_dialogue.append("Endelig.")
	quest.completion_dialogue.append("*Han smiler.*")
	quest.completion_dialogue.append("Bra gjort.")
	quest.completion_dialogue.append("Jeg er stolt av deg.")
	
	return quest


func _create_quest_kris_lua() -> Quest:
	var quest := Quest.new()
	quest.quest_id = "KRIS_LUA"
	quest.name = "Peak Performance"
	quest.description = "Kris har mistet lua si."
	quest.brief_description = "Finn Kris sin lua."
	quest.quest_type = Quest.QuestType.GATHER

	var obj := QuestObjective.new()
	obj.objective_id = "find_hat"
	obj.description = "Finn Peak Performance-lua"
	obj.type = QuestObjective.ObjectiveType.GATHER_ITEM
	obj.target_id = "peak_performance_lua"
	obj.target_amount = 1
	quest.objectives.append(obj)

	quest.reward_money = 150
	quest.offer_dialogue = [
		"Har du sett lua mi?",
		"Peak Performance-lua.",
		"Den betyr alt for meg.",
		"...",
		"Russegjengen tok den.",
		"De bor der nede.",
		"*Han peker nedover veien*",
		"Jeg tør ikke gå dit selv.",
		"Men du kanskje..."
	]
	quest.completion_dialogue = [
		"...",
		"*Han ser på lua*",
		"Liker du rimming?",
		"*Han setter på lua*",
		"Takk.",
		"*Han snur seg og går*"
	]
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
		"quest_kris_lua.tres"
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
		"quest_kris_lua.tres"
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
