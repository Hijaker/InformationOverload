# Information Overload

Information Overload gives your Darktide missions a history. It brings together mission results, combat statistics, personal records, weapon comparisons and the people you play with, so you can return to a run and see more than whether you won or lost.

Use it to follow a character's progress, compare weapons across actual missions, find the enemies responsible for your downs, revisit a clutch, or keep track of your fastest clears. The dashboard is the detailed view. Optional additions to the character screen, mission board, social screen and end screen put relevant information where you already play.

## Contents

- [Getting started](#getting-started)
- [Reading your statistics](#reading-your-statistics)
- [Overview](#overview)
- [Last Mission](#last-mission)
- [Match History](#match-history)
- [Trends](#trends)
- [Records](#records)
- [Weapons](#weapons)
- [Classes](#classes)
- [Streaks](#streaks)
- [Deaths](#deaths)
- [Speedrunning](#speedrunning)
- [Dossier](#dossier)
- [Team](#team)
- [Friends](#friends)
- [Psykhanium](#psykhanium)
- [Scoreboard and Tracker](#scoreboard-and-tracker)
- [Other game screens](#other-game-screens)
- [Settings and your saved data](#settings-and-your-saved-data)
- [Ways to use the information](#ways-to-use-the-information)

## Getting started

Information Overload requires Darktide Mod Framework. Install the mod in your Appdata/Fatshark/Darktide folder, and add `InformationOverload` to your mod load order after the framework.

Once you're in the game, enter `/io` or `/io_dashboard` in chat to open the dashboard. You can also assign **I/O's Key** in Mod Options. A separate **Scoreboard Key** is available if you want independent controls for the dashboard and scoreboard.

Play a mission, then return to the dashboard. There is no need to manually save ordinary missions. Some summaries finish updating after you return to the Mourningstar, so a temporary counting or preparation message can appear before the numbers are ready.

Start with **Overview** for a broad picture, **Match History** for a particular run, or **Weapons** for equipment comparisons. Open **Settings › Screens** to choose which additional game screens should show Information Overload's panels.

### Finding your way around

The navigation rail opens the dashboard pages. Its names can be pinned open. Page tabs and detail selectors provide more focused views, and the breadcrumb trail shows where you are. Back navigation lets you return from a record or mission to the page you came from.

Many record cards, mission rows and chart points open the mission behind the number. Use those links to check the conditions in which a result was set instead of judging the number alone.

### Set the scope before comparing

Pages offer the filters relevant to their information, including **Havoc / Non-Havoc**, **Difficulty**, **Patch** and, where appropriate, **Class**. Some pages support **All Patches**; others work within a selected patch.

Havoc and Non-Havoc results are kept distinct. Patch selection matters because balance changes can affect weapons, enemies and builds. An all-patch view is useful for your overall history, while a single-patch view makes comparisons easier to interpret.

For example, a weapon's average across every difficulty answers a different question from its average in Auric missions on the current patch. Check the scope and the number of contributing missions before comparing two figures.

## Reading your statistics

### Personal, team and teammate figures

A mission can contain your own statistics, the whole team's totals and individual teammate observations. Labels such as **Your**, **Whole Team**, **One Operative** and **Team Share** identify whose performance is being shown.

A team's damage total is not your damage total. Likewise, a class breakdown across your teams includes the operatives of that class who played alongside you; it is not automatically a breakdown of your own characters.

### Damage, useful damage and overkill

**Reported damage** is the damage recorded from the game's damage reports. **Useful damage** is the portion accounted for as removing remaining enemy health. **Overkill** is the portion accounted for beyond that remaining health.

Suppose an enemy has 100 health left and a hit reports 350 damage. With a current health observation, that hit contributes 100 useful damage and 250 overkill. A large finishing hit can therefore be a damage record while contributing less useful damage than its headline number suggests.

The useful/overkill split depends on observed health. Several players can hit the same enemy almost together, so the mod cannot independently prove every intermediate health value. Where the split is unavailable, information can be shown as uncertain or without an armour split. **Uncertainty** in this context describes damage the mod could not split; it is not a confidence interval covering every possible measurement error.

Read each page's caption. Weapon per-hit comparisons and Match History's combined damage summaries use useful damage, while other views can present reported damage, explicitly including overkill. A record-sized hit and a useful-damage average are different measurements.

Shield absorption and boss shields also need care: a shield interaction is not automatically enemy health damage. An absorbed hit, missing health information and an ordinary damaging hit should not be treated as interchangeable observations.

### Hits, attacks, kills and damage over time

One attack can hit several enemies. A projectile can produce a direct impact and an explosion. Burning, bleeding, Soulblaze and Toxin can continue to produce damage reports after the original attack. A hit count is therefore not a count of trigger pulls, swings or kills, and it is not a shooting-accuracy percentage.

Damage-over-time totals are available separately where recorded. They can make a large contribution even when a weapon's direct-hit history is sparse. Do not assume that every periodic tick can be uniquely traced back to one original shot or one blessing.

Where chronology is available, it reflects when events were observed. A delayed explosion or burning tick appears when its damage is reported, rather than being moved back to when the attack began.

### Missing information and sample size

A dash or **Not Recorded** means a value is unavailable, rather than zero.

Totals, averages and percentages can have different coverage. A page may contain 20 missions but only 14 with the information needed for a particular measurement. Read the contributing count where shown.

Small samples and exceptional encounters can move an average sharply. A short loss, a boss-heavy mission and a long horde fight need not produce comparable damage or per-hit values, even with the same equipment.

### Full missions, partial missions and interruptions

Losses can be full recorded missions. A **partial mission** instead indicates that the mod observed only part of the run, such as a late join, rejoin or early departure.

**Settings › Counting** controls whether those partial categories contribute to records and streaks. A partial result describes the play actually observed; it does not estimate what happened before you joined or while you were disconnected.

Reconnect handling can bring recorded portions of a mission together. Missing intervals remain missing, and uninterrupted combat streaks should not be assumed to continue through an observation gap.

## Overview

Overview is the starting point for your recorded career in the selected scope. It combines mission results, your latest run, class activity and headline records with links to more detailed pages.

Use the **Last Mission** card to reopen your latest recorded run. Follow a record to its source mission, or open **All Trends** to see how results developed over time. The class summary helps you see which classes you have played and how their recorded results compare. A favourite class can be marked in Settings.

Keep the selected mode and patch in mind: changing the scope can change which result qualifies as a best.

## Last Mission

Last Mission opens the newest recorded run directly, using the same detailed views as a mission opened from Match History. It is a shortcut for reviewing the game you just finished, including a loss, rather than a separate set of statistics.

Use it to check your squad's damage breakdown, incidents and biggest attacks before moving on. To compare it with an older run, return to Match History or Trends.

## Match History

Match History is the mission-by-mission record and the starting point for detailed comparisons. It has **Runs** and **All** tabs.

### Runs

The Runs list shows the date, match number, map, difficulty, result, class, your kills, your damage and Match Time. Partial missions are labelled. Sort the list to find recent missions, older runs, high-damage games, high-kill games or fast clears.

The filter panel can narrow results by outcome, date, your class, team composition, particular teammates, map and run type. Havoc also offers modifier filtering. **Team Had (Class)**, **Played With (Specific Player)** and **Modifiers** are useful when comparing a recurring group or a specific team composition.

For example, filter to Zealot, one map and victories to compare your successful runs without mixing in another class or unrelated missions. Add a particular teammate to see your results together.

### All: averages, minimums and maximums

The All tab summarizes the missions matching your filters. Its measurement selector offers averages and per-mission minimums or maximums, rather than requiring you to inspect every row.

The summaries include games and results, useful team and personal damage, class contributions, armour breakdowns, kill information, defensive statistics and friendly-fire information. A personal-class selector helps distinguish your own results on one class from all recorded operatives of that class in your teams.

Minimum and maximum comparisons use completed mission results, including defeats, rather than early-leave records. The available sample also depends on the selected filters and which missions saved the measurement in question.

Minimum and maximum figures are selected separately for each measurement. The highest team damage, the highest share for one class and the highest number of pickups need not come from the same mission. Source links let you open the run responsible for an individual extreme.

**Example:** use average useful damage to describe typical observed contribution, then maximum useful damage to find an exceptional run. Check the source mission before treating the maximum as representative.

### Inside a mission

Opening a run provides the following tabs when the saved information is available:

- **Overview:** mission context, result, Match Time, squad, useful-damage shares and armour breakdown, together with recorded kill-survival streaks.
- **Damage:** whole-team or individual-operative damage, useful damage, overkill and uncertainty. Categories include melee, ranged and damage over time, with recorded periodic effects such as Bleed, Burn, Soulblaze and Toxin shown separately.
- **Friendly Fire:** recorded damage and incidents between operatives, including who affected whom where attribution is available.
- **Deaths:** recorded downs, deaths and pickups, including enemy or incident causes and teammate interactions where known.
- **Attacks:** an operative's kill categories and largest recorded attacks, with weapon, enemy, armour or cleave details when saved.

A mission also shows its roster, classes, difficulty and modifiers.

**Delete Match** removes that mission and recounts records and streaks from the remaining history. This is permanent.

## Trends

Trends turns the selected mission history into graphs and comparisons over time. Tabs cover **Results**, **Damage**, **Kills**, **Deaths**, **Clear Times**, **Team Share** and **Classes**.

Use Results to follow wins and losses, Damage and Kills to see changes in your recorded output, and Deaths to look for recurring causes. Clear Times helps compare successful runs by map. Team Share shows your useful damage alongside the team's, while Classes compares recorded activity and outcomes between classes.

A trend is a prompt to investigate, rather than proof that a build change caused an improvement. Changing difficulty, team composition, mission length or enemy mix can change the graph just as much as changing a weapon.

For example, if your damage rises after switching weapons, check whether your missions also became longer. If your useful-damage share falls while your group starts winning more often, the other operatives may simply be contributing more.

## Records

Records is the place to find exceptional individual results, rather than your average performance. Its **Damage** and **Non-Damage** tabs separate offensive bests from incident-based records.

Damage records include the **Biggest Single-Target Hit**, **Biggest Melee Cleave** and **Biggest Explosion**. Detailed views organize saved records overall, by armour, by enemy or by weapon. Where a source mission was saved, you can open it to see the context.

Non-Damage records include observed downs, deaths, Pox Hound pounces, Trapper nets, Mutant catches, pickups and friendly-fire damage, with personal and team distinctions and outcome filtering where available.

A “most” record is a maximum, not necessarily a desirable result. Most pickups can describe a rescue-heavy mission; most downs describes a difficult run. A biggest-hit record also answers a different question from sustained damage or useful damage per hit.

## Weapons

Weapons connects recorded mission loadouts with the weapon information available for those missions. Browse weapon cards or use **Compare** to see weapons alongside one another, with melee/ranged selection and the page's scope filters.

Open a weapon for three detail tabs:

### Per Hit

See useful damage per hit by armour, the recorded hit distribution, overkill information and the missions contributing to the weapon's figures. Armour categories include **Unarmoured, Flak, Maniac, Carapace, Unyielding** and **Infested**.

The overall per-hit value is affected by what you hit. A weapon used mostly against hordes can have a different average from the same weapon used on elites. The armour breakdown helps make that distinction visible. Per-mission points provide context around the combined average.

### By Enemy

This view shows the biggest saved hits against enemy types and recorded melee cleaves. Use it to find which enemies produced a weapon's largest results, then open the relevant mission where a source link is available.

### Blessings

Compare the recorded blessing sets used with that weapon. The comparison uses useful damage per hit from the contributing missions, with armour details where available.

This is an observation of different loadouts in actual play. It does not isolate a blessing's contribution. If one set averages more damage, differences in attacks, targets, difficulty, other talents and teammates may also explain the result.

**Example:** compare two blessing sets against Flak rather than comparing only their combined averages. Check whether one set has only one mission and the other has twenty before drawing a conclusion.

### Coverage and exports

A weapon can appear because it was saved in a loadout even when it has little usable hit information. The page explicitly leaves the Inferno Force Staff, Purgatus Flamer, Rumbler and Grenadier Gauntlet without per-hit figures because their hit history is not sufficiently represented there yet. This does not mean that their reported mission damage is zero; use the mission damage breakdown for that view.

**Export Data Sheet** offers **By Armour (CSV)**, **By Enemy (CSV)** and **Everything (JSON)**, with a preview and file name before saving. Use a CSV in a spreadsheet to compare the page's recorded figures. The JSON option keeps the broader weapon summary. An export preserves the selected view's coverage and limitations; it does not add missing hits.

## Classes

Classes brings together one class's mission results, damage records and streaks. Choose a recorded class to see its **Overview**, **Damage** and **Streaks**, with additional class-specific tabs appearing when relevant information exists.

Only classes with recorded information appear in the relevant selections.

The overview includes results and a chronological mission chart, mission bests, kill-type bests, boss and clutch information, and applicable class records. Damage details can be grouped overall, by armour, by enemy or by weapon.

Class-specific information includes:

- **Blitz:** recorded explosion bests and, for supported abilities, kill totals and mission kill records.
- **Point-Blank Barrage:** Ogryn ammunition-return records, including weapon-specific figures.
- **Burst Limiter Override:** Ogryn proc and streak information.
- **Crystalline Will:** Psyker detonation records, including damage and kills per detonation or mission.
- **Hyper-Critical:** Hive Scum execution-kill summaries where recorded.

These are focused records, not a universal measurement of every talent or blessing. A class-specific tab appears when there is information to show.

## Streaks

Streaks shows current and best runs of qualifying events or mission results, across classes or for a selected class. Available entries include wins and losses in a row, wins without particular incapacitations, headshot and kill chains, melee dodge chains and selected team-condition streaks. Non-Havoc also includes Maelstrom result streaks.

Read the wording of the streak. **Wins Without A Down** is different from **Wins Without A Death**. **Kills Without A Down** is different from the mission detail's **Kills Before Taking A Hit**.

The two mission kill-survival measurements also differ:

- **Kills Before Taking A Hit** resets on observed incoming damage, including a hit to Toughness alone. Blocks and dodges do not reset it.
- **Kills Before Losing Health** tracks the separate health-loss condition.

Use streaks to follow consistency across missions, rather than only the largest individual hit.

## Deaths

Deaths looks at what downed or killed you across the selected history. It provides **Grouped** and **Individual** views, with detail selection for groups or specific enemies.

The page shows total downs and deaths, per-game figures where available and a most-lethal-enemy summary. Open an enemy to inspect its contribution to your recorded incidents.

A cause can be unknown or involve more than one recorded contributor. Treat the information as a way to identify recurring problems, rather than a complete replay of the last seconds before every down.

**Example:** repeated Trapper incidents suggest a different survival problem from repeated deaths to ordinary ranged enemies. Filter the relevant scope before changing your build or tactics based on the totals.

## Speedrunning

Speedrunning lists your fastest recorded clears by map, organized by mission area. Open a map for the fastest time, date, difficulty, modifiers and average time where available, with a link to the source mission.

### Match Time

**Match Time** uses the duration supplied by the game's backend in its end-of-match report. It is displayed to milliseconds: for example, **32:31.200**. This allows us to ensure that the time you got for a map, is timed the exact same way one of your friends map was. By using the Server's own supplied mission timing, we remove the uncertainty that Latency and Hardware adds to the game, and simultaneously allows us to give you a time for a map that you happened to disconnect from, in case of a crash or similar. As long as you're present for the end of the map, your time will be saved.

The report can arrive after the initial save, so the displayed Match Time can update once it is received.

The in-game clock and the backend report use different timing bases. The clock you see while playing can therefore differ from the saved Match Time; there is no fixed offset to add or subtract to make them agree, that we have found so far.

Choose a specific difficulty when comparing clears. In Havoc's all-difficulty Speedrunning view, the page uses the highest available Havoc rank in that scope.

Defeats remain in Match History but do not qualify as successful clear-time records.

## Dossier

Dossier follows your individual characters rather than combining every character of a class. Select an operative to see their recorded service history, results by difficulty, totals, equipment history, bests and mission entries.

It can show previous names associated with that same character, the newest saved loadout information and the weapons they have taken out. Counts such as “In 8 Of 10” make it clear when a total has information from only some missions.

Use Dossier to compare your characters' histories or revisit an operative you have not played recently. The equipment summary shows the latest saved loadout.

## Team

Team summarizes the squads you have played with. Its tabs are **Bosses**, **Clutches** and **Fun**.

**Bosses** lists the bosses killed by your teams and recorded rituals stopped.

**Clutches** shows recorded clutch results by operative. A semi-clutch begins with only one operative able to act while at least one other teammate is still down and potentially revivable. A full clutch has all the other teammates dead or awaiting rescue; a semi-clutch can become a full clutch situation if the remaining downed teammates die. A successful clutch is recorded when a teammate returns to an active state while the clutching operative survives. A clutch episode and a mission won with a clutch are separate counts: one successful mission can contain several clutch situations.

**Fun** collects unusual team-wide statistics, including recorded bot clutches (Disconnecting from a game, to create a bot that potentially gets an ally back on their feat) and Havoc departure/rejoin patterns. The **Leave Abuse** label describes detected patterns around disconnecting during situations such as a net, knock-off or death; it is not proof of a player's intention though. **Settings › Display › Name Leave Abusers** controls whether names or only counts are shown.

Use team records to revisit memorable runs, while checking the mission context before judging another player from a single number.

## Friends

Friends brings together Steam friends and players you choose to track. It shows missions and wins together, class results, clutch records and the enemies responsible for their downs.

To track someone, open a saved mission and choose **Track** next to their name. **Settings › Data › Tracked Players** also lets you manage tracked players and select from recent teammates. Steam friends are identified separately.

The tracking option in **Settings › Counting** controls keeping statistics for manually tracked players alongside Steam friends.

The **Most Successful Class** comparison requires at least five missions with that player on the class.

## Psykhanium

Psykhanium is a separate weapon bench for repeatable training sessions. Training observations are kept separate from ordinary mission records and streaks.

The bench currently focuses on the **melee slot**, showing the operative, weapon, blessings and perks where available. Its live view includes damage, hits, damage per hit, best hit and a damage-per-second graph. It also compares available per-armour results with recorded mission averages for the same loadout or weapon.

The live DPS display uses a **two-second window**; comparisons between saved sessions use a **six-second window**. **Best 10 Seconds** is a fixed ten-second window of reported damage, excluding shields, and never spans a reconnect. These are different measurements from **DPS While Hitting**, so compare matching labels.

To compare two loadouts:

1. Equip the first loadout and attack the training targets under consistent conditions.
2. Once the session has enough recorded hits, choose **Save Session**. Saving keeps it and starts a new session.
3. Equip the second loadout and repeat the same attack pattern and targets.
4. Select two sessions in Saved Sessions and open their comparison.

The comparison shows session duration, damage, hits, damage per hit, DPS while hitting, best ten seconds, best hit and per-armour differences. Session A and B have separate traces on the same timeline.

**Reset Session** clears the session in progress while keeping saved sessions. Saved sessions can also be deleted through the bench's deletion controls. Saving requires at least five recorded hits. Tracking in the Psykhanium can be disabled in Mod Options.

A comparison is only as controlled as the sessions you create. Different targets, armour, attack patterns or buffs can produce a difference even if a blessing change contributed nothing. Outside the Psykhanium, the page lets you revisit the sessions you saved.

## Scoreboard and Tracker

The optional scoreboard gives an in-mission squad view and can also be opened on the end screen. Available layouts are **Squad Table**, **Squad Cards**, **Strip** and **Off**, with separate choices for missions and the end screen.

The squad view includes recorded damage and combat/incident figures such as kills, elites, specials, downs and deaths. It reflects the same distinction between personal and team observations used elsewhere in the dashboard.

Configure whether holding or tapping your assigned key shows the scoreboard or opens Information Overload. Binding the separate Scoreboard Key gives that control its own key while I/O's Key opens the dashboard. **Move** and **Reset** controls let you position the panels.

The **Tracker Panel** provides Match Time, kill streak, downs and kills. It can appear alongside the Esc menu, with the held scoreboard, or while you wait to be rescued, according to your settings. The **Match Time** display can be enabled from Display settings.

Saved clear-time comparisons use Match Time from the end-of-match report.

## Other game screens

Open **Settings › Screens** to enable each screen addition independently. Enabling one exposes its own settings tab, so you can keep only the elements you want.

### Character Select

The **Service Record** shows the chosen operative's recorded results, kills and damage. Optional sections show their most-used weapons and recurring down/grab causes. **Account Wallet** displays the account's currencies beside Start.

### Squad Social

The social additions show the last observed class and level of friends, missions together and hover records for yourself or a strike-team member.

### Mission Board

Hovering a mission can show a **Map Briefing** with your record on that map. Optional sections show **What Downs You Here** and **Won Here With**, helping you connect a mission choice with your previous experience.

### End Screen

The end-screen additions show Match Time and records beneath the squad. Hover for a **Mission Debrief** covering recorded kills, damage, records and comparisons with other runs. The optional down/death section lists squad incidents in recorded order.

You can also hide the mission-rating thumbs without submitting a rating automatically.

## Settings and your saved data

### Display and controls

Display settings include compact K/M numbers or full numbers, relevant exact-value hovers, a favourite class, preferred starting mode, remembered page positions and the Match Time display. You can hide names in the departure-pattern section while retaining counts.

Mod Options contains dashboard/scoreboard keybinds and the switch for Psykhanium tracking. Most presentation and screen choices are inside the dashboard's Settings page.

### Counting

Choose how late-join, rejoined and early-leave missions contribute to records and streaks. Changes are recounted after returning to the Mourningstar. This can change the summaries without changing what originally happened in a saved mission.

### Chat and recording

The optional **Field Improvisation** message reports at mission start whether a Veteran in the squad has that talent. The line is shown only to you.

**Burst Limiter Override** recording can be switched off if you do not want to collect that Ogryn proc information. Turning off an optional screen panel changes what is displayed; it is not a general switch that stops all mission recording.

### What is saved

Information Overload saves its history locally. The ordinary data folder is:

`%APPDATA%\Fatshark\Darktide\InformationOverload`

Saved information can include:

- Mission identity, date, map, mode, difficulty, result, patch, modifiers and timing.
- Your character identity and observed squad identities, names, classes and loadouts.
- Personal and team damage, kill categories, useful/overkill accounting and attack records.
- Downs, deaths, disables, pickups, friendly-fire incidents, bosses, clutches and departures.
- Recorded combat chronology, kill-survival streaks and applicable class-specific records.
- Saved Psykhanium sessions and the summaries needed to compare them.

Saved loadouts describe the equipment and choices observed for that mission. They do not prove the exact effective state of every talent at every impact. The mod does not provide a complete reconstruction of damage added by each talent or blessing.

### Reset, restore, rebuild and import

The **Your Data** section under **Settings › Data** provides distinct actions:

- **Reset Statistics** moves the existing statistics into a backup after confirmation. Settings are kept.
- **Restore Latest Backup** or **Restore All Backups** brings back the chosen backup data while keeping matches played since the reset.
- **Delete Backups** permanently removes those backups while keeping the current statistics.
- **Rebuild Statistics** recounts records and streaks from saved Match History. It does not change the matches or create missing observations.
- **Import Match History** reads match files placed in `InformationOverload\reconstruction_import`. It replaces the active history on that PC and rebuilds statistics; it is not an additive merge into whatever is already there.

Read each confirmation before proceeding. Deleting a match and deleting backups are different actions. Keep a separate copy of the data folder before replacing or importing an important history.

## Ways to use the information

### Compare a weapon change

Select the same mode, difficulty and patch in Weapons. Compare useful damage per hit by armour, then inspect blessing sets and the contributing missions. Use Psykhanium sessions for a more controlled attack/target comparison. Treat a better mission average as an observed result, not automatic proof of a blessing's individual effect.

### Work on a recurring survival problem

Open Deaths and look at the grouped causes, then inspect the individual enemy. Check the relevant missions in Match History and compare the number of contributing games. A long history of one enemy causing downs is more informative than one unusual loss.

### Find out whether your group is improving

Use Match History's teammate filters, then review results and useful-damage summaries in All. Look at Trends for the selected scope and Team for bosses and clutches. Compare missions of similar difficulty rather than relying on the largest damage total.

### Follow one operative

Use Dossier for that character's history, equipment and bests. Use Classes for the broader class picture. The distinction matters if you have more than one character of the same class.

### Revisit a fast clear

Open Speedrunning, select the map and difficulty, then follow the source mission to review the loadout, team and modifiers behind its Match Time.
