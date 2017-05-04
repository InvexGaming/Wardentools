#include "wardentools/colours.sp"
#include "wardentools/highlights.sp"

//Convars
ConVar g_Cvar_SpecialDays_TeamDm_SlayTime = null;
ConVar g_Cvar_SpecialDays_TeamDm_TeleportTime = null;
ConVar g_Cvar_SpecialDays_TeamDm_HideTime = null;
ConVar g_Cvar_SpecialDays_TeamDm_AutoBeaconTime = null;

//Global statics
static bool s_IsEnabled = false;
static bool s_IsPastHideTime = false;
static Handle s_FreeForAllRoundEndHandle = null;
static Handle s_AutoBeaconHandle = null;
static Handle s_FreeForAllStartTimer = null;

static Colour s_TeamColourCodes[] = { Colour_Red, Colour_Blue, Colour_Green, Colour_Yellow, Colour_Black};
static int s_TeamCounter = 0;
static int s_NumTeams = 0;

static bool s_RestoreClanTags = false;
static char s_ClanTagStorage[MAXPLAYERS+1][32];

public void SpecialDays_Init_TeamDm()
{
  SpecialDays_RegisterDay("Team Deathmatch Day", SpecialDays_TeamDm_Start, SpecialDays_TeamDm_End, SpecialDays_TeamDm_RestrictionCheck, SpecialDays_TeamDm_OnClientPutInServer, false, false);
  
  //Convars
  g_Cvar_SpecialDays_TeamDm_TeleportTime = CreateConVar("sm_wt_specialdays_teamdm_tptime", "10.0", "The amount of time before all players are teleported to start beacon (def. 10.0)");
  g_Cvar_SpecialDays_TeamDm_HideTime = CreateConVar("sm_wt_specialdays_teamdm_hidetime", "60", "Number of seconds everyone has to hide (def. 60)");
  g_Cvar_SpecialDays_TeamDm_SlayTime = CreateConVar("sm_wt_specialdays_teamdm_slaytime", "420.0", "The amount of time before all players are slayed (def. 420.0)");
  g_Cvar_SpecialDays_TeamDm_AutoBeaconTime = CreateConVar("sm_wt_specialdays_teamdm_autobeacontime", "300.0", "The amount of time before all players are beaconed and told to actively hunt (def. 300.0)");
  
  //Hook
  HookEvent("player_death", SpecialDays_TeamDm_EventPlayerDeath, EventHookMode_Pre);
  HookEvent("round_prestart", SpecialDays_TeamDm_Reset, EventHookMode_Post);
  HookEvent("player_spawn", SpecialDays_TeamDm_EventPlayerSpawn, EventHookMode_Post);
}

public void SpecialDays_TeamDm_Start() 
{
  s_IsEnabled = true;
  
  //Remove radar
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      CreateTimer(0.0, RemoveRadar, i);
    }
  }
  
  //Create timer to slay all players
  s_FreeForAllRoundEndHandle = CreateTimer(g_Cvar_SpecialDays_TeamDm_SlayTime.FloatValue - GetTimeSinceRoundStart(), SpecialDays_TeamDm_TeamDmEnd);
  
  //Turn on friendly fire to prevent early round ends
  FindConVar("mp_friendlyfire").BoolValue = true;
  FindConVar("mp_teammates_are_enemies").BoolValue = true;
  
  //Create timer for damage protection
  SpecialDays_SetDamageProtection(true, g_Cvar_SpecialDays_TeamDm_TeleportTime.FloatValue + g_Cvar_SpecialDays_TeamDm_HideTime.FloatValue);
  
  //Create Timer for auto beacons
  s_AutoBeaconHandle = CreateTimer(g_Cvar_SpecialDays_TeamDm_AutoBeaconTime.FloatValue - GetTimeSinceRoundStart(), SpecialDays_TeamDm_AutoBeaconOn);
  
  //Team Deathmatch Day message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Day", RoundToNearest(g_Cvar_SpecialDays_TeamDm_TeleportTime.FloatValue), RoundToNearest(g_Cvar_SpecialDays_TeamDm_HideTime.FloatValue));
  
  //Show warning
  SpecialDays_ShowGameStartWarning(g_Cvar_SpecialDays_TeamDm_TeleportTime.FloatValue + g_Cvar_SpecialDays_TeamDm_HideTime.FloatValue, 5);
  
  //Create timer for team dm start
  s_FreeForAllStartTimer = CreateTimer(g_Cvar_SpecialDays_TeamDm_TeleportTime.FloatValue + g_Cvar_SpecialDays_TeamDm_HideTime.FloatValue, SpecialDays_TeamDm_TeamDmStart);
  
  //Teleport all players to warden
  int warden = GetWarden();
  if (warden != -1)
    SpecialDays_TeleportPlayers(warden, g_Cvar_SpecialDays_TeamDm_TeleportTime.FloatValue, "Team Deathmatch", SpecialDays_Teleport_Start_All, TeleportType_All);
}

public void SpecialDays_TeamDm_End() 
{
  s_IsEnabled = false;
}

public bool SpecialDays_TeamDm_RestrictionCheck() 
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
public void SpecialDays_TeamDm_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  delete s_FreeForAllRoundEndHandle;
  delete s_FreeForAllStartTimer;
  delete s_AutoBeaconHandle;

  s_IsPastHideTime = false;
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (!IsClientInGame(i))
      continue;
    
    //Reset clan tags to what was stored
    if (s_RestoreClanTags) {
      CS_SetClientClanTag(i, s_ClanTagStorage[i]);
      s_ClanTagStorage[i] = ""; //reset storage
    }
  }
  
  //After all clan tags have been restored, disable bool
  s_RestoreClanTags = false;
  
  FindConVar("mp_friendlyfire").BoolValue = false;
  FindConVar("mp_teammates_are_enemies").BoolValue = false;
}

public void SpecialDays_TeamDm_OnClientPutInServer(int client)
{
  SDKHook(client, SDKHook_OnTakeDamage, SpecialDays_TeamDm_OnTakeDamage);
}

//Player spawn hook
public Action SpecialDays_TeamDm_EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!s_IsEnabled)
    return Plugin_Continue;
    
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (!IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
    return Plugin_Continue;
  
  SpecialDays_TeamDm_ApplyEffects(client);
  
  return Plugin_Continue;
}

//Player death hook
public Action SpecialDays_TeamDm_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  if (!s_IsEnabled)
    return Plugin_Continue;
  
  if (!s_IsPastHideTime)
    return Plugin_Continue;
  
  //Check if team DM should be stopped
  int teamsLeft = SpecialDays_TeamDm_GetNumTeamsAlive();

  if (teamsLeft <= 1) {
    //Find winning team
    Colour winningTeamCode = Colour_Default;
    
    for (int i = 1; i <= MaxClients; ++i) {
      if (IsClientInGame(i) && IsPlayerAlive(i)) {
        if (Highlights_IsHighlighted(i)) {
          winningTeamCode = Highlights_GetHighlightedColour(i);
          break;
        }
      }
    }
  
    //Print message to all
    if (winningTeamCode == Colour_Red)
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Winner", "darkred", "red");
    else if (winningTeamCode == Colour_Blue)
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Winner", "blue", "blue");
    else if (winningTeamCode == Colour_Green)
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Winner", "lightgreen", "green");
    else if (winningTeamCode == Colour_Yellow)
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Winner", "olive", "yellow");
    else if (winningTeamCode == Colour_Black)
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Winner", "default", "black");

    //End the round
    CS_TerminateRound(FindConVar("mp_round_restart_delay").FloatValue, CSRoundEnd_CTWin, false);
  }
  
  return Plugin_Continue;
}

//Called when a player takes damage
public Action SpecialDays_TeamDm_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  //Ignore invalid entities
  if (!(victim >= 0 && victim <= MaxClients) || !(attacker >= 0 && attacker <= MaxClients)) {
    return Plugin_Continue;
  }

  if (s_IsEnabled && s_IsPastHideTime) {
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
int SpecialDays_TeamDm_GetNumTeamsAlive()
{
  //Check if at least two teams exist
  ArrayList teamsArray = new ArrayList();
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) {
        if (Highlights_IsHighlighted(i)) {
          int index = teamsArray.FindValue(Highlights_GetHighlightedColour(i));
          
          if (index == -1)
            teamsArray.Push(Highlights_GetHighlightedColour(i));
        }
      }
    }
  }
  
  int teamsArrayLength = teamsArray.Length;
  delete teamsArray;
  
  return teamsArrayLength;
}

//Auto beacon all alive players
public Action SpecialDays_TeamDm_AutoBeaconOn(Handle timer)
{
  s_AutoBeaconHandle = null; //Resolve dangling handle
  
  if (!s_IsEnabled)
    return Plugin_Handled;
    
  ServerCommand("sm_beacon @alive");
  ServerCommand("sm_msay All players must now actively hunt other players.");
  
  return Plugin_Handled;
}

//Called when TeamDM round ends
public Action SpecialDays_TeamDm_TeamDmEnd(Handle timer)
{
  s_FreeForAllRoundEndHandle = null; //Resolve dangling handle
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      ForcePlayerSuicide(i);
    }
  }
  
  //Print round end message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Round Over");
}

//Timer called once TeamDM day starts
public Action SpecialDays_TeamDm_TeamDmStart(Handle timer)
{
  s_FreeForAllStartTimer = null; //Resolve dangling handle
  
  s_IsPastHideTime = true; //hide time is over
  
  //Check that there are enough players to play
  ArrayList eligblePlayers = new ArrayList();
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) {
        eligblePlayers.Push(i);
      }
    }
  }
  
  //Check to see if the minimum number of players are present
  if (eligblePlayers.Length < 4) {
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Aborted");
    delete eligblePlayers;
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
  s_NumTeams = 0;
  
  if (eligblePlayers.Length <= 10)
    s_NumTeams = 2;
  else if (eligblePlayers.Length <= 20)
    s_NumTeams = 3;
  else if (eligblePlayers.Length <= 30)
    s_NumTeams = 4;
  else if (eligblePlayers.Length <= 40)
    s_NumTeams = 5;
  
  s_TeamCounter = 0;
  int numAlive = eligblePlayers.Length;  //need non-changing total
  
  //Assign team to each eligble player
  for (int c = 0; c < numAlive; ++c) {
    int rand = GetRandomInt(0, eligblePlayers.Length - 1);
    int client = eligblePlayers.Get(rand);
    RemoveAllValuesFromArray(eligblePlayers, client);
    
    //Highlight, assign team and colour
    SpecialDays_TeamDm_ApplyEffects(client);
  }
  
  delete eligblePlayers;
  
  //Enable hud for all
  CreateTimer(0.5, SpecialDays_TeamDm_ShowHud);
  
  return Plugin_Handled;
}

//Team DM HUD
public Action SpecialDays_TeamDm_ShowHud(Handle timer)
{
  if (!s_IsEnabled)
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
      
      if (Highlights_GetHighlightedColour(client) == Colour_Red) {
        Format(team, sizeof(team), "%s", "RED");
        Format(teamColour, sizeof(teamColour), "%s", "#FF0033");
      }
      else if (Highlights_GetHighlightedColour(client) == Colour_Blue) {
        Format(team, sizeof(team), "%s", "BLUE");
        Format(teamColour, sizeof(teamColour), "%s", "#0000FF");
      }
      else if (Highlights_GetHighlightedColour(client) == Colour_Green) {
        Format(team, sizeof(team), "%s", "GREEN");
        Format(teamColour, sizeof(teamColour), "%s", "#336600");
      }
      else if (Highlights_GetHighlightedColour(client) == Colour_Yellow) {
        Format(team, sizeof(team), "%s", "YELLOW");
        Format(teamColour, sizeof(teamColour), "%s", "#FFFF00");
      }
      else if (Highlights_GetHighlightedColour(client) == Colour_Black) {
        Format(team, sizeof(team), "%s", "BLACK");
        Format(teamColour, sizeof(teamColour), "%s", "#000000");
      }
      
      //Hint HUD
      PrintHintText(client, "%t", "SpecialDay - Team Deathmatch HUD", teamColour, team, teammatesAlive, teammatesTotal, enemiesAlive, enemiesTotal);
    }
  }
  
  CreateTimer(0.5, SpecialDays_TeamDm_ShowHud);

  return Plugin_Handled;
}

//Apply special day effects
void SpecialDays_TeamDm_ApplyEffects(int client)
{
  CreateTimer(0.0, RemoveRadar, client);
  GivePlayerItem(client, "item_assaultsuit");
  SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);
  
  //TDM started, assign random team to this player
  if (s_IsPastHideTime) {
    Highlights_SetIsHighlighted(client, true);
    Highlights_SetHighlightedColour(client, s_TeamColourCodes[s_TeamCounter]);
    
    //Highlight them and print a message
    char clantag[10];
    
    if (Highlights_GetHighlightedColour(client) == Colour_Red) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Started", s_NumTeams, "darkred", "red");
      Format(clantag, sizeof(clantag), "[RED]");
    }
    else if (Highlights_GetHighlightedColour(client) == Colour_Blue) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Started", s_NumTeams, "blue", "blue");
      Format(clantag, sizeof(clantag), "[BLUE]");
    }
    else if (Highlights_GetHighlightedColour(client) == Colour_Green) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Started", s_NumTeams, "lightgreen", "green");
      Format(clantag, sizeof(clantag), "[GREEN]");
    }
    else if (Highlights_GetHighlightedColour(client) == Colour_Yellow) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Started", s_NumTeams, "olive", "yellow");
      Format(clantag, sizeof(clantag), "[YELLOW]");
    }
    else if (Highlights_GetHighlightedColour(client) == Colour_Black) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Started", s_NumTeams, "default", "black");
      Format(clantag, sizeof(clantag), "[BLACK]");
    }
    
    //Set clan tag and preserve original clan tag
    setAndPreserveClanTag(client, clantag, s_ClanTagStorage);
    s_RestoreClanTags = true;
    
    ++s_TeamCounter;
    
    //Reset counter if we reach last team
    if (s_TeamCounter == s_NumTeams)
      s_TeamCounter = 0;
  }
}