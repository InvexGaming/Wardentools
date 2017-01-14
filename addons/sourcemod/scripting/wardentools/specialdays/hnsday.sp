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
ConVar cvar_specialdays_hnsday_cthealth = null;
ConVar cvar_specialdays_hnsday_tptime = null;
ConVar cvar_specialdays_hnsday_thealth = null;
ConVar cvar_specialdays_hnsday_ctfreezetime = null;
ConVar cvar_specialdays_hnsday_hiderswintime = null;

//Static globals
static bool isEnabled = false;
static Handle hnsPrisonersWinHandle = null;

public void Specialdays_Init_HnsDay()
{
  Specialdays_RegisterDay("Hide and Seek Day", Specialdays_HnsDay_Start, Specialdays_HnsDay_End, Specialdays_HnsDay_RestrictionCheck, Specialdays_HnsDay_OnClientPutInServer, false, false);
  
  //ConVars
  cvar_specialdays_hnsday_cthealth = CreateConVar("sm_wt_specialdays_hnsday_cthealth", "32000", "Health CT's get (def. 32000)");
  cvar_specialdays_hnsday_thealth = CreateConVar("sm_wt_specialdays_hnsday_thealth", "65", "Health T's get (def. 65)");
  cvar_specialdays_hnsday_ctfreezetime = CreateConVar("sm_wt_specialdays_hnsday_ctfreezetime", "90", "Number of seconds CT's should be frozen (def. 90)");
  cvar_specialdays_hnsday_tptime = CreateConVar("sm_wt_specialdays_hnsday_tptime", "10.0", "The amount of time before prisoners are teleported to start beacon (def. 10.0)");
  cvar_specialdays_hnsday_hiderswintime = CreateConVar("sm_wt_specialdays_hnsday_hiderswintime", "420.0", "The amount of time before prisoners win the hide and seek round (def. 420.0)");
    
  //Hooks
  HookEvent("player_death", Specialdays_HnsDay_EventPlayerDeath, EventHookMode_Pre);
  HookEvent("player_spawn", Specialdays_HnsDay_EventPlayerSpawn, EventHookMode_Post);
  HookEvent("round_prestart", Specialdays_HnsDay_Reset, EventHookMode_Post);
}

public void Specialdays_HnsDay_Start() 
{
  isEnabled = true;
  
  //Set players health
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i)) {
      SpecialDay_HnsDay_ApplyEffects(i);
    }
  }
  
  //Print start message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - HNS", GetConVarInt(cvar_specialdays_hnsday_ctfreezetime), RoundToNearest(GetConVarFloat(cvar_specialdays_hnsday_tptime)));
  
  //Create timer to kill CT's if they lose
  hnsPrisonersWinHandle = CreateTimer(GetConVarFloat(cvar_specialdays_hnsday_hiderswintime) - GetTimeSinceRoundStart(), Specialdays_HnsDay_HNSPrisonersWin);

  //Create timer for damage protection
  Specialdays_SetDamageProtection(true, float(GetConVarInt(cvar_specialdays_hnsday_ctfreezetime)));

  //Disable unlockables on HNS days
  toggleUnlockables(CS_TEAM_T, 0);
  toggleUnlockables(CS_TEAM_CT, 0);

  //Teleport all players to warden
  int warden = GetWarden();
  if (warden != -1)
    Specialdays_TeleportPlayers(warden, GetConVarFloat(cvar_specialdays_hnsday_tptime), "hide and seek day", Specialdays_Teleport_Start_T, TELEPORTTYPE_T);
      
}

public void Specialdays_HnsDay_End() 
{
  isEnabled = false;
}

public bool Specialdays_HnsDay_RestrictionCheck() 
{
  //Passed with no failures
  return true;
}

public void Specialdays_HnsDay_OnClientPutInServer() 
{
  //Nop
}

//Round pre start
public void Specialdays_HnsDay_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  if (hnsPrisonersWinHandle != null)
    delete hnsPrisonersWinHandle;
    
  //Enable Store jetpack and bunnyhop unlockables
  toggleUnlockables(CS_TEAM_T, 1);
  toggleUnlockables(CS_TEAM_CT, 1);
}

//Player death hook
public Action Specialdays_HnsDay_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  if (!isEnabled)
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
public Action Specialdays_HnsDay_EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!isEnabled)
    return Plugin_Continue;
    
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (!IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
    return Plugin_Continue;
    
  SpecialDay_HnsDay_ApplyEffects(client);
  
  return Plugin_Continue;
}

//Called when prisoners win HNS day
public Action Specialdays_HnsDay_HNSPrisonersWin(Handle timer)
{
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_CT) {
        ForcePlayerSuicide(i);
      }
    }
  }
  
  //Print victory message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - HNS Prisoners Win");
  
  //Reset timer handle
  hnsPrisonersWinHandle = null;
}

//Apply special day effects
void SpecialDay_HnsDay_ApplyEffects(int client)
{
  CreateTimer(0.0, RemoveRadar, client);

  if (GetClientTeam(client) == CS_TEAM_CT) {
    SetEntProp(client, Prop_Data, "m_iHealth", GetConVarInt(cvar_specialdays_hnsday_cthealth));
    
    int timeRemaining = GetConVarInt(cvar_specialdays_hnsday_ctfreezetime) - (GetTime() - Specialdays_GetDayStartTime());
    
    //Apply these effects in 'hide time' only
    if (timeRemaining > 0) {
      ServerCommand("sm_freeze #%d %d", GetClientUserId(client), timeRemaining);
      
      //Blind CT's during hide time
      Blind_SetBlind(client, true);
      
      Handle fadePack;
      CreateDataTimer(0.0, Blind_FadeClient, fadePack);
      WritePackCell(fadePack, client);
      WritePackCell(fadePack, 0);
      WritePackCell(fadePack, 0);
      WritePackCell(fadePack, 0);
      WritePackCell(fadePack, 255);
      
      //Unblind after freeze time
      Handle unfadePack;
      CreateDataTimer(float(timeRemaining), Blind_UnfadeClient, unfadePack);
      WritePackCell(unfadePack, client);
      WritePackCell(unfadePack, 0);
      WritePackCell(unfadePack, 0);
      WritePackCell(unfadePack, 0);
      WritePackCell(unfadePack, 0);
    }
  }
  else if (GetClientTeam(client) == CS_TEAM_T) {
    SetEntProp(client, Prop_Data, "m_iHealth", GetConVarInt(cvar_specialdays_hnsday_thealth));
  }
}