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
static bool s_IsMuted[MAXPLAYERS+1] = {false, ...}; //so we can keep track of those muted by this plugin rather than in general
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
  
  //Reset all clients
  for (int i = 1; i <= MaxClients; ++i) {
    PrioritySpeaker_ResetClient(i);
  }
}

void PrioritySpeaker_ResetClient(int client)
{
  if (IsClientInGame(client) && !IsFakeClient(client) && s_IsMuted[client])
    PrioritySpeaker_SetClientMute(client, false);
  
  s_IsMuted[client] = false;
  s_BlockMutedMessage[client] = false;
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
  else {
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Priority Speaker Toggle", "darkred", "disabled");

    //Reset all clients
    for (int i = 1; i <= MaxClients; ++i) {
      PrioritySpeaker_ResetClient(i);
    }
  }
}

public void OnClientSpeakingEx(int client)
{
  if (!s_IsEnabled)
    return;
  
  if (!IsClientInGame(client) || IsFakeClient(client))
    return;
  
  //Skip players that aren't alive on T or in spec
  if (!((IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_T) || GetClientTeam(client) == CS_TEAM_SPECTATOR))
    return;
  
  //Get the warden
  int warden = -1;
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && !IsFakeClient(i) && view_as<bool>(warden_iswarden(i))) {
      warden = i;
      break;
    }
  }
  
  //If warden is speaking, mute this client
  if (warden != -1 && IsClientSpeaking(warden)) {
    if (!BaseComm_IsClientMuted(client)) { //Only set mute if they arent already muted via other plugins
      PrioritySpeaker_SetClientMute(client, true);
      s_IsMuted[client] = true;
    }
  } else if (s_IsMuted[client]) {
    PrioritySpeaker_SetClientMute(client, false);
    s_IsMuted[client] = false;
  }
  
  //Check if they are muted at this stage by this plugin to show a hudtext message
  if (s_IsMuted[client] && !s_BlockMutedMessage[client]) {
    //Block message for 1 second so its not spammed
    s_BlockMutedMessage[client] = true;
    CreateTimer(1.0, Timer_RemoveMutedBlock, client);
    
    //Print HudText notifier
    SetHudTextParams(-1.0, 0.85, 1.0, 255, 0, 0, 50, 0, 1.0, 0.2, 0.2);
    ShowHudText(client, HUDTEXT_CHANNEL_PRIORITYSPEAKER, "PRIORITY SPEAKER IS MUTING YOU");
  }
}

public Action Timer_RemoveMutedBlock(Handle timer, int client)
{
  s_BlockMutedMessage[client] = false;
}

//Sets a clients mute using sourcecomms if available, or basecomm otherwise
bool PrioritySpeaker_SetClientMute(int client, bool muteState)
{    
  if (g_IsUsingSourceComms)
    SourceComms_SetClientMute(client, muteState, _, false, "Priority Speaker Mute");
  else
    BaseComm_SetClientMute(client, muteState);
  
  return true;
}