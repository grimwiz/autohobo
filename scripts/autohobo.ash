script "autohobo.ash";
since r29000;

// autohobo: adventures in your clan's Hobopolis for the skill books that teach the Hobopolis skills you haven't permed.
// It collects the books and never reads them: a skill read now is lost at ascension unless you perm it.
// Each side zone's hobos drop two books (a 120-MP elemental spell and a 30-MP buff). A zone holds about 500 hobos and
// only fights give drops, so autohobo fights them, takes the noncombats that add more hobos, skips the ones that kill
// hobos without drops, and never starts a boss fight.
//
// Usage (KoLmafia command line):
//   autohobo          farm until you have a book for every unpermed skill, the zones run out of hobos, or adventures run out
//   autohobo N        the same, spending at most N turns
//   autohobo status   show the instance and which skills are missing, without adventuring

// ---------------------------------------------------------------- logging and settings
// Settings are ordinary KoLmafia properties, changed with "set autohobo_<name> = <value>".

void ah_info(string msg)
{
	print("[autohobo] " + msg, "blue");
}

void ah_warn(string msg)
{
	print("[autohobo] " + msg, "red");
}

void ah_debug(string msg)
{
	if(get_property("autohobo_debug").to_boolean())
	{
		print("[autohobo debug] " + msg, "gray");
	}
}

string ah_setting(string name, string fallback)
{
	string value = get_property("autohobo_" + name);
	return value == "" ? fallback : value;
}

// Like autosea, take over a few global settings for the run and put them back afterwards.
string[string] ah_savedPrefs;

void ah_overrideProperty(string prop, string value)
{
	if(!(ah_savedPrefs contains prop))
	{
		ah_savedPrefs[prop] = get_property(prop);
	}
	set_property(prop, value);
}

void ah_restoreProperties()
{
	foreach prop, value in ah_savedPrefs
	{
		set_property(prop, value);
	}
	clear(ah_savedPrefs);
}

// ---------------------------------------------------------------- the zones
// place: clan_hobopolis.php?place=N. Each side zone opens after 250 more Town Square kills (Burnbarrel at 250,
// Purple Light at 1250). Spooky hobos take 1 damage from any element, so the Burial Ground needs physical damage.

record ah_zone
{
	location loc;
	int place;
	monster hobo;
	boolean physicalOnly;
	skill spell;
	item spellBook;
	skill buff;
	item buffBook;
};

ah_zone[int] ah_zones()
{
	ah_zone[int] zones;
	zones[0] = new ah_zone($location[Burnbarrel Blvd.], 4, $monster[Hot hobo], false,
		$skill[Awesome Balls of Fire], $item[Kissin' Cousins], $skill[Conjure Relaxing Campfire], $item[Tales from the Fireside]);
	zones[1] = new ah_zone($location[Exposure Esplanade], 5, $monster[Cold hobo], false,
		$skill[Snowclone], $item[Blizzards I Have Died In], $skill[Maximum Chill], $item[Maxing, Relaxing]);
	zones[2] = new ah_zone($location[The Heap], 6, $monster[Stench hobo], false,
		$skill[Eggsplosion], $item[Biddy Cracker's Old-Fashioned Cookbook], $skill[Mudbath], $item[Travels with Jerry]);
	zones[3] = new ah_zone($location[The Ancient Hobo Burial Ground], 7, $monster[Spooky hobo], true,
		$skill[Raise Backup Dancer], $item[Let Me Be!], $skill[Creepy Lullaby], $item[Asleep in the Cemetery]);
	zones[4] = new ah_zone($location[The Purple Light District], 8, $monster[Sleaze hobo], false,
		$skill[Grease Lightning], $item[Summer Nights], $skill[Inappropriate Backrub], $item[Sensual Massage for Creeps]);
	return zones;
}

// ---------------------------------------------------------------- reading the instance
// KoLmafia keeps no Hobopolis state, so read the pages. Every zone page shows a picture numbered by progress:
// the Town Square goes 0-25 (125 kills a step; "125" is the 12.5 tent step), a side zone 0-10 (10: boss is up,
// no hobos left; 11: boss killed).

int ah_pictureNumber(string page)
{
	matcher m = create_matcher("otherimages/hobopolis/[a-z]+(\\d+)", page);
	if(!m.find())
	{
		return -1;
	}
	int n = m.group(1).to_int();
	return n == 125 ? 12 : n;
}

string ah_townPage;

string ah_town()
{
	if(ah_townPage == "")
	{
		ah_townPage = visit_url("clan_hobopolis.php?place=2");
	}
	return ah_townPage;
}

void ah_forgetPages()
{
	ah_townPage = "";
}

// "sewers": still exploring the sewers; "town": through them; "" (and a warning): no way in
boolean ah_throughSewers = false;

string ah_stage()
{
	if(ah_throughSewers)
	{
		return "town";
	}
	string page = visit_url("clan_hobopolis.php");
	if(page.contains_text("adventure.php?snarfblat=166"))
	{
		return "sewers";
	}
	if(ah_pictureNumber(ah_town()) >= 0)
	{
		ah_throughSewers = true;
		return "town";
	}
	if(page.contains_text("have access") || page.contains_text("not in a clan"))
	{
		ah_warn("You don't have access to your clan's Hobopolis (dungeon permission, or no clan).");
	}
	else
	{
		ah_warn("Can't find a Hobopolis instance: your clan's sewer grate may be closed (reopening it costs 1,000,000 meat and a basement admin), or Hodgman is dead and the instance needs flooding.");
	}
	return "";
}

boolean ah_zoneOpen(ah_zone z)
{
	return ah_town().contains_text("clan_hobopolis.php?place=" + z.place);
}

int ah_zonePicture(ah_zone z)
{
	return ah_pictureNumber(visit_url("clan_hobopolis.php?place=" + z.place));
}

// the boss is up (or dead): every hobo in the zone is gone, so no more books from it
boolean ah_zoneExhausted(ah_zone z)
{
	return ah_zoneOpen(z) && ah_zonePicture(z) >= 10;
}

// ---------------------------------------------------------------- books
// autohobo never reads a book. A skill learned now lasts only until you ascend unless you perm it in Valhalla
// (100 Karma each), and Karma covers only one or two perms an ascension, so books are kept until you choose to read
// one. A skill still needs a book when it isn't permed, isn't known this life, and you have no copy of its book.

// the zone's two skills and the books that teach them
item[skill] ah_zoneBooks(ah_zone z)
{
	item[skill] books;
	books[z.spell] = z.spellBook;
	books[z.buff] = z.buffBook;
	return books;
}

// where you keep a copy of the book, or "" if you have none
string ah_bookWhere(item book)
{
	if(item_amount(book) > 0)
	{
		return "inventory";
	}
	if(closet_amount(book) > 0)
	{
		return "closet";
	}
	if(storage_amount(book) > 0)
	{
		return "Hagnk's";
	}
	if(shop_amount(book) > 0)
	{
		return "your store";
	}
	if(display_amount(book) > 0)
	{
		return "display case";
	}
	return "";
}

boolean ah_skillNeeded(skill sk, item book)
{
	return !(get_permed_skills() contains sk) && !have_skill(sk) && ah_bookWhere(book) == "";
}

boolean ah_zoneWanted(ah_zone z)
{
	return ah_skillNeeded(z.spell, z.spellBook) || (ah_skillNeeded(z.buff, z.buffBook) && ah_setting("buffs", "true").to_boolean());
}

// ---------------------------------------------------------------- choices
// Bosses are skipped (KoLmafia then stops automation, which ends the zone). Noncombats that add hobos are taken,
// since more hobos means more drops; ones that kill hobos without drops (tirevalanche, dances, barfights) are not.

void ah_setChoices()
{
	int[int] picks = {
		197: 1, 198: 1, 199: 1,	//sewers: take the tunnel (each test item passed counts as an extra exploration)
		211: 1, 212: 1,	//caged in the sewers: gnaw out (10 turns) rather than wait for a rescuer
		200: 2, 225: 3, 230: 2, 272: 2,	//Town Square: no Hodgman, no tent, no binder or marketplace
		201: 2, 206: 3, 207: 1, 213: 2, 291: 2,	//Burnbarrel: more hot hobos; no tires, no Ol' Scratch
		202: 2, 215: 3, 217: 1, 273: 2, 292: 2,	//Esplanade: more cold hobos; no Frosty
		203: 2, 214: 2, 216: 2, 218: 2, 295: 2,	//Heap: no Oscus, nothing that removes hobos
		204: 2, 208: 2, 220: 1, 221: 3, 222: 2, 293: 2,	//Burial Ground: more spooky hobos; no dancing, no Zombo
		205: 2, 219: 1, 223: 1, 224: 1, 294: 2	//Purple Light: fight the sleaze hobos; no Chester
	};
	foreach n, opt in picks
	{
		ah_overrideProperty("choiceAdventure" + n, opt.to_string());
	}
}

// ---------------------------------------------------------------- staying alive
// Hobos hit hard (Attack 350 in the side zones) and every hobo has special attacks; refuse a zone where a few
// hits would beat you up, rather than lose fights.

boolean ah_safe(location loc, monster hobo)
{
	int rounds = ah_setting("dangerRounds", "3").to_int();
	int hit = expected_damage(hobo);
	if(hit * rounds >= my_maxhp() * 0.9)
	{
		ah_warn("Skipping " + loc + ": " + hobo + " can hit you for about " + hit + " a round, and you have " + my_maxhp()
			+ " HP. More Moxie, HP or damage reduction will open it up (set autohobo_dangerRounds lower to go anyway).");
		return false;
	}
	return true;
}

boolean ah_recover()
{
	if(my_hp() < my_maxhp() * 0.8)
	{
		restore_hp(my_maxhp());
	}
	if(my_mp() < ah_setting("mpFloor", "150").to_int())
	{
		restore_mp(min(my_maxmp(), ah_setting("mpFloor", "150").to_int() * 2));
	}
	return my_hp() >= my_maxhp() * 0.5 && have_effect($effect[Beaten Up]) == 0;
}

// ---------------------------------------------------------------- physical damage (Burial Ground)
// Pasta spells deal physical damage unless a Flavour of Magic spirit is up. Whatever is tried, a skill that
// doesn't dent the hobo is dropped for the rest of the run and the weapon takes over.

boolean[skill] ah_noDamage;
skill ah_lastSkill;
int ah_hpBefore;
int ah_lastRound;

void ah_dropSpirits()
{
	foreach eff in $effects[Spirit of Cayenne, Spirit of Peppermint, Spirit of Garlic, Spirit of Wormwood, Spirit of Bacon Grease]
	{
		if(have_effect(eff) > 0)
		{
			cli_execute("shrug " + eff);
		}
	}
}

string ah_physicalFilter(int round, monster enemy, string text)
{
	if(round <= ah_lastRound)
	{
		ah_lastSkill = $skill[none];	//a new fight
	}
	ah_lastRound = round;
	if(ah_lastSkill != $skill[none] && monster_hp() >= ah_hpBefore - 10)
	{
		ah_debug(ah_lastSkill + " didn't hurt the " + enemy + "; using something else");
		ah_noDamage[ah_lastSkill] = true;
	}
	ah_hpBefore = monster_hp();
	foreach sk in $skills[Weapon of the Pastalord, Cannelloni Cannon, Ravioli Shurikens]
	{
		if(have_skill(sk) && !(ah_noDamage contains sk) && my_mp() >= mp_cost(sk))
		{
			ah_lastSkill = sk;
			return "skill " + sk;
		}
	}
	ah_lastSkill = $skill[none];
	return "attack";
}

// ---------------------------------------------------------------- one adventure

string ah_maximizeFor(location loc, boolean physical)
{
	string terms = ah_setting("maximize", "item drop, mainstat, moxie, 0.5 hp, 3 dr");
	if(loc == $location[A Maze of Sewer Tunnels])
	{
		//the umbrella passes a sewer test from the main hand; the binder adds explorations from its glyphs
		terms = "mainstat, moxie, 0.5 hp, 3 dr";
		if(available_amount($item[gatorskin umbrella]) > 0)
		{
			terms += ", +equip gatorskin umbrella";
		}
		if(available_amount($item[hobo code binder]) > 0)
		{
			terms += ", +equip hobo code binder";
		}
	}
	else if(physical)
	{
		terms += ", weapon damage";
	}
	else
	{
		terms += ", spell damage percent";
	}
	return terms;
}

boolean ah_adv(location loc, monster hobo, boolean physical)
{
	set_location(loc);
	maximize(ah_maximizeFor(loc, physical), false);
	if(!ah_safe(loc, hobo))
	{
		return false;
	}
	if(!ah_recover())
	{
		ah_warn("Couldn't recover enough HP to adventure safely (" + my_hp() + "/" + my_maxhp() + ").");
		return false;
	}
	if(physical)
	{
		ah_dropSpirits();
	}
	ah_lastRound = 999;
	int turnsBefore = my_turncount();
	boolean ok = adv1(loc, -1, physical ? "ah_physicalFilter" : "");
	ah_forgetPages();
	if(have_effect($effect[Beaten Up]) > 0)
	{
		ah_warn("Beaten up in " + loc + ". Stopping.");
		return false;
	}
	if(!ok && my_turncount() == turnsBefore)
	{
		ah_warn("The adventure at " + loc + " didn't happen (HP " + my_hp() + "/" + my_maxhp() + ", adventures " + my_adventures()
			+ "). KoLmafia's reason is in the CLI just above; \"autohobo pages\" shows what the Hobopolis pages say.");
		return false;
	}
	return true;
}

// ---------------------------------------------------------------- sewers
// Each player explores 100 times (a kill counts 1, a tunnel with a test item counts more), then one more turn
// reaches the Town Square. The test items are used up when they pass, so keep one of each in stock.

void ah_stockSewerItems()
{
	int maxPrice = ah_setting("maxPrice", "5000").to_int();
	int[item] want = {
		$item[gatorskin umbrella]: 1,
		$item[unfortunate dumplings]: 1,
		$item[sewer wad]: 1,
		$item[bottle of Ooze-O]: 1,
		$item[oil of oiliness]: 3,
	};
	foreach it, n in want
	{
		if(available_amount(it) >= n)
		{
			continue;
		}
		if(closet_amount(it) > 0)
		{
			take_closet(min(n - item_amount(it), closet_amount(it)), it);
		}
		if(item_amount(it) < n && can_interact() && mall_price(it) > 0 && mall_price(it) <= maxPrice)
		{
			buy(n - item_amount(it), it, maxPrice);
		}
	}
}

// ---------------------------------------------------------------- the cage
// Now and then the C. H. U. M.s cage someone in the sewers. They can gnaw out (10 turns), or a clanmate still in
// the sewers frees them by going down the ladder in The Former or the Ladder (1 turn). autohobo_chat.ash hears the
// game's /hobopolis messages and records who is caged; then the ladder is taken instead of the tunnel. Clans often
// keep a bot in the cage on purpose ("cagebait": only one player fits, so nobody else gets caged), so names in
// autohobo_cagebait are left there.

string ah_cagedClanmate()
{
	string who = get_property("_autohobo_caged");
	if(who == "" || who.to_lower_case() == my_name().to_lower_case())
	{
		return "";
	}
	foreach i, bait in ah_setting("cagebait", "ASSBot").split_string(",")
	{
		if(create_matcher("^\\s+|\\s+$", bait).replace_all("").to_lower_case() == who.to_lower_case())
		{
			return "";
		}
	}
	//a cage nobody has mentioned for an hour has probably been gnawed out of (the chat may have been closed)
	int minutes = (now_to_int() - get_property("_autohobo_cagedAt").to_int()) / 60000;
	return minutes > ah_setting("cageMinutes", "60").to_int() ? "" : who;
}

boolean ah_sewerTurn()
{
	if(my_adventures() < 10)
	{
		ah_warn("The sewers need at least 10 adventures left to enter.");
		return false;
	}
	ah_stockSewerItems();
	string caged = ah_cagedClanmate();
	if(caged != "")
	{
		ah_info(caged + " is caged: taking the ladder to free them if The Former or the Ladder comes up.");
	}
	ah_overrideProperty("choiceAdventure199", caged != "" ? "3" : "1");
	set_property("lastEncounter", "");
	int turnsBefore = my_turncount();
	boolean ok = ah_adv($location[A Maze of Sewer Tunnels], $monster[C. H. U. M.], false);
	if(!ok && my_turncount() == turnsBefore && have_effect($effect[Beaten Up]) == 0)
	{
		//the Hobopolis page links the sewers even when the grate is shut, and the game then says "You shouldn't be here"
		ah_warn("The game won't let you into the sewers. Your clan's Hobopolis is probably closed: after Hodgman dies "
			+ "the instance has to be flooded, then a basement admin opens the sewer grate again (1,000,000 meat).");
	}
	if(caged != "" && get_property("lastEncounter") == "The Former or the Ladder")
	{
		ah_info("Went down the ladder for " + caged + ".");
		set_property("_autohobo_caged", "");	//don't go again even if the chat message is missed
	}
	return ok;
}

// ---------------------------------------------------------------- Town Square
// Kills here open the side zones. Overkilled hobos (about 500 damage of one element or physical) leave a part with
// Richard instead of drops; a set of all six parts makes a scarehobo, which kills 6-10 hobos for no turn.

int ah_richardParts(string page, string name)
{
	matcher m = create_matcher("Richard has <b>(\\d+)</b> " + name, page);
	return m.find() ? m.group(1).to_int() : 0;
}

void ah_makeScarehobos()
{
	string page = visit_url("clan_hobopolis.php?place=3&action=talkrichard&whichtalk=3");
	int sets = 999;
	foreach name in $strings[pairs? of charred hobo boots?, pairs? of frozen hobo eyes, piles? of stinking hobo guts,
		creepy hobo skulls?, hobo crotch(es)?, hobo skins?]
	{
		sets = min(sets, ah_richardParts(page, name));
	}
	if(sets > 0 && sets < 999)
	{
		ah_info("Richard has " + sets + " full set" + (sets == 1 ? "" : "s") + " of hobo parts: making scarehobos.");
		visit_url("clan_hobopolis.php?place=3&action=talkrichard&whichtalk=3&preaction=simulacrum&qty=" + sets);
		ah_forgetPages();
	}
}

boolean ah_townTurn()
{
	ah_makeScarehobos();
	return ah_adv($location[Hobopolis Town Square], $monster[Normal hobo], false);
}

// ---------------------------------------------------------------- status

// why a skill isn't permed yet: known this life only, a book you own but haven't read, or no book at all
string ah_missingWhy(skill sk, item book)
{
	string where = ah_bookWhere(book);
	if(have_skill(sk))
	{
		return sk + ": known this life only. Perm it in Valhalla (100 Karma) or it's lost when you ascend"
			+ (where == "" ? "." : "; you also have " + book + " (" + where + ").");
	}
	if(where != "")
	{
		return sk + ": you have " + book + " (" + where + "), unread. Read it when you can perm the skill at the next Valhalla.";
	}
	int price = mall_price(book);
	return sk + ": no " + book + (price > 0 ? " (mall about " + price + ")." : " (none in the mall).");
}

void ah_status()
{
	//the skills first: they don't depend on getting into Hobopolis
	int missing = 0;
	foreach i, z in ah_zones()
	{
		foreach sk, book in ah_zoneBooks(z)
		{
			if(!(get_permed_skills() contains sk))
			{
				ah_info(ah_missingWhy(sk, book));
				missing += 1;
			}
		}
	}
	if(missing == 0)
	{
		ah_info("Every Hobopolis skill is permed.");
	}
	string stage = ah_stage();
	if(stage == "")
	{
		return;
	}
	if(get_property("_autohobo_caged") != "")
	{
		ah_info(get_property("_autohobo_caged") + " was caged in the sewers, as last heard on /hobopolis.");
	}
	if(stage == "sewers")
	{
		ah_info("You're still in the sewers (100 explorations, then one more turn).");
	}
	else
	{
		ah_info("Town Square picture " + ah_pictureNumber(ah_town()) + " of 25 (about " + (ah_pictureNumber(ah_town()) * 125) + " kills).");
	}
	foreach i, z in ah_zones()
	{
		string state = !ah_zoneOpen(z) ? "not open yet" : ah_zonePicture(z) >= 10 ? "no hobos left" : "picture " + ah_zonePicture(z) + " of 10";
		string books = "";
		foreach sk, book in ah_zoneBooks(z)
		{
			if(ah_skillNeeded(sk, book))
			{
				books += (books == "" ? "" : " and ") + book;
			}
		}
		ah_info(z.loc + ": " + state + ". " + (books == "" ? "No books needed here." : "Drops " + books + ", which you need."));
	}
}

// ---------------------------------------------------------------- the run

// the zone to farm: the first one (in opening order) whose books you still need and that still has hobos
int ah_targetZone(ah_zone[int] zones)
{
	foreach i, z in zones
	{
		if(ah_zoneWanted(z) && !ah_zoneExhausted(z))
		{
			return i;
		}
	}
	return -1;
}

void ah_run(int maxTurns)
{
	int start = my_turncount();
	int reserve = ah_setting("advReserve", "0").to_int();
	ah_zone[int] zones = ah_zones();
	while(maxTurns < 0 || my_turncount() - start < maxTurns)
	{
		if(my_adventures() <= reserve)
		{
			ah_info("Out of adventures (reserve " + reserve + ").");
			break;
		}
		int target = ah_targetZone(zones);
		if(target < 0)
		{
			ah_info("Nothing left to farm: every Hobopolis skill is permed, known this life, or has a book waiting; or the zones with the missing books have no hobos left.");
			break;
		}
		ah_zone z = zones[target];
		string stage = ah_stage();
		boolean acted;
		if(stage == "")
		{
			break;
		}
		else if(stage == "sewers")
		{
			acted = ah_sewerTurn();
		}
		else if(!ah_zoneOpen(z))
		{
			acted = ah_townTurn();
		}
		else
		{
			int[item] before;
			foreach sk, book in ah_zoneBooks(z)
			{
				before[book] = item_amount(book);
			}
			acted = ah_adv(z.loc, z.hobo, z.physicalOnly);
			foreach sk, book in ah_zoneBooks(z)
			{
				if(item_amount(book) > before[book])
				{
					ah_info("Got " + book + ". Keep it until you can perm " + sk + " (read it, then perm it at the next Valhalla).");
				}
			}
			if(!acted && ah_zoneExhausted(z))
			{
				ah_info(z.loc + " has no hobos left (the boss is waiting).");
				acted = true;	//the next pass picks another zone
			}
		}
		if(!acted)
		{
			break;
		}
	}
	ah_info("Spent " + (my_turncount() - start) + " turns.");
}

// the Hobopolis pages as text, to see what the game says when autohobo can't get in
void ah_pages()
{
	foreach url in $strings[clan_hobopolis.php, clan_hobopolis.php?place=2, clan_basement.php?fromabove=1]
	{
		string text = create_matcher("<[^>]*>", visit_url(url)).replace_all(" ");
		text = create_matcher("\\s+", text).replace_all(" ");
		ah_info(url + ": " + (text.length() > 1500 ? text.substring(0, 1500) + "..." : text));
	}
}

void main(string... args)
{
	//KoLmafia may pass "status" or "50" as one argument or several; join and split it ourselves
	string joined = "";
	foreach i, a in args
	{
		joined += " " + a;
	}
	string[int] words = (joined == "" ? "" : joined.substring(1)).to_lower_case().split_string(" ");
	if(words[0] == "status")
	{
		ah_status();
		return;
	}
	if(words[0] == "pages")
	{
		ah_pages();
		return;
	}
	if(words[0] != "" && words[0].to_int() <= 0)
	{
		ah_warn("Usage: autohobo [turns] | autohobo status | autohobo pages");
		return;
	}
	int turns = words[0] == "" ? -1 : words[0].to_int();
	try
	{
		ah_setChoices();
		ah_overrideProperty("choiceAdventureScript", "");
		//listen to /hobopolis for caged clanmates, unless you already run a chatbot script of your own
		string bot = get_property("chatbotScript");
		if(bot == "")
		{
			ah_overrideProperty("chatbotScript", "autohobo_chat.ash");
		}
		else if(!bot.contains_text("autohobo_chat"))
		{
			ah_warn("Your chatbot script (" + bot + ") is set, so autohobo won't hear who gets caged in the sewers.");
		}
		ah_run(turns);
	}
	finally
	{
		ah_restoreProperties();
	}
}
