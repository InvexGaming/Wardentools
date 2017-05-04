/*
* Priority Speaker
* Prefix: PrioritySpeaker_
*/

#if defined _wardentools_priorityspeaker_included
  #endinput
#endif
#define _wardentools_priorityspeaker_included

#include <wardentools>

//OnPluginStart
public void PrioritySpeaker_OnPluginStart()
{
  HookEvent("round_prestart", PrioritySpeaker_Reset, EventHookMode_Post);
}

//Round pre start
public void PrioritySpeaker_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  //Disable priority speaker for new wardens
  ConVar priorityToggle = FindConVar("sm_wardentalk2_enabled");
  
  if (priorityToggle != null) {
    priorityToggle.BoolValue = false;
  }
}

public void PrioritySpeaker_Toggle()
{
  //Toggle Cvar value
  ConVar priorityToggle = FindConVar("sm_wardentalk2_enabled");
  if (priorityToggle != null) {
    priorityToggle.BoolValue = !priorityToggle.BoolValue;
  }
  
  //Print messages
  if (priorityToggle.BoolValue)
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Priority Talk Toggle", "green", "enabled");
  else
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Priority Talk Toggle", "darkred", "disabled");
}