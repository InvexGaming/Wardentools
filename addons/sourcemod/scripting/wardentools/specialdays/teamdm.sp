#include "wardentools/colours.sp"
#include "wardentools/highlights.sp"

//Convars
ConVar cvar_specialdays_teamdm_slaytime = null;
ConVar cvar_specialdays_teamdm_tptime = null;
ConVar cvar_specialdays_teamdm_hidetime = null;
ConVar cvar_specialdays_teamdm_autobeacontime = null;

//Global statics
static bool isEnabled = false;
static bool isPastHideTime = false;
static Handle freeforallRoundEndHandle = null;
static Handle autoBeaconHandle = null;
static Handle freeforallStartTimer = null;

static int tdm_teamColourCodes[5] = { COLOURS_RED, COLOURS_BLUE, COLOURS_GREEN, COLOURS_YELLOW, COLOURS_BLACK};
static int tdm_teamCounter = 0;
static int tdm_numTeams = 0;

static bool restoreClanTags = false;
static char clantagStorage[MAXPLAYERS+1][32];

public void Specialdays_Init_TeamDm()
{
  Specialdays_RegisterDay("Team Deathmatch Day", Specialdays_TeamDm_Start, Specialdays_TeamDm_End, Specialdays_TeamDm_RestrictionCheck, Specialdays_TeamDm_OnClientPutInServer, false, false);
  
  //Convars
  cvar_specialdays_teamdm_tptime = CreateConVar("sm_wt_specialdays_teamdm_tptime", "10.0", "The amount of time before all players are teleported to start beacon (def. 10.0)");
  cvar_specialdays_teamdm_hidetime = CreateConVar("sm_wt_specialdays_teamdm_hidetime", "60", "Number of seconds everyone has to hide (def. 60)");
  cvar_specialdays_teamdm_slaytime = CreateConVar("sm_wt_specialdays_teamdm_slaytime", "420.0", "The amount of time before all players are slayed (def. 420.0)");
  cvar_specialdays_teamdm_autobeacontime = CreateConVar("sm_wt_specialdays_teamdm_autobeacontime", "300.0", "The amount of time before all players are beaconed and told to actively hunt (def. 300.0)");
  
  //Hook
  HookEvent("player_death", Specialdays_TeamDm_EventPlayerDeath, EventHookMode_Pre);
  HookEvent("round_prestart", Specialdays_TeamDm_Reset, EventHookMode_Post);
  HookEvent("player_spawn", Specialdays_TeamDm_EventPlayerSpawn, EventHookMode_Post);
}

public void Specialdays_TeamDm_Start() 
{
  isEnabled = true;
  
  //Remove radar
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      CreateTimer(0.0, RemoveRadar, i);
    }
  }
  
  //Create timer to slay all players
  freeforallRoundEndHandle = CreateTimer(GetConVarFloat(cvar_specialdays_teamdm_slaytime) - GetTimeSinceRoundStart(), Specialdays_TeamDm_TeamDmEnd);
  
  //Turn on friendly fire to prevent early round ends
  SetConVarBool(FindConVar("mp_friendlyfire"), true);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), true);
  
  //Create timer for damage protection
  Specialdays_SetDamageProtection(true, GetConVarFloat(cvar_specialdays_teamdm_tptime) + GetConVarFloat(cvar_specialdays_teamdm_hidetime));
  
  //Create Timer for auto beacons
  autoBeaconHandle = CreateTimer(GetConVarFloat(cvar_specialdays_teamdm_autobeacontime) - GetTimeSinceRoundStart(), Specialdays_TeamDm_AutoBeaconOn);
  
  //Team Deathmatch Day message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Day", RoundToNearest(GetConVarFloat(cvar_specialdays_teamdm_tptime)), RoundToNearest(GetConVarFloat(cvar_specialdays_teamdm_hidetime)));
  
  //Show warning
  Specialdays_ShowGameStartWarning(GetConVarFloat(cvar_specialdays_teamdm_tptime) + GetConVarFloat(cvar_specialdays_teamdm_hidetime), 5);
  
  //Create timer for team dm start
  freeforallStartTimer = CreateTimer(GetConVarFloat(cvar_specialdays_teamdm_tptime) + GetConVarFloat(cvar_specialdays_teamdm_hidetime), Specialdays_TeamDm_TeamDmStart);
  
  //Teleport all players to warden
  int warden = GetWarden();
  if (warden != -1)
    Specialdays_TeleportPlayers(warden, GetConVarFloat(cvar_specialdays_teamdm_tptime), "Team Deathmatch", Specialdays_Teleport_Start_All, TELEPORTTYPE_ALL);
}

public void Specialdays_TeamDm_End() 
{
  isEnabled = false;
}

public bool Specialdays_TeamDm_RestrictionCheck() 
{
  //Check that we have 4 people total alive
  int numAlive = 0;
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) {
        ++numAlive;
      }
    }
  }
  
  //Check for enough people
  if (numAlive < 4) {
    int warden = GetWarden();
    if (warden != -1)
      CPrintToChat(warden, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - More People Needed", 4);
    
    return false;
  }

  return true;
}

//Round pre start
public void Specialdays_TeamDm_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  if (freeforallRoundEndHandle != null)
    delete freeforallRoundEndHandle;
    
  if (freeforallStartTimer != null)
    delete freeforallStartTimer;
  
  if (autoBeaconHandle != null)
    delete autoBeaconHandle;

  isPastHideTime = false;
    
  for (int i = 1; i <= MaxClients; ++i) {
    if (!IsClientInGame(i))
      continue;
    
    //Reset clan tags to what was stored
    if (restoreClanTags) {
      CS_SetClientClanTag(i, clantagStorage[i]);
      clantagStorage[i] = ""; //reset storage
    }
  }
  
  //After all clan tags have been restored, disable bool
  restoreClanTags = false;
    
  SetConVarBool(FindConVar("mp_friendlyfire"), false);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), false);
}

public void Specialdays_TeamDm_OnClientPutInServer(int client)
{
  SDKHook(client, SDKHook_OnTakeDamage, Specialdays_TeamDm_OnTakeDamage);
}

//Player spawn hook
public Action Specialdays_TeamDm_EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!isEnabled)
    return Plugin_Continue;
    
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (!IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
    return Plugin_Continue;
  
  Specialdays_TeamDm_ApplyEffects(client);
  
  return Plugin_Continue;
}

//Player death hook
public Action Specialdays_TeamDm_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  if (!isEnabled)
    return Plugin_Continue;
  
  if (!isPastHideTime)
    return Plugin_Continue;
  
  //Check if team DM should be stopped
  int teamsLeft = Specialdays_TeamDm_GetNumTeamsAlive();

  if (teamsLeft <= 1) {
    //Find winning team
    int winningTeamCode = COLOURS_DEFAULT;
    
    for (int i = 1; i <= MaxClients; ++i) {
      if (IsClientInGame(i) && IsPlayerAlive(i)) {
        if (Highlights_IsHighlighted(i)) {
          winningTeamCode = Highlights_GetHighlightedColour(i);
          break;
        }
      }
    }
  
    //Print message to all
    if (winningTeamCode == COLOURS_RED)
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Winner", "darkred", "red");
    else if (winningTeamCode == COLOURS_BLUE)
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Winner", "blue", "blue");
    else if (winningTeamCode == COLOURS_GREEN)
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Winner", "lightgreen", "green");
    else if (winningTeamCode == COLOURS_YELLOW)
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Winner", "olive", "yellow");
    else if (winningTeamCode == COLOURS_BLACK)
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Winner", "default", "black");

    //End the round
    CS_TerminateRound(GetConVarFloat(FindConVar("mp_round_restart_delay")), CSRoundEnd_CTWin, false);
  }
  
  return Plugin_Continue;
}

//Called when a player takes damage
public Action Specialdays_TeamDm_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  //Ignore invalid entities
  if (!(victim >= 0 && victim <= MaxClients) || !(attacker >= 0 && attacker <= MaxClients)) {
    return Plugin_Continue;
  }

  if (isEnabled && isPastHideTime) {
    //Check for player trying to kill team mates
    //Everybody should be highlighted and on a team so this is sufficient
    if (Highlights_IsHighlighted(victim) && Highlights_IsHighlighted(attacker)) {
      if (Highlights_GetHighlightedColour(victim) == Highlights_GetHighlightedColour(attacker)) {
        return Plugin_Handled;
      }
    }
  }
  
  return Plugin_Continue;
}

//Get number of teams left alive in team DM (T Only)
int Specialdays_TeamDm_GetNumTeamsAlive()
{
  //Check if at least two teams exist
  ArrayList teamsArray = CreateArray(MaxClients);

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) {
        if (Highlights_IsHighlighted(i)) {
          int index = FindValueInArray(teamsArray, Highlights_GetHighlightedColour(i));
          
          if (index == -1)
            PushArrayCell(teamsArray, Highlights_GetHighlightedColour(i));
        }
      }
    }
  }
  
  return GetArraySize(teamsArray);
}

//Auto beacon all alive players
public Action Specialdays_TeamDm_AutoBeaconOn(Handle timer)
{
  autoBeaconHandle = null;
  
  if (!isEnabled)
    return Plugin_Handled;
    
  ServerCommand("sm_beacon @alive");
  ServerCommand("sm_msay All players must now actively hunt other players.");
  
  return Plugin_Handled;
}

//Called when TeamDM round ends
public Action Specialdays_TeamDm_TeamDmEnd(Handle timer)
{
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      ForcePlayerSuicide(i);
    }
  }
  
  //Print round end message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Round Over");
  
  //Reset timer handle
  freeforallRoundEndHandle = null;
}

//Timer called once TeamDM day starts
public Action Specialdays_TeamDm_TeamDmStart(Handle timer)
{
  isPastHideTime = true; //hide time is over
  
  //Check that there are enough players to play
  int entryCount = 0;
  ArrayList eligblePlayers = CreateArray(MaxClients+1);
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) {
        PushArrayCell(eligblePlayers, i);
        ++entryCount;
      }
    }
  }
  
  //Check to see if the minimum number of players are present
  if (entryCount < 4) {
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Aborted");
    freeforallStartTimer = null; //Needed so invalid handle doesnt occur later
    CS_TerminateRound(GetConVarFloat(FindConVar("mp_round_restart_delay")), CSRoundEnd_CTWin, false);
    return Plugin_Handled;
  }
  
  //Give players full armour
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      GivePlayerItem( i, "item_assaultsuit");
      SetEntProp(i, Prop_Data, "m_ArmorValue", 100, 1);
    }
  }

  //Pick teams and highlight players
  tdm_numTeams = 0;
  
  if (entryCount <= 10)
    tdm_numTeams = 2;
  else if (entryCount <= 20)
    tdm_numTeams = 3;
  else if (entryCount <= 30)
    tdm_numTeams = 4;
  else if (entryCount <= 40)
    tdm_numTeams = 5;
  
  tdm_teamCounter = 0;
  int numAlive = entryCount;  //needed for loop
  
  //Assign team to each eligble player
  for (int c = 0; c < numAlive; ++c) {
    int rand = GetRandomInt(0, entryCount - 1);
    int client = GetArrayCell(eligblePlayers, rand);
    removeClientFromArray(eligblePlayers, client);
    entryCount = GetArraySize(eligblePlayers);
    
    //Highlight, assign team and colour
    Specialdays_TeamDm_ApplyEffects(client);
  }
  
  //Enable hud for all
  CreateTimer(0.5, Specialdays_TeamDm_ShowHud);
  
  freeforallStartTimer = null;
  
  return Plugin_Handled;
}

//Team DM HUD
public Action Specialdays_TeamDm_ShowHud(Handle timer)
{
  if (!isEnabled)
    return Plugin_Handled;
  
  for (int client = 1; client <= MaxClients; ++client) {
    if (IsClientInGame(client) && Highlights_IsHighlighted(client)) {
      int teammatesAlive = 0;
      int teammatesTotal = 0;
      int enemiesAlive = 0;
      int enemiesTotal = 0;
    
      //Get required info
      for (int j = 1; j <= MaxClients; ++j) {
        if (IsClientInGame(j) && Highlights_IsHighlighted(j)) {
          if (j == client)  //ignore client
            continue;
            
          if (Highlights_GetHighlightedColour(j) == Highlights_GetHighlightedColour(client)) {
            ++teammatesTotal;
            if (IsPlayerAlive(j))
              ++teammatesAlive;
          }
          else {
            ++enemiesTotal;
            if (IsPlayerAlive(j))
              ++enemiesAlive;
          }
        }
      }
      
      char team[10];
      char teamColour[10];
      
      if (Highlights_GetHighlightedColour(client) == COLOURS_RED) {
        Format(team, sizeof(team), "%s", "RED");
        Format(teamColour, sizeof(teamColour), "%s", "#FF0033");
      }
      else if (Highlights_GetHighlightedColour(client) == COLOURS_BLUE) {
        Format(team, sizeof(team), "%s", "BLUE");
        Format(teamColour, sizeof(teamColour), "%s", "#0000FF");
      }
      else if (Highlights_GetHighlightedColour(client) == COLOURS_GREEN) {
        Format(team, sizeof(team), "%s", "GREEN");
        Format(teamColour, sizeof(teamColour), "%s", "#336600");
      }
      else if (Highlights_GetHighlightedColour(client) == COLOURS_YELLOW) {
        Format(team, sizeof(team), "%s", "YELLOW");
        Format(teamColour, sizeof(teamColour), "%s", "#FFFF00");
      }
      else if (Highlights_GetHighlightedColour(client) == COLOURS_BLACK) {
        Format(team, sizeof(team), "%s", "BLACK");
        Format(teamColour, sizeof(teamColour), "%s", "#000000");
      }
      
      //Hint HUD
      PrintHintText(client, "%t", "SpecialDay - Team Deathmatch HUD", teamColour, team, teammatesAlive, teammatesTotal, enemiesAlive, enemiesTotal);
    }
  }
  
  CreateTimer(0.5, Specialdays_TeamDm_ShowHud);

  return Plugin_Handled;
}

//Apply special day effects
void Specialdays_TeamDm_ApplyEffects(int client)
{
  CreateTimer(0.0, RemoveRadar, client);
  GivePlayerItem(client, "item_assaultsuit");
  SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);
  
  //TDM started, assign random team to this player
  if (isPastHideTime) {
    Highlights_SetIsHighlighted(client, true);
    Highlights_SetHighlightedColour(client, tdm_teamColourCodes[tdm_teamCounter]);
    
    //Highlight them and print a message
    char clantag[10];
    
    if (Highlights_GetHighlightedColour(client) == COLOURS_RED) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Started", tdm_numTeams, "darkred", "red");
      Format(clantag, sizeof(clantag), "[RED]");
    }
    else if (Highlights_GetHighlightedColour(client) == COLOURS_BLUE) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Started", tdm_numTeams, "blue", "blue");
      Format(clantag, sizeof(clantag), "[BLUE]");
    }
    else if (Highlights_GetHighlightedColour(client) == COLOURS_GREEN) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Started", tdm_numTeams, "lightgreen", "green");
      Format(clantag, sizeof(clantag), "[GREEN]");
    }
    else if (Highlights_GetHighlightedColour(client) == COLOURS_YELLOW) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Started", tdm_numTeams, "olive", "yellow");
      Format(clantag, sizeof(clantag), "[YELLOW]");
    }
    else if (Highlights_GetHighlightedColour(client) == COLOURS_BLACK) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Started", tdm_numTeams, "default", "black");
      Format(clantag, sizeof(clantag), "[BLACK]");
    }
    
    //Set clan tag and preserve original clan tag
    setAndPreserveClanTag(client, clantag, clantagStorage);
    restoreClanTags = true;
    
    ++tdm_teamCounter;
    
    //Reset counter if we reach last team
    if (tdm_teamCounter == tdm_numTeams)
      tdm_teamCounter = 0;
  }
}