/*
* Shark game mode
* Prefix: shark_
*/

#if defined _wardentools_shark_included
  #endinput
#endif
#define _wardentools_shark_included

#include <wardentools>
#include "wardentools/blind.sp"

#define JAWS_SOUND "invex_gaming/jb_wardentools/jaws_theme.mp3"

//Convars
ConVar cvar_shark_health = null;
ConVar cvar_shark_duration = null;
ConVar cvar_shark_timeleft_warning = null;

//Global Statics
static bool isShark[MAXPLAYERS+1] = false;

//OnPluginStart
public void Shark_OnPluginStart()
{
  //Convars
  cvar_shark_health = CreateConVar("sm_wt_shark_health", "32000", "Health CT Sharks get (def. 32000)");
  cvar_shark_duration = CreateConVar("sm_wt_shark_duration", "30.0", "The amount of time a shark should remain as a shark (def. 30.0)");
  cvar_shark_timeleft_warning = CreateConVar("sm_wt_shark_timeleft_warning", "5.0", "How many seconds should be left before a warning is shown (def. 5.0)");
  
  HookEvent("round_prestart", Shark_Reset, EventHookMode_Post);
  HookEvent("player_death", Shark_EventPlayerDeath, EventHookMode_Pre);
}

//OnClientPutInServer
public void Shark_OnClientPutInServer(int client)
{
  isShark[client] = false;
}

//Player death hook
public Action Shark_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (isShark[client]) {
    isShark[client] = false;
    
    //Unblind them
    Handle fadePack;
    CreateDataTimer(0.0, Blind_UnfadeClient, fadePack);
    WritePackCell(fadePack, client);
    WritePackCell(fadePack, 0);
    WritePackCell(fadePack, 0);
    WritePackCell(fadePack, 0);
    WritePackCell(fadePack, 0);
  
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Shark Removed", client); 
  }
}

//Round pre start
public void Shark_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  for (int i = 1; i <= MaxClients; ++i) {
    if (!IsClientInGame(i))
      continue;
    
    isShark[i] = false;
  }
}

public void Shark_SetShark(int client)
{
  isShark[client] = true;
  
  //Save current health
  int targetCurrentHP = GetEntProp(client, Prop_Send, "m_iHealth");
  int targetCurrentArmour = GetEntProp(client, Prop_Send, "m_ArmorValue");
  
  //Set sharks HP to high ammount
  SetEntProp(client, Prop_Data, "m_iHealth", GetConVarInt(cvar_shark_health));
  SetEntProp(client, Prop_Data, "m_ArmorValue", 0);
  
  //Blind the shark
  Handle fadePack;
  CreateDataTimer(0.0, Blind_FadeClient, fadePack);
  WritePackCell(fadePack, client);
  WritePackCell(fadePack, 0);
  WritePackCell(fadePack, 0);
  WritePackCell(fadePack, 0);
  WritePackCell(fadePack, 255);

  //Set timer to play shark sound
  CreateTimer(5.0, Shark_PlaySharkSound, client);
  
  //Set end timer to remove shark
  CreateTimer(GetConVarFloat(cvar_shark_duration), Shark_RemoveShark, client);
  
  //Set end timer for hp
  Handle pack;
  CreateDataTimer(GetConVarFloat(cvar_shark_duration) + 5.0, Shark_RemoveShark_HP, pack);
  WritePackCell(pack, client);
  WritePackCell(pack, targetCurrentHP);
  WritePackCell(pack, targetCurrentArmour);

  //Set warning timer
  CreateTimer(GetConVarFloat(cvar_shark_duration) - GetConVarFloat(cvar_shark_timeleft_warning), Shark_WarningUnShark, client);
  
  //Print Message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Shark New", client, RoundToNearest(GetConVarFloat(cvar_shark_duration)));
}

//Play shark sound for the shark
public Action Shark_PlaySharkSound(Handle timer, int client)
{
  if (!isShark[client])
    return;
    
  EmitSoundToAllAny(JAWS_SOUND, client, SNDCHAN_AUTO, SNDLEVEL_RAIDSIREN); 
}

//Remove a shark
public Action Shark_RemoveShark(Handle timer, int client)
{
  if (!isShark[client])
    return;
  
  if (!IsPlayerAlive(client))
    return;
  
  //Unblind them
  Handle fadePack;
  CreateDataTimer(0.0, Blind_UnfadeClient, fadePack);
  WritePackCell(fadePack, client);
  WritePackCell(fadePack, 0);
  WritePackCell(fadePack, 0);
  WritePackCell(fadePack, 0);
  WritePackCell(fadePack, 0);
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Shark Removed", client);
}

//Remove shark HP (delayed)
public Action Shark_RemoveShark_HP(Handle timer, Handle pack)
{
  ResetPack(pack);
  
  int client = ReadPackCell(pack);
  int origHP = ReadPackCell(pack);
  int origArmour = ReadPackCell(pack);

  if (!isShark[client])
    return;
  
  if (!IsPlayerAlive(client))
    return;
    
  isShark[client] = false;
  
  //Reset CT health/armour
  SetEntProp(client, Prop_Data, "m_iHealth", origHP);
  SetEntProp(client, Prop_Data, "m_ArmorValue", origArmour);
}

//Warn everybody that shark is about to unshark
public Action Shark_WarningUnShark(Handle timer, int client)
{
  if (!IsPlayerAlive(client))
    return;
    
  if (isShark[client])
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Shark Warning", client, RoundToNearest(GetConVarFloat(cvar_shark_timeleft_warning)));
}

//Getters/setters
public bool Shark_IsShark(int client)
{
  return isShark[client];
}