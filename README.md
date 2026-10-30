# autohobo

A KoLmafia script that adventures in your clan's Hobopolis for the skill books that teach the Hobopolis skills you
haven't permed: the five 120-MP elemental spells (Awesome Balls of Fire, Snowclone, Eggsplosion, Raise Backup Dancer,
Grease Lightning) and the five 30-MP buffs that drop next to them.

## Usage

```
autohobo            farm until you have a book for every unpermed skill, the zones run out of hobos, or adventures run out
autohobo 100        the same, spending at most 100 turns
autohobo status     show the instance and which skills are missing, without adventuring
autohobo pages      print the Hobopolis and clan basement pages as text (for when it can't get in)
```

Run `autohobo status` first. It spends no turns. For each skill you haven't permed, it says whether you know it this life
only (perm it or lose it), have its book unread (and where: inventory, closet, Hagnk's, your store or display case),
or have no copy (with the mall price). Then it shows whether you can get into Hobopolis and how far each zone has got.

## What it does

Before each adventure it re-reads the Hobopolis pages (KoLmafia keeps no Hobopolis state) and:

- **Never reads a book.** A skill learned now is lost when you ascend unless you perm it in Valhalla (100 Karma), and
  Karma only covers one or two perms an ascension. So autohobo collects books and leaves the reading to you. A skill counts
  as needed only if it isn't permed, isn't known this life, and you have no copy of its book (inventory, closet,
  Hagnk's, store or display case).
- **Picks the zone**: the first side zone, in opening order, whose books you still need and that still has hobos.

| Zone | Opens at (Town Square kills) | Books |
|---|---|---|
| Burnbarrel Blvd. | 250 | Kissin' Cousins (Awesome Balls of Fire), Tales from the Fireside (Conjure Relaxing Campfire) |
| Exposure Esplanade | 500 | Blizzards I Have Died In (Snowclone), Maxing, Relaxing (Maximum Chill) |
| The Heap | 750 | Biddy Cracker's Old-Fashioned Cookbook (Eggsplosion), Travels with Jerry (Mudbath) |
| The Ancient Hobo Burial Ground | 1000 | Let Me Be! (Raise Backup Dancer), Asleep in the Cemetery (Creepy Lullaby) |
| The Purple Light District | 1250 | Summer Nights (Grease Lightning), Sensual Massage for Creeps (Inappropriate Backrub) |

- **Sewers** if you haven't been through them. It keeps sewer wads in stock (the clan custom: the other test items are
  rarely worth their price; `autohobo_sewerItems` adds them), equips a gatorskin umbrella if you have one, and wears
  your hobo code binder.
- **If you get caged**, it follows the clan rule: it asks for a rescue in `/hobopolis` and `/clan`, then stops. Run it
  again later. It leaves the cage when someone comes down the ladder for you (heard on `/hobopolis`), or gnaws out
  (10 turns) once `autohobo_gnawAfter` minutes (60) pass without a rescue.
- **Rescues caged clanmates.** While you're still in the sewers and a clanmate is caged, it takes the ladder in The
  Former or the Ladder. That frees them for 1 of your turns instead of 10 of theirs. It learns who is caged from
  the game's messages on `/hobopolis` (see below), and it leaves cagebait bots (`autohobo_cagebait`) where they are:
  a bot in the cage keeps everyone else from being caged.
- **Town Square** until the zone it wants is open. Whenever Richard has a full set of six hobo parts it makes
  scarehobos, which kill hobos without a turn.
- **The side zone.** Book drops only come from fights, and a zone has only about 500 hobos, so it takes the
  noncombats that *add* hobos (Hot Dog door, Returning to the Tomb, and so on). It skips the ones that kill hobos without
  drops (tirevalanche, the zombie dance, barfights), and it **never fights a boss**. When a zone's boss turns up, that
  zone has no hobos left, so it announces the boss in `/hobopolis` (a clan rule, so people can queue for it) and
  moves to the next zone.
- **Burial Ground**: spooky hobos take 1 damage from any element, so it fights them with physical damage. It uses
  pasta spells (Weapon of the Pastalord, Cannelloni Cannon, Ravioli Shurikens) with any Flavour of Magic spirit removed,
  and falls back to a weapon attack if a skill doesn't hurt. Elsewhere your own combat settings fight.

Every choice setting it changes is put back when it finishes.

## Clan rules (Not Dead Yet)

autohobo follows the parts of the clan's Hobopolis rules that a script can: it asks for a rescue before gnawing,
rescues others, uses only sewer wads, announces bosses, never fights a boss, and never takes I Refuse! (which you
announce and share by hand). The rest is up to you: be in chat listening to `/hobopolis` and `/clan`, keep your loot
preferences in the clan's spreadsheet, and pay the stash for any loot you're given.

## Before you start

- Your clan needs an open Hobopolis instance, and you need dungeon permission. Opening the sewer grate costs
  1,000,000 meat and needs a basement admin; autohobo never does that for you.
- Hobos hit hard (Attack 300 in the Town Square, 350 in the side zones) and have special attacks that ignore Moxie.
  autohobo refuses a zone where 3 rounds of hits would cost 90% of your HP.
- Book drop rates aren't known. All the books are tradeable, and the mall is often cheaper than the turns: Kissin'
  Cousins sold for about 137,000 meat and Let Me Be! about 65,000 in October 2026.

## Listening to /hobopolis

`autohobo_chat.ash` is a chatbot script. KoLmafia runs it for each chat message, and it records who the game says
was imprisoned by, rescued from, or escaped from the C. H. U. M.s. While autohobo runs, it sets this as your
`chatbotScript`, unless you already have a chatbot script of your own, and puts the setting back afterwards. For
messages to arrive, KoLmafia's chat has to be open (the chat window, or chat in the relay browser) and listening to
`/hobopolis`. To keep it listening between runs: `set chatbotScript = autohobo_chat.ash`.

## Settings

`set autohobo_<name> = <value>`

| Setting | Default | |
|---|---|---|
| `maximize` | `item drop, mainstat, moxie, 0.5 hp, 3 dr` | maximizer terms for the side zones and Town Square (spell damage, or weapon damage in the Burial Ground, is added) |
| `buffs` | `true` | also farm for the 30-MP buff books, not only the spells |
| `dangerRounds` | `3` | rounds of expected damage that must fit in 90% of your HP |
| `mpFloor` | `150` | restore MP when it falls below this |
| `maxPrice` | `5000` | most it pays for a sewer test item |
| `sewerItems` | `sewer wad` | comma-separated sewer test items to keep in stock |
| `gnawAfter` | `60` | minutes to wait for a rescue before gnawing out of the cage |
| `advReserve` | `0` | adventures to leave unspent |
| `cagebait` | `ASSBot` | comma-separated players never to free from the cage |
| `cageMinutes` | `60` | ignore a cage report older than this (they've probably gnawed out) |
| `debug` | `false` | print extra detail |
