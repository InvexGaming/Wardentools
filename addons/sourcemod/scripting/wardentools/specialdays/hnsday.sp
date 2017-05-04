#include "emitsoundany.inc"
#include "wardentools/blind.sp"
#include <cstrike>

//Defines
#define SHORT_1 "invex_gaming/jb_wardentools/short_gotcha_bitch.mp3"
#define SHORT_2 "invex_gaming/jb_wardentools/short_shut_your.mp3"
#define SHORT_3 "invex_gaming/jb_wardentools/short_oh_baby_a_triple.mp3"
#define SHORT_4 "invex_gaming/jb_wardentools/short_get_noscoped.mp3"
#define SHORT_5 "invex_gaming/jb_wardentools/short_suprise_mother.mp3"
#define SHORT_6 "invex_gaming/jb_wardentools/short_hax.mp3"
#define SHORT_7 "invex_gaming/jb_wardentools/short_nathan_knew.mp3"

//Convars
ConVar g_Cvar_SpecialDays_HnsDay_CtHealth = null;
ConVar g_Cvar_SpecialDays_HnsDay_TeleportTime = null;
ConVar g_Cvar_SpecialDays_HnsDay_THealth = null;
ConVar g_Cvar_SpecialDays_HnsDay_CtFreezeTime = null;
ConVar g_Cvar_SpecialDays_HnsDay_HidersWinTime = null;

//Static globals
static bool s_IsEnabled = false;
static Handle s_HnsPrisonersWinHandle = null;

public void SpecialDays_Init_HnsDay()
{
  SpecialDays_RegisterDay("Hide and Seek Day", SpecialDays_HnsDay_Start, SpecialDays_HnsDay_End, SpecialDays_HnsDay_RestrictionCheck, SpecialDays_HnsDay_OnClientPutInServer, false, false);
  
  //ConVars
  g_Cvar_SpecialDays_HnsDay_CtHealth = CreateConVar("sm_wt_specialdays_hnsday_cthealth", "32000", "Health CT's get (def. 32000)");
  g_Cvar_SpecialDays_HnsDay_THealth = CreateConVar("sm_wt_specialdays_hnsday_thealth", "65", "Health T's get (def. 65)");
  g_Cvar_SpecialDays_HnsDay_CtFreezeTime = CreateConVar("sm_wt_specialdays_hnsday_ctfreezetime", "90", "Number of seconds CT's should be frozen (def. 90)");
  g_Cvar_SpecialDays_HnsDay_TeleportTime = CreateConVar("sm_wt_specialdays_hnsday_tptime", "10.0", "The amount of time before prisoners are teleported to start beacon (def. 10.0)");
  g_Cvar_SpecialDays_HnsDay_HidersWinTime = CreateConVar("sm_wt_specialdays_hnsday_hiderswintime", "420.0", "The amount of time before prisoners win the hide and seek round (def. 420.0)");
    
  //Hooks
  HookEvent("player_death", SpecialDays_HnsDay_EventPlayerDeath, EventHookMode_Pre);
  HookEvent("player_spawn", SpecialDays_HnsDay_EventPlayerSpawn, EventHookMode_Post);
  HookEvent("round_prestart", SpecialDays_HnsDay_Reset, EventHookMode_Post);
}

public void SpecialDays_HnsDay_Start() 
{
  s_IsEnabled = true;
  
  //Set players health
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i)) {
      SpecialDay_HnsDay_ApplyEffects(i);
    }
  }
  
  //Print start message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - HNS", g_Cvar_SpecialDays_HnsDay_CtFreezeTime.IntValue, RoundToNearest(g_Cvar_SpecialDays_HnsDay_TeleportTime.FloatValue));
  
  //Create timer to kill CT's if they lose
  s_HnsPrisonersWinHandle = CreateTimer(g_Cvar_SpecialDays_HnsDay_HidersWinTime.FloatValue - GetTimeSinceRoundStart(), SpecialDays_HnsDay_HNSPrisonersWin);
  
  //Create timer for damage protection
  SpecialDays_SetDamageProtection(true, float(g_Cvar_SpecialDays_HnsDay_CtFreezeTime.IntValue));

  //Disable unlockables on HNS days
  ToggleUnlockables(CS_TEAM_T, 0);
  ToggleUnlockables(CS_TEAM_CT, 0);

  //Teleport all players to warden
  int warden = GetWarden();
  if (warden != -1)
    SpecialDays_TeleportPlayers(warden, g_Cvar_SpecialDays_HnsDay_TeleportTime.FloatValue, "hide and seek day", SpecialDays_Teleport_Start_T, TeleportType_T);
      
}

public void SpecialDays_HnsDay_End() 
{
  s_IsEnabled = false;
}

public bool SpecialDays_HnsDay_RestrictionCheck() 
{
  //Passed with no failures
  return true;
}

public void SpecialDays_HnsDay_OnClientPutInServer() 
{
  //Nop
}

//Round pre start
public void SpecialDays_HnsDay_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  delete s_HnsPrisonersWinHandle;
    
  //Enable Store jetpack and bunnyhop unlockables
  ToggleUnlockables(CS_TEAM_T, 1);
  ToggleUnlockables(CS_TEAM_CT, 1);
}

//Player death hook
public Action SpecialDays_HnsDay_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  if (!s_IsEnabled)
    return Plugin_Continue;
  
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (GetClientTeam(client) == CS_TEAM_T) {
    //Play death  sound for them
    char hnsDeathSounds[7][] = {SHORT_1, SHORT_2, SHORT_3, SHORT_4, SHORT_5, SHORT_6, SHORT_7};
    int randNum = GetRandomInt(0, sizeof(hnsDeathSounds) - 1);
    
    //Play explosion sounds
    EmitSoundToAllAny(hnsDeathSounds[randNum], client, SNDCHAN_USER_BASE, SNDLEVEL_RAIDSIREN); 
  }
  
  return Plugin_Continue;
}

//Player spawn hook
public Action SpecialDays_HnsDay_EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!s_IsEnabled)
    return Plugin_Continue;
    
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (!IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
    return Plugin_Continue;
    
  SpecialDay_HnsDay_ApplyEffects(client);
  
  return Plugin_Continue;
}

//Called when prisoners win HNS day
public Action SpecialDays_HnsDay_HNSPrisonersWin(Handle timer)
{
  s_HnsPrisonersWinHandle = null; //Resolve dangling handle
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_CT) {
        ForcePlayerSuicide(i);
      }
    }
  }
  
  //Print victory message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - HNS Prisoners Win");
}

//Apply special day effects
void SpecialDay_HnsDay_ApplyEffects(int client)
{
  CreateTimer(0.0, RemoveRadar, client);

  if (GetClientTeam(client) == CS_TEAM_CT) {
    SetEntProp(client, Prop_Data, "m_iHealth", g_Cvar_SpecialDays_HnsDay_CtHealth.IntValue);
    
    int timeRemaining = g_Cvar_SpecialDays_HnsDay_CtFreezeTime.IntValue - (GetTime() - SpecialDays_GetDayStartTime());
    
    //Apply these effects in 'hide time' only
    if (timeRemaining > 0) {
      ServerCommand("sm_freeze #%d %d", GetClientUserId(client), timeRemaining);
      
      //Blind CT's during hide time
      Blind_SetBlind(client, true);
      Blind_Blind(client);
      
      //Unblind after freeze time
      Blind_Unblind(client, float(timeRemaining));
      
      //Todo: Need to call Blind_SetBlind(client, false) eventually?
    }
  }
  else if (GetClientTeam(client) == CS_TEAM_T) {
    SetEntProp(client, Prop_Data, "m_iHealth", g_Cvar_SpecialDays_HnsDay_THealth.IntValue);
  }
}