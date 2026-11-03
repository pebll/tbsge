# Design journal

Your original notes, kept as written (only headings normalised). The decisions and ideas are moved into `design/*.md`. **Append new entries at the bottom with a date header.**

> The 11/08/26 entry referenced a science panel screenshot (`Screenshot_2026-08-11_10-37-11.png`, Joplin resource `:/b5dc8396aff449e1947b687ab8b32b0c`). It is not in the repo. If you want it here, drop it in `doc/img/` and fix the link.

---

## 06/08/26

### What makes the game fun?

- Outplay the AI, win battle with less "value" on the board
- See big armies lined up before fighting each other

### What does the "final" game want to look like

I think for now, I would like for Fable Quest, at least the V1, to be the tactical side of Realmrise. Because Realmrise is a lot, it's combat, but it's also diplomacy & economy, which is not really covered by the current project. So the goal is to create a tactical realmrise, which can on day be used as a base to create the real Realmrise. *Realmrise Tactics*.

So, what is my current imagination about the final game? I think here I want to take a lot of inspiration from Civ Early Game, which is arguably one of the best parts of the game, because you get to explore and make progress fast. Ruins and random rewards ;D. Also HoMM5 has something I want: all the random buildings one can find and control: mills and farms for economy, but also more complex stuff like observatories that give science or even dragon pits where you can hire dragons. Mercenaries sounds like a good thing in my game. Also, I think that like in HoMM, there are neutral units just walking around minding their own businnes, that could be cool, also like civ barbarians.

### Buildings & Economy

Currently, we select an army from gold in a skirmish mode and we fight until the end, until no unit is left. Which can be a bit boring, since you cannot really react to your opponents army. Which also nice mode, but probably only for competitive matches that focus only on tactics. A big playerbase coming from 4X (me included) might want something a bit more grounded. With a base, economy, and production & expansion.

The idea would be that like in Civ, we start with a small city, with 1-2 base legions. If the captial falls, you loose. Then, you can start producing (captial is basically a casern). New units or builders. Builders can move around a build things (fields, castles, towers, etc.). These buildings will improve your economy. The builders are a weak unit that one has to defend, so it also forces the player to build around their capital and to defend it, because enemies can raid and destroy buildings and builders.

When attacking a building, one could either burn it to the ground (raid for gold) or take it over (if overtaking the territory). If taken over, the building shall take a few turns to change side.

Looting could also be a thing, where dead units drop (10-30% of their build cost and maybe if higher tier also some science). Or food for living things, if food is a thing.

### Progression

Progression is key, to have the classical early game -> midgame -> late game feel which works great. Simplest is via "Science". Units (& buildings?) have Tiers. With science, you can unlock more powerful units over time. Economy also scales to allow to build those. Now there are 3 ways to do science, which we can for now have as 3 game modes (of which we would at first only implement one):

- **Random tech tree, same for each player:**
    - Roguelike experience, we never know what strategies will work.
    - Who can make the best army with given tech tree.
    - Fair & balanced by nature
- **Random tech tree, different per played**:
    - Roguelike like above
    - Assymetric, much more interesting as you need to build around your opponent
    - Cool because it kindof reflects the unique unit thing of usually factions, but with the roguelike element
    - Maybe a bit unfair, but if the units are varied enough and well balanced (no legion that has luck to have no counter at all) then all good
- **Faction system, prepared tech tree per faction:**
    - Each faction has its own units, strengths, and culture / identitiy
    - Much better for role playing, as all the units have visual and ideoligical synergy, and also game synergy. (e.g. Undead synergize around necromance)
    - Hard to tune and balance factions, and after a time a bit boring maybe?
    - Very good for beginners and for immersion
    - Also allows for a campaign.

Note: A campaign can still be done without a faction system, since it will still be possible to create "fake factions" from existing legions for the sake of the campaign.

### Exploration

Exploration is a key part that makes civ early game so fun. What do i want:

- RUINS! Give randomly money, random tech, random mercenary, information about the map
- Barbarians: They give you a reason to use your early units
- Neutral legions: Cattle, animals minding their own businnes
- Mercenaries: for gold, they join army (like HoMM) (note: barbarians and neutral legions could maybe also be recruited with for example a druid or forest fae)
- Abandoned buildings that one can just occupy
- Special tiles: pyramids, big bone, teleporter, volcano etc

---

## 11/08/26

I just came across an amazing game thats currently being developed by a two-man indie team. KingdomHex. It looks amazing and is very similar to what I am trying to achieve. It also features stacking, tactical combat on hex grid, many different units with many skills, recruiting and exploring system, stealth and much more..

The combat system is more oriented towards HoMM and Autobattlers like SAP, while my goal is to still allow for deep multi-legion combat more like civ. Also, they are definetely doing a faction oriented system, which seems to work very well, but seems to be a lot of work. They also feature heroes and items, which I guess is not yet planned to much for me.

Notes on exploration of KingdomHex: They really take the HoMM inspiration here:
Most of those are guarded by a neutral unit.
- Statues that you can claim that give a permanent buff while you keep control of it (really good idea).
- Spawners that recruit units for you while you control it
- Chests (basically ruins)
- Mines, farms, outposts etc

I maybe like the idea of "hardcoding" outposts and farms & so on on the map (like HoMM) and disallow manual founding. This makes simplifies a lot without loosing to much on the the Expand aspect. Also this prevents problems like having to have special rules for city placement and also things like putting a city in an opponents face like in Gladius. However, making cities weak should fix this also. Idk, more to think about on this.

Anyways, this got me thinking a lot about my own game again. First of all, I really (for this version of Realmrise) go on the fast-paced tactical combat side (like KingdomHex) and maybe a bit more in the Battle Royale style like Hunger Games. This means, that gameplay has to stay very varied and strategic. For this I imagine a science system. There should be many many legions, classified into say 4 tiers. At the start of a game, you get one Tier 0 legion (pick from 3 or smth). The science panel looks something like this:

*(screenshot not in repo — see note at top)*

The concept is simple. The three pink circles represent the 3 tiers. Tier I researches are all visible and unlocked. Tier II and III researches function in the same way: they get visible once one of the two parent researches is done, and they get unlocked when BOTH of the parents are researched. This makes in my opinion the research a bit interesting, because you cannot just rush Tier III, and can also not just always take the one research that is 100% the best, you may be forced to make a research that is not super convinient but that gets you to your desired higher Tier research. This forces diversification and will hopefully bring players to play legions they would maybe not at first glance. This seems like a simple yet elegant solution to the research problem. The reasearches are randomized (for each player or just in general depends on the game mode). Also, the good thing about science progressing over time (contrary to KingdomHex where you just instant buy research with gold) is that you always recuringly get a new unit which you can use. This prevents the "Ah I could buy a new tech but its better to just buy units with the gold" tradeoff. I hope that I can make legions be and have counters and hard-counters. This would make research very important since you need to find a counter against an opponents strategy.

I also like the concept of food as a population cap. This could mean that we have 3 resources: gold, food, science. Gold builds and recruits, Food supplies Cities and units, Science researches.

Back to the Hunger games idea: A main problem with multiplayer without diplomacy (e.g. Battle royale) is that you always profitate from 2 people warring and you chilling / backstabbing. There may be just no incentive to fight. Winning a city from the defeated enemy is defently a great reward and a good setup to win the game, but reaching this state is often not that easy I imagine. So how can we force this "battle royale" to end? Like in fornite, a zone does not make much sense since we have cities that cannot move. This may be fixable with enough stuff on the map that improves the economy of whoever controls it. This makes expanding rewarding, and thus will generate conflicts when people want the same thing. Just sitting around building your economy will be outscaled by people who expand, win cities etc. So I guess just make enough stuff of the map?

### Moving factory + crumbling tiles?

Another idea i just got, that could be original, would be to just create "walking cities / walking factories". They are your king (like in chess) and can move away from the shrinking zone? This would make exploration also more rewarding since you dont need to let your homebase down.

Summary of claude discussion:
- Core idea: one mobile "factory-city" per player (your capital + army production + economy + tech, all in one), moves ~1 hex/turn, forces movement instead of turtling.
- Tech tree merges unit unlocks with city upgrades (HP, gold, science, food, minimal attack) — every research feels meaningful.
- Factory can fight back a little, but shouldn't become a real combat unit.

This is a thing to think about.

### AI

Did some research on AI. RL or similar learning agents are widely out of scope. Currently I am doing AI using some kind of "Utilitly AI", I score all the available actions given context (how low is the opponent, how low am I, how much battle expectation and so on). This is the way to go. Only thing is, these factor values (e.g. heal score = 1,5 * total_health + 3 * one_unit_under_10%_hp) are hardcoded magic numbers. Let an optimizer optimize the hell out of that, e.g. evolutionary algo. I should continue building the AI with that in mind.

### Dev flow

First of all:
1. Develop a new effect / feature
2. Implement a new legion(s) to use that
3. Test that the effect works as intended
4. Implement the utility AI for that effect
5. Test that the AI uses it as intended

Because we need a lot of different legions with different effects before continuing on with the tech system and tier system.

---

## 20/08/26

I thought a bit about the competitive aspect of the game. Realistically, we can make the game only 1v1 for online multiplayer, because I would like fast paced games (like chess or SAP), and since making the game have synchronous turns is not really possible / would ruin the player experience, we need to wait out the opponents turn. I would fancy as similar clock system to chess, but maybe working more with delays. E.g. 3 min max, 30s delay per turn, 10s increment. So that you can make longer turns, and not be pressured against playing super super fast, because there is the 30s delay + the increment.

Also, i thought that you can allow the player to manage his science tree & production queue also during the turn of the opponent, that would also help to make the game flow more and feel more synchronous. Like: your turn: tactics, opponents turn: economy.

For the 1v1, I would like to make the economy also play a role, to get always the rush & skip economy VS focus economy and late game (a bit like card games like MTG). Since we would like to have everything streamlined to each one having ONE capital, that produces units and loses the game if it falls, I cannot really put all the economy on the capital, its a bit boring and you cannot really interact with it. So, we would like to scatter the economy all over the map, such that territory control & raiding becomes a new strategy layer.
I would like to separate the territorial economy in two parts:
- Map-tied economy: like buildings that already exist on the map, special tiles, neutral units etc
- Self build economy: buildings that your builders can build: farms, mines, watchtowers, fishing boats...

The idea of the Civ6 builders is very good for this task I think: they are units, with a special action: *build something* **and** *consume itself*. Like in Civ6 with the builder chargers. Here each builder unit can build 1 thing and then be consumed. I would separate the builders into 3 tiers, and they each get unlocked when the first technology of that tier gets unlocked. This ensures a progression in the buildable things without needing a separate economy research tree. But here again, we could (maybe too complex), tie the buildable buildings (5 per tier) to the research tree. Such that each research gives 1 unit and 1 building. For tier 1 it could be:
- farm on grassland (+food)
- mine on mountain (+prod)
- ...
I'm not sure i can fill with 5 buildings per tier, its probably not very balanced...
Also, with this system, one could fill the surroundings of his base with fields and mines. But I mean maybe this is what we want. To spread out a bit, it's probably enough to have some special tiles that give higher rewards but at the same time require higher builder tier and are farther away so harder to protect. In addition to that there will maybe still be some neutral buildings that will increase the territorial control i would like.

How do units interact with these buildings? Simple, when conquering the building of the opponent, you can either:
- Claim (2AP, terminal) if you think you can keep it
- Burn down (1AP, terminal) if you are raiding them and do not plan to keep it

Actually, thinking of the putting fields all around your home, this can be a good thing to avoid turtle stalemates where 1 person is "loosing", but chills in his city super long and stalls the game. By loosing your surrounding fields, your economy crubles much faster and you'll not be able to keep up. This probably also allows for very interesting hit & run tactics.

I am loosing the faden. A few things i still wanted to say is that i found a way to introduce a "soft" food limit. I do not like hard caps because this feels very unnatural. But we can have a food counter, each unit eats for its size (so each full legion costs 12 food). If you are over your food limit, you will still be able to produce and/or research (not sure if reasearch should be impeded by food..), but production will be decreased by the food difference. This way you could force a bit army for a big push, and tank the worse economy if you think that your hit is going to be enough.

I am really excited for this, this starts to feel like a simple yet deep and strategic game. I think balancing everything will be quite hard but fun.
