/*
* Priority Speaker
* Prefix: priorityspeaker_
*/

#if defined _wardentools_priorityspeaker_included
  #endinput
#endif
#define _wardentools_priorityspeaker_included

#include <wardentools>

//OnPluginStart
public void Priorityspeaker_OnPluginStart()
{
  HookEvent("round_prestart", Priorityspeaker_Reset, EventHookMode_Post);
}

//Round pre start
public void Priorityspeaker_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  //Disable priority speaker for new wardens
  ConVar priorityToggle = FindConVar("sm_wardentalk2_enabled");
  
  if (priorityToggle != null) {
    SetConVarBool(priorityToggle, false);
  }
}

public void Priorityspeaker_Toggle()
{
  //Toggle Cvar value
  ConVar priorityToggle = FindConVar("sm_wardentalk2_enabled");
  if (priorityToggle != null) {
    SetConVarBool(priorityToggle, !GetConVarBool(priorityToggle));
  }
  
  //Print messages
  if (GetConVarBool(priorityToggle))
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Priority Talk Toggle", "green", "enabled");
  else
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Priority Talk Toggle", "darkred", "disabled");
}