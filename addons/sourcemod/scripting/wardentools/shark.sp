/*
* Shark game mode
* Prefix: Shark_
*/

#if defined _wardentools_shark_included
  #endinput
#endif
#define _wardentools_shark_included

#include <wardentools>
#include "wardentools/blind.sp"

#define JAWS_SOUND "invex_gaming/jb_wardentools/jaws_theme.mp3"

//Convars
ConVar g_Cvar_Shark_Health = null;
ConVar g_Cvar_Shark_Duration = null;
ConVar g_Cvar_Shark_TimeLeftWarning = null;

//Global Statics
static bool s_IsShark[MAXPLAYERS+1] = false;

//OnPluginStart
public void Shark_OnPluginStart()
{
  //Convars
  g_Cvar_Shark_Health = CreateConVar("sm_wt_shark_health", "32000", "Health CT Sharks get (def. 32000)");
  g_Cvar_Shark_Duration = CreateConVar("sm_wt_shark_duration", "30.0", "The amount of time a shark should remain as a shark (def. 30.0)");
  g_Cvar_Shark_TimeLeftWarning = CreateConVar("sm_wt_shark_timeleft_warning", "5.0", "How many seconds should be left before a warning is shown (def. 5.0)");
  
  HookEvent("round_prestart", Shark_Reset, EventHookMode_Post);
  HookEvent("player_death", Shark_EventPlayerDeath, EventHookMode_Pre);
}

//OnClientPutInServer
public void Shark_OnClientPutInServer(int client)
{
  s_IsShark[client] = false;
}

//Player death hook
public Action Shark_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (s_IsShark[client]) {
    s_IsShark[client] = false;
    
    //Unblind them
    Blind_Unblind(client);
  
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Shark Removed", client); 
  }
}

//Round pre start
public void Shark_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  for (int i = 1; i <= MaxClients; ++i) {
    if (!IsClientInGame(i))
      continue;
    
    s_IsShark[i] = false;
  }
}

public void Shark_SetShark(int client)
{
  s_IsShark[client] = true;
  
  //Save current health
  int targetCurrentHP = GetEntProp(client, Prop_Send, "m_iHealth");
  int targetCurrentArmour = GetEntProp(client, Prop_Send, "m_ArmorValue");
  
  //Set sharks HP to high ammount
  SetEntProp(client, Prop_Data, "m_iHealth", g_Cvar_Shark_Health.IntValue);
  SetEntProp(client, Prop_Data, "m_ArmorValue", 0);
  
  //Blind the shark
  Blind_Blind(client);

  //Set timer to play shark sound
  CreateTimer(5.0, Shark_PlaySharkSound, client);
  
  //Set end timer to remove shark
  CreateTimer(g_Cvar_Shark_Duration.FloatValue, Shark_RemoveShark, client);
  
  //Set end timer for hp
  DataPack pack;
  CreateDataTimer(g_Cvar_Shark_Duration.FloatValue + 5.0, Shark_RemoveShark_HP, pack);
  pack.WriteCell(client);
  pack.WriteCell(targetCurrentHP);
  pack.WriteCell(targetCurrentArmour);

  //Set warning timer
  CreateTimer(g_Cvar_Shark_Duration.FloatValue - g_Cvar_Shark_TimeLeftWarning.FloatValue, Shark_WarningUnShark, client);
  
  //Print Message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Shark New", client, RoundToNearest(g_Cvar_Shark_Duration.FloatValue));
}

//Play shark sound for the shark
public Action Shark_PlaySharkSound(Handle timer, int client)
{
  if (!s_IsShark[client])
    return;
    
  EmitSoundToAllAny(JAWS_SOUND, client, SNDCHAN_AUTO, SNDLEVEL_RAIDSIREN); 
}

//Remove a shark
public Action Shark_RemoveShark(Handle timer, int client)
{
  if (!s_IsShark[client])
    return;
  
  if (!IsPlayerAlive(client))
    return;
  
  //Unblind them
  Blind_Unblind(client);
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Shark Removed", client);
}

//Remove shark HP (delayed)
public Action Shark_RemoveShark_HP(Handle timer, DataPack pack)
{
  pack.Reset();
  
  int client = pack.ReadCell();
  int origHP = pack.ReadCell();
  int origArmour = pack.ReadCell();

  if (!s_IsShark[client])
    return;
  
  if (!IsPlayerAlive(client))
    return;
    
  s_IsShark[client] = false;
  
  //Reset CT health/armour
  SetEntProp(client, Prop_Data, "m_iHealth", origHP);
  SetEntProp(client, Prop_Data, "m_ArmorValue", origArmour);
}

//Warn everybody that shark is about to unshark
public Action Shark_WarningUnShark(Handle timer, int client)
{
  if (!IsPlayerAlive(client))
    return;
    
  if (s_IsShark[client])
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Shark Warning", client, RoundToNearest(g_Cvar_Shark_TimeLeftWarning.FloatValue));
}

//Getters/setters
public bool Shark_IsShark(int client)
{
  return s_IsShark[client];
}