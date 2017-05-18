/*
* Priority Speaker
* Prefix: PrioritySpeaker_
*/

#if defined _wardentools_priorityspeaker_included
  #endinput
#endif
#define _wardentools_priorityspeaker_included

#include <wardentools>
#include <basecomm>
#include <voiceannounce_ex>

//Global statics
static bool s_IsEnabled = false;
static bool s_IsMuted[MAXPLAYERS+1] = {false, ...}; //so we can keep track of those muted by this plugin
static bool s_BlockMutedMessage[MAXPLAYERS+1] = {false, ...};

//OnPluginStart
public void PrioritySpeaker_OnPluginStart()
{
  RegAdminCmd("sm_toggleps", PrioritySpeaker_Command, ADMFLAG_GENERIC, "Toggle priority speaker");
  HookEvent("round_prestart", PrioritySpeaker_Reset, EventHookMode_Post);
}

//Round pre start
public void PrioritySpeaker_Reset(Event event, const char[] name, bool dontBroadcast)
{
  s_IsEnabled = false;
  
  for (int i = 1; i <= MaxClients; ++i) {
    s_IsMuted[i] = false;
    s_BlockMutedMessage[i] = false;
  }
}

public void PrioritySpeaker_Toggle()
{
  PrioritySpeaker_Command(0, 0);
}

public Action PrioritySpeaker_Command(int client, int args)
{
  //Toggle value
  s_IsEnabled = !s_IsEnabled;
  
  //Print messages
  if (s_IsEnabled)
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Priority Speaker Toggle", "green", "enabled");
  else
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Priority Speaker Toggle", "darkred", "disabled");
}

//Fire off 1 call when we detect a client speaking
public void OnClientSpeakingEx(int client)
{
  if (!s_IsEnabled)
    return;
  
  //Skip if already muted
  if (BaseComm_IsClientMuted(client)) {
    if (s_IsMuted[client] && !s_BlockMutedMessage[client]) {
      //Block message for 1 second so its not spammed
      s_BlockMutedMessage[client] = true;
      CreateTimer(1.0, Timer_RemoveMutedBlock, client);
      
      //Print HudText notifier
      SetHudTextParams(-1.0, 0.85, 1.0, 255, 0, 0, 50, 0, 1.0, 0.2, 0.2);
      ShowHudText(client, HUDTEXT_CHANNEL_PRIORITYSPEAKER, "PRIORITY SPEAKER IS MUTING YOU");
    }
    
    return;
  }
  
  //Skip if not warden
  if(!view_as<bool>(warden_iswarden(client)))
    return;
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (i != client && IsClientInGame(i) && !IsFakeClient(i) && IsClientSpeaking(i) && !BaseComm_IsClientMuted(i)) {
      //Only mute alive T's and people in spectator
      if ((IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_T) || GetClientTeam(i) == CS_TEAM_SPECTATOR) {
        BaseComm_SetClientMute(i, true);
        s_IsMuted[i] = true;
      }
    }
  }
}

public void OnClientSpeakingEnd(int client)
{
  if (!IsClientInGame(client) || IsFakeClient(client))
    return;
  
  if (s_IsMuted[client]) {
    if (BaseComm_IsClientMuted(client))
      BaseComm_SetClientMute(client, false);
    
    s_IsMuted[client] = false;
  }
}

public Action Timer_RemoveMutedBlock(Handle timer, int client)
{
  s_BlockMutedMessage[client] = false;
}