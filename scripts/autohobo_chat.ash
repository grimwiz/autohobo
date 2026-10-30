script "autohobo_chat.ash";

// autohobo's chatbot script: KoLmafia runs it for every chat message while chat is open. It listens to /hobopolis
// for the dungeon's cage messages and remembers who is trapped, so autohobo can go down the ladder in the sewers
// and free them (1 turn for you, instead of 10 for them to gnaw out). autohobo sets it as your chatbot script for
// its run; to keep listening between runs: set chatbotScript = autohobo_chat.ash
//
// The messages, as the game posts them (sender "Dungeon", or a clan bot for the last one):
//   Demit has been imprisoned by the C. H. U. M.s!
//   Demit escaped from the C. H. U. M.s by gnawing through their cage.
//   Penne Basil has rescued Demit from the C. H. U. M.s.
//   Demit has left the C.H.U.M. cage.

void ah_chatFreed(string who)
{
	if(who.to_lower_case() == my_name().to_lower_case())
	{
		set_property("_autohobo_myCageAt", "");	//you're out
		set_property("_autohobo_rescued", "");
	}
	if(get_property("_autohobo_caged").to_lower_case() == who.to_lower_case())
	{
		set_property("_autohobo_caged", "");
		set_property("_autohobo_cagedAt", "");
	}
}

void main(string sender, string message, string channel)
{
	if(channel != "/hobopolis")
	{
		return;
	}
	string text = create_matcher("<[^>]*>", message).replace_all("");
	matcher m = create_matcher("^(.+?) has been imprisoned by the C\\. H\\. U\\. M\\.s", text);
	if(m.find())
	{
		if(m.group(1).to_lower_case() == my_name().to_lower_case())
		{
			if(get_property("_autohobo_myCageAt") == "")
			{
				set_property("_autohobo_myCageAt", now_to_int().to_string());
			}
			return;
		}
		set_property("_autohobo_caged", m.group(1));
		set_property("_autohobo_cagedAt", now_to_int().to_string());
		print("[autohobo] " + m.group(1) + " is caged in the sewers.", "blue");
		return;
	}
	m = create_matcher("^(.+?) escaped from the C\\. H\\. U\\. M\\.s", text);
	if(m.find())
	{
		ah_chatFreed(m.group(1));
		return;
	}
	m = create_matcher("^(.+?) has rescued (.+?) from the C\\. H\\. U\\. M\\.s", text);
	if(m.find())
	{
		if(m.group(2).to_lower_case() == my_name().to_lower_case())
		{
			set_property("_autohobo_rescued", "true");	//autohobo leaves the cage on its next sewer turn
			print("[autohobo] " + m.group(1) + " came down the ladder for you. Run autohobo to leave the cage.", "blue");
			return;
		}
		ah_chatFreed(m.group(2));
		print("[autohobo] " + m.group(1) + " freed " + m.group(2) + " from the cage.", "blue");
		return;
	}
	m = create_matcher("^(.+?) has left the C\\.H\\.U\\.M\\. cage", text);
	if(m.find())
	{
		ah_chatFreed(m.group(1));
	}
}
